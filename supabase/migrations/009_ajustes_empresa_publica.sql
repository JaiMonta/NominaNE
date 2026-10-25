drop policy if exists ajustes_empresa_publica on ajustes;

create policy ajustes_empresa_publica on ajustes for select to anon
  using (clave = 'empresa_nombre');
