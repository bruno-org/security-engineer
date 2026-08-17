// The product needs an address and a national identifier only at checkout,
// so neither is collected at signup. What is not held cannot leak.
async function signup(req, res) {
  const { email, password } = req.body;

  const user = await db.users.insert({
    email,
    password_hash: await hash(password),
    retention_review_at: addMonths(new Date(), 24),
  });

  // The vendor receives an opaque identifier and an event, no personal data.
  analytics.track(pseudonym(user.id), 'signup_completed');

  res.json({ id: user.id });
}

// The flag is operational recovery, bounded and short. Erasure is a separate
// mechanism that actually removes the record, everywhere it was copied.
async function deleteAccount(req, res) {
  const userId = req.session.userId;
  await db.users.update({ id: userId }, { deleted_at: new Date() });
  await erasureQueue.enqueue({
    userId,
    targets: ['primary', 'replicas', 'search_index', 'analytics', 'support_tool'],
    completeWithinDays: 30,
  });
  res.json({ ok: true });
}

module.exports = { signup, deleteAccount };
