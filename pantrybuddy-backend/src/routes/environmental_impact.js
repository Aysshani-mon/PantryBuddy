const express = require('express');
const pool = require('../db');
const { CATEGORY_DART_NAMES } = require('../util/enums');
const { assertMember } = require('../util/household_access');
const { ApiError, asyncHandler } = require('../util/errors');
const { toKilograms, unitWeightKey } = require('../util/weight');

const router = express.Router();

// Epic 8 — Environmental Impact Insights.
//
// Total CO2e = Σ (Q_i × EF_i)
//   Q_i  = quantity of wasted item i, converted to kg (util/weight.js)
//   EF_i = lifecycle emission factor for item i, kg CO2e per kg
//          (Poore & Nemecek 2018, via Our World in Data)
// No GWP multiplier: the factors are already in CO2e (see
// Formula_CO2e.pdf, section 2).
//
// Calculated here on the server rather than in Flutter, so the figures
// come from one place, and the reference data never has to be shipped
// to the client.
//
// "Wasted" means status = DISCARDED only, with checkout_date as the
// moment it happened — the same definition the Progress tab's "Wasted"
// count uses, so the two numbers always describe the same set of items.
// Donated items are not waste and are never counted.
//
// Reference tables (created/filled by the data team — see
// migrations/epic8_emission_factors.sql):
//   emission_factor_reference — one factor per category (reference_id
//     NULL), plus optional product-specific overrides (reference_id set).
//   unit_weight_reference — average kg per pcs/pack/box/... per category.
// Until those tables exist (or while the factor table is empty), this
// returns { status: 'pendingData' } instead of an error, so the frontend
// can be deployed ahead of the data.

const MAX_RANGE_DAYS = 366;
const DAY_MS = 24 * 60 * 60 * 1000;

function parseInstant(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new ApiError(400, `${name} is required (ISO 8601 date-time).`);
  }
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) throw new ApiError(400, `${name} must be an ISO 8601 date-time.`);
  return d;
}

/** JS Date -> 'YYYY-MM-DD HH:MM:SS' in UTC, matching how DATETIME
 * columns are stored (and returned, with dateStrings: true). */
function toDbDateTime(d) {
  return d.toISOString().slice(0, 19).replace('T', ' ');
}

/** DATETIME string from mysql2 (dateStrings: true, no timezone marker,
 * genuinely UTC) -> JS Date. */
function fromDbDateTime(s) {
  if (s instanceof Date) return s;
  const normalised = String(s).includes('T') ? String(s) : String(s).replace(' ', 'T');
  return new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(normalised) ? normalised : `${normalised}Z`);
}

/** The user's local calendar day for an instant, as 'YYYY-MM-DD'. */
function localDayKey(date, tzOffsetMinutes) {
  return new Date(date.getTime() + tzOffsetMinutes * 60000).toISOString().slice(0, 10);
}

function round(n, dp = 3) {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
}

async function loadReferenceData() {
  try {
    const [factorRows] = await pool.query(
      `SELECT category_id, reference_id, owid_entity, kg_co2e_per_kg
       FROM emission_factor_reference`
    );
    const [weightRows] = await pool.query(
      'SELECT category_id, unit, kg_per_unit FROM unit_weight_reference'
    );
    if (factorRows.length === 0) return null;

    const byCategory = new Map();
    const byReference = new Map();
    for (const row of factorRows) {
      const factor = { kgCo2ePerKg: Number(row.kg_co2e_per_kg), entity: row.owid_entity };
      if (!Number.isFinite(factor.kgCo2ePerKg) || factor.kgCo2ePerKg < 0) continue;
      if (row.reference_id === null || row.reference_id === undefined) {
        byCategory.set(Number(row.category_id), factor);
      } else {
        byReference.set(Number(row.reference_id), factor);
      }
    }
    const unitWeights = new Map();
    for (const row of weightRows) {
      const kg = Number(row.kg_per_unit);
      if (Number.isFinite(kg) && kg > 0) unitWeights.set(unitWeightKey(Number(row.category_id), row.unit), kg);
    }
    return { byCategory, byReference, unitWeights };
  } catch (err) {
    // Tables not created yet — the data team's migration hasn't run.
    if (err && (err.code === 'ER_NO_SUCH_TABLE' || err.errno === 1146)) return null;
    throw err;
  }
}

