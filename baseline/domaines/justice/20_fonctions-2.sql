-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- dossiers_actes_append_only() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossiers_actes_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'dossiers_judiciaires_actes est append-only : % refuse', TG_OP;
END;
$function$;

-- dossiers_actes_publier_au_journal() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossiers_actes_publier_au_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_f record; v_prevenu text; v_libelle text; v_data jsonb;
BEGIN
  SELECT * INTO v_f FROM public.justice_faits_publics WHERE type_acte = NEW.type;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT (p.data::jsonb) ->> 'cible' INTO v_prevenu
    FROM public.plaintes_en_cours p WHERE p.id = NEW.affaire;
  IF v_prevenu IS NULL THEN RETURN NEW; END IF;

  v_libelle := format(v_f.phrase, v_prevenu);

  IF NEW.type = 'audience_ouverte'
     AND coalesce((NEW.donnees ->> 'procureur_present')::boolean, true) IS FALSE THEN
    v_libelle := v_libelle || ', en l''absence du Procureur';
  END IF;

  v_data := jsonb_build_object(
    'affaire', NEW.affaire, 'acte', NEW.type,
    'categorie', (SELECT public.affaire_categorie_publique(p.data::jsonb)
                    FROM public.plaintes_en_cours p WHERE p.id = NEW.affaire));
  IF NEW.type = 'audience_ouverte' THEN
    v_data := v_data || jsonb_build_object(
      'procureur_present', coalesce((NEW.donnees ->> 'procureur_present')::boolean, true),
      'prevenu_present', coalesce((NEW.donnees ->> 'prevenu_present')::boolean, true));
  END IF;

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref, created_at)
  VALUES ('chronique-' || v_f.chronique_type || '-' || NEW.rang::text,
          NEW.pays, v_f.chronique_type, NEW.ville,
          jsonb_build_array(v_prevenu), v_libelle, v_data, NEW.affaire, now())
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END $function$;

-- dossiers_auditions_append_only() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossiers_auditions_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'dossiers_auditions est append-only : un proces-verbal ne se reecrit pas (% refuse)', TG_OP;
END;
$function$;

