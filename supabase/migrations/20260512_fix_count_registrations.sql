-- AG Converge — fix count_registrations
--
-- Bug: RETURNS TABLE declara saída chamada "capacity", criando ambiguidade
-- com a coluna event_config.capacity no SELECT interno (mesmo em PLPGSQL).
-- Fix: qualificar com alias de tabela (ec.capacity, ec.open).

DROP FUNCTION IF EXISTS count_registrations(TEXT);
CREATE OR REPLACE FUNCTION count_registrations(p_evento_id TEXT)
RETURNS TABLE (total BIGINT, capacity INT, available INT, open BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total    BIGINT  := 0;
  v_capacity INT     := 0;
  v_open     BOOLEAN := TRUE;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM registrations
  WHERE evento_id = p_evento_id;

  SELECT ec.capacity, ec.open INTO v_capacity, v_open
  FROM event_config ec
  WHERE ec.evento_id = p_evento_id;

  RETURN QUERY SELECT
    v_total,
    v_capacity,
    GREATEST(0, v_capacity - v_total::INT),
    v_open;
END;
$$;

-- Garante que a linha de configuração existe para rh-em-xeque
INSERT INTO event_config(evento_id, capacity, open)
VALUES ('rh-em-xeque', 120, true)
ON CONFLICT (evento_id) DO NOTHING;

GRANT EXECUTE ON FUNCTION count_registrations TO anon;
