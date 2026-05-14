-- Pesquisa de satisfação AG Converge
create table if not exists survey_responses (
  id          uuid        default gen_random_uuid() primary key,
  evento      text        not null default 'rh-em-xeque-2026-05-14',
  respostas   jsonb       not null,
  device_hint text,
  created_at  timestamptz default now()
);

alter table survey_responses enable row level security;

-- Qualquer visitante pode inserir (pesquisa pública via QR)
create policy "anon_insert" on survey_responses
  for insert to anon with check (true);

-- Anon pode ler (admin usa mesma chave do projeto)
create policy "anon_select" on survey_responses
  for select to anon using (true);
