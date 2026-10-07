import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from './src/app.js';

test('Independent health endpoint and explicitly unavailable synchronization', async () => {
  const server = createApp().listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try {
    const origin = `http://127.0.0.1:${server.address().port}`;
    const health = await fetch(`${origin}/health`);
    assert.equal(health.status, 200);
    assert.equal((await health.json()).service, 'nido-finanzas-api');
    assert.equal(health.headers.get('x-powered-by'), null);
    const sync = await fetch(`${origin}/api/v1/households/demo/sync`, { method: 'POST' });
    assert.equal(sync.status, 501);
    assert.equal((await sync.json()).error, 'SYNC_NOT_IMPLEMENTED');
    const other = await fetch(`${origin}/missing`);
    assert.equal(other.status, 404);
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
});
