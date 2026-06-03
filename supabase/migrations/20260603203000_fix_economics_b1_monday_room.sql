-- 20260603203000_fix_economics_b1_monday_room.sql
--
-- Goal
--   Keep Economics B-1 on B4009 for the late Monday block on both Mondays,
--   including the incorrect June 29 live rows currently on B1037.
--
-- Scope
--   Course id 144 (Economics B-1), slots 104 and 105
--   2026-06-29 Monday P8-P9
--
-- Idempotent
--   Re-running is safe because the target rows are set to the same value.

begin;

update public.timetable_slot_courses
   set override_room = 'B4009'
 where course_id = 144
   and slot_id in (104, 105);

commit;

select slot_id, override_room
from public.timetable_slot_courses
where course_id = 144
  and slot_id in (68, 69, 104, 105)
order by slot_id;