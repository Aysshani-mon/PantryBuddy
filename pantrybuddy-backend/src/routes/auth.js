const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { avatarKeyToId, avatarIdToKey } = require('../util/avatars');
const { ApiError, asyncHandler } = require('../util/errors');

const router = express.Router();

function userRowToJson(row) {
  return {
    id: String(row.user_id),
    name: row.display_name,
    email: row.email,
    avatarKey: avatarIdToKey(row.avatar_id),
  };
}

// POST /auth/signup { name, email, password, avatarKey }
router.post('/signup', asyncHandler(async (req, res) => {
  const { name, email, password, avatarKey } = req.body;
  if (!name || !email || !password) {
    throw new ApiError(400, 'name, email and password are required.');
  }
  const normalizedEmail = String(email).trim().toLowerCase();

  const [existing] = await pool.query('SELECT user_id FROM users WHERE email = ?', [normalizedEmail]);
  if (existing.length > 0) {
    throw new ApiError(409, 'An account already exists for that email.');
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const avatarId = avatarKeyToId(avatarKey) ?? 1;

  const [result] = await pool.query(
    'INSERT INTO users (email, password_hash, display_name, avatar_id) VALUES (?, ?, ?, ?)',
    [normalizedEmail, passwordHash, name, avatarId]
  );

  const [rows] = await pool.query('SELECT * FROM users WHERE user_id = ?', [result.insertId]);
  res.status(201).json(userRowToJson(rows[0]));
}));

// POST /auth/signin { email, password }
router.post('/signin', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    throw new ApiError(400, 'email and password are required.');
  }
  const normalizedEmail = String(email).trim().toLowerCase();

  const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [normalizedEmail]);
  if (rows.length === 0) {
    throw new ApiError(401, 'Incorrect email or password.');
  }
  const match = await bcrypt.compare(password, rows[0].password_hash);
  if (!match) {
    throw new ApiError(401, 'Incorrect email or password.');
  }
  res.json(userRowToJson(rows[0]));
}));

// POST /auth/forgot-password { email }
// NOTE: does not actually send an email yet — no email service is wired
// up. Deliberately always returns 200 regardless of whether the email
// exists, to avoid leaking which addresses are registered.
router.post('/forgot-password', asyncHandler(async (req, res) => {
  const { email } = req.body;
  if (!email) throw new ApiError(400, 'email is required.');
  // TODO: integrate a real email service (SendGrid, SES, etc.) here and
  // generate/store a reset token. See README "Not yet implemented".
  res.status(200).json({ ok: true });
}));

module.exports = { router, userRowToJson };
