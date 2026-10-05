-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- contact_organisation_choisir(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contact_organisation_choisir(p_joueur text, p_type_organisation text, p_exclues jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_r jsonb;
BEGIN
  -- `organisations.data` est un blob JSON ecrit par le client : on le lit, on n'y
  -- ecrit rien, et on ne suppose la presence d'aucune cle.
  --
  -- Une organisation SANS CHEF est ecartee ici et non par l'appelant : il n'y a
  -- personne a qui ecrire, donc ce n'est pas un choix valide.
  --
  -- A nombre de membres egal, l'identifiant tranche. Pas un critere de jeu : la
  -- seule facon de rendre le resultat reproductible.
  SELECT jsonb_build_object(
           'id',      o.id,
           'nom',     coalesce(d->>'nom', 'une organisation'),
           'chef',    d->>'chef',
           'membres', jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)))
    INTO v_r
    FROM public.organisations o
    CROSS JOIN LATERAL (SELECT public.jsonb_ou_null(o.data) AS d) j
   WHERE d IS NOT NULL
     AND d->>'type' = p_type_organisation
     AND coalesce(d->>'chef', '') <> ''
     AND NOT (coalesce(p_exclues, '[]'::jsonb) ? o.id)
   ORDER BY jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)) DESC, o.id ASC
   LIMIT 1;
  RETURN v_r;
END;
$function$

