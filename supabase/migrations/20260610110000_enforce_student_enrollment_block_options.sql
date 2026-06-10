begin;

do $$
begin
  alter table public.courses
    drop constraint if exists courses_block_code_check;

  alter table public.courses
    add constraint courses_block_code_check
    check (block_code is null or block_code in ('A', 'B', 'C', 'D', 'E', 'F', 'UC'));

  alter table public.student_enrollments
    drop constraint if exists student_enrollments_block_code_check;

  alter table public.student_enrollments
    add constraint student_enrollments_block_code_check
    check (block_code is null or block_code in ('A', 'B', 'C', 'D', 'E', 'F', 'UC'));
end $$;

create or replace function public.course_uses_non_block_enrollment(course_name text)
returns boolean
language sql
immutable
as $$
  select coalesce(btrim(course_name), '') in (
    'Chinese A HL',
    'Chinese A SL',
    'Chinese AB SL',
    'Chinese B HL',
    'Chinese B SL',
    'TOK (Group 1)',
    'TOK (Group 2)',
    'CAS (Group 1)',
    'CAS (Group 2)'
  );
$$;

create table if not exists public.course_block_options (
  course_id bigint not null references public.courses (id) on delete cascade,
  block_code text not null,
  source text not null default 'june-2026-canonical',
  created_at timestamptz not null default now(),
  primary key (course_id, block_code)
);

do $$
begin
  alter table public.course_block_options
    drop constraint if exists course_block_options_block_code_check;

  alter table public.course_block_options
    add constraint course_block_options_block_code_check
    check (block_code in ('A', 'B', 'C', 'D', 'E', 'F', 'UC'));
end $$;

create table if not exists public.timetable_slot_block_options (
  slot_order integer primary key,
  block_code text not null,
  source text not null default 'june-2026-canonical',
  created_at timestamptz not null default now()
);

do $$
begin
  alter table public.timetable_slot_block_options
    drop constraint if exists timetable_slot_block_options_block_code_check;

  alter table public.timetable_slot_block_options
    add constraint timetable_slot_block_options_block_code_check
    check (block_code in ('A', 'B', 'C', 'D', 'E', 'F', 'UC'));
end $$;

-- Rebuild the canonical course/block allow-list from the intended timetable.
-- This list is deliberately independent of student_enrollments, so a bad
-- student row cannot make an impossible course/block pair look valid.
delete from public.course_block_options;
delete from public.timetable_slot_block_options;

with canonical_options(course_name, block_code) as (
  values
    ('Math HL', 'A'),
    ('Math SL', 'A'),
    ('Regular Math A-1', 'A'),
    ('Regular Math A-2', 'A'),
    ('Physics A-1', 'A'),
    ('Chemistry A', 'A'),
    ('Economics A', 'A'),
    ('Chinese A', 'A'),
    ('Physics A-2 (Summit)', 'A'),
    ('Physics A-3', 'A'),
    ('Geography', 'A'),

    ('Physics B-1', 'B'),
    ('Physics B-2', 'B'),
    ('Biology', 'B'),
    ('Economics B-1', 'B'),
    ('Computer Science', 'B'),
    ('Music', 'B'),
    ('Chinese B', 'B'),
    ('Economics B-2 (Summit)', 'B'),
    ('Art & Design (Dual Dose)', 'B'),
    ('Economics HL', 'B'),
    ('Economics SL', 'B'),
    ('Biology HL', 'B'),
    ('Biology SL', 'B'),
    ('Theatre HL', 'B'),
    ('Theatre SL', 'B'),
    ('Physics HL', 'B'),
    ('Physics SL', 'B'),

    ('Physics HL', 'C'),
    ('Physics SL', 'C'),
    ('Chemistry HL', 'C'),
    ('Chemistry SL', 'C'),
    ('Biology HL', 'C'),
    ('Biology SL', 'C'),
    ('Regular Math C-1', 'C'),
    ('Regular Math C-2', 'C'),
    ('Further Math', 'C'),
    ('Advanced Math C (CIE)', 'C'),
    ('Chemistry C-1', 'C'),
    ('Economics C-1', 'C'),
    ('Business', 'C'),
    ('Chemistry C-2 (Summit)', 'C'),
    ('Economics C-2', 'C'),

    ('Regular Math D', 'D'),
    ('Fast Maths D (Edexcel)', 'D'),
    ('Advanced Math D (CIE)', 'D'),
    ('Physics D', 'D'),
    ('Chemistry D', 'D'),
    ('History', 'D'),
    ('Art & Design', 'D'),
    ('Chinese D-1', 'D'),
    ('Chinese D-2', 'D'),
    ('English A HL', 'D'),
    ('English A SL', 'D'),
    ('English B HL', 'D'),
    ('English B SL', 'D'),

    ('Economics HL', 'E'),
    ('Economics SL', 'E'),
    ('Business HL', 'E'),
    ('Business SL', 'E'),
    ('Philosophy HL', 'E'),
    ('Philosophy SL', 'E'),
    ('English E-1 - Honors', 'E'),
    ('English E-2 - L&L1', 'E'),
    ('English E-3 - L&L2', 'E'),
    ('English E-4 - L&L3', 'E'),
    ('English E-5 - ESL 1', 'E'),
    ('English E-6 - ESL 2', 'E'),
    ('English E-7 - ESL 3', 'E'),

    ('PE-1', 'F'),
    ('PE-2', 'F'),
    ('PE-3', 'F'),
    ('PE-4', 'F'),
    ('PE-5', 'F'),
    ('PE-6', 'F'),
    ('PE-7', 'F')
)
insert into public.course_block_options (course_id, block_code, source)
select distinct
  course.id,
  canonical_options.block_code,
  'june-2026-canonical'
