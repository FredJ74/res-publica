-- Mission du 27/11/2026 (soir, Claude), étape 2 — « Produire une fuite » aux Archives Gouvernementales du Palais du
-- Gouvernement (Républia ; la fuite de Sovarka, décidée le 08/11, reste celle de sovarka_pouvoir_commande).
-- Décision de Fred du 27/11/2026 : sur le modèle du vol d'archives des centres d'écoute de Sovarka
-- (sovarka_ecoute_archives_voler, moteur commun du vol du 21/11) : une information RÉELLE est tirée au hasard et rejoint
-- l'inventaire comme archive ; mêmes risques et sanctions en cas d'échec (crim_resoudre_interne, détection, combat contre
-- le témoin présent, peine du vol d'archives). Le joueur en fait ce qu'il veut (la monnayer à un journaliste, la donner…).
-- Le +5 influence / +10 popularité sans contenu (ligne fuite_info de ordres_generiques) disparaît.
--
-- Informations réelles possibles, tirées au hasard parmi celles qui existent au moment du vol :
--   • un fait réel (fuite_traces_eligibles : historique_crimes, actions_tracables, jamais déjà publié par la presse) d'un
--     membre du gouvernement du pays (président, Premier ministre, ministres) ;
--   • le solde réel d'une caisse du gouvernement du pays (caisses_batiments « <pays>_gouvernement… »).
-- Rien à prendre : refus « archives_vides » avant tout paiement. Coût inchangé : 3 PA (ordres_couts fuite_info).
-- Accès inchangé : un titulaire de poste (requiresPost:true), dans les Archives Gouvernementales de son pays.
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.ordres_generiques WHERE fn = 'fuite_info';                                  -- 0
--   SELECT position('fuite_archives_v1' in pg_get_functiondef('public.archives_gouv_fuite(text)'::regprocedure)) > 0; -- vrai
BEGIN;

CREATE TABLE IF NOT EXISTS public.archives_gouv_fuites (
  acteur text NOT NULL,
  requete text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete)
);
ALTER TABLE public.archives_gouv_fuites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.archives_gouv_fuites FROM PUBLIC, anon, authenticated;

DELETE FROM public.ordres_generiques WHERE fn = 'fuite_info';