-- contact_organisation_demander(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contact_organisation_demander(p_passeur text, p_type_organisation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi     text;
  v_passeur record;
  v_e       record;
  v_orga    jsonb;
  v_nom     text;
  v_corps   text;
  v_id      text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_passeur FROM public.contacts_organisations_passeurs p
   WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation;
  IF v_passeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  -- Verrou sur la ligne d'etat : deux clics simultanes ne doivent pas solliciter
  -- deux organisations d'un coup, ni deux fois la meme.
  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation
     FOR UPDATE;

  IF v_e IS NOT NULL AND now() < v_e.derniere_demande + interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
             'jours_restants', greatest(1, ceil(extract(epoch from
               (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer)); END IF;

  v_orga := public.contact_organisation_choisir(
              v_moi, p_type_organisation,
              coalesce(v_e.organisations_contactees, '[]'::jsonb));

  IF v_orga IS NULL THEN
    -- Le delai de trois jours N'EST PAS consomme : aucun message n'est parti.
    RETURN jsonb_build_object('ok', false, 'raison',
             CASE WHEN v_e IS NULL OR jsonb_array_length(v_e.organisations_contactees) = 0
                  THEN 'aucune_organisation' ELSE 'toutes_contactees' END); END IF;

  -- Le bouton ne voyage pas dans le HTML : marqueur textuel inerte, meme format
  -- que marqueurActionMail() cote navigateur.
  v_nom   := regexp_replace(v_moi, '[|\[\]]', '', 'g');
  v_corps := 'J''ai rencontré quelqu''un qui cherche un service. Contacte '
          || v_nom || ' de ma part.' || chr(10) || chr(10)
          || '[[act:ecrire_a|' || v_nom || ']]';

  v_id := 'co-' || (extract(epoch from clock_timestamp()) * 1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, v_passeur.expediteur, (v_orga->>'chef'), 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);

  INSERT INTO public.contacts_organisations
         (joueur, passeur, type_organisation, derniere_demande, organisations_contactees)
  VALUES (v_moi, p_passeur, p_type_organisation, now(), jsonb_build_array(v_orga->>'id'))
  ON CONFLICT (joueur, passeur, type_organisation) DO UPDATE
     SET derniere_demande = now(),
         organisations_contactees =
           public.contacts_organisations.organisations_contactees || jsonb_build_array(v_orga->>'id');

  -- Ne nomme PAS l'organisation : le passeur ne transmet aucun detail, dans les
  -- deux sens.
  RETURN jsonb_build_object('ok', true, 'rang',
           coalesce(jsonb_array_length(v_e.organisations_contactees), 0) + 1);
END;
$function$

-- contact_organisation_etat(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contact_organisation_etat(p_passeur text, p_type_organisation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_e record; v_restant integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contacts_organisations_passeurs p
                  WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation;

  IF v_e IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'peut_demander', true,
                              'jours_restants', 0, 'deja_contactees', 0); END IF;

  v_restant := greatest(0, ceil(extract(epoch from
                 (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer);

  RETURN jsonb_build_object(
    'ok', true,
    'peut_demander', (now() >= v_e.derniere_demande + interval '3 days'),
    'jours_restants', v_restant,
    'deja_contactees', jsonb_array_length(v_e.organisations_contactees));
END;
$function$

-- cron_journal_ecrire(text,date,text,text,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cron_journal_ecrire(p_tache text, p_jour date, p_statut text, p_erreur text DEFAULT NULL::text, p_contexte jsonb DEFAULT NULL::jsonb, p_duree_ms integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id  text;
  v_row public.cron_journal%ROWTYPE;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF p_tache IS NULL OR btrim(p_tache) = '' OR p_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_incomplets');
  END IF;
  IF p_statut NOT IN ('demarree','ok','echec','ignoree') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide');
  END IF;

  v_id := p_tache || ':' || p_jour::text;

  INSERT INTO public.cron_journal (id, tache, jour, statut, debut, fin, duree_ms, erreur, contexte)
  VALUES (
    v_id, p_tache, p_jour, p_statut, now(),
    CASE WHEN p_statut = 'demarree' THEN NULL ELSE now() END,
    p_duree_ms, left(p_erreur, 2000), p_contexte
  )
  ON CONFLICT (id) DO UPDATE SET
    statut     = EXCLUDED.statut,
    -- Le premier debut est conserve : un reessai doit rester lisible comme un
    -- reessai, pas se maquiller en premiere execution.
    fin        = CASE WHEN EXCLUDED.statut = 'demarree' THEN NULL ELSE now() END,
    duree_ms   = coalesce(EXCLUDED.duree_ms, public.cron_journal.duree_ms),
    erreur     = EXCLUDED.erreur,
    contexte   = coalesce(EXCLUDED.contexte, public.cron_journal.contexte),
    tentatives = public.cron_journal.tentatives
                 + CASE WHEN EXCLUDED.statut = 'demarree' THEN 1 ELSE 0 END
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'ok', true, 'id', v_row.id, 'statut', v_row.statut, 'tentatives', v_row.tentatives
  );
END;
$function$

-- don_argent_deposer(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.don_argent_deposer(p_requete text, p_destinataire text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_deja record; v_id bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_requete), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;
  IF COALESCE(btrim(p_destinataire), '') = '' OR p_destinataire = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;

  -- Rejeu : meme requete = meme resultat, aucun second debit.
  SELECT * INTO v_deja FROM public.dons_requetes WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'montant', v_deja.montant,
                              'destinataire', v_deja.destinataire);
  END IF;

  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  -- CONTREPARTIE REELLE : sans debit effectif, aucun depot. Fail-closed.
  IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  INSERT INTO public.dons_en_attente (destinataire, montant, expediteur, traite)
  VALUES (p_destinataire, p_montant, v_moi, false)
  RETURNING id INTO v_id;

  INSERT INTO public.dons_requetes (requete, expediteur, destinataire, montant, don_id)
  VALUES (p_requete, v_moi, p_destinataire, p_montant, v_id);

  RETURN jsonb_build_object('ok', true, 'don_id', v_id, 'montant', p_montant,
    'expediteur', v_moi, 'destinataire', p_destinataire,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END;
$function$

-- employe_liberer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_liberer(p_pnj_id text, p_motif text DEFAULT 'licenciement'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_m record; v_job text;
BEGIN
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_m FROM public.pnj_membres WHERE id = p_pnj_id FOR UPDATE;
  IF v_m.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'employe_introuvable'); END IF;
  IF v_m.famille IS DISTINCT FROM 'employe' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_employe', 'famille', v_m.famille); END IF;
  IF v_moi IS NOT NULL AND v_m.proprietaire_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_employe'); END IF;

  SELECT e.job INTO v_job FROM public.pnj_employes_metier e WHERE e.pnj_id = p_pnj_id;

  IF v_m.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', true, 'deja_parti', true,
      'pnj_id', p_pnj_id, 'metier', v_job); END IF;

  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
   WHERE id = p_pnj_id;
  RETURN jsonb_build_object('ok', true, 'pnj_id', p_pnj_id, 'metier', v_job, 'motif', p_motif);
END; $function$

-- employe_mes_employes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_mes_employes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'employes', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'pnj_id', m.id, 'nom', m.nom, 'metier', e.job, 'role', e.role_libelle,
             'genre', e.genre, 'cout_jour', e.cout_jour, 'pa', m.pa, 'liquide', m.liquide,
             'porte', (m.leader_pj = v_moi),
             'caracteristiques', public.pnj_caracteristiques_base(m.id))
           ORDER BY e.job, m.nom)
      FROM public.pnj_membres m JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
     WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'), '[]'::jsonb));
END; $function$

-- employe_metiers_recrutables() -> text[] | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_metiers_recrutables()
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(array_agg(metier order by metier), array[]::text[])
    from public.pnj_metiers_profils
   where recrutable;
$function$

-- employe_pnj_id(text,text,text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.employe_pnj_id(p_proprietaire text, p_metier text, p_nom text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'emp-' || p_metier || '-' || substr(md5(lower(btrim(p_proprietaire)) || '|' ||
                                                 lower(btrim(p_nom))), 1, 12);
$function$

-- employe_recruter(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_recruter(p_metier text, p_nom text, p_genre text DEFAULT NULL::text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT NULL::integer, p_cost integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb;
  v_pa integer; v_cost integer; v_deja integer; v_quota integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT (p_metier = ANY (public.employe_metiers_recrutables())) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
      'metier', COALESCE(p_metier, '<NULL>'),
      'recrutables', public.employe_metiers_recrutables()); END IF;
  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;
  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = p_metier;
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;
  SELECT count(*) INTO v_deja
    FROM public.pnj_membres m WHERE m.famille = 'employe'
     AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
      'plafond', c_max_employes); END IF;
  IF p_metier = 'escort' THEN
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'
                  AND e.job = 'escort' AND e.genre IS NOT DISTINCT FROM p_genre) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'genre', p_genre); END IF;
  ELSE
    v_quota := COALESCE(v_prof.quota_par_joueur, 1);
    SELECT count(*) INTO v_nb FROM public.pnj_membres m
      JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
     WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif' AND e.job = p_metier;
    IF v_nb >= v_quota THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'quota', v_quota, 'employes', v_nb); END IF;
  END IF;
  v_id := public.employe_pnj_id(v_moi, p_metier, v_nom);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employe', 'pnj_id', v_id); END IF;
  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSIF v_cost > 0 THEN
    v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;
  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', COALESCE(v_prof.classe, 'beta'), v_nom,
      (SELECT COALESCE(country, 'republic') FROM public.personnages_donnees WHERE name = v_moi),
      v_moi, v_moi, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', classe = EXCLUDED.classe,
      proprietaire_pj = EXCLUDED.proprietaire_pj,
      leader_pj = EXCLUDED.leader_pj, ville = NULL, building_id = NULL, room_id = NULL,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();
  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre, depuis_jour)
  VALUES (v_id, p_metier,
          COALESCE(v_prof.role_libelle,
                   CASE p_metier WHEN 'escort' THEN 'Escort — Agence Roxane Velours'
                                 WHEN 'informateur' THEN 'Informateur'
                                 ELSE initcap(p_metier) END),
          COALESCE(v_prof.cout_jour, 0), p_genre, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
      job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
      cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre;
  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'metier', p_metier, 'nom', v_nom,
    'genre', p_genre, 'cout_jour', COALESCE(v_prof.cout_jour, 0),
    'cout_initial', v_cost, 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(p_metier),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END; $function$

-- employeur_candidats(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employeur_candidats(p_employeur_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  c_max_employes constant integer := 10;
  v_moi text; v_pays text;
  v_emp public.pnj_employeurs%rowtype;
  v_deja integer;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); end if;
  select coalesce(country, 'republic') into v_pays
    from public.personnages_donnees where name = v_moi;
  select * into v_emp from public.pnj_employeurs
   where employeur_id = p_employeur_id and pays = v_pays and actif;
  if v_emp.employeur_id is null then
    return jsonb_build_object('ok', false, 'raison', 'employeur_inconnu'); end if;
  select count(*) into v_deja from public.pnj_membres m
   where m.famille = 'employe' and m.proprietaire_pj = v_moi and m.statut = 'actif';
  return jsonb_build_object(
    'ok', true,
    'employeur_id', v_emp.employeur_id,
    'employeur', v_emp.nom,
    'pays', v_pays,
    'plafond_employes', c_max_employes,
    'employes_actuels', v_deja,
    'metiers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'metier',           pr.metier,
               'libelle',          pr.role_libelle,
               'recrutable',       pr.recrutable,
               'cout_embauche',    coalesce(pr.cout_initial, 0),
               'cout_jour',        coalesce(pr.cout_jour, 0),
               'pa',               coalesce(pr.pa_initial, 0),
               'quota',            coalesce(pr.quota_par_joueur, 1),
               'employes',         (select count(*) from public.pnj_membres m
                                      join public.pnj_employes_metier e on e.pnj_id = m.id
                                     where m.proprietaire_pj = v_moi and m.statut = 'actif'
                                       and e.job = pr.metier),
               'caracteristiques', public.pnj_metier_profil(pr.metier))
             order by pr.metier)
        from public.pnj_metiers_profils pr
       where pr.metier in (select c.metier from public.pnj_candidats_catalogue c
                            where c.employeur_id = v_emp.employeur_id and c.actif)
    ), '[]'::jsonb),
    'candidats', coalesce((
      select jsonb_agg(jsonb_build_object(
               'candidat_id',  c.candidat_id,
               'metier',       c.metier,
               'nom',          c.nom,
               'genre',        c.genre,
               'accroche',     c.accroche,
               'portrait',     c.portrait,
               'vignette',     c.vignette,
               'cadrage',      c.cadrage,
               'deja_employe', exists (select 1 from public.pnj_membres m
                                         join public.pnj_employes_metier e on e.pnj_id = m.id
                                        where m.proprietaire_pj = v_moi and m.statut = 'actif'
                                          and e.candidat_id = c.candidat_id))
             order by c.metier, c.rang, c.nom)
        from public.pnj_candidats_catalogue c
       where c.employeur_id = v_emp.employeur_id and c.actif
    ), '[]'::jsonb));
end;
$function$

-- employeur_embaucher(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employeur_embaucher(p_candidat_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  c_max_employes constant integer := 10;
  v_moi text; v_pays text; v_id text; v_libelle text;
  v_cand public.pnj_candidats_catalogue%rowtype;
  v_emp  public.pnj_employeurs%rowtype;
  v_prof public.pnj_metiers_profils%rowtype;
  v_deja integer; v_quota integer; v_nb integer;
  v_pa integer; v_cost integer; v_pay jsonb; v_caisse jsonb := null;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); end if;
  select coalesce(country, 'republic') into v_pays
    from public.personnages_donnees where name = v_moi;
  select * into v_cand from public.pnj_candidats_catalogue
   where candidat_id = p_candidat_id and actif;
  if v_cand.candidat_id is null then
    return jsonb_build_object('ok', false, 'raison', 'candidat_inconnu'); end if;
  select * into v_emp from public.pnj_employeurs
   where employeur_id = v_cand.employeur_id and actif;
  if v_emp.employeur_id is null then
    return jsonb_build_object('ok', false, 'raison', 'employeur_inconnu'); end if;
  if v_emp.pays <> v_pays then
    return jsonb_build_object('ok', false, 'raison', 'employeur_hors_pays'); end if;
  select * into v_prof from public.pnj_metiers_profils where metier = v_cand.metier;
  if v_prof.metier is null then
    return jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); end if;
  if not v_prof.recrutable then
    return jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
                              'metier', v_cand.metier); end if;
  select count(*) into v_deja from public.pnj_membres m
   where m.famille = 'employe' and m.proprietaire_pj = v_moi and m.statut = 'actif';
  if v_deja >= c_max_employes then
    return jsonb_build_object('ok', false, 'raison', 'plafond_employes',
                              'plafond', c_max_employes); end if;
  v_quota := coalesce(v_prof.quota_par_joueur, 1);
  select count(*) into v_nb from public.pnj_membres m
    join public.pnj_employes_metier e on e.pnj_id = m.id
   where m.proprietaire_pj = v_moi and m.statut = 'actif' and e.job = v_cand.metier;
  if v_nb >= v_quota then
    return jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
      'metier', v_cand.metier, 'quota', v_quota, 'employes', v_nb); end if;
  v_id := public.employe_pnj_id(v_moi, v_cand.metier, v_cand.candidat_id);
  if exists (select 1 from public.pnj_membres where id = v_id and statut = 'actif') then
    return jsonb_build_object('ok', false, 'raison', 'deja_employe',
                              'pnj_id', v_id, 'nom', v_cand.nom); end if;
  if v_prof.ordre_fn is not null then
    v_pa   := coalesce(v_prof.pa_initial, 0);
    v_cost := coalesce(v_prof.cout_initial, 0);
    if not exists (select 1 from public.ordres_couts o
                    where o.fn = v_prof.ordre_fn and o.pa = v_pa and o.cost = v_cost) then
      return jsonb_build_object('ok', false, 'raison', 'ordre_non_declare',
                                'fn', v_prof.ordre_fn, 'pa', v_pa, 'cout', v_cost); end if;
    v_pay := public.payer_ordre(v_moi, v_prof.ordre_fn, v_pa, v_cost);
  else
    v_pa   := 0;
    v_cost := coalesce(v_prof.cout_initial, 0);
    if v_cost > 0 then v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
                  else v_pay := jsonb_build_object('ok', true, 'montant', 0); end if;
  end if;
  if coalesce((v_pay->>'ok')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'raison', 'paiement_refuse',
                              'paiement', v_pay, 'cout', v_cost); end if;
  if v_emp.caisse_id is not null and v_cost > 0 then
    perform set_config('rp.caisse_interne', 'on', true);
    v_caisse := public.caisse_institution_mouvement(v_emp.caisse_id, v_cost, false);
  end if;
  insert into public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  values (v_id, 'employe', coalesce(v_prof.classe, 'beta'), v_cand.nom, v_pays,
      v_moi, v_moi, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  on conflict (id) do update set
      statut = 'actif', nom = excluded.nom, classe = excluded.classe,
      proprietaire_pj = excluded.proprietaire_pj, leader_pj = excluded.leader_pj,
      ville = null, building_id = null, room_id = null,
      car_int = excluded.car_int, car_cha = excluded.car_cha, car_vol = excluded.car_vol,
      car_per = excluded.car_per, car_dup = excluded.car_dup, car_ent = excluded.car_ent,
      maj_le = now();
  v_libelle := coalesce(v_prof.role_libelle, initcap(v_cand.metier)) || ' — ' || v_emp.nom;
  insert into public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour,
      genre, photo_url, photo_pos, candidat_id, depuis_jour)
  values (v_id, v_cand.metier, v_libelle, coalesce(v_prof.cout_jour, 0),
      v_cand.genre, v_cand.portrait, v_cand.cadrage, v_cand.candidat_id, null)
  on conflict (pnj_id) do update set
      job = excluded.job, role_libelle = excluded.role_libelle,
      cout_jour = excluded.cout_jour, genre = excluded.genre,
      photo_url = excluded.photo_url, photo_pos = excluded.photo_pos,
      candidat_id = excluded.candidat_id;
  return jsonb_build_object('ok', true,
    'pnj_id', v_id, 'candidat_id', v_cand.candidat_id, 'metier', v_cand.metier,
    'nom', v_cand.nom, 'genre', v_cand.genre, 'accroche', v_cand.accroche,
    'portrait', v_cand.portrait, 'vignette', v_cand.vignette, 'cadrage', v_cand.cadrage,
    'role_libelle', v_libelle,
    'employeur_id', v_emp.employeur_id, 'employeur', v_emp.nom,
    'cout_embauche', v_cost, 'cout_jour', coalesce(v_prof.cout_jour, 0), 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(v_cand.metier),
    'paiement', v_pay, 'caisse_agence', v_caisse,
    'employes', v_deja + 1, 'plafond', c_max_employes,
    'quota', v_quota, 'employes_metier', v_nb + 1);
end;
$function$

-- escort_recruter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_recruter(p_escort_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$

-- escort_sociale_actuelle() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_sociale_actuelle()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_id text; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT c.escort_id INTO v_id FROM public.pnj_social_escort_choisi c WHERE c.joueur = v_moi;
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'escort_id', NULL); END IF;
  SELECT nom INTO v_nom FROM public.escorts_catalogue WHERE escort_id = v_id;
  RETURN jsonb_build_object('ok', true, 'escort_id', v_id, 'nom', v_nom);
END;
$function$

-- escort_sociale_choisir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_sociale_choisir(p_escort_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_avant text; v_avant_nom text;
  v_esc public.escorts_catalogue%ROWTYPE;
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

  SELECT c.escort_id INTO v_avant
    FROM public.pnj_social_escort_choisi c WHERE c.joueur = v_moi;
  IF v_avant IS NOT DISTINCT FROM p_escort_id THEN
    RETURN jsonb_build_object('ok', true, 'inchange', true,
                              'escort_id', p_escort_id, 'nom', v_esc.nom); END IF;
  SELECT nom INTO v_avant_nom FROM public.escorts_catalogue WHERE escort_id = v_avant;

  INSERT INTO public.pnj_social_escort_choisi (joueur, escort_id, choisi_le)
       VALUES (v_moi, p_escort_id, now())
  ON CONFLICT (joueur) DO UPDATE
     SET escort_id = EXCLUDED.escort_id, choisi_le = now();

  INSERT INTO public.pnj_social_relations (pnj_id, joueur)
       VALUES (p_escort_id, v_moi)
  ON CONFLICT (pnj_id, joueur) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'escort_id', p_escort_id, 'nom', v_esc.nom,
                            'precedente', v_avant, 'precedente_nom', v_avant_nom);
END;
$function$

-- escorts_agence() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escorts_agence()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_agence text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT nom INTO v_agence FROM public.escorts_agences WHERE pays = v_pays;
  IF v_agence IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'agence', NULL,
                              'escorts', '[]'::jsonb); END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pays', v_pays, 'agence', v_agence,
    'escorts', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'escort_id', c.escort_id, 'nom', c.nom, 'genre', c.genre,
               'portrait', c.portrait, 'vignette', c.vignette, 'cadrage', c.cadrage)
             ORDER BY c.genre, c.rang, c.nom)
        FROM public.escorts_catalogue c
       WHERE c.pays = v_pays AND c.actif), '[]'::jsonb));
