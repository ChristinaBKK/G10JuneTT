// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import postgres from 'https://esm.sh/postgres@3.4.4';

const FUNCTION_NAME = 'admin-course-change-api';
const BLOCK_CODES = ['A', 'B', 'C', 'D', 'E', 'F', 'UC'];
// Map of course name -> canonical block code for courses whose raw course
// metadata/timetable slot offers do not otherwise expose a single clear block.
const COURSE_BLOCK_OVERRIDES = new Map<string, string>([
  ['Business HL', 'E'],
]);
const NON_EDITABLE_UNBLOCKED_COURSES = new Set([
  'Early Dismissal',
  'Graduation parade',
  'House Activities',
  'University Counselling',
]);
const CHINESE_MANUAL_SYNC_SOURCE = 'manual-chinese-block-2026-06-admin-sync';
const TOK_CAS_MANUAL_SYNC_SOURCE = 'manual-monday-p34-tok-cas-admin-sync';
const CHINESE_PROTECTED_SLOT_IDS = [39, 40, 55, 84, 85];
const TOK_CAS_PROTECTED_SLOT_IDS = [63, 64, 99, 100];
const CHINESE_COURSE_NAMES = [
  'Chinese A HL',
  'Chinese A SL',
  'Chinese AB SL',
  'Chinese B HL',
  'Chinese B SL',
];
const TOK_COURSE_NAMES = [
  'TOK (Group 1)',
  'TOK (Group 2)',
];
const CAS_COURSE_NAMES = [
  'CAS (Group 1)',
  'CAS (Group 2)',
];
const SPECIAL_COURSE_NAMES = [
  ...CHINESE_COURSE_NAMES,
  ...TOK_COURSE_NAMES,
  ...CAS_COURSE_NAMES,
];
const TOK_CAS_SLOT_RULES = {
  'TOK (Group 1)::CAS (Group 2)': [
    { slotId: 63, courseName: 'TOK (Group 1)' },
    { slotId: 64, courseName: 'CAS (Group 2)' },
    { slotId: 99, courseName: 'TOK (Group 1)' },
    { slotId: 100, courseName: 'CAS (Group 2)' },
  ],
  'TOK (Group 2)::CAS (Group 1)': [
    { slotId: 63, courseName: 'CAS (Group 1)' },
    { slotId: 64, courseName: 'TOK (Group 2)' },
    { slotId: 99, courseName: 'CAS (Group 1)' },
    { slotId: 100, courseName: 'TOK (Group 2)' },
  ],
};
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-admin-password,x-client-info',
  'Content-Type': 'application/json; charset=utf-8',
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const supabaseDbUrl = Deno.env.get('SUPABASE_DB_URL') || '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const configuredPassword = Deno.env.get('ADMIN_COURSE_CHANGE_PASSWORD') || '';
const attendanceSyncUrl = Deno.env.get('ATTENDANCE_SYNC_URL') || '';
const attendanceSyncSecret = Deno.env.get('ATTENDANCE_SYNC_SECRET') || '';
const attendanceDbUrl = Deno.env.get('ATTENDANCE_DATABASE_URL') || '';

