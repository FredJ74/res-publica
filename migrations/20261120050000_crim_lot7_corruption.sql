-- CRIMINALITÉ — LOT 7 : CORRUPTION (GAME-DESIGN-CRIMINALITE.md § 12 ; Fred, 18/11/2026, 22 h).
-- • Règle commune à toutes les corruptions de PNJ (crim_corrompre_pnj_interne, sur la résolution commune crim_resoudre_interne) :
--   face à face (visage découvert forcé, ni cachette ni masque), dissuasion #135 comptée UNE fois (dans la résolution commune),
--   pas de bonus de carrière criminelle. Réussite : −5 DIS et rumeur de corruption (trace existante), AUCUN jet de détection.
--   Échec critique = 2 % des échecs : dénonciation — corrupteur identifié, recherché, peine d'office (crim_identifier_interne,
--   barème crim_peine_jours_interne : 1 j en Républia), −15 moral. Échec ordinaire : aucune suite pénale.
--   Branchée sur : directeur et gardien du QHS, douanier, greffier (copie de dossier, faux casier), journaliste, armurier.
--   Le gardien du goulag (chantier de Codex) n'est pas touché.
-- • Directeur du QHS (crim_corrompre_directeur, ordre corrompre_fonct 3 PA / 1 500) : détenu au QHS ; réussite = peine restante
--   divisée par deux, une seule fois par détention ; échec = +1 jour (barème de la corruption, aucune durée en dur), 1 500 FR
--   confisqués au profit de la caisse du QHS (sinon du ministère de la Justice), plus aucune tentative jusqu'à la fin de la
--   détention. Taux : 30 + 2 par point de CHA au-dessus de 8 − (ISN − 45) / 3, bornes 5-75 (même formule que le gardien).
-- • Gardien de couloir (crim_corrompre_gardien, ordre corrompre_gardien 2 PA / 800) : évasion facilitée (+25 % à la prochaine
--   tentative, une seule), message ou objet passé à un joueur extérieur, protection (pas de torture jusqu'au prochain « Dormir ») ;
--   même taux ; échec = 800 FR confisqués (caisse du QHS), une tentative par jour.
-- • Douanier : le +20 « zone transport » ne vaut plus que dans une zone de transport ; échec = 300 FR au profit des douanes,
--   une tentative par jour après un échec ; règle commune (plus de détection après réussite).
-- • Supprimés : « Falsifier un procès-verbal », la route corrompre_police, les trois accélérations par corruption (permis,
--   rendez-vous notarial, chantier). Les anciennes RPC répondent par un refus propre (« ordre_supprime » / « ordre_remplace »).
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia) ──────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('corruption_reussite_dis', 5), ('corruption_echec_critique_part', 2),
  ('corruption_qhs_base', 30), ('corruption_qhs_cha', 2), ('corruption_qhs_isn_pivot', 45), ('corruption_qhs_isn_diviseur', 3),
  ('corruption_qhs_min', 5), ('corruption_qhs_max', 75), ('corruption_gardien_evasion', 25),
  ('douanier_zone_transport', 20), ('greffe_corruption_taux', 75), ('armurier_corruption_taux', 30)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

-- Tarifs retirés (« Falsifier un procès-verbal » et les trois accélérations) ; corrompre_fonct 3 PA / 1 500 reste (directeur).
DELETE FROM public.ordres_couts WHERE (fn, pa, cost) IN (('corrompre_fonct', 3, 500), ('corrompre_fonct#reussite', 0, 500),
  ('corrompre_chantier', 2, 1500), ('corrompre_fonctionnaire_permis', 2, 800), ('corrompre_rdv_notaire', 2, 800));

