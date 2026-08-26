# Household Inventory Reminder System - MySQL Database

This folder contains the complete MySQL implementation for the Household Inventory Reminder System. It defines a 12-table relational schema for managing households/teams, memberships, join requests, products, storage locations, inventory, shelf-life rules, expiry reminders and notification recipients.

## Files

| File | Purpose |
| --- | --- |
| `schema.sql` | Creates the `pantry_buddy` database and all 12 tables with indexes, constraints and foreign keys. |
| `seed_data.sql` | Loads representative English seed data (users, teams, products, inventory, rules, reminders, recipients). |
| `test_data.sql` | Contains 32 executable test scenarios for manual verification. |
| `README.md` | This documentation. |

## Prerequisites

- MySQL 8.0 or newer (CHECK constraints are enforced from 8.0.16 onward).
- InnoDB storage engine (the default in MySQL).
- `utf8mb4` character set, which every table uses.

## Schema Overview

The schema contains exactly 12 tables and no additional summary, ML or prediction tables.

| # | Table | Purpose |
| --- | --- | --- |
| 1 | `users` | Registered users of the system. |
| 2 | `teams` | Households/teams that share inventory. |
| 3 | `team_members` | Membership of users in teams, with `ADMIN` or `MEMBER` role. |
| 4 | `join_requests` | Requests from users to join a team. |
| 5 | `product_categories` | Product categories such as Dairy, Meat, Vegetables. |
| 6 | `products` | Product catalogue; barcode is optional but unique. |
| 7 | `storage_types` | Storage locations: FRIDGE, FREEZER, PANTRY. |
| 8 | `inventory_items` | Stock entries owned by a team for a product at a storage location. |
| 9 | `inventory_transactions` | Audit trail of ADD / CONSUME / DISCARD operations. |
| 10 | `shelf_life_rules` | Suggested shelf-life ranges per category and storage type. |
| 11 | `reminders` | Expiry reminders for inventory items. |
| 12 | `notification_recipients` | Users notified for a reminder, with per-user read state. |

## Relationships

- `users` and `teams` are related many-to-many through `team_members`. A team admin is identified by `team_members.role = 'ADMIN'`; there is deliberately no `teams.created_by` column.
- `join_requests` connects `teams` and `users`; the reviewer is tracked with `reviewed_by -> users`.
- `products` belongs to exactly one `product_categories`.
- `inventory_items` belongs to one `teams`, one `products` and one `storage_types`; it is created by one `users`.
- `inventory_transactions` is the history of one `inventory_items` entry and is performed by one `users`.
- `shelf_life_rules` pairs one `product_categories` with one `storage_types` (unique pair).
- `reminders` references one `inventory_items`, one `teams` and one `users` (creator).
- `notification_recipients` connects `reminders` with `users`; each recipient has an independent read state.

## Foreign Key Delete Behavior

| Constraint | Parent | Child | On Delete |
| --- | --- | --- | --- |
| `fk_team_members_team` | `teams` | `team_members` | CASCADE |
| `fk_team_members_user` | `users` | `team_members` | CASCADE |
| `fk_join_requests_team` | `teams` | `join_requests` | CASCADE |
| `fk_join_requests_user` | `users` | `join_requests` | CASCADE |
| `fk_join_requests_reviewed_by` | `users` | `join_requests.reviewed_by` | SET NULL |
| `fk_products_category` | `product_categories` | `products` | RESTRICT |
| `fk_inventory_items_product` | `products` | `inventory_items` | RESTRICT |
| `fk_inventory_items_storage` | `storage_types` | `inventory_items` | RESTRICT |
| `fk_inventory_items_team` | `teams` | `inventory_items` | CASCADE |
| `fk_inventory_items_created_by` | `users` | `inventory_items.created_by` | RESTRICT |
| `fk_inventory_transactions_item` | `inventory_items` | `inventory_transactions` | CASCADE |
| `fk_inventory_transactions_user` | `users` | `inventory_transactions` | RESTRICT |
| `fk_shelf_life_rules_category` | `product_categories` | `shelf_life_rules` | CASCADE |
| `fk_shelf_life_rules_storage` | `storage_types` | `shelf_life_rules` | CASCADE |
| `fk_reminders_inventory_item` | `inventory_items` | `reminders` | CASCADE |
| `fk_reminders_team` | `teams` | `reminders` | CASCADE |
| `fk_reminders_created_by` | `users` | `reminders.created_by` | RESTRICT |
| `fk_notification_recipients_reminder` | `reminders` | `notification_recipients` | CASCADE |
| `fk_notification_recipients_user` | `users` | `notification_recipients` | CASCADE |

## Key Constraints and Business Rules

- `users.email` is unique (`uq_users_email`).
- `products.barcode` is unique (`uq_products_barcode`) and nullable; it is stored as `VARCHAR(50)`, never as an integer.
- `inventory_items.quantity` must be greater than 0 (`CHECK`).
- `inventory_items.shelf_life_days` must be greater than or equal to 0 when provided.
- `expiry_date_source` is one of `PACKAGING` (printed on the package), `USER_INPUT` (entered by the user) or `CALCULATED` (production date + shelf life).
- `inventory_transactions.discard_reason` may be non-NULL only when `transaction_type = 'DISCARD'`; otherwise it must be NULL.
- `shelf_life_rules.max_days` must be greater than or equal to `min_days`; each (category, storage type) pair is unique.
- `reminders.lead_time_days` defaults to 3 but supports any value greater than or equal to 0; reminders are not hard-coded to 3 days.
- Roles are `ADMIN` and `MEMBER` only; there is no OWNER role.
- Only `ADMIN` and `MEMBER` exist in `team_members.role`; no owner concept is used.
- The rule "one PENDING join request per (team, user)" is enforced by the application layer before insertion, because MySQL does not support partial unique indexes. No naive `UNIQUE(team_id, user_id, status)` constraint is added.
- No ML, prediction, model or summary tables exist in this schema.

