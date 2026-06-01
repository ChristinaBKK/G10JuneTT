begin;

drop view if exists public.student_timetable_entries;
drop table if exists public.student_enrollments;
drop table if exists public.students;
drop table if exists public.timetable_slot_courses;
drop table if exists public.timetable_slots;
drop table if exists public.courses;
drop table if exists public.periods;

create table public.periods (
  id text primary key,
  label text not null,
  starts_at time not null,
  ends_at time not null,
  sort_order smallint not null unique
);

create table public.courses (
  id bigint generated always as identity primary key,
  name text not null unique,
  default_teacher text,
  default_room text
);

create table public.timetable_slots (
  id bigint generated always as identity primary key,
  term_name text not null,
  grade_level text not null,
  day_name text not null check (day_name in ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')),
  start_period_id text not null references public.periods (id),
  end_period_id text not null references public.periods (id),
  slot_order integer not null unique,
  unique (term_name, grade_level, day_name, start_period_id, end_period_id)
);

create table public.timetable_slot_courses (
  slot_id bigint not null references public.timetable_slots (id) on delete cascade,
  course_id bigint not null references public.courses (id) on delete cascade,
  display_order smallint not null,
  override_teacher text,
  override_room text,
  primary key (slot_id, course_id)
);

create table public.students (
  student_id text primary key,
  full_name text not null
);

create table public.student_enrollments (
  student_id text not null references public.students (student_id) on delete cascade,
  course_id bigint not null references public.courses (id) on delete cascade,
  primary key (student_id, course_id)
);

with source_rows as (
  select *
  from jsonb_to_recordset($json$[
  {
    "id": "P1",
    "label": "8:20 – 9:00",
    "starts_at": "08:20",
    "ends_at": "09:00",
    "sort_order": 1
  },
  {
    "id": "P2",
    "label": "9:05 – 9:45",
    "starts_at": "09:05",
    "ends_at": "09:45",
    "sort_order": 2
  },
  {
    "id": "P3",
    "label": "10:00 – 10:40",
    "starts_at": "10:00",
    "ends_at": "10:40",
    "sort_order": 3
  },
  {
    "id": "P4",
    "label": "10:45 – 11:25",
    "starts_at": "10:45",
    "ends_at": "11:25",
    "sort_order": 4
  },
  {
    "id": "P5",
    "label": "11:30 – 12:10",
    "starts_at": "11:30",
    "ends_at": "12:10",
    "sort_order": 5
  },
  {
    "id": "P6",
    "label": "1:00 – 1:40",
    "starts_at": "13:00",
    "ends_at": "13:40",
    "sort_order": 6
  },
  {
    "id": "P7",
    "label": "1:45 – 2:25",
    "starts_at": "13:45",
    "ends_at": "14:25",
    "sort_order": 7
  },
  {
    "id": "P8",
    "label": "2:35 – 3:15",
    "starts_at": "14:35",
    "ends_at": "15:15",
    "sort_order": 8
  },
  {
    "id": "P9",
    "label": "3:20 – 4:00",
    "starts_at": "15:20",
    "ends_at": "16:00",
    "sort_order": 9
  }
]$json$::jsonb) as source_rows(
    id text,
    label text,
    starts_at text,
    ends_at text,
    sort_order smallint
  )
)
insert into public.periods (id, label, starts_at, ends_at, sort_order)
select id, label, starts_at::time, ends_at::time, sort_order
from source_rows;

with source_rows as (
  select *
  from jsonb_to_recordset($json$[
  {
    "name": "Advanced Maths",
    "default_teacher": "Roy Hou",
    "default_room": "B2039"
  },
  {
    "name": "AP English",
    "default_teacher": "Kurt Shelton",
    "default_room": "B2044"
  },
  {
    "name": "Art 1",
    "default_teacher": "Amanda Milne",
    "default_room": "B3027"
  },
  {
    "name": "Art 2",
    "default_teacher": "Luciana Liu",
    "default_room": "B4029"
  },
  {
    "name": "Assembly",
    "default_teacher": "N/A",
    "default_room": "Auditorium"
  },
  {
    "name": "Biology",
    "default_teacher": "Ambily Biju",
    "default_room": "B3007"
  },
  {
    "name": "Business 1",
    "default_teacher": "Kieran Foxe",
    "default_room": "B4038"
  },
  {
    "name": "Business 2",
    "default_teacher": "Joyce Zhou",
    "default_room": "B4040"
  },
  {
    "name": "Chemistry 1",
    "default_teacher": "Fiona Fu",
    "default_room": "B4005"
  },
  {
    "name": "Chemistry 2",
    "default_teacher": "Selina Sun",
    "default_room": "B4005"
  },
  {
    "name": "Chemistry 3",
    "default_teacher": "Selina Sun",
    "default_room": "B4004"
  },
  {
    "name": "ChemistrySummit",
    "default_teacher": "Judy Zhu",
    "default_room": "B4002"
  },
  {
    "name": "Chinese 1",
    "default_teacher": "Jenny Li",
    "default_room": "B4009"
  },
  {
    "name": "Chinese 2",
    "default_teacher": "Ivy Zhu",
    "default_room": "B3009"
  },
  {
    "name": "Computer Sci",
    "default_teacher": "Bill Jiang",
    "default_room": "B1029"
  },
  {
    "name": "Economics 1",
    "default_teacher": "Christine Du",
    "default_room": "B4043"
  },
  {
    "name": "Economics 2",
    "default_teacher": "Christine Du",
    "default_room": "B4043"
  },
  {
    "name": "Economics 3",
    "default_teacher": "Zoe Wang",
    "default_room": "B4039"
  },
  {
    "name": "Economics 4",
    "default_teacher": "Zoe Wang",
    "default_room": "B4042"
  },
  {
    "name": "EconomicsSummit",
    "default_teacher": "Farhan Nzamy",
    "default_room": "B4043"
  },
  {
    "name": "English L&L 1",
    "default_teacher": "Lim Wan",
    "default_room": "B2041"
  },
  {
    "name": "English L&L 2",
    "default_teacher": "Helen Liu",
    "default_room": "B2040"
  },
  {
    "name": "English L&L 3",
    "default_teacher": "Jenna-Wade Dunn",
    "default_room": "B2043"
  },
  {
    "name": "ESL 1",
    "default_teacher": "Helen Liu",
    "default_room": "B2040"
  },
  {
    "name": "ESL 2",
    "default_teacher": "Sally Guo",
    "default_room": "B2041"
  },
  {
    "name": "ESL 3",
    "default_teacher": "Sherry Yuan",
    "default_room": "B2042"
  },
  {
    "name": "Fast Maths 1",
    "default_teacher": "Sheryl Shane Canite",
    "default_room": "B3041"
  },
  {
    "name": "Fast Maths 2",
    "default_teacher": "Alice Mei",
    "default_room": "B3043"
  },
  {
    "name": "Further Maths",
    "default_teacher": "Shahid Anwar",
    "default_room": "B3043"
  },
  {
    "name": "Geography",
    "default_teacher": "Douglas Horton",
    "default_room": "B1034"
  },
  {
    "name": "House",
    "default_teacher": "Tutor",
    "default_room": "Homeroom"
  },
  {
    "name": "IB Biology",
    "default_teacher": "Lily Hung",
    "default_room": "B4012"
  },
  {
    "name": "IB Chemistry",
    "default_teacher": "Khurram Shezad",
    "default_room": "B4004"
  },
  {
    "name": "IB Chinese",
    "default_teacher": "Miya Yang",
    "default_room": "B4011"
  },
  {
    "name": "IB Economics 1",
    "default_teacher": "Chaminda Marasinghe",
    "default_room": "B4042"
  },
  {
    "name": "IB Economics 2",
    "default_teacher": "Kieran Foxe",
    "default_room": "B4038"
  },
  {
    "name": "IB English",
    "default_teacher": "Warwick Midlane",
    "default_room": "B2039"
  },
  {
    "name": "IB Geography",
    "default_teacher": "Alex Oniango",
    "default_room": "B4039"
  },
  {
    "name": "IB Maths",
    "default_teacher": "Shahid Anwar",
    "default_room": "B3007"
  },
  {
    "name": "IB Philosophy",
    "default_teacher": "Matthew Peatman",
    "default_room": "B4039"
  },
  {
    "name": "IB Physics 1",
    "default_teacher": "Logan Tian",
    "default_room": "B4007"
  },
  {
    "name": "IB Physics 2",
    "default_teacher": "Logan Tian",
    "default_room": "B3005"
  },
  {
    "name": "IB Theatre",
    "default_teacher": "Chalice Rakgoale",
    "default_room": "B2004"
  },
  {
    "name": "IB TOK",
    "default_teacher": "Matthew P. <br> Rob H. <br> Miya Yang",
    "default_room": "B1034"
  },
  {
    "name": "IPQ 1",
    "default_teacher": "Kelly Fang",
    "default_room": "B3009"
  },
  {
    "name": "IPQ 2",
    "default_teacher": "Jenny Shen",
    "default_room": "B3010"
  },
  {
    "name": "IPQ 3",
    "default_teacher": "Carol Fu",
    "default_room": "B3011"
  },
  {
    "name": "IPQ 4",
    "default_teacher": "Rob Hollingsworth",
    "default_room": "B2039"
  },
  {
    "name": "IPQ 5",
    "default_teacher": "Kelly Fang",
    "default_room": "B4009"
  },
  {
    "name": "IPQ 6",
    "default_teacher": "Jenny Shen",
    "default_room": "B2042"
  },
  {
    "name": "IPQ 7",
    "default_teacher": "Carol Fu",
    "default_room": "B4011"
  },
  {
    "name": "Music",
    "default_teacher": "Andy Clark",
    "default_room": "B2003"
  },
  {
    "name": "PE 1",
    "default_teacher": "Llyod Pique",
    "default_room": "Gym"
  },
  {
    "name": "PE 2",
    "default_teacher": "Abie Rakgoale",
    "default_room": "Gym"
  },
  {
    "name": "PE 3",
    "default_teacher": "Miko Qian",
    "default_room": "Gym"
  },
  {
    "name": "PE 4",
    "default_teacher": "Miko Qian",
    "default_room": "Gym"
  },
  {
    "name": "PE 5",
    "default_teacher": "Ed Chapman",
    "default_room": "Gym"
  },
  {
    "name": "PE 6",
    "default_teacher": "Llyod Pique",
    "default_room": "Gym"
  },
  {
    "name": "PE 7",
    "default_teacher": "Lourdes Caramol",
    "default_room": "Gym"
  },
  {
    "name": "PE 8",
    "default_teacher": "Abie Rakgoale",
    "default_room": "Gym"
  },
  {
    "name": "Physics 1",
    "default_teacher": "Peter R.",
    "default_room": "B3005"
  },
  {
    "name": "Physics 2",
    "default_teacher": "Peter R.",
    "default_room": "B3002"
  },
  {
    "name": "Physics 3",
    "default_teacher": "Evelyn Yang",
    "default_room": "B3002"
  },
  {
    "name": "Physics 4",
    "default_teacher": "Peter R.",
    "default_room": "B3002"
  },
  {
    "name": "PhysicsSummit",
    "default_teacher": "Xiong Chen",
    "default_room": "B3007"
  },
  {
    "name": "Regular Maths 1",
    "default_teacher": "Shaun Yang",
    "default_room": "B3044"
  },
  {
    "name": "Regular Maths 2",
    "default_teacher": "Celia Sun",
    "default_room": "B3012"
  },
  {
    "name": "Regular Maths 3",
    "default_teacher": "Eva Wang",
    "default_room": "B3040"
  },
  {
    "name": "Regular Maths 4",
    "default_teacher": "Mandy Chen",
    "default_room": "B3011"
  },
  {
    "name": "University Counselling",
    "default_teacher": "G10 Counsellors",
    "default_room": "W2004"
  }
]$json$::jsonb) as source_rows(
    name text,
    default_teacher text,
    default_room text
  )
)
insert into public.courses (name, default_teacher, default_room)
select name, default_teacher, default_room
from source_rows;

with source_rows as (
  select *
  from jsonb_to_recordset($json$[
  {
    "slot_order": 1,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P1",
    "end_period_id": "P1",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {
      "IB Philosophy": {
        "teacher": "Matthew P.",
        "room": "B4041"
      }
    }
  },
  {
    "slot_order": 2,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P2",
    "end_period_id": "P3",
    "courses": [
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "PE 2",
      "PE 4",
      "PE 6",
      "PE 8"
    ],
    "details": {}
  },
  {
    "slot_order": 3,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P4",
    "end_period_id": "P5",
    "courses": [
      "Physics 4",
      "Economics 4",
      "Chinese 1",
      "Chinese 2",
      "Geography",
      "IB Theatre",
      "IB Physics 2",
      "IB Chemistry"
    ],
    "details": {
      "Geography": {
        "teacher": "Douglas Horton",
        "room": "B4039"
      }
    }
  },
  {
    "slot_order": 4,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P6",
    "end_period_id": "P6",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "IB Physics 1": {
        "teacher": "Logan Tian",
        "room": "3005"
      }
    }
  },
  {
    "slot_order": 5,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P7",
    "end_period_id": "P7",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  },
  {
    "slot_order": 6,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P8",
    "end_period_id": "P8",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "IPQ 5",
      "IPQ 6",
      "IPQ 7"
    ],
    "details": {}
  },
  {
    "slot_order": 7,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P9",
    "end_period_id": "P9",
    "courses": [
      "ESL 1",
      "ESL 3",
      "IPQ 1",
      "IPQ 2",
      "IPQ 3",
      "IPQ 4",
      "IB TOK",
      "ESL 2"
    ],
    "details": {}
  },
  {
    "slot_order": 8,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P1",
    "end_period_id": "P1",
    "courses": [
      "ESL 1",
      "ESL 3",
      "IPQ 1",
      "IPQ 2",
      "IPQ 3",
      "IPQ 4",
      "IB TOK",
      "ESL 2"
    ],
    "details": {}
  },
  {
    "slot_order": 9,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P2",
    "end_period_id": "P2",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Business 2",
      "Chemistry 3",
      "Biology",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {}
  },
  {
    "slot_order": 10,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P3",
    "end_period_id": "P4",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  },
  {
    "slot_order": 11,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P5",
    "end_period_id": "P5",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "IPQ 5",
      "IPQ 6",
      "IPQ 7"
    ],
    "details": {}
  },
  {
    "slot_order": 12,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P6",
    "end_period_id": "P6",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "Physics 1": {
        "teacher": "Peter R.",
        "room": "B3002"
      },
      "IB Physics 1": {
        "teacher": "Logan Tian",
        "room": "B3005"
      },
      "IB Geography": {
        "teacher": "Alex Oniango",
        "room": "B4041"
      }
    }
  },
  {
    "slot_order": 13,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P7",
    "end_period_id": "P7",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Business 2",
      "Chemistry 3",
      "Biology",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {}
  },
  {
    "slot_order": 14,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P8",
    "end_period_id": "P9",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {}
  },
  {
    "slot_order": 15,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P1",
    "end_period_id": "P2",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Business 2",
      "Chemistry 3",
      "Biology",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {}
  },
  {
    "slot_order": 16,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P3",
    "end_period_id": "P4",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  },
  {
    "slot_order": 17,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P5",
    "end_period_id": "P5",
    "courses": [
      "ESL 1",
      "ESL 3",
      "IPQ 1",
      "IPQ 2",
      "IPQ 3",
      "IPQ 4",
      "IB TOK",
      "ESL 2"
    ],
    "details": {}
  },
  {
    "slot_order": 18,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P6",
    "end_period_id": "P7",
    "courses": [
      "Physics 4",
      "Economics 4",
      "Chinese 1",
      "Chinese 2",
      "Geography",
      "IB Theatre",
      "IB Physics 2",
      "IB Chemistry"
    ],
    "details": {}
  },
  {
    "slot_order": 19,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P8",
    "end_period_id": "P9",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {
      "IB Philosophy": {
        "teacher": "Douglas Horton",
        "room": "B4039"
      },
      "ChemistrySummit": {
        "teacher": "Judy Zhu",
        "room": "B4004"
      }
    }
  },
  {
    "slot_order": 20,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P1",
    "end_period_id": "P2",
    "courses": [
      "Physics 4",
      "Economics 4",
      "Chinese 1",
      "Chinese 2",
      "Geography",
      "IB Theatre",
      "IB Physics 2",
      "IB Chemistry"
    ],
    "details": {}
  },
  {
    "slot_order": 21,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P3",
    "end_period_id": "P3",
    "courses": [
      "University Counselling"
    ],
    "details": {}
  },
  {
    "slot_order": 22,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P4",
    "end_period_id": "P5",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Chemistry 3",
      "Biology",
      "Business 2",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {
      "Business 2": {
        "teacher": "Joyce Zhou<br>Jennifer J.",
        "room": "B4040"
      }
    }
  },
  {
    "slot_order": 23,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P6",
    "end_period_id": "P7",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "ESL 1",
      "ESL 2",
      "ESL 3"
    ],
    "details": {}
  },
  {
    "slot_order": 24,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P8",
    "end_period_id": "P9",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "Chemistry 1": {
        "teacher": "Fiona Fu",
        "room": "B4002"
      }
    }
  },
  {
    "slot_order": 25,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P1",
    "end_period_id": "P1",
    "courses": [
      "Assembly"
    ],
    "details": {}
  },
  {
    "slot_order": 26,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P2",
    "end_period_id": "P2",
    "courses": [
      "House"
    ],
    "details": {}
  },
  {
    "slot_order": 27,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P3",
    "end_period_id": "P3",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {
      "IB Philosophy": {
        "teacher": "Matthew P.",
        "room": "B4041"
      },
      "Physics 2": {
        "teacher": "Peter R.",
        "room": "B3005"
      },
      "Chemistry 2": {
        "teacher": "Selina Sun",
        "room": "B4004"
      }
    }
  },
  {
    "slot_order": 28,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P4",
    "end_period_id": "P5",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "IB Physics 1": {
        "teacher": "Logan Tian",
        "room": "B4004"
      },
      "Chemistry 1": {
        "teacher": "Fiona Fu",
        "room": "B4002"
      }
    }
  },
  {
    "slot_order": 29,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P6",
    "end_period_id": "P7",
    "courses": [
      "IB English",
      "ESL 1",
      "ESL 2",
      "ESL 3",
      "PE 1",
      "PE 3",
      "PE 5",
      "PE 7"
    ],
    "details": {}
  },
  {
    "slot_order": 30,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P8",
    "end_period_id": "P8",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "IPQ 5",
      "IPQ 6",
      "IPQ 7"
    ],
    "details": {}
  },
  {
    "slot_order": 31,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P9",
    "end_period_id": "P9",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  }
]$json$::jsonb) as source_rows(
    slot_order integer,
    term_name text,
    grade_level text,
    day_name text,
    start_period_id text,
    end_period_id text,
    courses jsonb,
    details jsonb
  )
)
insert into public.timetable_slots (term_name, grade_level, day_name, start_period_id, end_period_id, slot_order)
select term_name, grade_level, day_name, start_period_id, end_period_id, slot_order
from source_rows
order by slot_order;

