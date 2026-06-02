-- 20260602160000_swap_monday_p34_tok_cas_by_group.sql
--
-- Goal
--   On Monday P3 and P4 in the June 2026 G10 term (slot_ids 63, 64, 99, 100
--   today), pin the 31 TOK/CAS students to the dedicated TOK/CAS course in
--   each slot. Without this, the auto-derived rows in student_slot_assignments
--   leave them in their normal block-C subjects (Physics HL, Chemistry HL,
--   etc.) because the slot offerings list "TOK (Group 1/2)" and
--   "CAS (Group 1/2)" — the sync trigger only fires the TOK branch when it
--   sees the legacy "IB - TOK" marker, which is no longer in these slots.
--
-- Per-slot, per-group course map
--   The user-side rule is "TOK Group 1 = CAS Group 2" — i.e. a Group 1
--   student always takes TOK (Group 1) + CAS (Group 2); a Group 2 student
--   always takes CAS (Group 2) + TOK (Group 2). The two periods P3 and P4
--   hold the same course pair (TOK (Group 1) + CAS (Group 2)); the student
--   assignments in step 5 place each group on the matching course per period.
--
--   slot 63  (2026-06-15 P3)  Group 1 -> TOK (Group 1)  | Group 2 -> CAS (Group 2)
--   slot 64  (2026-06-15 P4)  Group 1 -> CAS (Group 2)  | Group 2 -> TOK (Group 2)
--   slot 99  (2026-06-29 P3)  Group 1 -> TOK (Group 1)  | Group 2 -> CAS (Group 2)
--   slot 100 (2026-06-29 P4)  Group 1 -> CAS (Group 2)  | Group 2 -> TOK (Group 2)
--
-- Why explicit student_slot_assignments rows
--   The student_timetable_entries view prefers rows in
--   student_slot_assignments over derived rows from student_enrollments, so
--   writing an explicit row for these 31 students hides whatever the trigger
--   would otherwise pick (their block-C subject) without affecting anyone
--   else in those slots.
--
-- Why the sync function also has to change
--   sync_student_slot_assignments_for_student deletes and re-inserts derived
--   rows on every student/enrollment change. Without an `on conflict do
--   nothing`, the re-insert would fail with a unique constraint violation
--   the next time any of the 31 students gets a routine metadata update.
--   Adding the conflict guard makes the re-sync a no-op for the protected
--   (student, slot) pair, which matches the view's "explicit wins" semantics
--   anyway.
--
-- Rollback
--   delete from public.student_slot_assignments
--   where source = 'manual-monday-p34-tok-cas-swap';
--   delete from public.timetable_slot_courses
--   where slot_id = 100
--     and course_id in (
--       select id from public.courses
--       where name in ('CAS (Group 1)', 'TOK (Group 2)')
--     );
--   insert into public.timetable_slot_courses (slot_id, course_id, display_order)
--   select 100, id, 10197 from public.courses where name = 'TOK (Group 1)';
--   insert into public.timetable_slot_courses (slot_id, course_id, display_order)
--   select 100, id, 10198 from public.courses where name = 'CAS (Group 2)';
--   update public.courses set default_teacher = null where name = 'TOK (Group 1)';
--   update public.courses set default_teacher = null where name = 'TOK (Group 2)';
--   update public.timetable_slot_courses
--   set override_room = null
--   where slot_id = 100
--     and course_id = (select id from public.courses where name = 'CAS (Group 1)');
--   update public.timetable_slot_courses
--   set override_room = null
--   where slot_id = 100
--     and course_id = (select id from public.courses where name = 'TOK (Group 2)');
--   -- then drop the `on conflict do nothing` clause added at the end of
--   -- public.sync_student_slot_assignments_for_student (or re-apply
--   -- 20260601190000_add_tok_block_code.sql on top to restore the old body).

begin;

-- 1) Assign the right teachers to the TOK courses.
update public.courses
   set default_teacher = 'Miya Yang'
 where name = 'TOK (Group 1)';

update public.courses
   set default_teacher = 'Matthew Peatman'
 where name = 'TOK (Group 2)';

