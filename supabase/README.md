# Supabase Setup

This folder contains generated SQL for the June 2025 G10 timetable data.

## Files

- `g10_june_2025_setup.sql`: standalone SQL file for direct execution in the Supabase SQL Editor.
- `migrations/20260529164800_g10_june_2025_setup.sql`: repository migration file for Supabase CLI and project-based workflows.
- `migrations/20260529193000_add_public_timetable_rpc_and_rls.sql`: adds the public timetable RPC and enables RLS on the base tables.

## Apply In A Repo-Based Supabase Setup

If this repository is linked to Supabase and you use the CLI workflow, apply the migration with:

```bash
supabase db push
```

If the project is not linked on your machine yet, link it first with your project reference:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

## Apply In SQL Editor

1. Open your Supabase project.
2. Go to SQL Editor.
3. Open `supabase/g10_june_2025_setup.sql` from this workspace.
4. Paste it into the SQL Editor and run it.

## What Gets Created

- `public.periods`
- `public.courses`
- `public.timetable_slots`
- `public.timetable_slot_courses`
- `public.students`
- `public.student_enrollments`
- `public.student_timetable_entries`
- `public.get_student_timetable_payload(text)`

## Access Model

- Browser access uses `public.get_student_timetable_payload(text)` with the publishable key.
- Direct browser reads to base tables such as `public.students` are blocked.
- Admin reads and writes remain available through Supabase CLI, SQL Editor, and service-role access.

## Example Query

```sql
select
  student_id,
  full_name,
  day_name,
  start_period_id,
  end_period_id,
  course_name,
  teacher,
  room
from public.student_timetable_entries
where student_id = '1154'
order by
  case day_name
    when 'Monday' then 1
    when 'Tuesday' then 2
    when 'Wednesday' then 3
    when 'Thursday' then 4
    when 'Friday' then 5
  end,
  start_period_order;
```

## Regenerate After Editing Data

If you update the inline data in `index.html`, run:

```bash
node scripts/generate-supabase-sql.mjs
```

The generator removes duplicate course names inside a single student's enrollment list because the current page logic only needs course membership, not repeated enrollment rows.