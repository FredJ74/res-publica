-- Banc annule du guide des baies (15/11/2026). A jouer dans une transaction, concatene derriere le corps de
-- migrations/20261115103000_guide_baies_lecture.sql (sans BEGIN/COMMIT) : essais sur Arnie, puis exception qui annule tout.
-- Resultat du 15/11 : sans guide pas_de_guide ; 12 -> 10 PA, +1 INT 24 h ; seconde lecture effet_deja_actif ; guide garde.
DO $banc$
DECLARE a text; v1 jsonb; v2 jsonb; v0 jsonb; pa0 int; pa1 int;
BEGIN
  SELECT name INTO a FROM public.personnages_donnees WHERE name ILIKE 'Arnie%' LIMIT 1;
  IF a IS NULL THEN RAISE EXCEPTION 'banc : Arnie introuvable'; END IF;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa,0), 10),
    effets_actifs = coalesce((SELECT jsonb_agg(e) FROM jsonb_array_elements(coalesce(effets_actifs,'[]'::jsonb)) e WHERE e->>'cle' <> 'guide_baies_int'), '[]'::jsonb)
   WHERE name = a;
  v0 := public.guide_baies_lire_interne(a);
  IF v0->>'raison' IS DISTINCT FROM 'pas_de_guide' THEN RAISE EXCEPTION 'banc : sans guide attendu pas_de_guide, recu %', v0; END IF;
  UPDATE public.personnages_donnees SET inventory = coalesce(inventory,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'id','guide_baies_krasnov_banc','type','guide_baies_krasnov','name','Guide des baies sauvages de Krasnov','familleProduitMarche','livre')) WHERE name = a;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = a;
  v1 := public.guide_baies_lire_interne(a);
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = a;
  v2 := public.guide_baies_lire_interne(a);
  RAISE EXCEPTION 'BANC_RESULTAT pa % -> %, lecture1 ok=% bonus=% , lecture2 raison=%, guide garde=%',
    pa0, pa1, v1->>'ok', v1->>'bonusInt', v2->>'raison',
    (SELECT count(*) FROM public.personnages_donnees p, jsonb_array_elements(p.inventory) o WHERE p.name = a AND o->>'type' = 'guide_baies_krasnov');
END $banc$;
