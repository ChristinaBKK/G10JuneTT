import fs from 'node:fs';
import path from 'node:path';

loadLocalEnvFile();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BLOCK_CODES = ['A', 'B', 'C', 'D', 'E', 'F'];
const COURSE_BLOCK_OVERRIDES = new Map([
  ['Chinese A HL', 'C'],
  ['Chinese A SL', 'C'],
  ['Chinese AB SL', 'C'],
  ['Chinese B HL', 'C'],
  ['Chinese B SL', 'C'],
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

function getAdminBlockCodeForCourseName(courseName, blockCode) {
  return COURSE_BLOCK_OVERRIDES.get(courseName) || blockCode || null;
}

async function main() {
  assertEnvironment();

  const [courses, enrollments, slotCourses] = await Promise.all([
    requestAll('/rest/v1/courses?select=id,name,default_teacher,default_room'),
    requestAll('/rest/v1/student_enrollments?select=student_id,block_code,course:courses(name)'),
    requestAll('/rest/v1/timetable_slot_courses?select=override_teacher,override_room,course:courses(name,default_teacher,default_room)'),
  ]);

  const courseMetaByName = new Map();
  for (const course of courses) {
    courseMetaByName.set(course.name, {
      defaultTeacher: (course.default_teacher || '').trim(),
      defaultRoom: (course.default_room || '').trim(),
    });
  }

  const fallbackByCourseName = new Map();
  for (const row of slotCourses) {
    const courseName = row.course?.name;
    if (!courseName) {
      continue;
    }

    const fallback = fallbackByCourseName.get(courseName) || { teacher: '', room: '' };
    fallback.teacher = fallback.teacher || (row.override_teacher || row.course?.default_teacher || '').trim();
    fallback.room = fallback.room || (row.override_room || row.course?.default_room || '').trim();
    fallbackByCourseName.set(courseName, fallback);
  }

  const blockOptionSets = new Map(BLOCK_CODES.map((blockCode) => [blockCode, new Set()]));
  const unblockedOptionSet = new Set();

  for (const row of enrollments) {
    const courseName = row.course?.name;
    if (!courseName) {
      continue;
    }

    const effectiveBlockCode = getAdminBlockCodeForCourseName(courseName, row.block_code);
    if (effectiveBlockCode && blockOptionSets.has(effectiveBlockCode)) {
      blockOptionSets.get(effectiveBlockCode).add(courseName);
      continue;
    }

    unblockedOptionSet.add(courseName);
  }

  const issues = {
    missing_teacher_options: [],
    missing_room_options: [],
  };

  const allOptionRows = [];
  for (const blockCode of BLOCK_CODES) {
    for (const courseName of [...blockOptionSets.get(blockCode)].sort((left, right) => left.localeCompare(right))) {
      allOptionRows.push({ bucket: `Block ${blockCode}`, course_name: courseName });
    }
  }
  for (const courseName of [...unblockedOptionSet].sort((left, right) => left.localeCompare(right))) {
    allOptionRows.push({ bucket: 'Unblocked', course_name: courseName });
  }

  for (const row of allOptionRows) {
    const meta = courseMetaByName.get(row.course_name) || { defaultTeacher: '', defaultRoom: '' };
    const fallback = fallbackByCourseName.get(row.course_name) || { teacher: '', room: '' };

    if (!(meta.defaultTeacher || fallback.teacher)) {
      issues.missing_teacher_options.push({
        bucket: row.bucket,
        course_name: row.course_name,
        default_teacher: meta.defaultTeacher,
        fallback_teacher: fallback.teacher,
      });
    }

    if (!(meta.defaultRoom || fallback.room)) {
      issues.missing_room_options.push({
        bucket: row.bucket,
        course_name: row.course_name,
        default_room: meta.defaultRoom,
        fallback_room: fallback.room,
      });
    }
  }

  const report = {
    summary: {
      block_option_count: allOptionRows.filter((row) => row.bucket !== 'Unblocked').length,
      unblocked_option_count: allOptionRows.filter((row) => row.bucket === 'Unblocked').length,
      total_option_count: allOptionRows.length,
      missing_teacher_options: issues.missing_teacher_options.length,
      missing_room_options: issues.missing_room_options.length,
    },
    breakdowns: {
      missing_teacher_by_bucket: summarizeBy(issues.missing_teacher_options, (item) => item.bucket),
      missing_teacher_by_course: summarizeBy(issues.missing_teacher_options, (item) => item.course_name),
      missing_room_by_bucket: summarizeBy(issues.missing_room_options, (item) => item.bucket),
      missing_room_by_course: summarizeBy(issues.missing_room_options, (item) => item.course_name),
    },
    samples: {
      missing_teacher_options: issues.missing_teacher_options.slice(0, 50),
      missing_room_options: issues.missing_room_options.slice(0, 50),
    },
  };

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});