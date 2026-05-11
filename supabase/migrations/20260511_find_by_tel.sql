-- Retorna o nome de quem já tem este telefone cadastrado (normaliza dígitos)
CREATE OR REPLACE FUNCTION find_by_tel(p_tel TEXT, p_evento_id TEXT)
RETURNS TEXT
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT nome FROM registrations
  WHERE regexp_replace(COALESCE(tel,''), '\D', '', 'g') = regexp_replace(p_tel, '\D', '', 'g')
    AND evento_id = p_evento_id
    AND length(regexp_replace(COALESCE(tel,''), '\D', '', 'g')) >= 8
  LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION find_by_tel TO anon;
