-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927171042
-- Nom original      : socle_pnj_renseignement_chantier_restant_documente
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 17:10:42 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4f601054049f4e05db9cf818ef263047
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
-- CHECKPOINT F (§8) — LE RENSEIGNEMENT RESTE INTACT, ET LE CHANTIER EST CHIFFRE
--
-- AUDIT FAIT, VERDICT : la convergence de cette famille exige une refonte, elle n'est pas une
-- bascule d'axe. 24 fonctions du schema touchent `agents_renseignement`, dont TREIZE ecrivent ou
-- lisent sa position et son leader_courant :
--   actions joueur vivantes  : agent_prendre, agent_deposer, agent_transferer
--   lectures de presence     : agents_couverture_ici, agents_renseignement_ici,
--                              agents_de_mon_groupe, agents_couverture_de_mon_groupe,
--                              agent_position_effective, cellule_renseignement_mes_cellules
--   observation par role     : agent_garde_observer, agent_traducteur_ecouter,
--                              agent_conseillere_observer, agent_coordinateur_port,
--                              agent_coordinateur_multimodal
--   cron et cycle de vie     : cellules_renseignement_collecter, cellules_renseignement_balayer,
--                              cellule_renseignement_clore
--   CYCLE CARCERAL           : detention_ouvrir_interne, detention_cible_pnj,
--                              detentions_pnj_liberer_echues  (un agent se fait DETENIR)
--   contre-espionnage        : contre_espionnage_resoudre, contre_espionnage_approfondir
--
-- Basculer l'axe position_leader vers le socle obligerait donc a reecrire treize fonctions, dont
-- trois actions de joueur en production et le chemin de detention. Le mandat l'interdit
-- explicitement : ne pas refondre pour pouvoir declarer le chantier termine.
--
-- CE QUI A ETE FAIT MALGRE TOUT, et qui est sans risque : la famille est DECLAREE (classe beta),
-- ses axes disent ou vit son autorite, et la regle de mouvement individuel dit vrai -- un agent se
-- porte, se depose et se transfere reellement a un autre joueur, sans son accord.
--
-- CE QUI RESTE, PRECISEMENT. Par ordre de dependance :
--   1. les 12 agents n'ont AUCUN profil de caracteristiques arbitre. Ils portent une seule valeur,
--      DUP, fixee par role (garde 10, coordinateur 12, conseillere 13, traducteur 15). Les cinq
--      autres manquent. Aucun profil `agent` n'a ete valide : il ne faut pas l'inventer.
--   2. `agents_renseignement` porte deja position, leader_courant et detention_id : ce sont les
--      memes axes que le socle, reimplementes en parallele. Une convergence honnete remplacerait
--      ces colonnes par pnj_membres, elle ne les doublerait pas -- un miroir creerait ici la
--      duplication meme que l'architecture combat.
--   3. le cycle carceral des PNJ devrait alors passer par le socle (statut 'detenu' y existe deja).
--   4. l'identite de COUVERTURE est propre a cette famille : un agent porte un vrai nom et un nom
--      de couverture, et le client ne recoit jamais le vrai. Le socle n'a aucune notion d'identite
--      double, et lui en donner une est une decision d'architecture, pas un raccordement.
UPDATE public.pnj_familles_classes
   SET note = 'Agent de renseignement. Famille 100 % SERVEUR et PLEINEMENT ACTIVE : 12 agents, '
           || '3 cellules, convoques par quatre par le Ministre de la Defense (3 PA du ministre + '
           || '500 FR sur la caisse min_def). Aucun PA d''agent, aucun salaire recurrent : une '
           || 'echeance a J+10 balayee par le cron. '
           || 'NON CONVERGEE, VOLONTAIREMENT : 24 fonctions touchent agents_renseignement, dont 13 '
           || 'ecrivent sa position ou son leader_courant, plus le cycle carceral et le '
           || 'contre-espionnage. C''est une refonte, pas une bascule d''axe. '
           || 'BLOQUANTS : (a) aucun profil de caracteristiques arbitre -- seule DUP existe, fixee '
           || 'par role (garde 10, coordinateur 12, conseillere 13, traducteur 15) ; (b) sa table '
           || 'porte deja position/leader/detention, donc un miroir creerait la duplication que '
           || 'l''architecture combat ; (c) l''identite de COUVERTURE, propre a cette famille, n''a '
           || 'aucun equivalent au socle.'
 WHERE famille = 'agent';

UPDATE public.pnj_axes_autorite
   SET note = 'Magasin historique : agents_renseignement, qui porte deja position, leader_courant et '
           || 'detention_id. 13 fonctions les ecrivent ou les lisent. Basculer cet axe est une '
           || 'refonte : voir la note de pnj_familles_classes pour la liste et les trois bloquants.'
 WHERE famille = 'agent';