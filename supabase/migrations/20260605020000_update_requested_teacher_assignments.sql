begin;

-- Requested teacher reassignment:
--   English E-7 - ESL 3: Cordelia Jiao -> Kelly Ding
--   Physics B-1: Chester Lim -> Raufie Shafie
--   Physics D: Raufie Shafie -> Chester Lim

update public.courses
set default_teacher = 'Kelly Ding'
where name = 'English E-7 - ESL 3';

update public.timetable_slot_courses as slot_course
set override_teacher = 'Kelly Ding'
from public.courses as course
where course.id = slot_course.course_id
  and course.name = 'English E-7 - ESL 3';

update public.timetable_slot_courses as slot_course
set override_teacher = 'Raufie Shafie'
from public.courses as course
where course.id = slot_course.course_id
  and course.name = 'Physics B-1';

update public.timetable_slot_courses as slot_course
set override_teacher = 'Chester Lim'
from public.courses as course
where course.id = slot_course.course_id
  and course.name = 'Physics D';

commit;
