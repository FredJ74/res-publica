-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914103234
-- Nom original      : inventaire_quete_carriere_persistee
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:32:34 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 16c0f8537c02433693e2b788d10e7273
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
-- PREREQUIS de l'entonnoir de sortie d'inventaire : state.char.queteCarriere, dont depend
-- toute la protection du colis secret (colisSecretProtege), n'etait ecrit dans AUCUNE colonne.
-- Il ne survivait que par localStorage -- la meme dependance au cache local qui a produit le
-- bug du personnage fantome. Le serveur etait donc structurellement incapable d'evaluer la
-- protection, et la quete de carriere etait perdue au changement de navigateur.
ALTER TABLE public.personnages_donnees
  ADD COLUMN IF NOT EXISTS quete_carriere jsonb;

-- La vue expose la colonne SANS masquage, comme les autres etats de quete (quete_accueil,
-- enigme1, maxence) : ce n'est ni de l'argent ni un inventaire.
CREATE OR REPLACE VIEW public.personnages AS
 SELECT id, name, country, photo_url, bio, archetype, career, origin, school,
    free_pts_restants, stats, resources,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN arg ELSE NULL::integer END AS arg,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN liquide ELSE NULL::integer END AS liquide,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN banque ELSE NULL::integer END AS banque,
    hp, pa, moral, poste, poste_depute, current_city, current_building, current_room,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN inventory ELSE NULL::jsonb END AS inventory,
    informateurs, contacts, historique_crimes, enquetes_en_cours, domicile, employes,
    escort_active, locations_actives, poison_actif, day, recherche, reputation_criminelle,
    salutations_du_jour, invitation_sociale_en_attente, convocations, est_emprisonne,
    detention_qhs, hospitalisation, stats_affaiblies, regen_jour, requisition, demandeur_emploi,
    carte_postale_moral_jour, motto, licence_sportive, performance_sportive, blessure_sportive,
    signature_html, signature_blocks, quete_accueil, enigme1, maxence, succes_maxence, journal,
    excommunie, reservation_hotel, qualifications, effets_actifs, bonus_lobbyiste,
    dernier_dormir, salaire_touche, dernier_objet_trouve_jour, photo_pos, user_id,
    created_at, updated_at,
    quete_carriere
   FROM personnages_donnees d;
