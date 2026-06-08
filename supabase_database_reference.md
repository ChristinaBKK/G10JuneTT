# Supabase Database Reference

Project ref: `aleqesajbbcmufcydgqy`

## Public API surface

- `courses`: `delete, get, patch, post`
- `periods`: `delete, get, patch, post`
- `students`: `delete, get, patch, post`
- `student_slot_assignments`: `delete, get, patch, post`
- `student_enrollment_slot_diagnostics`: `get`
- `timetable_slots`: `delete, get, patch, post`
- `timetable_slot_courses`: `delete, get, patch, post`
- `student_timetable_entries`: `get`

## Observed tables

### `courses`

Filterable/queryable columns:
- `id`
- `name`
- `default_teacher`
- `default_room`
- `block_code`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `periods`

Filterable/queryable columns:
- `id`
- `label`
- `starts_at`
- `ends_at`
- `sort_order`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `students`

Filterable/queryable columns:
- `student_id`
- `full_name`
- `program`
- `has_tok`
- `tok_course`
- `tok_block_code`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `student_slot_assignments`

Filterable/queryable columns:
- `student_id`
- `slot_id`
- `course_id`
- `source`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `student_enrollment_slot_diagnostics`

Filterable/queryable columns:
- `student_id`
- `full_name`
- `slot_id`
- `term_name`
- `grade_level`
- `day_name`
- `start_period_id`
- `end_period_id`
- `matched_course_count`
- `matched_course_names`
- `issue_type`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `timetable_slots`

Filterable/queryable columns:
- `id`
- `term_name`
- `grade_level`
- `day_name`
- `start_period_id`
- `end_period_id`
- `slot_order`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `timetable_slot_courses`

Filterable/queryable columns:
- `slot_id`
- `course_id`
- `display_order`
- `override_teacher`
- `override_room`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

### `student_timetable_entries`

Filterable/queryable columns:
- `student_id`
- `full_name`
- `term_name`
- `grade_level`
- `day_name`
- `slot_order`
- `start_period_id`
- `end_period_id`
- `start_period_order`
- `end_period_order`
- `course_name`
- `teacher`
- `room`
- `#/parameters/select`
- `#/parameters/order`
- `#/parameters/range`
- `#/parameters/rangeUnit`
- `#/parameters/offset`
- `#/parameters/limit`
- `#/parameters/preferCount`

## June 12 mapping notes

- `timetable_slots` row `id=58` is `2026-06-12`, `G10`, `Friday`, `P7` (`slot_order=6127`).
- `timetable_slots` row `id=59` is `2026-06-12`, `G10`, `Friday`, `P8` (`slot_order=6128`).
- `courses` row `id=960` is `House Activities` (`default_room='3rd Floor Art Rooms'`).
- `courses` rows `id=578, 607, 611, 633, 588, 618, 649` are `PE-1` through `PE-7`.
- June 12 P7/P8 swap is captured in `supabase/migrations/20260608100000_swap_june12_p7_p8.sql`.

## Root cause note

House Activities was not consistently visible in student view because the student timetable is rendered from `student_timetable_entries`, which depends on `student_slot_assignments`, not just `timetable_slot_courses`.

The bug pattern was:
- the slot mapping was updated in `timetable_slot_courses`
- but some student rows still had stale or incomplete `student_slot_assignments` for the same date
- the student view therefore kept rendering the old PE row or omitted House Activities entirely for affected students

### Avoid this in future changes

Whenever a slot swap affects student view, update both layers together:
- `timetable_slot_courses` for the canonical slot/course mapping
- `student_slot_assignments` for the derived per-student timetable rows

After the update, verify both:
- the slot-level assignment in `timetable_slot_courses`
- the rendered student row in `student_timetable_entries`

### June 12 P8 missing-row follow-up

