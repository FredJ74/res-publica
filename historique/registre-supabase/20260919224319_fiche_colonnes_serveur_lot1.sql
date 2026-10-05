-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919224319
-- Nom original      : fiche_colonnes_serveur_lot1
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 22:43:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e1a7dcd159bb16c3a4cc4d2814717045
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- LOT P0-A / INCREMENT 1 — LA FICHE CESSE D'ETRE ECRITE PAR LE NAVIGATEUR
-- =====================================================================
-- CE QUE CE LOT FERME, ET POURQUOI CES COLONNES-LA.
-- L'audit a demontre qu'un joueur, par le chemin NORMAL du client (sa propre
-- fiche, son propre JWT), pouvait ecrire stats=99, banque=5 000 000,
-- free_pts_restants=999, qualifications=[...]. Mesure prealable dans le depot :
-- ces quatre colonnes ont ZERO ecriture cliente legitime hors creation.js
--   state.stats           0 ecriture      state.freePts          0
--   state.qualifications  0 ecriture      state.banque           0
-- Elles sont donc epinglees a OLD : aucun parcours existant ne peut casser.
-- Les colonnes a fort trafic client (arg, liquide, hp, moral, resources, day,
-- inventory, position) NE SONT PAS epinglees ici : elles ont des dizaines de
-- chemins legitimes qu'il faut d'abord router vers le serveur. Les fermer
-- maintenant casserait le jeu en silence -- exactement ce que la consigne
-- interdit. Elles sont mises SOUS OBSERVATION (voir plus bas).
--
-- LA CREATION N'EST PAS CONCERNEE : seul le declencheur UPDATE est touche,
-- personnages_vue_inserer garde son plafonnement d'origine.

-- ---------------------------------------------------------------- observation
-- Meme doctrine que ordres_couts_ecarts : on MESURE avant de fermer. Chaque
-- hausse d'argent venue du navigateur est enregistree sans etre bloquee. Le
-- lot suivant migrera les sources reellement listees ici, pas celles qu'on
-- aurait devinees.
CREATE TABLE IF NOT EXISTS public.fiche_hausses_observees (
  id            bigserial PRIMARY KEY,
  personnage    text        NOT NULL,
  colonne       text        NOT NULL,
  ancienne      numeric,
  nouvelle      numeric,
  delta         numeric,
  role_sql      text,
  requete       text,
  vu_le         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fiche_hausses_observees_colonne_idx
  ON public.fiche_hausses_observees (colonne, vu_le DESC);

-- Les DEFAULT PRIVILEGES du schema public accordent arwdDxtm a anon sur tout
-- objet cree : sans ce REVOKE explicite, la table de mesure serait elle-meme
-- ouverte en ecriture.
ALTER TABLE public.fiche_hausses_observees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fiche_hausses_observees FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.fiche_hausses_observees_id_seq FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------- declencheur de la vue
CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_role text := coalesce(nullif(current_setting('role', true), ''), session_user);
  v_req  text := left(coalesce(current_query(), ''), 500);
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := OLD.user_id;   -- un personnage ne change pas de proprietaire

    -- LES PA NE S'AUGMENTENT PAS DEPUIS LE NAVIGATEUR (16 septembre 2026).
    IF coalesce(NEW.pa, 0) > coalesce(OLD.pa, 0) THEN
      NEW.pa := OLD.pa;
    END IF;

    -- EPINGLAGE (lot P0-A). Quatre colonnes sans aucun chemin client legitime.
    -- Une baisse comme une hausse sont refusees : ces valeurs ne se decident
    -- pas dans le navigateur, dans un sens comme dans l'autre.
    NEW.stats             := OLD.stats;
    NEW.free_pts_restants := OLD.free_pts_restants;
    NEW.qualifications    := OLD.qualifications;
    NEW.banque            := OLD.banque;

    -- OBSERVATION (ne bloque pas encore). On ne consigne que les HAUSSES :
    -- une baisse d'argent est au pire une perte pour le joueur, jamais un
    -- exploit. Le champ requete permet de remonter au site d'appel.
    IF coalesce(NEW.arg, 0) > coalesce(OLD.arg, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (OLD.name, 'arg', OLD.arg, NEW.arg, coalesce(NEW.arg,0) - coalesce(OLD.arg,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.liquide, 0) > coalesce(OLD.liquide, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (OLD.name, 'liquide', OLD.liquide, NEW.liquide, coalesce(NEW.liquide,0) - coalesce(OLD.liquide,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.hp, 0) > coalesce(OLD.hp, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (OLD.name, 'hp', OLD.hp, NEW.hp, coalesce(NEW.hp,0) - coalesce(OLD.hp,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.day, 0) > coalesce(OLD.day, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (OLD.name, 'day', OLD.day, NEW.day, coalesce(NEW.day,0) - coalesce(OLD.day,0), v_role, v_req);
    END IF;
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
$fn$;

-- --------------------------------------------- POP / INF : la base devient obligatoire
-- Ce declencheur implemente deja un protocole de DELTA : le client annonce la
-- valeur qu'il croyait (popBase) et la nouvelle ; le serveur applique
-- old + (new - base). C'est ce qui protege contre l'ecrasement par un onglet
-- en retard. Mais quand le client OMET la base, la valeur brute passait telle
-- quelle -- c'est par la que le banc d'audit a pose pop=100.
-- Desormais : pas de base transmise = la valeur serveur est conservee.
CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_base numeric;
  v_old  numeric;
  v_client boolean := NOT public.est_appel_serveur();
BEGIN
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'popBase') = 'number' THEN (NEW.resources ->> 'popBase')::numeric END;
    NEW.resources := NEW.resources - 'popBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'pop') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{pop}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'pop')::numeric - v_base)))));
    END IF;
  ELSIF TG_OP = 'UPDATE' AND v_client AND jsonb_typeof(NEW.resources) = 'object' THEN
    -- Pas de base annoncee : le navigateur ne decide pas d'une valeur absolue.
    IF jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN
      NEW.resources := jsonb_set(NEW.resources, '{pop}', OLD.resources -> 'pop');
    ELSE
      NEW.resources := NEW.resources - 'pop';
    END IF;
  END IF;

  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'infBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'infBase') = 'number' THEN (NEW.resources ->> 'infBase')::numeric END;
    NEW.resources := NEW.resources - 'infBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'inf') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN (OLD.resources ->> 'inf')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{inf}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'inf')::numeric - v_base)))));
    END IF;
  ELSIF TG_OP = 'UPDATE' AND v_client AND jsonb_typeof(NEW.resources) = 'object' THEN
    IF jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN
      NEW.resources := jsonb_set(NEW.resources, '{inf}', OLD.resources -> 'inf');
    ELSE
      NEW.resources := NEW.resources - 'inf';
    END IF;
  END IF;

  RETURN NEW;
END;
$fn$;