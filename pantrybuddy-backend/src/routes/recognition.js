const express = require('express');
const pool = require('../db');
const { ApiError, asyncHandler } = require('../util/errors');
const { CATEGORY_DART_NAMES } = require('../util/enums');

const router = express.Router();

// ==================== Config ====================
// Set these in .env (local) AND the Vercel dashboard (deployed), same as
// every other env var this backend uses.
const RECOGNITION_SERVICE_URL = process.env.RECOGNITION_SERVICE_URL; // e.g. http://<oracle-vm-ip>:8001
const RECOGNITION_SERVICE_KEY = process.env.RECOGNITION_SERVICE_KEY; // must match the VM's systemd env
const OFF_USER_AGENT = process.env.OFF_USER_AGENT || 'PantryBuddy/Iteration2 (team-contact-placeholder)';

// ==================== Shared: keyword-mapping lookup ====================
// Verified against the real schema.sql — product_keyword_mapping,
// product_reference and product_categories column names below are exact.
//
// Ranks exact full-name matches above shorter phrase matches, per the
// README's acceptance checks. Returns candidates for user confirmation —
// never auto-assigns anything.
async function resolveByKeywords(keywords, matchType) {
  if (!keywords || keywords.length === 0) return [];
  const normalized = keywords
    .map((k) => k.trim().toLowerCase())
    .filter((k) => k.length > 0);
  if (normalized.length === 0) return [];

  const placeholders = normalized.map(() => '?').join(',');
  const [rows] = await pool.query(
    `SELECT
        pkm.normalized_keyword,
        pkm.keyword,
        pkm.source_name,
        pkm.source_url,
        pr.reference_id,
        pr.product_id,
        pr.product_name,
        pr.category_id,
        pc.category_name
      FROM product_keyword_mapping pkm
      JOIN product_reference pr ON pr.reference_id = pkm.reference_id
      JOIN product_categories pc ON pc.category_id = pr.category_id
      WHERE pkm.match_type = ?
        AND pkm.is_active = 1
        AND pkm.normalized_keyword IN (${placeholders})`,
    [matchType, ...normalized]
  );

  // Exact match on the longest input keyword ranks first (README: "Exact
  // full-name matches should rank above shorter phrase matches").
  const longestInput = normalized.reduce((a, b) => (b.length > a.length ? b : a), '');
  rows.sort((a, b) => {
    const aExact = a.normalized_keyword === longestInput ? 1 : 0;
    const bExact = b.normalized_keyword === longestInput ? 1 : 0;
    return bExact - aExact;
  });

  // De-dupe by reference_id (several keywords can point at the same one).
  const seen = new Set();
  const candidates = [];
  for (const row of rows) {
    if (seen.has(row.reference_id)) continue;
    seen.add(row.reference_id);
    candidates.push({
      referenceId: row.reference_id,
      productId: row.product_id,
      productName: row.product_name,
      categoryId: row.category_id,
      categoryName: row.category_name,
      // The frontend's ProductCategory enum name — null for the 2
      // categories intentionally absent from the 16-category set (see
      // enums.js), in which case the frontend leaves category unset.
      categoryDartName: CATEGORY_DART_NAMES[row.category_name] ?? null,
      matchedKeyword: row.keyword,
      sourceName: row.source_name,
      sourceUrl: row.source_url,
      requiresConfirmation: true,
    });
  }
  return candidates;
}

function normalizeText(text) {
  return text.trim().toLowerCase().replace(/\s+/g, ' ');
}

// ==================== 1. Manual text ====================
// POST /recognize/text  { text }
router.post('/recognize/text', asyncHandler(async (req, res) => {
  const { text } = req.body;
  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    throw new ApiError(400, 'text is required.');
  }
  if (text.length > 500) {
    throw new ApiError(400, 'text must be 500 characters or fewer.');
  }
  const candidates = await resolveByKeywords([normalizeText(text)], 'TEXT');
  res.json({ candidates });
}));

