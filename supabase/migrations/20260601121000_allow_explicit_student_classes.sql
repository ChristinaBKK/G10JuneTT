begin;

create or replace view public.student_timetable_entries as
with explicit_entries as (
  select
    student.student_id,
    student.full_name,
    slot.term_name,
    slot.grade_level,
    slot.day_name,
    slot.slot_order,
    slot.start_period_id,
    slot.end_period_id,
    start_period.sort_order as start_period_order,
    end_period.sort_order as end_period_order,
    course.name as course_name,
    coalesce(slot_course.override_teacher, course.default_teacher) as teacher,
    coalesce(slot_course.override_room, course.default_room) as room
  from public.student_slot_assignments as assignment
  join public.students as student
    on student.student_id = assignment.student_id
  join public.timetable_slots as slot
    on slot.id = assignment.slot_id
  left join public.timetable_slot_courses as slot_course
    on slot_course.slot_id = assignment.slot_id
   and slot_course.course_id = assignment.course_id
  join public.courses as course
    on course.id = assignment.course_id
  join public.periods as start_period
    on start_period.id = slot.start_period_id
  join public.periods as end_period
    on end_period.id = slot.end_period_id
),
derived_entries as (
  select
    student.student_id,
    student.full_name,
    slot.term_name,
    slot.grade_level,
    slot.day_name,
    slot.slot_order,
    slot.start_period_id,
    slot.end_period_id,
    start_period.sort_order as start_period_order,
    end_period.sort_order as end_period_order,
    course.name as course_name,
    coalesce(slot_course.override_teacher, course.default_teacher) as teacher,
    coalesce(slot_course.override_room, course.default_room) as room
  from public.student_enrollments as enrollment
  join public.students as student
    on student.student_id = enrollment.student_id
  join public.timetable_slot_courses as slot_course
    on slot_course.course_id = enrollment.course_id
  join public.timetable_slots as slot
    on slot.id = slot_course.slot_id
  join public.courses as course
    on course.id = enrollment.course_id
  join public.periods as start_period
    on start_period.id = slot.start_period_id
  join public.periods as end_period
    on end_period.id = slot.end_period_id
  where not exists (
    select 1
    from public.student_slot_assignments as assignment
    where assignment.student_id = enrollment.student_id
      and assignment.slot_id = slot.id
  )
)
select * from explicit_entries
union all
select * from derived_entries;

commit;