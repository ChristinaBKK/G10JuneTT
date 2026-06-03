import process from 'node:process';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

async function api(path, options = {}) {
  const response = await fetch(`${url}${path}`, {
    ...options,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${JSON.stringify(data)}`);
  }

  return data;
}

const offeredRows = await api('/rest/v1/timetable_slot_courses?select=course_id');
const offeredCourseIds = new Set(offeredRows.map((row) => row.course_id));

const courses = await api('/rest/v1/courses?select=id,name');
const courseNameById = new Map(courses.map((row) => [row.id, row.name]));

const enrollments = await api('/rest/v1/student_enrollments?select=student_id,course_id');
const enrolledOfferedByStudent = new Map();
for (const row of enrollments) {
  if (!offeredCourseIds.has(row.course_id)) {
    continue;
  }
  if (!enrolledOfferedByStudent.has(row.student_id)) {
    enrolledOfferedByStudent.set(row.student_id, new Set());
  }
  enrolledOfferedByStudent.get(row.student_id).add(row.course_id);
}

const missingByStudent = [];
for (const [studentId, courseIds] of enrolledOfferedByStudent.entries()) {
  const payload = await api('/rest/v1/rpc/get_student_timetable_payload', {
    method: 'POST',
    body: JSON.stringify({ p_student_id: studentId }),
  });

  const entries = Array.isArray(payload?.entries) ? payload.entries : [];
  const payloadCourses = new Set(entries.map((entry) => String(entry.course_name || '').trim()));

  const missingCourseNames = [];
  for (const courseId of courseIds) {
    const courseName = String(courseNameById.get(courseId) || '').trim();
    if (!courseName) {
      continue;
    }
    if (!payloadCourses.has(courseName)) {
      missingCourseNames.push(courseName);
    }
  }

  if (missingCourseNames.length > 0) {
    missingByStudent.push({
      student_id: studentId,
      missing_course_count: missingCourseNames.length,
      missing_courses: missingCourseNames,
    });
  }
}

missingByStudent.sort((a, b) => b.missing_course_count - a.missing_course_count || a.student_id.localeCompare(b.student_id));

console.log(JSON.stringify({
  students_checked: enrolledOfferedByStudent.size,
  students_with_missing_enrollment_reflection: missingByStudent.length,
  sample_missing: missingByStudent.slice(0, 20),
}, null, 2));
