-- Bons d'Etat de Sovarka au guichet des mairies (Fred, 15/11/2026, tour de Starovka).
-- Plus de banques en Sovarka : presque tout l'argent y est liquide (salaires faibles, vie peu chere). Les bons
-- d'Etat (decision du 09/11, migration 20261110085000) se souscrivent desormais a la mairie, dans les trois villes :
-- Novomirsk (mairie-capitale) et Starovka / Krasnov (mairie). Seul le lieu change ; montants, taux, echeances,
-- remboursement et planche a billets sont inchanges.
BEGIN;

CREATE OR REPLACE FUNCTION public.sovarka_bon_etat_souscrire(p_requete text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; v_jour jsonb; v_pris numeric; v_tr jsonb; b public.sovarka_bons_etat;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:bon_etat:' || a, 0));
  SELECT * INTO b FROM public.sovarka_bons_etat WHERE requete = p_requete;
  IF FOUND THEN
    IF b.souscripteur <> a THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_etrangere'); END IF;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'montant', b.montant, 'taux', b.taux, 'echeance', b.echeance);
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF p.country IS DISTINCT FROM 'soviet' OR NOT (
       (p.current_city = 'capitale' AND p.current_building = 'mairie-capitale')
    OR (p.current_city IN ('ville_a', 'ville_b') AND p.current_building = 'mairie')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  v_pris := public.argent_debiter_interne(a, p_montant, 'liquide_puis_nationale');
  IF v_pris < p_montant THEN RAISE EXCEPTION USING MESSAGE = 'fonds_insuffisants', ERRCODE = 'P0001'; END IF;
  v_tr := public.fret_tresor_crediter_interne('soviet', p_montant);
  IF (v_tr->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'tresor_sovarka_refuse: %', v_tr; END IF;
  v_jour := public.sovarka_bons_etat_taux_interne();
  INSERT INTO public.sovarka_bons_etat (requete, souscripteur, montant, taux, indice_economie, ville, echeance)
  VALUES (p_requete, a, p_montant, (v_jour->>'taux')::numeric, (v_jour->>'indice')::numeric, p.current_city,
          public.sovarka_jour_paris() + 7)
  RETURNING * INTO b;
  RETURN jsonb_build_object('ok', true, 'montant', b.montant, 'taux', b.taux, 'echeance', b.echeance,
    'attendu', round(b.montant * (1 + b.taux / 100)),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = a),
    'arg', (SELECT arg FROM public.personnages WHERE name = a));
EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM = 'fonds_insuffisants' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  RAISE;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_bon_etat_souscrire(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_bon_etat_souscrire(text, integer) TO authenticated;

COMMIT;
