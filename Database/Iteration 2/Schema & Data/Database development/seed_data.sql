-- ============================================================
-- PantryBuddy - Household Inventory Reminder System
-- Iteration 2
-- Seed Data (seed_data.sql)
--
-- Execution order : schema.sql -> insert_static_data.sql -> seed_data.sql
--
-- Prerequisite : run schema.sql and insert_static_data.sql first so that
--                every table exists and the static catalogue
--                (storage_types, product_categories, products,
--                shelf_life_rules) is already loaded.
--
-- Content      : small development seed data for the operational tables
--                only. The catalogue tables are NOT inserted again here,
--                because insert_static_data.sql already provides them.
-- ============================================================

USE `Real_ProjectV2.0_TM06`;
SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- users
-- is_verified covers both TRUE and FALSE
-- ------------------------------------------------------------
INSERT INTO users (user_id, email, password_hash, display_name, avatar_id, is_verified) VALUES
  (1, 'alice.tan@example.com',  '$2b$12$SEED_HASH_ALICE_000000000000000000000000000000001', 'Alice Tan',  NULL, TRUE),
  (2, 'bob.lee@example.com',    '$2b$12$SEED_HASH_BOB_00000000000000000000000000000000002', 'Bob Lee',    NULL, FALSE),
  (3, 'carol.ng@example.com',   '$2b$12$SEED_HASH_CAROL_0000000000000000000000000000000003', 'Carol Ng',   NULL, TRUE),
  (4, 'david.wong@example.com', '$2b$12$SEED_HASH_DAVID_0000000000000000000000000000000004', 'David Wong', NULL, FALSE);

-- ------------------------------------------------------------
-- teams
-- ------------------------------------------------------------
INSERT INTO teams (team_id, team_name) VALUES
  (1, 'Lee Family Pantry'),
  (2, 'Hacker House Kitchen');

-- ------------------------------------------------------------
-- team_members
-- ------------------------------------------------------------
INSERT INTO team_members (team_id, user_id, role, status, joined_at) VALUES
  (1, 1, 'ADMIN',  'ACTIVE', '2026-07-01 09:00:00'),
  (1, 2, 'MEMBER', 'ACTIVE', '2026-07-02 10:00:00'),
  (2, 3, 'ADMIN',  'ACTIVE', '2026-07-05 11:00:00'),
  (2, 2, 'MEMBER', 'ACTIVE', '2026-07-08 12:00:00'),
  (2, 4, 'MEMBER', 'ACTIVE', '2026-07-15 13:00:00');

-- ------------------------------------------------------------
-- join_requests
-- ------------------------------------------------------------
INSERT INTO join_requests (request_id, team_id, user_id, status, requested_at, reviewed_at, reviewed_by) VALUES
  (1, 1, 3, 'PENDING',  '2026-08-20 10:00:00', NULL,                  NULL),
  (2, 2, 4, 'APPROVED', '2026-07-10 09:00:00', '2026-07-12 09:30:00', 3),
  (3, 1, 4, 'DECLINED', '2026-07-20 14:00:00', '2026-07-21 15:00:00', 1);

-- ------------------------------------------------------------
-- security_questions
-- Answers are stored as bcrypt-like hashes, never as plain text.
-- One row per (user_id, question); several questions per user allowed.
-- ------------------------------------------------------------
INSERT INTO security_questions (question_id, user_id, question, answer_hash) VALUES
  (1, 1, 'Name of first pet',           '$2b$12$ANSWER_HASH_ALICE_PET_0000000000000000000000001'),
  (2, 1, 'City where you were born',    '$2b$12$ANSWER_HASH_ALICE_CITY_000000000000000000000002'),
  (3, 2, 'Name of your primary school', '$2b$12$ANSWER_HASH_BOB_SCHOOL_00000000000000000000003'),
  (4, 3, 'Favourite childhood food',    '$2b$12$ANSWER_HASH_CAROL_FOOD_000000000000000000000004');

