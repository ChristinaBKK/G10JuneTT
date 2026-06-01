import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

loadLocalEnvFile();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

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
    let value = line.slice(separatorIndex + 1).trim();

    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

function usage() {
  console.log(`Usage:
  node scripts/supabase-admin-sync.mjs students-tsv <path-to-tsv>
  node scripts/supabase-admin-sync.mjs timetable <path-to-json>
  node scripts/supabase-admin-sync.mjs slot-assignments <path-to-json>
  node scripts/supabase-admin-sync.mjs set-block-enrollment <student-id> <block-code> <course-name>
  node scripts/supabase-admin-sync.mjs sync-slot-assignments <student-id|all>
  node scripts/supabase-admin-sync.mjs prune-unused-courses

Required environment variables:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY

These can be exported in your shell or stored in a local .env.local file.
`);
}

function assertEnvironment() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.');
  }
}

function readJsonFile(filePath) {
  const absolutePath = path.resolve(filePath);
  return JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
}

function readTsvFile(filePath) {
  return fs.readFileSync(path.resolve(filePath), 'utf8');
}

function parseRosterTsvRows(tsv, importBatchId) {
  const lines = tsv
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean);

  if (lines.length === 0) {
    throw new Error('The roster TSV file is empty.');
  }

  const [headerLine, ...dataLines] = lines;
  const headers = headerLine.split('\t').map((value) => value.trim());
  const expectedHeaders = ['Block', 'Program', 'Cohort', 'TID', 'No', 'Student', 'SID'];
  if (expectedHeaders.some((header, index) => headers[index] !== header)) {
    throw new Error('The roster TSV header does not match the expected format.');
  }

  return dataLines.map((line, index) => {
    const columns = line.split('\t');
    if (columns.length < 7) {
      throw new Error(`Invalid roster row: ${line}`);
    }

    const [rawBlock, rawProgram, rawCohort, rawTid, rawNo, rawStudent, studentId] = columns;
    if (!String(studentId || '').trim()) {
      throw new Error(`Missing SID in row: ${line}`);
    }

    return {
      import_batch_id: importBatchId,
      row_number: index + 1,
      raw_block: rawBlock,
      raw_program: rawProgram,
      raw_cohort: rawCohort,
      raw_tid: rawTid || null,
      raw_no: rawNo || null,
      raw_student: rawStudent,
      student_id: String(studentId).trim(),
    };
  });
}

function chunkRows(rows, size) {
  const chunks = [];
  for (let index = 0; index < rows.length; index += size) {
    chunks.push(rows.slice(index, index + size));
  }
  return chunks;
}

function normaliseBlockCode(blockCode) {
  const value = String(blockCode || '').trim().toUpperCase();
  if (!['A', 'B', 'C', 'D', 'E', 'F'].includes(value)) {
    throw new Error(`Invalid block code: ${blockCode}`);
  }
  return value;
}

