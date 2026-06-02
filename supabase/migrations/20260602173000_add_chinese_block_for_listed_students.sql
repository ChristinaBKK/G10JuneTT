-- 20260602173000_add_chinese_block_for_listed_students.sql
--
-- Goal
--   Create a Chinese A/B/AB HL/SL "block" on five specific G10 slots in the
--   June 2026 term and pin 30 named students to their Chinese class in each
--   of those slots. The other students in those slots keep their existing
--   block-C / block-D lessons unchanged.
--
--   Target slots (term_name 2026-06-XX, grade_level G10)
--     slot 39  (2026-06-10 Wednesday P6)
--     slot 40  (2026-06-10 Wednesday P7)
--     slot 55  (2026-06-12 Friday    P4)
--     slot 84  (2026-06-17 Wednesday P6)
--     slot 85  (2026-06-17 Wednesday P7)
--
--   Slots 39, 40, 84, 85 already carry Chinese A HL / A SL / AB SL / B HL /
--   B SL in their slot_courses. Slot 55 only carries "Chinese B" today, so
--   step 1 adds the other four Chinese variants to that slot.
--
-- Student -> course map
--   Chinese A HL  (4)   4022 CHEN ZHUOYOU (Maggie)
--                        4196 ZOU XIHUI (Zoe)
--                        4215 JIAO SONGYANG (Songyang)
--                        2813 XIAO ZHIXUAN (Priscilla)
--
--   Chinese A SL  (18)  2495 WANG HAOXUAN (Lance)
--                        3815 CHEN YIJIA (Jonina)
--                        4071 GAO ZICHENG (Edward)
--                        4070 HUA SHIYU (Shirley)
--                        1618 JIN YUCHEN (Achen)
--                        2487 LIAO CHENGWEI (Jerry)
--                        1037 LIN BOYAN (Andy)
--                        183  QIAN JICHEN (Charlis)
--                        3958 TENG AI (Alietti)
--                        4108 XU YUNXUAN (Wendy)
--                        4123 WANG YITIAN (Rachel)
--                        4126 WANG ZIHAN (Winny)
--                        1583 YAN SHAOQIAN (Thomas)
--                        3991 YANG YINGTONG (Annie)
--                        1616 YIN MEIJIA (Mika)
--                        4260 YIN YUE (Selina)
--                        4192 ZHANG YUXI (Ivy)
--                        1114 ZHANG YIYOU (Matthew)
--
--   Chinese AB SL (5)   3470 PAULINE BIJU RAFHAELA (Rafhaela)
--                        3291 MAHENDRA MIA MARIA (Mia)
--                        3465 SANCHEZ MOSQUERA MANUEL (Manuel)
--                        3643 SAWAR IMAN TAIBAH (Iman)
--                        4220 Z'BERG LYRIC (Lyric)
--
--   Chinese B HL  (1)   3677 DI JINYU (Jessica)
--
--   Chinese B SL  (3)   2698 ANUNCIACION MU (Ariah)
--                        626  CHEN PINYUE (Gloria)
--                        653  GU ROY (Roy)
--
--   Total: 31 students x 5 slots = 155 explicit student_slot_assignments rows.
--
-- Why explicit student_slot_assignments rows
--   The student_timetable_entries view prefers rows in
--   student_slot_assignments over derived rows from student_enrollments, so
--   writing explicit rows for the 31 listed students hides whatever the
--   trigger would otherwise pick (their block-C / block-D subject) without
--   affecting any other student in those slots.
--
--   The 31 students are also enrolled in the Chinese courses via
--   student_enrollments (e.g. CHEN YIJIA has Chinese A SL), so without
--   explicit rows the trigger's block_code branch would still pick their
--   block-D subject first and they would never land on the Chinese class.
--
-- Why slot 55 needs new course rows
--   The slot's existing offering is "Block B (CIE) / Chinese B / ...". The
--   view's join on slot_courses requires the assigned course to be present
--   in the slot, so a student can't be assigned to Chinese A HL on slot 55
--   unless that course is in the slot's offering list.
--
-- Teacher and room (per the user)
--   "All HL and SL are in the same room with the same teacher":
--     Chinese A HL / A SL  -> Melody Chen  in B4010
--     Chinese B HL / B SL  -> Jenny Li     in B4009
--   Chinese AB SL          -> Ann Yang     in B2036
--   These are encoded on the course defaults (step 1b) and the per-slot
--   overrides on slots 39/40/55/84/85 are cleared (step 1c) so the
--   defaults take effect everywhere.
--
-- Rollback
--   delete from public.student_slot_assignments
--   where source = 'manual-chinese-block-2026-06';
--   delete from public.timetable_slot_courses
--   where slot_id = 55
--     and course_id in (
--       select id from public.courses
--       where name in ('Chinese A HL', 'Chinese A SL', 'Chinese AB SL', 'Chinese B HL', 'Chinese B SL')
--     );
--   update public.courses set default_teacher = null, default_room = null
--   where id in (192, 154, 198, 200, 190);

begin;

