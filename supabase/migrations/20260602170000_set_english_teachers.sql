-- 20260602170000_set_english_teachers.sql
--
-- Goal
--   Pin default teachers on the four English courses so the rendered
--   timetables stop showing "Teacher: TBC" for any English class.
--
--   English A HL  -> Darren McQuay
--   English A SL  -> Darren McQuay
--   English B HL  -> Warwick Midlane
--   English B SL  -> Donald
--
-- All four are id-based updates so the script is safe to re-run even if
-- the course name gets renamed later. As of the data check on 2026-06-02:
--   English A HL (id 189), English A SL (id 199), English B HL (id 156)
--   are already set to the names above; English B SL (id 148) is null
--   and is the only one that actually changes value. Re-running is a
--   no-op for the first three and a write for the fourth.
--
-- Rollback
--   update public.courses set default_teacher = null where id in (189, 199, 156, 148);
--   -- then re-apply the original teacher values (Darren McQuay, Warwick Midlane)
--   -- for the ones you want to restore.

begin;

update public.courses
   set default_teacher = 'Darren McQuay'
 where id = 189;  -- English A HL

update public.courses
   set default_teacher = 'Darren McQuay'
 where id = 199;  -- English A SL

update public.courses
   set default_teacher = 'Warwick Midlane'
 where id = 156;  -- English B HL

update public.courses
   set default_teacher = 'Donald'
 where id = 148;  -- English B SL

commit;

-- Verification (read-only, runs after commit).
-- Expected: all four English courses show the new teacher and the rows that
-- were already correct are unchanged.
select
  id,
  name,
  default_teacher
from public.courses
where id in (189, 199, 156, 148)
order by name;
