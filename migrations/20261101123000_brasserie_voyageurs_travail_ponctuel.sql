-- Règle générale validée : tout PJ physiquement présent dans un commerce peut produire.
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
 SELECT coalesce(p_acteur,'')<>''
   AND coalesce(p_data->>'buildingId','')<>''
   AND EXISTS (
     SELECT 1 FROM public.personnages_donnees d
      WHERE d.name = p_acteur
        AND d.country = p_data->>'country'
        AND d.current_city = p_data->>'city'
        AND d.current_building = p_data->>'buildingId'
        AND (nullif(p_data->>'roomId','') IS NULL
             OR d.current_room = p_data->>'roomId')
   );
$function$;
