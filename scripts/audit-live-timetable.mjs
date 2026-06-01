import fs from 'node:fs';
import path from 'node:path';

loadLocalEnvFile();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const EXEMPT_COURSE_NAMES = new Set(['Graduation parade', 'Dismiss early']);
const EXEMPT_MISSING_DETAILS_COURSE_NAMES = new Set(['University Counselling']);
const PLACEHOLDER_COURSE_NAMES = new Set([
  'Block A',
  'Block B (CIE)',
  'Block B1 (IB)',
  'Block B2 (IB)',
  'Block C',
  'Block D',
  'Block E',
  'Block F - PE',
  'PE',
  'PE - Zach to check',
  'CAS-1',
  'CAS-2',
  'UNIVERSITY COUNSEL',
]);

function loadLocalEnvFile() {
  const envPath = path.resolve('.env.local');
  if (!fs.existsSync(envPath)) {
    return;
  }

  const envContents = fs.readFileSync(envPath, 'utf8');
  for (const rawLine of envContents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }

    const separatorIndex = line.indexOf('=');
    if (separatorIndex === -1) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    const rawValue = line.slice(separatorIndex + 1).trim();
    const value = rawValue.replace(/^['\"]|['\"]$/g, '');
    if (key && !(key in process.env)) {
      process.env[key] = value;
    }
  }
}

function assertEnvironment() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in the environment or .env.local.');
  }
}

