import fs from 'node:fs';
import path from 'node:path';

const timetableFilePath = path.resolve('examples/timetable.june-2026-slots.json');
const outputFilePath = path.resolve('examples/student-slot-assignments.june-2026.json');

function normaliseTrack(track) {
  return String(track || 'CIE').trim().toUpperCase();
}

function blockCodeForCourseName(courseName) {
  const match = /^Block\s+([A-F])/i.exec(courseName);
  return match ? match[1].toUpperCase() : null;
}

function chooseCourse(student, slot) {
  const offeredCourses = slot.courses;
  const track = normaliseTrack(student.track || student.program);
  const hasTok = student.has_tok !== false;
  const tokCourse = student.tok_course || 'IB - TOK';
  const slotOverrides = student.slot_overrides || {};
  const slotOverride = slotOverrides[String(slot.slot_order)];
  const blockAssignments = student.block_assignments || {};

  if (slotOverride) {
    if (!offeredCourses.includes(slotOverride)) {
      throw new Error(`Student ${student.student_id} has invalid slot override ${slotOverride} for ${slot.slot_order}`);
    }
    return slotOverride;
  }

  if (offeredCourses.length === 1) {
    const blockCode = blockCodeForCourseName(offeredCourses[0]);
    if (blockCode && blockAssignments[blockCode]) {
      return blockAssignments[blockCode];
    }
    return offeredCourses[0];
  }

  if (offeredCourses.includes('IB - TOK')) {
    if (track === 'IB' && hasTok) {
      return tokCourse;
    }

    const nonTokBlock = offeredCourses.find((course) => blockCodeForCourseName(course));
    const nonTokBlockCode = nonTokBlock ? blockCodeForCourseName(nonTokBlock) : null;
    if (nonTokBlockCode && blockAssignments[nonTokBlockCode]) {
      return blockAssignments[nonTokBlockCode];
    }

    return offeredCourses.find((course) => course !== 'IB - TOK');
  }

  if (offeredCourses.includes('Block B (CIE)')) {
    if (track === 'IB') {
      const ibBlock = offeredCourses.find((course) => course.includes('(IB)'));
      const ibBlockCode = ibBlock ? blockCodeForCourseName(ibBlock) : null;
      if (ibBlockCode && blockAssignments[ibBlockCode]) {
        return blockAssignments[ibBlockCode];
      }
      return ibBlock || offeredCourses.find((course) => !course.startsWith('CAS-'));
    }
    return blockAssignments.B || 'Block B (CIE)';
  }

  const blockCourse = offeredCourses.find((course) => blockCodeForCourseName(course));
  if (blockCourse) {
    const blockCode = blockCodeForCourseName(blockCourse);
    if (blockCode && blockAssignments[blockCode]) {
      return blockAssignments[blockCode];
    }
  }

  const nonCas = offeredCourses.find((course) => !course.startsWith('CAS-'));
  return nonCas || offeredCourses[0];
}

async function main() {
  const inputFilePath = path.resolve(process.argv[2] || 'examples/students.june-2026.sample.json');
  const resolvedOutputFilePath = path.resolve(process.argv[3] || outputFilePath);
  const timetable = JSON.parse(fs.readFileSync(timetableFilePath, 'utf8'));
  const students = JSON.parse(fs.readFileSync(inputFilePath, 'utf8'));

  if (!Array.isArray(students)) {
    throw new Error('Student roster must be a JSON array.');
  }

  const rows = [];
  students.forEach((student) => {
    if (!student.student_id || !student.full_name) {
      throw new Error('Each student must include student_id and full_name.');
    }

    if (!student.track && !student.program) {
      throw new Error(`Student ${student.student_id} must include track or program.`);
    }

    timetable.slots.forEach((slot) => {
      rows.push({
        student_id: student.student_id,
        slot_order: slot.slot_order,
        course_name: chooseCourse(student, slot),
        source: 'generated-june-2026-block-assignments',
      });
    });
  });

  fs.writeFileSync(resolvedOutputFilePath, `${JSON.stringify(rows, null, 2)}\n`, 'utf8');
  console.log(`Wrote ${resolvedOutputFilePath} with ${rows.length} rows.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});