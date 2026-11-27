-- Mission du 27/11/2026 (soir, Claude), étape 4 — « Demander le transfert d'un détenu » entre Républia et Sovarka.
-- Décision de Fred du 27/11/2026 : le voyage entre empires existe entre Républia et Sovarka (transport_effectuer : avion
-- depuis la zone d'embarquement après la douane, ou bateau depuis le quai d'un port, vers la capitale de l'autre pays).
-- L'ambassadeur demande qu'un compatriote détenu dans le pays hôte soit transféré dans une prison de son pays d'origine ;
-- le ministre des Affaires étrangères du pays hôte (et non celui de la Justice) accepte ou refuse ; en cas d'accord, le
-- détenu est transféré et purge chez lui le reste de sa peine. Demande, accord et refus au courrier des deux.
-- L'ordre reste grisé pour les pays qui n'ouvrent pas au lancement (El Estado, Al-Khalija) : refus « pays_non_ouvert ».
--
-- Choix techniques :
--   • Compatriote = personnage_nationalite(détenu) = empire de l'ambassade ; détenu = detention_active dans le pays hôte.
--   • Prison d'arrivée : la prison de la capitale du pays d'origine (commissariat › prison), comme detention_ouvrir_interne.
--   • Les jours de détention sont comptés sur le jour du personnage (detention_ouvrir_interne) : jour_fin est conservé,
--     le reste de la peine est donc purgé à l'identique, sans un jour de plus ni de moins.
--   • Refusés : détention au QHS, au goulag ou en salle d'interrogatoire du Renseignement (régimes particuliers).
--   • Une seule demande en attente par détenu ; une demande devient caduque si le détenu est libéré entre-temps.
--
-- Contrôles en lecture après application :
--   SELECT position('transfert_detenu_v1' in pg_get_functiondef('public.transfert_detenu_decider(bigint,text)'::regprocedure)) > 0; -- vrai
--   SELECT pa, cost FROM public.ordres_couts WHERE fn = 'demander_transfert_detenu';                                 -- 1 | 0
BEGIN;

CREATE TABLE IF NOT EXISTS public.transferts_detenus (
  id bigserial PRIMARY KEY,
  empire text NOT NULL,
  pays_hote text NOT NULL,
  detenu text NOT NULL,
  ambassadeur text NOT NULL,
  detention_id text NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'accepte', 'refuse', 'caduque')),
  decideur text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  decide_le timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS transferts_detenus_un_en_attente ON public.transferts_detenus (detenu) WHERE statut = 'en_attente';
ALTER TABLE public.transferts_detenus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.transferts_detenus FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.transferts_detenus_id_seq FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'demander_transfert_detenu', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'demander_transfert_detenu');
UPDATE public.ordres_couts SET pa = 1, cost = 0 WHERE fn = 'demander_transfert_detenu';

