# Pantry Buddy combined database delivery

This package is generated strictly for the supplied MySQL 8.0 `pantry_buddy` schema. No new table is introduced.

## Recommended setup

1. Run `schema.sql` on MySQL 8.0+. It recreates the 12-table database, so use it only for a new or disposable database.
2. Run `seed_data.sql` immediately afterwards.
3. Run `validate_seed.sql`; the duplicate, foreign-key and invalid-range checks should return no rows.

Do not load the old sample products first. This delivery uses formal product IDs 1–200.

## CSV files and import order

The `csv` folder contains exactly four table-import CSV files:

1. `product_categories.csv` → `product_categories`
2. `storage_types.csv` → `storage_types`
3. `products.csv` → `products`
4. `shelf_life_rules.csv` → `shelf_life_rules`

Their headers, field counts and field order match every column in the supplied schema. `created_at` and `updated_at` are included because they are real schema columns. `documentation/SOURCE_LINK_AUDIT.csv` is evidence documentation only and must not be imported into MySQL.

Empty cells in nullable CSV columns (`barcode`, category-fallback `product_id`, unavailable `recommended_days`, and optional evidence fields) must be imported as SQL `NULL`, not as an empty string or zero. The supplied `seed_data.sql` already handles all of these NULL values correctly and is therefore the recommended import method.

## Data included

- 18 product categories and 3 storage types.
- 200 fresh products: 50 Fruits (IDs 1–50), 50 Seafood (51–100), 50 Vegetables (101–150), and 50 Meat (151–200).
- 600 product-level shelf-life rules: one PANTRY, FRIDGE and FREEZER rule per product.
- 12 category fallbacks: three storage conditions for Meat, Seafood, Vegetables and Fruits.
- 612 shelf-life rules in total.

Blank `product_id` is intentional only for the 12 category fallback rows. All 600 product-specific rows have a valid `product_id`.

All numeric durations are stored as days. For `QUALITATIVE_ONLY` and `NOT_RECOMMENDED`, the schema requires non-NULL integer fields, so `min_days` and `max_days` use 0/0. The application must check `rule_status` before calculating an expiry date.

Lookup precedence:

`PACKAGING/USER_INPUT expiry date > product_id + storage_type_id rule > category fallback`

## Evidence

Every rule has `source_name`, `source_url` and `source_locator`. Exact product/table evidence is distinguished from category guidance, different-temperature evidence and institution-level matches through `evidence_classification` and `confidence`.

Some supplied meat/vegetable records named only an organisation or guide and did not provide a publication edition, page or table. Public tables and product fact sheets were located wherever possible. Remaining institution-level matches are explicitly marked `LOW` and `INSTITUTIONAL_GUIDANCE_LIMITED`; those links are traceability evidence and must not be described as proving the exact numeric value.

See `documentation/SOURCE_LINK_AUDIT.csv` and `VALIDATION_REPORT.txt` for the evidence and validation summaries.
