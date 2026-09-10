# PantryBuddy - Household Inventory Reminder System (Iteration 2)

This folder contains the complete MySQL implementation for Iteration 2 of the PantryBuddy project. Iteration 2 keeps the 12 tables of Iteration 1 unchanged and adds `users.is_verified` plus two new tables, giving 14 tables in total.

Iteration 1 remains the read-only source of truth. Nothing inside the Iteration 1 folder is modified by these files; every file in this folder is a separate Iteration 2 artifact.

## Files

| File | Purpose |
| --- | --- |
| `schema.sql` | Full clean schema for all 14 tables (drops and recreates them). |
| `insert_static_data.sql` | Static catalogue import. **Copied unchanged from Iteration 1** (byte-for-byte identical). |
| `seed_data.sql` | Small development seed data for the operational tables. |
| `test_data.sql` | Constraint and edge-case tests for the Iteration 2 changes. |
| `README.md` | This documentation. |

## Execution Order

Run the scripts in exactly this order:

```bash
mysql -u root -p < schema.sql
mysql -u root -p "Real_ProjectV2.0_TM06" < insert_static_data.sql
mysql -u root -p < seed_data.sql
mysql -u root -p < test_data.sql          # add --force, some blocks expect errors
```

Notes on the order:

- `schema.sql` creates the `Real_ProjectV2.0_TM06` database and all 14 tables, so it must run first.
- `insert_static_data.sql` fills the catalogue tables (`storage_types`, `product_categories`, `products`, `shelf_life_rules`). It is the verbatim Iteration 1 file and contains no `USE` statement, so the database name must be passed on the command line (as shown above).
- `seed_data.sql` adds development data for the operational tables and deliberately does **not** re-insert catalogue rows, because the static import already provides them. Running it before the static import will fail on missing catalogue rows.
- `test_data.sql` only reads and temporarily inserts rows; every block rolls back. Its last block drops all tables, so re-import the previous scripts afterwards if you want the data back.

## Schema Overview (14 tables)

Iteration 1 tables (definitions preserved exactly - columns, types, defaults, enum values, indexes, unique keys, foreign keys, constraint names, InnoDB engine and utf8mb4 charset):

| # | Table | Purpose |
| --- | --- | --- |
| 1 | `users` | Registered users; Iteration 2 adds `is_verified`. |
| 2 | `teams` | Households/teams that share inventory. |
| 3 | `team_members` | Membership of users in teams (`ADMIN` / `MEMBER`). |
| 4 | `join_requests` | Requests from users to join a team. |
| 5 | `product_categories` | Product categories (Dairy, Meat, Seafood, Fruits, ...). |
| 6 | `products` | Product catalogue; barcode is optional but unique. |
| 7 | `storage_types` | Storage locations: FRIDGE, FREEZER, PANTRY. |
| 8 | `inventory_items` | Stock entries owned by a team for a product at a storage location. |
| 9 | `inventory_transactions` | Audit trail of ADD / CONSUME / DISCARD / DONATE operations. |
| 10 | `shelf_life_rules` | Shelf-life rules with evidence metadata (product-level and category-level). |
| 11 | `reminders` | Expiry reminders for inventory items. |
| 12 | `notification_recipients` | Users notified for a reminder, with per-user read state. |

Iteration 2 additions:

| # | Table | Purpose |
| --- | --- | --- |
| 13 | `security_questions` | Account recovery questions per user, with bcrypt-hashed answers. |
| 14 | `product_reference` | Reference catalogue for image/OCR product matching, optionally linked to `products`. |

## Iteration 2 Changes

### 1. `users.is_verified`

```sql
is_verified BOOLEAN NOT NULL DEFAULT FALSE
```

- New verification flag placed after `avatar_id`, so existing email/name/avatar columns keep their positions.
- Defaults to `FALSE`; existing rows of an upgraded database automatically become unverified.
- The seed data covers both `TRUE` (Alice, Carol) and `FALSE` (Bob, David).

### 2. `inventory_items.status` accepts `DONATED`

```sql
ENUM('IN_STOCK','CONSUMED','EXPIRED','DISCARDED','DONATED') NOT NULL DEFAULT 'IN_STOCK'
```

