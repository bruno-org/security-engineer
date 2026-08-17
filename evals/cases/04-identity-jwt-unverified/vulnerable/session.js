const jwt = require('jsonwebtoken');

function currentUser(req) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return null;

  const claims = jwt.decode(token);
  if (!claims) return null;

  return { id: claims.sub, role: claims.role, tenantId: claims.tenant_id };
}

module.exports = { currentUser };
