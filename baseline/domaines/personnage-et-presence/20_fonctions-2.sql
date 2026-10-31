-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- personnages_preserver_judiciaire() -> trigger | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.personnages_preserver_judiciaire()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_elem   jsonb;
  v_old    jsonb;
  v_convs  jsonb;
  v_hist   jsonb;
BEGIN
  -- ---------------------------------------------------------------- CONVOCATIONS
  IF NEW.convocations IS DISTINCT FROM OLD.convocations THEN
    v_convs := '[]'::jsonb;

    -- 1. On part de la version entrante, en y reportant les drapeaux monotones de l'ancienne.
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(NEW.convocations, '[]'::jsonb)) LOOP
      SELECT o.value INTO v_old
        FROM jsonb_array_elements(COALESCE(OLD.convocations, '[]'::jsonb)) o
       WHERE public.assemblee_cle_convocation(o.value) = public.assemblee_cle_convocation(v_elem)
       LIMIT 1;

      IF v_old IS NOT NULL THEN
        IF COALESCE((v_old->>'traitee')::boolean, false) THEN
          v_elem := v_elem || jsonb_build_object('traitee', true);
        END IF;
        IF COALESCE((v_old->>'echue')::boolean, false) THEN
          v_elem := v_elem || jsonb_build_object('echue', true, 'echueTs', v_old->'echueTs');
        END IF;
      END IF;

      v_convs := v_convs || jsonb_build_array(v_elem);
      v_old := NULL;
    END LOOP;

    -- 2. Toute convocation connue de la base mais absente de la version entrante est reinjectee.
    FOR v_old IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.convocations, '[]'::jsonb)) LOOP
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_convs) n
         WHERE public.assemblee_cle_convocation(n.value) = public.assemblee_cle_convocation(v_old)
      ) THEN
        v_convs := v_convs || jsonb_build_array(v_old);
      END IF;
    END LOOP;

    NEW.convocations := v_convs;
  END IF;

  -- ---------------------------------------------------------------- HISTORIQUE DES CRIMES
  IF NEW.historique_crimes IS DISTINCT FROM OLD.historique_crimes THEN
    v_hist := COALESCE(NEW.historique_crimes, '[]'::jsonb);

    FOR v_old IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.historique_crimes, '[]'::jsonb)) LOOP
      IF v_old->>'origine' = 'serveur'
         AND v_old ? 'id'
         AND (v_old->>'expireTs' IS NULL OR now() < (v_old->>'expireTs')::timestamptz)
         AND NOT EXISTS (
           SELECT 1 FROM jsonb_array_elements(v_hist) n WHERE n.value->>'id' = v_old->>'id'
         )
      THEN
        v_hist := v_hist || jsonb_build_array(v_old);
      END IF;
    END LOOP;

    NEW.historique_crimes := v_hist;
  END IF;

  -- ---------------------------------------------------------------- AVIS DE RECHERCHE
  -- SERVEUR-AUTORITAIRE depuis le 10 octobre 2026 (chantier 5, chaine 14). `recherche` n'a
  -- aucune cle : deux versions du tableau ne peuvent pas etre fusionnees, et le dernier ecrivain
  -- gagnait. Toute version entrante qui ne vient pas d'une porte est donc IGNOREE -- et seule
  -- cette colonne l'est, les quarante-sept autres du blob passent normalement.
  IF NEW.recherche IS DISTINCT FROM OLD.recherche
     AND coalesce(current_setting('rp.recherche_interne', true), '') <> 'on' THEN
    NEW.recherche := OLD.recherche;
  END IF;

  RETURN NEW;
END;
$function$;

-- personnages_proteger_refugie() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_proteger_refugie()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.est_emprisonne IS NOT NULL AND NEW.est_emprisonne <> 'null'::jsonb
     AND (OLD.est_emprisonne IS NULL OR OLD.est_emprisonne = 'null'::jsonb)
     AND NEW.current_building = 'quartier-ambassades'
     AND public.ambassade_refuge_de(NEW.name) IS NOT NULL THEN
    RAISE EXCEPTION 'refugie_protege: % beneficie de l''asile politique au Quartier des Ambassades', NEW.name
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END; $function$;

-- personnages_vue_inserer() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_vue_inserer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'creation_sans_compte' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
    -- GENRE OBLIGATOIRE (31/10/2026) : la valeur choisie à la création (creation.js), normalisée
    -- et bornée comme la saisie libre de l'écran. Aucune valeur par défaut n'est inventée.
    IF jsonb_typeof(NEW.stats) IS DISTINCT FROM 'object'
       OR nullif(btrim(regexp_replace(coalesce(NEW.stats->>'genre', ''), '\s+', ' ', 'g')), '') IS NULL
       OR length(btrim(regexp_replace(NEW.stats->>'genre', '\s+', ' ', 'g'))) > 24 THEN
      RAISE EXCEPTION 'genre_requis' USING ERRCODE = '22023',
        DETAIL = 'Le genre du personnage est obligatoire à la création (24 caractères au plus).';
    END IF;
    NEW.stats := jsonb_set(NEW.stats, '{genre}',
      to_jsonb(btrim(regexp_replace(NEW.stats->>'genre', '\s+', ' ', 'g'))));
    NEW.pa := least(coalesce(NEW.pa, 10), 10);
    -- DOTATION DE DEPART : au plus la meilleure combinaison possible du jeu.
    NEW.arg     := greatest(0, least(coalesce(NEW.arg, 0), 5000));
    NEW.liquide := greatest(0, least(coalesce(NEW.liquide, 0), NEW.arg));
    NEW.banque  := greatest(0, least(coalesce(NEW.banque, 0), NEW.arg));
  END IF;

  INSERT INTO public.personnages_donnees (
    id, name, country, photo_url, bio, archetype, career, origin, school,
    free_pts_restants, stats, resources, arg, liquide, banque, hp, pa, moral,
    poste, poste_depute, current_city, current_building, current_room, inventory,
    informateurs, contacts, historique_crimes, enquetes_en_cours, domicile,
    employes, escort_active, locations_actives, poison_actif, day, recherche,
    reputation_criminelle, salutations_du_jour, invitation_sociale_en_attente,
    convocations, est_emprisonne, detention_qhs, hospitalisation, stats_affaiblies,
    regen_jour, requisition, demandeur_emploi, carte_postale_moral_jour, motto,
    licence_sportive, performance_sportive, blessure_sportive, signature_html,
    signature_blocks, quete_accueil, enigme1, maxence, succes_maxence, journal,
    excommunie, reservation_hotel, qualifications, effets_actifs, bonus_lobbyiste,
    dernier_dormir, salaire_touche, dernier_objet_trouve_jour, photo_pos,
    user_id, created_at, updated_at, quete_carriere
  ) VALUES (
    coalesce(NEW.id, gen_random_uuid()), NEW.name, NEW.country, NEW.photo_url, NEW.bio,
    NEW.archetype, NEW.career, NEW.origin, NEW.school,
    coalesce(NEW.free_pts_restants, 0), NEW.stats, NEW.resources, NEW.arg, NEW.liquide,
    NEW.banque, NEW.hp, NEW.pa, NEW.moral, NEW.poste, NEW.poste_depute,
    NEW.current_city, NEW.current_building, NEW.current_room, NEW.inventory,
    NEW.informateurs, NEW.contacts, NEW.historique_crimes, NEW.enquetes_en_cours, NEW.domicile,
    NEW.employes, NEW.escort_active, NEW.locations_actives, NEW.poison_actif, NEW.day,
    NEW.recherche, NEW.reputation_criminelle, NEW.salutations_du_jour,
    NEW.invitation_sociale_en_attente, NEW.convocations, NEW.est_emprisonne,
    NEW.detention_qhs, NEW.hospitalisation, coalesce(NEW.stats_affaiblies, '{}'::jsonb),
    NEW.regen_jour, NEW.requisition, coalesce(NEW.demandeur_emploi, false),
    NEW.carte_postale_moral_jour, NEW.motto, NEW.licence_sportive, NEW.performance_sportive,
    NEW.blessure_sportive, NEW.signature_html, NEW.signature_blocks, NEW.quete_accueil,
    NEW.enigme1, NEW.maxence, NEW.succes_maxence, NEW.journal, NEW.excommunie,
    NEW.reservation_hotel, coalesce(NEW.qualifications, '[]'::jsonb),
    coalesce(NEW.effets_actifs, '[]'::jsonb), coalesce(NEW.bonus_lobbyiste, 0),
    NEW.dernier_dormir, NEW.salaire_touche, NEW.dernier_objet_trouve_jour, NEW.photo_pos,
    NEW.user_id, coalesce(NEW.created_at, now()), coalesce(NEW.updated_at, now()),
    NEW.quete_carriere
  );
  RETURN NEW;
