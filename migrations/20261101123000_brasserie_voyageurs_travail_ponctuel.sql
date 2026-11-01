-- Brasserie des Voyageurs (Montrouge): production ponctuelle par PJ present sur place.
-- Garde serveur : cas strictement limite au commerce PNJ de ce batiment,
-- l'acteur doit toujours etre le PJ authentifie (exiger_acteur dans commerce_produire).
-- Toutes les autres autorisations proprietaire/salarie conservent leur regle commune.
-- Aucune modification de personnages, stocks ou entreprises.
CREATE OR REPLACE FUNCTION public.commerce_production_autorisee(p_data jsonb, p_acteur text)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT coalesce(p_acteur,'')<>'' AND (
  regexp_replace(coalesce(p_data->>'proprietaire',''),'^pj:','')=regexp_replace(p_acteur,'^pj:','')
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_data->'salaries')='array' THEN p_data->'salaries' ELSE '[]'::jsonb END) s
    WHERE s->'actif'='true'::jsonb AND regexp_replace(s->>'ref','^pj:','')=regexp_replace(p_acteur,'^pj:',''))
  OR (
    p_data->>'country'='republic'
    AND p_data->>'city'='ville_b'
    AND p_data->>'buildingId'='brasserie-voyageurs-montrouge'
    AND p_data->>'proprietaire'='PNJ'
    AND EXISTS (
      SELECT 1 FROM public.personnages_donnees d
      WHERE d.name=p_acteur
        AND d.country='republic'
        AND d.current_city='ville_b'
        AND d.current_building='brasserie-voyageurs-montrouge'
    )
  )
 );
$function$;

-- La signature et le mode d'acces ne changent pas ; l'ancienne autorite
-- reste en place pour toutes les entreprises hors brasserie ciblée.
