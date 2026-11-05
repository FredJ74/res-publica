-- Correction transport intra-empire : terminaux identifiés par pays ET ville.
-- Deux villes peuvent réutiliser le même identifiant de bâtiment, leur géographie reste isolée.
DO $correctif$
DECLARE
  definition text;
  ancienne text := ' AND NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles autre WHERE autre.pays=p_pays AND autre.ville<>p_ville AND autre.batiment=navigation_lieux_regles.batiment)';
  nouvelle text := '';
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE batiment LIKE 'centre-multinodal-%'
    GROUP BY pays,ville HAVING count(*) > 1
  ) THEN RAISE EXCEPTION 'terminaux_ambigus_par_ville'; END IF;
  IF (SELECT count(*) FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville IN ('ville_a','ville_b')
      AND batiment='centre-multinodal-montrouge') <> 2
  THEN RAISE EXCEPTION 'sovarka_terminaux_inattendus'; END IF;
  SELECT pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure)
    INTO definition;
  IF position(ancienne IN definition)=0
     OR length(definition)-length(replace(definition,ancienne,'')) <> length(ancienne)
  THEN RAISE EXCEPTION 'transport_moteur_inattendu'; END IF;
  EXECUTE replace(definition,ancienne,nouvelle);
  IF position(ancienne IN pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure))>0
  THEN RAISE EXCEPTION 'transport_exclusion_persistante'; END IF;
END $correctif$;