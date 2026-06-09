begin;

-- Final June 12 House Activities cleanup:
-- - student 2815 was still missing the P8 slot row
-- - House Activities had no teacher metadata, which kept failing audits

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

  update public.courses
     set default_teacher = 'Block E Teachers'
   where id = house_course_id;

  insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
  values ('2815', 59, house_course_id, 'manual-house-activities-2026-06-12-p8-final-fix')
  on conflict (student_id, slot_id) do update
    set course_id = excluded.course_id,
        source = excluded.source;
end $$;

commit;
