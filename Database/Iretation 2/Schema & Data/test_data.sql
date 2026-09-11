-- ============================================================
-- PantryBuddy - Household Inventory Reminder System
-- Iteration 2
-- Test Script (test_data.sql)
--
-- Execution order : schema.sql -> insert_static_data.sql -> seed_data.sql -> test_data.sql
--
-- How to run (a human executes and inspects the output):
--   mysql -u <user> -p --force < test_data.sql
--
-- Notes:
--   * Some blocks intentionally raise errors (marked [EXPECTED ERROR]).
--     Use --force so that execution does not stop at the first expected
--     error.
--   * Every block runs inside a transaction and rolls back, so the script
--     is repeatable and leaves no test data behind.
--   * Consume, discard and donate operations lock the target row with
--     SELECT ... FOR UPDATE to simulate concurrent-safe stock updates.
--   * Scenario 22 is the only block without a transaction because DDL
--     statements cause implicit commits in MySQL.
-- ============================================================

USE `Real_ProjectV2.0_TM06`;
SET NAMES utf8mb4;

-- ============================================================
-- SCENARIO 1: users.is_verified defaults to FALSE
-- Verify that omitting is_verified stores FALSE.
-- ============================================================
START TRANSACTION;

INSERT INTO users (email, password_hash, display_name)
VALUES ('test.default.verified@example.com', '$2b$12$TEST_HASH_DEFAULT_0001', 'Default Verified User');

SET @default_user = LAST_INSERT_ID();

SELECT user_id, email, is_verified
FROM users
WHERE user_id = @default_user;
-- Expected: is_verified = 0

ROLLBACK;

-- ============================================================
-- SCENARIO 2: users.is_verified stores TRUE
-- ============================================================
START TRANSACTION;

INSERT INTO users (email, password_hash, display_name, is_verified)
VALUES ('test.verified@example.com', '$2b$12$TEST_HASH_TRUE_0001', 'Verified Test User', TRUE);

SET @verified_user = LAST_INSERT_ID();

SELECT user_id, email, is_verified
FROM users
WHERE user_id = @verified_user;
-- Expected: is_verified = 1

ROLLBACK;

-- ============================================================
-- SCENARIO 3: security_questions stores a bcrypt-like answer hash
-- ============================================================
START TRANSACTION;

INSERT INTO security_questions (user_id, question, answer_hash)
VALUES (4, 'Name of first pet', '$2b$12$TEST_ANSWER_HASH_00000000000000000000000000001');

SET @question_id = LAST_INSERT_ID();

SELECT question_id, user_id, question, answer_hash
FROM security_questions
WHERE question_id = @question_id;
-- Expected: 1 row with the stored question and hash (never plain text)

ROLLBACK;

-- ============================================================
-- SCENARIO 4: UNIQUE(user_id, question) rejects a duplicate question
-- User 1 already has the question 'Name of first pet' in the seed data.
-- ============================================================
START TRANSACTION;

-- [EXPECTED ERROR] Duplicate entry for key 'uq_security_questions_user_question' (error 1062)
INSERT INTO security_questions (user_id, question, answer_hash)
VALUES (1, 'Name of first pet', '$2b$12$DUPLICATE_ANSWER_HASH_00000000000000000000001');

ROLLBACK;

-- ============================================================
-- SCENARIO 5: the same question text is allowed for another user
-- ============================================================
START TRANSACTION;

INSERT INTO security_questions (user_id, question, answer_hash)
VALUES (3, 'Name of first pet', '$2b$12$THIRD_USER_ANSWER_HASH_0000000000000000000001');

SELECT user_id, question
FROM security_questions
WHERE question = 'Name of first pet'
ORDER BY user_id;
-- Expected: one row for user 1 and one row for user 3 (same question, different users)

ROLLBACK;

-- ============================================================
-- SCENARIO 6: security_questions FK uses ON DELETE CASCADE
-- Deleting a user removes that user's security questions.
-- ============================================================
START TRANSACTION;

