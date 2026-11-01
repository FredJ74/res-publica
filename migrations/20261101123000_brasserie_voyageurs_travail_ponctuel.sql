-- Règle générale validée : tout PJ physiquement présent dans un commerce peut produire,
-- en plus du propriétaire et des salariés actifs (appelée aussi par fonds_reference_produire_lots).
-- Ni propriété ni contrat salarié exigés. Les contrôles de matières, caisse,
-- PA, recette autorisée et stock maximum restent dans commerce_produire.
-- commerce_produire impose exiger_acteur(p_acteur) : pas d'usurpation.
-- Aucune donnée joueur/entreprise modifiée par cette migration.
CREATE OR REPLACE FUNCTION public.commerce_production_autorisee(p_data jsonb, p_acteur text)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT coalesce(p_acteur,'')<>'' AND (
  -- droits antérieurs conservés (boutiques de PJ et armurerie n'ont pas d'adresse)
  regexp_replace(coalesce(p_data->>'proprietaire',''),'^pj:','')=regexp_replace(p_acteur,'^pj:','')
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_data->'salaries')='array' THEN p_data->'salaries' ELSE '[]'::jsonb END) s
    WHERE s->'actif'='true'::jsonb AND regexp_replace(s->>'ref','^pj:','')=regexp_replace(p_acteur,'^pj:',''))
  OR (coalesce(p_data->>'buildingId','')<>''
   AND EXISTS (
     SELECT 1 FROM public.personnages_donnees d
      WHERE d.name = p_acteur
        AND d.country = p_data->>'country'
        AND d.current_city = p_data->>'city'
        AND d.current_building = p_data->>'buildingId'
        AND (nullif(p_data->>'roomId','') IS NULL
             OR d.current_room = p_data->>'roomId')
   )));
$function$;
