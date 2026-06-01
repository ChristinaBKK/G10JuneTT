import { supabaseUrl } from './supabase-config.js';

const DEFAULT_ADMIN_API_BASE = `${supabaseUrl}/functions/v1/admin-course-change-api`;
const BLOCK_CODES = ['A', 'B', 'C', 'D', 'E', 'F'];
const ADMIN_PASSWORD_STORAGE_KEY = 'admin-course-change-password';

const adminApiBase = resolveAdminApiBase();
const state = {
  adminPassword: sessionStorage.getItem(ADMIN_PASSWORD_STORAGE_KEY) || '',
  currentStudentId: '',
  currentEditorData: null,
};

const elements = {
  apiBaseLabel: document.querySelector('#apiBaseLabel'),
  adminPassword: document.querySelector('#adminPassword'),
  authForm: document.querySelector('#authForm'),
  authOverlay: document.querySelector('#authOverlay'),
  authStatus: document.querySelector('#authStatus'),
  blockSelections: document.querySelector('#blockSelections'),
  connectionState: document.querySelector('#connectionState'),
  courseChangeForm: document.querySelector('#courseChangeForm'),
  editorEmptyState: document.querySelector('#editorEmptyState'),
  editorPanel: document.querySelector('#editorPanel'),
  lockPageButton: document.querySelector('#lockPageButton'),
  reloadStudentButton: document.querySelector('#reloadStudentButton'),
  refreshSearchButton: document.querySelector('#refreshSearchButton'),
  saveChangesButton: document.querySelector('#saveChangesButton'),
  statusBanner: document.querySelector('#statusBanner'),
  studentMeta: document.querySelector('#studentMeta'),
  studentQuery: document.querySelector('#studentQuery'),
  studentSearchForm: document.querySelector('#studentSearchForm'),
  studentSearchResults: document.querySelector('#studentSearchResults'),
  studentTitle: document.querySelector('#studentTitle'),
  timetablePreview: document.querySelector('#timetablePreview'),
  unblockedSelections: document.querySelector('#unblockedSelections'),
};

elements.apiBaseLabel.textContent = adminApiBase;

elements.authForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  await unlockPage();
});

elements.studentSearchForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  await searchStudents(elements.studentQuery?.value || '');
});

elements.refreshSearchButton?.addEventListener('click', async () => {
  await searchStudents(elements.studentQuery?.value || '');
});

elements.reloadStudentButton?.addEventListener('click', async () => {
  if (!state.currentStudentId) {
    return;
  }
  await loadStudent(state.currentStudentId);
});

elements.lockPageButton?.addEventListener('click', () => {
  clearAdminPassword();
  setStatus('Page locked. Enter the password again to continue.', 'idle');
});

elements.courseChangeForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!state.currentStudentId) {
    return;
  }

  const payload = collectSelections();
  setStatus('Saving course changes and rebuilding timetable…', 'working');
  setSaveDisabled(true);

  try {
    const editorData = await requestJson(`${adminApiBase}/student/${encodeURIComponent(state.currentStudentId)}/editor-data`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    state.currentEditorData = editorData;
    renderEditor(editorData);
    setStatus('Saved. The timetable preview has been rebuilt from the latest enrollment data.', 'success');
  } catch (error) {
    setStatus(error.message, 'error');
  } finally {
    setSaveDisabled(false);
  }
});

init().catch((error) => {
  elements.connectionState.textContent = error.message;
  elements.connectionState.className = 'connection-state is-offline';
});

async function init() {
  await checkAdminApi();

  if (state.adminPassword) {
    const unlocked = await validatePassword(state.adminPassword, { preserveInput: true });
    if (unlocked) {
      await searchStudents('');
      return;
    }
  }

  lockPage();
}

async function checkAdminApi() {
  try {
    const payload = await requestJson(`${adminApiBase}/health`, { skipAuth: true });
    elements.connectionState.textContent = payload.authenticated
      ? 'Hosted admin API online and unlocked'
      : 'Hosted admin API online and waiting for password';
    elements.connectionState.className = 'connection-state is-online';
  } catch {
    elements.connectionState.textContent = 'Hosted admin API is offline or not deployed yet.';
    elements.connectionState.className = 'connection-state is-offline';
  }
}

async function searchStudents(query) {
  if (!state.adminPassword) {
    lockPage();
    return;
  }

  elements.studentSearchResults.innerHTML = '<p class="search-feedback">Loading students…</p>';

  try {
    const payload = await requestJson(`${adminApiBase}/students?query=${encodeURIComponent(query.trim())}`);
    renderSearchResults(payload.students || []);
  } catch (error) {
    elements.studentSearchResults.innerHTML = `<p class="search-feedback is-error">${escapeHtml(error.message)}</p>`;
  }
}

