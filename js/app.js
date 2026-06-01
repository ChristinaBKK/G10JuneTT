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
  const entriesBySession = groupEntriesBySession(entries);
  const sessionGroups = getSessionGroups(entriesBySession);
  const table = document.createElement('table');
  table.id = 'timetableTable';
  const mobileSchedule = document.createElement('div');
  mobileSchedule.className = 'mobile-timetable';

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

  for (const sessionGroup of sessionGroups) {
    const row = document.createElement('tr');
    const dayCell = document.createElement('td');
    dayCell.innerHTML = buildSessionLabelMarkup(sessionGroup);
    row.appendChild(dayCell);

    let skipUntilPeriodIndex = -1;
    const dayEntries = entriesBySession.get(sessionGroup.key) || [];

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
        td.textContent = 'Free Period';
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
  mobileSchedule.innerHTML = buildMobileTimetableMarkup(periods, entriesBySession, sessionGroups);
  timetableContainer.appendChild(mobileSchedule);
  timetableContainer.appendChild(table);
}

function groupEntriesBySession(entries) {
  return entries.reduce((grouped, entry) => {
    const key = buildSessionKey(entry);
    if (!grouped.has(key)) {
      grouped.set(key, []);
    }

    grouped.get(key).push(entry);
    return grouped;
  }, new Map());
}

function getSessionGroups(entriesBySession) {
  return [...entriesBySession.entries()]
    .map(([key, sessionEntries]) => ({ key, entry: sessionEntries[0] || {} }))
    .sort((left, right) => compareTimetableEntries(left.entry, right.entry));
}

function compareTimetableEntries(left, right) {
  const leftTermName = String(left.term_name || '');
  const rightTermName = String(right.term_name || '');
  if (leftTermName || rightTermName) {
    if (leftTermName !== rightTermName) {
      return leftTermName.localeCompare(rightTermName);
    }
  }

  const leftDay = dayOrder.get(String(left.day_name || '')) ?? Number.MAX_SAFE_INTEGER;
  const rightDay = dayOrder.get(String(right.day_name || '')) ?? Number.MAX_SAFE_INTEGER;
  if (leftDay !== rightDay) {
    return leftDay - rightDay;
  }

  return Number(left.slot_order || 0) - Number(right.slot_order || 0);
}

function buildSessionKey(entry) {
  const termName = String(entry.term_name || '').trim();
  const dayName = String(entry.day_name || '').trim();
  return termName ? `${termName}::${dayName}` : dayName;
}

function buildSessionLabelMarkup(sessionGroup) {
  const dayName = escapeHtml(String(sessionGroup.entry?.day_name || 'Unknown day'));
  const termName = String(sessionGroup.entry?.term_name || '').trim();
  if (!termName) {
    return dayName;
  }

  return `${dayName}<br><span>${escapeHtml(formatTermName(termName))}</span>`;
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

function buildMobileTimetableMarkup(periods, entriesBySession, sessionGroups) {
  return sessionGroups.map((sessionGroup) => {
    const dayEntries = entriesBySession.get(sessionGroup.key) || [];
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
              <span class="mobile-free-label">Free Period</span>
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
        <h3>${buildSessionLabelMarkup(sessionGroup)}</h3>
        <div class="mobile-day-slots">
          ${items.join('')}
        </div>
      </section>
    `;
  }).join('');
}

function formatTermName(termName) {
  const match = termName.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    return termName;
  }

  const [, year, month, day] = match;
  return `${year}/${month}/${day}`;
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