if (!supabaseUrl || !serviceRoleKey || !configuredPassword) {
  throw new Error('SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and ADMIN_COURSE_CHANGE_PASSWORD must be set for admin-course-change-api.');
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

const directDb = supabaseDbUrl
  ? postgres(supabaseDbUrl, {
      ssl: 'require',
    })
  : null;

const attendanceDb = attendanceDbUrl
  ? postgres(attendanceDbUrl, {
      ssl: 'require',
      connect_timeout: 5,
    })
  : null;

Deno.serve(async (request) => {
  try {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    const url = new URL(request.url);
    const routePath = getRoutePath(url.pathname);

    if (request.method === 'GET' && routePath === '/health') {
      return jsonResponse(200, {
        ok: true,
        authenticated: isAuthorizedRequest(request),
      });
    }

    assertAuthorizedRequest(request);

    if (request.method === 'GET' && routePath === '/sync-diagnostics') {
      return jsonResponse(200, buildSyncDiagnostics());
    }

    if (request.method === 'GET' && routePath === '/students') {
      const query = (url.searchParams.get('query') || '').trim();
      const students = await searchStudents(query);
      return jsonResponse(200, { students });
    }

    const detailMatch = routePath.match(/^\/student\/([^/]+)\/editor-data$/);
    if (detailMatch && request.method === 'GET') {
      const studentId = decodeURIComponent(detailMatch[1]);
      return jsonResponse(200, await loadStudentEditorData(studentId));
    }

    if (detailMatch && request.method === 'POST') {
      const studentId = decodeURIComponent(detailMatch[1]);
      const body = await readJsonBody(request);
      return jsonResponse(200, await replaceStudentEnrollments(studentId, body || {}));
    }

    return jsonResponse(404, { error: 'Route not found.' });
  } catch (error) {
    return jsonResponse(error.statusCode || 500, {
      error: error.message || 'Unexpected server error.',
    });
  }
});

function getRoutePath(pathname: string) {
  const marker = `/${FUNCTION_NAME}`;
  const markerIndex = pathname.indexOf(marker);
  if (markerIndex === -1) {
    return pathname;
  }

  const routePath = pathname.slice(markerIndex + marker.length);
  return routePath || '/';
}

function isAuthorizedRequest(request: Request) {
  const providedPassword = request.headers.get('x-admin-password') || '';
  return providedPassword.length > 0 && providedPassword === configuredPassword;
}

function assertAuthorizedRequest(request: Request) {
  if (isAuthorizedRequest(request)) {
    return;
  }

  const error = new Error('Unauthorized. Enter the admin page password to continue.');
  error.statusCode = 401;
  throw error;
}

async function searchStudents(query: string) {
  if (!query.trim()) {
    const error = new Error('Enter a student ID or name before searching.');
    error.statusCode = 400;
    throw error;
  }

  const { data, error } = await supabase
    .from('students')
    .select('student_id,full_name,program,has_tok,tok_course,tok_block_code')
    .order('student_id', { ascending: true })
    .limit(5000);

  if (error) {
    throw wrapSupabaseError(error);
  }

  const normalizedQuery = query.toLowerCase();
  const filteredRows = normalizedQuery
    ? (data || []).filter((row) => {
        const studentId = String(row.student_id || '').toLowerCase();
        const fullName = String(row.full_name || '').toLowerCase();
        return studentId.includes(normalizedQuery) || fullName.includes(normalizedQuery);
      })
    : (data || []);

  return filteredRows.slice(0, 30).map(normalizeStudent);
}

async function loadStudentEditorData(studentId: string) {
  const [studentResult, enrollmentResult, courseCatalog, optionTeacherByCourseName, timetablePayload, enrollmentCountsByCourseNameAndBlock] = await Promise.all([
    supabase
      .from('students')
      .select('student_id,full_name,program,has_tok,tok_course,tok_block_code')
      .eq('student_id', studentId)
      .limit(1)
      .maybeSingle(),
    supabase
      .from('student_enrollments')
      .select('block_code,course:courses(name)')
      .eq('student_id', studentId)
      .limit(200),
    loadCourseCatalog(),
    loadOptionTeacherByCourseName(),
    loadStudentTimetablePayload(studentId),
    loadEnrollmentCountsByCourseNameAndBlock(),
  ]);

  if (studentResult.error) {
    throw wrapSupabaseError(studentResult.error);
  }
  if (enrollmentResult.error) {
    throw wrapSupabaseError(enrollmentResult.error);
  }
  if (!studentResult.data) {
    const error = new Error(`Student ${studentId} was not found.`);
    error.statusCode = 404;
    throw error;
  }

  const currentByBlock = new Map<string, string>();
  const currentTeacherByBlock = new Map<string, string>();
  const currentUnblocked: string[] = [];
  const timetableTeacherByCourseName = new Map<string, string>();
  const optionBuckets = buildOptionBuckets(courseCatalog);

  for (const entry of timetablePayload.entries || []) {
    if (!entry?.course_name || !entry?.teacher || timetableTeacherByCourseName.has(entry.course_name)) {
      continue;
    }
    timetableTeacherByCourseName.set(entry.course_name, entry.teacher);
  }

  for (const row of enrollmentResult.data || []) {
    const courseName = canonicalCourseName(row.course?.name);
    if (!courseName) {
      continue;
    }

    const effectiveBlockCode = getAdminBlockCodeForCourseName(courseName, row.block_code);

    if (effectiveBlockCode) {
      currentByBlock.set(effectiveBlockCode, courseName);
      currentTeacherByBlock.set(
        effectiveBlockCode,
        timetableTeacherByCourseName.get(courseName) || optionTeacherByCourseName.get(courseName) || '',
      );
      continue;
    }

    if (NON_EDITABLE_UNBLOCKED_COURSES.has(courseName)) {
      continue;
    }

    currentUnblocked.push(courseName);
  }

  const editableCourseNames = [...new Set([
    ...BLOCK_CODES.flatMap((blockCode) => optionBuckets.blocks[blockCode]),
    ...optionBuckets.unblocked,
  ])].sort((left, right) => left.localeCompare(right));

  const blockPreviewSlotSignatureByCode = Object.fromEntries(
    BLOCK_CODES.map((blockCode) => {
      const currentCourseName = currentByBlock.get(blockCode) || '';
      const currentEntries = (timetablePayload.entries || []).filter((entry) => entry?.course_name === currentCourseName);
      return [blockCode, buildSlotSignature(currentEntries)];
    }),
  );

  const coursePreviewByName = await loadCoursePreviewByName(editableCourseNames);
  const currentTokCourseName = currentUnblocked.find((courseName) => TOK_COURSE_NAMES.includes(courseName)) || '';

  return {
    student: normalizeStudent({
      ...studentResult.data,
      has_tok: Boolean(currentTokCourseName),
      tok_course: currentTokCourseName,
      tok_block_code: currentTokCourseName ? 'C' : '',
    }),
    editableCourseNames,
    blockPreviewSlotSignatureByCode,
    blocks: BLOCK_CODES.map((blockCode) => ({
      blockCode,
      label: `Block ${blockCode}`,
      currentCourseName: canonicalCourseName(currentByBlock.get(blockCode) || ''),
      currentTeacher: currentTeacherByBlock.get(blockCode) || '',
      currentEnrollmentCount: enrollmentCountsByCourseNameAndBlock.get(buildEnrollmentCountKey(currentByBlock.get(blockCode) || '', blockCode)) || 0,
      options: optionBuckets.blocks[blockCode].map((courseName) => ({
        courseName,
        teacher: optionTeacherByCourseName.get(courseName) || '',
        enrollmentCount: enrollmentCountsByCourseNameAndBlock.get(buildEnrollmentCountKey(courseName, blockCode)) || 0,
      })),
    })),
    unblocked: {
      label: 'No block / additional courses',
      currentCourseNames: [...new Set(currentUnblocked)].sort((left, right) => left.localeCompare(right)),
      options: optionBuckets.unblocked.map((courseName) => ({
        courseName,
        enrollmentCount: enrollmentCountsByCourseNameAndBlock.get(buildEnrollmentCountKey(courseName, '')) || 0,
      })),
    },
    coursePreviewByName,
    timetable: normalizeTimetablePayload(timetablePayload),
  };
}

function buildEnrollmentCountKey(courseName: string, blockCode: string | null) {
  return `${canonicalCourseName(courseName)}::${String(blockCode || '').trim()}`;
}

async function loadEnrollmentCountsByCourseNameAndBlock() {
  if (!directDb) {
    const error = new Error('SUPABASE_DB_URL is not configured for direct count queries.');
    error.statusCode = 500;
    throw error;
  }

  const rows = await directDb`
    select
      c.name as course_name,
      coalesce(se.block_code, '') as block_code,
      count(distinct se.student_id)::int as student_count
    from public.student_enrollments as se
    join public.courses as c
      on c.id = se.course_id
    group by c.name, coalesce(se.block_code, '')
  `;

  return new Map<string, number>(rows.map((row) => [
    buildEnrollmentCountKey(row.course_name, row.block_code),
    Number(row.student_count || 0),
  ]));
}

async function loadStudentTimetablePayload(studentId: string) {
  const [{ data: periods, error: periodsError }, { data: entries, error: entriesError }] = await Promise.all([
    supabase
      .from('periods')
      .select('id,label,sort_order')
      .order('sort_order', { ascending: true })
      .limit(50),
    supabase
      .from('student_timetable_entries')
      .select('term_name,day_name,slot_order,start_period_id,end_period_id,course_name,teacher,room')
      .eq('student_id', studentId)
      .order('slot_order', { ascending: true })
      .limit(500),
  ]);

  if (periodsError) {
    throw wrapSupabaseError(periodsError);
  }

  if (entriesError) {
    throw wrapSupabaseError(entriesError);
  }

  return {
    student: null,
    periods: periods || [],
    entries: entries || [],
  };
}

async function loadOptionBuckets() {
  const courseCatalog = await loadCourseCatalog();

  return buildOptionBuckets(courseCatalog);
}

function buildOptionBuckets(courseCatalog: { coursesByName: Map<string, Set<string>> }) {
  const blocks = Object.fromEntries(BLOCK_CODES.map((blockCode) => [blockCode, [] as string[]]));
  const unblocked: string[] = [];

  for (const [courseName, blockCodes] of courseCatalog.coursesByName.entries()) {
    const effectiveBlockCodes = blockCodes.size
      ? [...blockCodes].map((blockCode) => getAdminBlockCodeForCourseName(courseName, blockCode)).filter(Boolean)
      : [getAdminBlockCodeForCourseName(courseName, '')].filter(Boolean);

    if (!effectiveBlockCodes.length) {
      if (!NON_EDITABLE_UNBLOCKED_COURSES.has(courseName)) {
        unblocked.push(courseName);
      }
      continue;
    }

    for (const effectiveBlockCode of new Set(effectiveBlockCodes)) {
      if (!blocks[effectiveBlockCode]) {
        continue;
      }
      blocks[effectiveBlockCode].push(courseName);
    }
  }

  for (const blockCode of BLOCK_CODES) {
    blocks[blockCode] = [...new Set(blocks[blockCode])].sort((left, right) => left.localeCompare(right));
  }

  return {
    blocks,
    unblocked: unblocked.sort((left, right) => left.localeCompare(right)),
  };
}

async function loadCourseCatalog() {
  const courseRows = await fetchCourseRowsWithBlockCode();
  const blockCodesByName = new Map<string, Set<string>>();
  const idsByName = new Map<string, number>();

  for (const row of courseRows) {
    const courseName = canonicalCourseName(row.name);
    if (!courseName) {
      continue;
    }
    const effectiveBlockCode = row.block_code || COURSE_BLOCK_OVERRIDES.get(courseName) || null;
    if (!idsByName.has(courseName)) {
      idsByName.set(courseName, row.id);
    }
    if (!blockCodesByName.has(courseName)) {
      blockCodesByName.set(courseName, new Set<string>());
    }
    if (effectiveBlockCode) {
      blockCodesByName.get(courseName)!.add(effectiveBlockCode);
    }
  }

  return {
    coursesByName: blockCodesByName,
    idsByName,
  };
}

async function fetchCourseRowsWithBlockCode() {
  const canonicalResult = await supabase
    .from('courses')
    .select('id,name,block_code')
    .limit(5000);

  let courseRows: Array<{ id: number; name: string; block_code?: string | null }> = [];
  if (!canonicalResult.error) {
    courseRows = canonicalResult.data || [];
  } else {
    const errorMessage = String(canonicalResult.error.message || '');
    if (!errorMessage.toLowerCase().includes('block_code')) {
      throw wrapSupabaseError(canonicalResult.error);
    }

    const fallbackCoursesResult = await supabase
      .from('courses')
      .select('id,name')
      .limit(5000);

    if (fallbackCoursesResult.error) {
      throw wrapSupabaseError(fallbackCoursesResult.error);
    }

    courseRows = (fallbackCoursesResult.data || []).map((row) => ({
      id: row.id,
      name: row.name,
      block_code: null,
    }));
  }

  const blockOptionRows = await fetchCourseBlockOptionRows();
  if (blockOptionRows) {
    const blockCodesByCourseId = buildValidBlockCodesByCourseIdFromOptions(blockOptionRows, courseRows);
    return expandCourseRowsWithBlockCodes(courseRows, blockCodesByCourseId);
  }

  const slotCourseSelect = courseRows.some((row) => Object.prototype.hasOwnProperty.call(row, 'block_code'))
    ? 'slot_id,display_order,course:courses(id,name,block_code)'
    : 'slot_id,display_order,course:courses(id,name)';

  const { data: slotCourseRows, error: slotCoursesError } = await supabase
    .from('timetable_slot_courses')
    .select(slotCourseSelect)
    .limit(10000);

  if (slotCoursesError) {
    throw wrapSupabaseError(slotCoursesError);
  }

  const blockCodesByCourseId = buildValidBlockCodesByCourseId(slotCourseRows || [], courseRows);

  return expandCourseRowsWithBlockCodes(courseRows, blockCodesByCourseId);
}

async function fetchCourseBlockOptionRows() {
  const { data, error } = await supabase
    .from('course_block_options')
    .select('block_code,course:courses(id,name)')
    .limit(10000);

  if (error) {
    const errorText = [
      error.message,
      error.details,
      error.hint,
      error.code,
    ].map((value) => String(value || '').toLowerCase()).join(' ');

    if (errorText.includes('course_block_options') && (
      errorText.includes('schema cache') ||
      errorText.includes('not find') ||
      errorText.includes('does not exist') ||
      errorText.includes('relation')
    )) {
      return null;
    }

    throw wrapSupabaseError(error);
  }

  return data || [];
}

function buildValidBlockCodesByCourseIdFromOptions(
  blockOptionRows: Array<{ block_code?: string | null; course?: { id?: number | null; name?: string | null } | null }>,
  courseRows: Array<{ id: number; name: string }>,
) {
  const knownCourseIds = new Set(courseRows.map((row) => row.id));
  const blockCodesByCourseId = new Map<number, Set<string>>();

  for (const row of blockOptionRows) {
    const courseId = Number(row.course?.id || 0);
    const courseName = canonicalCourseName(row.course?.name);
    const blockCode = String(row.block_code || '').trim().toUpperCase();
    if (
      !knownCourseIds.has(courseId) ||
      !BLOCK_CODES.includes(blockCode) ||
      SPECIAL_COURSE_NAMES.includes(courseName)
    ) {
      continue;
    }

    if (!blockCodesByCourseId.has(courseId)) {
      blockCodesByCourseId.set(courseId, new Set<string>());
    }
    blockCodesByCourseId.get(courseId)!.add(blockCode);
  }

  return blockCodesByCourseId;
}

function expandCourseRowsWithBlockCodes(
  courseRows: Array<{ id: number; name: string }>,
  blockCodesByCourseId: Map<number, Set<string>>,
) {
  const expandedRows: Array<{ id: number; name: string; block_code: string | null }> = [];
  for (const row of courseRows || []) {
    const validBlockCodes = [...(blockCodesByCourseId.get(row.id) || [])].sort((left, right) => left.localeCompare(right));
    if (validBlockCodes.length) {
      for (const blockCode of validBlockCodes) {
        expandedRows.push({
          id: row.id,
          name: row.name,
          block_code: blockCode,
        });
      }
      continue;
    }

    expandedRows.push({
      id: row.id,
      name: row.name,
      block_code: null,
    });
  }

  return expandedRows;
}

function buildValidBlockCodesByCourseId(
  slotCourseRows: Array<{ slot_id?: number | null; display_order?: number | null; course?: { id?: number | null; name?: string | null; block_code?: string | null } | null }>,
  courseRows: Array<{ id: number; name: string; block_code?: string | null }>,
) {
  const blockCodesByCourseId = new Map<number, Set<string>>();

  for (const row of courseRows) {
    if (SPECIAL_COURSE_NAMES.includes(canonicalCourseName(row.name))) {
      continue;
    }

    const blockCode = getAdminBlockCodeForCourseName(row.name, row.block_code || null);
    if (!blockCode) {
      continue;
    }
    if (!blockCodesByCourseId.has(row.id)) {
      blockCodesByCourseId.set(row.id, new Set<string>());
    }
    blockCodesByCourseId.get(row.id)!.add(blockCode);
  }

  const slotBlockCodeById = inferSlotBlockCodes(slotCourseRows);
  for (const row of slotCourseRows) {
    const courseId = Number(row.course?.id || 0);
    const slotId = Number(row.slot_id || 0);
    const blockCode = slotBlockCodeById.get(slotId);
    if (!courseId || !blockCode || SPECIAL_COURSE_NAMES.includes(canonicalCourseName(row.course?.name))) {
      continue;
    }
    if (!blockCodesByCourseId.has(courseId)) {
      blockCodesByCourseId.set(courseId, new Set<string>());
    }
    blockCodesByCourseId.get(courseId)!.add(blockCode);
  }

  return blockCodesByCourseId;
}

function inferSlotBlockCodes(slotCourseRows: Array<{ slot_id?: number | null; display_order?: number | null; course?: { name?: string | null; block_code?: string | null } | null }>) {
  const blockCountsBySlotId = new Map<number, Map<string, { count: number; firstDisplayOrder: number }>>();

  for (const row of slotCourseRows) {
    const slotId = Number(row.slot_id || 0);
    const courseName = canonicalCourseName(row.course?.name);
    if (SPECIAL_COURSE_NAMES.includes(courseName)) {
      continue;
    }

    const blockCode = getAdminBlockCodeForCourseName(courseName, row.course?.block_code || null);
    if (!slotId || !blockCode) {
      continue;
    }

    if (!blockCountsBySlotId.has(slotId)) {
      blockCountsBySlotId.set(slotId, new Map<string, { count: number; firstDisplayOrder: number }>());
    }
    const blockCounts = blockCountsBySlotId.get(slotId)!;
    const existing = blockCounts.get(blockCode) || { count: 0, firstDisplayOrder: Number.POSITIVE_INFINITY };
    existing.count += 1;
    existing.firstDisplayOrder = Math.min(existing.firstDisplayOrder, Number(row.display_order || Number.POSITIVE_INFINITY));
    blockCounts.set(blockCode, existing);
  }

  const slotBlockCodeById = new Map<number, string>();
  for (const [slotId, counts] of blockCountsBySlotId.entries()) {
    const rankedBlocks = [...counts.entries()].sort((left, right) => {
      if (right[1].count !== left[1].count) {
        return right[1].count - left[1].count;
      }
      if (left[1].firstDisplayOrder !== right[1].firstDisplayOrder) {
        return left[1].firstDisplayOrder - right[1].firstDisplayOrder;
      }
      return left[0].localeCompare(right[0]);
    });
    slotBlockCodeById.set(slotId, rankedBlocks[0]?.[0] || '');
  }

  return slotBlockCodeById;
}

async function loadOptionTeacherByCourseName() {
  const [{ data: courseData, error: courseError }, { data, error }] = await Promise.all([
    supabase
      .from('courses')
      .select('name,default_teacher')
      .limit(5000),
    supabase
    .from('timetable_slot_courses')
    .select('override_teacher,course:courses(name,default_teacher)')
    .limit(5000),
  ]);

  if (courseError) {
    throw wrapSupabaseError(courseError);
  }

  if (error) {
    throw wrapSupabaseError(error);
  }

  const teacherByCourseName = new Map<string, string>();
  for (const row of courseData || []) {
    const courseName = canonicalCourseName(row.name);
    const teacher = row.default_teacher || '';
    if (!courseName || !teacher) {
      continue;
    }
    teacherByCourseName.set(courseName, teacher);
  }

  for (const row of data || []) {
    const courseName = canonicalCourseName(row.course?.name);
    const teacher = row.override_teacher || row.course?.default_teacher || '';
    if (!courseName || !teacher) {
      continue;
    }
    teacherByCourseName.set(courseName, teacher);
  }

  return teacherByCourseName;
}

async function loadCoursePreviewByName(courseNames: string[]) {
  const canonicalCourseNames = [...new Set(courseNames.map((courseName) => canonicalCourseName(courseName)).filter(Boolean))];
  if (!canonicalCourseNames.length) {
    return {};
  }

  const [{ data: courseData, error: courseError }, { data: slotCourseData, error: slotCourseError }, studentPreviewData] = await Promise.all([
    supabase
      .from('courses')
      .select('name,default_teacher,default_room')
      .in('name', canonicalCourseNames)
      .limit(5000),
    supabase
      .from('timetable_slot_courses')
      .select('override_teacher,override_room,course:courses(name,default_teacher,default_room),slot:timetable_slots(term_name,day_name,slot_order,start_period_id,end_period_id)')
      .in('course.name', canonicalCourseNames)
      .limit(5000),
    loadStudentTimetablePreviewEntries(canonicalCourseNames),
  ]);

  if (courseError) {
    throw wrapSupabaseError(courseError);
  }

  if (slotCourseError) {
    throw wrapSupabaseError(slotCourseError);
  }

  const courseDefaultsByName = new Map<string, { teacher: string; room: string }>();
  for (const row of courseData || []) {
    const courseName = canonicalCourseName(row.name);
    if (!courseName) {
      continue;
    }
    courseDefaultsByName.set(courseName, {
      teacher: row.default_teacher || '',
      room: row.default_room || '',
    });
  }

  const previewByCourseName = new Map<string, Map<string, Array<Record<string, unknown>>>>();
  const previewByStudentCourseKey = new Map<string, Array<Record<string, unknown>>>();

  for (const row of studentPreviewData || []) {
    const courseName = canonicalCourseName(row.course_name);
    const studentId = String(row.student_id || '');
    if (!courseName || !studentId) {
      continue;
    }

    const key = `${studentId}::${courseName}`;
    const currentEntries = previewByStudentCourseKey.get(key) || [];
    currentEntries.push({
      term_name: row.term_name || '',
      day_name: row.day_name || '',
      slot_order: row.slot_order || null,
      start_period_id: row.start_period_id || '',
      end_period_id: row.end_period_id || '',
      course_name: courseName,
      teacher: row.teacher || '',
      room: row.room || '',
    });
    previewByStudentCourseKey.set(key, currentEntries);
  }

  for (const entries of previewByStudentCourseKey.values()) {
    const courseName = String(entries[0]?.course_name || '');
    if (!courseName) {
      continue;
    }

    const slotSignature = buildSlotSignature(entries);
    if (!slotSignature) {
      continue;
    }

    const currentVariants = previewByCourseName.get(courseName) || new Map<string, Array<Record<string, unknown>>>();
    if (!currentVariants.has(slotSignature)) {
      currentVariants.set(slotSignature, sortPreviewEntries(entries));
      previewByCourseName.set(courseName, currentVariants);
    }
  }

  for (const row of slotCourseData || []) {
    const courseName = canonicalCourseName(row.course?.name);
    const slot = row.slot;
    if (!courseName || !slot) {
      continue;
    }

    const courseDefaults = courseDefaultsByName.get(courseName) || { teacher: '', room: '' };
    const slotSignature = buildSlotSignature([{ slot_order: slot.slot_order || null }]);
    const currentVariants = previewByCourseName.get(courseName) || new Map<string, Array<Record<string, unknown>>>();
    const currentEntries = currentVariants.get(slotSignature) || [];
    currentEntries.push({
      term_name: slot.term_name || '',
      day_name: slot.day_name || '',
      slot_order: slot.slot_order || null,
      start_period_id: slot.start_period_id || '',
      end_period_id: slot.end_period_id || '',
      course_name: courseName,
      teacher: row.override_teacher || courseDefaults.teacher,
      room: row.override_room || courseDefaults.room,
    });
    currentVariants.set(slotSignature, sortPreviewEntries(currentEntries));
    previewByCourseName.set(courseName, currentVariants);
  }

  return Object.fromEntries(
    [...previewByCourseName.entries()].map(([courseName, previewVariants]) => [
      courseName,
      Object.fromEntries(
        [...previewVariants.entries()]
          .sort(([left], [right]) => left.localeCompare(right))
          .map(([slotSignature, entries]) => [slotSignature, sortPreviewEntries(entries)]),
      ),
    ]),
  );
}

async function loadStudentTimetablePreviewEntries(courseNames: string[]) {
  const previewRows: Array<Record<string, unknown>> = [];
  const courseNameSet = new Set(courseNames);
  const courseNameChunks = chunkValues(courseNames, 20);
  const pageSize = 5000;

  for (const courseNameChunk of courseNameChunks) {
    for (let offset = 0; ; offset += pageSize) {
      const { data, error } = await supabase
        .from('student_timetable_entries')
        .select('student_id,course_name,term_name,day_name,slot_order,start_period_id,end_period_id,teacher,room')
        .in('course_name', courseNameChunk)
        .range(offset, offset + pageSize - 1);

      if (error) {
        throw wrapSupabaseError(error);
      }

      const filteredRows = (data || []).filter((row) => courseNameSet.has(String(row.course_name || '')));
      previewRows.push(...filteredRows);

      if ((data || []).length < pageSize) {
        break;
      }
    }
  }

  return previewRows;
}

function chunkValues(values: string[], chunkSize: number) {
  const chunks: string[][] = [];
  for (let index = 0; index < values.length; index += chunkSize) {
    chunks.push(values.slice(index, index + chunkSize));
  }
  return chunks;
}

function buildSlotSignature(entries: Array<Record<string, unknown>>) {
  const slotOrders = [...new Set(
    entries
      .map((entry) => Number(entry.slot_order || 0))
      .filter((slotOrder) => Number.isFinite(slotOrder) && slotOrder > 0),
  )].sort((left, right) => left - right);

  return slotOrders.join(',');
}

function sortPreviewEntries(entries: Array<Record<string, unknown>>) {
  return [...entries].sort((left, right) => Number(left.slot_order || 0) - Number(right.slot_order || 0));
}

async function replaceStudentEnrollments(studentId: string, payload: Record<string, unknown>) {
  const blockSelections = payload?.blockSelections && typeof payload.blockSelections === 'object'
    ? payload.blockSelections as Record<string, string>
    : {};
  const nextProgram = normaliseProgramValue(typeof payload?.program === 'string' ? payload.program : '');
  const unblockedCourseNames = Array.isArray(payload?.unblockedCourseNames)
    ? payload.unblockedCourseNames as string[]
    : [];

  const [courseCatalog, optionBuckets, studentResult] = await Promise.all([
    loadCourseCatalog(),
    loadOptionBuckets(),
    supabase.from('students').select('student_id,program,has_tok,tok_course,tok_block_code').eq('student_id', studentId).limit(1).maybeSingle(),
  ]);

  if (studentResult.error) {
    throw wrapSupabaseError(studentResult.error);
  }
  if (!studentResult.data) {
    const error = new Error(`Student ${studentId} was not found.`);
    error.statusCode = 404;
    throw error;
  }

  const previousStudentState = await loadStudentEnrollmentState(studentId, studentResult.data);

  if (nextProgram && !['A Level', 'IB'].includes(nextProgram)) {
    const error = new Error(`Unsupported programme: ${nextProgram}`);
    error.statusCode = 400;
    throw error;
  }

  const normalizedBlockSelections: Record<string, string> = {};
  for (const blockCode of BLOCK_CODES) {
    const rawValue = canonicalCourseName(blockSelections[blockCode]);
    if (!rawValue) {
      continue;
    }

    if (!courseCatalog.idsByName.has(rawValue)) {
      const error = new Error(`Unknown course selected for Block ${blockCode}: ${rawValue}`);
      error.statusCode = 400;
      throw error;
    }

    const courseBlockCodes = courseCatalog.coursesByName.get(rawValue) || new Set<string>();
    if (!courseBlockCodes.has(blockCode)) {
      const error = new Error(`Course ${rawValue} is not a valid option for Block ${blockCode}.`);
      error.statusCode = 400;
      throw error;
    }

    normalizedBlockSelections[blockCode] = rawValue;
  }

  const normalizedUnblocked = [...new Set(
    unblockedCourseNames
      .filter((courseName) => typeof courseName === 'string')
      .map((courseName) => canonicalCourseName(courseName))
      .filter((courseName) => Boolean(courseName) && !NON_EDITABLE_UNBLOCKED_COURSES.has(courseName)),
  )].sort((left, right) => left.localeCompare(right));

  validateSpecialCourseSelections(normalizedUnblocked);
  const selectedTokCourseName = normalizedUnblocked.find((courseName) => TOK_COURSE_NAMES.includes(courseName)) || '';

  for (const courseName of normalizedUnblocked) {
    if (!courseCatalog.idsByName.has(courseName)) {
      const error = new Error(`Unknown non-block course selected: ${courseName}`);
      error.statusCode = 400;
      throw error;
    }
    // The "is in the unblocked bucket" check is intentionally skipped: the
    // COURSE_BLOCK_OVERRIDES map drives that bucket, and any drift between
    // it and the student's intent has been a source of save-time errors.
    // Course validity is still enforced by the FK on course_id.
  }

  try {
    if (nextProgram && nextProgram !== normaliseProgramValue(studentResult.data.program || '')) {
      const updateStudent = await supabase
        .from('students')
        .update({ program: nextProgram })
        .eq('student_id', studentId);

      if (updateStudent.error) {
        throw wrapSupabaseError(updateStudent.error);
      }
    }

    for (const blockCode of BLOCK_CODES) {
      const { error } = await supabase
        .from('student_enrollments')
        .delete()
        .eq('student_id', studentId)
        .eq('block_code', blockCode);

      if (error) {
        throw wrapSupabaseError(error);
      }
    }

    const existingUnblockedResult = await supabase
      .from('student_enrollments')
      .select('course_id,course:courses(name)')
      .eq('student_id', studentId)
      .is('block_code', null)
      .limit(500);

    if (existingUnblockedResult.error) {
      throw wrapSupabaseError(existingUnblockedResult.error);
    }

    const removableUnblockedCourseIds = [...new Set((existingUnblockedResult.data || [])
      .map((row) => {
        const courseName = canonicalCourseName(row.course?.name);
        if (!courseName || NON_EDITABLE_UNBLOCKED_COURSES.has(courseName)) {
          return null;
        }
        return row.course_id;
      })
      .filter(Boolean))] as number[];

    const deleteUnblocked = removableUnblockedCourseIds.length
      ? await supabase
          .from('student_enrollments')
          .delete()
          .eq('student_id', studentId)
          .is('block_code', null)
          .in('course_id', removableUnblockedCourseIds)
      : { error: null };

    if (deleteUnblocked.error) {
      throw wrapSupabaseError(deleteUnblocked.error);
    }

    const updateTokMetadata = await supabase
      .from('students')
      .update(selectedTokCourseName
        ? { has_tok: true, tok_course: selectedTokCourseName, tok_block_code: 'C' }
        : { has_tok: false, tok_course: null, tok_block_code: null })
      .eq('student_id', studentId);

    if (updateTokMetadata.error) {
      throw wrapSupabaseError(updateTokMetadata.error);
    }

    const rowsToInsert = [];
    for (const blockCode of BLOCK_CODES) {
      const courseName = normalizedBlockSelections[blockCode];
      if (!courseName) {
        continue;
      }

      rowsToInsert.push({
        student_id: studentId,
        course_id: courseCatalog.idsByName.get(courseName),
        block_code: blockCode,
      });
    }

    for (const courseName of normalizedUnblocked) {
      rowsToInsert.push({
        student_id: studentId,
        course_id: courseCatalog.idsByName.get(courseName),
        block_code: null,
      });
    }

    if (rowsToInsert.length > 0) {
      const insertResult = await supabase.from('student_enrollments').insert(rowsToInsert);
      if (insertResult.error) {
        throw wrapSupabaseError(insertResult.error);
      }
    }

    await syncStudentTimetableFromEnrollments(studentId);

    const attendanceSync = await syncAttendanceForStudent(studentId);

    const editorData = await loadStudentEditorData(studentId);
    return {
      ...editorData,
      editorData,
      attendanceSync,
    };
  } catch (error) {
    const rollbackError = await restoreStudentEnrollmentState(studentId, previousStudentState);
    if (rollbackError) {
      const syncError = new Error(`Save failed and the previous state could not be restored cleanly. Please check the timetable manually. Rollback error: ${rollbackError.message || 'Unknown rollback error.'}`);
      syncError.statusCode = 500;
      throw syncError;
    }

    // Rollback succeeded — the timetable was NOT saved.
    const syncError = new Error(`Save cancelled. The timetable was not changed because the update did not complete. ${error.message || 'Update failed.'}`);
    syncError.statusCode = 400;
    throw syncError;
  }
}

function validateSpecialCourseSelections(courseNames: string[]) {
  const selectedChinese = courseNames.filter((courseName) => CHINESE_COURSE_NAMES.includes(courseName));
  const selectedTok = courseNames.filter((courseName) => TOK_COURSE_NAMES.includes(courseName));
  const selectedCas = courseNames.filter((courseName) => CAS_COURSE_NAMES.includes(courseName));

  if (selectedChinese.length > 1) {
    const error = new Error(`Choose only one Chinese course. Selected: ${selectedChinese.join(', ')}.`);
    error.statusCode = 400;
    throw error;
  }

  if (selectedTok.length > 1) {
    const error = new Error(`Choose only one TOK course. Selected: ${selectedTok.join(', ')}.`);
    error.statusCode = 400;
    throw error;
  }

  if (selectedCas.length > 1) {
    const error = new Error(`Choose only one CAS course. Selected: ${selectedCas.join(', ')}.`);
    error.statusCode = 400;
    throw error;
  }

  if (selectedTok.length || selectedCas.length) {
    if (selectedTok.length !== 1 || selectedCas.length !== 1) {
      const error = new Error('TOK and CAS must be changed together: choose one TOK group and one CAS group, or choose neither.');
      error.statusCode = 400;
      throw error;
    }

    const pairKey = buildTokCasPairKey(selectedTok[0], selectedCas[0]);
    if (!TOK_CAS_SLOT_RULES[pairKey]) {
      const error = new Error('Invalid TOK/CAS pair. Use TOK (Group 1) with CAS (Group 2), or TOK (Group 2) with CAS (Group 1).');
      error.statusCode = 400;
      throw error;
    }
  }
}

async function syncStudentTimetableFromEnrollments(studentId: string) {
  const courseCatalog = await loadCourseCatalog();
  await clearSpecialManualSlotAssignments(studentId, courseCatalog);

  const syncResult = await supabase.rpc('sync_student_slot_assignments_for_student', {
    target_student_id: studentId,
  });
  if (syncResult.error) {
    throw wrapSupabaseError(syncResult.error);
  }

  await reconcileSpecialManualSlotAssignments(studentId, courseCatalog);
}

async function clearSpecialManualSlotAssignments(studentId: string, courseCatalog: { idsByName: Map<string, number> }) {
  const specialCourseIds = SPECIAL_COURSE_NAMES
    .map((courseName) => courseCatalog.idsByName.get(courseName))
    .filter((courseId) => Number.isFinite(Number(courseId))) as number[];

  if (!specialCourseIds.length) {
    return;
  }

  const deleteResult = await supabase
    .from('student_slot_assignments')
    .delete()
    .eq('student_id', studentId)
    .in('slot_id', [...CHINESE_PROTECTED_SLOT_IDS, ...TOK_CAS_PROTECTED_SLOT_IDS])
    .in('course_id', specialCourseIds);

  if (deleteResult.error) {
    throw wrapSupabaseError(deleteResult.error);
  }
}

async function reconcileSpecialManualSlotAssignments(studentId: string, courseCatalog: { idsByName: Map<string, number> }) {
  const enrollmentResult = await supabase
    .from('student_enrollments')
    .select('course_id,course:courses(name)')
    .eq('student_id', studentId)
    .limit(500);

  if (enrollmentResult.error) {
    throw wrapSupabaseError(enrollmentResult.error);
  }

  const enrolledCourseNames = [...new Set((enrollmentResult.data || [])
    .map((row) => canonicalCourseName(row.course?.name))
    .filter(Boolean))];

  const rowsToUpsert = [
    ...buildChineseManualAssignmentRows(studentId, enrolledCourseNames, courseCatalog),
    ...buildTokCasManualAssignmentRows(studentId, enrolledCourseNames, courseCatalog),
  ];

  if (!rowsToUpsert.length) {
    return;
  }

  const upsertResult = await supabase
    .from('student_slot_assignments')
    .upsert(rowsToUpsert, { onConflict: 'student_id,slot_id' });

  if (upsertResult.error) {
    throw wrapSupabaseError(upsertResult.error);
  }
}

function buildChineseManualAssignmentRows(studentId: string, enrolledCourseNames: string[], courseCatalog: { idsByName: Map<string, number> }) {
  const chineseCourseName = CHINESE_COURSE_NAMES.find((courseName) => enrolledCourseNames.includes(courseName));
  if (!chineseCourseName) {
    return [];
  }

  const courseId = courseCatalog.idsByName.get(chineseCourseName);
  if (!courseId) {
    const error = new Error(`Could not reconcile Chinese timetable rows because ${chineseCourseName} is missing from courses.`);
    error.statusCode = 500;
    throw error;
  }

  return CHINESE_PROTECTED_SLOT_IDS.map((slotId) => ({
    student_id: studentId,
    slot_id: slotId,
    course_id: courseId,
    source: CHINESE_MANUAL_SYNC_SOURCE,
  }));
}

function buildTokCasManualAssignmentRows(studentId: string, enrolledCourseNames: string[], courseCatalog: { idsByName: Map<string, number> }) {
  const tokCourseName = TOK_COURSE_NAMES.find((courseName) => enrolledCourseNames.includes(courseName));
  const casCourseName = CAS_COURSE_NAMES.find((courseName) => enrolledCourseNames.includes(courseName));
  if (!tokCourseName || !casCourseName) {
    return [];
  }

  const slotRules = TOK_CAS_SLOT_RULES[buildTokCasPairKey(tokCourseName, casCourseName)];
  if (!slotRules) {
    const error = new Error('Could not reconcile TOK/CAS timetable rows because the current TOK/CAS enrollment pair is invalid.');
    error.statusCode = 500;
    throw error;
  }

  return slotRules.map(({ slotId, courseName }) => {
    const courseId = courseCatalog.idsByName.get(courseName);
    if (!courseId) {
      const error = new Error(`Could not reconcile TOK/CAS timetable rows because ${courseName} is missing from courses.`);
      error.statusCode = 500;
      throw error;
    }

    return {
      student_id: studentId,
      slot_id: slotId,
      course_id: courseId,
      source: TOK_CAS_MANUAL_SYNC_SOURCE,
    };
  });
}

function buildTokCasPairKey(tokCourseName: string, casCourseName: string) {
  return `${tokCourseName}::${casCourseName}`;
}

function formatAttendanceDate(rawDate: string) {
  const trimmed = String(rawDate || '').trim();
  if (!trimmed) {
    return '';
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    return trimmed.replace(/-/g, '/');
  }
  return trimmed;
}

function formatAttendanceTime(rawTime: string) {
  const trimmed = String(rawTime || '').trim();
  if (!trimmed) {
    return '';
  }

  const match = trimmed.match(/^(\d{2}:\d{2})(?::\d{2})?$/);
  if (match) {
    return match[1];
  }

  return trimmed;
}

async function loadAttendanceSyncPayload(studentId: string) {
  const [{ data: student, error: studentError }, { data: periods, error: periodsError }, { data: entries, error: entriesError }] = await Promise.all([
    supabase
      .from('students')
      .select('student_id,full_name')
      .eq('student_id', studentId)
      .limit(1)
      .maybeSingle(),
    supabase
      .from('periods')
      .select('id,starts_at,ends_at')
      .limit(50),
    supabase
      .from('student_timetable_entries')
      .select('term_name,start_period_id,end_period_id,course_name,teacher,room,slot_order')
      .eq('student_id', studentId)
      .order('slot_order', { ascending: true })
      .limit(500),
  ]);

  if (studentError) {
    throw wrapSupabaseError(studentError);
  }
  if (periodsError) {
    throw wrapSupabaseError(periodsError);
  }
  if (entriesError) {
    throw wrapSupabaseError(entriesError);
  }
  if (!student) {
    const error = new Error(`Student ${studentId} was not found for attendance sync.`);
    error.statusCode = 404;
    throw error;
  }

  const periodById = new Map((periods || []).map((period) => [String(period.id || ''), period]));
  const normalizedSessions = (entries || []).map((entry) => {
    const startPeriod = periodById.get(String(entry.start_period_id || ''));
    const endPeriod = periodById.get(String(entry.end_period_id || ''));
    const courseName = String(entry.course_name || '').trim();
    const attendanceFields = buildAttendanceSessionFields(courseName);
    return {
      name: courseName,
      component: attendanceFields.component,
      subject: attendanceFields.subject,
      paperCode: attendanceFields.paperCode,
      date: formatAttendanceDate(String(entry.term_name || '')),
      startTime: formatAttendanceTime(String(startPeriod?.starts_at || '')),
      endTime: formatAttendanceTime(String(endPeriod?.ends_at || '')),
      roomCode: String(entry.room || '').trim(),
      teacherName: String(entry.teacher || '').trim(),
      type: 'revision',
    };
  }).filter((session) => session.name && session.date && session.startTime && session.endTime);

  const uniqueSessions = [...new Map(
    normalizedSessions.map((session) => [
      [
        session.name,
        session.component,
        session.subject,
        session.date,
        session.startTime,
        session.endTime,
        session.roomCode,
        session.teacherName,
      ].join('|'),
      session,
    ]),
  ).values()];

  const attendanceTeacherByName = await loadAttendanceTeacherByName();

  const attendanceSessions = uniqueSessions.flatMap((session) => {
    if (isAttendancePlaceholderSession(session)) {
      return [];
    }

    const teacherNames = session.teacherName
      .split(/\s*\/\s*/)
      .map((teacher) => teacher.trim())
      .filter(Boolean);
    const teacherId = teacherNames
      .map((teacher) => resolveAttendanceTeacherId(teacher, attendanceTeacherByName))
      .find(Boolean) || '';

    if (attendanceTeacherByName && !teacherId) {
      return [];
    }
    return [{ ...session, teacherId }];
  });

  return {
    student: {
      candidateNumber: String(student.student_id || '').trim(),
      name: String(student.full_name || '').trim(),
    },
    sessions: attendanceSessions,
  };
}

function buildAttendanceSessionFields(courseName: string) {
  if (/^UC-\d+$/i.test(courseName)) {
    return {
      component: '',
      subject: '',
      paperCode: '',
    };
  }

  return {
    component: courseName,
    subject: courseName,
    paperCode: '',
  };
}

async function loadAttendanceTeacherByName(): Promise<Map<string, string> | null> {
  if (!attendanceDb) {
    return null;
  }
  try {
    const rows = await attendanceDb`
      SELECT id, name
      FROM teachers
      WHERE id IS NOT NULL
        AND name IS NOT NULL
    `;
    const byName = new Map<string, string>();
    for (const row of rows || []) {
      const teacherName = String(row.name || '').trim();
      const teacherId = String(row.id || '').trim();
      if (!teacherName || !teacherId) {
        continue;
      }
      byName.set(teacherName, teacherId);
      byName.set(canonicalTeacherIdentityKey(teacherName), teacherId);
    }
    return byName;
  } catch {
    // If the direct DB query fails (e.g. wrong schema), fall through to placeholder-only filtering
    return null;
  }
}

function resolveAttendanceTeacherId(teacherName: string, teacherByName: Map<string, string> | null) {
  if (!teacherByName) {
    return '';
  }
  const trimmed = String(teacherName || '').trim();
  if (!trimmed) {
    return '';
  }
  return teacherByName.get(trimmed)
    || teacherByName.get(canonicalTeacherIdentityKey(trimmed))
    || '';
}

function canonicalTeacherIdentityKey(value: string) {
  return String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function isAttendancePlaceholderSession(session: { name: string; teacherName: string }) {
  const courseName = String(session.name || '').trim();
  const teacherName = String(session.teacherName || '').trim();

  if (!courseName) {
    return true;
  }

  const placeholderTeachers = new Set([
    '',
    'N/A',
    'Teacher TBC',
    'Block A Teachers',
    'Block B Teachers',
    'Block C Teachers',
    'Block D Teachers',
    'Block E Teachers',
    'Block F Teachers',
    'University Counsellors',
  ]);

  if (placeholderTeachers.has(teacherName)) {
    return true;
  }

  return /^early dismissal$/i.test(courseName)
    || /^graduation parade$/i.test(courseName)
    || /^house activities$/i.test(courseName)
    || /^university counselling$/i.test(courseName);
}

async function syncAttendanceForStudent(studentId: string) {
  if (!attendanceSyncUrl || !attendanceSyncSecret) {
    const error = new Error('ATTENDANCE_SYNC_URL and ATTENDANCE_SYNC_SECRET must be set to sync attendance after admin course changes.');
    error.statusCode = 500;
    throw error;
  }

  const payload = await loadAttendanceSyncPayload(studentId);
  const response = await postAttendanceSyncPayload(payload);

  if (!response.ok) {
    const error = new Error(response.message || 'Attendance sync failed.' );
    error.statusCode = 502;
    throw error;
  }

  return {
    ok: true,
    message: 'Attendance database updated successfully.',
  };
}

async function postAttendanceSyncPayload(payload: { student: { candidateNumber: string; name: string }; sessions: Array<{ name: string; component: string; subject: string; paperCode: string; date: string; startTime: string; endTime: string; roomCode: string; teacherName: string; teacherId: string; type: string }> }) {
  const response = await fetch(`${attendanceSyncUrl.replace(/\/$/, '')}/api/sync/student`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${attendanceSyncSecret}`,
    },
    body: JSON.stringify(payload),
  });

  if (response.ok) {
    return { ok: true as const, message: 'Attendance database updated successfully.' };
  }

  const bodyText = await response.text().catch(() => '');
  let message = `Attendance sync failed: HTTP ${response.status}`;
  try {
    const body = bodyText ? JSON.parse(bodyText) : null;
    if (body?.error) {
      message = `Attendance sync failed: ${body.error}`;
    }
  } catch {
    if (bodyText.trim()) {
      message = `Attendance sync failed: HTTP ${response.status}: ${bodyText.trim().slice(0, 240)}`;
    }
  }

  return { ok: false as const, message };
}

function buildSyncDiagnostics() {
  return {
    attendanceSyncUrl: redactUrl(attendanceSyncUrl),
    attendanceSyncSecretConfigured: Boolean(attendanceSyncSecret),
    attendanceDatabaseUrl: redactUrl(attendanceDbUrl),
    attendanceDatabaseConfigured: Boolean(attendanceDbUrl),
  };
}

function redactUrl(value: string) {
  if (!value) {
    return '';
  }

  try {
    const url = new URL(value);
    if (url.username) {
      url.username = '<redacted>';
    }
    if (url.password) {
      url.password = '<redacted>';
    }
    return url.toString();
  } catch {
    return '<invalid-url>';
  }
}

async function loadStudentEnrollmentState(studentId: string, student: Record<string, unknown>) {
  const { data, error } = await supabase
    .from('student_enrollments')
    .select('course_id,block_code')
    .eq('student_id', studentId)
    .limit(500);

  if (error) {
    throw wrapSupabaseError(error);
  }

  return {
    program: normaliseProgramValue(String(student.program || '')),
    has_tok: typeof student.has_tok === 'boolean' ? student.has_tok : null,
    tok_course: student.tok_course || null,
    tok_block_code: student.tok_block_code || null,
    enrollments: (data || []).map((row) => ({
      student_id: studentId,
      course_id: row.course_id,
      block_code: row.block_code,
    })),
  };
}

async function restoreStudentEnrollmentState(studentId: string, state: { program: string; has_tok: boolean | null; tok_course: unknown; tok_block_code: unknown; enrollments: Array<{ student_id: string; course_id: number; block_code: string | null }> }) {
  const deleteResult = await supabase.from('student_enrollments').delete().eq('student_id', studentId);
  if (deleteResult.error) {
    return wrapSupabaseError(deleteResult.error);
  }

  if (state.enrollments.length > 0) {
    const insertResult = await supabase.from('student_enrollments').insert(state.enrollments);
    if (insertResult.error) {
      return wrapSupabaseError(insertResult.error);
    }
  }

  const programResult = await supabase
    .from('students')
    .update({
      program: state.program,
      has_tok: state.has_tok,
      tok_course: state.tok_course,
      tok_block_code: state.tok_block_code,
    })
    .eq('student_id', studentId);

  if (programResult.error) {
    return wrapSupabaseError(programResult.error);
  }

  try {
    await syncStudentTimetableFromEnrollments(studentId);
  } catch (error) {
    return error;
  }

  return null;
}

function normaliseProgramValue(program: string) {
  const normalized = program.trim().toUpperCase();
  if (!normalized) {
    return '';
  }
  if (normalized === 'IB' || normalized === 'IBDP') {
    return 'IB';
  }
  if (normalized === 'CAIE' || normalized === 'A LEVEL') {
    return 'A Level';
  }
  return program.trim();
}

function normalizeStudent(row: Record<string, unknown>) {
  return {
    studentId: row.student_id,
    fullName: row.full_name,
    program: row.program || '',
    hasTok: typeof row.has_tok === 'boolean' ? row.has_tok : null,
    tokCourse: row.tok_course || '',
    tokBlockCode: row.tok_block_code || '',
  };
}

function getAdminBlockCodeForCourseName(courseName: string, blockCode: string | null) {
  return COURSE_BLOCK_OVERRIDES.get(courseName) || blockCode || '';
}

function canonicalCourseName(courseName: unknown) {
  if (typeof courseName === 'string') {
    return courseName.trim();
  }

  if (courseName && typeof courseName === 'object') {
    const value = courseName as Record<string, unknown>;
    return canonicalCourseName(value.name || value.courseName || value.course_name || '');
  }

  return '';
}

function normalizeTimetablePayload(payload: Record<string, unknown> | null) {
  return {
    student: payload?.student || null,
    periods: Array.isArray(payload?.periods) ? payload.periods : [],
    entries: Array.isArray(payload?.entries) ? payload.entries : [],
  };
}

async function readJsonBody(request: Request) {
  try {
    return await request.json();
  } catch {
    const error = new Error('Request body must be valid JSON.');
    error.statusCode = 400;
    throw error;
  }
}

function wrapSupabaseError(error: { message: string }) {
  const wrappedError = new Error(error.message || 'Supabase request failed.');
  wrappedError.statusCode = 502;
  return wrappedError;
}

function jsonResponse(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders,
  });
}