function renderSearchResults(students) {
  if (!students.length) {
    elements.studentSearchResults.innerHTML = '<p class="search-feedback">No students matched that search.</p>';
    return;
  }

  const markup = students.map((student) => {
    const meta = [student.studentId];
    if (student.program) {
      meta.push(student.program);
    }
    return `
      <button class="student-result${student.studentId === state.currentStudentId ? ' is-active' : ''}" type="button" data-student-id="${escapeHtml(student.studentId)}">
        <span class="student-result-name">${escapeHtml(student.fullName || 'Unnamed student')}</span>
        <span class="student-result-meta">${escapeHtml(meta.join(' · '))}</span>
      </button>
    `;
  }).join('');

  elements.studentSearchResults.innerHTML = markup;
  elements.studentSearchResults.querySelectorAll('[data-student-id]').forEach((button) => {
    button.addEventListener('click', async () => {
      await loadStudent(button.dataset.studentId || '');
      renderSearchResults(students);
    });
  });
}

async function loadStudent(studentId) {
  if (!state.adminPassword) {
    lockPage();
    return;
  }

  state.currentStudentId = studentId;
  setStatus('Loading student record…', 'working');
  setSaveDisabled(true);

  try {
    const editorData = await requestJson(`${adminApiBase}/student/${encodeURIComponent(studentId)}/editor-data`);
    state.currentEditorData = editorData;
    renderEditor(editorData);
    setStatus('Choose new courses and save when ready.', 'idle');
  } catch (error) {
    setStatus(error.message, 'error');
  } finally {
    setSaveDisabled(false);
  }
}

function renderEditor(editorData) {
  elements.editorEmptyState.hidden = true;
  elements.editorPanel.hidden = false;

  const student = editorData.student || {};
  elements.studentTitle.textContent = `${student.fullName || 'Unnamed student'} (${student.studentId || ''})`;

  const metaParts = [];
  if (student.program) {
    metaParts.push(`Program: ${student.program}`);
  }
  if (student.tokCourse) {
    metaParts.push(`TOK: ${student.tokCourse}${student.tokBlockCode ? ` (${student.tokBlockCode})` : ''}`);
  } else if (student.hasTok === false) {
    metaParts.push('TOK disabled');
  }
  elements.studentMeta.textContent = metaParts.join(' · ');

  elements.blockSelections.innerHTML = (editorData.blocks || []).map((block) => `
    <article class="selection-card">
      <div class="selection-card-head">
        <h4>${escapeHtml(block.label)}</h4>
        <p>${block.currentCourseName ? `Current: ${escapeHtml(block.currentCourseName)}` : 'Currently empty'}</p>
      </div>
      <label class="field-label" for="block-${escapeHtml(block.blockCode)}">Choose course</label>
      <select class="block-select" id="block-${escapeHtml(block.blockCode)}" name="block-${escapeHtml(block.blockCode)}" data-block-code="${escapeHtml(block.blockCode)}">
        <option value="">Clear this block</option>
        ${block.options.map((courseName) => `
          <option value="${escapeHtml(courseName)}"${courseName === block.currentCourseName ? ' selected' : ''}>${escapeHtml(courseName)}</option>
        `).join('')}
      </select>
    </article>
  `).join('');

  const selectedUnblocked = new Set(editorData.unblocked?.currentCourseNames || []);
  const unblockedOptions = editorData.unblocked?.options || [];
  elements.unblockedSelections.innerHTML = unblockedOptions.length
    ? unblockedOptions.map((courseName) => `
      <label class="checkbox-card">
        <input type="checkbox" value="${escapeHtml(courseName)}"${selectedUnblocked.has(courseName) ? ' checked' : ''}>
        <span>${escapeHtml(courseName)}</span>
      </label>
    `).join('')
    : '<p class="search-feedback">No non-block course options were found in student_enrollments.</p>';

  renderTimetable(editorData.timetable || {});
}

function renderTimetable(timetable) {
  const periodsById = new Map((timetable.periods || []).map((period) => [period.id, period.label]));
  const entries = [...(timetable.entries || [])].sort((left, right) => {
    if (left.day_name !== right.day_name) {
      return String(left.day_name).localeCompare(String(right.day_name));
    }
    return Number(left.slot_order || 0) - Number(right.slot_order || 0);
  });

  if (!entries.length) {
    elements.timetablePreview.innerHTML = '<p class="search-feedback">No timetable entries were returned for this student.</p>';
    return;
  }

  const dayMarkup = [];
  const entriesByDay = new Map();
  for (const entry of entries) {
    const dayName = entry.day_name || 'Unknown day';
    if (!entriesByDay.has(dayName)) {
      entriesByDay.set(dayName, []);
    }
    entriesByDay.get(dayName).push(entry);
  }

  for (const [dayName, dayEntries] of entriesByDay) {
    const cards = dayEntries.map((entry) => {
      const startLabel = periodsById.get(entry.start_period_id) || entry.start_period_id || '';
      const endLabel = periodsById.get(entry.end_period_id) || entry.end_period_id || '';
      const periodLabel = startLabel === endLabel || !endLabel ? startLabel : `${startLabel} to ${endLabel}`;
      return `
        <article class="timetable-card">
          <p class="timetable-card-period">${escapeHtml(periodLabel)}</p>
          <h4>${escapeHtml(entry.course_name || 'No course')}</h4>
          <p>${escapeHtml(entry.teacher || 'Teacher TBC')}</p>
          <p>${escapeHtml(entry.room || 'Room TBC')}</p>
        </article>
      `;
    }).join('');

    dayMarkup.push(`
      <section class="timetable-day">
        <h4>${escapeHtml(dayName)}</h4>
        <div class="timetable-day-grid">${cards}</div>
      </section>
    `);
  }

  elements.timetablePreview.innerHTML = dayMarkup.join('');
}