-- 2) Make both P4 slots offer the same pair as P3 (TOK (Group 1) + CAS (Group 2)).
--    The actual student->course map is "TOK Group 1 = CAS Group 2" — i.e. a
--    Group 1 student takes TOK (Group 1) in P3 and CAS (Group 2) in P4, a
--    Group 2 student takes CAS (Group 2) in P3 and TOK (Group 2) in P4. So
--    every P3/P4 slot needs the same two courses to offer; the student
--    assignments in step 5 pick which one each group lands on per period.

-- 2a) Slot 64 (2026-06-15 P4): remove CAS (Group 1), add CAS (Group 2).
delete from public.timetable_slot_courses as sc
using public.courses as c
where sc.slot_id = 64
  and sc.course_id = c.id
  and c.name = 'CAS (Group 1)';

insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select 64, c.id, coalesce(max(sc.display_order), 0) + 1, null, null
from public.courses c
left join public.timetable_slot_courses sc on sc.slot_id = 64
where c.name = 'CAS (Group 2)'
group by c.id
on conflict (slot_id, course_id) do nothing;

-- 2b) Slot 100 (2026-06-29 P4): remove CAS (Group 1), add CAS (Group 2).
delete from public.timetable_slot_courses as sc
using public.courses as c
where sc.slot_id = 100
  and sc.course_id = c.id
  and c.name = 'CAS (Group 1)';

insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select 100, c.id, 10198, null, null
from public.courses c
where c.name = 'CAS (Group 2)'
on conflict (slot_id, course_id) do nothing;

-- 2.5) Pin one room per Monday P3/P4 slot, shared by both TOK/CAS courses
--      in the slot. Teachers always come from the course defaults, so we
--      clear all teacher/room overrides first and re-apply the rooms below.
--      slot 63  (2026-06-15 P3) -> B3044
--      slot 64  (2026-06-15 P4) -> B4010
--      slot 99  (2026-06-29 P3) -> B4010
--      slot 100 (2026-06-29 P4) -> B3004
update public.timetable_slot_courses as sc
   set override_teacher = null,
       override_room    = null
from public.courses as c
where sc.slot_id in (63, 64, 99, 100)
  and sc.course_id = c.id
  and c.name in ('TOK (Group 1)', 'TOK (Group 2)', 'CAS (Group 1)', 'CAS (Group 2)');

with slot_rooms (slot_id, room) as (
  values
    (63,  'B3044'),
    (64,  'B4010'),
    (99,  'B4010'),
    (100, 'B3004')
)
update public.timetable_slot_courses as sc
   set override_room = sr.room
from slot_rooms sr,
     public.courses as c
where sc.slot_id = sr.slot_id
  and sc.course_id = c.id
  and c.name in ('TOK (Group 1)', 'TOK (Group 2)', 'CAS (Group 1)', 'CAS (Group 2)');

-- 3) Patch the sync function so future re-syncs leave manual rows alone.
--    Full redefinition; body matches 20260601190000_add_tok_block_code.sql,
--    plus `on conflict (student_id, slot_id) do nothing` on the derived insert.
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
  where student.student_id = target_student_id
  on conflict (student_id, slot_id) do nothing;
end;
$$;

-- 4) Clean up the stale derived rows for the protected (student, slot) pairs
--    so the explicit rows in step 5 are the only ones present.
delete from public.student_slot_assignments as assignment
where assignment.slot_id in (63, 64, 99, 100)
  and assignment.source in ('generated-june-2026-block-assignments', 'synced-from-enrollments')
  and assignment.student_id in (
    '1037', '1114', '1583', '1616', '1618',  -- Group 1
    '2813', '3815', '3958', '3991', '4022',
    '4070', '4071', '4123', '4126', '4192',
    '4196', '4215', '4260',
    '183', '626', '653', '2487', '2495',       -- Group 2
    '2698', '3291', '3465', '3470', '3643',
    '3677', '4108', '4220'
  );

