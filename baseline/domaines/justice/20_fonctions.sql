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

-- affaire_autorite_de(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_autorite_de(p_city text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('juge', 'commissaire')
       -- Juridiction : la ville du POSTE doit etre celle de l'affaire.
       -- coalesce a 'capitale' pour les affaires anterieures sans ville.
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  );
$function$;

-- affaire_me_concerne(text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_me_concerne(p_data text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_json jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL OR p_data IS NULL OR left(btrim(p_data), 1) <> '{' THEN
    RETURN false;
  END IF;
  BEGIN
    v_json := p_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN false;   -- data illisible : on n'accorde rien
  END;
  RETURN (v_json ->> 'cible') = v_moi OR (v_json ->> 'plaignant') = v_moi;
END;
$function$;

-- affaire_statut(text) -> text | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_statut(p_data text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_data IS NULL OR left(btrim(p_data), 1) <> '{' THEN RETURN NULL; END IF;
  RETURN (p_data::jsonb ->> 'status');
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;   -- data illisible : aucune publicite accordee
END;
$function$;

-- arrestation_urgence(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.arrestation_urgence(p_cible text, p_motif text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_cible_pays text; v_cible_ville text;
  v_ville text; v_res jsonb; v_motifs jsonb; v_pnj record;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;

  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_int', 'min_just', 'commissaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente');
  END IF;
  IF p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;

  SELECT d.country, d.current_city INTO v_cible_pays, v_cible_ville
    FROM public.personnages_donnees d WHERE d.name = p_cible;

  IF v_cible_pays IS NULL THEN
    -- Pas de fiche : l'adaptateur repond, ou la cible reste introuvable.
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_cible, v_pays);
    IF v_pnj.systeme IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_arretable',
                                'niveau_connu', v_pnj.niveau_connu, 'niveau_requis', 2);
    END IF;
    v_cible_pays  := v_pnj.pays;
    v_cible_ville := v_pnj.ville;
  END IF;

  IF v_cible_pays IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF v_poste = 'commissaire' THEN
    IF v_poste_city IS NULL OR v_cible_ville IS DISTINCT FROM v_poste_city THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction_ville');
    END IF;
    v_ville := v_poste_city;
  ELSE
    v_ville := coalesce(v_cible_ville, 'capitale');
  END IF;

  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Arrestation d''urgence : ' || p_motif,
    'jour_fait', coalesce((SELECT d.day FROM public.personnages_donnees d WHERE d.name = p_cible),
                          public.jour_de_jeu_pays(v_pays)),
    'city', v_ville, 'jours', 1, 'source', 'arrestation_urgence',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
    p_cible, 'Arrestation d''urgence (' || p_motif || ')', 1, v_ville, v_pays,
    v_motifs, v_nom || ' (' || v_poste || ')', 'arrestation_urgence');

  IF (v_res ->> 'ok') IS DISTINCT FROM 'true' THEN
    RETURN v_res;
  END IF;

  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'isn', 1);
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'social', -1);

  RETURN v_res || jsonb_build_object('cible', p_cible, 'ville', v_ville,
                                     'autorite', v_nom, 'poste', v_poste,
                                     'securite', 1, 'social', -1);
END;
$function$;

-- commissaire_enqueter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.commissaire_enqueter(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_poste_city text; v_pays text;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_poste_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' OR p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  RETURN public.plainte_instruire_interne(v_pays, v_poste_city, p_cible, 'enquete', v_nom);
END;
$function$;

-- detention_active(text) -> TABLE(id text, country text, city text, jour_debut integer, jour_fin integer, qhs boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_active(p_nom text)
 RETURNS TABLE(id text, country text, city text, jour_debut integer, jour_fin integer, qhs boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.id, d.country, d.city, d.jour_debut, d.jour_fin, coalesce(d.qhs, false)
    FROM public.detentions d
   WHERE d.nom = p_nom
     AND d.mode_fin IS NULL
     AND d.jour_fin_effective IS NULL
   ORDER BY d.created_at DESC
   LIMIT 1;
$function$;

-- detention_cible_pnj(text,text) -> TABLE(systeme text, pays text, ville text, building_id text, room_id text, agent_id text, statut text, niveau_connu integer, arretable boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_cible_pnj(p_nom text, p_pays_autorite text)
 RETURNS TABLE(systeme text, pays text, ville text, building_id text, room_id text, agent_id text, statut text, niveau_connu integer, arretable boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'agent_renseignement'::text,
         pe.pays, pe.ville, pe.building_id, pe.room_id,
         ag.id, ag.statut,
         public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture),
         (    ag.statut = 'actif'
          AND ag.leader_courant IS NULL
          AND pe.ville IS NOT NULL
          AND pe.pays = p_pays_autorite
          AND public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture) >= 2)
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.nom_couverture = p_nom
     AND pe.pays IS NOT DISTINCT FROM p_pays_autorite
     AND c.statut = 'active'
   LIMIT 1;
$function$;

-- detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_ouvrir_interne(p_nom text, p_raison text, p_jours integer, p_city text, p_country text, p_motifs jsonb, p_autorite text, p_issue text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id         text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
                       substr(md5(random()::text), 1, 6);
  v_jour_cible integer;
  v_deja       jsonb;
  v_pnj        record;
  v_cellule    text;
BEGIN
  SELECT coalesce(d.day, 1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;

  IF NOT FOUND THEN
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_nom, p_country);
    IF v_pnj.systeme IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    IF v_pnj.statut = 'detenu' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
    END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_arretable',
                                'niveau_connu', v_pnj.niveau_connu, 'niveau_requis', 2);
    END IF;

    v_jour_cible := public.jour_de_jeu_pays(p_country);
    INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                   motifs, autorite, issue_judiciaire, ville_condamnation, provenance)
    VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
            p_motifs, p_autorite, p_issue, p_city, v_pnj.systeme);

    UPDATE public.agents_renseignement
       SET statut = 'detenu', detention_id = v_id, detenu_depuis = now(),
           leader_courant = NULL, maj_le = now()
     WHERE id = v_pnj.agent_id
    RETURNING cellule_id INTO v_cellule;

    PERFORM public.cellule_alerter_ministre(v_cellule, p_nom,
      'Agent arrete — ' || p_nom,
      'Votre agent operant sous l''identite de couverture « ' || p_nom ||
      ' » a ete arrete par les autorites de ' || p_country || ' a ' || p_city ||
      '. Il ne peut plus collecter ni etre deplace.');

    RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                              'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours,
                              'provenance', v_pnj.systeme);
  END IF;

  -- ---- Branche PJ : strictement le code historique. ----
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja) = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                 motifs, autorite, issue_judiciaire, ville_condamnation)
  VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
          p_motifs, p_autorite, p_issue, p_city);

  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object(
           'jours', p_jours, 'jourFin', v_jour_cible + p_jours, 'raison', p_raison,
           'detentionId', v_id, 'qhs', false, 'city', p_city, 'country', p_country,
           'debutTs', (extract(epoch from clock_timestamp())*1000)::bigint)
   WHERE name = p_nom;

  RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                            'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours);
