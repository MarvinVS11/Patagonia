-- Proyecto Supabase: Patagonia (hjrjplzeycmponjopmrh)
-- Esquema de vuelos y asientos que usa index.html. Ya aplicado; se guarda aquí como referencia.

create table public.vuelos (
  id            bigint generated always as identity primary key,
  tramo         text not null check (tramo in ('ida','vuelta')),
  orden         smallint not null,
  numero        text not null,
  aerolinea     text not null,
  aeronave      text,
  origen        text not null,
  origen_nombre text,
  destino       text not null,
  destino_nombre text,
  fecha_salida  date not null,
  hora_salida   time not null,   -- hora local del aeropuerto
  fecha_llegada date not null,
  hora_llegada  time not null,   -- hora local del aeropuerto
  duracion      interval,
  escala_despues text,           -- texto de la escala/espera que sigue
  updated_at    timestamptz not null default now(),
  unique (numero, fecha_salida),
  unique (tramo, orden)
);

create table public.asientos (
  id         bigint generated always as identity primary key,
  vuelo_id   bigint not null references public.vuelos(id) on delete cascade,
  orden      smallint not null,
  pasajero   text not null,
  asiento    text check (asiento is null or char_length(asiento) between 1 and 6), -- null = por asignar
  updated_at timestamptz not null default now(),
  unique (vuelo_id, pasajero)
);
create index asientos_vuelo_id_idx on public.asientos (vuelo_id);

create or replace function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end; $$;
create trigger vuelos_updated_at before update on public.vuelos for each row execute function public.set_updated_at();
create trigger asientos_updated_at before update on public.asientos for each row execute function public.set_updated_at();

-- Seguridad: la página (clave pública) puede leer y editar contenido, pero no crear ni borrar filas
alter table public.vuelos enable row level security;
alter table public.asientos enable row level security;

revoke insert, update, delete, truncate on public.vuelos, public.asientos from anon, authenticated;
grant update (asiento) on public.asientos to anon, authenticated;
grant update (numero, aerolinea, aeronave, origen, origen_nombre, destino, destino_nombre,
              fecha_salida, hora_salida, fecha_llegada, hora_llegada, duracion, escala_despues)
  on public.vuelos to anon, authenticated;

create policy "Lectura pública de vuelos"   on public.vuelos   for select to anon, authenticated using (true);
create policy "Lectura pública de asientos" on public.asientos for select to anon, authenticated using (true);
create policy "Edición de vuelos desde la página"   on public.vuelos   for update to anon, authenticated using (true) with check (true);
create policy "Edición de asientos desde la página" on public.asientos for update to anon, authenticated using (true) with check (true);

-- Tiempo real
alter publication supabase_realtime add table public.vuelos, public.asientos;

-- ── Gastos (agregado 7 nov 2026) ──
create table public.tipos_cambio (
  moneda     text primary key check (moneda in ('USD','CLP','CRC')),
  por_usd    numeric(12,4) not null check (por_usd > 0),   -- unidades por 1 USD
  updated_at timestamptz not null default now()
);
insert into public.tipos_cambio (moneda, por_usd) values ('USD',1), ('CLP',976.64), ('CRC',452.95);

create table public.gastos (
  id            uuid primary key default gen_random_uuid(),   -- lo genera el teléfono (permite cola sin señal)
  fecha         date not null default ((now() at time zone 'America/Punta_Arenas')::date),
  categoria     text not null check (categoria in ('hospedaje','vehiculo','gasolina','comida','super','tours','camping','transporte','vuelos','otros')),
  descripcion   text check (descripcion is null or char_length(descripcion) <= 120),
  monto         numeric(14,2) not null check (monto > 0 and monto < 100000000),
  moneda        text not null default 'CLP' check (moneda in ('USD','CLP','CRC')),
  pagado_por    text not null check (pagado_por in ('Nallely','Adrian','Heylin','Emanuel','Karol','Marvin')),
  participantes text[] not null default array['Nallely','Adrian','Heylin','Emanuel','Karol','Marvin']
                check (cardinality(participantes) between 1 and 6
                       and participantes <@ array['Nallely','Adrian','Heylin','Emanuel','Karol','Marvin']),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index gastos_fecha_idx on public.gastos (fecha desc, created_at desc);
create trigger gastos_updated_at before update on public.gastos for each row execute function public.set_updated_at();
create trigger tipos_cambio_updated_at before update on public.tipos_cambio for each row execute function public.set_updated_at();

alter table public.gastos enable row level security;
alter table public.tipos_cambio enable row level security;
revoke all on public.gastos, public.tipos_cambio from anon, authenticated;
grant select, insert, update, delete on public.gastos to anon, authenticated;
grant select on public.tipos_cambio to anon, authenticated;
grant update (por_usd) on public.tipos_cambio to anon, authenticated;
create policy "Leer gastos"    on public.gastos for select to anon, authenticated using (true);
create policy "Agregar gastos" on public.gastos for insert to anon, authenticated with check (true);
create policy "Editar gastos"  on public.gastos for update to anon, authenticated using (true) with check (true);
create policy "Borrar gastos"  on public.gastos for delete to anon, authenticated using (true);
create policy "Leer tipos de cambio"   on public.tipos_cambio for select to anon, authenticated using (true);
create policy "Editar tipos de cambio" on public.tipos_cambio for update to anon, authenticated using (moneda <> 'USD') with check (moneda <> 'USD');

alter table public.gastos replica identity full;
alter publication supabase_realtime add table public.gastos, public.tipos_cambio;
