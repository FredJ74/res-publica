-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928183548
-- Nom original      : c6_raccordement_objets_et_filtrage
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-28 18:35:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6c0016ed10f4e0fbe66c4318b057e0b2
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
-- ---------------------------------------------------------------------------
-- RACCORDEMENT DES RECETTES « OBJET » AU REFERENTIEL L2
-- ---------------------------------------------------------------------------
-- Aucune correspondance n'est ecrite a la main : elles sont LUES dans
-- catalogue_correspondance_legacy, la table produite par l'audit L2, dont
-- chaque ligne porte sa preuve (colonne source_audit). Si demain une ligne y
-- est corrigee, il suffit de rejouer ces deux instructions.
--
-- PERIMETRE STRICT : categorie = 'objet' et generique_id encore nul. La
-- restauration (boisson/menu/plat/petit_dej/snack) et l'armurerie
-- (recettes_production) ne sont pas touchees -- leurs verticales ne sont pas
-- ouvertes.

-- 1. Correspondances NOMINATIVES (motif 'recette_id') : la preuve la plus forte,
--    une ligne d'audit par recette. Concerne le t-shirt, l'echarpe, la casquette.
update public.recettes_commerce r
   set generique_id = c.generique_id
  from public.catalogue_correspondance_legacy c
 where c.motif = 'recette_id'
   and c.valeur = r.id
   and r.categorie = 'objet'
   and r.generique_id is null;

-- 2. Correspondance par FAMILLE, limitee explicitement a la carte postale. Les
--    neuf cartes portent toutes famille_produit_marche = 'carte_postale', et
--    l'audit fait correspondre cette famille au generique carte-postale.
--    On n'etend PAS ce mecanisme a la famille 'aliment' : le choix entre les
--    generiques 'encas' et 'encas-a-emporter' n'est pas arbitre, et ces
--    produits relevent de la verticale restauration, qui reste fermee.
update public.recettes_commerce r
   set generique_id = c.generique_id
  from public.catalogue_correspondance_legacy c
 where c.motif = 'famille_produit_marche'
   and c.valeur = 'carte_postale'
   and c.valeur = r.famille_produit_marche
   and r.categorie = 'objet'
   and r.generique_id is null;

-- ---------------------------------------------------------------------------
-- FILTRAGE STRUCTUREL : ON NE PROPOSE QUE CE QUI SE FABRIQUE
-- ---------------------------------------------------------------------------
-- Le joueur pouvait choisir un generique, arriver au bout du parcours et lire
-- « Ce produit ne se fabrique pas ». Ce n'etait pas un defaut d'affichage : le
-- referentiel L2 compte 84 generiques et un seul etait raccorde a une recette.
--
-- La correction est structurelle et sans liste : un generique n'est propose que
-- s'il existe AU MOINS UNE recette systeme qui le produise. La verite decoule
-- des donnees -- raccorder demain une recette a un nouveau generique le rendra
-- proposable sans toucher une ligne de code, ici ou dans l'interface.
create or replace function public.fonds_generiques_accessibles(p_fonds_id text)
returns table (generique_id text, libelle text, famille_id text, famille text, types text[])
language sql
stable
security definer
set search_path to 'public'
as $$
  with f as (select data as d from public.entreprises where id = p_fonds_id),
  t as (select jsonb_array_elements_text(coalesce((select d->'typesAutorises' from f), '[]'::jsonb)) as type_id)
  select g.id, g.libelle, g.famille_id, fam.libelle,
         array_agg(distinct ty.id order by ty.id)
    from t
    join public.catalogue_generique_type gt on gt.type_id = t.type_id
    join public.catalogue_generiques g      on g.id = gt.generique_id
    join public.catalogue_familles fam      on fam.id = g.famille_id
    join public.catalogue_types ty          on ty.id = gt.type_id
   where exists (select 1 from public.recettes_commerce r where r.generique_id = g.id)
   group by g.id, g.libelle, g.famille_id, fam.libelle
   order by fam.libelle, g.libelle;
$$;

comment on function public.fonds_generiques_accessibles(text) is
  'Generiques qu''un fonds peut decliner en references : croisement de ses typesAutorises avec le referentiel L2, RESTREINT aux generiques pour lesquels il existe au moins une recette systeme. Un generique sans recette n''est jamais propose : le joueur ne peut plus aboutir a un produit non fabricable.';

revoke all on function public.fonds_generiques_accessibles(text) from public, anon, authenticated;
grant execute on function public.fonds_generiques_accessibles(text) to anon, authenticated, service_role;