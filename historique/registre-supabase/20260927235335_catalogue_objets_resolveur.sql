-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927235335
-- Nom original      : catalogue_objets_resolveur
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 23:53:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d1bc95446c4f74cfdcba50f34ef63cdd
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
-- Correction technique : les deux correspondances en motif 'objet_id' ne sont pas
-- derivables d'un objet d'inventaire sans coder un cas particulier. On les rebascule
-- sur des motifs derivables. Le CONTENU (objet -> generique -> effets) est inchange.
alter table public.catalogue_correspondance_legacy drop constraint if exists catalogue_correspondance_legacy_motif_check;
alter table public.catalogue_correspondance_legacy add constraint catalogue_correspondance_legacy_motif_check
  check (motif in ('type_soustype','type','produit_militaire','type_produit_militaire',
                   'type_tracttype','type_originequete','famille_produit_marche',
                   'recette_id','stack_key','ordre','objet_id'));

update public.catalogue_correspondance_legacy
   set motif = 'type', valeur = 'armoire_souvenirs'
 where motif = 'objet_id' and valeur = 'armoire_souvenirs';

update public.catalogue_correspondance_legacy
   set motif = 'type_originequete', valeur = 'tract|jean_lou', priorite = 400
 where motif = 'objet_id' and valeur = 'tract|origineQuete=jean_lou';

-- RESOLVEUR PILOTE PAR LES DONNEES
-- Aucune cascade de `if` par produit : on derive les cles candidates de l'objet,
-- on les joint au registre de correspondances, et la priorite tranche.
-- Ajouter un mapping demain = UNE LIGNE DE DONNEES, aucun code.
--
-- Note sur le motif `recette_id` : un produit de marche pousse en inventaire un objet
-- dont le champ `type` vaut l'IDENTIFIANT DE RECETTE (plateau-actions-illegales-rumeurs.js:4757-4776).
-- La cle candidate `recette_id` est donc derivee de `type` -- c'est ce qui permet a la
-- meme ligne de correspondance de servir l'etiquette de recettes_commerce ET la
-- resolution d'un objet detenu.
create or replace function public.generique_de_objet(p_objet jsonb)
returns table (generique_id text, variante_id text, effets_effectifs jsonb,
               motif text, valeur text, priorite int)
language sql stable
as $$
  with cand(motif, valeur) as (
    select 'type_originequete', (p_objet->>'type') || '|' || (p_objet->>'origineQuete')
      where p_objet->>'type' is not null and p_objet->>'origineQuete' is not null
    union all
    select 'type_produit_militaire', (p_objet->>'type') || '|' || (p_objet->>'produitMilitaire')
      where p_objet->>'type' is not null and p_objet->>'produitMilitaire' is not null
    union all
    select 'produit_militaire', p_objet->>'produitMilitaire'
      where p_objet->>'produitMilitaire' is not null
    union all
    select 'type_tracttype', (p_objet->>'type') || '|' || (p_objet->>'tractType')
      where p_objet->>'type' is not null and p_objet->>'tractType' is not null
    union all
    select 'famille_produit_marche', p_objet->>'familleProduitMarche'
      where p_objet->>'familleProduitMarche' is not null
    union all
    select 'type_soustype', (p_objet->>'type') || '|' || (p_objet->>'sousType')
      where p_objet->>'type' is not null and p_objet->>'sousType' is not null
    union all
    select 'recette_id', p_objet->>'type'
      where p_objet->>'type' is not null
    union all
    select 'stack_key', p_objet->>'stackKey'
      where p_objet->>'stackKey' is not null
    union all
    select 'type', p_objet->>'type'
      where p_objet->>'type' is not null
  )
  select c.generique_id, c.variante_id, c.effets_effectifs, c.motif, c.valeur, c.priorite
    from cand
    join public.catalogue_correspondance_legacy c
      on c.motif = cand.motif and c.valeur = cand.valeur
   order by c.priorite desc, c.id asc
   limit 1;
$$;

comment on function public.generique_de_objet(jsonb) is
  'Resolveur de referentiel. Lecture seule, aucun effet de bord. Rend 0 ligne lorsque aucun generique ne peut etre determine : un objet non resoluble doit rendre NULL, jamais une valeur devinee.';

revoke all on function public.generique_de_objet(jsonb) from anon, authenticated;
grant execute on function public.generique_de_objet(jsonb) to anon, authenticated;