END;
$function$

-- naturalisation_traiter(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.naturalisation_traiter(p_demande_id text, p_accepter boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_acteur text; v_pays text; v_d record; v_rembours integer := 0; v_id bigint;
BEGIN
  -- Autorite : exiger_poste leve si le compte n'est pas le Ministre de l'Interieur en exercice.
  v_acteur := public.exiger_poste('min_int');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  SELECT * INTO v_d FROM public.demandes_naturalisation
   WHERE id = p_demande_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable');
  END IF;
  -- Un ministre ne traite que les demandes visant SON pays.
  IF v_d.pays_vise IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF COALESCE(v_d.statut, 'pending') <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'statut', v_d.statut);
  END IF;
  -- Delai de 48 h : la ligne porte deja l'echeance, le serveur la fait respecter.
  IF v_d.date_traitement_possible IS NOT NULL
     AND (EXTRACT(epoch FROM now()) * 1000) < v_d.date_traitement_possible THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule');
  END IF;

  IF p_accepter THEN
    UPDATE public.demandes_naturalisation SET statut = 'acceptee' WHERE id = p_demande_id;
    RETURN jsonb_build_object('ok', true, 'statut', 'acceptee', 'demandeur', v_d.demandeur);
  END IF;

  -- REFUS : remboursement de la moitie, montant relu sur la ligne, jamais fourni par le client.
  v_rembours := floor(COALESCE(v_d.montant, 0) * 0.5)::integer;
  UPDATE public.demandes_naturalisation SET statut = 'refusee' WHERE id = p_demande_id;
  IF v_rembours > 0 THEN
    INSERT INTO public.dons_en_attente (destinataire, montant, expediteur, traite)
    VALUES (v_d.demandeur, v_rembours, 'Service de l''Immigration', false)
    RETURNING id INTO v_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', 'refusee', 'demandeur', v_d.demandeur,
                            'remboursement', v_rembours, 'don_id', v_id);
