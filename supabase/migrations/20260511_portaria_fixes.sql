-- AG Converge — fix Bug 1: enforce_capacity sem FOR UPDATE
--              fix Bug 2: mark_entrada retorna BOOLEAN

-- ── Fix 1: adiciona FOR UPDATE para serializar inserts na última vaga ──────────
-- Sem FOR UPDATE, dois inserts simultâneos podiam ambos passar pela checagem
-- de capacidade e exceder o limite. FOR UPDATE no event_config garante que
-- apenas um insert por vez avança quando o slot está chegando ao limite.
CREATE OR REPLACE FUNCTION enforce_capacity()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cfg       RECORD;
  cur_count INT;
BEGIN
  SELECT capacity, open INTO cfg
  FROM event_config
  WHERE evento_id = NEW.evento_id
  FOR UPDATE;

  IF NOT FOUND THEN RETURN NEW; END IF;

  IF NOT cfg.open THEN
    RAISE EXCEPTION 'event_closed: inscricoes encerradas para %', NEW.evento_id;
  END IF;

  SELECT COUNT(*) INTO cur_count
  FROM registrations
  WHERE evento_id = NEW.evento_id;

  IF cur_count >= cfg.capacity THEN
    RAISE EXCEPTION 'capacity_exceeded: vagas esgotadas para %', NEW.evento_id;
  END IF;

  RETURN NEW;
END;
$$;

-- ── Fix 2: mark_entrada retorna BOOLEAN (true = entrada registrada, false = já entrou) ──
-- Permite que a portaria distinga "confirmado agora" de "já havia entrado"
-- sem precisar de um lookup adicional.
CREATE OR REPLACE FUNCTION mark_entrada(p_ingresso_id TEXT, p_pwd_hash TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  rows_updated INT;
BEGIN
  IF p_pwd_hash <> '61681c268936f5241e321e2bdacd6748849b9dab35cab8397fb77d0ebe2d2414' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  UPDATE registrations
  SET entrada_at = NOW()
  WHERE upper(ingresso_id) = upper(p_ingresso_id)
    AND entrada_at IS NULL;
  GET DIAGNOSTICS rows_updated = ROW_COUNT;
  RETURN rows_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_entrada TO anon;
