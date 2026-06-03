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

const blockCodes = ['A', 'B', 'C', 'D', 'E', 'F'];

const [slotOffers, enrollments, assignments, students] = await Promise.all([
  api('/rest/v1/timetable_slot_courses?select=slot_id,display_order,course_id,course:courses(name)'),
  api('/rest/v1/student_enrollments?select=student_id,course_id,block_code'),
  api('/rest/v1/student_slot_assignments?select=student_id,slot_id,source,course:courses(name)&source=eq.synced-from-enrollments'),
  api('/rest/v1/students?select=student_id'),
]);

const courseMajorityBlock = new Map();
const blockCountsByCourse = new Map();
for (const row of enrollments) {
  const code = String(row.block_code || '').toUpperCase();
  if (!blockCodes.includes(code)) {
    continue;
  }
  if (!blockCountsByCourse.has(row.course_id)) {
    blockCountsByCourse.set(row.course_id, new Map());
  }
  const map = blockCountsByCourse.get(row.course_id);
  map.set(code, (map.get(code) || 0) + 1);
}
for (const [courseId, counts] of blockCountsByCourse.entries()) {
  let bestCode = null;
  let bestCount = -1;
  for (const code of blockCodes) {
    const count = counts.get(code) || 0;
    if (count > bestCount) {
      bestCode = code;
      bestCount = count;
    }
  }
  if (bestCode && bestCount > 0) {
    courseMajorityBlock.set(courseId, bestCode);
  }
}

const slotOffersBySlot = new Map();
for (const offer of slotOffers) {
  if (!slotOffersBySlot.has(offer.slot_id)) {
    slotOffersBySlot.set(offer.slot_id, []);
  }
  slotOffersBySlot.get(offer.slot_id).push(offer);
}

const chooseBestBlock = (counts) => {
  let bestCode = null;
  let bestCount = -1;
  let bestDisplayOrder = Number.MAX_SAFE_INTEGER;
  for (const code of blockCodes) {
    const entry = counts.get(code) || { count: 0, firstDisplayOrder: Number.MAX_SAFE_INTEGER };
    if (
      entry.count > bestCount ||
      (entry.count === bestCount && entry.firstDisplayOrder < bestDisplayOrder)
    ) {
      bestCode = code;
      bestCount = entry.count;
      bestDisplayOrder = entry.firstDisplayOrder;
    }
  }
  return bestCount > 0 ? bestCode : null;
};

const slotBlock = new Map();
for (const [slotId, offers] of slotOffersBySlot.entries()) {
  const explicitCounts = new Map();
  const inferredCounts = new Map();

  for (const offer of offers) {
    const name = String(offer.course?.name || '');
    const explicitMatch = name.match(/\bBlock\s*([A-F])\b/i);
    const explicitCode = explicitMatch ? explicitMatch[1].toUpperCase() : null;
    const inferredCode = explicitCode || courseMajorityBlock.get(offer.course_id) || null;

    if (explicitCode) {
      const prev = explicitCounts.get(explicitCode) || { count: 0, firstDisplayOrder: Number.MAX_SAFE_INTEGER };
      explicitCounts.set(explicitCode, {
        count: prev.count + 1,
        firstDisplayOrder: Math.min(prev.firstDisplayOrder, Number(offer.display_order) || Number.MAX_SAFE_INTEGER),
      });
    }

    if (inferredCode) {
      const prev = inferredCounts.get(inferredCode) || { count: 0, firstDisplayOrder: Number.MAX_SAFE_INTEGER };
      inferredCounts.set(inferredCode, {
        count: prev.count + 1,
        firstDisplayOrder: Math.min(prev.firstDisplayOrder, Number(offer.display_order) || Number.MAX_SAFE_INTEGER),
      });
    }
  }

  const explicitPick = chooseBestBlock(explicitCounts);
  const inferredPick = chooseBestBlock(inferredCounts);
  slotBlock.set(slotId, explicitPick || inferredPick);
}

const enrolledBlocksByStudent = new Map();
for (const row of enrollments) {
  const code = String(row.block_code || '').toUpperCase();
  if (!blockCodes.includes(code)) {
    continue;
  }
  if (!enrolledBlocksByStudent.has(row.student_id)) {
    enrolledBlocksByStudent.set(row.student_id, new Set());
  }
  enrolledBlocksByStudent.get(row.student_id).add(code);
}

const violations = [];
for (const assignment of assignments) {
  const block = slotBlock.get(assignment.slot_id);
  if (!block || !blockCodes.includes(block)) {
    continue;
  }
  const enrolledBlocks = enrolledBlocksByStudent.get(assignment.student_id) || new Set();
  if (!enrolledBlocks.has(block)) {
    violations.push({
      student_id: assignment.student_id,
      slot_id: assignment.slot_id,
      block_code: block,
      course_name: assignment.course?.name || null,
    });
  }
}

const uniqueStudentsWithViolations = new Set(violations.map((v) => v.student_id));

console.log(JSON.stringify({
  students_checked: students.length,
  students_with_violations: uniqueStudentsWithViolations.size,
  violation_count: violations.length,
  sample_violations: violations.slice(0, 20),
}, null, 2));
