begin;

create or replace function public.import_student_roster_from_staging(target_import_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  imported_student_count integer := 0;
  inserted_enrollment_count integer := 0;
begin
  if not exists (
    select 1
    from public.student_roster_staging
    where import_batch_id = target_import_batch_id
  ) then
    raise exception 'No staged roster rows found for import batch %', target_import_batch_id;
  end if;

  insert into public.courses (name, default_teacher, default_room)
  select distinct
    staged.raw_cohort,
    null,
    null
  from public.student_roster_staging as staged
  where staged.import_batch_id = target_import_batch_id
  on conflict (name) do nothing;

  with staged_students as (
    select
      staged.student_id,
      min(public.parse_student_full_name(staged.raw_student, staged.student_id)) as full_name,
      min(public.normalise_student_program(staged.raw_program)) as program,
      bool_or(staged.raw_block ~* '^C/3(?:-[12])?$' and staged.raw_cohort ~* 'TOK') as has_tok,
      min(staged.raw_cohort) filter (where staged.raw_block ~* '^C/3(?:-[12])?$' and staged.raw_cohort ~* 'TOK') as tok_course,
      min(upper((regexp_match(staged.raw_block, '^([A-F])'))[1])) filter (where staged.raw_block ~* '^C/3(?:-[12])?$' and staged.raw_cohort ~* 'TOK') as tok_block_code
    from public.student_roster_staging as staged
    where staged.import_batch_id = target_import_batch_id
    group by staged.student_id
  ),
  upserted_students as (
    insert into public.students (student_id, full_name, program, has_tok, tok_course, tok_block_code)
    select
      staged_students.student_id,
      staged_students.full_name,
      staged_students.program,
      staged_students.has_tok,
      staged_students.tok_course,
      staged_students.tok_block_code
    from staged_students
    on conflict (student_id) do update
    set full_name = excluded.full_name,
        program = excluded.program,
        has_tok = excluded.has_tok,
        tok_course = excluded.tok_course,
        tok_block_code = excluded.tok_block_code
    returning student_id
  )
  select count(*) into imported_student_count
  from upserted_students;

  delete from public.student_enrollments as enrollment
  using (
    select distinct staged.student_id
    from public.student_roster_staging as staged
    where staged.import_batch_id = target_import_batch_id
  ) as imported_students
  where enrollment.student_id = imported_students.student_id;

  with raw_enrollments as (
    select distinct on (
      staged.student_id,
      course.id
    )
      staged.student_id,
      course.id as course_id,
      case
        when public.normalise_student_program(staged.raw_program) = 'IB'
          and staged.raw_block ~* '^F/6$'
          and staged.raw_cohort !~* '^PE-'
        then null::text
        else upper((regexp_match(staged.raw_block, '^([A-F])'))[1])
      end as block_code,
      case
        when public.normalise_student_program(staged.raw_program) = 'IB'
          and staged.raw_block ~* '^F/6$'
          and staged.raw_cohort !~* '^PE-'
        then 1
        else 0
      end as precedence
    from public.student_roster_staging as staged
    join public.courses as course
      on course.name = staged.raw_cohort
    where staged.import_batch_id = target_import_batch_id
      and not (staged.raw_block ~* '^C/3(?:-[12])?$' and staged.raw_cohort ~* 'TOK')
    order by staged.student_id,
      course.id,
      precedence,
      staged.row_number
  ),
  tok_enrollments as (
    select distinct on (staged.student_id)
      staged.student_id,
      course.id as course_id,
      null::text as block_code
    from public.student_roster_staging as staged
    join public.courses as course
      on course.name = staged.raw_cohort
    where staged.import_batch_id = target_import_batch_id
      and staged.raw_block ~* '^C/3(?:-[12])?$'
      and staged.raw_cohort ~* 'TOK'
    order by staged.student_id, staged.row_number
  ),
  inserted_rows as (
    insert into public.student_enrollments (student_id, course_id, block_code)
    select student_id, course_id, block_code from raw_enrollments
    union all
    select student_id, course_id, block_code from tok_enrollments
    returning 1
  )
  select count(*) into inserted_enrollment_count
  from inserted_rows;

  delete from public.student_roster_staging
  where import_batch_id = target_import_batch_id;

  return jsonb_build_object(
    'students', imported_student_count,
    'enrollments', inserted_enrollment_count
  );
end;
$$;

alter function public.import_student_roster_from_staging(uuid) set statement_timeout = '0';

commit;