-- enquete_garde_a_vue(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.enquete_garde_a_vue(p_cible text, p_motif text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_enquetes jsonb; v_jour integer; v_pays text; v_ok boolean := false;
  v_e jsonb; v_res jsonb; v_jours integer := 2;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT enquetes_en_cours, coalesce(day, 1), country
    INTO v_enquetes, v_jour, v_pays
    FROM public.personnages_donnees WHERE name = v_acteur;

  -- L'enquete doit exister SUR LA FICHE DE L'APPELANT, viser cette cible, et etre arrivee a terme.
  FOR v_e IN SELECT e FROM jsonb_array_elements(coalesce(v_enquetes, '[]'::jsonb)) e LOOP
    IF v_e->>'cible' = p_cible AND coalesce((v_e->>'day')::int, 999999) <= v_jour THEN
      v_ok := true;
      EXIT;
    END IF;
  END LOOP;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_enquete_arrivee_a_terme');
  END IF;

  v_res := public.detention_ouvrir_interne(
             p_cible,
             coalesce(nullif(p_motif, ''), 'Garde a vue suite a enquete'),
             v_jours,
             coalesce(nullif(p_ville, ''), 'capitale'),
             coalesce(v_e->>'country', v_pays, 'republic'),
             jsonb_build_array(jsonb_build_object(
               'type', coalesce(nullif(p_motif, ''), 'Garde a vue suite a enquete'),
               'jour_fait', coalesce((v_e->>'day')::int, v_jour),
               'city', coalesce(nullif(p_ville, ''), 'capitale'),
               'jours', v_jours,
               'source', 'garde_a_vue',
               'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_acteur,
             'garde_a_vue');
  RETURN v_res;
END; $function$;

-- enquete_ouvrir(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.enquete_ouvrir(p_type_cible text, p_cible text, p_nom_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_paie jsonb; v_caisse jsonb; v_reussi boolean; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_poste IS DISTINCT FROM 'min_just' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_min_just'); END IF;
  IF p_type_cible NOT IN ('citoyen', 'club_sportif', 'entreprise', 'organisation') OR coalesce(p_cible, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF p_type_cible = 'citoyen' AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  v_nom := coalesce(nullif(btrim(p_nom_cible), ''), p_cible);
  v_paie := public.payer_ordre(v_moi, 'ouvrir_enquete', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_caisse := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_just', -400, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF coalesce((v_caisse ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'enquete_ouvrir: caisse insuffisante' USING ERRCODE = 'P0001', HINT = 'caisse_insuffisante';
  END IF;
  v_reussi := random() < 0.9;
  IF v_reussi THEN
    PERFORM public.annonce_publique_interne(v_pays, '🔍 Le Ministère de la Justice ouvre une enquête sur ' || v_nom || '.');
    IF p_type_cible = 'citoyen' THEN
      PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', p_cible, 'Enquête ouverte',
        'Une enquête judiciaire a été ouverte à votre sujet.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'cout', 400) || jsonb_build_object('paie', v_paie);
EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM LIKE 'enquete_ouvrir: caisse insuffisante%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
  END IF;
  RAISE;
END; $function$;

-- fait_judiciaire_declare(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fait_judiciaire_declare(p_type text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.justice_faits_publics f
                  WHERE f.chronique_type = p_type);
$function$;

-- fraude_electorale_sanctionner(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fraude_electorale_sanctionner(p_fraude_id text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_contestataire text; v_f record; v_res jsonb; v_arg_contest numeric;
  v_amende integer := 500; v_recompense integer := 200; v_jours integer := 2;
  v_raison text; v_ville text;
BEGIN
  v_contestataire := public.mon_personnage();
  IF v_contestataire IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- 1. LA FRAUDE, dans la table canonique, verrouillee avant tout effet.
  SELECT * INTO v_f FROM public.fraudes_electorales WHERE id = p_fraude_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fraude_introuvable');
  END IF;
  IF coalesce(v_f.etat, '') = 'revelee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fraude_deja_revelee');
  END IF;
  IF coalesce(v_f.auteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inconnu');
  END IF;

  -- 2. LA REVELATION EST LE VERROU : rejeu et concurrence butent ici.
  UPDATE public.fraudes_electorales
     SET etat = 'revelee', revelee_par = v_contestataire, revelee_le = now()
   WHERE id = p_fraude_id;

  v_ville := coalesce(nullif(p_ville, ''), v_f.city, 'capitale');
  v_raison := 'Fraude électorale (' || replace(coalesce(v_f.type, 'fraude'), '_', ' ')
              || ') révélée par contestation';

  -- 3. L'AMENDE. Le montant vient d'ici, jamais de l'appelant.
  PERFORM public.amende_imposer_interne('fraude-'||p_fraude_id, v_f.country, v_f.auteur, v_amende);

  -- 4. LA DETENTION, par la primitive canonique -- 2 jours, la peine de ce chemin.
  v_res := public.detention_ouvrir_interne(
             v_f.auteur, v_raison, v_jours, v_ville, v_f.country,
             jsonb_build_array(jsonb_build_object(
               'type', v_raison, 'jours', v_jours, 'city', v_ville,
               'source', 'fraude_revelee_contestation',
               'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_contestataire, 'fraude_revelee');

  -- 5. LA RECOMPENSE du contestataire, dans la meme transaction.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_recompense
   WHERE name = v_contestataire
   RETURNING arg INTO v_arg_contest;

  RETURN jsonb_build_object(
    'ok', true, 'fraudeur', v_f.auteur, 'type', v_f.type, 'amende', v_amende,
    'jours', v_jours, 'recompense', v_recompense, 'arg_contestataire', v_arg_contest,
    'detention_id', v_res->>'detention_id',
    'detention_ouverte', coalesce((v_res->>'ok')::boolean, false),
    'detention_raison', v_res->>'raison');
END; $function$;

-- fraude_electorale_tenter(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fraude_electorale_tenter(p_type text, p_poste text, p_city text, p_candidat text, p_sens integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_fn text; v_pa integer; v_base integer; v_jours integer; v_city text;
  v_row record; v_cycle jsonb; v_now bigint := (extract(epoch FROM now()) * 1000)::bigint;
  v_paie jsonb; v_dis numeric; v_taux integer; v_roll integer; v_rang integer; v_delta integer;
  v_raison text; v_det jsonb; v_libelle text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, poste ->> 'id' AS poste, domicile, resources INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  CASE p_type
    WHEN 'falsification_listes' THEN v_fn := 'falsifier_listes_electorales'; v_pa := 2; v_base := 70; v_jours := 20;
    WHEN 'bourrage_urnes' THEN v_fn := 'bourrer_urnes'; v_pa := 1; v_base := 60; v_jours := 1;
    WHEN 'trucage_depouillement' THEN v_fn := 'truquer_depouillement'; v_pa := 2; v_base := 75; v_jours := 20;
    ELSE RETURN jsonb_build_object('ok', false, 'raison', 'fraude_inconnue');
  END CASE;
  IF p_type = 'falsification_listes' AND (d.poste IS NULL OR d.poste NOT IN ('maire', 'maire_adjoint') OR p_poste <> 'maire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acces_refuse'); END IF;
  IF p_type = 'trucage_depouillement' AND (d.poste IS NULL OR d.poste NOT IN ('commissaire', 'juge')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acces_refuse'); END IF;
  IF p_type = 'bourrage_urnes' AND coalesce(d.domicile ->> 'country', d.country) IS DISTINCT FROM d.country THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acces_refuse'); END IF;
  IF p_poste NOT IN ('president', 'chef_syndicat', 'maire', 'depute') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN d.current_city END;
  SELECT * INTO v_row FROM public.cycles_electoraux
   WHERE country = d.country AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  v_cycle := v_row.data::jsonb;
  IF p_type = 'falsification_listes' THEN
    IF NOT (v_now < coalesce((v_cycle ->> 'dateVote')::bigint, 0)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre'); END IF;
  ELSIF NOT (v_now >= coalesce((v_cycle ->> 'dateVote')::bigint, 0) AND v_now < coalesce((v_cycle ->> 'dateResultats')::bigint, 0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_cycle -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, v_fn, v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dis := coalesce(CASE WHEN jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric END, 50);
  v_taux := greatest(5, least(95, v_base + round((v_dis - 50) / 5)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    SELECT count(*) + 1 INTO v_rang FROM public.fraudes_electorales
     WHERE country = d.country AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city
       AND cycle_debut = (v_cycle ->> 'dateDebutCandidatures')::bigint AND type = p_type;
    v_delta := CASE p_type
      WHEN 'falsification_listes' THEN floor(random() * 10)::integer + 1
      WHEN 'bourrage_urnes' THEN floor(random() * 3)::integer + 1
      ELSE (CASE WHEN coalesce(p_sens, 1) < 0 THEN -1 ELSE 1 END) * (floor(random() * 10)::integer + 1) END;
    INSERT INTO public.fraudes_electorales (id, country, poste_id, city, cycle_debut, type, auteur, candidat,
                                            delta_voix, etat, detectabilite_pct, created_at)
    VALUES ('fraude-' || p_type || '-' || replace(gen_random_uuid()::text, '-', ''), d.country, p_poste, v_city,
            (v_cycle ->> 'dateDebutCandidatures')::bigint, p_type, v_moi, p_candidat, v_delta, 'non_revelee',
            (ARRAY[10, 30, 60, 90, 100])[least(v_rang, 5)], now());
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'delta', v_delta, 'candidat', p_candidat) || jsonb_build_object('paie', v_paie);
  END IF;
  v_raison := CASE p_type WHEN 'falsification_listes' THEN 'Falsification des listes électorales — pris(e) sur le fait'
                          WHEN 'bourrage_urnes' THEN 'Bourrage d''urnes — pris(e) sur le fait'
                          ELSE 'Trucage du dépouillement — pris(e) sur le fait' END;
  v_det := public.detention_ouvrir_interne(v_moi, v_raison, v_jours, coalesce(d.current_city, 'capitale'), d.country,
             jsonb_build_array(jsonb_build_object('type', v_raison, 'jours', v_jours, 'city', coalesce(d.current_city, 'capitale'),
               'source', 'fraude_electorale', 'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_moi, 'fraude_electorale');
  IF p_type = 'trucage_depouillement' THEN
    v_libelle := v_moi || ', ' || CASE WHEN d.poste = 'juge' THEN 'le juge' ELSE 'le commissaire' END
      || ', a été pris(e) sur le fait en tentant de truquer le dépouillement d''un scrutin.';
    INSERT INTO public.chronique_nationale (id, country, type, city, personnages, libelle, data)
    VALUES ('chronique-fraude_electorale_dejouee-' || replace(gen_random_uuid()::text, '-', ''), d.country,
            'fraude_electorale_dejouee', v_city, jsonb_build_array(v_moi), v_libelle,
            jsonb_build_object('poste_id', p_poste, 'candidat_vise', p_candidat));
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'jours', v_jours,
    'detention_ouverte', coalesce((v_det ->> 'ok')::boolean, false), 'detention_id', v_det ->> 'detention_id')
    || jsonb_build_object('paie', v_paie);
END; $function$;

-- geoles_detenus(text,text) -> TABLE(nom text, photo_url text, qhs boolean) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.geoles_detenus(p_pays text, p_ville text)
 RETURNS TABLE(nom text, photo_url text, qhs boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_salle text;
BEGIN
  IF public.est_appel_serveur() THEN
    RETURN QUERY
      SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
             coalesce(d.qhs, false)
        FROM public.detentions d
       WHERE d.country = p_pays AND d.city = p_ville
         AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
       ORDER BY d.created_at DESC;
    RETURN;
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;

  SELECT country, current_city, current_building, current_room
    INTO v_pays, v_ville, v_bat, v_salle
    FROM public.personnages_donnees WHERE name = v_moi;

  IF v_pays IS DISTINCT FROM p_pays OR v_ville IS DISTINCT FROM p_ville
     OR NOT ( (v_bat = 'commissariat'       AND v_salle = 'prison')
           OR (v_bat = 'commissariat-local' AND v_salle = 'geoles') ) THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT d.nom, (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
           -- SECRET DU QHS : jamais revele a un joueur, quel que soit l'endroit ou il se tient.
           false
      FROM public.detentions d
     WHERE d.country = p_pays AND d.city = p_ville
       AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
     ORDER BY d.created_at DESC;
END;
$function$;

-- greffe_corrompre_dossier(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.greffe_corrompre_dossier(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_inv jsonb; v_g record;
        v_aff_ville text; v_aff_pays text; v_jour integer;
        v_paye jsonb; v_copie jsonb; v_doc jsonb; v_decouvert boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- TOUTE AFFAIRE, EN COURS OU ARCHIVEE : aucun filtre de statut.
  SELECT p.city, p.country INTO v_aff_ville, v_aff_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_aff_ville IS NULL AND v_aff_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;

  -- LE GREFFE DU TRIBUNAL COMPETENT POUR CETTE AFFAIRE, ET LUI SEUL : un dossier ne se copie pas
  -- a distance, et pas davantage au greffe d'une autre ville.
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_aff_pays, v_aff_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_aff_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_aff_pays, v_aff_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_aff_ville, 'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- LES DEUX COUTS SONT PRELEVES A LA TENTATIVE. C'est la regle du precedent, et l'arbitrage
  -- interdit d'y faire une exception.
  v_paye := public.payer_ordre(v_moi, 'greffe_corrompre_dossier', 3, 300);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_decouvert := random() < 0.25;

  IF v_decouvert THEN
    PERFORM public.greffe_denoncer_corruption(v_pays);
    RETURN jsonb_build_object('ok', true, 'decouvert', true, 'document', NULL,
      'raison_metier', 'corruption_decouverte', 'jour', v_jour);
  END IF;

  v_copie := public.dossier_judiciaire_copie(p_affaire_id);
  IF coalesce((v_copie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'greffe_corrompre_dossier : copie impossible (%)', v_copie ->> 'raison';
  END IF;

  v_doc := public.document_officiel_emettre(
    'dossier_copie', 'dossier_copie', true,
    v_aff_pays, v_aff_ville, v_copie ->> 'prevenu', NULL, p_affaire_id, v_moi, v_moi, v_jour,
    'Copie du dossier judiciaire ' || p_affaire_id,
    'Copie integrale etablie au greffe au jour ' || v_jour || '. Document FIGE : les actes '
      || 'posterieurs a cette date n''y figurent pas.',
    'ti-folder', v_copie,
    jsonb_build_object('motif', 'greffier_corrompu'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'greffe_corrompre_dossier : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'decouvert', false,
    'document', v_doc ->> 'document', 'affaire', p_affaire_id,
    'jour', v_jour, 'tribunal', v_aff_ville, 'emis_par', v_doc ->> 'emis_par');
END;
$function$;

-- greffe_corrompre_faux_casier(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.greffe_corrompre_faux_casier(p_personne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_inv jsonb; v_g record;
        v_jour integer; v_paye jsonb; v_doc jsonb; v_decouvert boolean; v_contenu jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_personne, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_manquante');
  END IF;
  -- POUR N'IMPORTE QUEL PJ, pas seulement pour soi -- et la personne doit exister : un faux au
  -- nom de quelqu'un qui n'existe pas ne serait un document de rien.
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_introuvable');
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LE CASIER EST NATIONAL : n'importe lequel des trois greffes fait l'affaire. La presence
  -- PHYSIQUE au greffe ou l'on se trouve, elle, reste exigee.
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_paye := public.payer_ordre(v_moi, 'greffe_corrompre_faux_casier', 3, 300);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_decouvert := random() < 0.25;

  IF v_decouvert THEN
    PERFORM public.greffe_denoncer_corruption(v_pays);
    RETURN jsonb_build_object('ok', true, 'decouvert', true, 'document', NULL,
      'raison_metier', 'corruption_decouverte', 'jour', v_jour);
  END IF;

  -- LE CONTENU MENT, ET IL EST LE SEUL A MENTIR : la forme est exactement celle d'un vrai
  -- extrait -- memes cles, meme ordre --, et la DATE est la vraie date de fabrication.
  v_contenu := jsonb_build_object(
    'personne', p_personne,
    'pays', v_pays,
    'vierge', true,
    'condamnations', '[]'::jsonb);

  v_doc := public.document_officiel_emettre(
    'casier_faux', 'casier_extrait', false,
    v_pays, v_ville, p_personne, NULL, NULL, v_moi, v_moi, v_jour,
    'Extrait de casier judiciaire — ' || p_personne,
    'Delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit l''etat du casier '
      || 'au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'greffier_corrompu'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'greffe_corrompre_faux_casier : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'decouvert', false,
    'document', v_doc ->> 'document', 'personne', p_personne,
    'jour', v_jour, 'tribunal', v_ville, 'emis_par', v_doc ->> 'emis_par');
END;
$function$;

-- greffe_denoncer_corruption(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.greffe_denoncer_corruption(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour integer;
BEGIN
  v_jour := coalesce(public.jour_de_jeu_pays(p_pays), 1);
  RETURN public.recherche_inscrire(jsonb_build_object(
    'acte', 'corruption_fonctionnaire', 'type', 'delit', 'jour', v_jour,
    'origine', 'greffe'));
END $function$;

-- greffe_signataire(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.greffe_signataire(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(g.greffier_pnj,
                  'Greffe du tribunal de ' || coalesce(v.nom, coalesce(p_ville, 'la capitale')))
    FROM public.greffes_tribunaux g
    LEFT JOIN public.villes v ON v.pays = g.pays AND v.ville = g.ville
   WHERE g.pays = p_pays AND g.ville IS NOT DISTINCT FROM coalesce(p_ville, 'capitale');
$function$;

-- impact_deposer(text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.impact_deposer(p_id text, p_victime text, p_indice text, p_delta integer, p_palier text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; a record; c record; v_delta integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_id,'')),'') = '' OR length(p_id) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_invalide');
  END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT name, country, current_city, current_building, current_room INTO c
    FROM public.personnages_donnees WHERE name = btrim(coalesce(p_victime,''));
  IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'victime_introuvable'); END IF;
  IF c.name = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'auto_impact_refuse'); END IF;

  IF p_indice = 'hp_set' THEN
    -- 27/10/2026 : les degats sont poses par crime_neutraliser et crime_explosifs.
    RETURN jsonb_build_object('ok', false, 'raison', 'hp_set_par_le_serveur');
    -- LA CO-PRESENCE EST LA GARDE ESSENTIELLE. Elle ne remplace pas un jet serveur, mais elle
    -- supprime a elle seule l'attaque a distance sur une victime quelconque, qui etait le vrai
    -- danger : frapper sans etre la, sans arme et sans PA.
    IF a.country IS DISTINCT FROM c.country
       OR a.current_city IS DISTINCT FROM c.current_city
       OR a.current_building IS DISTINCT FROM c.current_building
       OR a.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    v_delta := greatest(0, least(100, coalesce(p_delta, 0)));

  ELSIF p_indice = 'moral_carte_postale' THEN
    -- Une carte postale est distante par nature : aucune co-presence exigee. Le montant n'est pas
    -- negociable et le plafond quotidien reste pose cote lecteur, la ou il l'a toujours ete.
    v_delta := 10;

  ELSIF p_indice = 'poison_start' THEN
    -- REFUS EXPLICITE, ET C'EST UN CONSTAT, PAS UNE DECISION. Le producteur envoie `poisonType` et
    -- `statsTouchees`, DEUX COLONNES QUI N'EXISTENT PAS dans cette table, et omet `delta` qui est
    -- NOT NULL sans defaut. Cet INSERT a donc toujours ete rejete par PostgREST, silencieusement
    -- (sbInsert journalise et rend null, l'appelant avale le null) : l'empoisonnement n'a jamais
    -- atteint sa victime. On refuse desormais VISIBLEMENT au lieu d'echouer en silence. Reparer
    -- l'empoisonnement est un lot a part : il demande un schema, pas un correctif de canal.
    RETURN jsonb_build_object('ok', false, 'raison', 'schema_incomplet',
      'detail', 'poison_start exige des colonnes absentes de la table');

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'indice_non_autorise', 'indice', p_indice);
  END IF;

  -- Idempotence : un retry apres un accuse de reception perdu ne cree pas de seconde ligne.
  INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite)
  VALUES (p_id, c.name, p_indice, v_delta, nullif(btrim(coalesce(p_palier,'')),''), false)
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'id', p_id, 'victime', c.name,
    'indice', p_indice, 'delta', v_delta);
END;
$function$;

-- impact_marquer_traite(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.impact_marquer_traite(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.impacts_indices_attente SET traite = true
   WHERE id = p_id AND victime = v_moi AND traite IS NOT TRUE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'marques', v_n);
END;
$function$;

-- infraction_canonique(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.infraction_canonique(p_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_canon text;
BEGIN
  v_id := nullif(btrim(coalesce(p_id, '')), '');
  IF v_id IS NULL THEN RETURN NULL; END IF;
  SELECT a.canonique INTO v_canon FROM public.infractions_alias a WHERE a.alias = v_id;
  IF v_canon IS NOT NULL THEN v_id := v_canon; END IF;
  IF EXISTS (SELECT 1 FROM public.infractions i WHERE i.id = v_id) THEN RETURN v_id; END IF;
  RETURN NULL;
END;
$function$;

-- infraction_peine_bornes(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.infraction_peine_bornes(p_infraction text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_i record; v_jmin integer; v_jmax integer; v_amin integer; v_amax integer;
BEGIN
  v_id := public.infraction_canonique(p_infraction);
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
                              'demande', p_infraction);
  END IF;
  SELECT * INTO v_i FROM public.infractions WHERE id = v_id;

  -- round() de PostgreSQL arrondit au plus proche, les demis vers le haut : round(0.5) = 1 et
  -- round(1.5) = 2. C'est la meme convention que Math.round cote navigateur.
  v_jmin := greatest(1, round(v_i.jours_reference * 0.5)::integer);
  v_jmax := round(v_i.jours_reference * 1.5)::integer;
  v_amin := greatest(0, round(v_i.amende_reference * 0.5)::integer);
  v_amax := round(v_i.amende_reference * 1.5)::integer;

  RETURN jsonb_build_object('ok', true,
    'infraction', v_i.id, 'libelle', v_i.libelle, 'categorie', v_i.categorie,
    'bareme_propre', v_i.bareme_propre, 'detectable', v_i.detectable,
    'jours_reference', v_i.jours_reference, 'jours_min', v_jmin, 'jours_max', v_jmax,
    'amende_reference', v_i.amende_reference, 'amende_min', v_amin, 'amende_max', v_amax,
    -- VRAI quand la borne basse EGALE la reference : l'attenuation est alors inexprimable, le
    -- juge ne peut qu'aggraver. Les huit infractions a 1 jour sont dans ce cas.
    'plancher_technique', (v_jmin >= v_i.jours_reference));
END;
$function$;

-- infractions_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.infractions_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      id || '|' || libelle || '|' || coalesce(categorie, '')
         || '|' || jours_reference::text || '|' || amende_reference::text
         || '|' || coalesce(detect_rate::text, '')
         || '|' || CASE WHEN bareme_propre THEN '1' ELSE '0' END,
      E'\n' ORDER BY id COLLATE "C")), 16)
  FROM public.infractions;
$function$;

-- juge_de_la_ville(text) -> TABLE(nom text, pays text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_de_la_ville(p_ville text)
 RETURNS TABLE(nom text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT j.nom, j.pays FROM public.juge_moi() j
   WHERE j.ville IS NOT DISTINCT FROM coalesce(p_ville, 'capitale');
$function$;

-- juge_dossiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record;
BEGIN
  SELECT * INTO v_j FROM public.juge_moi();
  IF v_j.nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge'); END IF;

  RETURN jsonb_build_object('ok', true, 'juge', v_j.nom, 'ville', coalesce(v_j.ville, 'capitale'),
    'dossiers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'ville', p.city, 'dossier', p.data::jsonb,
        'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                     'rang', a.rang, 'type', a.type, 'libelle', t.libelle,
                     'acteur', a.acteur, 'poste', a.acteur_poste,
                     'qualif_avant', a.qualif_avant, 'qualif_apres', a.qualif_apres,
                     'donnees', a.donnees, 'fait_le', a.fait_le) ORDER BY a.rang), '[]'::jsonb)
                    FROM public.dossiers_judiciaires_actes a
                    JOIN public.dossiers_judiciaires_actes_types t ON t.type = a.type
                   WHERE a.affaire = p.id)
      ) ORDER BY p.created_at), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_j.pays AND p.city IS NOT DISTINCT FROM coalesce(v_j.ville, 'capitale')
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande', 'appel', 'non_lieu')));
END $function$;

-- juge_moi() -> TABLE(nom text, pays text, ville text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_moi()
 RETURNS TABLE(nom text, pays text, ville text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inc text; v_pays text; v_ville text; v_pnj text;
BEGIN
  RETURN QUERY
    SELECT d.name, d.country, coalesce(d.poste ->> 'city', 'capitale')
      FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge'
     LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  v_inc := public.incarnation_courante();
  IF v_inc IS NULL THEN RETURN; END IF;
  v_pays  := public.incarnation_pays();
  v_ville := public.incarnation_siege();
  IF v_pays IS NULL OR v_ville IS NULL THEN RETURN; END IF;
  v_pnj := public.admin_pnj_titulaire(v_pays, 'juge', v_ville);
  IF v_pnj IS NULL OR v_pnj IS DISTINCT FROM v_inc THEN RETURN; END IF;
  RETURN QUERY SELECT v_pnj, v_pays, v_ville;
END $function$;

-- juge_ouvrir_enquete_malgre_non_lieu(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_ouvrir_enquete_malgre_non_lieu(p_affaire_id text, p_motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_motif text; v_n integer;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  -- L'AUTORITE EST CELLE DE LA VILLE DE L'AFFAIRE, la regle de toutes les portes du juge.
  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville);
  END IF;

  -- CE POUVOIR NE S'EXERCE QUE SUR UN NON-LIEU. Il n'autorise pas le juge a prendre la main sur
  -- un dossier que le parquet instruit encore, ni a ressusciter une affaire jugee, relaxee ou
  -- perimee : la decision contredite est NOMMEE, et c'est la seule.
  IF coalesce(v_a ->> 'status', '') <> 'non_lieu' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status');
  END IF;

  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- LE NON-LIEU N'EST PAS EFFACE : seules des cles sont AJOUTEES. `non_lieu_par`, `non_lieu_le`
  -- et `non_lieu_motif_declare` restent lisibles sur le dossier apres la reouverture.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'enquete',
           'juge_enquete_ouverte_par', v_j.nom,
           'juge_enquete_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'juge_enquete_motif_declare', v_motif))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'non_lieu';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'juge_enquete_ouverte',
    v_j.nom, 'juge', NULL, NULL,
    CASE WHEN v_motif IS NULL THEN NULL
         ELSE jsonb_build_object('motif_declare', v_motif) END);

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'enquete',
                            'juge', v_j.nom, 'non_lieu_par', v_a ->> 'non_lieu_par');
END;
$function$;

-- juge_suite_apres_abandon(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_suite_apres_abandon(p_affaire_id text, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_statut text; v_type text; v_n integer;
BEGIN
  IF p_decision NOT IN ('arret', 'poursuivre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide', 'decision', p_decision);
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville);
  END IF;
  IF coalesce(v_a ->> 'status', '') <> 'abandon_demande' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status');
  END IF;
  -- LE DELAI EST OPPOSABLE ICI AUSSI. Maintenir des poursuites sur un dossier eteint le
  -- ressusciterait ; le juge peut encore accepter l'arret, mais plus relancer la procedure.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_statut := CASE WHEN p_decision = 'arret' THEN 'arret' ELSE 'saisie' END;
  v_type := CASE WHEN p_decision = 'arret' THEN 'juge_arret_accepte'
                 ELSE 'juge_poursuite_maintenue' END;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', v_statut,
           'suite_abandon_par', v_j.nom,
           'suite_abandon_decision', p_decision,
           'suite_abandon_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'abandon_demande';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, v_type, v_j.nom, 'juge');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'decision', p_decision, 'statut', v_statut);
END;
$function$;

-- justice_affaires_publiques() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_affaires_publiques()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT d.country, coalesce(d.current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees d WHERE d.name = v_moi;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
      'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece); END IF;

  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'pays', v_pays,
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'affaire', p.id,
        'prevenu', (p.data::jsonb) ->> 'cible',
        'categorie', public.affaire_categorie_publique(p.data::jsonb),
        'statut', (p.data::jsonb) ->> 'status',
        'audience_jour', (p.data::jsonb) ->> 'audience_jour',
        'temoins', (SELECT coalesce(jsonb_agg(c.temoin ORDER BY c.rang), '[]'::jsonb)
                      FROM public.temoins_citations c WHERE c.affaire = p.id)
      ) ORDER BY p.id), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.city = v_ville
       AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb) ->> 'status' IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')),
    'greffe', jsonb_build_object('batiment', v_g.batiment, 'piece', v_g.piece));
END $function$;

-- justice_affaires_vivantes_avec_pv(text) -> TABLE(affaire text, pays text, infraction text, echeance integer) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_affaires_vivantes_avec_pv(p_nom text)
 RETURNS TABLE(affaire text, pays text, infraction text, echeance integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.id, p.country,
         public.affaire_infraction_de(p.data::jsonb),
         ((p.data::jsonb) ->> 'delai_jugement_jour')::integer
    FROM public.plaintes_en_cours p
    JOIN public.dossiers_auditions a ON a.affaire = p.id AND a.personne = p_nom
   WHERE p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
     AND ((p.data::jsonb) ->> 'cible') = p_nom
     AND ((p.data::jsonb) ->> 'status') IN
         ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')
     AND NOT public.affaire_delai_expire(p.data::jsonb, p.country);
$function$;

-- justice_appel_juger(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_appel_juger(p_affaire_id text, p_verdict text, p_infraction text DEFAULT NULL::text, p_genre text DEFAULT NULL::text, p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_calc jsonb; v_jours integer; v_amende integer; v_libelle text; v_peine text;
  v_inf text; v_jug text; v_n integer; v_motifs jsonb;
  v_det record; v_det_id text; v_purges integer; v_indus integer; v_ind jsonb;
  v_libere boolean := false;
BEGIN
  IF p_verdict NOT IN ('condamnation', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'verdict_invalide', 'verdict', p_verdict); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'appel' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_appel', 'statut', v_a ->> 'status'); END IF;

  -- L'AUDIENCE OBLIGATOIRE (13 octobre 2026). Le second examen est un jugement COMPLET et DEFINITIF :
  -- il tombe sous la meme regle. En pratique le verrou est deja satisfait -- un appel exige un
  -- jugement de premiere instance, qui exige desormais une audience ouverte, et
  -- `justice_appel_ouvrir` refuse la procedure simplifiee -- mais une porte qui ne verifie que
  -- par transitivite n'est pas verrouillee : elle l'est quand un GRANT de plus ou un statut pose
  -- a la main ne suffit pas a la franchir. AUCUNE SECONDE AUDIENCE N'EST INVENTEE : la cle
  -- `audience_ouverte_le` de la premiere instance reste sur le dossier, et c'est elle qui est lue.
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

  v_inf := public.infraction_canonique(
             coalesce(p_infraction, v_a ->> 'qualification_finale', v_a ->> 'qualification_parquet'));
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
      'demande', coalesce(p_infraction, v_a ->> 'qualification_finale')); END IF;

  v_jours := 0; v_amende := 0;
  IF p_verdict = 'condamnation' THEN
    IF coalesce(btrim(coalesce(p_genre, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'genre_absent'); END IF;
    v_calc := public.justice_peine_calcul(v_inf, p_genre, v_a ->> 'cible', v_pays);
    IF coalesce((v_calc ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_calc; END IF;
    v_jours  := coalesce(p_jours, 0);
    v_amende := coalesce(p_amende, 0);
    IF v_jours < (v_calc ->> 'jours_min')::integer
       OR v_jours > (v_calc ->> 'jours_max')::integer THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'peine_hors_bornes',
        'demande_jours', v_jours, 'jours_min', (v_calc ->> 'jours_min')::integer,
        'jours_max', (v_calc ->> 'jours_max')::integer); END IF;
    IF v_amende < (v_calc ->> 'amende_min')::integer
       OR v_amende > (v_calc ->> 'amende_max')::integer THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'amende_hors_bornes',
        'demande_amende', v_amende, 'amende_min', (v_calc ->> 'amende_min')::integer,
        'amende_max', (v_calc ->> 'amende_max')::integer); END IF;
    v_libelle := v_calc ->> 'libelle';
    v_peine := CASE p_genre
      WHEN 'prison'      THEN 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
      WHEN 'amende'      THEN 'Amende de ' || v_amende || ' FR'
      WHEN 'amenagement' THEN 'Amenagement : pointage quotidien au commissariat'
      WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'
      ELSE                    'Prison ' || v_jours || ' jours + popularite a zero'
    END;
  ELSE
    SELECT i.libelle INTO v_libelle FROM public.infractions i WHERE i.id = v_inf;
    v_peine := NULL;
  END IF;

  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;
  v_jour := coalesce(v_jour, 1);
  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_libelle, 'infraction', v_inf, 'jours', v_jours, 'city', v_ville,
      'source', 'jugement_appel',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  v_jug := 'jug-app-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible', v_libelle, v_peine,
          v_j.nom, v_jour, true,
          jsonb_build_object('verdict', p_verdict, 'instance', 'appel', 'definitif', true,
            'infraction', v_inf, 'infraction_libelle', v_libelle, 'genre', p_genre,
            'jours', v_jours, 'amende', v_amende,
            'jugement_premiere_instance', 'jug-' || p_affaire_id,
            'peine_premiere_instance', v_a ->> 'peine_libelle',
            'motif_allegue', v_a ->> 'motif',
            'qualification_parquet', v_a ->> 'qualification_parquet',
            'qualification_premiere_instance', v_a ->> 'qualification_finale',
            'motifs', v_motifs))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_juge'); END IF;

  -- LES JOURS PURGES SE COMPTENT SUR L'HORLOGE DU DETENU (voir justice_jours_purges).
  v_det_id := nullif(v_a ->> 'detention_id', '');
  SELECT * INTO v_det FROM public.detention_active(v_a ->> 'cible');
  IF v_det.id IS NOT NULL AND (v_det_id IS NULL OR v_det.id = v_det_id) THEN
    v_det_id := v_det.id;
    v_purges := public.justice_jours_purges(v_det_id);
    IF v_purges >= v_jours THEN
      PERFORM public.detention_clore_interne(v_a ->> 'cible', 'jugement_appel', NULL);
      v_libere := true;
    ELSE
      UPDATE public.detentions SET jour_fin = jour_debut + v_jours WHERE id = v_det_id;
    END IF;
  ELSIF v_det_id IS NOT NULL THEN
    v_purges := public.justice_jours_purges(v_det_id);
  ELSE
    v_purges := 0;
  END IF;

  v_indus := greatest(0, coalesce(v_purges, 0) - v_jours);
  IF v_indus > 0 THEN
    v_ind := public.justice_indemnite_naitre(v_pays, v_a ->> 'cible', p_affaire_id, v_jug, v_indus);
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'indemnisation',
      NULL, NULL, NULL, NULL,
      jsonb_build_object('jours_indus', v_indus, 'jours_purges', v_purges,
                         'peine_definitive_jours', v_jours,
                         'montant', v_indus * public.justice_indemnite_par_jour(),
                         'creance', v_ind ->> 'id', 'porteur', v_ind ->> 'porteur'));
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'jugee_appel',
           'verdict', p_verdict,
           'juge_appel', v_j.nom,
           'juge_appel_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_inf,
           'qualification_libelle', v_libelle,
           'peine_genre', p_genre,
           'peine_jours', v_jours,
           'peine_amende', v_amende,
           'peine_libelle', v_peine,
           'jours_purges', coalesce(v_purges, 0),
           'jours_indus', v_indus,
           'definitif', true))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'appel';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'jugement_appel',
    v_j.nom, 'juge', v_a ->> 'qualification_finale', v_inf,
    jsonb_build_object('verdict', p_verdict, 'genre', p_genre, 'jours', v_jours,
                       'amende', v_amende, 'jours_purges', coalesce(v_purges, 0),
                       'jours_indus', v_indus, 'libere', v_libere, 'definitif', true));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'jugement_id', v_jug,
    'verdict', p_verdict, 'definitif', true, 'juge', v_j.nom, 'infraction', v_inf,
    'genre', p_genre, 'jours', v_jours, 'amende', v_amende,
    'jours_purges', coalesce(v_purges, 0), 'jours_indus', v_indus,
    'libere', v_libere, 'indemnite', v_ind);
END;
$function$;

-- justice_appel_ouvrir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_appel_ouvrir(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_p record; v_brut text; v_a jsonb; v_ville text; v_pays text;
  v_jour integer; v_limite integer; v_qui text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  IF coalesce((v_a ->> 'procedure_simplifiee')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_exclu_procedure_simplifiee'); END IF;

  -- LE SECOND EXAMEN A DEJA EU LIEU, ET IL EST DEFINITIF. Ce refus-ci precede tous les autres :
  -- c'est le seul etat ou l'affaire est DEFINITIVEMENT close du cote judiciaire, et le dire est
  -- plus utile que n'importe quel autre motif.
  IF coalesce(v_a ->> 'status', '') = 'jugee_appel'
     OR coalesce((v_a ->> 'definitif')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_d_appel_definitif',
                              'statut', v_a ->> 'status',
                              'juge_appel', v_a ->> 'juge_appel'); END IF;

  -- L'UNICITE AVANT LE STATUT. C'est l'inversion qui paie la dette : tant que ce test venait
  -- apres celui du statut, il n'etait jamais atteint sur une affaire en appel.
  IF v_a ? 'appel_ouvert_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete',
                              'par', v_a ->> 'appel_par',
                              'qualite', v_a ->> 'appel_qualite'); END IF;

  IF coalesce(v_a ->> 'status', '') NOT IN ('jugee', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jugement_de_premiere_instance',
                              'statut', v_a ->> 'status'); END IF;

  v_qui := NULL;
  IF coalesce(v_a ->> 'cible', '') = v_moi THEN
    v_qui := 'condamne';
  ELSE
    SELECT * INTO v_p FROM public.parquet_moi();
    IF v_p.nom IS NOT NULL AND v_p.pays IS NOT DISTINCT FROM v_pays THEN
      v_qui := 'parquet';
    END IF;
  END IF;
  IF v_qui IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  v_limite := nullif(v_a ->> 'appel_jusqu_au_jour', '')::integer;
  IF v_limite IS NULL THEN
    SELECT coalesce((j.data ->> 'appel_jusqu_au_jour_pays')::integer,
                    (j.data ->> 'jour_pays')::integer + public.justice_fenetre_appel_jours(),
                    j.jour + public.justice_fenetre_appel_jours())
      INTO v_limite FROM public.jugements j WHERE j.id = 'jug-' || p_affaire_id;
  END IF;
  IF v_limite IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_introuvable'); END IF;
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF v_jour > v_limite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fenetre_appel_fermee',
                              'jour', v_jour, 'limite', v_limite); END IF;

  -- LE LAISSEZ-PASSER, ET IL NE DURE QUE CETTE ECRITURE. Sans lui, `plaintes_epingler_verdict`
  -- restaure le `status` que cette porte vient d'ecrire -- l'appel serait interjete et sans
  -- effet. Voir l'en-tete.
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'appel',
           'appel_par', v_moi,
           'appel_qualite', v_qui,
           'appel_jour', v_jour,
           'appel_ouvert_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id
     AND (data::jsonb ->> 'status') = (v_a ->> 'status')
     AND NOT (data::jsonb ? 'appel_ouvert_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM set_config('rp.verdict_interne', '', true);
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete'); END IF;

  -- ET L'EFFET EST RELU EN BASE, pas suppose.
  SELECT p.data::jsonb ->> 'status' INTO v_brut
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS DISTINCT FROM 'appel' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_non_applique', 'statut', v_brut); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'appel_ouvert',
    v_moi, CASE WHEN v_qui = 'parquet' THEN 'procureur' ELSE NULL END, NULL, NULL,
    jsonb_build_object('qualite', v_qui, 'jour', v_jour, 'limite', v_limite));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'par', v_moi,
                            'qualite', v_qui, 'jour', v_jour, 'limite', v_limite);
END;
$function$;

-- justice_archives_greffe(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_archives_greffe(p_affaire_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT d.country, coalesce(d.current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine'); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
      'site', v_g.batiment, 'piece', v_g.piece); END IF;

  RETURN jsonb_build_object('ok', true, 'ville', v_ville,
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'affaire', p.id,
        'prevenu', (p.data::jsonb) ->> 'cible',
        'categorie', public.affaire_categorie_publique(p.data::jsonb),
        'statut', (p.data::jsonb) ->> 'status',
        'verdict', (p.data::jsonb) ->> 'verdict',
        'peine', (SELECT j.peine FROM public.jugements j WHERE j.id = 'jug-' || p.id),
        'chronologie', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                          'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                          'poste', x.acteur_poste, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                         FROM public.dossiers_judiciaires_actes x
                         JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
                        WHERE x.affaire = p.id)
      ) ORDER BY p.id DESC), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.city = v_ville
       AND left(btrim(p.data), 1) = '{'
       AND (p_affaire_id IS NULL OR p.id = p_affaire_id)
       AND (p.data::jsonb) ->> 'status' IN
           ('non_lieu', 'abandonnee', 'arret', 'relaxe', 'jugee', 'jugee_appel', 'delai_expire')));
END $function$;

-- justice_audience_consentir(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_consentir(p_affaire_id text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- LE CONSENTEMENT APPARTIENT AU PREVENU, ET A LUI SEUL. Ni son avocat, ni le juge, ni le
  -- parquet ne peuvent le donner a sa place.
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF p_jour IS NOT NULL AND p_jour < v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_invalide', 'jour_courant', v_jour); END IF;

  UPDATE public.plaintes_en_cours
     SET data = CASE WHEN p_jour IS NULL
                THEN (v_a - 'audience_consentie_jour' - 'audience_consentie_le')::text
                ELSE (v_a || jsonb_build_object(
                        'audience_consentie_jour', p_jour,
                        'audience_consentie_le',
                        to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text END
   WHERE id = p_affaire_id AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
    CASE WHEN p_jour IS NULL THEN 'audience_consentement_retire' ELSE 'audience_consentement' END,
    v_moi, 'accuse', NULL, NULL, jsonb_build_object('jour', p_jour));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'consenti_jour', p_jour, 'retire', (p_jour IS NULL));
END $function$;

-- justice_audience_ecrire(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_ecrire(p_affaire_id text, p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_s record; v_role text; v_txt text; v_rang bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_txt := coalesce(p_texte, '');
  IF btrim(v_txt) = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_vide'); END IF;
  IF length(v_txt) > 4000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_trop_long'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

  -- ON PARLE DANS LA SALLE, PAS DEPUIS CHEZ SOI.
  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee'); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_requise',
      'site', v_s.batiment, 'piece', v_s.piece); END IF;

  -- LE ROLE EST RECALCULE ICI, A PARTIR DE LA BASE. Le navigateur n'en dit rien et n'est pas cru.
  v_role := public.audience_role_de(p_affaire_id, v_moi);
  IF v_role = 'spectateur' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'spectateur_sans_parole'); END IF;
  -- UN TEMOIN N'A AUCUN DROIT AUTOMATIQUE D'ECRIRE : il lui faut la parole du juge, et le juge
  -- peut la retirer.
  IF v_role = 'temoin' AND NOT public.audience_peut_ecrire(p_affaire_id, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parole_non_accordee'); END IF;

  INSERT INTO public.audience_messages (affaire, pays, ville, auteur, qualite, texte)
  VALUES (p_affaire_id, v_pays, v_ville, v_moi, v_role, v_txt)
  RETURNING rang INTO v_rang;

  RETURN jsonb_build_object('ok', true, 'rang', v_rang, 'affaire', p_affaire_id,
                            'qualite', v_role, 'auteur', v_moi);
END $function$;

-- justice_audience_fixer(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_fixer(p_affaire_id text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_jour integer; v_min integer; v_n integer; v_prev text;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie', 'statut', v_a ->> 'status'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_min  := v_jour + public.justice_delai_audience_jours();
  v_prev := v_a ->> 'cible';

  IF p_jour IS NULL OR p_jour < v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_invalide',
                              'jour_courant', v_jour, 'minimum', v_min); END IF;

  -- PLUS TOT QUE J+3 N'EST POSSIBLE QUE SI LE PREVENU A CONSENTI A CE JOUR-LA. Le consentement
  -- porte sur UN jour precis : s'il a consenti au jour 12 et que le juge fixe le 11, il faut un
  -- consentement neuf. Rien n'est deduit du silence.
  IF p_jour < v_min
     AND coalesce((v_a ->> 'audience_consentie_jour')::integer, -1) IS DISTINCT FROM p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'consentement_du_prevenu_requis',
      'minimum', v_min, 'demande', p_jour, 'prevenu', v_prev);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_jour', p_jour,
           'audience_fixee_par', v_j.nom,
           'audience_fixee_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- ET L'EFFET EST RELU EN BASE, jamais suppose.
  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF (v_a ->> 'audience_jour')::integer IS DISTINCT FROM p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'date_non_appliquee'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'audience_fixee',
    v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('jour', p_jour, 'minimum', v_min,
                       'consentement_du_prevenu', p_jour < v_min));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'jour', p_jour,
                            'minimum', v_min, 'juge', v_j.nom);
END $function$;

-- justice_audience_lire(text,bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_lire(p_affaire_id text, p_apres bigint DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_s record; v_role text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee'); END IF;
  -- LIRE EXIGE D'ETRE LA. Une audience publique l'est pour qui s'y rend, pas pour le monde entier.
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_requise',
      'site', v_s.batiment, 'piece', v_s.piece); END IF;

  v_role := public.audience_role_de(p_affaire_id, v_moi);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
    'ouverte', public.affaire_audience_ouverte(v_a),
    'mon_role', v_role,
    'je_peux_ecrire', public.affaire_audience_ouverte(v_a)
       AND v_role <> 'spectateur'
       AND (v_role <> 'temoin' OR public.audience_peut_ecrire(p_affaire_id, v_moi)),
    'paroles', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'personne', x.personne, 'accordee_le', x.accordee_le,
                  'retiree_le', x.retiree_le) ORDER BY x.accordee_le), '[]'::jsonb)
                 FROM public.audience_paroles x WHERE x.affaire = p_affaire_id),
    'messages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', m.rang, 'auteur', m.auteur, 'qualite', m.qualite,
                   'texte', m.texte, 'dit_le', m.dit_le) ORDER BY m.rang), '[]'::jsonb)
                  FROM (SELECT * FROM public.audience_messages
                         WHERE affaire = p_affaire_id AND rang > coalesce(p_apres, 0)
                         ORDER BY rang LIMIT 200) m));
END $function$;

-- justice_audience_ouvrir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_ouvrir(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_n integer;
        v_jour integer; v_s record; v_prev text; v_proc text;
        v_prev_la boolean; v_proc_la boolean;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status'); END IF;
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);

  -- LE JOUR DOIT AVOIR ETE FIXE, ET IL DOIT ETRE ARRIVE.
  IF (v_a ->> 'audience_jour') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_d_audience_non_fixe'); END IF;
  IF v_jour < (v_a ->> 'audience_jour')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_d_audience_non_venu',
      'jour_courant', v_jour, 'audience_jour', (v_a ->> 'audience_jour')::integer); END IF;

  -- LE JUGE TIENT SON AUDIENCE DANS SON TRIBUNAL. Pas depuis chez lui, pas depuis une autre ville.
  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_j.nom, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_du_juge_requise',
      'ville', v_ville, 'site', v_s.batiment, 'piece', v_s.piece); END IF;

  -- QUI EST LA, ET QUI N'Y EST PAS. C'est un CONSTAT, pas un reproche : ni l'absence du prevenu
  -- ni celle du procureur ne bloquent quoi que ce soit, et aucune consequence mecanique n'en
  -- decoule. Le fait est consigne ; son interpretation appartient aux joueurs.
  v_prev := v_a ->> 'cible';
  SELECT t.nom_pnj INTO v_proc FROM public.titulaires_pnj t
   WHERE t.country = v_pays AND t.poste_id = 'procureur' AND t.city IS NULL;
  IF v_proc IS NULL THEN
    SELECT a2.titulaire INTO v_proc FROM public.postes_attribues a2
     WHERE a2.country = v_pays AND a2.poste_id = 'procureur';
  END IF;
  v_prev_la := v_prev IS NOT NULL
               AND public.acteur_present_sur_site(v_prev, v_pays, v_ville, v_s.batiment, v_s.piece);
  v_proc_la := v_proc IS NOT NULL
               AND public.acteur_present_sur_site(v_proc, v_pays, v_ville, v_s.batiment, v_s.piece);

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'audience_ouverte_jour', v_jour,
           'audience_ouverte_par', v_j.nom,
           'audience_prevenu_present', v_prev_la,
           'audience_procureur_present', v_proc_la))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ouverture_non_appliquee'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'audience_ouverte',
    v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('jour', v_jour, 'prevenu_present', v_prev_la,
                       'procureur_present', v_proc_la, 'procureur', v_proc));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'juge', v_j.nom, 'jour', v_jour,
    'prevenu_present', v_prev_la, 'procureur_present', v_proc_la,
    'salle', jsonb_build_object('batiment', v_s.batiment, 'piece', v_s.piece));
END $function$;

-- justice_audience_parole(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_audience_parole(p_affaire_id text, p_personne text, p_donner boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_qui text;
BEGIN
  v_qui := nullif(btrim(coalesce(p_personne, '')), '');
  IF v_qui IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personne_manquante'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville'); END IF;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

  IF coalesce(p_donner, true) THEN
    INSERT INTO public.audience_paroles (affaire, personne, accordee_par)
    VALUES (p_affaire_id, v_qui, v_j.nom)
    ON CONFLICT (affaire, personne) DO UPDATE
      SET accordee_le = now(), accordee_par = v_j.nom, retiree_le = NULL;
  ELSE
    UPDATE public.audience_paroles SET retiree_le = now()
     WHERE affaire = p_affaire_id AND personne = v_qui AND retiree_le IS NULL;
  END IF;

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'personne', v_qui,
    'peut_ecrire', public.audience_peut_ecrire(p_affaire_id, v_qui), 'juge', v_j.nom);
END $function$;

-- justice_avocat_commis(text,text) -> TABLE(nom text, cha integer) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_avocat_commis(p_pays text, p_ville text)
 RETURNS TABLE(nom text, cha integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT a.nom, a.cha FROM public.justice_avocats_commis a
   WHERE a.pays = p_pays AND a.ville = p_ville;
$function$;

-- justice_avocats_disponibles(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_avocats_disponibles(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.country INTO v_brut, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;

  RETURN jsonb_build_object('ok', true,
    'affaire', p_affaire_id,
    'avocat_retenu', public.defense_avocat_de(p_affaire_id),
    'audience_ouverte', public.affaire_audience_ouverte(v_a),
    -- DEUX INFORMATIONS, ET DEUX SEULEMENT : l'identite et la tarification publiee. Rien de
    -- mecanique n'entre ici -- cette lecture ne joint aucune table de caracteristiques.
    'avocats', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'nom', b.nom, 'tarification', b.tarification) ORDER BY b.nom), '[]'::jsonb)
                 FROM public.avocats_barreau b
                WHERE b.pays = v_pays AND b.nom <> v_moi
                  AND public.avocat_est_qualifie(b.nom)),
    'demandes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', d.rang, 'avocat', d.avocat, 'etat', d.etat,
                   'demande_le', d.demande_le) ORDER BY d.rang DESC), '[]'::jsonb)
                  FROM public.defenses_demandes d
                 WHERE d.affaire = p_affaire_id AND d.prevenu = v_moi));
END $function$;

-- justice_cha_personnel(text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_cha_personnel(p_nom text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1,
           coalesce((d.stats ->> 'CHA')::integer, 8)
           -- Excommunication : -2 CHA, reversible, deja ecrite au serveur
           -- (`personnages_donnees.excommunie`, JSONB nullable). Elle n'est PAS une notion
           -- cliente : elle est posee et levee par la carriere religieuse.
           + CASE WHEN d.excommunie IS NOT NULL
                   AND jsonb_typeof(d.excommunie) <> 'null' THEN -2 ELSE 0 END)
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$function$;

-- justice_condamner(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_condamner(p_cible text, p_entree jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_juge text; v_id text; v_pays text; v_ville text; v_jours integer;
        v_aff text; v_brut text; v_a jsonb; v_aff_ville text; v_statut text; v_jl record;
BEGIN
  v_juge := public.exiger_poste('juge');
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  -- ===========================================================================================
  -- UNE CONDAMNATION JUDICIAIRE NOMME SON AFFAIRE, ET SON AFFAIRE A EU SON PROCES (13 oct. 2026)
  -- ===========================================================================================
  -- Cette porte est celle par laquelle la SANCTION tombe : `appliquerSentence` l'appelle AVANT
  -- `justice_rendre_sentence`, qui ne fait qu'archiver. Elle n'exigeait que le poste de juge.
  -- Un juge pouvait donc inscrire au registre une peine de n'importe quelle duree, sur
  -- n'importe quelle personne, hors de toute affaire, hors de tout barreme et hors de toute
  -- audience -- et `jugements` non executee EST l'avis de recherche.
  --
  -- CE QUI EST EXIGE MAINTENANT, et uniquement pour le genre qui est un jugement : l'entree de
  -- `type` 'condamnation' doit NOMMER son affaire, l'affaire doit exister, etre au statut ou un
  -- jugement complet se rend, avoir son audience OUVERTE, et l'appelant doit etre le juge DE SA
  -- VILLE -- la regle d'autorite des trois autres portes, qui manquait ici.
  --
  -- CE QUI RESTE OUVERT, EXPRES : le mandat du DESERTEUR (`type` 'militaire'), qui ne juge rien
  -- et n'attache aucune peine, et tout autre genre futur. Le verrou nomme son genre ; il ne
  -- decide pas a la place du game design ce que les autres deviennent.
  IF coalesce(p_entree ->> 'type', '') = 'condamnation' THEN
    v_aff := nullif(btrim(coalesce(p_entree ->> 'affaire_id', '')), '');
    IF v_aff IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_sans_affaire');
    END IF;
    SELECT p.data, p.city INTO v_brut, v_aff_ville
      FROM public.plaintes_en_cours p WHERE p.id = v_aff;
    IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente', 'affaire', v_aff);
    END IF;
    v_a := v_brut::jsonb;
    SELECT * INTO v_jl FROM public.juge_de_la_ville(v_aff_ville);
    IF v_jl.nom IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville',
                                'ville', v_aff_ville);
    END IF;
    -- LA CIBLE EST CELLE DE L'AFFAIRE, pas une personne choisie a cote du dossier.
    IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM p_cible THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_etrangere_a_l_affaire',
                                'affaire', v_aff);
    END IF;
    v_statut := coalesce(v_a ->> 'status', '');
    -- `saisie` : premiere instance. `appel` : le second examen, qui est aussi un jugement complet.
    IF v_statut NOT IN ('saisie', 'appel') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie', 'statut', v_statut);
    END IF;
    IF NOT public.affaire_audience_ouverte(v_a) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte', 'affaire', v_aff);
    END IF;
  END IF;

  SELECT coalesce(p_entree->>'country', country), coalesce(p_entree->>'ville_condamnation', current_city)
    INTO v_pays, v_ville FROM public.personnages_donnees WHERE name = v_juge;
  SELECT coalesce(sum((m->>'jours')::int), 0) INTO v_jours
    FROM jsonb_array_elements(coalesce(p_entree->'motifs', '[]'::jsonb)) m;

  v_id := coalesce(nullif(p_entree->>'id', ''),
                   'rech-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
                     || substr(md5(random()::text), 1, 6));

  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_id, v_pays, v_ville, p_cible,
          coalesce(p_entree #>> '{motifs,0,type}', 'Condamnation'),
          v_jours::text || ' jours', v_juge,
          coalesce((p_entree->>'jour_affaire')::int, 0), false,
          p_entree || jsonb_build_object('id', v_id))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'accuse', p_cible, 'jours', v_jours);
END; $function$;

-- justice_defense_part_relaxe() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_defense_part_relaxe()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 50 $function$;

-- justice_defense_taux(integer,integer,boolean) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_defense_taux(p_cha_avocat integer, p_cha_prevenu integer, p_preuve_reelle boolean)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT greatest(5, least(80,
    50 + (coalesce(p_cha_avocat, 13) - 13) * 5
       + (coalesce(p_cha_prevenu, 13) - 13) * 3
       - CASE WHEN coalesce(p_preuve_reelle, false) THEN 35 ELSE 0 END));
$function$;

-- justice_delai_audience_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_delai_audience_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 3; $function$;

-- justice_delai_convocation_temoin_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_delai_convocation_temoin_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 2 $function$;

-- justice_delai_jugement_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_delai_jugement_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 15 $function$;

-- justice_delais_echus() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_delais_echus()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_d record; v_n integer := 0; v_infr text; v_clos jsonb := '[]'::jsonb;
BEGIN
  -- PORTE DE SERVEUR. Aucun joueur ne declenche l'expiration d'un dossier : elle est l'effet du
  -- temps, pas d'une decision.
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  FOR v_d IN
    SELECT p.id, p.country, p.city, p.data::jsonb AS a
      FROM public.plaintes_en_cours p
     WHERE p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND ((p.data::jsonb) ->> 'status') IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')
       AND public.affaire_delai_expire(p.data::jsonb, p.country)
     ORDER BY p.created_at
     FOR UPDATE
  LOOP
    -- Compare-and-swap : une decision rendue dans la meme seconde gagne, et la passe ne l'ecrase
    -- pas. Un jugement arrive a l'heure n'est pas annule par une expiration de la nuit.
    UPDATE public.plaintes_en_cours
       SET data = (v_d.a || jsonb_build_object(
             'status', 'delai_expire',
             'delai_expire_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
     WHERE id = v_d.id AND (data::jsonb ->> 'status') = (v_d.a ->> 'status');
    IF NOT FOUND THEN CONTINUE; END IF;

    PERFORM public.dossier_acte_consigner(v_d.id, v_d.country, v_d.city,
      'charges_abandonnees_delai', NULL, NULL, NULL, NULL,
      jsonb_build_object('echeance', (v_d.a ->> 'delai_jugement_jour')::integer,
                         'statut_precedent', v_d.a ->> 'status'));

    -- LA RECHERCHE EST RESOLUE CONFORMEMENT A LA CLOTURE. Les charges sont abandonnees : la
    -- personne n'est plus recherchee POUR CET ACTE. Les autres entrees ne sont pas touchees --
    -- `recherche_retirer` filtre sur l'acte, et un motif n'en efface jamais un autre.
    v_infr := public.affaire_infraction_de(v_d.a);
    IF v_infr IS NOT NULL AND nullif(v_d.a ->> 'cible', '') IS NOT NULL THEN
      PERFORM public.recherche_retirer(ARRAY[v_infr], v_d.country, v_d.a ->> 'cible');
    END IF;

    v_n := v_n + 1;
    v_clos := v_clos || jsonb_build_array(jsonb_build_object(
      'affaire', v_d.id, 'cible', v_d.a ->> 'cible', 'infraction', v_infr));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'closes', v_n, 'dossiers', v_clos);
END;
$function$;

-- justice_est_recherche(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_est_recherche(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array'
                                     THEN d.recherche ELSE '[]'::jsonb END) e
     WHERE d.name = p_nom
       AND NOT EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(p_nom) v
                        WHERE v.infraction IS NOT NULL AND v.infraction = (e ->> 'acte')));
$function$;

-- justice_executer_condamnation(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation(p_jugement_id text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_j record; v_jours integer; v_motif text; v_res jsonb; v_det record;
BEGIN
  v_acteur := public.exiger_poste('commissaire');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- Verrou : deux executions simultanees de la meme condamnation ne peuvent pas coexister.
  SELECT * INTO v_j FROM public.jugements WHERE id = p_jugement_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_introuvable');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', true, 'deja_executee', true, 'accuse', v_j.accuse);
  END IF;

  -- Deja detenu : la peine s'ajoute a la detention en cours plutot que d'en ouvrir une seconde.
  SELECT * INTO v_det FROM public.detention_active(v_j.accuse);
  IF v_det.id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  v_jours := coalesce((SELECT sum((m->>'jours')::int)
                         FROM jsonb_array_elements(coalesce(v_j.data->'motifs', '[]'::jsonb)) m), 0);
  IF v_jours <= 0 THEN v_jours := 3; END IF;   -- meme repli que le flagrant delit du client
  v_motif := coalesce(v_j.motif, 'Avis de recherche');

  v_res := public.detention_ouvrir_interne(
             v_j.accuse, v_motif, v_jours, coalesce(p_ville, v_j.city), v_j.country,
             coalesce(v_j.data->'motifs', '[]'::jsonb), v_acteur,
             coalesce(v_j.data->>'issue_judiciaire', 'condamnation_executee'));
  IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN v_res;
  END IF;

  UPDATE public.jugements SET executee = true WHERE id = p_jugement_id;

  RETURN jsonb_build_object('ok', true, 'accuse', v_j.accuse, 'jours', v_jours,
                            'detention_id', v_res->>'detention_id', 'motif', v_motif);
END; $function$;

-- justice_executer_condamnation_soi(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation_soi(p_jugement_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text;
  v_j public.jugements%ROWTYPE;
  v_city text;
  v_jours integer;
  v_res jsonb;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie');
  END IF;
  SELECT current_city INTO v_city FROM public.personnages_donnees WHERE name = v_acteur;
  IF v_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_inconnue');
  END IF;
  SELECT * INTO v_j FROM public.jugements
   WHERE id = p_jugement_id AND accuse = v_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_non_autorisee');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_executee');
  END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active(v_acteur)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_detenu');
  END IF;
  SELECT coalesce(sum((m->>'jours')::integer),0) INTO v_jours
    FROM jsonb_array_elements(coalesce(v_j.data->'motifs','[]'::jsonb)) m;
  IF v_jours <= 0 THEN v_jours := 3; END IF;
  v_res := public.detention_ouvrir_interne(
    v_acteur, coalesce(v_j.motif,'Condamnation'), v_jours,
    v_city, v_j.country, coalesce(v_j.data->'motifs','[]'::jsonb),
    'interception_policiere', coalesce(v_j.data->>'issue_judiciaire','condamnation_executee'));
  IF NOT coalesce((v_res->>'ok')::boolean,false) THEN RETURN v_res; END IF;
  UPDATE public.jugements SET executee = true WHERE id = v_j.id;
  RETURN jsonb_build_object('ok',true,'jours',v_jours,'detention_id',v_res->>'detention_id',
    'motif',coalesce(v_j.motif,'Condamnation'));
END;
$function$;

-- justice_fenetre_appel_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_fenetre_appel_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 2 $function$;

-- justice_greffe_competent(text,text) -> TABLE(batiment text, piece text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_greffe_competent(p_pays text, p_ville text)
 RETURNS TABLE(batiment text, piece text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Le BATIMENT est celui que `parquet_site_competent` designe deja -- une seule regle pour le
  -- tribunal competent. La PIECE est le greffe, et elle porte le meme nom dans les deux gabarits.
  SELECT public.parquet_site_competent(p_pays, p_ville), 'greffe'
   WHERE public.parquet_site_competent(p_pays, p_ville) IS NOT NULL;
$function$;

-- justice_indemnite_naitre(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_indemnite_naitre(p_pays text, p_beneficiaire text, p_affaire text, p_jugement text, p_jours integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_montant integer; v_id text; v_caisse text; v_data jsonb; v_solde numeric;
  v_porteur text; v_paye integer := 0; v_r jsonb;
BEGIN
  IF coalesce(p_jours, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'indemnite', false, 'raison', 'aucun_jour_indu');
  END IF;
  v_montant := p_jours * public.justice_indemnite_par_jour();
  v_id := 'ind-' || substr(md5(coalesce(p_affaire, '') || '|' || p_beneficiaire || '|'
                               || coalesce(p_jugement, '')), 1, 16);
  -- IDEMPOTENCE PAR IDENTIFIANT DERIVE : un jugement d'appel rejoue ne cree pas deux creances.
  IF EXISTS (SELECT 1 FROM public.justice_indemnites WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'indemnite', true, 'deja_nee', true, 'id', v_id);
  END IF;

  -- PREMIER ETAGE : LA JUSTICE PAIE TOUT, OU NE PAIE RIEN. Pas de paiement composite -- c'est
  -- une regle explicite, et elle evite qu'une creance soit a cheval sur deux budgets.
  v_caisse := p_pays || '_gouvernement-min_just';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  v_solde := CASE WHEN v_data IS NOT NULL AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;

  IF v_solde >= v_montant THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_montant),
           updated_at = now()
     WHERE id = v_caisse;
    UPDATE public.personnages_donnees
       SET arg = coalesce(arg, 0) + v_montant
     WHERE name = p_beneficiaire;
    v_porteur := 'min_just'; v_paye := v_montant;
  ELSE
    -- RIEN N'EST PRELEVE CHEZ LA JUSTICE. La creance change de porteur, definitivement.
    v_porteur := 'min_fin'; v_paye := 0;
  END IF;

  INSERT INTO public.justice_indemnites
    (id, pays, beneficiaire, affaire, jugement, jours_indus, montant_du, montant_paye,
     porteur, etat, regle_le)
  VALUES (v_id, p_pays, p_beneficiaire, p_affaire, p_jugement, p_jours, v_montant, v_paye,
          v_porteur, CASE WHEN v_paye = v_montant THEN 'reglee' ELSE 'due' END,
          CASE WHEN v_paye = v_montant THEN now() ELSE NULL END);

  -- SECOND ETAGE : LES FINANCES PAIENT L'INTEGRALITE, OU LA DETTE RESTE. Le partiel n'est permis
  -- qu'aux alimentations ulterieures de leur caisse -- d'ou `p_partiel => false` ici.
  IF v_porteur = 'min_fin' THEN
    v_r := public.justice_indemnites_payer_depuis_finances(p_pays, false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'indemnite', true, 'id', v_id,
    'jours_indus', p_jours, 'montant', v_montant, 'porteur', v_porteur,
    'paye', (SELECT montant_paye FROM public.justice_indemnites WHERE id = v_id),
    'etat', (SELECT etat FROM public.justice_indemnites WHERE id = v_id));
END;
$function$;

-- justice_indemnite_par_jour() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_indemnite_par_jour()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 1000 $function$;

-- justice_indemnites_payer_depuis_finances(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_indemnites_payer_depuis_finances(p_pays text, p_partiel boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caisse text; v_data jsonb; v_solde numeric; v_c record;
  v_reste integer; v_verse integer; v_total integer := 0; v_n integer := 0;
BEGIN
  v_caisse := p_pays || '_gouvernement-min_fin';

  FOR v_c IN
    SELECT i.* FROM public.justice_indemnites i
     WHERE i.pays = p_pays AND i.etat = 'due' AND i.porteur = 'min_fin'
     ORDER BY i.rang
     FOR UPDATE
  LOOP
    SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_solde := CASE WHEN v_data IS NOT NULL AND jsonb_typeof(v_data -> 'solde') = 'number'
                    THEN (v_data ->> 'solde')::numeric ELSE 0 END;
    IF v_solde <= 0 THEN EXIT; END IF;

    v_reste := v_c.montant_du - v_c.montant_paye;
    v_verse := least(v_reste, floor(v_solde)::integer);
    IF v_verse <= 0 THEN EXIT; END IF;
    IF v_verse < v_reste AND NOT coalesce(p_partiel, true) THEN EXIT; END IF;

    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = v_caisse;

    UPDATE public.personnages_donnees
       SET arg = coalesce(arg, 0) + v_verse
     WHERE name = v_c.beneficiaire;

    UPDATE public.justice_indemnites
       SET montant_paye = v_c.montant_paye + v_verse,
           etat = CASE WHEN v_c.montant_paye + v_verse = v_c.montant_du THEN 'reglee' ELSE 'due' END,
           regle_le = CASE WHEN v_c.montant_paye + v_verse = v_c.montant_du THEN now() ELSE NULL END
     WHERE id = v_c.id;

    v_total := v_total + v_verse;
    v_n := v_n + 1;
    IF v_c.montant_paye + v_verse < v_c.montant_du THEN EXIT; END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'verse', v_total, 'creances_touchees', v_n);
END;
$function$;

-- justice_indemnites_sur_alimentation() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_indemnites_sur_alimentation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_av numeric; v_ap numeric; v_pays text;
BEGIN
  -- RECURSION : le paiement DEBITE cette meme caisse, donc ce declencheur se rappelle. Le garde
  -- est double -- un verrou de portee, et le fait qu'une BAISSE ne declenche rien.
  IF coalesce(current_setting('rp.indemnites_en_cours', true), '') = 'on' THEN
    RETURN NEW;
  END IF;
  IF NEW.id NOT LIKE '%\_gouvernement-min\_fin' THEN RETURN NEW; END IF;

  v_av := CASE WHEN jsonb_typeof(OLD.data -> 'solde') = 'number'
               THEN (OLD.data ->> 'solde')::numeric ELSE 0 END;
  v_ap := CASE WHEN jsonb_typeof(NEW.data -> 'solde') = 'number'
               THEN (NEW.data ->> 'solde')::numeric ELSE 0 END;
  IF v_ap <= v_av THEN RETURN NEW; END IF;

  v_pays := split_part(NEW.id, '_gouvernement-min_fin', 1);
  IF coalesce(v_pays, '') = '' THEN RETURN NEW; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.justice_indemnites
                  WHERE pays = v_pays AND etat = 'due' AND porteur = 'min_fin') THEN
    RETURN NEW;
  END IF;

  PERFORM set_config('rp.indemnites_en_cours', 'on', true);
  PERFORM public.justice_indemnites_payer_depuis_finances(v_pays, true);
  PERFORM set_config('rp.indemnites_en_cours', '', true);
  RETURN NEW;
END;
$function$;

-- justice_jours_purges(text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_jours_purges(p_detention_id text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0,
           coalesce(d.jour_fin_effective, coalesce(c.day, 1)) - d.jour_debut)
    FROM public.detentions d
    LEFT JOIN public.personnages_donnees c ON c.name = d.nom
   WHERE d.id = p_detention_id;
$function$;

-- justice_juge_titulaire(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_juge_titulaire(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT d.name FROM public.personnages_donnees d
      WHERE d.country = p_pays AND (d.poste ->> 'id') = 'juge'
        AND (d.poste ->> 'city') IS NOT DISTINCT FROM p_ville LIMIT 1),
    (SELECT t.nom_pnj FROM public.titulaires_pnj t
      WHERE t.country = p_pays AND t.poste_id = 'juge'
        AND t.city IS NOT DISTINCT FROM p_ville LIMIT 1));
$function$;

-- justice_mes_indemnites() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_mes_indemnites()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN jsonb_build_object('ok', true, 'indemnites', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'id', i.id, 'affaire', i.affaire, 'jours_indus', i.jours_indus,
             'du', i.montant_du, 'paye', i.montant_paye,
             'reste', i.montant_du - i.montant_paye,
             'porteur', i.porteur, 'etat', i.etat,
             'cree_le', i.cree_le, 'regle_le', i.regle_le) ORDER BY i.rang)
      FROM public.justice_indemnites i WHERE i.beneficiaire = v_moi), '[]'::jsonb));
END;
$function$;

-- justice_peine_calcul(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_peine_calcul(p_infraction text, p_genre text, p_cible text, p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_b jsonb; v_n integer; v_jmin integer; v_jmax integer;
        v_amin integer; v_amax integer; v_impose boolean := false;
BEGIN
  IF p_genre NOT IN ('prison', 'amende', 'amenagement', 'qhs', 'torture') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'genre_inconnu', 'genre', p_genre);
  END IF;

  v_b := public.infraction_peine_bornes(p_infraction);
  IF coalesce((v_b ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_b;   -- infraction_inconnue : le refus porte deja sa raison
  END IF;

  v_jmin := (v_b ->> 'jours_min')::integer;  v_jmax := (v_b ->> 'jours_max')::integer;
  v_amin := (v_b ->> 'amende_min')::integer; v_amax := (v_b ->> 'amende_max')::integer;

  IF p_genre = 'prison' THEN
    -- La modulation du juge porte sur les JOURS, dans la plage du catalogue. Aucune amende : le
    -- jeu n'en preleve aucune aujourd'hui (voir le genre `amende` ci-dessous).
    v_amin := 0; v_amax := 0;

  ELSIF p_genre = 'amende' THEN
    -- La modulation porte sur le MONTANT. Aucun jour de detention.
    -- DETTE NOMMEE, NON TRAITEE ICI : l'amende n'est PRELEVEE nulle part. `appliquerSentence`
    -- composait « Amende de 500 FR » -- un 500 en dur, sans rapport avec le bareme -- et
    -- n'appelait aucune porte de debit. Le montant devient au moins REEL (celui du catalogue,
    -- modulable) et verifie ; le prelevement reste a construire.
    v_jmin := 0; v_jmax := 0;

  ELSIF p_genre = 'amenagement' THEN
    -- Mention au registre, sans consequence mecanique -- c'etait deja le cas.
    v_jmin := 0; v_jmax := 0; v_amin := 0; v_amax := 0; v_impose := true;

  ELSIF p_genre = 'qhs' THEN
    -- TRENTE JOURS, RECOPIES DE LA REGLE VALIDEE, pas derives du catalogue : le QHS n'est pas une
    -- peine du code penal, c'est une mecanique a part, arbitree le 26 aout 2026 et inchangee ici.
    -- Le serveur l'IMPOSE desormais, au lieu de recevoir du navigateur une duree qu'il n'a jamais
    -- verifiee.
    v_jmin := 30; v_jmax := 30; v_amin := 0; v_amax := 0; v_impose := true;

  ELSE   -- torture
    -- TROIS JOURS PAR CONDAMNATION, CUMULES, RECOPIES DE LA REGLE VALIDEE. Le cumul se comptait
    -- cote navigateur (`sbGetActionsTracablesParAuteur`) : il se compte ici, sur la meme trace
    -- `condamnation_torture`, qui est ecrite avec une expiration a +36500 jours et ne s'eteint
    -- donc jamais. C'est la meme formule, deplacee la ou elle ne peut plus etre reecrite.
    SELECT count(*) INTO v_n FROM public.actions_tracables a
     WHERE a.auteur = p_cible AND a.type_action = 'condamnation_torture'
       AND a.country IS NOT DISTINCT FROM p_pays;
    v_jmin := 3 * (v_n + 1); v_jmax := v_jmin; v_amin := 0; v_amax := 0; v_impose := true;
  END IF;

  RETURN v_b || jsonb_build_object(
    'genre', p_genre,
    'jours_min', v_jmin, 'jours_max', v_jmax,
    'amende_min', v_amin, 'amende_max', v_amax,
    -- `impose` dit a l'ecran qu'il n'y a RIEN a moduler : la valeur est celle-la et pas une autre.
    'impose', v_impose,
    -- La valeur par defaut proposee au juge : la reference du catalogue pour les genres
    -- modulables, la valeur imposee sinon. Toujours dans la plage, par construction.
    'jours_defaut', CASE WHEN v_impose THEN v_jmin
                         WHEN p_genre = 'prison' THEN (v_b ->> 'jours_reference')::integer
                         ELSE 0 END,
    'amende_defaut', CASE WHEN p_genre = 'amende' THEN (v_b ->> 'amende_reference')::integer
                          ELSE 0 END);
END;
$function$;

-- justice_peine_proposer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_peine_proposer(p_affaire_id text, p_infraction text, p_genre text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- MEME REGLE D'AUTORITE QUE LA PORTE D'ENREGISTREMENT, lue en base : juge ou commissaire DE LA
  -- VILLE de l'affaire. Un ecran qui s'ouvrirait sans elle promettrait une competence absente.
  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') = 'jugee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_deja_jugee'); END IF;

  RETURN public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays)
         || jsonb_build_object('affaire', p_affaire_id,
                               'accuse', v_a ->> 'cible',
                               'motif_allegue', v_a ->> 'motif');
END;
$function$;

-- justice_preuve_reelle(text,text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_preuve_reelle(p_pays text, p_accuse text, p_infraction text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- L'EXPIRATION SE LIT SUR L'HORLOGE QUI A ECRIT LA TRACE : `actions_tracables.jour` et
  -- `jour_expiration` sont poses depuis le `day` de la fiche de l'auteur, jamais depuis
  -- l'horloge partagee du pays. Les melanger donnerait des traces perimees ou eternelles.
  SELECT EXISTS (
    SELECT 1 FROM public.actions_tracables t
     WHERE t.country IS NOT DISTINCT FROM p_pays
       AND t.auteur = p_accuse
       AND t.type_action = p_infraction
       AND coalesce(t.jour_expiration, 0)
           >= coalesce((SELECT d.day FROM public.personnages_donnees d WHERE d.name = p_accuse), 1));
$function$;

-- justice_prolonger_peine(text,jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_prolonger_peine(p_cible text, p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_juge text; v_r jsonb;
BEGIN
  v_juge := public.exiger_poste('juge');
  v_r := public.detention_prolonger_interne(p_cible, p_motifs, p_forcer_qhs);
  IF coalesce((v_r ->> 'ok')::boolean, false) THEN
    RETURN v_r || jsonb_build_object('juge', v_juge);
  END IF;
  RETURN v_r;
END; $function$;

-- justice_recherches(text) -> TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_recherches(p_nom text)
 RETURNS TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_autorise boolean := false;
BEGIN
  IF public.est_appel_serveur() THEN
    v_autorise := true;
  ELSE
    v_moi := public.mon_personnage();
    IF v_moi IS NOT NULL THEN
      -- Soi-meme : un joueur peut savoir qu'il est recherche.
      IF v_moi = p_nom THEN
        v_autorise := true;
      ELSE
        -- Autorite judiciaire, dans son propre pays.
        SELECT true INTO v_autorise
          FROM public.acteur_poste_courant() a
          JOIN public.personnages_donnees c ON c.name = p_nom
         WHERE a.poste_id IN ('commissaire','juge','min_just','min_int','president')
           AND a.pays = c.country
         LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF NOT coalesce(v_autorise, false) THEN RETURN; END IF;

  -- `motif_allegue` EST RETIRE DE CE QUI SORT (13 octobre 2026). C'est le texte libre du
  -- plaignant, recopie sur la condamnation depuis le dossier : il n'a rien a faire sur un avis de
  -- recherche, que l'autorite lit pour savoir QUI chercher, pour QUELLE qualification, OU et
  -- pour COMBIEN de jours. Le retrait est inconditionnel -- meme pour la personne recherchee
  -- elle-meme, qui lit le texte du plaignant sur SON dossier par sa propre porte, pas ici.
  RETURN QUERY
    SELECT j.id, j.country, j.city, j.motif,
           coalesce((SELECT sum((m->>'jours')::int)
                       FROM jsonb_array_elements(coalesce(j.data->'motifs', '[]'::jsonb)) m), 0)::int,
           (j.data - 'motif_allegue')
      FROM public.jugements j
     WHERE j.accuse = p_nom AND j.executee = false
     ORDER BY j.created_at;
END;
$function$;

-- justice_relaxer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_relaxer(p_affaire_id text, p_infraction text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_inf text; v_lib text; v_parquet text; v_jug text; v_n integer;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville);
  END IF;
  -- ON NE RELAXE QUE SUR UNE AFFAIRE REGULIEREMENT SAISIE. Sans saisine, il n'y a rien a juger.
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status');
  END IF;
  -- LE DELAI DE PREMIERE INSTANCE EST OPPOSABLE AU JUGE AUSSI (12 octobre 2026, nuit).
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;
  -- L'AUDIENCE OBLIGATOIRE (13 octobre 2026). UNE RELAXE EST UN VERDICT, pas une absence de
  -- decision : elle ne se prononce pas plus qu'une condamnation avant que le proces ait eu lieu.
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte',
                              'audience_jour', (v_a ->> 'audience_jour')::integer);
  END IF;

  -- LA RELAXE PORTE SUR UNE QUALIFICATION : on relaxe de QUELQUE CHOSE. Par defaut celle du
  -- parquet ; le juge peut requalifier avant de relaxer, et les deux restent lisibles.
  v_parquet := v_a ->> 'qualification_parquet';
  v_inf := public.infraction_canonique(coalesce(p_infraction, v_parquet));
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
                              'demande', coalesce(p_infraction, v_parquet));
  END IF;
  SELECT libelle INTO v_lib FROM public.infractions WHERE id = v_inf;
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;

  -- UNE RELAXE EST UN JUGEMENT, et elle a donc sa ligne au registre -- avec `peine` NULL, pas
  -- une peine de zero. C'est la difference entre « relaxe » et « condamne a rien ».
  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible', v_lib, NULL,
          v_j.nom, coalesce(v_jour, 1), true,
          jsonb_build_object('verdict', 'relaxe', 'infraction', v_inf,
            'infraction_libelle', v_lib, 'qualification_parquet', v_parquet,
            'motif_allegue', v_a ->> 'motif', 'motifs', '[]'::jsonb))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  -- REQUALIFICATION AVANT RELAXE : fait distinct, consigne avant le verdict.
  IF v_parquet IS NOT NULL AND v_inf IS DISTINCT FROM v_parquet THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
      'requalification', v_j.nom, 'juge', v_parquet, v_inf);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'relaxe',
           'verdict', 'relaxe',
           'juge', v_j.nom,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_inf,
           'qualification_libelle', v_lib))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'relaxe',
    v_j.nom, 'juge', v_parquet, v_inf, jsonb_build_object('accuse', v_a ->> 'cible'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'verdict', 'relaxe',
    'jugement_id', v_jug, 'juge', v_j.nom, 'infraction', v_inf, 'libelle', v_lib);
END;
$function$;

-- justice_rendre_sentence(text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_rendre_sentence(p_affaire_id text, p_infraction text, p_genre text, p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_calc jsonb; v_jours integer; v_amende integer; v_libelle text; v_peine text;
  v_jug text; v_n integer; v_motifs jsonb; v_parquet text;
  v_det record; v_exec jsonb; v_executee boolean := false; v_jour_pays integer;
BEGIN
  IF coalesce(btrim(coalesce(p_affaire_id, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_invalide'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;

  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status'); END IF;

  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer); END IF;

  -- L'AUDIENCE OBLIGATOIRE (13 octobre 2026). Une affaire qui releve de la procedure complete ne
  -- se juge pas sans proces : l'audience doit avoir ete fixee ET OUVERTE. Le refus est place
  -- APRES le delai pour ne rien changer a l'ordre des refus existants -- une affaire dont le
  -- delai a expire est morte, audience ou pas.
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte',
                              'audience_jour', (v_a ->> 'audience_jour')::integer); END IF;

  v_calc := public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays);
  IF coalesce((v_calc ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_calc; END IF;

  v_jours  := coalesce(p_jours, 0);
  v_amende := coalesce(p_amende, 0);

  IF v_jours < (v_calc ->> 'jours_min')::integer
     OR v_jours > (v_calc ->> 'jours_max')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'peine_hors_bornes',
      'demande_jours', v_jours,
      'jours_min', (v_calc ->> 'jours_min')::integer,
      'jours_max', (v_calc ->> 'jours_max')::integer,
      'jours_reference', (v_calc ->> 'jours_reference')::integer);
  END IF;
  IF v_amende < (v_calc ->> 'amende_min')::integer
     OR v_amende > (v_calc ->> 'amende_max')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'amende_hors_bornes',
      'demande_amende', v_amende,
      'amende_min', (v_calc ->> 'amende_min')::integer,
      'amende_max', (v_calc ->> 'amende_max')::integer,
      'amende_reference', (v_calc ->> 'amende_reference')::integer);
  END IF;

  -- DEUX HORLOGES, ET CHACUNE A SA PLACE. `v_jour` est le compteur personnel du juge : il datait
  -- deja `jugements.jour` avant cette tranche, et le changer reecrirait l'histoire. `v_jour_pays`
  -- est l'horloge PARTAGEE, et c'est la seule sur laquelle une echeance OPPOSABLE puisse vivre --
  -- celui qui interjette appel n'est pas le juge.
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;
  v_jour := coalesce(v_jour, 1);
  v_jour_pays := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_libelle := v_calc ->> 'libelle';
  v_parquet := v_a ->> 'qualification_parquet';

  v_peine := CASE p_genre
    WHEN 'prison'      THEN 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
    WHEN 'amende'      THEN 'Amende de ' || v_amende || ' FR'
    WHEN 'amenagement' THEN 'Amenagement : pointage quotidien au commissariat'
    WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'
    ELSE                    'Prison ' || v_jours || ' jours + popularite a zero'
  END;

  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_libelle, 'infraction', v_calc ->> 'infraction', 'jours', v_jours,
      'city', v_ville, 'source', 'jugement',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible',
          v_libelle, v_peine, v_j.nom, v_jour, false,
          jsonb_build_object(
            'verdict', 'condamnation', 'instance', 'premiere',
            'infraction', v_calc ->> 'infraction',
            'infraction_libelle', v_libelle,
            'genre', p_genre,
            'jours', v_jours, 'amende', v_amende,
            'jours_reference', (v_calc ->> 'jours_reference')::integer,
            'jours_min', (v_calc ->> 'jours_min')::integer,
            'jours_max', (v_calc ->> 'jours_max')::integer,
            'amende_reference', (v_calc ->> 'amende_reference')::integer,
            'jour_pays', v_jour_pays,
            'appel_jusqu_au_jour_pays', v_jour_pays + public.justice_fenetre_appel_jours(),
            'categorie_alleguee', v_a ->> 'categorie_alleguee',
            'motif_allegue', v_a ->> 'motif',
            'qualification_parquet', v_parquet,
            'motifs', v_motifs,
            'issue_judiciaire', v_peine))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  IF v_parquet IS NOT NULL AND (v_calc ->> 'infraction') IS DISTINCT FROM v_parquet THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
      'requalification', v_j.nom, 'juge', v_parquet, v_calc ->> 'infraction');
  END IF;

  IF v_jours > 0 THEN
    SELECT * INTO v_det FROM public.detention_active(v_a ->> 'cible');
    IF v_det.id IS NULL THEN
      v_exec := public.detention_ouvrir_interne(
                  v_a ->> 'cible', v_libelle, v_jours, coalesce(v_ville, 'capitale'), v_pays,
                  v_motifs, v_j.nom, coalesce(v_peine, 'condamnation_executee'));
      IF coalesce((v_exec ->> 'ok')::boolean, false) THEN
        UPDATE public.jugements SET executee = true WHERE id = v_jug;
        v_executee := true;
      END IF;
    END IF;
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'jugee',
           'verdict', 'condamnation',
           'juge', v_j.nom,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'jugement_jour', v_jour,
           'jugement_jour_pays', v_jour_pays,
           'appel_jusqu_au_jour', v_jour_pays + public.justice_fenetre_appel_jours(),
           'qualification_finale', v_calc ->> 'infraction',
           'qualification_libelle', v_libelle,
           'peine_genre', p_genre,
           'peine_jours', v_jours,
           'peine_amende', v_amende,
           'peine_libelle', v_peine,
           'detention_id', v_exec ->> 'detention_id'))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'condamnation',
    v_j.nom, 'juge', v_parquet, v_calc ->> 'infraction',
    jsonb_build_object('accuse', v_a ->> 'cible', 'genre', p_genre,
                       'jours', v_jours, 'amende', v_amende,
                       'jours_reference', (v_calc ->> 'jours_reference')::integer,
                       'executee', v_executee, 'instance', 'premiere'));

  RETURN jsonb_build_object('ok', true, 'jugement_id', v_jug, 'affaire', p_affaire_id,
    'juge', v_j.nom, 'jour', v_jour, 'jugement_cree', true,
    'infraction', v_calc ->> 'infraction', 'infraction_libelle', v_libelle,
    'qualification_parquet', v_parquet,
    'requalifiee', (v_parquet IS NOT NULL AND (v_calc ->> 'infraction') IS DISTINCT FROM v_parquet),
    'genre', p_genre, 'jours', v_jours, 'amende', v_amende, 'peine', v_peine,
    'motifs', v_motifs, 'executee', v_executee,
    'detention_id', v_exec ->> 'detention_id',
    'appel_jusqu_au_jour', v_jour_pays + public.justice_fenetre_appel_jours());
END;
$function$;

-- justice_salle_audience_competente(text,text) -> TABLE(batiment text, piece text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_salle_audience_competente(p_pays text, p_ville text)
 RETURNS TABLE(batiment text, piece text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT s.b,
         CASE WHEN s.b = 'tribunal' THEN 'salle_audience'
              WHEN s.b = 'tribunal-local' THEN 'salle_audience_locale'
              ELSE NULL END
    FROM (SELECT public.parquet_site_competent(p_pays, p_ville) AS b) s
   WHERE s.b IS NOT NULL;
$function$;

-- justice_seuil_procedure_simplifiee_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_seuil_procedure_simplifiee_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 2 $function$;

-- justice_statuts_publics() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_statuts_publics()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_p record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_p
    FROM public.presences pr WHERE pr.name = v_moi;
  IF v_p IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'statuts', '[]'::jsonb);
  END IF;

  RETURN jsonb_build_object('ok', true, 'statuts', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'nom', x.nom, 'recherche', x.recherche, 'inculpe', x.inculpe) ORDER BY x.nom)
      FROM (
        SELECT pr.name AS nom,
               public.justice_est_recherche(pr.name) AS recherche,
               EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(pr.name)) AS inculpe
          FROM public.presences pr
         WHERE pr.country IS NOT DISTINCT FROM v_p.country
           AND pr.city IS NOT DISTINCT FROM v_p.city
           AND pr.building_id IS NOT DISTINCT FROM v_p.building_id
           AND pr.room_id IS NOT DISTINCT FROM v_p.room_id
      ) x
      WHERE x.recherche OR x.inculpe), '[]'::jsonb));
