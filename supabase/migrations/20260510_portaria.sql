-- AG Converge — portaria / check-in

-- 1. Lookup por ingresso_id (sem auth — portaria precisa ser rápida)
CREATE OR REPLACE FUNCTION lookup_by_ingresso_id(p_ingresso_id TEXT)
RETURNS TABLE (
  ingresso_id TEXT, grupo_id TEXT, evento_id TEXT,
  nome TEXT, email TEXT, tel TEXT, empresa TEXT, cargo TEXT,
  titular BOOLEAN, titular_nome TEXT,
  doacao NUMERIC, ingresso_baixado BOOLEAN,
  entrada_at TIMESTAMPTZ, inscricao_at TIMESTAMPTZ
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT ingresso_id, grupo_id, evento_id, nome, email, tel, empresa, cargo,
         titular, titular_nome, doacao, ingresso_baixado, entrada_at, inscricao_at
  FROM registrations
  WHERE upper(ingresso_id) = upper(p_ingresso_id);
$$;

-- 2. Marcar entrada (com validação de senha admin)
CREATE OR REPLACE FUNCTION mark_entrada(p_ingresso_id TEXT, p_pwd_hash TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_pwd_hash <> '61681c268936f5241e321e2bdacd6748849b9dab35cab8397fb77d0ebe2d2414' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  UPDATE registrations
  SET entrada_at = NOW()
  WHERE upper(ingresso_id) = upper(p_ingresso_id)
    AND entrada_at IS NULL;
END;
$$;

-- 3. Contador de presença para o dashboard da portaria
CREATE OR REPLACE FUNCTION portaria_count(p_evento_id TEXT, p_pwd_hash TEXT)
RETURNS TABLE (total BIGINT, entraram BIGINT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_pwd_hash <> '61681c268936f5241e321e2bdacd6748849b9dab35cab8397fb77d0ebe2d2414' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  RETURN QUERY
    SELECT
      COUNT(*)                                    AS total,
      COUNT(*) FILTER (WHERE entrada_at IS NOT NULL) AS entraram
    FROM registrations
    WHERE evento_id = p_evento_id;
END;
$$;

GRANT EXECUTE ON FUNCTION lookup_by_ingresso_id TO anon;
GRANT EXECUTE ON FUNCTION mark_entrada          TO anon;
GRANT EXECUTE ON FUNCTION portaria_count        TO anon;
