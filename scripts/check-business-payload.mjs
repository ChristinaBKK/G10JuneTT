import process from 'node:process';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error(JSON.stringify({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }, null, 2));
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
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${JSON.stringify(data)}`);
  }

  return data;
}

const businessCourseIds = [146, 179, 197];
const enrollments = await api(
  `/rest/v1/student_enrollments?select=student_id,course_id&course_id=in.(${businessCourseIds.join(',')})`,
);

const studentIds = [...new Set(enrollments.map((row) => row.student_id))].sort();
const missing = [];

for (const studentId of studentIds) {
  const payload = await api('/rest/v1/rpc/get_student_timetable_payload', {
    method: 'POST',
    body: JSON.stringify({ p_student_id: studentId }),
  });

  const entries = Array.isArray(payload?.entries) ? payload.entries : [];
  const hasBusiness = entries.some((entry) => String(entry.course_name || '').includes('Business'));

  if (!hasBusiness) {
    missing.push(studentId);
  }
}

console.log(
  JSON.stringify(
    {
      students_with_business_enrollment: studentIds.length,
      students_missing_business_in_payload: missing.length,
      missing_student_ids: missing,
    },
    null,
    2,
  ),
);