END;
$function$;

-- minuit_amendes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.minuit_amendes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a record; limite integer; appel boolean; n_exigibles int := 0; n_preleves int := 0; total int := 0; pris int;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur'); END IF;
  FOR a IN SELECT * FROM public.amendes_tresor WHERE statut = 'suspendue' FOR UPDATE LOOP
    SELECT coalesce(a.appel_jusqu_au_jour_pays, nullif(j.data->>'appel_jusqu_au_jour_pays','')::integer) INTO limite
      FROM public.jugements j WHERE j.id = a.jugement_id;
    SELECT coalesce((p.data::jsonb ? 'appel_ouvert_le'), false) INTO appel FROM public.plaintes_en_cours p WHERE p.id = a.affaire_id;
    IF coalesce(appel, false) THEN CONTINUE; END IF;
    IF limite IS NOT NULL AND coalesce(public.jour_de_jeu_pays(a.pays), 1) > limite THEN
      UPDATE public.amendes_tresor SET statut = 'due', updated_at = now() WHERE jugement_id = a.jugement_id;
      n_exigibles := n_exigibles + 1;
    END IF;
  END LOOP;
  FOR a IN SELECT jugement_id FROM public.amendes_tresor WHERE statut = 'due' LOOP
    pris := public.amende_prelever_interne(a.jugement_id);
    IF pris > 0 THEN n_preleves := n_preleves + 1; total := total + pris; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'exigibles', n_exigibles, 'preleves', n_preleves, 'total', total);
