-- Securisation de journal_editions + file d'attente d'articles (chantier "interview de Jodie
-- Moitout", 3 septembre 2026, revu suite a audit de securite dedie).
--
-- PROBLEME CORRIGE : journal_editions n'avait AUCUNE politique RLS (RLS meme pas active) --
-- rien n'empechait un client, avec la seule cle anon deja presente dans le bundle JS, d'ecrire
-- ou de modifier arbitrairement une edition partagee entre TOUS les joueurs d'un pays. Jusqu'ici
-- seul le cron serveur (api/_journal-generation.js) y ecrivait, mais avec cette MEME cle anon --
-- la porte etait ouverte, simplement jamais empruntee cote client.
--
-- DOCTRINE DEJA ETABLIE DANS CE PROJET (voir migration_renseignements_connus.sql, executee en
-- production le 22 aout 2026, et api/upload-org-avatar.js) : RLS active + policy explicite pour
-- ce qui doit rester public, ZERO policy pour ce qui ne doit etre touche que par un endpoint
-- serveur privilegie (SUPABASE_SERVICE_ROLE_KEY, variable d'environnement Vercel UNIQUEMENT,
-- jamais exposee au client, contourne RLS par construction).
--
-- Difference avec renseignements_connus (verrouillage total) : journal_editions DOIT rester
-- LISIBLE par les joueurs (afficherJournalDuJour(), plateau-politique.js, lit directement via la
-- cle anon) -- seule l'ECRITURE doit etre fermee. D'ou une policy SELECT explicite, et aucune
-- policy INSERT/UPDATE/DELETE (refusees par defaut a anon/authenticated des que RLS est active).

ALTER TABLE journal_editions ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_editions_lecture_publique ON journal_editions
  FOR SELECT
  USING (true);

-- Aucune policy INSERT/UPDATE/DELETE definie ici : ces operations restent refusees par defaut a
-- anon et authenticated. Seul service_role (qui contourne RLS par nature) peut desormais ecrire,
-- via :
--   - api/_journal-generation.js (cron quotidien, bascule sur service_role dans ce meme chantier
--     -- il utilisait la cle anon jusqu'ici, ce qui aurait ete bloque par cette migration si son
--     code n'etait pas mis a jour en meme temps, voir rapport de livraison) ;
--   - api/journal-interview.js (nouvel endpoint dedie, publication securisee d'une interview).


-- =====================
-- FILE D'ATTENTE D'ARTICLES (interview terminee avant qu'une edition du jour n'existe encore)
-- =====================
-- Meme principe que petites_annonces (contenu depose, integre par le cron a la prochaine
-- generation, JAMAIS une seconde base d'articles ni un second systeme de journal) -- a la
-- difference de petites_annonces, le contenu ici est deja REDIGE PAR L'IA cote serveur au moment
-- du depot (api/journal-interview.js) : la generation quotidienne n'a JAMAIS a rappeler l'IA pour
-- ces lignes, elle les assemble telles quelles dans double_page_centrale.articles (meme doctrine
-- que assemblerAvantDernierePage/assemblerDernierePage : assemblage deterministe, zero invention,
-- zero appel IA supplementaire -- voir §20 du cahier des charges "Journal du jour", un seul appel
-- IA par pays et par jour pour la generation elle-meme, inchange par cette file d'attente).
--
-- RLS verrouillee comme renseignements_connus (zero policy) : le contenu ici est deja un article
-- PUBLIABLE tel quel par le cron, sans nouvelle verification -- il ne doit exister AUCUN chemin
-- cote client, meme indirect, pour y deposer un texte arbitraire. Seuls api/journal-interview.js
-- (ecriture) et api/_journal-generation.js (lecture + marquage "integree_le") y accedent, tous
-- deux via service_role.
--
-- "integree_le" (nullable, NULL = en attente) sert a la fois de statut ET de garde anti-
-- duplication : le cron ne selectionne que integree_le IS NULL, et le marque immediatement apres
-- integration reussie dans la MEME transaction logique que l'ecriture de l'edition -- un rejeu de
-- la generation (improbable, verrou de reservation deja existant sur journal_editions) ne
-- reprendrait jamais une ligne deja marquee.
CREATE TABLE IF NOT EXISTS journal_articles_en_attente (
  id text PRIMARY KEY,
  country text NOT NULL,
  rubrique text NOT NULL DEFAULT 'Portraits',
  titre text NOT NULL,
  texte text NOT NULL,
  image_url text,
  ville text,
  created_at timestamptz NOT NULL DEFAULT now(),
  integree_le timestamptz
);

CREATE INDEX IF NOT EXISTS idx_journal_articles_en_attente_country
  ON journal_articles_en_attente (country) WHERE integree_le IS NULL;

ALTER TABLE journal_articles_en_attente ENABLE ROW LEVEL SECURITY;
-- RLS active, aucune policy : refuse tout acces (SELECT/INSERT/UPDATE/DELETE) a anon et a tout
-- autre role soumis a RLS. Seul service_role peut y acceder.
