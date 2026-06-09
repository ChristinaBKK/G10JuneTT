begin;

update public.courses
   set default_teacher = 'Alex Varley',
       default_room = 'B3005'
 where name = 'Chemistry D';

update public.timetable_slot_courses
   set override_teacher = null,
       override_room = null
 where course_id = (
   select id
   from public.courses
   where name = 'Chemistry D'
   limit 1
 );

commit;
