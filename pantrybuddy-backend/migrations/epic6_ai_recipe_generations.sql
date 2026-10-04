-- =====================================================================
-- Epic 6 — AI recipe ideas (Gemini) shown alongside the recipe dataset.
-- ADDITIVE ONLY: one new table, CREATE TABLE IF NOT EXISTS. No existing
-- table is altered. Run against the Iteration 3 database (after the data
-- team's schema.sql / insert_static_data.sql).
--
-- Gemini's recipes themselves are stored in the existing recipes /
-- recipe_ingredients tables (is_active = FALSE, source_name starting
-- 'Gemini (AI-generated)'), so recipe_cook_sessions can record them like
-- any other recipe. This table only remembers which AI recipes were
-- generated for which household and when, so Gemini isn't called on
-- every page open (free-tier limits).
-- =====================================================================
CREATE TABLE IF NOT EXISTS recipe_ai_generations (
  generation_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  team_id         BIGINT UNSIGNED NOT NULL,
  model           VARCHAR(100)    NOT NULL,
  input_item_ids  JSON            NOT NULL,   -- inventory items offered to Gemini
  recipe_ids      JSON            NOT NULL,   -- recipes.recipe_id values saved from the reply
  created_by      BIGINT UNSIGNED NOT NULL,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (generation_id),
  KEY idx_recipe_ai_generations_team_created (team_id, created_at),
  CONSTRAINT fk_recipe_ai_generations_team FOREIGN KEY (team_id)
    REFERENCES teams (team_id) ON DELETE CASCADE,
  CONSTRAINT fk_recipe_ai_generations_user FOREIGN KEY (created_by)
    REFERENCES users (user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
