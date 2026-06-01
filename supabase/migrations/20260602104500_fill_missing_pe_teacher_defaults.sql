update public.courses
set default_teacher = case name
  when 'PE-1' then 'Abie Rakgoale'
  when 'PE-2' then 'Nicole Mangondo'
  when 'PE-3' then 'Miko Qian'
  when 'PE-4' then 'Matthew Johnson'
  when 'PE-5' then 'Milan Vucinic'
  when 'PE-6' then 'Lourdes Caramol'
  when 'PE-7' then 'Milan Saric'
  else default_teacher
end
where name in (
  'PE-1',
  'PE-2',
  'PE-3',
  'PE-4',
  'PE-5',
  'PE-6',
  'PE-7'
);