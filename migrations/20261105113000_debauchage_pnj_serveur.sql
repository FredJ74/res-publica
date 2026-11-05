-- Débauchage d'un PNJ employé par un autre joueur : paiement et jet au serveur
-- (Claude, 05/11/2026, chantier « jets de l'écran »).
--
-- DÉFAUT CORRIGÉ (grave). pnj_employe_debaucher retirait un PNJ de la fiche de n'importe quel joueur,
-- sans paiement ni jet : le prix et le dé n'existaient que dans l'écran (confirmerDebauchage). Un
-- appel direct vidait le personnel d'un autre joueur, gratuitement et à coup sûr.
--
-- Désormais pnj_debaucher fait tout dans une seule transaction : vérifie que le PNJ est encore chez
-- son employeur (ligne verrouillée), prélève la somme (liquide puis Banque nationale), tire le dé, et
-- seulement en cas de réussite retire le PNJ à l'ancien employeur. pnj_employe_debaucher n'est plus
-- appelable par un joueur.
-- Règles reprises telles quelles de l'écran (aucune valeur nouvelle) : 100 minimum ;
-- taux = (100 − loyauté)/2 + DUP + min(30, somme/100), borné à [5, 85]. La loyauté du métier vient de
-- PNJ_STATS_PAR_JOB (data.js), que le serveur ne recopie pas : l'écran la déclare, bornée ici à
-- [20, 100] (20 = la plus basse du jeu), même convention que les caractéristiques de PNJ de crime_voler.

CREATE OR REPLACE FUNCTION public.pnj_debaucher(p_ancien_proprietaire text, p_pnj_nom text, p_job text, p_montant integer, p_loyaute integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_liste jsonb; v_dispo numeric; v_dup numeric; v_loy integer; v_taux integer; v_roll integer;
  v_pris numeric; v_retrait jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_pnj_nom), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pnj_invalide'); END IF;
  IF coalesce(btrim(p_ancien_proprietaire), '') = '' OR p_ancien_proprietaire = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'employeur_invalide'); END IF;
  IF coalesce(p_montant, 0) < 100 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_insuffisant'); END IF;

  SELECT CASE WHEN p_job = 'escort' THEN escort_active ELSE employes END INTO v_liste
    FROM public.personnages_donnees WHERE name = p_ancien_proprietaire FOR UPDATE;
  IF NOT FOUND OR jsonb_typeof(v_liste) <> 'array'
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_liste) e WHERE e ->> 'nom' = p_pnj_nom) THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'deja_parti', true); END IF;

  SELECT coalesce(d.liquide, 0) + coalesce((SELECT sum(greatest(solde, 0)) FROM public.comptes_bancaires
                                             WHERE personnage = v_moi AND banque = 'nationale'), 0),
         coalesce((d.stats ->> 'DUP')::numeric, 8)
    INTO v_dispo, v_dup FROM public.personnages_donnees d WHERE d.name = v_moi FOR UPDATE;
  IF v_dispo < p_montant THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'disponible', v_dispo); END IF;
  v_pris := public.argent_debiter_interne(v_moi, p_montant, 'liquide_puis_nationale');
  IF v_pris < p_montant THEN RAISE EXCEPTION 'debauchage: prelevement partiel (% sur %)', v_pris, p_montant; END IF;

  v_loy := greatest(20, least(100, coalesce(p_loyaute, 40)));
  v_taux := greatest(5, least(85, round((100 - v_loy) / 2.0 + v_dup + least(30, floor(p_montant / 100.0)))::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    v_retrait := public.pnj_employe_debaucher(p_ancien_proprietaire, p_pnj_nom, p_job);
    IF coalesce((v_retrait ->> 'retire')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'debauchage: retrait non confirme %', v_retrait; END IF;
  END IF;
  RETURN (SELECT jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'taux', v_taux, 'jet', v_roll,
                 'montant', p_montant, 'pa', pa, 'liquide', liquide, 'arg', arg)
            FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

REVOKE ALL ON FUNCTION public.pnj_debaucher(text, text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_debaucher(text, text, text, integer, integer) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.pnj_employe_debaucher(text, text, text) FROM PUBLIC, anon, authenticated;
