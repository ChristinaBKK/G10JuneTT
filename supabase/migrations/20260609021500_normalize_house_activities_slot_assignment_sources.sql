begin;

-- Root cause:
--   Friday 2026-06-12 P8 House Activities rows were partly stored with
--   source = 'synced-from-enrollments', even though House Activities is a
--   special-event slot assignment rather than a true enrollment-backed course.
--   Any admin-triggered resync can delete those rows and fail to recreate
--   them, leaving P8 blank in student view for affected students.
--
-- Cleanup:
--   1. Ensure every student carrying the old P7 legacy source also has the
--      matching P8 House Activities row.
--   2. Normalize all P8 House Activities rows to a protected manual source.
--   3. Re-label stale P7 legacy rows as synced-from-enrollments so future
--      resyncs can freely rebuild the real PE assignment from block F.

do $$
declare
  house_course_id bigint;
begin
  select id
    into house_course_id
  from public.courses
  where name = 'House Activities'
  limit 1;

  if house_course_id is null then
    raise exception 'House Activities course was not found.';
  end if;

  insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
  select
    stale.student_id,
    59,
    house_course_id,
    'manual-house-activities-2026-06-12-p8'
  from public.student_slot_assignments as stale
  where stale.slot_id = 58
    and stale.source = 'manual-house-activities-2026-06-12'
    and not exists (
      select 1
      from public.student_slot_assignments as current_p8
      where current_p8.student_id = stale.student_id
        and current_p8.slot_id = 59
        and current_p8.course_id = house_course_id
    )
  on conflict (student_id, slot_id) do update
    set course_id = excluded.course_id,
        source = excluded.source;

  update public.student_slot_assignments
     set source = 'manual-house-activities-2026-06-12-p8'
   where slot_id = 59
     and course_id = house_course_id;

  update public.student_slot_assignments
     set source = 'synced-from-enrollments'
   where slot_id = 58
     and source = 'manual-house-activities-2026-06-12';
end $$;

commit;
