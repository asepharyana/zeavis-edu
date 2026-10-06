import { Elysia } from 'elysia';
import type {
  DiseaseCatalogItem,
  DiseaseSlug,
  ImageClassificationRecord,
  ManualClassificationRequest,
  ManualClassificationRecord,
  PredictionProbability,
  UploaderMetadata,
} from '@zeavis/shared';
import { isDiseaseSlug } from '@zeavis/shared';
import { createDbClient } from '../db/client';
import { diseaseCatalog, manualClassifications, imageClassifications } from '../db/schema';
import { badRequest, badGateway, serviceUnavailable } from '../lib/http-errors';
import { desc, eq } from 'drizzle-orm';
import { classifyImage } from '../lib/image-model';
import { uploadImageToStorage } from '../lib/uploader-client';
import { toDisease } from '../lib/disease-mappers';
import { classificationCounter } from '../lib/telemetry';

function toImageClassificationRecord(row: {
  id: string;
  predictedDiseaseSlug: string;
  confidence: number;
  probabilities: unknown;
  imageUrl: string;
  originalFileName: string;
  uploaderPublicId: string;
  uploaderPayload: unknown;
  createdAt: Date;
  disease: {
    slug: string;
    label: string;
    commonName: string;
    summary: string;
    description: string;
    symptoms: string[];
    recommendations: string[];
    riskLevel: string;
    accentColor: string;
    displayOrder: number;
  };
}): ImageClassificationRecord {
  return {
    id: row.id,
    predictedDiseaseSlug: row.predictedDiseaseSlug as DiseaseSlug,
    confidence: row.confidence,
    probabilities: row.probabilities as PredictionProbability[],
    imageUrl: row.imageUrl,
    originalFileName: row.originalFileName,
    uploaderPublicId: row.uploaderPublicId,
    uploader: row.uploaderPayload as UploaderMetadata,
    createdAt: row.createdAt.toISOString(),
    disease: toDisease(row.disease as typeof diseaseCatalog.$inferSelect),
  };
}

