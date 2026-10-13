const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

// Request limits for the routes that can be abused: guessing passwords,
// flooding reset emails, or using up the paid/free-tier AI quota.
//
// Counts are kept in memory. On Vercel each running instance keeps its own
// count, so the limits are per instance rather than global — enough to stop
// simple scripted attacks; a shared store (e.g. Redis) or Vercel firewall
// rules would make them global if traffic grows.

const MINUTE = 60 * 1000;

function limiter({ windowMs, limit, message, key, skipSuccessfulRequests = false }) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8', // tells the client when it can retry
    legacyHeaders: false,
    skipSuccessfulRequests,
    keyGenerator: key,
    // Same { error } shape as every other API error, so the app shows it as-is.
    handler: (req, res) => res.status(429).json({ error: message }),
  });
}

const byIp = (req) => ipKeyGenerator(req.ip);
const byIpAndEmail = (req) => `${ipKeyGenerator(req.ip)}|${String((req.body && req.body.email) || '').trim().toLowerCase()}`;
const byUser = (req) => `user:${req.userId}`;

// Only FAILED sign-ins count, so a user who signs in normally is never blocked.
const signInLimiter = limiter({
  windowMs: 15 * MINUTE, limit: 10, key: byIpAndEmail, skipSuccessfulRequests: true,
  message: 'Too many sign-in attempts. Please wait 15 minutes and try again.',
});

const signUpLimiter = limiter({
  windowMs: 60 * MINUTE, limit: 10, key: byIp,
  message: 'Too many accounts created from this network. Please try again later.',
});

const forgotPasswordLimiter = limiter({
  windowMs: 60 * MINUTE, limit: 5, key: byIpAndEmail,
  message: 'Too many reset requests. Please check your inbox, or try again in an hour.',
});

const resetPasswordLimiter = limiter({
  windowMs: 15 * MINUTE, limit: 10, key: byIp,
  message: 'Too many attempts. Please wait 15 minutes and try again.',
});

// AI and photo recognition call paid/limited Google services. Applied after
// requireAuth, so the count is per signed-in user.
const aiLimiter = limiter({
  windowMs: 10 * MINUTE, limit: 20, key: byUser,
  message: 'You have used the AI and photo features a lot in a short time. Please try again in a few minutes.',
});

module.exports = { signInLimiter, signUpLimiter, forgotPasswordLimiter, resetPasswordLimiter, aiLimiter };