END;
$function$

-- personnage_ajuster_pop_inf(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_cible text, p_pop integer, p_inf integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  IF COALESCE(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF COALESCE(abs(p_pop), 0) > 100 OR COALESCE(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;
  UPDATE public.personnages
     SET resources = (
           CASE WHEN p_inf IS NULL THEN r.base
                ELSE jsonb_set(r.base, '{inf}', to_jsonb(GREATEST(0, LEAST(100,
                  COALESCE(CASE WHEN jsonb_typeof(r.base -> 'inf') = 'number' THEN (r.base ->> 'inf')::numeric END, 0) + p_inf))))
           END)
    FROM (SELECT jsonb_set(
            CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
            '{pop}', to_jsonb(GREATEST(0, LEAST(100,
              COALESCE(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number' THEN (pp.resources ->> 'pop')::numeric END, 50)
              + COALESCE(p_pop, 0))))) AS base
            FROM public.personnages pp WHERE pp.name = p_cible) r
   WHERE public.personnages.name = p_cible
   RETURNING public.personnages.resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$function$

-- personnage_ajuster_pop_inf(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_acteur text, p_cible text, p_pop integer, p_inf integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_res jsonb; v_base jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF coalesce(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF coalesce(abs(p_pop), 0) > 100 OR coalesce(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;

  SELECT jsonb_set(
           CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
           '{pop}', to_jsonb(greatest(0, least(100,
             coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                           THEN (pp.resources ->> 'pop')::numeric END, 50)
             + coalesce(p_pop, 0)))))
    INTO v_base
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  UPDATE public.personnages_donnees
     SET resources = CASE WHEN p_inf IS NULL THEN v_base
            ELSE jsonb_set(v_base, '{inf}', to_jsonb(greatest(0, least(100,
                   coalesce(CASE WHEN jsonb_typeof(v_base -> 'inf') = 'number'
                                 THEN (v_base ->> 'inf')::numeric END, 0) + p_inf))))
          END
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$function$

-- personnage_ajuster_pop_inf(text,text,integer,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_acteur text, p_cible text, p_pop integer, p_inf integer, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_res jsonb; v_base jsonb;
  v_poste text; v_pays text;
  v_min integer; v_max integer;
  v_serveur boolean := public.est_appel_serveur();
BEGIN
  IF NOT v_serveur THEN PERFORM public.exiger_acteur(p_acteur); END IF;

  IF coalesce(btrim(coalesce(p_cible,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  -- Aucune mecanique du jeu ne modifie l'INF d'un AUTRE personnage aujourd'hui : l'influence
  -- d'une organisation est une autre jauge, portee par la table organisations. On refuse donc,
  -- plutot que de laisser une porte ouverte sans usage.
  IF p_inf IS NOT NULL AND NOT v_serveur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inf_sans_cause');
  END IF;

  SELECT pd.poste->>'id', pd.country INTO v_poste, v_pays
    FROM public.personnages_donnees pd WHERE pd.name = p_acteur;

  -- REGISTRE DES CAUSES. Chaque ligne = une mecanique reelle, son autorite et son amplitude.
  IF v_serveur THEN
    v_min := -100; v_max := 100;

  ELSIF p_cause = 'rumeur_pj' THEN
    -- Action grise ouverte a tout joueur. Perte tiree dans 5..20 (appliquerEffetRumeur).
    v_min := -20; v_max := -5;

  ELSIF p_cause = 'rumeur_gouvernement' THEN
    -- Meme action, cible gouvernementale. Perte tiree dans 1..5, appliquee a chaque titulaire.
    v_min := -5; v_max := -1;

  ELSIF p_cause = 'excommunication' THEN
    -- Reserve au Grand Pretre national en exercice. Le Grand Pretre n'est pas un poste porte par
    -- la fiche : c'est la ligne titulaires_pnj(pays, 'grand_pretre', NULL), que le client compare
    -- deja au nom du joueur (estGrandPretreActuel). Meme source de verite cote serveur.
    IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj t
                    WHERE t.poste_id = 'grand_pretre' AND t.city IS NULL
                      AND t.nom_pnj = p_acteur) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'grand_pretre');
    END IF;
    v_min := -15; v_max := -15;

  ELSIF p_cause IN ('dementi_reussi', 'dementi_rate') THEN
    -- Ordre « Dementi officiel » : requiresPost president (palais) ou min_info (ministere).
    IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_info') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    IF p_cause = 'dementi_reussi' THEN v_min := 1; v_max := 100;
    ELSE v_min := -100; v_max := -1; END IF;

  ELSIF p_cause = 'sentence_torture' THEN
    -- Ordre « Rendre la sentence » : requiresPost juge. -100 ramene la POP exactement a zero.
    IF v_poste IS DISTINCT FROM 'juge' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    v_min := -100; v_max := -100;

  ELSIF p_cause = 'football_match' THEN
    -- Gain de popularite d'un titulaire apres un match : +20 (participation) ou +30 (victoire).
    -- RESIDU ASSUME : le championnat n'a pas de moteur serveur, il avance depuis les navigateurs
    -- des joueurs. Aucun poste ne peut donc etre exige ici. L'amplitude est bornee aux deux
    -- seules valeurs declarees et le sens est POSITIF : le pire abus possible est d'elever la POP
    -- d'un personnage, jamais de l'abaisser. Fermeture definitive = moteur serveur du championnat.
    IF coalesce(p_pop,0) NOT IN (20, 30) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                                'cause', p_cause, 'pop', p_pop);
    END IF;
    v_min := 20; v_max := 30;

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_non_declaree', 'cause', p_cause);
  END IF;

  IF coalesce(p_pop, 0) < v_min OR coalesce(p_pop, 0) > v_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                              'cause', p_cause, 'pop', p_pop, 'min', v_min, 'max', v_max);
  END IF;

  SELECT jsonb_set(
           CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
           '{pop}', to_jsonb(greatest(0, least(100,
             coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                           THEN (pp.resources ->> 'pop')::numeric END, 50)
             + coalesce(p_pop, 0)))))
    INTO v_base
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  UPDATE public.personnages_donnees
     SET resources = CASE WHEN p_inf IS NULL THEN v_base
            ELSE jsonb_set(v_base, '{inf}', to_jsonb(greatest(0, least(100,
                   coalesce(CASE WHEN jsonb_typeof(v_base -> 'inf') = 'number'
                                 THEN (v_base ->> 'inf')::numeric END, 0) + p_inf))))
          END
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf',
                            'cause', p_cause);
END;
$function$

-- personnages_archiver_suppression() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_archiver_suppression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_claims jsonb; v_role text;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_claims := NULL;
  END;

  v_role := nullif(current_setting('role', true), 'none');
  IF v_role IS NULL OR v_role = '' THEN v_role := session_user; END IF;

  INSERT INTO public.personnages_supprimes
    (personnage_id, nom, user_id, ligne, chemin, origine,
     role_sql, session_sql, jwt_role, jwt_sub, application, client_addr,
     backend_pid, transaction_id, requete)
  VALUES (
    OLD.id, OLD.name, OLD.user_id, to_jsonb(OLD),
    CASE WHEN coalesce(current_setting('rp.suppression_via_vue', true), '') = '1'
         THEN 'vue' ELSE 'direct' END,
    nullif(current_setting('rp.suppression_origine', true), ''),
    v_role, session_user,
    v_claims ->> 'role', v_claims ->> 'sub',
    nullif(current_setting('application_name', true), ''),
    inet_client_addr(),
    pg_backend_pid(),
    txid_current()::text,
    left(coalesce(current_query(), ''), 2000));

  RETURN OLD;
END;
$function$

-- personnages_attester_poste() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_attester_poste()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    IF NOT public.poste_est_atteste(NEW.name, NEW.poste, NEW.country) THEN
      NEW.poste := NULL;
    END IF;
    IF NOT public.poste_est_atteste(NEW.name, NEW.poste_depute, NEW.country) THEN
      NEW.poste_depute := NULL;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.poste IS DISTINCT FROM OLD.poste
     AND NOT public.poste_est_atteste(NEW.name, NEW.poste, NEW.country) THEN
    NEW.poste := OLD.poste;
  END IF;
  IF NEW.poste_depute IS DISTINCT FROM OLD.poste_depute
     AND NOT public.poste_est_atteste(NEW.name, NEW.poste_depute, NEW.country) THEN
    NEW.poste_depute := OLD.poste_depute;
  END IF;
  RETURN NEW;
END;
$function$

-- personnages_borner_jour() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_borner_jour()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Le serveur (cron, RPC, service_role) n'est pas concerne : lui peut corriger, reparer,
  -- rattraper un retard. La borne ne vise que ce qui vient d'un navigateur.
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;

  IF NEW.day IS DISTINCT FROM OLD.day AND coalesce(NEW.day, 0) > coalesce(OLD.day, 0) + 1 THEN
    NEW.day := coalesce(OLD.day, 0) + 1;
  END IF;

  -- Le jour ne recule pas non plus : une peine ne s'annule pas en revenant en arriere.
  IF coalesce(NEW.day, 0) < coalesce(OLD.day, 0) THEN
    NEW.day := OLD.day;
  END IF;

  RETURN NEW;
END;
$function$

-- personnages_fusionner_pop() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_base numeric;
  v_old  numeric;
  v_client boolean := NOT public.est_appel_serveur();
BEGIN
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'popBase') = 'number' THEN (NEW.resources ->> 'popBase')::numeric END;
    NEW.resources := NEW.resources - 'popBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'pop') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{pop}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'pop')::numeric - v_base)))));
    END IF;
  ELSIF TG_OP = 'UPDATE' AND v_client AND jsonb_typeof(NEW.resources) = 'object' THEN
    -- Pas de base annoncee : le navigateur ne decide pas d'une valeur absolue.
    IF jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN
      NEW.resources := jsonb_set(NEW.resources, '{pop}', OLD.resources -> 'pop');
    ELSE
      NEW.resources := NEW.resources - 'pop';
    END IF;
  END IF;

  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'infBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'infBase') = 'number' THEN (NEW.resources ->> 'infBase')::numeric END;
    NEW.resources := NEW.resources - 'infBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'inf') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN (OLD.resources ->> 'inf')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{inf}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'inf')::numeric - v_base)))));
    END IF;
  ELSIF TG_OP = 'UPDATE' AND v_client AND jsonb_typeof(NEW.resources) = 'object' THEN
    IF jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN
      NEW.resources := jsonb_set(NEW.resources, '{inf}', OLD.resources -> 'inf');
    ELSE
      NEW.resources := NEW.resources - 'inf';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$

-- personnages_lien_militaire_rompu() -> trigger | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.personnages_lien_militaire_rompu()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_ancien text; v_nouveau text;
BEGIN
  v_ancien  := coalesce(OLD.poste->>'id', '');
  v_nouveau := coalesce(NEW.poste->>'id', '');

  IF v_ancien = 'lieutenant' AND v_nouveau IS DISTINCT FROM 'lieutenant' THEN
    -- OLD porte la DERNIERE position canonique connue du chef : c'est la que ses hommes restent.
    PERFORM public.militaire_lien_operationnel_rompre(
      OLD.name, OLD.current_city, OLD.current_building, OLD.current_room);
  END IF;

  IF v_ancien IN ('lieutenant','capitaine','commandant') AND v_nouveau IS DISTINCT FROM v_ancien THEN
    PERFORM public.militaire_service_fermer(OLD.name, v_ancien);
  END IF;

  -- Prise de fonction : la periode s'ouvre au moment ou le poste est reellement porte par la
  -- fiche, quel que soit le chemin (RPC de nomination, tirage au sort, cron).
  IF v_nouveau IN ('lieutenant','capitaine','commandant') AND v_nouveau IS DISTINCT FROM v_ancien THEN
    PERFORM public.militaire_service_ouvrir(NEW.name, coalesce(NEW.country,'republic'), v_nouveau,
              NEW.poste->>'compagnieId', NEW.poste->>'sectionId');
  END IF;

  RETURN NEW;
END;
$function$

-- personnages_lien_militaire_supprime() -> trigger | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.personnages_lien_militaire_supprime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.militaire_lien_operationnel_rompre(
    OLD.name, OLD.current_city, OLD.current_building, OLD.current_room);
  RETURN OLD;
END;
$function$

-- personnages_lier_proprietaire() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_lier_proprietaire()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- L'autorite est auth.uid(), jamais NEW.user_id fourni par l'appelant.
    IF auth.uid() IS NOT NULL THEN
      NEW.user_id := auth.uid();
    ELSE
      NEW.user_id := NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- 2) A la mise a jour : user_id est IMMUABLE cote client. Seul le serveur
  --    (service_role) peut le changer -- transfert de personnage, reparation.
  --    Sans ca, un joueur pourrait s'attribuer le personnage d'un autre d'un
  --    simple PATCH, ce qui reduirait a neant tout le reste du chantier.
  IF NEW.user_id IS DISTINCT FROM OLD.user_id AND NOT public.est_appel_serveur() THEN
    NEW.user_id := OLD.user_id;
  END IF;
  RETURN NEW;
END;
$function$

-- personnages_observer_inventaire() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_observer_inventaire()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant int; v_apres int; v_ajoutes jsonb;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF NEW.inventory IS NOT DISTINCT FROM OLD.inventory THEN RETURN NEW; END IF;

  v_avant := CASE WHEN jsonb_typeof(OLD.inventory)='array' THEN jsonb_array_length(OLD.inventory) ELSE 0 END;
  v_apres := CASE WHEN jsonb_typeof(NEW.inventory)='array' THEN jsonb_array_length(NEW.inventory) ELSE 0 END;
  IF v_apres <= v_avant THEN RETURN NEW; END IF;   -- retrait ou remplacement : hors sujet

  -- Les identifiants apparus, sans le reste de l'objet (les images base64 n'ont rien a faire ici).
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', o->>'id', 'name', o->>'name',
                                               'type', o->>'type', 'pm', o->>'produitMilitaire')), '[]'::jsonb)
    INTO v_ajoutes
    FROM jsonb_array_elements(NEW.inventory) o
   WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(OLD.inventory,'[]'::jsonb)) a
                      WHERE a->>'id' = o->>'id');

  INSERT INTO public.fiche_inventaire_observe
         (personnage, avant, apres, delta, objets_ajoutes, role_sql, requete)
  VALUES (NEW.name, v_avant, v_apres, v_apres - v_avant, left(v_ajoutes::text, 2000)::jsonb,
          coalesce(nullif(current_setting('role', true), 'none'), session_user),
          left(coalesce(current_query(), ''), 300));

  RETURN NEW;
