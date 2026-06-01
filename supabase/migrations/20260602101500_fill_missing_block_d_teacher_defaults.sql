update public.courses
set default_teacher = case name
  when 'Chinese D-1' then 'Miya Yang'
  when 'Chinese D-2' then 'Ivy Zhu'
  when 'English A HL' then 'Darren McQuay'
  when 'English A SL' then 'Darren McQuay'
  when 'English B HL' then 'Warwick Midlane'
  else default_teacher
end
where name in (
  'Chinese D-1',
  'Chinese D-2',
  'English A HL',
  'English A SL',
  'English B HL'
);