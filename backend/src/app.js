import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: process.env.CORS_ORIGIN ?? 'http://localhost:8080' }));
  app.use(express.json({ limit: '256kb' }));
  app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'nido-finanzas-api', version: '0.1.0' }));
  app.all('/api/v1/households/:householdId/sync', (_req, res) => res.status(501).json({ error: 'SYNC_NOT_IMPLEMENTED', message: 'Authentication, household authorization and synchronization will be added in the next stage.' }));
  app.use((_req, res) => res.status(404).json({ error: 'NOT_FOUND' }));
  app.use((err, _req, res, _next) => {
    const status = err.status === 400 ? 400 : 500;
    res.status(status).json({ error: status === 400 ? 'INVALID_JSON' : 'INTERNAL_ERROR' });
  });
  return app;
}
