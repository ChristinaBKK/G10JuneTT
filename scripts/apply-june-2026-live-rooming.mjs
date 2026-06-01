import fs from 'node:fs';
import path from 'node:path';

loadLocalEnvFile();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const slotGroups = {
  blockA: [6101, 6102, 6122, 6156, 6157, 6163, 6164, 6171, 6172, 6296, 6297],
  blockBCie: [6105, 6106, 6107, 6118, 6119, 6123, 6124, 6158, 6159, 6175, 6176, 6177, 6188, 6189, 6298, 6299],
  blockB1Ib: [6105, 6118, 6119, 6123, 6158, 6159, 6175, 6188, 6189, 6298, 6299],
  blockB2Ib: [6106, 6107, 6176, 6177],
  blockC: [6108, 6109, 6116, 6117, 6153, 6154, 6161, 6162, 6178, 6179, 6186, 6187, 6293, 6294],
  blockD: [6103, 6104, 6113, 6114, 6125, 6155, 6168, 6169, 6173, 6174, 6183, 6184, 6295],
  blockE: [6111, 6112, 6121, 6151, 6152, 6165, 6181, 6182, 6185, 6291, 6292],
  tok: [6153, 6154, 6293, 6294],
  cas: [6124, 6125],
};

const rooming = [
  { coursePatterns: ['Math HL'], slotOrders: slotGroups.blockA, teacher: 'Rajesh Choyikkunimmal', room: 'B3040' },
  { coursePatterns: ['Math SL'], slotOrders: slotGroups.blockA, teacher: 'Shahid Anwar', room: 'B3039' },
  { coursePatterns: ['Regular Math A-1'], slotOrders: slotGroups.blockA, teacher: 'Joy Farhat', room: 'B3042' },
  { coursePatterns: ['Regular Math A-2'], slotOrders: slotGroups.blockA, teacher: 'Sheryl Shane Canite', room: 'B3009' },
  { coursePatterns: ['Physics A-1'], slotOrders: slotGroups.blockA, teacher: 'Evelyn Yang', room: null },
  { coursePatterns: ['Chemistry A'], slotOrders: slotGroups.blockA, teacher: 'Selina Sun', room: 'B4002' },
  { coursePatterns: ['Economics A'], slotOrders: slotGroups.blockA, teacher: 'Reza Hamroun', room: 'B2040' },
  { coursePatterns: ['Chinese A'], slotOrders: slotGroups.blockA, teacher: 'Jenny Li', room: 'B4009' },
  { coursePatterns: ['Physics A-2 (Summit)'], slotOrders: slotGroups.blockA, teacher: 'Mike Hu', room: null },
  { coursePatterns: ['Physics A-3*'], slotOrders: slotGroups.blockA, teacher: 'Logan Tian', room: null },
  { coursePatterns: ['Geography'], slotOrders: slotGroups.blockA, teacher: 'Keith Seeley / Alex Oniango', room: 'B2039' },

  { coursePatterns: ['Physics B-1'], slotOrders: slotGroups.blockBCie, teacher: 'Chester Lim', room: null },
  { coursePatterns: ['Physics B-2'], slotOrders: slotGroups.blockBCie, teacher: 'Evelyn Yang', room: null },
  {
    coursePatterns: ['Biology'],
    teacher: 'Ambily Biju',
    roomsBySlotOrder: {
      6105: 'B4007', 6106: 'B4007', 6107: 'B4007',
      6118: 'B4004', 6119: 'B4004', 6123: 'B4004',
      6158: 'B4007', 6159: 'B4007',
      6175: 'B4004', 6176: 'B4004', 6177: 'B4004',
      6188: 'B4004', 6189: 'B4004', 6298: 'B4004', 6299: 'B4004',
    },
  },
  { coursePatterns: ['Economics B-1'], slotOrders: slotGroups.blockBCie, teacher: 'Helgaard Le Roux', room: 'B1037' },
  { coursePatterns: ['Computer Science'], slotOrders: slotGroups.blockBCie, teacher: 'Bill Jiang', room: 'B1029' },
  { coursePatterns: ['Music'], slotOrders: slotGroups.blockBCie, teacher: 'Andy Clark', room: 'B2004' },
  { coursePatterns: ['Chinese B'], slotOrders: slotGroups.blockBCie, teacher: 'Ivy Zhu', room: 'B3009' },
  { coursePatterns: ['Economics B-2 (Summit)'], slotOrders: slotGroups.blockBCie, teacher: 'Fahran Nzamy', room: 'B4011' },
  { coursePatterns: ['Art & Design (Dual Dose)'], slotOrders: slotGroups.blockBCie, teacher: 'Mark Ford', room: 'B3028' },

  { coursePatterns: ['Economics HL', 'Economics SL'], slotOrders: slotGroups.blockB1Ib, teacher: 'Chaminda Marasinghe', room: 'B3010' },
  { coursePatterns: ['Biology HL', 'Biology SL'], slotOrders: slotGroups.blockB1Ib, teacher: 'Fisher Yu', room: 'B3012' },
  { coursePatterns: ['Theatre HL', 'Theatre SL'], slotOrders: slotGroups.blockB1Ib, teacher: 'Chalice Rakgoale', room: 'B2003' },
  { coursePatterns: ['Physics HL', 'Physics SL'], slotOrders: slotGroups.blockB1Ib, teacher: 'Logan Tian', room: 'B4012' },

  { coursePatterns: ['Chinese A HL', 'Chinese A SL'], slotOrders: slotGroups.blockB2Ib, teacher: 'Melody Chen', room: 'B4010' },
  { coursePatterns: ['Chinese B HL', 'Chinese B SL', 'Chinese AB SL'], slotOrders: slotGroups.blockB2Ib, teacher: 'Jenny Li/Ann Yang', room: 'B4009' },

  { coursePatterns: ['Physics HL', 'Physics SL'], slotOrders: slotGroups.blockC, teacher: 'Logan Tian', room: 'B3005' },
  { coursePatterns: ['Chemistry HL', 'Chemistry SL'], slotOrders: slotGroups.blockC, teacher: 'Judy Zhu', room: 'B3004' },
  { coursePatterns: ['Biology HL', 'Biology SL'], slotOrders: slotGroups.blockC, teacher: 'Lily Hung', room: 'B3007' },
  { coursePatterns: ['Regular Math C-1'], slotOrders: slotGroups.blockC, teacher: 'Narmina Magsudova', room: 'B3040' },
  { coursePatterns: ['Regular Math C-2'], slotOrders: slotGroups.blockC, teacher: 'Shaun Yang', room: 'B3009' },
  { coursePatterns: ['Further Math'], slotOrders: slotGroups.blockC, teacher: 'Rajesh', room: 'B3011' },
  { coursePatterns: ['Advanced Math C (CIE)'], slotOrders: slotGroups.blockC, teacher: 'Mandy Chen', room: 'B3042' },
  { coursePatterns: ['Chemistry C-1'], slotOrders: slotGroups.blockC, teacher: 'Khurram Shezad', room: 'B4004' },
  { coursePatterns: ['Economics C-1'], slotOrders: slotGroups.blockC, teacher: 'Marshall Irby', room: 'B2043' },
  { coursePatterns: ['Business'], slotOrders: slotGroups.blockC, teacher: 'Joyce Zhou', room: 'B1034' },
  { coursePatterns: ['Chemistry C-2*'], slotOrders: slotGroups.blockC, teacher: 'Alistair Furze', room: 'B4005' },
  { coursePatterns: ['Economics C-2*'], slotOrders: slotGroups.blockC, teacher: 'Winnie Hu', room: 'B2041' },
  { coursePatterns: ['TOK (Group 1)', 'TOK (Group 2)'], slotOrders: slotGroups.tok, teacher: 'Miya Yang / Matthew Peatman', room: 'B3044' },
  { coursePatterns: ['CAS-1', 'CAS-2'], slotOrders: slotGroups.cas, teacher: null, room: 'B2044' },

  {
    coursePatterns: ['Regular Math D'],
    teacher: 'Joy Farhat',
    roomsBySlotOrder: {
      6103: 'B3042', 6104: 'B3042', 6113: 'B3039', 6114: 'B3039',
      6125: 'B3042', 6155: 'B3042', 6168: 'B3042', 6169: 'B3042',
      6173: 'B3042', 6174: 'B3042', 6183: 'B3039', 6184: 'B3039', 6295: 'B3042',
    },
  },
  { coursePatterns: ['Fast Maths D (Edexcel)'], slotOrders: slotGroups.blockD, teacher: 'Rajesh', room: 'B1034' },
  { coursePatterns: ['Advanced Math D (CIE)'], slotOrders: slotGroups.blockD, teacher: 'Eva Wang', room: 'B3043' },
  { coursePatterns: ['Physics D'], slotOrders: slotGroups.blockD, teacher: 'Raufie Shafie', room: null },
  { coursePatterns: ['Chemistry D'], slotOrders: slotGroups.blockD, teacher: 'Selina Sun', room: 'B3005' },
  { coursePatterns: ['History'], slotOrders: slotGroups.blockD, teacher: 'Keith Seeley / Matthew Peatman', room: 'B3044' },
  {
    coursePatterns: ['Art & Design'],
    teacher: 'Amanda Milne / Luciana Liu',
    roomsBySlotOrder: {
      6103: 'B3029', 6104: 'B3029', 6113: 'B3029', 6114: 'B3029',
      6125: 'B4029', 6155: 'B4029', 6168: 'B4029', 6169: 'B4029',
      6173: 'B4029', 6174: 'B4029', 6183: 'B3029', 6184: 'B3029', 6295: 'B4029',
    },
  },
  {
    coursePatterns: ['Chinese D-1'],
    teacher: 'Miya Yang',
    roomsBySlotOrder: {
      6103: 'B3010', 6104: 'B3010',
      6113: 'B3009', 6114: 'B3009', 6125: 'B3009', 6155: 'B3009',
      6168: 'B3009', 6169: 'B3009', 6173: 'B3009', 6174: 'B3009',
      6183: 'B3009', 6184: 'B3009', 6295: 'B3009',
    },
  },
  {
    coursePatterns: ['Chinese D-2'],
    teacher: 'Ivy Zhu',
    roomsBySlotOrder: {
      6103: 'B4011', 6104: 'B4011', 6113: 'B4011', 6114: 'B4011', 6125: 'B4011',
      6155: 'B3010', 6168: 'B3010', 6169: 'B3010', 6173: 'B3010', 6174: 'B3010',
      6183: 'B3010', 6184: 'B3010', 6295: 'B3010',
    },
  },
  { coursePatterns: ['English A HL', 'English A SL'], slotOrders: slotGroups.blockD, teacher: 'Warwick Midlane', room: 'B2039' },
  { coursePatterns: ['English B HL'], slotOrders: slotGroups.blockD, teacher: 'Donald Meyer', room: 'B2040' },
  { coursePatterns: ['English B SL'], slotOrders: slotGroups.blockD, teacher: 'Darren McQuay', room: 'B2043' },

  { coursePatterns: ['Economics HL', 'Economics SL'], slotOrders: slotGroups.blockE, teacher: 'Chaminda Marasinghe', room: 'B3011' },
  { coursePatterns: ['Business HL', 'Business SL'], slotOrders: slotGroups.blockE, teacher: 'Jennifer Jacobs-Kraft', room: 'B3043' },
  { coursePatterns: ['Philosophy HL', 'Philosophy SL'], slotOrders: slotGroups.blockE, teacher: 'Matthew Peatman', room: 'B2036' },
  { coursePatterns: ['English E-1*'], slotOrders: slotGroups.blockE, teacher: 'Kurt Shelton', room: 'B4038' },
  { coursePatterns: ['English E-2*'], slotOrders: slotGroups.blockE, teacher: 'Jenna Wade Dunn', room: 'B1029' },
  { coursePatterns: ['English E-3*'], slotOrders: slotGroups.blockE, teacher: 'Lim Wan', room: 'B4009' },
  { coursePatterns: ['English E-4*'], slotOrders: slotGroups.blockE, teacher: 'Helen Liu', room: 'B4039' },
  { coursePatterns: ['English E-5*'], slotOrders: slotGroups.blockE, teacher: 'Sally Guo', room: 'B4040' },
  {
    coursePatterns: ['English E-6*'],
    teacher: 'Sherry Yuan',
    roomsBySlotOrder: {
      6111: 'B3010', 6112: 'B3010', 6121: 'B3010',
      6151: 'B3012', 6152: 'B3012', 6165: 'B3012',
      6181: 'B3012', 6182: 'B3012', 6291: 'B3012', 6292: 'B3012',
    },
  },

  { coursePatterns: ['PE-1'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Abie Rakgoale', room: 'Gym' },
  { coursePatterns: ['PE-2'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Nicole Mangondo', room: 'Gym' },
  { coursePatterns: ['PE-3'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Miko Qian', room: 'Gym' },
  { coursePatterns: ['PE-4'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Matthew Johnson', room: 'Gym' },
  { coursePatterns: ['PE-5'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Milan Vucinic', room: 'Gym' },
  { coursePatterns: ['PE-6'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Lourdes Caramol', room: 'Gym' },
  { coursePatterns: ['PE-7'], slotOrders: [6127, 6128, 6166, 6167], teacher: 'Milan Saric', room: 'Gym' },
  {
    coursePatterns: ['English E-7*'],
    teacher: 'Cordelia Jiao',
    roomsBySlotOrder: {
      6111: 'B4011', 6112: 'B4011', 6121: 'B4011',
      6151: 'B4011', 6152: 'B4011', 6165: 'B4011',
      6181: 'B4041', 6182: 'B4041', 6291: 'B4041', 6292: 'B4041',
    },
  },
];

function loadLocalEnvFile() {
  const envPath = path.resolve('.env.local');
  if (!fs.existsSync(envPath)) {
    return;
  }

  const envContents = fs.readFileSync(envPath, 'utf8');
  for (const rawLine of envContents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }

    const separatorIndex = line.indexOf('=');
    if (separatorIndex === -1) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

function assertEnvironment() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.');
  }
}

async function request(endpoint, options = {}) {
  const response = await fetch(`${SUPABASE_URL}${endpoint}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });

  if (!response.ok) {
    throw new Error(`${options.method || 'GET'} ${endpoint} failed: ${response.status} ${await response.text()}`);
  }

  const contentType = response.headers.get('content-type') || '';
  return contentType.includes('application/json') ? response.json() : response.text();
}

function resolveCourses(patterns, courses) {
  const resolved = new Map();

  for (const pattern of patterns) {
    if (pattern.endsWith('*')) {
      const prefix = pattern.slice(0, -1).toLowerCase();
      for (const course of courses) {
        if (course.name.toLowerCase().startsWith(prefix)) {
          resolved.set(course.id, course);
        }
      }
      continue;
    }

    const course = courses.find((candidate) => candidate.name === pattern);
    if (course) {
      resolved.set(course.id, course);
    }
  }

  return [...resolved.values()];
}

function chunkRows(rows, size) {
  const chunks = [];
  for (let index = 0; index < rows.length; index += size) {
    chunks.push(rows.slice(index, index + size));
  }
  return chunks;
}

async function main() {
  assertEnvironment();

  const [courses, slots, existingSlotCourses] = await Promise.all([
    request('/rest/v1/courses?select=id,name&limit=1000'),
    request('/rest/v1/timetable_slots?select=id,slot_order&term_name=gte.2026-06-10&term_name=lte.2026-06-29&limit=500'),
    request('/rest/v1/timetable_slot_courses?select=slot_id,display_order&limit=5000'),
  ]);

  const slotIdByOrder = new Map(slots.map((slot) => [slot.slot_order, slot.id]));
  const nextDisplayOrderBySlotId = new Map();
  for (const row of existingSlotCourses) {
    nextDisplayOrderBySlotId.set(row.slot_id, Math.max(nextDisplayOrderBySlotId.get(row.slot_id) || 0, row.display_order || 0));
  }

  const upsertRows = [];
  const touchedCourseNames = new Set();

  for (const item of rooming) {
    const matchedCourses = resolveCourses(item.coursePatterns, courses);
    if (matchedCourses.length === 0) {
      throw new Error(`Could not resolve any courses for patterns: ${item.coursePatterns.join(', ')}`);
    }

    const slotOrders = item.slotOrders || Object.keys(item.roomsBySlotOrder || {}).map((value) => Number(value));
    for (const course of matchedCourses) {
      touchedCourseNames.add(course.name);
      for (const slotOrder of slotOrders) {
        const slotId = slotIdByOrder.get(slotOrder);
        if (!slotId) {
          throw new Error(`Unknown slot_order ${slotOrder} for course ${course.name}`);
        }

        const currentMax = nextDisplayOrderBySlotId.get(slotId) || 0;
        nextDisplayOrderBySlotId.set(slotId, currentMax + 1);

        upsertRows.push({
          slot_id: slotId,
          course_id: course.id,
          display_order: 1000 + currentMax + 1,
          override_teacher: item.teacher,
          override_room: item.roomsBySlotOrder ? (item.roomsBySlotOrder[slotOrder] ?? null) : item.room,
        });
      }
    }
  }

  for (const chunk of chunkRows(upsertRows, 500)) {
    await request('/rest/v1/timetable_slot_courses?on_conflict=slot_id,course_id', {
      method: 'POST',
      headers: {
        Prefer: 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(chunk),
    });
  }

  console.log(`Upserted ${upsertRows.length} rooming rows for ${touchedCourseNames.size} courses.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});