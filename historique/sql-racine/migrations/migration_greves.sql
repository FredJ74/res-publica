-- Migration requise avant le chantier "Greves, greve generale et contre-pouvoirs" (audit
-- valide le 3 septembre 2026, implementation le meme jour).
--
-- Contexte : la grève ORDINAIRE ne necessite AUCUNE nouvelle table -- elle vit entierement dans
-- organisations.data.greve (meme doctrine que election/caisse, deja inline sur l'organisation),
-- exactement comme le blocus syndical vit dans batiments_etat.data.blocus. Rien a migrer pour ce
-- volet.
--
-- La grève GENERALE, elle, coordonne PLUSIEURS organisations a la fois (reponses individuelles
-- de chaque chef, calcul d'adoption/puissance sur l'ensemble) -- ca ne peut pas vivre dans le
-- jsonb d'une seule organisation. Meme besoin structurel que "demandes_manifestation" en son
-- temps : une table dediee, une ligne par grève générale (jamais par syndicat participant).
--
-- Pas de RLS ici : convention par defaut de ce projet pour les tables de gameplay normales
-- (organisations, batiments_etat, demandes_manifestation...), la RLS verrouillee est l'EXCEPTION
-- reservee aux cas ou une faille d'identite/falsification concrete a ete demontree (voir
-- migration_renseignements_connus.sql, migration_interviews_jodie.sql) -- pas le cas ici, meme
-- doctrine d'acces que le reste des mecaniques syndicales/organisationnelles deja en production.
--
-- La cle anon n'a pas les privileges DDL necessaires pour executer ceci elle-meme -- a executer
-- manuellement par Fred dans l'editeur SQL Supabase, comme toutes les migrations precedentes.
CREATE TABLE IF NOT EXISTS greves_generales (
  id text PRIMARY KEY,
  country text NOT NULL,
  -- 'consultation' (reponses en cours) -> 'active' (adoptee, effets quotidiens) -> 'terminee'
  -- (effondrement apres retraits, ou -- non prevu par le game design actuel -- jamais de fin
  -- automatique par duree, seul le retrait syndicat par syndicat y met fin).
  statut text NOT NULL DEFAULT 'consultation',
  initiateur text NOT NULL,
  syndicat_initiateur_id text NOT NULL,
  revendications text NOT NULL,
  forum_topic_id text,
  -- Liste FIGEE au lancement de la consultation (cahier des charges §4 : "au lancement de la
  -- consultation, etablir la liste des syndicats actifs eligibles") -- jamais recalculee apres
  -- coup si un syndicat devient/cesse d'etre eligible en cours de route. Une entree par syndicat
  -- eligible au moment du lancement :
  -- [{orgaId, orgaNom, chef, statut:'en_discussion'|'accepte'|'refuse'|'retire', membresUniques:[nom,...]}]
  participants jsonb NOT NULL DEFAULT '[]'::jsonb,
  date_lancement timestamptz NOT NULL DEFAULT now(),
  date_entree_vigueur timestamptz,
  -- Compteur de jours REELS ecoules depuis l'entree en vigueur, incremente une fois par passage
  -- de cron (jamais une difference de dates recalculee, pour rester robuste a un cron manque) --
  -- meme doctrine que l'usure INF de la greve ordinaire.
  jours_actifs integer NOT NULL DEFAULT 0,
  -- Garde-fou anti double-application si le cron est rejoue le meme jour (aucun verrou
  -- equivalent n'existe aujourd'hui pour la production economique quotidienne, voir audit --
  -- celui-ci est propre a la greve generale).
  derniere_application_jour text,
  -- Recalcule a CHAQUE changement de participants (adoption initiale, puis chaque retrait) --
  -- jamais recalcule par le cron seul, voir §8 du cahier des charges (retrait -> recalcul
  -- immediat, pas d'attente du lendemain).
  puissance_niveau integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_greves_generales_country_statut ON greves_generales (country, statut);
