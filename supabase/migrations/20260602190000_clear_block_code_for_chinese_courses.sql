-- 20260602190000_clear_block_code_for_chinese_courses.sql
--
-- Goal
--   Move the 29 Chinese course enrollments out of Block B and into the
--   Non Block bucket. Block_code is currently 'B' on every Chinese A HL,
--   A SL, AB SL, B HL, B SL enrollment; per the user's spec, Chinese
--   courses should not belong to any block.
--
-- Scope
--   Updates only the five Chinese course ids (192, 154, 198, 200, 190).
--   The Chinese block on 2026-06-12 P9 (slot 60) is set up via explicit
--   student_slot_assignments with source 'manual-early-dismissal-...'
--   / 'manual-chinese-block-2026-06', so this enrollment fix does not
--   disturb that block — it only changes which bucket the admin UI
--   groups these courses into.
--
-- Rollback
--   update public.student_enrollments
--      set block_code = 'B'
--    where course_id in (192, 154, 198, 200, 190)
--      and block_code is null
--      and student_id in (...);
--   (You'd need to capture the (student_id, course_id) pairs before
--   nulling them out, since the original block_code is lost.)

begin;

update public.student_enrollments
   set block_code = null
 where course_id in (192, 154, 198, 200, 190)
   and block_code is not null;

commit;

-- Verification (read-only, runs after commit).
-- Expected: every Chinese course enrollment is now block_code = null.
select
  coalesce(block_code, 'NULL') as block_code,
  course_id,
  count(*) as rows
from public.student_enrollments
where course_id in (192, 154, 198, 200, 190)
group by block_code, course_id
order by block_code, course_id;