-- 5) Insert explicit student_slot_assignments for the 31 students,
--    one row per (student, slot) using the per-slot, per-group course map.
with group1_students (student_id) as (
  values
    ('1037'),  -- LIN BOYAN (Andy)
    ('1114'),  -- ZHANG YIYOU (Matthew)
    ('1583'),  -- YAN SHAOQIAN (Thomas)
    ('1616'),  -- YIN MEIJIA (Mika)
    ('1618'),  -- JIN YUCHEN (Achen)
    ('2813'),  -- XIAO ZHIXUAN (Priscilla)
    ('3815'),  -- CHEN YIJIA (Jonina)
    ('3958'),  -- TENG AI (Alietti)
    ('3991'),  -- YANG YINGTONG (Annie)
    ('4022'),  -- CHEN ZHUOYOU (Maggie)
    ('4070'),  -- HUA SHIYU (Shirley)
    ('4071'),  -- GAO ZICHENG (Edward)
    ('4123'),  -- WANG YITIAN (Rachel)
    ('4126'),  -- WANG ZIHAN (Winny)
    ('4192'),  -- ZHANG YUXI (Ivy)
    ('4196'),  -- ZOU XIHUI (Zoe)
    ('4215'),  -- JIAO SONGYANG (Songyang)
    ('4260')   -- YIN YUE (Selina)
),
group2_students (student_id) as (
  values
    ('183'),   -- QIAN JICHEN (Charlis)
    ('626'),   -- CHEN PINYUE (Gloria)
    ('653'),   -- GU ROY (Roy)
    ('2487'),  -- LIAO CHENGWEI (Jerry)
    ('2495'),  -- WANG HAOXUAN (Lance)
    ('2698'),  -- ANUNCIACION MU (Ariah)
    ('3291'),  -- MAHENDRA MIA MARIA (Mia)
    ('3465'),  -- SANCHEZ MOSQUERA MANUEL (Manuel)
    ('3470'),  -- PAULINE BIJU RAFHAELA (Rafhaela)
    ('3643'),  -- SAWAR IMAN TAIBAH (Iman)
    ('3677'),  -- DI JINYU (Jessica)
    ('4108'),  -- XU YUNXUAN (Wendy)
    ('4220')   -- Z'BERG LYRIC (Lyric)
),
g1_assignments (slot_id, course_name) as (
  values
    (63,  'TOK (Group 1)'),
    (64,  'CAS (Group 2)'),
    (99,  'TOK (Group 1)'),
    (100, 'CAS (Group 2)')
),
g2_assignments (slot_id, course_name) as (
  values
    (63,  'CAS (Group 2)'),
    (64,  'TOK (Group 2)'),
    (99,  'CAS (Group 2)'),
    (100, 'TOK (Group 2)')
),
g1_rows as (
  select g1.student_id, a.slot_id, c.id as course_id
  from group1_students g1
  cross join g1_assignments a
  join public.courses c on c.name = a.course_name
),
g2_rows as (
  select g2.student_id, a.slot_id, c.id as course_id
  from group2_students g2
  cross join g2_assignments a
  join public.courses c on c.name = a.course_name
),
all_rows as (
  select * from g1_rows
  union all
  select * from g2_rows
)
insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
select student_id, slot_id, course_id, 'manual-monday-p34-tok-cas-swap'
from all_rows
on conflict (student_id, slot_id) do update
  set course_id = excluded.course_id,
      source = excluded.source;

commit;

-- Verification (read-only, runs after commit).
-- Expected: 124 rows = 31 students x 4 slots, all with
-- source = 'manual-monday-p34-tok-cas-swap', course_name matching the
-- per-slot, per-group map above.
select
  s.student_id,
  s.full_name,
  slot.term_name,
  slot.day_name,
  slot.start_period_id,
  slot.end_period_id,
  course.name as course_name,
  coalesce(slot_course.override_teacher, course.default_teacher) as teacher,
  coalesce(slot_course.override_room, course.default_room) as room
from public.student_slot_assignments as a
join public.students as s on s.student_id = a.student_id
join public.timetable_slots as slot on slot.id = a.slot_id
join public.courses as course on course.id = a.course_id
left join public.timetable_slot_courses as slot_course
  on slot_course.slot_id = a.slot_id
 and slot_course.course_id = a.course_id
where a.source = 'manual-monday-p34-tok-cas-swap'
  and slot.grade_level = 'G10'
  and slot.day_name = 'Monday'
  and slot.start_period_id in ('P3', 'P4')
  and slot.term_name between '2026-06-01' and '2026-06-30'
order by s.student_id, slot.term_name, slot.start_period_id;
