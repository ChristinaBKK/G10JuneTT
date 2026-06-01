begin;

create or replace function public.sync_all_student_slot_assignments()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student record;
  synced_count integer := 0;
begin
  for current_student in
    select student_id
    from public.students
    order by student_id
  loop
    perform public.sync_student_slot_assignments_for_student(current_student.student_id);
    synced_count := synced_count + 1;
  end loop;

  return synced_count;
end;
$$;

comment on function public.sync_all_student_slot_assignments() is
  'Regenerates derived student_slot_assignments for every student from student_enrollments and student scheduling metadata.';

commit;