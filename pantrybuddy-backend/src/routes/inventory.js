const express = require('express');
const pool = require('../db');
const { ApiError, asyncHandler } = require('../util/errors');
const { CATEGORY_DB_NAMES, CATEGORY_DART_NAMES, STORAGE_DB_NAMES, STORAGE_DART_NAMES } = require('../util/enums');
const { assertMember, assertMemberForItem } = require('../util/household_access');

const router = express.Router();

// NOTE: schema.sql's inventory_items has no `unit` column (e.g. 'pcs',
// 'g', 'cans') — quantity is a bare DECIMAL. The app's FoodItem.unit is
// therefore NOT persisted yet; this API always returns 'pcs'. Ask the DB
// teammate to add `unit VARCHAR(20) NULL` to inventory_items if you want
// this preserved for real — it's then a 2-line change in this file
// (add it to the INSERT/UPDATE and to itemRowToJson below).
const UNIT_PLACEHOLDER = 'pcs';

function itemRowToJson(row) {
  return {
    id: String(row.inventory_item_id),
    householdId: String(row.team_id),
    name: row.product_name,
    quantity: Number(row.quantity),
    unit: UNIT_PLACEHOLDER,
    storageLocation: STORAGE_DART_NAMES[row.storage_name] ?? 'pantry',
    category: CATEGORY_DART_NAMES[row.category_name] ?? 'shelfStableFoods',
    useByDate: row.expiry_date,
    addedAt: row.entry_date,
    addedByUserId: String(row.created_by),
    disposition: row.status === 'CONSUMED' ? 'consumed' : row.status === 'DISCARDED' ? 'discarded' : null,
    resolvedAt: row.checkout_date,
  };
}

const ITEM_SELECT = `
  SELECT ii.*, p.product_name, p.category_id, pc.category_name, st.storage_name
  FROM inventory_items ii
  JOIN products p ON p.product_id = ii.product_id
  JOIN product_categories pc ON pc.category_id = p.category_id
  JOIN storage_types st ON st.storage_type_id = ii.storage_type_id
`;

/** Finds an existing product row matching (name, category), or creates one. */
async function findOrCreateProductId(conn, name, categoryDartName) {
  const categoryDbName = CATEGORY_DB_NAMES[categoryDartName];
  if (!categoryDbName) throw new ApiError(400, `Unknown category: ${categoryDartName}`);

  const [catRows] = await conn.query('SELECT category_id FROM product_categories WHERE category_name = ?', [categoryDbName]);
  if (catRows.length === 0) throw new ApiError(500, `Category "${categoryDbName}" not found in product_categories.`);
  const categoryId = catRows[0].category_id;

  const [existing] = await conn.query(
    'SELECT product_id FROM products WHERE category_id = ? AND LOWER(product_name) = LOWER(?)',
    [categoryId, name]
  );
  if (existing.length > 0) return existing[0].product_id;

  const [inserted] = await conn.query(
    'INSERT INTO products (category_id, product_name) VALUES (?, ?)',
    [categoryId, name]
  );
  return inserted.insertId;
}

async function findStorageTypeId(conn, storageDartName) {
  const dbName = STORAGE_DB_NAMES[storageDartName];
  if (!dbName) throw new ApiError(400, `Unknown storage location: ${storageDartName}`);
  const [rows] = await conn.query('SELECT storage_type_id FROM storage_types WHERE storage_name = ?', [dbName]);
  if (rows.length === 0) throw new ApiError(500, `Storage type "${dbName}" not found.`);
  return rows[0].storage_type_id;
}

// GET /households/:householdId/inventory-items
router.get('/households/:householdId/inventory-items', asyncHandler(async (req, res) => {
  await assertMember(req.userId, req.params.householdId);
  const [rows] = await pool.query(`${ITEM_SELECT} WHERE ii.team_id = ? ORDER BY ii.expiry_date ASC`, [req.params.householdId]);
  res.json(rows.map(itemRowToJson));
}));

// POST /households/:householdId/inventory-items
// { name, quantity, storageLocation, category, useByDate }
// addedByUserId is always req.userId, never trusted from the body.
router.post('/households/:householdId/inventory-items', asyncHandler(async (req, res) => {
  await assertMember(req.userId, req.params.householdId);
  const { name, quantity, storageLocation, category, useByDate } = req.body;
  if (!name || !quantity || !storageLocation || !category || !useByDate) {
    throw new ApiError(400, 'name, quantity, storageLocation, category, useByDate are required.');
  }
  const addedByUserId = req.userId;

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const productId = await findOrCreateProductId(conn, name, category);
    const storageTypeId = await findStorageTypeId(conn, storageLocation);

    const [result] = await conn.query(
      `INSERT INTO inventory_items
        (team_id, product_id, storage_type_id, created_by, quantity, purchase_date, expiry_date, expiry_date_source, status)
       VALUES (?, ?, ?, ?, ?, CURDATE(), ?, 'USER_INPUT', 'IN_STOCK')`,
      [req.params.householdId, productId, storageTypeId, addedByUserId, quantity, useByDate]
    );
    await conn.query(
      `INSERT INTO inventory_transactions (inventory_item_id, user_id, transaction_type, quantity, note)
       VALUES (?, ?, 'ADD', ?, 'Initial stock entry')`,
      [result.insertId, addedByUserId, quantity]
    );
    await conn.commit();

    const [rows] = await conn.query(`${ITEM_SELECT} WHERE ii.inventory_item_id = ?`, [result.insertId]);
    res.status(201).json(itemRowToJson(rows[0]));
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}));

