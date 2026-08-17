const express = require('express');
const path = require('path');
const app = express();

// Only the build output is published. Nothing else in the tree is reachable.
app.disable('x-powered-by');
app.use(express.static(path.join(__dirname, 'public'), { dotfiles: 'ignore' }));

app.use((err, req, res, next) => {
  const correlationId = crypto.randomUUID();
  logger.error({ correlationId, name: err.name });
  res.status(500).json({ error: 'internal error', correlationId });
});

app.listen(3000);
