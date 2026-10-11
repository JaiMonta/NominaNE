-- =====================================================================
-- NÓMINA WEB APP — Desglose de aportes patronales por concepto
-- Separa IVSS, RPE, FAOV y LOPCYMAT en los recibos y en los totales
-- de la nómina. Requiere haber ejecutado antes 001..003.
-- =====================================================================

-- Aportes patronales por recibo
alter table recibos add column aporte_ivss_patronal     numeric(14,2) not null default 0;
alter table recibos add column aporte_rpe_patronal      numeric(14,2) not null default 0;
alter table recibos add column aporte_faov_patronal     numeric(14,2) not null default 0;
alter table recibos add column aporte_lopcymat_patronal numeric(14,2) not null default 0;

-- Totales de aportes patronales por nómina
alter table nominas add column total_aporte_ivss     numeric(16,2) default 0;
alter table nominas add column total_aporte_rpe      numeric(16,2) default 0;
alter table nominas add column total_aporte_faov     numeric(16,2) default 0;
alter table nominas add column total_aporte_lopcymat numeric(16,2) default 0;
