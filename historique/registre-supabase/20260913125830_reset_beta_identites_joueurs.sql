-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913125830
-- Nom original      : reset_beta_identites_joueurs
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 12:58:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 721d36c0166912cf065014d7f965752b
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
-- ============================================================================
-- REINITIALISATION DE LA BETA — IDENTITES ET DONNEES DE JOUEURS
-- 13 septembre 2026, 12:57 UTC. Feu vert donne, beta-testeurs prevenus.
-- Sauvegarde integrale prealable : schema sauvegarde_beta_20260913 (119/119
-- tables, restauration prouvee a l'identique sur personnages).
-- ============================================================================
-- PRINCIPE APPLIQUE, LIGNE PAR LIGNE :
--   * ce qui n'existe QUE parce qu'un joueur l'a fait  -> supprime ;
--   * ce qui est structurel mais REFERENCE un joueur   -> conserve, reference videe ;
--   * ce qui est structurel et independant des joueurs -> intact.
-- Les 15 personnages disparaissent ; la Republia batie reste debout.

-- --- 1) Donnees entierement produites par les joueurs -----------------------
DELETE FROM public.actions_tracables;
DELETE FROM public.calomnies_actes;
DELETE FROM public.candidatures;
DELETE FROM public.chat_piece;
DELETE FROM public.contenu_caisses_fret;
DELETE FROM public.caisses_fret;
DELETE FROM public.comptes_bancaires;
DELETE FROM public.contributions_piete;
DELETE FROM public.corruptions_presse;
DELETE FROM public.demandes_grace;
DELETE FROM public.demandes_manifestation;
DELETE FROM public.demandes_mariage;
DELETE FROM public.demandes_naturalisation;
DELETE FROM public.detentions;
DELETE FROM public.dons_en_attente;
DELETE FROM public.dossiers_urbanisme;
DELETE FROM public.elections_tracts_pnj;
DELETE FROM public.engagements_militaires;
DELETE FROM public.escort_evenements_commerciaux;
DELETE FROM public.etat_civil_deces;
DELETE FROM public.etat_civil_naissances;
DELETE FROM public.evenements_globaux;
DELETE FROM public.forum_posts;
DELETE FROM public.forum_topics;
DELETE FROM public.fraudes_electorales;
DELETE FROM public.fuites_journalistiques;
DELETE FROM public.historique_deplacements;
DELETE FROM public.impacts_indices_attente;
DELETE FROM public.interviews_jodie;
DELETE FROM public.invitations_diner;
DELETE FROM public.investissements;
DELETE FROM public.journal_articles_en_attente;
DELETE FROM public.jugements;
DELETE FROM public.lectures_chat;
DELETE FROM public.locations_archives;
DELETE FROM public.locations_actives;
DELETE FROM public.logements_attributions_historique;
DELETE FROM public.logements_demandes;
DELETE FROM public.mails;
DELETE FROM public.mandats_maires_archives;
DELETE FROM public.mariages;
DELETE FROM public.messages_chat;
DELETE FROM public.militants_recrutes;
DELETE FROM public.nominations_poste_attente;
DELETE FROM public.objets_abandonnes;
DELETE FROM public.objets_recus;
DELETE FROM public.oeuvres;
DELETE FROM public.offres;
DELETE FROM public.organisations;
DELETE FROM public.paris_sportifs;
DELETE FROM public.petites_annonces;
DELETE FROM public.placements_bancaires;
DELETE FROM public.plaintes_en_cours;
DELETE FROM public.presences;
DELETE FROM public.presidents_clubs;
DELETE FROM public.prets;
DELETE FROM public.prets_bancaires;
DELETE FROM public.prisonniers_qhs;
DELETE FROM public.quetes_actives;
DELETE FROM public.rapports_renseignement;
DELETE FROM public.registre_ventes_armes;
DELETE FROM public.renseignements_connus;
DELETE FROM public.reservations_salle_reception;
DELETE FROM public.retraits_materiel_militaire;
DELETE FROM public.rumeurs_actives;
DELETE FROM public.salons_membres;
DELETE FROM public.salons_chat;
DELETE FROM public.scandales_presse;
DELETE FROM public.scandales_tentatives;
DELETE FROM public.souvenirs_accueil;
DELETE FROM public.successions;
DELETE FROM public.terrains_historique_ventes;
DELETE FROM public.testaments;
DELETE FROM public.tournees;
DELETE FROM public.transferts_clubs;
DELETE FROM public.tribune_articles_etouffes;
DELETE FROM public.votes_confiance_bulletins;
DELETE FROM public.votes_confiance;
DELETE FROM public.votes_electoraux;
DELETE FROM public.vols_en_attente;
DELETE FROM public.compromis_historique;
DELETE FROM public.biens_saisis_helvetia;
DELETE FROM public.obligations_helvetia;
DELETE FROM public.bnr_refinancements_helvetia;
-- Titulaires PNJ : remis a zero pour que le cron reattribue proprement les
-- postes laisses vacants par la disparition des PJ (Arnie etait President,
-- Vince Major Kubrick ministre de la Defense).
DELETE FROM public.titulaires_pnj;

-- --- 2) Structures conservees, references de joueur videes ------------------
-- Les terrains restent, avec leurs batiments, leur surface et leur valeur :
-- seuls proprietaire, coproprietaire, locataire et l'etat de chantier lie a un
-- PJ sont effaces. Un terrain sans proprietaire redevient achetable.
UPDATE public.terrains_etat
SET data = (
  (data::jsonb)
    - 'proprietaire' - 'coproprietaire' - 'locataire' - 'compromis' - 'compromisPar'
    - 'acompte' - 'compromisAt' - 'compromisExpireAt' - 'pretDemande'
    - 'chantier' - 'chantierReamenagement' - 'permis' - 'dette_fonciere'
)::text,
    updated_at = now()
WHERE data::jsonb ?| array['proprietaire','coproprietaire','locataire','compromis','chantier','chantierReamenagement','permis'];

-- Les entreprises restent en place, rendues aux PNJ.
UPDATE public.entreprises
SET data = (data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt'
                 - 'compromisExpireAt' - 'pretDemande')
           || jsonb_build_object('proprietaire', 'PNJ'),
    updated_at = now()
WHERE data ? 'proprietaire' OR data ? 'compromis';

-- Le calendrier electoral survit : on ne retire que les candidats et les voix
-- des PJ disparus, jamais le cycle lui-meme -- sans quoi plus aucune election
-- ne se tiendrait.
UPDATE public.cycles_electoraux
SET data = jsonb_set(
             jsonb_set(
               jsonb_set((data::jsonb), '{candidats}', '[]'::jsonb, true),
               '{votes}', '{}'::jsonb, true),
             '{votesPNJ}', '{}'::jsonb, true)::text,
    updated_at = now();

-- --- 3) Les personnages, puis les comptes -----------------------------------
DELETE FROM public.personnages;
DELETE FROM auth.users;

-- --- 4) Etat final du lien : un personnage a TOUJOURS un proprietaire -------
-- Possible seulement maintenant : plus aucune ligne heritee sans compte.
ALTER TABLE public.personnages ALTER COLUMN user_id SET NOT NULL;

-- --- 5) Fin du mecanisme transitoire ----------------------------------------
-- rattacher_personnage n'existait que pour adopter les personnages d'avant
-- l'authentification. Il n'en reste aucun, et la fonction deviendrait une porte
-- ouverte : tout personnage a desormais un proprietaire des sa creation.
DROP FUNCTION IF EXISTS public.rattacher_personnage(text);