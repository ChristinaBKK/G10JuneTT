begin;

do $$
declare
  target_student_id constant text := '3433';
  graduation_slot_id bigint;
  house_slot_id bigint;
  dismissal_slot_id bigint;
  graduation_course_id bigint;
  house_course_id bigint;
  dismissal_course_id bigint;
begin
  select id
    into graduation_slot_id
  from public.timetable_slots
  where term_name = '2026-06-12'
    and grade_level = 'G10'
    and day_name = 'Friday'
    and start_period_id = 'P6'
    and end_period_id = 'P6';

  select id
    into house_slot_id
  from public.timetable_slots
  where term_name = '2026-06-12'
    and grade_level = 'G10'
    and day_name = 'Friday'
    and start_period_id = 'P8'
    and end_period_id = 'P8';

  select id
    into dismissal_slot_id
  from public.timetable_slots
  where term_name = '2026-06-12'
    and grade_level = 'G10'
    and day_name = 'Friday'
    and start_period_id = 'P9'
    and end_period_id = 'P9';

  select id into graduation_course_id from public.courses where name = 'Graduation parade';
  select id into house_course_id from public.courses where name = 'House Activities';
  select id into dismissal_course_id from public.courses where name = 'Early Dismissal';

  if not exists (select 1 from public.students where student_id = target_student_id) then
    raise exception 'Student % was not found.', target_student_id;
  end if;

  if graduation_slot_id is null or house_slot_id is null or dismissal_slot_id is null then
    raise exception 'One or more June 12 P6/P8/P9 slots were not found.';
  end if;

  if graduation_course_id is null or house_course_id is null or dismissal_course_id is null then
    raise exception 'One or more June 12 event courses were not found.';
  end if;

  insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
  values
    (graduation_slot_id, graduation_course_id, 1, null, null),
    (house_slot_id, house_course_id, 1, null, '3rd Floor Art Rooms'),
    (dismissal_slot_id, dismissal_course_id, 1, null, null)
  on conflict (slot_id, course_id) do update
    set override_teacher = excluded.override_teacher,
        override_room = excluded.override_room;

  insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
  values
    (target_student_id, graduation_slot_id, graduation_course_id, 'manual-june12-events-student-3433'),
    (target_student_id, house_slot_id, house_course_id, 'manual-june12-events-student-3433'),
    (target_student_id, dismissal_slot_id, dismissal_course_id, 'manual-june12-events-student-3433')
  on conflict (student_id, slot_id) do update
    set course_id = excluded.course_id,
        source = excluded.source;
end $$;

commit;
