alter table novedades
  add column if not exists aplicada_nomina_id uuid references nominas(id) on delete set null;

create index if not exists novedades_aplicada_nomina_idx
  on novedades (aplicada_nomina_id);

create table if not exists nomina_recalculos (
  id uuid primary key default gen_random_uuid(),
  nomina_id uuid not null references nominas(id) on delete cascade,
  tasa_anterior numeric(18,4) not null,
  tasa_nueva numeric(18,4) not null,
  fecha_anterior date,
  fecha_nueva date,
  recalculado_por uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table nomina_recalculos enable row level security;
drop policy if exists nomina_recalculos_read on nomina_recalculos;
create policy nomina_recalculos_read on nomina_recalculos for select
  using (es_rrhh());

create or replace function aprobar_nomina(p_nomina_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inicio date;
  v_fin date;
  v_modalidad text;
  v_aplicadas integer := 0;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  select periodo_inicio, periodo_fin, modalidad_nomina
    into v_inicio, v_fin, v_modalidad
    from nominas
   where id = p_nomina_id
     and estado = 'borrador'
     for update;

  if not found then
    raise exception 'Nomina no encontrada o no esta en borrador';
  end if;

  if v_modalidad = 'normal' then
    update novedades n
       set aplicada_nomina_id = p_nomina_id
      from recibos r
     where r.nomina_id = p_nomina_id
       and n.empleado_id = r.empleado_id
       and n.periodo_inicio is not null
       and n.periodo_inicio <= v_fin
       and coalesce(n.periodo_fin, n.periodo_inicio) >= v_inicio
       and n.aplicada_nomina_id is null;
    get diagnostics v_aplicadas = row_count;
  end if;

  update nominas set estado = 'aprobada' where id = p_nomina_id;
  return v_aplicadas;
end;
$$;

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
         aporte_ince_patronal = round(r.aporte_ince_patronal * v_factor, 2)
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
           r.aporte_ince_patronal,
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
    coalesce(round(sum(r.aporte_ince_patronal), 2), 0)
  into
    v_total_ingresos,
    v_total_egresos,
    v_total_neto,
    v_total_aportes,
    v_total_ivss,
    v_total_rpe,
    v_total_faov,
    v_total_lop,
    v_total_ince
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
