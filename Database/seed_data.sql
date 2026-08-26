-- ============================================================
-- Household Inventory Reminder System
-- Seed Data (seed_data.sql)
--
-- Prerequisite : run schema.sql first so that all tables exist.
-- Content      : representative English seed data for every table.
-- ============================================================

USE pantry_buddy;
SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- users
-- ------------------------------------------------------------
INSERT INTO users (user_id, email, password_hash, display_name, avatar_id) VALUES
  (1, 'alice.tan@example.com',   '$2b$12$PLACEHOLDER_ALICE_HASH_000000000000000000000000000001', 'Alice Tan',  NULL),
  (2, 'bob.lee@example.com',     '$2b$12$PLACEHOLDER_BOB_HASH_00000000000000000000000000000002', 'Bob Lee',    NULL),
  (3, 'carol.ng@example.com',    '$2b$12$PLACEHOLDER_CAROL_HASH_0000000000000000000000000000003', 'Carol Ng',   NULL),
  (4, 'david.wong@example.com',  '$2b$12$PLACEHOLDER_DAVID_HASH_0000000000000000000000000000004', 'David Wong', NULL);

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
  (1, 1, 3, 'PENDING',  '2026-08-20 10:00:00', NULL,                 NULL),
  (2, 2, 4, 'APPROVED', '2026-07-10 09:00:00', '2026-07-12 09:30:00', 3),
  (3, 1, 4, 'DECLINED', '2026-07-20 14:00:00', '2026-07-21 15:00:00', 1);

-- ------------------------------------------------------------
-- product_categories
-- ------------------------------------------------------------
INSERT INTO product_categories (category_id, category_name, is_fresh_food, description) VALUES
  (1, 'Dairy',           TRUE,  'Milk, cheese, yogurt, butter and other refrigerated dairy products.'),
  (2, 'Meat',            TRUE,  'Fresh and processed meat such as chicken, beef and pork.'),
  (3, 'Seafood',         TRUE,  'Fish, shellfish and other aquatic foods.'),
  (4, 'Vegetables',      TRUE,  'Fresh vegetables including leafy greens, roots and tubers.'),
  (5, 'Fruits',          TRUE,  'Fresh fruits such as apples, bananas and berries.'),
  (6, 'Snacks',          FALSE, 'Packaged snacks including chips, biscuits and confectionery.'),
  (7, 'Beverages',       FALSE, 'Drinks such as water, juice and soft drinks.'),
  (8, 'Frozen Food',     FALSE, 'Frozen items such as frozen vegetables, dumplings and ice cream.'),
  (9, 'Household Items', FALSE, 'Non-food household goods such as cleaning supplies and toiletries.');

-- ------------------------------------------------------------
-- storage_types
-- ------------------------------------------------------------
INSERT INTO storage_types (storage_type_id, storage_name, description) VALUES
  (1, 'FRIDGE',  'Chilled storage at refrigerator temperature (approximately 0-4 C).'),
  (2, 'FREEZER', 'Frozen storage below -18 C for long-term preservation.'),
  (3, 'PANTRY',  'Room-temperature dry storage such as kitchen cabinets or shelves.');

-- ------------------------------------------------------------
-- products
-- ------------------------------------------------------------
INSERT INTO products (product_id, category_id, product_name, barcode) VALUES
  (1,  1, 'Fresh Whole Milk',       '9555123400012'),
  (2,  1, 'Greek Yogurt Natural',   '9555123400029'),
  (3,  2, 'Chicken Breast Fillet',  '9555123400036'),
  (4,  2, 'Beef Mince',             NULL),
  (5,  3, 'Atlantic Salmon Fillet', '9555123400043'),
  (6,  3, 'Frozen Raw Shrimp',      NULL),
  (7,  4, 'Fresh Broccoli',         '9555123400050'),
  (8,  4, 'Organic Carrot',         NULL),
  (9,  5, 'Cavendish Banana',       '9555123400067'),
  (10, 5, 'Fuji Apple',             NULL),
  (11, 6, 'Potato Chips Sea Salt',  '9555123400074'),
  (12, 6, 'Butter Cookies',         NULL),
  (13, 7, 'Sparkling Water Can',    '9555123400081'),
  (14, 7, 'Orange Juice 1L',        '9555123400098'),
  (15, 8, 'Frozen Pork Dumplings',  '9555123400104'),
  (16, 8, 'Vanilla Ice Cream Tub',  NULL),
  (17, 9, 'Lemon Dish Soap',        '9555123400111'),
  (18, 9, 'Kitchen Paper Towels',   NULL);

