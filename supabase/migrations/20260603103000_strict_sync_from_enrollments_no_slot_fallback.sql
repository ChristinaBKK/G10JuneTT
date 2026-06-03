begin;

-- Make derived slot assignment strict: do not auto-pick arbitrary slot offers
-- when a student has no matching enrollment for that slot.
create or replace function public.sync_student_slot_assignments_for_student(target_student_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.student_slot_assignments
  where student_id = target_student_id
    and source in ('generated-june-2026-block-assignments', 'synced-from-enrollments');

  if not exists (
    select 1
    from public.students
    where student_id = target_student_id
  ) then
    return;
  end if;

  insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
  select
    student.student_id,
    slot.id,
    resolved.course_id,
    'synced-from-enrollments'
  from public.students as student
  join public.timetable_slots as slot
    on true
  join lateral (
    with slot_offers as (
      select
        slot_course.display_order,
        slot_course.course_id,
        course.name,
        public.block_code_for_course_name(course.name) as block_code
      from public.timetable_slot_courses as slot_course
      join public.courses as course
        on course.id = slot_course.course_id
      where slot_course.slot_id = slot.id
    ),
    tok_offer as (
      select
        slot_offer.course_id,
        slot_offer.block_code
      from slot_offers as slot_offer
      where slot_offer.name = coalesce(nullif(student.tok_course, ''), 'IB - TOK')
      order by slot_offer.display_order
      limit 1
    ),
    enrolled_offer as (
      select slot_offer.course_id
      from slot_offers as slot_offer
      join public.student_enrollments as enrollment
        on enrollment.course_id = slot_offer.course_id
       and enrollment.student_id = student.student_id
      order by slot_offer.display_order
      limit 1
    )
    select coalesce(
      case
        when upper(coalesce(student.program, '')) = 'IB'
         and coalesce(student.has_tok, true)
         and exists (select 1 from tok_offer)
         and coalesce(student.tok_block_code, 'C') = coalesce((select tok_offer.block_code from tok_offer), 'C')
        then (
          select tok_offer.course_id
          from tok_offer
          limit 1
        )
      end,
      (
        select enrolled_offer.course_id
        from enrolled_offer
        limit 1
      )
    ) as course_id
  ) as resolved
    on resolved.course_id is not null
  where student.student_id = target_student_id
  on conflict (student_id, slot_id) do nothing;
end;
$$;

-- Reassert enrollment-change trigger coverage for INSERT/UPDATE/DELETE.
drop trigger if exists sync_student_slot_assignments_on_enrollment_change on public.student_enrollments;
create trigger sync_student_slot_assignments_on_enrollment_change
after insert or update or delete on public.student_enrollments
for each row
execute function public.sync_student_slot_assignments_from_enrollment_change();

commit;