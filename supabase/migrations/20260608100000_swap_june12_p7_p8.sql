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
    and course_id = house_course_id;

  insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
  values
    (58, 578, 5031, 'Abie Rakgoale', 'Gym'),
    (58, 607, 5032, 'Nicole Mangondo', 'Gym'),
    (58, 611, 5033, 'Miko Qian', 'Gym'),
    (58, 633, 5034, 'Matthew Johnson', 'Gym'),
    (58, 588, 5035, 'Milan Vucinic', 'Gym'),
    (58, 618, 5036, 'Lourdes Caramol', 'Gym'),
    (58, 649, 5037, 'Milan Saric', 'Gym')
  on conflict (slot_id, course_id) do update
    set display_order = excluded.display_order,
        override_teacher = excluded.override_teacher,
        override_room = excluded.override_room;

  delete from public.timetable_slot_courses
  where slot_id = 59
    and course_id in (578, 607, 611, 633, 588, 618, 649);

  insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
  values (59, house_course_id, 1, null, '3rd Floor Art Rooms')
  on conflict (slot_id, course_id) do update
    set display_order = excluded.display_order,
        override_teacher = excluded.override_teacher,
        override_room = excluded.override_room;

  insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
  select
    student.student_id,
    59,
    house_course_id,
    'manual-house-activities-2026-06-12-p8'
  from public.students as student
  on conflict (student_id, slot_id) do update
    set course_id = excluded.course_id,
        source = excluded.source;
end $$;

commit;