-- 1) Add the four missing Chinese variants to slot 55 (2026-06-12 P4) if not
--    already present. Display_order is set after the existing max so the new
--    rows append rather than collide. Teacher/room are filled in below.
with target_slot as (
  select max(display_order) as max_order
  from public.timetable_slot_courses
  where slot_id = 55
),
new_courses (course_name, course_id) as (
  values
    ('Chinese A HL',  192),
    ('Chinese A SL',  154),
    ('Chinese AB SL', 198),
    ('Chinese B HL',  200),
    ('Chinese B SL',  190)
)
insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select 55, nc.course_id, ts.max_order + row_number() over (order by nc.course_name), null, null
from new_courses nc, target_slot ts
where ts.max_order is not null
on conflict (slot_id, course_id) do nothing;

-- 1b) Pin teacher and room on the course defaults for the five Chinese
--     variants. "All HL and SL are in the same room with the same teacher"
--     means the rule belongs on the courses themselves, not per-slot — so
--     we encode it as course defaults and let every slot fall back to them.
update public.courses set default_teacher = 'Melody Chen',     default_room = 'B4010' where id = 192;  -- Chinese A HL
update public.courses set default_teacher = 'Melody Chen',     default_room = 'B4010' where id = 154;  -- Chinese A SL
update public.courses set default_teacher = 'Ann Yang',        default_room = 'B2036' where id = 198;  -- Chinese AB SL
update public.courses set default_teacher = 'Jenny Li', default_room = 'B4009' where id = 200;  -- Chinese B HL
update public.courses set default_teacher = 'Jenny Li', default_room = 'B4009' where id = 190;  -- Chinese B SL

-- 1c) Clear the per-slot overrides on the five Chinese variants across the
--     five target slots so the course defaults (just set above) take effect.
--     In particular, this rewrites the existing "Jenny Li/Ann Yang" / "B4009"
--     on Chinese AB SL to the new "Ann Yang" / "B2036" the user wants.
update public.timetable_slot_courses as sc
   set override_teacher = null,
       override_room    = null
from public.courses as c
where sc.slot_id in (39, 40, 55, 84, 85)
  and sc.course_id = c.id
  and c.name in ('Chinese A HL', 'Chinese A SL', 'Chinese AB SL', 'Chinese B HL', 'Chinese B SL');

-- 2) Clean up the stale derived rows for the protected (student, slot) pairs
--    so the explicit rows in step 3 are the only ones present.
delete from public.student_slot_assignments as assignment
where assignment.slot_id in (39, 40, 55, 84, 85)
  and assignment.source in ('generated-june-2026-block-assignments', 'synced-from-enrollments')
  and assignment.student_id in (
    '4022', '4196', '4215', '2813',  -- Chinese A HL
    '2495', '3815', '4071', '4070', '1618', '2487', '1037', '183', '3958',
    '4108',
    '4123', '4126', '1583', '3991', '1616', '4260', '4192', '1114',  -- Chinese A SL
    '3470', '3291', '3465', '3643', '4220',  -- Chinese AB SL
    '3677',                              -- Chinese B HL
    '2698', '626', '653'                 -- Chinese B SL
  );

-- 3) Insert explicit student_slot_assignments for the 30 students,
--    one row per (student, slot) using the per-student course map.
with chinese_a_hl (student_id) as (
  values ('4022'), ('4196'), ('4215'), ('2813')
),
chinese_a_sl (student_id) as (
  values
    ('2495'), ('3815'), ('4071'), ('4070'), ('1618'),
    ('2487'), ('1037'), ('183'),  ('3958'), ('4108'),
    ('4123'), ('4126'), ('1583'), ('3991'), ('1616'),
    ('4260'), ('4192'), ('1114')
),
chinese_ab_sl (student_id) as (
  values ('3470'), ('3291'), ('3465'), ('3643'), ('4220')
),
chinese_b_hl (student_id) as (
  values ('3677')
),
chinese_b_sl (student_id) as (
  values ('2698'), ('626'), ('653')
),
all_students (student_id, course_id) as (
  select student_id, 192 from chinese_a_hl
  union all select student_id, 154 from chinese_a_sl
  union all select student_id, 198 from chinese_ab_sl
  union all select student_id, 200 from chinese_b_hl
  union all select student_id, 190 from chinese_b_sl
),
target_slots (slot_id) as (
  values (39), (40), (55), (84), (85)
)
insert into public.student_slot_assignments (student_id, slot_id, course_id, source)
select s.student_id, ts.slot_id, s.course_id, 'manual-chinese-block-2026-06'
from all_students s
cross join target_slots ts
on conflict (student_id, slot_id) do update
  set course_id = excluded.course_id,
      source = excluded.source;

commit;

-- Verification (read-only, runs after commit).
-- Expected: 155 rows = 31 students x 5 slots, all with
-- source = 'manual-chinese-block-2026-06', course_name matching the
-- per-student Chinese variant.
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
where a.source = 'manual-chinese-block-2026-06'
  and slot.grade_level = 'G10'
  and slot.term_name in ('2026-06-10', '2026-06-12', '2026-06-17')
order by s.student_id, slot.term_name, slot.start_period_id;
