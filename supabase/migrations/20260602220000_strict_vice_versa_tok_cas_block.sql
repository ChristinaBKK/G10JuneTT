-- 20260602220000_strict_vice_versa_tok_cas_block.sql
--
-- Goal
--   Switch the Monday P3/P4 TOK/CAS block to the strict "vice versa"
--   design: each group takes their own TOK + the OTHER group's CAS.
--     P3: Group 1 -> TOK (Group 1), Group 2 -> CAS (Group 1)
--     P4: Group 1 -> CAS (Group 2), Group 2 -> TOK (Group 2)
--
-- This migration supersedes the per-slot room overrides in
-- 20260602210000 with course-level defaults (the user's "always" rule)
-- and rewrites the slot_courses + explicit student_slot_assignments rows
-- so that Group 2's P3 picks up CAS (Group 1) instead of CAS (Group 2).
--
-- Course-level room defaults
--   TOK (Group 1)  -> B4010  (Miya Yang,  course id 598)
--   TOK (Group 2)  -> B3044  (Matthew Peatman, course id 612)
--   CAS (Group 1)  -> B3044  (Lucas Lin,    course id 958)
--   CAS (Group 2)  -> B4010  (Lucas Lin,    course id 959)
--
-- 31 students in scope (per the user's list)
--   Group 1 (18): 1037, 1114, 1583, 1616, 1618, 2813, 3815, 3958, 3991,
--                  4022, 4070, 4071, 4123, 4126, 4192, 4196, 4215, 4260
--   Group 2 (13): 183, 626, 653, 2487, 2495, 2698, 3291, 3465, 3470,
--                  3643, 3677, 4108, 4220
--
-- Rollback (rough sketch — re-apply the older state if needed)
--   update public.student_slot_assignments
--      set course_id = 959  -- CAS (Group 2)
--    where slot_id in (63, 99)
--      and student_id in ('183','626','653','2487','2495','2698',
--                         '3291','3465','3470','3643','3677','4108','4220')
--      and source = 'manual-monday-p34-tok-cas-swap';
--   delete from public.timetable_slot_courses
--     where slot_id in (63, 99) and course_id = 958;

begin;

-- 1) Course-level room defaults.
update public.courses set default_room = 'B4010' where id = 598;  -- TOK (Group 1)
update public.courses set default_room = 'B3044' where id = 612;  -- TOK (Group 2)
update public.courses set default_room = 'B3044' where id = 958;  -- CAS (Group 1)
update public.courses set default_room = 'B4010' where id = 959;  -- CAS (Group 2)

-- 2) Clear per-slot overrides on the four TOK/CAS courses so the defaults
--    take effect everywhere.
update public.timetable_slot_courses
   set override_teacher = null,
       override_room    = null
 where course_id in (598, 612, 958, 959);

-- 3) Add CAS (Group 1) to the slot_courses for the two P3 slots (63, 99)
--    and the two P4 slots (64, 100). With CAS (Group 1) now in all four
--    slots, the explicit_entries join always resolves.
--    (For slot 64, remove CAS (Group 2) first if it's there from the
--    earlier swap migration's misfire; same for slot 100.)
delete from public.timetable_slot_courses
where slot_id in (64, 100)
  and course_id = 959;  -- CAS (Group 2)

insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select s.slot_id, c.id, 10199, null, null
from (values (63), (64), (99), (100)) as s(slot_id)
cross join public.courses c
where c.id = 958  -- CAS (Group 1)
on conflict (slot_id, course_id) do nothing;

-- 4) Re-point Group 2's explicit P3 assignment from CAS (Group 2) to
--    CAS (Group 1) so the "vice versa" design lights up in the view.
update public.student_slot_assignments
   set course_id = 958,  -- CAS (Group 1)
       source   = 'manual-monday-p34-tok-cas-swap'
 where slot_id in (63, 99)
   and course_id = 959  -- CAS (Group 2)
   and source = 'manual-monday-p34-tok-cas-swap'
   and student_id in (
     '183', '626', '653', '2487', '2495', '2698',
     '3291', '3465', '3470', '3643', '3677', '4108', '4220'
   );

commit;

-- Verification (read-only, runs after commit).
-- 1) Course defaults.
select id, name, default_teacher, default_room
from public.courses
where id in (598, 612, 958, 959)
order by id;

-- 2) All four Monday P3/P4 slots should now offer TOK (Group 1),
--    TOK (Group 2), and CAS (Group 1). CAS (Group 2) should only
--    be in the slot_courses if some design needs it; the migration
--    above removed it from slots 64 and 100. Spot check:
select s.id as slot_id, s.term_name, s.start_period_id, c.name as course
from public.timetable_slots s
join public.timetable_slot_courses sc on sc.slot_id = s.id
join public.courses c on c.id = sc.course_id
where s.id in (63, 64, 99, 100)
  and c.name in ('TOK (Group 1)','TOK (Group 2)','CAS (Group 1)','CAS (Group 2)')
order by s.id, c.name;

-- 3) Group 2 students in P3 (slots 63, 99) should now show CAS (Group 1);
--    Group 1 students in P3 should still show TOK (Group 1).
--    Note: student_timetable_entries is a VIEW that doesn't expose slot_id
--    as a column, so we filter by the view's own slot columns instead of
--    joining timetable_slots.
select
  s.student_id,
  s.full_name,
  e.term_name,
  e.day_name,
  e.start_period_id,
  e.course_name,
  e.teacher,
  e.room
from public.student_timetable_entries e
join public.students s on s.student_id = e.student_id
where e.start_period_id in ('P3', 'P4')
  and e.day_name = 'Monday'
  and e.term_name in ('2026-06-15', '2026-06-29')
  and e.course_name in ('TOK (Group 1)','TOK (Group 2)','CAS (Group 1)','CAS (Group 2)')
order by s.student_id, e.term_name, e.start_period_id;
