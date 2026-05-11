-- AG Converge — contagem pública de inscrições (sem auth)
CREATE OR REPLACE FUNCTION count_registrations(p_evento_id TEXT)
RETURNS TABLE (total BIGINT)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COUNT(*) AS total
  FROM registrations
  WHERE evento_id = p_evento_id;
$$;

GRANT EXECUTE ON FUNCTION count_registrations TO anon;
