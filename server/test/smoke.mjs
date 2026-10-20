// Quick checks of the contact and chat routes without a database, Redis or the real Anthropic API.
import assert from 'node:assert/strict';
import express from 'express';
import mongoose from 'mongoose';

mongoose.set('bufferCommands', false); mongoose.set('autoCreate', false); mongoose.set('autoIndex', false);
const { default: contact } = await import('../src/contact.js');
const { default: chat } = await import('../src/chat.js');

const pass = (_req, _res, next) => next();
const app = express(); app.use(express.json());
app.use('/api/contact', contact(pass)); app.use('/api/chat', chat(pass));
app.use((_e, _q, res, _n) => res.status(500).json({ error: 'server' }));
const server = app.listen(0);
const base = `http://127.0.0.1:${server.address().port}`;

const realFetch = globalThis.fetch; let sent;
globalThis.fetch = async (url, opts) => {
  if (String(url).startsWith('https://api.anthropic.com')) { sent = JSON.parse(opts.body); return new Response(JSON.stringify({ content: [{ type: 'text', text: 'stub reply' }] }), { status: 200 }); }
  return realFetch(url, opts);
};
const post = (path, body) => realFetch(base + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });

let r = await post('/api/contact', { name: 'A', email: 'nope', message: 'hi' });
assert.equal(r.status, 400); assert.ok((await r.json()).fields.email);
r = await post('/api/contact', { name: 'Bot', email: 'b@x.com', message: 'spam spam spam spam', website: 'http://spam' });
assert.equal(r.status, 201);
r = await post('/api/contact', { name: 'Real Person', email: 'p@x.com', message: 'Hello, I have a role for you.' });
assert.equal(r.status, 500); // valid input reaches the database layer, which is not running here

delete process.env.ANTHROPIC_API_KEY;
r = await post('/api/chat', { messages: [{ role: 'user', content: 'Hi' }] });
assert.equal(r.status, 503);
process.env.ANTHROPIC_API_KEY = 'test-key';
r = await post('/api/chat', { messages: [{ role: 'user', content: '' }] });
assert.equal(r.status, 400);
r = await post('/api/chat', { messages: [{ role: 'assistant', content: 'Hello' }, { role: 'user', content: 'What does Aman do?' }] });
assert.equal(r.status, 200); assert.equal((await r.json()).reply, 'stub reply');
assert.equal(sent.messages[0].role, 'user'); assert.match(sent.system, /Aman Bansal/);

console.log('all smoke checks passed'); server.close(); process.exit(0);
