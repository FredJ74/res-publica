-- Migration requise avant que les demandes de logement social de Montrouge (chantier du 18 aout
-- 2026) ne soient reellement persistees, et avant que les attributions ne laissent une trace en
-- archives municipales.
--
-- Contexte : aucune colonne existante ne convient. "personnages" est relue et resauvegardee en
-- integralite (sbSavePersonnage) a CHAQUE action de CHAQUE joueur -- y ajouter une colonne pour
-- les demandes ferait echouer TOUTES les sauvegardes tant que cette migration n'est pas
-- appliquee (meme raisonnement deja documente dans migration_etat_civil_ville.sql). Les demandes
-- doivent en outre etre lisibles par un joueur DIFFERENT de celui qui les a deposees (l'adjoint
-- au maire), ce qu'aucune donnee actuellement stockee sur le personnage ne permet.
--
-- Deux tables nouvelles, sur le modele exact de "terrains_historique_ventes" (deja en
-- production) : id text primary key construit cote application, created_at automatique,
-- aucune contrainte d'unicite additionnelle, aucune colonne de qualification.
--
-- 1) logements_demandes : file d'attente persistante. Une ligne par demande. "statut" suit le
--    meme principe que journal_editions/terrains_etat (colonne texte + CHECK, jamais un enum
--    Postgres dedie, coherent avec le reste du projet). "room_id_attribue" reste NULL tant que
--    la demande n'est pas traitee ; renseigne au moment de l'attribution, jamais modifie ensuite
--    (pas de re-attribution prevue dans ce lot).
--
-- 2) logements_attributions_historique : archive append-only, jamais mise a jour ni supprimee
--    (y compris lors d'une resiliation -- voir plateau-logements-montrouge.js,
--    resilierLogementSocialSiDepartMontrouge). Champs strictement factuels (logement,
--    beneficiaire, autorite, date) : aucune colonne de jugement ("suspect", "corruption",
--    "legitime", etc.), conformement a la doctrine validee lors de l'audit -- le jeu ne qualifie
--    jamais une attribution, les joueurs tirent leurs propres conclusions des faits.
--
-- La cle anon (utilisee par le client via l'API REST) n'a pas les privileges DDL necessaires
-- pour executer ceci elle-meme -- comme pour toutes les migrations precedentes de ce projet,
-- toujours executees manuellement par Fred dans l'editeur SQL Supabase.
--
-- Sans cette migration : demanderLogementSocial()/attribuerLogementSocial() echouent
-- silencieusement (toutes les ecritures sont deja protegees par .catch(() => {}) ou verifient
-- explicitement un retour null) -- le joueur voit un message "La persistance des demandes n'est
-- pas encore disponible" plutot qu'une erreur technique. Aucune autre fonctionnalite du jeu
-- n'est affectee : "personnages" et "locations_actives" (bail lui-meme, deja existante) ne sont
-- pas touchees par cette migration.

CREATE TABLE IF NOT EXISTS logements_demandes (
  id text PRIMARY KEY,
  country text NOT NULL,
  ville text NOT NULL,
  demandeur text NOT NULL,
  type_souhaite text,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'attribuee', 'annulee')),
  room_id_attribue text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS logements_attributions_historique (
  id text PRIMARY KEY,
  country text NOT NULL,
  ville text NOT NULL,
  room_id text NOT NULL,
  beneficiaire text NOT NULL,
  autorite text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
