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

## Admin Backdoor Page

There is now a browser-safe admin course-change page at `admin-course-changes.html`.

The page is designed to stay online as a static frontend while its write operations go through a password-protected Supabase Edge Function.

Deploy the backend once:

1. In Supabase, set these Edge Function secrets:

```bash
SUPABASE_URL="https://aleqesajbbcmufcydgqy.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"
ADMIN_COURSE_CHANGE_PASSWORD="<shared-admin-password>"
ATTENDANCE_DATABASE_URL="postgres://flyadmin:pass123@localhost:5433/postgres"
```

`ATTENDANCE_DATABASE_URL` is required for attendance sync after admin course changes.
`ATTENDANCE_SYNC_MODE` is not used by this project and should be omitted.

2. Deploy the function without JWT enforcement because the shared password is the gate here:

```bash
supabase functions deploy admin-course-change-api --no-verify-jwt
```

3. Keep the frontend online as normal and open `admin-course-changes.html`.

By default, the page calls:

```text
https://aleqesajbbcmufcydgqy.supabase.co/functions/v1/admin-course-change-api
```

You can override that with `?adminApi=` if needed.

The page prompts for the shared password before it loads any student data. The hosted function validates that password, reads current student enrollments, groups choices by `Block A` through `Block F`, shows the `block_code is null` options separately, and writes the updated selections back with the service-role key.

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
node scripts/supabase-admin-sync.mjs timetable ./examples/timetable.june-2026-slots.json
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