END;
$function$;

-- minuit_convocations() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.minuit_convocations()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_c jsonb; v_n integer := 0; v_det jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR r IN SELECT name, convocations FROM public.personnages_donnees
            WHERE jsonb_typeof(convocations) = 'array' AND jsonb_array_length(convocations) > 0 LOOP
    SELECT e INTO v_c FROM jsonb_array_elements(r.convocations) e WHERE public.convocation_echue_interne(e) LIMIT 1;
    IF v_c IS NOT NULL THEN
      PERFORM public.convocation_marquer_interne(r.name, v_c);
      v_det := public.convocation_detention_interne(r.name, 'Non-présentation à une convocation', 2);
      PERFORM public.mail_systeme_poser_interne('Commissariat', r.name, 'Non-présentation',
        'Vous ne vous êtes pas présenté(e) dans le délai imparti suite à votre convocation. Vous êtes arrêté(e) pour deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
      v_n := v_n + 1;
    END IF;
    v_c := NULL;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'sanctionnees', v_n);
END; $function$;

-- minuit_couvre_feu_recherche(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.minuit_couvre_feu_recherche(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_jour text := ((now() AT TIME ZONE 'Europe/Paris')::date)::text;
  v_now_ms bigint := (extract(epoch from now()) * 1000)::bigint;
  v_cf jsonb; v_rech jsonb; v_arme text; v_coefs jsonb; v_cmd text; v_touches integer := 0;
  v_out jsonb := '{}'::jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data) <> 'object' THEN RETURN jsonb_build_object('ok', true, 'budget', 'absent'); END IF;

  v_cf := v_data -> 'couvreFeu';
  IF jsonb_typeof(v_cf) = 'object' AND coalesce((v_cf ->> 'actif')::boolean, false) THEN
    IF (v_cf ->> 'dateFin') IS NOT NULL AND v_now_ms > (v_cf ->> 'dateFin')::numeric THEN
      v_data := jsonb_set(v_data, '{couvreFeu,actif}', 'false'::jsonb);
      v_out := v_out || jsonb_build_object('couvre_feu', 'expire');
    ELSIF v_data ->> 'dernierEffetCouvreFeuJour' IS DISTINCT FROM v_jour THEN
      UPDATE public.personnages_donnees d
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(d.resources) = 'object' THEN d.resources ELSE '{}'::jsonb END,
               '{pop}', to_jsonb(greatest(0, coalesce(CASE WHEN jsonb_typeof(d.resources -> 'pop') = 'number'
                                                           THEN (d.resources ->> 'pop')::numeric END, 50) - 2)))
       WHERE d.country = p_pays
         AND d.poste ->> 'id' IN ('president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae');
      GET DIAGNOSTICS v_touches = ROW_COUNT;
      v_data := v_data || jsonb_build_object('dernierEffetCouvreFeuJour', v_jour);
      v_out := v_out || jsonb_build_object('couvre_feu', 'effet', 'titulaires', v_touches);
    END IF;
  END IF;

  v_rech := v_data #> '{rechercheMilitaire,enCours}';
  IF jsonb_typeof(v_rech) = 'object' AND (v_rech ->> 'dateFin') IS NOT NULL
     AND v_now_ms >= (v_rech ->> 'dateFin')::numeric THEN
    v_arme := v_rech ->> 'arme';
    v_coefs := CASE WHEN jsonb_typeof(v_data -> 'coefficientsArmesAcquis') = 'object' THEN v_data -> 'coefficientsArmesAcquis' ELSE '{}'::jsonb END;
    v_coefs := jsonb_set(v_coefs, ARRAY[v_arme], to_jsonb(coalesce((v_coefs ->> v_arme)::numeric, 0) + 0.5));
    v_data := v_data || jsonb_build_object('coefficientsArmesAcquis', v_coefs);
    v_data := jsonb_set(v_data, '{rechercheMilitaire,enCours}', 'null'::jsonb);
    PERFORM public.annonce_publique_interne(p_pays, 'Recherche militaire achevée : le coefficient de tir de « '
      || coalesce(v_arme, '?') || ' » est amélioré pour toute la nation.');
    SELECT name INTO v_cmd FROM public.personnages_donnees WHERE country = p_pays AND poste ->> 'id' = 'commandant' LIMIT 1;
    IF v_cmd IS NOT NULL THEN
      PERFORM public.mail_systeme_poser_interne('Chercheurs Civils', v_cmd, 'Recherche achevée',
        'Le programme de recherche sur « ' || coalesce(v_arme, '?') || ' » est terminé. Coefficient amélioré.');
    END IF;
    v_out := v_out || jsonb_build_object('recherche', v_arme);
  END IF;

  UPDATE public.budgets_nationaux SET data = v_data WHERE id = p_pays;
  RETURN jsonb_build_object('ok', true) || v_out;