from canonical_options
join public.courses as course
  on btrim(course.name) = canonical_options.course_name
where not public.course_uses_non_block_enrollment(course.name)
on conflict (course_id, block_code) do update
set source = excluded.source;

insert into public.course_block_options (course_id, block_code, source)
select distinct
  course.id,
  'UC',
  'june-2026-canonical'
from public.courses as course
where btrim(course.name) ~* '^UC-[0-9]+$'
on conflict (course_id, block_code) do update
set source = excluded.source;

with canonical_slot_blocks(slot_order, block_code) as (
  values
    (6101, 'A'), (6102, 'A'), (6122, 'A'), (6156, 'A'), (6157, 'A'),
    (6163, 'A'), (6164, 'A'), (6171, 'A'), (6172, 'A'), (6296, 'A'), (6297, 'A'),

    (6105, 'B'), (6106, 'B'), (6107, 'B'), (6118, 'B'), (6119, 'B'),
    (6123, 'B'), (6124, 'B'), (6158, 'B'), (6159, 'B'), (6175, 'B'),
    (6176, 'B'), (6177, 'B'), (6188, 'B'), (6189, 'B'), (6298, 'B'), (6299, 'B'),

    (6108, 'C'), (6109, 'C'), (6116, 'C'), (6117, 'C'), (6153, 'C'),
    (6154, 'C'), (6161, 'C'), (6162, 'C'), (6178, 'C'), (6179, 'C'),
    (6186, 'C'), (6187, 'C'), (6293, 'C'), (6294, 'C'),

    (6103, 'D'), (6104, 'D'), (6113, 'D'), (6114, 'D'), (6125, 'D'),
    (6155, 'D'), (6168, 'D'), (6169, 'D'), (6173, 'D'), (6174, 'D'),
    (6183, 'D'), (6184, 'D'), (6295, 'D'),

    (6111, 'E'), (6112, 'E'), (6121, 'E'), (6151, 'E'), (6152, 'E'),
    (6165, 'E'), (6181, 'E'), (6182, 'E'), (6185, 'E'), (6291, 'E'), (6292, 'E'),

    (6127, 'F'), (6128, 'F'), (6166, 'F'), (6167, 'F'),

    (6115, 'UC')
)
insert into public.timetable_slot_block_options (slot_order, block_code, source)
select slot_order, block_code, 'june-2026-canonical'
from canonical_slot_blocks
on conflict (slot_order) do update
set block_code = excluded.block_code,
    source = excluded.source;

