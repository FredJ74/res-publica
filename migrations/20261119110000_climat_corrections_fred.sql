-- MALADIES ET CLIMAT — corrections demandées par Fred le 19/11/2026 (GAME-DESIGN-MALADIES-CLIMAT.md § 11) :
-- • orages : une fois par trimestre et par ville avec propagation dans TOUS les pays, Sovarka comprise (plus « une fois par
--   mois ») ; l'orage déjà annoncé à Novomirsk le 21/11 devient l'orage du trimestre de Novomirsk, Starovka et Krasnov
--   suivent à 1 ou 2 jours d'intervalle ; les autres orages mensuels, pas encore annoncés, sont annulés ;
-- • plats contaminés (moteur historique : tournées, dîners) : UN SEUL jet pour la tablée ; s'il touche, l'acheteur et ses
--   invités joueurs tombent malades ensemble ;
-- • furet renifleur : 150 au lieu de 250 (réglable par le MJ).
BEGIN;

UPDATE public.climat_parametres SET frequence = 'trimestre_propage', par_periode = 1, delai_min = 1, delai_max = 2
 WHERE type = 'orage' AND pays = 'soviet';
UPDATE public.climat_evenements SET annule = true
 WHERE type = 'orage' AND pays = 'soviet' AND origine = 'calendrier' AND alerte_le IS NULL AND NOT annule AND debut > now();
-- L'orage déjà annoncé (Novomirsk, 21/11) ouvre la propagation du trimestre ; les deux autres villes suivent.
DO $$
DECLARE e public.climat_evenements; v_villes text[]; v_jour date; v_ville text;
BEGIN
  SELECT * INTO e FROM public.climat_evenements
   WHERE type = 'orage' AND pays = 'soviet' AND origine = 'calendrier' AND NOT annule AND alerte_le IS NOT NULL
     AND periode ~ '^\d{4}-\d{2}$' ORDER BY debut LIMIT 1;
  IF e.id IS NULL THEN RETURN; END IF;
  UPDATE public.climat_evenements SET periode = to_char(e.debut AT TIME ZONE 'Europe/Paris', 'YYYY') || '-T'
         || extract(quarter FROM e.debut AT TIME ZONE 'Europe/Paris')::text WHERE id = e.id;
  SELECT array_agg(x ORDER BY random()) INTO v_villes FROM unnest(public.climat_villes_interne('soviet')) x WHERE x <> e.ville;
  v_jour := (e.debut AT TIME ZONE 'Europe/Paris')::date;
  FOREACH v_ville IN ARRAY v_villes LOOP
    v_jour := v_jour + 1 + floor(random() * 2)::integer;
    PERFORM public.climat_creer_interne('orage', 'soviet', v_ville, v_jour,
      to_char(e.debut AT TIME ZONE 'Europe/Paris', 'YYYY') || '-T' || extract(quarter FROM e.debut AT TIME ZONE 'Europe/Paris')::text, 'calendrier');
  END LOOP;
END $$;
SELECT public.climat_planifier_interne();

UPDATE public.aliments_parametres SET valeur = 150 WHERE cle = 'prix_furet';

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Un seul jet par service ; le résultat est laissé à l'appelant (tournée, dîner) pour ses invités.
SELECT pg_temp.rp_raccorder('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure,
  $a$  IF v_contamines > 0 THEN -- aliments_plats_tirage
    PERFORM public.maladie_tirer_interne(regexp_replace(p_acteur, '^pj:', ''), 'intoxication', public.maladie_risque_interne('intoxication', 'plat_avarie'), 'plat_avarie');
  END IF;$a$,
  $b$  PERFORM set_config('rp.plat_contamine', '0', true); -- aliments_plats_tablee_v1
  IF v_contamines > 0 AND random() * 100 < public.maladie_risque_interne('intoxication', 'plat_avarie') THEN -- aliments_plats_tirage
    PERFORM public.maladie_contracter_interne(regexp_replace(p_acteur, '^pj:', ''), 'intoxication', 'plat_avarie');
    PERFORM set_config('rp.plat_contamine', '1', true);
  END IF;$b$,
  'aliments_plats_tablee_v1');
SELECT pg_temp.rp_raccorder('public.tournee_cloturer_boire(text)'::regprocedure,
  $a$PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE$a$,
  $b$IF current_setting('rp.plat_contamine', true) = '1' THEN -- aliments_plats_tablee_v1
     PERFORM public.maladie_contracter_interne(x, 'intoxication', 'plat_avarie') FROM unnest(v_participants) x;
   END IF;
   PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE$b$,
  'aliments_plats_tablee_v1');
SELECT pg_temp.rp_raccorder('public.restaurant_diner_servir(bigint)'::regprocedure,
  $a$    IF public.boisson_alcoolisee_interne('champagne_luthecia') THEN -- maladies_boissons_v1$a$,
  $b$    IF current_setting('rp.plat_contamine', true) = '1' AND NOT i.invite_pnj THEN -- aliments_plats_tablee_v1
      PERFORM public.maladie_contracter_interne(i.invite, 'intoxication', 'plat_avarie'); END IF;
    IF public.boisson_alcoolisee_interne('champagne_luthecia') THEN -- maladies_boissons_v1$b$,
  'aliments_plats_tablee_v1');
SELECT pg_temp.rp_raccorder('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  $a$    IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1$a$,
  $b$    IF current_setting('rp.plat_contamine', true) = '1' AND NOT i.invite_pnj THEN -- aliments_plats_tablee_v1
      PERFORM public.maladie_contracter_interne(i.invite, 'intoxication', 'plat_avarie'); END IF;
    IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1$b$,
  'aliments_plats_tablee_v1');

DO $$ BEGIN
  IF (SELECT frequence FROM public.climat_parametres WHERE type = 'orage' AND pays = 'soviet') <> 'trimestre_propage'
     OR (SELECT valeur FROM public.aliments_parametres WHERE cle = 'prix_furet') <> 150
     OR position('aliments_plats_tablee_v1' IN pg_get_functiondef('public.tournee_cloturer_boire(text)'::regprocedure)) = 0
     OR position('aliments_plats_tablee_v1' IN pg_get_functiondef('public.diner_commerce_servir_interne(text,bigint)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'corrections du 19/11 : controle structurel en echec'; END IF;
END $$;

COMMIT;
