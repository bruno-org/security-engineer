const express = require('express');
const router = express.Router();

router.post('/checkout', requireSession, async (req, res) => {
  const session = await stripe.checkout.sessions.create({
    line_items: [{
      price_data: {
        currency: 'brl',
        unit_amount: req.body.amountCents,
        product_data: { name: req.body.planName },
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: 'https://example.com/success',
  });
  res.json({ url: session.url });
});

router.post('/webhooks/stripe', express.json(), async (req, res) => {
  const event = req.body;
  if (event.type === 'checkout.session.completed') {
    await db.accounts.update(
      { id: event.data.object.client_reference_id },
      { plan: 'pro', status: 'active' }
    );
  }
  res.json({ received: true });
});

module.exports = router;