-- ── Services obtenus d'un gardien (et réductions du directeur), par détention ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crim_corruptions_qhs (
  id bigserial PRIMARY KEY,
  affaire bigint,
  nom text NOT NULL,
  detention text NOT NULL,
  pnj text NOT NULL,
  service text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(),
  consomme_le timestamptz
);
CREATE INDEX IF NOT EXISTS crim_corruptions_qhs_nom ON public.crim_corruptions_qhs (nom, detention);
ALTER TABLE public.crim_corruptions_qhs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_corruptions_qhs FROM anon, authenticated;

-- ── Règle commune ────────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_corrompre_pnj_interne(p_auteur text, p_acte text, p_taux numeric, p_params jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r jsonb; v_peine text := coalesce(p_params ->> 'acte_peine', p_acte); v_denonce boolean;
  v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
BEGIN
  -- Face à face : visage découvert forcé ; cible NULL (le PNJ acheté n'est ni victime ni plaignant) ; aucune détection.
  r := public.crim_resoudre_interne(p_acte, p_auteur, NULL, jsonb_build_object(
    'taux', p_taux, 'min', 0, 'max', 100, 'mode', 'decouvert', 'combat', false, 'detection', false,
    'remarque_echec', 0, 'decouvert_identifie', false, 'critique_identifie', true, 'critique_moral', true,
    'critique_echec_part', public.crim_param_interne('corruption_echec_critique_part', 2),
    'acte_peine_reussite', v_peine, 'acte_peine_echec', v_peine, 'type_recherche', 'delit', 'brouillard', false,
    'corruption', true, 'msg_reussite', '', 'msg_echec', '',
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END)
    || (coalesce(p_params, '{}'::jsonb) - 'acte_peine'));
  v_denonce := coalesce((r ->> 'echec_critique')::boolean, false);
  IF coalesce((r ->> 'reussi')::boolean, false) THEN
    PERFORM public.crime_dis_ajuster_interne(p_auteur, -public.crim_param_interne('corruption_reussite_dis', 5)::integer);
    PERFORM public.crime_trace_rumeur_interne(p_auteur, 'corruption', NULL);
  ELSIF v_denonce THEN
    PERFORM public.mail_systeme_poser_interne('Événement', p_auteur, 'Dénoncé(e) !',
      'La personne que vous tentiez d''acheter vous a dénoncé(e) à la police. Vous êtes recherché(e) et condamné(e) d''office à '
      || coalesce(r ->> 'peine_jours', '?') || ' jour(s) de prison.', v_date);
  END IF;
  RETURN r || jsonb_build_object('denonce', v_denonce,
    'dis', (SELECT resources -> 'dis' FROM public.personnages_donnees WHERE name = p_auteur));
END $$;

-- ── QHS : taux, état, directeur, gardien ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_corruption_qhs_taux_interne(p_cha numeric, p_isn numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(public.crim_param_interne('corruption_qhs_min', 5), least(public.crim_param_interne('corruption_qhs_max', 75),
    round(public.crim_param_interne('corruption_qhs_base', 30)
          + public.crim_param_interne('corruption_qhs_cha', 2) * greatest(0, coalesce(p_cha, 8) - 8)
          - (coalesce(p_isn, 30) - public.crim_param_interne('corruption_qhs_isn_pivot', 45)) / public.crim_param_interne('corruption_qhs_isn_diviseur', 3))))::integer;
$$;

CREATE OR REPLACE FUNCTION public.crim_corruption_qhs_etat_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_jour integer; v_isn numeric; v_reste integer; v_qhs boolean;
  v_aujourdhui date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT * INTO d FROM public.detention_active(p_nom);
  v_qhs := d.id IS NOT NULL AND d.qhs AND coalesce(d.country, '') <> 'soviet';  -- le goulag garde ses propres règles
  IF NOT v_qhs THEN RETURN jsonb_build_object('detenu_qhs', false); END IF;
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = p_nom;
  v_reste := greatest(0, coalesce(d.jour_fin, v_jour) - v_jour);
  v_isn := (SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes WHERE id = d.country || '_' || coalesce(d.city, 'capitale'));
  RETURN jsonb_build_object('detenu_qhs', true, 'detention', d.id, 'pays', d.country, 'ville', d.city, 'jour', v_jour,
    'jour_fin', d.jour_fin, 'reste', v_reste, 'gain_possible', floor(v_reste / 2.0)::integer, 'reduction_possible', floor(v_reste / 2.0) >= 1,
    'isn', v_isn, 'taux', public.crim_corruption_qhs_taux_interne(public.crim_stat_interne(p_nom, 'CHA', 8), v_isn),
    'directeur_tente', EXISTS (SELECT 1 FROM public.crim_affaires a WHERE a.acte = 'corrompre_fonct' AND a.auteur = p_nom
                                 AND a.details -> 'params' ->> 'detention' = d.id),
    'gardien_aujourdhui', EXISTS (SELECT 1 FROM public.crim_affaires a WHERE a.acte = 'corrompre_gardien' AND a.auteur = p_nom
                                    AND (a.cree_le AT TIME ZONE 'Europe/Paris')::date = v_aujourdhui),
    'evasion_active', EXISTS (SELECT 1 FROM public.crim_corruptions_qhs c WHERE c.nom = p_nom AND c.detention = d.id
                                AND c.service = 'evasion' AND c.consomme_le IS NULL),
    'protection_active', EXISTS (SELECT 1 FROM public.crim_corruptions_qhs c WHERE c.nom = p_nom AND c.service = 'protection'
                                   AND c.consomme_le IS NULL),
    'bonus_evasion', public.crim_param_interne('corruption_gardien_evasion', 25)::integer,
    'peine_echec_jours', public.crim_peine_jours_interne('corrompre_fonct', d.country));
END $$;

-- Lecture pour l'écran (aucune chance affichée : le taux reste côté serveur).
CREATE OR REPLACE FUNCTION public.crim_corruption_qhs_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true) || (public.crim_corruption_qhs_etat_interne(a) - 'taux' - 'isn');
END $$;

-- Argent confisqué : caisse du QHS du pays, sinon ministère de la Justice.
CREATE OR REPLACE FUNCTION public.crim_corruption_confisquer_interne(p_pays text, p_montant integer)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_caisse text := coalesce(p_pays, 'republic') || '_qhs-prison';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    v_caisse := coalesce(p_pays, 'republic') || '_gouvernement-min_just';
  END IF;
  PERFORM public.assemblee_crediter_caisse(v_caisse, p_montant);
  RETURN v_caisse;
END $$;

CREATE OR REPLACE FUNCTION public.crim_corrompre_directeur(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; e jsonb; v_paie jsonb; r jsonb; v_out jsonb;
  v_gain integer; v_fin integer; v_prol jsonb; v_caisse text; c_pa constant integer := 3; c_cout constant integer := 1500;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crim_corrompre_directeur', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  e := public.crim_corruption_qhs_etat_interne(a);
  IF NOT (e ->> 'detenu_qhs')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_qhs_requis'); END IF;
  IF (e ->> 'directeur_tente')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'directeur_deja_sollicite'); END IF;
  IF NOT (e ->> 'reduction_possible')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'peine_trop_courte'); END IF;
  v_paie := public.payer_ordre(a, 'corrompre_fonct', c_pa, c_cout);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  r := public.crim_corrompre_pnj_interne(a, 'corrompre_fonct', (e ->> 'taux')::numeric, jsonb_build_object(
    'min', public.crim_param_interne('corruption_qhs_min', 5), 'max', public.crim_param_interne('corruption_qhs_max', 75),
    'detention', e ->> 'detention', 'pnj', 'directeur_qhs', 'titre_echec', 'Corruption du directeur du QHS'));

  IF (r ->> 'reussi')::boolean THEN
    -- Peine restante divisée par deux (arrondi au jour inférieur pour la remise).
    -- (la remise est consignée dans crim_corruptions_qhs.details)
    UPDATE public.detentions SET jour_fin = jour_fin - floor(greatest(0, jour_fin - (e ->> 'jour')::integer) / 2.0)::integer
     WHERE id = e ->> 'detention'
     RETURNING jour_fin INTO v_fin;
    v_gain := (e ->> 'gain_possible')::integer;
    UPDATE public.personnages_donnees
       SET est_emprisonne = est_emprisonne || jsonb_build_object('jours', greatest(1, coalesce((est_emprisonne ->> 'jours')::integer, 0) - v_gain),
                                                                  'jourFin', v_fin)
     WHERE name = a AND jsonb_typeof(est_emprisonne) = 'object';
    INSERT INTO public.crim_corruptions_qhs (affaire, nom, detention, pnj, service, details, consomme_le)
    VALUES ((r ->> 'affaire')::bigint, a, e ->> 'detention', 'directeur', 'reduction', jsonb_build_object('gain', v_gain, 'jour_fin', v_fin), now());
    v_out := r || jsonb_build_object('gain', v_gain, 'jour_fin', v_fin);
  ELSE
    -- Échec : +1 jour (barème de la corruption), argent confisqué, plus aucune tentative pendant cette détention.
    v_prol := public.detention_prolonger_interne(a, jsonb_build_array(jsonb_build_object(
      'type', 'Tentative de corruption du directeur', 'acte', 'corrompre_fonct', 'jour_fait', (e ->> 'jour')::integer,
      'city', coalesce(e ->> 'ville', 'capitale'), 'jours', coalesce(public.crim_peine_jours_interne('corrompre_fonct', e ->> 'pays'), 1),
      'source', 'evenement_detention', 'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))), false);
    v_caisse := public.crim_corruption_confisquer_interne(e ->> 'pays', c_cout);
    v_out := r || jsonb_build_object('jours_ajoutes', (v_prol ->> 'jours_ajoutes')::integer, 'jour_fin', (v_prol ->> 'jour_fin')::integer,
                                     'proces', v_prol -> 'proces', 'confisque', c_cout, 'caisse', v_caisse);
  END IF;
  v_out := v_out || jsonb_build_object('ok', true) - 'jets';
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crim_corrompre_directeur', prm, v_out);
END $$;

CREATE OR REPLACE FUNCTION public.crim_corrompre_gardien(p_service text, p_destinataire text, p_texte text, p_index integer,
                                                         p_signature jsonb, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; e jsonb; v_paie jsonb; r jsonb; v_out jsonb; m record;
  v_dest text := nullif(btrim(coalesce(p_destinataire, '')), ''); v_texte text := btrim(coalesce(p_texte, '')); v_pos integer;
  v_don jsonb; v_caisse text; c_pa constant integer := 2; c_cout constant integer := 800;
  v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  prm := jsonb_build_object('service', p_service, 'destinataire', v_dest, 'texte', md5(v_texte), 'index', p_index, 'signature', p_signature);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crim_corrompre_gardien', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT inventory, quete_carriere INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  e := public.crim_corruption_qhs_etat_interne(a);
  IF NOT (e ->> 'detenu_qhs')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_qhs_requis'); END IF;
  IF (e ->> 'gardien_aujourdhui')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'une_tentative_par_jour'); END IF;
  IF p_service NOT IN ('evasion', 'message', 'objet', 'protection') THEN RETURN jsonb_build_object('ok', false, 'raison', 'service_inconnu'); END IF;
  IF (p_service = 'evasion' AND (e ->> 'evasion_active')::boolean) OR (p_service = 'protection' AND (e ->> 'protection_active')::boolean) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'service_deja_actif'); END IF;
  IF p_service IN ('message', 'objet') THEN
    IF v_dest IS NULL OR v_dest = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_dest) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
    IF (SELECT id FROM public.detention_active(v_dest)) IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_detenu'); END IF;
  END IF;
  IF p_service = 'message' AND (v_texte = '' OR length(v_texte) > 1000) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'message_invalide'); END IF;
  IF p_service = 'objet' THEN
    v_pos := public.inventaire_localiser(coalesce(m.inventory, '[]'::jsonb), p_index, p_signature);
    IF p_index IS NULL OR v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
    IF public.inventaire_objet_protege(m.quete_carriere, m.inventory -> v_pos) OR (m.inventory -> v_pos) ? 'porte_par' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_protege'); END IF;
  END IF;
  v_paie := public.payer_ordre(a, 'corrompre_gardien', c_pa, c_cout);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  r := public.crim_corrompre_pnj_interne(a, 'corrompre_gardien', (e ->> 'taux')::numeric, jsonb_build_object(
    'min', public.crim_param_interne('corruption_qhs_min', 5), 'max', public.crim_param_interne('corruption_qhs_max', 75),
    'detention', e ->> 'detention', 'pnj', 'gardien_qhs', 'service', p_service, 'titre_echec', 'Corruption d''un gardien du QHS'));

  IF (r ->> 'reussi')::boolean THEN
    IF p_service = 'message' THEN
      PERFORM public.mail_systeme_poser_interne(a, v_dest, 'Un mot passé par un gardien du QHS', v_texte, v_date);
    ELSIF p_service = 'objet' THEN
      v_don := public.inventaire_donner(a, v_dest, p_index, p_signature, 1, NULL);
      IF coalesce((v_don ->> 'ok')::boolean, false) IS NOT TRUE THEN
        RAISE EXCEPTION 'crim_corrompre_gardien : remise impossible (%)', v_don ->> 'raison'; END IF;
    END IF;
    INSERT INTO public.crim_corruptions_qhs (affaire, nom, detention, pnj, service, details, consomme_le)
    VALUES ((r ->> 'affaire')::bigint, a, e ->> 'detention', 'gardien', p_service,
            jsonb_strip_nulls(jsonb_build_object('destinataire', v_dest, 'objet', v_don -> 'objet' ->> 'name')),
            CASE WHEN p_service IN ('message', 'objet') THEN now() END);
    v_out := r || jsonb_build_object('service', p_service, 'destinataire', v_dest);
  ELSE
    v_caisse := public.crim_corruption_confisquer_interne(e ->> 'pays', c_cout);
    v_out := r || jsonb_build_object('service', p_service, 'confisque', c_cout, 'caisse', v_caisse);
  END IF;
  v_out := v_out || jsonb_build_object('ok', true) - 'jets';
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crim_corrompre_gardien', prm, v_out);
END $$;

-- Évasion facilitée : consommée par la prochaine tentative d'évasion de la même détention.
CREATE OR REPLACE FUNCTION public.crim_corruption_evasion_bonus_interne(p_nom text, p_detention text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint;
BEGIN
  SELECT id INTO v_id FROM public.crim_corruptions_qhs
   WHERE nom = p_nom AND detention = p_detention AND service = 'evasion' AND consomme_le IS NULL ORDER BY id LIMIT 1 FOR UPDATE;
  IF v_id IS NULL THEN RETURN 0; END IF;
  UPDATE public.crim_corruptions_qhs SET consomme_le = now() WHERE id = v_id;
  RETURN public.crim_param_interne('corruption_gardien_evasion', 25)::integer;
END $$;

CREATE OR REPLACE FUNCTION public.crim_corruption_protege_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.crim_corruptions_qhs WHERE nom = p_nom AND service = 'protection' AND consomme_le IS NULL);
$$;

-- ── Douanier ─────────────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_zone_transport_interne(p_batiment text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(p_batiment, '') LIKE 'centre-multinodal-%' OR coalesce(p_batiment, '') LIKE 'port-%'
      OR coalesce(p_batiment, '') LIKE 'aeroport%' OR coalesce(p_batiment, '') LIKE 'gare%';
$$;

CREATE OR REPLACE FUNCTION public.douane_corruption_executer_interne(p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; r jsonb; v_caisse text;
  v_aujourdhui date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees d JOIN public.navigation_lieux_regles l
    ON l.pays=d.country AND l.ville=d.current_city AND l.batiment=d.current_building
    WHERE d.name=v_moi AND d.current_building LIKE 'centre-multinodal-%'
    AND d.current_room='hall_douanes' AND l.pieces ? d.current_room) THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_controle');END IF;
  -- Après un échec, on retente dès le lendemain (crim_lot7).
  IF EXISTS (SELECT 1 FROM public.crim_affaires a WHERE a.acte = 'corrompre_douanier' AND a.auteur = v_moi AND a.issue <> 'reussite'
               AND (a.cree_le AT TIME ZONE 'Europe/Paris')::date = v_aujourdhui) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'une_tentative_par_jour'); END IF;
  v_paie := public.payer_ordre(v_moi, 'corrompre_douanier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT stats, resources, country, current_building INTO m FROM public.personnages_donnees WHERE name = v_moi;
  -- 55 + DUP/10 + INF/10, +20 seulement dans une zone de transport (correctif technique du § 12).
  v_taux := 55 + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer
            + floor(coalesce(CASE WHEN jsonb_typeof(m.resources -> 'inf') = 'number' THEN (m.resources ->> 'inf')::numeric END, 0) / 10)::integer
            + CASE WHEN public.crim_zone_transport_interne(m.current_building) THEN public.crim_param_interne('douanier_zone_transport', 20)::integer ELSE 0 END;
  r := public.crim_corrompre_pnj_interne(v_moi, 'corrompre_douanier', v_taux, jsonb_build_object('min', 5, 'pnj', 'douanier'));
  IF (r ->> 'reussi')::boolean THEN
    INSERT INTO public.navigation_passages_douaniers(personnage,pays,ville,batiment,mode,corruption)
    SELECT name,country,current_city,current_building,'avion',true FROM public.personnages_donnees WHERE name=v_moi
    ON CONFLICT(personnage) DO UPDATE SET pays=EXCLUDED.pays,ville=EXCLUDED.ville,batiment=EXCLUDED.batiment,mode=EXCLUDED.mode,corruption=true,controle_le=now();
  ELSE
    -- Les 300 FR sont confisqués au profit des douanes.
    v_caisse := m.country || '_douane';
    PERFORM public.assemblee_crediter_caisse(v_caisse, p_cost);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', (r ->> 'reussi')::boolean, 'repere', (r ->> 'denonce')::boolean,
      'denonce', (r ->> 'denonce')::boolean, 'peine_jours', r -> 'peine_jours', 'taux', (r ->> 'taux')::integer,
      'jet', (r ->> 'jet')::numeric, 'affaire', (r ->> 'affaire')::bigint, 'confisque', CASE WHEN (r ->> 'reussi')::boolean THEN 0 ELSE p_cost END)
    || public.crime_etat_acteur_interne(v_moi);
END $$;

-- ── Anciennes routes : refus propre ──────────────────────────────────────────────────────────────────────────────
-- crime_corrompre servait « Corrompre le directeur », « Corrompre un gardien », « Falsifier un procès-verbal » et la route
-- orpheline corrompre_police (comptait la dissuasion #135 deux fois).
CREATE OR REPLACE FUNCTION public.crime_corrompre(p_fn text, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'actualiser_client', true, 'raison',
    CASE WHEN (p_fn = 'corrompre_fonct' AND p_cost = 1500) OR p_fn = 'corrompre_gardien' THEN 'ordre_remplace' ELSE 'ordre_supprime' END);
$$;
-- « Le temps ne s'achète pas » dans les empires actuels.
CREATE OR REPLACE FUNCTION public.terrain_permis_corrompre(p_terrain text, p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'ordre_supprime', 'actualiser_client', true);
$$;
CREATE OR REPLACE FUNCTION public.terrain_rdv_notaire_accelerer(p_terrain text, p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'ordre_supprime', 'actualiser_client', true);
$$;

-- ── Raccords (règle commune chez le journaliste, le greffier, l'armurier ; évasion ; torture ; Dormir) ─────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Journaliste : même formule (30 + CHA + INF/4 − ISN, 5-85), jet par la règle commune ; « déjà tenté » vérifié AVANT le jet.
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamp with time zone)'::regprocedure,
  $a$  v_ok   boolean;$a$,
  $b$  v_ok   boolean;
  v_r    jsonb; /* crim_corruption_presse_decl_v1 */$b$,
  'crim_corruption_presse_decl_v1');
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamp with time zone)'::regprocedure,
  $a$  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;$a$,
  $b$  IF EXISTS (SELECT 1 FROM public.corruptions_presse WHERE affaire_ref = p_affaire_ref AND corrupteur = p_joueur) THEN /* crim_corruption_presse_v1 */
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente'));
  END IF;
  v_r := public.crim_corrompre_pnj_interne(p_joueur, 'corrompre_journaliste', v_taux,
           jsonb_build_object('min', 5, 'max', 85, 'pnj', 'journaliste', 'affaire_ref', p_affaire_ref));
  v_jet := ceil((v_r ->> 'jet')::numeric)::integer; v_taux := (v_r ->> 'taux')::integer;
  v_ok := coalesce((v_r ->> 'reussi')::boolean, false);$b$,
  'crim_corruption_presse_v1');
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamp with time zone)'::regprocedure,
  $a$    'ok', true, 'reussi', v_ok, 'jet', v_jet, 'taux', v_taux,$a$,
  $b$    'ok', true, 'reussi', v_ok, 'jet', v_jet, 'taux', v_taux, 'denonce', coalesce((v_r ->> 'denonce')::boolean, false), /* crim_corruption_presse_retour_v1 */$b$,
  'crim_corruption_presse_retour_v1');