with option_counts as (
  select
    option.course_id,
    count(distinct option.block_code) as block_count,
    min(option.block_code) as only_block_code
  from public.course_block_options as option
  group by option.course_id
)
update public.courses as course
set block_code = case
  when option_counts.block_count = 1 then option_counts.only_block_code
  else null
end
from option_counts
where course.id = option_counts.course_id;

update public.courses
set block_code = null
where public.course_uses_non_block_enrollment(name);

-- Chinese B is a Block B CIE course. It should not appear in Block C slots.
delete from public.student_slot_assignments as assignment
using public.courses as course,
      public.timetable_slots as slot
where course.id = assignment.course_id
  and slot.id = assignment.slot_id
  and btrim(course.name) = 'Chinese B'
  and slot.slot_order in (
    6108, 6109, 6116, 6117, 6153, 6154, 6161, 6162,
    6178, 6179, 6186, 6187, 6293, 6294
  );

delete from public.timetable_slot_courses as slot_course
using public.courses as course,
      public.timetable_slots as slot
where course.id = slot_course.course_id
  and slot.id = slot_course.slot_id
  and btrim(course.name) = 'Chinese B'
  and slot.slot_order in (
    6108, 6109, 6116, 6117, 6153, 6154, 6161, 6162,
    6178, 6179, 6186, 6187, 6293, 6294
  );

-- UC-## courses are student counseling buckets for the UC block. They should
-- not appear as offers or assignments inside academic A-F block slots.
delete from public.student_slot_assignments as assignment
using public.courses as course,
      public.timetable_slots as slot
where course.id = assignment.course_id
  and slot.id = assignment.slot_id
  and btrim(course.name) ~* '^UC-[0-9]+$'
  and slot.slot_order is distinct from 6115;

delete from public.timetable_slot_courses as slot_course
using public.courses as course,
      public.timetable_slots as slot
where course.id = slot_course.course_id
  and slot.id = slot_course.slot_id
  and btrim(course.name) ~* '^UC-[0-9]+$'
  and slot.slot_order is distinct from 6115;

create or replace function public.timetable_slot_block_code(target_slot_order integer)
returns text
language sql
stable
as $$
  select block_code
  from public.timetable_slot_block_options
  where slot_order = target_slot_order
  limit 1;
$$;

create or replace function public.course_is_valid_for_block(target_course_id bigint, target_block_code text)
returns boolean
language sql
stable
as $$
  with requested as (
    select upper(trim(coalesce(target_block_code, ''))) as block_code
  ),
  target_course as (
    select course.id, course.name
    from public.courses as course
    where course.id = target_course_id
  )
  select case
    when (select block_code from requested) = '' then true
    when not exists (select 1 from target_course) then false
    when exists (
      select 1
      from target_course
      where public.course_uses_non_block_enrollment(target_course.name)
    ) then false
    when exists (
      select 1
      from public.course_block_options as option
      join requested
        on requested.block_code = option.block_code
      where option.course_id = target_course_id
    ) then true
    else false
  end;
$$;

create or replace function public.timetable_slot_course_is_valid(target_slot_id bigint, target_course_id bigint)
returns boolean
language sql
stable
as $$
  with target_slot as (
    select
      slot.id,
      public.timetable_slot_block_code(slot.slot_order) as block_code
    from public.timetable_slots as slot
    where slot.id = target_slot_id
  )
  select case
    when not exists (select 1 from target_slot) then false
    when not exists (select 1 from public.courses where id = target_course_id) then false
    when not exists (select 1 from public.course_block_options where course_id = target_course_id) then true
    when (select block_code from target_slot) is null then true
    when exists (
      select 1
      from public.course_block_options as option
      join target_slot
        on target_slot.block_code = option.block_code
      where option.course_id = target_course_id
    ) then true
    else false
  end;
