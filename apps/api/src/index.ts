import { Elysia } from 'elysia';
import { node } from '@elysiajs/node';
import cors from '@elysiajs/cors';
import { env, assertRequiredEnv } from './config/env';
import { healthRoutes } from './routes/health';
import { statusRoutes } from './routes/status';
import { diseaseRoutes } from './routes/diseases';
import { classificationRoutes } from './routes/classifications';
import { diagnosisRoutes } from './routes/diagnoses';
import { dashboardRoutes } from './routes/dashboard';
import { authRoutes } from './routes/auth';
import { expertRoutes } from './routes/expert';
import { metricsRoutes } from './routes/metrics';
import { httpRequestCounter, httpRequestDuration, httpRequestsActive } from './lib/telemetry';
import './types';

assertRequiredEnv();

// Elysia picks its server adapter from the runtime: under bun it found the Bun
// global and used BunAdapter, but on Node there is no `Bun` global, so it fell
// back to WebStandardAdapter — which has no `listen()` and throws on startup.
// Selecting the Node adapter explicitly is what makes `.listen()` work here.
const app = new Elysia({ adapter: node() })
  .use(cors({
    origin: env.allowedOrigins,
    credentials: true,
  }))
  .use(metricsRoutes)
  .onBeforeHandle(({ request, path }) => {
    httpRequestsActive.inc();
    request.metricsStart = performance.now();
    request.metricsPath = path;
  })
  .onAfterHandle(({ request, set }) => {
    const start = (request as any).metricsStart as number | undefined;
    const path = (request as any).metricsPath as string | undefined;
    if (start && path) {
      const duration = (performance.now() - start) / 1000;
      const method = request.method;
      const status = set.status ?? 200;
      httpRequestCounter.labels(method, path, String(status)).inc();
      httpRequestDuration.labels(method, path).observe(duration);
    }
    httpRequestsActive.dec();
  })
  .use(healthRoutes)
  .use(statusRoutes)
  .use(authRoutes)
  .use(diseaseRoutes)
  .use(classificationRoutes)
  .use(diagnosisRoutes)
  .use(expertRoutes)
  .use(dashboardRoutes)
  .listen(env.port);

// `app.server` only exists on the Bun adapter; the Node adapter holds the
// socket privately, so report the configured port rather than printing undefined.
console.log(`ZeaVis Edu API running at http://0.0.0.0:${env.port}`);

export type App = typeof app;
