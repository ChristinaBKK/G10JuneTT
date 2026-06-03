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

-- Diagnostics are defined in 20260603160000_redefine_diagnostics_from_canonical_payload.sql.

commit;