$$;

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
    with slot_context as (
      select public.timetable_slot_block_code(slot.slot_order) as block_code
    ),
    slot_offers as (
      select
        slot_course.display_order,
        slot_course.course_id,
        course.name,
        (select slot_context.block_code from slot_context) as block_code
      from public.timetable_slot_courses as slot_course
      join public.courses as course
        on course.id = slot_course.course_id
      where slot_course.slot_id = slot.id
    ),
    preferred_block as (
      select slot_context.block_code
      from slot_context
      where slot_context.block_code is not null
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

do $$
declare
  invalid_enrollment record;
begin
  select
    enrollment.student_id,
    enrollment.block_code,
    course.name as course_name
    into invalid_enrollment
  from public.student_enrollments as enrollment
  join public.courses as course
    on course.id = enrollment.course_id
  where enrollment.block_code is not null
    and not public.course_is_valid_for_block(enrollment.course_id, enrollment.block_code)
  order by enrollment.student_id, enrollment.block_code, course.name
  limit 1;

  if found then
    raise exception 'Existing invalid enrollment: student %, course "%", block %. Fix this row before installing the block guardrail.',
      invalid_enrollment.student_id,
      invalid_enrollment.course_name,
      invalid_enrollment.block_code
      using errcode = '23514';
  end if;
end $$;

do $$
declare
  invalid_slot_offer record;
begin
  select
    slot.slot_order,
    public.timetable_slot_block_code(slot.slot_order) as block_code,
    course.name as course_name
    into invalid_slot_offer
  from public.timetable_slot_courses as slot_course
  join public.timetable_slots as slot
    on slot.id = slot_course.slot_id
  join public.courses as course
    on course.id = slot_course.course_id
  where not public.timetable_slot_course_is_valid(slot_course.slot_id, slot_course.course_id)
  order by slot.slot_order, course.name
  limit 1;

  if found then
    raise exception 'Existing invalid slot offer: course "%" is in Block % slot_order %. Fix this slot row before installing the block guardrail.',
      invalid_slot_offer.course_name,
      invalid_slot_offer.block_code,
      invalid_slot_offer.slot_order
      using errcode = '23514';
  end if;
end $$;

create or replace function public.validate_student_enrollment_block()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_block_code text;
  target_course_name text;
begin
  normalized_block_code := upper(trim(coalesce(new.block_code, '')));

  if normalized_block_code = '' then
    new.block_code := null;
    return new;
  end if;

  new.block_code := normalized_block_code;

  if not public.course_is_valid_for_block(new.course_id, normalized_block_code) then
    select course.name
      into target_course_name
    from public.courses as course
    where course.id = new.course_id;

    raise exception 'Course "%" is not available in Block %.',
      coalesce(target_course_name, new.course_id::text),
      normalized_block_code
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.validate_timetable_slot_course_block()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_slot_order integer;
  target_block_code text;
  target_course_name text;
begin
  if not public.timetable_slot_course_is_valid(new.slot_id, new.course_id) then
    select slot.slot_order, public.timetable_slot_block_code(slot.slot_order)
      into target_slot_order, target_block_code
    from public.timetable_slots as slot
    where slot.id = new.slot_id;

    select course.name
      into target_course_name
    from public.courses as course
    where course.id = new.course_id;

    raise exception 'Course "%" is not available in Block % slot_order %.',
      coalesce(target_course_name, new.course_id::text),
      coalesce(target_block_code, 'unknown'),
      coalesce(target_slot_order::text, new.slot_id::text)
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_student_enrollment_block on public.student_enrollments;
create trigger validate_student_enrollment_block
before insert or update of course_id, block_code on public.student_enrollments
for each row
execute function public.validate_student_enrollment_block();

drop trigger if exists validate_timetable_slot_course_block on public.timetable_slot_courses;
create trigger validate_timetable_slot_course_block
before insert or update of slot_id, course_id on public.timetable_slot_courses
for each row
execute function public.validate_timetable_slot_course_block();

comment on table public.course_block_options is
  'Canonical allow-list of course/block pairs for student_enrollments.block_code.';

comment on table public.timetable_slot_block_options is
  'Canonical mapping from June 2026 timetable slot_order values to block codes.';

comment on function public.validate_student_enrollment_block() is
  'Rejects student_enrollments rows when a non-null block_code points to a course not available in that block.';

comment on function public.validate_timetable_slot_course_block() is
  'Rejects timetable_slot_courses rows when a block-coded course is attached to a slot from an unavailable block.';

commit;
