-- =====================================================================
-- L2 — SOCLE DU REFERENTIEL D'OBJETS (types / familles / generiques /
-- variantes / correspondances legacy)
-- =====================================================================
-- Migration appliquee en base : 20260927234824 catalogue_objets_socle
-- (1re des 5 migrations du lot L2 ; ordre de rejeu : socle, seed,
--  resolveur, fiche_officielle).
--
-- Chantier de normalisation des objets et preparation des commerces PJ.
-- Perimetre L2 valide : REFERENTIEL + RESOLVEUR + FICHE OFFICIELLE EN
-- LECTURE sur les produits existants.
--
-- DOCTRINE DE CE LOT :
--   1. ADDITIF. Aucune structure existante n'est modifiee, hormis trois
--      colonnes `generique_id` NULLABLE posees sur des tables de recettes.
--      Aucun lecteur existant ne les voit.
--   2. LE REFERENTIEL NE REECRIT JAMAIS UN OBJET. Il repond seulement a la
--      question « de quel generique cet objet releve-t-il ? ». Il n'ecrit ni
--      dans personnages_donnees.inventory, ni dans entreprises.data, ni dans
--      aucun blob institutionnel.
--   3. SERVEUR AUTORITAIRE. Les six tables sont fermees en ecriture aux
--      clients : GRANT SELECT seul ET une seule policy SELECT. C'est la
--      double fermeture qui protege deja caisses_batiments -- et l'inverse
--      de organisations (policy allow_all) et de registre_ventes_armes
--      (RLS desactivee).
--   4. AUCUNE DONNEE DERIVABLE N'EST STOCKEE. Le raccordement legacy d'un
--      generique est une VUE, jamais une colonne : une colonne creerait une
--      seconde source de verite susceptible de deriver, defaut releve six
--      fois par l'audit (empreinte de ressources_economie a jour et jamais
--      relue, stockMax 30 stocke contre 20 applique, prixFixe conserve et
--      ecrase au calcul).
--
-- CE QUE CE LOT NE FAIT PAS, DELIBEREMENT :
--   - aucune table de gabarit de recette (flux L6) ;
--   - aucune table de reference commerciale ni de snapshot (flux L5) ;
--   - aucune table d'installation (flux L8). L'audit a montre qu'un moteur
--     d'installation complet existe deja dans plateau-objets.js, 39 symboles,
--     zero appelant : on ne reproduit pas cette situation ;
--   - aucun plafond commercial (flux L5) ;
--   - aucune empreinte de coherence stockee : le controle est un harnais
--     executable, pas un condense que personne ne relit.

-- ---------------------------------------------------------------------
-- 1. TYPES DE COMMERCE
-- ---------------------------------------------------------------------
-- Pas de colonne `actif` : aucun lecteur en L2. Si un besoin reel de
-- visibilite apparait, un champ nomme pour ce besoin sera ajoute alors.
create table if not exists public.catalogue_types (
  id      text primary key,
  libelle text not null,
  ordre   int  not null default 0
);

comment on table public.catalogue_types is
  'Les 14 types de commerce du referentiel cible. Lecture publique, ecriture service_role.';

-- ---------------------------------------------------------------------
-- 2. FAMILLES
-- ---------------------------------------------------------------------
-- Liste PLATE en L2. Le rattachement type <-> famille (catalogue_type_famille)
-- est reporte en L5 : il ne sert qu'au formulaire de creation de reference
-- (« quelles familles mon type me donne-t-il ? »), qui n'existe pas encore.
-- La fiche officielle, elle, remonte la famille depuis le generique.
create table if not exists public.catalogue_familles (
  id      text primary key,
  libelle text not null
);

comment on table public.catalogue_familles is
  'Familles commerciales. Liste plate en L2 ; le rattachement aux types arrive en L5.';

