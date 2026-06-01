update timetable_slot_courses
set override_room = 'B3007'
where course_id = 105
  and slot_id in (81, 82);