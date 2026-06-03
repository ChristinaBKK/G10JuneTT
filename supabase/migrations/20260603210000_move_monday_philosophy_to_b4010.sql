-- 20260603210000_move_monday_philosophy_to_b4010.sql
--
-- Goal
--   Move Philosophy HL and Philosophy SL to B4010 for the two Monday block E
--   sessions on 2026-06-15 and 2026-06-29.
--
-- Scope
--   Affects slot_ids 61, 62, 97, and 98 for course_ids 159 and 176 only.
--
-- Idempotent
--   Re-running keeps the same override_room value on the same rows.

begin;

update public.timetable_slot_courses
   set override_room = 'B4010'
 where course_id in (159, 176)
   and slot_id in (61, 62, 97, 98);

commit;

select
  sc.slot_id,
  ts.term_name,
  ts.day_name,
  ts.start_period_id,
  ts.end_period_id,
  c.name as course_name,
  sc.override_room
from public.timetable_slot_courses sc
join public.courses c
  on c.id = sc.course_id
join public.timetable_slots ts
  on ts.id = sc.slot_id
where sc.course_id in (159, 176)
  and sc.slot_id in (61, 62, 97, 98)
order by sc.slot_id, c.name;