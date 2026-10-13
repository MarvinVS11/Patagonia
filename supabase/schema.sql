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