with source_rows as (
  select *
  from jsonb_to_recordset($json$[
  {
    "slot_order": 1,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P1",
    "end_period_id": "P1",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {
      "IB Philosophy": {
        "teacher": "Matthew P.",
        "room": "B4041"
      }
    }
  },
  {
    "slot_order": 2,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P2",
    "end_period_id": "P3",
    "courses": [
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "PE 2",
      "PE 4",
      "PE 6",
      "PE 8"
    ],
    "details": {}
  },
  {
    "slot_order": 3,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P4",
    "end_period_id": "P5",
    "courses": [
      "Physics 4",
      "Economics 4",
      "Chinese 1",
      "Chinese 2",
      "Geography",
      "IB Theatre",
      "IB Physics 2",
      "IB Chemistry"
    ],
    "details": {
      "Geography": {
        "teacher": "Douglas Horton",
        "room": "B4039"
      }
    }
  },
  {
    "slot_order": 4,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P6",
    "end_period_id": "P6",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "IB Physics 1": {
        "teacher": "Logan Tian",
        "room": "3005"
      }
    }
  },
  {
    "slot_order": 5,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P7",
    "end_period_id": "P7",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  },
  {
    "slot_order": 6,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P8",
    "end_period_id": "P8",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "IPQ 5",
      "IPQ 6",
      "IPQ 7"
    ],
    "details": {}
  },
  {
    "slot_order": 7,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Monday",
    "start_period_id": "P9",
    "end_period_id": "P9",
    "courses": [
      "ESL 1",
      "ESL 3",
      "IPQ 1",
      "IPQ 2",
      "IPQ 3",
      "IPQ 4",
      "IB TOK",
      "ESL 2"
    ],
    "details": {}
  },
  {
    "slot_order": 8,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P1",
    "end_period_id": "P1",
    "courses": [
      "ESL 1",
      "ESL 3",
      "IPQ 1",
      "IPQ 2",
      "IPQ 3",
      "IPQ 4",
      "IB TOK",
      "ESL 2"
    ],
    "details": {}
  },
  {
    "slot_order": 9,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P2",
    "end_period_id": "P2",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Business 2",
      "Chemistry 3",
      "Biology",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {}
  },
  {
    "slot_order": 10,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P3",
    "end_period_id": "P4",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  },
  {
    "slot_order": 11,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P5",
    "end_period_id": "P5",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "IPQ 5",
      "IPQ 6",
      "IPQ 7"
    ],
    "details": {}
  },
  {
    "slot_order": 12,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P6",
    "end_period_id": "P6",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "Physics 1": {
        "teacher": "Peter R.",
        "room": "B3002"
      },
      "IB Physics 1": {
        "teacher": "Logan Tian",
        "room": "B3005"
      },
      "IB Geography": {
        "teacher": "Alex Oniango",
        "room": "B4041"
      }
    }
  },
  {
    "slot_order": 13,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P7",
    "end_period_id": "P7",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Business 2",
      "Chemistry 3",
      "Biology",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {}
  },
  {
    "slot_order": 14,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Tuesday",
    "start_period_id": "P8",
    "end_period_id": "P9",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {}
  },
  {
    "slot_order": 15,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P1",
    "end_period_id": "P2",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Business 2",
      "Chemistry 3",
      "Biology",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {}
  },
  {
    "slot_order": 16,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P3",
    "end_period_id": "P4",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  },
  {
    "slot_order": 17,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P5",
    "end_period_id": "P5",
    "courses": [
      "ESL 1",
      "ESL 3",
      "IPQ 1",
      "IPQ 2",
      "IPQ 3",
      "IPQ 4",
      "IB TOK",
      "ESL 2"
    ],
    "details": {}
  },
  {
    "slot_order": 18,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P6",
    "end_period_id": "P7",
    "courses": [
      "Physics 4",
      "Economics 4",
      "Chinese 1",
      "Chinese 2",
      "Geography",
      "IB Theatre",
      "IB Physics 2",
      "IB Chemistry"
    ],
    "details": {}
  },
  {
    "slot_order": 19,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Wednesday",
    "start_period_id": "P8",
    "end_period_id": "P9",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {
      "IB Philosophy": {
        "teacher": "Douglas Horton",
        "room": "B4039"
      },
      "ChemistrySummit": {
        "teacher": "Judy Zhu",
        "room": "B4004"
      }
    }
  },
  {
    "slot_order": 20,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P1",
    "end_period_id": "P2",
    "courses": [
      "Physics 4",
      "Economics 4",
      "Chinese 1",
      "Chinese 2",
      "Geography",
      "IB Theatre",
      "IB Physics 2",
      "IB Chemistry"
    ],
    "details": {}
  },
  {
    "slot_order": 21,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P3",
    "end_period_id": "P3",
    "courses": [
      "University Counselling"
    ],
    "details": {}
  },
  {
    "slot_order": 22,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P4",
    "end_period_id": "P5",
    "courses": [
      "Physics 3",
      "Economics 3",
      "EconomicsSummit",
      "Chemistry 3",
      "Biology",
      "Business 2",
      "Computer Sci",
      "IB Chinese"
    ],
    "details": {
      "Business 2": {
        "teacher": "Joyce Zhou<br>Jennifer J.",
        "room": "B4040"
      }
    }
  },
  {
    "slot_order": 23,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P6",
    "end_period_id": "P7",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "ESL 1",
      "ESL 2",
      "ESL 3"
    ],
    "details": {}
  },
  {
    "slot_order": 24,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Thursday",
    "start_period_id": "P8",
    "end_period_id": "P9",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "Chemistry 1": {
        "teacher": "Fiona Fu",
        "room": "B4002"
      }
    }
  },
  {
    "slot_order": 25,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P1",
    "end_period_id": "P1",
    "courses": [
      "Assembly"
    ],
    "details": {}
  },
  {
    "slot_order": 26,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P2",
    "end_period_id": "P2",
    "courses": [
      "House"
    ],
    "details": {}
  },
  {
    "slot_order": 27,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P3",
    "end_period_id": "P3",
    "courses": [
      "Further Maths",
      "Physics 2",
      "Economics 2",
      "Chemistry 2",
      "ChemistrySummit",
      "Business 1",
      "Art 1",
      "Art 2",
      "IB Philosophy",
      "IB Economics 1"
    ],
    "details": {
      "IB Philosophy": {
        "teacher": "Matthew P.",
        "room": "B4041"
      },
      "Physics 2": {
        "teacher": "Peter R.",
        "room": "B3005"
      },
      "Chemistry 2": {
        "teacher": "Selina Sun",
        "room": "B4004"
      }
    }
  },
  {
    "slot_order": 28,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P4",
    "end_period_id": "P5",
    "courses": [
      "Physics 1",
      "PhysicsSummit",
      "Economics 1",
      "Chemistry 1",
      "Music",
      "IB Physics 1",
      "IB Biology",
      "IB Geography",
      "IB Economics 2"
    ],
    "details": {
      "IB Physics 1": {
        "teacher": "Logan Tian",
        "room": "B4004"
      },
      "Chemistry 1": {
        "teacher": "Fiona Fu",
        "room": "B4002"
      }
    }
  },
  {
    "slot_order": 29,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P6",
    "end_period_id": "P7",
    "courses": [
      "IB English",
      "ESL 1",
      "ESL 2",
      "ESL 3",
      "PE 1",
      "PE 3",
      "PE 5",
      "PE 7"
    ],
    "details": {}
  },
  {
    "slot_order": 30,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P8",
    "end_period_id": "P8",
    "courses": [
      "IB English",
      "AP English",
      "English L&L 1",
      "English L&L 2",
      "English L&L 3",
      "IPQ 5",
      "IPQ 6",
      "IPQ 7"
    ],
    "details": {}
  },
  {
    "slot_order": 31,
    "term_name": "June 2025",
    "grade_level": "G10",
    "day_name": "Friday",
    "start_period_id": "P9",
    "end_period_id": "P9",
    "courses": [
      "Regular Maths 1",
      "Regular Maths 2",
      "Regular Maths 3",
      "Regular Maths 4",
      "Fast Maths 1",
      "Fast Maths 2",
      "IB Maths",
      "Advanced Maths"
    ],
    "details": {}
  }
]$json$::jsonb) as source_rows(
    slot_order integer,
    term_name text,
    grade_level text,
    day_name text,
    start_period_id text,
    end_period_id text,
    courses jsonb,
    details jsonb
  )
)
insert into public.timetable_slot_courses (slot_id, course_id, display_order, override_teacher, override_room)
select
  slot.id,
  course.id,
  offered.ordinality::smallint,
  source_rows.details -> offered.course_name ->> 'teacher' as override_teacher,
  source_rows.details -> offered.course_name ->> 'room' as override_room