END;
$function$

-- personnages_poste_perdu() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_poste_perdu()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.poste IS NOT NULL AND jsonb_typeof(OLD.poste) = 'object'
     AND (NEW.poste IS NULL OR jsonb_typeof(NEW.poste) = 'null'
          OR (NEW.poste ->> 'id') IS DISTINCT FROM (OLD.poste ->> 'id')
          OR (NEW.poste ->> 'city') IS DISTINCT FROM (OLD.poste ->> 'city')) THEN
    DELETE FROM public.postes_attribues
     WHERE titulaire = OLD.name
       AND poste_id = (OLD.poste ->> 'id')
       AND country = OLD.country
       AND city IS NOT DISTINCT FROM nullif(OLD.poste ->> 'city', '');
  END IF;
  RETURN NULL;
END;
$function$

-- personnages_preserver_judiciaire() -> trigger | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.personnages_preserver_judiciaire()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_elem   jsonb;
  v_old    jsonb;
  v_convs  jsonb;
  v_hist   jsonb;
BEGIN
  -- ---------------------------------------------------------------- CONVOCATIONS
  IF NEW.convocations IS DISTINCT FROM OLD.convocations THEN
    v_convs := '[]'::jsonb;

    -- 1. On part de la version entrante, en y reportant les drapeaux monotones de l'ancienne.
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(NEW.convocations, '[]'::jsonb)) LOOP
      SELECT o.value INTO v_old
        FROM jsonb_array_elements(COALESCE(OLD.convocations, '[]'::jsonb)) o
       WHERE public.assemblee_cle_convocation(o.value) = public.assemblee_cle_convocation(v_elem)
       LIMIT 1;

      IF v_old IS NOT NULL THEN
        IF COALESCE((v_old->>'traitee')::boolean, false) THEN
          v_elem := v_elem || jsonb_build_object('traitee', true);
        END IF;
        IF COALESCE((v_old->>'echue')::boolean, false) THEN
          v_elem := v_elem || jsonb_build_object('echue', true, 'echueTs', v_old->'echueTs');
        END IF;
      END IF;

      v_convs := v_convs || jsonb_build_array(v_elem);
      v_old := NULL;
    END LOOP;

    -- 2. Toute convocation connue de la base mais absente de la version entrante est reinjectee.
    FOR v_old IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.convocations, '[]'::jsonb)) LOOP
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_convs) n
         WHERE public.assemblee_cle_convocation(n.value) = public.assemblee_cle_convocation(v_old)
      ) THEN
        v_convs := v_convs || jsonb_build_array(v_old);
      END IF;
    END LOOP;

    NEW.convocations := v_convs;
  END IF;

  -- ---------------------------------------------------------------- HISTORIQUE DES CRIMES
  IF NEW.historique_crimes IS DISTINCT FROM OLD.historique_crimes THEN
    v_hist := COALESCE(NEW.historique_crimes, '[]'::jsonb);

    FOR v_old IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.historique_crimes, '[]'::jsonb)) LOOP
      IF v_old->>'origine' = 'serveur'
         AND v_old ? 'id'
         AND (v_old->>'expireTs' IS NULL OR now() < (v_old->>'expireTs')::timestamptz)
         AND NOT EXISTS (
           SELECT 1 FROM jsonb_array_elements(v_hist) n WHERE n.value->>'id' = v_old->>'id'
         )
      THEN
        v_hist := v_hist || jsonb_build_array(v_old);
      END IF;
    END LOOP;

    NEW.historique_crimes := v_hist;
  END IF;

  RETURN NEW;