-- Greffier : 75 % (taux fixe existant) ; échec ordinaire = refus sans suite ; seul l'échec critique dénonce.
SELECT pg_temp.rp_raccorder('public.greffe_corrompre_dossier(text)'::regprocedure,
  $a$v_paye jsonb; v_copie jsonb; v_doc jsonb; v_decouvert boolean;$a$,
  $b$v_paye jsonb; v_copie jsonb; v_doc jsonb; v_decouvert boolean; v_r jsonb; /* crim_corruption_greffe_decl_v1 */$b$,
  'crim_corruption_greffe_decl_v1');
SELECT pg_temp.rp_raccorder('public.greffe_corrompre_faux_casier(text)'::regprocedure,
  $a$v_jour integer; v_paye jsonb; v_doc jsonb; v_decouvert boolean; v_contenu jsonb;$a$,
  $b$v_jour integer; v_paye jsonb; v_doc jsonb; v_decouvert boolean; v_contenu jsonb; v_r jsonb; /* crim_corruption_greffe_decl_v1 */$b$,
  'crim_corruption_greffe_decl_v1');
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['greffe_corrompre_dossier', 'greffe_corrompre_faux_casier'] LOOP
    PERFORM pg_temp.rp_raccorder(('public.' || f || '(text)')::regprocedure,
      $a$  v_decouvert := random() < 0.25;

  IF v_decouvert THEN
    PERFORM public.greffe_denoncer_corruption(v_pays);
    RETURN jsonb_build_object('ok', true, 'decouvert', true, 'document', NULL,
      'raison_metier', 'corruption_decouverte', 'jour', v_jour);
  END IF;$a$,
      replace($b$  v_r := public.crim_corrompre_pnj_interne(v_moi, '@FN@', public.crim_param_interne('greffe_corruption_taux', 75),
           jsonb_build_object('acte_peine', 'corruption_fonctionnaire', 'pnj', 'greffier')); /* crim_corruption_greffe_v1 */
  v_decouvert := NOT coalesce((v_r ->> 'reussi')::boolean, false);

  IF v_decouvert THEN
    RETURN jsonb_build_object('ok', true, 'decouvert', coalesce((v_r ->> 'denonce')::boolean, false), 'refuse', true, 'document', NULL,
      'raison_metier', CASE WHEN coalesce((v_r ->> 'denonce')::boolean, false) THEN 'corruption_decouverte' ELSE 'corruption_refusee' END,
      'jour', v_jour, 'peine_jours', v_r -> 'peine_jours');
  END IF;$b$, '@FN@', f),
      'crim_corruption_greffe_v1');
  END LOOP;
