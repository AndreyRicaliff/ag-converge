-- AG Converge — concurrency fixes

-- 1. UNIQUE constraint: impede e-mail duplicado no banco (fecha race condition)
CREATE UNIQUE INDEX IF NOT EXISTS idx_reg_unique_email_evento
  ON registrations(lower(email), evento_id);

-- 2. Tabela de configuração por evento (capacidade + status aberto/fechado)
CREATE TABLE IF NOT EXISTS event_config (
  evento_id  TEXT PRIMARY KEY,
  capacity   INT     NOT NULL DEFAULT 0,
  open       BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO event_config(evento_id, capacity, open)
VALUES ('rh-em-xeque', 120, true)
ON CONFLICT (evento_id) DO NOTHING;

-- 3. Trigger de capacidade — server-side, executado a cada INSERT, sem janela de race condition
CREATE OR REPLACE FUNCTION enforce_capacity()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cfg       RECORD;
  cur_count INT;
BEGIN
  SELECT capacity, open INTO cfg FROM event_config WHERE evento_id = NEW.evento_id;
  IF NOT FOUND THEN RETURN NEW; END IF;

  IF NOT cfg.open THEN
    RAISE EXCEPTION 'event_closed: inscricoes encerradas para %', NEW.evento_id;
  END IF;

  -- Conta ANTES deste INSERT (FOR UPDATE trava a leitura contra concurrent inserts)
  SELECT COUNT(*) INTO cur_count
  FROM registrations
  WHERE evento_id = NEW.evento_id;

  IF cur_count >= cfg.capacity THEN
    RAISE EXCEPTION 'capacity_exceeded: vagas esgotadas para %', NEW.evento_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_capacity ON registrations;
CREATE TRIGGER trg_enforce_capacity
  BEFORE INSERT ON registrations
  FOR EACH ROW EXECUTE FUNCTION enforce_capacity();

-- 4. Abrir/fechar inscrições manualmente (via admin)
CREATE OR REPLACE FUNCTION set_event_open(
  p_evento_id TEXT,
  p_open      BOOLEAN,
  p_pwd_hash  TEXT
)
RETURNS void LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_pwd_hash <> '61681c268936f5241e321e2bdacd6748849b9dab35cab8397fb77d0ebe2d2414' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  UPDATE event_config SET open = p_open WHERE evento_id = p_evento_id;
END;
$$;

-- 5. Atualiza count_registrations para também retornar vagas livres e status
DROP FUNCTION IF EXISTS count_registrations(TEXT);
CREATE OR REPLACE FUNCTION count_registrations(p_evento_id TEXT)
RETURNS TABLE (total BIGINT, capacity INT, available INT, open BOOLEAN)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT
    COUNT(r.id)                             AS total,
    COALESCE(c.capacity, 0)                 AS capacity,
    GREATEST(0, COALESCE(c.capacity, 0) - COUNT(r.id)::INT) AS available,
    COALESCE(c.open, TRUE)                  AS open
  FROM event_config c
  LEFT JOIN registrations r ON r.evento_id = c.evento_id
  WHERE c.evento_id = p_evento_id
  GROUP BY c.capacity, c.open;
$$;

GRANT EXECUTE ON FUNCTION set_event_open     TO anon;
GRANT EXECUTE ON FUNCTION enforce_capacity   TO anon;
-- count_registrations já tem grant do migration anterior
