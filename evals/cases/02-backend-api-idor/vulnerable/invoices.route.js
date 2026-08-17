const express = require('express');
const router = express.Router();

router.get('/invoices/:id', requireSession, async (req, res) => {
  const { rows } = await db.query(
    'select id, account_id, total_cents, pdf_url from invoices where id = $1',
    [req.params.id]
  );
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

module.exports = router;
