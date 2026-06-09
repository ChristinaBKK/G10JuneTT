import process from 'node:process';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error(JSON.stringify({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }, null, 2));
  process.exit(1);
}

async function supabase(path, options = {}) {
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
    data = { raw: text };
  }

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${JSON.stringify(data)}`);
  }

  return data;
}

function duplicateSummary(entries) {
  const counts = new Map();
  for (const entry of entries) {
    const key = `${entry.term_name}|${entry.day_name}|${entry.start_period_id}|${entry.end_period_id}`;
    counts.set(key, (counts.get(key) || 0) + 1);
  }

  const duplicateGroups = [...counts.entries()].filter(([, count]) => count > 1);
  return {
    groups: duplicateGroups.length,
    rows: duplicateGroups.reduce((sum, [, count]) => sum + (count - 1), 0),
  };
}

const students = await supabase('/rest/v1/students?select=student_id,full_name&order=student_id.asc');
const duplicateStudents = [];
const emptyStudents = [];

for (const student of students) {
  const payload = await supabase('/rest/v1/rpc/get_student_timetable_payload', {
    method: 'POST',
    body: JSON.stringify({ p_student_id: student.student_id }),
  });

  const entries = Array.isArray(payload?.entries) ? payload.entries : [];

  if (entries.length === 0) {
    emptyStudents.push(student);
    continue;
  }

  const duplicate = duplicateSummary(entries);
  if (duplicate.groups > 0) {
    duplicateStudents.push({
      student_id: student.student_id,
      full_name: student.full_name,
      duplicate_groups: duplicate.groups,
      duplicate_rows: duplicate.rows,
    });
  }
}

console.log(
  JSON.stringify(
    {
      total_students: students.length,
      students_with_same_date_duplicate_payload_rows: duplicateStudents.length,
      students_with_empty_payload: emptyStudents.length,
      sample_duplicates: duplicateStudents.slice(0, 10),
      sample_empty: emptyStudents.slice(0, 10),
    },
    null,
    2,
  ),
);