-- ---------------------------------------------------------------------
-- 3. GENERIQUES
-- ---------------------------------------------------------------------
-- est_service : SEULE propriete intrinseque de commercialisation.
--   true  = ne produit JAMAIS d'objet d'inventaire, quel que soit le commerce
--           (une coupe de cheveux, une nuit d'hotel, une reparation).
--   false = c'est un bien. Qu'il soit livre en objet ou consomme sur place
--           N'EST PAS decide ici : c'est une propriete du mode de
--           commercialisation, portee par la reference (L5). Une boisson au
--           comptoir et une bouteille emportee sont le meme generique.
--
-- consommable / equipable : NON EXCLUSIFS et cumulables avec le statut de
--   bien. C'est ce qui permet de representer correctement un encas a
--   emporter, qui est a la fois une marchandise et un consommable -- ce
--   qu'une valeur unique de « nature » interdisait.
--
-- effets / capacites / durabilite / conditions / contraintes : NULL partout
--   en L2. Aucun chiffre n'est invente. Un generique sans effet est un etat
--   legitime et la fiche officielle affichera « Aucun effet ».
--   effets    = deltas mesurables.
--   capacites = ce que l'objet PERMET DE FAIRE. Jamais herite, jamais deduit
--               d'un nom : un « Article du quotidien » rebaptise « Ordinateur
--               quantique » n'acquiert aucune capacite informatique.
create table if not exists public.catalogue_generiques (
  id            text primary key,
  libelle       text not null,
  famille_id    text not null references public.catalogue_familles(id),
  regime        text not null default 'libre'
                check (regime in ('libre','reglemente','illegal','institutionnel')),
  est_service   boolean not null default false,
  empilable     boolean not null default false,
  individualise boolean not null default false,
  consommable   boolean not null default false,
  equipable     boolean not null default false,
  encombrement  int,
  effets        jsonb,
  capacites     jsonb,
  durabilite    jsonb,
  conditions    jsonb,
  contraintes   jsonb,
  note          text
);

comment on column public.catalogue_generiques.est_service is
  'true = ne produit jamais d''objet d''inventaire. Le mode de commercialisation d''un bien (livre ou consomme sur place) n''est PAS une propriete du generique : il releve de la reference (L5).';
comment on column public.catalogue_generiques.equipable is
  'Affectation REELLEMENT existante dans le moteur actuel uniquement. Aucune anticipation des futures mecaniques d''installation.';
comment on column public.catalogue_generiques.capacites is
  'Ce que l''objet permet de faire. Jamais herite d''un autre generique, jamais deduit du nom commercial.';

-- ---------------------------------------------------------------------
-- 4. GENERIQUE <-> TYPE (N:N indispensable des L2)
-- ---------------------------------------------------------------------
-- Un type_id unique sur le generique serait un mensonge de modele :
-- `boisson` appartient reellement a bar-restauration ET commerce-alimentaire,
-- `protection-corporelle` a armurerie ET sport-loisirs, `article-de-supporter`
-- a commerce-non-alimentaire ET sport-loisirs, `encas-a-emporter` a
-- commerce-alimentaire ET bar-restauration. Le remplacer plus tard par une
-- N:N obligerait a reecrire toutes les lectures.
create table if not exists public.catalogue_generique_type (
  generique_id text not null references public.catalogue_generiques(id),
  type_id      text not null references public.catalogue_types(id),
  primary key (generique_id, type_id)
);

-- ---------------------------------------------------------------------
-- 5. VARIANTES
-- ---------------------------------------------------------------------
-- Une variante est une configuration du generique qui porte des CAPACITES
-- propres. Necessaire des L2 parce que les objets militaires existent DEJA :
-- sans elle, deux seules issues, toutes deux fausses --
--   (a) le generique `appareil-de-communication` porte la capacite militaire
--       et contamine tout appareil vendu par un commerce PJ ;
--   (b) on cree un generique « Radio militaire » separe, et l'on reconstitue
--       l'accumulation d'objets specifiques que ce chantier supprime.
-- Aucune variante civile n'est creee : leurs proprietes seront definies
-- lorsqu'il sera reellement decide de les introduire.
create table if not exists public.catalogue_variantes (
  id           text primary key,
  generique_id text not null references public.catalogue_generiques(id),
  cle          text not null,
  libelle      text not null,
  regime       text not null default 'reglemente'
               check (regime in ('libre','reglemente','illegal','institutionnel')),
  surcharges   jsonb,
  capacites    jsonb,
  note         text,
  unique (generique_id, cle)
);

-- ---------------------------------------------------------------------
-- 6. CORRESPONDANCES LEGACY  (resolveur pilote par les donnees)
-- ---------------------------------------------------------------------
-- Table de mapping ET source de verite des effets REELLEMENT APPLIQUES aux
-- objets historiques.
--
-- POURQUOI effets_effectifs VIT ICI ET NON SUR LE GENERIQUE : un tee-shirt
-- historique donne +1 ENT, mais cela ne fait pas de « +1 ENT » l'effet du
-- generique `Haut`. La fiche officielle doit donc pouvoir rapporter des effets
-- de deux origines distinctes : ceux du generique (pour une future reference)
-- et ceux du moteur pour un objet historique donne.
--
-- CONSEQUENCE HEUREUSE : effets_effectifs ne contient que ce qui est PROUVE
-- applique. Le `bonus:{stat:'PER',val:8}` d'un revolver, jamais lu par
-- getStatEffective, n'y figure pas -- il ne peut donc jamais etre affiche,
-- sans filtre, sans exception et sans liste noire a maintenir.
--
-- motif `type_produit_militaire` : indispensable pour distinguer l'explosif
-- retire legalement (type:'explosif') de l'explosif subtilise (type:'arme'),
-- qui partagent le meme produitMilitaire et n'ont pas le meme comportement.
create table if not exists public.catalogue_correspondance_legacy (
  id               bigserial primary key,
  motif            text not null check (motif in (
                     'type_soustype','type','produit_militaire',
                     'type_produit_militaire','type_tracttype',
                     'famille_produit_marche','recette_id','stack_key',
                     'ordre','objet_id')),
  valeur           text not null,
  generique_id     text not null references public.catalogue_generiques(id),
  variante_id      text references public.catalogue_variantes(id),
  priorite         int  not null default 100,
  effets_effectifs jsonb,
  source_audit     text not null,
  note             text,
  unique (motif, valeur)
);

comment on column public.catalogue_correspondance_legacy.effets_effectifs is
  'UNIQUEMENT les effets que le moteur applique reellement a cet objet historique. NULL = aucun effet effectif, ce qui produira « Aucun effet » sur la fiche. Les proprietes declarees mais jamais lues n''y figurent jamais.';
comment on column public.catalogue_correspondance_legacy.source_audit is
  'chemin:ligne ou nom de fonction prouvant l''effet. Obligatoire : une correspondance sans preuve ne doit pas exister.';

create index if not exists idx_corresp_legacy_generique
  on public.catalogue_correspondance_legacy (generique_id);

-- ---------------------------------------------------------------------
-- 7. VUE DE RACCORDEMENT  (donnee DERIVEE, jamais stockee)
-- ---------------------------------------------------------------------
-- Remplace le champ `actif` retire du modele. Un generique est « raccorde »
-- si et seulement si au moins une correspondance legacy le designe. Ce fait
-- est calcule, donc il ne peut pas deriver de la realite.
-- L'autorisation commerciale future (`commercialisable`) sera une DECISION
-- distincte, avec sa propre colonne et son propre nom, ajoutee en L5.
create or replace view public.catalogue_generiques_raccordes as
  select g.id                as generique_id,
         count(c.id)::int    as nb_correspondances
    from public.catalogue_generiques g
    left join public.catalogue_correspondance_legacy c on c.generique_id = g.id
   group by g.id;

-- ---------------------------------------------------------------------
-- 8. ETIQUETTES SUR L'EXISTANT  (additif, aucun lecteur existant)
-- ---------------------------------------------------------------------
alter table public.recettes_commerce     add column if not exists generique_id text;
alter table public.recettes_production   add column if not exists generique_id text;
alter table public.produits_manufactures add column if not exists generique_id text;

comment on column public.recettes_commerce.generique_id is
  'Etiquette de referentiel (L2). Nullable, aucun lecteur historique. Ne modifie aucun comportement.';

-- ---------------------------------------------------------------------
-- 9. FERMETURE  (double : GRANT + policy)
-- ---------------------------------------------------------------------
-- Piege evite ici : une policy USING(true) posee sur une table dont la RLS
-- serait desactivee est dormante et ne protege rien. On active la RLS ET on
-- restreint les GRANT.
alter table public.catalogue_types                  enable row level security;
alter table public.catalogue_familles               enable row level security;
alter table public.catalogue_generiques             enable row level security;
alter table public.catalogue_generique_type         enable row level security;
alter table public.catalogue_variantes              enable row level security;
alter table public.catalogue_correspondance_legacy  enable row level security;

drop policy if exists "catalogue_types lecture"       on public.catalogue_types;
drop policy if exists "catalogue_familles lecture"    on public.catalogue_familles;
drop policy if exists "catalogue_generiques lecture"  on public.catalogue_generiques;
drop policy if exists "catalogue_generique_type lecture" on public.catalogue_generique_type;
drop policy if exists "catalogue_variantes lecture"   on public.catalogue_variantes;
drop policy if exists "catalogue_correspondance_legacy lecture" on public.catalogue_correspondance_legacy;

create policy "catalogue_types lecture"
  on public.catalogue_types for select to anon, authenticated using (true);
create policy "catalogue_familles lecture"
  on public.catalogue_familles for select to anon, authenticated using (true);
create policy "catalogue_generiques lecture"
  on public.catalogue_generiques for select to anon, authenticated using (true);
create policy "catalogue_generique_type lecture"
  on public.catalogue_generique_type for select to anon, authenticated using (true);
create policy "catalogue_variantes lecture"
  on public.catalogue_variantes for select to anon, authenticated using (true);
create policy "catalogue_correspondance_legacy lecture"
  on public.catalogue_correspondance_legacy for select to anon, authenticated using (true);

revoke all on public.catalogue_types                 from anon, authenticated;
revoke all on public.catalogue_familles              from anon, authenticated;
revoke all on public.catalogue_generiques            from anon, authenticated;
revoke all on public.catalogue_generique_type        from anon, authenticated;
revoke all on public.catalogue_variantes             from anon, authenticated;
revoke all on public.catalogue_correspondance_legacy from anon, authenticated;
revoke all on public.catalogue_generiques_raccordes  from anon, authenticated;

grant select on public.catalogue_types                 to anon, authenticated;
grant select on public.catalogue_familles              to anon, authenticated;
grant select on public.catalogue_generiques            to anon, authenticated;
grant select on public.catalogue_generique_type        to anon, authenticated;
grant select on public.catalogue_variantes             to anon, authenticated;
grant select on public.catalogue_correspondance_legacy to anon, authenticated;
grant select on public.catalogue_generiques_raccordes  to anon, authenticated;
