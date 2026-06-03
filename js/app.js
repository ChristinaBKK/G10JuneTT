import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { supabasePublishableKey, supabaseUrl } from './supabase-config.js';

const supabase = createClient(supabaseUrl, supabasePublishableKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const dayOrder = new Map(days.map((day, index) => [day, index]));
const periodOrder = new Map();
const DATE_VIEW_START = '2026-06-10';
const DATE_VIEW_END = '2026-06-29';
const TIMETABLE_VIEW_MODES = {
  weekday: 'weekday',
  date: 'date',
};

const lookupForm = document.getElementById('lookupForm');
const pupilIdInput = document.getElementById('pupilID');
const statusMessage = document.getElementById('statusMessage');
const timetableContainer = document.getElementById('timetableContainer');
const downloadButton = document.getElementById('downloadPDF');
const lookupButton = document.getElementById('lookupButton');
const recentLookupsContainer = document.getElementById('recentLookups');
const clearRecentLookupsButton = document.getElementById('clearRecentLookups');

const recentLookupStorageKey = 'g10-june-tt:recent-lookups';
const maxRecentLookups = 6;

let periodsCache = null;
let currentStudent = null;
const state = {
  currentTimetableData: null,
  viewMode: TIMETABLE_VIEW_MODES.weekday,
};

lookupForm.addEventListener('submit', handleLookupSubmit);
downloadButton.addEventListener('click', downloadPDF);
clearRecentLookupsButton.addEventListener('click', clearRecentLookups);

renderEmptyState('Enter a pupil ID to load timetable data.');
renderRecentLookups();

async function handleLookupSubmit(event) {
  event.preventDefault();

  const pupilId = pupilIdInput.value.trim();
  if (!pupilId) {
    setStatus('Enter a pupil ID before searching.', 'error');
    renderEmptyState('A pupil ID is required to load a timetable.');
    downloadButton.hidden = true;
    return;
  }

  try {
    setLoading(true);
    setStatus(`Loading timetable for ${pupilId}...`, 'loading');

    const payload = await fetchStudentTimetablePayload(pupilId);
    const periods = normalisePeriods(payload.periods || []);
    const student = payload.student;
    const entries = payload.entries || [];

    if (!student) {
      currentStudent = null;
      renderEmptyState(`No student found for pupil ID ${pupilId}.`);
      setStatus(`No student found for pupil ID ${pupilId}.`, 'error');
      downloadButton.hidden = true;
      return;
    }

    currentStudent = student;
    saveRecentLookup(student.student_id, student.full_name);
    state.currentTimetableData = { periods, student, entries };
    renderTimetable(periods, student, entries);
    downloadButton.hidden = false;
    setStatus(`Loaded timetable for ${student.full_name}.`, 'ready');
  } catch (error) {
    console.error(error);
    currentStudent = null;
    renderEmptyState('The timetable could not be loaded from Supabase. Check the browser console for details.');
    setStatus(error.message || 'The timetable could not be loaded from Supabase.', 'error');
    downloadButton.hidden = true;
  } finally {
    setLoading(false);
  }
}

async function fetchPeriods() {
  return periodsCache || [];
}

async function fetchStudentTimetablePayload(studentId) {
  const { data, error } = await supabase
    .rpc('get_student_timetable_payload', { p_student_id: studentId });

  if (error) {
    throw new Error(`Unable to load timetable data: ${error.message}`);
  }

  return data;
}

function normalisePeriods(periods) {
  periodsCache = periods.map((period, index) => {
    periodOrder.set(period.id, index);
    return {
      id: period.id,
      time: period.label,
      sortOrder: period.sort_order,
    };
  });

  return periodsCache;
}

function renderTimetable(periods, student, entries) {
  state.currentTimetableData = { periods, student, entries };
  const visibleEntries = getEntriesForCurrentView(entries, state.viewMode);
  const viewGroups = buildTimetableGroups(visibleEntries, state.viewMode);
  const table = document.createElement('table');
  table.id = 'timetableTable';
  const mobileSchedule = document.createElement('div');
  mobileSchedule.className = 'mobile-timetable';
  const toolbar = document.createElement('div');
  toolbar.className = 'timetable-toolbar';
  toolbar.innerHTML = `
    <div class="timetable-view-copy">
      <p class="timetable-view-kicker">Student view</p>
      <p class="timetable-view-note">${escapeHtml(getViewDescription(state.viewMode))}</p>
    </div>
    <div class="timetable-view-toggle" role="tablist" aria-label="Timetable view">
      <button class="view-toggle-button${state.viewMode === TIMETABLE_VIEW_MODES.weekday ? ' is-active' : ''}" type="button" data-view-mode="${TIMETABLE_VIEW_MODES.weekday}">Weekday view</button>
      <button class="view-toggle-button${state.viewMode === TIMETABLE_VIEW_MODES.date ? ' is-active' : ''}" type="button" data-view-mode="${TIMETABLE_VIEW_MODES.date}">Date view</button>
    </div>
  `;

  toolbar.querySelectorAll('[data-view-mode]').forEach((button) => {
    button.addEventListener('click', () => {
      setTimetableViewMode(button.dataset.viewMode || TIMETABLE_VIEW_MODES.weekday);
    });
  });

  const headerRow = document.createElement('tr');
  const firstHeader = document.createElement('th');
  firstHeader.textContent = 'Day / Period';
  headerRow.appendChild(firstHeader);

  for (const period of periods) {
    const th = document.createElement('th');
    th.textContent = `${period.id}\n${period.time}`;
    headerRow.appendChild(th);
  }

  table.appendChild(headerRow);

  for (const viewGroup of viewGroups) {
    const row = document.createElement('tr');
    const dayCell = document.createElement('td');
    dayCell.innerHTML = buildViewGroupLabelMarkup(viewGroup);
    row.appendChild(dayCell);

    let skipUntilPeriodIndex = -1;
    const dayEntries = viewGroup.entries || [];

    periods.forEach((period, periodIndex) => {
      if (periodIndex <= skipUntilPeriodIndex) {
        return;
      }

      const entry = dayEntries.find((candidate) => {
        const startIndex = periodOrder.get(candidate.start_period_id);
        const endIndex = periodOrder.get(candidate.end_period_id);
        return periodIndex >= startIndex && periodIndex <= endIndex;
      });

      if (!entry) {
        const td = document.createElement('td');
        td.className = 'free-period';
        td.textContent = '';
        row.appendChild(td);
        return;
      }

      if (entry.start_period_id === period.id) {
        const td = document.createElement('td');
        const startIndex = periodOrder.get(entry.start_period_id);
        const endIndex = periodOrder.get(entry.end_period_id);
        const colspan = endIndex - startIndex + 1;

        if (colspan > 1) {
          td.colSpan = colspan;
          skipUntilPeriodIndex = periodIndex + colspan - 1;
        }

        td.innerHTML = buildCellMarkup(entry);
        row.appendChild(td);
      }
    });

    table.appendChild(row);
  }

  timetableContainer.innerHTML = `
    <div class="timetable-heading">
      <div>
        <h2>June 2026 Timetable for ${escapeHtml(student.full_name)}</h2>
        <p>ID: ${escapeHtml(student.student_id)}</p>
      </div>
    </div>
  `;
  timetableContainer.appendChild(toolbar);

  if (!viewGroups.length) {
    timetableContainer.appendChild(renderNoViewEntriesState(state.viewMode));
    return;
  }

  mobileSchedule.innerHTML = buildMobileTimetableMarkup(periods, viewGroups);
  timetableContainer.appendChild(mobileSchedule);
  timetableContainer.appendChild(table);
}

function getEntriesForCurrentView(entries, viewMode) {
  if (viewMode !== TIMETABLE_VIEW_MODES.date) {
    return entries;
  }

  return entries.filter((entry) => isWithinDateViewRange(entry.term_name));
}

function buildTimetableGroups(entries, viewMode) {
  const entriesByGroupKey = new Map();

  entries.forEach((entry) => {
    const groupKey = getTimetableGroupKey(entry, viewMode);
    if (!groupKey) {
      return;
    }

    if (!entriesByGroupKey.has(groupKey)) {
      entriesByGroupKey.set(groupKey, []);
    }

    entriesByGroupKey.get(groupKey).push(entry);
  });

  return [...entriesByGroupKey.entries()]
    .map(([groupKey, groupEntries]) => buildTimetableGroup(groupKey, groupEntries, viewMode))
    .sort((left, right) => compareTimetableGroup(left, right, viewMode));
}

function getTimetableGroupKey(entry, viewMode) {
  if (viewMode === TIMETABLE_VIEW_MODES.date) {
    return String(entry.term_name || '').trim();
  }

  return String(entry.day_name || '').trim();
}

function buildTimetableGroup(groupKey, entries, viewMode) {
  const sortedEntries = [...entries].sort((left, right) => Number(left.slot_order || 0) - Number(right.slot_order || 0));
  const firstEntry = sortedEntries[0] || {};
  const dayName = String(firstEntry.day_name || '').trim();
  const termName = String(firstEntry.term_name || '').trim();
  const formattedDate = formatDateLabel(termName);

  return {
    key: groupKey,
    entries: sortedEntries,
    mainLabel: viewMode === TIMETABLE_VIEW_MODES.date ? (dayName || formattedDate) : groupKey,
    subLabel: viewMode === TIMETABLE_VIEW_MODES.date ? formattedDate : '',
    sortKey: viewMode === TIMETABLE_VIEW_MODES.date ? termName : dayName,
  };
}

function compareTimetableGroup(leftGroup, rightGroup, viewMode) {
  if (viewMode === TIMETABLE_VIEW_MODES.date) {
    const leftDate = parseIsoDate(leftGroup.sortKey);
    const rightDate = parseIsoDate(rightGroup.sortKey);
    if (leftDate && rightDate) {
      const delta = leftDate.getTime() - rightDate.getTime();
      if (delta !== 0) {
        return delta;
      }
    } else if (leftDate || rightDate) {
      return leftDate ? -1 : 1;
    }
  } else {
    const leftDay = dayOrder.get(String(leftGroup.sortKey || '')) ?? Number.MAX_SAFE_INTEGER;
    const rightDay = dayOrder.get(String(rightGroup.sortKey || '')) ?? Number.MAX_SAFE_INTEGER;
    if (leftDay !== rightDay) {
      return leftDay - rightDay;
    }
  }

  return String(leftGroup.sortKey || '').localeCompare(String(rightGroup.sortKey || ''));
}

function buildCellMarkup(entry) {
  const courseName = escapeHtml(String(entry.course_name || '').trim() || 'Unassigned');
  const teacher = escapeHtml(toCompactText(entry.teacher, 'Teacher TBC'));
  const room = escapeHtml(toCompactText(entry.room, 'Room TBC'));

  return `
    <div class="cell-content">
      <span class="cell-course" title="${courseName}">${courseName}</span>
      <span class="cell-meta" title="${teacher}">Teacher: ${teacher}</span>
      <span class="cell-meta" title="${room}">Room: ${room}</span>
    </div>
  `;
}

function buildMobileTimetableMarkup(periods, viewGroups) {
  return viewGroups.map((viewGroup) => {
    const dayEntries = viewGroup.entries || [];
    const items = [];
    let skipUntilPeriodIndex = -1;

    periods.forEach((period, periodIndex) => {
      if (periodIndex <= skipUntilPeriodIndex) {
        return;
      }

      const entry = dayEntries.find((candidate) => {
        const startIndex = periodOrder.get(candidate.start_period_id);
        const endIndex = periodOrder.get(candidate.end_period_id);
        return periodIndex >= startIndex && periodIndex <= endIndex;
      });

      if (!entry) {
        items.push(`
          <article class="mobile-slot-card is-free">
            <div class="mobile-slot-meta">
              <span class="mobile-slot-period">${escapeHtml(period.id)}</span>
              <span class="mobile-slot-time">${escapeHtml(period.time)}</span>
            </div>
            <div class="mobile-slot-body">
              <span class="mobile-free-label"></span>
            </div>
          </article>
        `);
        return;
      }

      if (entry.start_period_id !== period.id) {
        return;
      }

      const startIndex = periodOrder.get(entry.start_period_id);
      const endIndex = periodOrder.get(entry.end_period_id);
      const endPeriod = periods[endIndex];
      const periodLabel = startIndex === endIndex
        ? period.id
        : `${period.id}-${endPeriod.id}`;
      const timeLabel = startIndex === endIndex
        ? period.time
        : `${period.time} to ${endPeriod.time}`;

      items.push(`
        <article class="mobile-slot-card">
          <div class="mobile-slot-meta">
            <span class="mobile-slot-period">${escapeHtml(periodLabel)}</span>
            <span class="mobile-slot-time">${escapeHtml(timeLabel)}</span>
          </div>
          <div class="mobile-slot-body">
            <span class="mobile-slot-course">${escapeHtml(String(entry.course_name || '').trim() || 'Unassigned')}</span>
            <span class="mobile-slot-detail">Teacher: ${escapeHtml(toCompactText(entry.teacher, 'Teacher TBC'))}</span>
            <span class="mobile-slot-detail">Room: ${escapeHtml(toCompactText(entry.room, 'Room TBC'))}</span>
          </div>
        </article>
      `);

      skipUntilPeriodIndex = endIndex;
    });

    return `
      <section class="mobile-day-card">
        <h3>${buildViewGroupLabelMarkup(viewGroup)}</h3>
        <div class="mobile-day-slots">
          ${items.join('')}
        </div>
      </section>
    `;
  }).join('');
}

function buildViewGroupLabelMarkup(viewGroup) {
  const mainLabel = escapeHtml(viewGroup.mainLabel || 'Unknown day');
  const subLabel = String(viewGroup.subLabel || '').trim();

  if (!subLabel) {
    return `<span class="timetable-group-main">${mainLabel}</span>`;
  }

  return `<span class="timetable-group-main">${mainLabel}</span><span class="timetable-group-subtitle">${escapeHtml(subLabel)}</span>`;
}

function getViewDescription(viewMode) {
  return viewMode === TIMETABLE_VIEW_MODES.date
    ? 'Date view from June 10 to June 29 with weekdays labelled underneath.'
    : 'Weekday view grouped from Monday to Friday.';
}

function renderNoViewEntriesState(viewMode) {
  const message = viewMode === TIMETABLE_VIEW_MODES.date
    ? 'No timetable entries were found between June 10 and June 29.'
    : 'No timetable entries were returned for the weekday view.';
  const empty = document.createElement('div');
  empty.className = 'empty-state';
  empty.innerHTML = `<p>${escapeHtml(message)}</p>`;
  return empty;
}

function setTimetableViewMode(viewMode) {
  if (!Object.values(TIMETABLE_VIEW_MODES).includes(viewMode)) {
    return;
  }

  if (state.viewMode === viewMode) {
    return;
  }

  state.viewMode = viewMode;
  renderCurrentTimetable();
}

function renderCurrentTimetable() {
  if (!state.currentTimetableData) {
    return;
  }

  const { periods, student, entries } = state.currentTimetableData;
  renderTimetable(periods, student, entries);
}

function isWithinDateViewRange(termName) {
  const date = parseIsoDate(termName);
  const start = parseIsoDate(DATE_VIEW_START);
  const end = parseIsoDate(DATE_VIEW_END);

  if (!date || !start || !end) {
    return false;
  }

  return date >= start && date <= end;
}

function parseIsoDate(value) {
  const match = String(value || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    return null;
  }

  const [, year, month, day] = match;
  return new Date(Number(year), Number(month) - 1, Number(day));
}

function formatDateLabel(termName) {
  const date = parseIsoDate(termName);
  if (!date) {
    return termName;
  }

  return date.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
  });
}

