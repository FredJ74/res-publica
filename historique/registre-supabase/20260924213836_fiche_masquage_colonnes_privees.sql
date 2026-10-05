-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924213836
-- Nom original      : fiche_masquage_colonnes_privees
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 21:38:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1427abfe89dc2335d2e6dec502d3dd0f
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
-- LA FICHE CESSE D'ETRE PUBLIQUE SUR SEPT COLONNES (24 septembre 2026, chantier securite).
-- La vue ne masquait que arg/liquide/banque/inventory ; tout le reste etait lisible par
-- n'importe qui, jeton ou non : journal intime, casier, enquetes, contacts, informateurs,
-- reputation criminelle, placement au QHS.
--
-- `recherche` N'EST PAS MASQUEE, deliberement : un avis de recherche est public par nature, et
-- plateau-justice-economie.js:10803 le lit legitimement SUR AUTRUI (controle de police).
-- `est_emprisonne` non plus : le public peut savoir qu'un personnage est detenu -- c'est le QHS,
-- et lui seul, qui reste secret, pendant comme apres.
--
-- Aucune donnee detruite : le masquage est un CASE a la lecture. Proprietaire et appels serveur
-- (est_appel_serveur) voient tout, comme pour l'argent. Les archives internes du QHS restent
-- intactes cote serveur. Verifie avant d'agir : aucun appel client ne lit ces colonnes sur un
-- AUTRE personnage ; seul le cron (service_role) lit journal et detention_qhs.
--
-- CREATE OR REPLACE conserve triggers INSTEAD OF et GRANT : liste et ordre des colonnes
-- strictement inchanges, seules sept expressions le sont.
CREATE OR REPLACE VIEW public.personnages AS
 SELECT id, name, country, photo_url, bio, archetype, career, origin, school,
    free_pts_restants, stats, resources,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN arg ELSE NULL::integer END AS arg,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN liquide ELSE NULL::integer END AS liquide,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN banque ELSE NULL::integer END AS banque,
    hp, pa, moral, poste, poste_depute, current_city, current_building, current_room,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN inventory ELSE NULL::jsonb END AS inventory,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN informateurs ELSE NULL::jsonb END AS informateurs,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN contacts ELSE NULL::jsonb END AS contacts,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN historique_crimes ELSE NULL::jsonb END AS historique_crimes,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN enquetes_en_cours ELSE NULL::jsonb END AS enquetes_en_cours,
    domicile, employes, escort_active, locations_actives, poison_actif, day,
    recherche,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN reputation_criminelle ELSE NULL::integer END AS reputation_criminelle,
    salutations_du_jour, invitation_sociale_en_attente, convocations, est_emprisonne,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN detention_qhs ELSE NULL::jsonb END AS detention_qhs,
    hospitalisation, stats_affaiblies, regen_jour, requisition, demandeur_emploi,
    carte_postale_moral_jour, motto, licence_sportive, performance_sportive, blessure_sportive,
    signature_html, signature_blocks, quete_accueil, enigme1, maxence, succes_maxence,
    CASE WHEN user_id = auth.uid() OR est_appel_serveur() THEN journal ELSE NULL::jsonb END AS journal,
    excommunie, reservation_hotel, qualifications, effets_actifs, bonus_lobbyiste,
    dernier_dormir, salaire_touche, dernier_objet_trouve_jour, photo_pos, user_id,
    created_at, updated_at, quete_carriere
   FROM personnages_donnees d;