async function request(endpoint) {
  const response = await fetch(`${SUPABASE_URL}${endpoint}`, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Supabase request failed for ${endpoint}: ${response.status} ${response.statusText} ${text}`);
  }

  return text ? JSON.parse(text) : null;
}

async function requestAll(endpoint, pageSize = 1000) {
  const rows = [];
  let offset = 0;

  while (true) {
    const separator = endpoint.includes('?') ? '&' : '?';
    const page = await request(`${endpoint}${separator}limit=${pageSize}&offset=${offset}`);
    rows.push(...page);
    if (page.length < pageSize) {
      return rows;
    }
    offset += pageSize;
  }
}

function pushIssue(map, issueType, payload) {
  const issues = map.get(issueType) || [];
  issues.push(payload);
  map.set(issueType, issues);
}

function summarizeBy(items, keyFn) {
  const counts = new Map();
  for (const item of items) {
    const key = keyFn(item);
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
    .map(([key, count]) => ({ key, count }));
}

function uniqueStudentCount(items) {
  return new Set(items.map((item) => item.student_id)).size;
}

async function main() {
  assertEnvironment();

  const [students, slots, slotCourses, entries] = await Promise.all([
    request('/rest/v1/students?select=student_id,full_name&order=student_id.asc&limit=500'),
    request('/rest/v1/timetable_slots?select=id,slot_order,term_name,day_name,start_period_id,end_period_id&grade_level=eq.G10&term_name=gte.2026-06-10&term_name=lte.2026-06-29&order=slot_order.asc&limit=500'),
    requestAll('/rest/v1/timetable_slot_courses?select=slot_id,courses(name)'),
    requestAll('/rest/v1/student_timetable_entries?select=student_id,full_name,term_name,grade_level,day_name,slot_order,start_period_id,end_period_id,course_name,teacher,room&grade_level=eq.G10&term_name=gte.2026-06-10&term_name=lte.2026-06-29&order=student_id.asc,slot_order.asc'),
  ]);

  const slotCourseNamesBySlotId = new Map();
  for (const row of slotCourses) {
    const courseNames = slotCourseNamesBySlotId.get(row.slot_id) || [];
    courseNames.push(row.courses?.name ?? '');
    slotCourseNamesBySlotId.set(row.slot_id, courseNames);
  }

  const expectedSlots = slots.filter((slot) => {
    const courseNames = slotCourseNamesBySlotId.get(slot.id) || [];
    return !courseNames.some((name) => EXEMPT_COURSE_NAMES.has(name));
  });

  const entriesByStudentSlot = new Map();
  for (const entry of entries) {
    const key = `${entry.student_id}::${entry.slot_order}`;
    const studentEntries = entriesByStudentSlot.get(key) || [];
    studentEntries.push(entry);
    entriesByStudentSlot.set(key, studentEntries);
  }

  const issuesByType = new Map();

  for (const student of students) {
    for (const slot of expectedSlots) {
      const key = `${student.student_id}::${slot.slot_order}`;
      const studentEntries = entriesByStudentSlot.get(key) || [];

      if (studentEntries.length === 0) {
        pushIssue(issuesByType, 'emptyPeriods', {
          student_id: student.student_id,
          full_name: student.full_name,
          slot_order: slot.slot_order,
          term_name: slot.term_name,
          day_name: slot.day_name,
          period_label: slot.start_period_id === slot.end_period_id ? slot.start_period_id : `${slot.start_period_id}-${slot.end_period_id}`,
        });
        continue;
      }

      if (studentEntries.length > 1) {
        pushIssue(issuesByType, 'conflictingPeriods', {
          student_id: student.student_id,
          full_name: student.full_name,
          slot_order: slot.slot_order,
          courses: studentEntries.map((entry) => entry.course_name),
        });
      }

      for (const entry of studentEntries) {
        if (!entry.course_name || !entry.course_name.trim()) {
          pushIssue(issuesByType, 'missingCourse', entry);
        }

        if (!EXEMPT_MISSING_DETAILS_COURSE_NAMES.has(entry.course_name)) {
          if (!entry.teacher || !String(entry.teacher).trim()) {
            pushIssue(issuesByType, 'missingTeacher', entry);
          }

          if (!entry.room || !String(entry.room).trim()) {
            pushIssue(issuesByType, 'missingRoom', entry);
          }
        }

        if (PLACEHOLDER_COURSE_NAMES.has(entry.course_name)) {
          pushIssue(issuesByType, 'placeholderCourse', entry);
        }
      }
    }
  }

  const emptyPeriods = issuesByType.get('emptyPeriods') || [];
  const conflictingPeriods = issuesByType.get('conflictingPeriods') || [];
  const missingTeacher = issuesByType.get('missingTeacher') || [];
  const missingRoom = issuesByType.get('missingRoom') || [];
  const missingCourse = issuesByType.get('missingCourse') || [];
  const placeholderCourse = issuesByType.get('placeholderCourse') || [];

  const report = {
    summary: {
      students: students.length,
      expected_slots_per_student: expectedSlots.length,
      audited_student_periods: students.length * expectedSlots.length,
      empty_periods: emptyPeriods.length,
      conflicting_periods: conflictingPeriods.length,
      missing_teacher_entries: missingTeacher.length,
      missing_room_entries: missingRoom.length,
      missing_course_entries: missingCourse.length,
      placeholder_course_entries: placeholderCourse.length,
    },
    affected_students: {
      empty_periods: uniqueStudentCount(emptyPeriods),
      conflicting_periods: uniqueStudentCount(conflictingPeriods),
      missing_teacher: uniqueStudentCount(missingTeacher),
      missing_room: uniqueStudentCount(missingRoom),
      missing_course: uniqueStudentCount(missingCourse),
      placeholder_course: uniqueStudentCount(placeholderCourse),
    },
    breakdowns: {
      missing_teacher_by_course: summarizeBy(missingTeacher, (item) => item.course_name || '(blank course)').slice(0, 20),
      missing_room_by_course: summarizeBy(missingRoom, (item) => item.course_name || '(blank course)').slice(0, 20),
      placeholder_course_by_name: summarizeBy(placeholderCourse, (item) => item.course_name || '(blank course)').slice(0, 20),
    },
    samples: {
      empty_periods: emptyPeriods.slice(0, 20),
      conflicting_periods: conflictingPeriods.slice(0, 20),
      missing_teacher: missingTeacher.slice(0, 20),
      missing_room: missingRoom.slice(0, 20),
      missing_course: missingCourse.slice(0, 20),
      placeholder_course: placeholderCourse.slice(0, 20),
    },
  };

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});