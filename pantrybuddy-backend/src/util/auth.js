const jwt = require('jsonwebtoken');
const { ApiError } = require('./errors');

const JWT_SECRET = process.env.JWT_SECRET;
const TOKEN_EXPIRY = '24h';

if (!JWT_SECRET) {
  // Fail loudly rather than silently signing tokens with a guessable
  // default — a missing secret in production would make every token
  // forgeable. Set JWT_SECRET in your .env locally and in Vercel's
  // environment variables for the deployed backend (any long random
  // string works, e.g. generate one with `openssl rand -hex 32`).
  console.error('FATAL: JWT_SECRET is not set. Add it to your .env (local) or Vercel project settings (deployed).');
}

function signToken(userId) {
  return jwt.sign({ sub: String(userId) }, JWT_SECRET, { expiresIn: TOKEN_EXPIRY });
}

/** Applied globally in app.js to everything except /health and /auth/*.
 * Verifies the Bearer token and sets req.userId (a string) for every
 * route below it to use for authorization checks. */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(new ApiError(401, 'Missing or invalid Authorization header.'));
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.userId = payload.sub;
    next();
  } catch (err) {
    next(new ApiError(401, 'Session expired or invalid — please sign in again.'));
  }
}

module.exports = { signToken, requireAuth };
