import type { DiseaseCatalogItem, DiseaseSlug, DiseaseLabel, RiskLevel } from '@zeavis/shared';
import { getDiseaseBySlug } from '@zeavis/shared';
import type { diseaseCatalog } from '../db/schema';

export function toDisease(row: typeof diseaseCatalog.$inferSelect): DiseaseCatalogItem {
  // `disease_catalog` predates the `medicineRecommendations`/`imageUrl` columns
  // that `DiseaseCatalogItem` requires, and the database is not the source of
  // truth for them — the shared catalog seed is. Fill them in from there (by
  // slug) so a row returned by the API still satisfies the shared type.
  const seed = getDiseaseBySlug(row.slug);

  return {
    slug: row.slug as DiseaseSlug,
    label: row.label as DiseaseLabel,
    commonName: row.commonName,
    summary: row.summary,
    description: row.description,
    symptoms: row.symptoms,
    recommendations: row.recommendations,
    medicineRecommendations: seed?.medicineRecommendations ?? [],
    imageUrl: seed?.imageUrl ?? '',
    riskLevel: row.riskLevel as RiskLevel,
    accentColor: row.accentColor,
    displayOrder: row.displayOrder,
  };
}
