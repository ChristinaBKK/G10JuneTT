begin;

create table if not exists public.student_roster_staging (
  import_batch_id uuid not null,
  row_number integer not null,
  raw_block text not null,
  raw_program text not null,
  raw_cohort text not null,
  raw_tid text,
  raw_no text,
  raw_student text not null,
  student_id text not null,
  created_at timestamptz not null default now(),
  primary key (import_batch_id, row_number)
);

create index if not exists student_roster_staging_batch_student_idx
  on public.student_roster_staging (import_batch_id, student_id);

alter table public.student_roster_staging enable row level security;

create or replace function public.normalise_student_program(raw_program text)
returns text
language sql
immutable
as $$
  select case upper(trim(coalesce(raw_program, '')))
    when 'IBDP' then 'IB'
    when 'CAIE' then 'CAIE'
    else coalesce(nullif(upper(trim(coalesce(raw_program, ''))), ''), 'CAIE')
  end;
$$;

create or replace function public.parse_student_full_name(raw_student text, sid text)
returns text
language sql
immutable
as $$
  select case
    when trim(coalesce(raw_student, '')) = '' then trim(coalesce(sid, ''))
    when sid is not null and raw_student like sid || '-%' then trim(substr(raw_student, char_length(sid) + 2))
    else trim(regexp_replace(coalesce(raw_student, ''), '^\d+-', ''))
  end;
$$;

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

  with block_enrollments as (
    select distinct on (
      staged.student_id,
      upper((regexp_match(staged.raw_block, '^([A-F])'))[1])
    )
      staged.student_id,
      course.id as course_id,
      upper((regexp_match(staged.raw_block, '^([A-F])'))[1]) as block_code
    from public.student_roster_staging as staged
    join public.courses as course
      on course.name = staged.raw_cohort
    where staged.import_batch_id = target_import_batch_id
      and not (staged.raw_block ~* '^C/3(?:-[12])?$' and staged.raw_cohort ~* 'TOK')
    order by staged.student_id,
      upper((regexp_match(staged.raw_block, '^([A-F])'))[1]),
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
    select * from block_enrollments
    union all
    select * from tok_enrollments
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

commit;