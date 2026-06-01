update courses
set default_teacher = case name
  when 'English E-1 - Honors' then 'Kurt Shelton'
  when 'English E-2 - L&L1' then 'Jenna Wade Dunn'
  when 'English E-3 - L&L2' then 'Lim Wan'
  when 'English E-4 - L&L3' then 'Helen Liu'
  when 'English E-5 - ESL 1' then 'Sally Guo'
  when 'English E-6 - ESL 2' then 'Sherry Yuan'
  when 'English E-7 - ESL 3' then 'Cordelia Jiao'
  else default_teacher
end
where name in (
  'English E-1 - Honors',
  'English E-2 - L&L1',
  'English E-3 - L&L2',
  'English E-4 - L&L3',
  'English E-5 - ESL 1',
  'English E-6 - ESL 2',
  'English E-7 - ESL 3'
)
and coalesce(default_teacher, '') = '';