-- Consommation Supabase #55/#60 (04/11/2026) : empreinte des portraits pour le cache du navigateur.
-- L'annuaire (sbListPersonnages, ~40 appelants) redescendait tous les portraits à chaque lecture
-- (≈ 500 Ko pour 12 fiches). Le navigateur garde désormais les portraits en cache et ne relit que
-- ceux dont l'empreinte a changé. Lecture seule, SECURITY INVOKER : passe par la vue personnages,
-- avec les mêmes droits que la lecture actuelle des portraits.
CREATE OR REPLACE FUNCTION public.portraits_empreintes()
RETURNS TABLE(name text, empreinte text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p.name, md5(p.photo_url) FROM public.personnages p
   WHERE coalesce(p.photo_url, '') <> '';
$$;
REVOKE ALL ON FUNCTION public.portraits_empreintes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.portraits_empreintes() TO authenticated;
