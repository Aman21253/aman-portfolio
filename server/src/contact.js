import { Router } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import nodemailer from 'nodemailer';

const Message = mongoose.model('Message', new mongoose.Schema(
  { name: String, email: String, message: String, ip: String }, { timestamps: true }));

const schema = z.object({
  name: z.string().trim().min(2, 'Enter your name.').max(80),
  email: z.string().trim().email('Enter a valid email address.').max(120),
  message: z.string().trim().min(10, 'Write at least 10 characters.').max(2000),
  website: z.string().optional(), // honeypot: real people never fill this in
});

const mailer = process.env.SMTP_HOST
  ? nodemailer.createTransport({
      host: process.env.SMTP_HOST, port: Number(process.env.SMTP_PORT) || 587,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    })
  : null;

export default (limit) => {
  const router = Router();
  router.post('/', limit, async (req, res, next) => {
    const parsed = schema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Check the highlighted fields.', fields: parsed.error.flatten().fieldErrors });
    }
    const { name, email, message, website } = parsed.data;
    if (website) return res.status(201).json({ ok: true }); // silently drop bots
    try {
      await Message.create({ name, email, message, ip: req.ip });
      mailer?.sendMail({
        from: process.env.SMTP_USER, to: process.env.CONTACT_TO, replyTo: email,
        subject: `Portfolio message from ${name}`, text: message,
      }).catch((e) => console.error('Mail failed:', e.message));
      res.status(201).json({ ok: true });
    } catch (e) { next(e); }
  });
  return router;
};
