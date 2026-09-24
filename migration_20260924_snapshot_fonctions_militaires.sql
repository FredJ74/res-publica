-- =====================================================================
-- SNAPSHOT DES FONCTIONS MILITAIRES — ÉTAT RÉELLEMENT DÉPLOYÉ
-- Date du relevé : 24 septembre 2026
-- Source : base Supabase de production (schéma public), lecture seule
--          via pg_get_functiondef() sur pg_proc.
-- =====================================================================
--
-- NATURE DE CE FICHIER
-- --------------------
-- Ce fichier est DESCRIPTIF, pas prescriptif. Il photographie le corps
-- des fonctions telles qu'elles tournaient en production au 24/09/2026.
-- Il N'EST PAS une migration à rejouer : il ne doit jamais être exécuté
-- tel quel sans vérification préalable, car il ne contient que des
-- CREATE OR REPLACE FUNCTION qui ÉCRASERAIENT sans avertissement toute
-- version plus récente déployée depuis. Le rejouer, c'est ramener la
-- base à l'état du 24/09/2026 pour ces 105 fonctions.
--
-- Il ne contient par ailleurs AUCUN des objets dont ces fonctions
-- dépendent : tables, vues, types, séquences, triggers, politiques RLS
-- et GRANT ne sont pas repris ici. Un rejeu sur une base vierge
-- échouerait.
--
-- POURQUOI IL EXISTE
-- ------------------
-- Avant ce fichier, le corps de ces fonctions n'existait dans Git que
-- dispersé à travers une vingtaine de migrations datées, et seulement
-- en partie : 51 des 105 fonctions apparaissaient dans au moins une
-- migration versionnée — et rien ne garantissait que la version qui s'y
-- trouvait soit encore celle qui tournait. Les 54 autres n'avaient
-- AUCUN corps dans le dépôt : elles n'existaient qu'en base. Une perte
-- ou un écrasement aurait été irrécupérable.
--
-- Ce fichier est le premier endroit du dépôt où l'état déployé se lit
-- d'un seul tenant, à une date connue.
--
-- PÉRIMÈTRE
-- ---------
-- Fonctions du schéma public dont le nom correspond à :
--   proname LIKE 'militaire\_%'
--   OR proname LIKE 'cellule%'
--   OR proname LIKE 'mutinerie\_%'
--   OR proname IN ('refectoire_repas', 'poste_est_atteste',
--                  'exiger_poste', 'detentions_pnj_liberer_echues')
--
-- NOMBRE EXACT DE FONCTIONS INCLUSES : 105
-- Ces 105 signatures correspondent EXACTEMENT au périmètre tel qu'il
-- était déployé à la fin du relevé — vérifié par comparaison terme à
-- terme des signatures avec pg_proc. Toutes sont des fonctions au sens
-- strict (prokind = 'f') : aucune procédure, aucune fonction d'agrégat
-- ou de fenêtrage.
--
-- UNE FONCTION A DISPARU PENDANT LE RELEVÉ
-- ----------------------------------------
-- militaire_arrieres_regler() existait encore au début du relevé et
-- n'existait plus à la fin : le commit a7e3ca1 du 24/09/2026 l'a
-- supprimée volontairement (DROP FUNCTION IF EXISTS). Elle est donc
-- ABSENTE de ce snapshot, à dessein — l'y laisser aurait fait de ce
-- fichier un moyen de la ressusciter par mégarde. Son corps reste
-- lisible dans l'historique Git (migrations de septembre).
--
-- ORDRE : alphabétique par nom de fonction, puis par oid en cas de
--         surcharge. Chaque fonction est précédée d'un séparateur
--         -- ========== <signature> ==========
--
-- POINT DE SÉCURITÉ À CONNAÎTRE
-- -----------------------------
-- 9 de ces fonctions sont exécutables par le rôle `anon` :
--   exiger_poste(text)
--   militaire_mutinerie_declencher()
--   militaire_ration_consommer()
--   militaire_reposer_section(text, text)
--   mutinerie_camp_de(text)
--   mutinerie_camps_presents(text, text, text, text)
--   mutinerie_est_camp(text)
--   mutinerie_pays_du_camp(text)
--   mutinerie_social_national(text)
-- =====================================================================

-- ========== cellule_alerter_ministre(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.cellule_alerter_ministre(p_cellule_id text, p_couverture text, p_sujet text, p_corps text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_destinataire text;
BEGIN
  SELECT c.pays_proprietaire INTO v_pays
    FROM public.cellules_renseignement c WHERE c.id = p_cellule_id;
  IF v_pays IS NULL THEN RETURN; END IF;

  -- Titulaire reel du poste : un PJ s'il y en a un, sinon le PNJ du registre.
  SELECT d.name INTO v_destinataire FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.poste ->> 'id' = 'min_def' LIMIT 1;
  IF v_destinataire IS NULL THEN
    SELECT t.nom_pnj INTO v_destinataire FROM public.titulaires_pnj t
     WHERE t.country = v_pays AND t.poste_id = 'min_def' LIMIT 1;
  END IF;
  IF v_destinataire IS NULL THEN RETURN; END IF;

  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6),
          'Service de renseignement', v_destinataire, p_sujet, p_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
END;
$function$


-- ========== cellule_rapports_mes_cellules(integer) ==========
CREATE OR REPLACE FUNCTION public.cellule_rapports_mes_cellules(p_limite integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x ->> 'jour' DESC), '[]'::jsonb) INTO v_res
    FROM (SELECT rc.contenu || jsonb_build_object('nb_faits', rc.nb_faits) AS x
            FROM public.rapports_cellules rc
            JOIN public.cellules_renseignement c ON c.id = rc.cellule_id
           WHERE c.pays_proprietaire = v_pays
           ORDER BY rc.jour DESC
           LIMIT greatest(1, least(coalesce(p_limite, 10), 60))) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'rapports', v_res);
END;
$function$


-- ========== cellule_renseignement_clore(text,text) ==========
CREATE OR REPLACE FUNCTION public.cellule_renseignement_clore(p_cellule_id text, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_statut text; v_evades integer := 0; v_disparus integer := 0; v_morts integer := 0;
BEGIN
  SELECT c.statut INTO v_statut FROM public.cellules_renseignement c
   WHERE c.id = p_cellule_id FOR UPDATE;
  IF v_statut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_introuvable');
  END IF;
  IF v_statut <> 'active' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'cellule_deja_close');
  END IF;

  SELECT count(*) INTO v_morts FROM public.agents_renseignement
   WHERE cellule_id = p_cellule_id AND statut = 'mort';

  -- Agents DETENUS : la detention est CLOTUREE, jamais supprimee. Le registre
  -- affichera donc « Evasion », et l'histoire de la detention reste lisible.
  WITH detenus AS (
    SELECT id, detention_id FROM public.agents_renseignement
     WHERE cellule_id = p_cellule_id AND statut = 'detenu'
  ), fermeture AS (
    UPDATE public.detentions d
       SET mode_fin = 'evasion',
           jour_fin_effective = public.jour_de_jeu_pays(d.country),
           date_fin_effective = now()
      FROM detenus x
     WHERE d.id = x.detention_id AND d.mode_fin IS NULL
    RETURNING d.id
  )
  SELECT count(*) INTO v_evades FROM fermeture;

  UPDATE public.agents_renseignement
     SET statut = 'disparu', leader_courant = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, maj_le = now()
   WHERE cellule_id = p_cellule_id AND statut IN ('actif', 'detenu');
  GET DIAGNOSTICS v_disparus = ROW_COUNT;

  UPDATE public.cellules_renseignement
     SET statut = CASE WHEN p_mode = 'echec_agents' THEN 'echec' ELSE 'terminee' END,
         mode_fin = p_mode, terminee_le = now()
   WHERE id = p_cellule_id;

  RETURN jsonb_build_object('ok', true, 'cellule', p_cellule_id, 'mode_fin', p_mode,
    'agents_disparus', v_disparus, 'evasions', v_evades, 'morts', v_morts);
END;
$function$


-- ========== cellule_renseignement_creer(text) ==========
CREATE OR REPLACE FUNCTION public.cellule_renseignement_creer(p_pays_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa   constant integer := 3;
  c_cout constant numeric := 500;
  v_nom text; v_poste text; v_pays text;
  v_pa integer; v_caisse text; v_mvt jsonb;
  v_cellule text; v_echeance timestamptz;
  v_nb_id integer; v_libres_h integer; v_libres_f integer;
  v_besoin_h integer; v_besoin_f integer;
  v_agents jsonb := '[]'::jsonb;
  r record; v_couv text; v_prec text; v_idx integer := 0;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF p_pays_cible IS NULL OR btrim(p_pays_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'couverture_absente'); END IF;

  SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles;
  IF v_nb_id < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identites_reelles_incompletes',
                              'definies', v_nb_id, 'attendues', 4); END IF;

  SELECT count(*) FILTER (WHERE sexe = 'H'), count(*) FILTER (WHERE sexe = 'F')
    INTO v_besoin_h, v_besoin_f FROM public.renseignement_identites_reelles;

  SELECT count(*) FILTER (WHERE c.sexe = 'H'), count(*) FILTER (WHERE c.sexe = 'F')
    INTO v_libres_h, v_libres_f
    FROM public.renseignement_couvertures c
   WHERE c.pays = p_pays_cible
     AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                      WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                        AND a.statut IN ('actif', 'detenu'));
  IF v_libres_h < v_besoin_h OR v_libres_f < v_besoin_f THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pool_couvertures_insuffisant',
      'libres_h', v_libres_h, 'requis_h', v_besoin_h,
      'libres_f', v_libres_f, 'requis_f', v_besoin_f); END IF;

  SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'disponibles', v_pa); END IF;

  v_caisse := v_pays || '_gouvernement-min_def';
  v_mvt := public.caisse_institution_mouvement(v_caisse, -c_cout, false);
  IF coalesce((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
      'caisse', v_caisse, 'requis', c_cout, 'detail', v_mvt ->> 'raison'); END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_nom;

  v_cellule  := 'cel-' || (extract(epoch from clock_timestamp())*1000)::bigint
                       || '-' || substr(md5(random()::text), 1, 6);
  v_echeance := now() + interval '10 days';

  INSERT INTO public.cellules_renseignement
    (id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le)
  VALUES (v_cellule, v_pays, p_pays_cible, v_nom, 'active', c_cout, v_caisse, v_echeance);

  FOR r IN SELECT role, vrai_nom, dup, sexe
             FROM public.renseignement_identites_reelles ORDER BY role
  LOOP
    SELECT a.nom_couverture INTO v_prec
      FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c2 ON c2.id = a.cellule_id
     WHERE a.role = r.role AND a.pays_couverture = p_pays_cible
       AND c2.pays_proprietaire = v_pays
     ORDER BY a.cree_le DESC LIMIT 1;

    SELECT c.nom INTO v_couv
      FROM public.renseignement_couvertures c
     WHERE c.pays = p_pays_cible
       AND c.sexe IS NOT DISTINCT FROM r.sexe
       AND c.nom IS DISTINCT FROM coalesce(v_prec, '')
       AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                        WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                          AND a.statut IN ('actif', 'detenu'))
     ORDER BY random() LIMIT 1;

    IF v_couv IS NULL THEN
      SELECT c.nom INTO v_couv
        FROM public.renseignement_couvertures c
       WHERE c.pays = p_pays_cible
         AND c.sexe IS NOT DISTINCT FROM r.sexe
         AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                          WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                            AND a.statut IN ('actif', 'detenu'))
       ORDER BY random() LIMIT 1;
    END IF;
    IF v_couv IS NULL THEN RAISE EXCEPTION 'pool_couvertures_epuise'; END IF;

    v_idx := v_idx + 1;
    INSERT INTO public.agents_renseignement
      (id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut, leader_courant)
    VALUES (v_cellule || '-a' || v_idx, v_cellule, r.role, r.vrai_nom, r.dup,
            p_pays_cible, v_couv, 'actif', v_nom);
    v_agents := v_agents || jsonb_build_array(jsonb_build_object(
      'role', r.role, 'vrai_nom', r.vrai_nom, 'couverture', v_couv,
      'sexe', r.sexe, 'dup', r.dup, 'statut', 'actif'));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'cellule', v_cellule, 'pays_couverture', p_pays_cible,
    'pays_cible', p_pays_cible, 'echeance', v_echeance, 'cout', c_cout, 'caisse', v_caisse,
    'pa_restants', v_pa - c_pa, 'agents', v_agents);
END;
$function$

-- ========== cellule_renseignement_mes_cellules() ==========
CREATE OR REPLACE FUNCTION public.cellule_renseignement_mes_cellules()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x ->> 'cree_le' DESC), '[]'::jsonb) INTO v_res
  FROM (
    SELECT jsonb_build_object(
      'cellule', c.id, 'pays_couverture', c.pays_cible, 'pays_cible', c.pays_cible,
      'statut', c.statut, 'mode_fin', c.mode_fin, 'cree_le', c.cree_le,
      'echeance', c.echeance_le, 'terminee_le', c.terminee_le,
      'agents', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                    'id', ag.id, 'role', ag.role, 'vrai_nom', ag.vrai_nom,
                    'couverture', ag.nom_couverture, 'dup', ag.dup, 'statut', ag.statut,
                    'leader', ag.leader_courant,
                    'pays', pe.pays, 'ville', pe.ville,
                    'batiment', pe.building_id, 'piece', pe.room_id,
                    'porte', pe.porte,
                    'au_bureau', public.agent_au_bureau_min_def(pe.building_id, pe.room_id),
                    'portrait', public.agent_portrait_chemin(ag.role, ag.pays_couverture))
                    ORDER BY ag.role), '[]'::jsonb)
                   FROM public.agents_renseignement ag
                   LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
                  WHERE ag.cellule_id = c.id)
    ) AS x
    FROM public.cellules_renseignement c
   WHERE c.pays_proprietaire = v_pays
  ) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'cellules', v_res);
END;
$function$


-- ========== cellule_renseignement_terminer(text) ==========
CREATE OR REPLACE FUNCTION public.cellule_renseignement_terminer(p_cellule_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_proprio text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  SELECT c.pays_proprietaire INTO v_proprio
    FROM public.cellules_renseignement c WHERE c.id = p_cellule_id;
  IF v_proprio IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_introuvable');
  END IF;
  IF v_proprio IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_d_un_autre_empire');
  END IF;
  -- Aucun remboursement : le cout n'est jamais rendu.
  RETURN public.cellule_renseignement_clore(p_cellule_id, 'volontaire');
END;
$function$


-- ========== cellules_rapports_generer() ==========
CREATE OR REPLACE FUNCTION public.cellules_rapports_generer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_faits jsonb; v_n integer := 0; v_nb integer;
BEGIN
  FOR c IN SELECT id, pays_proprietaire, pays_cible
             FROM public.cellules_renseignement WHERE statut = 'active'
  LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.rapports_cellules rc
                           WHERE rc.cellule_id = c.id AND rc.jour = v_jour);

    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'categorie', r.categorie, 'fait', r.contenu, 'source', r.source)
             ORDER BY r.categorie, r.created_at), '[]'::jsonb)
      INTO v_faits
      FROM public.renseignements_connus r
     WHERE r.titulaire = 'cellule:' || c.id
       AND (r.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour;

    INSERT INTO public.rapports_cellules (cellule_id, jour, contenu, nb_faits)
    VALUES (c.id, v_jour,
            jsonb_build_object('cellule', c.id, 'pays_cible', c.pays_cible,
                               'jour', v_jour, 'faits', v_faits),
            jsonb_array_length(v_faits))
    ON CONFLICT (cellule_id, jour) DO NOTHING;

    -- Le nombre est lu UNE fois et sert a la fois au chiffre et a l'accord.
    v_nb := jsonb_array_length(v_faits);

    PERFORM public.cellule_alerter_ministre(c.id, NULL,
      'Rapport de renseignement du ' || to_char(v_jour, 'DD/MM/YYYY'),
      'Le rapport quotidien de votre cellule ' || c.id ||
      ' est disponible dans votre Bureau du Ministre de la Défense, rubrique ' ||
      '« Renseignement militaire » → « Lire les rapports ». ' ||
      v_nb || CASE WHEN v_nb > 1 THEN ' faits consignés.' ELSE ' fait consigné.' END);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END;
$function$


-- ========== cellules_renseignement_balayer() ==========
CREATE OR REPLACE FUNCTION public.cellules_renseignement_balayer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_nat integer := 0; v_ech integer := 0;
BEGIN
  -- Echec : les quatre agents morts.
  FOR r IN SELECT c.id FROM public.cellules_renseignement c
            WHERE c.statut = 'active'
              AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                               WHERE a.cellule_id = c.id AND a.statut <> 'mort')
  LOOP
    PERFORM public.cellule_renseignement_clore(r.id, 'echec_agents');
    v_ech := v_ech + 1;
  END LOOP;

  -- Echeance atteinte.
  FOR r IN SELECT c.id FROM public.cellules_renseignement c
            WHERE c.statut = 'active' AND c.echeance_le <= now()
  LOOP
    PERFORM public.cellule_renseignement_clore(r.id, 'naturelle');
    v_nat := v_nat + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'fins_naturelles', v_nat, 'echecs', v_ech);
END;
$function$


-- ========== cellules_renseignement_collecter() ==========
CREATE OR REPLACE FUNCTION public.cellules_renseignement_collecter()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0; v_faits integer := 0; v_res jsonb; v_res2 jsonb;
BEGIN
  FOR r IN
    SELECT a.id, a.role FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c ON c.id = a.cellule_id
      LEFT JOIN LATERAL public.agent_position_effective(a.id) pe ON true
     WHERE c.statut = 'active' AND a.statut = 'actif'
       AND pe.ville IS NOT NULL AND pe.pays IS NOT NULL
       AND NOT public.agent_au_bureau_min_def(pe.building_id, pe.room_id)
  LOOP
    IF r.role = 'coordinateur' THEN
      v_res  := public.agent_coordinateur_multimodal(r.id);
      v_res2 := public.agent_coordinateur_port(r.id);
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0)
                         + coalesce((v_res2 ->> 'faits')::integer, 0);
    ELSE
      v_res := CASE r.role
        WHEN 'garde'      THEN public.agent_garde_observer(r.id)
        WHEN 'traducteur' THEN public.agent_traducteur_ecouter(r.id)
        WHEN 'conseiller' THEN public.agent_conseillere_observer(r.id)
      END;
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'agents', v_n, 'faits', v_faits);
END;
$function$


-- ========== detentions_pnj_liberer_echues() ==========
CREATE OR REPLACE FUNCTION public.detentions_pnj_liberer_echues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT d.id, d.country, a.id AS agent_id
      FROM public.detentions d
      JOIN public.agents_renseignement a ON a.detention_id = d.id
     WHERE d.provenance = 'agent_renseignement'
       AND d.mode_fin IS NULL
       AND d.jour_fin_effective IS NULL
       AND a.statut = 'detenu'
       AND a.detenu_depuis IS NOT NULL
       AND now() >= a.detenu_depuis + ((d.jour_fin - d.jour_debut) * interval '1 day')
  LOOP
    UPDATE public.detentions
       SET mode_fin = 'purgee', jour_fin_effective = public.jour_de_jeu_pays(r.country),
           date_fin_effective = now()
     WHERE id = r.id;
    UPDATE public.agents_renseignement
       SET statut = 'actif', detention_id = NULL, detenu_depuis = NULL, maj_le = now()
     WHERE id = r.agent_id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'liberations', v_n);
END;
$function$


