begin;

update public.courses
   set default_teacher = 'Teacher TBD'
 where name = 'House Activities';

commit;
