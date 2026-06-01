# G10 June Timetable

## Local Development

Install dependencies once:

```bash
npm install
```

Start the local dev server:

```bash
npm run dev
```

Create a production build:

```bash
npm run build
```

## Lookup UX

The timetable search now remembers recent pupil IDs in the browser and lets you rerun them with one click.

## Frontend Structure

- `index.html`: app shell
- `styles/main.css`: page styling
- `js/supabase-config.js`: Supabase URL and publishable key
- `js/app.js`: timetable UI and Supabase RPC integration

## Data Access

The browser no longer reads `periods`, `students`, or `student_timetable_entries` directly.
It calls `public.get_student_timetable_payload(text)` with the publishable key.

This keeps the frontend read-only while leaving administrative database access available through Supabase CLI, SQL Editor, or service-role credentials.

## Admin Writes

Use the admin script for write access from your terminal, not from the browser.

The safest local setup is an ignored `.env.local` file in the project root.

1. Copy `.env.local.example` to `.env.local`.
2. Paste your real `service_role` key into `.env.local`.
3. Run the admin script.

Example `.env.local`:

```bash
SUPABASE_URL="https://aleqesajbbcmufcydgqy.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"
```

If you prefer shell exports instead, this still works:

```bash
export SUPABASE_URL="https://aleqesajbbcmufcydgqy.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"
```

Preferred: import students and enrollments directly from the raw TSV into Supabase staging tables, then let the database build the normalized rows:

```bash
node scripts/supabase-admin-sync.mjs students-tsv ./examples/students.june-2026.raw.tsv
```

This path keeps the roster import database-driven. The TSV is staged in Supabase and the database function updates `public.students`, `public.student_enrollments`, and trigger-driven `public.student_slot_assignments`.
Changing a student's enrollment row in `public.student_enrollments` now automatically regenerates that student's `public.student_slot_assignments` records.

For block-based schedules, set `block_code` on the enrollment row so the sync can map the course back to `Block A` through `Block F` slots.

Update one student's block assignment from the terminal:

```bash
node scripts/supabase-admin-sync.mjs set-block-enrollment 4393 E "English E-7 - ESL 3"
```

This updates `public.student_enrollments`, then the trigger immediately regenerates that student's timetable rows.

Resync derived slot assignments after a timetable change:

```bash
node scripts/supabase-admin-sync.mjs sync-slot-assignments 4393
node scripts/supabase-admin-sync.mjs sync-slot-assignments all
```

Use `all` after changing timetable slot definitions for a whole term structure so every student's derived timetable is rebuilt from the latest enrollment data.

Ready-to-run sample:

```bash
node scripts/supabase-admin-sync.mjs students-tsv ./examples/students.june-2026.raw.tsv
```

Upsert timetable periods, courses, slots, and slot-course rows from a JSON file:

```bash
node scripts/supabase-admin-sync.mjs timetable ./path/to/timetable.json
```

Ready-to-run sample:

```bash
node scripts/supabase-admin-sync.mjs timetable ./examples/timetable.sample.json
```

Optional: generate explicit student-to-slot assignments for debugging or one-off imports:

```bash
node scripts/generate-june-2026-block-assignments.mjs ./examples/students.june-2026.sample.json
node scripts/supabase-admin-sync.mjs slot-assignments ./examples/student-slot-assignments.june-2026.json
```

Timetable JSON shape:

```json
{
	"periods": [
		{
			"id": "P1",
			"label": "8:20 – 9:00",
			"starts_at": "08:20",
			"ends_at": "09:00",
			"sort_order": 1
		}
	],
	"courses": [
		{
			"name": "Business 1",
			"default_teacher": "Kieran Foxe",
			"default_room": "B4038"
		}
	],
	"slots": [
		{
			"slot_order": 1,
			"term_name": "June 2025",
			"grade_level": "G10",
			"day_name": "Monday",
			"start_period_id": "P1",
			"end_period_id": "P1",
			"courses": ["Business 1"],
			"overrides": {
				"Business 1": {
					"teacher": "Kieran Foxe",
					"room": "B4038"
				}
			}
		}
	]
}
```

Where to find the service role key:

1. Open Supabase Dashboard.
2. Go to Project Settings.
3. Open API.
4. Copy the `service_role` key.

Do not put the `service_role` key in frontend files or commit it to git.