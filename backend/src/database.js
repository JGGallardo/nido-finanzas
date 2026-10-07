import pg from 'pg';

// Independent pool: never reuses another product's connection, schema or credentials.
// Instantiate only after configuring this service's own DATABASE_URL.
export function createDatabasePool() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  return new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 10, ssl: process.env.PG_SSL === 'true' ? { rejectUnauthorized: true } : false });
}
