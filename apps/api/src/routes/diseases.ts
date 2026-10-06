import { Elysia } from 'elysia';
import type { DiseaseCatalogItem } from '@zeavis/shared';
import { createDbClient } from '../db/client';
import { diseaseCatalog } from '../db/schema';
import { toDisease } from '../lib/disease-mappers';
import { notFound, serviceUnavailable } from '../lib/http-errors';
import { asc, eq } from 'drizzle-orm';

export const diseaseRoutes = new Elysia({ prefix: '/api/v1' })
  .get('/diseases', async () => {
    try {
      const db = createDbClient();
      const rows = await db
        .select()
        .from(diseaseCatalog)
        .orderBy(asc(diseaseCatalog.displayOrder));

      const items: DiseaseCatalogItem[] = rows.map(toDisease);

      return items;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  })
  .get('/diseases/:slug', async ({ params }) => {
    try {
      const db = createDbClient();
      const row = await db
        .select()
        .from(diseaseCatalog)
        .where(eq(diseaseCatalog.slug, params.slug))
        .limit(1);

      if (row.length === 0) {
        return notFound(`Disease with slug "${params.slug}" not found`);
      }

      const item: DiseaseCatalogItem = toDisease(row[0]);

      return item;
    } catch (error) {
      return serviceUnavailable('Database unavailable');
    }
  });
