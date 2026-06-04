begin;

do $$
declare
  house_course_id bigint;
begin
  insert into public.courses (name, block_code, default_teacher, default_room)
  values ('House Activities', null, null, '3rd Floor Art Rooms')
  on conflict (name) do update
    set default_teacher = excluded.default_teacher,
        default_room = excluded.default_room
  returning id into house_course_id;

  delete from public.timetable_slot_courses
  where slot_id = 58
    and course_id in (select id from public.courses where name like 'PE-%');

  insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
  values (
    58,
    house_course_id,
    coalesce((select max(display_order) from public.timetable_slot_courses where slot_id = 58), 0) + 1,
    null,
    '3rd Floor Art Rooms'
  )
  on conflict (slot_id, course_id) do update
    set override_teacher = excluded.override_teacher,
        override_room = excluded.override_room;

  insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
  select
    student.student_id,
    58,
    house_course_id,
    'manual-house-activities-2026-06-12'
  from public.students as student
  on conflict (student_id, slot_id) do update
    set course_id = excluded.course_id,
        source = excluded.source;
end $$;

commit;