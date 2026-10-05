-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929211421
-- Nom original      : t1_terminal_section_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-29 21:14:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6e46b62eb6ebd47c5237a94531448148
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
create table if not exists public.militaire_terminal_requetes (
  requete   text primary key,
  acteur    text not null,
  action    text not null,
  resultat  jsonb not null,
  cree_le   timestamptz not null default now()
);
alter table public.militaire_terminal_requetes enable row level security;
revoke all on table public.militaire_terminal_requetes from public, anon, authenticated;

create or replace function public.militaire_ma_section(
  OUT o_moi text, OUT o_compagnie text, OUT o_section text,
  OUT o_data jsonb, OUT o_raison text)
returns record
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;

  SELECT c.id, s->>'id', c.data
    INTO o_compagnie, o_section, o_data
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
   WHERE s->>'lieutenantNom' = o_moi
     AND c.data->>'pays' = (SELECT country FROM public.personnages_donnees WHERE name = o_moi)
   LIMIT 1;

  IF o_compagnie IS NULL THEN o_raison := 'pas_lieutenant_de_section'; RETURN; END IF;
  o_raison := NULL;
END; $fn$;

comment on function public.militaire_ma_section() is
  'Section dont l''appelant est le Lieutenant structurel, resolue par le SERVEUR a partir de mon_personnage() : le client n''annonce aucun identifiant et n''a donc pas besoin de lire le blob des compagnies. Rend pas_lieutenant_de_section a tout autre joueur, y compris Capitaine, Commandant et Ministre de la Defense.';

revoke all on function public.militaire_ma_section() from public, anon, authenticated;
grant execute on function public.militaire_ma_section() to service_role;

create or replace function public.militaire_arme_operationnelle(p_pnj_id text)
returns text
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT coalesce(
    (SELECT b.cle FROM public.pnj_possessions p
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(p.objet->>'produitMilitaire', p.objet->>'name')
       WHERE p.pnj_id = p_pnj_id AND p.objet->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC, b.cle LIMIT 1),
    (SELECT b.cle FROM public.pnj_possessions p
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(p.objet->>'produitMilitaire', p.objet->>'name')
       WHERE p.pnj_id = p_pnj_id AND p.objet->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC, b.cle LIMIT 1),
    'corps_a_corps');
$fn$;

comment on function public.militaire_arme_operationnelle(text) is
  'Arme operationnelle d''un PNJ soldat, DEDUITE de ce qu''il porte reellement dans pnj_possessions. Meme regle que pour un joueur dans militaire_bataille_combattants : meilleur bonus, le tir primant le corps a corps, repli sur corps_a_corps.';

create or replace function public.militaire_arme_recalculer(p_pnj_id text)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_arme text; v_compagnie text;
BEGIN
  SELECT sm.compagnie_id INTO v_compagnie FROM public.pnj_soldats_metier sm WHERE sm.pnj_id = p_pnj_id;
  IF v_compagnie IS NULL THEN RETURN NULL; END IF;
  v_arme := public.militaire_arme_operationnelle(p_pnj_id);
  UPDATE public.pnj_soldats_metier SET arme = v_arme WHERE pnj_id = p_pnj_id;
  PERFORM public.militaire_blob_projeter(v_compagnie);
  RETURN v_arme;
END; $fn$;

comment on function public.militaire_arme_recalculer(text) is
  'Recalcule et ecrit l''arme operationnelle d''un PNJ soldat depuis ses possessions, puis reprojette le blob.';

create or replace function public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
returns table(eng_id bigint, est_pj boolean, nom text, compagnie_id text,
              section_id text, matricule text, pa integer, comp_tir numeric,
              comp_cac numeric, arme_feu boolean, arme_cle text, bonus_arme integer,
              def_per numeric, def_dup numeric, saute_round integer, groupe_id text)
language sql
stable
security definer
set search_path to 'public'
as $fn$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false,
         NULL::text,
         e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce(m.pa, 0)),
         coalesce((sm.formation->>'tir')::numeric, 0),
         coalesce((sm.formation->>'combat_rapproche')::numeric, 0),
         EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                  WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode = 'feu'),
         coalesce(sm.arme,'corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sm.arme,'corps_a_corps'),
           CASE WHEN EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                              WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode = 'feu')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.pnj_soldats_metier sm ON sm.matricule = e.matricule
    JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND m.id LIKE e.compagnie_id || '-%'
     AND sm.section_id = e.section_id;
$fn$;

comment on function public.militaire_bataille_combattants(bigint,text) is
  'Combattants d''un camp. Le mode (feu ou corps a corps) d''un PNJ est determine par militaire_armes_bonus et non plus par une paire de categories ecrite en dur : arme_de_poing et mitraillette conservent exactement 8 et 15 en feu.';

revoke all on function public.militaire_bataille_combattants(bigint,text) from public, anon, authenticated;
grant execute on function public.militaire_bataille_combattants(bigint,text) to service_role;

insert into public.pnj_possessions (pnj_id, objet, origine)
select sm.pnj_id,
       jsonb_build_object(
         'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
         'type', 'arme', 'sousType', 'militaire',
         'origineMilitaire', true, 'lot', 'reprise-t1',
         'produitMilitaire', sm.arme,
         'name', CASE sm.arme WHEN 'arme_de_poing' THEN 'Pistolet militaire'
                              WHEN 'mitraillette'  THEN 'Mitraillette' END,
         'icon', 'ti-crosshair', 'legal', true,
         'imageUrl', CASE sm.arme
           WHEN 'arme_de_poing' THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png'
           WHEN 'mitraillette'  THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png' END,
         'desc', 'Arme reglementaire de l''armee. Materialisee le 29 septembre 2026 '
              || 'lors du passage a l''armement deduit des possessions (lot T1).'),
       'socle'
  from public.pnj_soldats_metier sm
  join public.pnj_membres m on m.id = sm.pnj_id
 where m.statut = 'actif'
   and sm.arme in ('arme_de_poing', 'mitraillette')
   and not exists (
     select 1 from public.pnj_possessions p
      where p.pnj_id = sm.pnj_id and p.objet->>'type' = 'arme'
        and coalesce(p.objet->>'produitMilitaire', p.objet->>'name') = sm.arme);

update public.pnj_soldats_metier sm
   set arme = public.militaire_arme_operationnelle(sm.pnj_id)
  from public.pnj_membres m
 where m.id = sm.pnj_id and m.statut = 'actif'
   and sm.arme is distinct from public.militaire_arme_operationnelle(sm.pnj_id);