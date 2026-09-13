# PantryBuddy Iteration 2 Price Mapping Handover

## What is included

This handover contains one prepared data file:

- `pantrybuddy_price_mapping_data.csv`

It contains all 284 PriceCatcher items that have price observations in the supplied September 2026 data. Every item has been mapped to one of the fixed PantryBuddy category IDs.

The original `food_price.csv` remains the source of the 561,441 dated, premise-level price observations and is not duplicated in this folder.

## Data source

- Malaysia PriceCatcher item lookup: https://storage.data.gov.my/pricecatcher/lookup_item.csv
- September 2026 prices: https://storage.data.gov.my/pricecatcher/pricecatcher_2026-09.csv
- Official catalogue: https://open.dosm.gov.my/data-catalogue/pricecatcher
- Licence: CC BY 4.0
- Currency: MYR

## How to use the CSV

The CSV is one master staging file. It does not represent one database table. Hank can use its columns to update the existing recognition tables and populate the new price tables.

### Step 1: update the existing `product_reference` table

Group the CSV by `reference_key`. For rows marked `NEW_REFERENCE_REQUIRED`, insert one product reference per unique `reference_key` using:

- `pantrybuddy_category_id` -> `category_id`
- `canonical_product_name` -> `product_name`
- `reference_key` -> temporary import key used to retrieve the generated `reference_id`

Do not insert a second reference for rows marked `EXISTING_REFERENCE`.

Several PriceCatcher item codes may share one product reference because they represent different package sizes of the same product.

### Step 2: update the existing `product_keyword_mapping` table

Use each distinct combination of `reference_key` and `source_item_name`:

- `source_item_name` -> `keyword`
- lowercase letters/numbers with punctuation replaced by spaces -> `normalized_keyword`
- resolve `reference_key` to `product_reference.reference_id`
- source name -> `Malaysia PriceCatcher Item Lookup`
- source URL -> value in `lookup_source_url`
- source locator -> `item_code=<item_code>`

Check the unique key before insertion and skip an identical keyword that already exists for the same reference.

### Step 3: create and populate `price_item_reference`

Create one row for every `item_code`. This table connects a PriceCatcher item and package unit to PantryBuddy:

```sql
CREATE TABLE price_item_reference (
    item_code INT UNSIGNED PRIMARY KEY,
    reference_id BIGINT UNSIGNED NOT NULL,
    source_item_name VARCHAR(255) NOT NULL,
    source_unit VARCHAR(50) NOT NULL,
    source_item_group VARCHAR(100) NULL,
    source_item_category VARCHAR(100) NULL,
    package_quantity_in_base_unit DECIMAL(12,4) NULL,
    base_unit ENUM('KG', 'L', 'PIECE', 'UNSUPPORTED') NOT NULL,
    median_package_price DECIMAL(10,2) NULL,
    mean_package_price DECIMAL(10,2) NULL,
    minimum_package_price DECIMAL(10,2) NULL,
    maximum_package_price DECIMAL(10,2) NULL,
    latest_day_median_price DECIMAL(10,2) NULL,
    median_price_per_base_unit DECIMAL(12,4) NULL,
    price_observation_count INT UNSIGNED NOT NULL,
    latest_observation_date DATE NULL,
    source_url VARCHAR(500) NOT NULL,
    CONSTRAINT fk_price_item_reference_product
        FOREIGN KEY (reference_id)
        REFERENCES product_reference(reference_id)
        ON DELETE RESTRICT
);
```

Populate it using the matching columns in `pantrybuddy_price_mapping_data.csv`. Resolve `reference_key` to the generated or existing `reference_id` first.

### Step 4: create and populate `price_observations`

Use the original `food_price.csv`:

```sql
CREATE TABLE price_observations (
    observation_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    observation_date DATE NOT NULL,
    premise_code INT UNSIGNED NOT NULL,
    item_code INT UNSIGNED NOT NULL,
    price_myr DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (observation_id),
    UNIQUE KEY uq_price_observation
        (observation_date, premise_code, item_code),
    KEY idx_price_item_date (item_code, observation_date),
    CONSTRAINT fk_price_observation_item
        FOREIGN KEY (item_code)
        REFERENCES price_item_reference(item_code)
        ON DELETE RESTRICT,
    CONSTRAINT chk_price_positive CHECK (price_myr > 0)
);
```

Import field mapping:

- `date` -> `observation_date`
- `premise_code` -> `premise_code`
- `item_code` -> `item_code`
- `price` -> `price_myr`

## Database relationship

```text
product_categories
        |
product_reference
        |-------------------------------|
product_keyword_mapping       price_item_reference
                                      |
                              price_observations
```

The first two tables already exist. Only `price_item_reference` and `price_observations` are new.

## Price selection

Recommended backend order:

1. Use the user's actual purchase price when provided.
2. Otherwise use `median_package_price` when the item and package unit match.
3. Use `median_price_per_base_unit` only when the user's quantity uses the same compatible base unit.
4. If no compatible public price exists, ask the user to enter a price.

Both median and mean are supplied. The median is recommended because it is less affected by unusually high or low premise prices.

## Fixed category rule

Keep all existing PantryBuddy category IDs unchanged. IDs 9 and 10 do not exist. The 284 current priced items naturally cover 12 of the 16 PantryBuddy categories. They do not include priced items for Snacks, Frozen Food, Vegetarian Proteins or Deli & Prepared Foods.

## Validation

- Mapped priced items: 284 of 284
- Invalid category IDs: 0
- Duplicate item codes: 0
- Blank source URLs: 0
- Unconvertible units: 0
- Original price observations: 561,441
- Duplicate `(date, premise_code, item_code)` records: 0

