begin;

alter function public.import_student_roster_from_staging(uuid) set statement_timeout = '0';

commit;