begin;

with target_slot as (
  select id
  from public.timetable_slots
  where term_name = '2026-06-11'
    and grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
),
source_slot as (
  select id
  from public.timetable_slots
  where term_name = '2026-06-18'
    and grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
)
delete from public.timetable_slot_courses as target_courses
using target_slot
where target_courses.slot_id = target_slot.id;

with target_slot as (
  select id
  from public.timetable_slots
  where term_name = '2026-06-11'
    and grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
),
source_slot as (
  select id
  from public.timetable_slots
  where term_name = '2026-06-18'
    and grade_level = 'G10'
    and day_name = 'Thursday'
    and start_period_id = 'P5'
    and end_period_id = 'P5'
)
insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select
  target_slot.id,
  source_courses.course_id,
  source_courses.display_order,
  source_courses.override_teacher,
  source_courses.override_room
from public.timetable_slot_courses as source_courses
cross join source_slot
cross join target_slot
where source_courses.slot_id = source_slot.id;

select public.sync_all_student_slot_assignments();

commit;