-- LOT DE KRASNOV (1re partie), point 8 — décisions de Fred du 21/11/2026 sur le radar (#1169).
--  1. Habitué du Bar Sever : règle commune des informateurs de Sovarka — on le paie de 7 à 20 PSK, payer donne toujours
--     un service, la qualité dépend de la somme :
--       palier flou (7 à 12 PSK) : il met sur la piste sans rien livrer ;
--       palier correct (13 à 19 PSK) : il nomme le colonel Voronov et laisse entendre qu'il vend « quelque chose » ;
--       palier premier choix (20 PSK) : il donne la phrase de passe ; le secret entre au carnet.
--     (Bornes intermédiaires 12/13 posées par Claude : seule la borne de 20 PSK est fixée par Fred.)
--  2. Vol des archives : plus de pile ou face. L'opérateur Ilia Sorokine reçoit une fiche de PNJ avec un profil de combat
--     par défaut (ENT 10, VOL 12, PER 12, DUP 8 : profil des agents de l'État) ; le vol passe par le moteur commun
--     (crim_resoudre_interne, comme le cambriolage) et la bagarre par le vrai moteur de combat (modificateurs et plafond
--     de la neutralisation, comme pour tout PNJ). Sans personne de présent (opérateur neutralisé), le vol réussit d'office.
-- Idempotente.
BEGIN;

INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, pa, statut,
  car_ent, car_cha, car_dup, car_int, car_per, car_vol, proprietaire_institution, proprietaire_perimetre, classe, position_pays)
SELECT 'sovarka-radar-krasnov-sorokine', 'employe', 'Caporal Ilia Sorokine', 'soviet', 'ville_b', 'station-radar-krasnov', 'salle_ecoute', 12, 'actif',
       10, 8, 8, 10, 12, 12, 'station_radar', 'soviet:ville_b:station-radar-krasnov', 'beta', 'soviet'
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = 'sovarka-radar-krasnov-sorokine');

