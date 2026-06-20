-- =====================================================================
-- Historical Lotto draw results (actual Norsk Tipping outcomes).
--
-- This is intentionally a SEPARATE table from lotto_combinations:
--   - lotto_combinations = every mathematically possible row (5,379,616
--     rows, static, generated once).
--   - lotto_draws = real-world historical results (one row per Saturday
--     draw, grows by exactly 1 row per week, populated from actual data).
--
-- Norsk Tipping draws 7 main numbers (1-34) plus 1 separate bonus
-- number ("tilleggstall") from the 27 numbers that did NOT come up
-- as a main number. Draws happen every Saturday, play closes 18:00,
-- results published 20:00.
-- =====================================================================

CREATE TABLE IF NOT EXISTS lotto_draws (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    draw_date    DATE NOT NULL,              -- the Saturday of the draw
    draw_number  INT UNSIGNED NULL,          -- Norsk Tipping's own draw/round number, if you want to track it (optional - leave NULL if unknown)

    n1           TINYINT UNSIGNED NOT NULL,  -- 7 main winning numbers, ascending
    n2           TINYINT UNSIGNED NOT NULL,
    n3           TINYINT UNSIGNED NOT NULL,
    n4           TINYINT UNSIGNED NOT NULL,
    n5           TINYINT UNSIGNED NOT NULL,
    n6           TINYINT UNSIGNED NOT NULL,
    n7           TINYINT UNSIGNED NOT NULL,

    bonus_number TINYINT UNSIGNED NOT NULL,  -- tilleggstall, drawn separately from the 27 non-winning numbers

    -- Same derived statistics as lotto_combinations, computed the same
    -- way, so historical draws can be compared apples-to-apples against
    -- the theoretical distribution (e.g. "is the real-world odd_count
    -- distribution actually close to the predicted 30.08% at 3-4 split?").
    row_sum            SMALLINT UNSIGNED
        GENERATED ALWAYS AS (n1+n2+n3+n4+n5+n6+n7) STORED,
    odd_count          TINYINT UNSIGNED
        GENERATED ALWAYS AS ((n1%2)+(n2%2)+(n3%2)+(n4%2)+(n5%2)+(n6%2)+(n7%2)) STORED,
    spread             TINYINT UNSIGNED
        GENERATED ALWAYS AS (n7-n1) STORED,
    consecutive_pairs  TINYINT UNSIGNED
        GENERATED ALWAYS AS (
            (n2=n1+1)+(n3=n2+1)+(n4=n3+1)+(n5=n4+1)+(n6=n5+1)+(n7=n6+1)
        ) STORED,
    low_count          TINYINT UNSIGNED
        GENERATED ALWAYS AS ((n1<=17)+(n2<=17)+(n3<=17)+(n4<=17)+(n5<=17)+(n6<=17)+(n7<=17)) STORED,

    -- Optional jackpot tracking - useful if you ever want to study
    -- rollover patterns (Norsk Tipping doubles the pot when nobody
    -- hits first price). Nullable since you may not always have this data.
    jackpot_amount_nok   DECIMAL(14,2) NULL,
    jackpot_winners      SMALLINT UNSIGNED NULL,
    was_rollover         BOOLEAN NULL,        -- TRUE if this draw's pot rolled over from a previous no-winner week

    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_draw_date (draw_date),       -- exactly one draw per Saturday
    UNIQUE KEY uq_draw_numbers (n1,n2,n3,n4,n5,n6,n7,bonus_number), -- catches duplicate-entry mistakes

    INDEX idx_row_sum (row_sum),
    INDEX idx_odd_count (odd_count),
    INDEX idx_bonus_number (bonus_number)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

-- Example insert (replace with a real historical draw):
-- INSERT INTO lotto_draws (draw_date, n1,n2,n3,n4,n5,n6,n7, bonus_number)
-- VALUES ('2026-06-13', 3,11,14,19,22,28,33, 7);
