alter table empleados
  add column if not exists modalidad_nomina text not null default 'normal'
  check (modalidad_nomina in ('normal', 'contratado'));

alter table nominas
  add column if not exists modalidad_nomina text not null default 'normal'
  check (modalidad_nomina in ('normal', 'contratado'));