CREATE OR REPLACE FUNCTION public.sovarka_ecoute_archives_voler(p_requete text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); p record; c text; v_paie jsonb; r public.sovarka_ecoutes_rapports; v jsonb; x record;
  t jsonb; rr jsonb; v_req uuid; v_jets jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:vol_archives:' || a, 0));
  SELECT * INTO x FROM public.sovarka_ecoutes_vols WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true) || public.crime_etat_acteur_interne(a); END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  c := CASE WHEN p.country = 'soviet' THEN public.sovarka_ecoute_centre_interne(p.current_city, p.current_building) END;
  IF c IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF c = 'novomirsk' AND p.current_room IS DISTINCT FROM 'salle_ecoutes' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.sovarka_titulaire_interne('min_def') IS NOT DISTINCT FROM a THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ministre_defense'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour >= public.sovarka_jour_paris() - 30) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'archives_vides'); END IF;
  v_paie := public.payer_ordre(a, 'voler_archives_ecoute', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  /* vol_archives_moteur_commun_v4 (Fred, 21/11/2026) : moteur commun du vol, vrai combat contre l'opérateur. */
  v_req := md5('vol_archives:' || a || ':' || p_requete)::uuid;
  v_jets := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END;
  t := public.crim_temoin_interne(a, NULL);
  IF t IS NULL THEN
    rr := public.crim_resoudre_interne('voler_archives_ecoute', a, NULL, jsonb_build_object(
      'reussite_auto', true, 'detection_base', public.crim_param_interne('cambriolage_detection', 30),
      'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'voler_archives_ecoute', 'acte_peine_echec', 'voler_archives_ecoute', 'type_recherche', 'delit_mineur',
      'indices', jsonb_build_object('butin', 'archives'), 'butin', 'archives', 'lieu_vide', true, 'jets', v_jets));
  ELSE
    rr := public.crim_resoudre_interne('voler_archives_ecoute', a, CASE WHEN (t ->> 'pj')::boolean THEN t ->> 'nom' ELSE t ->> 'pnj_id' END, jsonb_build_object(
      'taux', public.crim_voler_taux_interne('hasard', public.crim_stat_interne(a, 'dis', 50), public.crim_per_groupe_interne(t), public.crim_carriere_interne(a)),
      'min', public.crim_param_interne('vol_min', 5), 'max', public.crim_param_interne('vol_max', 85),
      'critique_reussite_part', public.crim_param_interne('vol_critique_reussite_part', 5), 'critique_sans_detection', true,
      'combat', true, 'per_victime', (t ->> 'per')::numeric, 'remarque_echec', public.crim_voler_remarque_interne(public.crim_per_groupe_interne(t), public.crim_stat_interne(a, 'dis', 50)),
      'detection_base', public.crim_param_interne('cambriolage_detection', 30), 'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'voler_archives_ecoute', 'acte_peine_echec', 'voler_archives_ecoute', 'type_recherche', 'delit_mineur', 'cible_info', t,
      'titre_reussite', 'Vol d''archives', 'titre_echec', 'Tentative de vol d''archives',
      'msg_reussite', '{Auteur} a dérobé un rapport d''écoute sous vos yeux.',
      'msg_echec', '{Auteur} a tenté de dérober un rapport d''écoute sous vos yeux.',
      'motif_plainte', 'Vol dans les archives d''écoute',
      'indices', jsonb_build_object('butin', 'archives'), 'butin', 'archives', 'jets', v_jets));
  END IF;
  IF rr ->> 'issue' = 'combat' THEN rr := public.crim_combat_ouvrir_interne(a, rr, t, 'mains', v_req); END IF;
  IF rr ->> 'issue' = 'reussite' THEN
    SELECT * INTO r FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour >= public.sovarka_jour_paris() - 30
     ORDER BY random() LIMIT 1;
    PERFORM public.crime_tracer_interne(a, 'voler_archives_ecoute', 'archives d''écoute de ' || initcap(c));
    PERFORM public.mail_systeme_poser_interne('Archives volées', a,
      'Rapport d''écoute dérobé — ' || initcap(r.centre) || ', ' || to_char(r.jour, 'DD/MM'),
      public.sovarka_ecoute_rapport_texte_interne(r));
    rr := rr || jsonb_build_object('centre', r.centre, 'jour', r.jour, 'nb', jsonb_array_length(r.mails));
  END IF;
  v := jsonb_build_object('ok', true, 'reussi', rr ->> 'issue' = 'reussite', 'pa', v_paie -> 'pa', 'lieu_vide', t IS NULL)
       || (rr - 'notifie' - 'affaire' - 'garde');
  INSERT INTO public.sovarka_ecoutes_vols (acteur, requete, resultat) VALUES (a, p_requete, v);
  RETURN v || public.crime_etat_acteur_interne(a);
END $function$;

-- Habitué : paiement libre de 7 à 20 PSK (aucun PA), trois paliers de service.
UPDATE public.ordres_couts SET pa = 0, cost = 0 WHERE fn = 'offrir_verre_habitue_krasnov' AND (pa, cost) IS DISTINCT FROM (0, 0);
DROP FUNCTION IF EXISTS public.secret_source_ecouter(uuid, text);
DROP FUNCTION IF EXISTS public.secret_source_interne(text, text);

CREATE OR REPLACE FUNCTION public.secret_source_interne(p_acteur text, p_source text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_paie jsonb := '{}'::jsonb; v_palier text; v_appris boolean := false; v_deja boolean;
  v_liquide numeric; v_arg numeric; v_compte text; v_solde numeric; v_pris numeric;
BEGIN
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF p_source = 'habitue_krasnov' THEN
    IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM ('soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
    IF p_montant IS NULL OR p_montant NOT BETWEEN 7 AND 20 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
    SELECT coalesce(liquide, 0), coalesce(arg, 0) INTO v_liquide, v_arg FROM public.personnages_donnees WHERE name = p_acteur;
    SELECT id, coalesce(solde, 0) INTO v_compte, v_solde FROM public.comptes_bancaires WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
    IF v_liquide + coalesce(v_solde, 0) < p_montant THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', p_montant); END IF;
    v_pris := least(v_liquide, p_montant);
    UPDATE public.personnages_donnees SET liquide = v_liquide - v_pris, arg = v_arg - p_montant WHERE name = p_acteur;
    IF p_montant - v_pris > 0 THEN UPDATE public.comptes_bancaires SET solde = solde - (p_montant - v_pris), updated_at = now() WHERE id = v_compte; END IF;
    v_palier := CASE WHEN p_montant >= 20 THEN 'premier_choix' WHEN p_montant >= 13 THEN 'correct' ELSE 'flou' END;
    v_appris := v_palier = 'premier_choix';
    v_paie := (SELECT jsonb_build_object('liquide', liquide, 'arg', arg) FROM public.personnages_donnees WHERE name = p_acteur);
  ELSIF p_source = 'kalachnikov' THEN
    IF (p.country, p.current_city) IS DISTINCT FROM ('soviet', 'capitale') OR p.current_building IS DISTINCT FROM 'armurerie' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
    v_paie := public.payer_ordre(p_acteur, 'demander_fournisseur_kalachnikov', 1, 0);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    v_palier := 'premier_choix'; v_appris := true;
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'source_inconnue'); END IF;
  v_deja := EXISTS (SELECT 1 FROM public.personnages_secrets WHERE personnage = p_acteur AND cle = 'colonel_polonium');
  IF v_appris AND NOT v_deja THEN
    INSERT INTO public.personnages_secrets (personnage, cle, source) VALUES (p_acteur, 'colonel_polonium', p_source) ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('ok', true, 'source', p_source, 'palier', v_palier, 'montant', p_montant, 'appris', v_appris, 'deja', v_deja,
    'pa', v_paie -> 'pa', 'liquide', v_paie -> 'liquide', 'arg', v_paie -> 'arg',
    'secret', CASE WHEN v_appris THEN public.secret_fiche_interne('colonel_polonium') END);
END $$;
REVOKE ALL ON FUNCTION public.secret_source_interne(text, text, integer) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.secret_source_ecouter(p_requete uuid, p_source text, p_montant integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('source', p_source, 'montant', p_montant); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'secret_source_ecouter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.secret_source_interne(a, p_source, p_montant);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'secret_source_ecouter', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.secret_source_ecouter(uuid, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.secret_source_ecouter(uuid, text, integer) TO authenticated;

COMMIT;
