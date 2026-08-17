const crypto = require('crypto');
const Sentry = require('@sentry/node');

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  sendDefaultPii: false,
  beforeSend(event) {
    delete event.request?.data;
    delete event.request?.cookies;
    return event;
  },
});

// Enough to correlate repeated attempts, not enough to identify anyone.
const pseudonym = (value) =>
  crypto.createHmac('sha256', process.env.LOG_PEPPER).update(String(value)).digest('hex').slice(0, 16);

function logLogin(req) {
  logger.info('login attempt', {
    subject: pseudonym(req.body.email),
    outcome: 'pending',
  });
}

function errorHandler(err, req, res, next) {
  const correlationId = crypto.randomUUID();
  logger.error({ correlationId, name: err.name });
  res.status(500).json({ error: 'internal error', correlationId });
}

module.exports = { logLogin, errorHandler };
