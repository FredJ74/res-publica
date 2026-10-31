-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029184923.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Rumeurs : organisations criminelles ciblables, composition privée.
-- Appliquer avant le frontend qui appelle rumeurs_organisations_cibles().
-- La fonction ne renvoie jamais chef/fondateur/membres/description/caisse.
CREATE OR REPLACE FUNCTION public.rumeurs_organisations_cibles()
RETURNS TABLE (id text, nom text, country text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT o.id, o.data::jsonb->>'nom', o.data::jsonb->>'country'
  FROM public.organisations AS o
  WHERE coalesce(o.data::jsonb->>'nom','') <> ''
    AND (o.data::jsonb->>'visible' = 'true'
         OR o.data::jsonb->>'type' = 'criminelle')
  ORDER BY o.data::jsonb->>'nom', o.id;
$$;
REVOKE ALL ON FUNCTION public.rumeurs_organisations_cibles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rumeurs_organisations_cibles() TO anon, authenticated, service_role;

-- Restreindre les lignes secretes aux membres du groupe, pas seulement aux ecrans.
-- Les autres organisations restent compatibles avec leur lecture existante.
DROP POLICY IF EXISTS organisations_lecture_publique ON public.organisations;
CREATE POLICY organisations_lecture_publique ON public.organisations
FOR SELECT TO anon, authenticated
USING (
  (coalesce(data::jsonb->>'visible','false') = 'true'
    AND coalesce(data::jsonb->>'type','') <> 'criminelle')
  OR (
    public.mon_personnage() IS NOT NULL
    AND (
      data::jsonb->>'chef' = public.mon_personnage()
      OR data::jsonb->>'fondateur' = public.mon_personnage()
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(data::jsonb->'membres') = 'array'
            THEN data::jsonb->'membres' ELSE '[]'::jsonb END
        ) AS membre(obj)
        WHERE membre.obj->>'nom' = public.mon_personnage()
      )
    )
  )
);
-- Les fonctions internes utilisant service_role continuent de contourner RLS.
