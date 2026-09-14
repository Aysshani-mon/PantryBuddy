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

// ==================== Shared: Open Food Facts lookup ====================
// Throws on a genuine network/server failure (distinct from "not found",
// which returns null) — callers that want to tolerate failures for one
// item among many (e.g. receipt parsing) should catch around this
// themselves rather than this function silently swallowing errors.
async function lookupOpenFoodFacts(barcode) {
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
    throw new ApiError(502, 'Could not reach the product database.');
  }
  // Some Open Food Facts deployments return 404 for an unknown barcode
  // instead of 200+status:0 — treat both the same way (see chat history).
  if (offResponse.status === 404) return null;
  if (!offResponse.ok) throw new ApiError(502, `Product lookup failed (upstream returned ${offResponse.status}).`);

  const body = await offResponse.json();
  if (body.status !== 1 || !body.product) return null;
  const product = body.product;
  return {
    name: (product.product_name_en || product.product_name || '').trim() || null,
    brand: (product.brands || '').split(',')[0]?.trim() || null,
    categoriesTags: Array.isArray(product.categories_tags) ? product.categories_tags : [],
  };
}

// ==================== 2. Barcode -> Open Food Facts -> mapping ====================
// POST /recognize/barcode  { barcode }
router.post('/recognize/barcode', asyncHandler(async (req, res) => {
  const { barcode } = req.body;
  if (!barcode || typeof barcode !== 'string') {
    throw new ApiError(400, 'barcode is required.');
  }

  const product = await lookupOpenFoodFacts(barcode);
  if (!product) {
    return res.json({ product: null, candidates: [] });
  }

  const candidates = await resolveByKeywords(product.categoriesTags, 'OFF_TAG');
  res.json({ product, candidates });
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

// ==================== 5. Receipt (Jaya Grocer format) -> items ====================
//
// Built directly against a real Jaya Grocer receipt sample (see chat),
// not guessed — this is deliberately narrow to that one store's layout
// for now, per the team's explicit "just Jaya Grocer for now" scope.
//
// Observed structure, 2 lines per item:
//   Line A: PRODUCT NAME [*N]              <- name, sometimes with a
//                                              trailing promo/limit marker
//   Line B: <barcode> <UNIT> <qty>x<price> <total>
// Anchoring on Line B's barcode is what makes this reliable — it also
// naturally skips the subtotal/discount/footer lines (e.g. a promo-code
// line like "01   14.99   -5.01"), since none of those contain a
// 12-14 digit barcode. This is the same anchoring strategy that worked
// in the earlier KK Supermart notebook, just with real data behind it.
const RECEIPT_ITEM_LINE = /(\d{12,14})\s+([A-Za-z]+)\s+([\d.]+)\s*[xX]\s*([\d.]+)\s+([\d.]+)/;
const RECEIPT_UNIT_MAP = { KG: 'kg', G: 'g', UNIT: 'pcs', PKT: 'pack', PCS: 'pcs', L: 'L', ML: 'mL' };
// Lines that could be mistaken for a product name if they happen to sit
// directly above a real item line — skip these as a name candidate.
const RECEIPT_BOILERPLATE = /^(invoice|item\s*\d|qty\s|saving|subtotal|spec\.?disc|rounding|total|change|approcode|thank you|we sell|if you are)/i;

function parseJayaGrocerReceipt(rawText) {
  const lines = rawText.split('\n').map((l) => l.trim()).filter(Boolean);
  const parsed = [];

  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(RECEIPT_ITEM_LINE);
    if (!match) continue;

    const [, barcode, unitToken, qtyStr, unitPriceStr, totalStr] = match;

    // Name is the nearest preceding line that isn't itself an item line
    // or obvious receipt boilerplate.
    let name = null;
    for (let j = i - 1; j >= 0 && j >= i - 2; j--) {
      const candidate = lines[j];
      if (RECEIPT_ITEM_LINE.test(candidate) || RECEIPT_BOILERPLATE.test(candidate)) continue;
      name = candidate;
      break;
    }
    if (!name) continue; // no usable name — skip rather than guess

    // Strip a trailing promo/limit marker like " *1".
    name = name.replace(/\s*\*\d+\s*$/, '').trim();

    parsed.push({
      rawName: name,
      barcode,
      unit: RECEIPT_UNIT_MAP[unitToken.toUpperCase()] ?? 'pcs',
      quantity: parseFloat(qtyStr),
      unitPrice: parseFloat(unitPriceStr),
      totalPrice: parseFloat(totalStr),
    });
  }
  return parsed;
}

// Strips a trailing size/weight suffix (e.g. "...130.2G", "...360G") to
// try a second, simpler match if the full product name doesn't hit —
// receipt names are often more specific than what's in the keyword table.
function simplifyProductName(name) {
  return name.replace(/\s*\d+(\.\d+)?\s*(G|KG|ML|L)\s*$/i, '').trim();
}

// POST /recognize/receipt  { text }
// Deliberately does NOT auto-decide "food vs not food" by silently
// dropping unmatched lines — every parsed line is returned, but ones
// with zero resolved candidates are flagged (matched: false) so the
// review screen can make that visible rather than losing an item the
// person actually paid for without them knowing.
router.post('/recognize/receipt', asyncHandler(async (req, res) => {
  const { text } = req.body;
  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    throw new ApiError(400, 'text is required.');
  }
  if (text.length > 8000) {
    throw new ApiError(400, 'text is too long — is this really a single receipt?');
  }

  const rawItems = parseJayaGrocerReceipt(text);
  const items = [];
  for (const raw of rawItems) {
    let candidates = await resolveByKeywords([raw.rawName, simplifyProductName(raw.rawName)], 'TEXT');

    // Fall back to the barcode via Open Food Facts if the name-based
    // match came up empty — a second, independent channel to identify
    // the same line item. A failure here (network, OFF down) shouldn't
    // fail the whole receipt, so it's caught per-item.
    if (candidates.length === 0) {
      try {
        const offProduct = await lookupOpenFoodFacts(raw.barcode);
        if (offProduct) {
          candidates = await resolveByKeywords(offProduct.categoriesTags, 'OFF_TAG');
        }
      } catch (e) {
        // swallow — this item just stays unmatched, not a hard failure
      }
    }

    items.push({ ...raw, candidates, matched: candidates.length > 0 });
  }

  res.json({ items });
}));

module.exports = router;
