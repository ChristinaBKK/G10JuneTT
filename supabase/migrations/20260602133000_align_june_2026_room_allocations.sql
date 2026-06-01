update timetable_slot_courses
set override_room = case
  when course_id = 143 and slot_id in (88, 89, 92) then 'B3010'
  when course_id = 108 and slot_id in (43, 44) then 'B4041'
  when course_id = 108 and slot_id in (97, 98) then 'B4011'
  when course_id = 136 and slot_id in (81, 82) then 'B4011'
  when course_id = 105 and slot_id in (36, 37) then 'B3007'
  when course_id = 193 and slot_id in (36, 37) then 'B3009'
  else override_room
end
where (course_id = 143 and slot_id in (88, 89, 92))
   or (course_id = 108 and slot_id in (43, 44, 97, 98))
   or (course_id = 136 and slot_id in (81, 82))
   or (course_id = 105 and slot_id in (36, 37))
   or (course_id = 193 and slot_id in (36, 37));