END; $function$;

-- minuit_decouverte_crimes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.minuit_decouverte_crimes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; t jsonb; v_rate integer; v_jours integer; v_amende integer; v_n integer := 0; v_label text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR r IN SELECT name, country, coalesce(current_city, 'capitale') AS city, historique_crimes FROM public.personnages_donnees
            WHERE jsonb_typeof(historique_crimes) = 'array' AND jsonb_array_length(historique_crimes) > 0 LOOP
    FOR t IN SELECT e FROM jsonb_array_elements(r.historique_crimes) e
              WHERE e ->> 'origine' = 'serveur' AND NOT coalesce((e ->> 'decouvert')::boolean, false)
                AND (e ->> 'expireTs') IS NOT NULL AND now() < (e ->> 'expireTs')::timestamptz
                AND EXISTS (SELECT 1 FROM public.actes_illegaux a WHERE a.fn = e ->> 'acte' AND a.decouvrable) LOOP
      SELECT detect_rate INTO v_rate FROM public.actes_illegaux WHERE fn = t ->> 'acte';
      IF floor(random() * 100)::integer + 1 <= coalesce(v_rate, 25) THEN
        UPDATE public.personnages_donnees
           SET historique_crimes = (SELECT jsonb_agg(CASE WHEN e ->> 'id' = t ->> 'id' THEN e || '{"decouvert": true}'::jsonb ELSE e END)
                                      FROM jsonb_array_elements(historique_crimes) e)
         WHERE name = r.name;
        SELECT p.jours, p.amende INTO v_jours, v_amende FROM public.crime_peine_interne(t ->> 'acte', true) p;
        v_label := 'Affaire résolue : ' || replace(t ->> 'acte', '_', ' ');
        PERFORM public.detention_ouvrir_interne(r.name, v_label, v_jours, r.city, r.country,
          jsonb_build_array(jsonb_build_object('type', v_label, 'jours', v_jours, 'city', r.city, 'source', 'decouverte_differee',
            'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
          'Brigade Criminelle', 'decouverte_differee');
        IF coalesce(v_amende, 0) > 0 THEN
          PERFORM public.sanction_financiere_imposer_interne('decouverte-' || r.name || '-' || coalesce(t ->> 'id', md5(t::text)),
            'decouverte_crime', r.country, r.name, v_amende, 'tresor');
        END IF;
        PERFORM public.mail_systeme_poser_interne('Brigade Criminelle', r.name, 'Affaire résolue',
          'Une enquête a permis de vous identifier comme responsable d''un acte commis récemment. Vous êtes arrêté(e) : '
          || v_jours || ' jour(s), amende de ' || v_amende || ' FR.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
        v_n := v_n + 1;
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'decouvertes', v_n);
END; $function$;

-- organisation_extrait_duplicata(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisation_extrait_duplicata(p_organisation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_inv jsonb; v_brut text; v_o jsonb;
        v_jour integer; v_paye jsonb; v_doc jsonb; v_caisse text; v_original text;
        v_contenu jsonb; v_role text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT o.data INTO v_brut FROM public.organisations o WHERE o.id = p_organisation_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable');
  END IF;
  v_o := v_brut::jsonb;

  -- LE PRESIDENT OU LE SECRETAIRE, NOMMEMENT. Une organisation qui ne nomme ni l'un ni l'autre
  -- n'ouvre ce droit a personne -- c'est le choix assume de ne pas BRICOLER un repli sur le chef.
  v_role := CASE
    WHEN coalesce(v_o ->> 'president', '')  = v_moi THEN 'president'
    WHEN coalesce(v_o ->> 'secretaire', '') = v_moi THEN 'secretaire'
    ELSE NULL END;
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president_ou_au_secretaire');
  END IF;

  -- L'ORIGINAL DOIT EXISTER : pas d'extrait, pas de duplicata.
  SELECT d.id INTO v_original FROM public.documents_officiels d
   WHERE d.organisation = p_organisation_id AND d.genre = 'domiciliation_extrait'
     AND (d.donnees ->> 'motif') = 'constitution'
   ORDER BY d.emis_le LIMIT 1;
  IF v_original IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_extrait_original',
                              'organisation', p_organisation_id);
  END IF;

  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_caisse := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'orga_extrait_duplicata', 1, 75);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  PERFORM public.caisse_institution_mouvement(v_caisse, 75, true);

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);

  -- UN DUPLICATA DIT L'ETAT COURANT, A SA PROPRE DATE. Il n'est pas la photographie de
  -- l'original : c'est un extrait de plus, et il est fige a SA date comme l'original l'etait a
  -- la sienne. Sa provenance dit de quel original il est le duplicata.
  v_contenu := jsonb_build_object(
    'organisation', p_organisation_id, 'nom', v_o ->> 'nom', 'type', v_o ->> 'type',
    'syndicat_etudiant', coalesce((v_o ->> 'syndicat_etudiant')::boolean, false),
    'pays', coalesce(v_o ->> 'country', v_pays), 'ville', v_ville,
    'domicile', v_o ->> 'localId',
    'domicile_libelle', 'Salle de reunion de l''Universite',
    'president', v_o ->> 'president', 'fondateur', v_o ->> 'fondateur',
    'constituee_le_jour', v_o ->> 'creeLe', 'frais_de_greffe', 150,
    'duplicata', true, 'duplicata_de', v_original, 'duplicata_le_jour', v_jour);

  v_doc := public.document_officiel_emettre(
    'domiciliation_extrait', 'domiciliation_extrait', true,
    v_pays, v_ville, NULL, p_organisation_id, NULL, v_moi, v_moi, v_jour,
    'Extrait de domiciliation (duplicata) — ' || coalesce(v_o ->> 'nom', p_organisation_id),
    'Duplicata delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit la '
      || 'domiciliation telle qu''elle est a cette date.',
    'ti-building-community', v_contenu,
    jsonb_build_object('motif', 'duplicata', 'original', v_original, 'qualite', v_role));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'organisation_extrait_duplicata : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'organisation', p_organisation_id,
    'document', v_doc ->> 'document', 'original', v_original, 'qualite', v_role,
    'jour', v_jour, 'frais_de_greffe', 75);
