const nodemailer = require('nodemailer');

const GMAIL_USER = process.env.GMAIL_USER; // e.g. yourname@gmail.com
const GMAIL_APP_PASSWORD = process.env.GMAIL_APP_PASSWORD; // 16-char App Password, NOT your normal Gmail password
const FRONTEND_URL = process.env.FRONTEND_URL; // e.g. https://pantrysentry.vercel.app
// True on Vercel (which sets VERCEL=1) or when NODE_ENV=production.
const IS_DEPLOYED = Boolean(process.env.VERCEL) || process.env.NODE_ENV === 'production';

let transporter = null;
if (GMAIL_USER && GMAIL_APP_PASSWORD) {
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: GMAIL_USER, pass: GMAIL_APP_PASSWORD },
  });
} else {
  console.error('GMAIL_USER / GMAIL_APP_PASSWORD not set — password reset emails will NOT be sent. See README "Email (Gmail SMTP)".');
}

/**
 * Sends a password-reset email with a link back to the Flutter app, via
 * your own Gmail account. Unlike a third-party email API's sandbox mode,
 * this has NO restriction on which recipient it can send to — it works
 * for any user's email address, not just your own, once GMAIL_USER and
 * GMAIL_APP_PASSWORD are set correctly. See README "Email (Gmail SMTP)"
 * for how to generate an App Password.
 */
async function sendPasswordResetEmail(toEmail, resetToken) {
  const resetLink = `${FRONTEND_URL}/#/reset-password?token=${encodeURIComponent(resetToken)}`;

  if (!transporter) {
    // No Gmail credentials configured. Locally, print the link so password
    // reset can still be tested without email. When deployed, never print
    // it: a reset link lets whoever has it take over the account, and logs
    // are readable by more people than the account owner.
    if (IS_DEPLOYED) {
      console.error('Password reset email NOT sent: GMAIL_USER / GMAIL_APP_PASSWORD are not set on this deployment.');
    } else {
      console.log(`[password reset email — not sent, Gmail not configured] Would send to ${toEmail}: ${resetLink}`);
    }
    return;
  }

  await transporter.sendMail({
    from: `"PantrySentry" <${GMAIL_USER}>`,
    to: toEmail,
    subject: 'Reset your PantrySentry password',
    html: `
      <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2E7D4F;">Reset your password</h2>
        <p>We received a request to reset your PantrySentry password. Click the button below to choose a new one — this link expires in 30 minutes.</p>
        <p style="text-align: center; margin: 32px 0;">
          <a href="${resetLink}" style="background: #2E7D4F; color: white; padding: 12px 28px; border-radius: 8px; text-decoration: none; font-weight: bold;">Reset Password</a>
        </p>
        <p style="color: #888; font-size: 13px;">If you didn't request this, you can safely ignore this email.</p>
      </div>
    `,
  });
}

module.exports = { sendPasswordResetEmail };
