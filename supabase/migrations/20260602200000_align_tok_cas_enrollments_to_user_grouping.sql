-- 20260602200000_align_tok_cas_enrollments_to_user_grouping.sql
--
-- Goal
--   Make the admin "No block / additional courses" section show both
--   CAS (Group 1) and CAS (Group 2) alongside the existing TOK entries,
--   and align the whole TOK/CAS enrollment set to the user's grouping
--   ("TOK Group 1 = CAS Group 2 and vice versa").
--
-- Current state (before this migration)
--   31 students have a TOK enrollment, but split 16 / 15 between
--   TOK (Group 1) and TOK (Group 2) — that split does not match the
--   user's Group 1 (18) / Group 2 (13) cohort split.
--   0 students have a CAS enrollment of either kind.
--   All enrollments have block_code = NULL (Non Block), which is
--   what the user wants, so we only touch the course_id, not the
--   block_code.
--
-- Target state
--   Every student in the user's Group 1 (18 students) is enrolled in
--     TOK (Group 1)   id 598
--     CAS (Group 2)   id 959
--   Every student in the user's Group 2 (13 students) is enrolled in
--     TOK (Group 2)   id 612
--     CAS (Group 1)   id 958
--   All enrollments have block_code = NULL.
--
-- Note on the Monday P3/P4 TOK/CAS block
--   That block is wired through explicit student_slot_assignments rows
--   (source = 'manual-monday-p34-tok-cas-swap'), not through the
--   student_enrollments trigger. So changing the enrollments here does
--   not disturb the Monday block — explicit rows always win in the
--   student_timetable_entries view.
--
-- Rollback
--   Not provided. The pre-migration state was inconsistent (16/15 split
--   not matching the 18/13 group split, 0 CAS enrollments) and is not
--   a target state to return to. To reverse the data itself, take a
--   snapshot of the 31 (student_id, course_id) pairs before running.

begin;

-- 1) Re-point the existing TOK enrollments to match the user's grouping.
--    We do this in two passes to keep the (student_id, course_id) PK
--    happy: first delete the rows that are on the wrong course, then
--    insert the corrected rows. Both pass keys are scoped to the 31
--    students so no other student's enrollments are disturbed.

-- Group 1 students who currently sit on TOK (Group 2) need to flip to TOK (Group 1).
delete from public.student_enrollments
where course_id = 612  -- TOK (Group 2)
  and student_id in (
    '1037', '1114', '1583', '1616', '1618', '2813',
    '3815', '3958', '3991', '4022', '4070', '4071',
    '4123', '4126', '4192', '4196', '4215', '4260'
  );

-- Group 2 students who currently sit on TOK (Group 1) need to flip to TOK (Group 2).
delete from public.student_enrollments
where course_id = 598  -- TOK (Group 1)
  and student_id in (
    '183', '626', '653', '2487', '2495', '2698',
    '3291', '3465', '3470', '3643', '3677', '4108', '4220'
  );

-- 2) Now insert the canonical 31 TOK enrollments (idempotent via ON CONFLICT).
insert into public.student_enrollments (student_id, course_id, block_code) values
  -- Group 1 (18 students) -> TOK (Group 1)
  ('1037', 598, null), ('1114', 598, null), ('1583', 598, null),
  ('1616', 598, null), ('1618', 598, null), ('2813', 598, null),
  ('3815', 598, null), ('3958', 598, null), ('3991', 598, null),
  ('4022', 598, null), ('4070', 598, null), ('4071', 598, null),
  ('4123', 598, null), ('4126', 598, null), ('4192', 598, null),
  ('4196', 598, null), ('4215', 598, null), ('4260', 598, null),
  -- Group 2 (13 students) -> TOK (Group 2)
  ('183', 612, null), ('626', 612, null), ('653', 612, null),
  ('2487', 612, null), ('2495', 612, null), ('2698', 612, null),
  ('3291', 612, null), ('3465', 612, null), ('3470', 612, null),
  ('3643', 612, null), ('3677', 612, null), ('4108', 612, null),
  ('4220', 612, null)
on conflict (student_id, course_id) do nothing;

-- 3) Add the CAS enrollments per the "TOK G1 = CAS G2 and vice versa" rule.
insert into public.student_enrollments (student_id, course_id, block_code) values
  -- Group 1 (18 students) -> CAS (Group 2)
  ('1037', 959, null), ('1114', 959, null), ('1583', 959, null),
  ('1616', 959, null), ('1618', 959, null), ('2813', 959, null),
  ('3815', 959, null), ('3958', 959, null), ('3991', 959, null),
  ('4022', 959, null), ('4070', 959, null), ('4071', 959, null),
  ('4123', 959, null), ('4126', 959, null), ('4192', 959, null),
  ('4196', 959, null), ('4215', 959, null), ('4260', 959, null),
  -- Group 2 (13 students) -> CAS (Group 1)
  ('183', 958, null), ('626', 958, null), ('653', 958, null),
  ('2487', 958, null), ('2495', 958, null), ('2698', 958, null),
  ('3291', 958, null), ('3465', 958, null), ('3470', 958, null),
  ('3643', 958, null), ('3677', 958, null), ('4108', 958, null),
  ('4220', 958, null)
on conflict (student_id, course_id) do nothing;

commit;

-- Verification (read-only, runs after commit).
-- Expected: every student has exactly two rows, one TOK + one CAS, in the
-- pairs the user specified.
select
  course_id,
  count(*) as student_count
from public.student_enrollments
where course_id in (598, 612, 958, 959)
group by course_id
order by course_id;

-- And a per-student cross-check to verify each student has exactly the
-- two right courses paired together.
select
  e.student_id,
  bool_or(e.course_id = 598) as has_tok_g1,
  bool_or(e.course_id = 612) as has_tok_g2,
  bool_or(e.course_id = 958) as has_cas_g1,
  bool_or(e.course_id = 959) as has_cas_g2
from public.student_enrollments e
where e.course_id in (598, 612, 958, 959)
group by e.student_id
order by e.student_id;
