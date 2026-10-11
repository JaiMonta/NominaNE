-- =====================================================================
-- NÓMINA WEB APP — Ajustes de texto (empresa para documentos/PDF)
-- parametros_legales.valor es numérico; aquí van los valores de texto.
-- Requiere haber ejecutado antes 001_schema.sql (usa es_rrhh()).
-- =====================================================================

create table ajustes (
  clave text primary key,
  valor text not null default '',
  descripcion text
);

alter table ajustes enable row level security;
create policy ajustes_read on ajustes for select using (auth.uid() is not null);
create policy ajustes_write on ajustes for all
  using (es_rrhh()) with check (es_rrhh());

insert into ajustes (clave, valor, descripcion) values
  ('empresa_nombre', '', 'Nombre de la empresa en recibos/PDF'),
  ('empresa_rif',    '', 'RIF de la empresa (opcional, documentos/PDF)');