END;
$function$;

-- parquet_abandonner(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_abandonner(p_affaire_id text, p_motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_avant text; v_apres text; v_motif text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['poursuites', 'saisie']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';
  v_avant := v_a ->> 'status';
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- Avant saisine : la procedure s'arrete. Apres saisine : le juge doit decider.
  v_apres := CASE WHEN v_avant = 'saisie' THEN 'abandon_demande' ELSE 'abandonnee' END;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', v_apres,
           'abandon_par', v_g ->> 'procureur',
           'abandon_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'abandon_motif_declare', v_motif,
           'abandon_apres_saisine', (v_avant = 'saisie')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = v_avant;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'abandon_poursuites', v_g ->> 'procureur', 'procureur', NULL, NULL,
    jsonb_build_object('apres_saisine', (v_avant = 'saisie'))
      || CASE WHEN v_motif IS NULL THEN '{}'::jsonb
              ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', v_apres,
                            'apres_saisine', (v_avant = 'saisie'));
END;
$function$;

-- parquet_dossiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_p record;
BEGIN
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_procureur');
  END IF;
  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom,
    'dossiers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'ville', p.city,
        'site', public.parquet_site_competent(p.country, p.city),
        'present', public.acteur_present_sur_site(v_p.nom, p.country, p.city,
                     public.parquet_site_competent(p.country, p.city), NULL),
        'dossier', p.data::jsonb,
        -- La chronologie accompagne le dossier : le parquet doit voir ce qui a deja ete fait.
        'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                     'rang', a.rang, 'type', a.type, 'libelle', t.libelle,
                     'acteur', a.acteur, 'poste', a.acteur_poste,
                     'qualif_avant', a.qualif_avant, 'qualif_apres', a.qualif_apres,
                     'donnees', a.donnees, 'fait_le', a.fait_le) ORDER BY a.rang), '[]'::jsonb)
                    FROM public.dossiers_judiciaires_actes a
                    JOIN public.dossiers_judiciaires_actes_types t ON t.type = a.type
                   WHERE a.affaire = p.id)
      ) ORDER BY p.created_at), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_p.pays
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')));
END;
$function$;
