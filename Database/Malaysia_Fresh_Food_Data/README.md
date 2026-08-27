# Database import package

This package contains the five CSV files needed to implement fresh-food expiry lookup.

## Files

1. `1_storage_types.csv` maps to the existing `storage_types` table.
2. `2_product_categories.csv` maps to the existing `product_categories` table. Existing category IDs 1-9 are preserved. Fruits use category 5 and Seafood uses category 3.
3. `3_shelf_life_rules.csv` maps to the existing category-level `shelf_life_rules` table. These records are fallbacks used when image recognition cannot identify one of the 100 catalogue products. Packaged-category `0/0` records are application sentinels and are ignored when an OCR/user expiry date exists. The Seafood + PANTRY `0/0` record means room-temperature storage is not recommended; FDA permits no more than two hours at 25-30 C.
4. `4_products.csv` contains 50 fruits followed by 50 seafood products and maps to the existing `products` columns. Production IDs run from 1 to 100; delete/replace the temporary test products before import.
5. `5_product_shelf_life_rules.csv` contains 300 product-specific rules. This requires a new product-level rule table because the existing `shelf_life_rules` table has `category_id` but no `product_id`.

## Required lookup precedence

1. If `expiry_date_source` is `PACKAGING` or `USER_INPUT`, use the OCR-recognized/user-entered expiry date and do not query fresh-food rules.
2. If image recognition matches a row in `products`, query the product-specific table by `product_id + storage_type_id`.
3. If recognition returns only Fruits or Seafood, query `shelf_life_rules` by `category_id + storage_type_id`.

In compact form:

`PACKAGING/USER_INPUT date > matched product rule > category fallback rule`

## Product-level rule behavior

- Use `recommended_days` for the single suggested duration displayed by the current frontend.
- Keep `min_value`, `max_value`, and `duration_unit` for the evidence-backed range.
- `AVAILABLE`: a numeric recommendation is available.
- `QUALITATIVE_ONLY`: the source says something such as "until ripe" without a defensible number; use the category fallback if the UI requires a numeric date.
- `NOT_RECOMMENDED`: show a warning rather than an endorsed expiry date.
- Every product rule includes `source_name`, `source_url`, and `source_locator`.

## Important schema note

Do not force product-specific data into the existing category-level table. Add a product-level rule table with `product_id` as a foreign key. The existing table remains the fallback table. The source CSV also contains status, unit, confidence, evidence classification, and provenance fields; retain these fields in the new table so hour-based safety limits and non-numeric guidance are not lost.

