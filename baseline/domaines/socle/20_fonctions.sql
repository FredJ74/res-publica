-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- achat_requete_clore_interne(text,uuid,text,jsonb,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.achat_requete_clore_interne(p_acteur text, p_requete uuid, p_action text, p_parametres jsonb, p_resultat jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record;
BEGIN
  INSERT INTO public.inventaire_actions_recus(acteur, requete, action, parametres, resultat, cree_le)
  VALUES (p_acteur, p_requete, p_action, p_parametres, p_resultat - 'inventory', now());
  SELECT inventory, inventory_revision, pa, liquide, arg INTO d FROM public.personnages_donnees WHERE name = p_acteur;
  RETURN p_resultat || jsonb_build_object('inventory', d.inventory, 'revision', d.inventory_revision,
    'paie', jsonb_build_object('pa', d.pa, 'liquide', d.liquide, 'arg', d.arg,
      'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires
                                  WHERE personnage = p_acteur AND banque = 'nationale'), 0)));
END; $function$;

-- achat_requete_ouvrir_interne(text,uuid,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.achat_requete_ouvrir_interne(p_acteur text, p_requete uuid, p_action text, p_parametres jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('inventaire_action:' || p_acteur || ':' || p_requete::text, 0));
  RETURN public.inventaire_action_rejouer_interne(p_acteur, p_requete, p_action, p_parametres);
END; $function$;

-- acte_nocturne_revendiquer(text,text,text,jsonb) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acte_nocturne_revendiquer(p_pays text, p_mecanisme text, p_sujet text DEFAULT '-'::text, p_details jsonb DEFAULT NULL::jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pays   text := lower(btrim(coalesce(p_pays, '')));
  v_meca   text := lower(btrim(coalesce(p_mecanisme, '')));
  v_sujet  text := btrim(coalesce(p_sujet, ''));
  v_n      integer;
BEGIN
  -- FAIL-CLOSED : une identite incomplete LEVE. Rendre false voudrait dire « deja fait ».
  IF v_pays = '' OR v_meca = '' THEN
    RAISE EXCEPTION 'acte_nocturne_revendiquer : pays et mecanisme sont obligatoires (pays=%, mecanisme=%)', p_pays, p_mecanisme;
  END IF;
  IF v_sujet = '' THEN
    v_sujet := '-';
  END IF;
  -- LE JOUR N'EST PAS UN PARAMETRE. Europe/Paris, comme jourParisISO() cote JavaScript.
  INSERT INTO public.actes_nocturnes (pays, mecanisme, sujet, jour, details)
  VALUES (v_pays, v_meca, v_sujet, (now() AT TIME ZONE 'Europe/Paris')::date, p_details)
  ON CONFLICT (pays, mecanisme, sujet, jour) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n = 1;
END; $function$;

-- acteur_est_moi(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acteur_est_moi(p_ref text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.est_appel_serveur() OR public.titulaire_est_moi(p_ref);
$function$;

-- acteur_identifie() -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acteur_identifie()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.est_appel_serveur() OR public.mon_personnage() IS NOT NULL;
$function$;

-- acteur_poste_courant() -> TABLE(nom text, poste_id text, poste_city text, pays text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acteur_poste_courant()
 RETURNS TABLE(nom text, poste_id text, poste_city text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name, p.poste->>'id', p.poste->>'city', p.country
    FROM public.personnages_donnees p
   WHERE p.user_id = auth.uid()
   LIMIT 1;
$function$;

-- acteur_present_sur_site(text,text,text,text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.acteur_present_sur_site(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE a record; v_siege text;
BEGIN
  -- FERME PAR DEFAUT. Un site dont on ignore le pays, la ville ou le batiment ne
  -- permet pas d'etablir une presence : on refuse, on ne devine pas.
  IF p_acteur IS NULL OR coalesce(p_pays, '') = ''
     OR coalesce(p_ville, '') = '' OR coalesce(p_batiment, '') = '' THEN
    RETURN false;
  END IF;

  -- LE SIEGE D'UN PNJ TITULAIRE INCARNE.
  IF p_acteur = public.incarnation_courante() THEN
    v_siege := public.incarnation_siege();
    IF v_siege IS NULL THEN RETURN false; END IF;
    RETURN p_pays IS NOT DISTINCT FROM public.incarnation_pays()
       AND p_ville IS NOT DISTINCT FROM v_siege
       AND p_batiment IS NOT DISTINCT FROM public.parquet_site_competent(p_pays, v_siege);
  END IF;

  -- LA POSITION FAISANT AUTORITE, et elle seule. Le navigateur ne transmet ici
  -- aucune localisation : il ne pourrait pas mentir meme s'il essayait.
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR a.current_city IS NULL OR a.current_building IS NULL THEN
    RETURN false;
  END IF;

  IF a.country          IS DISTINCT FROM p_pays     THEN RETURN false; END IF;
  IF a.current_city     IS DISTINCT FROM p_ville    THEN RETURN false; END IF;
  IF a.current_building IS DISTINCT FROM p_batiment THEN RETURN false; END IF;

  -- La piece ne compte que si le site en designe une. Sept commerces du jeu
  -- occupent leur batiment entier (voir commerces_types) : y etre, c'est y etre.
  IF coalesce(p_piece, '') <> '' AND a.current_room IS DISTINCT FROM p_piece THEN
    RETURN false;
  END IF;

  RETURN true;
END $function$;

-- admin_exiger() -> uuid | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_exiger()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- ELLE LEVE, ELLE NE REFUSE PAS. Un refus propre serait jete par un appelant distrait ; une
  -- exception annule la transaction entiere. C'est la meme doctrine que `exiger_poste`.
  IF NOT public.est_administrateur() THEN
    RAISE EXCEPTION 'autorite_administrateur_requise' USING ERRCODE = '42501';
  END IF;
  RETURN auth.uid();
END $function$;

-- admin_incarner(text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_incarner(p_poste text, p_action text, p_affaire_id text, p_params jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; v_lib text; v_pays text := 'republic'; v_ville_poste text;
  v_a record; v_pnj text; v_p jsonb; v_r jsonb;
BEGIN
  v_uid := public.admin_exiger();
  SELECT a.libelle INTO v_lib FROM public.administrateurs a WHERE a.user_id = v_uid;
  v_p := CASE WHEN jsonb_typeof(p_params) = 'object' THEN p_params ELSE '{}'::jsonb END;

  -- LE PERIMETRE EST FERME, ET IL TIENT EN DEUX POSTES.
  IF p_poste = 'procureur' THEN v_ville_poste := NULL;
  ELSIF p_poste = 'juge'   THEN v_ville_poste := 'capitale';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_hors_perimetre', 'poste', p_poste);
  END IF;

  SELECT * INTO v_a FROM public.admin_actions_tribunal a
   WHERE a.poste = p_poste AND a.action = p_action;
  IF v_a.action IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_hors_perimetre',
                              'poste', p_poste, 'action', p_action);
  END IF;

  -- LA TITULARITE EST VERIFIEE MAINTENANT, pas a l'ouverture de l'ecran. Un PJ nomme entre les
  -- deux ferme la porte, y compris si le client appelle directement.
  v_pnj := public.admin_pnj_titulaire(v_pays, p_poste, v_ville_poste);
  IF v_pnj IS NULL THEN
    INSERT INTO public.admin_journal (admin_user_id, admin_libelle, pnj, poste, affaire,
                                      action, parametres, resultat, ok)
    VALUES (v_uid, v_lib, NULL, p_poste, p_affaire_id, p_action, v_p,
            jsonb_build_object('raison', 'poste_tenu_par_un_pj'), false);
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_tenu_par_un_pj', 'poste', p_poste);
  END IF;

  PERFORM set_config('rp.incarnation_pnj', v_pnj, true);
  PERFORM set_config('rp.incarnation_pays', v_pays, true);
  PERFORM set_config('rp.incarnation_siege', coalesce(v_ville_poste, 'capitale'), true);

  -- AUCUN SQL DYNAMIQUE : dix appels nommes, et pas un de plus. Ce sont EXACTEMENT les fonctions
  -- que le titulaire appellerait, avec leurs gardes intactes.
  v_r := CASE
    WHEN p_poste = 'procureur' AND p_action = 'enqueter'
      THEN public.parquet_enqueter(p_affaire_id)
    WHEN p_poste = 'procureur' AND p_action = 'poursuivre'
      THEN public.parquet_poursuivre(p_affaire_id, v_p ->> 'infraction')
    WHEN p_poste = 'procureur' AND p_action = 'non_lieu'
      THEN public.parquet_non_lieu(p_affaire_id, v_p ->> 'motif')
    WHEN p_poste = 'procureur' AND p_action = 'transmettre_juge'
      THEN public.parquet_transmettre_juge(p_affaire_id)
    WHEN p_poste = 'procureur' AND p_action = 'abandonner'
      THEN public.parquet_abandonner(p_affaire_id, v_p ->> 'motif')
    WHEN p_poste = 'procureur' AND p_action = 'appel_ouvrir'
      THEN public.justice_appel_ouvrir(p_affaire_id)
    WHEN p_poste = 'juge' AND p_action = 'relaxer'
      THEN public.justice_relaxer(p_affaire_id, v_p ->> 'infraction')
    WHEN p_poste = 'juge' AND p_action = 'rendre_sentence'
      THEN public.justice_rendre_sentence(p_affaire_id, v_p ->> 'infraction',
             v_p ->> 'genre', (v_p ->> 'jours')::integer, (v_p ->> 'amende')::integer)
    WHEN p_poste = 'juge' AND p_action = 'suite_apres_abandon'
      THEN public.juge_suite_apres_abandon(p_affaire_id, v_p ->> 'decision')
    WHEN p_poste = 'juge' AND p_action = 'juger_appel'
      THEN public.justice_appel_juger(p_affaire_id, v_p ->> 'verdict', v_p ->> 'infraction',
             v_p ->> 'genre', (v_p ->> 'jours')::integer, (v_p ->> 'amende')::integer)
  END;

  PERFORM set_config('rp.incarnation_pnj', '', true);
  PERFORM set_config('rp.incarnation_pays', '', true);
  PERFORM set_config('rp.incarnation_siege', '', true);

  -- L'AUDIT EST PRIVE, ET IL NE CHANGE RIEN A LA REPRESENTATION PUBLIQUE DE L'ACTE.
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, pnj, poste, affaire,
                                    action, parametres, resultat, ok)
  VALUES (v_uid, v_lib, v_pnj, p_poste, p_affaire_id, p_action, v_p, v_r,
          coalesce((v_r ->> 'ok')::boolean, false));

  RETURN coalesce(v_r, jsonb_build_object('ok', false, 'raison', 'action_sans_effet'));
END $function$;

-- admin_journal_append_only() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_journal_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'admin_journal est en ajout seul : ni modification ni suppression (%)', TG_OP
    USING ERRCODE = '42501';
END $function$;

-- admin_moi() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_moi()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
    'ok', true,
    'administrateur', public.est_administrateur(),
    'libelle', (SELECT a.libelle FROM public.administrateurs a
                 WHERE a.user_id = auth.uid() AND a.actif),
    -- L'APPELANT N'APPREND RIEN SUR LES AUTRES. Vrai seulement s'il a LUI-MEME une invitation
    -- non consommee, sur une adresse confirmee. Un compte sans invitation lit `false` et ne
    -- distingue donc pas une administration constituee d'une administration vide.
    'invitation_ouverte', EXISTS (
       SELECT 1 FROM auth.users u
         JOIN public.administrateurs_invitations i ON i.email = lower(btrim(u.email))
        WHERE u.id = auth.uid()
          AND coalesce(u.is_anonymous, false) IS FALSE
          AND u.email_confirmed_at IS NOT NULL
          AND i.consommee_le IS NULL));
$function$;

-- admin_pnj_titulaire(text,text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_pnj_titulaire(p_pays text, p_poste text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN EXISTS (
      SELECT 1 FROM public.personnages_donnees d
       WHERE d.country = p_pays AND (d.poste ->> 'id') = p_poste
         AND (d.poste ->> 'city') IS NOT DISTINCT FROM p_ville)
    THEN NULL
    ELSE (SELECT t.nom_pnj FROM public.titulaires_pnj t
           WHERE t.country = p_pays AND t.poste_id = p_poste
             AND t.city IS NOT DISTINCT FROM p_ville LIMIT 1)
  END;
$function$;

-- admin_se_declarer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_se_declarer(p_libelle text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid; v_u record; v_email text; v_n integer; v_lib text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_session');
  END IF;
  v_lib := coalesce(nullif(btrim(coalesce(p_libelle, '')), ''), 'Administration');

  -- UNE IDENTITE REELLE ET CONFIRMEE, PAS UN ANONYME. Les comptes joueurs sont anonymes
  -- (chantier B) : aucun d'eux ne peut franchir cette ligne. Et la confirmation est ce qui
  -- prouve que l'appelant tient la boite de l'adresse invitee.
  SELECT u.email, u.is_anonymous, u.email_confirmed_at INTO v_u
    FROM auth.users u WHERE u.id = v_uid;
  IF NOT FOUND OR coalesce(v_u.is_anonymous, false) IS TRUE
     OR coalesce(btrim(coalesce(v_u.email, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_sans_identite_reelle');
  END IF;
  IF v_u.email_confirmed_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'adresse_non_confirmee');
  END IF;
  v_email := lower(btrim(v_u.email));

  -- « CE N'EST PAS LE COMPTE JOUEUR. » Verifie, pas suppose.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_porte_un_personnage');
  END IF;

  -- L'INVITATION EST LA SEULE PORTE, et elle se consomme par COMPARE-AND-SWAP : deux onglets
  -- simultanes ne peuvent pas la prendre tous les deux.
  IF NOT EXISTS (SELECT 1 FROM public.administrateurs_invitations i WHERE i.email = v_email) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_invitation');
  END IF;
  UPDATE public.administrateurs_invitations
     SET consommee_le = now(), consommee_par = v_uid
   WHERE email = v_email AND consommee_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'invitation_deja_consommee');
  END IF;

  INSERT INTO public.administrateurs (user_id, libelle)
  VALUES (v_uid, v_lib)
  ON CONFLICT (user_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'administrateur_deja_inscrit');
  END IF;

  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, ok, resultat)
  VALUES (v_uid, v_lib, 'declaration_premier_administrateur', true,
          jsonb_build_object('email', v_email, 'invitation', v_email));
  RETURN jsonb_build_object('ok', true, 'administrateur', true);
END $function$;

-- admin_tribunal_dossiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.admin_tribunal_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; v_pays text := 'republic';
  v_saad text; v_honore text; v_parquet jsonb; v_juge jsonb; v_attente integer;
BEGIN
  v_uid := public.admin_exiger();

  -- LE PARQUET, PAR LES YEUX DE SAAD -- s'il est reellement titulaire.
  v_saad := public.admin_pnj_titulaire(v_pays, 'procureur', NULL);
  IF v_saad IS NOT NULL THEN
    PERFORM set_config('rp.incarnation_pnj', v_saad, true);
    PERFORM set_config('rp.incarnation_pays', v_pays, true);
    PERFORM set_config('rp.incarnation_siege', 'capitale', true);
    v_parquet := public.parquet_dossiers();
    PERFORM set_config('rp.incarnation_pnj', '', true);
    PERFORM set_config('rp.incarnation_pays', '', true);
    PERFORM set_config('rp.incarnation_siege', '', true);
  ELSE
    v_parquet := jsonb_build_object('ok', false, 'raison', 'poste_tenu_par_un_pj');
  END IF;

  -- LE TRIBUNAL, PAR LES YEUX D'HONORE -- juge de la capitale, et de nulle part ailleurs.
  v_honore := public.admin_pnj_titulaire(v_pays, 'juge', 'capitale');
  IF v_honore IS NOT NULL THEN
    PERFORM set_config('rp.incarnation_pnj', v_honore, true);
    PERFORM set_config('rp.incarnation_pays', v_pays, true);
    PERFORM set_config('rp.incarnation_siege', 'capitale', true);
    v_juge := public.juge_dossiers();
    PERFORM set_config('rp.incarnation_pnj', '', true);
    PERFORM set_config('rp.incarnation_pays', '', true);
    PERFORM set_config('rp.incarnation_siege', '', true);
  ELSE
    v_juge := jsonb_build_object('ok', false, 'raison', 'poste_tenu_par_un_pj');
  END IF;

  -- L'INDICATEUR DISCRET : combien de dossiers attendent une decision institutionnelle. Compte,
  -- pas alerte -- et aucune notification nulle part.
  SELECT count(*) INTO v_attente FROM (
    SELECT (d -> 'dossier') ->> 'status' AS st, 'procureur' AS po
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_parquet -> 'dossiers') = 'array'
                                     THEN v_parquet -> 'dossiers' ELSE '[]'::jsonb END) d
    UNION ALL
    SELECT (d -> 'dossier') ->> 'status', 'juge'
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_juge -> 'dossiers') = 'array'
                                     THEN v_juge -> 'dossiers' ELSE '[]'::jsonb END) d
  ) x
  WHERE EXISTS (SELECT 1 FROM public.admin_actions_tribunal a
                 WHERE a.poste = x.po AND x.st = ANY (a.statuts));

  RETURN jsonb_build_object(
    'ok', true,
    'pays', v_pays,
    'admin', (SELECT a.libelle FROM public.administrateurs a WHERE a.user_id = v_uid),
    'parquet', jsonb_build_object('pnj', v_saad, 'incarnable', v_saad IS NOT NULL,
                                  'vue', v_parquet),
    'juge', jsonb_build_object('pnj', v_honore, 'incarnable', v_honore IS NOT NULL,
                               'ville', 'capitale', 'vue', v_juge),
    'actions', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'poste', a.poste, 'action', a.action, 'libelle', a.libelle,
                  'statuts', to_jsonb(a.statuts)) ORDER BY a.poste, a.ordre), '[]'::jsonb)
                 FROM public.admin_actions_tribunal a),
    'en_attente', v_attente,
    'lu_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
END $function$;

-- carriere_initiale(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.carriere_initiale(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE coalesce(d.career, '')
           WHEN 'civil' THEN 'magistrat' WHEN 'local_civil' THEN 'magistrat'
           WHEN 'lawyer' THEN 'magistrat' WHEN 'influencer' THEN 'press'
           WHEN 'academic' THEN 'doctor'  WHEN 'lobbyist' THEN 'business'
           WHEN 'union' THEN 'worker'     WHEN 'unemployed' THEN 'worker'
           ELSE d.career END
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$function$;

-- carriere_possede(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.carriere_possede(p_nom text, p_carriere text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_carriere = ANY (public.carrieres_de(p_nom));
$function$;

-- carrieres_de(text) -> text[] | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.carrieres_de(p_nom text)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT ARRAY(SELECT DISTINCT x FROM unnest(ARRAY[
           public.carriere_initiale(p_nom),
           (SELECT a.carriere FROM public.carrieres_acquises a WHERE a.personnage = p_nom)
         ]) AS x WHERE x IS NOT NULL);
$function$;

-- combat_coup_resoudre(numeric,numeric,numeric,integer,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.combat_coup_resoudre(p_comp_attaque numeric, p_comp_defense numeric, p_stat_defense numeric, p_bonus_arme integer, p_pa_cible integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_taux integer;
  v_jet integer;
  v_degre text;
  v_pa integer;
BEGIN
  IF p_comp_attaque IS NULL OR p_comp_defense IS NULL OR
     p_stat_defense IS NULL OR p_pa_cible IS NULL OR
     p_pa_cible < 0 OR p_pa_cible > 100000 OR
     p_comp_attaque < 0 OR p_comp_defense < 0 OR p_stat_defense < 0 OR
     p_comp_attaque > 1000 OR p_comp_defense > 1000 OR p_stat_defense > 1000 OR
     coalesce(p_bonus_arme,0) NOT BETWEEN -100 AND 100 THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');
  END IF;
  v_taux := public.militaire_taux_combat(
    p_comp_attaque,p_comp_defense,p_stat_defense,coalesce(p_bonus_arme,0));
  v_jet := floor(random()*100)::integer+1;
  v_degre := public.militaire_degre_combat(v_taux,v_jet);
  v_pa := public.militaire_pa_restants(p_pa_cible,v_degre);
  RETURN jsonb_build_object('ok',true,'taux',v_taux,'jet',v_jet,
    'degre',v_degre,'pa_avant',p_pa_cible,'pa_apres',v_pa,
    'perte',p_pa_cible-v_pa,'neutralise',v_pa=0);
END;
$function$;

-- deplacement_enregistrer(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.deplacement_enregistrer(p_city text, p_building text, p_room text, p_heure text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_jour integer; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_building IS NULL OR p_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_incomplete'); END IF;

  SELECT coalesce(country, 'republic'), coalesce(day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- Dedoublonnage : un battement au meme endroit n'ecrit RIEN.
  SELECT h.city, h.building_id, h.room_id INTO d
    FROM public.historique_deplacements h
   WHERE h.name = v_moi ORDER BY h.created_at DESC LIMIT 1;
  IF FOUND AND d.city IS NOT DISTINCT FROM p_city
           AND d.building_id IS NOT DISTINCT FROM p_building
           AND d.room_id IS NOT DISTINCT FROM p_room THEN
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'position_inchangee');
  END IF;

  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure)
  VALUES (v_moi, v_pays, p_city, p_building, p_room, v_jour, p_heure);
  RETURN jsonb_build_object('ok', true, 'enregistre', true);
END;
$function$;

-- eg_etat_id(text,jsonb) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.eg_etat_id(p_pays text, p_entrepot jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_pays || '_' || (p_entrepot ->> 'city') || '_' || (p_entrepot ->> 'building');
$function$;

-- eg_etat_lire(jsonb) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.eg_etat_lire(p_brut jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_brut IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof(p_brut) = 'string' THEN (p_brut #>> '{}')::jsonb
    WHEN jsonb_typeof(p_brut) = 'object' THEN p_brut
    ELSE '{}'::jsonb END;
$function$;

-- embargo_actif(text,text) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.embargo_actif(p_pays_soi text, p_pays_cible text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((
    SELECT (data -> 'sanctions' -> p_pays_cible -> 'mesures') ? 'embargo'
      FROM public.budgets_nationaux
     WHERE id = p_pays_soi
       AND jsonb_typeof(data -> 'sanctions' -> p_pays_cible -> 'mesures') = 'array'
  ), false);
$function$;

-- enigme_objet_recevoir(uuid,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp, TimeZone=UTC
CREATE OR REPLACE FUNCTION public.enigme_objet_recevoir(p_requete uuid, p_action text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'UTC'
AS $function$
DECLARE a public.personnages_donnees; e jsonb; o jsonb; v jsonb; paiement jsonb; params jsonb;
 changement boolean:=false; statut text:='inchange'; variante text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_action IS NULL OR p_action NOT IN('verifier','coffre') THEN RETURN jsonb_build_object('ok',false,'raison','commande_invalide');END IF;
 params:=jsonb_build_object('action',p_action,'pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'enigme_objet',params);
 IF v IS NOT NULL THEN RETURN v||jsonb_build_object('enigme',a.enigme1,'changement',false);END IF;
 e:=CASE WHEN jsonb_typeof(a.enigme1)='object' THEN a.enigme1 ELSE '{"etape":"non_commencee","variante":null}'::jsonb END;
 IF p_action='verifier' THEN
  IF p_pa IS DISTINCT FROM 0 OR p_cost IS DISTINCT FROM 0 THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
  IF e->>'etape'='non_commencee' AND extract(epoch FROM now()-(a.created_at AT TIME ZONE 'UTC'))>=3*86400
   AND NOT EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE acteur=a.name AND action='enigme_objet' AND resultat->>'statut'='declenchee') THEN
   variante:=(ARRAY['maire','criminel','entrepreneur','plume'])[floor(random()*4)::integer+1];
   e:=jsonb_build_object('etape','declenchee','variante',variante,'dateDeclenchement',now());
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.inventory) i WHERE i->>'calepinEnigme1'='true') THEN
    SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='enigme:calepin';
   END IF;
   changement:=true;statut:='declenchee';
  ELSIF e->>'etape'='declenchee' AND extract(epoch FROM now()-(a.created_at AT TIME ZONE 'UTC'))>=6*86400 THEN
   e:=e||jsonb_build_object('etape','relancee');changement:=true;statut:='relancee';
  END IF;
 ELSE
  IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM ('republic','capitale','banque-nationale','accueil_banque') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  paiement:=public.payer_ordre(a.name,'presenter_autorisation_coffre',p_pa,p_cost);
  IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement;END IF;
  IF coalesce((e->>'autorisationCoffre')::boolean,false) IS NOT TRUE THEN statut:='sans_autorisation';
  ELSIF coalesce((e->>'coffreOuvert')::boolean,false) OR EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE acteur=a.name AND action='enigme_objet' AND resultat->>'statut'='cle_remise') THEN statut:='deja_ouvert';
  ELSE
   SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='enigme:cle';
   e:=e||jsonb_build_object('coffreOuvert',true);changement:=true;statut:='cle_remise';
  END IF;
 END IF;
 IF o IS NOT NULL THEN
  v:=public.inventaire_deposer_interne(a.name,o,true);
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'enigme: depot refuse';END IF;
 ELSE SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision) INTO v FROM public.personnages_donnees WHERE name=a.name;END IF;
 IF changement THEN UPDATE public.personnages_donnees SET enigme1=e WHERE name=a.name;END IF;
 v:=v||jsonb_build_object('enigme',e,'changement',changement,'statut',statut,'paie',paiement);
 IF changement OR p_action='coffre' THEN INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'enigme_objet',params,v,now());END IF;
 RETURN v;
END; $function$;

-- est_administrateur() -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.est_administrateur()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT auth.uid() IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.administrateurs a
                  WHERE a.user_id = auth.uid() AND a.actif);
$function$;

-- est_appel_serveur() -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.est_appel_serveur()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN coalesce(nullif(current_setting('role', true), 'none'), session_user)
         IN ('anon', 'authenticated')
      THEN false
    WHEN coalesce(nullif(current_setting('role', true), 'none'), session_user)
         IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin')
      THEN true
    ELSE coalesce(
           nullif(current_setting('request.jwt.claim.role', true), ''),
           (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
           'anon'
         ) = 'service_role'
  END;
$function$;

-- est_mon_personnage(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.est_mon_personnage(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.est_appel_serveur()
      OR (p_nom IS NOT NULL AND auth.uid() IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.personnages p
                      WHERE p.name = p_nom AND p.user_id = auth.uid()));
$function$;

-- exiger_acteur(text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.exiger_acteur(p_nom text)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_mon_personnage(p_nom) THEN
    RAISE EXCEPTION 'acteur_non_authentifie: % n''appartient pas au compte connecte', coalesce(p_nom, '(null)')
      USING ERRCODE = '42501';
  END IF;
END;
$function$;

-- exiger_poste(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
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
$function$;

-- fiche_fusionner_ecran(jsonb,jsonb,jsonb) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fiche_fusionner_ecran(p_nouvelle jsonb, p_base jsonb, p_canon jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  champs constant text[] := ARRAY['pa','hp','moral','current_city','current_building','current_room',
    'est_emprisonne','hospitalisation','poison_actif','stats_affaiblies','regen_jour','requisition',
    'domicile','employes','escort_active','locations_actives','dernier_dormir','reservation_hotel','excommunie'];
  f text; n jsonb; b jsonb; c jsonb; r jsonb := '{}'::jsonb;
BEGIN
  FOREACH f IN ARRAY champs LOOP
    c := p_canon -> f;
    IF NOT (p_base ? f) OR NOT (p_nouvelle ? f) THEN
      r := r || jsonb_build_object(f, c);                     -- inconnu : le serveur fait foi
      CONTINUE;
    END IF;
    n := p_nouvelle -> f; b := p_base -> f;
    IF public.fiche_valeur_normalisee(n) IS NOT DISTINCT FROM public.fiche_valeur_normalisee(b) THEN
      r := r || jsonb_build_object(f, c);                     -- pas changé à l'écran
    ELSIF public.fiche_valeur_normalisee(c) IS NOT DISTINCT FROM public.fiche_valeur_normalisee(b) THEN
      r := r || jsonb_build_object(f, n);                     -- changé à l'écran seulement
    ELSE
      r := r || jsonb_build_object(f, c);                     -- conflit : le serveur l'emporte
    END IF;
  END LOOP;
  RETURN r;
END;
$function$;

-- fiche_valeur_normalisee(jsonb) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fiche_valeur_normalisee(v jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN v IS NULL OR v = 'null'::jsonb OR v = '{}'::jsonb OR v = '[]'::jsonb OR v = '""'::jsonb THEN NULL ELSE v END;
$function$;

-- fortune_serveur_diagnostic() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fortune_serveur_diagnostic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pj public.personnages_donnees%ROWTYPE;
 v_comptes numeric; v_placements numeric; v_poches numeric;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentification_requise'; END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE user_id=auth.uid() LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'personnage_introuvable'; END IF;
 SELECT coalesce(sum(solde),0) INTO v_comptes FROM public.comptes_bancaires WHERE personnage=v_pj.name;
 SELECT coalesce(sum(montant),0) INTO v_placements FROM public.placements_bancaires WHERE personnage=v_pj.name AND statut='actif';
 v_poches := coalesce(v_pj.liquide,0) + v_comptes + v_placements;
 RETURN jsonb_build_object('ok',true,'arg_enregistre',v_pj.arg,'liquide',v_pj.liquide,
    'comptes',v_comptes,'placements',v_placements,'total_composantes',v_poches,
    'ecart',coalesce(v_pj.arg,0)-v_poches,'coherent',v_pj.arg=v_poches);
END; $function$;

-- generique_de_objet(jsonb) -> TABLE(generique_id text, variante_id text, effets_effectifs jsonb, motif text, valeur text, priorite integer) | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.generique_de_objet(p_objet jsonb)
 RETURNS TABLE(generique_id text, variante_id text, effets_effectifs jsonb, motif text, valeur text, priorite integer)
 LANGUAGE sql
 STABLE
AS $function$
  with direct as (
    -- Designation DIRECTE par le referentiel. Priorite maximale : quand le serveur
    -- a lui-meme pose l'identite mecanique, aucune cle legacy n'a a la deviner.
    select g.id                                  as generique_id,
           (select v.id from public.catalogue_variantes v
             where v.id = p_objet->>'variante_id' and v.generique_id = g.id) as variante_id,
           null::jsonb                           as effets_effectifs,
           'generique_id'::text                  as motif,
           g.id                                  as valeur,
           1000                                  as priorite,
           0::bigint                             as ordre
      from public.catalogue_generiques g
     where g.id = p_objet->>'generique_id'
  ),
  cand(motif, valeur) as (
    select 'type_originequete', (p_objet->>'type') || '|' || (p_objet->>'origineQuete')
      where p_objet->>'type' is not null and p_objet->>'origineQuete' is not null
    union all
    select 'type_produit_militaire', (p_objet->>'type') || '|' || (p_objet->>'produitMilitaire')
      where p_objet->>'type' is not null and p_objet->>'produitMilitaire' is not null
    union all
    select 'produit_militaire', p_objet->>'produitMilitaire'
      where p_objet->>'produitMilitaire' is not null
    union all
    select 'type_tracttype', (p_objet->>'type') || '|' || (p_objet->>'tractType')
      where p_objet->>'type' is not null and p_objet->>'tractType' is not null
    union all
    select 'famille_produit_marche', p_objet->>'familleProduitMarche'
      where p_objet->>'familleProduitMarche' is not null
    union all
    select 'type_soustype', (p_objet->>'type') || '|' || (p_objet->>'sousType')
      where p_objet->>'type' is not null and p_objet->>'sousType' is not null
    union all
    select 'recette_id', p_objet->>'type'
      where p_objet->>'type' is not null
    union all
    select 'stack_key', p_objet->>'stackKey'
      where p_objet->>'stackKey' is not null
    union all
    select 'type', p_objet->>'type'
      where p_objet->>'type' is not null
  ),
  legacy as (
    select c.generique_id, c.variante_id, c.effets_effectifs, c.motif, c.valeur,
           c.priorite, c.id as ordre
      from cand
      join public.catalogue_correspondance_legacy c
        on c.motif = cand.motif and c.valeur = cand.valeur
  ),
  tout as (select * from direct union all select * from legacy)
  select t.generique_id, t.variante_id, t.effets_effectifs, t.motif, t.valeur, t.priorite
    from tout t
   order by t.priorite desc, t.ordre asc
   limit 1;
$function$;

-- generique_recettes_systeme(text) -> TABLE(recette_id text, label text, pa integer, portions integer, materiaux jsonb) | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.generique_recettes_systeme(p_generique_id text)
 RETURNS TABLE(recette_id text, label text, pa integer, portions integer, materiaux jsonb)
 LANGUAGE sql
 STABLE
AS $function$
  with toutes as (
    select r.id, r.label, r.label_forme, r.pa, r.portions,
           coalesce(r.materiaux, '{}'::jsonb) as materiaux
      from public.recettes_commerce r
     where r.generique_id = p_generique_id
  ), arbitre as (
    select exists (select 1 from toutes where nullif(btrim(label_forme), '') is not null) as oui
  )
  select t.id, coalesce(nullif(btrim(t.label_forme), ''), t.label),
         t.pa, t.portions, t.materiaux
    from toutes t, arbitre a
   where NOT a.oui OR nullif(btrim(t.label_forme), '') is not null
   order by t.id;
$function$;

-- habilitation_ouverte(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.habilitation_ouverte(p_nom text, p_habilitation text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.habilitations_carrieres h
     WHERE h.habilitation = p_habilitation
       AND h.carriere = ANY (public.carrieres_de(p_nom)));
$function$;

-- incarnation_courante() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.incarnation_courante()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.est_administrateur()
              THEN nullif(current_setting('rp.incarnation_pnj', true), '') END;
$function$;

-- incarnation_pays() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.incarnation_pays()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.est_administrateur()
              THEN nullif(current_setting('rp.incarnation_pays', true), '') END;
$function$;

-- incarnation_siege() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.incarnation_siege()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.est_administrateur()
              THEN nullif(current_setting('rp.incarnation_siege', true), '') END;
$function$;

-- inventaire_abandonner(text,integer,jsonb,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_abandonner(p_acteur text, p_index integer, p_signature jsonb, p_country text, p_city text, p_building text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_objet jsonb; v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_building, '') = '' OR coalesce(p_room, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  -- Identifiant attribue par le SERVEUR : la plupart des objets uniques du jeu n'ont aucun
  -- champ id (seuls les objets de quete en ont un), et l'ancien chemin client reprenait
  -- objet.id tel quel -- donc NULL le plus souvent, pour une colonne qui est la cle primaire.
  v_id := 'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '');
  v_objet := (v_r->'objet') || jsonb_build_object('id', v_id);

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
  VALUES (v_id, p_country, p_city, p_building, p_room, v_objet::text);

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $function$;

-- inventaire_action_rejouer_interne(text,uuid,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_action_rejouer_interne(p_acteur text, p_requete uuid, p_action text, p_parametres jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.inventaire_actions_recus; d record;
BEGIN
 SELECT * INTO r FROM public.inventaire_actions_recus WHERE acteur=p_acteur AND requete=p_requete;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF r.action IS DISTINCT FROM p_action OR r.parametres IS DISTINCT FROM p_parametres THEN
  RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
 SELECT inventory,inventory_revision,pa,liquide,arg INTO d FROM public.personnages_donnees WHERE name=p_acteur;
 RETURN r.resultat || jsonb_build_object('rejeu',true,'inventory',d.inventory,'revision',d.inventory_revision,
  'paie',jsonb_build_object('pa',d.pa,'liquide',d.liquide,'arg',d.arg,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=p_acteur AND banque='nationale'),0)));
END; $function$;

-- inventaire_ajouter(jsonb,text,integer,text) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_ajouter(p_inv jsonb, p_cle text, p_qte integer, p_desc text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb := coalesce(p_inv, '[]'::jsonb);
BEGIN
  IF p_qte <= 0 THEN RETURN v_inv; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE e->>'stackKey' = p_cle) THEN
    SELECT jsonb_agg(CASE WHEN e->>'stackKey' = p_cle
             THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) + p_qte))
             ELSE e END) INTO v_inv FROM jsonb_array_elements(v_inv) e;
    RETURN v_inv;
  END IF;
  RETURN v_inv || jsonb_build_array(jsonb_build_object(
    'name', p_cle, 'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'desc', p_desc));
END; $function$;

-- inventaire_ajouts_interdits(jsonb,jsonb) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_ajouts_interdits(p_ancien jsonb, p_nouveau jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pris boolean[]; v_anc jsonb[]; n jsonb; i integer; v_trouve boolean; v_hors jsonb := '[]'::jsonb;
BEGIN
  SELECT coalesce(array_agg(e ORDER BY o), ARRAY[]::jsonb[]) INTO v_anc
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_ancien) = 'array' THEN p_ancien ELSE '[]'::jsonb END) WITH ORDINALITY x(e, o);
  v_pris := array_fill(false, ARRAY[greatest(1, coalesce(array_length(v_anc, 1), 0))]);
  FOR n IN SELECT e FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_nouveau) = 'array' THEN p_nouveau ELSE '[]'::jsonb END) e LOOP
    v_trouve := false;
    FOR i IN 1..coalesce(array_length(v_anc, 1), 0) LOOP
      CONTINUE WHEN v_pris[i];
      IF (v_anc[i] - 'qty' - 'quantite') = (n - 'qty' - 'quantite')
         AND (NOT (n ? 'qty') OR (jsonb_typeof(n -> 'qty') = 'number' AND (n ->> 'qty')::numeric > 0
              AND (n ->> 'qty')::numeric <= coalesce(CASE WHEN jsonb_typeof(v_anc[i] -> 'qty') = 'number' THEN (v_anc[i] ->> 'qty')::numeric END, 1)))
         AND (NOT (n ? 'quantite') OR (jsonb_typeof(n -> 'quantite') = 'number' AND (n ->> 'quantite')::numeric > 0
              AND (n ->> 'quantite')::numeric <= coalesce(CASE WHEN jsonb_typeof(v_anc[i] -> 'quantite') = 'number' THEN (v_anc[i] ->> 'quantite')::numeric END, 0)))
      THEN v_pris[i] := true; v_trouve := true; EXIT; END IF;
    END LOOP;
    IF NOT v_trouve THEN v_hors := v_hors || jsonb_build_array(n); END IF;
  END LOOP;
  RETURN v_hors;
END; $function$;

-- inventaire_confisquer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_confisquer(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inv jsonb; v_quete jsonb; v_pays text; v_trouve boolean;
  v_saisis jsonb; v_restant jsonb;
  v_ville text; v_bat text; v_room text; v_ref text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere, coalesce(country, 'republic'),
         current_city, current_building, current_room
    INTO v_trouve, v_inv, v_quete, v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  WITH elements AS (
    SELECT e, (coalesce((e->>'legal')::boolean, true) = false
               OR public.assemblee_loi_en_vigueur(v_pays, e, now()) IS NOT NULL)
              AND NOT public.inventaire_objet_protege(v_quete, e) AS saisi
      FROM jsonb_array_elements(v_inv) e
  )
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE saisi), '[]'::jsonb),
         coalesce(jsonb_agg(e) FILTER (WHERE NOT saisi), '[]'::jsonb)
    INTO v_saisis, v_restant FROM elements;

  IF jsonb_array_length(v_saisis) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'saisis', '[]'::jsonb, 'inventory', v_inv, 'noms', '');
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_restant WHERE name = p_acteur;

  -- EVENEMENT MONDE, une ligne par objet reellement confisque, dans la meme
  -- transaction que le retrait.
  v_ref := 'conf-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
           substr(md5(p_acteur || random()::text), 1, 8);
  INSERT INTO public.confiscations_douanieres
    (id, personne, objet_nom, objet_type, quantite, pays, ville, building_id, room_id, reference)
  SELECT v_ref || '-' || o.ord, p_acteur,
         coalesce(o.e ->> 'name', o.e ->> 'nom', '?'),
         o.e ->> 'type',
         nullif(coalesce(o.e ->> 'qty', o.e ->> 'quantite'), '')::integer,
         v_pays, v_ville, v_bat, v_room, v_ref
    FROM jsonb_array_elements(v_saisis) WITH ORDINALITY AS o(e, ord);

  RETURN jsonb_build_object('ok', true, 'saisis', v_saisis, 'inventory', v_restant,
    'noms', (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(v_saisis) e));
END; $function$;

-- inventaire_consommer(text,integer,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_consommer(p_acteur text, p_index integer, p_signature jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb;v_quete jsonb;v_item jsonb;v_r jsonb;v_pos integer;v_date numeric;v_frais boolean;v_pa integer;v_delta integer;v_aliment boolean;v_id text;v_base text;v_k integer;v_ch text;v_digit integer;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 SELECT coalesce(inventory,'[]'::jsonb),quete_carriere INTO v_inv,v_quete FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 v_pos:=public.inventaire_localiser(v_inv,p_index,p_signature);
 IF v_pos<0 THEN RETURN jsonb_build_object('ok',false,'raison','objet_absent'); END IF;
 v_item:=v_inv->v_pos;
 v_aliment:=coalesce(v_item->>'familleProduitMarche','')='aliment'
   OR (coalesce(v_item->>'generique_id','')='encas-a-emporter' AND coalesce(v_item->>'recette_id','')<>'');
 IF NOT (v_aliment OR coalesce(v_item->>'type','') IN ('medicament','explosif','poison')) THEN
   RETURN jsonb_build_object('ok',false,'raison','objet_non_consommable');
 END IF;
 IF v_aliment THEN
   BEGIN v_date:=(v_item->>'dateAchat')::numeric; EXCEPTION WHEN others THEN v_date:=NULL; END;
   IF v_date IS NULL OR v_date<=0 THEN
     -- Les anciens achats comportent un identifiant horodate genere a l'achat.
     -- Cette retrocompatibilite n'est admise que pour les aliments manufactures identifies.
     v_id:=v_item#>>'{exemplaire,id}';
     IF v_id ~ '^achat-[0-9a-z]{8,12}-[0-9a-z]+-[0-9]+$' AND v_item ? 'provenance' THEN
       v_base:=split_part(v_id,'-',2);v_date:=0;
       FOR v_k IN 1..length(v_base) LOOP
         v_ch:=substr(v_base,v_k,1);
         v_digit:=strpos('0123456789abcdefghijklmnopqrstuvwxyz',v_ch)-1;
         v_date:=v_date*36+v_digit;
       END LOOP;
     END IF;
   END IF;
   IF v_date IS NULL OR v_date<1600000000000 OR v_date>(extract(epoch FROM now())*1000+300000) THEN
     RETURN jsonb_build_object('ok',false,'raison','date_achat_invalide');
   END IF;
 END IF;
 v_r:=public.helvetia_inventaire_sortie(v_inv,v_quete,p_index,p_signature,1);
 IF NOT coalesce((v_r->>'ok')::boolean,false) THEN RETURN v_r; END IF;
 UPDATE public.personnages_donnees SET inventory=v_r->'inventory' WHERE name=p_acteur;
 IF v_aliment THEN
   v_frais:=(extract(epoch FROM now())*1000-v_date)<=604800000;
   v_delta:=CASE WHEN v_frais THEN 1 ELSE -1 END;
   UPDATE public.personnages_donnees SET pa=least(30,greatest(0,coalesce(pa,0)+v_delta)) WHERE name=p_acteur RETURNING pa INTO v_pa;
   v_r:=v_r||jsonb_build_object('pa',v_pa,'aliment_frais',v_frais);
 END IF;
 RETURN v_r;
END;$function$;

-- inventaire_deposer_interne(text,jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_deposer_interne(p_nom text, p_objet jsonb, p_automatique boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_place integer; v_q integer; v_cle text; v_obj jsonb := p_objet; v_pile bigint;
BEGIN
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide'); END IF;
  SELECT coalesce(inventory,'[]'::jsonb) INTO v_inv
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF jsonb_typeof(v_inv) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_format_a_examiner'); END IF;
  v_place := CASE WHEN p_automatique THEN 1000000 ELSE public.inventaire_place_restante(v_inv) END;
  v_cle := nullif(p_objet ->> 'stackKey', '');
  IF coalesce((p_objet ->> 'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    IF coalesce((p_objet->>'qty')::numeric,1)<=0 OR coalesce((p_objet->>'qty')::numeric,1)<>trunc(coalesce((p_objet->>'qty')::numeric,1)) THEN
      RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
    v_q := least(coalesce((p_objet->>'qty')::numeric,1),v_place)::integer;
    IF v_q <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    SELECT o INTO v_pile FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e,o) WHERE coalesce((e->>'stackable')::boolean,false) AND e->>'stackKey'=v_cle ORDER BY o LIMIT 1;
    IF v_pile IS NOT NULL THEN
      SELECT jsonb_agg(CASE WHEN o=v_pile
                       THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e ->> 'qty')::numeric, 1) + v_q)) ELSE e END ORDER BY o)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o);
    ELSE
      v_inv := v_inv || jsonb_build_array(p_objet || jsonb_build_object('qty', v_q));
    END IF;
  ELSE
    v_q := greatest(1, coalesce((p_objet ->> 'encombrement')::numeric, 1)::integer);
    IF v_place < v_q THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    IF coalesce(p_objet ->> 'id', '') = '' THEN
      v_obj := p_objet || jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', ''));
    END IF;
    v_inv := v_inv || jsonb_build_array(v_obj);
    v_q := 1;
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true, 'qte', v_q)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_nom);
END; $function$;

-- inventaire_detruire(text,integer,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_detruire(p_acteur text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $function$;

-- inventaire_donner(text,text,integer,jsonb,integer,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_donner(p_acteur text, p_destinataire text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1, p_mutations jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_id text;
        v_mut jsonb; v_objet jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' OR p_destinataire = p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  -- Mutations de PRESENTATION seulement (carte postale ecrite). Liste NOIRE plutot que blanche :
  -- un champ de jeu nouvellement invente reste transmissible, mais aucun champ economique ne
  -- peut l'etre par oubli.
  v_objet := v_r->'objet';
  IF p_mutations IS NOT NULL AND jsonb_typeof(p_mutations) = 'object' THEN
    v_mut := p_mutations - 'qty' - 'quantite' - 'stackable' - 'stackKey'
                         - 'encombrement' - 'type' - 'legal' - 'id';
    v_objet := v_objet || v_mut;
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  -- objets_recus est le SAS obligatoire : le serveur n'ecrit JAMAIS directement dans
  -- l'inventaire du destinataire, dont le client ouvert reecrirait le tableau entier et
  -- ecraserait l'ajout (doctrine posee par migration_moteur_commerce.sql).
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, p_acteur, to_jsonb(v_objet::text));

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $function$;

-- inventaire_localiser(jsonb,integer,jsonb) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_localiser(p_inv jsonb, p_index integer, p_signature jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH inv AS (
    SELECT e, (ord - 1)::int AS pos
      FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
  ), correspond AS (
    SELECT pos FROM inv
     WHERE coalesce(e->>'name', '')     = coalesce(p_signature->>'name', '')
       AND coalesce(e->>'type', '')     = coalesce(p_signature->>'type', '')
       AND coalesce(e->>'stackKey', '') = coalesce(p_signature->>'stackKey', '')
  )
  SELECT coalesce((SELECT pos FROM correspond WHERE pos = p_index),
                  (SELECT min(pos) FROM correspond), -1);
$function$;

-- inventaire_objet_protege(jsonb,jsonb) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_objet_protege(p_quete jsonb, p_item jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_item->>'type', '') = 'colis_secret_pat'
     AND (p_quete IS NULL
          OR (coalesce(p_quete->>'ambition', '') = 'criminel'
              AND coalesce(p_quete->>'etape', '') <> 'terminee'));
$function$;

-- inventaire_place_restante(jsonb) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_place_restante(p_inv jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT greatest(0,100-coalesce((
 SELECT sum(CASE
   WHEN coalesce(e->>'quantite','') ~ '^[0-9]+$' THEN (e->>'quantite')::numeric
   WHEN coalesce(e->>'qty','') ~ '^[0-9]+$' THEN (e->>'qty')::numeric
   WHEN coalesce(e->>'encombrement','') ~ '^[0-9]+$' THEN (e->>'encombrement')::numeric
   ELSE 1 END)
 FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e),0))::integer;
$function$;

-- inventaire_quantite(jsonb,text) -> numeric | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_quantite(p_inv jsonb, p_cle text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT sum(coalesce((e->>'qty')::numeric,1))
                   FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e
                   WHERE e->>'stackKey' = p_cle), 0);
$function$;

-- inventaire_reception_etat(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_reception_etat(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v public.personnages_donnees%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
  PERFORM public.exiger_acteur(p_acteur);
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
  IF NOT FOUND OR v.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';
  END IF;
  IF jsonb_typeof(v.inventory) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'inventaire_format_a_reexaminer';
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'inventory',v.inventory,'revision',v.inventory_revision);
END;
$function$;

-- inventaire_reclamer_livraison(text,text,uuid,bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_reclamer_livraison(p_acteur text, p_id text, p_jeton uuid, p_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v public.personnages_donnees%rowtype; l public.objets_recus%rowtype;
  o jsonb; inv jsonb; e jsonb; pos integer := -1; i integer := 0; q numeric;
BEGIN
  PERFORM public.inventaire_reception_etat(p_acteur);
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
  IF EXISTS(SELECT 1 FROM public.inventaire_livraisons_recues WHERE jeton=p_jeton AND id=p_id AND destinataire=p_acteur) THEN
    RETURN jsonb_build_object('ok',true,'contrat',1,'rejeu',true,'inventory',v.inventory,'revision',v.inventory_revision);
  END IF;
  SELECT * INTO l FROM public.objets_recus WHERE id=p_id AND reception_token=p_jeton FOR UPDATE;
  IF NOT FOUND OR l.destinataire IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok',false,'raison','livraison_absente');
  END IF;
  IF p_revision IS DISTINCT FROM v.inventory_revision THEN
    RETURN jsonb_build_object('ok',false,'raison','inventaire_perime','revision',v.inventory_revision);
  END IF;
  o := CASE WHEN jsonb_typeof(l.data)='string' THEN (l.data #>> '{}')::jsonb ELSE l.data END;
  IF jsonb_typeof(o) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'livraison_format_invalide'; END IF;
  inv := v.inventory;
  -- Memes priorites que recevoirLotTracts puis recevoirObjetAutomatique : premier lot seulement.
  IF p_id LIKE 'don-tracts-%' THEN
    FOR e IN SELECT value FROM jsonb_array_elements(inv) LOOP
      IF e->'type' IS NOT DISTINCT FROM o->'type' AND e->'cible' IS NOT DISTINCT FROM o->'cible'
       AND coalesce(e->>'tractType','')=coalesce(o->>'tractType','')
       AND (coalesce(e->'legal','true')<>'false'::jsonb)=(coalesce(o->'legal','true')<>'false'::jsonb)
       AND coalesce(e->'origineQuete','null') IN ('null','false','0','""')
       AND coalesce(o->'origineQuete','null') IN ('null','false','0','""') THEN
        pos:=i; EXIT;
      END IF;
      i:=i+1;
    END LOOP;
    IF pos>=0 THEN
      q:=coalesce((inv->pos->>'quantite')::numeric,0)+coalesce((o->>'quantite')::numeric,0);
      inv:=jsonb_set(inv,ARRAY[pos::text,'quantite'],to_jsonb(q));
    END IF;
  END IF;
  IF pos<0 AND o->'stackable'='true'::jsonb AND coalesce(o->>'stackKey','')<>'' THEN
    q:=coalesce(nullif((o->>'qty')::numeric,0),1);
    IF q<=0 THEN RAISE EXCEPTION 'livraison_quantite_invalide'; END IF;
    i:=0;
    FOR e IN SELECT value FROM jsonb_array_elements(inv) LOOP
      IF e->'stackable'='true'::jsonb AND e->>'stackKey'=o->>'stackKey' THEN pos:=i;EXIT;END IF;
      i:=i+1;
    END LOOP;
    IF pos>=0 THEN
      inv:=jsonb_set(inv,ARRAY[pos::text,'qty'],to_jsonb(coalesce(nullif((inv->pos->>'qty')::numeric,0),1)+q));
    ELSE
      inv:=inv||jsonb_build_array(o||jsonb_build_object('qty',q)); pos:=jsonb_array_length(inv)-1;
    END IF;
  END IF;
  IF pos<0 THEN inv:=inv||jsonb_build_array(o); END IF;
  -- Surcharge permise, aucun plafonnement ni changement des metadonnees d'un objet nouveau.
  UPDATE public.personnages_donnees SET inventory=inv WHERE name=p_acteur RETURNING * INTO v;
  IF v.inventory IS DISTINCT FROM inv THEN
    RAISE EXCEPTION 'inventaire_ecriture_non_appliquee';
  END IF;
  INSERT INTO public.inventaire_livraisons_recues(jeton,id,destinataire) VALUES(p_jeton,p_id,p_acteur);
  DELETE FROM public.objets_recus WHERE id=p_id AND reception_token=p_jeton AND destinataire=p_acteur;
  -- Relire APRES les triggers, pas seulement le tuple capture par UPDATE RETURNING.
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
  IF v.inventory IS DISTINCT FROM inv
     OR EXISTS(SELECT 1 FROM public.objets_recus WHERE reception_token=p_jeton)
     OR NOT EXISTS(SELECT 1 FROM public.inventaire_livraisons_recues WHERE jeton=p_jeton AND destinataire=p_acteur) THEN
    RAISE EXCEPTION 'reception_postcondition_invalide';
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'rejeu',false,'inventory',v.inventory,
    'revision',v.inventory_revision,'objet',o,'expediteur',l.expediteur);
END;
$function$;

-- inventaire_remettre(text,integer,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_remettre(p_acteur text, p_index integer, p_signature jsonb, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_pos integer; v_item jsonb; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;

  -- Objet protege : sortie autorisee UNIQUEMENT vers son destinataire designe.
  IF public.inventaire_objet_protege(v_quete, v_item) THEN
    IF coalesce(v_item->>'type', '') = 'colis_secret_pat' AND p_destinataire = 'Brigitte Menottes' THEN
      v_inv := public.inventaire_retirer_position(v_inv, v_pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_acteur;
      RETURN jsonb_build_object('ok', true, 'inventory', v_inv, 'objet', v_item,
                                'position', v_pos, 'remise_quete', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_non_designe');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $function$;

-- inventaire_retirer(jsonb,text,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_retirer(p_inv jsonb, p_cle text, p_qte integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE coalesce((e->>'qty')::numeric, 1) > 0), '[]'::jsonb)
  FROM (SELECT CASE WHEN e->>'stackKey' = p_cle
                    THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) - p_qte))
                    ELSE e END AS e
        FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e) x;
$function$;

-- inventaire_retirer_position(jsonb,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_retirer_position(p_inv jsonb, p_pos integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
    FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
   WHERE (ord - 1) <> p_pos;
$function$;

-- inventaire_revision_garder() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_revision_garder()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(nullif(current_setting('role',true),'none'),session_user) IN ('anon','authenticated')
     AND coalesce(current_setting('request.path',true),'') NOT LIKE '/rpc/%' THEN
    NEW.inventory := OLD.inventory;
  END IF;
  NEW.inventory_revision := OLD.inventory_revision
    + CASE WHEN NEW.inventory IS DISTINCT FROM OLD.inventory THEN 1 ELSE 0 END;
  RETURN NEW;
END;
$function$;

-- inventaire_sauver_revision(text,bigint,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_sauver_revision(p_acteur text, p_revision bigint, p_inventory jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v public.personnages_donnees%rowtype;
BEGIN
  PERFORM public.inventaire_reception_etat(p_acteur); -- autorite + verrou personnage d'abord
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
  IF jsonb_typeof(p_inventory) IS DISTINCT FROM 'array' THEN
    RETURN jsonb_build_object('ok',false,'raison','inventaire_invalide');
  END IF;
  -- Aucun rebasage d'un snapshot different. Un etat deja exact ne reecrit rien.
  IF p_inventory IS DISTINCT FROM v.inventory THEN
    IF p_revision IS DISTINCT FROM v.inventory_revision THEN
      RETURN jsonb_build_object('ok',false,'raison','inventaire_perime','revision',v.inventory_revision);
    END IF;
    -- VERROU, ETAPE 1 (observation) : un objet qui n'etait pas deja possede est inscrit.
    INSERT INTO public.inventaire_ecarts_observes (acteur, objet)
    SELECT p_acteur, x FROM jsonb_array_elements(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) x;
    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur
      RETURNING * INTO v;
    SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
    IF v.inventory IS DISTINCT FROM p_inventory OR v.inventory_revision IS DISTINCT FROM p_revision+1 THEN
      RAISE EXCEPTION 'inventaire_ecriture_non_appliquee';
    END IF;
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'inventory',v.inventory,'revision',v.inventory_revision);
END;
$function$;

-- is_national(text) -> numeric | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.is_national(p_pays text)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN count(*) = 3 THEN round(avg((v.data ->> 'isn')::numeric), 2)
    ELSE 50
  END
  FROM public.indices_villes v
  WHERE v.id = ANY (ARRAY[p_pays || '_capitale',
                          p_pays || '_ville_a',
                          p_pays || '_ville_b'])
    AND jsonb_typeof(v.data -> 'isn') = 'number';
$function$;

-- jour_de_jeu_pays(text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jour_de_jeu_pays(p_pays text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1,
    ((now() AT TIME ZONE 'Europe/Paris')::date
      - coalesce((SELECT e.jour_un FROM public.rp_epoques e WHERE e.pays = p_pays),
                 DATE '2026-09-13')
    )::int + 1);
$function$;

-- jour_de_jeu_reel() -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jour_de_jeu_reel()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.jour_de_jeu_pays('republic');
$function$;

-- jsonb_cle_economique_presente(jsonb) -> text | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.jsonb_cle_economique_presente(p_val jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_cle text; v_sous jsonb; v_res text;
BEGIN
  IF p_val IS NULL THEN RETURN NULL; END IF;

  IF jsonb_typeof(p_val) = 'object' THEN
    FOR v_cle, v_sous IN SELECT key, value FROM jsonb_each(p_val) LOOP
      IF lower(v_cle) = ANY (ARRAY[
            'caisse','caisses','stock','stocks','stockmatieres','stockproduits','stockbois',
            'stockmedical','reserve','reserves','prix','prixmanuel','prixachat','prixvente',
            'prixunitaire','repartition','arg','liquide','banque','inventory','inventaire',
            'solde','production','chaines','montant','salaire','tresorerie','budget','fonds',
            'loyer','imprimerie','entrepot','entrepots','usine','usines','sante','terrain',
            'commerce','journal','pret','prets','dette','dettes','taxe','impot']) THEN
        RETURN v_cle;
      END IF;
      v_res := public.jsonb_cle_economique_presente(v_sous);
      IF v_res IS NOT NULL THEN RETURN v_res; END IF;
    END LOOP;

  ELSIF jsonb_typeof(p_val) = 'array' THEN
    FOR v_sous IN SELECT value FROM jsonb_array_elements(p_val) LOOP
      v_res := public.jsonb_cle_economique_presente(v_sous);
      IF v_res IS NOT NULL THEN RETURN v_res; END IF;
    END LOOP;
  END IF;

  RETURN NULL;
END; $function$;

-- jsonb_cles_hors_liste(jsonb,text[]) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.jsonb_cles_hors_liste(p_obj jsonb, p_autorisees text[])
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT key FROM jsonb_each(p_obj)
  WHERE jsonb_typeof(p_obj) = 'object' AND NOT (key = ANY (p_autorisees))
  LIMIT 1;
$function$;

-- jsonb_ou_null(text) -> jsonb | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.jsonb_ou_null(p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN p_texte::jsonb;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$function$;

-- mes_carrieres() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mes_carrieres()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true,
    'initiale', public.carriere_initiale(v_moi),
    'seconde', (SELECT a.carriere FROM public.carrieres_acquises a WHERE a.personnage = v_moi),
    'carrieres', to_jsonb(public.carrieres_de(v_moi)),
    'seconde_carriere_disponible',
      NOT EXISTS (SELECT 1 FROM public.carrieres_acquises a WHERE a.personnage = v_moi),
    'habilitations', (SELECT coalesce(jsonb_agg(DISTINCT h.habilitation), '[]'::jsonb)
                        FROM public.habilitations_carrieres h
                       WHERE h.carriere = ANY (public.carrieres_de(v_moi))));
END $function$;

-- mission_carriere_recevoir(uuid,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp, TimeZone=UTC
CREATE OR REPLACE FUNCTION public.mission_carriere_recevoir(p_requete uuid, p_mission text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'UTC'
AS $function$
DECLARE a public.personnages_donnees; qc jsonb; o jsonb; v jsonb; params jsonb; ambition text; batiment text; piece text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_mission IS NULL OR p_mission NOT IN('pat','jean_lou') THEN RETURN jsonb_build_object('ok',false,'raison','mission_inconnue');END IF;
 params:=jsonb_build_object('mission',p_mission);v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'mission_carriere',params);
 IF v IS NOT NULL THEN RETURN v||jsonb_build_object('quete_carriere',a.quete_carriere);END IF;
 ambition:=CASE p_mission WHEN 'pat' THEN 'criminel' ELSE 'politique' END;
 batiment:=CASE p_mission WHEN 'pat' THEN 'place-formulaire-liberte' ELSE 'bureau-national-emploi' END;
 piece:=CASE p_mission WHEN 'pat' THEN 'place' ELSE 'accueil' END;
 IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM ('republic','capitale',batiment,piece) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 qc:=a.quete_carriere;
 IF qc->>'ambition' IS DISTINCT FROM ambition OR qc->>'etape' IS DISTINCT FROM 'a_rencontrer' THEN RETURN jsonb_build_object('ok',false,'raison','etape_non_conforme');END IF;
 IF EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE acteur=a.name AND action='mission_carriere' AND parametres=params) THEN RETURN jsonb_build_object('ok',false,'raison','objet_deja_remis');END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='mission:'||p_mission;
 IF p_mission='pat' THEN qc:=qc||jsonb_build_object('etape','colis_recu');
 ELSE qc:=qc||jsonb_build_object('etape','tracts_recus','electionCible',null,'ciblesJeanLou','[]'::jsonb,'resultatsJeanLou','[]'::jsonb);
  o:=o||jsonb_build_object('name','Tracts POUR '||a.name,'cible',a.name);
 END IF;
 v:=public.inventaire_deposer_interne(a.name,o);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'mission: depot refuse';END IF;
 UPDATE public.personnages_donnees SET quete_carriere=qc WHERE name=a.name;
 IF p_mission='pat' THEN
  INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
  VALUES('action-'||gen_random_uuid(),a.name,'Pat Hounette','colis_recu_pat_hounette',a.country,a.current_city,public.jour_de_jeu_pays(a.country),public.jour_de_jeu_pays(a.country)+7);
 END IF;
 v:=v||jsonb_build_object('quete_carriere',qc);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'mission_carriere',params,v,now());RETURN v;
END; $function$;

-- mon_personnage() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mon_personnage()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name FROM public.personnages p
  WHERE p.user_id IS NOT NULL AND p.user_id = auth.uid()
  LIMIT 1;
$function$;

-- mon_poste_est(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mon_poste_est(p_poste text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
  );
$function$;

-- mon_poste_est_dans(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mon_poste_est_dans(p_poste text, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
       AND (p_pays IS NULL OR d.country = p_pays)
  );
$function$;

-- mouvement_titulaire(text,numeric) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mouvement_titulaire(p_ref text, p_delta numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_type text; v_id text; v_solde numeric; v_data text; v_json jsonb;
 v_liquide numeric; v_comptes numeric; v_reste numeric; v_debit numeric;
 v_compte record;
BEGIN
 IF coalesce(p_ref,'')='' OR p_delta IS NULL OR p_delta<>trunc(p_delta) THEN RETURN false; END IF;
 IF left(p_ref,5)='orga:' THEN v_type:='orga';v_id:=substr(p_ref,6);
 ELSIF left(p_ref,3)='pj:' THEN v_type:='pj';v_id:=substr(p_ref,4);
 ELSIF left(p_ref,6)='ville:' THEN RETURN false;
 ELSE v_type:='pj';v_id:=p_ref; END IF;
 IF coalesce(v_id,'')='' THEN RETURN false; END IF;
 IF v_type='pj' THEN
   SELECT coalesce(arg,0),coalesce(liquide,0) INTO v_solde,v_liquide
   FROM public.personnages_donnees WHERE name=v_id FOR UPDATE;
   IF NOT FOUND THEN RETURN false; END IF;
   SELECT coalesce(sum(greatest(0,solde)),0) INTO v_comptes
   FROM public.comptes_bancaires WHERE personnage=v_id;
   IF p_delta<0 AND (v_solde < -p_delta OR v_liquide+v_comptes < -p_delta) THEN RETURN false; END IF;
   IF p_delta>=0 THEN
     UPDATE public.personnages_donnees SET arg=coalesce(arg,0)+p_delta,
       liquide=coalesce(liquide,0)+p_delta,updated_at=now() WHERE name=v_id;
   ELSE
     v_reste:=-p_delta;
     v_debit:=least(v_liquide,v_reste);
     UPDATE public.personnages_donnees SET liquide=liquide-v_debit,
       arg=arg+p_delta,updated_at=now() WHERE name=v_id;
     v_reste:=v_reste-v_debit;
     FOR v_compte IN SELECT id,solde FROM public.comptes_bancaires
       WHERE personnage=v_id AND solde>0 ORDER BY CASE WHEN banque='nationale' THEN 0 ELSE 1 END,id FOR UPDATE LOOP
       EXIT WHEN v_reste<=0;
       v_debit:=least(v_compte.solde,v_reste);
       UPDATE public.comptes_bancaires SET solde=solde-v_debit,updated_at=now() WHERE id=v_compte.id;
       v_reste:=v_reste-v_debit;
     END LOOP;
     IF v_reste>0 THEN RAISE EXCEPTION 'Mouvement titulaire: avoirs modifies concurremment'; END IF;
   END IF;
   RETURN true;
 END IF;
 SELECT data INTO v_data FROM public.organisations WHERE id=v_id FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 BEGIN v_json:=v_data::jsonb; EXCEPTION WHEN others THEN RETURN false; END;
 IF v_json IS NULL OR jsonb_typeof(v_json)<>'object' THEN RETURN false; END IF;
 v_solde:=greatest(0,coalesce((v_json->>'caisse')::numeric,0));
 IF v_solde+p_delta<0 THEN RETURN false; END IF;
 UPDATE public.organisations SET data=jsonb_set(v_json,'{caisse}',to_jsonb(v_solde+p_delta))::text WHERE id=v_id;
 RETURN true;
END;$function$;

-- objet_abandonne_ramasser(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.objet_abandonne_ramasser(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; o record; v_objet jsonb; v_inv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb) AS inv
    INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO o FROM public.objets_abandonnes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_disparu'); END IF;
  IF o.building_id IS DISTINCT FROM d.current_building OR o.room_id IS DISTINCT FROM d.current_room
     OR (o.city IS NOT NULL AND o.city IS DISTINCT FROM d.current_city) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  BEGIN v_objet := o.data::jsonb; EXCEPTION WHEN others THEN v_objet := NULL; END;
  IF v_objet IS NULL OR jsonb_typeof(v_objet) <> 'object' THEN
    DELETE FROM public.objets_abandonnes WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_illisible'); END IF;
  v_objet := v_objet - 'id';
  IF coalesce((v_objet ->> 'stackable')::boolean, false) AND (v_objet ->> 'stackKey') IS NOT NULL THEN
    v_inv := public.inventaire_ajouter(d.inv, v_objet ->> 'stackKey', greatest(1, coalesce((v_objet ->> 'qty')::integer, 1)), v_objet ->> 'desc');
  ELSE
    v_inv := d.inv || jsonb_build_array(v_objet);
  END IF;
  DELETE FROM public.objets_abandonnes WHERE id = p_id;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'objet', v_objet, 'inventory', v_inv);
END; $function$;

-- objet_acheter(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.objet_acheter(p_ordre text, p_modele text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_objet jsonb; v_paie jsonb; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT m.objet INTO v_objet FROM public.objets_achetables a JOIN public.objets_modeles m ON m.id = a.modele
   WHERE a.ordre = p_ordre AND a.modele = p_modele;
  IF v_objet IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_vendu_ici'); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(v_moi, p_ordre, p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dep := public.inventaire_deposer_interne(v_moi, v_objet);
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'objet_acheter: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'objet', v_objet ->> 'name', 'paie', v_paie) || (v_dep - 'ok' - 'qte')
    || jsonb_build_object('pa', v_paie -> 'pa', 'arg', v_paie -> 'arg', 'liquide', v_paie -> 'liquide');
END; $function$;

-- objet_acheter(uuid,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.objet_acheter(p_requete uuid, p_ordre text, p_modele text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('ordre', p_ordre, 'modele', p_modele, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'objet_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.objet_acheter(p_ordre, p_modele, p_pa, p_cost);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'objet_acheter', prm, v);
END; $function$;

-- objet_fiche_officielle(jsonb) -> jsonb | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.objet_fiche_officielle(p_objet jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  with r as (
    select * from public.generique_de_objet(p_objet) limit 1
  ),
  g as (
    select gen.*, fam.libelle as famille_libelle
      from r
      join public.catalogue_generiques gen on gen.id = r.generique_id
      join public.catalogue_familles    fam on fam.id = gen.famille_id
  ),
  v as (
    select va.libelle, va.capacites
      from r
      join public.catalogue_variantes va on va.id = r.variante_id
  ),
  t as (
    select coalesce(jsonb_agg(ty.libelle order by ty.ordre), '[]'::jsonb) as types
      from g
      join public.catalogue_generique_type gt on gt.generique_id = g.id
      join public.catalogue_types ty on ty.id = gt.type_id
  )
  select case
    when not exists (select 1 from r) then
      jsonb_build_object('resolu', false)
    else
      (select jsonb_strip_nulls(jsonb_build_object(
        'resolu',        true,
        'generique_id',  g.id,
        'generique',     g.libelle,
        'famille',       g.famille_libelle,
        'types',         (select types from t),
        'variante',      (select libelle from v),
        'regime',        g.regime,
        'est_service',   g.est_service,
        'effets',        coalesce((select effets_effectifs from r), g.effets),
        'capacites',     coalesce((select capacites from v), g.capacites),
        'consommable',   g.consommable,
        'equipable',     g.equipable,
        'encombrement',  g.encombrement,
        'durabilite',    g.durabilite,
        'conditions',    g.conditions,
        'contraintes',   g.contraintes
      )) || jsonb_build_object(
        'aucun_effet',
        (coalesce((select effets_effectifs from r), g.effets) is null
         and coalesce((select capacites from v), g.capacites) is null)
      )
      from g)
  end;
$function$;

-- objet_sas_deposer(text,text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.objet_sas_deposer(p_motif text, p_destinataire text, p_objet jsonb, p_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_vol record;
  v_nouveau_type text;
  v_demandeur text;
  v_expediteur text;
  v_id text;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_destinataire, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  IF p_motif = 'butin_vol' THEN
    -- La victime depose le butin pour le voleur. La ligne de vol est la piece justificative :
    -- elle doit exister, designer l'acteur comme victime et le destinataire comme voleur.
    SELECT * INTO v_vol FROM public.vols_en_attente
     WHERE id = p_reference FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vol_introuvable', 'reference', p_reference);
    END IF;
    IF v_vol.victime IS DISTINCT FROM v_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_la_victime');
    END IF;
    IF v_vol.voleur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_voleur');
    END IF;
    -- Anti-rejeu : un butin deja confirme ne se depose pas deux fois.
    IF v_vol.type_butin IN ('matiere_confirmee', 'objet_confirme') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'butin_deja_confirme');
    END IF;
    v_nouveau_type := CASE v_vol.type_butin
      WHEN 'matiere' THEN 'matiere_confirmee'
      WHEN 'objet'   THEN 'objet_confirme'
      ELSE NULL END;
    IF v_nouveau_type IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_butin_non_transferable',
                                'type_butin', v_vol.type_butin);
    END IF;
    v_expediteur := 'Butin de vol';

  ELSIF p_motif = 'document_urbanisme' THEN
    -- L'archive municipale COMMANDE : le joueur ne doit jamais detenir un recepisse d'un acte que
    -- la mairie n'a pas enregistre. La ligne d'archive est donc la piece justificative, et c'est
    -- elle qui nomme le demandeur legitime.
    SELECT demandeur INTO v_demandeur FROM public.dossiers_urbanisme WHERE id = p_reference;
    IF v_demandeur IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable',
                                'reference', p_reference);
    END IF;
    IF v_demandeur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_demandeur');
    END IF;
    v_expediteur := 'Services d''urbanisme';

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_non_declare', 'motif', p_motif);
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, v_expediteur, to_jsonb(p_objet::text));

  -- Meme transaction que le depot : le marquage du butin ne peut plus rester en arriere.
  IF p_motif = 'butin_vol' THEN
    UPDATE public.vols_en_attente SET type_butin = v_nouveau_type WHERE id = p_reference;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire,
                            'motif', p_motif, 'type_butin', v_nouveau_type);
END;
$function$;

-- objet_trouve_reclamer(uuid,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.objet_trouve_reclamer(p_requete uuid, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v jsonb; o jsonb; paiement jsonb; depot jsonb;
 v_index integer; v_jour date:=(now() AT TIME ZONE 'Europe/Paris')::date; params jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 params:=jsonb_build_object('pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'objet_trouve',params); IF v IS NOT NULL THEN RETURN v; END IF;
 IF ((a.current_building='mairie-capitale' AND a.current_room='hall_mairie' AND a.current_city='capitale')
 OR (a.current_building='mairie' AND a.current_room='accueil_mairie' AND a.current_city IN('ville_a','ville_b'))
 OR (a.current_building='assemblee' AND a.current_room='accueil_assemblee' AND a.current_city='capitale')) IS NOT TRUE THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 IF EXISTS(SELECT 1 FROM public.objets_trouves_jours WHERE acteur=a.name AND jour=v_jour)
 OR a.dernier_objet_trouve_jour=public.jour_de_jeu_pays(a.country) THEN
 RETURN jsonb_build_object('ok',false,'raison','deja_fait_aujourdhui'); END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
 paiement:=public.payer_ordre(a.name,'objet_trouve',p_pa,p_cost);
 IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement; END IF;
 INSERT INTO public.objets_trouves_jours VALUES(a.name,v_jour);
 UPDATE public.personnages_donnees SET dernier_objet_trouve_jour=public.jour_de_jeu_pays(a.country) WHERE name=a.name;
 IF random()<0.5 THEN
  v_index:=floor(random()*7)::integer;
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='objet_trouve:'||v_index;
  depot:=public.inventaire_deposer_interne(a.name,o);
  IF (depot->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'objet trouve: depot refuse'; END IF;
  INSERT INTO public.souvenirs_accueil(id,pj_nom,objet_nom,jour_creation,jour_expiration,revele)
  VALUES('souv-'||gen_random_uuid(),a.name,o->>'name',public.jour_de_jeu_pays(a.country),public.jour_de_jeu_pays(a.country)+12,false);
 ELSE SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision) INTO depot FROM public.personnages_donnees WHERE name=a.name;
 END IF;
 v:=depot||jsonb_build_object('paie',paiement,'trouve',o IS NOT NULL,'objet',o->>'name');
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'objet_trouve',params,v,now()); RETURN v;
END; $function$;

-- ordre_generique_executer(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ordre_generique_executer(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; o record; d record; v_paie jsonb; v_roll integer; v_taux integer; v_res text; v_mult numeric;
  v_hp integer; v_moral integer; v_res_j jsonb; v_rembourse numeric := 0; v_repere boolean := false;
  e_hp numeric; e_moral numeric; e_pop numeric; e_inf numeric; e_dis numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO o FROM public.ordres_generiques WHERE fn = p_fn;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'ordre_indisponible'); END IF;
  SELECT current_building, poste ->> 'id' AS poste INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT (coalesce(d.current_building, '') = ANY (o.batiments)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF o.poste_requis = '*' AND d.poste IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  IF o.poste_requis IS NOT NULL AND o.poste_requis <> '*' AND d.poste IS DISTINCT FROM o.poste_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis', 'requis', o.poste_requis); END IF;

  v_paie := public.payer_ordre(v_moi, p_fn, p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_roll := floor(random() * 100)::integer + 1;
  v_taux := greatest(5, CASE WHEN o.taux_reussite >= 98 THEN 99 ELSE o.taux_reussite END);
  IF v_roll <= 100 - v_taux THEN v_res := 'crit-fail';
  ELSIF v_roll <= 100 - (v_taux * 0.7) THEN v_res := 'fail';
  ELSIF v_roll <= 100 - (v_taux * 0.4) THEN v_res := 'partial';
  ELSIF v_roll >= 95 THEN v_res := 'crit';
  ELSE v_res := 'success'; END IF;
  IF o.toujours_reussi THEN v_res := CASE WHEN v_roll >= 95 THEN 'crit' ELSE 'success' END; END IF;
  v_mult := CASE v_res WHEN 'crit' THEN 1.5 WHEN 'success' THEN 1 WHEN 'partial' THEN 0.5 WHEN 'fail' THEN 0 ELSE -0.5 END;

  e_hp := coalesce((o.effets ->> 'hp')::numeric, 0);
  e_moral := coalesce((o.effets ->> 'moral')::numeric, 0);
  e_pop := coalesce((o.effets ->> 'pop')::numeric, 0);
  e_inf := coalesce((o.effets ->> 'inf')::numeric, 0);
  e_dis := coalesce((o.effets ->> 'dis')::numeric, 0);

  SELECT coalesce(hp, 100), coalesce(moral, 75),
         CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_hp, v_moral, v_res_j FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;

  IF e_hp <> 0 THEN v_hp := least(100, greatest(0, v_hp + round(e_hp * v_mult)::integer)); END IF;
  IF e_moral <> 0 THEN v_moral := least(100, greatest(0, v_moral + round(e_moral * v_mult)::integer)); END IF;
  IF e_inf <> 0 THEN v_res_j := jsonb_set(v_res_j, '{inf}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'inf')::numeric, 0) + round(e_inf * v_mult))))); END IF;
  IF e_pop <> 0 THEN v_res_j := jsonb_set(v_res_j, '{pop}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'pop')::numeric, 50) + round(e_pop * CASE WHEN v_res = 'crit-fail' THEN -1 ELSE v_mult END))))); END IF;
  IF e_dis <> 0 THEN v_res_j := jsonb_set(v_res_j, '{dis}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'dis')::numeric, 85) + round(e_dis * CASE WHEN e_dis < 0 THEN 1 ELSE v_mult END))))); END IF;

  IF v_res = 'fail' AND coalesce(p_cost, 0) > 0 THEN v_rembourse := round(p_cost * 0.3); END IF;

  UPDATE public.personnages_donnees
     SET hp = v_hp, moral = v_moral, resources = v_res_j,
         liquide = coalesce(liquide, 0) + v_rembourse, arg = coalesce(arg, 0) + v_rembourse
   WHERE name = v_moi;

  -- DETECTION PAR LE SERVEUR (27/10/2026) : l'ecran la tirait apres coup, un tricheur s'en dispensait.
  IF v_res IN ('partial', 'success', 'crit') AND EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = p_fn) THEN
    v_repere := public.crime_detecter_interne(v_moi, p_fn, true);
    SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END INTO v_res_j
      FROM public.personnages_donnees WHERE name = v_moi;
  END IF;
  RETURN jsonb_build_object('ok', true, 'resultat', v_res, 'repere', v_repere,
    'recherche', (SELECT recherche FROM public.personnages_donnees WHERE name = v_moi), 'jet', v_roll, 'hp', v_hp, 'moral', v_moral,
    'pop', v_res_j -> 'pop', 'inf', v_res_j -> 'inf', 'dis', v_res_j -> 'dis', 'rembourse', v_rembourse,
    'pa', (v_paie -> 'pa'),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'solde_national', v_paie -> 'solde_national');
END; $function$;

-- personnage_fantome_declarer(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.personnage_fantome_declarer(p_nom text, p_empreinte jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid; v_nom text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  v_nom := btrim(coalesce(p_nom, ''));
  IF v_nom = '' OR length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide');
  END IF;

  -- Ce compte a deja un personnage : ce n'est pas un fantome, rien a reconcilier.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu');
  END IF;
  -- Le nom reclame appartient a un personnage VIVANT : on n'enregistre pas une revendication
  -- sur l'identite de quelqu'un d'autre.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
  END IF;

  INSERT INTO public.reconciliation_fantomes (user_id, nom_local, empreinte, vu_le)
  VALUES (v_uid, v_nom, coalesce(p_empreinte, '{}'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE
    SET nom_local = EXCLUDED.nom_local, empreinte = EXCLUDED.empreinte, vu_le = now();

  RETURN jsonb_build_object('ok', true, 'enregistre', v_nom);
END;
$function$;

-- quete_objet_reclamer(uuid,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.quete_objet_reclamer(p_requete uuid, p_quete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; q public.quetes_actives; params jsonb; v jsonb; o jsonb; contenu text; msg text; indice integer;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR nullif(p_quete,'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 params:=jsonb_build_object('quete',p_quete);v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'quete_objet',params);IF v IS NOT NULL THEN RETURN v;END IF;
 SELECT * INTO q FROM public.quetes_actives WHERE id=p_quete FOR UPDATE;
 IF NOT FOUND OR q.statut IS DISTINCT FROM 'active' THEN RETURN jsonb_build_object('ok',false,'raison','quete_indisponible');END IF;
 IF q.country IS DISTINCT FROM a.country OR q.building_id IS NULL OR q.room_id IS NULL OR (a.current_building,a.current_room) IS DISTINCT FROM (q.building_id,q.room_id) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF q.etape_actuelle<q.nb_etapes_total THEN RETURN jsonb_build_object('ok',false,'raison','quete_non_terminee');END IF;
 IF EXISTS(SELECT 1 FROM public.inventaire_actions_recus WHERE action='quete_objet' AND parametres=params) THEN RETURN jsonb_build_object('ok',false,'raison','recompense_deja_remise');END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 IF q.recompense_type='objet' THEN
  indice:=floor(random()*7)::integer;
  SELECT objet-'origine'-'cible' INTO STRICT o FROM public.objets_modeles WHERE id='objet_trouve:'||indice;
  msg:='Vous obtenez : '||(o->>'name')||'.';
 ELSIF q.recompense_type='dossier_surveillance' AND nullif(q.cible_dossier,'') IS NOT NULL THEN
  SELECT string_agg('- '||type_action||coalesce(' (cible: '||cible||')','')||' — Jour '||jour,E'\n' ORDER BY created_at,id) INTO contenu
   FROM public.actions_tracables WHERE auteur=q.cible_dossier AND country=a.country AND city=a.current_city AND jour_expiration>=public.jour_de_jeu_pays(a.country);
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='quete:dossier';
  o:=o||jsonb_build_object('name','Dossier de surveillance — '||q.cible_dossier,'desc','Compilation d''actions réelles concernant '||q.cible_dossier||E' :\n'||coalesce(contenu,'Aucune action notable recensée récemment.'));
  msg:='Vous obtenez un dossier de surveillance complet sur '||q.cible_dossier||' !';
 ELSE RETURN jsonb_build_object('ok',false,'raison','recompense_non_objet');END IF;
 v:=public.inventaire_deposer_interne(a.name,o);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'quete: depot refuse';END IF;
 UPDATE public.quetes_actives SET statut='resolue',resolu_par=a.name,recompense_detail=msg WHERE id=q.id;
 v:=v||jsonb_build_object('message',msg,'titre',q.titre);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'quete_objet',params,v,now());RETURN v;
END; $function$;

-- rattacher_personnage(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rattacher_personnage(p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid       uuid := auth.uid();
  v_proprio   uuid;
  v_mien      text;
  c_sans_maitre CONSTANT uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  -- Jamais d'action sous la cle anon partagee : il faut une identite nominative.
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_session');
  END IF;
  IF p_nom IS NULL OR btrim(p_nom) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent');
  END IF;

  SELECT d.user_id INTO v_proprio
    FROM public.personnages_donnees d
   WHERE d.name = p_nom
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- Cas nominal : il est deja a moi. Rien a ecrire, l'acces est legitime.
  IF v_proprio = v_uid THEN
    RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'deja_rattache', true);
  END IF;

  -- Ce compte porte-t-il deja un AUTRE personnage ?
  SELECT d.name INTO v_mien
    FROM public.personnages_donnees d
   WHERE d.user_id = v_uid
   LIMIT 1;
  IF v_mien IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu', 'personnage', v_mien);
  END IF;

  -- Il appartient a un autre compte : refus sec, aucune ecriture.
  IF v_proprio IS DISTINCT FROM c_sans_maitre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_deja_possede');
  END IF;

  -- Seul cas de rattachement : personnage explicitement sans maitre.
  UPDATE public.personnages_donnees
     SET user_id = v_uid
   WHERE name = p_nom AND user_id = c_sans_maitre;

  RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'deja_rattache', false);
END;
$function$;

-- ref_patrimoine_existe(text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.ref_patrimoine_existe(p_ref text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;
  IF left(p_ref, 5) = 'orga:' THEN
    RETURN EXISTS (SELECT 1 FROM organisations WHERE id = substr(p_ref, 6));
  ELSIF left(p_ref, 3) = 'pj:' THEN
    RETURN EXISTS (SELECT 1 FROM personnages WHERE name = substr(p_ref, 4));
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM personnages WHERE name = p_ref);
END;
$function$;

-- ressource_ajuster_interne(text,text,integer) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ressource_ajuster_interne(p_nom text, p_cle text, p_delta integer)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, ARRAY[p_cle],
               to_jsonb(least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> p_cle) = 'number'
                                                              THEN (resources ->> p_cle)::numeric END, 0) + p_delta))))
       WHERE name = p_nom AND p_cle IN ('inf', 'pop') $function$;

-- restaurer_personnage_sauvegarde(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.restaurer_personnage_sauvegarde(p_nom text, p_poste text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid; v_emp jsonb; v_sauv record; v_cols text; v_sql text; v_res jsonb;
  v_champs text[] := ARRAY['archetype','career','origin','school'];
  v_c text; v_stat text;
BEGIN
  -- --- 1. Le compte a-t-il declare ce personnage ? ---
  SELECT user_id, empreinte INTO v_uid, v_emp
    FROM public.reconciliation_fantomes
   WHERE nom_local = p_nom AND traite IS FALSE
   ORDER BY vu_le DESC LIMIT 1;
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_declaration',
      'detail', 'Ce personnage n''a ete declare par aucun compte : le joueur doit recharger le jeu.');
  END IF;

  SELECT * INTO v_sauv FROM sauvegarde_beta_20260913.personnages WHERE name = p_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'absent_de_la_sauvegarde'); END IF;

  -- --- 2. L'empreinte corrobore-t-elle la sauvegarde ? ---
  FOREACH v_c IN ARRAY v_champs LOOP
    IF coalesce(v_emp ->> v_c, '') IS DISTINCT FROM coalesce(
         CASE v_c WHEN 'archetype' THEN v_sauv.archetype WHEN 'career' THEN v_sauv.career
                  WHEN 'origin' THEN v_sauv.origin ELSE v_sauv.school END, '') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'empreinte_incompatible', 'champ', v_c,
        'declare', v_emp ->> v_c, 'sauvegarde',
        CASE v_c WHEN 'archetype' THEN v_sauv.archetype WHEN 'career' THEN v_sauv.career
                 WHEN 'origin' THEN v_sauv.origin ELSE v_sauv.school END);
    END IF;
  END LOOP;
  FOREACH v_stat IN ARRAY ARRAY['CHA','DUP','ENT','INT','PER','VOL'] LOOP
    IF (v_emp -> 'stats' ->> v_stat) IS DISTINCT FROM (v_sauv.stats ->> v_stat) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'empreinte_incompatible', 'champ', 'stats.'||v_stat,
        'declare', v_emp -> 'stats' ->> v_stat, 'sauvegarde', v_sauv.stats ->> v_stat);
    END IF;
  END LOOP;

  -- --- 3. Ni doublon de compte, ni doublon de nom ---
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu');
  END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
  END IF;

  -- --- 4. Copie, colonnes communes uniquement, poste exclu ---
  SELECT string_agg(quote_ident(s.column_name), ', ' ORDER BY s.column_name) INTO v_cols
    FROM information_schema.columns s
   WHERE s.table_schema='sauvegarde_beta_20260913' AND s.table_name='personnages'
     AND s.column_name NOT IN ('poste','user_id','id')
     AND EXISTS (SELECT 1 FROM information_schema.columns a
                  WHERE a.table_schema='public' AND a.table_name='personnages_donnees'
                    AND a.column_name = s.column_name);

  -- Le trigger personnages_lier_proprietaire ecrase user_id par auth.uid() : on pose donc les
  -- claims de CE compte, localement a la transaction, pour que la ligne lui soit rattachee.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  v_sql := format('INSERT INTO public.personnages_donnees (%s, user_id) SELECT %s, %L FROM sauvegarde_beta_20260913.personnages WHERE name = %L',
                  v_cols, v_cols, v_uid, p_nom);
  EXECUTE v_sql;

  -- --- 5. Poste historique, via la primitive qui tient registre + PNJ + miroir ---
  IF p_poste IS NOT NULL THEN
    v_res := public.poste_attribuer_interne(v_sauv.country, p_poste, NULL, p_nom, 'restauration_sauvegarde');
    IF coalesce((v_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_restaure', 'detail', v_res);
    END IF;
  END IF;

  UPDATE public.reconciliation_fantomes SET traite = true WHERE user_id = v_uid;

  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'user_id', v_uid,
    'poste', p_poste, 'poste_resultat', v_res);
END;
$function$;

-- rp_transition_active(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rp_transition_active(p_cle text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT t.actif FROM public.rp_transitions t WHERE t.cle = p_cle), false);
$function$;

-- rue_position_enregistrer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rue_position_enregistrer(p_noeud text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_noeud public.rue_noeuds_serveur%ROWTYPE;
 v_depart text;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR v_pj.est_emprisonne IS NOT NULL AND v_pj.est_emprisonne<>'null'::jsonb THEN
 RETURN jsonb_build_object('ok',false,'raison','personnage_indisponible'); END IF;
 IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=v_nom AND expires_at>now()) THEN
 RETURN jsonb_build_object('ok',false,'raison','interception_en_cours'); END IF;
 SELECT * INTO v_noeud FROM public.rue_noeuds_serveur WHERE country=v_pj.country AND city=v_pj.current_city AND noeud=p_noeud;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','noeud_inconnu'); END IF;
 IF v_pj.current_building IS NOT NULL THEN
 IF NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments
 WHERE country=v_pj.country AND city=v_pj.current_city AND building=v_pj.current_building AND noeud=p_noeud) THEN
 RETURN jsonb_build_object('ok',false,'raison','sortie_invalide'); END IF;
 ELSIF v_pj.current_street IS NOT NULL AND v_pj.current_street<>p_noeud THEN
 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
 WHERE country=v_pj.country AND city=v_pj.current_city AND noeud=v_pj.current_street
 AND p_noeud=ANY(voisins)) THEN RETURN jsonb_build_object('ok',false,'raison','trajet_invalide'); END IF;
 ELSIF v_pj.current_street IS NULL THEN
 v_depart:=CASE v_pj.current_city WHEN 'capitale' THEN 'luthecia-palais-presidentiel'
 WHEN 'ville_a' THEN 'psm-centre-multimodal' WHEN 'ville_b' THEN 'montrouge-vue-3' ELSE NULL END;
 IF p_noeud IS DISTINCT FROM v_depart THEN RETURN jsonb_build_object('ok',false,'raison','position_initiale_invalide'); END IF;
 END IF;
 UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=p_noeud WHERE id=v_pj.id;
 UPDATE public.police_interceptions SET expires_at=now() WHERE personnage=v_nom AND expires_at>now();
 RETURN jsonb_build_object('ok',true,'noeud',p_noeud);
END;
$function$;

-- rue_position_lire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rue_position_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 RETURN jsonb_build_object('ok',true,'country',v_pj.country,'city',v_pj.current_city,
 'building',v_pj.current_building,'room',v_pj.current_room,'street',v_pj.current_street);
END;
$function$;

-- rue_sortie_batiment_lire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rue_sortie_batiment_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pj public.personnages_donnees%ROWTYPE; v_noeud text;
BEGIN
 v_nom := public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=v_nom;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 IF v_pj.current_building IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_dans_un_batiment'); END IF;
 SELECT s.noeud INTO v_noeud FROM public.rue_sorties_batiments s
 JOIN public.rue_noeuds_serveur n ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
 WHERE s.country=v_pj.country AND s.city=v_pj.current_city AND s.building=v_pj.current_building
 ORDER BY (s.noeud=v_pj.current_street) DESC,s.noeud LIMIT 1;
 IF v_noeud IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sortie_non_referencee'); END IF;
 RETURN jsonb_build_object('ok',true,'noeud',v_noeud);
END;
$function$;

-- sans_commentaires(text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.sans_commentaires(p_src text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  -- Retire les commentaires de ligne SQL/plpgsql. Sert UNIQUEMENT aux preuves de migration et aux
  -- controles : une mesure d'absence qui lirait la prose mesurerait le commentaire qui explique
  -- l'interdiction, pas le code qui la respecte.
  SELECT regexp_replace(coalesce(p_src, ''), '--[^\n]*', '', 'g');
$function$;

-- titulaire_est_moi(text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.titulaire_est_moi(p_ref text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;
  v_brut := btrim(coalesce(p_ref, ''));
  IF v_brut = '' THEN RETURN false; END IF;
  -- `orga:` et `ville:` ne sont jamais « moi » : titulaireCourant() est toujours un `pj:`.
  IF left(v_brut, 5) = 'orga:' OR left(v_brut, 6) = 'ville:' THEN RETURN false; END IF;
  IF left(v_brut, 3) = 'pj:' THEN RETURN btrim(substr(v_brut, 4)) = v_moi; END IF;
  -- Chaine non typee : donnee historique, toujours un nom de personnage aujourd'hui.
  RETURN v_brut = v_moi;
END; $function$;
