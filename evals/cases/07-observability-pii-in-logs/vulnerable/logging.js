const Sentry = require('@sentry/node');

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  sendDefaultPii: true,
});

function logLogin(req) {
  logger.info('login attempt', {
    email: req.body.email,
    password: req.body.password,
    nationalId: req.body.national_id,
    ip: req.ip,
  });
}

function errorHandler(err, req, res, next) {
  logger.error(err);
  res.status(500).json({ error: err.message, stack: err.stack });
}

module.exports = { logLogin, errorHandler };
