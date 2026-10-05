-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929123358
-- Nom original      : c7_gestion_proprietaire_matieres
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-29 12:33:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5f5eb1f2b77c8387918280b7618aae24
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
with reprise as (
  select e.id,
         public.fonds_plafond_stock_matiere(e.data->'implantation'->>'country') as plafond,
         coalesce(e.data->'parametres'->'stockMaxMatieres',  '{}'::jsonb) as maxis,
         coalesce(e.data->'parametres'->'matieresAcceptees', '{}'::jsonb) as oks
    from public.entreprises e
   where coalesce((e.data->>'version')::numeric, 0) >= 2
), cles as (
  select r.id, r.plafond, r.maxis, r.oks, t.cle
    from reprise r
    join lateral (
      select key as cle from jsonb_each(r.maxis)
      union
      select key from jsonb_each(r.oks)
    ) t on true
), traduites as (
  select c.id,
         jsonb_object_agg(c.cle, to_jsonb(
           case
             when not coalesce((c.oks->>c.cle)::boolean, false) then 0
             when coalesce((c.maxis->>c.cle)::integer, 0) = 0 then coalesce(c.plafond, 0)
             else least(greatest(0, (c.maxis->>c.cle)::integer), coalesce(c.plafond, 0))
           end)) as maxis
    from cles c
   group by c.id
)
update public.entreprises e
   set data = jsonb_set(
         jsonb_set(e.data, '{parametres,stockMaxMatieres}', t.maxis, true),
         '{parametres,matieresAcceptees}',
         (select coalesce(jsonb_object_agg(k.key, to_jsonb((k.value#>>'{}')::integer > 0)), '{}'::jsonb)
            from jsonb_each(t.maxis) k), true),
       updated_at = now()
  from traduites t
 where t.id = e.id;

create or replace function public.fonds_matieres_accessibles(p_fonds_id text)
returns table(matiere text, stock numeric, maximum integer, plafond_pays integer,
              prix_achat numeric, place_restante integer, acceptee boolean, utilisee boolean)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_defaut integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  v_defaut  := LEAST(2, coalesce(v_plafond, 0));

  RETURN QUERY
  WITH acces AS (
    SELECT DISTINCT m.key AS cle
      FROM public.fonds_generiques_accessibles(p_fonds_id) g
      JOIN LATERAL public.generique_recettes_systeme(g.generique_id) s ON true,
           jsonb_each(s.materiaux) m
  ), utilisees AS (
    SELECT DISTINCT m.key AS cle
      FROM jsonb_each(coalesce(v_data->'references', '{}'::jsonb)) e
      JOIN public.recettes_commerce rc ON rc.id = e.value->>'recette_id',
           jsonb_each(coalesce(rc.materiaux, '{}'::jsonb)) m
  )
  SELECT x.cle, x.stk, x.maxi, v_plafond,
         coalesce((v_data->'parametres'->'prixAchatMatiere'->>x.cle)::numeric,
                  (SELECT re.prix_achat_fournisseur FROM public.ressources_economie re
                    WHERE re.cle = x.cle)),
         GREATEST(0, x.maxi - x.stk)::integer,
         x.maxi > 0,
         EXISTS (SELECT 1 FROM utilisees u WHERE u.cle = x.cle)
    FROM (
      SELECT a.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>a.cle)::numeric, 0)) AS stk,
             LEAST(GREATEST(0, coalesce((v_data->'parametres'->'stockMaxMatieres'->>a.cle)::integer,
                                        v_defaut)),
                   coalesce(v_plafond, 0))::integer AS maxi
        FROM acces a
    ) x
   ORDER BY x.cle;
END; $fn$;

comment on function public.fonds_matieres_accessibles(text) is
  'Matieres qu''un fonds PJ PEUT manipuler, derivees de ses activites (typesAutorises -> generiques -> recettes -> materiaux), avec son stock, son stock maximum et son prix de rachat. LE MAXIMUM EST LA SEULE GRANDEUR : 0 signifie que le commerce refuse la matiere, un maximum non declare vaut 2, et le plafond du pays borne le tout. La colonne acceptee est CALCULEE (maximum > 0) et conservee pour la garde de fonds_matiere_apporter.';

revoke all on function public.fonds_matieres_accessibles(text) from public, anon, authenticated;
grant execute on function public.fonds_matieres_accessibles(text) to authenticated, service_role;

create or replace function public.fonds_matiere_parametres(
  p_acteur text, p_fonds_id text, p_matiere text,
  p_prix_achat numeric, p_maximum integer, p_acceptee boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_par jsonb; v_mat text; v_ok boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_mat := btrim(coalesce(p_matiere, ''));
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
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

  IF NOT EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(p_fonds_id) m
                  WHERE m.matiere = v_mat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites'); END IF;

  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  IF v_plafond IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini', 'pays', v_pays); END IF;

  IF p_prix_achat IS NULL OR p_prix_achat < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 OR p_maximum > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide',
                              'minimum', 0, 'maximum', v_plafond); END IF;

  v_ok := p_maximum > 0;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['prixAchatMatiere'],
             jsonb_set(coalesce(v_par->'prixAchatMatiere','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(round(p_prix_achat, 2))), true);
  v_par := jsonb_set(v_par, ARRAY['stockMaxMatieres'],
             jsonb_set(coalesce(v_par->'stockMaxMatieres','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(p_maximum)), true);
  v_par := jsonb_set(v_par, ARRAY['matieresAcceptees'],
             jsonb_set(coalesce(v_par->'matieresAcceptees','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(v_ok)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'matiere', v_mat,
                            'prixAchat', round(p_prix_achat, 2), 'maximum', p_maximum,
                            'acceptee', v_ok, 'plafondPays', v_plafond);
END; $fn$;

comment on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) is
  'Reglages d''une matiere pour un fonds PJ : prix de rachat libre et stock maximum (0 = le commerce n''en veut pas, borne par le plafond du pays). Le perimetre autorise est celui des ACTIVITES du commerce. p_acceptee est conserve pour la compatibilite de signature mais IGNORE : l''acceptation se deduit du maximum.';

revoke all on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) from public, anon, authenticated;
grant execute on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) to authenticated, service_role;