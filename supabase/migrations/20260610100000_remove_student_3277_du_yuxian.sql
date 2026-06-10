begin;

delete from public.student_roster_staging
where student_id = '3277'
   or raw_student ilike '%DU YUXIAN%'
   or raw_student ilike '%Derrick%';

delete from public.students
where student_id = '3277';

commit;