END; $function$;

-- personnages_vue_modifier() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_canon public.personnages_donnees%rowtype;
  v_role  text := coalesce(nullif(current_setting('role', true), ''), session_user);
  v_req   text := left(coalesce(current_query(), ''), 500);
  v_verrou boolean;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF auth.uid() IS NULL
       OR OLD.user_id IS NULL
       OR OLD.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_canon FROM public.personnages_donnees WHERE id = OLD.id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501';
    END IF;

    NEW.user_id := v_canon.user_id;

    -- REFUS BRUYANT (30/10/2026) : une fonction serveur lancée par un joueur n'écrit jamais
    -- l'argent ni les champs protégés par cette porte ; sinon l'effet serait annulé en silence.
    IF coalesce(current_setting('request.path', true), '') LIKE '/rpc/%' AND (
         NEW.arg IS DISTINCT FROM OLD.arg
      OR NEW.liquide IS DISTINCT FROM OLD.liquide
      OR NEW.banque IS DISTINCT FROM OLD.banque
      OR NEW.stats IS DISTINCT FROM OLD.stats
      OR NEW.free_pts_restants IS DISTINCT FROM OLD.free_pts_restants
      OR NEW.qualifications IS DISTINCT FROM OLD.qualifications
      OR coalesce(NEW.pa, 0) > coalesce(OLD.pa, 0)) THEN
      RAISE EXCEPTION 'fiche_ecriture_serveur_par_la_vue'
        USING ERRCODE = 'P0001',
              DETAIL = 'Une fonction serveur doit écrire public.personnages_donnees, pas la vue de l''écran.';
    END IF;

    -- Fusion à trois voies (30/10/2026) : une copie ancienne ne défait plus le serveur.
    IF NEW.fiche_base IS NOT NULL AND jsonb_typeof(NEW.fiche_base) = 'object' THEN
      NEW := jsonb_populate_record(NEW, public.fiche_fusionner_ecran(to_jsonb(NEW), NEW.fiche_base, to_jsonb(v_canon)));
    END IF;
    NEW.fiche_base := NULL;

    IF coalesce(NEW.pa, 0) > coalesce(v_canon.pa, 0) THEN
      NEW.pa := v_canon.pa;
    END IF;

    NEW.stats             := v_canon.stats;
    NEW.free_pts_restants := v_canon.free_pts_restants;
    NEW.qualifications    := v_canon.qualifications;
    NEW.banque            := v_canon.banque;

    v_verrou := public.rp_transition_active('argent_verrou');

    IF coalesce(NEW.arg, 0) > coalesce(v_canon.arg, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'arg', v_canon.arg, NEW.arg, coalesce(NEW.arg,0) - coalesce(v_canon.arg,0), v_role, v_req);
      IF v_verrou THEN NEW.arg := v_canon.arg; END IF;
    END IF;
    IF coalesce(NEW.liquide, 0) > coalesce(v_canon.liquide, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'liquide', v_canon.liquide, NEW.liquide, coalesce(NEW.liquide,0) - coalesce(v_canon.liquide,0), v_role, v_req);
      IF v_verrou THEN NEW.liquide := v_canon.liquide; END IF;
    END IF;
    IF coalesce(NEW.hp, 0) > coalesce(v_canon.hp, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'hp', v_canon.hp, NEW.hp, coalesce(NEW.hp,0) - coalesce(v_canon.hp,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.day, 0) > coalesce(v_canon.day, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'day', v_canon.day, NEW.day, coalesce(NEW.day,0) - coalesce(v_canon.day,0), v_role, v_req);
    END IF;

    NEW.arg       := coalesce(NEW.arg,       v_canon.arg);
    NEW.liquide   := coalesce(NEW.liquide,   v_canon.liquide);
    NEW.inventory := coalesce(NEW.inventory, v_canon.inventory);
  END IF;

  -- PLAFOND DU JOURNAL PERSONNEL : 500 ENTREES (24 septembre 2026, regle validee).
  -- Le journal est empile par la tete (unshift cote client) : on garde donc les 500
  -- PREMIERES, c'est-a-dire les plus recentes, et on abandonne les plus anciennes.
  -- Plafond de RETENTION, applique a toute ecriture, serveur comprise -- ce n'est pas un
  -- controle d'autorite. Aucune fiche reelle n'est concernee (120 entrees au maximum) :
  -- cette migration ne transforme aucune donnee existante.
  IF jsonb_typeof(NEW.journal) = 'array' AND jsonb_array_length(NEW.journal) > 500 THEN
    SELECT jsonb_agg(e ORDER BY ord) INTO NEW.journal
      FROM jsonb_array_elements(NEW.journal) WITH ORDINALITY AS t(e, ord) WHERE ord <= 500;
  END IF;

  IF NOT public.est_appel_serveur() THEN
     NEW.arg := v_canon.arg;
     NEW.liquide := v_canon.liquide;
   END IF;

  IF NOT public.est_appel_serveur() THEN
     NEW.arg       := v_canon.arg;
     NEW.liquide   := v_canon.liquide;
   END IF;

  UPDATE public.personnages_donnees SET
    name = NEW.name, country = NEW.country, photo_url = NEW.photo_url, bio = NEW.bio,
    archetype = NEW.archetype, career = NEW.career, origin = NEW.origin, school = NEW.school,
    free_pts_restants = NEW.free_pts_restants, stats = NEW.stats, resources = NEW.resources,
    arg = NEW.arg, liquide = NEW.liquide, banque = NEW.banque,
    hp = NEW.hp, pa = NEW.pa, moral = NEW.moral, poste = NEW.poste, poste_depute = NEW.poste_depute,
    current_city = NEW.current_city, current_building = NEW.current_building, current_room = NEW.current_room,
    inventory = NEW.inventory, informateurs = NEW.informateurs, contacts = NEW.contacts,
    historique_crimes = NEW.historique_crimes, enquetes_en_cours = NEW.enquetes_en_cours,
    domicile = NEW.domicile, employes = NEW.employes, escort_active = NEW.escort_active,
    locations_actives = NEW.locations_actives, poison_actif = NEW.poison_actif, day = NEW.day,
    recherche = NEW.recherche, reputation_criminelle = NEW.reputation_criminelle,
    salutations_du_jour = NEW.salutations_du_jour,
    invitation_sociale_en_attente = NEW.invitation_sociale_en_attente,
    convocations = NEW.convocations, est_emprisonne = NEW.est_emprisonne,
    detention_qhs = NEW.detention_qhs, hospitalisation = NEW.hospitalisation,
    stats_affaiblies = NEW.stats_affaiblies, regen_jour = NEW.regen_jour,
    requisition = NEW.requisition, demandeur_emploi = NEW.demandeur_emploi,
    carte_postale_moral_jour = NEW.carte_postale_moral_jour, motto = NEW.motto,
    licence_sportive = NEW.licence_sportive, performance_sportive = NEW.performance_sportive,
    blessure_sportive = NEW.blessure_sportive, signature_html = NEW.signature_html,
    signature_blocks = NEW.signature_blocks, quete_accueil = NEW.quete_accueil,
    enigme1 = NEW.enigme1, maxence = NEW.maxence, succes_maxence = NEW.succes_maxence,
    journal = NEW.journal, excommunie = NEW.excommunie, reservation_hotel = NEW.reservation_hotel,
    qualifications = NEW.qualifications, effets_actifs = NEW.effets_actifs,
    bonus_lobbyiste = NEW.bonus_lobbyiste, dernier_dormir = NEW.dernier_dormir,
    salaire_touche = NEW.salaire_touche, dernier_objet_trouve_jour = NEW.dernier_objet_trouve_jour,
    photo_pos = NEW.photo_pos, user_id = NEW.user_id, updated_at = NEW.updated_at,
    quete_carriere = NEW.quete_carriere
  WHERE id = OLD.id;
  RETURN NEW;
END;
$function$;

-- personnages_vue_supprimer() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_vue_supprimer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
  END IF;
  PERFORM set_config('rp.suppression_via_vue', '1', true);   -- true = LOCAL
  DELETE FROM public.personnages_donnees WHERE id = OLD.id;
  PERFORM set_config('rp.suppression_via_vue', '', true);
  RETURN OLD;
END; $function$;

-- piete_score_actif_interne(text,text) -> numeric | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.piete_score_actif_interne(p_auteur text, p_ville text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce(sum(quantite), 0)::numeric FROM public.contributions_piete
       WHERE pays = 'republic' AND auteur = p_auteur AND ville = p_ville
         AND created_at >= now() - interval '7 days' $function$;

-- piete_ville_calculee_interne(text) -> numeric | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.piete_ville_calculee_interne(p_ville text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT least(100, greatest(0, 40 + coalesce(sum(quantite), 0)))::numeric FROM public.contributions_piete
       WHERE pays = 'republic' AND ville = p_ville AND created_at >= now() - interval '7 days' $function$;

-- piete_villes_actualiser() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.piete_villes_actualiser()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ville text; v_out jsonb := '{}'::jsonb;
BEGIN
  FOREACH v_ville IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
    INSERT INTO public.indices_villes (id, data, updated_at)
      VALUES ('republic_' || v_ville, '{"isn":30,"ie":50,"social":45,"moral":50}'::jsonb, now())
      ON CONFLICT (id) DO UPDATE SET updated_at = now();
    v_out := v_out || jsonb_build_object(v_ville, public.piete_ville_calculee_interne(v_ville));
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'piete', v_out);
END; $function$;

-- quete_accueil_contexte() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.quete_accueil_contexte()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_q jsonb; v_etape text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT quete_accueil INTO v_q FROM public.personnages_donnees WHERE name = v_moi;
  IF v_q IS NULL OR jsonb_typeof(v_q) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'etape', NULL, 'visite_en_cours', false);
  END IF;
  v_etape := nullif(btrim(coalesce(v_q ->> 'etape', '')), '');

  -- LES TROIS ETATS TERMINAUX SONT NOMMES, PAS DEVINES. `carriere_terminee`,
  -- `quete_terminee_sans_aide` et `refusee` sont les trois valeurs que le client ecrit quand la
  -- visite est finie ou refusee ; toute autre valeur est une visite en cours. Nommer l'inverse --
  -- la liste des etapes vivantes -- aurait fait mentir cette porte a chaque etape ajoutee.
  RETURN jsonb_build_object(
    'ok', true,
    'etape', v_etape,
    'visite_en_cours',
      v_etape IS NOT NULL
      AND v_etape NOT IN ('carriere_terminee', 'quete_terminee_sans_aide', 'refusee'));
END;
$function$;

-- referent_pedagogie_contexte(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.referent_pedagogie_contexte(p_referent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_moi    text;
  v_n      integer := 0;
  v_sujets jsonb   := '[]'::jsonb;
  FENETRE  constant interval := interval '10 days';
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'pas_de_personnage');
  end if;

  select coalesce(p.consultations, 0),
         coalesce(
           (select jsonb_agg(c.libelle order by c.libelle)
              from jsonb_each_text(coalesce(p.sujets, '{}'::jsonb)) as s(cle, quand)
              join public.pnj_referents_sujets_connus c
                on c.referent_id = p_referent_id and c.sujet = s.cle
             where (s.quand)::timestamptz > now() - FENETRE),
           '[]'::jsonb)
    into v_n, v_sujets
    from public.pnj_referents_pedagogie p
   where p.referent_id = p_referent_id and p.joueur = v_moi;

  return jsonb_build_object('ok', true,
                            'consultations', coalesce(v_n, 0),
                            'sujets', coalesce(v_sujets, '[]'::jsonb));
end;
$function$;

-- referent_pedagogie_noter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.referent_pedagogie_noter(p_referent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = p_referent_id) THEN
    RETURN jsonb_build_object('ok', true, 'referent', false); END IF;

  INSERT INTO public.pnj_referents_pedagogie (referent_id, joueur, consultations)
       VALUES (p_referent_id, v_moi, 1)
  ON CONFLICT (referent_id, joueur) DO UPDATE
     SET consultations = public.pnj_referents_pedagogie.consultations + 1,
         derniere_le   = now();

  SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
   WHERE referent_id = p_referent_id AND joueur = v_moi;
  RETURN jsonb_build_object('ok', true, 'referent', true, 'consultations', v_n);
END;
$function$;

-- referent_pedagogie_noter_sujet(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.referent_pedagogie_noter_sujet(p_referent_id text, p_sujet text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_moi text;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'pas_de_personnage');
  end if;

  if not exists (
    select 1 from public.pnj_referents_sujets_connus
     where referent_id = p_referent_id and sujet = p_sujet
  ) then
    return jsonb_build_object('ok', false, 'raison', 'sujet_inconnu');
  end if;

  insert into public.pnj_referents_pedagogie (referent_id, joueur)
  values (p_referent_id, v_moi)
  on conflict (referent_id, joueur) do nothing;

  -- L'horodatage ECRASE le precedent : reparler d'un sujet le rafraichit.
  update public.pnj_referents_pedagogie
     set sujets = coalesce(sujets, '{}'::jsonb)
                  || jsonb_build_object(p_sujet, to_jsonb(now())),
         derniere_le = now()
   where referent_id = p_referent_id and joueur = v_moi;

  return jsonb_build_object('ok', true);
end;
$function$;

-- religion_agir(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.religion_agir(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_eglise text; v_paie jsonb; v_excom boolean; v_qte integer := 0;
  v_moral integer; v_res jsonb; v_total numeric; v_grade_avant text; v_grade_apres text;
  v_score numeric; v_tit text; v_score_tit numeric; v_gp text; v_score_gp numeric; v_v text;
  v_nom_ville text; v_charge boolean := false; v_gp_conquis boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fn NOT IN ('prier', 'faire_don') THEN RETURN jsonb_build_object('ok', false, 'raison', 'ordre_indisponible'); END IF;
  SELECT country, current_city, current_building, excommunie INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF d.country IS DISTINCT FROM 'republic' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_republia'); END IF;
  v_eglise := CASE d.current_city WHEN 'capitale' THEN 'tabernacle-impots' WHEN 'ville_a' THEN 'notre-dame-mer'
                                  WHEN 'ville_b' THEN 'eglise-montrouge' END;
  IF v_eglise IS NULL OR d.current_building IS DISTINCT FROM v_eglise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_nom_ville := CASE d.current_city WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie' ELSE 'Montrouge' END;
  v_excom := d.excommunie IS NOT NULL AND jsonb_typeof(d.excommunie) <> 'null' AND d.excommunie <> 'false'::jsonb;
  IF p_fn = 'prier' THEN
    v_paie := public.payer_ordre(v_moi, p_fn, p_pa, p_cost);
  ELSE
    v_paie := public.vente_structure_encaisser(p_fn, p_pa, p_cost, 'republic_' || v_eglise, d.current_city);
  END IF;
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT coalesce(moral, 75), CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_moral, v_res FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF p_fn = 'prier' THEN
    v_moral := least(100, v_moral + 2);
    v_qte := CASE WHEN v_excom THEN 0 ELSE 3 END;
  ELSE
    v_res := jsonb_set(v_res, '{pop}', to_jsonb(least(100, coalesce(CASE WHEN jsonb_typeof(v_res -> 'pop') = 'number'
                                                                        THEN (v_res ->> 'pop')::numeric END, 50) + 3)));
    v_qte := 5;
  END IF;
  UPDATE public.personnages_donnees SET moral = v_moral, resources = v_res WHERE name = v_moi;
  IF v_qte > 0 THEN
    SELECT coalesce(sum(quantite), 0) INTO v_total FROM public.contributions_piete WHERE pays = 'republic' AND auteur = v_moi;
    v_grade_avant := public.religion_grade_interne(v_total);
    INSERT INTO public.contributions_piete (pays, ville, auteur, quantite, created_at)
      VALUES ('republic', d.current_city, v_moi, v_qte, now());
    v_grade_apres := public.religion_grade_interne(v_total + v_qte);
    UPDATE public.indices_villes SET updated_at = now() WHERE id = 'republic_' || d.current_city;
    IF NOT FOUND THEN PERFORM public.piete_villes_actualiser(); END IF;
    IF v_grade_apres = 'pretre' THEN
      v_score := public.piete_score_actif_interne(v_moi, d.current_city);
      v_tit := public.religion_titulaire_interne('pretre', d.current_city);
      IF v_tit IS DISTINCT FROM v_moi THEN
        v_score_tit := CASE WHEN EXISTS (SELECT 1 FROM public.personnages_donnees WHERE country = 'republic' AND name = v_tit)
                            THEN public.piete_score_actif_interne(v_tit, d.current_city)
                            ELSE CASE WHEN d.current_city = 'capitale' THEN 50 ELSE 40 END END;
        IF v_score > v_score_tit THEN
          PERFORM public.religion_titulaire_poser_interne('pretre', d.current_city, v_moi);
          PERFORM public.annonce_publique_interne('republic', '⛪ ' || v_moi || ' devient Prêtre titulaire de ' || v_nom_ville || '.');
          v_charge := true; v_tit := v_moi;
        END IF;
      END IF;
      IF v_tit = v_moi THEN
        v_gp := public.religion_titulaire_interne('grand_pretre', NULL);
        IF v_gp IS DISTINCT FROM v_moi THEN
          IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE country = 'republic' AND name = v_gp) THEN
            v_score_gp := NULL;
            FOREACH v_v IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
              IF v_score_gp IS NULL AND public.religion_titulaire_interne('pretre', v_v) = v_gp THEN
                v_score_gp := public.piete_score_actif_interne(v_gp, v_v);
              END IF;
            END LOOP;
          ELSE
            v_score_gp := 50;
          END IF;
          IF v_score_gp IS NULL OR v_score > v_score_gp THEN
            PERFORM public.religion_titulaire_poser_interne('grand_pretre', NULL, v_moi);
            PERFORM public.annonce_publique_interne('republic', '⛪ ' || v_moi || ' devient le nouveau Grand Prêtre national de Républia.');
            v_gp_conquis := true;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'fn', p_fn, 'piete_ajoutee', v_qte, 'excommunie', v_excom,
    'moral', v_moral, 'pop', v_res -> 'pop',
    'grade_avant', v_grade_avant, 'grade', v_grade_apres,
    'charge_conquise', v_charge, 'grand_pretre_conquis', v_gp_conquis, 'ville', d.current_city, 'nom_ville', v_nom_ville,
    'piete_ville', public.piete_ville_calculee_interne(d.current_city),
    'pa', v_paie -> 'pa', 'liquide', v_paie -> 'liquide', 'arg', v_paie -> 'arg', 'solde_national', v_paie -> 'solde_national');
END; $function$;

-- religion_grade_interne(numeric) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.religion_grade_interne(p_total numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT CASE WHEN p_total >= 45 THEN 'pretre' WHEN p_total >= 25 THEN 'clerc'
                  WHEN p_total >= 10 THEN 'enfant_de_choeur' END $function$;

-- religion_titulaire_interne(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.religion_titulaire_interne(p_poste text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce(
  (SELECT nom_pnj FROM public.titulaires_pnj WHERE id = 'republic_' || p_poste || '_' || coalesce(p_ville, 'national')),
  CASE WHEN p_poste = 'grand_pretre' THEN 'Père Ception'
       ELSE CASE p_ville WHEN 'capitale' THEN 'Père Ception' WHEN 'ville_a' THEN 'Père Iscope'
                         WHEN 'ville_b' THEN 'Abbé Tonnière' END END) $function$;

-- religion_titulaire_poser_interne(text,text,text) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.religion_titulaire_poser_interne(p_poste text, p_ville text, p_nom text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at)
      VALUES ('republic_' || p_poste || '_' || coalesce(p_ville, 'national'), 'republic', p_poste, p_ville, p_nom, now())
      ON CONFLICT (id) DO UPDATE SET nom_pnj = EXCLUDED.nom_pnj, updated_at = now() $function$;

-- souvenir_accueil_tirer(text,date) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.souvenir_accueil_tirer(p_souvenir_id text, p_jour date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s public.souvenirs_accueil; v_chance numeric; v_jet numeric; v_n integer;
BEGIN
  IF p_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_manquant');
  END IF;

  SELECT * INTO s FROM public.souvenirs_accueil WHERE id = p_souvenir_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'souvenir_introuvable');
  END IF;

  -- Un souvenir deja revele ne refuit pas. Ce n'est pas une erreur : c'est le cas normal d'une
  -- liste lue avant qu'une autre passe ne la consomme.
  IF coalesce(s.revele, false) THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_revele');
  END IF;

  -- LA GARDE QUE L'AUDIT RECLAMAIT : la frontiere est le souvenir, pas la passe.
  IF s.jour_tirage = p_jour THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_tire');
  END IF;

  -- LE HASARD EST DANS LA TRANSACTION QUI EN PORTE LES CONSEQUENCES. Memes deux tirages, memes
  -- bornes, meme comparaison que dans le navigateur : 5 % a 10 %.
  v_chance := 0.05 + random() * 0.05;
  v_jet := random();

  IF v_jet >= v_chance THEN
    UPDATE public.souvenirs_accueil SET jour_tirage = p_jour
     WHERE id = p_souvenir_id AND revele IS NOT TRUE;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN RAISE EXCEPTION 'souvenir_accueil_tirer : marquage de journee non pris'; END IF;
    RETURN jsonb_build_object('ok', true, 'action', 'pas_de_fuite');
  END IF;

  -- LE MARQUAGE EST UN COMPARE-AND-SWAP, et l'annonce est dans la meme transaction que lui.
  UPDATE public.souvenirs_accueil SET revele = true, jour_tirage = p_jour
   WHERE id = p_souvenir_id AND revele IS NOT TRUE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_revele');
  END IF;

  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES ('republic', NULL,
          '📰 SCANDALE : un journaliste révèle que ' || s.pj_nom || ' a récupéré "'
            || s.objet_nom || '" au service des objets trouvés de l''Assemblée.',
          NULL);

  RETURN jsonb_build_object('ok', true, 'action', 'fuite', 'pj', s.pj_nom, 'objet', s.objet_nom);
END; $function$;

-- succession_regler(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.succession_regler(p_succession_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s public.successions; v_disp jsonb; v_nouv jsonb; v_d jsonb; v_i integer;
  v_benef text; v_reglees integer := 0; v_echecs text[] := '{}'; v_fisc text[] := '{}';
  v_cloturee boolean := false; v_n integer; v_tid text; v_etat jsonb; v_nat jsonb;
  v_ok boolean; v_r jsonb;
BEGIN
  SELECT * INTO s FROM public.successions WHERE id = p_succession_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_introuvable');
  END IF;
  IF s.statut <> 'en_attente' THEN
    -- Pas une erreur : la cloture a deja eu lieu. Le rejeu ne doit rien faire et le dire.
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_resolue', 'cloturee', false);
  END IF;

  v_disp := coalesce(s.dispositions, '[]'::jsonb);

  FOR v_i IN 0 .. greatest(0, jsonb_array_length(v_disp) - 1) LOOP
    v_d := v_disp -> v_i;
    CONTINUE WHEN v_d IS NULL;
    CONTINUE WHEN coalesce((v_d ->> 'regle')::boolean, false);
    -- Une disposition sans decision tranchee n'est pas reglable. L'appelant ne presente la
    -- succession que lorsque toutes le sont ; on refuse plutot que de lever.
    IF v_d -> 'resultat' IS NULL OR jsonb_typeof(v_d -> 'resultat') = 'null' THEN
      v_echecs := array_append(v_echecs, v_i::text || ':decision_absente');
      CONTINUE;
    END IF;
    v_benef := nullif(v_d -> 'resultat' ->> 'beneficiaire', '');

    BEGIN
      IF (v_d ->> 'type') = 'terrain' THEN
        SELECT t.id, t.data::jsonb INTO v_tid, v_etat FROM public.terrains_etat t
         WHERE t.country = s.country AND t.building_id = (v_d ->> 'id') FOR UPDATE;
        IF v_tid IS NULL THEN RAISE EXCEPTION 'terrain_introuvable'; END IF;
        v_etat := jsonb_set(coalesce(v_etat,'{}'::jsonb), '{proprietaire}',
                            coalesce(to_jsonb(v_benef), 'null'::jsonb), true);
        v_etat := jsonb_set(v_etat, '{coproprietaire}', 'null'::jsonb, true);
        v_etat := jsonb_set(v_etat, '{succession_gel}', 'null'::jsonb, true);
        UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = v_tid;

      ELSIF (v_d ->> 'type') = 'entreprise' THEN
        SELECT e.data INTO v_etat FROM public.entreprises e
         WHERE e.id = (v_d ->> 'id') FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'entreprise_introuvable'; END IF;
        v_etat := jsonb_set(coalesce(v_etat,'{}'::jsonb), '{proprietaire}',
                            to_jsonb(coalesce(v_benef, 'PNJ')), true);
        v_etat := jsonb_set(v_etat, '{succession_gel}', 'null'::jsonb, true);
        UPDATE public.entreprises SET data = v_etat, updated_at = now() WHERE id = (v_d ->> 'id');

      ELSIF (v_d ->> 'type') = 'argent' AND coalesce((v_d ->> 'part_nette')::numeric, 0) > 0 THEN
        v_n := 0;
        IF v_benef IS NOT NULL THEN
          UPDATE public.personnages_donnees
             SET arg = coalesce(arg, 0) + (v_d ->> 'part_nette')::numeric
           WHERE name = v_benef;
          GET DIAGNOSTICS v_n = ROW_COUNT;
        END IF;
        -- Devolution a l'Etat : d'emblee (chaine epuisee) ou en repli si le beneficiaire a
        -- disparu entre l'acceptation et le reglement, plutot que de laisser la somme disparaitre.
        IF v_n <> 1 THEN
          SELECT b.data INTO v_nat FROM public.budgets_nationaux b
           WHERE b.id = s.country FOR UPDATE;
          IF NOT FOUND THEN RAISE EXCEPTION 'budget_national_introuvable'; END IF;
          UPDATE public.budgets_nationaux
             SET data = jsonb_set(coalesce(v_nat,'{}'::jsonb), '{reserveJour}',
                   to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0)
                            + (v_d ->> 'part_nette')::numeric), true),
                 updated_at = now()
           WHERE id = s.country;
        END IF;
      END IF;

      -- LE MARQUEUR, DANS LA MEME SOUS-TRANSACTION QUE LA MUTATION. C'est tout l'objet de ce lot.
      v_nouv := jsonb_set(v_disp, ARRAY[v_i::text, 'regle'], 'true'::jsonb, true);
      UPDATE public.successions SET dispositions = v_nouv WHERE id = p_succession_id;
      v_disp := v_nouv;
      v_reglees := v_reglees + 1;
    EXCEPTION WHEN others THEN
      -- La sous-transaction a annule la mutation ET le marqueur. v_disp n'a pas ete reaffecte.
      v_echecs := array_append(v_echecs, v_i::text || ':' || sqlerrm);
    END;
  END LOOP;

  IF coalesce(s.droits_total, 0) > 0 THEN
    IF NOT coalesce(s.part_etat_reglee, false) THEN
      BEGIN
        SELECT b.data INTO v_nat FROM public.budgets_nationaux b
         WHERE b.id = s.country FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'budget_national_introuvable'; END IF;
        UPDATE public.budgets_nationaux
           SET data = jsonb_set(coalesce(v_nat,'{}'::jsonb), '{reserveJour}',
                 to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0)
                          + coalesce(s.part_etat, 0)), true),
               updated_at = now()
         WHERE id = s.country;
        UPDATE public.successions SET part_etat_reglee = true WHERE id = p_succession_id;
        v_fisc := array_append(v_fisc, 'etat');
      EXCEPTION WHEN others THEN
        v_echecs := array_append(v_echecs, 'etat:' || sqlerrm);
      END;
    END IF;
    IF NOT coalesce(s.part_notaire_reglee, false) THEN
      BEGIN
        PERFORM set_config('rp.caisse_interne', 'on', true);
        v_r := public.caisse_institution_mouvement(s.country || '_office-notarial',
                                                   coalesce(s.part_notaire, 0));
        v_ok := coalesce((v_r ->> 'ok')::boolean, false);
        IF NOT v_ok THEN RAISE EXCEPTION 'caisse_notaire:%', coalesce(v_r ->> 'raison','?'); END IF;
        UPDATE public.successions SET part_notaire_reglee = true WHERE id = p_succession_id;
        v_fisc := array_append(v_fisc, 'notaire');
      EXCEPTION WHEN others THEN
        v_echecs := array_append(v_echecs, 'notaire:' || sqlerrm);
      END;
    END IF;
  END IF;

  -- CLOTURE EN TOUT DERNIER, sur l'etat RELU : statut='resolue' n'est pas une protection contre le
  -- rejeu, seulement un marqueur de fermeture. Le compare-and-swap sur statut la rend unique.
  SELECT * INTO s FROM public.successions WHERE id = p_succession_id;
  IF (SELECT bool_and(coalesce((e ->> 'regle')::boolean, false))
        FROM jsonb_array_elements(coalesce(s.dispositions, '[]'::jsonb)) e) IS NOT FALSE
     AND (coalesce(s.droits_total, 0) = 0
          OR (coalesce(s.part_etat_reglee,false) AND coalesce(s.part_notaire_reglee,false))) THEN
    UPDATE public.successions SET statut = 'resolue', resolved_at = now()
     WHERE id = p_succession_id AND statut = 'en_attente';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_cloturee := (v_n = 1);
  END IF;

  RETURN jsonb_build_object('ok', true, 'dispositions_reglees', v_reglees,
    'fiscalite', to_jsonb(v_fisc), 'cloturee', v_cloturee, 'echecs', to_jsonb(v_echecs));
END; $function$;

-- syndicat_etudiant_domicilier(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.syndicat_etudiant_domicilier(p_nom text, p_desc text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  -- L'ECHELLE DES GRADES SYNDICAUX, RECOPIEE DE `ORGANISATIONS_DEF.syndicale.grades` (data.js).
  -- Le serveur ne peut pas importer data.js -- aucun module, aucun export -- et un syndicat
  -- etudiant doit avoir la MEME echelle que les autres syndicats. La copie est donc assumee et
  -- signalee au rapport comme une ressaisie a tenir en phase.
  c_grades constant jsonb := jsonb_build_object(
    'republic', jsonb_build_array('Adherent', 'Secretaire General Adjoint', 'Secretaire General', 'Confederal'),
    'narco',    jsonb_build_array('Afilado', 'Delegado', 'Secretario', 'Comandante Sindical'),
    'soviet',   jsonb_build_array('Camarade de base', 'Delegue', 'Secretaire de cellule', 'Premier Secretaire'),
    'khalija',  jsonb_build_array('Affilie', 'Delegue du Souk', 'Secretaire de la Guilde', 'Grand Intendant'));
  v_moi text; v_pays text; v_ville text; v_inv jsonb; v_nom text; v_desc text;
  v_jour integer; v_paye jsonb; v_doc jsonb; v_caisse text; v_id text;
  v_grades jsonb; v_grade text; v_blob jsonb; v_contenu jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  v_nom  := nullif(btrim(coalesce(p_nom, '')), '');
  v_desc := nullif(btrim(coalesce(p_desc, '')), '');
  IF v_nom IS NULL OR length(v_nom) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_requis');
  END IF;
  IF length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80);
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LA PRESENCE DANS LA SALLE DE REUNION, ET LA REGLE DE LOCALISATION UNIQUE DU JEU.
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, 'universite', 'salle_reunion') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_de_reunion_requise',
                              'site', 'universite', 'piece', 'salle_reunion');
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- AUCUNE EXCLUSIVITE : on ne verifie PAS qu'une organisation occupe deja ce local. C'est tout
  -- le changement de nature de la piece -- plusieurs syndicats y sont domicilies a la fois.
  v_caisse := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'syndicat_etudiant_creer', 2, 150);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  -- LES 150 FR SONT DES FRAIS DE GREFFE : ils entrent dans la caisse du tribunal.
  PERFORM public.caisse_institution_mouvement(v_caisse, 150, true);

  v_jour   := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_grades := coalesce(c_grades -> v_pays, c_grades -> 'republic');
  v_grade  := v_grades ->> (jsonb_array_length(v_grades) - 1);
  v_id     := 'orga_syndet_' || replace(gen_random_uuid()::text, '-', '');

  v_blob := jsonb_build_object(
    'id', v_id, 'type', 'syndicale', 'nom', v_nom, 'desc', coalesce(v_desc, ''),
    'fondateur', v_moi, 'chef', v_moi,
    -- LA FONDATION MINIMALE DE L'OSSATURE, et rien de plus : deux cles, aucune prerogative.
    'president', v_moi, 'secretaire', NULL, 'tresorier', NULL,
    'country', v_pays, 'country_origine', v_pays,
    'creeLe', v_jour,
    'membres', jsonb_build_array(jsonb_build_object(
      'nom', v_moi, 'grade', v_grade, 'gradeIdx', jsonb_array_length(v_grades) - 1,
      'rejointLe', v_jour)),
    'demandesAdhesion', '[]'::jsonb,
    'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0),
    'caisse', 0, 'influence', 50,
    'localId', 'universite:salle_reunion',
    'visible', true,
    -- CE QUI DISTINGUE UN SYNDICAT ETUDIANT D'UN AUTRE SYNDICAT : sa domiciliation, et ce
    -- drapeau. Aucune prerogative n'y est attachee.
    'syndicat_etudiant', true,
    'domicilie_le_jour', v_jour,
    'frais_de_greffe', 150);

  INSERT INTO public.organisations (id, country_origine, data)
  VALUES (v_id, v_pays, v_blob::text);

  v_contenu := jsonb_build_object(
    'organisation', v_id, 'nom', v_nom, 'type', 'syndicale', 'syndicat_etudiant', true,
    'pays', v_pays, 'ville', v_ville,
    'domicile', 'universite:salle_reunion',
    'domicile_libelle', 'Salle de reunion de l''Universite',
    'president', v_moi, 'fondateur', v_moi,
    'constituee_le_jour', v_jour, 'frais_de_greffe', 150);

  v_doc := public.document_officiel_emettre(
    'domiciliation_extrait', 'domiciliation_extrait', true,
    v_pays, v_ville, NULL, v_id, NULL, v_moi, v_moi, v_jour,
    'Extrait de domiciliation — ' || v_nom,
    'Delivre par le greffe au jour ' || v_jour || ' a la constitution. Document FIGE : il dit la '
      || 'domiciliation telle qu''elle etait a cette date.',
    'ti-building-community', v_contenu,
    jsonb_build_object('motif', 'constitution'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'syndicat_etudiant_domicilier : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'organisation', v_id, 'nom', v_nom,
    'document', v_doc ->> 'document', 'jour', v_jour, 'ville', v_ville,
    'grade', v_grade, 'frais_de_greffe', 150);
END;
$function$;

-- tournee_cloturer(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tournee_cloturer(p_tournee_id text, p_servie boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  t public.tournees; v_moi text; v_credites integer := 0; v_supprimees integer := 0;
  v_n integer; r record;
BEGIN
  SELECT * INTO t FROM public.tournees WHERE id = p_tournee_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'tournee_introuvable'); END IF;

  -- SEUL L'OFFREUR CLOT SA TOURNEE (le serveur traverse : mon_personnage() rend NULL pour lui).
  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL AND v_moi IS DISTINCT FROM t.offreur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_offre');
  END IF;

  IF t.contrat='boire_v1' THEN RETURN public.tournee_cloturer_boire(p_tournee_id); END IF;

  -- LE COMPARE-AND-SWAP : seule une tournee revendiquee se clot, et une seule fois.
  IF t.statut <> 'en_resolution' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_resolution', 'statut', t.statut);
  END IF;

  IF coalesce(p_servie, false) THEN
    -- LE CREDIT DES INVITES, ENFIN APPLIQUE -- et dans la meme transaction que la cloture.
    -- Il vise la TABLE, pas la vue : c'est la vue qui refusait la fiche d'autrui.
    FOR r IN SELECT i.invite FROM public.invitations_diner i
              WHERE i.tournee_id = p_tournee_id AND i.statut = 'acceptee'
    LOOP
      UPDATE public.personnages_donnees d
         SET moral = least(100, coalesce(d.moral, 75) + 2),
             stats = CASE
               WHEN coalesce((d.stats ->> 'ENT')::numeric, 0) < 20
                 THEN jsonb_set(coalesce(d.stats, '{}'::jsonb), '{ENT}',
                        to_jsonb(least(20, coalesce((d.stats ->> 'ENT')::numeric, 0) + 1)), true)
               ELSE coalesce(d.stats, '{}'::jsonb) END
       WHERE d.name = r.invite;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_credites := v_credites + v_n;
    END LOOP;
  END IF;

  DELETE FROM public.invitations_diner WHERE tournee_id = p_tournee_id;
  GET DIAGNOSTICS v_supprimees = ROW_COUNT;

  UPDATE public.tournees
     SET statut = 'resolue',
         pa_debite = CASE WHEN coalesce(p_servie,false) THEN true ELSE coalesce(pa_debite,false) END
   WHERE id = p_tournee_id AND statut = 'en_resolution';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'tournee_cloturer : la cloture n''a pas pris sur %', p_tournee_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'servie', coalesce(p_servie,false),
    'credites', v_credites, 'invitations_supprimees', v_supprimees);
END; $function$;

-- universite_abandonner(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_abandonner(p_requete text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_id text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  UPDATE public.universite_inscriptions
     SET statut = 'abandonne', clos_le = now()
   WHERE personnage = v_moi AND statut = 'en_cours'
  RETURNING id INTO v_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  -- RIEN N'EST ECRIT DANS personnages_qualifications : le slot a vie reste disponible, et c'est
  -- la regle. Un abandon n'est pas un echec de qualification, c'est l'absence de qualification.
  RETURN jsonb_build_object('ok', true, 'inscription', v_id, 'statut', 'abandonne',
    'slot_consomme', public.universite_slot_consomme(v_moi));
END;
$function$;

-- universite_diplomer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_diplomer(p_requete text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_ins record; v_cur record; v_total integer; v_faits integer; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  IF now() > v_ins.limite_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_expire', 'limite_le', v_ins.limite_le);
  END IF;
  -- LA DUREE THEORIQUE EST UN MINIMUM, PAS UNE ESTIMATION.
  IF now() < v_ins.fin_theorique_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'duree_theorique_non_atteinte',
      'fin_theorique_le', v_ins.fin_theorique_le);
  END IF;

  SELECT count(*), count(a.jalon) INTO v_total, v_faits
    FROM public.universite_cursus_jalons j
    LEFT JOIN public.universite_jalons_accomplis a
           ON a.jalon = j.id AND a.inscription = v_ins.id
   WHERE j.cursus = v_ins.cursus;
  IF v_faits < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jalons_incomplets',
      'accomplis', v_faits, 'total', v_total);
  END IF;

  SELECT * INTO v_cur FROM public.universite_cursus WHERE id = v_ins.cursus;

  -- LE SLOT SE CONSOMME EN ECRIVANT LA CARRIERE, jamais en posant un drapeau. La CLE PRIMAIRE de
  -- `carrieres_acquises` est le personnage : deux appels simultanes ne peuvent pas en ecrire deux,
  -- et il n'existe aucune forme de la table ou une troisieme carriere tiendrait.
  INSERT INTO public.carrieres_acquises (personnage, carriere, source, inscription_id)
  VALUES (v_moi, v_cur.carriere, 'universite', v_ins.id)
  ON CONFLICT (personnage) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seconde_carriere_deja_acquise');
  END IF;

  UPDATE public.universite_inscriptions
     SET statut = 'diplome', clos_le = now()
   WHERE id = v_ins.id;

  RETURN jsonb_build_object('ok', true, 'inscription', v_ins.id,
    'carriere', v_cur.carriere, 'slot_consomme', true,
    'carrieres', to_jsonb(public.carrieres_de(v_moi)));
END;
$function$;

-- universite_expirer_echues() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_expirer_echues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_n integer;
BEGIN
  -- AU-DELA DE LA LIMITE, LE CURSUS EST ECHOUE ET LE SLOT RESTE DISPONIBLE. Rien n'est ecrit
  -- dans personnages_qualifications : c'est toute la difference avec un diplome.
  UPDATE public.universite_inscriptions
     SET statut = 'expire', clos_le = now()
   WHERE statut = 'en_cours' AND now() > limite_le;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'expires', v_n);
END;
$function$;

-- universite_inscrire(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_inscrire(p_cursus text, p_requete text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_cur record; v_id text; v_debut timestamptz := now(); v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NOT NULL AND p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  IF p_requete IS NOT NULL THEN
    SELECT id INTO v_id FROM public.universite_inscriptions WHERE requete = p_requete;
    IF v_id IS NOT NULL THEN
      RETURN jsonb_build_object('ok', true, 'rejeu', true, 'inscription', v_id);
    END IF;
  END IF;

  SELECT * INTO v_cur FROM public.universite_cursus WHERE id = p_cursus;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cursus_inconnu'); END IF;

  -- LE SLOT A VIE. Une seconde carriere deja acquise ferme definitivement la porte.
  IF public.universite_slot_consomme(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seconde_carriere_deja_acquise');
  END IF;

  -- ON NE DEPENSE PAS SON UNIQUE SLOT POUR CE QU'ON A DEJA. Ce n'est pas une punition : c'est le
  -- refus d'un gachis irreversible.
  IF public.carriere_possede(v_moi, v_cur.carriere) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_deja_detenue',
                              'carriere', v_cur.carriere);
  END IF;

  IF EXISTS (SELECT 1 FROM public.universite_inscriptions
              WHERE personnage = v_moi AND statut = 'en_cours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_deja_en_cours');
  END IF;

  v_id := 'ins-' || left(md5(v_moi || '|' || p_cursus || '|' || coalesce(p_requete, v_debut::text)), 20);

  INSERT INTO public.universite_inscriptions
    (id, personnage, cursus, semaines_theoriques, debut_le, fin_theorique_le, limite_le, statut, requete)
  VALUES (v_id, v_moi, p_cursus, v_cur.semaines_theoriques, v_debut,
          public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques),
          public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques * 2),
          'en_cours', p_requete)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inscription_deja_posee'); END IF;

  RETURN jsonb_build_object('ok', true, 'inscription', v_id, 'carriere', v_cur.carriere,
    'semaines_theoriques', v_cur.semaines_theoriques,
    'fin_theorique_le', public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques),
    'limite_le', public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques * 2));
END;
$function$;

-- universite_jalon_accomplir(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_jalon_accomplir(p_jalon text, p_requete text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_ins record; v_jal record; v_ouvre timestamptz; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NOT NULL AND p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  SELECT * INTO v_jal FROM public.universite_cursus_jalons WHERE id = p_jalon;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'jalon_inconnu'); END IF;
  IF v_jal.cursus <> v_ins.cursus THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jalon_hors_cursus');
  END IF;

  -- LE CURSUS EXPIRE N'ACCEPTE PLUS RIEN.
  IF now() > v_ins.limite_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_expire', 'limite_le', v_ins.limite_le);
  END IF;

  -- VOICI CE QUI REND LA DUREE INCOMPRESSIBLE, ET IL N'Y A RIEN D'AUTRE A AJOUTER. Un jalon de
  -- rang N s'ouvre N-1 semaines apres le debut du cursus. Aucune quantite de PA, aucune somme
  -- d'argent et aucune repetition ne peuvent avancer cette date : elle est derivee de
  -- `debut_le`, que seule l'inscription ecrit.
  v_ouvre := public.universite_plus_semaines(v_ins.debut_le, v_jal.rang - 1);
  IF now() < v_ouvre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'semaine_non_ouverte',
      'rang', v_jal.rang, 'ouvre_le', v_ouvre);
  END IF;

  INSERT INTO public.universite_jalons_accomplis (inscription, jalon, requete)
  VALUES (v_ins.id, p_jalon, p_requete)
  ON CONFLICT (inscription, jalon) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'jalon_deja_accompli');
  END IF;

  RETURN jsonb_build_object('ok', true, 'jalon', p_jalon, 'rang', v_jal.rang);