A second House Activities issue occurred after the swap: four students (`2516`, `2813`, `3291`, `824`) had PE correctly assigned to `slot_id=58` (`P7`) but had no `student_slot_assignments` row for `slot_id=59` (`P8`). Because `student_timetable_entries` only renders rows that exist in `student_slot_assignments`, House Activities appeared blank in student view for those students.

Fix applied: inserted `slot_id=59`, `course_id=960` for those students with source `manual-house-activities-2026-06-12-p8-missing-row-fix`.

Prevention check after any whole-grade slot swap: scan for students with an affected `P7`/`P8` row missing its counterpart before verifying the UI.

### Chinese manual block stale assignment follow-up

Student `2813` had current enrollment `Chinese A SL` (`course_id=154`), but student view still showed `Chinese A HL` because the manual Chinese block rows in `student_slot_assignments` still pointed to `course_id=192`.

Root cause: migration `20260602173000_add_chinese_block_for_listed_students.sql` hard-coded student `2813` into the `Chinese A HL` list. Later admin/enrollment data showed the student as `Chinese A SL`, but the manual rows with source `manual-chinese-block-2026-06` were not automatically rebuilt from current enrollments.

Fix applied: updated `2813` manual Chinese rows for slots `39`, `40`, `55`, `84`, and `85` from `course_id=192` to `course_id=154`, using source `manual-chinese-block-2026-06-current-enrollment-fix`.

Prevention check: after any admin course change involving manually protected rows, audit manual `student_slot_assignments` against current `student_enrollments`. Do not rely only on the checkbox/admin UI state; the student view renders from `student_timetable_entries`, which follows `student_slot_assignments`.

### Why admin sync did not update Chinese / TOK / CAS

Root cause: the normal rebuild function `sync_student_slot_assignments_for_student` only deletes and rebuilds rows whose `source` is `generated-june-2026-block-assignments` or `synced-from-enrollments`.

Chinese and TOK/CAS rows are protected manual rows in `student_slot_assignments`, so the normal RPC intentionally leaves them alone:
- Chinese protected rows use slots `39`, `40`, `55`, `84`, `85`.
- TOK/CAS protected rows use slots `63`, `64`, `99`, `100`.
- Older sources include `manual-chinese-block-2026-06` and `manual-monday-p34-tok-cas-swap`.

That preservation is why the admin editor could save a new `student_enrollments` row while the student view still showed the old Chinese/TOK/CAS course. The student view reads from `student_timetable_entries`, and that view prefers `student_slot_assignments` over enrollment-derived rows.

Fix added in `supabase/functions/admin-course-change-api/index.ts`: after each admin save/rollback, the Edge Function now runs a wrapper around the normal RPC:
- clear special manual Chinese/TOK/CAS rows for the target student in the protected slots
- run `sync_student_slot_assignments_for_student`
- upsert fresh protected manual rows from current `student_enrollments`
- validate that only one Chinese course is selected
- validate that TOK/CAS are changed together as either `TOK (Group 1)` + `CAS (Group 2)` or `TOK (Group 2)` + `CAS (Group 1)`

The reconciliation writes new manual sources:
- `manual-chinese-block-2026-06-admin-sync`
- `manual-monday-p34-tok-cas-admin-sync`

TOK/CAS slot rule used by the reconciliation:
- `TOK (Group 1)` + `CAS (Group 2)`: slots `63`/`99` = TOK Group 1, slots `64`/`100` = CAS Group 2.
- `TOK (Group 2)` + `CAS (Group 1)`: slots `63`/`99` = CAS Group 1, slots `64`/`100` = TOK Group 2.

Future recipe for changing Chinese / TOK / CAS:
- Make the change through the admin course-change Edge Function, not by editing `student_enrollments` alone.
- Verify `student_enrollments` has the intended course IDs.
- Verify `student_slot_assignments` has matching protected rows for slots `39`, `40`, `55`, `84`, `85`, `63`, `64`, `99`, `100` as applicable.
- Verify `student_timetable_entries` shows the final student-facing result.
