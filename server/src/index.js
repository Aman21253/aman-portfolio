import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import os from 'os';
import mongoose from 'mongoose';
import Redis from 'ioredis';
import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import contactRoutes from './contact.js';
import chatRoutes from './chat.js';

// Fail fast if a secret is missing instead of running half-configured.
for (const k of ['MONGO_URI', 'REDIS_URL', 'CORS_ORIGIN']) {
  if (!process.env[k]) { console.error(`Missing env var: ${k}`); process.exit(1); }
}

const redis = new Redis(process.env.REDIS_URL);

// Counters live in Redis, so the limit is shared across all API replicas.
const limiter = (windowMs, limit, prefix) =>
  rateLimit({
    windowMs, limit, standardHeaders: 'draft-7', legacyHeaders: false,
    message: { error: 'Too many requests. Please try again later.' },
    store: new RedisStore({ sendCommand: (...args) => redis.call(...args), prefix }),
  });

const app = express();
app.set('trust proxy', 1); // one hop: Nginx
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN }));
app.use(express.json({ limit: '10kb' }));
// Health check first, so container health probes never count against visitors' rate limit.
app.get('/api/health', (_req, res) => res.json({ ok: true, instance: os.hostname() }));
app.use('/api', limiter(15 * 60 * 1000, 200, 'rl:general:'));
app.use('/api/contact', contactRoutes(limiter(60 * 60 * 1000, 5, 'rl:contact:')));
app.use('/api/chat', chatRoutes(limiter(10 * 60 * 1000, 20, 'rl:chat:'))); // 20 questions per 10 min per IP, shared across replicas

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Something went wrong on our side.' });
});

await mongoose.connect(process.env.MONGO_URI);
app.listen(4000, () => console.log(`API ${os.hostname()} listening on 4000`));