from source_rows
join public.timetable_slots as slot
  on slot.slot_order = source_rows.slot_order
join lateral jsonb_array_elements_text(source_rows.courses) with ordinality as offered(course_name, ordinality)
  on true
join public.courses as course
  on course.name = offered.course_name;

with source_rows as (
  select *
  from jsonb_to_recordset($json$[
  {
    "student_id": "189",
    "full_name": "Xie, Yue 解悦 (Alisa)",
    "enrollments": [
      "Chemistry 1",
      "Business 2",
      "Economics 4",
      "Regular Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "195",
    "full_name": "Fan, Huiyan 范惠嫣 (Kristen)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Business 2",
      "Regular Maths 4",
      "IPQ 1",
      "English L&L 2",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "209",
    "full_name": "Guo, Haoen 郭昊恩 (Ryan)",
    "enrollments": [
      "Chemistry 2",
      "Economics 3",
      "Physics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "217",
    "full_name": "Yu, Hao 余好 (Yumi)",
    "enrollments": [
      "Economics 1",
      "Business 1",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "220",
    "full_name": "Yu, Chunxi 于淳熙 (Brian)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "225",
    "full_name": "Chen, Ruilin 陈睿琳 (Reylin)",
    "enrollments": [
      "Art 1",
      "Economics 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "229",
    "full_name": "Deng, Zixuan 邓子萱 (Tina)",
    "enrollments": [
      "Art 2",
      "IB Theatre",
      "Regular Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "273",
    "full_name": "Xi, Xiangnan 奚向南 (Lucas)",
    "enrollments": [
      "Chemistry 2",
      "Biology",
      "Physics 4",
      "Fast Maths 1",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "301",
    "full_name": "Xie, Yifan 谢逸凡 (Steven)",
    "enrollments": [
      "PhysicsSummit",
      "Chemistry 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "317",
    "full_name": "Wu, Chengzhen 吴承臻 (Felix)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "327",
    "full_name": "Zhang, Qiwen 张荠文 (Angela)",
    "enrollments": [
      "Economics 1",
      "Art 2",
      "Physics 3",
      "Regular Maths 4",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "348",
    "full_name": "Qu, Zitong 瞿子童 (William)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Computer Sci",
      "Advanced Maths",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "384",
    "full_name": "Xu, Fanxi 徐凡茜 (Fancy)",
    "enrollments": [
      "Chemistry 1",
      "Business 2",
      "Physics 4",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "400",
    "full_name": "Hou, Kaiyi 侯凯译 (Eason)",
    "enrollments": [
      "ChemistrySummit",
      "PhysicsSummit",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "468",
    "full_name": "Wang, Meicheng 王美程 (Linda)",
    "enrollments": [
      "Economics 1",
      "Art 2",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "491",
    "full_name": "Liu, Yihan 刘奕含 (Michelle)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "527",
    "full_name": "Li, Ziheng 李梓蘅 (Hannah)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "529",
    "full_name": "Pang, Lixuan 庞力瑄 (Mylo)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "573",
    "full_name": "Jiang, Mingzhen 姜铭震 (Leo)",
    "enrollments": [
      "Chemistry 2",
      "Biology",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "587",
    "full_name": "Zhang, Leer 张乐儿 (Jasmine)",
    "enrollments": [
      "IB Economics 2",
      "IB Philosophy",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "622",
    "full_name": "Lee, Marty 李咏谦 (Marty)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "647",
    "full_name": "Shen, Juchen 沈居宸 (Jason)",
    "enrollments": [
      "Economics 1",
      "Physics 3",
      "Chinese 1",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "677",
    "full_name": "Tang, Jinglun 唐靖伦 (Jay)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "792",
    "full_name": "Yang, Michelle 杨茗羽 (Michelle)",
    "enrollments": [
      "IB Geography",
      "IB Philosophy",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "830",
    "full_name": "Chen, Ziyi 陈姿溢 (Jack)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "981",
    "full_name": "Zou, Peicheng 邹沛澄 (Kate)",
    "enrollments": [
      "Business 1",
      "Chemistry 3",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1001",
    "full_name": "Li, Muyao 李牧瑶 (Lynn)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1007",
    "full_name": "Yin, Yiyi 殷一奕 (Iris)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Chinese 2",
      "Regular Maths 3",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1009",
    "full_name": "Yu, Chengjie 虞程杰 (Jay)",
    "enrollments": [
      "IB Geography",
      "IB Economics 1",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1083",
    "full_name": "Yu, Youxin 俞佑欣 (Rebecca)",
    "enrollments": [
      "IB Geography",
      "IB Economics 1",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1154",
    "full_name": "Lu, Mengyao 陆孟瑶 (Yome)",
    "enrollments": [
      "Business 1",
      "Chemistry 3",
      "Geography",
      "Fast Maths 1",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1337",
    "full_name": "Zhu, Xutao 诸旭涛 (James)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Chemistry 3",
      "Regular Maths 4",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1464",
    "full_name": "Qian, Yunuo 钱雨诺 (Darren)",
    "enrollments": [
      "Economics 1",
      "Chemistry 3",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1587",
    "full_name": "Song, Yingjian 宋英健 (Sunny)",
    "enrollments": [
      "Economics 2",
      "Physics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1589",
    "full_name": "Zhang, Siyuan 张思远 (Owen)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1591",
    "full_name": "Chen, Xinyan 陈欣妍 (Candice)",
    "enrollments": [
      "Economics 2",
      "Chemistry 1",
      "Regular Maths 3",
      "IB Theatre",
      "English L&L 1",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1603",
    "full_name": "Deng, Ziyi 邓子毅 (Alpha)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1608",
    "full_name": "Li, Jinni 李金妮 (Jenny)",
    "enrollments": [
      "Economics 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1617",
    "full_name": "Xu, Jingbo 徐靖博 (Leo)",
    "enrollments": [
      "Physics 1",
      "Chinese 1",
      "Economics 3",
      "Regular Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1619",
    "full_name": "Wang, Linhui 汪麟珲 (Angela)",
    "enrollments": [
      "Physics 2",
      "Biology",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1620",
    "full_name": "Yin, Ziyou 殷梓又 (Jonathan)",
    "enrollments": [
      "Physics 1",
      "Chemistry 3",
      "Economics 4",
      "Regular Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1622",
    "full_name": "Huang, Lingyun 黄凌云 (Cathy)",
    "enrollments": [
      "Art 2",
      "Physics 3",
      "Economics 4",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1633",
    "full_name": "Huang, Ziyi 黄子一 (Ziyi)",
    "enrollments": [
      "Chemistry 1",
      "Art 1",
      "Biology",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1653",
    "full_name": "Chen, Feiran 陈菲然 (Felice)",
    "enrollments": [
      "Economics 2",
      "Business 2",
      "Chinese 1",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1657",
    "full_name": "Li, Jialang 李佳朗 (Richard)",
    "enrollments": [
      "Physics 1",
      "Biology",
      "Geography",
      "Regular Maths 2",
      "IPQ 3",
      "English L&L 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1729",
    "full_name": "Zhu, Chenxi 朱陈熙 (Tracy)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1747",
    "full_name": "Xiang, Qiuyu 向秋宇 (Tiffany)",
    "enrollments": [
      "Physics 1",
      "Art 2",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1750",
    "full_name": "Li, Chenrui 李辰睿 (Ray)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Biology",
      "Regular Maths 4",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1791",
    "full_name": "Liu, Shangrui 刘尚睿 (Shawn)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1840",
    "full_name": "Xia, Zitong 夏子童 (Alice)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Fast Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1860",
    "full_name": "Li, Yuanyuan 李媛媛 (Florence)",
    "enrollments": [
      "PhysicsSummit",
      "Economics 2",
      "Chemistry 3",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1935",
    "full_name": "Zhang, Ruyi 章茹壹 (Louise)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1961",
    "full_name": "Wu, Boxuan 武博轩 (Bob)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2200",
    "full_name": "Wu, Chongbo 吴翀博 (Mason)",
    "enrollments": [
      "Physics 2",
      "Chemistry 3",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2296",
    "full_name": "Ma, Shiyuan 马仕原 (Miles)",
    "enrollments": [
      "Chemistry 1",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2303",
    "full_name": "Cui, Yuhao 崔钰浩 (Harry)",
    "enrollments": [
      "Chemistry 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2351",
    "full_name": "Luo, Yehaoyu 罗叶浩宇 (Daniel)",
    "enrollments": [
      "ChemistrySummit",
      "Physics 3",
      "Geography",
      "Fast Maths 1",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2488",
    "full_name": "Zhou, Yuzhi 周榆智 (Mollar)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2489",
    "full_name": "Wu, Zhehan 吴哲涵 (Allan)",
    "enrollments": [
      "Physics 1",
      "Further Maths",
      "Chemistry 3",
      "Fast Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2497",
    "full_name": "Yuan, Zilin 袁梓琳 (Zilin)",
    "enrollments": [
      "Chemistry 2",
      "Business 2",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2498",
    "full_name": "Lu, Xuanyu 陆暄宇 (Tom)",
    "enrollments": [
      "Economics 1",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2502",
    "full_name": "Luan, Yue 栾越 (Arvin)",
    "enrollments": [
      "Music",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2507",
    "full_name": "Zhao, Xiaoshi 赵小石 (Stone)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2509",
    "full_name": "Xue, Chengxi 薛丞希 (Richard)",
    "enrollments": [
      "Art 1",
      "Physics 3",
      "Chinese 1",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2519",
    "full_name": "Yang, Keyi 杨珂一 (Yvonne)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Regular Maths 4",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2546",
    "full_name": "Huang, Yucheng 黄昱诚 (Johny)",
    "enrollments": [
      "Economics 1",
      "Business 2",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2562",
    "full_name": "Yue, Cheng 岳铖 (Eric)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Biology",
      "Regular Maths 4",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2563",
    "full_name": "Lu, Yiheng 陆以恒 (Raymond)",
    "enrollments": [
      "Economics 1",
      "Physics 3",
      "Geography",
      "Regular Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2564",
    "full_name": "Bao, Yiduo 包益朵 (Grace)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Economics 4",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2579",
    "full_name": "Zhang, Zikai 张子楷 (Carl)",
    "enrollments": [
      "Further Maths",
      "Chemistry 3",
      "Physics 4",
      "Fast Maths 1",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2585",
    "full_name": "Wu, Zeyu 吴泽宇 (William)",
    "enrollments": [
      "Physics 1",
      "Further Maths",
      "Business 2",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2594",
    "full_name": "Xu, Xiaoge 许潇戈 (Sophia)",
    "enrollments": [
      "Art 1",
      "Business 2",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2596",
    "full_name": "Qian, Xingyou 钱星友 (Ray)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2609",
    "full_name": "Geng, Xintong 耿欣彤 (Cynthia)",
    "enrollments": [
      "Physics 1",
      "Art 1",
      "Geography",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2610",
    "full_name": "Geng, Xinyi 耿欣仪 (Margaret)",
    "enrollments": [
      "Economics 1",
      "Chemistry 2",
      "Biology",
      "Regular Maths 4",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2642",
    "full_name": "Zhou, Qiyu 周琪宇 (Alex)",
    "enrollments": [
      "Physics 1",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2647",
    "full_name": "Tang, Zihao 汤子豪 (Howard)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Regular Maths 4",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2796",
    "full_name": "Guo, Gangcheng 郭罡呈 (Aiden)",
    "enrollments": [
      "Physics 1",
      "Business 2",
      "Chinese 1",
      "Regular Maths 2",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2836",
    "full_name": "Meng, Chenyi 孟辰逸 (Charles)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Computer Sci",
      "Advanced Maths",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2854",
    "full_name": "Zhu, Zhiyu 朱芝羽 (Carmen)",
    "enrollments": [
      "Music",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2899",
    "full_name": "Yao, Yuda 姚瑜达 (Adam)",
    "enrollments": [
      "Chemistry 2",
      "Computer Sci",
      "Physics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2922",
    "full_name": "Wang, Jiayi 王嘉毅 (Lester Bieber)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2947",
    "full_name": "Gu, Kanjie 顾阚杰 (Jay)",
    "enrollments": [
      "Physics 2",
      "Business 2",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3030",
    "full_name": "Li, Renxiang 李仁芗 (Elliott)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3093",
    "full_name": "Shi, Yuchen 史雨晨 (Zeena)",
    "enrollments": [
      "Economics 1",
      "Art 1",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3106",
    "full_name": "Zhang, Chi 张驰 (Alexandra)",
    "enrollments": [
      "Further Maths",
      "Economics 3",
      "Chinese 1",
      "Fast Maths 1",
      "IPQ 3",
      "English L&L 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3126",
    "full_name": "Lu, Yao 陆尧 (Lucas)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3166",
    "full_name": "Dai, Jiajun 戴嘉均 (Peter)",
    "enrollments": [
      "Physics 2",
      "Chemistry 3",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3168",
    "full_name": "Wang, Yuanzhe 王元哲 (Jeremy)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3243",
    "full_name": "Xing, Weibo 邢惟博 (Webber)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3278",
    "full_name": "Dai, Lu 戴璐 (Jane)",
    "enrollments": [
      "Physics 1",
      "Chemistry 2",
      "Biology",
      "Fast Maths 2",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3280",
    "full_name": "Lu, Zishi 陆子石 (David)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3284",
    "full_name": "Ding, Yifan 丁一梵 (Vinson)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Chemistry 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3297",
    "full_name": "Li, Yifeng 李沂风 (Aaron)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Computer Sci",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3309",
    "full_name": "Jiang, Gaofan 蒋高凡 (Elsa)",
    "enrollments": [
      "Economics 1",
      "Computer Sci",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3343",
    "full_name": "Wang, Sihan 王思涵 (Kevin)",
    "enrollments": [
      "Physics 1",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 2",
      "English L&L 1",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3362",
    "full_name": "Ding, Jiaqian 丁嘉倩 (Bettie)",
    "enrollments": [
      "Economics 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3368",
    "full_name": "Wang, Hongrui 王泓睿 (Albert)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3379",
    "full_name": "Wang, Feihao 王飞皓 (Frank)",
    "enrollments": [
      "PhysicsSummit",
      "Chemistry 2",
      "Computer Sci",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3383",
    "full_name": "Yin, Tianhao 印天浩 (Tianhao)",
    "enrollments": [
      "Chemistry 1",
      "Business 1",
      "Chinese 2",
      "Regular Maths 3",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3405",
    "full_name": "Huang, Liming 黄理铭 (Will)",
    "enrollments": [
      "Physics 2",
      "Business 2",
      "Economics 4",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3442",
    "full_name": "Zong, zhaoyi 宗昭亦 (Helix)",
    "enrollments": [
      "Chemistry 1",
      "Further Maths",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3451",
    "full_name": "Pan, Haonan 潘浩楠 (Haonan)",
    "enrollments": [
      "Chemistry 1",
      "Physics 3",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3485",
    "full_name": "Guo, Yunyi 过芸熠 (Mojito)",
    "enrollments": [
      "Physics 1",
      "Chemistry 3",
      "Chinese 2",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3500",
    "full_name": "Wu, Jiaqi 吴佳淇 (Kiki)",
    "enrollments": [
      "Physics 1",
      "Art 1",
      "Economics 4",
      "Regular Maths 3",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3503",
    "full_name": "Zhao, Yuanchen 赵元晨 (Lucas)",
    "enrollments": [
      "PhysicsSummit",
      "Economics 3",
      "Chemistry 2",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3508",
    "full_name": "Qi, Zixiang 漆子翔 (Bosen)",
    "enrollments": [
      "Business 1",
      "Physics 3",
      "Chinese 1",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3516",
    "full_name": "Zheng, Zehao 郑泽昊 (Leo)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Chemistry 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3522",
    "full_name": "Nunns, Johnathan 刘浩然 (Johnathan)",
    "enrollments": [
      "Further Maths",
      "Computer Sci",
      "Physics 4",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3527",
    "full_name": "Yang, Zongliang 杨宗亮 (Leon)",
    "enrollments": [
      "PhysicsSummit",
      "Economics 2",
      "Biology",
      "Fast Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3534",
    "full_name": "Gu, Yuhan 古钰涵 (Felina)",
    "enrollments": [
      "Art 1",
      "Physics 3",
      "Economics 4",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3543",
    "full_name": "Chai, lulin 柴璐琳 (Francesca)",
    "enrollments": [
      "Chemistry 1",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3574",
    "full_name": "Huang, Yuqiao 黄羽乔 (Fiona)",
    "enrollments": [
      "Physics 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3580",
    "full_name": "Qin, Yi 秦翌 (Angela)",
    "enrollments": [
      "Physics 1",
      "Business 1",
      "Geography",
      "Regular Maths 3",
      "IPQ 3",
      "English L&L 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3589",
    "full_name": "Mok, Jie Ying 莫洁楹 (Clara )",
    "enrollments": [
      "Chemistry 1",
      "Biology",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 1",
      "English L&L 2",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3591",
    "full_name": "Fan, Mengyao 樊梦瑶 (Carol)",
    "enrollments": [
      "Chinese 1",
      "Art 2",
      "Economics 3",
      "Regular Maths 1",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3618",
    "full_name": "Fan, Zheming 范哲铭 (Jeremy)",
    "enrollments": [
      "Art 2",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3620",
    "full_name": "Yao, Chengyun 姚程匀 (Kevin)",
    "enrollments": [
      "Physics 1",
      "Art 2",
      "Chinese 2",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3646",
    "full_name": "Chen, Siyan 陈思言 (Chloe)",
    "enrollments": [
      "Chemistry 2",
      "Biology",
      "Economics 4",
      "Fast Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3647",
    "full_name": "Xu, Yaqi 徐雅淇 (Ciya)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3665",
    "full_name": "Lin, Ruolan 林若岚 (Ava)",
    "enrollments": [
      "Chemistry 1",
      "Art 1",
      "Physics 4",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3673",
    "full_name": "Ji, Jiayu 季珈羽 (Yoyo)",
    "enrollments": [
      "IB Economics 2",
      "IB Philosophy",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3710",
    "full_name": "Ding, Wanjia 丁琬珈 (Jennifer)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3712",
    "full_name": "Guo, TianZi 过天子 (King)",
    "enrollments": [
      "Physics 1",
      "Business 1",
      "Chemistry 3",
      "Regular Maths 4",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3805",
    "full_name": "Wang, Jianuo 王嘉诺 (Clora)",
    "enrollments": [
      "Business 1",
      "Economics 1",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3808",
    "full_name": "Jiang, Qinfang 蒋沁芳 (Emily)",
    "enrollments": [
      "Economics 4",
      "Art 2",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3809",
    "full_name": "Zhu, DanChen 朱丹宸 (Cathy)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Physics 4",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3823",
    "full_name": "YANG, YUNKAI 杨云开 (Witt)",
    "enrollments": [
      "IB Philosophy",
      "EconomicsSummit",
      "Geography",
      "Fast Maths 1",
      "AP English",
      "IPQ 4",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3830",
    "full_name": "Wang, Anni 王安妮 (Annie)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Economics 4",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3835",
    "full_name": "Zhang, Yitao 章一韬 (Jerry)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Business 2",
      "Regular Maths 4",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3838",
    "full_name": "GU, RUIXI 顾睿羲 (Tesia)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3840",
    "full_name": "Wang, Hongxi 王翃熙 (Felix)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3841",
    "full_name": "tang, zhongxian 唐仲贤 (Tony)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3842",
    "full_name": "BAI, DONGLIN 白东霖 (COLE)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3845",
    "full_name": "Zhou, Sichen 周思忱 (Eastin)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3850",
    "full_name": "hu, yutong 胡语桐 (Julie)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3851",
    "full_name": "lu, yue 鲁越 (Andy)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3857",
    "full_name": "wang, yijin 王艺瑾 (Jennifer)",
    "enrollments": [
      "Economics 1",
      "Physics 3",
      "Chinese 2",
      "Regular Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3867",
    "full_name": "You, Ya 尤雅 (Grace)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Chemistry 3",
      "Fast Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3868",
    "full_name": "Zhao, Zehua 赵泽华 (Ricardo)",
    "enrollments": [
      "PhysicsSummit",
      "Further Maths",
      "EconomicsSummit",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3869",
    "full_name": "Wei, zixuan 魏子轩 (Weizen)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3871",
    "full_name": "Jiang, Jiaxin 蒋佳芯 (Klino)",
    "enrollments": [
      "Chemistry 1",
      "Physics 3",
      "Geography",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3877",
    "full_name": "Lyv, Xinwen 吕新闻 (News)",
    "enrollments": [
      "Economics 1",
      "Computer Sci",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3881",
    "full_name": "Wu, Yiyang 吴依洋 (Wicky)",
    "enrollments": [
      "Physics 1",
      "Business 2",
      "Economics 4",
      "Regular Maths 2",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3885",
    "full_name": "Ju, Tianmai 鞠天迈 (Tim)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3886",
    "full_name": "Liu, Hanze 刘瀚泽 (Arthur)",
    "enrollments": [
      "Chemistry 1",
      "Business 1",
      "Physics 4",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3887",
    "full_name": "Jiang, Ruoling 蒋若龄 (Rowling)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Economics 4",
      "Regular Maths 3",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3889",
    "full_name": "Xie, Zixuan 谢子轩 (Oscar)",
    "enrollments": [
      "Chemistry 3",
      "Physics 2",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3890",
    "full_name": "Zhao, Yutong 赵妤彤 (Teresa)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3901",
    "full_name": "Shen, Zizhen 沈子桢 (Jenson)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3938",
    "full_name": "Wang, Juntong 王君同 (Kingsley)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3946",
    "full_name": "Lu, Yanxin 陆言芯 (Sunny)",
    "enrollments": [
      "Art 2",
      "Economics 4",
      "Biology",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3965",
    "full_name": "Liu, Yufei 刘雨菲 (Yufei)",
    "enrollments": [
      "Economics 1",
      "Chemistry 2",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3972",
    "full_name": "Ling, Gerui 凌歌芮 (Andrea)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "4015",
    "full_name": "Yan, ShengYu 阎晟瑜 (Lily)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Theatre",
      "IB Chinese",
      "IB Maths",
      "IB TOK",
      "IB English",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "4062",
    "full_name": "Hanyu, Shangnuo 韩余尚诺 (Sunno)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Regular Maths 4",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  }
]$json$::jsonb) as source_rows(
    student_id text,
    full_name text,
    enrollments jsonb
  )
)
insert into public.students (student_id, full_name)
select student_id, full_name
from source_rows;

with source_rows as (
  select *
  from jsonb_to_recordset($json$[
  {
    "student_id": "189",
    "full_name": "Xie, Yue 解悦 (Alisa)",
    "enrollments": [
      "Chemistry 1",
      "Business 2",
      "Economics 4",
      "Regular Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "195",
    "full_name": "Fan, Huiyan 范惠嫣 (Kristen)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Business 2",
      "Regular Maths 4",
      "IPQ 1",
      "English L&L 2",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "209",
    "full_name": "Guo, Haoen 郭昊恩 (Ryan)",
    "enrollments": [
      "Chemistry 2",
      "Economics 3",
      "Physics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "217",
    "full_name": "Yu, Hao 余好 (Yumi)",
    "enrollments": [
      "Economics 1",
      "Business 1",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "220",
    "full_name": "Yu, Chunxi 于淳熙 (Brian)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "225",
    "full_name": "Chen, Ruilin 陈睿琳 (Reylin)",
    "enrollments": [
      "Art 1",
      "Economics 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "229",
    "full_name": "Deng, Zixuan 邓子萱 (Tina)",
    "enrollments": [
      "Art 2",
      "IB Theatre",
      "Regular Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "273",
    "full_name": "Xi, Xiangnan 奚向南 (Lucas)",
    "enrollments": [
      "Chemistry 2",
      "Biology",
      "Physics 4",
      "Fast Maths 1",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "301",
    "full_name": "Xie, Yifan 谢逸凡 (Steven)",
    "enrollments": [
      "PhysicsSummit",
      "Chemistry 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "317",
    "full_name": "Wu, Chengzhen 吴承臻 (Felix)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "327",
    "full_name": "Zhang, Qiwen 张荠文 (Angela)",
    "enrollments": [
      "Economics 1",
      "Art 2",
      "Physics 3",
      "Regular Maths 4",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "348",
    "full_name": "Qu, Zitong 瞿子童 (William)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Computer Sci",
      "Advanced Maths",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "384",
    "full_name": "Xu, Fanxi 徐凡茜 (Fancy)",
    "enrollments": [
      "Chemistry 1",
      "Business 2",
      "Physics 4",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "400",
    "full_name": "Hou, Kaiyi 侯凯译 (Eason)",
    "enrollments": [
      "ChemistrySummit",
      "PhysicsSummit",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "468",
    "full_name": "Wang, Meicheng 王美程 (Linda)",
    "enrollments": [
      "Economics 1",
      "Art 2",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "491",
    "full_name": "Liu, Yihan 刘奕含 (Michelle)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "527",
    "full_name": "Li, Ziheng 李梓蘅 (Hannah)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "529",
    "full_name": "Pang, Lixuan 庞力瑄 (Mylo)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "573",
    "full_name": "Jiang, Mingzhen 姜铭震 (Leo)",
    "enrollments": [
      "Chemistry 2",
      "Biology",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "587",
    "full_name": "Zhang, Leer 张乐儿 (Jasmine)",
    "enrollments": [
      "IB Economics 2",
      "IB Philosophy",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "622",
    "full_name": "Lee, Marty 李咏谦 (Marty)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "647",
    "full_name": "Shen, Juchen 沈居宸 (Jason)",
    "enrollments": [
      "Economics 1",
      "Physics 3",
      "Chinese 1",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "677",
    "full_name": "Tang, Jinglun 唐靖伦 (Jay)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "792",
    "full_name": "Yang, Michelle 杨茗羽 (Michelle)",
    "enrollments": [
      "IB Geography",
      "IB Philosophy",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "830",
    "full_name": "Chen, Ziyi 陈姿溢 (Jack)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "981",
    "full_name": "Zou, Peicheng 邹沛澄 (Kate)",
    "enrollments": [
      "Business 1",
      "Chemistry 3",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1001",
    "full_name": "Li, Muyao 李牧瑶 (Lynn)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1007",
    "full_name": "Yin, Yiyi 殷一奕 (Iris)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Chinese 2",
      "Regular Maths 3",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1009",
    "full_name": "Yu, Chengjie 虞程杰 (Jay)",
    "enrollments": [
      "IB Geography",
      "IB Economics 1",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1083",
    "full_name": "Yu, Youxin 俞佑欣 (Rebecca)",
    "enrollments": [
      "IB Geography",
      "IB Economics 1",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1154",
    "full_name": "Lu, Mengyao 陆孟瑶 (Yome)",
    "enrollments": [
      "Business 1",
      "Chemistry 3",
      "Geography",
      "Fast Maths 1",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1337",
    "full_name": "Zhu, Xutao 诸旭涛 (James)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Chemistry 3",
      "Regular Maths 4",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1464",
    "full_name": "Qian, Yunuo 钱雨诺 (Darren)",
    "enrollments": [
      "Economics 1",
      "Chemistry 3",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1587",
    "full_name": "Song, Yingjian 宋英健 (Sunny)",
    "enrollments": [
      "Economics 2",
      "Physics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1589",
    "full_name": "Zhang, Siyuan 张思远 (Owen)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1591",
    "full_name": "Chen, Xinyan 陈欣妍 (Candice)",
    "enrollments": [
      "Economics 2",
      "Chemistry 1",
      "Regular Maths 3",
      "IB Theatre",
      "English L&L 1",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1603",
    "full_name": "Deng, Ziyi 邓子毅 (Alpha)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1608",
    "full_name": "Li, Jinni 李金妮 (Jenny)",
    "enrollments": [
      "Economics 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1617",
    "full_name": "Xu, Jingbo 徐靖博 (Leo)",
    "enrollments": [
      "Physics 1",
      "Chinese 1",
      "Economics 3",
      "Regular Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1619",
    "full_name": "Wang, Linhui 汪麟珲 (Angela)",
    "enrollments": [
      "Physics 2",
      "Biology",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1620",
    "full_name": "Yin, Ziyou 殷梓又 (Jonathan)",
    "enrollments": [
      "Physics 1",
      "Chemistry 3",
      "Economics 4",
      "Regular Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1622",
    "full_name": "Huang, Lingyun 黄凌云 (Cathy)",
    "enrollments": [
      "Art 2",
      "Physics 3",
      "Economics 4",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1633",
    "full_name": "Huang, Ziyi 黄子一 (Ziyi)",
    "enrollments": [
      "Chemistry 1",
      "Art 1",
      "Biology",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1653",
    "full_name": "Chen, Feiran 陈菲然 (Felice)",
    "enrollments": [
      "Economics 2",
      "Business 2",
      "Chinese 1",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1657",
    "full_name": "Li, Jialang 李佳朗 (Richard)",
    "enrollments": [
      "Physics 1",
      "Biology",
      "Geography",
      "Regular Maths 2",
      "IPQ 3",
      "English L&L 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1729",
    "full_name": "Zhu, Chenxi 朱陈熙 (Tracy)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1747",
    "full_name": "Xiang, Qiuyu 向秋宇 (Tiffany)",
    "enrollments": [
      "Physics 1",
      "Art 2",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1750",
    "full_name": "Li, Chenrui 李辰睿 (Ray)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Biology",
      "Regular Maths 4",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1791",
    "full_name": "Liu, Shangrui 刘尚睿 (Shawn)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1840",
    "full_name": "Xia, Zitong 夏子童 (Alice)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Fast Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1860",
    "full_name": "Li, Yuanyuan 李媛媛 (Florence)",
    "enrollments": [
      "PhysicsSummit",
      "Economics 2",
      "Chemistry 3",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1935",
    "full_name": "Zhang, Ruyi 章茹壹 (Louise)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "1961",
    "full_name": "Wu, Boxuan 武博轩 (Bob)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2200",
    "full_name": "Wu, Chongbo 吴翀博 (Mason)",
    "enrollments": [
      "Physics 2",
      "Chemistry 3",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2296",
    "full_name": "Ma, Shiyuan 马仕原 (Miles)",
    "enrollments": [
      "Chemistry 1",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2303",
    "full_name": "Cui, Yuhao 崔钰浩 (Harry)",
    "enrollments": [
      "Chemistry 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2351",
    "full_name": "Luo, Yehaoyu 罗叶浩宇 (Daniel)",
    "enrollments": [
      "ChemistrySummit",
      "Physics 3",
      "Geography",
      "Fast Maths 1",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2488",
    "full_name": "Zhou, Yuzhi 周榆智 (Mollar)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2489",
    "full_name": "Wu, Zhehan 吴哲涵 (Allan)",
    "enrollments": [
      "Physics 1",
      "Further Maths",
      "Chemistry 3",
      "Fast Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2497",
    "full_name": "Yuan, Zilin 袁梓琳 (Zilin)",
    "enrollments": [
      "Chemistry 2",
      "Business 2",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2498",
    "full_name": "Lu, Xuanyu 陆暄宇 (Tom)",
    "enrollments": [
      "Economics 1",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2502",
    "full_name": "Luan, Yue 栾越 (Arvin)",
    "enrollments": [
      "Music",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2507",
    "full_name": "Zhao, Xiaoshi 赵小石 (Stone)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2509",
    "full_name": "Xue, Chengxi 薛丞希 (Richard)",
    "enrollments": [
      "Art 1",
      "Physics 3",
      "Chinese 1",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2519",
    "full_name": "Yang, Keyi 杨珂一 (Yvonne)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Regular Maths 4",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2546",
    "full_name": "Huang, Yucheng 黄昱诚 (Johny)",
    "enrollments": [
      "Economics 1",
      "Business 2",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2562",
    "full_name": "Yue, Cheng 岳铖 (Eric)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Biology",
      "Regular Maths 4",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2563",
    "full_name": "Lu, Yiheng 陆以恒 (Raymond)",
    "enrollments": [
      "Economics 1",
      "Physics 3",
      "Geography",
      "Regular Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2564",
    "full_name": "Bao, Yiduo 包益朵 (Grace)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Economics 4",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2579",
    "full_name": "Zhang, Zikai 张子楷 (Carl)",
    "enrollments": [
      "Further Maths",
      "Chemistry 3",
      "Physics 4",
      "Fast Maths 1",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2585",
    "full_name": "Wu, Zeyu 吴泽宇 (William)",
    "enrollments": [
      "Physics 1",
      "Further Maths",
      "Business 2",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2594",
    "full_name": "Xu, Xiaoge 许潇戈 (Sophia)",
    "enrollments": [
      "Art 1",
      "Business 2",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2596",
    "full_name": "Qian, Xingyou 钱星友 (Ray)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2609",
    "full_name": "Geng, Xintong 耿欣彤 (Cynthia)",
    "enrollments": [
      "Physics 1",
      "Art 1",
      "Geography",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2610",
    "full_name": "Geng, Xinyi 耿欣仪 (Margaret)",
    "enrollments": [
      "Economics 1",
      "Chemistry 2",
      "Biology",
      "Regular Maths 4",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2642",
    "full_name": "Zhou, Qiyu 周琪宇 (Alex)",
    "enrollments": [
      "Physics 1",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2647",
    "full_name": "Tang, Zihao 汤子豪 (Howard)",
    "enrollments": [
      "Chemistry 1",
      "Economics 2",
      "Physics 3",
      "Regular Maths 4",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2796",
    "full_name": "Guo, Gangcheng 郭罡呈 (Aiden)",
    "enrollments": [
      "Physics 1",
      "Business 2",
      "Chinese 1",
      "Regular Maths 2",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2836",
    "full_name": "Meng, Chenyi 孟辰逸 (Charles)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Computer Sci",
      "Advanced Maths",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2854",
    "full_name": "Zhu, Zhiyu 朱芝羽 (Carmen)",
    "enrollments": [
      "Music",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2899",
    "full_name": "Yao, Yuda 姚瑜达 (Adam)",
    "enrollments": [
      "Chemistry 2",
      "Computer Sci",
      "Physics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2922",
    "full_name": "Wang, Jiayi 王嘉毅 (Lester Bieber)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "2947",
    "full_name": "Gu, Kanjie 顾阚杰 (Jay)",
    "enrollments": [
      "Physics 2",
      "Business 2",
      "Chinese 1",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3030",
    "full_name": "Li, Renxiang 李仁芗 (Elliott)",
    "enrollments": [
      "IB Biology",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3093",
    "full_name": "Shi, Yuchen 史雨晨 (Zeena)",
    "enrollments": [
      "Economics 1",
      "Art 1",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3106",
    "full_name": "Zhang, Chi 张驰 (Alexandra)",
    "enrollments": [
      "Further Maths",
      "Economics 3",
      "Chinese 1",
      "Fast Maths 1",
      "IPQ 3",
      "English L&L 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3126",
    "full_name": "Lu, Yao 陆尧 (Lucas)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3166",
    "full_name": "Dai, Jiajun 戴嘉均 (Peter)",
    "enrollments": [
      "Physics 2",
      "Chemistry 3",
      "Economics 4",
      "Fast Maths 1",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3168",
    "full_name": "Wang, Yuanzhe 王元哲 (Jeremy)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Computer Sci",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3243",
    "full_name": "Xing, Weibo 邢惟博 (Webber)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3278",
    "full_name": "Dai, Lu 戴璐 (Jane)",
    "enrollments": [
      "Physics 1",
      "Chemistry 2",
      "Biology",
      "Fast Maths 2",
      "IPQ 4",
      "English L&L 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3280",
    "full_name": "Lu, Zishi 陆子石 (David)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3284",
    "full_name": "Ding, Yifan 丁一梵 (Vinson)",
    "enrollments": [
      "Physics 1",
      "Economics 2",
      "Chemistry 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3297",
    "full_name": "Li, Yifeng 李沂风 (Aaron)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Computer Sci",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3309",
    "full_name": "Jiang, Gaofan 蒋高凡 (Elsa)",
    "enrollments": [
      "Economics 1",
      "Computer Sci",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3343",
    "full_name": "Wang, Sihan 王思涵 (Kevin)",
    "enrollments": [
      "Physics 1",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 2",
      "English L&L 1",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3362",
    "full_name": "Ding, Jiaqian 丁嘉倩 (Bettie)",
    "enrollments": [
      "Economics 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3368",
    "full_name": "Wang, Hongrui 王泓睿 (Albert)",
    "enrollments": [
      "Physics 2",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3379",
    "full_name": "Wang, Feihao 王飞皓 (Frank)",
    "enrollments": [
      "PhysicsSummit",
      "Chemistry 2",
      "Computer Sci",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3383",
    "full_name": "Yin, Tianhao 印天浩 (Tianhao)",
    "enrollments": [
      "Chemistry 1",
      "Business 1",
      "Chinese 2",
      "Regular Maths 3",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3405",
    "full_name": "Huang, Liming 黄理铭 (Will)",
    "enrollments": [
      "Physics 2",
      "Business 2",
      "Economics 4",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3442",
    "full_name": "Zong, zhaoyi 宗昭亦 (Helix)",
    "enrollments": [
      "Chemistry 1",
      "Further Maths",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3451",
    "full_name": "Pan, Haonan 潘浩楠 (Haonan)",
    "enrollments": [
      "Chemistry 1",
      "Physics 3",
      "Chinese 2",
      "Regular Maths 2",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3485",
    "full_name": "Guo, Yunyi 过芸熠 (Mojito)",
    "enrollments": [
      "Physics 1",
      "Chemistry 3",
      "Chinese 2",
      "Regular Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3500",
    "full_name": "Wu, Jiaqi 吴佳淇 (Kiki)",
    "enrollments": [
      "Physics 1",
      "Art 1",
      "Economics 4",
      "Regular Maths 3",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3503",
    "full_name": "Zhao, Yuanchen 赵元晨 (Lucas)",
    "enrollments": [
      "PhysicsSummit",
      "Economics 3",
      "Chemistry 2",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3508",
    "full_name": "Qi, Zixiang 漆子翔 (Bosen)",
    "enrollments": [
      "Business 1",
      "Physics 3",
      "Chinese 1",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3516",
    "full_name": "Zheng, Zehao 郑泽昊 (Leo)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Chemistry 3",
      "Regular Maths 4",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3522",
    "full_name": "Nunns, Johnathan 刘浩然 (Johnathan)",
    "enrollments": [
      "Further Maths",
      "Computer Sci",
      "Physics 4",
      "Regular Maths 1",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3527",
    "full_name": "Yang, Zongliang 杨宗亮 (Leon)",
    "enrollments": [
      "PhysicsSummit",
      "Economics 2",
      "Biology",
      "Fast Maths 2",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3534",
    "full_name": "Gu, Yuhan 古钰涵 (Felina)",
    "enrollments": [
      "Art 1",
      "Physics 3",
      "Economics 4",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3543",
    "full_name": "Chai, lulin 柴璐琳 (Francesca)",
    "enrollments": [
      "Chemistry 1",
      "Economics 3",
      "Chinese 1",
      "Regular Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3574",
    "full_name": "Huang, Yuqiao 黄羽乔 (Fiona)",
    "enrollments": [
      "Physics 1",
      "Art 1",
      "Chinese 1",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3580",
    "full_name": "Qin, Yi 秦翌 (Angela)",
    "enrollments": [
      "Physics 1",
      "Business 1",
      "Geography",
      "Regular Maths 3",
      "IPQ 3",
      "English L&L 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3589",
    "full_name": "Mok, Jie Ying 莫洁楹 (Clara )",
    "enrollments": [
      "Chemistry 1",
      "Biology",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 1",
      "English L&L 2",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3591",
    "full_name": "Fan, Mengyao 樊梦瑶 (Carol)",
    "enrollments": [
      "Chinese 1",
      "Art 2",
      "Economics 3",
      "Regular Maths 1",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3618",
    "full_name": "Fan, Zheming 范哲铭 (Jeremy)",
    "enrollments": [
      "Art 2",
      "Economics 3",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3620",
    "full_name": "Yao, Chengyun 姚程匀 (Kevin)",
    "enrollments": [
      "Physics 1",
      "Art 2",
      "Chinese 2",
      "Regular Maths 3",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3646",
    "full_name": "Chen, Siyan 陈思言 (Chloe)",
    "enrollments": [
      "Chemistry 2",
      "Biology",
      "Economics 4",
      "Fast Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3647",
    "full_name": "Xu, Yaqi 徐雅淇 (Ciya)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3665",
    "full_name": "Lin, Ruolan 林若岚 (Ava)",
    "enrollments": [
      "Chemistry 1",
      "Art 1",
      "Physics 4",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3673",
    "full_name": "Ji, Jiayu 季珈羽 (Yoyo)",
    "enrollments": [
      "IB Economics 2",
      "IB Philosophy",
      "IB Chinese",
      "IB Physics 2",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3710",
    "full_name": "Ding, Wanjia 丁琬珈 (Jennifer)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3712",
    "full_name": "Guo, TianZi 过天子 (King)",
    "enrollments": [
      "Physics 1",
      "Business 1",
      "Chemistry 3",
      "Regular Maths 4",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3805",
    "full_name": "Wang, Jianuo 王嘉诺 (Clora)",
    "enrollments": [
      "Business 1",
      "Economics 1",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3808",
    "full_name": "Jiang, Qinfang 蒋沁芳 (Emily)",
    "enrollments": [
      "Economics 4",
      "Art 2",
      "Regular Maths 3",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3809",
    "full_name": "Zhu, DanChen 朱丹宸 (Cathy)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Physics 4",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3823",
    "full_name": "YANG, YUNKAI 杨云开 (Witt)",
    "enrollments": [
      "IB Philosophy",
      "EconomicsSummit",
      "Geography",
      "Fast Maths 1",
      "AP English",
      "IPQ 4",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3830",
    "full_name": "Wang, Anni 王安妮 (Annie)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Economics 4",
      "Regular Maths 1",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3835",
    "full_name": "Zhang, Yitao 章一韬 (Jerry)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Business 2",
      "Regular Maths 4",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3838",
    "full_name": "GU, RUIXI 顾睿羲 (Tesia)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3840",
    "full_name": "Wang, Hongxi 王翃熙 (Felix)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Chinese",
      "IB Theatre",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3841",
    "full_name": "tang, zhongxian 唐仲贤 (Tony)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3842",
    "full_name": "BAI, DONGLIN 白东霖 (COLE)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3845",
    "full_name": "Zhou, Sichen 周思忱 (Eastin)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3850",
    "full_name": "hu, yutong 胡语桐 (Julie)",
    "enrollments": [
      "IB Biology",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3851",
    "full_name": "lu, yue 鲁越 (Andy)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "EconomicsSummit",
      "Advanced Maths",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3857",
    "full_name": "wang, yijin 王艺瑾 (Jennifer)",
    "enrollments": [
      "Economics 1",
      "Physics 3",
      "Chinese 2",
      "Regular Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3867",
    "full_name": "You, Ya 尤雅 (Grace)",
    "enrollments": [
      "Economics 1",
      "Physics 2",
      "Chemistry 3",
      "Fast Maths 2",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3868",
    "full_name": "Zhao, Zehua 赵泽华 (Ricardo)",
    "enrollments": [
      "PhysicsSummit",
      "Further Maths",
      "EconomicsSummit",
      "Fast Maths 2",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3869",
    "full_name": "Wei, zixuan 魏子轩 (Weizen)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3871",
    "full_name": "Jiang, Jiaxin 蒋佳芯 (Klino)",
    "enrollments": [
      "Chemistry 1",
      "Physics 3",
      "Geography",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3877",
    "full_name": "Lyv, Xinwen 吕新闻 (News)",
    "enrollments": [
      "Economics 1",
      "Computer Sci",
      "Physics 4",
      "Regular Maths 2",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3881",
    "full_name": "Wu, Yiyang 吴依洋 (Wicky)",
    "enrollments": [
      "Physics 1",
      "Business 2",
      "Economics 4",
      "Regular Maths 2",
      "IPQ 6",
      "ESL 2",
      "PE 4",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3885",
    "full_name": "Ju, Tianmai 鞠天迈 (Tim)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3886",
    "full_name": "Liu, Hanze 刘瀚泽 (Arthur)",
    "enrollments": [
      "Chemistry 1",
      "Business 1",
      "Physics 4",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3887",
    "full_name": "Jiang, Ruoling 蒋若龄 (Rowling)",
    "enrollments": [
      "Chemistry 1",
      "Physics 2",
      "Economics 4",
      "Regular Maths 3",
      "AP English",
      "IPQ 1",
      "PE 1",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3889",
    "full_name": "Xie, Zixuan 谢子轩 (Oscar)",
    "enrollments": [
      "Chemistry 3",
      "Physics 2",
      "Chinese 2",
      "Regular Maths 1",
      "IPQ 5",
      "ESL 1",
      "PE 2",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3890",
    "full_name": "Zhao, Yutong 赵妤彤 (Teresa)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 3",
      "IPQ 4",
      "PE 7",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3901",
    "full_name": "Shen, Zizhen 沈子桢 (Jenson)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "AP English",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3938",
    "full_name": "Wang, Juntong 王君同 (Kingsley)",
    "enrollments": [
      "PhysicsSummit",
      "ChemistrySummit",
      "Biology",
      "Fast Maths 2",
      "English L&L 1",
      "IPQ 2",
      "PE 3",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3946",
    "full_name": "Lu, Yanxin 陆言芯 (Sunny)",
    "enrollments": [
      "Art 2",
      "Economics 4",
      "Biology",
      "Regular Maths 1",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3965",
    "full_name": "Liu, Yufei 刘雨菲 (Yufei)",
    "enrollments": [
      "Economics 1",
      "Chemistry 2",
      "Chinese 2",
      "Regular Maths 3",
      "IPQ 7",
      "ESL 3",
      "PE 6",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "3972",
    "full_name": "Ling, Gerui 凌歌芮 (Andrea)",
    "enrollments": [
      "IB Physics 1",
      "IB Economics 1",
      "IB Chinese",
      "IB Chemistry",
      "IB Maths",
      "IB English",
      "IB TOK",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "4015",
    "full_name": "Yan, ShengYu 阎晟瑜 (Lily)",
    "enrollments": [
      "IB Physics 1",
      "IB Philosophy",
      "IB Theatre",
      "IB Chinese",
      "IB Maths",
      "IB TOK",
      "IB English",
      "PE 8",
      "University Counselling",
      "Assembly",
      "House"
    ]
  },
  {
    "student_id": "4062",
    "full_name": "Hanyu, Shangnuo 韩余尚诺 (Sunno)",
    "enrollments": [
      "Art 2",
      "Business 2",
      "Regular Maths 4",
      "English L&L 2",
      "IPQ 3",
      "PE 5",
      "University Counselling",
      "Assembly",
      "House"
    ]
  }
]$json$::jsonb) as source_rows(
    student_id text,
    full_name text,
    enrollments jsonb
  )
)
insert into public.student_enrollments (student_id, course_id)
select distinct
  source_rows.student_id,
  course.id
from source_rows
join lateral jsonb_array_elements_text(source_rows.enrollments) as enrolled(course_name)
  on true
join public.courses as course
  on course.name = enrolled.course_name;

create view public.student_timetable_entries as
select
  student.student_id,
  student.full_name,
  slot.term_name,
  slot.grade_level,
  slot.day_name,
  slot.slot_order,
  slot.start_period_id,
  slot.end_period_id,
  start_period.sort_order as start_period_order,
  end_period.sort_order as end_period_order,
  course.name as course_name,
  coalesce(slot_course.override_teacher, course.default_teacher) as teacher,
  coalesce(slot_course.override_room, course.default_room) as room
from public.student_enrollments as enrollment
join public.students as student
  on student.student_id = enrollment.student_id
join public.timetable_slot_courses as slot_course
  on slot_course.course_id = enrollment.course_id
join public.timetable_slots as slot
  on slot.id = slot_course.slot_id
join public.courses as course
  on course.id = enrollment.course_id
join public.periods as start_period
  on start_period.id = slot.start_period_id
join public.periods as end_period
  on end_period.id = slot.end_period_id;

comment on view public.student_timetable_entries is
  'Derived student timetable entries generated from timetable slots and student course enrollments.';

commit;
