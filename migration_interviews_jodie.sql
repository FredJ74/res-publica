-- Migration requise avant tout test/production de l'ordre "Donner une interview" (Jodie Moitout,
-- La Tribune de Republia, chantier du 3 septembre 2026).
--
-- Contexte : besoin d'un cooldown de 10 JOURS REELS par PJ, persistant (survit au rechargement de
-- page, au changement de navigateur, a la deconnexion/reconnexion), jamais base sur state.day
-- (compteur de jours de JEU propre a chaque personnage, deja documente comme non fiable pour ce
-- genre de garde-fou -- voir api/_journal-collecte.js et api/cron-minuit.js, "state.day...
-- inutilisable pour comparer des joueurs entre eux").
--
-- Nouvelle table dediee plutot qu'une colonne ajoutee a la table "personnages" deja tres partagee
-- (meme doctrine que successions/demandes_mariage/prets/logements_demandes : une petite table par
-- fonctionnalite, jamais de colonne fonctionnalite-specifique posee sur une table centrale). Une
-- ligne par interview REELLEMENT LANCEE (PA deja consomme a cet instant, voir cahier des charges
-- §2/§9) -- jamais une ligne par tentative refusee pour cause de cooldown.
--
-- REVISION DE SECURITE (3 septembre 2026, audit dedie apres le lot RLS journal_editions) :
-- CETTE TABLE N'A JAMAIS ETE EXECUTEE EN PRODUCTION -- toute cette section peut donc encore etre
-- corrigee ici, jamais un ALTER TABLE separe. Deux failles identifiees dans la version precedente
-- de cette migration/du endpoint associe, corrigees ci-dessous :
--   1. Sans RLS, cette table etait INTEGRALEMENT lisible via la cle anon publique du bundle JS --
--      un attaquant pouvait lister TOUTES les interviews en cours (personnage + id compris) et
--      voler la paire d'un autre joueur pour publier un article EN SON NOM.
--   2. Le endpoint acceptait questions/reponses telles quelles depuis le client au moment de la
--      publication, sans aucun lien avec un echange reellement temoin cote serveur -- un client
--      pouvait remplacer integralement le contenu par des Q/R inventees.
--
-- CORRECTIF : RLS activee, ZERO policy (meme doctrine que renseignements_connus -- acces refuse
-- par defaut a anon, seul service_role, jamais expose au client, y accede desormais). Nouvelle
-- colonne "transcript" (jsonb, tableau de {question, reponse}) : rempli UNIQUEMENT par
-- api/journal-interview.js au fil du dialogue (action 'question'), jamais par le client -- la
-- publication finale (action 'publier') lit ce transcript tel quel, plus jamais un tableau
-- questions/reponses fourni dans le corps de la requete. Le contenu publie est desormais
-- garanti identique a ce que le serveur a lui-meme vu passer, tour par tour.
--
-- La cle anon n'a pas les privileges DDL necessaires pour executer ceci elle-meme -- a executer
-- manuellement par Fred dans l'editeur SQL Supabase, comme toutes les migrations precedentes.
CREATE TABLE IF NOT EXISTS interviews_jodie (
  id text PRIMARY KEY,
  personnage text NOT NULL,
  country text NOT NULL,
  transcript jsonb NOT NULL DEFAULT '[]'::jsonb,
  publie boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Une seule requete reelle sur cette table : la derniere interview d'un PJ donne, la plus recente
-- en tete -- index dedie pour que cette lecture reste immediate meme lorsque l'historique grandit.
CREATE INDEX IF NOT EXISTS interviews_jodie_personnage_idx ON interviews_jodie (personnage, created_at DESC);

ALTER TABLE interviews_jodie ENABLE ROW LEVEL SECURITY;
-- RLS active, aucune policy : refuse tout acces (SELECT/INSERT/UPDATE/DELETE) a anon et a tout
-- autre role soumis a RLS. Seul service_role (api/journal-interview.js) peut y acceder --
-- ferme la fuite de lecture qui permettait de decouvrir l'id d'interview d'un autre joueur.
