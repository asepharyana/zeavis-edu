const uploadAllowedMimeTypes = (Bun.env.UPLOAD_ALLOWED_MIME_TYPES ?? 'image/jpeg,image/png')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const googleOAuthEnabled = Boolean(
  Bun.env.GOOGLE_CLIENT_ID && Bun.env.GOOGLE_CLIENT_SECRET && Bun.env.GOOGLE_REDIRECT_URI,
);

const webAppUrl = Bun.env.WEB_APP_URL ?? 'http://localhost:5173';
const allowedOrigins = [
  webAppUrl,
  'https://tauri.localhost',
  'http://tauri.localhost',
  'tauri://localhost',
  'http://localhost:5173',
];
const secureCookies = Bun.env.SECURE_COOKIES === 'true' || webAppUrl.startsWith('https://');

export const env = {
  port: Number(Bun.env.API_PORT ?? 4006),
  databaseUrl: Bun.env.DATABASE_URL,
  sessionSecret: Bun.env.SESSION_SECRET,
  uploaderBaseUrl: Bun.env.UPLOADER_BASE_URL ?? 'https://upload.asepharyana.my.id',
  // Note: was 'https://upload.asepharyana.tech' — .tech domain is dead, changed to .my.id
  mlServiceUrl: Bun.env.ML_SERVICE_URL ?? 'http://127.0.0.1:8001',
  uploadMaxBytes: Number(Bun.env.UPLOAD_MAX_BYTES ?? 5 * 1024 * 1024),
  uploadAllowedMimeTypes,
  googleOAuthEnabled,
  googleClientId: Bun.env.GOOGLE_CLIENT_ID,
  googleClientSecret: Bun.env.GOOGLE_CLIENT_SECRET,
  googleRedirectUri: Bun.env.GOOGLE_REDIRECT_URI,
  webAppUrl,
  allowedOrigins,
  secureCookies,
};

export function assertRequiredEnv() {
  if (!env.databaseUrl) {
    throw new Error('DATABASE_URL is required');
  }

  if (!env.sessionSecret || env.sessionSecret.length < 32) {
    throw new Error('SESSION_SECRET is required and must be at least 32 characters');
  }
}
