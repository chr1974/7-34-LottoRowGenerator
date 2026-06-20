-- =====================================================================
-- Historical prize amounts per tier, per draw.
--
-- Why a separate table instead of more columns on lotto_draws: each
-- draw has 5 prize tiers, and each tier has its OWN amount and winner
-- count - that's a one-to-many relationship (1 draw -> 5 tier rows),
-- which normalizes far more cleanly as its own table than as 10 extra
-- columns (5 amounts + 5 winner counts) bolted onto lotto_draws.
--
-- IMPORTANT: unlike the fixed mathematical odds, prize AMOUNTS are
-- pari-mutuel - within each tier, the prize pool for that tier is
-- split equally among however many rows won that tier that week.
-- So the krone amount for "5 correct" varies draw to draw depending
-- on total ticket sales and how many other players also got 5 correct
-- that week. Tiers 4 and 5 are usually near-fixed in practice because
-- so many people win them each week that the pool rarely swings much,
-- but 1st-3rd tier amounts can vary a lot, especially after a rollover.
-- =====================================================================

CREATE TABLE IF NOT EXISTS lotto_prize_tiers (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    draw_id         INT UNSIGNED NOT NULL,

    tier            TINYINT UNSIGNED NOT NULL,   -- 1 = jackpot (7 correct) ... 5 = 4 correct
    tier_label      VARCHAR(20) NOT NULL,         -- '7', '6+bonus', '6', '5', '4' - matches your table

    winner_count    INT UNSIGNED NOT NULL DEFAULT 0,  -- how many winning rows existed nationally this tier, this draw
    prize_per_winner_nok DECIMAL(14,2) NULL,       -- amount each individual winning row received (NULL if winner_count = 0, since there's nothing to divide)
    total_pool_nok       DECIMAL(14,2) NULL,       -- winner_count * prize_per_winner_nok, stored for convenience/sanity-checking against source data

    FOREIGN KEY (draw_id) REFERENCES lotto_draws(id) ON DELETE CASCADE,
    UNIQUE KEY uq_draw_tier (draw_id, tier)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

-- ---------------------------------------------------------------------
-- Example insert for one draw's full prize breakdown (5 rows per draw).
-- Replace draw_id with the actual id from lotto_draws after inserting
-- that week's winning numbers.
-- ---------------------------------------------------------------------
-- INSERT INTO lotto_prize_tiers (draw_id, tier, tier_label, winner_count, prize_per_winner_nok, total_pool_nok) VALUES
-- (1, 1, '7',        0,   NULL,       0),          -- nobody hit jackpot -> rolls over
-- (1, 2, '6+bonus',  2,   125000.00,  250000.00),
-- (1, 3, '6',        14,  8500.00,    119000.00),
-- (1, 4, '5',         410, 700.00,    287000.00),
-- (1, 5, '4',         6200, 50.00,    310000.00);

-- ---------------------------------------------------------------------
-- Handy view: join draws + prize tiers for easy reading, one row per
-- draw with all 5 tiers' amounts as columns (pivoted), similar shape
-- to Norsk Tipping's own results page.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW lotto_draws_with_prizes AS
SELECT
    d.draw_date,
    d.n1, d.n2, d.n3, d.n4, d.n5, d.n6, d.n7, d.bonus_number,
    d.jackpot_amount_nok,
    d.was_rollover,
    MAX(CASE WHEN pt.tier = 1 THEN pt.winner_count END) AS tier1_winners,
    MAX(CASE WHEN pt.tier = 1 THEN pt.prize_per_winner_nok END) AS tier1_prize,
    MAX(CASE WHEN pt.tier = 2 THEN pt.winner_count END) AS tier2_winners,
    MAX(CASE WHEN pt.tier = 2 THEN pt.prize_per_winner_nok END) AS tier2_prize,
    MAX(CASE WHEN pt.tier = 3 THEN pt.winner_count END) AS tier3_winners,
    MAX(CASE WHEN pt.tier = 3 THEN pt.prize_per_winner_nok END) AS tier3_prize,
    MAX(CASE WHEN pt.tier = 4 THEN pt.winner_count END) AS tier4_winners,
    MAX(CASE WHEN pt.tier = 4 THEN pt.prize_per_winner_nok END) AS tier4_prize,
    MAX(CASE WHEN pt.tier = 5 THEN pt.winner_count END) AS tier5_winners,
    MAX(CASE WHEN pt.tier = 5 THEN pt.prize_per_winner_nok END) AS tier5_prize
FROM lotto_draws d
LEFT JOIN lotto_prize_tiers pt ON pt.draw_id = d.id
GROUP BY d.id, d.draw_date, d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7,d.bonus_number,
         d.jackpot_amount_nok, d.was_rollover
ORDER BY d.draw_date DESC;

-- Usage: SELECT * FROM lotto_draws_with_prizes;

-- ---------------------------------------------------------------------
-- Track how a specific tier's typical payout has moved over time
-- (useful once you have many weeks of data loaded).
-- ---------------------------------------------------------------------
-- SELECT
--     d.draw_date,
--     pt.tier_label,
--     pt.winner_count,
--     pt.prize_per_winner_nok
-- FROM lotto_prize_tiers pt
-- JOIN lotto_draws d ON d.id = pt.draw_id
-- WHERE pt.tier_label = '5'
-- ORDER BY d.draw_date;