async function request(endpoint, options = {}) {
  const response = await fetch(`${SUPABASE_URL}${endpoint}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`${options.method || 'GET'} ${endpoint} failed: ${response.status} ${errorText}`);
  }

  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    return response.json();
  }

  return response.text();
}

async function loadCourseMap() {
  const courses = await request('/rest/v1/courses?select=id,name');
  return new Map(courses.map((course) => [course.name, course.id]));
}

async function ensureCoursesExist(courseNames) {
  if (!courseNames.length) {
    return;
  }

  await request('/rest/v1/courses?on_conflict=name', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(courseNames.map((name) => ({
      name,
      default_teacher: null,
      default_room: null,
    }))),
  });
}

async function syncSlotAssignments(targetStudentId) {
  if (targetStudentId === 'all') {
    const result = await request('/rest/v1/rpc/sync_all_student_slot_assignments', {
      method: 'POST',
      body: JSON.stringify({}),
    });
    console.log(`Synced slot assignments for ${result} students.`);
    return;
  }

  await request('/rest/v1/rpc/sync_student_slot_assignments_for_student', {
    method: 'POST',
    body: JSON.stringify({ target_student_id: targetStudentId }),
  });
  console.log(`Synced slot assignments for student ${targetStudentId}.`);
}

async function setBlockEnrollment(studentId, blockCode, courseName) {
  const resolvedBlockCode = normaliseBlockCode(blockCode);
  const trimmedCourseName = String(courseName || '').trim();
  if (!trimmedCourseName) {
    throw new Error('Course name is required for set-block-enrollment.');
  }

  await ensureCoursesExist([trimmedCourseName]);

  const courseMap = await loadCourseMap();
  const courseId = courseMap.get(trimmedCourseName);
  if (!courseId) {
    throw new Error(`Unknown course: ${trimmedCourseName}`);
  }

  await request(`/rest/v1/student_enrollments?student_id=eq.${studentId}&block_code=eq.${resolvedBlockCode}`, {
    method: 'DELETE',
    headers: {
      Prefer: 'return=minimal',
    },
  });

  await request('/rest/v1/student_enrollments', {
    method: 'POST',
    headers: {
      Prefer: 'return=minimal',
    },
    body: JSON.stringify([{ student_id: studentId, course_id: courseId, block_code: resolvedBlockCode }]),
  });

  const rows = await request(`/rest/v1/student_timetable_entries?select=term_name,day_name,slot_order,course_name&student_id=eq.${studentId}&course_name=eq.${encodeURIComponent(trimmedCourseName)}&order=term_name.asc,slot_order.asc`);
  console.log(`Updated ${studentId} block ${resolvedBlockCode} to ${trimmedCourseName}.`);
  console.log(JSON.stringify(rows, null, 2));
}

async function pruneUnusedCourses() {
  const [courses, slotCourses, enrollments, assignments] = await Promise.all([
    request('/rest/v1/courses?select=id,name&order=name.asc'),
    request('/rest/v1/timetable_slot_courses?select=course_id'),
    request('/rest/v1/student_enrollments?select=course_id'),
    request('/rest/v1/student_slot_assignments?select=course_id'),
  ]);

  const usedCourseIds = new Set([
    ...slotCourses.map((row) => row.course_id),
    ...enrollments.map((row) => row.course_id),
    ...assignments.map((row) => row.course_id),
  ]);

  const unusedCourses = courses.filter((course) => !usedCourseIds.has(course.id));
  if (!unusedCourses.length) {
    console.log('No unused courses found.');
    return;
  }

  const unusedCourseIds = unusedCourses.map((course) => course.id);
  await request(`/rest/v1/courses?id=in.(${unusedCourseIds.join(',')})`, {
    method: 'DELETE',
    headers: {
      Prefer: 'return=minimal',
    },
  });

  console.log(`Deleted ${unusedCourses.length} unused courses.`);
  console.log(JSON.stringify(unusedCourses.map((course) => course.name), null, 2));
}

async function importStudentsTsv(filePath) {
  const importBatchId = crypto.randomUUID();
  const rows = parseRosterTsvRows(readTsvFile(filePath), importBatchId);

  for (const chunk of chunkRows(rows, 500)) {
    await request('/rest/v1/student_roster_staging', {
      method: 'POST',
      headers: {
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(chunk),
    });
  }

  let result;
  try {
    result = await request('/rest/v1/rpc/import_student_roster_from_staging', {
      method: 'POST',
      body: JSON.stringify({ target_import_batch_id: importBatchId }),
    });
  } catch (error) {
    try {
      await request(`/rest/v1/student_roster_staging?import_batch_id=eq.${importBatchId}`, {
        method: 'DELETE',
        headers: {
          Prefer: 'return=minimal',
        },
      });
    } catch {
      // Preserve the original import error if staging cleanup also fails.
    }
    throw error;
  }

  console.log(`Imported TSV roster batch ${importBatchId}.`);
  console.log(JSON.stringify(result, null, 2));
}

async function upsertTimetable(filePath) {
  const payload = readJsonFile(filePath);

  if (!Array.isArray(payload.periods) || !Array.isArray(payload.courses) || !Array.isArray(payload.slots)) {
    throw new Error('Timetable payload must contain periods, courses, and slots arrays.');
  }

  await request('/rest/v1/periods?on_conflict=id', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(payload.periods),
  });

  await request('/rest/v1/courses?on_conflict=name', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(payload.courses),
  });

  const slots = payload.slots.map((slot) => ({
    term_name: slot.term_name,
    grade_level: slot.grade_level,
    day_name: slot.day_name,
    start_period_id: slot.start_period_id,
    end_period_id: slot.end_period_id,
    slot_order: slot.slot_order,
  }));

  await request('/rest/v1/timetable_slots?on_conflict=slot_order', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify(slots),
  });

  const slotRows = await request(`/rest/v1/timetable_slots?select=id,slot_order&slot_order=in.(${slots.map((slot) => slot.slot_order).join(',')})`);
  const slotIdByOrder = new Map(slotRows.map((row) => [row.slot_order, row.id]));
  const courseMap = await loadCourseMap();

  await request(`/rest/v1/timetable_slot_courses?slot_id=in.(${slotRows.map((row) => row.id).join(',')})`, {
    method: 'DELETE',
    headers: {
      Prefer: 'return=minimal',
    },
  });

  const slotCourseRows = [];
  payload.slots.forEach((slot) => {
    const slotId = slotIdByOrder.get(slot.slot_order);
    if (!slotId) {
      throw new Error(`Could not resolve slot_id for slot_order ${slot.slot_order}`);
    }

    slot.courses.forEach((courseName, index) => {
      const courseId = courseMap.get(courseName);
      if (!courseId) {
        throw new Error(`Unknown course in timetable payload: ${courseName}`);
      }

      const override = slot.overrides?.[courseName] || {};
      slotCourseRows.push({
        slot_id: slotId,
        course_id: courseId,
        display_order: index + 1,
        override_teacher: override.teacher || null,
        override_room: override.room || null,
      });
    });
  });

  if (slotCourseRows.length > 0) {
    await request('/rest/v1/timetable_slot_courses', {
      method: 'POST',
      headers: {
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(slotCourseRows),
    });
  }

  console.log(`Upserted ${payload.periods.length} periods, ${payload.courses.length} courses, ${slots.length} slots, and ${slotCourseRows.length} slot-course rows.`);
}

async function upsertSlotAssignments(filePath) {
  const payload = readJsonFile(filePath);
  if (!Array.isArray(payload)) {
    throw new Error('Slot assignment payload must be a JSON array.');
  }

  const studentIds = [...new Set(payload.map((row) => row.student_id))];
  const slotOrders = [...new Set(payload.map((row) => row.slot_order))];
  const courseNames = [...new Set(payload.map((row) => row.course_name))];

  await ensureCoursesExist(courseNames);

  const slots = await request(`/rest/v1/timetable_slots?select=id,slot_order&slot_order=in.(${slotOrders.join(',')})`);
  const slotIdByOrder = new Map(slots.map((slot) => [slot.slot_order, slot.id]));
  const courseMap = await loadCourseMap();

  for (const slotOrder of slotOrders) {
    if (!slotIdByOrder.has(slotOrder)) {
      throw new Error(`Unknown slot_order in slot assignment payload: ${slotOrder}`);
    }
  }

  for (const courseName of courseNames) {
    if (!courseMap.has(courseName)) {
      throw new Error(`Unknown course in slot assignment payload: ${courseName}`);
    }
  }

  const slotIds = slotOrders.map((slotOrder) => slotIdByOrder.get(slotOrder));
  await request(`/rest/v1/student_slot_assignments?student_id=in.(${studentIds.join(',')})&slot_id=in.(${slotIds.join(',')})`, {
    method: 'DELETE',
    headers: {
      Prefer: 'return=minimal',
    },
  });

  const rows = payload.map((row) => ({
    student_id: row.student_id,
    slot_id: slotIdByOrder.get(row.slot_order),
    course_id: courseMap.get(row.course_name),
    source: row.source || 'import',
  }));

  if (rows.length > 0) {
    await request('/rest/v1/student_slot_assignments', {
      method: 'POST',
      headers: {
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(rows),
    });
  }

  console.log(`Upserted ${rows.length} explicit student slot assignments.`);
}

async function main() {
  const [command, ...args] = process.argv.slice(2);

  if (!command || ['-h', '--help'].includes(command)) {
    usage();
    process.exit(command ? 0 : 1);
  }

  assertEnvironment();

  if (command === 'students-tsv') {
    const [filePath] = args;
    if (!filePath) {
      usage();
      process.exit(1);
    }
    await importStudentsTsv(filePath);
    return;
  }

  if (command === 'timetable') {
    const [filePath] = args;
    if (!filePath) {
      usage();
      process.exit(1);
    }
    await upsertTimetable(filePath);
    return;
  }

  if (command === 'slot-assignments') {
    const [filePath] = args;
    if (!filePath) {
      usage();
      process.exit(1);
    }
    await upsertSlotAssignments(filePath);
    return;
  }

  if (command === 'set-block-enrollment') {
    const [studentId, blockCode, ...courseParts] = args;
    const courseName = courseParts.join(' ').trim();
    if (!studentId || !blockCode || !courseName) {
      usage();
      process.exit(1);
    }
    await setBlockEnrollment(studentId, blockCode, courseName);
    return;
  }

  if (command === 'sync-slot-assignments') {
    const [targetStudentId] = args;
    if (!targetStudentId) {
      usage();
      process.exit(1);
    }
    await syncSlotAssignments(targetStudentId);
    return;
  }

  if (command === 'prune-unused-courses') {
    await pruneUnusedCourses();
    return;
  }

  throw new Error(`Unknown command: ${command}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});