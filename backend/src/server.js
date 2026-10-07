import { createApp } from './app.js';
const port = Number(process.env.PORT ?? 3000);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');
const server = createApp().listen(port, () => console.log(`Nido Finanzas API listening on port ${port}`));
process.on('SIGTERM', () => server.close());
