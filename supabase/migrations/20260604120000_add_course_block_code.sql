begin;

alter table public.courses
  add column if not exists block_code text
    check (block_code is null or block_code in ('A', 'B', 'C', 'D', 'E', 'F'));

update public.courses as course
set block_code = coalesce(
  public.block_code_for_course_name(course.name),
  (
    select enrollment.block_code
    from public.student_enrollments as enrollment
    where enrollment.course_id = course.id
      and enrollment.block_code is not null
    group by enrollment.block_code
    order by count(*) desc, enrollment.block_code asc
    limit 1
  )
)
where course.block_code is null;

commit;