function toCompactText(value, fallback) {
  const normalised = String(value || '')
    .replace(/<br\s*\/?>/gi, ' / ')
    .replace(/\s*\n\s*/g, ' / ')
    .replace(/\s{2,}/g, ' ')
    .trim();

  return normalised || fallback;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function renderEmptyState(message) {
  timetableContainer.innerHTML = `<div class="empty-state"><p>${escapeHtml(message)}</p></div>`;
}

function renderRecentLookups() {
  const recentLookups = getRecentLookups();
  recentLookupsContainer.innerHTML = '';
  clearRecentLookupsButton.hidden = recentLookups.length === 0;

  if (recentLookups.length === 0) {
    recentLookupsContainer.innerHTML = '<p class="recent-lookups__empty">No recent IDs yet.</p>';
    return;
  }

  recentLookups.forEach((lookup) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'recent-lookups__chip';
    button.innerHTML = `${escapeHtml(lookup.studentId)} <span>${escapeHtml(lookup.name)}</span>`;
    button.addEventListener('click', () => {
      pupilIdInput.value = lookup.studentId;
      lookupForm.requestSubmit();
    });
    recentLookupsContainer.appendChild(button);
  });
}

function getRecentLookups() {
  try {
    const raw = window.localStorage.getItem(recentLookupStorageKey);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function saveRecentLookup(studentId, name) {
  const recentLookups = getRecentLookups().filter((lookup) => lookup.studentId !== studentId);
  recentLookups.unshift({ studentId, name });
  window.localStorage.setItem(
    recentLookupStorageKey,
    JSON.stringify(recentLookups.slice(0, maxRecentLookups)),
  );
  renderRecentLookups();
}

function clearRecentLookups() {
  window.localStorage.removeItem(recentLookupStorageKey);
  renderRecentLookups();
}

function setStatus(message, state) {
  if (!statusMessage) {
    return;
  }

  statusMessage.textContent = message;
  statusMessage.dataset.state = state;
}

function setLoading(isLoading) {
  lookupButton.disabled = isLoading;
  lookupButton.textContent = isLoading ? 'Loading...' : 'Get Timetable';
}

function downloadPDF() {
  if (!currentStudent || !timetableContainer.querySelector('#timetableTable')) {
    return;
  }

  const clone = timetableContainer.cloneNode(true);
  clone.style.position = 'absolute';
  clone.style.left = '-9999px';
  clone.style.width = '1200px';
  clone.style.maxWidth = '1200px';
  clone.style.padding = '10px';
  document.body.appendChild(clone);

  clone.querySelectorAll('th, td').forEach((cell) => {
    cell.style.position = 'static';
    cell.style.left = 'auto';
    cell.style.zIndex = 'auto';
  });

  html2canvas(clone, { scale: 2 }).then((canvas) => {
    document.body.removeChild(clone);

    const imgData = canvas.toDataURL('image/png');
    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF({
      orientation: 'landscape',
      unit: 'pt',
      format: 'a4',
    });

    const margin = 40;
    const pdfWidth = pdf.internal.pageSize.getWidth();
    const pdfHeight = pdf.internal.pageSize.getHeight();
    const contentWidth = pdfWidth - (2 * margin);
    const contentHeight = pdfHeight - (2 * margin);
    const ratio = Math.min(contentWidth / canvas.width, contentHeight / canvas.height);
    const scaledWidth = canvas.width * ratio;
    const scaledHeight = canvas.height * ratio;
    const x = margin + ((contentWidth - scaledWidth) / 2);

    pdf.addImage(imgData, 'PNG', x, margin, scaledWidth, scaledHeight);
    pdf.save(`June_2026_Timetable_${currentStudent.student_id}.pdf`);
  });
}