END;
$function$

-- personnages_vue_inserer() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_vue_inserer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'creation_sans_compte' USING ERRCODE = '42501';
    END IF;
    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
    NEW.pa := least(coalesce(NEW.pa, 10), 10);
    -- DOTATION DE DEPART : au plus la meilleure combinaison possible du jeu.
    NEW.arg     := greatest(0, least(coalesce(NEW.arg, 0), 5000));
    NEW.liquide := greatest(0, least(coalesce(NEW.liquide, 0), NEW.arg));
    NEW.banque  := greatest(0, least(coalesce(NEW.banque, 0), NEW.arg));
  END IF;

  INSERT INTO public.personnages_donnees (
    id, name, country, photo_url, bio, archetype, career, origin, school,
    free_pts_restants, stats, resources, arg, liquide, banque, hp, pa, moral,
    poste, poste_depute, current_city, current_building, current_room, inventory,
    informateurs, contacts, historique_crimes, enquetes_en_cours, domicile,
    employes, escort_active, locations_actives, poison_actif, day, recherche,
    reputation_criminelle, salutations_du_jour, invitation_sociale_en_attente,
    convocations, est_emprisonne, detention_qhs, hospitalisation, stats_affaiblies,
    regen_jour, requisition, demandeur_emploi, carte_postale_moral_jour, motto,
    licence_sportive, performance_sportive, blessure_sportive, signature_html,
    signature_blocks, quete_accueil, enigme1, maxence, succes_maxence, journal,
    excommunie, reservation_hotel, qualifications, effets_actifs, bonus_lobbyiste,
    dernier_dormir, salaire_touche, dernier_objet_trouve_jour, photo_pos,
    user_id, created_at, updated_at, quete_carriere
  ) VALUES (
    coalesce(NEW.id, gen_random_uuid()), NEW.name, NEW.country, NEW.photo_url, NEW.bio,
    NEW.archetype, NEW.career, NEW.origin, NEW.school,
    coalesce(NEW.free_pts_restants, 0), NEW.stats, NEW.resources, NEW.arg, NEW.liquide,
    NEW.banque, NEW.hp, NEW.pa, NEW.moral, NEW.poste, NEW.poste_depute,
    NEW.current_city, NEW.current_building, NEW.current_room, NEW.inventory,
    NEW.informateurs, NEW.contacts, NEW.historique_crimes, NEW.enquetes_en_cours, NEW.domicile,
    NEW.employes, NEW.escort_active, NEW.locations_actives, NEW.poison_actif, NEW.day,
    NEW.recherche, NEW.reputation_criminelle, NEW.salutations_du_jour,
    NEW.invitation_sociale_en_attente, NEW.convocations, NEW.est_emprisonne,
    NEW.detention_qhs, NEW.hospitalisation, coalesce(NEW.stats_affaiblies, '{}'::jsonb),
    NEW.regen_jour, NEW.requisition, coalesce(NEW.demandeur_emploi, false),
    NEW.carte_postale_moral_jour, NEW.motto, NEW.licence_sportive, NEW.performance_sportive,
    NEW.blessure_sportive, NEW.signature_html, NEW.signature_blocks, NEW.quete_accueil,
    NEW.enigme1, NEW.maxence, NEW.succes_maxence, NEW.journal, NEW.excommunie,
    NEW.reservation_hotel, coalesce(NEW.qualifications, '[]'::jsonb),
    coalesce(NEW.effets_actifs, '[]'::jsonb), coalesce(NEW.bonus_lobbyiste, 0),
    NEW.dernier_dormir, NEW.salaire_touche, NEW.dernier_objet_trouve_jour, NEW.photo_pos,
    NEW.user_id, coalesce(NEW.created_at, now()), coalesce(NEW.updated_at, now()),
    NEW.quete_carriere
  );
  RETURN NEW;
