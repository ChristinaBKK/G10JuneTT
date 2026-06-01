import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const workspaceRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const htmlPath = path.join(workspaceRoot, 'index.html');
const outputDir = path.join(workspaceRoot, 'supabase');
const outputPath = path.join(outputDir, 'g10_june_2025_setup.sql');
const migrationsDir = path.join(outputDir, 'migrations');
const migrationPath = path.join(migrationsDir, '20260529164800_g10_june_2025_setup.sql');

function extractInlineScript(html) {
  const match = html.match(/<script>([\s\S]*?)<\/script>/);
  if (!match) {
    throw new Error('Could not find the inline timetable script in index.html');
  }
  return match[1];
}

function loadSourceData(scriptContent) {
  const sandbox = {};
  vm.createContext(sandbox);
  vm.runInContext(
    `${scriptContent}\nthis.__copilot_export__ = { periods, masterTimetable, classDetails, studentData };`,
    sandbox,
  );
  return sandbox.__copilot_export__;
}

function normaliseTimePart(value, isAfternoon) {
  const [hours, minutes] = value.trim().split(':').map(Number);
  const adjustedHours = isAfternoon && hours < 12 ? hours + 12 : hours;
  return `${String(adjustedHours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function buildPeriods(periods) {
  return periods.map((period, index) => {
    const isAfternoon = index >= 5;
    const [startsAt, endsAt] = period.time
      .split('–')
      .map((part) => normaliseTimePart(part, isAfternoon));
    return {
      id: period.id,
      label: period.time,
      starts_at: startsAt,
      ends_at: endsAt,
      sort_order: index + 1,
    };
  });
}

function buildCourses(masterTimetable, classDetails, studentData) {
  const names = new Set();

  for (const slot of masterTimetable) {
    for (const courseName of slot.courses) {
      names.add(courseName);
    }
  }

  for (const student of Object.values(studentData)) {
    for (const courseName of student.enrollments) {
      names.add(courseName);
    }
  }

  for (const courseName of Object.keys(classDetails)) {
    names.add(courseName);
  }

  return [...names]
    .sort((left, right) => left.localeCompare(right))
    .map((name) => ({
      name,
      default_teacher: classDetails[name]?.teacher ?? null,
      default_room: classDetails[name]?.room ?? null,
    }));
}

function buildSlots(masterTimetable) {
  return masterTimetable.map((slot, index) => ({
    slot_order: index + 1,
    term_name: 'June 2025',
    grade_level: 'G10',
    day_name: slot.day,
    start_period_id: slot.start,
    end_period_id: slot.end,
    courses: slot.courses,
    details: slot.details ?? {},
  }));
}

function buildStudents(studentData) {
  return Object.entries(studentData)
    .sort(([left], [right]) => Number(left) - Number(right))
    .map(([studentId, student]) => ({
      student_id: studentId,
      full_name: student.name,
      enrollments: [...new Set(student.enrollments)],
    }));
}

function sqlJson(value) {
  return `$json$${JSON.stringify(value, null, 2)}$json$::jsonb`;
}

function buildSql({ periods, courses, slots, students }) {
  return `begin;

drop view if exists public.student_timetable_entries;
drop table if exists public.student_enrollments;
drop table if exists public.students;
drop table if exists public.timetable_slot_courses;
drop table if exists public.timetable_slots;
drop table if exists public.courses;
drop table if exists public.periods;

create table public.periods (
  id text primary key,
  label text not null,
  starts_at time not null,
  ends_at time not null,
  sort_order smallint not null unique
);

create table public.courses (
  id bigint generated always as identity primary key,
  name text not null unique,
  default_teacher text,
  default_room text
);

create table public.timetable_slots (
  id bigint generated always as identity primary key,
  term_name text not null,
  grade_level text not null,
  day_name text not null check (day_name in ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')),
  start_period_id text not null references public.periods (id),
  end_period_id text not null references public.periods (id),
  slot_order integer not null unique,
  unique (term_name, grade_level, day_name, start_period_id, end_period_id)
);

create table public.timetable_slot_courses (
  slot_id bigint not null references public.timetable_slots (id) on delete cascade,
  course_id bigint not null references public.courses (id) on delete cascade,
  display_order smallint not null,
  override_teacher text,
  override_room text,
  primary key (slot_id, course_id)
);

create table public.students (
  student_id text primary key,
  full_name text not null
);

create table public.student_enrollments (
  student_id text not null references public.students (student_id) on delete cascade,
  course_id bigint not null references public.courses (id) on delete cascade,
  primary key (student_id, course_id)
);

with source_rows as (
  select *
  from jsonb_to_recordset(${sqlJson(periods)}) as source_rows(
    id text,
    label text,
    starts_at text,
    ends_at text,
    sort_order smallint
  )
)
insert into public.periods (id, label, starts_at, ends_at, sort_order)
select id, label, starts_at::time, ends_at::time, sort_order
from source_rows;

with source_rows as (
  select *
  from jsonb_to_recordset(${sqlJson(courses)}) as source_rows(
    name text,
    default_teacher text,
    default_room text
  )
)
insert into public.courses (name, default_teacher, default_room)
select name, default_teacher, default_room
from source_rows;

with source_rows as (
  select *
  from jsonb_to_recordset(${sqlJson(slots)}) as source_rows(
    slot_order integer,
    term_name text,
    grade_level text,
    day_name text,
    start_period_id text,
    end_period_id text,
    courses jsonb,
    details jsonb
  )
)
insert into public.timetable_slots (term_name, grade_level, day_name, start_period_id, end_period_id, slot_order)
select term_name, grade_level, day_name, start_period_id, end_period_id, slot_order
from source_rows
order by slot_order;

with source_rows as (
  select *
  from jsonb_to_recordset(${sqlJson(slots)}) as source_rows(
    slot_order integer,
    term_name text,
    grade_level text,
    day_name text,
    start_period_id text,
    end_period_id text,
    courses jsonb,
    details jsonb
  )
)
insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select
  slot.id,
  course.id,
  offered.ordinality::smallint,
  source_rows.details -> offered.course_name ->> 'teacher' as override_teacher,
  source_rows.details -> offered.course_name ->> 'room' as override_room
from source_rows
join public.timetable_slots as slot
  on slot.slot_order = source_rows.slot_order
join lateral jsonb_array_elements_text(source_rows.courses) with ordinality as offered(course_name, ordinality)
  on true
join public.courses as course
  on course.name = offered.course_name;

with source_rows as (
  select *
  from jsonb_to_recordset(${sqlJson(students)}) as source_rows(
    student_id text,
    full_name text,
    enrollments jsonb
  )
)
insert into public.students (student_id, full_name)
select student_id, full_name
from source_rows;

with source_rows as (
  select *
  from jsonb_to_recordset(${sqlJson(students)}) as source_rows(
    student_id text,
    full_name text,
    enrollments jsonb
  )
)
insert into public.student_enrollments (student_id, course_id)
select distinct
  source_rows.student_id,
  course.id
from source_rows
join lateral jsonb_array_elements_text(source_rows.enrollments) as enrolled(course_name)
  on true
join public.courses as course
  on course.name = enrolled.course_name;

create view public.student_timetable_entries as
select
  student.student_id,
  student.full_name,
  slot.term_name,
  slot.grade_level,
  slot.day_name,
  slot.slot_order,
  slot.start_period_id,
  slot.end_period_id,
  start_period.sort_order as start_period_order,
  end_period.sort_order as end_period_order,
  course.name as course_name,
  coalesce(slot_course.override_teacher, course.default_teacher) as teacher,
  coalesce(slot_course.override_room, course.default_room) as room
from public.student_enrollments as enrollment
join public.students as student
  on student.student_id = enrollment.student_id
join public.timetable_slot_courses as slot_course
  on slot_course.course_id = enrollment.course_id
join public.timetable_slots as slot
  on slot.id = slot_course.slot_id
join public.courses as course
  on course.id = enrollment.course_id
join public.periods as start_period
  on start_period.id = slot.start_period_id
join public.periods as end_period
  on end_period.id = slot.end_period_id;

comment on view public.student_timetable_entries is
  'Derived student timetable entries generated from timetable slots and student course enrollments.';

commit;
`;
}

const html = fs.readFileSync(htmlPath, 'utf8');
const sourceData = loadSourceData(extractInlineScript(html));
const sql = buildSql({
  periods: buildPeriods(sourceData.periods),
  courses: buildCourses(sourceData.masterTimetable, sourceData.classDetails, sourceData.studentData),
  slots: buildSlots(sourceData.masterTimetable),
  students: buildStudents(sourceData.studentData),
});

fs.mkdirSync(outputDir, { recursive: true });
fs.mkdirSync(migrationsDir, { recursive: true });
fs.writeFileSync(outputPath, sql, 'utf8');
fs.writeFileSync(migrationPath, sql, 'utf8');

console.log(`Wrote ${outputPath}`);
console.log(`Wrote ${migrationPath}`);