INSERT INTO users (email, password_hash, display_name)
VALUES ('temp.cascade@example.com', '$2b$12$TEMP_CASCADE_HASH_0001', 'Temp Cascade User');
SET @cascade_user = LAST_INSERT_ID();

INSERT INTO security_questions (user_id, question, answer_hash)
VALUES (@cascade_user, 'Name of first pet', '$2b$12$TEMP_CASCADE_ANSWER_000000000000000000001');

SELECT COUNT(*) AS questions_before_delete
FROM security_questions
WHERE user_id = @cascade_user;
-- Expected: 1

DELETE FROM users WHERE user_id = @cascade_user;

SELECT COUNT(*) AS questions_after_delete
FROM security_questions
WHERE user_id = @cascade_user;
-- Expected: 0 (cascade deleted the question rows)

ROLLBACK;

-- ============================================================
-- SCENARIO 7: product_reference can link to a catalogue product
-- product_id 200 (Beef Knuckle) is not referenced by the seed data.
-- ============================================================
START TRANSACTION;

INSERT INTO product_reference (product_id, category_id, product_name, barcode, description)
VALUES (200, 2, 'Beef Knuckle', NULL, 'Linked reference row for the edge-case tests.');

SET @reference_id = LAST_INSERT_ID();

SELECT pr.reference_id, pr.product_id, pr.category_id, pr.product_name, p.product_name AS catalogue_name
FROM product_reference pr
LEFT JOIN products p ON p.product_id = pr.product_id
WHERE pr.reference_id = @reference_id;
-- Expected: 1 row where product_id = 200 and catalogue_name = 'Beef Knuckle'

ROLLBACK;

-- ============================================================
-- SCENARIO 8: UNIQUE(product_id) rejects a second row for the same product
-- Seed data already links product_id 1 (Starfruit).
-- ============================================================
START TRANSACTION;

-- [EXPECTED ERROR] Duplicate entry for key 'uq_product_reference_product_id' (error 1062)
INSERT INTO product_reference (product_id, category_id, product_name, barcode)
VALUES (1, 5, 'Starfruit Duplicate Link', NULL);

ROLLBACK;

-- ============================================================
-- SCENARIO 9: multiple product_reference rows with NULL product_id are allowed
-- MySQL does not compare NULL values in a UNIQUE index, so the
-- UNIQUE(product_id) key still permits unlinked reference rows.
-- ============================================================
START TRANSACTION;

INSERT INTO product_reference (product_id, category_id, product_name, barcode) VALUES
  (NULL, 15, 'Test Unlinked Reference One', NULL),
  (NULL, 15, 'Test Unlinked Reference Two', NULL);

SELECT COUNT(*) AS null_product_references
FROM product_reference
WHERE product_id IS NULL;
-- Expected: 4 (2 seeded unlinked rows + 2 inserted here)

ROLLBACK;

-- ============================================================
-- SCENARIO 10: UNIQUE(category_id, product_name) rejects a duplicate
-- Seed data already contains (category 5, 'Starfruit').
-- ============================================================
START TRANSACTION;

-- [EXPECTED ERROR] Duplicate entry for key 'uq_product_reference_category_name' (error 1062)
INSERT INTO product_reference (product_id, category_id, product_name, barcode)
VALUES (NULL, 5, 'Starfruit', NULL);

ROLLBACK;

-- ============================================================
-- SCENARIO 11: the same product_name is allowed in another category
-- ============================================================
START TRANSACTION;

INSERT INTO product_reference (product_id, category_id, product_name, barcode) VALUES
  (NULL, 7,  'Mango Drink', NULL),
  (NULL, 15, 'Mango Drink', NULL);

SELECT category_id, product_name, COUNT(*) AS row_count
FROM product_reference
WHERE product_name = 'Mango Drink'
GROUP BY category_id, product_name
ORDER BY category_id;
-- Expected: two rows, one for category 7 and one for category 15

ROLLBACK;

-- ============================================================
-- SCENARIO 12: UNIQUE barcode rejects a duplicate barcode
-- Seed data already uses barcode '9556000000018'.
-- ============================================================
START TRANSACTION;