END; $function$

-- personnages_vue_modifier() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_canon public.personnages_donnees%rowtype;
  v_role  text := coalesce(nullif(current_setting('role', true), ''), session_user);
  v_req   text := left(coalesce(current_query(), ''), 500);
  v_verrou boolean;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF auth.uid() IS NULL
       OR OLD.user_id IS NULL
       OR OLD.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_canon FROM public.personnages_donnees WHERE id = OLD.id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501';
    END IF;

    NEW.user_id := v_canon.user_id;

    IF coalesce(NEW.pa, 0) > coalesce(v_canon.pa, 0) THEN
      NEW.pa := v_canon.pa;
    END IF;

    NEW.stats             := v_canon.stats;
    NEW.free_pts_restants := v_canon.free_pts_restants;
    NEW.qualifications    := v_canon.qualifications;
    NEW.banque            := v_canon.banque;

    v_verrou := public.rp_transition_active('argent_verrou');

    IF coalesce(NEW.arg, 0) > coalesce(v_canon.arg, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'arg', v_canon.arg, NEW.arg, coalesce(NEW.arg,0) - coalesce(v_canon.arg,0), v_role, v_req);
      IF v_verrou THEN NEW.arg := v_canon.arg; END IF;
    END IF;
    IF coalesce(NEW.liquide, 0) > coalesce(v_canon.liquide, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'liquide', v_canon.liquide, NEW.liquide, coalesce(NEW.liquide,0) - coalesce(v_canon.liquide,0), v_role, v_req);
      IF v_verrou THEN NEW.liquide := v_canon.liquide; END IF;
    END IF;
    IF coalesce(NEW.hp, 0) > coalesce(v_canon.hp, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'hp', v_canon.hp, NEW.hp, coalesce(NEW.hp,0) - coalesce(v_canon.hp,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.day, 0) > coalesce(v_canon.day, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'day', v_canon.day, NEW.day, coalesce(NEW.day,0) - coalesce(v_canon.day,0), v_role, v_req);
    END IF;

    NEW.arg       := coalesce(NEW.arg,       v_canon.arg);
    NEW.liquide   := coalesce(NEW.liquide,   v_canon.liquide);
    NEW.inventory := coalesce(NEW.inventory, v_canon.inventory);
  END IF;

  -- PLAFOND DU JOURNAL PERSONNEL : 500 ENTREES (24 septembre 2026, regle validee).
  -- Le journal est empile par la tete (unshift cote client) : on garde donc les 500
  -- PREMIERES, c'est-a-dire les plus recentes, et on abandonne les plus anciennes.
  -- Plafond de RETENTION, applique a toute ecriture, serveur comprise -- ce n'est pas un
  -- controle d'autorite. Aucune fiche reelle n'est concernee (120 entrees au maximum) :
  -- cette migration ne transforme aucune donnee existante.
  IF jsonb_typeof(NEW.journal) = 'array' AND jsonb_array_length(NEW.journal) > 500 THEN
    SELECT jsonb_agg(e ORDER BY ord) INTO NEW.journal
      FROM jsonb_array_elements(NEW.journal) WITH ORDINALITY AS t(e, ord) WHERE ord <= 500;
  END IF;

  UPDATE public.personnages_donnees SET
    name = NEW.name, country = NEW.country, photo_url = NEW.photo_url, bio = NEW.bio,
    archetype = NEW.archetype, career = NEW.career, origin = NEW.origin, school = NEW.school,
    free_pts_restants = NEW.free_pts_restants, stats = NEW.stats, resources = NEW.resources,
    arg = NEW.arg, liquide = NEW.liquide, banque = NEW.banque,
    hp = NEW.hp, pa = NEW.pa, moral = NEW.moral, poste = NEW.poste, poste_depute = NEW.poste_depute,
    current_city = NEW.current_city, current_building = NEW.current_building, current_room = NEW.current_room,
    inventory = NEW.inventory, informateurs = NEW.informateurs, contacts = NEW.contacts,
    historique_crimes = NEW.historique_crimes, enquetes_en_cours = NEW.enquetes_en_cours,
    domicile = NEW.domicile, employes = NEW.employes, escort_active = NEW.escort_active,
    locations_actives = NEW.locations_actives, poison_actif = NEW.poison_actif, day = NEW.day,
    recherche = NEW.recherche, reputation_criminelle = NEW.reputation_criminelle,
    salutations_du_jour = NEW.salutations_du_jour,
    invitation_sociale_en_attente = NEW.invitation_sociale_en_attente,
    convocations = NEW.convocations, est_emprisonne = NEW.est_emprisonne,
    detention_qhs = NEW.detention_qhs, hospitalisation = NEW.hospitalisation,
    stats_affaiblies = NEW.stats_affaiblies, regen_jour = NEW.regen_jour,
    requisition = NEW.requisition, demandeur_emploi = NEW.demandeur_emploi,
    carte_postale_moral_jour = NEW.carte_postale_moral_jour, motto = NEW.motto,
    licence_sportive = NEW.licence_sportive, performance_sportive = NEW.performance_sportive,
    blessure_sportive = NEW.blessure_sportive, signature_html = NEW.signature_html,
    signature_blocks = NEW.signature_blocks, quete_accueil = NEW.quete_accueil,
    enigme1 = NEW.enigme1, maxence = NEW.maxence, succes_maxence = NEW.succes_maxence,
    journal = NEW.journal, excommunie = NEW.excommunie, reservation_hotel = NEW.reservation_hotel,
    qualifications = NEW.qualifications, effets_actifs = NEW.effets_actifs,
    bonus_lobbyiste = NEW.bonus_lobbyiste, dernier_dormir = NEW.dernier_dormir,
    salaire_touche = NEW.salaire_touche, dernier_objet_trouve_jour = NEW.dernier_objet_trouve_jour,
    photo_pos = NEW.photo_pos, user_id = NEW.user_id, updated_at = NEW.updated_at,
    quete_carriere = NEW.quete_carriere
  WHERE id = OLD.id;
  RETURN NEW;
END;
$function$

-- personnages_vue_supprimer() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_vue_supprimer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF OLD.user_id IS NULL OR OLD.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;
  END IF;
  PERFORM set_config('rp.suppression_via_vue', '1', true);   -- true = LOCAL
  DELETE FROM public.personnages_donnees WHERE id = OLD.id;
  PERFORM set_config('rp.suppression_via_vue', '', true);
  RETURN OLD;
END; $function$

-- referent_pedagogie_contexte(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.referent_pedagogie_contexte(p_referent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_moi    text;
  v_n      integer := 0;
  v_sujets jsonb   := '[]'::jsonb;
  FENETRE  constant interval := interval '10 days';
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'pas_de_personnage');
  end if;

  select coalesce(p.consultations, 0),
         coalesce(
           (select jsonb_agg(c.libelle order by c.libelle)
              from jsonb_each_text(coalesce(p.sujets, '{}'::jsonb)) as s(cle, quand)
              join public.pnj_referents_sujets_connus c
                on c.referent_id = p_referent_id and c.sujet = s.cle
             where (s.quand)::timestamptz > now() - FENETRE),
           '[]'::jsonb)
    into v_n, v_sujets
    from public.pnj_referents_pedagogie p
   where p.referent_id = p_referent_id and p.joueur = v_moi;

  return jsonb_build_object('ok', true,
                            'consultations', coalesce(v_n, 0),
                            'sujets', coalesce(v_sujets, '[]'::jsonb));
end;
$function$

-- referent_pedagogie_noter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.referent_pedagogie_noter(p_referent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = p_referent_id) THEN
    RETURN jsonb_build_object('ok', true, 'referent', false); END IF;

  INSERT INTO public.pnj_referents_pedagogie (referent_id, joueur, consultations)
       VALUES (p_referent_id, v_moi, 1)
  ON CONFLICT (referent_id, joueur) DO UPDATE
     SET consultations = public.pnj_referents_pedagogie.consultations + 1,
         derniere_le   = now();

  SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
   WHERE referent_id = p_referent_id AND joueur = v_moi;
  RETURN jsonb_build_object('ok', true, 'referent', true, 'consultations', v_n);
END;
$function$

-- referent_pedagogie_noter_sujet(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.referent_pedagogie_noter_sujet(p_referent_id text, p_sujet text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_moi text;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'pas_de_personnage');
  end if;

  if not exists (
    select 1 from public.pnj_referents_sujets_connus
     where referent_id = p_referent_id and sujet = p_sujet
  ) then
    return jsonb_build_object('ok', false, 'raison', 'sujet_inconnu');
  end if;

  insert into public.pnj_referents_pedagogie (referent_id, joueur)
  values (p_referent_id, v_moi)
  on conflict (referent_id, joueur) do nothing;

  -- L'horodatage ECRASE le precedent : reparler d'un sujet le rafraichit.
  update public.pnj_referents_pedagogie
     set sujets = coalesce(sujets, '{}'::jsonb)
                  || jsonb_build_object(p_sujet, to_jsonb(now())),
         derniere_le = now()
   where referent_id = p_referent_id and joueur = v_moi;

  return jsonb_build_object('ok', true);
end;
$function$