END;
$function$;

-- universite_mon_etat() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_mon_etat()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_ins record; v_jalons jsonb; v_total integer; v_faits integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'cursus_actif', NULL,
      'slot_consomme', public.universite_slot_consomme(v_moi),
      'carriere_initiale', public.carriere_initiale(v_moi),
      'carrieres', to_jsonb(public.carrieres_de(v_moi)),
      'seconde_carriere', (SELECT jsonb_build_object('carriere', a.carriere,
                                   'libelle', c.libelle, 'acquise_le', a.acquise_le)
                             FROM public.carrieres_acquises a
                             LEFT JOIN public.carrieres c ON c.id = a.carriere
                            WHERE a.personnage = v_moi),
      -- LES CURSUS QUI MENENT A UNE CARRIERE QU'ON A DEJA SONT ECARTES DE LA LISTE : l'ecran ne
      -- propose donc pas de depenser l'unique slot pour rien.
      'cursus_disponibles', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'id', u.id, 'libelle', u.libelle, 'carriere', u.carriere,
          'carriere_libelle', c.libelle,
          'semaines_theoriques', u.semaines_theoriques,
          'cout_pa', u.cout_pa, 'cout_fr', u.cout_fr) ORDER BY u.id), '[]'::jsonb)
        FROM public.universite_cursus u
        LEFT JOIN public.carrieres c ON c.id = u.carriere
        WHERE NOT public.carriere_possede(v_moi, u.carriere)));
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', j.id, 'rang', j.rang, 'libelle', j.libelle, 'genre', j.genre,
      'batiment', j.batiment, 'ville', j.ville, 'piece', j.piece,
      'ouvre_le', public.universite_plus_semaines(v_ins.debut_le, j.rang - 1),
      'ouvert', now() >= public.universite_plus_semaines(v_ins.debut_le, j.rang - 1),
      'accompli', (a.jalon IS NOT NULL),
      'accompli_le', a.accompli_le) ORDER BY j.rang, j.id), '[]'::jsonb),
    count(*), count(a.jalon)
    INTO v_jalons, v_total, v_faits
    FROM public.universite_cursus_jalons j
    LEFT JOIN public.universite_jalons_accomplis a
           ON a.jalon = j.id AND a.inscription = v_ins.id
   WHERE j.cursus = v_ins.cursus;

  RETURN jsonb_build_object('ok', true,
    'slot_consomme', public.universite_slot_consomme(v_moi),
    'carriere_initiale', public.carriere_initiale(v_moi),
    'carrieres', to_jsonb(public.carrieres_de(v_moi)),
    'cursus_actif', jsonb_build_object(
      'inscription', v_ins.id, 'cursus', v_ins.cursus,
      'carriere', (SELECT u.carriere FROM public.universite_cursus u WHERE u.id = v_ins.cursus),
      'semaines_theoriques', v_ins.semaines_theoriques,
      'debut_le', v_ins.debut_le, 'fin_theorique_le', v_ins.fin_theorique_le,
      'limite_le', v_ins.limite_le,
      'duree_atteinte', now() >= v_ins.fin_theorique_le,
      'expire', now() > v_ins.limite_le,
      'jalons_total', v_total, 'jalons_accomplis', v_faits,
      'diplomable', (v_faits = v_total AND now() >= v_ins.fin_theorique_le AND now() <= v_ins.limite_le),
      'jalons', v_jalons));
