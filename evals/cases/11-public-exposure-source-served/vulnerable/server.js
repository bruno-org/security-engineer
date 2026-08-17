const express = require('express');
const path = require('path');
const app = express();

app.use(express.static(__dirname));

app.get('/debug', (req, res) => {
  res.json({ env: process.env, versions: process.versions });
});

app.use((err, req, res, next) => {
  res.status(500).send(`<pre>${err.stack}</pre>`);
});

app.listen(3000);