// ==================== 2. Barcode -> Open Food Facts -> mapping ====================
// POST /recognize/barcode  { barcode }
router.post('/recognize/barcode', asyncHandler(async (req, res) => {
  const { barcode } = req.body;
  if (!barcode || typeof barcode !== 'string') {
    throw new ApiError(400, 'barcode is required.');
  }

  const url = `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(barcode)}.json?fields=product_name,product_name_en,categories_tags,brands`;
  let offResponse;
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    offResponse = await fetch(url, {
      headers: { 'User-Agent': OFF_USER_AGENT },
      signal: controller.signal,
    });
    clearTimeout(timeout);
  } catch (e) {
    throw new ApiError(502, 'Could not reach the product database. Try again, or enter the item manually.');
  }

  // Some Open Food Facts deployments return 404 for an unknown barcode
  // instead of 200+status:0 — treat both the same way (see chat history).
  if (offResponse.status === 404) {
    return res.json({ product: null, candidates: [] });
  }
  if (!offResponse.ok) {
    throw new ApiError(502, `Product lookup failed (upstream returned ${offResponse.status}).`);
  }

  const body = await offResponse.json();
  if (body.status !== 1 || !body.product) {
    return res.json({ product: null, candidates: [] });
  }

  const product = body.product;
  const name = (product.product_name_en || product.product_name || '').trim();
  const tags = Array.isArray(product.categories_tags) ? product.categories_tags : [];

  const candidates = await resolveByKeywords(tags, 'OFF_TAG');
  res.json({
    product: { name: name || null, brand: (product.brands || '').split(',')[0]?.trim() || null, categoriesTags: tags },
    candidates,
  });
}));

// ==================== Shared: call the private recognition VM ====================
async function callRecognitionService(path, imageBuffer) {
  if (!RECOGNITION_SERVICE_URL || !RECOGNITION_SERVICE_KEY) {
    throw new ApiError(500, 'Recognition service is not configured on this backend yet.');
  }
  let response;
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000); // model inference can be slow on CPU
    response = await fetch(`${RECOGNITION_SERVICE_URL}${path}`, {
      method: 'POST',
      headers: {
        'X-Service-Key': RECOGNITION_SERVICE_KEY,
        'Content-Type': 'image/jpeg',
      },
      body: imageBuffer,
      signal: controller.signal,
    });
    clearTimeout(timeout);
  } catch (e) {
    throw new ApiError(502, 'Could not reach the recognition service. It may be offline — try manual entry.');
  }
  if (!response.ok) {
    throw new ApiError(502, `Recognition service returned an error (${response.status}).`);
  }
  return response.json();
}

function decodeImageBody(req) {
  const { imageBase64 } = req.body;
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    throw new ApiError(400, 'imageBase64 is required.');
  }
  const buffer = Buffer.from(imageBase64, 'base64');
  // Keep this in sync with whatever the Flutter client compresses to —
  // large uploads risk hitting the platform's request-body size limit.
  const maxBytes = 6 * 1024 * 1024;
  if (buffer.length === 0 || buffer.length > maxBytes) {
    throw new ApiError(400, 'Image must be a non-empty JPEG under 6MB.');
  }
  return buffer;
}

// ==================== 3. Photo -> SigLIP -> mapping ====================
// POST /recognize/image  { imageBase64 }
router.post('/recognize/image', asyncHandler(async (req, res) => {
  const buffer = decodeImageBody(req);
  const result = await callRecognitionService('/image', buffer);
  // Reference service's /image is expected to return { labels: [{ label, score }, ...] }
  const labels = (result.labels || []).map((l) => l.label);
  const candidates = await resolveByKeywords(labels, 'TEXT');
  res.json({ labels: result.labels || [], candidates });
}));

// ==================== 4. OCR -> mapping ====================
// POST /recognize/ocr  { imageBase64 }
router.post('/recognize/ocr', asyncHandler(async (req, res) => {
  const buffer = decodeImageBody(req);
  const result = await callRecognitionService('/ocr', buffer);
  // Reference service's /ocr is expected to return { text: "..." }
  const text = result.text || '';
  const lines = text.split('\n').map((l) => l.trim()).filter(Boolean);
  const candidates = await resolveByKeywords(lines, 'TEXT');
  res.json({ text, candidates });
}));

module.exports = router;