END;
$function$;

-- detentions_pnj_liberer_echues() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detentions_pnj_liberer_echues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT d.id, d.country, a.id AS agent_id
      FROM public.detentions d
      JOIN public.agents_renseignement a ON a.detention_id = d.id
     WHERE d.provenance = 'agent_renseignement'
       AND d.mode_fin IS NULL
       AND d.jour_fin_effective IS NULL
       AND a.statut = 'detenu'
       AND a.detenu_depuis IS NOT NULL
       AND now() >= a.detenu_depuis + ((d.jour_fin - d.jour_debut) * interval '1 day')
  LOOP
    UPDATE public.detentions
       SET mode_fin = 'purgee', jour_fin_effective = public.jour_de_jeu_pays(r.country),
           date_fin_effective = now()
     WHERE id = r.id;
    UPDATE public.agents_renseignement
       SET statut = 'actif', detention_id = NULL, detenu_depuis = NULL, maj_le = now()
     WHERE id = r.agent_id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'liberations', v_n);
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
  UPDATE public.personnages_donnees
     SET arg = greatest(0, coalesce(arg, 0) - v_amende)
   WHERE name = v_f.auteur;

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

-- justice_condamner(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_condamner(p_cible text, p_entree jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_juge text; v_id text; v_pays text; v_ville text; v_jours integer;
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

-- justice_prolonger_peine(text,jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.justice_prolonger_peine(p_cible text, p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_juge text; v_peine jsonb; v_det record;
  v_jours_supp int; v_nouveau_jour_fin int; v_motifs_actuels jsonb;
BEGIN
  v_juge := public.exiger_poste('juge');

  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' OR jsonb_array_length(p_motifs) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motifs_absents');
  END IF;

  SELECT * INTO v_det FROM public.detention_active(p_cible);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  SELECT coalesce(sum((m->>'jours')::int), 0) INTO v_jours_supp
    FROM jsonb_array_elements(p_motifs) m;
  v_nouveau_jour_fin := coalesce(v_det.jour_fin, 0) + v_jours_supp;

  SELECT coalesce(motifs, '[]'::jsonb) INTO v_motifs_actuels
    FROM public.detentions WHERE id = v_det.id FOR UPDATE;

  UPDATE public.detentions
     SET motifs = v_motifs_actuels || p_motifs,
         jour_fin = v_nouveau_jour_fin,
         qhs = CASE WHEN p_forcer_qhs THEN true ELSE qhs END
   WHERE id = v_det.id;

  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  IF v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object' THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine
             || jsonb_build_object('jours', coalesce((v_peine->>'jours')::int, 0) + v_jours_supp)
             || jsonb_build_object('jourFin', v_nouveau_jour_fin)
             || CASE WHEN p_forcer_qhs THEN jsonb_build_object('qhs', true) ELSE '{}'::jsonb END,
           -- Drapeau QHS de la fiche : pose ici, plus par le navigateur du juge.
           detention_qhs = CASE WHEN p_forcer_qhs
                                THEN jsonb_build_object('enQHS', true, 'paLimite1Jour', false)
                                ELSE detention_qhs END
     WHERE name = p_cible;
  END IF;

  IF p_forcer_qhs AND NOT EXISTS (
       SELECT 1 FROM public.prisonniers_qhs
        WHERE data->>'nom' = p_cible AND coalesce(statut, '') <> 'transfere') THEN
    INSERT INTO public.prisonniers_qhs (id, statut, data)
    VALUES ('qhs-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
              || substr(md5(random()::text), 1, 6),
            'detenu',
            jsonb_build_object('pays', v_det.country, 'nom', p_cible,
                               'raison', coalesce(p_motifs->0->>'type', 'Sentence'),
                               'jourDebut', v_det.jour_debut, 'jourFin', v_nouveau_jour_fin));
  END IF;

  RETURN jsonb_build_object('ok', true, 'juge', v_juge, 'cible', p_cible,
                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau_jour_fin);
END;
$function$;

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

  RETURN QUERY
    SELECT j.id, j.country, j.city, j.motif,
           coalesce((SELECT sum((m->>'jours')::int)
                       FROM jsonb_array_elements(coalesce(j.data->'motifs', '[]'::jsonb)) m), 0)::int,
           j.data
      FROM public.jugements j
     WHERE j.accuse = p_nom AND j.executee = false
     ORDER BY j.created_at;
END;
$function$;

-- plainte_deposer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_commissaire text; v_est_pj boolean := false;
  v_id text; v_res jsonb; v_statut text; v_data jsonb; v_cible text;
BEGIN
  SELECT d.name, d.country, coalesce(d.current_city, 'capitale'), coalesce(d.day, 1)
    INTO v_nom, v_pays, v_ville, v_jour
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;
  v_cible := coalesce(nullif(btrim(p_cible), ''), 'X');

  -- ANTI-SPAM (l'audit n'en avait trouve aucun) : une seule plainte en cours par plaignant et
  -- par cible. Le dossier doit etre instruit avant qu'un second soit ouvert sur le meme sujet.
  IF EXISTS (SELECT 1 FROM public.plaintes_en_cours p
              WHERE p.country = v_pays
                AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
                AND (p.data::jsonb) ->> 'auteur' = v_nom
                AND (p.data::jsonb) ->> 'cible'  = v_cible
                AND (p.data::jsonb) ->> 'status' = 'deposee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plainte_deja_en_cours');
  END IF;

  SELECT d.name INTO v_commissaire
    FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.poste ->> 'id' = 'commissaire' AND d.poste ->> 'city' = v_ville
   LIMIT 1;
  IF v_commissaire IS NOT NULL THEN
    v_est_pj := true;
  ELSE
    SELECT t.nom_pnj INTO v_commissaire FROM public.titulaires_pnj t
     WHERE t.country = v_pays AND t.poste_id = 'commissaire' AND t.city = v_ville LIMIT 1;
  END IF;

  v_id := 'plainte-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);

  IF v_est_pj THEN
    v_statut := 'deposee';
    v_res := jsonb_build_object('ok', true, 'decision', 'transmise_commissaire');
  ELSE
    v_res := public.plainte_instruire_interne(v_pays, v_ville, v_cible, p_motif,
                                              coalesce(v_commissaire, 'Commissariat'));
    v_statut := v_res ->> 'decision';
  END IF;

  v_data := jsonb_build_object(
    'id', v_id, 'auteur', v_nom, 'cible', v_cible, 'motif', p_motif,
    'jour', v_jour, 'city', v_ville, 'country', v_pays, 'status', v_statut,
    'commissaire', v_commissaire, 'commissaire_pj', v_est_pj,
    'decide_le', CASE WHEN v_est_pj THEN NULL
                      ELSE to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END,
    'motif_decision', v_res ->> 'motif_decision');

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text);

  RETURN v_res || jsonb_build_object('id', v_id, 'commissaire', v_commissaire,
                                     'commissaire_pj', v_est_pj, 'ville', v_ville);
END;
$function$;

-- plainte_instruire_interne(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_instruire_interne(p_pays text, p_ville text, p_cible text, p_motif text, p_instructeur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acte   public.actions_tracables%ROWTYPE;
  v_jour   integer;
  v_det    jsonb;
  v_motifs jsonb;
  v_ce     jsonb;
BEGIN
  SELECT * INTO v_acte FROM public.actions_tracables a
   WHERE a.country = p_pays AND a.city = p_ville AND a.auteur = p_cible
     AND a.decouvert IS NOT TRUE
   ORDER BY a.jour DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'classee',
                              'motif_decision', 'aucun_element_a_charge');
  END IF;

  UPDATE public.actions_tracables SET decouvert = true WHERE id = v_acte.id;

  -- BRANCHE CONTRE-ESPIONNAGE. L'auteur de la trace est-il la couverture d'un
  -- agent reel ? Si oui, l'instruction produit un DEMASQUAGE, pas une garde a
  -- vue : detention_ouvrir_interne refuserait de toute facon (pas de fiche).
  v_ce := public.contre_espionnage_resoudre(p_pays, p_cible, p_instructeur,
            'actions_tracables:' || v_acte.id);
  IF coalesce((v_ce ->> 'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'contre_espionnage',
      'acte', coalesce(v_acte.type_action, 'acte illegal'),
      'couverture', p_cible, 'enquete', v_ce);
  END IF;

  -- ---- A partir d'ici, comportement historique STRICTEMENT inchange ----
  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = p_cible;
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'),
    'cible', v_acte.cible,
    'jour_fait', v_acte.jour,
    'city', p_ville,
    'ref_type', 'action_tracee',
    'ref_id', v_acte.id,
    'jours', 2,
    'source', 'garde_a_vue',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_det := public.detention_ouvrir_interne(
    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), 2,
    p_ville, p_pays, v_motifs, p_instructeur, 'garde_a_vue_enquete');

  RETURN jsonb_build_object('ok', true, 'decision', 'enquete_ouverte',
                            'acte', coalesce(v_acte.type_action, 'acte illegal'),
                            'detention', v_det);
END;
$function$;

-- plainte_traiter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_traiter(p_id text, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_brut text; v_data jsonb; v_ville text; v_pays_plainte text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_decision NOT IN ('classer', 'enqueter') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays_plainte
    FROM public.plaintes_en_cours p WHERE p.id = p_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable');
  END IF;
  v_data := v_brut::jsonb;

  IF v_pays_plainte IS DISTINCT FROM v_pays OR v_ville IS DISTINCT FROM v_poste_city THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF v_data ->> 'status' IS DISTINCT FROM 'deposee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_deja_instruit');
  END IF;

  IF p_decision = 'classer' THEN
    v_res := jsonb_build_object('ok', true, 'decision', 'classee',
                                'motif_decision', 'classement_du_commissaire');
  ELSE
    v_res := public.plainte_instruire_interne(v_pays, v_ville, v_data ->> 'cible',
                                              v_data ->> 'motif', v_nom);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_data || jsonb_build_object(
           'status', v_res ->> 'decision',
           'instruit_par', v_nom,
           'motif_decision', v_res ->> 'motif_decision',
           'decide_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_id;

  RETURN v_res || jsonb_build_object('id', p_id);
END;
$function$;

-- plaintes_epingler_verdict() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plaintes_epingler_verdict()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_old jsonb; v_new jsonb; v_cle text;
  -- Champs qui disent l'issue judiciaire. Tout le reste (defense, pieces,
  -- circonstances) reste librement modifiable par les parties.
  v_verdict constant text[] := ARRAY['status','sentence','peine','jugement','juge',
                                     'circonstanceAttenuante','aggravation'];
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF public.affaire_autorite_de(NEW.city) THEN RETURN NEW; END IF;

  -- L'auteur n'est pas l'autorite judiciaire : on restaure les champs de verdict
  -- tels qu'ils etaient. Si l'un d'eux est illisible, on ne prend aucun risque.
  IF OLD.data IS NULL OR left(btrim(OLD.data), 1) <> '{'
     OR NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_old := OLD.data::jsonb;
    v_new := NEW.data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  FOREACH v_cle IN ARRAY v_verdict LOOP
    IF (v_new -> v_cle) IS DISTINCT FROM (v_old -> v_cle) THEN
      IF (v_old ? v_cle) THEN
        v_new := jsonb_set(v_new, ARRAY[v_cle], v_old -> v_cle);
      ELSE
        v_new := v_new - v_cle;   -- le champ n'existait pas : il n'apparait pas
      END IF;
    END IF;
  END LOOP;

  NEW.data := v_new::text;
  RETURN NEW;
END;
$function$;

-- police_autorite_de_perimetre(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ville text; v_bat text; v_nom text;
BEGIN
  IF p_perimetre IS NULL OR position(':' in p_perimetre) = 0 THEN RETURN NULL; END IF;
  v_ville := split_part(p_perimetre, ':', 1);
  v_bat   := split_part(p_perimetre, ':', 2);
  IF v_bat NOT IN ('commissariat','commissariat-local') THEN RETURN NULL; END IF;
  SELECT pd.name INTO v_nom
    FROM public.personnages_donnees pd
   WHERE COALESCE(pd.country, 'republic') = p_pays
     AND pd.poste->>'id' = 'commissaire'
     AND pd.poste->>'city' = v_ville
   ORDER BY pd.name
   LIMIT 1;
  RETURN v_nom;
END; $function$;

-- police_caracteristiques_metier() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_caracteristiques_metier()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.pnj_metier_profil('policier');
$function$;

-- police_payer_effectifs(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_payer_effectifs(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_standard  constant integer := 50;
  c_cynophile constant integer := 100;
  v_serveur boolean; v_moi text; v_poste text;
  v_jour date; r record; v_etat jsonb; v_eff jsonb; v_liste jsonb;
  v_du numeric; v_verse numeric; v_rep jsonb; v_n integer; v_gardes integer;
  v_cumul numeric; v_el jsonb; v_caisse text;
  v_villes jsonb := '[]'::jsonb; v_total_verse numeric := 0; v_total_partis integer := 0;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_serveur := public.est_appel_serveur();
  IF NOT v_serveur THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
    SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;
    IF v_poste IS DISTINCT FROM 'min_int' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                    WHERE name = v_moi AND COALESCE(country,'republic') = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite'); END IF;
  END IF;

  v_jour := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);

  FOR r IN SELECT b.id, b.city, b.building_id, b.data
             FROM public.batiments_etat b
            WHERE b.country = p_pays
              AND b.building_id IN ('commissariat','commissariat-local')
            ORDER BY b.city
            FOR UPDATE
  LOOP
    v_etat := COALESCE(public.batiment_etat_lire(r.data), '{}'::jsonb);
    v_eff  := v_etat -> 'effectifsPolice';
    CONTINUE WHEN v_eff IS NULL OR jsonb_typeof(v_eff) <> 'object';
    CONTINUE WHEN COALESCE(v_eff ->> 'dernierPaiementJour', '') = v_jour::text;

    v_liste := COALESCE(v_eff -> 'policiers', '[]'::jsonb);
    IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
    v_n := jsonb_array_length(v_liste);

    IF v_n = 0 THEN
      v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','dernierPaiementJour'],
                          to_jsonb(v_jour::text), true);
      UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
       WHERE id = r.id;
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.city, 'effectif_avant', 0, 'verse', 0, 'partis', 0));
      CONTINUE;
    END IF;

    v_du := 0;
    FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
      v_du := v_du + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                          THEN c_cynophile ELSE c_standard END;
    END LOOP;

    -- La caisse est celle du commissariat DE CETTE VILLE. L'autorite propre a l'operation vient
    -- d'etre verifiee : on ouvre la porte interne pour cette transaction seulement.
    v_caisse := p_pays || '_commissariat_' || r.city;
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement_plafonne(v_caisse, v_du);
    PERFORM set_config('rp.caisse_interne', '', true);
    IF NOT COALESCE((v_rep->>'ok')::boolean, false) THEN
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.city, 'refus', COALESCE(v_rep->>'raison','debit_refuse')));
      CONTINUE;
    END IF;
    v_verse := COALESCE((v_rep->>'verse')::numeric, 0);

    v_cumul := 0; v_gardes := 0;
    FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
      v_cumul := v_cumul + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                                THEN c_cynophile ELSE c_standard END;
      EXIT WHEN v_cumul > v_verse;
      v_gardes := v_gardes + 1;
    END LOOP;

    IF v_gardes < v_n THEN
      SELECT COALESCE(jsonb_agg(e ORDER BY o), '[]'::jsonb) INTO v_liste
        FROM jsonb_array_elements(v_liste) WITH ORDINALITY AS t(e, o)
       WHERE o <= v_gardes;
      v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','policiers'], v_liste, true);
    END IF;
    v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','dernierPaiementJour'],
                        to_jsonb(v_jour::text), true);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
     WHERE id = r.id;

    v_total_verse  := v_total_verse + v_verse;
    v_total_partis := v_total_partis + (v_n - v_gardes);
    v_villes := v_villes || jsonb_build_array(jsonb_build_object(
      'ville', r.city, 'caisse', v_caisse, 'du', v_du, 'verse', v_verse,
      'effectif_avant', v_n, 'effectif_apres', v_gardes, 'partis', v_n - v_gardes));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'pays', p_pays,
    'verse_total', v_total_verse, 'partis_total', v_total_partis, 'villes', v_villes);
