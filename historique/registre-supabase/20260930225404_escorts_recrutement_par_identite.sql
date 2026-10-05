-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260930225404
-- Nom original      : escorts_recrutement_par_identite
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-30 22:54:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : af41a8397a044a95d950f59ead12c9fa
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
alter table public.pnj_employes_metier
  add column if not exists escort_id text;

comment on column public.pnj_employes_metier.escort_id is
  'Identite du catalogue que cet emploi instancie, pour le metier escort. Nul pour les autres metiers. C''est ce qui relie un contrat a une personne, et permet a deux joueurs d''employer la meme sans collision.';

update public.pnj_metiers_profils
   set quota_note = 'Aucun quota par genre depuis le 1er octobre 2026 : plusieurs escorts par joueur, c''est le game design. Seul subsiste le plafond commun de 10 employes.'
 where metier = 'escort';

create or replace function public.escort_recruter(p_escort_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_pays text; v_agence text; v_id text;
  v_esc  public.escorts_catalogue%ROWTYPE;
  v_prof public.pnj_metiers_profils%ROWTYPE;
  v_deja integer; v_pay jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_esc FROM public.escorts_catalogue
   WHERE escort_id = p_escort_id AND pays = v_pays AND actif;
  IF v_esc.escort_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'escort_inconnue'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'escort';
  IF v_prof.metier IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'employe' AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
                              'plafond', c_max_employes); END IF;

  v_id := public.employe_pnj_id(v_moi, 'escort', p_escort_id);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employee',
                              'pnj_id', v_id, 'nom', v_esc.nom); END IF;

  v_pay := public.debiter_fonds_ordinaires(v_moi, v_prof.cout_initial);
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse',
                              'paiement', v_pay, 'cout', v_prof.cout_initial); END IF;

  SELECT nom INTO v_agence FROM public.escorts_agences WHERE pays = v_pays;

  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
                                  leader_pj, pa, statut,
                                  car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', 'beta', v_esc.nom, v_pays, v_moi, v_moi, 12, 'actif',
          v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
          v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
    statut = 'actif', nom = EXCLUDED.nom,
    proprietaire_pj = EXCLUDED.proprietaire_pj, leader_pj = EXCLUDED.leader_pj,
    ville = NULL, building_id = NULL, room_id = NULL,
    car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
    car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
    maj_le = now();

  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre,
                                          escort_id, depuis_jour)
  VALUES (v_id, 'escort',
          'Escort — ' || coalesce(v_agence, 'Agence'),
          v_prof.cout_jour, v_esc.genre, v_esc.escort_id, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
    job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
    cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre,
    escort_id = EXCLUDED.escort_id;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id,
    'escort_id', v_esc.escort_id, 'nom', v_esc.nom, 'genre', v_esc.genre,
    'portrait', v_esc.portrait, 'vignette', v_esc.vignette, 'cadrage', v_esc.cadrage,
    'agence', v_agence, 'cout_jour', v_prof.cout_jour, 'cout_initial', v_prof.cout_initial,
    'caracteristiques', public.pnj_metier_profil('escort'),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END;
$fn$;

comment on function public.escort_recruter(text) is
  'Engage une escort du catalogue de l''empire OU SE TROUVE le joueur. Aucun quota par genre : plusieurs escorts par joueur. L''identifiant d''emploi derive de (proprietaire, escort_id), donc deux joueurs peuvent employer la meme personne, et un meme joueur ne peut pas l''employer deux fois. Le libelle de role vient de escorts_agences, jamais d''un litteral.';

revoke all on function public.escort_recruter(text) from public, anon;
grant execute on function public.escort_recruter(text) to authenticated, service_role;

create or replace function public.employe_metiers_recrutables()
returns text[]
language sql
immutable
as $fn$
  -- codetenu volontairement exclu : metier prevu, jamais active.
  -- escort retire le 1er octobre 2026 : elle se recrute par son identite, via
  -- escort_recruter(escort_id), qui valide contre le catalogue de l'empire.
  SELECT ARRAY['informateur']::text[];
$fn$;

comment on function public.employe_metiers_recrutables() is
  'Metiers que employe_recruter accepte encore. `escort` en a ete retire le 1er octobre 2026 : elle passe par escort_recruter(escort_id). Liste fermee : ajouter un metier ici l''ouvre au chemin generique.';