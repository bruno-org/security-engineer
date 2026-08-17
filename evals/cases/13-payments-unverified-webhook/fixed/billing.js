const express = require('express');
const router = express.Router();

const PLANS = { pro_monthly: { priceId: 'price_1QabcPro', name: 'Pro' } };

router.post('/checkout', requireSession, async (req, res) => {
  // The client names a plan. The price comes from the catalogue.
  const plan = PLANS[req.body.planKey];
  if (!plan) return res.status(400).json({ error: 'unknown plan' });

  const session = await stripe.checkout.sessions.create({
    line_items: [{ price: plan.priceId, quantity: 1 }],
    mode: 'subscription',
    client_reference_id: req.session.accountId,
    success_url: 'https://example.com/success',
  });
  res.json({ url: session.url });
});

// Raw body, because the signature is computed over the bytes as sent.
router.post('/webhooks/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      req.headers['stripe-signature'],
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch {
    return res.status(400).json({ error: 'invalid signature' });
  }

  // Providers retry. The unique constraint on event_id makes the effect
  // happen once no matter how many times the same event arrives.
  const first = await db.processedEvents.insertIfAbsent({ event_id: event.id });
  if (!first) return res.json({ received: true });

  if (event.type === 'checkout.session.completed') {
    await db.accounts.update(
      { id: event.data.object.client_reference_id },
      { plan: 'pro', status: 'active' }
    );
  }
  res.json({ received: true });
});

module.exports = router;