-- ------------------------------------------------------------
-- product_reference
-- Rows 1-4 are linked to the static products catalogue through
-- product_id. Rows 5-6 are user-added references with product_id NULL,
-- which is allowed because NULL values are not compared by the
-- UNIQUE(product_id) key.
-- ------------------------------------------------------------
INSERT INTO product_reference (reference_id, product_id, category_id, product_name, barcode, description, is_active) VALUES
  (1, 1,    5,  'Starfruit',            NULL,             'Reference row linked to the products catalogue.',            TRUE),
  (2, 2,    5,  'Papaya',               NULL,             'Reference row linked to the products catalogue.',            TRUE),
  (3, 12,   5,  'Mango',                '9556000000018',  'Linked reference row with its own scanned barcode.',         TRUE),
  (4, 101,  4,  'Water Spinach',        NULL,             'Reference row linked to the products catalogue.',            TRUE),
  (5, NULL, 13, 'Homemade Chili Paste', NULL,             'User-added reference, not linked to the catalogue yet.',     TRUE),
  (6, NULL, 15, 'Dried Anchovy Snack',  '9556000000025',  'User-added reference that is currently disabled.',           FALSE);

-- ------------------------------------------------------------
-- inventory_items
-- Covers IN_STOCK, EXPIRED, CONSUMED, DONATED and DISCARDED, plus
-- unit, notes, discard_reason and consumed_amount.
-- storage_type_id : 1 = FRIDGE, 2 = FREEZER, 3 = PANTRY
-- ------------------------------------------------------------
INSERT INTO inventory_items
  (inventory_item_id, team_id, product_id, storage_type_id, created_by, quantity,
   unit, notes, production_date, purchase_date, entry_date, shelf_life_days,
   expiry_date, expiry_date_source, checkout_date, status, discard_reason,
   consumed_amount)
