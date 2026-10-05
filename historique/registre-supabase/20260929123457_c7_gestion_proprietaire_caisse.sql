-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929123457
-- Nom original      : c7_gestion_proprietaire_caisse
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-29 12:34:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 598563b423b164405ef2e4144b796f58
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
create or replace function public.alimenter_caisse_fonds(
  p_acteur text, p_fonds_id text, p_montant integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_data    jsonb;
  v_m       integer := coalesce(p_montant, 0);
  v_proprio text;
  v_liquide numeric;
  v_caisse  numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_acteur,'') = '' OR coalesce(p_fonds_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_m <= 0 OR v_m IS DISTINCT FROM p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  v_proprio := v_data->>'proprietaire';
  IF v_proprio IS DISTINCT FROM p_acteur AND v_proprio IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  IF left(coalesce(v_proprio,''), 5) = 'orga:' THEN
    IF NOT public.mouvement_titulaire(v_proprio, -v_m) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  ELSE
    SELECT coalesce(liquide, 0) INTO v_liquide
      FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
    IF v_liquide IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent'); END IF;
    IF v_liquide < v_m THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'liquide_insuffisant',
                                'liquide', v_liquide); END IF;
    UPDATE public.personnages_donnees
       SET arg     = coalesce(arg, 0)     - v_m,
           liquide = coalesce(liquide, 0) - v_m,
           updated_at = now()
     WHERE name = p_acteur;
  END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_m)),
         updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse + v_m);
END; $fn$;

comment on function public.alimenter_caisse_fonds(text,text,integer) is
  'Le proprietaire d''un fonds de commerce verse du NUMERAIRE dans sa caisse. Exige l''identite de l''acteur. Debite arg ET liquide (une caisse contient des especes : un solde bancaire n''est pas debitable par cette voie), ou la caisse de l''organisation proprietaire. Transfert reel, jamais une creation de monnaie.';

create or replace function public.retirer_caisse_fonds(
  p_acteur text, p_fonds_id text, p_montant integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_data    jsonb;
  v_caisse  integer;
  v_m       integer := coalesce(p_montant, 0);
  v_proprio text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_acteur,'') = '' OR coalesce(p_fonds_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_m <= 0 OR v_m IS DISTINCT FROM p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  v_proprio := v_data->>'proprietaire';
  IF v_proprio IS DISTINCT FROM p_acteur AND v_proprio IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0))::integer;
  IF v_m > v_caisse THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse); END IF;

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_m)),
         updated_at = now()
   WHERE id = p_fonds_id;

  IF left(coalesce(v_proprio,''), 5) = 'orga:' THEN
    IF NOT public.mouvement_titulaire(v_proprio, v_m) THEN
      RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  ELSE
    UPDATE public.personnages_donnees
       SET arg     = coalesce(arg, 0)     + v_m,
           liquide = coalesce(liquide, 0) + v_m,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse - v_m);
END; $fn$;

comment on function public.retirer_caisse_fonds(text,text,integer) is
  'Le proprietaire reprend du NUMERAIRE dans la caisse de son fonds. Exige l''identite de l''acteur. Credite arg ET liquide, ou la caisse de l''organisation proprietaire. Ce n''est pas un revenu : ce qui sort de la caisse entre dans le patrimoine, et rien d''autre.';

revoke all on function public.alimenter_caisse_fonds(text,text,integer) from public, anon, authenticated;
grant execute on function public.alimenter_caisse_fonds(text,text,integer) to authenticated, service_role;

revoke all on function public.retirer_caisse_fonds(text,text,integer) from public, anon, authenticated;
grant execute on function public.retirer_caisse_fonds(text,text,integer) to authenticated, service_role;