-- Une information réelle des archives du gouvernement de p_pays, tirée au hasard (NULL s'il n'y a rien).
CREATE OR REPLACE FUNCTION public.archives_gouv_information_interne(p_pays text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH membres AS (
    SELECT p.name, p.poste->>'id' AS poste FROM public.personnages_donnees p
     WHERE (p.poste->>'id' IN ('president', 'premier_ministre') OR p.poste->>'id' LIKE 'min\_%')
       AND coalesce(public.poste_pays_de(p.name), p.country) = p_pays
  ), infos AS (
    SELECT jsonb_build_object('source', 'trace', 'cle', t.trace_cle, 'membre', m.name, 'poste', m.poste, 'faits', t.faits,
      'texte', 'Pièce des archives du gouvernement concernant ' || m.name || ' : '
        || public.interrogatoire_fait_texte_interne(t.faits) || '.') AS info
      FROM membres m CROSS JOIN LATERAL public.fuite_traces_eligibles(m.name) t
    UNION ALL
    SELECT jsonb_build_object('source', 'caisse', 'cle', 'caisse:' || c.id, 'caisse', c.id,
      'solde', coalesce((c.data->>'solde')::numeric, 0),
      'texte', 'Note du Trésor : la caisse « ' || c.id || ' » détenait '
        || replace(to_char(coalesce((c.data->>'solde')::numeric, 0), 'FM999G999G999G990'), ',', ' ') || ' FR au '
        || to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') || '.')
      FROM public.caisses_batiments c
     WHERE c.id LIKE p_pays || '\_gouvernement%'
  )
  SELECT info FROM infos ORDER BY random() LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.archives_gouv_information_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.archives_gouv_fuite(p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
-- fuite_archives_v1 : moteur commun du vol (copie du vol d'archives d'écoute, 21/11/2026), butin = archive réelle.
DECLARE a text := public.mon_personnage(); p record; x record; v_paie jsonb; t jsonb; rr jsonb; v_req uuid; v_jets jsonb;
  v_info jsonb; v_objet jsonb; v_dep jsonb; v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('archives_gouv:fuite:' || a, 0));
  SELECT * INTO x FROM public.archives_gouv_fuites WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true) || public.crime_etat_acteur_interne(a); END IF;
  SELECT country, current_building, current_room, poste INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF p.country IS NULL OR p.country = 'soviet' OR p.current_building IS DISTINCT FROM 'palais-gouvernement'
     OR p.current_room IS DISTINCT FROM 'archives_gouv' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce(p.poste->>'id', '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_titulaire_poste'); END IF;
  v_info := public.archives_gouv_information_interne(p.country);
  IF v_info IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'archives_vides'); END IF;
  v_paie := public.payer_ordre(a, 'fuite_info', 3, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_req := md5('fuite_archives:' || a || ':' || p_requete)::uuid;
  v_jets := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END;
  t := public.crim_temoin_interne(a, NULL);
  IF t IS NULL THEN
    rr := public.crim_resoudre_interne('fuite_info', a, NULL, jsonb_build_object(
      'reussite_auto', true, 'detection_base', public.crim_param_interne('cambriolage_detection', 30),
      'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'voler_archives_ecoute', 'acte_peine_echec', 'voler_archives_ecoute', 'type_recherche', 'delit_mineur',
      'indices', jsonb_build_object('butin', 'archives'), 'butin', 'archives', 'lieu_vide', true, 'jets', v_jets));
  ELSE
    rr := public.crim_resoudre_interne('fuite_info', a, CASE WHEN (t ->> 'pj')::boolean THEN t ->> 'nom' ELSE t ->> 'pnj_id' END, jsonb_build_object(
      'taux', public.crim_voler_taux_interne('hasard', public.crim_stat_interne(a, 'dis', 50), public.crim_per_groupe_interne(t), public.crim_carriere_interne(a)),
      'min', public.crim_param_interne('vol_min', 5), 'max', public.crim_param_interne('vol_max', 85),
      'critique_reussite_part', public.crim_param_interne('vol_critique_reussite_part', 5), 'critique_sans_detection', true,
      'combat', true, 'per_victime', (t ->> 'per')::numeric, 'remarque_echec', public.crim_voler_remarque_interne(public.crim_per_groupe_interne(t), public.crim_stat_interne(a, 'dis', 50)),
      'detection_base', public.crim_param_interne('cambriolage_detection', 30), 'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'voler_archives_ecoute', 'acte_peine_echec', 'voler_archives_ecoute', 'type_recherche', 'delit_mineur', 'cible_info', t,
      'titre_reussite', 'Vol d''archives', 'titre_echec', 'Tentative de vol d''archives',
      'msg_reussite', '{Auteur} a dérobé une pièce des archives du gouvernement sous vos yeux.',
      'msg_echec', '{Auteur} a tenté de dérober une pièce des archives du gouvernement sous vos yeux.',
      'motif_plainte', 'Vol dans les archives du gouvernement',
      'indices', jsonb_build_object('butin', 'archives'), 'butin', 'archives', 'jets', v_jets));
  END IF;
  IF rr ->> 'issue' = 'combat' THEN rr := public.crim_combat_ouvrir_interne(a, rr, t, 'mains', v_req); END IF;
  IF rr ->> 'issue' = 'reussite' THEN
    v_objet := jsonb_build_object('name', 'Archive gouvernementale', 'icon', 'ti-file-text', 'type', 'archive',
      'desc', v_info ->> 'texte', 'encombrement', 1,
      'archive', (v_info - 'texte') || jsonb_build_object('pays', p.country, 'volee_le', now()));
    v_dep := public.inventaire_deposer_interne(a, v_objet, true);
    PERFORM public.crime_tracer_interne(a, 'fuite_archives_gouvernement', 'archives du gouvernement');
    rr := rr || jsonb_build_object('archive', v_info ->> 'texte', 'source', v_info ->> 'source');
  END IF;
  v := jsonb_build_object('ok', true, 'reussi', rr ->> 'issue' = 'reussite', 'pa', v_paie -> 'pa', 'lieu_vide', t IS NULL)
       || (rr - 'notifie' - 'affaire' - 'garde');
  INSERT INTO public.archives_gouv_fuites (acteur, requete, resultat) VALUES (a, p_requete, v);
  RETURN v || public.crime_etat_acteur_interne(a)
    || jsonb_build_object('inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = a));
END $$;
REVOKE ALL ON FUNCTION public.archives_gouv_fuite(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.archives_gouv_fuite(text) TO authenticated;

COMMIT;
