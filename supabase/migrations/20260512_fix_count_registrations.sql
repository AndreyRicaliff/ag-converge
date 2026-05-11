-- AG Converge — fix count_registrations
--
-- Bug anterior: count_registrations fazia LEFT JOIN a partir de event_config.
-- Se o evento não tivesse linha em event_config a query retornava vazio,
-- e todo o grupo (titular + convidados) ficava com total = 0 na barra de vagas.
--
-- Fix: conta registrations diretamente, join event_config apenas para capacity/open.

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

  SELECT capacity, open INTO v_capacity, v_open
  FROM event_config
  WHERE evento_id = p_evento_id;

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
