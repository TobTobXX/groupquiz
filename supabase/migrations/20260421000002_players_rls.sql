-- Section 3: Block direct client UPDATE on players.
-- All score/streak/correct_count mutations go through submit_answer (security definer),
-- which bypasses RLS.  Removing the UPDATE policy means any direct UPDATE from the
-- browser is rejected with a 403.
-- INSERT and SELECT stay open for anonymous players (join flow and leaderboard).

DROP POLICY IF EXISTS players_all_open ON players;
DROP POLICY IF EXISTS players_select ON players;
DROP POLICY IF EXISTS players_insert ON players;

CREATE POLICY players_select_open ON players FOR SELECT USING (true);
CREATE POLICY players_insert_open ON players FOR INSERT WITH CHECK (true);