END;
$function$;

-- universite_plus_semaines(timestamp with time zone,integer) -> timestamp with time zone | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_plus_semaines(p_ts timestamp with time zone, p_semaines integer)
 RETURNS timestamp with time zone
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (((p_ts AT TIME ZONE 'Europe/Paris') + (p_semaines * interval '7 days')) AT TIME ZONE 'Europe/Paris');
$function$;

-- universite_prochaine_etape() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_prochaine_etape()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_moi text; v_ins record; v_j record; v_prev record; v_base timestamptz; v_due timestamptz; v_shift interval := interval '0 seconds'; v_plan timestamptz; v_prev_date timestamptz; v_prev_offset int := 0; v_offset int; v_i record;
begin
 v_moi:=public.mon_personnage();
 if v_moi is null then return jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); end if;
 select * into v_ins from public.universite_inscriptions where personnage=v_moi and statut='en_cours';
 if not found then return jsonb_build_object('ok',true,'etape',null); end if;
 -- Lundi de la semaine suivant l'inscription, 00h Paris.
 v_base := ((date_trunc('week',v_ins.debut_le at time zone 'Europe/Paris') + interval '7 days') at time zone 'Europe/Paris');
 for v_i in select j.*,a.accompli_le from public.universite_cursus_jalons j
 left join public.universite_jalons_accomplis a on a.jalon=j.id and a.inscription=v_ins.id
 where j.cursus=v_ins.cursus order by j.rang loop
   v_offset := ((v_i.rang-1)/3)*7; -- remplacé par grille explicite de 24 jalons
   v_offset := case when v_i.rang<=3 then (v_i.rang-1)*2
      else 7+((v_i.rang-4)/3)*7+
        case ((v_i.rang-4)%3) when 0 then 0 when 1 then 2 else 3 end end;
   v_plan:=v_base + make_interval(days=>v_offset)+v_shift;
   if v_prev_date is not null then
      v_plan:=greatest(v_plan,v_prev_date+make_interval(days=>v_offset-v_prev_offset));
   end if;
   if v_i.accompli_le is null then
      return jsonb_build_object('ok',true,'etape',jsonb_build_object(
       'id',v_i.id,'rang',v_i.rang,'libelle',v_i.libelle,'genre',v_i.genre,
       'batiment',v_i.batiment,'ville',v_i.ville,'piece',v_i.piece,
       'action',v_i.note,'ouvre_le',v_plan,'ouvert',now()>=v_plan,
       'pa',case when v_i.genre='universite' then 6 else 0 end));
   end if;
   v_shift:=v_shift+greatest(interval '0 seconds',v_i.accompli_le-v_plan);
   v_prev_date:=v_i.accompli_le;
   v_prev_offset:=v_offset;
 end loop;
 return jsonb_build_object('ok',true,'etape',null,'tous_accomplis',true);
