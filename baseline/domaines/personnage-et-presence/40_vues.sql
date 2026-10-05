-- Vues
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 40 : vues
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- Vue personnages | reloptions = AUCUNE
-- ATTENTION : ne JAMAIS ajouter security_invoker. Son absence est ce qui
-- fait tenir le masquage des colonnes privees.
CREATE OR REPLACE VIEW public.personnages AS
 SELECT id,
    name,
    country,
    photo_url,
    bio,
    archetype,
    career,
    origin,
    school,
    free_pts_restants,
    stats,
    resources,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN arg
            ELSE NULL::integer
        END AS arg,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN liquide
            ELSE NULL::integer
        END AS liquide,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN banque
            ELSE NULL::integer
        END AS banque,
    hp,
    pa,
    moral,
    poste,
    poste_depute,
    current_city,
    current_building,
    current_room,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN inventory
            ELSE NULL::jsonb
        END AS inventory,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN informateurs
            ELSE NULL::jsonb
        END AS informateurs,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN contacts
            ELSE NULL::jsonb
        END AS contacts,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN historique_crimes
            ELSE NULL::jsonb
        END AS historique_crimes,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN enquetes_en_cours
            ELSE NULL::jsonb
        END AS enquetes_en_cours,
    domicile,
    employes,
    escort_active,
    locations_actives,
    poison_actif,
    day,
    recherche,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN reputation_criminelle
            ELSE NULL::integer
        END AS reputation_criminelle,
    salutations_du_jour,
    invitation_sociale_en_attente,
    convocations,
    est_emprisonne,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN detention_qhs
            ELSE NULL::jsonb
        END AS detention_qhs,
    hospitalisation,
    stats_affaiblies,
    regen_jour,
    requisition,
    demandeur_emploi,
    carte_postale_moral_jour,
    motto,
    licence_sportive,
    performance_sportive,
    blessure_sportive,
    signature_html,
    signature_blocks,
    quete_accueil,
    enigme1,
    maxence,
    succes_maxence,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN journal
            ELSE NULL::jsonb
        END AS journal,
    excommunie,
    reservation_hotel,
    qualifications,
    effets_actifs,
    bonus_lobbyiste,
    dernier_dormir,
    salaire_touche,
    dernier_objet_trouve_jour,
    photo_pos,
    user_id,
    created_at,
    updated_at,
    quete_carriere
   FROM personnages_donnees d;