VALUES
  (1, 1, 1,  1, 1, 5.00, 'pcs', 'Bought at the night market', NULL,
   DATE_SUB(CURDATE(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), 7,
   DATE_ADD(CURDATE(), INTERVAL 5 DAY), 'PACKAGING', NULL, 'IN_STOCK', NULL, NULL),
  (2, 1, 12, 1, 1, 3.00, 'pcs', 'Ripening on the counter',
   DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(CURDATE(), INTERVAL 1 DAY),
   DATE_SUB(NOW(), INTERVAL 1 DAY), 5, DATE_ADD(CURDATE(), INTERVAL 4 DAY),
   'CALCULATED', NULL, 'IN_STOCK', NULL, NULL),
  (3, 1, 60, 1, 2, 0.50, 'kg', 'For sambal',
   DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(CURDATE(), INTERVAL 1 DAY),
   DATE_SUB(NOW(), INTERVAL 1 DAY), 2, DATE_ADD(CURDATE(), INTERVAL 1 DAY),
   'CALCULATED', NULL, 'IN_STOCK', NULL, NULL),
  (4, 1, 101, 1, 1, 1.00, 'kg', NULL, NULL,
   DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY), NULL,
   DATE_ADD(CURDATE(), INTERVAL 2 DAY), 'USER_INPUT', NULL, 'IN_STOCK', NULL, NULL),
  (5, 2, 175, 2, 3, 1.00, 'kg', 'Freezer batch 2', NULL,
   DATE_SUB(CURDATE(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 10 DAY), 90,
   DATE_ADD(CURDATE(), INTERVAL 60 DAY), 'PACKAGING', NULL, 'IN_STOCK', NULL, NULL),
  (6, 2, 2,  3, 3, 2.00, 'pcs', NULL, NULL,
   DATE_SUB(CURDATE(), INTERVAL 6 DAY), DATE_SUB(NOW(), INTERVAL 6 DAY), NULL,
   DATE_SUB(CURDATE(), INTERVAL 1 DAY), 'USER_INPUT', DATE_SUB(NOW(), INTERVAL 1 DAY),
   'EXPIRED', 'EXPIRED', NULL),
  (7, 2, 150, 1, 3, 1.00, 'kg', 'Used for soup',
   DATE_SUB(CURDATE(), INTERVAL 3 DAY), DATE_SUB(CURDATE(), INTERVAL 3 DAY),
   DATE_SUB(NOW(), INTERVAL 3 DAY), 7, DATE_ADD(CURDATE(), INTERVAL 4 DAY),
   'CALCULATED', DATE_SUB(NOW(), INTERVAL 2 DAY), 'CONSUMED', NULL, '1.00'),
  (8, 1, 199, 1, 1, 0.80, 'kg', 'Shared with the neighbours', NULL,
   DATE_SUB(CURDATE(), INTERVAL 4 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY), 3,
   DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'PACKAGING', DATE_SUB(NOW(), INTERVAL 1 DAY),
   'DONATED', 'DONATED', NULL),
  (9, 1, 4,  3, 2, 1.00, 'pcs', 'Overripe', NULL,
   DATE_SUB(CURDATE(), INTERVAL 5 DAY), DATE_SUB(NOW(), INTERVAL 5 DAY), NULL,
   DATE_SUB(CURDATE(), INTERVAL 3 DAY), 'USER_INPUT', DATE_SUB(NOW(), INTERVAL 3 DAY),
   'DISCARDED', 'USER_DISCARDED', NULL);

-- ------------------------------------------------------------
-- inventory_transactions
-- ADD for every seeded item, plus CONSUME, DISCARD and DONATE events.
-- discard_reason is non-NULL only for DISCARD transactions.
-- ------------------------------------------------------------
INSERT INTO inventory_transactions
  (transaction_id, inventory_item_id, user_id, transaction_type, quantity, transaction_time, note, discard_reason)
VALUES
  (1,  1, 1, 'ADD',     5.00, DATE_SUB(NOW(), INTERVAL 2 DAY),  'Initial stock entry', NULL),
  (2,  2, 1, 'ADD',     3.00, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Initial stock entry', NULL),
  (3,  3, 2, 'ADD',     0.50, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Initial stock entry', NULL),
  (4,  4, 1, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Initial stock entry', NULL),
  (5,  5, 3, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 10 DAY), 'Initial stock entry', NULL),
  (6,  6, 3, 'ADD',     2.00, DATE_SUB(NOW(), INTERVAL 6 DAY),  'Initial stock entry', NULL),
  (7,  7, 3, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 3 DAY),  'Initial stock entry', NULL),
  (8,  8, 1, 'ADD',     0.80, DATE_SUB(NOW(), INTERVAL 4 DAY),  'Initial stock entry', NULL),
  (9,  9, 2, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 5 DAY),  'Initial stock entry', NULL),
  (10, 7, 3, 'CONSUME', 1.00, DATE_SUB(NOW(), INTERVAL 2 DAY),  'Eaten with dinner', NULL),
  (11, 6, 3, 'DISCARD', 2.00, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Found expired in the pantry', 'EXPIRED'),
  (12, 9, 2, 'DISCARD', 1.00, DATE_SUB(NOW(), INTERVAL 3 DAY),  'Overripe and unappealing', 'USER_DISCARDED'),
  (13, 8, 1, 'DONATE',  0.80, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Given to the neighbours', NULL);

-- ------------------------------------------------------------
-- reminders
-- ------------------------------------------------------------
INSERT INTO reminders
  (reminder_id, inventory_item_id, team_id, created_by, lead_time_days, reminder_at, status, created_at, cancelled_at)
VALUES
  (1, 2, 1, 1, 3, DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 9 HOUR), 'PENDING',   NOW(), NULL),
  (2, 3, 1, 2, 1, DATE_ADD(CURDATE(), INTERVAL 9 HOUR),                           'PENDING',   NOW(), NULL),
  (3, 5, 2, 3, 7, DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 53 DAY), INTERVAL 9 HOUR),'PENDING',   NOW(), NULL),
  (4, 6, 2, 3, 3, DATE_SUB(CURDATE(), INTERVAL 6 DAY),                            'CANCELLED', DATE_SUB(NOW(), INTERVAL 7 DAY), DATE_SUB(NOW(), INTERVAL 5 DAY));

-- ------------------------------------------------------------
-- notification_recipients
-- ------------------------------------------------------------
INSERT INTO notification_recipients (reminder_id, user_id, is_read, read_at) VALUES
  (1, 1, TRUE,  DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (1, 2, FALSE, NULL),
  (2, 1, FALSE, NULL),
  (2, 2, TRUE,  DATE_SUB(NOW(), INTERVAL 2 HOUR)),
  (3, 3, FALSE, NULL),
  (3, 2, FALSE, NULL),
  (4, 3, TRUE,  DATE_SUB(NOW(), INTERVAL 5 DAY)),
  (4, 2, FALSE, NULL);