-- ========== exiger_poste(text) ==========
CREATE OR REPLACE FUNCTION public.exiger_poste(p_poste text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text;
BEGIN
  -- Le serveur (cron, endpoints /api/*) traverse : il n'a pas de personnage.
  IF public.est_appel_serveur() THEN RETURN NULL; END IF;

  SELECT p.name, p.poste->>'id' INTO v_nom, v_poste
  FROM public.personnages_donnees p
  WHERE p.user_id = auth.uid()
  LIMIT 1;

  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'acteur_non_authentifie: aucun personnage rattache a ce compte'
      USING ERRCODE = '42501';
  END IF;
  IF v_poste IS DISTINCT FROM p_poste THEN
    RAISE EXCEPTION 'autorite_insuffisante: poste % requis, poste reel %',
      p_poste, coalesce(v_poste, '(aucun)') USING ERRCODE = '42501';
  END IF;
  RETURN v_nom;
END;
$function$


-- ========== militaire_accepter_capitaine(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_accepter_capitaine(p_nomination_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_n record; v_data jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'capitaine' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('capitaineNom', v_moi)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','capitaine','compagnieId', v_n.compagnie_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;
  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'capitaine', v_moi);
END; $function$

-- ========== militaire_accepter_lieutenant(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_accepter_lieutenant(p_nomination_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_n record; v_data jsonb; v_secs jsonb; v_trouve boolean := false;
  v_reserve jsonb; v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'lieutenant' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- Combien d'hommes la section compte-t-elle deja, et combien la reserve peut-elle en fournir ?
  SELECT count(*) INTO v_deja
    FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats', '[]'::jsonb)) sol
   WHERE s->>'id' = v_n.section_id;
  v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array'
                    THEN v_data->'reserve' ELSE '[]'::jsonb END;
  -- Jamais plus de 24 places : la limite est desormais APPLIQUEE cote serveur, elle n'etait
  -- jusqu'ici qu'une taille de lot pour la generation des matricules, verifiee nulle part.
  v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));

  SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
         coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
    INTO v_pris, v_reste
    FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = v_n.section_id AND COALESCE(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_moi,
                       'soldats', coalesce(s->'soldats', '[]'::jsonb) || v_pris)
                ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = v_n.section_id AND s->>'lieutenantNom' = v_moi) INTO v_trouve;
  IF NOT v_trouve THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_n.compagnie_id,
                                    'sectionId', v_n.section_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;

  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'section', v_n.section_id,
                            'hommes', v_tire, 'places', c_places,
                            'incomplete', (v_deja + v_tire) < c_places,
                            'reserve_restante', jsonb_array_length(v_reste));
END;
$function$


-- ========== militaire_affecter_leader(text,text,integer,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(p_compagnie_id text, p_section_id text, p_nb integer, p_leader text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_dispo int;
        v_mv text; v_mb text; v_mr text; v_lv text; v_lb text; v_lr text; v_pays_l text; v_pays_m text;
        v_membre boolean;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_leader,'')),'') = '' OR p_leader = g.o_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  SELECT current_city, current_building, current_room, country INTO v_mv, v_mb, v_mr, v_pays_m
    FROM public.personnages_donnees WHERE name = g.o_moi;
  SELECT current_city, current_building, current_room, country INTO v_lv, v_lb, v_lr, v_pays_l
    FROM public.personnages_donnees WHERE name = p_leader;
  IF v_pays_l IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable');
  END IF;
  IF v_pays_l IS DISTINCT FROM v_pays_m THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_juridiction');
  END IF;
  IF v_lv IS DISTINCT FROM v_mv OR v_lb IS DISTINCT FROM v_mb OR v_lr IS DISTINCT FROM v_mr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_absent');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  -- ------------------------------------------------------------------------------------------
  -- LA GARDE AJOUTEE : la cible doit etre un SOLDAT JOUEUR DE CETTE SECTION.
  -- Un soldat joueur vit dans le blob sous la forme { pj: true, nom: '...' }. Exiger pj = true
  -- exclut du meme coup les PNJ -- qui n'ont ni inventaire ni existence hors de la section --
  -- et l'absence de la cible dans soldats[] exclut les civils et les militaires d'une autre
  -- section, meme presents dans la piece.
  -- ------------------------------------------------------------------------------------------
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false) AND s->>'nom' = p_leader
  ) INTO v_membre;
  IF NOT v_membre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_section');
  END IF;

  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'leaderCourant' = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', p_leader) ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos, (sol->>'leaderCourant' = g.o_moi) AS avec,
                 row_number() OVER (PARTITION BY (sol->>'leaderCourant' = g.o_moi) ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'affectes', p_nb, 'leader', p_leader);
END;
$function$


-- ========== militaire_armurerie_transfert(text,text,text,integer,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_armurerie_transfert(p_compagnie_id text, p_section_id text, p_produit text, p_qte integer, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  g record; v_pays text; v_sec jsonb; v_stock jsonb; v_dispo int; v_mvt jsonb;
  v_pa int; v_paye jsonb;
BEGIN
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;
  IF COALESCE(p_qte, 0) <= 0 OR p_qte > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_sens NOT IN ('vers_section', 'vers_armurerie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;

  -- AUTORITE : le lieutenant de CETTE section. Refuse le capitaine, le commandant et tout autre.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT country, COALESCE(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  -- COUT DE L'ORDRE, verifie AVANT tout mouvement de stock : un refus doit etre lisible.
  IF COALESCE(v_pa, 0) < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'pa_reel', COALESCE(v_pa, 0));
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;

  IF p_sens = 'vers_section' THEN
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, -p_qte, NULL);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
    v_stock := v_stock || jsonb_build_object(p_produit,
                 GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0)) + p_qte);
  ELSE
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0));
    IF v_dispo < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'disponible', v_dispo);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_produit, v_dispo - p_qte);
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, p_qte, 'retour-' || p_section_id);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;

  -- PAIEMENT ATTESTE (miroir ordres_couts). En cas de refus, l'exception annule aussi le
  -- mouvement de stock : jamais d'armes transferees sans PA preleves.
  v_paye := public.payer_ordre(g.o_moi, 'repartir_armement', c_pa, 0);
  IF NOT COALESCE((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_armurerie_transfert: paiement refuse (%)',
      COALESCE(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'produit', p_produit, 'quantite', p_qte,
    'stock_armurerie', v_mvt->'stock', 'stock_section', v_stock->p_produit,
    'pa', v_paye->'pa', 'pa_preleves', c_pa);
END; $function$


-- ========== militaire_assigner_mission(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_assigner_mission(p_compagnie_id text, p_section_id text, p_mission text, p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_mission NOT IN ('bloquer_acces','securiser','assassiner','arreter','surveiller') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mission_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  -- cibleEscorte est retire de la section a chaque assignation : plus aucune mission ne l'utilise,
  -- et laisser trainer un champ mort ferait croire un jour qu'il veut encore dire quelque chose.
  v_sec := (v_sec - 'cibleEscorte') || jsonb_build_object('mission', p_mission);
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id, v_sec)
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'mission', p_mission);
END;
$function$


-- ========== militaire_bande_distance(text,text,text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bande_distance(p_pays_a text, p_ville_a text, p_bat_a text, p_pays_b text, p_ville_b text, p_bat_b text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b
     AND p_bat_a   IS NOT DISTINCT FROM p_bat_b   THEN 'proche'
    WHEN p_ville_a IS NOT DISTINCT FROM p_ville_b THEN 'moyenne'
    WHEN p_pays_a  IS NOT DISTINCT FROM p_pays_b  THEN 'longue'
    ELSE 'hors' END;
$function$


-- ========== militaire_bataille_actions(bigint,text,integer,boolean) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_actions(p_bataille_id bigint, p_camp_att text, p_round integer, p_surprise boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_res jsonb := '[]'::jsonb;
  a record; k integer; n integer; v_hostiles text[];
  d_eng bigint[]; d_pj boolean[]; d_nom text[]; d_cie text[]; d_sec text[]; d_mat text[];
  d_camp text[]; d_per numeric[]; d_dup numeric[]; d_tir numeric[]; d_cac numeric[];
  d_feu boolean[]; u_tir integer[]; u_cac integer[]; v_urne integer[];
  v_mode text; v_taux integer; v_jet integer; v_degre text;
BEGIN
  v_hostiles := public.militaire_camps_hostiles(p_bataille_id, p_camp_att);
  IF coalesce(array_length(v_hostiles, 1), 0) = 0 THEN RETURN v_res; END IF;

  SELECT array_agg(c.eng_id ORDER BY c.eng_id), array_agg(c.est_pj ORDER BY c.eng_id),
         array_agg(c.nom ORDER BY c.eng_id), array_agg(c.compagnie_id ORDER BY c.eng_id),
         array_agg(c.section_id ORDER BY c.eng_id), array_agg(c.matricule ORDER BY c.eng_id),
         array_agg(c.camp ORDER BY c.eng_id), array_agg(c.def_per ORDER BY c.eng_id),
         array_agg(c.def_dup ORDER BY c.eng_id), array_agg(c.comp_tir ORDER BY c.eng_id),
         array_agg(c.comp_cac ORDER BY c.eng_id), array_agg(c.arme_feu ORDER BY c.eng_id)
    INTO d_eng, d_pj, d_nom, d_cie, d_sec, d_mat, d_camp, d_per, d_dup, d_tir, d_cac, d_feu
    FROM (SELECT x.*, h.camp
            FROM unnest(v_hostiles) AS h(camp)
            CROSS JOIN LATERAL public.militaire_bataille_combattants(p_bataille_id, h.camp) x) c;
  n := coalesce(array_length(d_eng, 1), 0);
  IF n = 0 THEN RETURN v_res; END IF;

  -- Urne de base : un jeton par ennemi.
  SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO u_cac FROM generate_series(1, n) AS g(i);
  -- Urne des tireurs : un second jeton pour chaque ennemi au corps-a-corps.
  SELECT u_cac || coalesce(array_agg(i ORDER BY i), '{}') INTO u_tir
    FROM generate_series(1, n) AS g(i) WHERE NOT coalesce(d_feu[g.i], false);

  FOR a IN
    SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att)
     WHERE saute_round IS DISTINCT FROM p_round
  LOOP
    v_mode := CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END;
    v_urne := CASE WHEN a.arme_feu THEN u_tir ELSE u_cac END;
    k := v_urne[1 + floor(random() * array_length(v_urne, 1))::integer];

    -- La competence qui DEFEND est celle du meme domaine que l'attaque subie.
    v_taux := public.militaire_taux_combat(
      CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
      CASE WHEN a.arme_feu THEN d_tir[k]   ELSE d_cac[k]   END,
      CASE WHEN a.arme_feu THEN d_per[k]   ELSE d_dup[k]   END,
      a.bonus_arme);
    v_jet   := floor(random() * 100)::integer + 1;
    v_degre := public.militaire_degre_combat(v_taux, v_jet);

    IF coalesce(p_surprise, false) AND v_jet <> 1 THEN
      v_degre := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) + 1);
    END IF;

    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'camp_attaquant', p_camp_att,
      'att_eng', a.eng_id, 'att_pj', a.est_pj, 'att_nom', a.nom, 'att_mat', a.matricule,
      'att_arme', a.arme_cle, 'att_bonus', a.bonus_arme, 'att_groupe', a.groupe_id,
      'cib_eng', d_eng[k], 'cib_pj', d_pj[k], 'cib_nom', d_nom[k], 'cib_mat', d_mat[k],
      'cib_cie', d_cie[k], 'cib_sec', d_sec[k], 'cib_camp', d_camp[k],
      'mode', v_mode, 'taux', v_taux, 'jet', v_jet, 'degre', v_degre,
      'surprise', coalesce(p_surprise, false)));
  END LOOP;
  RETURN v_res;
END;
$function$


-- ========== militaire_bataille_appliquer(bigint,jsonb,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(p_bataille_id bigint, p_actions jsonb, p_round integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
  v_out jsonb := '[]'::jsonb; v_protege boolean;
  v_camp_mutin text; v_b record; v_ville_prison text; v_det jsonb;
BEGIN
  SELECT pays, ville INTO v_b FROM public.batailles WHERE id = p_bataille_id;

  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre'; v_protege := false;

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0, 'saute_suivant', true));
      CONTINUE;
    END IF;

    IF public.militaire_degats_pct(v_degre) = 0
       OR NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                       WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL) THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    IF v_pa IS NULL THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_protege := true;
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    v_out := v_out || jsonb_build_array(act || jsonb_build_object(
      'pa_avant', v_pa, 'pa_apres', v_new, 'perte', v_pa - v_new,
      'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre)));

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      v_camp_mutin := public.mutinerie_camp_de(act->>'cib_nom');
      IF v_camp_mutin IS NOT NULL THEN
        -- MUTIN NEUTRALISE : capture. La prison est ouverte par le chemin canonique du jeu, avec
        -- la peine de 7 jours ; le cycle carceral existant prend le relais.
        -- La caserne n'est pas une ville dotee d'une prison : on rabat sur la capitale.
        v_ville_prison := CASE WHEN coalesce(v_b.ville,'') IN ('', 'caserne') THEN 'capitale' ELSE v_b.ville END;
        v_det := public.detention_ouvrir_interne(act->>'cib_nom', 'Mutinerie', 7,
                   v_ville_prison, coalesce(v_b.pays, 'republic'),
                   jsonb_build_object('source', 'mutinerie', 'bataille', p_bataille_id),
                   'Armee reguliere', 'capture');
        UPDATE public.mutineries_membres SET statut = 'capture'
         WHERE personnage = act->>'cib_nom' AND camp = v_camp_mutin;
        UPDATE public.batailles_engagements
           SET sorti_round = p_round, etat_final = 'capture'
         WHERE id = (act->>'cib_eng')::bigint;
      ELSE
        UPDATE public.personnages_donnees
           SET current_city = 'caserne', current_building = 'caserne-militaire',
               current_room = 'infirmerie'
         WHERE name = act->>'cib_nom';
        UPDATE public.batailles_engagements
           SET sorti_round = p_round, etat_final = 'neutralise'
         WHERE id = (act->>'cib_eng')::bigint;
      END IF;
    ELSE
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$function$

-- ========== militaire_bataille_arbitrer_groupes(bigint,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_arbitrer_groupes(p_bataille_id bigint, p_round integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_attente integer := 0;
BEGIN
  FOR g IN SELECT * FROM public.batailles_groupes
            WHERE bataille_id = p_bataille_id AND sorti_round IS NULL
  LOOP
    -- Un groupe qui a deja tranche « replier » decroche.
    IF g.decision = 'replier' THEN
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;
    -- Un groupe qui a deja tranche « tenir » continue : rien a faire.
    IF g.decision = 'tenir' THEN CONTINUE; END IF;

    IF NOT public.militaire_groupe_sous_seuil(p_bataille_id, g.groupe_id) THEN
      CONTINUE;                                  -- pas encore a 50 % de pertes
    END IF;

    IF g.leader IS NULL THEN
      -- Groupe mene par un PNJ : repli automatique, sans attente.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;

    IF g.attente_depuis IS NULL THEN
      -- Ouverture de la fenetre de 90 secondes pour le chef PJ.
      UPDATE public.batailles_groupes SET attente_depuis = now()
       WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;
      v_attente := v_attente + 1;
    ELSIF now() - g.attente_depuis >= interval '90 seconds' THEN
      -- Delai ecoule sans reponse : repli automatique du groupe.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
    ELSE
      v_attente := v_attente + 1;                -- la fenetre court encore
    END IF;
  END LOOP;
  RETURN v_attente;
END;
$function$


-- ========== militaire_bataille_avancer(bigint) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_avancer(p_bataille_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE b record; v_attente integer; v_debout integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  -- Les fenetres echues se resolvent ici : un chef qui n'a pas repondu dans
  -- les 90 secondes voit son groupe decrocher.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, b.round_courant);

  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'camp_hors_combat',
           issue = CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                        ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                              WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
     WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', true, 'terminee', true, 'camps_debout', v_debout);
  END IF;

  IF v_attente > 0 THEN
    -- AUCUN ROUND NE PART tant qu'un chef a la main : la fenetre de decision
    -- ne se paie pas en morts.
    RETURN jsonb_build_object('ok', true, 'en_attente', v_attente,
      'raison', 'decision_en_attente', 'round', b.round_courant);
  END IF;

  RETURN public.militaire_bataille_round(p_bataille_id);
END;
$function$


-- ========== militaire_bataille_combattants(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
 RETURNS TABLE(eng_id bigint, est_pj boolean, nom text, compagnie_id text, section_id text, matricule text, pa integer, comp_tir numeric, comp_cac numeric, arme_feu boolean, arme_cle text, bonus_arme integer, def_per numeric, def_dup numeric, saute_round integer, groupe_id text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false, sol->>'nom', e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce((sol->>'pa')::integer, 0)),
         coalesce((sol->'formation'->>'tir')::numeric, 0),
         coalesce((sol->'formation'->>'combat_rapproche')::numeric, 0),
         coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette'),
         coalesce(sol->>'arme','corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sol->>'arme','corps_a_corps'),
           CASE WHEN coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.compagnies_militaires c ON c.id = e.compagnie_id
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND s->>'id' = e.section_id AND sol->>'matricule' = e.matricule;
$function$


-- ========== militaire_bataille_decider(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; b record; g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_decision NOT IN ('tenir','replier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  SELECT * INTO g FROM public.batailles_groupes
   WHERE bataille_id = p_bataille_id AND leader = v_moi AND sorti_round IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_groupe');
  END IF;

  UPDATE public.batailles_groupes
     SET decision = p_decision, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;

  IF p_decision = 'replier' THEN
    PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, b.round_courant);
  END IF;

  RETURN public.militaire_bataille_avancer(p_bataille_id)
         || jsonb_build_object('mon_groupe', g.groupe_id, 'ma_decision', p_decision);
END;
$function$


-- ========== militaire_bataille_decision_effective(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_decision_effective(p_bataille_id bigint, p_camp text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE b record; v_dec text; v_doc text; v_init integer; v_reste integer; v_repli jsonb;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;
  IF p_camp = b.camp_a THEN v_dec := b.decision_a; v_doc := b.doctrine_a;
                            v_init := b.effectif_initial_a; v_repli := b.repli_a;
                       ELSE v_dec := b.decision_b; v_doc := b.doctrine_b;
                            v_init := b.effectif_initial_b; v_repli := b.repli_b; END IF;
  IF v_dec IS NULL THEN
    IF v_doc = 'repli_50' THEN
      SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(p_bataille_id, p_camp);
      -- SEUIL CALCULE SUR L'EFFECTIF INITIAL DE CETTE BATAILLE, jamais recalcule round par round.
      v_dec := CASE WHEN v_reste * 2 <= coalesce(v_init, 0) THEN 'replier' ELSE 'continuer' END;
    ELSE
      v_dec := 'continuer';
    END IF;
  END IF;
  -- Un camp sans position de repli connue ne peut pas se replier : il tient, et le rapport le dit.
  IF v_dec = 'replier' AND v_repli IS NULL THEN v_dec := 'continuer'; END IF;
  RETURN v_dec;
END;
$function$


-- ========== militaire_bataille_decrocher_groupe(bigint,text,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_decrocher_groupe(p_bataille_id bigint, p_groupe_id text, p_round integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; v_repli jsonb; v_data jsonb; v_sec jsonb; v_sols jsonb; v_n integer := 0;
BEGIN
  SELECT g.repli INTO v_repli FROM public.batailles_groupes g
   WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id;
  IF v_repli IS NULL THEN RETURN 0; END IF;   -- sans position de repli, on tient

  FOR r IN SELECT e.* FROM public.batailles_engagements e
            WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
              AND e.sorti_round IS NULL
  LOOP
    IF r.personnage IS NOT NULL THEN
      UPDATE public.personnages_donnees
         SET current_city = v_repli->>'ville', current_building = v_repli->>'batiment',
             current_room = v_repli->>'piece'
       WHERE name = r.personnage;
    ELSE
      SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = r.compagnie_id FOR UPDATE;
      SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
       WHERE s->>'id' = r.section_id;
      CONTINUE WHEN v_sec IS NULL;
      SELECT coalesce(jsonb_agg(
               CASE WHEN sol->>'matricule' = r.matricule AND (sol->>'leaderCourant') IS NULL
                    THEN sol || jsonb_build_object('ville', v_repli->>'ville',
                                 'buildingId', v_repli->>'batiment', 'roomId', v_repli->>'piece')
                    ELSE sol END ORDER BY pos), '[]'::jsonb)
        INTO v_sols FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
          WITH ORDINALITY AS t(sol, pos);
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, r.section_id,
                      v_sec || jsonb_build_object('soldats', v_sols))
       WHERE id = r.compagnie_id;
    END IF;
    UPDATE public.batailles_engagements
       SET sorti_round = p_round, etat_final = 'replie' WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;

  UPDATE public.batailles_groupes
     SET sorti_round = p_round, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = p_groupe_id;
  RETURN v_n;
END;
$function$


-- ========== militaire_bataille_doctrine(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_doctrine(p_bataille_id bigint, p_doctrine text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object('ok', false, 'raison', 'doctrine_obsolete',
    'detail', 'Le repli se decide desormais groupe par groupe, a 50 % de pertes.');
$function$

-- ========== militaire_bataille_engager() ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; a record; v_id bigint; v_contact bigint; v_init text;
  v_camps text[]; v_camp text; v_na integer; v_total integer; v_mon_camp text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.services_militaires
                  WHERE personnage = v_moi AND fin_ts IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;
  IF EXISTS (SELECT 1 FROM public.batailles WHERE statut = 'en_cours'
              AND pays = a.country AND ville = a.current_city
              AND batiment = a.current_building AND piece = a.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_deja_en_cours');
  END IF;

  -- MON CAMP : mon camp mutin s'il existe, mon pays sinon. Jamais fourni par le client.
  v_mon_camp := coalesce(public.mutinerie_camp_de(v_moi), a.country);

  -- (a) ENNEMIS ETRANGERS : predicat d'origine, inchange. Reserve aux forces loyalistes ;
  --     une force mutine ne combat pas encore l'etranger (lot suivant).
  IF v_mon_camp = a.country THEN
    SELECT coalesce(array_agg(DISTINCT c.data->>'pays'), '{}') INTO v_camps
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM a.country
       AND sol->>'ville' = a.current_city AND sol->>'buildingId' = a.current_building
       AND sol->>'roomId' = a.current_room AND (sol->>'leaderCourant') IS NULL
       AND EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut = 'active'
                    AND ((g.data->>'attaquant' = a.country AND g.data->>'attaque' = c.data->>'pays')
                      OR (g.data->>'attaque'  = a.country AND g.data->>'attaquant' = c.data->>'pays')));
  ELSE
    v_camps := '{}';
  END IF;

  -- (b) ADVERSAIRES DU MEME PAYS : uniquement si une mutinerie separe reellement les deux camps.
  SELECT v_camps || coalesce(array_agg(c), '{}') INTO v_camps
    FROM unnest(public.mutinerie_camps_presents(a.country, a.current_city,
                                                a.current_building, a.current_room)) c
   WHERE c IS DISTINCT FROM v_mon_camp
     AND (public.mutinerie_est_camp(c) OR public.mutinerie_est_camp(v_mon_camp));

  IF coalesce(array_length(v_camps, 1), 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ennemi_ici');
  END IF;

  SELECT id INTO v_contact FROM public.contacts_militaires
   WHERE consomme_le IS NULL AND ville = a.current_city AND batiment = a.current_building
     AND ((pays_a = a.country AND pays_b = ANY(v_camps)) OR (pays_a = ANY(v_camps) AND pays_b = a.country))
   ORDER BY etabli_le DESC LIMIT 1;
  v_init := CASE WHEN v_contact IS NOT NULL THEN 'simultane' ELSE 'a' END;

  INSERT INTO public.batailles (pays, ville, batiment, piece, camp_a, camp_b, initiative,
                                leader_a, contact_id, statut, round_courant)
  VALUES (a.country, a.current_city, a.current_building, a.current_room, v_mon_camp, v_camps[1],
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, v_mon_camp, a.current_city, a.current_building, a.current_room);
  FOREACH v_camp IN ARRAY v_camps LOOP
    PERFORM public.militaire_bataille_recruter(v_id, v_camp, a.current_city, a.current_building, a.current_room);
  END LOOP;

  SELECT count(*) INTO v_na    FROM public.militaire_bataille_combattants(v_id, v_mon_camp);
  SELECT count(*) INTO v_total FROM public.batailles_engagements
   WHERE bataille_id = v_id AND camp <> v_mon_camp AND sorti_round IS NULL;
  IF v_na = 0 OR v_total = 0 THEN
    DELETE FROM public.batailles_engagements WHERE bataille_id = v_id;
    DELETE FROM public.batailles WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant',
      'mon_camp', v_na, 'adverse', v_total);
  END IF;

  PERFORM public.militaire_bataille_groupes_constituer(v_id);
  UPDATE public.batailles SET effectif_initial_a = v_na, effectif_initial_b = v_total,
         repli_a = public.militaire_position_repli(v_moi, a.current_city, a.current_building, a.current_room)
   WHERE id = v_id;

  IF v_contact IS NOT NULL THEN
    UPDATE public.contacts_militaires SET consomme_le = now(), bataille_id = v_id WHERE id = v_contact;
  END IF;

  RETURN jsonb_build_object('ok', true, 'bataille_id', v_id, 'initiative', v_init,
    'mon_camp', v_mon_camp, 'camps_adverses', v_camps, 'mon_effectif', v_na,
    'effectif_adverse', v_total,
    'groupes', (SELECT count(*) FROM public.batailles_groupes WHERE bataille_id = v_id));
END;
$function$


-- ========== militaire_bataille_etat(bigint) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_etat(p_bataille_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_id bigint; b record; g record; v_camp text; v_reste integer;
  v_rounds jsonb; v_hostiles text[]; v_secondes integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_bataille_id IS NULL THEN
    SELECT e.bataille_id INTO v_id FROM public.batailles_engagements e
      JOIN public.batailles bb ON bb.id = e.bataille_id
     WHERE e.personnage = v_moi AND bb.statut = 'en_cours'
     ORDER BY bb.debut_ts DESC LIMIT 1;
    IF v_id IS NULL THEN RETURN jsonb_build_object('ok', true, 'bataille', NULL); END IF;
  ELSE
    v_id := p_bataille_id;
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;

  v_camp := public.militaire_bataille_mon_camp(v_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;

  -- Mon groupe : celui ou je suis engage.
  SELECT gg.* INTO g FROM public.batailles_groupes gg
    JOIN public.batailles_engagements e
      ON e.bataille_id = gg.bataille_id AND e.groupe_id = gg.groupe_id
   WHERE gg.bataille_id = v_id AND e.personnage = v_moi LIMIT 1;

  v_hostiles := public.militaire_camps_hostiles(v_id, v_camp);
  SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(v_id, v_camp);
  SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb) INTO v_rounds
    FROM public.batailles_rounds r WHERE r.bataille_id = v_id AND r.camp = v_camp;

  v_secondes := CASE WHEN g.attente_depuis IS NULL THEN NULL
    ELSE greatest(0, 90 - extract(epoch FROM now() - g.attente_depuis))::integer END;

  RETURN jsonb_build_object('ok', true, 'bataille', jsonb_build_object(
    'id', b.id, 'statut', b.statut, 'round_courant', b.round_courant,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', v_camp, 'camps_adverses', v_hostiles,
    'camp_adverse', coalesce(v_hostiles[1], '—'),
    'mon_effectif_actuel', v_reste,
    -- Mon groupe, unite de decision
    'mon_groupe', g.groupe_id,
    'mon_groupe_effectif_initial', g.effectif_initial,
    'mon_groupe_restants', (SELECT count(*) FROM public.batailles_engagements e2
                             WHERE e2.bataille_id = v_id AND e2.groupe_id = g.groupe_id
                               AND e2.sorti_round IS NULL),
    'mon_effectif_initial', g.effectif_initial,
    'je_suis_leader', (g.leader IS NOT NULL AND g.leader = v_moi),
    'mon_chef', g.leader,
    'decision_attendue', (g.attente_depuis IS NOT NULL AND g.decision IS NULL),
    'secondes_restantes', v_secondes,
    'ma_decision', g.decision,
    'mon_groupe_replie', (g.sorti_round IS NOT NULL),
    'issue', b.issue, 'rounds', v_rounds));
END;
$function$


-- ========== militaire_bataille_groupes_constituer(bigint) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_groupes_constituer(p_bataille_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.batailles_groupes
    (bataille_id, groupe_id, camp, compagnie_id, section_id, leader, effectif_initial, repli)
  SELECT e.bataille_id, e.groupe_id, min(e.camp), min(e.compagnie_id), min(e.section_id),
         (SELECT p.personnage FROM public.batailles_engagements p
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL
           ORDER BY CASE p.grade WHEN 'commandant' THEN 1 WHEN 'capitaine' THEN 2
                                 WHEN 'lieutenant' THEN 3 ELSE 4 END, p.id LIMIT 1),
         count(*),
         coalesce(
           (SELECT public.militaire_position_repli(p.personnage, b.ville, b.batiment, b.piece)
              FROM public.batailles_engagements p
              JOIN public.batailles b ON b.id = p.bataille_id
             WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
               AND p.personnage IS NOT NULL LIMIT 1),
           jsonb_build_object('ville', 'caserne', 'batiment', 'caserne-militaire',
                              'piece', 'corps_garde'))
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
   GROUP BY e.bataille_id, e.groupe_id
  ON CONFLICT (bataille_id, groupe_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$


-- ========== militaire_bataille_mon_camp(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_mon_camp(p_bataille_id bigint, p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT e.camp FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id AND e.personnage = p_nom LIMIT 1;
$function$


-- ========== militaire_bataille_poursuivre(bigint) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre(p_bataille_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.militaire_bataille_mon_camp(p_bataille_id, v_moi) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_engage');
  END IF;
  RETURN public.militaire_bataille_avancer(p_bataille_id);
END;
$function$


-- ========== militaire_bataille_rapport(bigint,text,text,integer,jsonb,integer,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_rapport(p_bataille_id bigint, p_camp text, p_camp_adverse text, p_round integer, p_actions jsonb, p_reste_moi integer, p_reste_adverse integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b record; v_pa_perdus integer; v_touches integer; v_morts integer; v_neutralises integer;
  v_tombes_adverse integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;

  SELECT coalesce(sum(coalesce((a->>'perte')::integer, 0)), 0),
         count(*) FILTER (WHERE coalesce((a->>'perte')::integer, 0) > 0)
    INTO v_pa_perdus, v_touches
    FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
   WHERE a->>'cib_camp' = p_camp;

  SELECT count(*) FILTER (WHERE etat_final = 'mort'),
         count(*) FILTER (WHERE etat_final = 'neutralise')
    INTO v_morts, v_neutralises
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp = p_camp AND sorti_round = p_round;

  SELECT count(*) INTO v_tombes_adverse FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp <> p_camp AND sorti_round = p_round;

  RETURN jsonb_build_object(
    'round', p_round,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', p_camp,
    'mes_combattants_restants', p_reste_moi,
    'mes_pa_perdus', v_pa_perdus,
    'mes_combattants_touches', v_touches,
    'mes_morts_pnj', v_morts,
    'mes_pj_neutralises', v_neutralises,
    'adversaires_tombes', v_tombes_adverse,
    'adversaire_estime', CASE WHEN p_reste_adverse > 0
      THEN public.militaire_degrader('proche', p_reste_adverse, p_camp_adverse, b.ville, b.batiment)
      ELSE jsonb_build_object('libelle', 'plus aucun adversaire debout') END,
    'termine', (p_reste_moi = 0 OR p_reste_adverse = 0));
END;
$function$


-- ========== militaire_bataille_recruter(bigint,text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_mutin boolean; v_pays text;
BEGIN
  v_mutin := public.mutinerie_est_camp(p_camp);
  v_pays  := public.mutinerie_pays_du_camp(p_camp);

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa,
         p_camp || '|' || coalesce(sm.compagnie_id, 'solo') || ':' || coalesce(sm.section_id, pd.name)
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.current_city = p_ville AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
     AND pd.country = v_pays
     AND CASE WHEN v_mutin THEN public.mutinerie_camp_de(pd.name) = p_camp
                           ELSE public.mutinerie_camp_de(pd.name) IS NULL END
  ON CONFLICT DO NOTHING;

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, c.id, s->>'id', sol->>'matricule', 'soldat',
         (sol->>'pa')::integer, p_camp || '|' || c.id || ':' || (s->>'id')
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' = v_pays
     AND NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND CASE WHEN v_mutin THEN sol->>'mutin' = p_camp ELSE (sol->>'mutin') IS NULL END
     AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
           AND (sol->>'leaderCourant') IS NULL)
       OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                   WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                     AND chef.current_building = p_bat AND chef.current_room = p_piece))
  ON CONFLICT DO NOTHING;
END;
$function$

-- ========== militaire_bataille_round(bigint) ==========
CREATE OR REPLACE FUNCTION public.militaire_bataille_round(p_bataille_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b record; v_round integer; v_camps text[]; v_camp text; v_surprise text;
  v_actions jsonb := '[]'::jsonb; v_autres jsonb := '[]'::jsonb;
  v_reste integer; v_debout integer; v_issue text; v_attente integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_round := b.round_courant + 1;
  IF v_round > 200 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'borne_technique_atteinte', issue = NULL WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'borne_technique_atteinte', 'round', v_round);
  END IF;

  SELECT coalesce(array_agg(DISTINCT camp), '{}') INTO v_camps
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;

  -- SURPRISE : premier round, et seulement si l'engageant avait l'initiative.
  v_surprise := CASE WHEN v_round = 1 AND b.initiative = 'a' THEN b.camp_a ELSE NULL END;

  IF v_surprise IS NOT NULL THEN
    -- La passe du camp surprenant est calculee ET appliquee avant que les
    -- autres ne soient photographies : c'est cela, l'initiative.
    v_actions := public.militaire_bataille_actions(p_bataille_id, v_surprise, v_round, true);
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    FOREACH v_camp IN ARRAY v_camps LOOP
      CONTINUE WHEN v_camp = v_surprise;
      v_autres := v_autres || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_autres  := public.militaire_bataille_appliquer(p_bataille_id, v_autres, v_round);
    v_actions := v_actions || v_autres;
  ELSE
    -- Hors surprise, toutes les passes sont calculees AVANT toute
    -- application : c'est cela, la simultaneite.
    FOREACH v_camp IN ARRAY v_camps LOOP
      v_actions := v_actions || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
  END IF;

  -- Un rapport par camp encore present.
  FOREACH v_camp IN ARRAY v_camps LOOP
    SELECT count(*) INTO v_reste FROM public.batailles_engagements
     WHERE bataille_id = p_bataille_id AND camp = v_camp AND sorti_round IS NULL;
    INSERT INTO public.batailles_rounds (bataille_id, numero, camp, rapport)
    VALUES (p_bataille_id, v_round, v_camp,
            public.militaire_bataille_rapport(p_bataille_id, v_camp,
              coalesce((public.militaire_camps_hostiles(p_bataille_id, v_camp))[1], v_camp),
              v_round, v_actions, v_reste,
              (SELECT count(*)::integer FROM public.batailles_engagements
                WHERE bataille_id = p_bataille_id AND camp <> v_camp AND sorti_round IS NULL)))
    ON CONFLICT (bataille_id, numero, camp) DO NOTHING;
  END LOOP;

  UPDATE public.batailles SET round_courant = v_round WHERE id = p_bataille_id;

  -- Seuil de 50 %, fenetre de 90 s, replis automatiques.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);

  -- Fin : il ne reste qu'un camp debout, ou aucun.
  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    SELECT CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                      WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
      INTO v_issue;
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(), issue = v_issue,
           termine_raison = 'camp_hors_combat' WHERE id = p_bataille_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'round', v_round, 'surprise', v_surprise,
    'camps', v_camps, 'camps_debout', v_debout, 'groupes_en_attente', v_attente,
    'issue', v_issue, 'terminee', (v_debout <= 1));
END;
$function$


-- ========== militaire_bonus_arme(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_bonus_arme(p_cle text, p_mode text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT b.bonus FROM public.militaire_armes_bonus b
                    WHERE b.cle = p_cle AND b.mode = p_mode), 0);
$function$


-- ========== militaire_calepin() ==========
CREATE OR REPLACE FUNCTION public.militaire_calepin()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_periodes jsonb; v_total integer; v_comp jsonb;
  v_grade text; v_pays text; v_deco jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'),
         CASE WHEN jsonb_typeof(competences_militaires)='object' THEN competences_militaires ELSE '{}'::jsonb END
    INTO v_pays, v_comp FROM public.personnages_donnees WHERE name = v_moi;

  SELECT coalesce(jsonb_agg(p ORDER BY p_debut DESC), '[]'::jsonb), coalesce(sum(p_jours), 0)
    INTO v_periodes, v_total
    FROM (
      SELECT sm.debut_ts AS p_debut,
             greatest(1, (coalesce(sm.fin_ts, now())::date - sm.debut_ts::date) + 1) AS p_jours,
             jsonb_build_object(
               'grade', sm.grade, 'pays', sm.pays,
               'compagnie', sm.compagnie_id, 'section', sm.section_id,
               'debut', sm.debut_ts::date, 'fin', sm.fin_ts::date,
               'en_cours', sm.fin_ts IS NULL,
               'jours', greatest(1, (coalesce(sm.fin_ts, now())::date - sm.debut_ts::date) + 1)) AS p
        FROM public.services_militaires sm
       WHERE sm.personnage = v_moi) t;

  SELECT sm.grade INTO v_grade FROM public.services_militaires sm
   WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL ORDER BY sm.debut_ts DESC LIMIT 1;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'niveau', d.niveau, 'intitule', d.intitule, 'citation', d.citation,
           'decerne_par', d.decerne_par, 'poste', d.poste_decernant,
           'le', d.decerne_le::date) ORDER BY d.decerne_le DESC), '[]'::jsonb)
    INTO v_deco FROM public.decorations_militaires d WHERE d.decore = v_moi;

  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'pays', v_pays,
    'grade_courant', v_grade, 'en_service', v_grade IS NOT NULL,
    'jours_total', v_total, 'periodes', v_periodes, 'decorations', v_deco,
    'competences', jsonb_build_object(
      'combat_rapproche', coalesce((v_comp->>'combat_rapproche')::integer, 0),
      'tir',             coalesce((v_comp->>'tir')::integer, 0),
      'reconnaissance',  coalesce((v_comp->>'reconnaissance')::integer, 0),
      'secourisme',      coalesce((v_comp->>'secourisme')::integer, 0)));
END;
$function$


-- ========== militaire_camouflage_groupe(numeric,integer,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_camouflage_groupe(p_reco_moyenne numeric, p_effectif integer, p_equipes integer)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(p_reco_moyenne, 0)
       + CASE WHEN coalesce(p_effectif,0) > 0
              THEN 20.0 * least(1.0, greatest(0, coalesce(p_equipes,0))::numeric / p_effectif)
              ELSE 0 END
       + public.militaire_malus_taille(p_effectif);
$function$


-- ========== militaire_camps_hostiles(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_camps_hostiles(p_bataille_id bigint, p_camp text)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(array_agg(DISTINCT e.camp), '{}')
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
     AND e.sorti_round IS NULL
     AND e.camp IS DISTINCT FROM p_camp
     AND ( EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = p_camp AND g.data->>'attaque'  = e.camp)
                        OR (g.data->>'attaque'  = p_camp AND g.data->>'attaquant' = e.camp)))
        OR ( public.mutinerie_pays_du_camp(p_camp) = public.mutinerie_pays_du_camp(e.camp)
             AND (public.mutinerie_est_camp(p_camp) OR public.mutinerie_est_camp(e.camp)) ) );
$function$


-- ========== militaire_candidater_soldat(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_candidater_soldat(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays text; v_bat text; v_poste text;
  v_data jsonb; v_sec jsonb; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''), coalesce(poste->>'id','')
    INTO v_pays, v_bat, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- Presence reelle exigee, comme militaire_retrait et refectoire_repas : on s'engage a la caserne.
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF v_poste IN ('lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_officier', 'poste', v_poste);
  END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF coalesce(v_sec->>'lieutenantNom','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant'); END IF;

  -- Deja soldat quelque part ? On ne sert pas deux sections a la fois.
  IF EXISTS (SELECT 1 FROM public.compagnies_militaires c,
                    jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
                    jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
              WHERE coalesce((sol->>'pj')::boolean,false) AND sol->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soldat');
  END IF;

  -- Candidature active deja en cours pour ce meme PJ (tous statuts non finaux).
  IF EXISTS (SELECT 1 FROM public.engagements_militaires
              WHERE statut IN ('soldat_attente_lieutenant','soldat_liste_attente')
                AND data->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  v_id := 'engsold-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.engagements_militaires (id, statut, data)
  VALUES (v_id, 'soldat_attente_lieutenant', jsonb_build_object(
    'grade', 'soldat', 'nom', v_moi, 'pays', v_pays,
    'compagnieId', p_compagnie_id, 'sectionId', p_section_id,
    'lieutenantNom', v_sec->>'lieutenantNom', 'depuis', to_jsonb(now())));

  RETURN jsonb_build_object('ok', true, 'engagement', v_id,
                            'lieutenant', v_sec->>'lieutenantNom');
END; $function$


-- ========== militaire_candidature_traiter(text,boolean) ==========
CREATE OR REPLACE FUNCTION public.militaire_candidature_traiter(p_engagement_id text, p_accepter boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  g record; v_e record; v_nom text; v_sec jsonb; v_sols jsonb;
  v_total integer; v_pnj_pos integer; v_pnj jsonb; v_reserve jsonb;
BEGIN
  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  IF v_e.statut NOT IN ('soldat_attente_lieutenant','soldat_liste_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'engagement_deja_traite', 'statut', v_e.statut);
  END IF;

  -- AUTORITE : le Lieutenant structurel de la section visee, verifie sur la compagnie elle-meme.
  SELECT * INTO g FROM public.militaire_section_de_moi(v_e.data->>'compagnieId', v_e.data->>'sectionId');
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  v_nom := v_e.data->>'nom';
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  IF NOT coalesce(p_accepter, false) THEN
    UPDATE public.engagements_militaires SET statut = 'soldat_refuse' WHERE id = p_engagement_id;
    RETURN jsonb_build_object('ok', true, 'resultat', 'refuse', 'nom', v_nom);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = v_e.data->>'sectionId';
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_total := jsonb_array_length(v_sols);

  -- Deja dans la section ? Idempotence.
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_sols) s
              WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' = v_nom) THEN
    UPDATE public.engagements_militaires SET statut = 'soldat_accepte' WHERE id = p_engagement_id;
    RETURN jsonb_build_object('ok', true, 'resultat', 'deja_present', 'nom', v_nom);
  END IF;

  IF v_total < c_places THEN
    -- Place libre : le PJ l'occupe.
    v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_nom));
    v_reserve := CASE WHEN jsonb_typeof(g.o_data->'reserve') = 'array' THEN g.o_data->'reserve' ELSE '[]'::jsonb END;
  ELSE
    -- Section pleine : on cherche un PNJ a remplacer. Le premier venu.
    SELECT pos, sol INTO v_pnj_pos, v_pnj
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
     WHERE NOT coalesce((sol->>'pj')::boolean, false) ORDER BY pos LIMIT 1;
    IF v_pnj IS NULL THEN
      -- 24 PJ : personne n'est evince. Liste d'attente, le candidat reste civil.
      UPDATE public.engagements_militaires SET statut = 'soldat_liste_attente' WHERE id = p_engagement_id;
      RETURN jsonb_build_object('ok', true, 'resultat', 'liste_attente', 'nom', v_nom,
                                'places', c_places);
    END IF;
    -- Remplacement ATOMIQUE : le PNJ COMPLET retourne en reserve, avec son matricule et son
    -- entrainement. Aucune perte d'identite, aucun PNJ cree ni detruit.
    SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos) WHERE pos <> v_pnj_pos;
    v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_nom));
    v_reserve := (CASE WHEN jsonb_typeof(g.o_data->'reserve') = 'array' THEN g.o_data->'reserve' ELSE '[]'::jsonb END)
                 || jsonb_build_array(v_pnj);
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, v_e.data->>'sectionId',
                  v_sec || jsonb_build_object('soldats', v_sols))
                || jsonb_build_object('reserve', v_reserve)
   WHERE id = v_e.data->>'compagnieId';

  UPDATE public.engagements_militaires SET statut = 'soldat_accepte' WHERE id = p_engagement_id;
  PERFORM public.militaire_service_ouvrir(v_nom, g.o_data->>'pays', 'soldat',
            v_e.data->>'compagnieId', v_e.data->>'sectionId');

  RETURN jsonb_build_object('ok', true, 'resultat', 'accepte', 'nom', v_nom,
    'pnj_rendu_reserve', (v_pnj IS NOT NULL),
    'matricule_rendu', v_pnj->>'matricule',
    'effectif', jsonb_array_length(v_sols),
    'reserve', jsonb_array_length(v_reserve));
END; $function$


-- ========== militaire_chance_detection(numeric,numeric,integer,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_chance_detection(p_reco_observateur numeric, p_camouflage_cible numeric, p_modif_distance integer, p_bonus_jumelles integer DEFAULT 0)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT greatest(5, least(95, round(
    50 + coalesce(p_reco_observateur,0) - coalesce(p_camouflage_cible,0)
       + coalesce(p_modif_distance,0) + coalesce(p_bonus_jumelles,0))::integer));
$function$


-- ========== militaire_compagnie_creer() ==========
CREATE OR REPLACE FUNCTION public.militaire_compagnie_creer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_contingent constant integer := 96;
  c_sections   constant integer := 4;
  c_cout       constant numeric := 20000;
  c_pa         constant integer := 3;
  v_moi text; v_pays text; v_pa integer; v_id text; v_prefixe text;
  v_paye jsonb; v_caisse jsonb; v_sections jsonb; v_reserve jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic'), coalesce(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  v_caisse := public.caisse_institution_mouvement(v_pays || '_caserne-militaire', -c_cout, true);
  IF NOT coalesce((v_caisse->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false,
      'raison', coalesce(v_caisse->>'raison', 'caisse_refusee'), 'cout', c_cout);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'recruter_compagnie', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_compagnie_creer: paiement des PA refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  v_id := 'compagnie-' || v_pays || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text;
  v_prefixe := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYYMM');

  SELECT jsonb_agg(jsonb_build_object(
           'id', v_id || '-s' || i, 'numero', i, 'lieutenantNom', NULL,
           'soldats', '[]'::jsonb) ORDER BY i)
    INTO v_sections FROM generate_series(1, c_sections) AS g(i);

  SELECT jsonb_agg(jsonb_build_object(
           'matricule', v_prefixe || '-' || lpad(i::text, 3, '0'),
           'formation', jsonb_build_object('combat_rapproche', 0, 'tir', 0,
                                           'reconnaissance', 0, 'secourisme', 0),
           'arme', 'corps_a_corps',
           'ville', 'caserne', 'buildingId', 'caserne-militaire', 'roomId', 'corps_garde',
           'leaderCourant', NULL, 'pa', 12) ORDER BY i)
    INTO v_reserve FROM generate_series(1, c_contingent) AS g(i);

  INSERT INTO public.compagnies_militaires (id, data)
  VALUES (v_id, jsonb_build_object(
    'id', v_id, 'pays', v_pays, 'capitaineNom', NULL,
    'contingentInitial', c_contingent, 'reserve', v_reserve, 'sections', v_sections));

  RETURN jsonb_build_object('ok', true, 'compagnie', v_id, 'contingent', c_contingent,
                            'sections', c_sections, 'cout', c_cout, 'pa', v_paye->'pa');
END;
$function$


-- ========== militaire_competences(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_competences(p_nom text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
           'combat_rapproche', coalesce((competences_militaires->>'combat_rapproche')::numeric, 0),
           'tir',              coalesce((competences_militaires->>'tir')::numeric, 0),
           'reconnaissance',   coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
           'secourisme',       coalesce((competences_militaires->>'secourisme')::numeric, 0))
    FROM public.personnages_donnees WHERE name = p_nom;
$function$


-- ========== militaire_decorer(text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_decorer(p_decore text, p_intitule text, p_citation text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_poste text; v_niveau text; v_pays_moi text; v_pays_cible text; v_id bigint;
  v_intitule text; v_citation text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a;
  v_niveau := CASE v_poste WHEN 'commandant' THEN 'compagnie'
                           WHEN 'min_def'    THEN 'armee'
                           WHEN 'president'  THEN 'etat' END;
  IF v_niveau IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
      'poste', coalesce(v_poste, '(aucun)'));
  END IF;

  v_intitule := btrim(coalesce(p_intitule, ''));
  IF length(v_intitule) < 3 OR length(v_intitule) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'intitule_invalide');
  END IF;
  v_citation := nullif(btrim(coalesce(p_citation, '')), '');
  IF length(coalesce(v_citation, '')) > 600 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'citation_trop_longue');
  END IF;

  IF btrim(coalesce(p_decore,'')) = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auto_decoration_refusee');
  END IF;

  SELECT country INTO v_pays_moi   FROM public.personnages_donnees WHERE name = v_moi;
  SELECT country INTO v_pays_cible FROM public.personnages_donnees WHERE name = btrim(coalesce(p_decore,''));
  IF v_pays_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'decore_introuvable'); END IF;
  IF v_pays_cible IS DISTINCT FROM v_pays_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  BEGIN
    INSERT INTO public.decorations_militaires (decore, pays, niveau, intitule, citation, decerne_par, poste_decernant)
    VALUES (btrim(p_decore), v_pays_cible, v_niveau, v_intitule, v_citation, v_moi, v_poste)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_decernee');
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'decore', btrim(p_decore),
    'niveau', v_niveau, 'intitule', v_intitule, 'decerne_par', v_moi, 'poste', v_poste);
END;
$function$

-- ========== militaire_defense_pnj(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_defense_pnj(p_cle text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 8::numeric;
$function$


-- ========== militaire_degats_pct(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_degats_pct(p_degre text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_degre
    WHEN 'critique'    THEN 1.00
    WHEN 'partielle_1' THEN 0.75
    WHEN 'partielle_2' THEN 0.50
    ELSE                    0.00
  END;
$function$


-- ========== militaire_degrader(text,integer,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_degrader(p_bande text, p_effectif integer, p_pays text, p_ville text, p_batiment text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE p_bande
    -- Proche : lieu au batiment, nationalite sure, petite fourchette autour du reel.
    WHEN 'proche' THEN jsonb_build_object(
      'precision', 'proche', 'ville', p_ville, 'batiment', p_batiment,
      'nationalite', p_pays, 'nationalite_sure', true,
      'effectif_min', greatest(1, p_effectif - 1), 'effectif_max', p_effectif + 1,
      'libelle', (greatest(1, p_effectif - 1))::text || ' à ' || (p_effectif + 1)::text || ' soldats')
    -- Moyenne : lieu a la ville, nationalite sure, tranche de 5.
    WHEN 'moyenne' THEN jsonb_build_object(
      'precision', 'moyenne', 'ville', p_ville, 'batiment', NULL,
      'nationalite', p_pays, 'nationalite_sure', true,
      'effectif_min', greatest(1, (p_effectif / 5) * 5),
      'effectif_max', ((p_effectif / 5) + 1) * 5,
      'libelle', greatest(1, (p_effectif / 5) * 5)::text || ' à ' || (((p_effectif / 5) + 1) * 5)::text || ' hommes')
    -- Longue : lieu a la ville, nationalite INCERTAINE, effectif tres approximatif.
    WHEN 'longue' THEN jsonb_build_object(
      'precision', 'longue', 'ville', p_ville, 'batiment', NULL,
      'nationalite', p_pays, 'nationalite_sure', false,
      'effectif_min', NULL, 'effectif_max', NULL,
      'libelle', CASE WHEN p_effectif < 10 THEN 'moins de 10 hommes'
                      WHEN p_effectif < 30 THEN 'une dizaine d''hommes, peut-être plus'
                      ELSE 'plusieurs dizaines d''hommes' END)
    -- Au-dela : rien d'autre qu'un signe de vie. Ni effectif, ni nationalite.
    ELSE jsonb_build_object(
      'precision', 'limite', 'ville', p_ville, 'batiment', NULL,
      'nationalite', NULL, 'nationalite_sure', false,
      'effectif_min', NULL, 'effectif_max', NULL,
      'libelle', 'Mouvement de troupes possible dans ce secteur')
  END;
$function$


-- ========== militaire_degre_combat(integer,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_degre_combat(p_taux integer, p_jet integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_jet = 1 THEN 'echec_critique'
    ELSE (SELECT CASE
            WHEN s >= 95 THEN 'critique'
            WHEN s >= 70 THEN 'partielle_1'
            WHEN s >= 50 THEN 'partielle_2'
            WHEN s >= 10 THEN 'echec'
            ELSE                'echec_critique'
          END
          FROM (SELECT least(100, greatest(0,
                  p_jet + (coalesce(p_taux, 50) - 50) / 2.0)) AS s) x)
  END;
$function$


-- ========== militaire_degre_par_rang(integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_degre_par_rang(p_rang integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE greatest(0, least(4, coalesce(p_rang, 0)))
    WHEN 0 THEN 'echec_critique'
    WHEN 1 THEN 'echec'
    WHEN 2 THEN 'partielle_2'
    WHEN 3 THEN 'partielle_1'
    ELSE        'critique'
  END;
$function$


-- ========== militaire_degre_rang(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_degre_rang(p_degre text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_degre
    WHEN 'echec_critique' THEN 0
    WHEN 'echec'          THEN 1
    WHEN 'partielle_2'    THEN 2
    WHEN 'partielle_1'    THEN 3
    WHEN 'critique'       THEN 4
  END;
$function$


-- ========== militaire_demettre_lieutenant(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_demettre_lieutenant(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_data jsonb; v_secs jsonb; v_ancien text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie'); END IF;

  SELECT s->>'lieutenantNom' INTO v_ancien
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_ancien IS NULL OR v_ancien = '' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'section_deja_vacante'); END IF;

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id THEN s - 'lieutenantNom' ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);

  UPDATE public.compagnies_militaires SET data = v_data || jsonb_build_object('sections', v_secs)
   WHERE id = p_compagnie_id;
  UPDATE public.personnages_donnees SET poste = NULL, updated_at = now()
   WHERE name = v_ancien AND poste->>'id' = 'lieutenant'
     AND poste->>'compagnieId' = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'ancien_lieutenant', v_ancien, 'section', p_section_id);
END; $function$


-- ========== militaire_deposer_soldats(text,text,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_deposer_soldats(p_compagnie_id text, p_section_id text, p_nb integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  -- TRANSITION : le sentinel historique '__avec_lieutenant__' est encore ACCEPTE en lecture, pour
  -- qu'aucun soldat ne reste bloque s'il en portait un. Il n'est plus jamais ECRIT.
  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'leaderCourant' = g.o_moi OR s->>'roomId' = '__avec_lieutenant__';
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', NULL,
                         'ville', v_ville, 'buildingId', v_bat, 'roomId', v_room)
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos,
                 (sol->>'leaderCourant' = g.o_moi
                  OR sol->>'roomId' = '__avec_lieutenant__') AS avec,
                 row_number() OVER (PARTITION BY (sol->>'leaderCourant' = g.o_moi
                                    OR sol->>'roomId' = '__avec_lieutenant__') ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'deposes', p_nb,
                            'ville', v_ville, 'batiment', v_bat, 'piece', v_room);
END;
$function$


-- ========== militaire_desertions_verifier(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_desertions_verifier(p_pays text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pays text := coalesce(nullif(btrim(coalesce(p_pays, '')), ''), 'republic');
  v_maintenant numeric := floor(extract(epoch FROM now()) * 1000);
  c record; v_data jsonb; v_sec jsonb; v_liste jsonb;
  v_noms text[]; v_nouveaux jsonb := '[]'::jsonb;
BEGIN
  IF public.mon_personnage() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  FOR c IN SELECT id, data FROM public.compagnies_militaires
            WHERE data->>'pays' = v_pays FOR UPDATE LOOP
    v_data := c.data;
    FOR v_sec IN SELECT s FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s LOOP
      SELECT array_agg(e->>'nom') INTO v_noms
        FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e
       WHERE coalesce(e->>'statut', '') = 'convoque'
         AND (CASE WHEN (e->>'deadline') ~ '^[0-9]+(\.[0-9]+)?$'
                   THEN (e->>'deadline')::numeric ELSE NULL END) < v_maintenant;

      IF v_noms IS NOT NULL AND array_length(v_noms, 1) > 0 THEN
        SELECT coalesce(jsonb_agg(CASE WHEN e->>'nom' = ANY(v_noms)
                                       THEN e || jsonb_build_object('statut', 'deserteur') ELSE e END), '[]'::jsonb)
          INTO v_liste
          FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e;
        v_data := public.militaire_sections_remplacer(v_data, v_sec->>'id',
                    v_sec || jsonb_build_object('civilsRequisitionnes', v_liste));

        UPDATE public.personnages_donnees p
           SET requisition = jsonb_build_object('compagnieId', c.id, 'sectionId', v_sec->>'id',
                                                'statut', 'deserteur')
         WHERE p.name = ANY(v_noms);

        SELECT v_nouveaux || coalesce(jsonb_agg(jsonb_build_object(
                 'nom', n, 'compagnieId', c.id, 'sectionId', v_sec->>'id',
                 'section', v_sec->>'numero')), '[]'::jsonb)
          INTO v_nouveaux FROM unnest(v_noms) n;
      END IF;
    END LOOP;
    IF v_data IS DISTINCT FROM c.data THEN
      UPDATE public.compagnies_militaires SET data = v_data WHERE id = c.id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'deserteurs', v_nouveaux);
END;
$function$


-- ========== militaire_detachement_ici() ==========
CREATE OR REPLACE FUNCTION public.militaire_detachement_ici()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; v_out jsonb := '[]'::jsonb; r record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  FOR r IN
    SELECT c.data->>'pays' AS pays, c.id AS compagnie_id, s->>'id' AS section_id,
           s->>'lieutenantNom' AS lieutenant, s->>'mission' AS mission,
           count(*)::integer AS effectif
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE sol->>'ville' = a.current_city
       AND sol->>'buildingId' = a.current_building
       AND sol->>'roomId' = a.current_room
       AND (sol->>'leaderCourant') IS NULL
     GROUP BY 1,2,3,4,5
  LOOP
    IF r.pays = a.country THEN
      -- Mes propres troupes : je les vois telles qu'elles sont.
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', true, 'compagnie_id', r.compagnie_id,
        'section_id', r.section_id, 'lieutenant', r.lieutenant,
        'mission', r.mission, 'effectif', r.effectif));
    ELSE
      -- Troupe etrangere : meme degradation que la reconnaissance. Ni effectif
      -- exact, ni mission, ni identite d'officier.
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'pays', r.pays, 'mien', false,
        'estime', public.militaire_degrader('proche', r.effectif, r.pays,
                    a.current_city, a.current_building)));
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'detachements', v_out);
END;
$function$


-- ========== militaire_engagement_affecter_compagnie(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_engagement_affecter_compagnie(p_engagement_id text, p_compagnie_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_e record; v_cie jsonb;
BEGIN
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  -- ETAT PRECEDENT verifie : on ne saute pas une etape et on ne rejoue pas.
  IF v_e.statut <> 'attente_commandant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'statut', v_e.statut);
  END IF;
  IF v_e.data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT data INTO v_cie FROM public.compagnies_militaires WHERE id = p_compagnie_id;
  IF v_cie IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_cie->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  UPDATE public.engagements_militaires
     SET statut = 'attente_capitaine',
         data = data || jsonb_build_object('compagnieId', p_compagnie_id, 'parCommandant', v_moi)
   WHERE id = p_engagement_id;
  RETURN jsonb_build_object('ok', true, 'statut', 'attente_capitaine', 'compagnie', p_compagnie_id);
END; $function$

-- ========== militaire_engagement_affecter_section(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_engagement_affecter_section(p_engagement_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_pays text; v_e record; v_data jsonb; v_secs jsonb; v_nom text;
  v_reserve jsonb; v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb; v_ok boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  IF v_e.statut <> 'attente_capitaine' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'statut', v_e.statut);
  END IF;
  v_nom := v_e.data->>'nom';

  SELECT data INTO v_data FROM public.compagnies_militaires
   WHERE id = v_e.data->>'compagnieId' FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  -- AUTORITE : le Capitaine de CETTE compagnie, et personne d'autre.
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  -- Meme regle de contingent que militaire_accepter_lieutenant : la section se peuple depuis la
  -- reserve, sans jamais depasser 24, et peut naitre incomplete.
  SELECT count(*) INTO v_deja
    FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE s->>'id' = p_section_id;
  v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve')='array' THEN v_data->'reserve' ELSE '[]'::jsonb END;
  v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));
  SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
         coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
    INTO v_pris, v_reste FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

  SELECT coalesce(jsonb_agg(
           CASE WHEN s->>'id' = p_section_id AND coalesce(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_nom,
                       'soldats', coalesce(s->'soldats','[]'::jsonb) || v_pris)
                ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = p_section_id AND s->>'lieutenantNom' = v_nom) INTO v_ok;
  IF NOT v_ok THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
   WHERE id = v_e.data->>'compagnieId';
  -- LE POSTE DU CANDIDAT, ecrit ICI. C'est ce que le client ne pouvait plus faire.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','name','Lieutenant',
                   'compagnieId', v_e.data->>'compagnieId', 'sectionId', p_section_id),
         updated_at = now()
   WHERE name = v_nom;
  UPDATE public.engagements_militaires
     SET statut = 'affecte', data = data || jsonb_build_object('sectionId', p_section_id, 'parCapitaine', v_moi)
   WHERE id = p_engagement_id;

  RETURN jsonb_build_object('ok', true, 'statut', 'affecte', 'nom', v_nom,
    'section', p_section_id, 'hommes', v_tire, 'incomplete', (v_deja + v_tire) < c_places);
END; $function$


-- ========== militaire_engagement_creer() ==========
CREATE OR REPLACE FUNCTION public.militaire_engagement_creer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(poste->>'id','')
    INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_poste IN ('lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_officier');
  END IF;
  IF EXISTS (SELECT 1 FROM public.engagements_militaires
              WHERE statut IN ('attente_commandant','attente_capitaine')
                AND data->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  v_id := 'eng-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.engagements_militaires (id, statut, data)
  VALUES (v_id, 'attente_commandant',
          jsonb_build_object('pays', v_pays, 'nom', v_moi, 'depuis', to_jsonb(now())));
  RETURN jsonb_build_object('ok', true, 'engagement', v_id, 'pays', v_pays);
END; $function$


-- ========== militaire_entrainer_section(text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_entrainer_section(p_compagnie_id text, p_section_id text, p_stat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_max     constant integer := 12;
  c_pa      constant integer := 6;
  c_gain    constant integer := 3;
  c_plafond constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_pa_chef integer;
  v_elus_pnj jsonb; v_elus_pj jsonb; v_n integer; v_nom text;
BEGIN
  IF p_stat NOT IN ('combat_rapproche','tir','reconnaissance','secourisme') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'domaine_invalide', 'domaine', p_stat);
  END IF;

  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT coalesce(pa, 0) INTO v_pa_chef FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;
  IF v_pa_chef < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_chef_insuffisants',
                              'requis', c_pa, 'pa_reel', v_pa_chef);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- SELECTION COMMUNE PJ + PNJ : les moins formes d'abord dans ce domaine, jusqu'a 12 au total.
  -- Ne participent que ceux qui ont REELLEMENT leurs 6 PA -- les PA d'un PNJ vivent dans le blob,
  -- ceux d'un PJ sur sa fiche. Personne n'est debite sans progresser, ni l'inverse.
  CREATE TEMP TABLE IF NOT EXISTS pg_temp_elus (nom text, matricule text, est_pj boolean, niveau numeric) ON COMMIT DROP;
  DELETE FROM pg_temp_elus;

  INSERT INTO pg_temp_elus (nom, matricule, est_pj, niveau)
  SELECT NULL, sol->>'matricule', false, coalesce((sol->'formation'->>p_stat)::numeric, 0)
    FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::numeric, 0) >= c_pa
     AND coalesce(sol->>'matricule', '') <> ''
  UNION ALL
  SELECT pd.name, NULL, true, coalesce((pd.competences_militaires->>p_stat)::numeric, 0)
    FROM jsonb_array_elements(v_sols) sol
    JOIN public.personnages_donnees pd ON pd.name = sol->>'nom'
   WHERE coalesce((sol->>'pj')::boolean, false) AND coalesce(pd.pa, 0) >= c_pa;

  DELETE FROM pg_temp_elus WHERE ctid NOT IN (
    SELECT ctid FROM pg_temp_elus ORDER BY niveau, coalesce(matricule, nom) LIMIT c_max);

  SELECT count(*) INTO v_n FROM pg_temp_elus;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_en_etat', 'pa_requis', c_pa);
  END IF;

  SELECT coalesce(jsonb_agg(matricule), '[]'::jsonb) INTO v_elus_pnj FROM pg_temp_elus WHERE NOT est_pj;
  SELECT coalesce(jsonb_agg(nom), '[]'::jsonb)       INTO v_elus_pj  FROM pg_temp_elus WHERE est_pj;

  -- PNJ : debit et gain dans la meme ecriture du blob.
  SELECT coalesce(jsonb_agg(
           CASE WHEN v_elus_pnj ? (sol->>'matricule')
                THEN sol || jsonb_build_object('pa', coalesce((sol->>'pa')::numeric, 0) - c_pa)
                         || jsonb_build_object('formation',
                              coalesce(CASE WHEN jsonb_typeof(sol->'formation') = 'object'
                                            THEN sol->'formation' END, '{}'::jsonb)
                              || jsonb_build_object(p_stat, least(c_plafond,
                                   coalesce((sol->'formation'->>p_stat)::numeric, 0) + c_gain)))
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- PJ participants : leurs PA sont sur leur fiche, leurs competences dans la colonne dediee.
  FOR v_nom IN SELECT nom FROM pg_temp_elus WHERE est_pj LOOP
    UPDATE public.personnages_donnees
       SET pa = greatest(0, coalesce(pa, 0) - c_pa),
           competences_militaires = coalesce(competences_militaires, '{}'::jsonb)
             || jsonb_build_object(p_stat, least(c_plafond,
                  coalesce((competences_militaires->>p_stat)::numeric, 0) + c_gain))
     WHERE name = v_nom;
  END LOOP;

  -- Le Lieutenant paie sa seance. Un debit, jamais une remise a une valeur pleine.
  UPDATE public.personnages_donnees SET pa = v_pa_chef - c_pa WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'domaine', p_stat, 'progresses', v_n,
    'pnj', jsonb_array_length(v_elus_pnj), 'pj', jsonb_array_length(v_elus_pj),
    'gain', c_gain, 'plafond', c_plafond, 'pa_soldat', c_pa, 'pa_chef', c_pa,
    'pa_restants_chef', v_pa_chef - c_pa, 'matricules', v_elus_pnj, 'joueurs', v_elus_pj);
END;
$function$


-- ========== militaire_entree_zone() ==========
CREATE OR REPLACE FUNCTION public.militaire_entree_zone()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_piece text;
  v_jour text; v_zone text; v_cle text; v_garde_posee boolean := false;
  v_reco numeric; v_jumelles boolean;
  v_mes_pnj integer; v_ma_reco numeric; v_mes_equipes integer; v_mon_effectif integer;
  v_militaire boolean; v_contacts jsonb := '[]'::jsonb; v_mutuels integer := 0;
  r record; v_bande text; v_modif integer;
  v_camo_eux numeric; v_camo_moi numeric;
  v_chance_moi integer; v_chance_eux integer; v_vu_par_moi boolean; v_vu_par_eux boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(current_room,''), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_piece, v_reco, v_jumelles
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  SELECT count(*)::integer,
         coalesce(avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)), 0),
         count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
            WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer
    INTO v_mes_pnj, v_ma_reco, v_mes_equipes
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE sol->>'leaderCourant' = v_moi;

  v_militaire := EXISTS (SELECT 1 FROM public.services_militaires sm
                          WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL);

  IF coalesce(v_mes_pnj,0) = 0 AND NOT v_militaire THEN
    RETURN jsonb_build_object('ok', true, 'force', false, 'contacts', '[]'::jsonb);
  END IF;
  v_mon_effectif := coalesce(v_mes_pnj,0) + 1;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_zone := v_pays || '/' || v_ville || '/' || v_bat || '/' || v_piece;
  v_cle  := v_moi || ':' || v_jour || ':' || v_zone;

  FOR r IN
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS piece,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes,
           bool_or(EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'jumelles')) AS a_jumelles
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM v_pays
       AND sol->>'ville' = v_ville
       AND (sol->>'leaderCourant') IS NULL
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = c.data->>'pays')
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = c.data->>'pays')))
     GROUP BY 1, 2, 3, 4
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    CONTINUE WHEN v_modif IS NULL;

    -- GARDE PARESSEUSE : posee ici, juste avant le PREMIER jet reel, et une seule fois.
    IF NOT v_garde_posee THEN
      BEGIN
        INSERT INTO public.militaire_detections (id, personnage, jour, zone)
        VALUES (v_cle, v_moi, v_jour, v_zone);
        v_garde_posee := true;
      EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('ok', true, 'force', true, 'deja_sonde', true,
          'contacts', '[]'::jsonb);
      END;
    END IF;

    v_camo_eux := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_camo_moi := public.militaire_camouflage_groupe(v_ma_reco, v_mon_effectif, v_mes_equipes);

    v_chance_moi := public.militaire_chance_detection(
      v_reco, v_camo_eux, v_modif, CASE WHEN v_jumelles THEN c_bonus_jumelles ELSE 0 END);
    v_chance_eux := public.militaire_chance_detection(
      r.reco_moy, v_camo_moi, v_modif, CASE WHEN coalesce(r.a_jumelles,false) THEN c_bonus_jumelles ELSE 0 END);

    v_vu_par_moi := (floor(random() * 100)::integer + 1) <= v_chance_moi;
    v_vu_par_eux := (floor(random() * 100)::integer + 1) <= v_chance_eux;

    IF v_vu_par_moi THEN
      v_contacts := v_contacts || jsonb_build_array(
        public.militaire_degrader(v_bande, r.effectif, r.pays_cible, r.ville, r.bat));
    END IF;

    IF v_vu_par_moi AND v_vu_par_eux THEN
      INSERT INTO public.contacts_militaires (pays_a, pays_b, ville, batiment, piece, effectif_a, effectif_b)
      VALUES (v_pays, r.pays_cible, r.ville, r.bat, r.piece, v_mon_effectif, r.effectif);
      v_mutuels := v_mutuels + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'force', true, 'effectif', v_mon_effectif,
    'reconnaissance', v_reco, 'jumelles', v_jumelles,
    'contacts', v_contacts, 'contacts_mutuels', v_mutuels);
END;
$function$


-- ========== militaire_equiper_accessoire(text,text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_equiper_accessoire(p_compagnie_id text, p_section_id text, p_matricule text, p_objet_id text, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  g record; v_sec jsonb; v_sols jsonb; v_inv jsonb; v_occupe numeric;
  v_objet jsonb; v_pos integer; v_acc jsonb; v_trouve boolean := false;
BEGIN
  IF coalesce(p_sens,'') NOT IN ('equiper','desequiper') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  IF coalesce(btrim(coalesce(p_matricule,'')),'') = '' OR coalesce(btrim(coalesce(p_objet_id,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- AUTORITE : Lieutenant structurel de cette section, meme empire. Verrouille la compagnie.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  -- Le soldat vise doit exister, etre un PNJ, et porter ce matricule.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_sols) sol
                  WHERE NOT coalesce((sol->>'pj')::boolean,false)
                    AND sol->>'matricule' = p_matricule) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable', 'matricule', p_matricule);
  END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'equiper' THEN
    -- L'objet doit REELLEMENT etre dans l'inventaire du Lieutenant. Pas de drapeau, pas de copie.
    SELECT i, pos INTO v_objet, v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'id' = p_objet_id LIMIT 1;
    IF v_objet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent_de_l_inventaire');
    END IF;
    -- Il quitte l'inventaire...
    SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
      FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
    -- ...et rejoint le soldat, entier.
    SELECT coalesce(jsonb_agg(
             CASE WHEN NOT coalesce((sol->>'pj')::boolean,false) AND sol->>'matricule' = p_matricule
                  THEN sol || jsonb_build_object('accessoires',
                         (CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                               THEN sol->'accessoires' ELSE '[]'::jsonb END) || jsonb_build_array(v_objet))
                  ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);
    v_trouve := true;

  ELSE
    -- Desequiper : l'objet doit reellement etre porte par ce soldat.
    SELECT a INTO v_objet
      FROM jsonb_array_elements(v_sols) sol,
           jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                     THEN sol->'accessoires' ELSE '[]'::jsonb END) a
     WHERE NOT coalesce((sol->>'pj')::boolean,false) AND sol->>'matricule' = p_matricule
       AND a->>'id' = p_objet_id LIMIT 1;
    IF v_objet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_porte');
    END IF;

    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
      INTO v_occupe FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + 1 > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
    END IF;

    SELECT coalesce(jsonb_agg(
             CASE WHEN NOT coalesce((sol->>'pj')::boolean,false) AND sol->>'matricule' = p_matricule
                  THEN sol || jsonb_build_object('accessoires', (
                         SELECT coalesce(jsonb_agg(a ORDER BY ap), '[]'::jsonb)
                           FROM jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                                          THEN sol->'accessoires' ELSE '[]'::jsonb END)
                                WITH ORDINALITY AS ta(a, ap)
                          WHERE a->>'id' <> p_objet_id))
                  ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);
    v_inv := v_inv || jsonb_build_array(v_objet);
    v_trouve := true;
  END IF;

  IF NOT v_trouve THEN RETURN jsonb_build_object('ok', false, 'raison', 'operation_impossible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = g.o_moi;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'objet', v_objet->>'name', 'produit', v_objet->>'produitMilitaire', 'objet_id', p_objet_id);
END;
$function$


-- ========== militaire_equiper_soldat(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_equiper_soldat(p_compagnie_id text, p_section_id text, p_matricule text, p_categorie text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb; v_stock jsonb; v_sol jsonb; v_anc text; v_dispo int; v_sols jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_categorie NOT IN ('corps_a_corps','arme_de_poing','mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;
  SELECT s INTO v_sol FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'matricule' = p_matricule LIMIT 1;
  IF v_sol IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  v_anc := COALESCE(v_sol->>'arme', 'corps_a_corps');
  IF v_anc = p_categorie THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_categorie)::int, 0));
    IF v_dispo <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'categorie', p_categorie);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_categorie, v_dispo - 1);
  END IF;
  IF v_anc <> 'corps_a_corps' THEN
    v_stock := v_stock || jsonb_build_object(v_anc, GREATEST(0, COALESCE((v_stock->>v_anc)::int, 0)) + 1);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN sol->>'matricule' = p_matricule THEN sol || jsonb_build_object('arme', p_categorie)
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols, 'stockArmes', v_stock))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'matricule', p_matricule, 'arme', p_categorie,
                            'ancienne', v_anc, 'stock', v_stock);
END; $function$


-- ========== militaire_gilet_absorber(boolean,text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_gilet_absorber(p_est_pj boolean, p_nom text, p_compagnie_id text, p_section_id text, p_matricule text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_inv jsonb; v_pos integer; v_protege boolean; v_data jsonb; v_sec jsonb; v_sols jsonb;
        v_trouve boolean := false;
BEGIN
  IF p_est_pj THEN
    SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
      INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
    IF v_inv IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'porteur_introuvable'); END IF;
    SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'produitMilitaire' = 'gilet_pare_balles'
       AND coalesce((i->>'fragilise')::boolean, false) = false ORDER BY pos LIMIT 1;
    IF v_pos IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact'); END IF;

    -- Le jet a lieu AVANT l'ecriture : le gilet ne se fragilise que s'il a servi de rempart, et
    -- sur un echec il reste intact -- exactement la regle validee.
    v_protege := (random() < 0.5);
    IF v_protege THEN
      SELECT coalesce(jsonb_agg(CASE WHEN pos = v_pos
               THEN i || jsonb_build_object('fragilise', true,
                      'desc', coalesce(i->>'desc','') || ' Fragilisé : a déjà encaissé un impact.')
               ELSE i END ORDER BY pos), '[]'::jsonb)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
    END IF;
    RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
  END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'section_introuvable'); END IF;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;

  SELECT true INTO v_trouve FROM jsonb_array_elements(v_sols) sol,
         jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                   THEN sol->'accessoires' ELSE '[]'::jsonb END) a
   WHERE sol->>'matricule' = p_matricule
     AND a->>'produitMilitaire' = 'gilet_pare_balles'
     AND coalesce((a->>'fragilise')::boolean, false) = false LIMIT 1;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact');
  END IF;

  v_protege := (random() < 0.5);
  IF v_protege THEN
    SELECT coalesce(jsonb_agg(
             CASE WHEN sol->>'matricule' = p_matricule
                  THEN sol || jsonb_build_object('accessoires', (
                         SELECT coalesce(jsonb_agg(
                                  CASE WHEN a->>'produitMilitaire' = 'gilet_pare_balles'
                                        AND coalesce((a->>'fragilise')::boolean,false) = false
                                        AND ap = (SELECT min(ap2) FROM jsonb_array_elements(sol->'accessoires')
                                                   WITH ORDINALITY AS t2(a2, ap2)
                                                  WHERE a2->>'produitMilitaire' = 'gilet_pare_balles'
                                                    AND coalesce((a2->>'fragilise')::boolean,false) = false)
                                       THEN a || jsonb_build_object('fragilise', true)
                                       ELSE a END ORDER BY ap), '[]'::jsonb)
                           FROM jsonb_array_elements(CASE WHEN jsonb_typeof(sol->'accessoires')='array'
                                                          THEN sol->'accessoires' ELSE '[]'::jsonb END)
                                WITH ORDINALITY AS ta(a, ap)))
                  ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);
    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                    v_sec || jsonb_build_object('soldats', v_sols))
     WHERE id = p_compagnie_id;
  END IF;
  RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
END;
$function$


-- ========== militaire_grade_effectif(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_grade_effectif(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    (SELECT pd.poste->>'id' FROM public.personnages_donnees pd
      WHERE pd.name = p_nom AND pd.poste->>'id' IN ('lieutenant','capitaine','commandant')),
    (SELECT 'soldat' FROM public.compagnies_militaires c,
            jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
            jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
      WHERE coalesce((sol->>'pj')::boolean,false) AND sol->>'nom' = p_nom LIMIT 1));
$function$

-- ========== militaire_groupe_sous_seuil(bigint,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_groupe_sous_seuil(p_bataille_id bigint, p_groupe_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT (SELECT count(*) FROM public.batailles_engagements e
           WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
             AND e.sorti_round IS NULL) * 2
         <= coalesce((SELECT g.effectif_initial FROM public.batailles_groupes g
                       WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id), 0);
$function$


-- ========== militaire_lien_operationnel_rompre(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_lien_operationnel_rompre(p_leader text, p_ville text, p_bat text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_cie record; v_sections jsonb; v_n int; v_total int := 0;
BEGIN
  IF coalesce(btrim(coalesce(p_leader, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  FOR v_cie IN SELECT id, data FROM public.compagnies_militaires FOR UPDATE LOOP
    SELECT count(*) INTO v_n
      FROM jsonb_array_elements(coalesce(v_cie.data->'sections', '[]'::jsonb)) sec,
           jsonb_array_elements(coalesce(sec->'soldats', '[]'::jsonb)) sol
     WHERE sol->>'leaderCourant' = p_leader;
    CONTINUE WHEN v_n = 0;

    SELECT coalesce(jsonb_agg(
             sec || jsonb_build_object('soldats', (
               SELECT coalesce(jsonb_agg(
                        CASE WHEN sol->>'leaderCourant' = p_leader
                             THEN sol || jsonb_build_object('leaderCourant', NULL,
                                    'ville', p_ville, 'buildingId', p_bat, 'roomId', p_room)
                             ELSE sol END ORDER BY spos), '[]'::jsonb)
                 FROM jsonb_array_elements(coalesce(sec->'soldats', '[]'::jsonb))
                      WITH ORDINALITY AS ts(sol, spos)))
             ORDER BY pos), '[]'::jsonb)
      INTO v_sections
      FROM jsonb_array_elements(coalesce(v_cie.data->'sections', '[]'::jsonb))
           WITH ORDINALITY AS t(sec, pos);

    UPDATE public.compagnies_militaires
       SET data = v_cie.data || jsonb_build_object('sections', v_sections)
     WHERE id = v_cie.id;
    v_total := v_total + v_n;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'soldats', v_total,
                            'ville', p_ville, 'batiment', p_bat, 'piece', p_room);
END;
$function$


-- ========== militaire_malus_taille(integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_malus_taille(p_effectif integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN coalesce(p_effectif,0) <= 1  THEN 0
    WHEN p_effectif <= 4   THEN -5
    WHEN p_effectif <= 9   THEN -10
    WHEN p_effectif <= 15  THEN -20
    WHEN p_effectif <= 25  THEN -30
    WHEN p_effectif <= 50  THEN -40
    ELSE -50 END;
$function$


-- ========== militaire_mes_batailles(integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_mes_batailles(p_limite integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'debut' DESC), '[]'::jsonb) INTO v_res FROM (
    SELECT jsonb_build_object(
      'id', b.id, 'debut', b.debut_ts, 'fin', b.fin_ts, 'statut', b.statut, 'issue', b.issue,
      'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
      'mon_camp', e.camp, 'mon_etat', e.etat_final, 'sorti_round', e.sorti_round,
      'rounds', (SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb)
                   FROM public.batailles_rounds r
                  WHERE r.bataille_id = b.id AND r.camp = e.camp)) AS x
      FROM public.batailles_engagements e
      JOIN public.batailles b ON b.id = e.bataille_id
     WHERE e.personnage = v_moi
     ORDER BY b.debut_ts DESC LIMIT greatest(1, least(50, coalesce(p_limite, 10)))) t;
  RETURN jsonb_build_object('ok', true, 'batailles', v_res);
END;
$function$


-- ========== militaire_mobilisation_fixer(boolean) ==========
CREATE OR REPLACE FUNCTION public.militaire_mobilisation_fixer(p_actif boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- AUTORITE. exiger_poste leve si le poste n'est pas atteste : on ne se contente pas de lire
  -- poste->>'id' sur la fiche, qui est ce que le navigateur affiche.
  PERFORM public.exiger_poste('min_def');

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- ECRITURE CHIRURGICALE : une seule cle, sous verrou, sans relire ni reecrire le reste du blob.
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{mobilisationNationaleActive}',
                          to_jsonb(coalesce(p_actif, false)), true),
         updated_at = now()
   WHERE id = v_pays;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable', 'pays', v_pays);
  END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'actif', coalesce(p_actif, false));
END;
$function$


-- ========== militaire_modif_distance(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_modif_distance(p_bande text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE p_bande WHEN 'proche' THEN 0 WHEN 'moyenne' THEN -20
                      WHEN 'longue' THEN -40 ELSE NULL END;
$function$


-- ========== militaire_mon_pays() ==========
CREATE OR REPLACE FUNCTION public.militaire_mon_pays()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() LIMIT 1;
$function$


-- ========== militaire_mutinerie_declencher() ==========
CREATE OR REPLACE FUNCTION public.militaire_mutinerie_declencher()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_effectif_max constant integer := 24;
  c_bonus_max    constant integer := 4;
  c_seuil_crise  constant numeric := 35;
  g record; v_moi text; v_pays text; v_cie text; v_sec text;
  v_cha numeric; v_base integer; v_social numeric; v_ie numeric;
  v_deg_s numeric; v_deg_e numeric; v_score numeric; v_bonus integer;
  v_vises integer; v_dispo integer; v_camp text; v_choisis text[]; v_sols jsonb; v_secj jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), poste->>'compagnieId', poste->>'sectionId',
         public.assemblee_stat_base(stats, 'CHA')
    INTO v_pays, v_cie, v_sec, v_cha
    FROM public.personnages_donnees
   WHERE name = v_moi AND poste->>'id' = 'lieutenant';
  IF v_cie IS NULL OR v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_lieutenant');
  END IF;

  IF public.mutinerie_camp_de(v_moi) IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.mutineries_membres WHERE personnage = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mutin');
  END IF;

  -- AUTORITE ET VERROU : le Lieutenant STRUCTUREL de cette section, verrou pose sur la compagnie.
  SELECT * INTO g FROM public.militaire_section_de_moi(v_cie, v_sec);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- BAREME DE CHARISME (game design). CHA 17+ traite comme 16 : le bareme ne monte pas au-dela.
  v_base := CASE WHEN v_cha <= 13 THEN 12 WHEN v_cha < 15 THEN 15
                 WHEN v_cha < 16 THEN 18 ELSE 20 END;

  -- BONUS DE CRISE NATIONALE : social pese 2/3, economie 1/3. Une situation saine (>= 35)
  -- n'apporte rien. 'ie' est lu pour de vrai bien qu'aucune mecanique ne le fasse encore bouger :
  -- la mutinerie sera prete le jour ou il deviendra vivant.
  v_social := public.mutinerie_social_national(v_pays);
  v_ie     := public.helvetia_ie_national(v_pays);
  v_deg_s  := greatest(0, (c_seuil_crise - v_social) / c_seuil_crise);
  v_deg_e  := greatest(0, (c_seuil_crise - v_ie)     / c_seuil_crise);
  v_score  := (2.0/3.0) * v_deg_s + (1.0/3.0) * v_deg_e;
  v_bonus  := least(c_bonus_max, greatest(0, ceil(c_bonus_max * v_score)::integer));

  v_vises := least(c_effectif_max, v_base + v_bonus);

  SELECT s INTO v_secj FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = v_sec;
  v_sols := CASE WHEN jsonb_typeof(v_secj->'soldats') = 'array' THEN v_secj->'soldats' ELSE '[]'::jsonb END;

  -- SOLDATS REELLEMENT DISPONIBLES : les PNJ vivants de la section, jamais un PJ (un joueur ne se
  -- rallie pas malgre lui), jamais un effectif invente.
  SELECT count(*)::integer INTO v_dispo FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND (sol->>'mutin') IS NULL;
  v_vises := least(v_vises, v_dispo);

  v_camp := 'mutin:' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
  INSERT INTO public.mutineries (camp, pays, fondateur, compagnie_id, section_id)
  VALUES (v_camp, v_pays, v_moi, v_cie, v_sec);
  INSERT INTO public.mutineries_membres (camp, personnage, role_origine)
  VALUES (v_camp, v_moi, 'lieutenant');

  -- TIRAGE ALEATOIRE parmi les soldats disponibles. Les non-tires restent strictement loyalistes.
  IF v_vises > 0 THEN
    SELECT coalesce(array_agg(mat), '{}'::text[]) INTO v_choisis FROM (
      SELECT sol->>'matricule' AS mat FROM jsonb_array_elements(v_sols) sol
       WHERE NOT coalesce((sol->>'pj')::boolean, false)
         AND coalesce((sol->>'pa')::integer, 0) > 0
         AND (sol->>'mutin') IS NULL
       ORDER BY random() LIMIT v_vises) x;

    SELECT coalesce(jsonb_agg(
             CASE WHEN sol->>'matricule' = ANY (v_choisis)
                  THEN sol || jsonb_build_object('mutin', v_camp) ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(g.o_data, v_sec,
                    v_secj || jsonb_build_object('soldats', v_sols))
     WHERE id = v_cie;
  END IF;

  RETURN jsonb_build_object('ok', true, 'camp', v_camp, 'cha', v_cha,
    'base', v_base, 'bonus_crise', v_bonus, 'social', v_social, 'ie', v_ie,
    'soldats_rallies', v_vises, 'soldats_disponibles', v_dispo,
    'soldats_restes_loyalistes', greatest(0, v_dispo - v_vises));
END;
$function$


-- ========== militaire_observer() ==========
CREATE OR REPLACE FUNCTION public.militaire_observer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_pa integer; v_reco numeric;
  v_a_jumelles boolean; v_contacts jsonb := '[]'::jsonb;
  r record; v_bande text; v_modif integer; v_camo numeric; v_chance integer; v_jet integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(pa,0), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_pa, v_reco, v_a_jumelles
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT v_a_jumelles THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jumelles'); END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa);
  END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_moi;

  -- Forces ENNEMIES : sections d'une compagnie dont le pays est en guerre ACTIVE avec le mien,
  -- et dont des soldats ont une position reelle (ceux qui suivent un chef n'en ont pas).
  FOR r IN
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM v_pays
       AND coalesce(sol->>'ville','') <> ''
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = c.data->>'pays')
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = c.data->>'pays')))
     GROUP BY 1, 2, 3
  LOOP
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    -- Hors bande : les jumelles ne donnent qu'un signe de vie, et seulement si le jet passe.
    IF v_modif IS NULL THEN v_modif := -60; END IF;
    v_camo := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_chance := public.militaire_chance_detection(v_reco, v_camo, v_modif, c_bonus_jumelles);
    v_jet := floor(random() * 100)::integer + 1;
    -- ECHEC : on n'ajoute RIEN. Pas de trace, pas de compteur, pas d'indice.
    CONTINUE WHEN v_jet > v_chance;
    v_contacts := v_contacts || jsonb_build_array(
      public.militaire_degrader(CASE WHEN v_modif = -60 THEN 'limite' ELSE v_bande END,
                                r.effectif, r.pays_cible, r.ville, r.bat));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pa_restants', v_pa - c_pa,
    'reconnaissance', v_reco, 'contacts', v_contacts);
END; $function$


-- ========== militaire_ordre_collectif(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_ordre_collectif(p_compagnie_id text, p_section_id text, p_action text, p_leader text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_capacite_tente   constant integer := 13;
  c_gain             constant integer := 1;
  c_pa_max_pnj       constant integer := 12;
  c_max_ration_jour  constant integer := 2;
  v_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb; v_leader text;
  v_jour text; v_n integer; v_tentes integer; v_requis integer;
  v_rations integer; v_inv jsonb; v_pos integer; i integer;
  v_a_distance boolean := false; v_radio_chef boolean; v_radio_leader boolean;
BEGIN
  IF p_action NOT IN ('ration', 'bivouac') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;

  -- Le groupe vise : celui mene par p_leader, ou par l'acteur lui-meme par defaut.
  v_leader := coalesce(nullif(btrim(coalesce(p_leader,'')), ''), v_moi);

  -- AUTORITE : le Lieutenant structurel, ou le leader operationnel pour SON propre groupe.
  IF v_sec->>'lieutenantNom' = v_moi THEN
    v_a_distance := (v_leader <> v_moi);
  ELSIF v_leader = v_moi THEN
    NULL;   -- un leader operationnel commande le groupe qu'il mene physiquement
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  -- DOUBLE RADIO obligatoire pour commander a distance. Relais de commandement, pas teleportation.
  IF v_a_distance THEN
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_moi AND i2->>'produitMilitaire' = 'radio') INTO v_radio_chef;
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_leader AND i2->>'produitMilitaire' = 'radio') INTO v_radio_leader;
    IF NOT coalesce(v_radio_chef,false) OR NOT coalesce(v_radio_leader,false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'radio_manquante',
        'radio_lieutenant', coalesce(v_radio_chef,false), 'radio_leader', coalesce(v_radio_leader,false));
    END IF;
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  -- BENEFICIAIRES. Le predicat est ecrit a l'identique ici et lors de l'application : un soldat
  -- compte est un soldat servi, et reciproquement.
  --   - soldat PNJ mene par ce leader ;
  --   - PAS DEJA AU PLAFOND : a 12 PA il ne gagnerait rien, on ne lui prend donc rien ;
  --   - ration : moins de deux rations consommees aujourd'hui (l'ancien marqueur seul vaut 1) ;
  --   - bivouac : pas encore bivouaque aujourd'hui -- frequence inchangee.
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean,false)
     AND sol->>'leaderCourant' = v_leader
     AND coalesce((sol->>'pa')::numeric, 0) < c_pa_max_pnj
     AND CASE WHEN p_action = 'ration'
              THEN (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                         THEN coalesce((sol->>'nb_ration')::integer, 1) ELSE 0 END) < c_max_ration_jour
              ELSE coalesce(sol->>'dernier_bivouac','') <> v_jour
         END;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_concerne');
  END IF;

  -- RESSOURCES, verifiees pour TOUT le groupe avant la moindre ecriture.
  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = v_leader FOR UPDATE;
  IF p_action = 'ration' THEN
    SELECT count(*) INTO v_rations FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'ration_combat';
    IF v_rations < v_n THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes',
        'requis', v_n, 'disponibles', v_rations);
    END IF;
  ELSE
    SELECT count(*) INTO v_tentes FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'tente';
    v_requis := ceil(v_n::numeric / c_capacite_tente)::integer;
    IF coalesce(v_tentes,0) < v_requis THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'tentes_insuffisantes',
        'requis', v_requis, 'disponibles', coalesce(v_tentes,0), 'capacite_tente', c_capacite_tente);
    END IF;
  END IF;

  -- APPLICATION : +1 PA, plafond respecte, et le marqueur du jour mis a jour. Pour la ration, le
  -- compteur est incremente a partir de la meme lecture compatible que ci-dessus.
  SELECT coalesce(jsonb_agg(
           CASE WHEN NOT coalesce((sol->>'pj')::boolean,false)
                     AND sol->>'leaderCourant' = v_leader
                     AND coalesce((sol->>'pa')::numeric, 0) < c_pa_max_pnj
                     AND CASE WHEN p_action = 'ration'
                              THEN (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                                         THEN coalesce((sol->>'nb_ration')::integer, 1) ELSE 0 END) < c_max_ration_jour
                              ELSE coalesce(sol->>'dernier_bivouac','') <> v_jour
                         END
                THEN sol
                     || jsonb_build_object('pa', least(c_pa_max_pnj,
                          coalesce((sol->>'pa')::numeric, 0) + c_gain))
                     || CASE WHEN p_action = 'ration'
                             THEN jsonb_build_object('dernier_ration', v_jour,
                                    'nb_ration', (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                                                       THEN coalesce((sol->>'nb_ration')::integer, 1)
                                                       ELSE 0 END) + 1)
                             ELSE jsonb_build_object('dernier_bivouac', v_jour)
                        END
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La ration est consommee : une par soldat nourri. Le bivouac ne detruit PAS la tente.
  IF p_action = 'ration' THEN
    FOR i IN 1 .. v_n LOOP
      SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos)
       WHERE i2->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
      SELECT coalesce(jsonb_agg(i2 ORDER BY pos), '[]'::jsonb) INTO v_inv
        FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos) WHERE pos <> v_pos;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_leader;
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', p_action, 'leader', v_leader,
    'soldats', v_n, 'a_distance', v_a_distance, 'gain_pa', c_gain,
    'tentes_requises', CASE WHEN p_action='bivouac' THEN v_requis END,
    'rations_consommees', CASE WHEN p_action='ration' THEN v_n END,
    'max_ration_jour', CASE WHEN p_action='ration' THEN c_max_ration_jour END);
END;
$function$

-- ========== militaire_pa_restants(integer,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_pa_restants(p_pa integer, p_degre text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(0, floor(greatest(0, coalesce(p_pa, 0))
                           * (1 - public.militaire_degats_pct(p_degre)))::integer);
$function$


-- ========== militaire_position_repli(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_position_repli(p_nom text, p_ville text, p_bat text, p_piece text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object('ville', h.city, 'batiment', h.building_id, 'piece', h.room_id)
    FROM public.historique_deplacements h
   WHERE p_nom IS NOT NULL AND h.name = p_nom
     AND NOT (h.city = p_ville AND h.building_id = p_bat AND h.room_id = p_piece)
   ORDER BY h.created_at DESC LIMIT 1;
$function$


-- ========== militaire_presentation_affectation() ==========
CREATE OR REPLACE FUNCTION public.militaire_presentation_affectation()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  v_moi text; v_pays text; v_bat text; v_pa integer;
  v_req jsonb; v_recherche jsonb; v_recherche2 jsonb;
  v_statut text; v_deserteur boolean; v_maintenant numeric; v_deadline numeric;
  v_cid text; v_sid text; v_data jsonb; v_sec jsonb; v_liste jsonb;
  v_inscrit boolean := false; v_numero text; v_paye jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.current_building, ''), coalesce(p.pa, 0),
         p.requisition, coalesce(p.recherche, '[]'::jsonb)
    INTO v_pays, v_bat, v_pa, v_req, v_recherche
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- La colonne est jsonb, mais le client y ecrivait un JSON.stringify : la valeur peut donc
  -- etre soit un objet, soit une CHAINE json contenant l'objet. Les deux sont acceptees.
  IF jsonb_typeof(v_req) = 'string' THEN
    BEGIN v_req := (v_req #>> '{}')::jsonb; EXCEPTION WHEN others THEN v_req := NULL; END;
  END IF;
  IF v_req IS NULL OR jsonb_typeof(v_req) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation');
  END IF;

  v_statut := coalesce(v_req->>'statut', '');
  v_deserteur := (v_statut = 'deserteur');
  IF v_statut NOT IN ('convoque', 'deserteur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation', 'statut', v_statut);
  END IF;
  -- Presence reelle exigee, comme militaire_retrait et militaire_candidater_soldat.
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_maintenant := floor(extract(epoch FROM now()) * 1000);
  v_deadline := CASE WHEN (v_req->>'deadline') ~ '^[0-9]+(\.[0-9]+)?$'
                     THEN (v_req->>'deadline')::numeric ELSE NULL END;
  -- Un DESERTEUR se rend a tout moment, sans delai : c'est ce qui fait de la reddition une
  -- option de jeu. Un convoque, lui, reste tenu par son delai.
  IF NOT v_deserteur AND v_deadline IS NOT NULL AND v_deadline < v_maintenant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- 1. LE BLOB DE LA COMPAGNIE, ecrit par le serveur (le civil n'a aucune autorite dessus).
  v_cid := v_req->>'compagnieId';
  v_sid := v_req->>'sectionId';
  IF v_cid IS NOT NULL THEN
    SELECT c.data INTO v_data FROM public.compagnies_militaires c WHERE c.id = v_cid FOR UPDATE;
  END IF;
  IF v_data IS NOT NULL THEN
    SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
     WHERE s->>'id' = v_sid;
    IF v_sec IS NOT NULL THEN
      v_numero := v_sec->>'numero';
      SELECT coalesce(jsonb_agg(CASE WHEN e->>'nom' = v_moi
                                     THEN e || jsonb_build_object('statut', 'affecte') ELSE e END), '[]'::jsonb),
             coalesce(bool_or(e->>'nom' = v_moi), false)
        INTO v_liste, v_inscrit
        FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e;
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, v_sid,
                      v_sec || jsonb_build_object('civilsRequisitionnes', coalesce(v_liste, '[]'::jsonb)))
       WHERE id = v_cid;
    END IF;
  END IF;

  -- 2. LA FICHE DU JOUEUR. La presentation ETEINT les poursuites pour desertion -- et elles
  -- seules : on FILTRE le tableau `recherche`, on ne le remplace jamais (tout autre motif,
  -- crime, condamnation en attente, motif d'un autre empire, survit intact).
  v_req := v_req || jsonb_build_object('statut', 'affecte');
  v_recherche2 := v_recherche;
  IF v_deserteur THEN
    SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_recherche2
      FROM jsonb_array_elements(v_recherche) e
     WHERE NOT (coalesce(e->>'acte', '') = 'desertion'
                AND coalesce(e->>'country', v_pays) = v_pays);
  END IF;
  UPDATE public.personnages_donnees
     SET requisition = v_req, recherche = v_recherche2
   WHERE name = v_moi;

  -- 3. LE PAIEMENT, en dernier et sous le meme verrou : payer_ordre relit le cout dans le
  -- miroir declare. Un refus a ce stade annule TOUT (exception = rollback), jamais un effet
  -- accorde sans contrepartie.
  v_paye := public.payer_ordre(v_moi, 'se_presenter_affectation', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_presentation_affectation: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'deserteur', v_deserteur, 'section', v_numero,
    'compagnie', v_cid, 'inscrit', v_inscrit, 'requisition', v_req,
    'recherche', v_recherche2, 'pa', v_paye->'pa');
END;
$function$


-- ========== militaire_proposer_capitaine(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_proposer_capitaine(p_compagnie_id text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_acteur text; v_pays text; v_data jsonb; v_id text;
BEGIN
  v_acteur := public.exiger_poste('commandant');           -- leve si ce n'est pas le Commandant
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  SELECT data::jsonb INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF COALESCE(v_data->>'capitaineNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_deja_commandee', 'capitaine', v_data->>'capitaineNom');
  END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire AND country = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  DELETE FROM public.nominations_militaires
   WHERE compagnie_id = p_compagnie_id AND grade = 'capitaine' AND traitee = false;
  v_id := 'nomil-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.nominations_militaires (id, pays, grade, compagnie_id, section_id, destinataire, par)
  VALUES (v_id, v_pays, 'capitaine', p_compagnie_id, NULL, p_destinataire, v_acteur);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire);
END; $function$


-- ========== militaire_proposer_lieutenant(text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_proposer_lieutenant(p_compagnie_id text, p_section_id text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_data jsonb; v_sec jsonb; v_id text; v_nb int;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'capitaineNom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_capitaine_de_cette_compagnie'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  v_nb := COALESCE(jsonb_array_length(v_data->'sections'), 0);
  IF v_nb > 4 THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_incoherente', 'sections', v_nb); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF COALESCE(v_sec->>'lieutenantNom','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_deja_commandee'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire AND country = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  DELETE FROM public.nominations_militaires
   WHERE compagnie_id = p_compagnie_id AND section_id = p_section_id
     AND grade = 'lieutenant' AND traitee = false;
  v_id := 'nomil-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.nominations_militaires (id, pays, grade, compagnie_id, section_id, destinataire, par)
  VALUES (v_id, v_pays, 'lieutenant', p_compagnie_id, p_section_id, p_destinataire, v_moi);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire);
END; $function$


-- ========== militaire_ration_consommer() ==========
CREATE OR REPLACE FUNCTION public.militaire_ration_consommer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj    constant integer := 30;
  c_gain         constant integer := 1;
  c_max_par_jour constant integer := 2;
  v_moi text; v_inv jsonb; v_stats jsonb; v_pos integer;
  v_pa_avant integer; v_pa_apres integer; v_reste integer;
  v_jour text; v_deja integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- VERROU AVANT TOUTE LECTURE : deux appels simultanes sont serialises ici, le second relit
  -- un inventaire et un compteur deja a jour. Ni la ration ni le quota ne peuvent etre doubles.
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END,
         CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END,
         coalesce(pa, 0)
    INTO v_inv, v_stats, v_pa_avant
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_deja := CASE WHEN coalesce(v_stats->>'rationsCombatJour', '') = v_jour
                 THEN coalesce((v_stats->>'rationsCombatNb')::integer, 0) ELSE 0 END;

  -- LA POSSESSION EST VERIFIEE ICI, jamais crue sur parole. La premiere ration trouvee est
  -- consommee : elles sont interchangeables, aucun choix a offrir au joueur.
  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ration'); END IF;

  -- LES DEUX REFUS CONSERVENT LA RATION : aucune ecriture n'a encore eu lieu a ce stade.
  IF v_pa_avant >= c_pa_max_pj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_maximum', 'pa', v_pa_avant, 'plafond', c_pa_max_pj);
  END IF;
  IF v_deja >= c_max_par_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_quotidien',
      'consommees_aujourdhui', v_deja, 'maximum', c_max_par_jour);
  END IF;

  v_pa_apres := least(c_pa_max_pj, v_pa_avant + c_gain);

  -- USAGE UNIQUE : la ration quitte l'inventaire dans la MEME transaction que le gain et que
  -- l'incrementation du compteur du jour.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;

  UPDATE public.personnages_donnees
     SET inventory = v_inv, pa = v_pa_apres,
         stats = v_stats || jsonb_build_object('rationsCombatJour', v_jour,
                                               'rationsCombatNb', v_deja + 1)
   WHERE name = v_moi;

  SELECT count(*)::integer INTO v_reste FROM jsonb_array_elements(v_inv) i
   WHERE i->>'produitMilitaire' = 'ration_combat';

  RETURN jsonb_build_object('ok', true, 'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres,
    'gain_reel', v_pa_apres - v_pa_avant, 'rations_restantes', v_reste,
    'consommees_aujourdhui', v_deja + 1, 'maximum', c_max_par_jour);
END;
$function$


-- ========== militaire_rations_retirer(integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_rations_retirer(p_nombre integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_ref jsonb; v_dispo integer; v_n integer; i integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_n := greatest(0, coalesce(p_nombre, 0));
  IF v_n = 0 OR v_n > 50 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i2->>'qty')::numeric, (i2->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i2;
  IF v_occupe + v_n > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  v_ref := CASE WHEN jsonb_typeof(v_data->'refectoire')='object' THEN v_data->'refectoire' ELSE '{}'::jsonb END;
  v_dispo := greatest(0, coalesce((v_ref->>'rations')::integer, 0));
  IF v_dispo < v_n THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes', 'disponibles', v_dispo);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_dispo - v_n)),
         updated_at = now()
   WHERE id = v_pays;

  FOR i IN 1 .. v_n LOOP
    v_inv := v_inv || jsonb_build_array(jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'vivres', 'sousType', 'militaire', 'produitMilitaire', 'ration_combat',
      'origineMilitaire', true, 'usageUnique', true,
      'name', 'Ration de combat', 'icon', 'ti-soup', 'legal', true,
      'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-ration-combat.png',
      'desc', 'Ration de combat. +1 PA par ration, 2 rations par jour au maximum.'));
  END LOOP;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'retirees', v_n, 'restantes', v_dispo - v_n);
END;
$function$


-- ========== militaire_recuperer_soldats(text,text,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_recuperer_soldats(p_compagnie_id text, p_section_id text, p_nb integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_ville text; v_bat text; v_room text; v_dispo int;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;

  SELECT current_city, current_building, current_room INTO v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;
  IF COALESCE(v_bat,'') = '' OR COALESCE(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'ville' = v_ville AND s->>'buildingId' = v_bat AND s->>'roomId' = v_room
     AND s->>'leaderCourant' IS NULL;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant_ici', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN ici AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', g.o_moi,
                         'ville', NULL, 'buildingId', NULL, 'roomId', NULL)
           ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos,
                 (sol->>'ville' = v_ville AND sol->>'buildingId' = v_bat
                  AND sol->>'roomId' = v_room AND sol->>'leaderCourant' IS NULL) AS ici,
                 row_number() OVER (PARTITION BY (sol->>'ville' = v_ville
                                    AND sol->>'buildingId' = v_bat AND sol->>'roomId' = v_room
                                    AND sol->>'leaderCourant' IS NULL) ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'recuperes', p_nb, 'leader', g.o_moi);
END;
$function$


-- ========== militaire_reposer_section(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_reposer_section(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max         constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  c_capacite_tente constant integer := 13;
  g record; v_sec jsonb; v_sols jsonb; v_jour text;
  v_caserne integer; v_tente integer; v_terrain integer; v_deja integer; v_total integer;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  WITH base AS (
    SELECT sol, pos,
           NOT coalesce((sol->>'pj')::boolean, false)        AS est_pnj,
           coalesce((sol->>'pa')::numeric, 0)::integer       AS pa,
           nullif(btrim(coalesce(sol->>'leaderCourant','')), '') AS leader,
           coalesce(sol->>'dernier_sommeil', '')             AS marqueur
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
  ),
  situe AS (
    SELECT b.*,
           coalesce(pd.current_building, b.sol->>'buildingId') AS batiment
      FROM base b
      LEFT JOIN public.personnages_donnees pd
             ON b.leader IS NOT NULL AND pd.name = b.leader
  ),
  eligible AS (
    SELECT s.*,
           (s.est_pnj AND s.pa > 0 AND s.marqueur <> v_jour)   AS peut,
           (coalesce(s.batiment, '') = 'caserne-militaire')    AS a_la_caserne
      FROM situe s
  ),
  tentes AS (
    SELECT l.leader,
           (SELECT count(*) FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(pd.inventory) = 'array' THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE i->>'produitMilitaire' = 'tente')::integer AS nb
      FROM (SELECT DISTINCT leader FROM eligible
             WHERE peut AND NOT a_la_caserne AND leader IS NOT NULL) l
      JOIN public.personnages_donnees pd ON pd.name = l.leader
  ),
  rang AS (
    SELECT pos, leader,
           row_number() OVER (PARTITION BY leader ORDER BY (sol->>'matricule'), pos) AS n
      FROM eligible
     WHERE peut AND NOT a_la_caserne AND leader IS NOT NULL
  ),
  final AS (
    SELECT e.sol, e.pos, e.pa,
           CASE
             WHEN NOT e.peut            THEN 'aucun'
             WHEN e.a_la_caserne        THEN 'caserne'
             WHEN r.n IS NOT NULL
              AND r.n <= coalesce(t.nb, 0) * c_capacite_tente THEN 'tente'
             ELSE 'terrain'
           END AS sort,
           (NOT e.peut AND e.est_pnj AND e.pa > 0 AND e.marqueur = v_jour) AS deja_repose
      FROM eligible e
      LEFT JOIN rang   r ON r.pos = e.pos
      LEFT JOIN tentes t ON t.leader = e.leader
  )
  SELECT coalesce(jsonb_agg(
           CASE f.sort
             WHEN 'caserne' THEN f.sol || jsonb_build_object('pa', c_pa_max, 'dernier_sommeil', v_jour)
             WHEN 'tente'   THEN f.sol || jsonb_build_object(
                                  'pa', least(c_pa_max, f.pa + c_gain_terrain + c_bonus_tente),
                                  'dernier_sommeil', v_jour)
             WHEN 'terrain' THEN f.sol || jsonb_build_object(
                                  'pa', least(c_pa_max, f.pa + c_gain_terrain),
                                  'dernier_sommeil', v_jour)
             ELSE f.sol
           END ORDER BY f.pos), '[]'::jsonb),
         count(*) FILTER (WHERE f.sort = 'caserne')::integer,
         count(*) FILTER (WHERE f.sort = 'tente')::integer,
         count(*) FILTER (WHERE f.sort = 'terrain')::integer,
         count(*) FILTER (WHERE f.deja_repose)::integer,
         count(*)::integer
    INTO v_sols, v_caserne, v_tente, v_terrain, v_deja, v_total
    FROM final f;

  IF coalesce(v_caserne,0) + coalesce(v_tente,0) + coalesce(v_terrain,0) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'caserne', 0, 'tente', 0, 'terrain', 0,
      'deja_reposes', coalesce(v_deja,0), 'effectif', coalesce(v_total,0), 'reposes', 0);
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  RETURN jsonb_build_object('ok', true,
    'caserne', v_caserne, 'tente', v_tente, 'terrain', v_terrain,
    'deja_reposes', v_deja, 'effectif', v_total,
    'reposes', v_caserne + v_tente + v_terrain);
END;
$function$

-- ========== militaire_requisition_civile(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_requisition_civile(p_compagnie_id text, p_section_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa       constant integer := 3;
  c_heures   constant integer := 48;
  c_effectif constant integer := 24;
  v_moi text; v_pays text; v_pa integer; v_mobilisee boolean;
  v_data jsonb; v_sec jsonb; v_liste jsonb; v_noms text[];
  v_deadline numeric; v_paye jsonb;
BEGIN
  -- Poste ATTESTE : exiger_poste leve 42501 si l'appelant n'est pas reellement min_def.
  v_moi := public.exiger_poste('min_def');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT coalesce((b.data->>'mobilisationNationaleActive')::boolean, false) INTO v_mobilisee
    FROM public.budgets_nationaux b WHERE b.id = v_pays;
  IF NOT coalesce(v_mobilisee, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mobilisation_inactive');
  END IF;

  SELECT c.data INTO v_data FROM public.compagnies_militaires c
   WHERE c.id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable');
  END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable');
  END IF;
  IF coalesce(v_sec->>'lieutenantNom', '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant');
  END IF;
  IF jsonb_array_length(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_requisitionnee');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- TIRAGE AU SORT, cote serveur : le client ne choisit plus qui est requisitionne. Memes
  -- exclusions que la liste d'origine (officiers, ministres, maire) + le ministre lui-meme.
  SELECT array_agg(q.name) INTO v_noms FROM (
    SELECT p.name FROM public.personnages_donnees p
     WHERE coalesce(p.domicile->>'country', p.country, 'republic') = v_pays
       AND coalesce(p.poste->>'id', '') NOT IN ('lieutenant','capitaine','commandant','min_def',
             'president','pm','min_int','min_fin','min_just','min_info','min_ae','maire')
       AND p.name <> v_moi
     ORDER BY random() LIMIT c_effectif) q;
  IF v_noms IS NULL OR array_length(v_noms, 1) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_civil_eligible');
  END IF;

  v_deadline := floor(extract(epoch FROM now()) * 1000) + c_heures * 3600000;
  SELECT jsonb_agg(jsonb_build_object('nom', n, 'statut', 'convoque', 'deadline', v_deadline))
    INTO v_liste FROM unnest(v_noms) n;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('civilsRequisitionnes', v_liste))
   WHERE id = p_compagnie_id;

  UPDATE public.personnages_donnees p
     SET requisition = jsonb_build_object('compagnieId', p_compagnie_id, 'sectionId', p_section_id,
                                          'deadline', v_deadline, 'statut', 'convoque')
   WHERE p.name = ANY(v_noms);

  v_paye := public.payer_ordre(v_moi, 'mobilisation_nationale', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_requisition_civile: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'convoques', to_jsonb(v_noms),
    'nombre', array_length(v_noms, 1), 'deadline', v_deadline, 'delai_heures', c_heures,
    'section', v_sec->>'numero', 'lieutenant', v_sec->>'lieutenantNom', 'pa', v_paye->'pa');
END;
$function$


-- ========== militaire_retrait(text,text,integer,text,text,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_retrait(p_pays text, p_produit text, p_quantite integer, p_lieutenant text, p_section text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_pj public.personnages%ROWTYPE;
  v_mvt jsonb; v_lot jsonb; v_inv jsonb; v_occupe numeric; v_poses integer := 0;
  v_label text; v_type text; v_soustype text; v_icon text; v_img text; v_desc text; v_trouve boolean;
BEGIN
  PERFORM public.exiger_acteur(p_lieutenant);
  IF COALESCE(p_quantite, 0) <= 0 OR p_quantite > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- Forme de l'objet, miroir de RECETTES_MILITAIRES. La liste EST la liste blanche : un produit
  -- absent d'ici est refuse, donc il n'existe pas deux listes a tenir a jour.
  SELECT true, r.label, r.t, r.st, r.ic, r.im, r.de
    INTO v_trouve, v_label, v_type, v_soustype, v_icon, v_img, v_desc
    FROM (VALUES
      ('arme_de_poing', 'Pistolet militaire', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png',
       'Arme de poing réglementaire de l''armée de Républia.'),
      ('mitraillette', 'Mitraillette', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png',
       'Arme automatique réglementaire de l''armée de Républia.'),
      ('explosif_militaire', 'Explosifs militaires', 'explosif', 'militaire', 'ti-bomb',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-militaires.png',
       'Explosifs réglementaires de l''armée de Républia.'),
      ('gilet_pare_balles', 'Gilet pare-balles', 'equipement', 'militaire', 'ti-shield-check', NULL,
       'Gilet pare-balles réglementaire. Protège contre les attaques pertinentes, notamment les tirs.'),
      ('radio', 'Radio de campagne', 'equipement', 'militaire', 'ti-radio', NULL,
       'Poste radio de campagne. Relais de commandement : permet de transmettre des ordres à distance.'),
      ('tente', 'Tente de campagne', 'equipement', 'militaire', 'ti-tent', NULL,
       'Tente de campagne. Abrite 13 personnes en bivouac. Aucun montage à ordonner.'),
      ('jumelles', 'Jumelles', 'equipement', 'militaire', 'ti-binoculars', NULL,
       'Jumelles d''observation. Renseignement toujours approximatif.'),
      ('tenue_camouflage', 'Tenue de camouflage', 'equipement', 'militaire', 'ti-eye-off', NULL,
       'Tenue de camouflage. Protège CELUI QUI LA PORTE.')
    ) AS r(p, label, t, st, ic, im, de) WHERE r.p = p_produit;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide', 'produit', p_produit);
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_lieutenant FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF COALESCE(v_pj.poste ->> 'id', '') <> 'lieutenant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_section');
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_pj.inventory) = 'array' THEN v_pj.inventory ELSE '[]'::jsonb END;
  SELECT coalesce(sum(greatest(1,
           coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + p_quantite > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein',
                              'occupe', v_occupe, 'plafond', c_plafond, 'demande', p_quantite);
  END IF;

  v_mvt := public.caserne_stock_mouvement(p_pays, p_produit, -p_quantite, NULL);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;

  FOR v_lot IN SELECT value FROM jsonb_array_elements(COALESCE(v_mvt -> 'lots', '[]'::jsonb)) LOOP
    INSERT INTO public.retraits_materiel_militaire
      (pays, materiel, lot, quantite, lieutenant, section, jour)
    VALUES (p_pays, p_produit, v_lot ->> 'lot', (v_lot ->> 'qte')::integer, p_lieutenant, p_section, p_jour);

    FOR i IN 1 .. greatest(0, coalesce((v_lot ->> 'qte')::integer, 0)) LOOP
      v_inv := v_inv || jsonb_build_array(jsonb_build_object(
        'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
        'type', v_type, 'sousType', v_soustype,
        'origineMilitaire', true, 'lot', coalesce(v_lot ->> 'lot', 'legacy'),
        'produitMilitaire', p_produit,
        'name', v_label, 'icon', v_icon, 'legal', true, 'imageUrl', v_img,
        'desc', v_desc || ' Lot ' || coalesce(v_lot ->> 'lot', 'legacy') || '.'));
      v_poses := v_poses + 1;
    END LOOP;
  END LOOP;

  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_lieutenant;
  RETURN v_mvt || jsonb_build_object('registre', true, 'objets_poses', v_poses,
                                     'inventaire_serveur', true);
END;
$function$


-- ========== militaire_section_de_moi(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_section_de_moi(p_compagnie_id text, p_section_id text, OUT o_moi text, OUT o_data jsonb, OUT o_raison text)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_pays text; v_sec jsonb;
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = o_moi;
  SELECT data INTO o_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF o_data IS NULL THEN o_raison := 'compagnie_introuvable'; RETURN; END IF;
  IF o_data->>'pays' IS DISTINCT FROM v_pays THEN o_raison := 'hors_juridiction'; RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(COALESCE(o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id LIMIT 1;
  IF v_sec IS NULL THEN o_raison := 'section_introuvable'; RETURN; END IF;
  IF v_sec->>'lieutenantNom' IS DISTINCT FROM o_moi THEN
    o_raison := 'pas_lieutenant_de_cette_section'; RETURN;
  END IF;
  o_raison := NULL;
END; $function$


-- ========== militaire_sections_remplacer(jsonb,text,jsonb) ==========
CREATE OR REPLACE FUNCTION public.militaire_sections_remplacer(p_data jsonb, p_section_id text, p_nouvelle jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT p_data || jsonb_build_object('sections', COALESCE((
    SELECT jsonb_agg(CASE WHEN s->>'id' = p_section_id THEN p_nouvelle ELSE s END ORDER BY ord)
      FROM jsonb_array_elements(COALESCE(p_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord)
  ), '[]'::jsonb));
$function$


-- ========== militaire_service_fermer(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_service_fermer(p_nom text, p_grade text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.services_militaires SET fin_ts = now()
   WHERE personnage = p_nom AND grade = p_grade AND fin_ts IS NULL;
END; $function$


-- ========== militaire_service_jours(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_service_jours(p_nom text, p_grade text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(sum(extract(epoch FROM (coalesce(fin_ts, now()) - debut_ts)) / 86400.0), 0)
    FROM public.services_militaires
   WHERE personnage = p_nom AND (p_grade IS NULL OR grade = p_grade);
$function$


-- ========== militaire_service_ouvrir(text,text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_service_ouvrir(p_nom text, p_pays text, p_grade text, p_compagnie text, p_section text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Idempotent : une periode deja ouverte pour ce grade n'est pas dupliquee (index unique
  -- partiel). Un double clic ou un rejeu ne cree donc pas deux services simultanes.
  INSERT INTO public.services_militaires (personnage, pays, grade, compagnie_id, section_id)
  SELECT p_nom, p_pays, p_grade, p_compagnie, p_section
   WHERE NOT EXISTS (SELECT 1 FROM public.services_militaires
                      WHERE personnage = p_nom AND grade = p_grade AND fin_ts IS NULL);
END; $function$


-- ========== militaire_soldat_pa_fixer(text,text,text,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_soldat_pa_fixer(p_compagnie_id text, p_section_id text, p_matricule text, p_pa integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_sec jsonb; v_sols jsonb;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN; END IF;
  SELECT coalesce(jsonb_agg(CASE WHEN sol->>'matricule' = p_matricule
           THEN sol || jsonb_build_object('pa', greatest(0, p_pa)) ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
      WITH ORDINALITY AS t(sol, pos);
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
END;
$function$


-- ========== militaire_soldat_retirer(text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_soldat_retirer(p_compagnie_id text, p_section_id text, p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb;
  v_avant int; v_apres int; v_lieut text; v_par text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_nom,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide'); END IF;

  SELECT coalesce(country,'republic') INTO v_pays_moi
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  -- MEME GARDE DE JURIDICTION que militaire_section_de_moi : le banc a montre qu'elle manquait
  -- ici, et un officier d'un empire ne doit pas pouvoir toucher aux effectifs d'un autre.
  IF v_data->>'pays' IS DISTINCT FROM v_pays_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  v_lieut := v_sec->>'lieutenantNom';

  -- DEUX AUTORITES LEGITIMES, et deux seulement : le soldat lui-meme (demission) ou le Lieutenant
  -- de CETTE section (renvoi). Tout autre acteur est refuse.
  IF v_moi = p_nom THEN v_par := 'demission';
  ELSIF v_lieut IS NOT NULL AND v_lieut = v_moi THEN v_par := 'renvoi';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_avant := jsonb_array_length(v_sols);
  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
   WHERE NOT (coalesce((sol->>'pj')::boolean, false) AND sol->>'nom' = p_nom);
  v_apres := jsonb_array_length(v_sols);
  IF v_apres = v_avant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_soldat_de_cette_section');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La periode de service se termine ici : c'est elle, et non le calepin, qui fait foi.
  PERFORM public.militaire_service_fermer(p_nom, 'soldat');

  RETURN jsonb_build_object('ok', true, 'motif', v_par, 'nom', p_nom,
    'effectif', v_apres, 'places_libres', 24 - v_apres);
END; $function$

-- ========== militaire_soldat_supprimer(text,text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_soldat_supprimer(p_compagnie_id text, p_section_id text, p_matricule text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_sec jsonb; v_sols jsonb;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN; END IF;
  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
      WITH ORDINALITY AS t(sol, pos)
   WHERE sol->>'matricule' IS DISTINCT FROM p_matricule;
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
END;
$function$


-- ========== militaire_solde_percevoir() ==========
CREATE OR REPLACE FUNCTION public.militaire_solde_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_pays text; v_grade text; v_du integer; v_jour date; v_id text;
  v_mvt jsonb; v_verse integer; v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;

  -- Baremes GD. Les PNJ n'ont aucune solde : ils ne passent jamais par ici.
  v_du := CASE v_grade WHEN 'soldat' THEN 50 WHEN 'lieutenant' THEN 150
                       WHEN 'capitaine' THEN 250 WHEN 'commandant' THEN 400 END;
  IF v_du IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_sans_solde'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  -- ANTI-REJEU PAR LA CLE : deux clics simultanes ne peuvent pas creer deux lignes.
  BEGIN
    INSERT INTO public.soldes_militaires (id, personnage, pays, grade, jour, du, verse)
    VALUES (v_id, v_moi, v_pays, v_grade, v_jour, v_du, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percue_aujourdhui', 'jour', v_jour);
  END;

  -- Debit PLAFONNE : la caserne verse ce qu'elle peut, le reste devient une dette.
  v_mvt := public.caisse_institution_mouvement_plafonne(v_pays || '_caserne-militaire', v_du);
  v_verse := greatest(0, coalesce((v_mvt->>'verse')::integer, 0));

  IF v_verse > 0 THEN
    v_credit := public.assemblee_crediter_joueur(v_moi, v_verse);
  END IF;
  UPDATE public.soldes_militaires
     SET verse = v_verse, regle_le = CASE WHEN v_verse >= v_du THEN now() END
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'grade', v_grade, 'du', v_du, 'verse', v_verse,
    'dette', v_du - v_verse, 'jour', v_jour,
    'liquide', v_credit->'liquide', 'arg', v_credit->'arg');
END; $function$


-- ========== militaire_subtiliser(text,text) ==========
CREATE OR REPLACE FUNCTION public.militaire_subtiliser(p_pays text, p_joueur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pj public.personnages%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  RETURN public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
END;
$function$


-- ========== militaire_subtiliser_tenter(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_subtiliser_tenter(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_seuil_detection constant integer := 20;
  c_seuil_reussite  constant integer := 66;
  c_isn_defaut      constant integer := 30;
  v_moi text; v_pj public.personnages_donnees%ROWTYPE;
  v_dup numeric; v_isn integer; v_rep integer; v_bonus_rep integer;
  v_bonus numeric; v_jet integer; v_score integer;
  v_stock jsonb; v_objet jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF coalesce(v_pj.current_building,'') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LE PA EST DEBITE AVANT LE JET, comme pour toute tentative : on paie l'essai, pas le resultat.
  IF coalesce(v_pj.pa, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', 2);
  END IF;

  -- DUP effective : meme regle que getStatEffective -- une caracteristique affaiblie est
  -- proportionnelle aux points de vie, jamais en dessous de 1.
  v_dup := coalesce((v_pj.stats->>'DUP')::numeric, 8);
  IF v_pj.stats_affaiblies ? 'DUP' THEN
    v_dup := greatest(1, round(v_dup * greatest(0, least(1, coalesce(v_pj.hp,0)::numeric / 100))));
  END IF;

  -- ISN de la zone. La caserne n'a pas d'indices propres : repli sur le defaut, exactement comme
  -- getIndiceVille cote client.
  SELECT coalesce((data->>'isn')::integer, c_isn_defaut) INTO v_isn
    FROM public.indices_villes WHERE id = p_pays || '_' || coalesce(v_pj.current_city,'');
  v_isn := coalesce(v_isn, c_isn_defaut);

  v_rep := greatest(0, least(100, coalesce(v_pj.reputation_criminelle, 0)));
  v_bonus_rep := CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END;

  v_bonus := (v_dup - 10) * 2 - (v_isn - 45)::numeric / 3 + v_bonus_rep;
  v_jet := floor(random() * 100)::integer + 1 - 50;
  v_score := greatest(0, least(100, round(50 + v_bonus + v_jet)::integer));

  UPDATE public.personnages_donnees SET pa = greatest(0, coalesce(pa,0) - 2) WHERE name = v_moi;

  IF v_score < c_seuil_reussite THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false,
      'detecte', v_score < c_seuil_detection, 'score', v_score);
  END IF;

  -- REUSSITE. Le stock est decremente AVANT que l'objet n'existe : jamais d'explosif cree de rien.
  v_stock := public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
  IF coalesce((v_stock->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false, 'detecte', false,
      'score', v_score, 'raison', 'stock_insuffisant');
  END IF;

  -- ...et c'est le SERVEUR qui le pose dans l'inventaire, plus le navigateur.
  v_objet := jsonb_build_object(
    'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
    'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
    'lot', coalesce(v_stock->'lots'->0->>'lot', 'legacy'),
    'produitMilitaire', 'explosif_militaire', 'name', 'Explosif militaire',
    'icon', 'ti-bomb', 'legal', true, 'imageUrl', NULL,
    'desc', 'Explosif militaire. Lot ' || coalesce(v_stock->'lots'->0->>'lot', 'legacy') || '.');

  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END)
                     || jsonb_build_array(v_objet)
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'reussite', true, 'detecte', false,
    'score', v_score, 'objet', v_objet, 'lot', v_objet->>'lot');
END;
$function$


-- ========== militaire_taux_combat(numeric,numeric,numeric,integer) ==========
CREATE OR REPLACE FUNCTION public.militaire_taux_combat(p_comp_off numeric, p_comp_cible numeric, p_stat_cible numeric, p_bonus_arme integer DEFAULT 0)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(10, least(85, round(
      50 + coalesce(p_comp_off, 0) / 3.0
         - coalesce(p_comp_cible, 0) / 5.0
         - (coalesce(p_stat_cible, 8) - 8)
         + coalesce(p_bonus_arme, 0)
    )::integer));
$function$


-- ========== militaire_trousse_retirer() ==========
CREATE OR REPLACE FUNCTION public.militaire_trousse_retirer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_plafond constant integer := 100;
  v_moi text; v_pays text; v_bat text; v_inv jsonb; v_occupe numeric;
  v_data jsonb; v_commun jsonb; v_tex integer; v_med integer; v_des integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country,'republic'), coalesce(current_building,''),
         CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_pays, v_bat, v_inv
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- La PIECE determine ce qu'on peut fabriquer ; le BATIMENT determine les matieres accessibles.
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + 1 > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes'); END IF;
  v_commun := CASE WHEN jsonb_typeof(v_data->'caserneMatieres')='object'
                   THEN v_data->'caserneMatieres' ELSE '{}'::jsonb END;
  v_tex := greatest(0, coalesce((v_commun->>'textile')::integer, 0));
  v_med := greatest(0, coalesce((v_commun->>'medicaments')::integer, 0));
  v_des := greatest(0, coalesce((v_commun->>'desinfectant')::integer, 0));

  IF v_tex < 1 OR v_med < 1 OR v_des < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
      'textile', v_tex, 'medicaments', v_med, 'desinfectant', v_des);
  END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('caserneMatieres',
           v_commun || jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1,
                                          'desinfectant', v_des - 1)),
         updated_at = now()
   WHERE id = v_pays;

  UPDATE public.personnages_donnees
     SET inventory = v_inv || jsonb_build_array(jsonb_build_object(
           'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
           'type', 'soin', 'sousType', 'militaire', 'produitMilitaire', 'trousse_secours',
           'origineMilitaire', true, 'usageUnique', true,
           'name', 'Trousse de premiers secours', 'icon', 'ti-first-aid-kit',
           'legal', true,
           'imageUrl', 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/militaire-trousse-secours.png',
           'desc', 'Trousse de premiers secours. Usage unique. Restaure des PA, d''autant plus que le soignant maîtrise le Secourisme.'))
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'fabriquee', true,
    'restant', jsonb_build_object('textile', v_tex - 1, 'medicaments', v_med - 1, 'desinfectant', v_des - 1));
END;
$function$


-- ========== militaire_trousse_utiliser(text) ==========
CREATE OR REPLACE FUNCTION public.militaire_trousse_utiliser(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj constant integer := 30;
  v_moi text; v_inv jsonb; v_pos integer; v_sec numeric; v_gain integer;
  v_cible text; v_pa_avant integer; v_pa_apres integer;
  m record; c record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := coalesce(nullif(btrim(coalesce(p_cible,'')), ''), v_moi);

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END,
         coalesce((competences_militaires->>'secourisme')::numeric, 0)
    INTO v_inv, v_sec FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- CO-PRESENCE, MOTIF DE impact_deposer : pays + ville + batiment + piece identiques,
  -- verifiee AVANT toute ecriture pour qu'un refus ne consomme pas la trousse.
  IF v_cible <> v_moi THEN
    SELECT country, current_city, current_building, current_room INTO m
      FROM public.personnages_donnees WHERE name = v_moi;
    SELECT name, country, current_city, current_building, current_room INTO c
      FROM public.personnages_donnees WHERE name = v_cible;
    IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
    IF m.country IS DISTINCT FROM c.country
       OR m.current_city IS DISTINCT FROM c.current_city
       OR m.current_building IS DISTINCT FROM c.current_building
       OR m.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
  END IF;

  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'trousse_secours' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_trousse'); END IF;

  -- +2 de base, +1 par tranche COMPLETE de 25 de Secourisme DU SOIGNANT.
  v_gain := 2 + floor(least(100, greatest(0, v_sec)) / 25)::integer;

  SELECT coalesce(pa, 0) INTO v_pa_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_pa_avant IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
  v_pa_apres := least(c_pa_max_pj, v_pa_avant + v_gain);

  -- USAGE UNIQUE : la trousse quitte l'inventaire dans la MEME transaction que le gain.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  UPDATE public.personnages_donnees SET pa = v_pa_apres WHERE name = v_cible;

  RETURN jsonb_build_object('ok', true, 'soignant', v_moi, 'cible', v_cible,
    'secourisme', v_sec, 'gain_theorique', v_gain,
    'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres, 'gain_reel', v_pa_apres - v_pa_avant);
END; $function$


-- ========== mutinerie_camp_de(text) ==========
CREATE OR REPLACE FUNCTION public.mutinerie_camp_de(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT mm.camp FROM public.mutineries_membres mm
    JOIN public.mutineries m ON m.camp = mm.camp
   WHERE mm.personnage = p_nom AND mm.statut = 'actif' AND m.statut = 'active'
   LIMIT 1;
$function$


-- ========== mutinerie_camps_presents(text,text,text,text) ==========
CREATE OR REPLACE FUNCTION public.mutinerie_camps_presents(p_pays text, p_ville text, p_bat text, p_piece text)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce(array_agg(DISTINCT t.camp), '{}'::text[]) FROM (
    SELECT coalesce(sol->>'mutin', c.data->>'pays') AS camp
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' = p_pays
       AND NOT coalesce((sol->>'pj')::boolean, false)
       AND coalesce((sol->>'pa')::integer, 0) > 0
       AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
             AND (sol->>'leaderCourant') IS NULL)
         OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                     WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                       AND chef.current_building = p_bat AND chef.current_room = p_piece))
    UNION ALL
    SELECT coalesce(public.mutinerie_camp_de(pd.name), pd.country)
      FROM public.personnages_donnees pd
      JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
     WHERE pd.country = p_pays AND pd.current_city = p_ville
       AND pd.current_building = p_bat AND pd.current_room = p_piece
       AND coalesce(pd.pa, 0) > 0
  ) t;
$function$


-- ========== mutinerie_est_camp(text) ==========
CREATE OR REPLACE FUNCTION public.mutinerie_est_camp(p_camp text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.mutineries WHERE camp = p_camp);
$function$


-- ========== mutinerie_pays_du_camp(text) ==========
CREATE OR REPLACE FUNCTION public.mutinerie_pays_du_camp(p_camp text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce((SELECT m.pays FROM public.mutineries m WHERE m.camp = p_camp), p_camp);
$function$


-- ========== mutinerie_social_national(text) ==========
CREATE OR REPLACE FUNCTION public.mutinerie_social_national(p_pays text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE WHEN count(*) = 3 THEN round(avg((v.data ->> 'social')::numeric), 2) ELSE 45 END
    FROM public.indices_villes v
   WHERE v.id = ANY (ARRAY[p_pays || '_capitale', p_pays || '_ville_a', p_pays || '_ville_b'])
     AND jsonb_typeof(v.data -> 'social') = 'number';
$function$


-- ========== poste_est_atteste(text,jsonb,text) ==========
CREATE OR REPLACE FUNCTION public.poste_est_atteste(p_nom text, p_poste jsonb, p_pays text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text; v_city text; v_cycle text;
BEGIN
  IF p_poste IS NULL OR jsonb_typeof(p_poste) = 'null' THEN RETURN true; END IF;
  IF jsonb_typeof(p_poste) <> 'object' THEN RETURN false; END IF;
  v_id   := p_poste ->> 'id';
  v_city := nullif(p_poste ->> 'city', '');
  IF v_id IS NULL OR v_id = '' THEN RETURN false; END IF;

  -- a) POSTES ELUS : la verite est le depouillement, ecrit par le cron.
  IF v_id IN ('president', 'maire', 'chef_syndicat') THEN
    SELECT c.data INTO v_cycle FROM public.cycles_electoraux c
     WHERE c.country = p_pays AND c.poste_id = v_id
       AND c.city IS NOT DISTINCT FROM v_city
     LIMIT 1;
    IF v_cycle IS NULL OR left(btrim(v_cycle), 1) <> '{' THEN RETURN false; END IF;
    RETURN (v_cycle::jsonb ->> 'eluId') = p_nom;
  END IF;

  IF v_id = 'depute' THEN
    SELECT c.data INTO v_cycle FROM public.cycles_electoraux c
     WHERE c.country = p_pays AND c.poste_id = 'depute'
       AND c.city IS NOT DISTINCT FROM v_city
     LIMIT 1;
    IF v_cycle IS NULL OR left(btrim(v_cycle), 1) <> '{' THEN RETURN false; END IF;
    RETURN (v_cycle::jsonb -> 'elus') ? p_nom;
  END IF;

  -- b) POSTES MILITAIRES : la verite est la compagnie.
  IF v_id = 'capitaine' THEN
    RETURN EXISTS (SELECT 1 FROM public.compagnies_militaires m
                    WHERE m.data ->> 'capitaineNom' = p_nom);
  END IF;
  IF v_id = 'lieutenant' THEN
    RETURN EXISTS (SELECT 1 FROM public.compagnies_militaires m,
                        jsonb_array_elements(coalesce(m.data -> 'sections', '[]'::jsonb)) s
                    WHERE s ->> 'lieutenantNom' = p_nom);
  END IF;

  -- c) TOUT LE RESTE : un poste nomme n'existe que s'il est inscrit au registre. Fail closed --
  --    un identifiant inconnu n'est jamais accepte.
  RETURN EXISTS (SELECT 1 FROM public.postes_attribues a
                  WHERE a.titulaire = p_nom AND a.poste_id = v_id
                    AND a.country = p_pays AND a.city IS NOT DISTINCT FROM v_city);
END;
$function$


-- ========== refectoire_repas(text,text,integer,integer,integer) ==========
CREATE OR REPLACE FUNCTION public.refectoire_repas(p_pays text, p_joueur text, p_jour integer, p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pj personnages%ROWTYPE; v_pays text; v_jour text; v_stats jsonb;
  v_data jsonb; v_ref jsonb; v_commun jsonb; v_rations integer;
  v_cer integer; v_via integer; v_poi integer; v_prot text; v_fab boolean := false; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- Ni le pays ni le jour ne sont crus : le batiment 'caserne-militaire' existe dans les quatre
  -- empires, et p_jour etait un robinet de PA. p_pays, p_jour, p_gain et p_pa_max sont ignores.
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_pj.country, '')), ''), 'republic');
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE(v_stats ->> 'repasCaserneJour', '') = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange', 'jourCle', v_jour);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_ref := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object'
                THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_commun := CASE WHEN jsonb_typeof(v_data -> 'caserneMatieres') = 'object'
                   THEN v_data -> 'caserneMatieres' ELSE '{}'::jsonb END;
  v_rations := GREATEST(0, COALESCE((v_ref ->> 'rations')::integer, 0));

  IF v_rations <= 0 THEN
    -- Fabrication automatique d'un lot de 10, sur le STOCK COMMUN : 1 cereale + 1 (viande OU poisson).
    v_cer := GREATEST(0, COALESCE((v_commun ->> 'cereales')::integer, 0));
    v_via := GREATEST(0, COALESCE((v_commun ->> 'viande')::integer, 0));
    v_poi := GREATEST(0, COALESCE((v_commun ->> 'poisson')::integer, 0));
    IF v_cer < 1 OR (v_via + v_poi) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
                                'cereales', v_cer, 'viande', v_via, 'poisson', v_poi);
    END IF;
    v_prot := CASE WHEN v_via >= 1 THEN 'viande' ELSE 'poisson' END;
    v_commun := v_commun || jsonb_build_object('cereales', v_cer - 1,
                  v_prot, (CASE WHEN v_prot = 'viande' THEN v_via ELSE v_poi END) - 1);
    v_rations := 10;
    v_fab := true;
  END IF;

  v_rations := v_rations - 1;
  v_data := v_data
            || jsonb_build_object('caserneMatieres', v_commun)
            || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_rations));
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = v_pays;

  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa, stats = v_stats || jsonb_build_object('repasCaserneJour', v_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot,
                            'pays', v_pays, 'jourCle', v_jour);
END; $function$

