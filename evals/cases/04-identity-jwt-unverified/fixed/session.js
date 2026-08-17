const jwt = require('jsonwebtoken');

function currentUser(req) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return null;

  let claims;
  try {
    // The accepted algorithm is pinned, so a token that declares another one
    // is rejected instead of being trusted. Expiry is enforced by verify().
    claims = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256'],
      issuer: process.env.JWT_ISSUER,
      maxAge: '15m',
    });
  } catch {
    return null;
  }

  // Role is authoritative in the database, not in the token.
  return { id: claims.sub, tenantId: claims.tenant_id };
}

module.exports = { currentUser };
