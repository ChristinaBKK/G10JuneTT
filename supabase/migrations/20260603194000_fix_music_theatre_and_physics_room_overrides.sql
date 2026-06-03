-- 20260603194000_fix_music_theatre_and_physics_room_overrides.sql
--
-- Keep room overrides aligned with the June 2026 live rooming sheet:
--   - Physics A-1 should be in B3004
--   - Music should be in B2003
--   - Theatre HL/SL should be in B2004

begin;

update public.timetable_slot_courses as slot_course
   set override_room = 'B3004'
  from public.courses as course
 where course.id = slot_course.course_id
   and course.name = 'Physics A-1';

update public.timetable_slot_courses as slot_course
   set override_room = 'B2003'
  from public.courses as course
 where course.id = slot_course.course_id
   and course.name = 'Music';

update public.timetable_slot_courses as slot_course
   set override_room = 'B2004'
  from public.courses as course
 where course.id = slot_course.course_id
   and course.name in ('Theatre HL', 'Theatre SL');

commit;

-- Verification (read-only, runs after commit).
select
  course.name as course_name,
  count(*) filter (where slot_course.override_room = 'B3004') as in_b3004,
  count(*) filter (where slot_course.override_room = 'B2003') as in_b2003,
  count(*) filter (where slot_course.override_room = 'B2004') as in_b2004
from public.timetable_slot_courses as slot_course
join public.courses as course
  on course.id = slot_course.course_id
where course.name in ('Physics A-1', 'Music', 'Theatre HL', 'Theatre SL')
group by course.name
order by course.name;