END; $function$;

-- police_pnj_id(text,text,text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.police_pnj_id(p_pays text, p_ville text, p_matricule text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'police-' || p_pays || '-' || p_ville || '-' || p_matricule;
$function$;

-- presidence_gracier(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_gracier(p_condamne text, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_president text; v_peine jsonb; v_detention_id text;
BEGIN
  v_president := public.exiger_poste('president');

  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
  WHERE name = p_condamne FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'libere', false, 'raison', 'non_detenu');
  END IF;

  v_detention_id := v_peine->>'detentionId';
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = p_condamne;

  IF v_detention_id IS NOT NULL THEN
    UPDATE public.detentions
    SET mode_fin = 'grace_presidentielle',
        jour_fin_effective = p_jour,
        date_fin_effective = now()
    WHERE id = v_detention_id AND mode_fin IS NULL;
  END IF;

  RETURN jsonb_build_object('ok', true, 'libere', true,
                            'president', v_president, 'condamne', p_condamne);
END;
$function$;

-- qhs_pouvoir(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.qhs_pouvoir(p_prisonnier_id text, p_acte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_pays text; v_data jsonb; v_nom text; v_det record;
  v_caisse text; v_solde numeric; v_cout integer := 500; v_res jsonb; v_moral integer;
BEGIN
  -- 1. AUTORITE : le poste est relu sur la ligne de l'appelant, jamais annonce par lui.
  v_acteur := public.exiger_poste('min_just');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_acte NOT IN ('transferer', 'ameliorer', 'torturer') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  -- 2. LE PRISONNIER DU REGISTRE QHS.
  SELECT data INTO v_data FROM public.prisonniers_qhs
   WHERE id = p_prisonnier_id AND coalesce(statut, '') <> 'transfere' FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prisonnier_introuvable');
  END IF;
  v_nom := v_data->>'nom';

  -- 3. LA DETENTION CANONIQUE. Sans elle, aucun pouvoir QHS ne s'exerce.
  SELECT * INTO v_det FROM public.detention_active(v_nom);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  -- 4. L'ACTE.
  IF p_acte = 'transferer' THEN
    UPDATE public.detentions SET qhs = false WHERE id = v_det.id;
    UPDATE public.prisonniers_qhs SET statut = 'transfere' WHERE id = p_prisonnier_id;
    UPDATE public.personnages_donnees
       SET detention_qhs = jsonb_build_object('enQHS', false, 'eligibleBonusAvocat', true)
     WHERE name = v_nom;
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom);
  END IF;

  IF p_acte = 'ameliorer' THEN
    -- Debit et effet dans la MEME transaction : plus jamais 500 FR sortis pour rien.
    v_caisse := v_pays || '_qhs-prison';
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    IF v_solde IS NULL OR v_solde < v_cout THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'cout', v_cout);
    END IF;
    UPDATE public.caisses_batiments
       SET data = data || jsonb_build_object('solde', v_solde - v_cout), updated_at = now()
     WHERE id = v_caisse;

    SELECT coalesce(moral, 50) INTO v_moral FROM public.personnages_donnees WHERE name = v_nom;
    UPDATE public.personnages_donnees
       SET moral = least(100, v_moral + 15),
           detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false,
                                              'conditionsAmeliorees', true)
     WHERE name = v_nom;
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom, 'cout', v_cout);
  END IF;

  -- torture : indices et moral a zero, PA plafonnes a 1 le lendemain.
  -- inf/pop/dis sont des CLES DE `resources`, pas des colonnes -- l'ancien code l'ignorait.
  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_res FROM public.personnages_donnees WHERE name = v_nom;
  UPDATE public.personnages_donnees
     SET resources = v_res || jsonb_build_object('inf', 0, 'pop', 0, 'dis', 0),
         moral = 0,
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', true)
   WHERE name = v_nom;
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom);
END; $function$;
