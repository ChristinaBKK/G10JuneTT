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

Upsert students and their enrollments from a JSON file:

```bash
node scripts/supabase-admin-sync.mjs students ./path/to/students.json
```

Ready-to-run sample:

```bash
node scripts/supabase-admin-sync.mjs students ./examples/students.sample.json
```

Upsert timetable periods, courses, slots, and slot-course rows from a JSON file:

```bash
node scripts/supabase-admin-sync.mjs timetable ./path/to/timetable.json
```

Ready-to-run sample:

```bash
node scripts/supabase-admin-sync.mjs timetable ./examples/timetable.sample.json
```

Generate explicit student-to-slot assignments for a June 2026 roster file:

```bash
node scripts/generate-june-2026-block-assignments.mjs ./examples/students.june-2026.sample.json
node scripts/supabase-admin-sync.mjs students ./examples/students.june-2026.sample.json
node scripts/supabase-admin-sync.mjs slot-assignments ./examples/student-slot-assignments.june-2026.json
```

Roster format:

```json
[
	{
		"student_id": "J26001",
		"full_name": "Avery Chen",
		"track": "CIE"
	},
	{
		"student_id": "J26003",
		"full_name": "Isla Wong",
		"track": "IB",
		"has_tok": true,
		"slot_overrides": {
			"6124": "CAS-1"
		}
	}
]
```

Student JSON shape:

```json
[
	{
		"student_id": "1154",
		"full_name": "Lu, Mengyao 陆孟瑶 (Yome)",
		"enrollments": ["Business 1", "Chemistry 3", "Geography"]
	}
]
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