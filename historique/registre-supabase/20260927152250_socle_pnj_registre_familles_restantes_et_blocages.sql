-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927152250
-- Nom original      : socle_pnj_registre_familles_restantes_et_blocages
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 15:22:50 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e91cf36947b5d0bfb094348c0cf32475
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
-- CHECKPOINT B/C — LES FAMILLES RESTANTES SONT DECLAREES, AVEC LEUR BLOCAGE MOTIVE
--
-- Cartographie etablie par lecture du code, pas par supposition. Trois enseignements ont change la
-- forme de ce registre :
--
-- 1. ESCORT, INFORMATEUR et CODETENU NE SONT PAS DES FAMILLES. Ce sont des METIERS de la famille
--    `employe` : ils vivent tous dans `state.employes` avec un champ `job`, et la table socle
--    `pnj_employes_metier` porte deja ce `job`. L'architecture SOCLE -> CLASSE -> METIER les place
--    donc au niveau metier, et il n'y a pas trois familles a migrer mais une.
--
-- 2. L'AGENT DE RENSEIGNEMENT EST LA FAMILLE LA PLUS AVANCEE DU JEU HORS SOCLE, et elle est
--    PLEINEMENT ACTIVE : 12 agents, 3 cellules, 100 % serveur, avec sa propre position
--    (pays/ville/building_id/room_id), son propre leader (`leader_courant`), son propre transfert
--    entre joueurs, son propre cron. C'est-a-dire exactement les axes que `pnj_axes_autorite` gere
--    -- reimplementes en parallele. Converger cette famille n'est donc PAS une petite bascule :
--    c'est deplacer 33 fonctions, un cron, le contre-espionnage et la detention. C'est une refonte,
--    explicitement hors mandat. Je la declare et je m'arrete la.
--
-- 3. AUCUNE DE CES FAMILLES N'A SES SIX CARACTERISTIQUES, et les valeurs existantes sont souvent
--    TIREES AU HASARD a l'embauche. Les figer demanderait de decider si l'aleatoire disparait :
--    c'est du game design. Je n'invente rien.
--
-- CES DECLARATIONS NE CREENT AUCUNE DONNEE ET NE DEBLOQUENT RIEN. Elles rendent l'etat verifiable
-- en base, et arment les gardes generiques par avance : l'axe etant 'blob', aucune primitive du
-- socle ne peut ecrire ces familles, meme si quelqu'un les y inscrivait demain.
INSERT INTO public.pnj_familles_classes (famille, classe, note) VALUES
  ('employe', 'beta',
   'Famille employable du joueur. METIERS attestes dans le champ job : escort, informateur, '
   || 'codetenu, plus le job generique. Stockage : state.employes, persiste dans '
   || 'personnages_donnees.employes -- donc COTE CLIENT. Salaire preleve PAR LE NAVIGATEUR a '
   || 'l''ordre Dormir (payerEmployes / payerEscorts), sans cron ni RPC. Coquille socle prete et '
   || 'vide : pnj_employes_metier. AUCUN PA nulle part, ce qui est coherent avec Beta. '
   || 'BLOQUEE : (a) le recrutement generique est mure volontairement -- confirmerPnjRecrut sort '
   || 'sur "Temporairement indisponible" et tout le code dessous est mort ; (b) les '
   || 'caracteristiques sont TIREES AU HASARD a l''embauche (escort CHA 12-18, DUP 10-16, '
   || 'INT 8-14 ; informateur PER 12-18 ; codetenu FOR et DUP 8-12) et VOL, PER, ENT manquent -- '
   || 'les figer est un arbitrage ; (c) le metier codetenu est MORT-NE, aucun PNJ du jeu ne porte '
   || 'job=codetenu ; (d) deplacer le salaire au serveur changerait des consequences reelles '
   || '(plainte au tribunal, -20 POP, article de presse) : mecanique existante, hors mandat.'),
  ('militant', 'beta',
   'Militant recrute par un membre d''une organisation syndicale, 2 PA du JOUEUR, gratuit a vie '
   || '(aucun salaire, ni navigateur ni cron). Stockage double : table militants_recrutes ET '
   || 'organisations.membres[]. Coquille socle prete et vide : pnj_militants_metier. Pose dans '
   || 'room.persons a l''universite, ne suit jamais personne. '
   || 'BLOQUEE : les six caracteristiques manquent toutes, et sa seule utilite -- le blocus '
   || 'syndical -- est morte en amont (getMonSyndicatEtGrade lit chargerOrgas et state.orgas, qui '
   || 'n''existent ni l''un ni l''autre ; la vraie liste est state.organisations). 0 ligne en '
   || 'production : la famille n''a jamais servi. Reparer ce chemin est un correctif de gameplay, '
   || 'pas une migration.'),
  ('agent', 'beta',
   'Agent de renseignement. Famille 100 % SERVEUR et PLEINEMENT ACTIVE : 12 agents, 3 cellules, '
   || 'convoques par quatre par le Ministre de la Defense (3 PA du ministre + 500 FR sur la caisse '
   || 'min_def). Aucun PA d''agent, aucun salaire recurrent : une echeance a J+10 balayee par le '
   || 'cron. Une seule caracteristique sur six, DUP, en valeurs FIXES par role (garde 10, '
   || 'coordinateur 12, conseillere 13, traducteur 15) -- INT, CHA, VOL, PER, ENT manquent. '
   || 'BLOQUEE POUR REFONTE, PAS POUR INDECISION : agents_renseignement porte deja sa position, '
   || 'son leader_courant, son transfert entre joueurs et sa detention, c''est-a-dire les memes '
   || 'axes que le socle, reimplementes en parallele. Converger exigerait de deplacer 33 fonctions, '
   || 'le cron de collecte, le contre-espionnage et le cycle carceral. Hors mandat : aucune refonte.')