-- [EXPECTED ERROR] Duplicate entry for key 'uq_product_reference_barcode' (error 1062)
INSERT INTO product_reference (product_id, category_id, product_name, barcode)
VALUES (NULL, 15, 'Duplicate Barcode Reference', '9556000000018');

ROLLBACK;

-- ============================================================
-- SCENARIO 13: multiple NULL barcodes are allowed
-- Empty barcodes must be stored as NULL, never as an empty string.
-- ============================================================
START TRANSACTION;

INSERT INTO product_reference (product_id, category_id, product_name, barcode) VALUES
  (NULL, 15, 'Null Barcode Reference One', NULL),
  (NULL, 15, 'Null Barcode Reference Two', NULL),
  (NULL, 15, 'Null Barcode Reference Three', '');

SELECT SUM(barcode IS NULL) AS null_barcodes, SUM(barcode = '') AS empty_string_barcodes
FROM product_reference
WHERE product_name LIKE 'Null Barcode Reference%';
-- Expected: null_barcodes = 2 (the row inserted with '') is stored as an empty string
--           and shows why the application must convert '' to NULL before inserting

ROLLBACK;

-- ============================================================
-- SCENARIO 14: product_reference.is_active defaults to TRUE
-- ============================================================
START TRANSACTION;

INSERT INTO product_reference (product_id, category_id, product_name, barcode)
VALUES (NULL, 15, 'Default Active Reference', NULL);

SET @active_reference = LAST_INSERT_ID();

SELECT reference_id, product_name, is_active
FROM product_reference
WHERE reference_id = @active_reference;
-- Expected: is_active = 1

ROLLBACK;

-- ============================================================
-- SCENARIO 15: product_reference.product_id FK uses ON DELETE RESTRICT
-- Product 200 is referenced only by the temporary reference row below.
-- ============================================================
START TRANSACTION;

INSERT INTO product_reference (product_id, category_id, product_name, barcode)
VALUES (200, 2, 'Beef Knuckle', NULL);

SELECT product_id, product_name
FROM products
WHERE product_id = 200;
-- Expected: 1 catalogue row

-- [EXPECTED ERROR] Cannot delete or update a parent row: product_reference
-- references products (error 1451)
DELETE FROM products WHERE product_id = 200;

ROLLBACK;

-- ============================================================
-- SCENARIO 16: product_reference.category_id FK uses ON DELETE RESTRICT
-- Category 13 (Condiments, Sauces & Canned Goods) has no products in the
-- static catalogue, so the failure comes from the product_reference FK.
-- ============================================================
START TRANSACTION;

SELECT COUNT(*) AS products_in_category_13
FROM products
WHERE category_id = 13;
-- Expected: 0 (only product_reference rows use this category)

-- [EXPECTED ERROR] Cannot delete or update a parent row: product_reference
-- references product_categories (error 1451)
DELETE FROM product_categories WHERE category_id = 13;

ROLLBACK;

-- ============================================================
-- SCENARIO 17: inventory_items.status accepts DONATED and rejects others
-- ============================================================
START TRANSACTION;

INSERT INTO inventory_items
  (team_id, product_id, storage_type_id, created_by, quantity, unit,
   purchase_date, expiry_date_source, expiry_date, status, discard_reason)
VALUES (1, 12, 1, 1, 2.00, 'pcs', CURDATE(), 'USER_INPUT',
        DATE_ADD(CURDATE(), INTERVAL 3 DAY), 'DONATED', 'DONATED');

SET @donated_item = LAST_INSERT_ID();

SELECT inventory_item_id, status, discard_reason
FROM inventory_items
WHERE inventory_item_id = @donated_item;
-- Expected: status 'DONATED' and discard_reason 'DONATED'

-- [EXPECTED ERROR] Data truncated for column 'status' (error 1265):
-- 'RETURNED' is not a legal enum value
INSERT INTO inventory_items
  (team_id, product_id, storage_type_id, created_by, quantity, unit,
   purchase_date, expiry_date_source, status)
