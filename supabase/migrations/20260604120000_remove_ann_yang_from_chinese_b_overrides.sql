-- 20260604120000_remove_ann_yang_from_chinese_b_overrides.sql
--
-- Remove Ann Yang from the targeted Chinese B HL / Chinese B SL timetable
-- overrides so those rows show Jenny Li as the teacher.

begin;

with target_rows as (
  select course.id as course_id
  from public.courses as course
  where course.name in ('Chinese B HL', 'Chinese B SL')
)
update public.timetable_slot_courses as slot_course
set override_teacher = 'Jenny Li'
from target_rows
where slot_course.course_id = target_rows.course_id
  and slot_course.override_teacher = 'Jenny Li/Ann Yang';

commit;

select
  slot.term_name,
  slot.day_name,
  slot.start_period_id,
  slot.end_period_id,
  course.name as course_name,
  slot_course.override_teacher,
  slot_course.override_room
from public.timetable_slot_courses as slot_course
join public.timetable_slots as slot
  on slot.id = slot_course.slot_id
join public.courses as course
  on course.id = slot_course.course_id
where course.name in ('Chinese B HL', 'Chinese B SL')
  and slot_course.override_teacher = 'Jenny Li'
order by slot.term_name, slot.start_period_id, course.name;