-- ------------------------------------------------------------
-- shelf_life_rules
-- ------------------------------------------------------------
INSERT INTO shelf_life_rules (rule_id, category_id, storage_type_id, min_days, max_days, source) VALUES
  (1,  1, 1, 5,   7,   'USDA refrigerated dairy guideline'),
  (2,  1, 2, 60,  180, 'Manufacturer frozen dairy recommendation'),
  (3,  2, 1, 2,   4,   'USDA fresh meat guideline'),
  (4,  2, 2, 90,  365, 'Manufacturer frozen meat recommendation'),
  (5,  3, 1, 1,   2,   'Seafood freshness guideline'),
  (6,  3, 2, 90,  180, 'Manufacturer frozen seafood recommendation'),
  (7,  4, 1, 3,   7,   'Fresh vegetable storage guide'),
  (8,  4, 2, 180, 365, 'Frozen vegetable storage guide'),
  (9,  5, 2, 180, 365, 'Frozen fruit storage guide'),
  (10, 5, 3, 3,   7,   'Fruit ripening and shelf life guide'),
  (11, 6, 3, 180, 365, 'Packaged snack best-before guide'),
  (12, 7, 3, 365, 730, 'Beverage shelf life guide'),
  (13, 8, 2, 90,  365, 'Frozen food manufacturer guidance'),
  (14, 9, 3, 365, 1095,'Household product durability guide');

-- ------------------------------------------------------------
-- inventory_items
-- ------------------------------------------------------------
INSERT INTO inventory_items
  (inventory_item_id, team_id, product_id, storage_type_id, created_by, quantity,
   production_date, purchase_date, entry_date, shelf_life_days, expiry_date,
   expiry_date_source, checkout_date, status)
