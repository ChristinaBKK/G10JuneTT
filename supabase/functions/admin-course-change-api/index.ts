// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const FUNCTION_NAME = 'admin-course-change-api';
const BLOCK_CODES = ['A', 'B', 'C', 'D', 'E', 'F'];
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'content-type,x-admin-password',
  'Content-Type': 'application/json; charset=utf-8',
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const configuredPassword = Deno.env.get('ADMIN_COURSE_CHANGE_PASSWORD') || '';

if (!supabaseUrl || !serviceRoleKey || !configuredPassword) {
  throw new Error('SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and ADMIN_COURSE_CHANGE_PASSWORD must be set for admin-course-change-api.');
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

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
  const [studentResult, enrollmentResult, optionBuckets, timetableResult] = await Promise.all([
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
    loadOptionBuckets(),
    supabase.rpc('get_student_timetable_payload', { p_student_id: studentId }),
  ]);

  if (studentResult.error) {
    throw wrapSupabaseError(studentResult.error);
  }
  if (enrollmentResult.error) {
    throw wrapSupabaseError(enrollmentResult.error);
  }
  if (timetableResult.error) {
    throw wrapSupabaseError(timetableResult.error);
  }

  if (!studentResult.data) {
    const error = new Error(`Student ${studentId} was not found.`);
    error.statusCode = 404;
    throw error;
  }

  const currentByBlock = new Map<string, string>();
  const currentUnblocked: string[] = [];
  for (const row of enrollmentResult.data || []) {
    const courseName = row.course?.name;
    if (!courseName) {
      continue;
    }

    if (row.block_code) {
      currentByBlock.set(row.block_code, courseName);
      if (!optionBuckets.blocks[row.block_code].includes(courseName)) {
        optionBuckets.blocks[row.block_code].push(courseName);
      }
      continue;
    }

    currentUnblocked.push(courseName);
    if (!optionBuckets.unblocked.includes(courseName)) {
      optionBuckets.unblocked.push(courseName);
    }
  }

  optionBuckets.unblocked.sort((left, right) => left.localeCompare(right));
  for (const blockCode of BLOCK_CODES) {
    optionBuckets.blocks[blockCode].sort((left, right) => left.localeCompare(right));
  }

  return {
    student: normalizeStudent(studentResult.data),
    blocks: BLOCK_CODES.map((blockCode) => ({
      blockCode,
      label: `Block ${blockCode}`,
      currentCourseName: currentByBlock.get(blockCode) || '',
      options: optionBuckets.blocks[blockCode],
    })),
    unblocked: {
      label: 'No block / additional courses',
      currentCourseNames: [...new Set(currentUnblocked)].sort((left, right) => left.localeCompare(right)),
      options: optionBuckets.unblocked,
    },
    timetable: normalizeTimetablePayload(timetableResult.data),
  };
}

async function loadOptionBuckets() {
  const { data, error } = await supabase
    .from('student_enrollments')
    .select('block_code,course:courses(name)')
    .limit(5000);

  if (error) {
    throw wrapSupabaseError(error);
  }

  const blocks = Object.fromEntries(BLOCK_CODES.map((blockCode) => [blockCode, [] as string[]]));
  const blockSets = Object.fromEntries(BLOCK_CODES.map((blockCode) => [blockCode, new Set<string>()]));
  const unblockedSet = new Set<string>();

  for (const row of data || []) {
    const courseName = row.course?.name;
    if (!courseName) {
      continue;
    }

    if (row.block_code && blockSets[row.block_code]) {
      blockSets[row.block_code].add(courseName);
      continue;
    }

    unblockedSet.add(courseName);
  }

  for (const blockCode of BLOCK_CODES) {
    blocks[blockCode] = [...blockSets[blockCode]].sort((left, right) => left.localeCompare(right));
  }

  return {
    blocks,
    unblocked: [...unblockedSet].sort((left, right) => left.localeCompare(right)),
  };
}

