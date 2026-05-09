-- AG Converge — schema inicial

CREATE TABLE IF NOT EXISTS registrations (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  ingresso_id      TEXT        UNIQUE NOT NULL,
  grupo_id         TEXT        NOT NULL,
  evento_id        TEXT        NOT NULL,
  nome             TEXT        NOT NULL,
  email            TEXT        NOT NULL,
  tel              TEXT,
  empresa          TEXT,
  cargo            TEXT,
  origem           TEXT        DEFAULT 'direto',
  inscricao_at     TIMESTAMPTZ DEFAULT NOW(),
  doacao           NUMERIC(10,2) DEFAULT 0,
  doacao_confirmada BOOLEAN    DEFAULT FALSE,
  titular          BOOLEAN     DEFAULT TRUE,
  titular_nome     TEXT,
  ingresso_baixado BOOLEAN     DEFAULT FALSE,
  entrada_at       TIMESTAMPTZ
);

-- Índices para lookup rápido
CREATE INDEX idx_reg_email     ON registrations(lower(email));
CREATE INDEX idx_reg_evento    ON registrations(evento_id);
CREATE INDEX idx_reg_grupo     ON registrations(grupo_id);
CREATE INDEX idx_reg_ingresso  ON registrations(ingresso_id);

-- RLS
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;

-- Qualquer um pode se inscrever
CREATE POLICY "public insert" ON registrations
  FOR INSERT WITH CHECK (true);

-- Ninguém lê direto pela anon key — tudo via funções abaixo
CREATE POLICY "no direct select" ON registrations
  FOR SELECT USING (false);

-- ── FUNÇÕES DE ACESSO ──────────────────────────────────────────

-- 1. Lookup do usuário: retorna ingressos de um e-mail num evento
CREATE OR REPLACE FUNCTION lookup_ingresso(p_email TEXT, p_evento_id TEXT)
RETURNS TABLE (
  ingresso_id TEXT, grupo_id TEXT, evento_id TEXT,
  nome TEXT, email TEXT, tel TEXT,
  titular BOOLEAN, titular_nome TEXT,
  doacao NUMERIC, doacao_confirmada BOOLEAN,
  ingresso_baixado BOOLEAN, inscricao_at TIMESTAMPTZ
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT ingresso_id, grupo_id, evento_id, nome, email, tel,
         titular, titular_nome, doacao, doacao_confirmada,
         ingresso_baixado, inscricao_at
  FROM registrations
  WHERE lower(email) = lower(p_email)
    AND evento_id = p_evento_id;
$$;

-- 2. Histórico cross-event: todos os eventos de um e-mail
CREATE OR REPLACE FUNCTION historico_email(p_email TEXT)
RETURNS TABLE (
  ingresso_id TEXT, grupo_id TEXT, evento_id TEXT,
  nome TEXT, titular BOOLEAN, titular_nome TEXT,
  doacao NUMERIC, inscricao_at TIMESTAMPTZ
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT ingresso_id, grupo_id, evento_id, nome,
         titular, titular_nome, doacao, inscricao_at
  FROM registrations
  WHERE lower(email) = lower(p_email)
  ORDER BY inscricao_at DESC;
$$;

-- 3. Admin: retorna todos os leads de um evento (valida hash da senha no Postgres)
CREATE OR REPLACE FUNCTION admin_leads(p_evento_id TEXT, p_pwd_hash TEXT)
RETURNS TABLE (
  ingresso_id TEXT, grupo_id TEXT, nome TEXT, email TEXT,
  tel TEXT, empresa TEXT, cargo TEXT, origem TEXT,
  titular BOOLEAN, titular_nome TEXT,
  doacao NUMERIC, doacao_confirmada BOOLEAN,
  ingresso_baixado BOOLEAN, entrada_at TIMESTAMPTZ,
  inscricao_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- hash da senha admin (SHA-256 de ag@admin2026)
  IF p_pwd_hash <> '61681c268936f5241e321e2bdacd6748849b9dab35cab8397fb77d0ebe2d2414' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  RETURN QUERY
    SELECT r.ingresso_id, r.grupo_id, r.nome, r.email,
           r.tel, r.empresa, r.cargo, r.origem,
           r.titular, r.titular_nome,
           r.doacao, r.doacao_confirmada,
           r.ingresso_baixado, r.entrada_at, r.inscricao_at
    FROM registrations r
    WHERE r.evento_id = p_evento_id
    ORDER BY r.inscricao_at DESC;
END;
$$;

-- 4. Marcar ingresso como baixado
CREATE OR REPLACE FUNCTION mark_baixado(p_ingresso_id TEXT)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE registrations SET ingresso_baixado = TRUE
  WHERE ingresso_id = p_ingresso_id;
$$;

-- 5. Check duplicata antes de salvar (evita race condition com localStorage)
CREATE OR REPLACE FUNCTION check_duplicate(p_email TEXT, p_evento_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM registrations
    WHERE lower(email) = lower(p_email) AND evento_id = p_evento_id
  );
$$;

GRANT EXECUTE ON FUNCTION lookup_ingresso      TO anon;
GRANT EXECUTE ON FUNCTION historico_email      TO anon;
GRANT EXECUTE ON FUNCTION admin_leads          TO anon;
GRANT EXECUTE ON FUNCTION mark_baixado         TO anon;
GRANT EXECUTE ON FUNCTION check_duplicate      TO anon;
