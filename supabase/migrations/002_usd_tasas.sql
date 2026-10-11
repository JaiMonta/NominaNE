-- =====================================================================
-- NÓMINA WEB APP — Moneda USD y tasa BCV (VES)
-- Los montos base se guardan en USD; al generar la nómina se convierten
-- a Bolívares (VES) a la tasa del BCV de la fecha de corte, cargada
-- manualmente por un administrador/rrhh en la pantalla "Tasas".
-- Requiere haber ejecutado antes 001_schema.sql (usa es_rrhh()).
-- =====================================================================

-- ---------- Tasas de cambio (carga manual) ----------
create table tasas_cambio (
  fecha date not null,
  moneda text not null default 'USD',
  tasa numeric(18,4) not null check (tasa > 0),
  fuente text default 'BCV',
  created_at timestamptz default now(),
  primary key (fecha, moneda)
);

alter table tasas_cambio enable row level security;
create policy tasas_read on tasas_cambio for select using (auth.uid() is not null);
create policy tasas_write on tasas_cambio for all
  using (es_rrhh()) with check (es_rrhh());

-- ---------- Aclarar moneda USD en los datos base ----------
-- Los valores existentes YA están en USD: sólo se renombra la columna.
alter table empleados rename column salario_mensual to salario_mensual_usd;
alter table novedades rename column monto to monto_usd;

comment on column empleados.salario_mensual_usd is 'Salario mensual en USD (se convierte a VES al generar la nómina)';
comment on column novedades.monto_usd is 'Monto de la novedad en USD (0 = lo calcula el motor)';
comment on column conceptos.valor is 'Monto fijo en USD o fracción (0.10 = 10%) según calculo';

-- ---------- Tasa congelada en la nómina ----------
alter table nominas add column tasa_bcv numeric(18,4);
alter table nominas add column tasa_fecha date;

-- ---------- Resultados en VES y su espejo en USD ----------
alter table recibos add column salario_mensual_usd numeric(14,2);
alter table recibos add column tasa_bcv numeric(18,4);
alter table recibos add column total_ingresos_usd numeric(14,2);
alter table recibos add column total_egresos_usd numeric(14,2);
alter table recibos add column neto_usd numeric(14,2);

alter table recibo_detalle add column monto_usd numeric(14,2);
