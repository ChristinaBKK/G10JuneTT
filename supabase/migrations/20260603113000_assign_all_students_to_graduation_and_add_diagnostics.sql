begin;

-- Ensure the graduation slot is explicitly assigned for every student.
-- Course id 100 = 'Graduation parade', slot id 57 = 2026-06-12 Friday P6.
insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
select
  student.student_id,
  57,
  100,
  'manual-graduation-ceremony-all-students'
from public.students as student
on conflict (student_id, slot_id) do update
set
  course_id = excluded.course_id,
  source = excluded.source;

-- Detailed diagnostics by student + slot based on enrollment-vs-offered matching.
create or replace view public.student_enrollment_slot_diagnostics as
with enrollment_matches as (
  select
    student.student_id,
    student.full_name,
    slot.id as slot_id,
    slot.term_name,
    slot.grade_level,
    slot.day_name,
    slot.start_period_id,
    slot.end_period_id,
    count(distinct enrollment.course_id) as matched_course_count,
    coalesce(
      array_agg(distinct course.name order by course.name)
        filter (where enrollment.course_id is not null),
      array[]::text[]
    ) as matched_course_names
  from public.students as student
  cross join public.timetable_slots as slot
  left join public.timetable_slot_courses as slot_course
    on slot_course.slot_id = slot.id
  left join public.student_enrollments as enrollment
    on enrollment.student_id = student.student_id
   and enrollment.course_id = slot_course.course_id
  left join public.courses as course
    on course.id = enrollment.course_id
  group by
    student.student_id,
    student.full_name,
    slot.id,
    slot.term_name,
    slot.grade_level,
    slot.day_name,
    slot.start_period_id,
    slot.end_period_id
)
select
  student_id,
  full_name,
  slot_id,
  term_name,
  grade_level,
  day_name,
  start_period_id,
  end_period_id,
  matched_course_count,
  matched_course_names,
  case
    when matched_course_count = 0 then 'missing'
    when matched_course_count > 1 then 'duplicate'
  end as issue_type
from enrollment_matches
where matched_course_count = 0
   or matched_course_count > 1;

-- Summary diagnostics per student for quick auditing.
create or replace view public.student_enrollment_diagnostic_summary as
select
  diagnostics.student_id,
  max(diagnostics.full_name) as full_name,
  count(*) filter (where diagnostics.issue_type = 'duplicate') as duplicate_slot_conflicts,
  count(*) filter (where diagnostics.issue_type = 'missing') as missing_slot_gaps
from public.student_enrollment_slot_diagnostics as diagnostics
group by diagnostics.student_id;

-- Helper function for querying diagnostics (all students or one student).
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
  'Detailed audit rows where a student has either zero offered enrolled courses (missing) or more than one (duplicate) for a slot.';

comment on view public.student_enrollment_diagnostic_summary is
  'Per-student counts of duplicate-slot conflicts and missing-slot gaps based on enrollment-vs-slot-offering matching.';

comment on function public.get_student_enrollment_slot_diagnostics(text) is
  'Returns enrollment diagnostics rows for one student (or all students when null).';

commit;