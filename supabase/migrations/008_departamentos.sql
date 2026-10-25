create table if not exists departamentos (
  id uuid primary key default gen_random_uuid(),
  nombre text unique not null,
  activo boolean not null default true,
  orden integer not null default 999,
  created_at timestamptz default now()
);

alter table departamentos enable row level security;

drop policy if exists departamentos_read on departamentos;
create policy departamentos_read on departamentos for select
  using (auth.uid() is not null);

drop policy if exists departamentos_write on departamentos;
create policy departamentos_write on departamentos for all
  using (es_rrhh()) with check (es_rrhh());

insert into departamentos (nombre, orden) values
  ('Presidencia', 10),
  ('Gerencia', 20),
  ('Finanzas', 30),
  ('Administración', 40),
  ('Producción', 50),
  ('Seguridad', 60),
  ('Ventas', 70),
  ('RRHH', 80)
on conflict (nombre) do nothing;

alter table empleados add column if not exists departamento_id uuid;

update empleados
   set departamento = case
     when lower(trim(departamento)) in ('prosuccion', 'prosucción') then 'Producción'
     when lower(trim(departamento)) = 'vigilancia' then 'Seguridad'
     else regexp_replace(trim(departamento), '\s+', ' ', 'g')
   end
 where departamento is not null;

insert into departamentos (nombre, orden)
select distinct departamento, 999
  from empleados
 where departamento is not null and trim(departamento) <> ''
on conflict (nombre) do nothing;

update empleados e
   set departamento = d.nombre,
       departamento_id = d.id
  from departamentos d
 where lower(e.departamento) = lower(d.nombre);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'empleados_departamento_id_fkey'
  ) then
    alter table empleados
      add constraint empleados_departamento_id_fkey
      foreign key (departamento_id) references departamentos(id) on delete set null;
  end if;
end $$;

create index if not exists empleados_departamento_id_idx
  on empleados (departamento_id);

create or replace function public.sync_departamento_nombre() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.nombre is distinct from old.nombre then
    update empleados set departamento = new.nombre where departamento_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists departamentos_sync_nombre on departamentos;
create trigger departamentos_sync_nombre
  after update of nombre on departamentos
  for each row execute function public.sync_departamento_nombre();
