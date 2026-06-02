-- 20260602210000_set_tok_cas_room_defaults_and_fix_slot_100_cas.sql
--
-- Goal
--   1. Encode the per-course room rule as course defaults (instead of
--      per-slot overrides) so the rule survives any future slot changes:
--        TOK (Group 1) -> B3044
--        TOK (Group 2) -> B4010
--        CAS (Group 1) -> B4010
--        CAS (Group 2) -> B3044
--      Then clear override_room (and override_teacher) on the four
--      courses' slot_courses rows so the defaults take effect everywhere.
--      (The teacher names were set in step 1 of the Monday P3/P4 migration:
--      Miya Yang / Matthew Peatman / Lucas Lin / Lucas Lin.)
--
--   2. Fix slot 100 (2026-06-29 P4) so it carries the correct swap pair
--      "TOK (Group 2) + CAS (Group 1)" — matching slot 64. The earlier
--      Monday swap migration accidentally added CAS (Group 2) to slot 100
--      instead of CAS (Group 1), so CAS (Group 1) was missing from
--      slot_courses.
--
-- Notes
--   - The Monday P3/P4 explicit student_slot_assignments rows are not
--     touched. The view's explicit_entries uses a LEFT JOIN on
--     timetable_slot_courses, so even if a course is missing from a
--     slot's offerings the row still renders; the course default fills
--     the room.
--   - Group 1's existing explicit assignment in slot 100 is CAS (Group 2)
--     and stays as-is. After this migration the slot also offers
--     CAS (Group 1); both will render in the view but only the explicit
--     assignment surfaces for Group 1.
--
-- Rollback
--   -- Re-apply the per-slot rooms that were in place before this migration
--   update public.timetable_slot_courses set override_room = 'B3044', override_teacher = null
--     where slot_id in (63) and course_id = (select id from public.courses where name = 'TOK (Group 1)');
--   -- ... (and the other 7 rows from the audit log)
--   update public.courses set default_room = null
--     where id in (598, 612, 958, 959);
--   delete from public.timetable_slot_courses
--     where slot_id = 100 and course_id = (select id from public.courses where name = 'CAS (Group 1)');
--   insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
--     select 100, id, 10198, null, null from public.courses where name = 'CAS (Group 2)';

begin;

-- 1) Set per-course room defaults.
update public.courses set default_room = 'B3044' where id = 598;  -- TOK (Group 1)
update public.courses set default_room = 'B4010' where id = 612;  -- TOK (Group 2)
update public.courses set default_room = 'B4010' where id = 958;  -- CAS (Group 1)
update public.courses set default_room = 'B3044' where id = 959;  -- CAS (Group 2)

-- 2) Clear per-slot overrides on the four TOK/CAS courses so the course
--    defaults take effect.
update public.timetable_slot_courses
   set override_teacher = null,
       override_room    = null
 where course_id in (598, 612, 958, 959);

-- 3) Fix slot 100: remove CAS (Group 2) (it was added in error by the
--    earlier Monday swap migration) and add CAS (Group 1) so the slot
--    matches slot 64's swap pair.
delete from public.timetable_slot_courses
where slot_id = 100
  and course_id = (select id from public.courses where name = 'CAS (Group 2)');

insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select 100, c.id, 10198, null, null
from public.courses c
where c.name = 'CAS (Group 1)'
on conflict (slot_id, course_id) do nothing;

commit;

-- Verification (read-only, runs after commit).
-- 1) Course defaults.
select id, name, default_teacher, default_room
from public.courses
where id in (598, 612, 958, 959)
order by id;

-- 2) Slot 100 should now have TOK (Group 2) + CAS (Group 1), matching slot 64.
select s.id as slot_id, s.term_name, s.start_period_id, c.name as course
from public.timetable_slots s
join public.timetable_slot_courses sc on sc.slot_id = s.id
join public.courses c on c.id = sc.course_id
where s.id in (64, 100)
  and c.name in ('TOK (Group 1)', 'TOK (Group 2)', 'CAS (Group 1)', 'CAS (Group 2)')
order by s.id, c.name;

-- 3) Resolved view: every TOK/CAS entry across the four Monday P3/P4 slots
--    should show the room from the course default (no per-slot overrides).
select
  s.student_id,
  slot.term_name,
  slot.start_period_id,
  course.name as course_name,
  coalesce(slot_course.override_room, course.default_room) as resolved_room
from public.student_timetable_entries e
join public.students s on s.student_id = e.student_id
join public.timetable_slots slot on slot.id = e.slot_id
join public.courses course on course.id = e.course_id
left join public.timetable_slot_courses slot_course
  on slot_course.slot_id = e.slot_id
 and slot_course.course_id = e.course_id
where slot.id in (63, 64, 99, 100)
  and course.name in ('TOK (Group 1)', 'TOK (Group 2)', 'CAS (Group 1)', 'CAS (Group 2)')
order by slot.id, s.student_id;
