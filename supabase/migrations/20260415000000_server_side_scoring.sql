-- v0.6: Server-side score calculation
-- Tighten RLS on players and player_answers, add submit_answer function.

-- Drop broad policies on players and replace with narrower ones
drop policy "allow all" on players;
create policy players_select on players for select using (true);
create policy players_insert on players for insert with check (true);

-- Drop broad policy on player_answers and replace with select-only
drop policy "allow all" on player_answers;
create policy player_answers_select on player_answers for select using (true);

-- Function: submit an answer, calculate score, and update the player
create or replace function submit_answer(
  p_player_id  uuid,
  p_question_id uuid,
  p_answer_id   uuid
) returns void
language plpgsql
security definer
as $$
declare
  v_is_correct boolean;
  v_points     integer;
begin
  insert into player_answers (player_id, question_id, answer_id)
  values (p_player_id, p_question_id, p_answer_id);

  select a.is_correct, q.points
    into v_is_correct, v_points
    from answers a
    join questions q on q.id = a.question_id
   where a.id = p_answer_id;

  if v_is_correct then
    update players
       set score = score + v_points
     where id = p_player_id;
  end if;
end;
$$;