END $$;

-- Armurier : 30 % (taux existant), jet par la règle commune.
SELECT pg_temp.rp_raccorder('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$    v_detecte:=floor(random()*100)::integer+1<=30;$a$,
  $b$    v_detecte:=coalesce((public.crim_corrompre_pnj_interne(a.name,'corrompre_armurier',public.crim_param_interne('armurier_corruption_taux',30),
      jsonb_build_object('acte_peine','corruption_fonctionnaire','pnj','armurier'))->>'reussi')::boolean,false); /* crim_corruption_armurier_v1 */$b$,
  'crim_corruption_armurier_v1');

-- Évasion facilitée par un gardien : +25 % à la prochaine tentative (maximum absolu 90 %, comme les autres bonus).
SELECT pg_temp.rp_raccorder('public.detention_tenter_evasion(integer,integer,boolean)'::regprocedure,
  $a$  v_bonus := public.crim_grilles_bonus_interne(v_pays, v_ville); /* crim_grilles_evasion_v1 */
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;$a$,
  $b$  v_bonus := public.crim_grilles_bonus_interne(v_pays, v_ville); /* crim_grilles_evasion_v1 */
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;
  v_bonus := public.crim_corruption_evasion_bonus_interne(v_moi, v_det.id); /* crim_corruption_evasion_v1 */
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;$b$,
  'crim_corruption_evasion_v1');

