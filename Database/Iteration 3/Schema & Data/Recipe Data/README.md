# Recipe Dataset: Verified Image Links

This package contains three files: `recipes.csv`, `recipe_ingredients.csv`, and `README.md`.

- Recipes: 7,258
- Ingredient rows: 59,518
- Cuisine groups: 1,665 Asian recipes and 5,593 Western recipes
- Image validation date: 2026-10-03

All qualifying candidates were considered. No fixed recipe-count limit was applied to this release.

## Image validation and display

Every retained image URL passed an HTTPS GET request, full image decoding, and a cross-origin HTML `img` loading test in a fresh Chrome browser environment. Natural image width and height were each at least 100 pixels. The tests did not use a user's login profile.

The frontend can use `image_url` directly as an `img` element's `src`; users do not need to open the link themselves. Spaces and other characters were URL-encoded where necessary without changing the image source. Image files are not included; the database stores URLs only.

The deployed application must allow the image domains in its Content Security Policy (`img-src`) and provide a fallback image when loading fails. External images may change or disappear. These tests do not guarantee permanent availability or cover every browser and deployment configuration. Images were not individually reviewed to confirm the depicted dish, and successful validation does not grant image usage rights.

## Integration with the existing Iteration 3 schema

- Import `recipes.csv` into the existing `recipes` table.
- Import `recipe_ingredients.csv` into the existing `recipe_ingredients` table.
- Join the tables using `recipe_id`.
- Both CSV files use UTF-8 with a BOM. Import empty cells as SQL `NULL`.
- Import recipes before their ingredient rows. No new tables are required.

Before importing, check `reference_id` and `category_id` against the target database and check for existing ID conflicts. Do not rerun the original `schema.sql` on an existing database: it drops existing tables.

If an earlier delivery has already been imported, this package is a filtered replacement, not an additional batch to append blindly. Reconcile the differences and preserve user cooking history before applying changes.

ID rules remain consistent with the previous release. Apart from standard URL encoding of `image_url`, recipe and ingredient values come from the same cleaning pipeline. This release was checked for unique IDs, parent-child relationships, JSON validity, and preservation of field values. It has not been imported into the team's live database.

## Display and missing-value rules

Preparation time, cooking time, and total time are separate source fields. Do not treat a missing time as zero or label preparation time as total time. Recipes are not excluded solely because one time field is missing. Time values have not been manually checked against the instructions for every recipe.

Ingredient amounts such as 'to taste', ranges, and alternatives are retained in `notes`; `quantity` may be `NULL`. A missing `reference_id` means the ingredient has not been matched to a reference record, not that the user lacks the ingredient. Some reference records have no `product_id`, so complete automatic inventory matching is not available for every ingredient.

## Sources and usage conditions

Each recipe retains `source_name` and `source_url` for traceability. Source-page HTTP status was not individually checked in this validation run.

Primary source: [Food.com Recipes and Reviews](https://www.kaggle.com/datasets/irkaal/foodcom-recipes-and-reviews).

Complete ingredient text was supplemented from RecipeNLG only when source recipe IDs, titles, all instruction steps, and individual quantities agreed.

Original RecipeNLG terms: [RecipeNLG dataset card](https://huggingface.co/datasets/mbien/recipe_nlg).

The combined dataset is managed for noncommercial teaching and research. Do not treat the entire package as CC0 or assume commercial image usage rights have been obtained.

Detailed image-validation evidence, exclusion results, and data management plan records are retained separately by the data maintainer in `audit/image_verified`; they are not additional SQL handover files.
