-- CRIMINALITÉ — LOT 2 : résolution commune des crimes et Neutraliser (GAME-DESIGN-CRIMINALITE.md §§ 2, 3, 6 ; Fred, 18-19/11/2026).
-- • crim_resoudre_interne(acte, auteur, cible, params) : LA résolution commune, réutilisée par tous les actes (lots 3 à 5) :
--   jet de réussite (taux fourni par l'acte, dissuasion #135 retranchée UNE fois, bornes), réussite critique optionnelle,
--   échec critique (part des échecs, 2 % par défaut ; −15 moral ; identifié sans masque), passage au combat (10 % des échecs,
--   +2/PER de la victime au-dessus de 10, +15 garde du corps ou agence, −10 caché, bornes 2-40), détection (base de l'acte,
--   −20 caché, −10 masqué, plancher ; sans masque identifie, avec masque trace sans nom), message à la victime selon le mode
--   (nom / « un inconnu » / « un individu masqué »), employeur d'un PNJ alerté et plainte déposée, affaire enregistrée pour
--   l'enquête du lot 6 (crim_affaires : trace, plafond d'identification 5 / 15 %, indices), peine d'office si identifié
--   (avis de recherche ; barème, valeur de Républia paramétrée par empire). Suite d'un combat : crim_resoudre_suite_interne.
-- • crime_neutraliser(cible, mode, requete) : jet de réussite serveur rétabli (formule historique : base + 2 × FOR / DUP / PER,
--   +15 carrière criminelle, − PER de la cible / 2, plafonds 65 / 75 / 85 ; PA 2 / 2 / 3), +10 depuis la cachette, gilet revêtu
--   −20 arme à feu / −5 sinon ; le combat (moteur inchangé) n'arrive que par le passage au combat d'un échec.
--   Vaincu = identifié ; vainqueur = réussite (détection), perd sa cachette, garde son masque. Cible : PJ, individu masqué
--   (jeton de crim_presents) ou PNJ référencé (caractéristiques réelles, sinon PER 8 ; hors service jusqu'au lendemain).
-- • Un affrontement « civil » contre une personne ne s'ouvre plus directement : il passe par crime_neutraliser
--   (squatteurs, faune et gardes d'accès inchangés).
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia tant qu'ils n'ont pas les leurs) ─────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('echec_critique_part', 2),
  ('combat_base', 10), ('combat_par_per', 2), ('combat_per_seuil', 10), ('combat_garde', 15), ('combat_cache', 10),
  ('combat_min', 2), ('combat_max', 40),
  ('detection_cache', 20), ('detection_masque', 10), ('detection_min', 5), ('detection_identifie_dis', 10),
  ('plafond_enquete_reussite', 5), ('plafond_enquete_echec', 15),
  ('neutraliser_cache', 10), ('neutraliser_gilet_feu', 20), ('neutraliser_gilet_autre', 5), ('neutraliser_carriere', 15),
  ('neutraliser_per_pnj', 8), ('neutraliser_per_pj', 10),
  ('peine_jours_assassinat_republic', 2), ('peine_jours_tentative_assassinat_republic', 2)
ON CONFLICT (cle) DO NOTHING;

-- ── Affaires (lues par l'enquête sur plainte contre X, lot 6) ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crim_affaires (
  id bigserial PRIMARY KEY,
  acte text NOT NULL, auteur text NOT NULL, cible text, cible_pnj text, employeur text, mode text NOT NULL,
  pays text, ville text, batiment text, piece text, jour integer,
  issue text NOT NULL,                       -- reussite / echec / combat / combat_gagne / combat_perdu
  reussite_critique boolean NOT NULL DEFAULT false, echec_critique boolean NOT NULL DEFAULT false,
  detecte boolean NOT NULL DEFAULT false, identifie boolean NOT NULL DEFAULT false, trace boolean NOT NULL DEFAULT false,
  remarque boolean NOT NULL DEFAULT false,   -- la victime (ou l'employeur) sait qu'il s'est passé quelque chose
  plafond_enquete integer, plainte_id text, bataille bigint, peine_jours integer,
  indices jsonb NOT NULL DEFAULT '{}'::jsonb, details jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(), maj_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS crim_affaires_lieu ON public.crim_affaires (pays, ville, cree_le);
CREATE INDEX IF NOT EXISTS crim_affaires_cible ON public.crim_affaires (cible, cree_le);
CREATE INDEX IF NOT EXISTS crim_affaires_auteur ON public.crim_affaires (auteur, cree_le);
ALTER TABLE public.crim_affaires ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_affaires FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_affaires_id_seq FROM anon, authenticated;

-- ── Briques ─────────────────────────────────────────────────────────────────────────────────────────────────────
-- Désignation de l'auteur selon le mode. forme 'sujet' : « Arnie » / « Quelqu'un » / « Un individu masqué » ;
-- forme 'complement' : « Arnie » / « un inconnu » / « un individu masqué ».
CREATE OR REPLACE FUNCTION public.crim_designation_interne(p_mode text, p_auteur text, p_forme text DEFAULT 'sujet')
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_mode IN ('masque', 'cache_masque') THEN CASE WHEN p_forme = 'sujet' THEN 'Un individu masqué' ELSE 'un individu masqué' END
              WHEN p_mode = 'cache' THEN CASE WHEN p_forme = 'sujet' THEN 'Quelqu''un' ELSE 'un inconnu' END
              ELSE p_auteur END;
$$;

CREATE OR REPLACE FUNCTION public.crim_message_interne(p_modele text, p_mode text, p_auteur text, p_cible text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT replace(replace(replace(coalesce(p_modele, ''), '{Auteur}', public.crim_designation_interne(p_mode, p_auteur, 'sujet')),
                 '{auteur}', public.crim_designation_interne(p_mode, p_auteur, 'complement')), '{cible}', coalesce(p_cible, ''));
$$;

-- Passage au combat (§ 2) : 10 % + 2 par point de PER de la victime au-dessus de 10, +15 garde, −10 caché, bornes 2-40.
CREATE OR REPLACE FUNCTION public.crim_combat_taux_interne(p_per numeric, p_garde boolean, p_cache boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(public.crim_param_interne('combat_min', 2), least(public.crim_param_interne('combat_max', 40),
           public.crim_param_interne('combat_base', 10)
           + public.crim_param_interne('combat_par_per', 2) * greatest(0, coalesce(p_per, 10) - public.crim_param_interne('combat_per_seuil', 10))
           + CASE WHEN p_garde THEN public.crim_param_interne('combat_garde', 15) ELSE 0 END
           - CASE WHEN p_cache THEN public.crim_param_interne('combat_cache', 10) ELSE 0 END))::integer;
$$;

-- Détection (§§ 2, 6) : base de l'acte, −20 caché, −10 masqué (cumulés), plancher propre à l'acte.
CREATE OR REPLACE FUNCTION public.crim_detection_taux_interne(p_base numeric, p_mode text, p_min numeric DEFAULT NULL)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(100, greatest(coalesce(p_min, public.crim_param_interne('detection_min', 5)),
           coalesce(p_base, 0)
           - CASE WHEN p_mode IN ('cache', 'cache_masque') THEN public.crim_param_interne('detection_cache', 20) ELSE 0 END
           - CASE WHEN p_mode IN ('masque', 'cache_masque') THEN public.crim_param_interne('detection_masque', 10) ELSE 0 END))::integer;
$$;

-- Peine d'office (jours) d'un acte du barème, par empire : paramètre de l'empire, sinon celui de Républia, sinon barème.
CREATE OR REPLACE FUNCTION public.crim_peine_jours_interne(p_acte text, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(
    (SELECT valeur FROM public.crim_parametres WHERE cle = 'peine_jours_' || p_acte || '_' || coalesce(p_pays, 'republic')),
    (SELECT valeur FROM public.crim_parametres WHERE cle = 'peine_jours_' || p_acte || '_republic'),
    (SELECT jours_reference FROM public.infractions WHERE id = p_acte AND bareme_propre),
    (SELECT peine_jours FROM public.actes_illegaux WHERE fn = p_acte))::integer;
$$;

-- Le barème des arrestations lit la même valeur par empire (arrestation_flagrant_interne → peine_acte_interne).
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

SELECT pg_temp.rp_raccorder('public.peine_acte_interne(text,text)'::regprocedure,
  $a$SELECT * INTO i FROM public.infractions WHERE id = p_acte;$a$,
  $b$SELECT * INTO i FROM public.infractions WHERE id = p_acte;
IF EXISTS (SELECT 1 FROM public.crim_parametres WHERE cle = 'peine_jours_' || p_acte || '_republic') THEN /* crim_peine_empire_v1 */
  libelle := coalesce(i.libelle, p_acte); jours := public.crim_peine_jours_interne(p_acte, p_pays); RETURN NEXT; RETURN; END IF;$b$,
  'crim_peine_empire_v1');

-- Garde du corps ou agence de sécurité auprès de la victime : agents privés (employés agent de sécurité / maître-chien)
-- ou soldats rattachés à la victime (ou à l'employeur d'un PNJ), présents au même endroit.
CREATE OR REPLACE FUNCTION public.crim_garde_cible_interne(p_proprietaire text, p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_proprietaire IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) p
     WHERE m.statut = 'actif' AND m.pa > 0 AND p.pays = p_pays AND p.ville = p_ville
       AND p.building_id IS NOT DISTINCT FROM p_batiment AND p.room_id IS NOT DISTINCT FROM p_piece
       AND ((m.famille = 'employe' AND m.proprietaire_pj = p_proprietaire
             AND EXISTS (SELECT 1 FROM public.pnj_employes_metier e WHERE e.pnj_id = m.id AND e.job IN ('agent_securite', 'maitre_chien')))
         OR (m.famille = 'soldat' AND m.leader_pj = p_proprietaire)));
$$;

-- Cible d'un crime en pièce : nom de PJ, jeton d'un individu masqué (crim_presents) ou PNJ référencé (id ou nom unique).
-- Un PJ caché ou masqué n'est pas désignable par son nom (on ne confirme pas une identité). Rend aussi le PER de la cible.
CREATE OR REPLACE FUNCTION public.crim_cible_resoudre_interne(p_auteur text, p_cible text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a record; c record; v_nom text; v_jeton boolean := false; v_pnj public.pnj_membres%ROWTYPE; pe record;
BEGIN
  IF coalesce(btrim(p_cible), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT name, country, current_city, current_building, current_room, current_street INTO a FROM public.personnages_donnees WHERE name = p_auteur;
  IF p_cible ~ '^[0-9a-f-]{36}$' THEN
    v_nom := public.crim_jeton_resoudre_interne(p_cible); v_jeton := true;
    IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
  ELSIF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    v_nom := p_cible;
    IF v_nom <> p_auteur AND (public.crim_cache_interne(v_nom) OR public.crim_masque_interne(v_nom)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
  END IF;
  IF v_nom IS NOT NULL THEN
    IF v_nom = p_auteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
    SELECT name, country, current_city, current_building, current_room, current_street INTO c FROM public.personnages_donnees WHERE name = v_nom;
    IF (c.country, c.current_city, c.current_building, c.current_room) IS DISTINCT FROM (a.country, a.current_city, a.current_building, a.current_room)
       OR (a.current_building IS NULL AND c.current_street IS DISTINCT FROM a.current_street) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
    IF v_nom <> p_auteur AND public.crim_cache_interne(v_nom) THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
    RETURN jsonb_build_object('ok', true, 'pj', true, 'nom', v_nom, 'via_jeton', v_jeton,
      'per', public.crim_stat_interne(v_nom, 'PER', public.crim_param_interne('neutraliser_per_pj', 10)),
      'pays', c.country, 'ville', c.current_city, 'batiment', c.current_building, 'piece', c.current_room);
  END IF;
  SELECT * INTO v_pnj FROM public.pnj_membres WHERE id = p_cible AND statut = 'actif';
  IF NOT FOUND THEN
    IF (SELECT count(*) FROM public.pnj_membres WHERE nom = p_cible AND statut = 'actif') > 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_ambigue'); END IF;
    SELECT * INTO v_pnj FROM public.pnj_membres WHERE nom = p_cible AND statut = 'actif';
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_referencee'); END IF;
  END IF;
  IF v_pnj.classe = 'gamma' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_protegee'); END IF;
  IF NOT public.pnj_co_present(p_auteur, v_pnj.id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(v_pnj.id);
  RETURN jsonb_build_object('ok', true, 'pj', false, 'pnj_id', v_pnj.id, 'nom', v_pnj.nom, 'via_jeton', false,
    'per', coalesce(v_pnj.car_per, public.crim_param_interne('neutraliser_per_pnj', 8)),
    'employeur', coalesce(v_pnj.proprietaire_pj, v_pnj.leader_pj), 'pa', v_pnj.pa,
    'profil_combat', (v_pnj.famille = 'soldat' OR (v_pnj.car_vol IS NOT NULL AND v_pnj.car_per IS NOT NULL AND v_pnj.car_dup IS NOT NULL)),
    'pays', pe.pays, 'ville', pe.ville, 'batiment', pe.building_id, 'piece', pe.room_id);
END $$;

-- Identification : avis de recherche (peine d'office au barème, valeur de l'empire) ; rend les jours.
CREATE OR REPLACE FUNCTION public.crim_identifier_interne(p_auteur text, p_acte_peine text, p_type text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pays text;
BEGIN
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_auteur;
  PERFORM public.crime_rechercher_interne(p_auteur, p_acte_peine, coalesce(p_type, 'crime'));
  RETURN public.crim_peine_jours_interne(p_acte_peine, v_pays);
END $$;

-- Messages et plainte de l'employeur (PNJ) : partie commune à la résolution immédiate et à la suite d'un combat.
CREATE OR REPLACE FUNCTION public.crim_affaire_notifier_interne(p_affaire bigint, p_succes boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.crim_affaires%ROWTYPE; p jsonb; v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
        v_titre text; v_corps text; v_id text; v_cible_plainte text; v_jour integer; v_victime boolean := false; v_employeur boolean := false;
BEGIN
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  p := f.details -> 'params';
  IF NOT f.remarque THEN RETURN jsonb_build_object('victime', false, 'employeur', false); END IF;
  v_titre := coalesce(p ->> CASE WHEN p_succes THEN 'titre_reussite' ELSE 'titre_echec' END, 'Agression');
  IF f.cible_pnj IS NULL AND f.cible IS NOT NULL THEN
    v_corps := public.crim_message_interne(p ->> CASE WHEN p_succes THEN 'msg_reussite' ELSE 'msg_echec' END, f.mode, f.auteur, f.cible);
    IF v_corps <> '' THEN
      PERFORM public.mail_systeme_poser_interne('Événement', f.cible, v_titre, v_corps, v_date); v_victime := true;
    END IF;
  ELSIF f.employeur IS NOT NULL THEN
    v_corps := public.crim_message_interne(p ->> CASE WHEN p_succes THEN 'msg_employeur_reussite' ELSE 'msg_employeur_echec' END, f.mode, f.auteur, f.cible);
    IF v_corps <> '' THEN
      PERFORM public.mail_systeme_poser_interne('Événement', f.employeur, v_titre, v_corps, v_date); v_employeur := true;
    END IF;
    -- L'employeur porte plainte (§ 6) : contre l'auteur s'il était à visage découvert, sinon contre X.
    IF f.plainte_id IS NULL THEN
      v_cible_plainte := CASE WHEN f.mode = 'decouvert' THEN f.auteur ELSE 'X' END;
      SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = f.employeur;
      v_id := 'plainte-' || (extract(epoch from clock_timestamp()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 6);
      INSERT INTO public.plaintes_en_cours (id, country, city, data)
      VALUES (v_id, f.pays, coalesce(f.ville, 'capitale'), jsonb_build_object('id', v_id, 'auteur', f.employeur, 'cible', v_cible_plainte,
        'motif', coalesce(p ->> 'motif_plainte', f.acte) || ' (' || f.cible || ')', 'categorie_alleguee', NULL, 'jour', v_jour,
        'city', coalesce(f.ville, 'capitale'), 'country', f.pays, 'status', 'au_parquet', 'origine', 'crim_affaire', 'affaire', f.id,
        'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))::text);
      PERFORM public.dossier_acte_consigner(v_id, f.pays, coalesce(f.ville, 'capitale'), 'plainte_deposee', f.employeur, NULL, NULL, NULL,
        jsonb_build_object('cible', v_cible_plainte, 'affaire', f.id));
      UPDATE public.crim_affaires SET plainte_id = v_id, maj_le = now() WHERE id = f.id;
    END IF;
  END IF;
  RETURN jsonb_build_object('victime', v_victime, 'employeur', v_employeur, 'plainte', coalesce(v_id, f.plainte_id));
END $$;

-- Détection après une réussite (commune à la résolution immédiate et au combat gagné). Rend {detecte, identifie, trace, jours}.
CREATE OR REPLACE FUNCTION public.crim_detection_interne(p_affaire bigint, p_jet numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.crim_affaires%ROWTYPE; p jsonb; v_taux integer; v_u numeric; v_det boolean; v_ident boolean := false; v_jours integer;
BEGIN
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  p := f.details -> 'params';
  IF coalesce((p ->> 'detection')::boolean, true) IS NOT TRUE OR p ->> 'detection_base' IS NULL THEN
    RETURN jsonb_build_object('detecte', false, 'identifie', f.identifie, 'trace', f.trace, 'taux_detection', NULL);
  END IF;
  v_taux := public.crim_detection_taux_interne((p ->> 'detection_base')::numeric, f.mode, (p ->> 'detection_min')::numeric);
  v_u := coalesce(p_jet, random() * 100);
  v_det := v_u < v_taux;
  IF v_det THEN
    IF f.mode IN ('masque', 'cache_masque') THEN
      UPDATE public.crim_affaires SET detecte = true, trace = true, maj_le = now() WHERE id = f.id;
    ELSE
      v_ident := true;
      IF NOT f.identifie THEN
        v_jours := public.crim_identifier_interne(f.auteur, coalesce(p ->> 'acte_peine_reussite', f.acte), p ->> 'type_recherche');
        -- Règle existante de la détection : −10 DIS à l'auteur repéré.
        UPDATE public.personnages_donnees
           SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}',
                 to_jsonb(greatest(0, public.crim_stat_interne(f.auteur, 'dis', 50) - public.crim_param_interne('detection_identifie_dis', 10))))
         WHERE name = f.auteur;
      END IF;
      UPDATE public.crim_affaires SET detecte = true, identifie = true, trace = true, peine_jours = coalesce(v_jours, peine_jours), maj_le = now()
       WHERE id = f.id;
    END IF;
  END IF;
  RETURN jsonb_build_object('detecte', v_det, 'identifie', v_ident OR f.identifie, 'trace', v_det OR f.trace, 'taux_detection', v_taux,
                            'jet_detection', round(v_u, 2), 'peine_jours', coalesce(v_jours, f.peine_jours));
END $$;

-- ── LA résolution commune ───────────────────────────────────────────────────────────────────────────────────────
-- p_cible : nom de PJ ou id de PNJ (déjà résolu par crim_cible_resoudre_interne), ou NULL (lieu vide, bâtiment).
-- p_params (jsonb) — fournis par l'acte :
--   taux (obligatoire, avant dissuasion), min (0), max (100), dissuasion (true : #135 retranchée une fois ici),
--   reussite_auto (false : pas de jet de réussite, ex. lieu vide), critique_reussite_part (0), critique_sans_detection (false),
--   critique_echec_part (crim_parametres.echec_critique_part = 2), critique_identifie (true : échec critique sans masque = identifié),
--   combat (false), per_victime, garde (bool ; sinon calculé), detection (true), detection_base, detection_min,
--   remarque_echec (100 : % de chances que la victime remarque un échec ordinaire), acte_peine_reussite / acte_peine_echec
--   (clés du barème ; défaut = acte), type_recherche ('crime'), decouvert_identifie (true : visage découvert remarqué = identifié), mode (défaut crim_mode_action_interne), cible_info (jsonb),
--   titre_reussite, titre_echec, msg_reussite, msg_echec, msg_employeur_reussite, msg_employeur_echec ({Auteur} {auteur} {cible}),
--   motif_plainte, indices (jsonb : arme…), jets (tests seulement : {reussite, combat, detection, remarque} en 0-100).
-- Rend : ok, affaire, mode, taux, dissuasion, jet, reussi, reussite_critique, echec_critique, issue ('reussite' | 'echec' | 'combat'),
--   taux_combat, jet_combat, detecte, identifie, trace, peine_jours, remarque, notifie.
CREATE OR REPLACE FUNCTION public.crim_resoudre_interne(p_acte text, p_auteur text, p_cible text, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p jsonb := coalesce(p_params, '{}'::jsonb); j jsonb := coalesce(p_params -> 'jets', '{}'::jsonb); a record; ci jsonb;
  v_mode text; v_masque boolean; v_cache boolean; v_dis integer := 0; v_taux integer; v_u numeric; v_reussi boolean;
  v_crit_r boolean := false; v_crit_e boolean := false; v_part numeric; v_combat boolean := false; v_taux_c integer; v_u_c numeric;
  v_ident boolean := false; v_jours integer; v_remarque boolean := false; v_issue text; v_id bigint; v_det jsonb := '{}'::jsonb;
  v_notif jsonb := '{}'::jsonb; v_garde boolean; v_per numeric; v_plafond integer;
BEGIN
  IF p ->> 'taux' IS NULL AND coalesce((p ->> 'reussite_auto')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'crim_resoudre_interne : taux absent (%)', p_acte; END IF;
  SELECT name, country, current_city, current_building, current_room, coalesce(day, 1) AS jour, stats INTO a
    FROM public.personnages_donnees WHERE name = p_auteur;
  IF NOT FOUND THEN RAISE EXCEPTION 'crim_resoudre_interne : auteur inconnu %', p_auteur; END IF;
  ci := coalesce(p -> 'cible_info', '{}'::jsonb);
  v_mode := coalesce(p ->> 'mode', public.crim_mode_action_interne(p_auteur));
  v_masque := v_mode IN ('masque', 'cache_masque');
  v_cache := v_mode IN ('cache', 'cache_masque');

  -- 1. Jet de réussite (dissuasion des hommes armés #135 : une seule fois, ici).
  IF coalesce((p ->> 'reussite_auto')::boolean, false) THEN
    v_taux := 100; v_u := 0; v_reussi := true;
  ELSE
    IF coalesce((p ->> 'dissuasion')::boolean, true) THEN v_dis := coalesce(public.securite_malus_lieu_interne(p_auteur), 0); END IF;
    v_taux := greatest(coalesce((p ->> 'min')::numeric, 0), least(coalesce((p ->> 'max')::numeric, 100), (p ->> 'taux')::numeric - v_dis))::integer;
    v_u := coalesce((j ->> 'reussite')::numeric, random() * 100);
    v_reussi := v_u < v_taux;
    IF v_reussi THEN
      v_part := coalesce((p ->> 'critique_reussite_part')::numeric, 0);
      v_crit_r := v_part > 0 AND v_u < v_taux * v_part / 100.0;
    ELSE
      -- Échec critique : la part haute des échecs (2 % des échecs par défaut).
      v_part := coalesce((p ->> 'critique_echec_part')::numeric, public.crim_param_interne('echec_critique_part', 2));
      v_crit_e := v_part > 0 AND v_u >= 100 - (100 - v_taux) * v_part / 100.0;
    END IF;
  END IF;

  -- 2. Échec critique : −15 moral ; sans masque, identité révélée.
  IF v_crit_e THEN
    UPDATE public.personnages_donnees SET moral = greatest(0, coalesce(moral, 50) - public.crim_param_interne('echec_critique_moral', 15)::integer)
     WHERE name = p_auteur;
    IF NOT v_masque AND coalesce((p ->> 'critique_identifie')::boolean, true) THEN v_ident := true; END IF;
  END IF;

  -- 3. Passage au combat (échecs seulement ; avec masque, l'échec critique laisse aussi le jet normal décider).
  IF NOT v_reussi AND coalesce((p ->> 'combat')::boolean, false) AND p_cible IS NOT NULL THEN
    v_per := coalesce((p ->> 'per_victime')::numeric, (ci ->> 'per')::numeric, 10);
    v_garde := coalesce((p ->> 'garde')::boolean, public.crim_garde_cible_interne(
                 CASE WHEN coalesce((ci ->> 'pj')::boolean, true) THEN p_cible ELSE ci ->> 'employeur' END,
                 coalesce(ci ->> 'pays', a.country), coalesce(ci ->> 'ville', a.current_city),
                 coalesce(ci ->> 'batiment', a.current_building), coalesce(ci ->> 'piece', a.current_room)));
    v_taux_c := public.crim_combat_taux_interne(v_per, v_garde, v_cache);
    v_u_c := coalesce((j ->> 'combat')::numeric, random() * 100);
    v_combat := v_u_c < v_taux_c;
  END IF;

  -- 4. La victime remarque-t-elle l'échec ? (réussite : toujours, sauf réussite critique « sans détection »).
  IF v_reussi THEN
    v_remarque := NOT (v_crit_r AND coalesce((p ->> 'critique_sans_detection')::boolean, false));
  ELSIF v_combat OR v_crit_e OR v_ident THEN
    v_remarque := true;
  ELSE
    v_remarque := coalesce((j ->> 'remarque')::numeric, random() * 100) < coalesce((p ->> 'remarque_echec')::numeric, 100);
  END IF;
  IF p_cible IS NULL THEN v_remarque := false; END IF;
  -- À visage découvert, la victime connaît toujours son agresseur (§§ 1, 3) : identifié dès qu'elle s'aperçoit de l'acte
  -- (un combat le décidera à son issue).
  IF v_mode = 'decouvert' AND v_remarque AND NOT v_combat AND coalesce((p ->> 'decouvert_identifie')::boolean, true) THEN v_ident := true; END IF;

  v_issue := CASE WHEN v_reussi THEN 'reussite' WHEN v_combat THEN 'combat' ELSE 'echec' END;
  IF v_ident THEN
    v_jours := public.crim_identifier_interne(p_auteur,
      coalesce(p ->> CASE WHEN v_reussi THEN 'acte_peine_reussite' ELSE 'acte_peine_echec' END, p_acte), p ->> 'type_recherche');
  END IF;
  v_plafond := CASE WHEN v_reussi THEN public.crim_param_interne('plafond_enquete_reussite', 5)
                    ELSE public.crim_param_interne('plafond_enquete_echec', 15) END;

  -- 5. Affaire (lot 6 : plainte contre X, enquête du commissaire de la ville).
  INSERT INTO public.crim_affaires (acte, auteur, cible, cible_pnj, employeur, mode, pays, ville, batiment, piece, jour, issue,
      reussite_critique, echec_critique, identifie, trace, remarque, plafond_enquete, peine_jours, indices, details)
  VALUES (p_acte, p_auteur, CASE WHEN coalesce((ci ->> 'pj')::boolean, true) THEN p_cible ELSE coalesce(ci ->> 'nom', p_cible) END,
      CASE WHEN coalesce((ci ->> 'pj')::boolean, true) THEN NULL ELSE coalesce(ci ->> 'pnj_id', p_cible) END,
      CASE WHEN coalesce((ci ->> 'pj')::boolean, true) THEN NULL ELSE ci ->> 'employeur' END,
      v_mode, a.country, a.current_city, a.current_building, a.current_room, a.jour, v_issue,
      v_crit_r, v_crit_e, v_ident, v_ident, v_remarque, v_plafond, v_jours,
      coalesce(p -> 'indices', '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object('genre', a.stats ->> 'genre')),
      jsonb_build_object('params', p - 'jets' - 'cible_info', 'taux', v_taux, 'jet', round(v_u, 2), 'dissuasion', v_dis,
                         'taux_combat', v_taux_c, 'jet_combat', round(v_u_c, 2), 'garde', v_garde))
  RETURNING id INTO v_id;

  -- 6. Détection après réussite (sauf réussite critique « sans détection »).
  IF v_reussi AND NOT (v_crit_r AND coalesce((p ->> 'critique_sans_detection')::boolean, false)) THEN
    v_det := public.crim_detection_interne(v_id, (j ->> 'detection')::numeric);
  END IF;
  -- 7. Messages (victime ou employeur) et plainte de l'employeur ; un combat les reporte à son issue.
  IF v_issue <> 'combat' THEN v_notif := public.crim_affaire_notifier_interne(v_id, v_reussi); END IF;

  RETURN jsonb_build_object('ok', true, 'affaire', v_id, 'mode', v_mode, 'taux', v_taux, 'dissuasion', v_dis, 'jet', round(v_u, 2),
      'reussi', v_reussi, 'reussite_critique', v_crit_r, 'echec_critique', v_crit_e, 'issue', v_issue,
      'taux_combat', v_taux_c, 'jet_combat', round(v_u_c, 2), 'garde', v_garde,
      'detecte', coalesce((v_det ->> 'detecte')::boolean, false), 'taux_detection', (v_det ->> 'taux_detection')::integer,
      'identifie', v_ident OR coalesce((v_det ->> 'identifie')::boolean, false),
      'trace', v_ident OR coalesce((v_det ->> 'trace')::boolean, false),
      'peine_jours', coalesce(v_jours, (v_det ->> 'peine_jours')::integer),
      'remarque', v_remarque, 'notifie', v_notif);
END $$;

-- Suite d'une affaire passée au combat (ou dont le combat n'a pas pu s'ouvrir).
-- p_issue : 'vainqueur' (= réussite : détection, messages), 'vaincu' (= identifié), 'sans_combat' (= échec ordinaire).
CREATE OR REPLACE FUNCTION public.crim_resoudre_suite_interne(p_affaire bigint, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.crim_affaires%ROWTYPE; p jsonb; v_det jsonb := '{}'::jsonb; v_jours integer; v_notif jsonb;
BEGIN
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_introuvable'); END IF;
  IF f.issue <> 'combat' THEN RETURN jsonb_build_object('ok', true, 'deja', true, 'issue', f.issue); END IF;
  p := f.details -> 'params';
  IF p_issue = 'vainqueur' THEN
    UPDATE public.crim_affaires SET issue = 'combat_gagne', plafond_enquete = public.crim_param_interne('plafond_enquete_reussite', 5), maj_le = now()
     WHERE id = f.id;
    IF f.mode = 'decouvert' AND NOT f.identifie THEN   -- la victime l'a vu : identifié
      v_jours := public.crim_identifier_interne(f.auteur, coalesce(p ->> 'acte_peine_reussite', f.acte), p ->> 'type_recherche');
      UPDATE public.crim_affaires SET identifie = true, trace = true, peine_jours = v_jours, maj_le = now() WHERE id = f.id;
    END IF;
    v_det := public.crim_detection_interne(f.id, NULL);
    v_notif := public.crim_affaire_notifier_interne(f.id, true);
  ELSIF p_issue = 'vaincu' THEN
    IF NOT f.identifie THEN
      v_jours := public.crim_identifier_interne(f.auteur, coalesce(p ->> 'acte_peine_echec', f.acte), p ->> 'type_recherche');
    END IF;
    UPDATE public.crim_affaires SET issue = 'combat_perdu', identifie = true, trace = true, peine_jours = coalesce(v_jours, peine_jours), maj_le = now()
     WHERE id = f.id;
    v_notif := public.crim_affaire_notifier_interne(f.id, false);
  ELSE
    IF f.mode = 'decouvert' AND NOT f.identifie THEN
      v_jours := public.crim_identifier_interne(f.auteur, coalesce(p ->> 'acte_peine_echec', f.acte), p ->> 'type_recherche');
    END IF;
    UPDATE public.crim_affaires SET issue = 'echec', identifie = identifie OR f.mode = 'decouvert', trace = trace OR f.mode = 'decouvert',
           peine_jours = coalesce(v_jours, peine_jours), maj_le = now() WHERE id = f.id;
    v_notif := public.crim_affaire_notifier_interne(f.id, false);
  END IF;
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire;
  RETURN jsonb_build_object('ok', true, 'affaire', f.id, 'issue', f.issue, 'identifie', f.identifie, 'detecte', f.detecte, 'trace', f.trace,
                            'peine_jours', f.peine_jours, 'taux_detection', v_det -> 'taux_detection', 'notifie', v_notif);
END $$;

-- ── Neutraliser (§ 2) ───────────────────────────────────────────────────────────────────────────────────────────
-- Taux (formule historique, § 2 « formule actuelle conservée ») : base + 2 × stat (8 par défaut) + 15 carrière criminelle
-- − PER de la cible / 2 + 10 depuis la cachette − gilet revêtu (20 arme à feu, 5 sinon), borné 0 – plafond du mode.
CREATE OR REPLACE FUNCTION public.crim_neutraliser_taux_interne(p_mode text, p_stat numeric, p_criminel boolean, p_per_cible numeric,
                                                               p_cache boolean, p_gilet boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(CASE p_mode WHEN 'mains' THEN 15 WHEN 'arme' THEN 25 ELSE 35 END
         + 2 * coalesce(p_stat, 8)
         + CASE WHEN p_criminel THEN public.crim_param_interne('neutraliser_carriere', 15) ELSE 0 END
         - coalesce(p_per_cible, 10) / 2.0
         + CASE WHEN p_cache THEN public.crim_param_interne('neutraliser_cache', 10) ELSE 0 END
         - CASE WHEN p_gilet THEN CASE WHEN p_mode = 'feu' THEN public.crim_param_interne('neutraliser_gilet_feu', 20)
                                       ELSE public.crim_param_interne('neutraliser_gilet_autre', 5) END ELSE 0 END)::integer;
$$;

CREATE OR REPLACE FUNCTION public.crime_neutraliser(p_cible text, p_mode text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cible', p_cible, 'mode', p_mode); v jsonb; m record; ci jsonb;
  v_stat text; v_cap integer; v_pa integer; v_sous text[]; v_paie jsonb; v_dis numeric; v_taux integer; v_cache boolean; v_gilet boolean;
  v_det integer; r jsonb; v_comb jsonb; v_suite jsonb; v_cible_id text; v_arme text; v_out jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  CASE p_mode
    WHEN 'mains' THEN v_stat := 'FOR'; v_cap := 65; v_pa := 2; v_sous := NULL;
    WHEN 'arme'  THEN v_stat := 'DUP'; v_cap := 75; v_pa := 2; v_sous := ARRAY['blanche'];
    WHEN 'feu'   THEN v_stat := 'PER'; v_cap := 85; v_pa := 3; v_sous := ARRAY['poing', 'carabine'];
    ELSE RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END CASE;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_neutraliser', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, career, stats, inventory, resources, est_emprisonne, current_building INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  ci := public.crim_cible_resoudre_interne(a, p_cible);
  IF coalesce((ci ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN ci; END IF;
  v_cible_id := CASE WHEN (ci ->> 'pj')::boolean THEN ci ->> 'nom' ELSE ci ->> 'pnj_id' END;
  IF NOT (ci ->> 'pj')::boolean AND coalesce((ci ->> 'pa')::integer, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_indisponible'); END IF;
  IF EXISTS (SELECT 1 FROM public.groupe_participants_interne(a) g WHERE g.identifiant = v_cible_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'meme_groupe'); END IF;
  IF v_sous IS NOT NULL THEN
    SELECT i ->> 'name' INTO v_arme FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) i
     WHERE i ->> 'type' = 'arme' AND i ->> 'sousType' = ANY (v_sous) LIMIT 1;
    IF v_arme IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'arme_manquante'); END IF;
  END IF;

  v_paie := public.payer_ordre(a, 'neutraliser_' || p_mode, v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dis := public.crim_stat_interne(a, 'dis', 50);
  IF p_mode = 'feu' THEN   -- règle existante : le coup de feu coûte 20 de discrétion
    v_dis := greatest(0, v_dis - 20);
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}', to_jsonb(v_dis))
     WHERE name = a;
  END IF;

  v_cache := public.crim_cache_interne(a);
  v_gilet := (ci ->> 'pj')::boolean AND public.crim_objet_porte_interne(ci ->> 'nom', 'gilet');
  v_taux := public.crim_neutraliser_taux_interne(p_mode, public.crim_stat_interne(a, v_stat, 8), m.career = 'criminal_c',
                                                 (ci ->> 'per')::numeric, v_cache, v_gilet);
  SELECT detect_rate INTO v_det FROM public.actes_illegaux WHERE fn = 'assassiner_' || p_mode;
  r := public.crim_resoudre_interne('neutraliser', a, v_cible_id, jsonb_build_object(
    'taux', v_taux, 'min', 0, 'max', v_cap, 'combat', true, 'per_victime', (ci ->> 'per')::numeric,
    'detection_base', coalesce(v_det, CASE p_mode WHEN 'mains' THEN 30 WHEN 'arme' THEN 40 ELSE 60 END), 'detection_min', 5,
    'acte_peine_reussite', 'assassinat', 'acte_peine_echec', 'tentative_assassinat', 'type_recherche', 'crime', 'cible_info', ci,
    'titre_reussite', 'Agression', 'titre_echec', 'Tentative d''agression',
    'msg_reussite', 'Vous avez été neutralisé(e) par {auteur}. Vous êtes hors de combat et conduit(e) à l''hôpital.',
    'msg_echec', '{Auteur} a tenté de vous neutraliser.',
    'msg_employeur_reussite', 'Votre employé(e) {cible} a été neutralisé(e) par {auteur}. Hors service jusqu''à demain, il (elle) garde la marchandise. Une plainte a été déposée.',
    'msg_employeur_echec', '{Auteur} a tenté de neutraliser votre employé(e) {cible}. Une plainte a été déposée.',
    'motif_plainte', 'Agression de votre employé(e)',
    'indices', jsonb_build_object('arme', coalesce(v_arme, 'mains nues'), 'mode_arme', p_mode),
    'gilet_cible', v_gilet));

  IF r ->> 'issue' = 'reussite' THEN
    -- La victime tombe à 0 PA (hospitalisation par la règle existante) ; un PNJ est hors service jusqu'au lendemain.
    IF (ci ->> 'pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = 0 WHERE name = v_cible_id;
    ELSE
      PERFORM public.pnj_pa_fixer(ARRAY[v_cible_id], 0);
    END IF;
  ELSIF r ->> 'issue' = 'combat' THEN
    -- Combat (moteur existant inchangé). L'assassin s'est montré : il perd sa cachette, garde son masque.
    PERFORM public.crim_debusquer_interne(a, 'combat');
    IF NOT (ci ->> 'pj')::boolean AND NOT coalesce((ci ->> 'profil_combat')::boolean, false) THEN
      v_comb := jsonb_build_object('ok', false, 'raison', 'profil_combattant_incomplet');
    ELSE
      PERFORM set_config('rp.crim_neutraliser', 'on', true);
      v_comb := public.combat_ouvrir_interne(v_cible_id, p_mode, p_requete);
      PERFORM set_config('rp.crim_neutraliser', '', true);
    END IF;
    IF coalesce((v_comb ->> 'ok')::boolean, false) THEN
      UPDATE public.batailles SET contexte = contexte || jsonb_build_object('crim_affaire', (r ->> 'affaire')::bigint, 'crim_mode', r ->> 'mode')
       WHERE id = (v_comb ->> 'bataille')::bigint;
      UPDATE public.crim_affaires SET bataille = (v_comb ->> 'bataille')::bigint, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
      r := r || jsonb_build_object('bataille', (v_comb ->> 'bataille')::bigint, 'phase', v_comb ->> 'phase');
    ELSE
      -- Le combat n'a pas pu s'ouvrir (groupe dispersé, profil incomplet…) : échec ordinaire.
      v_suite := public.crim_resoudre_suite_interne((r ->> 'affaire')::bigint, 'sans_combat');
      r := r || jsonb_build_object('issue', 'echec', 'combat_refuse', v_comb ->> 'raison');
    END IF;
  END IF;

  -- Réponse à l'écran : jamais le nom d'une cible désignée par jeton.
  v_out := jsonb_build_object('ok', true, 'mode_arme', p_mode, 'cible_pj', (ci ->> 'pj')::boolean, 'dis', public.crim_stat_interne(a, 'dis', 50))
    || (r - 'notifie' - 'affaire' - 'garde')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_neutraliser', prm, v_out);
END $$;

-- Ancienne signature : l'écran doit passer une requête (idempotence) ; plus aucun affrontement sans jet.
CREATE OR REPLACE FUNCTION public.crime_neutraliser(p_cible text, p_mode text, p_per_pnj integer DEFAULT 10)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'requete_requise');
$$;

-- ── Raccords du combat (moteur inchangé : seule l'ouverture et l'issue civile sont branchées) ─────────────────────
-- 1. Garde d'installation : elle exigeait l'ancien crime_neutraliser « combat_universel_requis ».
SELECT pg_temp.rp_raccorder('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure,
  $a$OR NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.crime_neutraliser(text,text,integer)'::regprocedure AND position('combat_universel_requis' IN prosrc)>0)$a$,
  $b$OR to_regprocedure('public.crim_resoudre_interne(text,text,text,jsonb)') IS NULL /* crim_garde_installation_v1 */$b$,
  'crim_garde_installation_v1');
-- 2. Un affrontement contre une personne (PJ ou PNJ ordinaire) ne s'ouvre que depuis crime_neutraliser.
SELECT pg_temp.rp_raccorder('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure,
  $a$ BEGIN
  v:=public.combat_agression_preparer_interne(coalesce(cible,pnj),p_mode,10);$a$,
  $b$ IF terrain IS NULL AND (cible IS NOT NULL OR (pnj NOT LIKE 'faune:%' AND pnj NOT LIKE 'garde_acces:%'))
    AND coalesce(current_setting('rp.crim_neutraliser', true), '') <> 'on' THEN
  RETURN jsonb_build_object('ok',false,'raison','neutraliser_requis'); END IF; /* crim_neutraliser_jet_v1 */
 BEGIN
  v:=public.combat_agression_preparer_interne(coalesce(cible,pnj),p_mode,10);$b$,
  'crim_neutraliser_jet_v1');
-- 3. PA et DIS déjà prélevés par crime_neutraliser.
SELECT pg_temp.rp_raccorder('public.combat_agression_preparer_interne(text,text,integer)'::regprocedure,
  $a$IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(current_setting('rp.crim_neutraliser', true), '') = 'on' THEN RETURN jsonb_build_object('ok', true, 'deja_paye', true); END IF; /* crim_neutraliser_paye_v1 */$b$,
  'crim_neutraliser_paye_v1');
-- 4. Issue d'un combat né d'une neutralisation : résolution commune (vainqueur = réussite, vaincu = identifié).
SELECT pg_temp.rp_raccorder('public.combat_finaliser_interne(bigint)'::regprocedure,
  $a$ ELSE
  IF issue<>'defaite' THEN$a$,
  $b$ ELSIF b.contexte ? 'crim_affaire' THEN /* crim_combat_issue_v1 */
  v:=public.crim_resoudre_suite_interne((b.contexte->>'crim_affaire')::bigint,CASE WHEN issue='defaite' THEN 'vaincu' ELSE 'vainqueur' END)||jsonb_build_object('issue',issue);
 ELSE
  IF issue<>'defaite' THEN$b$,
  'crim_combat_issue_v1');

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_designation_interne(text,text,text)', 'crim_message_interne(text,text,text,text)',
    'crim_combat_taux_interne(numeric,boolean,boolean)', 'crim_detection_taux_interne(numeric,text,numeric)',
    'crim_peine_jours_interne(text,text)', 'crim_garde_cible_interne(text,text,text,text,text)', 'crim_cible_resoudre_interne(text,text)',
    'crim_identifier_interne(text,text,text)', 'crim_affaire_notifier_interne(bigint,boolean)', 'crim_detection_interne(bigint,numeric)',
    'crim_resoudre_interne(text,text,text,jsonb)', 'crim_resoudre_suite_interne(bigint,text)',
    'crim_neutraliser_taux_interne(text,numeric,boolean,numeric,boolean,boolean)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crime_neutraliser(text,text,uuid)', 'crime_neutraliser(text,text,integer)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
