async function signup(req, res) {
  const { email, password, fullName, nationalId, dateOfBirth, address, phone } = req.body;

  const user = await db.users.insert({
    email,
    password_hash: await hash(password),
    full_name: fullName,
    national_id: nationalId,
    date_of_birth: dateOfBirth,
    address,
    phone,
  });

  analytics.identify(user.id, { email, fullName, nationalId, address });

  res.json({ id: user.id });
}

async function deleteAccount(req, res) {
  await db.users.update({ id: req.session.userId }, { deleted: true });
  res.json({ ok: true });
}

module.exports = { signup, deleteAccount };
