update public.students
set program = 'A Level'
where upper(trim(coalesce(program, ''))) = 'CAIE';

create or replace function public.normalise_student_program(raw_program text)
returns text
language sql
immutable
as $$
  select case upper(trim(coalesce(raw_program, '')))
    when 'IBDP' then 'IB'
    when 'IB' then 'IB'
    when 'CAIE' then 'A Level'
    when 'A LEVEL' then 'A Level'
    else coalesce(nullif(trim(coalesce(raw_program, '')), ''), 'A Level')
  end;
$$;