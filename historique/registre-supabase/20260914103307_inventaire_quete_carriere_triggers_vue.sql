-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914103307
-- Nom original      : inventaire_quete_carriere_triggers_vue
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:33:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 67518091ce2435bdc7b8a2d616290afa
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
-- Les deux triggers INSTEAD OF de la vue doivent porter la nouvelle colonne, sinon elle serait
-- exposee en lecture mais jamais ecrite -- exactement le defaut qu'on corrige.
CREATE OR REPLACE FUNCTION public.personnages_vue_inserer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'creation_sans_compte' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
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

CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := OLD.user_id;   -- un personnage ne change pas de proprietaire
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
END; $function$;
