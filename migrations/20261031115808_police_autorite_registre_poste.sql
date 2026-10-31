-- #219 : conserver l'autorité territoriale pendant un voyage international.
-- Registre existant, aucune attribution de poste ou modification de joueur.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.police_autorite_de_perimetre(text,text)'::regprocedure)
 NOT IN ('212ae9ffdb5918ff9544429df54d6759','a8264cb9089367ca697d4da247bc0271') THEN RAISE EXCEPTION 'police_autorite_vivante_non_examinee';END IF;
 IF EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.poste->>'id'='commissaire'
 AND NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=coalesce(d.country,'republic')
 AND a.poste_id='commissaire' AND a.city=d.poste->>'city' AND a.titulaire=d.name)
 AND NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.poste_id='commissaire' AND a.titulaire=d.name)) THEN
 RAISE EXCEPTION 'mandat_police_historique_a_reconcilier';END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.police_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ville text; v_bat text; v_nom text;
BEGIN
  IF p_perimetre IS NULL OR position(':' in p_perimetre) = 0 THEN RETURN NULL; END IF;
  v_ville := split_part(p_perimetre, ':', 1);
  v_bat   := split_part(p_perimetre, ':', 2);
  IF v_bat NOT IN ('commissariat','commissariat-local') THEN RETURN NULL; END IF;
  -- Le registre du poste fait autorité ; voyager ne transfère pas ce mandat.
  SELECT a.titulaire INTO v_nom FROM public.postes_attribues a
   JOIN public.personnages_donnees pd ON pd.name=a.titulaire
   WHERE a.country=p_pays AND a.poste_id='commissaire' AND a.city=v_ville
   ORDER BY a.id LIMIT 1;
  RETURN v_nom;
END; $function$;
