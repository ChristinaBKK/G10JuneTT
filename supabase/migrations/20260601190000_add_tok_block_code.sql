begin;

alter table public.students
  add column if not exists tok_block_code text
    check (tok_block_code is null or tok_block_code in ('A', 'B', 'C', 'D', 'E', 'F'));

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
    preferred_block as (
      select slot_offer.block_code
      from slot_offers as slot_offer
      where slot_offer.block_code is not null
      order by slot_offer.display_order
      limit 1
    ),
    enrolled_offer as (
      select enrollment.course_id
      from public.student_enrollments as enrollment
      join slot_offers as slot_offer
        on slot_offer.course_id = enrollment.course_id
      where enrollment.student_id = student.student_id
      order by slot_offer.display_order
      limit 1
    ),
    block_offer as (
      select enrollment.course_id
      from public.student_enrollments as enrollment
      join preferred_block as block
        on block.block_code = enrollment.block_code
      where enrollment.student_id = student.student_id
      limit 1
    ),
    fallback_non_cas as (
      select slot_offer.course_id
      from slot_offers as slot_offer
      where slot_offer.name !~* '^CAS-'
      order by slot_offer.display_order
      limit 1
    )
    select coalesce(
      case
        when exists (
          select 1
          from slot_offers
          where name = 'IB - TOK'
        )
        and upper(coalesce(student.program, '')) = 'IB'
        and coalesce(student.has_tok, true)
        and coalesce(student.tok_block_code, 'C') = coalesce((select preferred_block.block_code from preferred_block), 'C')
        then (
          select course.id
          from public.courses as course
          where course.name = coalesce(student.tok_course, 'IB - TOK')
          limit 1
        )
      end,
      case
        when exists (
          select 1
          from slot_offers
          where block_code is not null
        )
        then (
          select block_offer.course_id
          from block_offer
          limit 1
        )
      end,
      (
        select enrolled_offer.course_id
        from enrolled_offer
        limit 1
      ),
      case
        when exists (
          select 1
          from slot_offers
          where block_code is not null
        )
        then (
          select slot_offer.course_id
          from slot_offers as slot_offer
          where slot_offer.block_code is not null
          order by slot_offer.display_order
          limit 1
        )
      end,
      (
        select fallback_non_cas.course_id
        from fallback_non_cas
        limit 1
      ),
      (
        select slot_offer.course_id
        from slot_offers as slot_offer
        order by slot_offer.display_order
        limit 1
      )
    ) as course_id
  ) as resolved
    on resolved.course_id is not null
  where student.student_id = target_student_id;
end;
$$;

drop trigger if exists sync_student_slot_assignments_on_student_change on public.students;
create trigger sync_student_slot_assignments_on_student_change
after insert or update of program, has_tok, tok_course, tok_block_code on public.students
for each row
execute function public.sync_student_slot_assignments_from_student_change();

commit;