VALUES (1, 12, 1, 1, 1.00, 'pcs', CURDATE(), 'USER_INPUT', 'RETURNED');

ROLLBACK;

-- ============================================================
-- SCENARIO 18: inventory_transactions.transaction_type accepts DONATE
-- and rejects others
-- ============================================================
START TRANSACTION;

INSERT INTO inventory_transactions
  (inventory_item_id, user_id, transaction_type, quantity, note, discard_reason)
VALUES (1, 1, 'DONATE', 1.00, 'Donated to a neighbour', NULL);

SET @donate_transaction = LAST_INSERT_ID();

SELECT transaction_id, transaction_type, quantity, discard_reason
FROM inventory_transactions
WHERE transaction_id = @donate_transaction;
-- Expected: transaction_type 'DONATE' and discard_reason NULL

-- [EXPECTED ERROR] Data truncated for column 'transaction_type' (error 1265):
-- 'RETURN' is not a legal enum value
INSERT INTO inventory_transactions
  (inventory_item_id, user_id, transaction_type, quantity)
VALUES (1, 1, 'RETURN', 1.00);

ROLLBACK;

-- ============================================================
-- SCENARIO 19: donation lifecycle and discard_reason CHECK constraint
-- A DONATE row must keep the transaction-level discard_reason NULL,
-- while a DISCARD row must provide one.
-- ============================================================
START TRANSACTION;

SELECT inventory_item_id, quantity, status
FROM inventory_items
WHERE inventory_item_id = 1
FOR UPDATE;

INSERT INTO inventory_transactions
  (inventory_item_id, user_id, transaction_type, quantity, note, discard_reason)
VALUES (1, 1, 'DONATE', 5.00, 'Full case donated', NULL);

UPDATE inventory_items
SET status = 'DONATED',
    discard_reason = 'DONATED',
    checkout_date = NOW(),
    updated_at = CURRENT_TIMESTAMP
WHERE inventory_item_id = 1;

SELECT i.inventory_item_id, i.status, i.discard_reason,
       t.transaction_type, t.discard_reason AS txn_discard_reason
FROM inventory_items i
JOIN inventory_transactions t USING (inventory_item_id)
WHERE i.inventory_item_id = 1
ORDER BY t.transaction_id DESC
LIMIT 1;
-- Expected: item status 'DONATED', item discard_reason 'DONATED',
--           transaction type 'DONATE', transaction discard_reason NULL

-- [EXPECTED ERROR] Check constraint 'chk_inventory_transactions_discard_reason'
-- is violated (error 3819): a DONATE row must not carry a discard_reason
INSERT INTO inventory_transactions
  (inventory_item_id, user_id, transaction_type, quantity, discard_reason)
VALUES (1, 1, 'DONATE', 1.00, 'EXPIRED');

ROLLBACK;

-- ============================================================
-- SCENARIO 20: new inventory_items columns round-trip
-- Covers unit (explicit and default), notes, discard_reason and
-- consumed_amount.
-- ============================================================
START TRANSACTION;

INSERT INTO inventory_items
  (team_id, product_id, storage_type_id, created_by, quantity, unit, notes,
   purchase_date, expiry_date_source, expiry_date, status, discard_reason, consumed_amount)
VALUES (1, 3, 1, 1, 0.75, 'kg', 'Half a packet left', CURDATE(), 'USER_INPUT',
        DATE_ADD(CURDATE(), INTERVAL 2 DAY), 'CONSUMED', NULL, '0.75');

SET @unit_item = LAST_INSERT_ID();

INSERT INTO inventory_items
  (team_id, product_id, storage_type_id, created_by, quantity,
   purchase_date, expiry_date_source, expiry_date)
VALUES (1, 3, 1, 1, 1.00, CURDATE(), 'USER_INPUT', DATE_ADD(CURDATE(), INTERVAL 2 DAY));

SET @default_unit_item = LAST_INSERT_ID();

SELECT inventory_item_id, unit, notes, consumed_amount
FROM inventory_items
WHERE inventory_item_id = @unit_item;
-- Expected: unit 'kg', notes 'Half a packet left', consumed_amount '0.75'

