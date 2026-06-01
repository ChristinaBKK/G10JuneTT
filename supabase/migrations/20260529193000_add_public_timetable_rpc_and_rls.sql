begin;

create or replace function public.get_student_timetable_payload(p_student_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  student_record public.students%rowtype;
begin
  select *
  into student_record
  from public.students
  where student_id = p_student_id;

  return jsonb_build_object(
    'student',
    case
      when student_record.student_id is null then null
      else jsonb_build_object(
        'student_id', student_record.student_id,
        'full_name', student_record.full_name
      )
    end,
    'periods', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', periods.id,
            'label', periods.label,
            'sort_order', periods.sort_order
          )
          order by periods.sort_order
        ),
        '[]'::jsonb
      )
      from public.periods as periods
    ),
    'entries', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'day_name', timetable.day_name,
            'slot_order', timetable.slot_order,
            'start_period_id', timetable.start_period_id,
            'end_period_id', timetable.end_period_id,
            'course_name', timetable.course_name,
            'teacher', timetable.teacher,
            'room', timetable.room
          )
          order by timetable.slot_order
        ),
        '[]'::jsonb
      )
      from public.student_timetable_entries as timetable
      where timetable.student_id = p_student_id
    )
  );
end;
$$;

revoke all on function public.get_student_timetable_payload(text) from public;
grant execute on function public.get_student_timetable_payload(text) to anon;
grant execute on function public.get_student_timetable_payload(text) to authenticated;
grant execute on function public.get_student_timetable_payload(text) to service_role;

alter table public.periods enable row level security;
alter table public.courses enable row level security;
alter table public.timetable_slots enable row level security;
alter table public.timetable_slot_courses enable row level security;
alter table public.students enable row level security;
alter table public.student_enrollments enable row level security;

revoke all on public.periods from anon, authenticated;
revoke all on public.courses from anon, authenticated;
revoke all on public.timetable_slots from anon, authenticated;
revoke all on public.timetable_slot_courses from anon, authenticated;
revoke all on public.students from anon, authenticated;
revoke all on public.student_enrollments from anon, authenticated;

drop policy if exists "service role full access periods" on public.periods;
create policy "service role full access periods"
on public.periods
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role full access courses" on public.courses;
create policy "service role full access courses"
on public.courses
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role full access timetable slots" on public.timetable_slots;
create policy "service role full access timetable slots"
on public.timetable_slots
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role full access timetable slot courses" on public.timetable_slot_courses;
create policy "service role full access timetable slot courses"
on public.timetable_slot_courses
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role full access students" on public.students;
create policy "service role full access students"
on public.students
for all
to service_role
using (true)
with check (true);

drop policy if exists "service role full access student enrollments" on public.student_enrollments;
create policy "service role full access student enrollments"
on public.student_enrollments
for all
to service_role
using (true)
with check (true);

comment on function public.get_student_timetable_payload(text) is
  'Returns a single student timetable payload for public browser access without exposing base tables.';

commit;