function collectSelections() {
  const blockSelections = Object.fromEntries(BLOCK_CODES.map((blockCode) => [blockCode, '']));
  elements.blockSelections.querySelectorAll('[data-block-code]').forEach((select) => {
    blockSelections[select.dataset.blockCode] = select.value;
  });

  const unblockedCourseNames = [...elements.unblockedSelections.querySelectorAll('input[type="checkbox"]:checked')]
    .map((checkbox) => checkbox.value)
    .sort((left, right) => left.localeCompare(right));

  return {
    blockSelections,
    unblockedCourseNames,
  };
}

async function requestJson(url, options) {
  const headers = new Headers(options?.headers || {});
  if (!options?.skipAuth && state.adminPassword) {
    headers.set('x-admin-password', state.adminPassword);
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });
  const contentType = response.headers.get('content-type') || '';
  const payload = contentType.includes('application/json') ? await response.json() : await response.text();

  if (!response.ok) {
    const message = typeof payload === 'string' ? payload : payload?.error || 'Request failed.';
    if (response.status === 401) {
      clearAdminPassword();
      lockPage(message);
    }
    throw new Error(message);
  }

  return payload;
}

async function unlockPage() {
  const password = elements.adminPassword?.value || '';
  if (!password) {
    setAuthStatus('Enter the admin password.', 'error');
    return;
  }

  const unlocked = await validatePassword(password, { preserveInput: false });
  if (unlocked) {
    await searchStudents(elements.studentQuery?.value || '');
  }
}

async function validatePassword(password, { preserveInput }) {
  state.adminPassword = password;
  setAuthStatus('Checking password…', 'working');

  try {
    await requestJson(`${adminApiBase}/students?query=`);
    sessionStorage.setItem(ADMIN_PASSWORD_STORAGE_KEY, password);
    unlockShell();
    setAuthStatus('Unlocked.', 'success');
    if (!preserveInput && elements.adminPassword) {
      elements.adminPassword.value = '';
    }
    await checkAdminApi();
    return true;
  } catch (error) {
    if (elements.adminPassword && !preserveInput) {
      elements.adminPassword.focus();
      elements.adminPassword.select();
    }
    setAuthStatus(error.message, 'error');
    return false;
  }
}

function clearAdminPassword() {
  state.adminPassword = '';
  sessionStorage.removeItem(ADMIN_PASSWORD_STORAGE_KEY);
  if (elements.authOverlay) {
    elements.authOverlay.hidden = false;
  }
  if (elements.lockPageButton) {
    elements.lockPageButton.hidden = true;
  }
  if (elements.adminPassword) {
    elements.adminPassword.value = '';
  }
}

function lockPage(message = 'Enter the admin password to continue.') {
  if (elements.authOverlay) {
    elements.authOverlay.hidden = false;
  }
  if (elements.lockPageButton) {
    elements.lockPageButton.hidden = true;
  }
  if (elements.adminPassword) {
    elements.adminPassword.focus();
  }
  setAuthStatus(message, 'idle');
}

function unlockShell() {
  if (elements.authOverlay) {
    elements.authOverlay.hidden = true;
  }
  if (elements.lockPageButton) {
    elements.lockPageButton.hidden = false;
  }
}

function setAuthStatus(message, stateName) {
  if (!elements.authStatus) {
    return;
  }
  elements.authStatus.textContent = message;
  elements.authStatus.className = `auth-status is-${stateName}`;
}

function setStatus(message, stateName) {
  elements.statusBanner.textContent = message;
  elements.statusBanner.className = `status-banner is-${stateName}`;
}

function setSaveDisabled(disabled) {
  if (elements.saveChangesButton) {
    elements.saveChangesButton.disabled = disabled;
  }
}

function resolveAdminApiBase() {
  const searchParams = new URLSearchParams(window.location.search);
  return searchParams.get('adminApi') || DEFAULT_ADMIN_API_BASE;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}