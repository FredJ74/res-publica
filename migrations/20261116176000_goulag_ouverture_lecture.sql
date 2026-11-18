-- Goulag de Sovarka : lecture de l'ouverture pour le navigateur (décision de Fred du 17/11/2026).
-- Le client du goulag reste entièrement caché tant que cette fonction ne rend pas `true`.
-- Lecture seule ; ne modifie rien. Le verrou CHECK (active IS FALSE) reste en place :
-- tant qu'il existe, cette fonction rend toujours false.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_ouvert()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT c.active IS TRUE FROM public.sovarka_goulag_configuration c WHERE c.singleton), false);
$$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_ouvert() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_ouvert() TO authenticated, service_role;