// PUT /inventory-items/:id  — edit (name/quantity/storage/category/date)
router.put('/inventory-items/:id', asyncHandler(async (req, res) => {
  await assertMemberForItem(req.userId, req.params.id);
  const { name, quantity, storageLocation, category, useByDate } = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [existingRows] = await conn.query(`${ITEM_SELECT} WHERE ii.inventory_item_id = ? FOR UPDATE`, [req.params.id]);
    if (existingRows.length === 0) throw new ApiError(404, 'Item not found.');

    const updates = [];
    const params = [];
    if (name !== undefined && category !== undefined) {
      const productId = await findOrCreateProductId(conn, name, category);
      updates.push('product_id = ?');
      params.push(productId);
    }
    if (storageLocation !== undefined) {
      updates.push('storage_type_id = ?');
      params.push(await findStorageTypeId(conn, storageLocation));
    }
    if (quantity !== undefined) {
      updates.push('quantity = ?');
      params.push(quantity);
    }
    if (useByDate !== undefined) {
      updates.push('expiry_date = ?');
      params.push(useByDate);
    }
    if (updates.length > 0) {
      params.push(req.params.id);
      await conn.query(`UPDATE inventory_items SET ${updates.join(', ')} WHERE inventory_item_id = ?`, params);
    }
    await conn.commit();

    const [rows] = await conn.query(`${ITEM_SELECT} WHERE ii.inventory_item_id = ?`, [req.params.id]);
    res.json(itemRowToJson(rows[0]));
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}));

// POST /inventory-items/:id/resolve { disposition: 'consumed'|'discarded' }
// resolvedByUserId is always req.userId, never trusted from the body.
router.post('/inventory-items/:id/resolve', asyncHandler(async (req, res) => {
  await assertMemberForItem(req.userId, req.params.id);
  const { disposition } = req.body;
  if (!['consumed', 'discarded'].includes(disposition)) {
    throw new ApiError(400, "disposition must be 'consumed' or 'discarded'.");
  }
  const resolvedByUserId = req.userId;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [rows] = await conn.query('SELECT * FROM inventory_items WHERE inventory_item_id = ? FOR UPDATE', [req.params.id]);
    if (rows.length === 0) throw new ApiError(404, 'Item not found.');
    const item = rows[0];
    if (item.status !== 'IN_STOCK') throw new ApiError(409, 'This item has already been resolved.');

    const newStatus = disposition === 'consumed' ? 'CONSUMED' : 'DISCARDED';
    await conn.query(
      'UPDATE inventory_items SET status = ?, checkout_date = NOW() WHERE inventory_item_id = ?',
      [newStatus, req.params.id]
    );

    if (disposition === 'consumed') {
      await conn.query(
        `INSERT INTO inventory_transactions (inventory_item_id, user_id, transaction_type, quantity, note)
         VALUES (?, ?, 'CONSUME', ?, 'Marked consumed')`,
        [req.params.id, resolvedByUserId, item.quantity]
      );
    } else {
      const discardReason = item.expiry_date && new Date(item.expiry_date) < new Date() ? 'EXPIRED' : 'USER_DISCARDED';
      await conn.query(
        `INSERT INTO inventory_transactions (inventory_item_id, user_id, transaction_type, quantity, note, discard_reason)
         VALUES (?, ?, 'DISCARD', ?, 'Marked discarded', ?)`,
        [req.params.id, resolvedByUserId, item.quantity, discardReason]
      );
    }
    await conn.commit();

    const [updatedRows] = await conn.query(`${ITEM_SELECT} WHERE ii.inventory_item_id = ?`, [req.params.id]);
    res.json(itemRowToJson(updatedRows[0]));
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}));

// DELETE /inventory-items/:id
router.delete('/inventory-items/:id', asyncHandler(async (req, res) => {
  await assertMemberForItem(req.userId, req.params.id);
  await pool.query('DELETE FROM inventory_items WHERE inventory_item_id = ?', [req.params.id]);
  res.status(204).send();
}));

module.exports = router;
