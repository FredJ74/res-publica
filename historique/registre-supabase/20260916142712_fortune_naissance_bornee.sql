-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916142712
-- Nom original      : fortune_naissance_bornee
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 14:27:12 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8ca29df30bde7cb17e55aa8077960d5d
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
-- ON NE NAIT PLUS RICHE (16 septembre 2026).
--
-- Un personnage pouvait etre cree avec la fortune de son choix : arg = 999999, liquide = 888888,
-- banque = 777777 sont acceptes tels quels aujourd'hui (verifie). C'est la meme faille que les
-- PA avant leur verrou, sur la ressource la plus sensible du jeu.
--
-- La dotation de depart n'est pas une constante : elle vaut origine + ecole + archetype +
-- carriere (creation.js, totalArg). Le serveur ne borne donc pas a une valeur fixe, mais au
-- MAXIMUM ATTEIGNABLE en combinant les meilleurs choix de chaque table -- 2200 + 400 + 1200 +
-- 1200 = 5000, mesure sur le vrai data.js par JavaScriptCore. Aucune creation legitime n'est
-- donc genee : la plus genereuse des combinaisons passe exactement.
--
-- liquide et banque sont des SOUS-ENSEMBLES de la fortune (15 % / 85 % a la creation) : on les
-- borne a arg, ce qui suffit a interdire la fabrication d'argent sans figer la repartition.
--
-- CE LOT NE FERME QUE LA NAISSANCE. Les ecritures de fortune EN COURS DE PARTIE restent ouvertes :
-- 16 appels a crediterFondsOrdinaires et 26 hausses directes de state.arg/state.liquide vivent
-- encore dans le client et doivent d'abord etre raccordees a des primitives serveur -- sans quoi
-- fermer l'UPDATE casserait des gains legitimes. Le recensement est au rapport ; le banc
-- .scratch/banc_arg_autorite.py mesure precisement ce qui reste ouvert.

CREATE OR REPLACE FUNCTION public.personnages_vue_inserer()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'creation_sans_compte' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
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
END; $$;