-- 20260602180000_early_dismissal_2026_06_12_p9.sql
--
-- Goal
--   On 12 June P9 (slot 60), make every G10 student have a "Early Dismissal"
--   class with no teacher and no room. The class is shown to the student
--   as a single cell, replacing what would otherwise be an empty / "Free
--   Period" cell.
--
-- How
--   1. Rename the existing "Dismiss early" course (id 99) to "Early Dismissal"
--      so the displayed label matches the user's wording. The existing
--      default_teacher = 'N/A' and default_room = 'N/A' stay as-is — those
--      are exactly the "no teacher or room" the user asked for.
--   2. Add "Early Dismissal" to slot 60's slot_courses offering list so the
--      derived branch of student_timetable_entries can resolve it.
--   3. Bulk-insert student_slot_assignments for every G10 student on slot 60
--      with course_id = 99. ON CONFLICT DO UPDATE keeps the existing 142 rows
--      in sync and adds the 32 missing ones.
--
-- Rollback
--   update public.courses set name = 'Dismiss early' where id = 99;
--   delete from public.timetable_slot_courses
--   where slot_id = 60 and course_id = 99;
--   delete from public.student_slot_assignments
--   where slot_id = 60 and course_id = 99
--     and source = 'manual-early-dismissal-2026-06-12';

begin;

-- 1) Rename the course to match the user's wording.
update public.courses
   set name = 'Early Dismissal'
 where id = 99
   and name = 'Dismiss early';

-- 2) Add "Early Dismissal" to slot 60's slot_courses (idempotent).
insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select 60, 99, coalesce(max(display_order), 0) + 1, null, null
from public.timetable_slot_courses
where slot_id = 60
on conflict (slot_id, course_id) do nothing;

-- 3) Bulk-insert student_slot_assignments for every G10 student on slot 60.
--    Cross-join with public.students picks up every student in the system.
--    ON CONFLICT DO UPDATE no-ops the 142 already-correct rows and adds the
--    32 missing ones.
insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
select s.student_id, 60, 99, 'manual-early-dismissal-2026-06-12'
from public.students as s
where exists (
    select 1
    from public.student_timetable_entries as e
    where e.student_id = s.student_id
      and e.grade_level = 'G10'
      and e.term_name between '2026-06-01' and '2026-06-30'
    limit 1
  )
on conflict (student_id, slot_id) do update
  set course_id = excluded.course_id,
      source = excluded.source;

commit;

-- Verification (read-only, runs after commit).
-- Expected: every G10 student with a 2026-06 entry has a "Early Dismissal"
-- row for slot 60 (2026-06-12 P9), teacher 'N/A', room 'N/A'.
select
  count(distinct s.student_id) as students_with_early_dismissal,
  count(*) as total_rows
from public.student_timetable_entries as e
join public.students as s on s.student_id = e.student_id
where e.term_name = '2026-06-12'
  and e.day_name = 'Friday'
  and e.start_period_id = 'P9'
  and e.course_name = 'Early Dismissal';

-- And a quick scan to confirm the cross-check vs the universe of G10
-- students in scope:
select
  (select count(distinct student_id) from public.student_timetable_entries
    where grade_level = 'G10'
      and term_name between '2026-06-01' and '2026-06-30') as g10_students_in_term,
  count(*) as early_dismissal_rows_on_2026_06_12_p9;
