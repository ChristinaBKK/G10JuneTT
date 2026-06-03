-- 20260603195000_update_chinese_b_and_ab_rooms.sql
--
-- Requested live room updates for Chinese classes:
--   Chinese A (Melody Chen)  -> B4010
--   Chinese B (Jenny Li/Ann Yang) -> B3010
--   Chinese AB (Ann Yang) -> B2036
--
-- Target slots by date/time:
--   2026-06-10 13:00-14:25 (P6, P7)
--   2026-06-12 10:45-11:25 (P4)
--   2026-06-17 13:00-14:25 (P6, P7)

begin;

with target_slots as (
  select id
  from public.timetable_slots
  where grade_level = 'G10'
    and (
      (term_name = '2026-06-10' and start_period_id in ('P6', 'P7') and end_period_id in ('P6', 'P7'))
      or (term_name = '2026-06-12' and start_period_id = 'P4' and end_period_id = 'P4')
      or (term_name = '2026-06-17' and start_period_id in ('P6', 'P7') and end_period_id in ('P6', 'P7'))
    )
),
target_courses as (
  select id, name
  from public.courses
  where name in ('Chinese A HL', 'Chinese A SL', 'Chinese B HL', 'Chinese B SL', 'Chinese AB SL')
)
update public.timetable_slot_courses as slot_course
set
  override_room = case
    when target_courses.name in ('Chinese A HL', 'Chinese A SL') then 'B4010'
    when target_courses.name in ('Chinese B HL', 'Chinese B SL') then 'B3010'
    when target_courses.name = 'Chinese AB SL' then 'B2036'
    else slot_course.override_room
  end,
  override_teacher = case
    when target_courses.name in ('Chinese A HL', 'Chinese A SL') then 'Melody Chen'
    when target_courses.name in ('Chinese B HL', 'Chinese B SL') then 'Jenny Li/Ann Yang'
    when target_courses.name = 'Chinese AB SL' then 'Ann Yang'
    else slot_course.override_teacher
  end
from target_slots, target_courses
where slot_course.slot_id = target_slots.id
  and slot_course.course_id = target_courses.id;

commit;

-- Verification (read-only, runs after commit).
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
where slot.grade_level = 'G10'
  and course.name in ('Chinese A HL', 'Chinese A SL', 'Chinese B HL', 'Chinese B SL', 'Chinese AB SL')
  and (
    (slot.term_name = '2026-06-10' and slot.start_period_id in ('P6', 'P7') and slot.end_period_id in ('P6', 'P7'))
    or (slot.term_name = '2026-06-12' and slot.start_period_id = 'P4' and slot.end_period_id = 'P4')
    or (slot.term_name = '2026-06-17' and slot.start_period_id in ('P6', 'P7') and slot.end_period_id in ('P6', 'P7'))
  )
order by slot.term_name, slot.start_period_id, course.name;