/** Works out one wasted item's CO2e, or why it couldn't be. */
function estimateItem(row, ref) {
  const factor =
    (row.reference_id !== null && row.reference_id !== undefined && ref.byReference.get(Number(row.reference_id))) ||
    ref.byCategory.get(Number(row.category_id)) ||
    null;
  const factorSource = factor
    ? (row.reference_id !== null && row.reference_id !== undefined && ref.byReference.has(Number(row.reference_id)) ? 'product' : 'category')
    : null;
  const weight = toKilograms(row.quantity, row.unit, Number(row.category_id), ref.unitWeights);

  let status = 'estimated';
  if (!factor) status = 'noFactor';
  else if (!weight) status = 'unknownWeight';

  return {
    status,
    kgWasted: weight ? weight.kg : null,
    weightBasis: weight ? weight.basis : null,
    emissionFactor: factor ? factor.kgCo2ePerKg : null,
    factorEntity: factor ? factor.entity : null,
    factorSource,
    kgCo2e: status === 'estimated' ? weight.kg * factor.kgCo2ePerKg : null,
  };
}

// GET /households/:householdId/environmental-impact
//   ?start=<ISO>&end=<ISO>                  current period (inclusive)
//   &previousStart=<ISO>&previousEnd=<ISO>  optional; defaults to the
//                                           equal-length window before start
//   &tzOffsetMinutes=480                    optional; the user's UTC offset,
//                                           for grouping the daily trend by
//                                           their local calendar day
router.get('/households/:householdId/environmental-impact', asyncHandler(async (req, res) => {
  await assertMember(req.userId, req.params.householdId);

  const start = parseInstant(req.query.start, 'start');
  const end = parseInstant(req.query.end, 'end');
  if (end < start) throw new ApiError(400, 'end must be after start.');
  if (end - start > MAX_RANGE_DAYS * DAY_MS) throw new ApiError(400, `The period can be at most ${MAX_RANGE_DAYS} days.`);

  let previousStart;
  let previousEnd;
  if (req.query.previousStart !== undefined || req.query.previousEnd !== undefined) {
    previousStart = parseInstant(req.query.previousStart, 'previousStart');
    previousEnd = parseInstant(req.query.previousEnd, 'previousEnd');
    if (previousEnd < previousStart) throw new ApiError(400, 'previousEnd must be after previousStart.');
    if (previousEnd >= start) throw new ApiError(400, 'The previous period must end before the current one starts.');
    if (previousEnd - previousStart > MAX_RANGE_DAYS * DAY_MS) {
      throw new ApiError(400, `The previous period can be at most ${MAX_RANGE_DAYS} days.`);
    }
  } else {
    previousEnd = new Date(start.getTime() - 1);
    previousStart = new Date(start.getTime() - (end.getTime() - start.getTime()) - 1);
  }

  const tzOffsetMinutes = req.query.tzOffsetMinutes === undefined ? 0 : Number(req.query.tzOffsetMinutes);
  if (!Number.isInteger(tzOffsetMinutes) || Math.abs(tzOffsetMinutes) > 14 * 60) {
    throw new ApiError(400, 'tzOffsetMinutes must be a whole number of minutes between -840 and 840.');
  }

  const ref = await loadReferenceData();
  if (!ref) {
    return res.json({ status: 'pendingData' });
  }

  // Every resolved item across both periods in one query. Non-discarded
  // items are only used to tell "no activity at all" apart from "a real
  // zero-waste period" for the comparison below.
  const [rows] = await pool.query(
    `SELECT ii.inventory_item_id, ii.quantity, ii.unit, ii.status, ii.checkout_date,
            p.product_name, p.category_id, pc.category_name, pr.reference_id
     FROM inventory_items ii
     JOIN products p ON p.product_id = ii.product_id
     JOIN product_categories pc ON pc.category_id = p.category_id
     LEFT JOIN product_reference pr ON pr.product_id = ii.product_id
     WHERE ii.team_id = ?
       AND ii.status IN ('CONSUMED', 'DISCARDED', 'DONATED')
       AND ii.checkout_date BETWEEN ? AND ?`,
    [req.params.householdId, toDbDateTime(previousStart < start ? previousStart : start), toDbDateTime(end)]
  );

  // The LEFT JOIN can repeat an item if a product has several reference
  // rows — keep one row per inventory item.
  const seen = new Set();
  const uniqueRows = rows.filter((r) => (seen.has(r.inventory_item_id) ? false : seen.add(r.inventory_item_id)));

  const inRange = (t, a, b) => t >= a && t <= b;
  let hasCurrentActivity = false;
  let hasPreviousActivity = false;
  let previousTotal = 0;

  const items = [];
  const byCategory = new Map();
  const daily = new Map();

  for (const row of uniqueRows) {
    const resolvedAt = fromDbDateTime(row.checkout_date);
    const isCurrent = inRange(resolvedAt, start, end);
    const isPrevious = inRange(resolvedAt, previousStart, previousEnd);
    if (isCurrent) hasCurrentActivity = true;
    if (isPrevious) hasPreviousActivity = true;
    if (row.status !== 'DISCARDED') continue;

    const estimate = estimateItem(row, ref);

    if (isPrevious && estimate.status === 'estimated') previousTotal += estimate.kgCo2e;
    if (!isCurrent) continue;

    const category = CATEGORY_DART_NAMES[row.category_name] ?? 'shelfStableFoods';
    items.push({
      id: String(row.inventory_item_id),
      name: row.product_name,
      category,
      quantity: Number(row.quantity),
      unit: row.unit || 'pcs',
      resolvedAt: row.checkout_date,
      status: estimate.status,
      kgWasted: estimate.kgWasted === null ? null : round(estimate.kgWasted),
      weightBasis: estimate.weightBasis,
      emissionFactor: estimate.emissionFactor,
      factorEntity: estimate.factorEntity,
      factorSource: estimate.factorSource,
      kgCo2e: estimate.kgCo2e === null ? null : round(estimate.kgCo2e),
    });

    if (estimate.status !== 'estimated') continue;
    const c = byCategory.get(category) || { category, kgCo2e: 0, kgWasted: 0, itemCount: 0 };
    c.kgCo2e += estimate.kgCo2e;
    c.kgWasted += estimate.kgWasted;
    c.itemCount += 1;
    byCategory.set(category, c);

    const day = localDayKey(resolvedAt, tzOffsetMinutes);
    daily.set(day, (daily.get(day) || 0) + estimate.kgCo2e);
  }

  // One entry per local calendar day in the period, real zeros included,
  // but no entries for days that haven't happened yet (same rule as the
  // existing trend chart, AC 5.3.7).
  const dailySeries = [];
  const lastDay = localDayKey(new Date(Math.min(end.getTime(), Date.now())), tzOffsetMinutes);
  let cursor = new Date(`${localDayKey(start, tzOffsetMinutes)}T00:00:00Z`);
  while (cursor.toISOString().slice(0, 10) <= lastDay) {
    const key = cursor.toISOString().slice(0, 10);
    dailySeries.push({ date: key, kgCo2e: round(daily.get(key) || 0) });
    cursor = new Date(cursor.getTime() + DAY_MS);
  }

  const estimated = items.filter((i) => i.status === 'estimated');
  const total = estimated.reduce((sum, i) => sum + i.kgCo2e, 0);

  res.json({
    status: 'ready',
    totalKgCo2e: round(total),
    totalKgWasted: round(estimated.reduce((sum, i) => sum + i.kgWasted, 0)),
    // null = nothing meaningful to compare against (no resolved items in
    // one of the two periods) — the same rule that fixed the Iteration 2
    // "400% more waste" bug. Compared as an absolute kg difference, not
    // a percentage, so a near-zero previous period can't blow it up.
    previousTotalKgCo2e: hasCurrentActivity && hasPreviousActivity ? round(previousTotal) : null,
    wastedItemCount: items.length,
    estimatedItemCount: estimated.length,
    excludedCounts: {
      noFactor: items.filter((i) => i.status === 'noFactor').length,
      unknownWeight: items.filter((i) => i.status === 'unknownWeight').length,
    },
    hasApproximateWeights: estimated.some((i) => i.weightBasis !== 'mass'),
    byCategory: [...byCategory.values()]
      .map((c) => ({ ...c, kgCo2e: round(c.kgCo2e), kgWasted: round(c.kgWasted) }))
      .sort((a, b) => b.kgCo2e - a.kgCo2e),
    daily: dailySeries,
    items: items.sort((a, b) => (b.kgCo2e ?? -1) - (a.kgCo2e ?? -1)),
  });
}));

module.exports = router;
module.exports._internal = { estimateItem, localDayKey, fromDbDateTime, toDbDateTime };
