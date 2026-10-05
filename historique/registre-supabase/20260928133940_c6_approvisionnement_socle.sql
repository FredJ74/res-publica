-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928133940
-- Nom original      : c6_approvisionnement_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-28 13:39:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8289ff376e645294c651e043f1c2ab86
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
insert into public.entreprises_constantes (cle, valeur) values
  ('stock_max_matiere_republic', 20)
on conflict (cle) do nothing;

create or replace function public.fonds_plafond_stock_matiere(p_pays text)
returns integer
language sql
stable
as $$
  select valeur::integer
    from public.entreprises_constantes
   where cle = 'stock_max_matiere_' || coalesce(nullif(btrim(p_pays), ''), '__aucun__');
$$;

comment on function public.fonds_plafond_stock_matiere(text) is
  'Plafond de stock d''une matiere premiere dans un fonds de commerce PJ. Politique economique PAR PAYS, lue dans entreprises_constantes. Rend NULL pour un pays non arbitre : aucune valeur n''est inventee, l''approvisionnement y est refuse.';

revoke all on function public.fonds_plafond_stock_matiere(text) from public, anon, authenticated;
grant execute on function public.fonds_plafond_stock_matiere(text) to anon, authenticated, service_role;

create or replace function public.fonds_acteur_present(p_acteur text, p_implantation jsonb)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE a record;
BEGIN
  IF p_acteur IS NULL OR p_implantation IS NULL THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR a.current_city IS NULL THEN RETURN false; END IF;
  RETURN coalesce(
       a.country          IS NOT DISTINCT FROM (p_implantation->>'country')
   AND a.current_city     IS NOT DISTINCT FROM (p_implantation->>'city')
   AND a.current_building IS NOT DISTINCT FROM (p_implantation->>'buildingId')
   AND a.current_room     IS NOT DISTINCT FROM (p_implantation->>'roomId'), false);
END; $$;

comment on function public.fonds_acteur_present(text, jsonb) is
  'Vrai si le personnage se trouve physiquement dans le local ou le fonds est implante. Compare personnages_donnees.current_* a data->implantation, comme pnj_co_present.';

revoke all on function public.fonds_acteur_present(text, jsonb) from public, anon, authenticated;
grant execute on function public.fonds_acteur_present(text, jsonb) to authenticated, service_role;

create or replace function public.fonds_matieres_recherchees(p_fonds_id text)
returns table (
  matiere        text,
  stock          numeric,
  maximum        integer,
  plafond_pays   integer,
  prix_achat     numeric,
  place_restante integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_pays text; v_plafond integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);

  RETURN QUERY
  WITH recettes AS (
    SELECT DISTINCT e.value->>'recette_id' AS rid
      FROM jsonb_each(coalesce(v_data->'references', '{}'::jsonb)) e
     WHERE nullif(btrim(coalesce(e.value->>'recette_id', '')), '') IS NOT NULL
  ), matieres AS (
    SELECT DISTINCT m.key AS cle
      FROM recettes r
      JOIN public.recettes_commerce rc ON rc.id = r.rid,
           jsonb_each(coalesce(rc.materiaux, '{}'::jsonb)) m
  )
  SELECT x.cle,
         x.stk,
         x.maxi,
         v_plafond,
         coalesce((v_data->'parametres'->'prixAchatMatiere'->>x.cle)::numeric,
                  (SELECT re.prix_achat_fournisseur FROM public.ressources_economie re WHERE re.cle = x.cle)),
         GREATEST(0, x.maxi - x.stk)::integer
    FROM (
      SELECT m.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>m.cle)::numeric, 0)) AS stk,
             LEAST(coalesce((v_data->'parametres'->'stockMaxMatieres'->>m.cle)::integer, coalesce(v_plafond, 0)),
                   coalesce(v_plafond, 0))::integer AS maxi
        FROM matieres m
    ) x
   ORDER BY x.cle;
END; $$;

comment on function public.fonds_matieres_recherchees(text) is
  'Matieres premieres qu''un fonds PJ recherche, DEDUITES des recettes systeme de ses references (actives ou non). Rend pour chacune le stock, le maximum choisi par le proprietaire, le plafond du pays, le prix de rachat affiche et la place restante.';

revoke all on function public.fonds_matieres_recherchees(text) from public, anon, authenticated;
grant execute on function public.fonds_matieres_recherchees(text) to anon, authenticated, service_role;