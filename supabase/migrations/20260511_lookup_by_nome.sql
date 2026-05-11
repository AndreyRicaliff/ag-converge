-- AG Converge — busca por nome na portaria (fallback quando participante não tem QR)

CREATE OR REPLACE FUNCTION lookup_by_nome(p_nome TEXT, p_evento_id TEXT, p_pwd_hash TEXT)
RETURNS TABLE (
  ingresso_id TEXT, grupo_id TEXT, evento_id TEXT,
  nome TEXT, email TEXT, tel TEXT, empresa TEXT, cargo TEXT,
  titular BOOLEAN, titular_nome TEXT,
  doacao NUMERIC, ingresso_baixado BOOLEAN,
  entrada_at TIMESTAMPTZ, inscricao_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_pwd_hash <> '61681c268936f5241e321e2bdacd6748849b9dab35cab8397fb77d0ebe2d2414' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  RETURN QUERY
    SELECT r.ingresso_id, r.grupo_id, r.evento_id, r.nome, r.email, r.tel,
           r.empresa, r.cargo, r.titular, r.titular_nome, r.doacao,
           r.ingresso_baixado, r.entrada_at, r.inscricao_at
    FROM registrations r
    WHERE r.evento_id = p_evento_id
      AND r.nome ILIKE '%' || p_nome || '%'
    ORDER BY r.entrada_at NULLS FIRST, r.nome
    LIMIT 10;
END;
$$;

GRANT EXECUTE ON FUNCTION lookup_by_nome TO anon;