ON CONFLICT (famille) DO UPDATE SET classe = EXCLUDED.classe, note = EXCLUDED.note;

-- REGLE DE JEU, distincte de l'etat de migration. Une ligne EXPLICITE pour chacune : sans ligne,
-- `pnj_mouvement_individuel_refus` ne refuse rien (il joint sur la table), et ce fail-open serait
-- une porte ouverte le jour ou la famille entrerait au socle.
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES
  ('employe', true, 'employe_du_joueur',
   'Un employe se laisse en place et se reprend dans le groupe : le jeu le permet deja '
   || '(laisserPnjEnPlace, recupererPnjDansGroupe), et il se debauche meme par un autre joueur. '
   || 'La regle de jeu est donc OUVERTE. C''est l''AXE, encore au magasin client, qui l''empeche '
   || 'aujourd''hui -- les deux gardes disent bien deux choses differentes.'),
  ('militant', false, 'militant_de_terrain',
   'Un militant reste sur son lieu de militance. Aucune mecanique du jeu ne le prend dans un '
   || 'groupe ni ne le deplace.'),
  ('agent', true, 'agent_porte_par_son_officier',
   'Un agent se porte et se depose reellement (agent_prendre, agent_deposer) et se transfere a un '
   || 'autre joueur SANS son accord (agent_transferer). La regle de jeu est donc ouverte ; seul '
   || 'l''axe, encore dans agents_renseignement, empeche le socle d''y toucher.')
ON CONFLICT (famille) DO UPDATE SET autorise = EXCLUDED.autorise,
  raison = EXCLUDED.raison, note = EXCLUDED.note;

-- Les axes restent au magasin historique de chaque famille. 'blob' se lit ici "un magasin metier
-- autre que pnj_membres" -- un JSON pour l'employe, une table dediee pour l'agent.
INSERT INTO public.pnj_axes_autorite (famille, axe, autorite, note)
SELECT f.famille, a.axe, 'blob', f.note
  FROM (VALUES
    ('employe',  'Magasin historique : state.employes, persiste dans personnages_donnees.employes. Cote client.'),
    ('militant', 'Magasin historique : militants_recrutes + organisations.membres[]. Double ecriture.'),
    ('agent',    'Magasin historique : agents_renseignement, qui porte deja position, leader_courant et detention.')
  ) f(famille, note),
       (VALUES ('position_leader'), ('pa'), ('possessions'), ('argent'), ('propriete')) a(axe)
ON CONFLICT (famille, axe) DO UPDATE SET autorite = EXCLUDED.autorite, note = EXCLUDED.note;