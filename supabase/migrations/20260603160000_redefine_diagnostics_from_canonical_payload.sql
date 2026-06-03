begin;

create or replace view public.student_enrollment_slot_diagnostics as
with payload_entries as (
  select
    student.student_id,
    student.full_name,
    payload_entry.term_name,
    payload_entry.day_name,
    payload_entry.start_period_id,
    payload_entry.end_period_id,
    payload_entry.course_name,
    payload_entry.teacher,
    payload_entry.room
  from public.students as student
  cross join lateral public.get_student_timetable_payload(student.student_id) as payload(payload)
  cross join lateral jsonb_to_recordset(coalesce(payload.payload->'entries', '[]'::jsonb)) as payload_entry(
    term_name text,
    day_name text,
    start_period_id text,
    end_period_id text,
    course_name text,
    teacher text,
    room text
  )
),
duplicate_entries as (
  select
    student_id,
    full_name,
    null::bigint as slot_id,
    term_name,
    null::text as grade_level,
    day_name,
    start_period_id,
    end_period_id,
    count(*) as matched_course_count,
    coalesce(array_agg(course_name order by course_name), array[]::text[]) as matched_course_names,
    'duplicate'::text as issue_type
  from payload_entries
  group by
    student_id,
    full_name,
    term_name,
    day_name,
    start_period_id,
    end_period_id
  having count(*) > 1
),
offered_courses as (
  select distinct course_id
  from public.timetable_slot_courses
),
missing_enrollments as (
  select
    student.student_id,
    student.full_name,
    null::bigint as slot_id,
    null::text as term_name,
    null::text as grade_level,
    null::text as day_name,
    null::text as start_period_id,
    null::text as end_period_id,
    0::bigint as matched_course_count,
    array[course.name]::text[] as matched_course_names,
    'missing'::text as issue_type
  from public.students as student
  join public.student_enrollments as enrollment
    on enrollment.student_id = student.student_id
  join offered_courses as offered
    on offered.course_id = enrollment.course_id
  join public.courses as course
    on course.id = enrollment.course_id
  where not exists (
    select 1
    from payload_entries as payload_entry
    where payload_entry.student_id = student.student_id
      and payload_entry.course_name = course.name
  )
)
select * from duplicate_entries
union all
select * from missing_enrollments;

create or replace view public.student_enrollment_diagnostic_summary as
select
  student.student_id,
  student.full_name,
  count(*) filter (where diagnostics.issue_type = 'duplicate') as duplicate_slot_conflicts,
  count(*) filter (where diagnostics.issue_type = 'missing') as missing_slot_gaps
from public.students as student
left join public.student_enrollment_slot_diagnostics as diagnostics
  on diagnostics.student_id = student.student_id
group by student.student_id, student.full_name;

create or replace function public.get_student_enrollment_slot_diagnostics(target_student_id text default null)
returns table (
  student_id text,
  full_name text,
  slot_id bigint,
  term_name text,
  grade_level text,
  day_name text,
  start_period_id text,
  end_period_id text,
  matched_course_count bigint,
  matched_course_names text[],
  issue_type text
)
language sql
stable
as $$
  select
    diagnostics.student_id,
    diagnostics.full_name,
    diagnostics.slot_id,
    diagnostics.term_name,
    diagnostics.grade_level,
    diagnostics.day_name,
    diagnostics.start_period_id,
    diagnostics.end_period_id,
    diagnostics.matched_course_count,
    diagnostics.matched_course_names,
    diagnostics.issue_type
  from public.student_enrollment_slot_diagnostics as diagnostics
  where target_student_id is null
     or diagnostics.student_id = target_student_id
  order by
    diagnostics.student_id,
    diagnostics.term_name,
    diagnostics.day_name,
    diagnostics.start_period_id,
    diagnostics.slot_id;
$$;

comment on view public.student_enrollment_slot_diagnostics is
  'Detailed audit rows for unresolved timetable issues based on the canonical public timetable payload.';

comment on view public.student_enrollment_diagnostic_summary is
  'Per-student counts of unresolved timetable conflicts and missing reflected enrollments based on the canonical public timetable payload.';

comment on function public.get_student_enrollment_slot_diagnostics(text) is
  'Returns canonical payload-based diagnostic rows for one student (or all students when null).';

commit;