async function replaceStudentEnrollments(studentId: string, payload: Record<string, unknown>) {
  const blockSelections = payload?.blockSelections && typeof payload.blockSelections === 'object'
    ? payload.blockSelections as Record<string, string>
    : {};
  const unblockedCourseNames = Array.isArray(payload?.unblockedCourseNames)
    ? payload.unblockedCourseNames as string[]
    : [];

  const [courseMap, optionBuckets, studentResult] = await Promise.all([
    loadCourseMap(),
    loadOptionBuckets(),
    supabase.from('students').select('student_id').eq('student_id', studentId).limit(1).maybeSingle(),
  ]);

  if (studentResult.error) {
    throw wrapSupabaseError(studentResult.error);
  }
  if (!studentResult.data) {
    const error = new Error(`Student ${studentId} was not found.`);
    error.statusCode = 404;
    throw error;
  }

  const normalizedBlockSelections: Record<string, string> = {};
  for (const blockCode of BLOCK_CODES) {
    const rawValue = typeof blockSelections[blockCode] === 'string' ? blockSelections[blockCode].trim() : '';
    if (!rawValue) {
      continue;
    }

    if (!courseMap.has(rawValue)) {
      const error = new Error(`Unknown course selected for Block ${blockCode}: ${rawValue}`);
      error.statusCode = 400;
      throw error;
    }

    if (!optionBuckets.blocks[blockCode].includes(rawValue)) {
      const error = new Error(`Course ${rawValue} is not a valid option for Block ${blockCode}.`);
      error.statusCode = 400;
      throw error;
    }

    normalizedBlockSelections[blockCode] = rawValue;
  }

  const normalizedUnblocked = [...new Set(
    unblockedCourseNames
      .filter((courseName) => typeof courseName === 'string')
      .map((courseName) => courseName.trim())
      .filter(Boolean),
  )].sort((left, right) => left.localeCompare(right));

  for (const courseName of normalizedUnblocked) {
    if (!courseMap.has(courseName)) {
      const error = new Error(`Unknown non-block course selected: ${courseName}`);
      error.statusCode = 400;
      throw error;
    }

    if (!optionBuckets.unblocked.includes(courseName)) {
      const error = new Error(`Course ${courseName} is not a valid non-block option.`);
      error.statusCode = 400;
      throw error;
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

  const deleteUnblocked = await supabase
    .from('student_enrollments')
    .delete()
    .eq('student_id', studentId)
    .is('block_code', null);

  if (deleteUnblocked.error) {
    throw wrapSupabaseError(deleteUnblocked.error);
  }

  const rowsToInsert = [];
  for (const blockCode of BLOCK_CODES) {
    const courseName = normalizedBlockSelections[blockCode];
    if (!courseName) {
      continue;
    }

    rowsToInsert.push({
      student_id: studentId,
      course_id: courseMap.get(courseName),
      block_code: blockCode,
    });
  }

  for (const courseName of normalizedUnblocked) {
    rowsToInsert.push({
      student_id: studentId,
      course_id: courseMap.get(courseName),
      block_code: null,
    });
  }

  if (rowsToInsert.length > 0) {
    const insertResult = await supabase.from('student_enrollments').insert(rowsToInsert);
    if (insertResult.error) {
      throw wrapSupabaseError(insertResult.error);
    }
  }

  const syncResult = await supabase.rpc('sync_student_slot_assignments_for_student', {
    target_student_id: studentId,
  });
  if (syncResult.error) {
    throw wrapSupabaseError(syncResult.error);
  }

  return loadStudentEditorData(studentId);
}

async function loadCourseMap() {
  const { data, error } = await supabase
    .from('courses')
    .select('id,name')
    .order('name', { ascending: true })
    .limit(5000);

  if (error) {
    throw wrapSupabaseError(error);
  }

  return new Map((data || []).map((row) => [row.name, row.id]));
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