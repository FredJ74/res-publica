-- =====================================================================
-- LOT 1.5.5 — ARCHIVE MUNICIPALE DES DOSSIERS D'URBANISME
-- Table dediee, append-only, imposee par la base elle-meme
-- 6 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- L'archivage est BLOQUANT (voir archiverEvenementUrbanisme, plateau-immobilier.js) : tant que
-- cette table n'existe pas, tout depot de permis et toute decision seront REFUSES, avec un message
-- explicite. C'est le comportement voulu -- l'archive est la source historique officielle, un acte
-- administratif ne doit jamais etre repute traite sans elle -- mais cela signifie qu'un code
-- deploye avant la migration bloque les permis. Jamais l'inverse : la table peut exister sans le
-- code, elle restera simplement vide.
--
-- POURQUOI UNE TABLE DEDIEE. La premiere version de ce lot deposait les evenements dans
-- chronique_nationale, deja append-only par doctrine. Ecarte : c'est le journal d'evenements
-- PUBLICS du pays (nominations, elections, greves), lu par la collecte de La Tribune. Y verser
-- des dossiers d'urbanisme municipaux serait une pollution semantique, et l'append-only n'y
-- reposait que sur une convention de code -- rien n'empechait techniquement un UPDATE.
--
-- Ici l'append-only est garanti PAR LA BASE : RLS active, aucune policy UPDATE, aucune policy
-- DELETE. Meme avec la cle anon publique, une ligne d'archive ne peut etre ni reecrite ni
-- supprimee. C'est la propriete la plus importante de cette table.

CREATE TABLE IF NOT EXISTS dossiers_urbanisme (
  id             text PRIMARY KEY,
  country        text NOT NULL,
  city           text,
  building_id    text,
  -- Clef de regroupement d'un dossier. NULL pour les dossiers anterieurs au Lot 1.5.2, qui n'ont
  -- jamais recu de numero : on ne leur en fabrique pas.
  numero_dossier text,
  -- 'depot' | 'acceptation' | 'refus' | 'accord_tacite' | 'modification_plan'
  type_evenement text NOT NULL,
  demandeur      text,
  jour           integer,
  libelle        text,
  -- Snapshot fige de l'evenement (surface, decoupage declare, palier, motif de refus...).
  data           jsonb NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Consultation municipale : filtrage pays + ville, puis regroupement par dossier.
CREATE INDEX IF NOT EXISTS dossiers_urbanisme_commune_idx ON dossiers_urbanisme (country, city, created_at);
CREATE INDEX IF NOT EXISTS dossiers_urbanisme_numero_idx  ON dossiers_urbanisme (numero_dossier);
CREATE INDEX IF NOT EXISTS dossiers_urbanisme_terrain_idx ON dossiers_urbanisme (country, building_id);

ALTER TABLE dossiers_urbanisme ENABLE ROW LEVEL SECURITY;

-- LECTURE publique : un registre d'urbanisme est un document administratif consultable. Le
-- filtrage de ce qui est REELLEMENT montre a l'ecran reste porte par le jeu (consultation reservee
-- au maire adjoint dans son bureau, data.js) -- la base n'a pas a arbitrer une regle de jeu.
DROP POLICY IF EXISTS dossiers_urbanisme_lecture ON dossiers_urbanisme;
CREATE POLICY dossiers_urbanisme_lecture ON dossiers_urbanisme
  FOR SELECT USING (true);

-- ECRITURE : insertion seule. Les actes sont deposes par le client (depot d'un permis par le
-- proprietaire, decision du maire adjoint), donc par la cle anon -- meme doctrine que mariages,
-- jugements, detentions ou terrains_historique_ventes.
DROP POLICY IF EXISTS dossiers_urbanisme_insertion ON dossiers_urbanisme;
CREATE POLICY dossiers_urbanisme_insertion ON dossiers_urbanisme
  FOR INSERT WITH CHECK (true);

-- AUCUNE policy UPDATE, AUCUNE policy DELETE : volontaire et structurant. Avec RLS active, une
-- operation sans policy correspondante est refusee. L'historique est donc immuable au niveau du
-- moteur de base, pas seulement par convention de code -- y compris contre un appel direct a
-- l'API REST avec la cle publique.

-- CONTROLE POSTERIEUR — attendu : 'dossiers_urbanisme_lecture' (SELECT) et
-- 'dossiers_urbanisme_insertion' (INSERT), et RIEN d'autre.
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'dossiers_urbanisme'
ORDER BY policyname;

-- CONTROLE POSTERIEUR — attendu : rowsecurity = true, 0 ligne dans la table.
SELECT relrowsecurity AS rls_active FROM pg_class WHERE relname = 'dossiers_urbanisme';
SELECT count(*) AS lignes FROM dossiers_urbanisme;
