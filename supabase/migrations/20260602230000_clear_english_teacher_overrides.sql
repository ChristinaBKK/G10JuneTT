-- 20260602230000_clear_english_teacher_overrides.sql
--
-- Goal
--   The admin course-change dropdown was rendering the wrong teacher for
--   each English course because the per-slot override_teacher values in
--   timetable_slot_courses were mis-paired: each course had the wrong
--   teacher's name. The function loadOptionTeacherByCourseName prefers
--   the override over the course default, so the wrong teacher won.
--
-- Fix
--   Clear override_teacher on every English A HL / A SL / B HL / B SL
--   slot_courses row so the course default (which was set in
--   20260602170000_set_english_teachers.sql) takes effect everywhere:
--     English A HL / A SL  -> Darren McQuay
--     English B HL         -> Warwick Midlane
--     English B SL         -> Donald
--
--   override_room is left alone — those were not flagged by the user.
--   If the room pairings are also wrong, run a follow-up that clears
--   them too.
--
-- Rollback
--   update public.timetable_slot_courses
--      set override_teacher = case course_id
--        when 189 then 'Warwick Midlane'  -- English A HL
--        when 199 then 'Warwick Midlane'  -- English A SL
--        when 156 then 'Donald Meyer'     -- English B HL
--        when 148 then 'Darren McQuay'    -- English B SL
--      end
--    where course_id in (189, 199, 156, 148);

begin;

update public.timetable_slot_courses
   set override_teacher = null
 where course_id in (189, 199, 156, 148)
   and override_teacher is not null;

commit;

-- Verification (read-only, runs after commit).
-- Expected: zero rows; every English course in slot_courses now has
-- override_teacher = null so the course default (Darren McQuay /
-- Warwick Midlane / Donald) wins in the dropdown.
select
  c.name as course_name,
  count(*) as rows_with_override_teacher
from public.timetable_slot_courses sc
join public.courses c on c.id = sc.course_id
where c.id in (189, 199, 156, 148)
  and sc.override_teacher is not null
group by c.name
order by c.name;

-- And a per-course current state:
select
  c.id,
  c.name,
  c.default_teacher,
  c.default_room
from public.courses c
where c.id in (189, 199, 156, 148)
order by c.id;
