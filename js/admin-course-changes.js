import { supabaseUrl } from './supabase-config.js';

const DEFAULT_ADMIN_API_BASE = `${supabaseUrl}/functions/v1/admin-course-change-api`;
const BLOCK_CODES = ['A', 'B', 'C', 'D', 'E', 'F', 'UC'];
const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const DAY_ORDER = new Map(DAY_NAMES.map((dayName, index) => [dayName, index]));
const ADMIN_PASSWORD_STORAGE_KEY = 'admin-course-change-password';
const SAVE_BUTTON_IDLE_LABEL = 'Save changes and rebuild timetable';
const SAVE_BUTTON_WORKING_LABEL = 'Updating timetable and attendance';

const adminApiBase = resolveAdminApiBase();
const state = {
  adminPassword: sessionStorage.getItem(ADMIN_PASSWORD_STORAGE_KEY) || '',
  currentStudentId: '',
  currentEditorData: null,
  lastSaveMeta: null,
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
  restoreChangesButton: document.querySelector('#restoreChangesButton'),
  saveChangesButton: document.querySelector('#saveChangesButton'),
  saveResultBody: document.querySelector('#saveResultBody'),
  saveResultCloseButton: document.querySelector('#saveResultCloseButton'),
  saveResultDetails: document.querySelector('#saveResultDetails'),
  saveResultKicker: document.querySelector('#saveResultKicker'),
  saveResultModal: document.querySelector('#saveResultModal'),
  saveResultTitle: document.querySelector('#saveResultTitle'),
  statusBanner: document.querySelector('#statusBanner'),
  studentProgram: document.querySelector('#studentProgram'),
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

elements.reloadStudentButton?.addEventListener('click', async () => {
  if (!state.currentStudentId) {
    return;
  }
  await loadStudent(state.currentStudentId);
});

elements.restoreChangesButton?.addEventListener('click', () => {
  if (!state.currentEditorData) {
    return;
  }

  renderEditor(state.currentEditorData);
  setStatus('Restored the current saved selections for this student.', 'idle');
});

elements.lockPageButton?.addEventListener('click', () => {
  clearAdminPassword();
  setStatus('Page locked. Enter the password again to continue.', 'idle');
});

elements.saveResultCloseButton?.addEventListener('click', closeSaveResultModal);
elements.saveResultModal?.querySelectorAll('[data-save-result-close]').forEach((element) => {
  element.addEventListener('click', closeSaveResultModal);
});

elements.courseChangeForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!state.currentStudentId) {
    return;
  }

  const payload = collectSelections();
  setStatus('Saving course changes and rebuilding timetable…', 'working');
  setSaveButtonLoading(true);

  try {
    const payloadResponse = await requestJson(`${adminApiBase}/student/${encodeURIComponent(state.currentStudentId)}/editor-data`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const editorData = payloadResponse.editorData || payloadResponse;
    const attendanceSync = payloadResponse.attendanceSync || { ok: true, message: 'Attendance database updated successfully.' };
    state.currentEditorData = editorData;
    state.lastSaveMeta = { attendanceSync };
    renderEditor(editorData);
    setStatus('Saved. The timetable preview has been rebuilt from the latest enrollment data.', 'success');
    openSaveResultModal({
      tone: attendanceSync.ok ? 'success' : 'warning',
      kicker: attendanceSync.ok ? 'Saved And Synced' : 'Saved With Warning',
      title: attendanceSync.ok ? 'Changes saved successfully' : 'Timetable saved, attendance needs attention',
      body: attendanceSync.ok
        ? 'The timetable preview has been rebuilt, and the attendance database confirms the update.'
        : 'The timetable save completed, but the attendance database still needs attention.',
      details: [
        {
          label: 'Timetable database',
          value: 'Updated and rebuilt from the latest enrollment data.',
        },
        {
          label: 'Attendance database',
          value: attendanceSync.message || (attendanceSync.ok ? 'Updated successfully.' : 'Not updated.'),
        },
      ],
    });
  } catch (error) {
    setStatus(error.message, 'error');
    openSaveResultModal(buildFailureModalContent(error.message));
  } finally {
    setSaveButtonLoading(false);
  }
});

