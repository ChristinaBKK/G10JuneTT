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

const students = await api('/rest/v1/students?select=student_id&order=student_id.asc');
let synced = 0;

for (const row of students) {
  await api('/rest/v1/rpc/sync_student_slot_assignments_for_student', {
    method: 'POST',
    body: JSON.stringify({ target_student_id: row.student_id }),
  });
  synced += 1;
  if (synced % 25 === 0) {
    console.log(`Synced ${synced}/${students.length}`);
  }
}

console.log(JSON.stringify({ total_students: students.length, synced_students: synced }, null, 2));