export const classificationRoutes = new Elysia({ prefix: '/api/v1' })
  .get('/classifications/image', async () => {
    try {
      const db = createDbClient();
      const rows = await db
        .select({
          id: imageClassifications.id,
          predictedDiseaseSlug: imageClassifications.predictedDiseaseSlug,
          confidence: imageClassifications.confidence,
          probabilities: imageClassifications.probabilities,
          imageUrl: imageClassifications.imageUrl,
          originalFileName: imageClassifications.originalFileName,
          uploaderPublicId: imageClassifications.uploaderPublicId,
          uploaderPayload: imageClassifications.uploaderPayload,
          createdAt: imageClassifications.createdAt,
          disease: {
            slug: diseaseCatalog.slug,
            label: diseaseCatalog.label,
            commonName: diseaseCatalog.commonName,
            summary: diseaseCatalog.summary,
            description: diseaseCatalog.description,
            symptoms: diseaseCatalog.symptoms,
            recommendations: diseaseCatalog.recommendations,
            riskLevel: diseaseCatalog.riskLevel,
            accentColor: diseaseCatalog.accentColor,
            displayOrder: diseaseCatalog.displayOrder,
          },
        })
        .from(imageClassifications)
        .innerJoin(diseaseCatalog, eq(imageClassifications.predictedDiseaseSlug, diseaseCatalog.slug))
        .orderBy(desc(imageClassifications.createdAt))
        .limit(20);

      const records: ImageClassificationRecord[] = rows.map(toImageClassificationRecord);
      return records;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .post('/classifications/image', async ({ body }) => {
    let file: File | undefined;

    if (body instanceof FormData) {
      const formFile = body.get('file');
      if (formFile instanceof File) {
        file = formFile;
      }
    } else if (typeof body === 'object' && body !== null) {
      const bodyObj = body as Record<string, unknown>;
      if (bodyObj.file instanceof File) {
        file = bodyObj.file;
      } else if (Array.isArray(bodyObj.file) && bodyObj.file.length > 0 && bodyObj.file[0] instanceof File) {
        file = bodyObj.file[0];
      }
    }

    if (!file) {
      return badRequest('Missing required field: file');
    }

    if (file.size === 0) {
      return badRequest('File is empty');
    }

    if (file.type !== 'image/jpeg' && file.type !== 'image/png') {
      return badRequest('File must be JPEG or PNG image');
    }

    try {
      let uploaderMetadata: UploaderMetadata;
      try {
        uploaderMetadata = await uploadImageToStorage(file);
      } catch (error) {
        return badGateway(
          `Upload service error: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }

      let classificationResult;
      try {
        classificationResult = await classifyImage(file);
      } catch (error) {
        return serviceUnavailable(
          `Model service error: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }

      classificationCounter.labels(classificationResult.predictedDiseaseSlug).inc();

      const db = createDbClient();
      let diseaseRow;
      try {
        const diseaseRows = await db
          .select()
          .from(diseaseCatalog)
          .where(eq(diseaseCatalog.slug, classificationResult.predictedDiseaseSlug))
          .limit(1);

        if (diseaseRows.length === 0) {
          return serviceUnavailable(
            `Predicted disease "${classificationResult.predictedDiseaseSlug}" not found in catalog`
          );
        }

        diseaseRow = diseaseRows[0];
      } catch (error) {
        return serviceUnavailable('Database unavailable');
      }

      let inserted;
      try {
        const result = await db
          .insert(imageClassifications)
          .values({
            predictedDiseaseSlug: classificationResult.predictedDiseaseSlug,
            confidence: classificationResult.confidence,
            probabilities: classificationResult.probabilities,
            imageUrl: uploaderMetadata.download_url,
            originalFileName: file.name,
            uploaderPublicId: uploaderMetadata.public_id,
            uploaderPayload: uploaderMetadata,
          })
          .returning();

        inserted = result[0];
      } catch (error) {
        return serviceUnavailable('Database unavailable');
      }

      const record: ImageClassificationRecord = toImageClassificationRecord({
        id: inserted.id,
        predictedDiseaseSlug: inserted.predictedDiseaseSlug,
        confidence: inserted.confidence,
        probabilities: inserted.probabilities,
        imageUrl: inserted.imageUrl,
        originalFileName: inserted.originalFileName,
        uploaderPublicId: inserted.uploaderPublicId,
        uploaderPayload: inserted.uploaderPayload,
        createdAt: inserted.createdAt,
        disease: {
          slug: diseaseRow.slug,
          label: diseaseRow.label,
          commonName: diseaseRow.commonName,
          summary: diseaseRow.summary,
          description: diseaseRow.description,
          symptoms: diseaseRow.symptoms,
          recommendations: diseaseRow.recommendations,
          riskLevel: diseaseRow.riskLevel,
          accentColor: diseaseRow.accentColor,
          displayOrder: diseaseRow.displayOrder,
        },
      });

      return record;
    } catch (error) {
      return serviceUnavailable('Internal server error');
    }
  })
  .get('/classifications/manual', async () => {
    try {
      const db = createDbClient();
      const rows = await db
        .select({
          id: manualClassifications.id,
          diseaseSlug: manualClassifications.diseaseSlug,
          observation: manualClassifications.observation,
          location: manualClassifications.location,
          createdAt: manualClassifications.createdAt,
          disease: {
            slug: diseaseCatalog.slug,
            label: diseaseCatalog.label,
            commonName: diseaseCatalog.commonName,
            summary: diseaseCatalog.summary,
            description: diseaseCatalog.description,
            symptoms: diseaseCatalog.symptoms,
            recommendations: diseaseCatalog.recommendations,
            riskLevel: diseaseCatalog.riskLevel,
            accentColor: diseaseCatalog.accentColor,
            displayOrder: diseaseCatalog.displayOrder,
          },
        })
        .from(manualClassifications)
        .innerJoin(diseaseCatalog, eq(manualClassifications.diseaseSlug, diseaseCatalog.slug))
        .orderBy(desc(manualClassifications.createdAt))
        .limit(20);

      const records: ManualClassificationRecord[] = rows.map((row) => ({
        id: row.id,
        diseaseSlug: row.diseaseSlug as any,
        observation: row.observation,
        location: row.location,
        createdAt: row.createdAt.toISOString(),
        disease: toDisease(row.disease as typeof diseaseCatalog.$inferSelect),
      }));

      return records;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .post('/classifications/manual', async ({ body }) => {
    const req = body as Partial<ManualClassificationRequest> | undefined;

    if (!req || typeof req !== 'object' || !req.diseaseSlug || !req.observation || !req.location) {
      return badRequest('Missing required fields: diseaseSlug, observation, location');
    }

    if (!isDiseaseSlug(req.diseaseSlug)) {
      return badRequest(`Unknown disease slug: "${req.diseaseSlug}"`);
    }

    try {
      const db = createDbClient();

      const diseaseExists = await db
        .select()
        .from(diseaseCatalog)
        .where(eq(diseaseCatalog.slug, req.diseaseSlug))
        .limit(1);

      if (diseaseExists.length === 0) {
        return badRequest(`Disease with slug "${req.diseaseSlug}" does not exist`);
      }

      const inserted = await db
        .insert(manualClassifications)
        .values({
          diseaseSlug: req.diseaseSlug,
          observation: req.observation,
          location: req.location,
        })
        .returning();

      const disease = diseaseExists[0];
      const record: ManualClassificationRecord = {
        id: inserted[0].id,
        diseaseSlug: inserted[0].diseaseSlug as any,
        observation: inserted[0].observation,
        location: inserted[0].location,
        createdAt: inserted[0].createdAt.toISOString(),
        disease: toDisease(disease),
      };

      return record;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  });
