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
            'term_name', timetable.term_name,
            'day_name', timetable.day_name,
            'slot_order', timetable.slot_order,
            'start_period_id', timetable.start_period_id,
            'end_period_id', timetable.end_period_id,
            'course_name', timetable.course_name,
            'teacher', timetable.teacher,
            'room', timetable.room
          )
          order by
            timetable.term_name,
            case timetable.day_name
              when 'Monday' then 1
              when 'Tuesday' then 2
              when 'Wednesday' then 3
              when 'Thursday' then 4
              when 'Friday' then 5
              else 99
            end,
            timetable.slot_order,
            timetable.start_period_id,
            timetable.end_period_id,
            timetable.course_name
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

comment on function public.get_student_timetable_payload(text) is
  'Returns a single student timetable payload for public browser access without exposing base tables.';

commit;