end; $function$;

-- universite_slot_consomme(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_slot_consomme(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.carrieres_acquises a WHERE a.personnage = p_nom);
$function$;

-- universite_valider_etape(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.universite_valider_etape(p_jalon text, p_action text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_moi text;v_ins record;v_et jsonb;v_step jsonb;v_pos record;v_pa int;v_n int;
begin
 v_moi:=public.mon_personnage();
 if v_moi is null then return jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); end if;
 select * into v_ins from public.universite_inscriptions where personnage=v_moi and statut='en_cours' for update;
 if not found then return jsonb_build_object('ok',false,'raison','aucun_cursus_en_cours'); end if;
 if now()>v_ins.limite_le then return jsonb_build_object('ok',false,'raison','cursus_expire'); end if;
 v_et:=public.universite_prochaine_etape();v_step:=v_et->'etape';
 if v_step is null or v_step='null'::jsonb then return jsonb_build_object('ok',false,'raison','parcours_termine'); end if;
 if v_step->>'id'<>p_jalon then return jsonb_build_object('ok',false,'raison','etape_non_courante'); end if;
 if not (v_step->>'ouvert')::boolean then return jsonb_build_object('ok',false,'raison','etape_non_ouverte','ouvre_le',v_step->>'ouvre_le'); end if;
 select current_city,current_building,current_room,pa into v_pos from public.personnages_donnees where name=v_moi for update;
 if not found then return jsonb_build_object('ok',false,'raison','personnage_introuvable'); end if;
 if v_pos.current_city is distinct from v_step->>'ville'
   or v_pos.current_building is distinct from v_step->>'batiment'
   or (v_step->>'piece' is not null and v_pos.current_room is distinct from v_step->>'piece') then
    return jsonb_build_object('ok',false,'raison','lieu_incorrect','ville',v_step->>'ville','batiment',v_step->>'batiment','piece',v_step->>'piece');
 end if;
 if v_step->>'genre'='terrain' and p_action is distinct from v_step->>'action' then
   return jsonb_build_object('ok',false,'raison','objectif_non_valide');end if;
 if v_pos.pa<(v_step->>'pa')::int then return jsonb_build_object('ok',false,'raison','pa_insuffisants','pa_reel',v_pos.pa); end if;
 update public.personnages_donnees set pa=pa-(v_step->>'pa')::int where name=v_moi;
 insert into public.universite_jalons_accomplis(inscription,jalon) values(v_ins.id,p_jalon)
 on conflict(inscription,jalon) do nothing;
 get diagnostics v_n=row_count;
 if v_n<>1 then raise exception 'etape deja validee concurrente'; end if;
 return jsonb_build_object('ok',true,'jalon',p_jalon,'pa_preleves',(v_step->>'pa')::int);
end; $function$;