### 3. `inventory_transactions.transaction_type` accepts `DONATE`

```sql
ENUM('ADD','CONSUME','DISCARD','DONATE') NOT NULL
```

### 4. `inventory_items.discard_reason`

```sql
discard_reason VARCHAR(30) NULL   -- placed AFTER status
```

Stores why an item left stock, for example `EXPIRED`, `USER_DISCARDED` or `DONATED`.

### 5. `inventory_items.consumed_amount`

```sql
consumed_amount VARCHAR(20) NULL  -- placed AFTER discard_reason
```

Stores an optional human-readable consumed amount, for example `0.75` or `1.00`.

### 6. `inventory_items.unit` and `notes`

```sql
unit  VARCHAR(20)  NOT NULL DEFAULT 'pcs'   -- after quantity
notes VARCHAR(500) NULL                      -- after unit
```

`unit` holds the measurement unit (`pcs`, `kg`, `g`, `L`, `ml`, `dozen`); `notes` holds free-form user notes such as opened status or partial consumption. Both were already present in Iteration 1 and are kept unchanged.

### 7. `security_questions` (new)

| Column | Type | Notes |
| --- | --- | --- |
| `question_id` | `BIGINT UNSIGNED AUTO_INCREMENT` | Primary key. |
| `user_id` | `BIGINT UNSIGNED NOT NULL` | Same type as `users.user_id`; FK to `users.user_id` `ON DELETE CASCADE`. |
| `question` | `VARCHAR(255) NOT NULL` | Question text. |
| `answer_hash` | `VARCHAR(255) NOT NULL` | bcrypt hash of the answer; never store plain text. |
| `created_at` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` | Row creation time. |
| `updated_at` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | Row update time. |

Keys: `PRIMARY KEY (question_id)`, `UNIQUE (user_id, question)`, `INDEX (user_id)`.

Behaviour:

- A user may store several questions, but only one row per question text (`UNIQUE (user_id, question)`).
- The same question text may be reused by different users.
- Deleting a user deletes that user's questions (`ON DELETE CASCADE`).

### 8. `product_reference` (new)

| Column | Type | Notes |
| --- | --- | --- |
| `reference_id` | `BIGINT UNSIGNED AUTO_INCREMENT` | Primary key. |
| `product_id` | `BIGINT UNSIGNED NULL` | Same type as `products.product_id`; FK to `products.product_id` `ON DELETE RESTRICT`; `UNIQUE`. |
| `category_id` | `INT UNSIGNED NOT NULL` | Same type as `product_categories.category_id`; FK to `product_categories.category_id` `ON DELETE RESTRICT`. |
| `product_name` | `VARCHAR(255) NOT NULL` | Reference display name. |
| `barcode` | `VARCHAR(50) NULL` | `UNIQUE`; always `VARCHAR`, never an integer; store empty values as `NULL`, never as `''`. |
| `description` | `VARCHAR(500) NULL` | Optional description. |
| `is_active` | `BOOLEAN NOT NULL DEFAULT TRUE` | Soft enable/disable flag. |
| `created_at` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` | Row creation time. |
| `updated_at` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | Row update time. |

Keys: `PRIMARY KEY (reference_id)`, `UNIQUE (product_id)`, `UNIQUE (barcode)`, `UNIQUE (category_id, product_name)`, `INDEX (category_id)`, `INDEX (product_name)`.

Relationship and usage:

- `products ||--o| product_reference` is a one-to-one optional relationship through `product_id`: a catalogue product has at most one reference row, and a reference row may exist without a linked product.
- `UNIQUE (product_id)` still allows many rows with `product_id IS NULL`, because MySQL does not compare `NULL` values in a unique index. Those rows are user-added references that are not linked to the catalogue yet.
- The static import links `products` and `product_reference` through `product_id`.
- When a user picks a reference product, use `product_reference.product_id` for the new `inventory_items` row.
- When a user adds a product that is not in `product_reference`, insert only into `products` and leave `product_reference.product_id` as `NULL` (or simply do not create a reference row).

## Static Data Import

