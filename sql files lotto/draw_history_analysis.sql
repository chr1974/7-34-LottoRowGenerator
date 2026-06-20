-- =====================================================================
-- Cross-referencing played rows against real historical draws.
--
-- These queries assume you maintain a small table of "my played rows"
-- (your subscription's 10 rows). If you don't have one yet, create it
-- first - see the bottom of this file for a starter table.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. For ONE specific draw, count how many of your played row's
--    numbers matched the 7 main winning numbers, and whether your
--    leftover number(s) hit the bonus.
--    (Run this manually with explicit numbers, or join against
--    my_played_rows - see query 2 below for the automated version.)
-- ---------------------------------------------------------------------
SELECT
    d.draw_date,
    d.n1, d.n2, d.n3, d.n4, d.n5, d.n6, d.n7, d.bonus_number,
    -- counts how many of YOUR row's 7 numbers appear in the draw's 7 winning numbers
    (
        (7 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (9 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (24 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (27 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (29 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (31 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (34 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7))
    ) AS numbers_matched
FROM lotto_draws d
WHERE d.draw_date = '2026-06-13'  -- adjust to the draw you're checking
;

-- ---------------------------------------------------------------------
-- 2. Starter table for tracking your own played rows (e.g. your 10-row
--    subscription), separate from the full combinations universe.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS my_played_rows (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    label       VARCHAR(50) NULL,        -- e.g. 'subscription row 1'
    n1          TINYINT UNSIGNED NOT NULL,
    n2          TINYINT UNSIGNED NOT NULL,
    n3          TINYINT UNSIGNED NOT NULL,
    n4          TINYINT UNSIGNED NOT NULL,
    n5          TINYINT UNSIGNED NOT NULL,
    n6          TINYINT UNSIGNED NOT NULL,
    n7          TINYINT UNSIGNED NOT NULL,
    active      BOOLEAN DEFAULT TRUE,     -- so you can retire/replace rows over time without deleting history
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- Insert your current 10 rows (adjust if any have changed since the screenshot):
INSERT INTO my_played_rows (label, n1,n2,n3,n4,n5,n6,n7) VALUES
('row 1',  7, 9,24,27,29,31,34),
('row 2', 11,14,21,26,28,30,32),
('row 3', 12,15,20,27,30,32,34),
('row 4', 11,18,20,25,28,30,34),
('row 5', 12,15,18,21,24,28,34),
('row 6',  6,12,19,27,29,31,33),
('row 7', 14,20,22,24,29,32,34),
('row 8', 13,17,20,22,25,27,29),
('row 9', 11,13,15,20,25,29,34),
('row 10', 7,15,20,23,25,29,32);

-- ---------------------------------------------------------------------
-- 3. Automated matching: for every historical draw, check every one of
--    your played rows, and report how many numbers matched (and
--    whether the leftover number was the bonus).
-- ---------------------------------------------------------------------
SELECT
    d.draw_date,
    p.label,
    p.n1, p.n2, p.n3, p.n4, p.n5, p.n6, p.n7,
    (
        (p.n1 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (p.n2 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (p.n3 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (p.n4 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (p.n5 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (p.n6 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7)) +
        (p.n7 IN (d.n1,d.n2,d.n3,d.n4,d.n5,d.n6,d.n7))
    ) AS numbers_matched,
    (
        d.bonus_number IN (p.n1,p.n2,p.n3,p.n4,p.n5,p.n6,p.n7)
    ) AS bonus_matched
FROM lotto_draws d
CROSS JOIN my_played_rows p
WHERE p.active = TRUE
ORDER BY d.draw_date DESC, numbers_matched DESC;

-- ---------------------------------------------------------------------
-- 4. Real-world vs theoretical: compare the ACTUAL observed odd_count
--    distribution from historical draws against the predicted
--    percentages we computed earlier (30.08% at 3-4 split, etc).
--    Needs a reasonable number of historical draws loaded to be
--    statistically meaningful - a handful of draws won't show much.
-- ---------------------------------------------------------------------
SELECT
    odd_count,
    COUNT(*) AS actual_draws,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM lotto_draws), 2) AS actual_pct,
    CASE odd_count
        WHEN 0 THEN 0.36 WHEN 1 THEN 3.91 WHEN 2 THEN 15.64 WHEN 3 THEN 30.08
        WHEN 4 THEN 30.08 WHEN 5 THEN 15.64 WHEN 6 THEN 3.91 WHEN 7 THEN 0.36
    END AS theoretical_pct
FROM lotto_draws
GROUP BY odd_count
ORDER BY odd_count;
