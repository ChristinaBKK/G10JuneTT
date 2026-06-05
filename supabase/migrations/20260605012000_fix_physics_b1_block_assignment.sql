begin;

-- Physics B-1 is a Block B course. A few imported rows and slot offerings
-- accidentally placed it in Block C, which made the admin course editor show
-- it under the wrong block for affected students.

update public.student_enrollments as enrollment
set block_code = 'B'
from public.courses as course
where course.id = enrollment.course_id
  and course.name = 'Physics B-1'
  and enrollment.block_code = 'C';

delete from public.timetable_slot_courses as slot_course
using public.courses as course,
      public.timetable_slots as slot
where course.id = slot_course.course_id
  and slot.id = slot_course.slot_id
  and course.name = 'Physics B-1'
  and slot.slot_order in (
    6108, 6109, 6116, 6117, 6153, 6154, 6161, 6162,
    6178, 6179, 6186, 6187, 6293, 6294
  );

select public.sync_student_slot_assignments_for_student(enrollment.student_id)
from public.student_enrollments as enrollment
join public.courses as course
  on course.id = enrollment.course_id
where course.name = 'Physics B-1';

commit;
