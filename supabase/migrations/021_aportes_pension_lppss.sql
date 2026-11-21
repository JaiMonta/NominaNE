-- =====================================================================
-- NÓMINA WEB APP — Contribución Especial de Protección de Pensiones
-- Ley de Protección de las Pensiones de Seguridad Social (LPPSS)
-- Decreto N.º 4.952 (Gaceta Oficial N.º 42.880): alícuota del 9%.
-- Aporte exclusivo del patrono sobre salario + bonos no salariales.
-- El piso por trabajador es el ingreso mínimo integral (configurable).
-- =====================================================================

insert into parametros_legales (clave, valor, descripcion, referencia_legal) values
  ('pension_patrono_pct', 0.09, 'Contribución Especial LPPSS - aporte patrono sobre salario y bonos no salariales', 'Ley de Protección de las Pensiones / Decreto 4.952'),
  ('pension_base_minima_bs', 0, 'Piso mensual por trabajador para la contribución LPPSS (ingreso mínimo integral). 0 = sin piso', 'LPPSS Art. 7 / Decreto 4.952')
on conflict (clave) do nothing;

alter table recibos
  add column if not exists aporte_pension_patronal numeric(14,2) not null default 0;

alter table nominas
  add column if not exists total_aporte_pension numeric(16,2) not null default 0;

-- Recalcular también la contribución de pensiones al cambiar la tasa BCV.
create or replace function recalcular_nomina(
  p_nomina_id uuid,
  p_tasa numeric,
  p_tasa_fecha date
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_nomina nominas%rowtype;
  v_factor numeric;
  v_total_ingresos numeric;
  v_total_egresos numeric;
  v_total_neto numeric;
  v_total_aportes numeric;
  v_total_ivss numeric;
  v_total_rpe numeric;
  v_total_faov numeric;
  v_total_lop numeric;
  v_total_ince numeric;
  v_total_pension numeric;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;
  if p_tasa is null or p_tasa <= 0 then
    raise exception 'La tasa debe ser mayor a 0';
  end if;
  if p_tasa_fecha is null then
    raise exception 'Indique la fecha de la tasa';
  end if;

  select * into v_nomina
    from nominas
   where id = p_nomina_id
   for update;

  if not found then
    raise exception 'Nómina no encontrada';
  end if;
  if v_nomina.estado <> 'aprobada' then
    raise exception 'Solo se pueden recalcular nóminas aprobadas';
  end if;
  if v_nomina.tasa_bcv is null or v_nomina.tasa_bcv <= 0 then
    raise exception 'La nómina no tiene una tasa anterior válida';
  end if;

  v_factor := p_tasa / v_nomina.tasa_bcv;

  update recibo_detalle d
     set monto = round(d.monto * v_factor, 2),
         monto_usd = round(d.monto * v_factor / p_tasa, 2)
    from recibos r
   where d.recibo_id = r.id
     and r.nomina_id = p_nomina_id;

  update recibos r
     set salario_mensual = round(r.salario_mensual * v_factor, 2),
         salario_diario = round(r.salario_diario * v_factor, 4),
         tasa_bcv = p_tasa,
         total_ingresos = coalesce((
           select round(sum(d.monto), 2)
             from recibo_detalle d
            where d.recibo_id = r.id and d.tipo = 'ingreso'
         ), 0),
         total_egresos = coalesce((
           select round(sum(d.monto), 2)
             from recibo_detalle d
            where d.recibo_id = r.id and d.tipo = 'egreso'
         ), 0),
         neto = coalesce((
           select round(sum(d.monto), 2)
             from recibo_detalle d
            where d.recibo_id = r.id and d.tipo = 'ingreso'
         ), 0) - coalesce((
           select round(sum(d.monto), 2)
             from recibo_detalle d
            where d.recibo_id = r.id and d.tipo = 'egreso'
         ), 0),
         aporte_ivss_patronal = round(r.aporte_ivss_patronal * v_factor, 2),
         aporte_rpe_patronal = round(r.aporte_rpe_patronal * v_factor, 2),
         aporte_faov_patronal = round(r.aporte_faov_patronal * v_factor, 2),
         aporte_lopcymat_patronal = round(r.aporte_lopcymat_patronal * v_factor, 2),
         aporte_ince_patronal = round(r.aporte_ince_patronal * v_factor, 2),
         aporte_pension_patronal = round(r.aporte_pension_patronal * v_factor, 2)
   where r.nomina_id = p_nomina_id;

  update recibos r
     set total_ingresos_usd = round(r.total_ingresos / p_tasa, 2),
         total_egresos_usd = round(r.total_egresos / p_tasa, 2),
         neto_usd = round(r.neto / p_tasa, 2),
         aportes_patronales = round(
           r.aporte_ivss_patronal +
           r.aporte_rpe_patronal +
           r.aporte_faov_patronal +
           r.aporte_lopcymat_patronal +
           r.aporte_ince_patronal +
           r.aporte_pension_patronal,
           2
         )
   where r.nomina_id = p_nomina_id;

  select
    coalesce(round(sum(r.total_ingresos), 2), 0),
    coalesce(round(sum(r.total_egresos), 2), 0),
    coalesce(round(sum(r.neto), 2), 0),
    coalesce(round(sum(r.aportes_patronales), 2), 0),
    coalesce(round(sum(r.aporte_ivss_patronal), 2), 0),
    coalesce(round(sum(r.aporte_rpe_patronal), 2), 0),
    coalesce(round(sum(r.aporte_faov_patronal), 2), 0),
    coalesce(round(sum(r.aporte_lopcymat_patronal), 2), 0),
    coalesce(round(sum(r.aporte_ince_patronal), 2), 0),
    coalesce(round(sum(r.aporte_pension_patronal), 2), 0)
  into
    v_total_ingresos,
    v_total_egresos,
    v_total_neto,
    v_total_aportes,
    v_total_ivss,
    v_total_rpe,
    v_total_faov,
    v_total_lop,
    v_total_ince,
    v_total_pension
  from recibos r
  where r.nomina_id = p_nomina_id;

  update nominas
     set total_ingresos = v_total_ingresos,
         total_egresos = v_total_egresos,
         total_neto = v_total_neto,
         total_aportes_patronales = v_total_aportes,
         total_aporte_ivss = v_total_ivss,
         total_aporte_rpe = v_total_rpe,
         total_aporte_faov = v_total_faov,
         total_aporte_lopcymat = v_total_lop,
         total_aporte_ince = v_total_ince,
         total_aporte_pension = v_total_pension,
         tasa_bcv = p_tasa,
         tasa_fecha = p_tasa_fecha
   where id = p_nomina_id;

  insert into nomina_recalculos
    (nomina_id, tasa_anterior, tasa_nueva, fecha_anterior, fecha_nueva, recalculado_por)
  values
    (p_nomina_id, v_nomina.tasa_bcv, p_tasa, v_nomina.tasa_fecha, p_tasa_fecha, auth.uid());

  return jsonb_build_object(
    'ok', true,
    'tasa_anterior', v_nomina.tasa_bcv,
    'tasa_nueva', p_tasa,
    'total_neto', v_total_neto
  );
end;
$$;

revoke all on function recalcular_nomina(uuid, numeric, date) from public;
grant execute on function recalcular_nomina(uuid, numeric, date) to authenticated;
