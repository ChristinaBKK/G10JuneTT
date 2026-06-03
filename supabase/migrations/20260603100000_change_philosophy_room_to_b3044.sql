-- 20260603100000_change_philosophy_room_to_b3044.sql
--
-- Goal
--   Update the room for both Philosophy courses (Philosophy HL id 159 and
--   Philosophy SL id 176) from B2036 to B3044 in every G10 slot where
--   Philosophy is currently booked in B2036.
--
-- Scope
--   22 rows total, across slots 43, 44, 52, 61, 62, 74, 88, 89, 92,
--   97, 98 (both courses offered in each slot, in the same display_order
--   band 10102-10106). The override_teacher (Matthew Peatman) is
--   unchanged — only the room changes.
--
-- Idempotent
--   The WHERE clause filters to rows where override_room is currently
--   'B2036', so re-running on the post-migration state is a no-op.
--
-- Rollback
--   update public.timetable_slot_courses
--      set override_room = 'B2036'
--    where course_id in (159, 176)
--      and override_room = 'B3044';

begin;

update public.timetable_slot_courses
   set override_room = 'B3044'
 where course_id in (159, 176)
   and override_room = 'B2036';

commit;

-- Verification (read-only, runs after commit).
-- Expected: zero rows still on B2036 for the two Philosophy courses.
select
  c.name as course_name,
  count(*) filter (where sc.override_room = 'B2036') as still_on_b2036,
  count(*) filter (where sc.override_room = 'B3044') as now_on_b3044
from public.timetable_slot_courses sc
join public.courses c on c.id = sc.course_id
where c.id in (159, 176)
group by c.name
order by c.name;