SELECT inventory_item_id, unit, notes
FROM inventory_items
WHERE inventory_item_id = @default_unit_item;
-- Expected: unit 'pcs' (column default) and notes NULL

ROLLBACK;

-- ============================================================
-- SCENARIO 21: static data and seed data loading check
-- insert_static_data.sql must be executed before seed_data.sql.
-- ============================================================
START TRANSACTION;

SELECT 'storage_types' AS table_name, COUNT(*) AS row_count FROM storage_types
UNION ALL SELECT 'product_categories', COUNT(*) FROM product_categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'shelf_life_rules', COUNT(*) FROM shelf_life_rules
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'teams', COUNT(*) FROM teams
UNION ALL SELECT 'security_questions', COUNT(*) FROM security_questions
UNION ALL SELECT 'product_reference', COUNT(*) FROM product_reference
UNION ALL SELECT 'inventory_items', COUNT(*) FROM inventory_items
UNION ALL SELECT 'inventory_transactions', COUNT(*) FROM inventory_transactions
UNION ALL SELECT 'reminders', COUNT(*) FROM reminders
UNION ALL SELECT 'notification_recipients', COUNT(*) FROM notification_recipients
ORDER BY table_name;

SELECT IF(COUNT(*) = 3, 'PASS', 'FAIL') AS storage_types_check FROM storage_types;
SELECT IF(COUNT(*) = 16, 'PASS', 'FAIL') AS categories_check FROM product_categories;
SELECT IF(COUNT(*) = 200, 'PASS', 'FAIL') AS static_products_check FROM products;
SELECT IF(COUNT(*) = 612, 'PASS', 'FAIL') AS static_rules_check FROM shelf_life_rules;
SELECT IF(COUNT(*) >= 4, 'PASS', 'FAIL') AS seed_users_check FROM users;
SELECT IF(SUM(is_verified) >= 1 AND SUM(is_verified = 0) >= 1, 'PASS', 'FAIL') AS verified_flags_check FROM users;
SELECT IF(COUNT(*) >= 4, 'PASS', 'FAIL') AS security_questions_check FROM security_questions;
SELECT IF(SUM(product_id IS NOT NULL) >= 1 AND SUM(product_id IS NULL) >= 2, 'PASS', 'FAIL') AS reference_link_check
FROM product_reference;
SELECT IF(SUM(status = 'DONATED') >= 1, 'PASS', 'FAIL') AS donated_items_check FROM inventory_items;
SELECT IF(SUM(transaction_type = 'DONATE') >= 1, 'PASS', 'FAIL') AS donate_txn_check FROM inventory_transactions;
SELECT IF(SUM(discard_reason IS NOT NULL) >= 1 AND SUM(consumed_amount IS NOT NULL) >= 1,
          'PASS', 'FAIL') AS disposal_columns_check FROM inventory_items;
-- Expected: every check PASS

ROLLBACK;

-- ============================================================
-- SCENARIO 22: clean schema recreation
-- Drop all 14 tables (reverse dependency order) so the schema can be
-- recreated from scratch. DDL causes implicit commits in MySQL, so this
-- block intentionally runs without a transaction.
--
-- After this block, re-import in order:
--   mysql -u <user> -p < schema.sql
--   mysql -u <user> -p < insert_static_data.sql
--   mysql -u <user> -p < seed_data.sql
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS security_questions;
DROP TABLE IF EXISTS product_reference;
DROP TABLE IF EXISTS notification_recipients;
DROP TABLE IF EXISTS reminders;
DROP TABLE IF EXISTS shelf_life_rules;
DROP TABLE IF EXISTS inventory_transactions;
DROP TABLE IF EXISTS inventory_items;
DROP TABLE IF EXISTS storage_types;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_categories;
DROP TABLE IF EXISTS join_requests;
DROP TABLE IF EXISTS team_members;
DROP TABLE IF EXISTS teams;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

SHOW TABLES;
-- Expected: empty result set (no tables remain)