VALUES
  (1,  1, 1,  1, 1, 2.00, NULL, DATE_SUB(CURDATE(), INTERVAL 3 DAY),  DATE_SUB(NOW(), INTERVAL 3 DAY),  7,   DATE_ADD(CURDATE(), INTERVAL 4 DAY),    'PACKAGING',  NULL,                            'IN_STOCK'),
  (2,  1, 3,  1, 2, 1.50, DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY),  4,   DATE_ADD(CURDATE(), INTERVAL 3 DAY),    'CALCULATED', NULL,                            'IN_STOCK'),
  (3,  1, 5,  1, 1, 1.00, DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY),  2,   DATE_ADD(CURDATE(), INTERVAL 1 DAY),    'CALCULATED', NULL,                            'IN_STOCK'),
  (4,  1, 7,  1, 1, 3.00, DATE_SUB(CURDATE(), INTERVAL 2 DAY), DATE_SUB(CURDATE(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY),  5,   DATE_ADD(CURDATE(), INTERVAL 3 DAY),    'CALCULATED', NULL,                            'IN_STOCK'),
  (5,  1, 13, 3, 2, 12.00, NULL, DATE_SUB(CURDATE(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 10 DAY), 730, DATE_ADD(CURDATE(), INTERVAL 400 DAY), 'PACKAGING', NULL,                            'IN_STOCK'),
  (6,  1, 15, 2, 2, 4.00, NULL, DATE_SUB(CURDATE(), INTERVAL 30 DAY), DATE_SUB(NOW(), INTERVAL 30 DAY), 180, DATE_ADD(CURDATE(), INTERVAL 120 DAY), 'PACKAGING', NULL,                            'IN_STOCK'),
  (7,  1, 2,  1, 1, 1.00, NULL, DATE_SUB(CURDATE(), INTERVAL 8 DAY),  DATE_SUB(NOW(), INTERVAL 8 DAY),  21,  DATE_SUB(CURDATE(), INTERVAL 2 DAY),   'PACKAGING',  DATE_SUB(NOW(), INTERVAL 1 DAY), 'EXPIRED'),
  (8,  1, 9,  3, 1, 6.00, NULL, DATE_SUB(CURDATE(), INTERVAL 2 DAY),  DATE_SUB(NOW(), INTERVAL 2 DAY),  NULL, DATE_ADD(CURDATE(), INTERVAL 2 DAY),   'USER_INPUT', NULL,                            'IN_STOCK'),
  (9,  1, 11, 3, 2, 2.00, NULL, DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_SUB(NOW(), INTERVAL 20 DAY), 365, DATE_ADD(CURDATE(), INTERVAL 100 DAY), 'PACKAGING',  DATE_SUB(NOW(), INTERVAL 10 DAY), 'CONSUMED'),
  (10, 1, 17, 3, 1, 1.00, NULL, DATE_SUB(CURDATE(), INTERVAL 60 DAY), DATE_SUB(NOW(), INTERVAL 60 DAY), 730, DATE_ADD(CURDATE(), INTERVAL 300 DAY), 'PACKAGING',  DATE_SUB(NOW(), INTERVAL 5 DAY),  'DISCARDED'),
  (11, 2, 4,  1, 3, 2.00, DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(CURDATE(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY),  3,   DATE_ADD(CURDATE(), INTERVAL 2 DAY),    'CALCULATED', NULL,                            'IN_STOCK'),
  (12, 2, 6,  2, 3, 3.00, NULL, DATE_SUB(CURDATE(), INTERVAL 40 DAY), DATE_SUB(NOW(), INTERVAL 40 DAY), 365, DATE_ADD(CURDATE(), INTERVAL 200 DAY), 'PACKAGING', NULL,                            'IN_STOCK'),
  (13, 2, 16, 2, 3, 1.00, NULL, DATE_SUB(CURDATE(), INTERVAL 7 DAY),  DATE_SUB(NOW(), INTERVAL 7 DAY),  365, DATE_ADD(CURDATE(), INTERVAL 60 DAY),  'PACKAGING', NULL,                            'IN_STOCK'),
  (14, 2, 12, 3, 2, 5.00, NULL, DATE_SUB(CURDATE(), INTERVAL 15 DAY), DATE_SUB(NOW(), INTERVAL 15 DAY), 365, DATE_ADD(CURDATE(), INTERVAL 30 DAY),  'PACKAGING', NULL,                            'IN_STOCK'),
  (15, 2, 8,  1, 3, 2.00, DATE_SUB(CURDATE(), INTERVAL 3 DAY), DATE_SUB(CURDATE(), INTERVAL 3 DAY), DATE_SUB(NOW(), INTERVAL 3 DAY),  7,   DATE_ADD(CURDATE(), INTERVAL 4 DAY),    'CALCULATED', DATE_SUB(NOW(), INTERVAL 3 DAY), 'CONSUMED'),
  (16, 2, 10, 3, 3, 4.00, NULL, DATE_SUB(CURDATE(), INTERVAL 5 DAY),  DATE_SUB(NOW(), INTERVAL 5 DAY),  NULL, DATE_SUB(CURDATE(), INTERVAL 1 DAY),  'USER_INPUT', DATE_SUB(NOW(), INTERVAL 1 DAY), 'DISCARDED'),
  (17, 2, 14, 1, 3, 2.00, NULL, DATE_SUB(CURDATE(), INTERVAL 3 DAY),  DATE_SUB(NOW(), INTERVAL 3 DAY),  14,  DATE_ADD(CURDATE(), INTERVAL 6 DAY),   'PACKAGING', NULL,                            'IN_STOCK');

-- ------------------------------------------------------------
-- inventory_transactions
-- ------------------------------------------------------------
INSERT INTO inventory_transactions
  (transaction_id, inventory_item_id, user_id, transaction_type, quantity, transaction_time, note, discard_reason)
VALUES
  (1,  1,  1, 'ADD',     2.00, DATE_SUB(NOW(), INTERVAL 3 DAY),  'Initial stock entry', NULL),
  (2,  2,  2, 'ADD',     1.50, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Initial stock entry', NULL),
  (3,  3,  1, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Initial stock entry', NULL),
  (4,  4,  1, 'ADD',     3.00, DATE_SUB(NOW(), INTERVAL 2 DAY),  'Initial stock entry', NULL),
  (5,  5,  2, 'ADD',    12.00, DATE_SUB(NOW(), INTERVAL 10 DAY), 'Initial stock entry', NULL),
  (6,  6,  2, 'ADD',     4.00, DATE_SUB(NOW(), INTERVAL 30 DAY), 'Initial stock entry', NULL),
  (7,  7,  1, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 8 DAY),  'Initial stock entry', NULL),
  (8,  8,  1, 'ADD',     6.00, DATE_SUB(NOW(), INTERVAL 2 DAY),  'Initial stock entry', NULL),
  (9,  9,  2, 'ADD',     2.00, DATE_SUB(NOW(), INTERVAL 20 DAY), 'Initial stock entry', NULL),
  (10, 9,  1, 'CONSUME', 2.00, DATE_SUB(NOW(), INTERVAL 10 DAY), 'Finished during the week', NULL),
  (11, 10, 1, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 60 DAY), 'Initial stock entry', NULL),
  (12, 10, 1, 'DISCARD', 1.00, DATE_SUB(NOW(), INTERVAL 5 DAY),  'Cleaning product no longer needed', 'USER_DISCARDED'),
  (13, 11, 3, 'ADD',     2.00, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Initial stock entry', NULL),
  (14, 12, 3, 'ADD',     3.00, DATE_SUB(NOW(), INTERVAL 40 DAY), 'Initial stock entry', NULL),
  (15, 13, 3, 'ADD',     1.00, DATE_SUB(NOW(), INTERVAL 7 DAY),  'Initial stock entry', NULL),
  (16, 14, 2, 'ADD',     5.00, DATE_SUB(NOW(), INTERVAL 15 DAY), 'Initial stock entry', NULL),
  (17, 15, 3, 'ADD',     2.00, DATE_SUB(NOW(), INTERVAL 3 DAY),  'Initial stock entry', NULL),
  (18, 15, 3, 'CONSUME', 2.00, DATE_SUB(NOW(), INTERVAL 3 DAY),  'Used in dinner recipes', NULL),
  (19, 16, 3, 'ADD',     4.00, DATE_SUB(NOW(), INTERVAL 5 DAY),  'Initial stock entry', NULL),
  (20, 16, 3, 'DISCARD', 4.00, DATE_SUB(NOW(), INTERVAL 1 DAY),  'Found expired when checking the pantry', 'EXPIRED'),
  (21, 17, 3, 'ADD',     2.00, DATE_SUB(NOW(), INTERVAL 3 DAY),  'Initial stock entry', NULL);

-- ------------------------------------------------------------
-- reminders
-- ------------------------------------------------------------
INSERT INTO reminders
  (reminder_id, inventory_item_id, team_id, created_by, lead_time_days, reminder_at, status, created_at, cancelled_at)
VALUES
  (1, 3,  1, 1, 1, DATE_ADD(CURDATE(), INTERVAL 9 HOUR),                              'PENDING',   NOW(), NULL),
  (2, 2,  1, 2, 3, DATE_ADD(CURDATE(), INTERVAL 9 HOUR),                              'PENDING',   NOW(), NULL),
  (3, 8,  1, 1, 2, DATE_ADD(CURDATE(), INTERVAL 9 HOUR),                              'PENDING',   NOW(), NULL),
  (4, 11, 2, 3, 2, DATE_ADD(CURDATE(), INTERVAL 9 HOUR),                              'PENDING',   NOW(), NULL),
  (5, 17, 2, 3, 5, DATE_ADD(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 9 HOUR),    'PENDING',   NOW(), NULL),
  (6, 3,  1, 2, 1, DATE_SUB(CURDATE(), INTERVAL 1 DAY),                               'TRIGGERED', DATE_SUB(NOW(), INTERVAL 2 DAY), NULL),
  (7, 7,  1, 1, 3, DATE_SUB(CURDATE(), INTERVAL 5 DAY),                               'CANCELLED', DATE_SUB(NOW(), INTERVAL 8 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY));

-- ------------------------------------------------------------
-- notification_recipients
-- ------------------------------------------------------------
INSERT INTO notification_recipients (reminder_id, user_id, is_read, read_at) VALUES
  (1, 1, TRUE,  DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (1, 2, FALSE, NULL),
  (2, 1, FALSE, NULL),
  (2, 2, FALSE, NULL),
  (3, 1, FALSE, NULL),
  (3, 2, TRUE,  DATE_SUB(NOW(), INTERVAL 2 HOUR)),
  (4, 3, FALSE, NULL),
  (4, 2, FALSE, NULL),
  (5, 3, TRUE,  DATE_SUB(NOW(), INTERVAL 1 HOUR)),
  (5, 2, FALSE, NULL),
  (6, 1, FALSE, NULL),
  (7, 1, TRUE,  DATE_SUB(NOW(), INTERVAL 4 DAY));
