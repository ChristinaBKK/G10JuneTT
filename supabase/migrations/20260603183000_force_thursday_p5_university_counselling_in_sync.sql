begin;

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
        public.block_code_for_course_name(course.name) as explicit_block_code,
        coalesce(
          public.block_code_for_course_name(course.name),
          (
            select enrollment_block.block_code
            from public.student_enrollments as enrollment_block
            where enrollment_block.course_id = course.id
              and enrollment_block.block_code is not null
            group by enrollment_block.block_code
            order by count(*) desc, enrollment_block.block_code asc
            limit 1
          )
        ) as block_code
      from public.timetable_slot_courses as slot_course
      join public.courses as course
        on course.id = slot_course.course_id
      where slot_course.slot_id = slot.id
    ),
    preferred_block as (
      select block_candidates.block_code
      from (
        select
          slot_offer.explicit_block_code as block_code,
          count(*) as block_count,
          min(slot_offer.display_order) as first_display_order,
          0 as priority
        from slot_offers as slot_offer
        where slot_offer.explicit_block_code is not null
        group by slot_offer.explicit_block_code

        union all

        select
          slot_offer.block_code as block_code,
          count(*) as block_count,
          min(slot_offer.display_order) as first_display_order,
          1 as priority
        from slot_offers as slot_offer
        where slot_offer.block_code is not null
        group by slot_offer.block_code
      ) as block_candidates
      order by
        block_candidates.priority,
        block_candidates.block_count desc,
        block_candidates.first_display_order asc,
        block_candidates.block_code asc
      limit 1
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
    block_offer as (
      select enrollment.course_id
      from public.student_enrollments as enrollment
      join preferred_block as preferred
        on preferred.block_code = enrollment.block_code
      join slot_offers as slot_offer
        on slot_offer.course_id = enrollment.course_id
      where enrollment.student_id = student.student_id
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
      case
        when slot.grade_level = 'G10'
         and slot.day_name = 'Thursday'
         and slot.start_period_id = 'P5'
         and slot.end_period_id = 'P5'
         and slot.term_name >= '2026-06-10'
         and slot.term_name <= '2026-06-29'
        then 103
        when exists (select 1 from preferred_block)
        then (
          select block_offer.course_id
          from block_offer
          limit 1
        )
        else (
          select enrolled_offer.course_id
          from enrolled_offer
          limit 1
        )
      end
    ) as course_id
  ) as resolved
    on resolved.course_id is not null
  where student.student_id = target_student_id
  on conflict (student_id, slot_id) do nothing;
end;
$$;

commit;