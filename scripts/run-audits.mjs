import { spawn } from 'node:child_process';

const audits = [
  {
    label: 'student timetable audit',
    command: 'node',
    args: ['scripts/audit-live-timetable.mjs'],
  },
  {
    label: 'admin option audit',
    command: 'node',
    args: ['scripts/audit-admin-course-options.mjs'],
  },
];

for (const audit of audits) {
  console.log(`\n=== ${audit.label} ===`);
  await runCommand(audit.command, audit.args);
}

function runCommand(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: 'inherit',
      env: process.env,
    });

    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${command} ${args.join(' ')} exited with code ${code}`));
    });
  });
}