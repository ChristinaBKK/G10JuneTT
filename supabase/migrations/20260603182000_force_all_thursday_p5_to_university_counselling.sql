begin;

with target_slots as (
  select id
  from public.timetable_slots
  where grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
    and term_name >= '2026-06-10'
    and term_name <= '2026-06-29'
)
delete from public.timetable_slot_courses as slot_courses
using target_slots
where slot_courses.slot_id = target_slots.id;

with target_slots as (
  select id
  from public.timetable_slots
  where grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
    and term_name >= '2026-06-10'
    and term_name <= '2026-06-29'
)
insert into public.timetable_slot_courses (
  slot_id,
  course_id,
  display_order,
  override_teacher,
  override_room
)
select
  target_slots.id,
  103,
  10000,
  'University Counsellors',
  'To be updated by my counsellor'
from target_slots
on conflict (slot_id, course_id) do update
set
  display_order = excluded.display_order,
  override_teacher = excluded.override_teacher,
  override_room = excluded.override_room;

with target_slots as (
  select id
  from public.timetable_slots
  where grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
    and term_name >= '2026-06-10'
    and term_name <= '2026-06-29'
)
insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
select
  student.student_id,
  target_slots.id,
  103,
  'manual-thursday-p5-university-counselling-all-students'
from public.students as student
cross join target_slots
on conflict (student_id, slot_id) do update
set
  course_id = excluded.course_id,
  source = excluded.source;

commit;