CREATE OR REPLACE FUNCTION public.transfert_detenu_pays_ouverts_interne(p_empire text, p_hote text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_empire IN ('republic', 'soviet') AND p_hote IN ('republic', 'soviet') AND p_empire <> p_hote
$$;
REVOKE ALL ON FUNCTION public.transfert_detenu_pays_ouverts_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Le détenu peut-il être transféré ? NULL si oui, sinon la raison du refus.
CREATE OR REPLACE FUNCTION public.transfert_detenu_refus_interne(p_detenu text, p_empire text, p_hote text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_det record; v_emp jsonb;
BEGIN
  IF public.personnage_nationalite(p_detenu) IS DISTINCT FROM p_empire THEN RETURN 'pas_compatriote'; END IF;
  SELECT * INTO v_det FROM public.detention_active(p_detenu);
  IF v_det.id IS NULL OR v_det.country IS DISTINCT FROM p_hote THEN RETURN 'pas_detenu_ici'; END IF;
  SELECT est_emprisonne INTO v_emp FROM public.personnages_donnees WHERE name = p_detenu;
  IF v_det.qhs OR v_det.city = 'qhs' OR coalesce(v_emp ? 'interrogatoire', false)
     OR EXISTS (SELECT 1 FROM public.sovarka_goulag_registre g WHERE g.detention_id = v_det.id) THEN
    RETURN 'regime_particulier'; END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_refus_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- Ministres des Affaires étrangères (PJ) d'un pays.
CREATE OR REPLACE FUNCTION public.transfert_detenu_mae_interne(p_pays text)
RETURNS SETOF text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p.name FROM public.personnages_donnees p
   WHERE p.poste->>'id' = 'min_ae' AND coalesce(public.poste_pays_de(p.name), p.country) = p_pays
$$;
REVOKE ALL ON FUNCTION public.transfert_detenu_mae_interne(text) FROM PUBLIC, anon, authenticated;

-- Ambassadeur : ses compatriotes détenus dans le pays hôte, et ses demandes récentes.
CREATE OR REPLACE FUNCTION public.transfert_detenu_detenus(p_empire text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m jsonb; v_hote text;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_hote := m ->> 'hote';
  IF NOT public.transfert_detenu_pays_ouverts_interne(p_empire, v_hote) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_ouvert'); END IF;
  RETURN jsonb_build_object('ok', true, 'hote', v_hote,
    'detenus', coalesce((SELECT jsonb_agg(jsonb_build_object('nom', d.nom, 'raison', d.raison, 'jour_fin', d.jour_fin,
        'refus', public.transfert_detenu_refus_interne(d.nom, p_empire, v_hote),
        'en_attente', EXISTS (SELECT 1 FROM public.transferts_detenus t WHERE t.detenu = d.nom AND t.statut = 'en_attente')) ORDER BY d.nom)
      FROM public.detentions d
     WHERE d.country = v_hote AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
       AND (SELECT a.id FROM public.detention_active(d.nom) a) = d.id
       AND public.personnage_nationalite(d.nom) = p_empire), '[]'::jsonb),
    'demandes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', t.id, 'detenu', t.detenu, 'statut', t.statut,
        'decideur', t.decideur, 'le', t.cree_le) ORDER BY t.cree_le DESC)
      FROM (SELECT * FROM public.transferts_detenus WHERE empire = p_empire AND pays_hote = v_hote
             ORDER BY cree_le DESC LIMIT 15) t), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_detenus(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfert_detenu_detenus(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.transfert_detenu_demander(p_empire text, p_detenu text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m jsonb; v_moi text; v_hote text; v_refus text; v_det record; v_paie jsonb; v_id bigint; v_mae text; v_nb integer := 0;
  v_txt text;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_moi := m ->> 'moi'; v_hote := m ->> 'hote';
  IF NOT public.transfert_detenu_pays_ouverts_interne(p_empire, v_hote) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_ouvert'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = btrim(p_detenu) FOR UPDATE;
  v_refus := public.transfert_detenu_refus_interne(btrim(p_detenu), p_empire, v_hote);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', v_refus); END IF;
  IF EXISTS (SELECT 1 FROM public.transferts_detenus WHERE detenu = btrim(p_detenu) AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_deja_en_cours'); END IF;
  SELECT * INTO v_det FROM public.detention_active(btrim(p_detenu));
  v_paie := public.payer_ordre(v_moi, 'demander_transfert_detenu', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.transferts_detenus (empire, pays_hote, detenu, ambassadeur, detention_id)
  VALUES (p_empire, v_hote, btrim(p_detenu), v_moi, v_det.id) RETURNING id INTO v_id;
  v_txt := 'L''ambassadeur ' || v_moi || ' (' || public.empire_nom_interne(p_empire) || ') demande le transfert de son compatriote '
    || btrim(p_detenu) || ', détenu en ' || public.empire_nom_interne(v_hote) || ', vers une prison de son pays d''origine, où il purgerait '
    || 'le reste de sa peine.';
  FOR v_mae IN SELECT public.transfert_detenu_mae_interne(v_hote) LOOP
    PERFORM public.mail_systeme_poser_interne('Ministère des Affaires étrangères', v_mae, 'Demande de transfert d''un détenu : ' || btrim(p_detenu),
      v_txt || ' Votre décision : Bureau du ministre des Affaires étrangères, « Demandes de transfert de détenus ».');
    v_nb := v_nb + 1;
  END LOOP;
  PERFORM public.mail_systeme_poser_interne('Ministère des Affaires étrangères', v_moi, 'Demande de transfert envoyée : ' || btrim(p_detenu),
    v_txt || ' Le ministre des Affaires étrangères de ' || public.empire_nom_interne(v_hote) || ' décidera.');
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ministres', v_nb, 'paie', v_paie);
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_demander(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfert_detenu_demander(text, text) TO authenticated;

-- Ministre des Affaires étrangères du pays hôte : les demandes reçues.
CREATE OR REPLACE FUNCTION public.transfert_detenu_demandes()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text; v_poste text; v_pays text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_ae' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_min_ae'); END IF;
  RETURN jsonb_build_object('ok', true, 'demandes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', t.id, 'detenu', t.detenu,
      'empire', t.empire, 'ambassadeur', t.ambassadeur, 'statut', t.statut, 'decideur', t.decideur, 'le', t.cree_le)
      ORDER BY (t.statut = 'en_attente') DESC, t.cree_le DESC)
    FROM (SELECT * FROM public.transferts_detenus WHERE pays_hote = v_pays
           AND (statut = 'en_attente' OR cree_le > now() - interval '14 days') ORDER BY cree_le DESC LIMIT 30) t), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_demandes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfert_detenu_demandes() TO authenticated;

CREATE OR REPLACE FUNCTION public.transfert_detenu_decider(p_id bigint, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
-- transfert_detenu_v1 : accord ou refus du ministre des Affaires étrangères du pays hôte (Fred, 27/11/2026).
DECLARE v_nom text; v_poste text; v_pays text; t public.transferts_detenus%ROWTYPE; v_refus text; v_det record; v_txt text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_ae' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_min_ae'); END IF;
  IF p_decision NOT IN ('accepter', 'refuser') THEN RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide'); END IF;
  SELECT * INTO t FROM public.transferts_detenus WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR t.pays_hote IS DISTINCT FROM v_pays THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable'); END IF;
  IF t.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_deja_traitee', 'statut', t.statut); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = t.detenu FOR UPDATE;
  IF p_decision = 'refuser' THEN
    UPDATE public.transferts_detenus SET statut = 'refuse', decideur = v_nom, decide_le = now() WHERE id = p_id;
    v_txt := v_nom || ', ministre des Affaires étrangères de ' || public.empire_nom_interne(t.pays_hote)
      || ', refuse le transfert de ' || t.detenu || ' demandé par l''ambassadeur ' || t.ambassadeur || '. Le détenu reste dans sa prison.';
    PERFORM public.mail_systeme_poser_interne('Ministère des Affaires étrangères', t.ambassadeur, 'Transfert refusé : ' || t.detenu, v_txt);
    PERFORM public.mail_systeme_poser_interne('Ministère des Affaires étrangères', v_nom, 'Transfert refusé : ' || t.detenu, v_txt);
    RETURN jsonb_build_object('ok', true, 'statut', 'refuse');
  END IF;
  v_refus := public.transfert_detenu_refus_interne(t.detenu, t.empire, t.pays_hote);
  SELECT * INTO v_det FROM public.detention_active(t.detenu);
  IF v_refus IS NOT NULL OR v_det.id IS DISTINCT FROM t.detention_id THEN
    UPDATE public.transferts_detenus SET statut = 'caduque', decideur = v_nom, decide_le = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_caduque', 'detail', coalesce(v_refus, 'detention_changee'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = t.empire AND ville = 'capitale'
                   AND batiment = 'commissariat' AND pieces ? 'prison') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prison_non_referencee'); END IF;
  -- Le reste de la peine est purgé chez lui : jour_fin (jour du personnage) inchangé.
  UPDATE public.detentions
     SET country = t.empire, city = 'capitale',
         motifs = (CASE WHEN jsonb_typeof(motifs) = 'array' THEN motifs ELSE '[]'::jsonb END) || jsonb_build_array(jsonb_build_object(
           'source', 'transfert_international', 'depuis', t.pays_hote, 'demande', t.id, 'ambassadeur', t.ambassadeur, 'accorde_par', v_nom,
           'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
   WHERE id = v_det.id;
  UPDATE public.personnages_donnees
     SET est_emprisonne = est_emprisonne || jsonb_build_object('city', 'capitale', 'country', t.empire, 'transfertDepuis', t.pays_hote)
                          - 'retourVille',
         country = t.empire, current_city = 'capitale', current_building = 'commissariat', current_room = 'prison',
         current_street = NULL, updated_at = clock_timestamp()
   WHERE name = t.detenu;
  UPDATE public.transferts_detenus SET statut = 'accepte', decideur = v_nom, decide_le = now() WHERE id = p_id;
  v_txt := v_nom || ', ministre des Affaires étrangères de ' || public.empire_nom_interne(t.pays_hote) || ', accepte le transfert de '
    || t.detenu || ' demandé par l''ambassadeur ' || t.ambassadeur || '. Le détenu est transféré à la prison de la capitale de '
    || public.empire_nom_interne(t.empire) || ', où il purge le reste de sa peine.';
  PERFORM public.mail_systeme_poser_interne('Ministère des Affaires étrangères', t.ambassadeur, 'Transfert accepté : ' || t.detenu, v_txt);
  PERFORM public.mail_systeme_poser_interne('Ministère des Affaires étrangères', v_nom, 'Transfert accepté : ' || t.detenu, v_txt);
  PERFORM public.mail_systeme_poser_interne('Administration pénitentiaire', t.detenu, 'Vous êtes transféré dans votre pays',
    'À la demande de l''ambassadeur ' || t.ambassadeur || ', vous êtes transféré à la prison de la capitale de '
    || public.empire_nom_interne(t.empire) || '. Vous y purgez le reste de votre peine, sans un jour de plus.');
  RETURN jsonb_build_object('ok', true, 'statut', 'accepte', 'detenu', t.detenu);
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_decider(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfert_detenu_decider(bigint, text) TO authenticated;

COMMIT;
