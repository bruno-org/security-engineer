const express = require('express');
const router = express.Router();

router.get('/invoices/:id', requireSession, async (req, res) => {
  // The account comes from the verified session, never from the request.
  const { rows } = await db.query(
    `select id, account_id, total_cents, pdf_url
       from invoices
      where id = $1 and account_id = $2`,
    [req.params.id, req.session.accountId]
  );
  // Same answer for "does not exist" and "not yours": no enumeration oracle.
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

module.exports = router;