init().catch((error) => {
  elements.connectionState.textContent = error.message;
  elements.connectionState.className = 'connection-state is-offline';
});

setSearchPrompt();

async function init() {
  await checkAdminApi();

  if (state.adminPassword) {
    await validatePassword(state.adminPassword, { preserveInput: true });
    return;
  }

  lockPage();
}

async function checkAdminApi() {
  try {
    const payload = await requestJson(`${adminApiBase}/health`, { skipAuth: !state.adminPassword });
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

  const normalizedQuery = query.trim();
  if (!normalizedQuery) {
    setSearchPrompt();
    setStatus('Enter a student ID or name before searching.', 'idle');
    return;
  }

  elements.studentSearchResults.innerHTML = '<p class="search-feedback">Loading students…</p>';

  try {
    const payload = await requestJson(`${adminApiBase}/students?query=${encodeURIComponent(normalizedQuery)}`);
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
      meta.push(formatProgramLabel(student.program));
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

function setSearchPrompt() {
  elements.studentSearchResults.innerHTML = '<p class="search-feedback">Enter a student ID or name to search.</p>';
}

function formatProgramLabel(program) {
  if (!program) {
    return '';
  }
  return program === 'CAIE' ? 'A Level' : program;
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
    metaParts.push(`Program: ${formatProgramLabel(student.program)}`);
  }
  if (student.tokCourse) {
    metaParts.push(`TOK: ${student.tokCourse}${student.tokBlockCode ? ` (${student.tokBlockCode})` : ''}`);
  } else if (student.hasTok === false) {
    metaParts.push('TOK disabled');
  }
  elements.studentMeta.textContent = metaParts.join(' · ');
  if (elements.studentProgram) {
    elements.studentProgram.value = student.program === 'IB' ? 'IB' : 'A Level';
  }

  elements.blockSelections.innerHTML = (editorData.blocks || []).map((block) => `
    <article class="selection-card">
      <div class="selection-card-head">
        <h4>${escapeHtml(block.label)}</h4>
        <p>${renderCurrentCourseSummary(block)}</p>
        <p>${block.currentTeacher ? `Teacher: ${escapeHtml(formatTeacherDisplay(block.currentTeacher))}` : 'Teacher: Not set'}</p>
      </div>
      <label class="field-label" for="block-${escapeHtml(block.blockCode)}">Choose course</label>
      <select class="block-select" id="block-${escapeHtml(block.blockCode)}" name="block-${escapeHtml(block.blockCode)}" data-block-code="${escapeHtml(block.blockCode)}">
        <option value="">Clear this block</option>
        ${block.options.map((option) => {
          const normalizedOption = normalizeCourseOption(option);
          const teacherLabel = formatTeacherDisplay(normalizedOption.teacher);
          return `
          <option value="${escapeHtml(normalizedOption.courseName)}" data-teacher="${escapeHtml(teacherLabel)}"${normalizedOption.courseName === block.currentCourseName ? ' selected' : ''}>${escapeHtml(formatCourseOptionLabel(normalizedOption.courseName, normalizedOption.enrollmentCount))}${teacherLabel ? ` - ${escapeHtml(teacherLabel)}` : ''}</option>
          `;
        }).join('')}
      </select>
      <p class="selection-card-choice-teacher" data-block-choice-teacher="${escapeHtml(block.blockCode)}">${renderSelectedTeacherText(block)}</p>
    </article>
  `).join('');

  elements.blockSelections.querySelectorAll('[data-block-code]').forEach((select) => {
    select.addEventListener('change', () => {
      updateSelectedTeacher(select);
      updateDraftPreview();
    });
  });

  const selectedUnblocked = new Set(editorData.unblocked?.currentCourseNames || []);
  const unblockedOptions = editorData.unblocked?.options || [];
  elements.unblockedSelections.innerHTML = unblockedOptions.length
    ? unblockedOptions.map((option) => {
      const normalizedOption = normalizeCourseOption(option);
      return `
      <label class="checkbox-card">
        <input type="checkbox" value="${escapeHtml(normalizedOption.courseName)}"${selectedUnblocked.has(normalizedOption.courseName) ? ' checked' : ''}>
        <span>${escapeHtml(formatCourseOptionLabel(normalizedOption.courseName, normalizedOption.enrollmentCount))}</span>
      </label>
      `;
    }).join('')
    : '<p class="search-feedback">No non-block course options were found in student_enrollments.</p>';

  elements.unblockedSelections.querySelectorAll('input[type="checkbox"]').forEach((checkbox) => {
    checkbox.addEventListener('change', () => updateDraftPreview());
  });

  renderTimetable(editorData.timetable || {});
}

function updateDraftPreview() {
  if (!state.currentEditorData) {
    return;
  }

  renderTimetable(buildDraftTimetable(state.currentEditorData, collectSelections()));
}

function buildDraftTimetable(editorData, selections) {
  const baseTimetable = editorData.timetable || { periods: [], entries: [] };
  const coursePreviewByName = editorData.coursePreviewByName || {};
  const editableCourseNames = new Set(editorData.editableCourseNames || []);
  const blockPreviewSlotSignatureByCode = editorData.blockPreviewSlotSignatureByCode || {};

  const preservedEntries = (baseTimetable.entries || []).filter((entry) => !editableCourseNames.has(entry.course_name));
  const nextEntries = [];

  for (const blockCode of BLOCK_CODES) {
    const courseName = selections.blockSelections?.[blockCode] || '';
    if (!courseName) {
      continue;
    }
    nextEntries.push(...resolvePreviewEntries(coursePreviewByName, courseName, blockPreviewSlotSignatureByCode[blockCode] || ''));
  }

  for (const courseName of selections.unblockedCourseNames || []) {
    nextEntries.push(...resolvePreviewEntries(coursePreviewByName, courseName, ''));
  }

  return {
    periods: baseTimetable.periods || [],
    entries: [...preservedEntries, ...nextEntries],
  };
}

function clonePreviewEntries(entries) {
  return entries.map((entry) => ({ ...entry }));
}

function resolvePreviewEntries(coursePreviewByName, courseName, preferredSlotSignature) {
  const previewVariants = coursePreviewByName[courseName];
  if (!previewVariants) {
    return [];
  }

  if (Array.isArray(previewVariants)) {
    return clonePreviewEntries(previewVariants);
  }

  if (preferredSlotSignature && Array.isArray(previewVariants[preferredSlotSignature])) {
    return clonePreviewEntries(previewVariants[preferredSlotSignature]);
  }

  const rankedVariants = Object.entries(previewVariants)
    .filter(([, entries]) => Array.isArray(entries) && entries.length)
    .sort(([leftSignature, leftEntries], [rightSignature, rightEntries]) => {
      const overlapDelta = countSlotSignatureOverlap(rightSignature, preferredSlotSignature)
        - countSlotSignatureOverlap(leftSignature, preferredSlotSignature);
      if (overlapDelta !== 0) {
        return overlapDelta;
      }

      const entryDelta = rightEntries.length - leftEntries.length;
      if (entryDelta !== 0) {
        return entryDelta;
      }

      return leftSignature.localeCompare(rightSignature);
    });

  return clonePreviewEntries(rankedVariants[0]?.[1] || []);
}

function countSlotSignatureOverlap(leftSignature, rightSignature) {
  if (!leftSignature || !rightSignature) {
    return 0;
  }

  const rightSlots = new Set(String(rightSignature).split(',').filter(Boolean));
  return String(leftSignature)
    .split(',')
    .filter((slotOrder) => rightSlots.has(slotOrder))
    .length;
}

function renderSelectedTeacherText(block) {
  const selectedOption = (block.options || []).find((option) => option.courseName === block.currentCourseName);
  if (!selectedOption?.teacher) {
    return 'Selected teacher: Not set';
  }
  return `Selected teacher: ${formatTeacherDisplay(selectedOption.teacher)}`;
}

function renderCurrentCourseSummary(block) {
  if (!block.currentCourseName) {
    return 'Currently empty';
  }

  const countLabel = formatEnrollmentCountLabel(block.currentEnrollmentCount);
  return `Current: ${escapeHtml(block.currentCourseName)}${countLabel ? ` (${countLabel})` : ''}`;
}

function formatCourseOptionLabel(courseName, enrollmentCount) {
  const countLabel = formatEnrollmentCountLabel(enrollmentCount);
  return countLabel ? `${courseName} (${countLabel})` : courseName;
}

function normalizeCourseOption(option) {
  if (typeof option === 'string') {
    return {
      courseName: option,
      teacher: '',
      enrollmentCount: 0,
    };
  }

  return {
    courseName: option?.courseName || '',
    teacher: option?.teacher || '',
    enrollmentCount: option?.enrollmentCount || 0,
  };
}

function formatEnrollmentCountLabel(enrollmentCount) {
  const count = Number(enrollmentCount || 0);
  if (!count) {
    return '0 students';
  }
  return count === 1 ? '1 student' : `${count} students`;
}

function updateSelectedTeacher(selectElement) {
  const blockCode = selectElement.dataset.blockCode;
  const teacherElement = elements.blockSelections.querySelector(`[data-block-choice-teacher="${blockCode}"]`);
  if (!teacherElement) {
    return;
  }

  const selectedOption = selectElement.options[selectElement.selectedIndex];
  const teacher = formatTeacherDisplay(selectedOption?.dataset?.teacher || '');
  teacherElement.textContent = teacher ? `Selected teacher: ${teacher}` : 'Selected teacher: Not set';
}

function renderTimetable(timetable) {
  const periodsById = new Map((timetable.periods || []).map((period) => [period.id, period.label]));
  const entries = [...(timetable.entries || [])].sort((left, right) => {
    if (left.day_name !== right.day_name) {
      const leftDayOrder = DAY_ORDER.get(String(left.day_name)) ?? Number.MAX_SAFE_INTEGER;
      const rightDayOrder = DAY_ORDER.get(String(right.day_name)) ?? Number.MAX_SAFE_INTEGER;
      if (leftDayOrder !== rightDayOrder) {
        return leftDayOrder - rightDayOrder;
      }
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
    const groupKey = String(entry?.day_name || 'Unknown day').trim();
    if (!entriesByDay.has(groupKey)) {
      entriesByDay.set(groupKey, []);
    }
    entriesByDay.get(groupKey).push(entry);
  }

  for (const [groupKey, dayEntries] of entriesByDay) {
    const normalizedEntries = collapseDayEntries(dayEntries);
    const cards = normalizedEntries.map((entry) => {
      const startLabel = periodsById.get(entry.start_period_id) || entry.start_period_id || '';
      const endLabel = periodsById.get(entry.end_period_id) || entry.end_period_id || '';
      const periodLabel = startLabel === endLabel || !endLabel ? startLabel : `${startLabel} to ${endLabel}`;
      return `
        <article class="timetable-card">
          <p class="timetable-card-period">${escapeHtml(periodLabel)}</p>
          <h4>${escapeHtml(entry.course_name || 'No course')}</h4>
          <p>${escapeHtml(formatTeacherDisplay(entry.teacher) || 'Teacher TBC')}</p>
          <p>${escapeHtml(entry.room || 'Room TBC')}</p>
        </article>
      `;
    }).join('');

    dayMarkup.push(`
      <section class="timetable-day">
        <h4>${escapeHtml(groupKey)}</h4>
        <div class="timetable-day-grid">${cards}</div>
      </section>
    `);
  }

  elements.timetablePreview.innerHTML = dayMarkup.join('');
}

function collapseDayEntries(dayEntries) {
  const entriesByPeriod = new Map();

  for (const entry of dayEntries) {
    const startPeriodId = String(entry.start_period_id || '');
    const endPeriodId = String(entry.end_period_id || '');
    if (!startPeriodId) {
      continue;
    }

    const periodKey = `${startPeriodId}::${endPeriodId}`;
    if (!entriesByPeriod.has(periodKey)) {
      entriesByPeriod.set(periodKey, entry);
      continue;
    }

    const current = entriesByPeriod.get(periodKey);
    const currentTermName = String(current?.term_name || '9999-99-99');
    const nextTermName = String(entry?.term_name || '9999-99-99');
    if (nextTermName < currentTermName) {
      entriesByPeriod.set(periodKey, entry);
    }
  }

  return [...entriesByPeriod.values()].sort((left, right) => Number(left.slot_order || 0) - Number(right.slot_order || 0));
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
    program: elements.studentProgram?.value || '',
    unblockedCourseNames,
  };
}

function buildFailureModalContent(message) {
  const saveCancelled = message.toLowerCase().includes('save cancelled');

  if (saveCancelled) {
    return {
      tone: 'error',
      kicker: 'Save Cancelled',
      title: 'No changes were made',
      body: 'The save was cancelled and the timetable was not changed. The attendance database must be reachable before course changes can be saved.',
      details: [
        {
          label: 'Timetable database',
          value: 'Not changed. The previous course selections are still in effect.',
        },
        {
          label: 'Attendance database',
          value: message,
        },
      ],
    };
  }

  // Legacy path: old error messages that mention attendance but the save did commit.
  const attendanceFailure = message.toLowerCase().includes('attendance sync failed')
    || message.toLowerCase().includes('attendance database');

  if (attendanceFailure) {
    return {
      tone: 'warning',
      kicker: 'Attendance Sync Failed',
      title: 'Timetable saved, but attendance did not update',
      body: 'The course change appears to have been saved in the timetable system, but the attendance database did not confirm the update.',
      details: [
        {
          label: 'Timetable database',
          value: 'Likely saved already. Reload the student to confirm the latest course selections.',
        },
        {
          label: 'Attendance database',
          value: message,
        },
      ],
    };
  }

  return {
    tone: 'error',
    kicker: 'Save Failed',
    title: 'Changes were not confirmed',
    body: 'The save request did not complete cleanly, so you should treat this change as not confirmed until you reload and verify it.',
    details: [
      {
        label: 'Server response',
        value: message,
      },
    ],
  };
}

function openSaveResultModal({ tone = 'success', kicker = 'Save Result', title = 'Save complete', body = '', details = [] }) {
  if (!elements.saveResultModal) {
    return;
  }

  const card = elements.saveResultModal.querySelector('.save-result-card');
  if (card) {
    card.classList.remove('is-success', 'is-warning', 'is-error');
    card.classList.add(`is-${tone}`);
  }

  elements.saveResultKicker.textContent = kicker;
  elements.saveResultTitle.textContent = title;
  elements.saveResultBody.textContent = body;
  elements.saveResultDetails.innerHTML = details.map((detail) => `
    <div class="save-result-detail">
      <strong>${escapeHtml(detail.label || '')}</strong>
      <span>${escapeHtml(detail.value || '')}</span>
    </div>
  `).join('');
  elements.saveResultModal.hidden = false;
}

function closeSaveResultModal() {
  if (elements.saveResultModal) {
    elements.saveResultModal.hidden = true;
  }
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
    if ((elements.studentQuery?.value || '').trim()) {
      await searchStudents(elements.studentQuery?.value || '');
    }
  }
}

async function validatePassword(password, { preserveInput }) {
  state.adminPassword = password;
  setAuthStatus('Checking password…', 'working');

  try {
    const payload = await requestJson(`${adminApiBase}/health`);
    if (!payload?.authenticated) {
      const error = new Error('Unauthorized. Enter the admin page password to continue.');
      error.statusCode = 401;
      throw error;
    }
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

function setSaveButtonLoading(isLoading) {
  if (!elements.saveChangesButton) {
    return;
  }

  elements.saveChangesButton.disabled = isLoading;
  elements.saveChangesButton.classList.toggle('is-loading', isLoading);
  elements.saveChangesButton.setAttribute('aria-busy', isLoading ? 'true' : 'false');
  elements.saveChangesButton.textContent = isLoading ? SAVE_BUTTON_WORKING_LABEL : SAVE_BUTTON_IDLE_LABEL;
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

function formatTeacherDisplay(value) {
  return String(value || '')
    .replace(/<br\s*\/?>/gi, ' / ')
    .replace(/\s*\n\s*/g, ' / ')
    .replace(/\s*\/\s*/g, ' / ')
    .replace(/\s{2,}/g, ' ')
    .trim();
}