`insert_static_data.sql` is copied unchanged from Iteration 1 (`Iteration_1/insert_static_data.sql`). It is used as-is:

- 3 storage types, 16 product categories, 200 products, 612 shelf-life rules.
- No static data for `security_questions` or `product_reference` is added there.
- The 200 products and 612 shelf-life rules are not modified, reordered or regenerated.

Because the file is used verbatim, `seed_data.sql` references catalogue rows that already exist after the import (for example product 1 = Starfruit, product 12 = Mango, product 199 = Beef Striploin).

## Seed Data Summary

| Table | Rows | Coverage |
| --- | --- | --- |
| `users` | 4 | `is_verified` TRUE (users 1, 3) and FALSE (users 2, 4). |
| `teams` | 2 | Two households. |
| `team_members` | 5 | Admin and member roles. |
| `join_requests` | 3 | PENDING, APPROVED and DECLINED. |
| `security_questions` | 4 | bcrypt-like `answer_hash` values; user 1 has two questions. |
| `product_reference` | 6 | 4 rows linked to `products`, 2 rows with `product_id` NULL, 2 barcodes and 4 NULL barcodes, one inactive row. |
| `inventory_items` | 9 | IN_STOCK, EXPIRED, CONSUMED, DONATED and DISCARDED; unit, notes, discard_reason and consumed_amount all covered. |
| `inventory_transactions` | 13 | ADD, CONSUME, DISCARD and DONATE. |
| `reminders` | 4 | PENDING and CANCELLED. |
| `notification_recipients` | 8 | Independent read state per recipient. |

## Testing

`test_data.sql` contains 22 scenarios. Run it with `--force` because several blocks intentionally raise errors:

```bash
mysql -u root -p --force < test_data.sql
```

### Covered Cases

| # | Scenario | What it verifies |
| --- | --- | --- |
| 1 | `is_verified` default | Omitting the column stores `FALSE`. |
| 2 | `is_verified` TRUE | `TRUE` is stored as `1`. |
| 3 | Security question insert | Question and bcrypt-like hash are stored. |
| 4 | `UNIQUE(user_id, question)` | Duplicate question for the same user is rejected. |
| 5 | Same question, other user | The unique key is per user. |
| 6 | `ON DELETE CASCADE` | Deleting a user removes their security questions. |
| 7 | Linked reference row | `product_reference.product_id` joins to `products`. |
| 8 | `UNIQUE(product_id)` | A second reference row for the same product is rejected. |
| 9 | Multiple NULL `product_id` | Unlinked reference rows are allowed. |
| 10 | `UNIQUE(category_id, product_name)` | Duplicate name inside a category is rejected. |
| 11 | Same name, other category | The unique key is per category. |
| 12 | `UNIQUE(barcode)` | Duplicate barcode is rejected. |
| 13 | Multiple NULL barcodes | NULL barcodes are allowed, `''` is not the same as NULL. |
| 14 | `is_active` default | Defaults to `TRUE`. |
| 15 | `ON DELETE RESTRICT` (product) | Deleting a referenced product fails. |
| 16 | `ON DELETE RESTRICT` (category) | Deleting a referenced category fails. |
| 17 | `DONATED` enum | `DONATED` is accepted, invalid statuses are rejected. |
| 18 | `DONATE` enum | `DONATE` is accepted, invalid types are rejected. |
| 19 | Donation lifecycle | DONATE transaction + DONATED item; the discard_reason CHECK still holds. |
| 20 | New item columns | `unit`, `notes`, `discard_reason`, `consumed_amount` round-trip, `unit` defaults to `pcs`. |
| 21 | Static + seed loading | Row counts and coverage checks for both scripts. |
| 22 | Clean schema recreation | All 14 tables are dropped for a fresh rebuild. |

## Verification SQL

Quick checks after loading schema, static data and seed data:

```sql
-- 1. All 14 tables exist
SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = DATABASE();
-- Expected: 14

-- 2. users.is_verified exists with the right definition
SELECT column_name, column_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'is_verified';
-- Expected: tinyint(1), NO, 0

-- 3. Donation enums
SELECT column_type FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'inventory_items' AND column_name = 'status';
-- Expected: enum('IN_STOCK','CONSUMED','EXPIRED','DISCARDED','DONATED')

SELECT column_type FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'inventory_transactions' AND column_name = 'transaction_type';
-- Expected: enum('ADD','CONSUME','DISCARD','DONATE')

-- 4. product_reference keys
SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns_in_index, non_unique
FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = 'product_reference'
GROUP BY index_name, non_unique
ORDER BY index_name;

-- 5. One reference row per linked product, and unlinked rows are allowed
SELECT product_id, COUNT(*) AS rows_per_product
FROM product_reference
WHERE product_id IS NOT NULL
GROUP BY product_id
HAVING COUNT(*) > 1;
-- Expected: empty result set

SELECT COUNT(*) AS unlinked_references FROM product_reference WHERE product_id IS NULL;

-- 6. Reference products can be used for inventory rows
SELECT pr.reference_id, pr.product_name, pr.product_id, p.product_name AS catalogue_name
FROM product_reference pr
JOIN products p ON p.product_id = pr.product_id
ORDER BY pr.reference_id;

-- 7. Security questions belong to users and are hashed
SELECT sq.question_id, u.email, sq.question, LEFT(sq.answer_hash, 7) AS hash_prefix
FROM security_questions sq
JOIN users u ON u.user_id = sq.user_id
ORDER BY sq.question_id;

-- 8. Donation data is present
SELECT status, COUNT(*) FROM inventory_items GROUP BY status;
SELECT transaction_type, COUNT(*) FROM inventory_transactions GROUP BY transaction_type;
```

## MySQL 8.0 and TiDB Compatibility

- **MySQL 8.0.16+**: fully supported. `CHECK` constraints (`chk_inventory_items_quantity`, `chk_inventory_items_shelf_life_days`, `chk_inventory_transactions_quantity`, `chk_inventory_transactions_discard_reason`, `chk_shelf_life_rules_min_days`, `chk_shelf_life_rules_max_days`, `chk_reminders_lead_time_days`) are enforced. On MySQL 8.0.0-8.0.15 the script still runs, but `CHECK` clauses are parsed and ignored.
- **MySQL 5.7 or older**: not supported, because `CHECK` clauses and `utf8mb4_unicode_ci` defaults in this form are not enforced or are unavailable.
- **TiDB**: the DDL is compatible (InnoDB-style DDL, `ENUM`, `BOOLEAN`, `utf8mb4`). Keep these points in mind:
  - `CHECK` constraints are parsed but not enforced on TiDB, so the quantity, shelf-life, discard-reason and lead-time rules must also be validated in the application.
  - Foreign key enforcement depends on the TiDB version and configuration: TiDB versions before v6.6 ignore foreign keys, and `FOREIGN_KEY_CHECKS` behaves differently from MySQL. Verify `RESTRICT` / `CASCADE` behaviour in your target cluster.
  - TiDB handles `UNIQUE` indexes with `NULL` values the same way MySQL does: many `NULL` rows are allowed, which is what this schema relies on for `product_reference.product_id`, `product_reference.barcode` and `shelf_life_rules.product_id`.
  - `AUTO_INCREMENT` values are not guaranteed to be gap-free or strictly sequential on TiDB.

## Notes

- Iteration 2 does not add any ML, prediction or model-related tables.
- Iteration 2 uses the database name `Real_ProjectV2.0_TM06`, while Iteration 1 keeps `Real_ProjectV1.0_TM06`, so both iterations can be loaded side by side without overwriting each other.
- `insert_static_data.sql` has no `USE` statement (it is byte-for-byte identical to the Iteration 1 file), so always pass the Iteration 2 database name on the command line when importing it.
- `schema.sql` ends with migration notes for backend teams: the Iteration 1 upgrade notes plus an Iteration 2 note (`ALTER TABLE users ADD COLUMN is_verified ...` and the `CREATE TABLE` statements for the two new tables).
- The application layer is responsible for converting empty barcodes to `NULL`, keeping security answers hashed, and rejecting duplicate PENDING join requests, since these rules cannot be expressed as pure database constraints here.