-- Protection : pas de torture jusqu'au prochain « Dormir ».
SELECT pg_temp.rp_raccorder('public.qhs_pouvoir(text,text)'::regprocedure,
  $a$  -- torture : indices et moral a zero, PA plafonnes a 1 le lendemain.$a$,
  $b$  IF public.crim_corruption_protege_interne(v_nom) THEN /* crim_corruption_protection_v1 */
    RETURN jsonb_build_object('ok', false, 'raison', 'detenu_protege');
  END IF;
  -- torture : indices et moral a zero, PA plafonnes a 1 le lendemain.$b$,
  'crim_corruption_protection_v1');
SELECT pg_temp.rp_raccorder('public.pa_repos_nocturne(text)'::regprocedure,
  $a$  PERFORM public.crim_vols_reveil_interne(p_acteur); /* crim_vol_reveil_v1 */$a$,
  $b$  PERFORM public.crim_vols_reveil_interne(p_acteur); /* crim_vol_reveil_v1 */
  UPDATE public.crim_corruptions_qhs SET consomme_le = now() /* crim_corruption_dormir_v1 */
   WHERE nom = p_acteur AND service = 'protection' AND consomme_le IS NULL;$b$,
  'crim_corruption_dormir_v1');

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_corrompre_pnj_interne(text,text,numeric,jsonb)', 'crim_corruption_qhs_taux_interne(numeric,numeric)',
    'crim_corruption_qhs_etat_interne(text)', 'crim_corruption_confisquer_interne(text,integer)',
    'crim_corruption_evasion_bonus_interne(text,text)', 'crim_corruption_protege_interne(text)', 'crim_zone_transport_interne(text)',
    'douane_corruption_executer_interne(integer,integer)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crim_corruption_qhs_lire()', 'crim_corrompre_directeur(uuid)',
    'crim_corrompre_gardien(text,text,text,integer,jsonb,uuid)', 'crime_corrompre(text,integer,integer)',
    'terrain_permis_corrompre(text,uuid)', 'terrain_rdv_notaire_accelerer(text,uuid)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
