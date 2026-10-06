import { diseaseCatalogSeed } from '@zeavis/shared';
import type { InferInsertModel } from 'drizzle-orm';
import { diseaseCatalog, users } from './schema';

export type DiseaseCatalogRow = InferInsertModel<typeof diseaseCatalog>;
export type UserRow = InferInsertModel<typeof users>;

export const diseaseCatalogRows: DiseaseCatalogRow[] = diseaseCatalogSeed.map((item) => ({
  slug: item.slug,
  label: item.label,
  commonName: item.commonName,
  summary: item.summary,
  description: item.description,
  symptoms: item.symptoms,
  recommendations: item.recommendations,
  riskLevel: item.riskLevel,
  accentColor: item.accentColor,
  displayOrder: item.displayOrder,
}));

export const demoExpertUser = {
  email: 'expert@zeavis.local',
  name: 'ZeaVis Expert',
  role: 'expert' as const,
  password: process.env.DEMO_EXPERT_PASSWORD ?? 'password123',
};
