-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928134019
-- Nom original      : c6_apport_matiere_et_maximums
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-28 13:40:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 95bfcc874e2cc57a42a6f4fe78a8efbc
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
create or replace function public.fonds_matiere_parametres(
  p_acteur text, p_fonds_id text, p_matiere text,
  p_prix_achat numeric, p_maximum integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_pays text; v_plafond integer; v_par jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(btrim(p_matiere),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  IF NOT EXISTS (SELECT 1 FROM public.fonds_matieres_recherchees(p_fonds_id) m
                  WHERE m.matiere = btrim(p_matiere)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_recherchee'); END IF;

  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  IF v_plafond IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini', 'pays', v_pays); END IF;

  IF p_prix_achat IS NULL OR p_prix_achat < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 OR p_maximum > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide',
                              'minimum', 0, 'maximum', v_plafond); END IF;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['prixAchatMatiere'],
             jsonb_set(coalesce(v_par->'prixAchatMatiere','{}'::jsonb),
                       ARRAY[btrim(p_matiere)], to_jsonb(round(p_prix_achat, 2))), true);
  v_par := jsonb_set(v_par, ARRAY['stockMaxMatieres'],
             jsonb_set(coalesce(v_par->'stockMaxMatieres','{}'::jsonb),
                       ARRAY[btrim(p_matiere)], to_jsonb(p_maximum)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'matiere', btrim(p_matiere),
                            'prixAchat', round(p_prix_achat, 2), 'maximum', p_maximum,
                            'plafondPays', v_plafond);
END; $$;

comment on function public.fonds_matiere_parametres(text, text, text, numeric, integer) is
  'Le proprietaire fixe le prix de rachat (libre, >= 0) et le stock maximum (0..plafond du pays) d''une matiere de son fonds. Ecrit uniquement data->parametres->prixAchatMatiere et ->stockMaxMatieres.';

revoke all on function public.fonds_matiere_parametres(text, text, text, numeric, integer) from public, anon, authenticated;
grant execute on function public.fonds_matiere_parametres(text, text, text, numeric, integer) to authenticated, service_role;

create or replace function public.fonds_reference_stock_max(
  p_acteur text, p_fonds_id text, p_reference_id text, p_maximum integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE v_data jsonb; v_par jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_data->'references'->p_reference_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['stockMaxReferences'],
             jsonb_set(coalesce(v_par->'stockMaxReferences','{}'::jsonb),
                       ARRAY[p_reference_id], to_jsonb(p_maximum)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id, 'maximum', p_maximum);
END; $$;

comment on function public.fonds_reference_stock_max(text, text, text, integer) is
  'Stock maximum souhaite pour UNE reference (data->parametres->stockMaxReferences). Grandeur DISTINCTE du maximum des matieres. Stockee et affichee ; volontairement non opposee a la production tant que le comportement du depassement par le rendement d''une recette n''est pas arbitre.';

revoke all on function public.fonds_reference_stock_max(text, text, text, integer) from public, anon, authenticated;
grant execute on function public.fonds_reference_stock_max(text, text, text, integer) to authenticated, service_role;

create table if not exists public.apports_matieres (
  requete        text primary key,
  cree_le        timestamptz not null default now(),
  fonds_id       text not null,
  acteur         text not null,
  matiere        text not null,
  mode           text not null check (mode in ('vente', 'don')),
  quantite       integer not null check (quantite > 0),
  prix_unitaire  numeric not null default 0,
  montant        numeric not null default 0
);

create index if not exists apports_matieres_fonds_idx on public.apports_matieres (fonds_id, cree_le desc);

alter table public.apports_matieres enable row level security;
revoke all on table public.apports_matieres from public, anon, authenticated;
grant select on table public.apports_matieres to service_role;

comment on table public.apports_matieres is
  'Journal des apports de matiere premiere a un fonds PJ (vente ou don). La cle de requete porte l''idempotence. Ecrit uniquement par fonds_matiere_apporter (SECURITY DEFINER) ; ferme au client.';