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
      with candidate_entries as (
        select distinct on (timetable.day_name, timetable.start_period_id, timetable.end_period_id)
          timetable.day_name,
          timetable.start_period_id,
          timetable.end_period_id,
          timetable.slot_order,
          timetable.term_name,
          timetable.course_name,
          timetable.teacher,
          timetable.room,
          start_period.sort_order as start_period_sort_order,
          case timetable.day_name
            when 'Monday' then 1
            when 'Tuesday' then 2
            when 'Wednesday' then 3
            when 'Thursday' then 4
            when 'Friday' then 5
            else 99
          end as day_sort
        from public.student_timetable_entries as timetable
        join public.timetable_slots as slot
          on slot.term_name = timetable.term_name
         and slot.grade_level = timetable.grade_level
         and slot.day_name = timetable.day_name
         and slot.start_period_id = timetable.start_period_id
         and slot.end_period_id = timetable.end_period_id
         and slot.slot_order = timetable.slot_order
        join public.periods as start_period
          on start_period.id = timetable.start_period_id
        left join public.student_slot_assignments as assignment
          on assignment.student_id = timetable.student_id
         and assignment.slot_id = slot.id
        where timetable.student_id = p_student_id
        order by
          timetable.day_name,
          timetable.start_period_id,
          timetable.end_period_id,
          case when assignment.student_id is not null then 0 else 1 end,
          timetable.term_name desc,
          timetable.course_name asc
      )
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'term_name', candidate_entries.term_name,
            'day_name', candidate_entries.day_name,
            'slot_order', candidate_entries.slot_order,
            'start_period_id', candidate_entries.start_period_id,
            'end_period_id', candidate_entries.end_period_id,
            'course_name', candidate_entries.course_name,
            'teacher', candidate_entries.teacher,
            'room', candidate_entries.room
          )
          order by candidate_entries.day_sort, candidate_entries.start_period_sort_order
        ),
        '[]'::jsonb
      )
      from candidate_entries
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