## Seed Data

`seed_data.sql` loads representative data with English names and descriptions:

| Table | Row count | Notes |
| --- | --- | --- |
| `users` | 4 | Alice, Bob, Carol, David. |
| `teams` | 2 | Lee Family Pantry, Hacker House Kitchen. |
| `team_members` | 5 | Admins and members, both ACTIVE. |
| `join_requests` | 3 | One PENDING, one APPROVED, one DECLINED. |
| `product_categories` | 9 | Dairy, Meat, Seafood, Vegetables, Fruits, Snacks, Beverages, Frozen Food, Household Items. |
| `products` | 18 | Products across all categories, most with barcodes. |
| `storage_types` | 3 | FRIDGE, FREEZER, PANTRY. |
| `inventory_items` | 17 | Mixed statuses: IN_STOCK, CONSUMED, EXPIRED, DISCARDED. |
| `inventory_transactions` | 21 | ADD / CONSUME / DISCARD history, including an EXPIRED discard. |
| `shelf_life_rules` | 14 | Ranges per category and storage type. |
| `reminders` | 7 | Lead times of 1, 2, 3 and 5 days; PENDING, TRIGGERED and CANCELLED. |
| `notification_recipients` | 12 | Multiple recipients per reminder with independent read state. |

Expiry dates in the seed data are computed relative to `CURDATE()` so the sample data remains useful when the script is re-run at a later date.

## Initialization

Run the scripts in order from the MySQL client:

```bash
mysql -u root -p < schema.sql
mysql -u root -p < seed_data.sql
```

Both scripts contain a `USE pantry_buddy;` statement, so the database is selected automatically.

## Testing

`test_data.sql` contains 32 scenarios for manual verification. Because several blocks intentionally raise errors (duplicate email, duplicate barcode, invalid foreign keys, over-consumption rejection), run the script with `--force` so that execution does not stop at the first expected error:

```bash
mysql -u root -p --force pantry_buddy < test_data.sql
```

Alternatively, copy individual scenario blocks into a MySQL client and inspect each result set.

### Test Conventions

- Every scenario runs inside a transaction and rolls back afterwards, so the script is repeatable and leaves no test data behind.
- Consume and discard scenarios lock the target row with `SELECT ... FOR UPDATE` before updating stock, simulating concurrent-safe operations.
- Scenario 32 (clean schema recreation) is the only block without a transaction, because DDL statements cause implicit commits in MySQL. After it runs, re-import `schema.sql` and `seed_data.sql`.

### The 32 Scenarios

| # | Scenario | What it verifies |
| --- | --- | --- |
| 1 | User creation | A new user can be inserted and read back. |
| 2 | Duplicate email rejection | The unique email index rejects duplicates. |
| 3 | Team creation | A new team can be created. |
| 4 | Admin creation | A user can be added to a team as ADMIN. |
| 5 | Join request | A user can request to join a team. |
| 6 | Duplicate pending join request prevention | The application-layer guard prevents duplicate PENDING requests. |
| 7 | Approve join request | A request can be approved with reviewer information. |
| 8 | Decline join request | A request can be declined. |
| 9 | Product creation | A new product can be added. |
| 10 | Duplicate barcode rejection | The unique barcode index rejects duplicates. |
| 11 | Inventory creation | An inventory item can be added to a team. |
| 12 | Expiry source handling | PACKAGING, USER_INPUT and CALCULATED sources are all stored. |
| 13 | Static shelf-life calculation support | CALCULATED expiry equals production date + shelf life. |
| 14 | Partial consumption | Part of the stock is consumed and the quantity reduced. |
| 15 | Full consumption | The whole stock is consumed and the item marked CONSUMED. |
| 16 | Over-consumption rejection | Consuming more than available stock is rejected. |
| 17 | Discard | An item is discarded with a valid discard reason. |
| 18 | Expired discard | An expired item is discarded with reason EXPIRED. |
| 19 | User-discarded item | An item is discarded with reason USER_DISCARDED. |
| 20 | Invalid FK rejection | Inserts with non-existent parents fail. |
| 21 | Product search | Products can be searched by name. |
| 22 | Inventory filtering | Inventory can be filtered by team, status and storage. |
| 23 | Home summary queries | Aggregates per team and expiring-soon lists work. |
| 24 | Reminder creation | A reminder can be created. |
| 25 | Default 3-day reminder | lead_time_days defaults to 3. |
| 26 | Custom reminder lead time | A custom lead time such as 7 days is supported. |
| 27 | Reminder cancellation | A reminder can be cancelled with cancelled_at set. |
| 28 | Multiple notification recipients | A reminder can notify several users. |
| 29 | Independent read/unread state | Each recipient's read state is independent. |
| 30 | Foreign-key delete behavior | CASCADE, SET NULL and RESTRICT all behave as designed. |
| 31 | Seed data loading | Every table is populated by the seed script. |
| 32 | Clean schema recreation | All tables can be dropped and recreated from scratch. |

## Design Notes

- All tables use the InnoDB engine and the `utf8mb4` character set with `utf8mb4_unicode_ci` collation.
- CHECK constraints are included and are enforced by MySQL 8.0.16+.
- `barcode` is always `VARCHAR(50)`; integer barcodes are not supported by design.
- Expiry reminders support multiple lead times; 3 is only the default.
- The application layer is responsible for the duplicate-PENDING-join-request check and for rejecting over-consumption, since neither is representable as a pure database constraint here.
