import fs from 'node:fs';
import path from 'node:path';

const defaultInputPath = path.resolve('examples/students.june-2026.raw.tsv');
const defaultOutputPath = path.resolve('examples/students.june-2026.bulk.json');

function usage() {
  console.log(`Usage:
  node scripts/parse-june-2026-roster.mjs [input-tsv] [output-json]

Defaults:
  input: ${defaultInputPath}
  output: ${defaultOutputPath}
`);
}

function normaliseProgram(program) {
  const value = String(program || '').trim().toUpperCase();
  if (value === 'IBDP') {
    return 'IB';
  }
  if (value === 'CAIE') {
    return 'CAIE';
  }
  return value || 'CAIE';
}

function baseBlockCode(rawBlock) {
  const match = String(rawBlock || '').trim().match(/^([A-F])/i);
  return match ? match[1].toUpperCase() : null;
}

function isTokBlock(rawBlock, cohort) {
  return /^C\/3(?:-[12])?$/i.test(String(rawBlock || '').trim()) && /TOK/i.test(String(cohort || ''));
}

function parseStudentName(studentCell, sid) {
  const raw = String(studentCell || '').trim();
  if (!raw) {
    return String(sid || '').trim();
  }

  const prefix = `${sid}-`;
  if (sid && raw.startsWith(prefix)) {
    return raw.slice(prefix.length).trim();
  }

  return raw.replace(/^\d+-/, '').trim();
}

function parseTsv(tsv) {
  const lines = tsv
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean);

  if (lines.length === 0) {
    throw new Error('The roster TSV file is empty.');
  }

  const [headerLine, ...dataLines] = lines;
  const headers = headerLine.split('\t').map((value) => value.trim());
  const expectedHeaders = ['Block', 'Program', 'Cohort', 'TID', 'No', 'Student', 'SID'];
  if (expectedHeaders.some((header, index) => headers[index] !== header)) {
    throw new Error('The roster TSV header does not match the expected format.');
  }

  const students = new Map();

  dataLines.forEach((line) => {
    const columns = line.split('\t');
    if (columns.length < 7) {
      throw new Error(`Invalid roster row: ${line}`);
    }

    const [block, program, cohort, , , studentCell, sid] = columns;
    const studentId = String(sid || '').trim();
    if (!studentId) {
      throw new Error(`Missing SID in row: ${line}`);
    }

    const student = students.get(studentId) || {
      student_id: studentId,
      full_name: parseStudentName(studentCell, studentId),
      program: normaliseProgram(program),
      block_assignments: {},
      has_tok: false,
    };

    const cohortName = String(cohort || '').trim();
    const blockCode = baseBlockCode(block);
    if (!blockCode) {
      throw new Error(`Could not determine block from row: ${line}`);
    }

    if (isTokBlock(block, cohortName)) {
      student.has_tok = true;
      student.tok_course = cohortName;
    } else if (!student.block_assignments[blockCode]) {
      student.block_assignments[blockCode] = cohortName;
    }

    students.set(studentId, student);
  });

  return [...students.values()].sort((left, right) => left.student_id.localeCompare(right.student_id, 'en'));
}

function main() {
  const [inputArg, outputArg] = process.argv.slice(2);
  if (['-h', '--help'].includes(inputArg)) {
    usage();
    process.exit(0);
  }

  const inputPath = path.resolve(inputArg || defaultInputPath);
  const outputPath = path.resolve(outputArg || defaultOutputPath);
  const roster = parseTsv(fs.readFileSync(inputPath, 'utf8'));

  fs.writeFileSync(outputPath, `${JSON.stringify(roster, null, 2)}\n`, 'utf8');
  console.log(`Wrote ${outputPath} with ${roster.length} students.`);
}

try {
  main();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}