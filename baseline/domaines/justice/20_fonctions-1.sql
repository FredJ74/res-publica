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

-- affaire_delai_expire(jsonb,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_delai_expire(p_data jsonb, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (p_data ->> 'delai_jugement_jour') IS NOT NULL
     AND coalesce(public.jour_de_jeu_pays(coalesce(p_pays, p_data ->> 'country')), 1)
         > (p_data ->> 'delai_jugement_jour')::integer;
$function$;

-- affaire_infraction_de(jsonb) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_infraction_de(p_data jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT nullif(btrim(coalesce(
    p_data ->> 'qualification_finale',
    p_data ->> 'qualification_parquet',
    p_data ->> 'infraction_constatee', '')), '');
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

-- affaire_transmettre(text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_transmettre(p_cible text, p_motif text, p_city text, p_fait jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_jour integer; v_ville text;
  v_cible text; v_motif text; v_id text; v_data jsonb; v_n integer; v_infr text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := nullif(btrim(coalesce(p_cible, '')), '');
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF v_motif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent'); END IF;
  v_ville := coalesce(nullif(btrim(coalesce(p_city, '')), ''), 'capitale');

  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee', 'ville', v_ville);
  END IF;

  -- L'INFRACTION CONSTATEE, QUAND LA POLICE LA CONNAIT. Elle passe par `infraction_canonique`,
  -- qui refuse un identifiant inconnu ET un nom de categorie : un motif libre ne devient jamais
  -- une qualification par accident. Une infraction non reconnue n'est pas une erreur -- la
  -- police transmet souvent sur un motif qu'aucun catalogue ne nomme -- elle est simplement
  -- ignoree, et le dossier part sans infraction constatee, comme avant cette migration.
  v_infr := NULL;
  IF p_fait IS NOT NULL AND jsonb_typeof(p_fait) = 'object'
     AND nullif(btrim(coalesce(p_fait ->> 'infraction', '')), '') IS NOT NULL THEN
    v_infr := public.infraction_canonique(p_fait ->> 'infraction');
  END IF;

  SELECT d.country, coalesce(d.day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees d WHERE d.name = v_nom LIMIT 1;
  v_pays := coalesce(v_pays, 'republic');

  v_id := 'affaire-' || v_pays || '-' || v_ville || '-' || v_jour || '-'
          || substr(md5(v_cible || '|' || v_motif || '|' || coalesce(p_fait ->> 'refId', '')), 1, 12);

  v_data := jsonb_build_object('id', v_id, 'country', v_pays, 'city', v_ville,
                               'cible', v_cible, 'motif', v_motif, 'jour', v_jour,
                               'status', 'au_parquet', 'origine', 'police',
                               'transmise_par', v_nom,
                               'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  IF v_infr IS NOT NULL THEN
    v_data := v_data || jsonb_build_object('infraction_constatee', v_infr);
  END IF;
  IF p_fait IS NOT NULL AND jsonb_typeof(p_fait) = 'object' THEN
    IF nullif(p_fait ->> 'victime', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('victime', p_fait ->> 'victime'); END IF;
    IF p_fait ? 'jourFait' AND p_fait ->> 'jourFait' IS NOT NULL THEN v_data := v_data || jsonb_build_object('jourFait', (p_fait ->> 'jourFait')::integer); END IF;
    IF nullif(p_fait ->> 'refType', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('refType', p_fait ->> 'refType'); END IF;
    IF nullif(p_fait ->> 'refId', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('refId', p_fait ->> 'refId'); END IF;
  END IF;

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    SELECT CASE WHEN data IS NULL THEN NULL ELSE data::jsonb END INTO v_data
      FROM public.plaintes_en_cours WHERE id = v_id;
    RETURN jsonb_build_object('ok', true, 'deja_transmise', true, 'affaire', v_data, 'id', v_id);
  END IF;

  PERFORM public.dossier_acte_consigner(v_id, v_pays, v_ville, 'affaire_transmise_police',
    v_nom, 'commissaire', NULL, v_infr,
    jsonb_build_object('cible', v_cible, 'ref_type', p_fait ->> 'refType',
                       'ref_id', p_fait ->> 'refId', 'infraction_constatee', v_infr));
  RETURN jsonb_build_object('ok', true, 'deja_transmise', false, 'affaire', v_data, 'id', v_id);
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

-- detention_clore_evasion() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_evasion()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb;
        v_fin integer; v_reliquat integer; v_motifs jsonb; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne, country INTO v_jour, v_peine, v_pays
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- EVASION REUSSIE N'EST PAS UNE LIBERATION : la peine n'est pas purgee, et `jour_fin` n'est
  -- JAMAIS reecrit. Le reliquat et les motifs d'origine sont rendus, pour l'avis de recherche.
  v_fin := coalesce((v_peine->>'jourFin')::integer, v_jour);
  v_reliquat := greatest(0, v_fin - v_jour);
  IF v_det.id IS NOT NULL THEN
    SELECT coalesce(motifs,'[]'::jsonb), coalesce(country, v_pays) INTO v_motifs, v_pays
      FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  ELSE
    v_motifs := '[]'::jsonb;
  END IF;
  RETURN public.detention_clore_interne(v_moi, 'evasion')
         || jsonb_build_object('ok',true,'reliquat_jours',v_reliquat,'motifs',v_motifs,'country',v_pays);
END; $function$;

-- detention_clore_interne(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_interne(p_nom text, p_mode text, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour integer; v_peine jsonb; v_det record; v_qhs boolean;
BEGIN
  IF coalesce(btrim(p_mode),'') = '' THEN
    RAISE EXCEPTION 'detention_clore_interne : le mode de fin est obligatoire';
  END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  -- Le caractere QHS se lit des DEUX cotes : la fiche peut le porter sans la ligne, et l'inverse.
  v_qhs := coalesce((v_peine->>'qhs')::boolean,false) OR coalesce(v_det.qhs,false);
  -- 1. La ligne. `AND mode_fin IS NULL` : une ligne deja close n'est pas reecrite.
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin = p_mode, jour_fin_effective = coalesce(p_jour, v_jour),
           date_fin_effective = now()
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  -- 2. et 3. La fiche, et le drapeau en OBJET -- la forme que pa_repos_nocturne sait lire.
  UPDATE public.personnages_donnees
     SET est_emprisonne = NULL,
         detention_qhs = CASE WHEN v_qhs
           THEN jsonb_build_object('enQHS', false, 'paLimite1Jour', false) ELSE detention_qhs END
   WHERE name = p_nom;
  -- 4. Le registre du QHS, sans quoi le Ministere voit un detenu libre.
  IF v_qhs THEN
    UPDATE public.prisonniers_qhs SET statut='libere'
     WHERE data ->> 'nom' = p_nom AND coalesce(statut,'') = 'detenu';
  END IF;
  RETURN jsonb_build_object('detention_id', v_det.id, 'sortait_du_qhs', v_qhs,
                            'jour', coalesce(p_jour, v_jour),
                            'retour_ville', v_peine ->> 'retourVille');
END; $function$;

-- detention_clore_motif_eteint(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_motif_eteint(p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_peine jsonb; v_r jsonb;
BEGIN
  -- LISTE FERMEE : la porte ne sert que ces deux actes administratifs.
  IF p_mode NOT IN ('poursuites_eteintes','incorporation') THEN
    RAISE EXCEPTION 'detention_clore_motif_eteint : mode inconnu « % »', p_mode;
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  IF coalesce((v_peine->>'motifDesertionSeul')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_pas_seulement_desertion'); END IF;
  v_r := public.detention_clore_interne(v_moi, p_mode);
  RETURN v_r || jsonb_build_object('ok', true, 'mode', p_mode);
END; $function$;

-- detention_clore_purgee() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_clore_purgee()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb; v_fin integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- LE JOUR DE REFERENCE EST CELUI DE LA FICHE, jamais un parametre : sinon la liberation serait
  -- a la main du navigateur. C'est exactement la condition du client (state.day >= jourFin).
  v_fin := coalesce((v_peine ->> 'jourFin')::integer, v_det.jour_fin);
  IF v_fin IS NULL OR v_jour < v_fin THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_non_purgee','jour',v_jour,'jour_fin',v_fin);
  END IF;
  RETURN public.detention_clore_interne(v_moi, 'purgee') || jsonb_build_object('ok', true);
END; $function$;

-- detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_ouvrir_interne(p_nom text, p_raison text, p_jours integer, p_city text, p_country text, p_motifs jsonb, p_autorite text, p_issue text, p_extras jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6);
  v_jour_cible integer; v_deja jsonb; v_pnj record; v_cellule text;
  v_x jsonb := CASE WHEN jsonb_typeof(p_extras)='object' THEN p_extras ELSE '{}'::jsonb END;
  v_ville_cond text; v_jour_aff integer; v_prec text; v_reliquat integer; v_retour text;
BEGIN
  -- Chacune de ces cinq valeurs vaut NULL quand p_extras l'ignore : un appel a huit arguments
  -- produit donc exactement la ligne qu'il produisait avant ce lot.
  v_ville_cond := coalesce(nullif(v_x->>'ville_condamnation',''), p_city);
  v_jour_aff   := nullif(v_x->>'jour_affaire','')::integer;
  v_prec       := nullif(v_x->>'detention_precedente_id','');
  v_reliquat   := nullif(v_x->>'reliquat_jours','')::integer;
  v_retour     := nullif(v_x->>'retour_ville','');
  SELECT coalesce(d.day,1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_nom, p_country);
    IF v_pnj.systeme IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','cible_introuvable'); END IF;
    IF v_pnj.statut = 'detenu' THEN RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue'); END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok',false,'raison','cible_non_arretable','niveau_connu',v_pnj.niveau_connu,'niveau_requis',2);
    END IF;
    v_jour_cible := public.jour_de_jeu_pays(p_country);
    INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
             autorite,issue_judiciaire,ville_condamnation,provenance,jour_affaire,detention_precedente_id,reliquat_jours)
    VALUES (v_id,p_country,p_city,p_nom,p_raison,v_jour_cible,v_jour_cible+p_jours,false,p_motifs,
             p_autorite,p_issue,v_ville_cond,v_pnj.systeme,v_jour_aff,v_prec,v_reliquat);
    UPDATE public.agents_renseignement
       SET statut='detenu', detention_id=v_id, detenu_depuis=now(), leader_courant=NULL, maj_le=now()
     WHERE id = v_pnj.agent_id RETURNING cellule_id INTO v_cellule;
    PERFORM public.cellule_alerter_ministre(v_cellule, p_nom, 'Agent arrete — ' || p_nom,
      'Votre agent operant sous l''identite de couverture « ' || p_nom ||
      ' » a ete arrete par les autorites de ' || p_country || ' a ' || p_city ||
      '. Il ne peut plus collecter ni etre deplace.');
    RETURN jsonb_build_object('ok',true,'detention_id',v_id,'jour_debut',v_jour_cible,
                              'jour_fin',v_jour_cible+p_jours,'provenance',v_pnj.systeme);
  END IF;
  -- LA GARDE DE REJEU : une peine en cours interdit d'en ouvrir une seconde. C'est elle qui rend
  -- un double appel inoffensif, et elle existait avant ce lot.
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja)='object' THEN
    RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue');
  END IF;
  INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
           autorite,issue_judiciaire,ville_condamnation,jour_affaire,detention_precedente_id,reliquat_jours)
  VALUES (v_id,p_country,p_city,p_nom,p_raison,v_jour_cible,v_jour_cible+p_jours,false,p_motifs,
           p_autorite,p_issue,v_ville_cond,v_jour_aff,v_prec,v_reliquat);
  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object('jours',p_jours,'jourFin',v_jour_cible+p_jours,
           'raison',p_raison,'detentionId',v_id,'qhs',false,'city',p_city,'country',p_country,
           'debutTs',(extract(epoch from clock_timestamp())*1000)::bigint)
         || CASE WHEN v_retour IS NOT NULL THEN jsonb_build_object('retourVille',v_retour) ELSE '{}'::jsonb END
   WHERE name = p_nom;
  RETURN jsonb_build_object('ok',true,'detention_id',v_id,'jour_debut',v_jour_cible,'jour_fin',v_jour_cible+p_jours);
END; $function$;

-- detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_ouvrir_soi(p_raison text, p_jours integer, p_city text DEFAULT NULL::text, p_motifs jsonb DEFAULT NULL::jsonb, p_qhs boolean DEFAULT false, p_extras jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_jour integer; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_jours IS NULL OR p_jours < 0 OR p_jours > 3650 THEN
    RETURN jsonb_build_object('ok',false,'raison','duree_invalide'); END IF;
  -- Le pays et le JOUR viennent de la fiche, jamais de l'appelant : jour_fin se calcule donc sur
  -- le compteur que le serveur detient, exactement comme pour une arrestation par un tiers.
  SELECT country, coalesce(nullif(btrim(p_city),''), current_city, 'capitale'), coalesce(day,1)
    INTO v_pays, v_ville, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours, v_ville, v_pays,
           CASE WHEN jsonb_typeof(p_motifs)='array' AND jsonb_array_length(p_motifs) > 0 THEN p_motifs
                ELSE jsonb_build_array(jsonb_build_object('type',coalesce(p_raison,'Detention'),
                       'jour_fait',v_jour,'city',v_ville,'jours',p_jours,
                       'source','detention_ouvrir_soi','date_evenement',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))) END,
           nullif(p_extras->>'autorite',''), nullif(p_extras->>'issue_judiciaire',''), p_extras);
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN RETURN v_r; END IF;
  IF p_qhs THEN
    PERFORM public.detention_qhs_poser_interne(v_moi, v_r->>'detention_id', p_raison);
    RETURN v_r || jsonb_build_object('qhs', true);
  END IF;
  RETURN v_r;
END; $function$;

-- detention_prolonger_interne(text,jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_prolonger_interne(p_nom text, p_motifs jsonb, p_forcer_qhs boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_peine jsonb; v_det record; v_jours_supp int; v_nouveau int; v_motifs jsonb;
BEGIN
  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' OR jsonb_array_length(p_motifs) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motifs_absents');
  END IF;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;
  SELECT coalesce(sum((m ->> 'jours')::int), 0) INTO v_jours_supp
    FROM jsonb_array_elements(p_motifs) m;
  v_nouveau := coalesce(v_det.jour_fin, 0) + v_jours_supp;
  -- Les motifs sont relus SOUS VERROU puis concatenes. La branche cliente, elle, les lisait
  -- avec `.catch(() => [])` : un echec de lecture ECRASAIT tous les motifs existants.
  SELECT coalesce(motifs, '[]'::jsonb) INTO v_motifs
    FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  UPDATE public.detentions
     SET motifs = v_motifs || p_motifs, jour_fin = v_nouveau
   WHERE id = v_det.id;
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
   WHERE name = p_nom FOR UPDATE;
  IF v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object' THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine
             || jsonb_build_object('jours', coalesce((v_peine ->> 'jours')::int, 0) + v_jours_supp)
             || jsonb_build_object('jourFin', v_nouveau)
     WHERE name = p_nom;
  END IF;
  IF p_forcer_qhs THEN
    PERFORM public.detention_qhs_poser_interne(p_nom, v_det.id,
              coalesce(p_motifs -> 0 ->> 'type', 'Sentence'));
  END IF;
  RETURN jsonb_build_object('ok', true, 'cible', p_nom, 'detention_id', v_det.id,
                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau);
END; $function$;

-- detention_prolonger_soi(jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_prolonger_soi(p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN public.detention_prolonger_interne(v_moi, p_motifs, p_forcer_qhs);
END; $function$;

-- detention_qhs_poser_interne(text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_qhs_poser_interne(p_nom text, p_detention_id text, p_raison text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_det record; v_peine jsonb; v_photo text;
BEGIN
  SELECT country, city, jour_debut, jour_fin INTO v_det
    FROM public.detentions WHERE id = p_detention_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  UPDATE public.detentions SET qhs = true WHERE id = p_detention_id;
  SELECT est_emprisonne, photo_url INTO v_peine, v_photo
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  UPDATE public.personnages_donnees
     SET est_emprisonne = CASE
           WHEN v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object'
           THEN v_peine || jsonb_build_object('qhs', true) ELSE v_peine END,
         -- OBJET, jamais une chaine : c'est la forme que pa_repos_nocturne sait lire.
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false)
   WHERE name = p_nom;
  IF NOT EXISTS (SELECT 1 FROM public.prisonniers_qhs
                  WHERE data ->> 'nom' = p_nom AND coalesce(statut,'') <> 'transfere') THEN
    INSERT INTO public.prisonniers_qhs (id, statut, data)
    VALUES ('qhs-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
              || substr(md5(random()::text),1,6), 'detenu',
            jsonb_build_object('pays', v_det.country, 'nom', p_nom,
                               'raison', coalesce(nullif(btrim(p_raison),''),'Sentence'),
                               'photoUrl', v_photo,
                               'jourDebut', v_det.jour_debut, 'jourFin', v_det.jour_fin));
  END IF;
END; $function$;

-- detention_reduire_peine(boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_reduire_peine(p_requete_acceptee boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_jour integer; v_peine jsonb; v_det record;
        v_fin integer; v_restants integer; v_reduction integer; v_nouveau integer;
        v_jours integer; v_libere boolean; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  IF coalesce((v_peine->>'avocatUtilise')::boolean,false) THEN
    RETURN jsonb_build_object('ok',false,'raison','avocat_deja_utilise'); END IF;
  -- L'AVOCAT EST CONSOMME MEME QUAND LE JUGE REFUSE. Regle d'origine, rendue fiable.
  IF NOT coalesce(p_requete_acceptee, false) THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine || jsonb_build_object('avocatUtilise', true)
     WHERE name = v_moi;
    RETURN jsonb_build_object('ok',true,'acceptee',false,'reduction',0,'libere',false);
  END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_fin := coalesce((v_peine->>'jourFin')::integer, v_det.jour_fin);
  IF v_fin IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','peine_sans_terme'); END IF;
  -- Transcription exacte du calcul du navigateur, aux memes bornes.
  v_restants  := greatest(1, v_fin - v_jour);
  v_reduction := greatest(1, ceil(v_restants / 2.0)::integer);
  v_nouveau   := greatest(v_jour, v_fin - v_reduction);
  v_jours     := greatest(0, v_restants - v_reduction);
  v_libere    := v_jours <= 0 OR v_jour >= v_nouveau;
  -- La reduction ne reecrit JAMAIS motifs[].jours : elle vit a part, dans reduction_jours.
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions SET reduction_jours = v_reduction, jour_fin = v_nouveau
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  IF v_libere THEN
    v_r := public.detention_clore_interne(v_moi, 'anticipee_avocat');
  ELSE
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine || jsonb_build_object('jourFin', v_nouveau, 'jours', v_jours,
                                                          'avocatUtilise', true)
     WHERE name = v_moi;
    v_r := jsonb_build_object('detention_id', v_det.id);
  END IF;
  RETURN v_r || jsonb_build_object('ok',true,'acceptee',true,'reduction',v_reduction,
                                   'jour_fin',v_nouveau,'jours',v_jours,'libere',v_libere);
END; $function$;

-- detention_transferer_qhs(text,integer,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.detention_transferer_qhs(p_raison text, p_jours integer, p_city text DEFAULT NULL::text, p_motifs jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb; v_r jsonb; v_prec text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_jours IS NULL OR p_jours <= 0 OR p_jours > 3650 THEN
    RETURN jsonb_build_object('ok',false,'raison','duree_invalide'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_prec := v_det.id;
  -- 1. L'ANCIENNE LIGNE EST CLOSE EXPLICITEMENT. La laisser a NULL la ferait apparaitre comme
  --    encore en cours dans le registre, ce qui est faux : elle est terminee, juste pas par une
  --    liberation. Commentaire d'origine du client, conserve parce qu'il dit le vrai.
  IF v_prec IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin='transfert_qhs', jour_fin_effective=v_jour, date_fin_effective=now()
     WHERE id = v_prec;
  END IF;
  -- 2. est_emprisonne est vide AVANT la reouverture : la primitive refuse une cible deja detenue.
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = v_moi;
  -- 3. La nouvelle peine passe par la primitive canonique, qui la chaine a la precedente.
  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours,
           coalesce(nullif(btrim(p_city),''), v_det.city, 'qhs'),
           coalesce(v_det.country, (SELECT country FROM public.personnages_donnees WHERE name=v_moi)),
           CASE WHEN jsonb_typeof(p_motifs)='array' AND jsonb_array_length(p_motifs) > 0 THEN p_motifs
                ELSE jsonb_build_array(jsonb_build_object('type',coalesce(p_raison,'Transfert QHS'),
                       'jour_fait',v_jour,'jours',p_jours,'source','detention_transferer_qhs')) END,
           NULL, NULL,
           jsonb_build_object('detention_precedente_id', v_prec,
                              'retour_ville', v_peine ->> 'retourVille'));
  -- 4. SI LA REOUVERTURE ECHOUE, RIEN NE RESTE : on LEVE, et la transaction de la RPC emporte la
  --    cloture de l'etape 1. Rendre un verdict ici laisserait un detenu sans peine en cours.
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN
    RAISE EXCEPTION 'detention_transferer_qhs : reouverture impossible (%)', v_r ->> 'raison';
  END IF;
  PERFORM public.detention_qhs_poser_interne(v_moi, v_r ->> 'detention_id', p_raison);
  RETURN v_r || jsonb_build_object('qhs', true, 'detention_precedente', v_prec);
END; $function$;

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

-- dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossier_acte_consigner(p_affaire text, p_pays text, p_ville text, p_type text, p_acteur text DEFAULT NULL::text, p_acteur_poste text DEFAULT NULL::text, p_qualif_avant text DEFAULT NULL::text, p_qualif_apres text DEFAULT NULL::text, p_donnees jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_rang integer; v_id text;
BEGIN
  -- ELLE LEVE, ELLE NE REFUSE PAS. Tous ses appelants sont internes et l'invoquent par PERFORM,
  -- qui jette la valeur rendue : un refus propre serait un trou silencieux dans la chronologie.
  -- En levant, elle annule la transaction entiere -- l'acte judiciaire ET sa trace, ou ni l'un ni
  -- l'autre.
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types t WHERE t.type = p_type) THEN
    RAISE EXCEPTION 'chronologie judiciaire : type d''acte inconnu (%)', p_type;
  END IF;
  IF coalesce(btrim(coalesce(p_affaire, '')), '') = '' THEN
    RAISE EXCEPTION 'chronologie judiciaire : acte sans affaire';
  END IF;
  IF coalesce(btrim(coalesce(p_pays, '')), '') = '' THEN
    RAISE EXCEPTION 'chronologie judiciaire : acte sans pays (affaire %)', p_affaire;
  END IF;

  -- LE RANG EST CALCULE PAR LE SERVEUR. La contrainte UNIQUE (affaire, rang) fait le reste :
  -- deux actes simultanes sur la meme affaire ne peuvent pas partager un rang.
  SELECT coalesce(max(a.rang), 0) + 1 INTO v_rang
    FROM public.dossiers_judiciaires_actes a WHERE a.affaire = p_affaire;
  v_id := 'acte-' || p_affaire || '-' || v_rang;
  INSERT INTO public.dossiers_judiciaires_actes
    (id, affaire, pays, ville, rang, type, acteur, acteur_poste,
     qualif_avant, qualif_apres, donnees)
  VALUES (v_id, p_affaire, p_pays, p_ville, v_rang, p_type, p_acteur, p_acteur_poste,
          p_qualif_avant, p_qualif_apres, p_donnees);
  RETURN jsonb_build_object('ok', true, 'acte', v_id, 'rang', v_rang);
END;
$function$;

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
  SELECT d.name, d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge'
     AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_ville, 'capitale')
   LIMIT 1;
$function$;

-- juge_dossiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.juge_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_ville text;
BEGIN
  SELECT d.name, d.country, d.poste ->> 'city' INTO v_nom, v_pays, v_ville
    FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge' LIMIT 1;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge'); END IF;
  v_ville := coalesce(v_ville, 'capitale');

  RETURN jsonb_build_object('ok', true, 'juge', v_nom, 'ville', v_ville,
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
     WHERE p.country = v_pays AND p.city IS NOT DISTINCT FROM v_ville
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande', 'appel')));
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
  IF coalesce(v_a ->> 'status', '') NOT IN ('jugee', 'relaxe') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jugement_de_premiere_instance',
                              'statut', v_a ->> 'status'); END IF;
  IF v_a ? 'appel_ouvert_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_deja_interjete',
                              'par', v_a ->> 'appel_par'); END IF;

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

-- justice_fenetre_appel_jours() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.justice_fenetre_appel_jours()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 2 $function$;

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

-- parquet_enqueter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_enqueter(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'enquete',
           'enquete_par', v_g ->> 'procureur',
           'enquete_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'au_parquet';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'enquete_diligentee', v_g ->> 'procureur', 'procureur');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'enquete');
END;
$function$;

-- parquet_garde(text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_garde(p_affaire_id text, p_statuts text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_p record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_site text;
BEGIN
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_procureur');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  IF v_pays IS DISTINCT FROM v_p.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF NOT (coalesce(v_a ->> 'status', '') = ANY (p_statuts)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status', 'attendus', to_jsonb(p_statuts));
  END IF;

  -- LE DELAI S'OPPOSE ICI, et non seulement a minuit. Entre l'echeance et la passe nocturne, le
  -- dossier est perime : la poursuivre serait poursuivre une procedure eteinte.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_site := public.parquet_site_competent(v_pays, v_ville);
  IF NOT public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_requise',
                              'ville', v_ville, 'site', v_site);
  END IF;

  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom, 'pays', v_pays,
                            'ville', v_ville, 'affaire', v_a);
END;
$function$;

-- parquet_moi() -> TABLE(nom text, pays text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_moi()
 RETURNS TABLE(nom text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.name, d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'procureur'
   LIMIT 1;
$function$;

-- parquet_non_lieu(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_non_lieu(p_affaire_id text, p_motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_motif text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet', 'enquete']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- UN NON-LIEU N'EST PAS UN VERDICT SUR LES FAITS. Le serveur enregistre que le parquet a
  -- decide de ne pas poursuivre, et rien de plus : ni que la plainte etait mensongere, ni que la
  -- personne visee est innocente. Le motif, quand il y en a un, est le TEXTE DU PROCUREUR --
  -- une declaration de joueur, pas une conclusion du serveur.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'non_lieu',
           'non_lieu_par', v_g ->> 'procureur',
           'non_lieu_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'non_lieu_motif_declare', v_motif))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') IN ('au_parquet', 'enquete');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'non_lieu', v_g ->> 'procureur', 'procureur', NULL, NULL,
    CASE WHEN v_motif IS NULL THEN NULL
         ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'non_lieu');
END;
$function$;

-- parquet_poursuivre(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_poursuivre(p_affaire_id text, p_infraction text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_inf text; v_lib text; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet', 'enquete']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  -- LA QUALIFICATION EST CANONIQUE, OU ELLE N'EST PAS. `infraction_canonique` est fail closed et
  -- refuse aussi un nom de CATEGORIE : on ne poursuit pas quelqu'un pour « crime » en general.
  v_inf := public.infraction_canonique(p_infraction);
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue', 'demande', p_infraction);
  END IF;
  SELECT libelle INTO v_lib FROM public.infractions WHERE id = v_inf;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'poursuites',
           'qualification_parquet', v_inf,
           'qualification_parquet_libelle', v_lib,
           'poursuites_par', v_g ->> 'procureur',
           'poursuites_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') IN ('au_parquet', 'enquete');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'poursuites_engagees', v_g ->> 'procureur', 'procureur', NULL, v_inf,
    jsonb_build_object('accuse', v_a ->> 'cible',
                       'categorie_alleguee', v_a ->> 'categorie_alleguee'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'poursuites',
                            'qualification', v_inf, 'libelle', v_lib);
END;
$function$;

-- parquet_site_competent(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_site_competent(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN v.est_capitale THEN 'tribunal' ELSE 'tribunal-local' END
    FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville;
$function$;

-- parquet_transmettre_juge(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_transmettre_juge(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g jsonb; v_a jsonb; v_n integer;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['poursuites']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'saisie',
           'saisine_par', v_g ->> 'procureur',
           'saisine_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'poursuites';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'juge_saisi', v_g ->> 'procureur', 'procureur', NULL, v_a ->> 'qualification_parquet');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'saisie');
END;
$function$;

-- plainte_defendre(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text, p_issue text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
  v_inf text; v_i record; v_seuil integer; v_pays text; v_ville text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_issue NOT IN ('reussite_critique', 'attenuante', 'aggravation', 'infructueuse') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'issue_inconnue');
  END IF;

  SELECT p.data, p.country, p.city INTO v_brut, v_pays, v_ville
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_data := v_brut::jsonb;
  IF coalesce(v_data ->> 'cible', '') IS DISTINCT FROM v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  IF coalesce(v_data ->> 'status', '') IS DISTINCT FROM 'au_parquet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_defendable',
                              'statut', v_data ->> 'status');
  END IF;
  IF v_data ? 'defense_le' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'defense_deja_plaidee',
                              'issue_precedente', v_data ->> 'defense_issue');
  END IF;

  v_inf := public.affaire_infraction_de(v_data);
  IF v_inf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_non_determinee');
  END IF;
  SELECT i.jours_reference, i.categorie INTO v_i
    FROM public.infractions i WHERE i.id = v_inf;
  IF v_i.jours_reference IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_hors_catalogue',
                              'infraction', v_inf);
  END IF;

  -- PREMIER CRITERE : LA DUREE DE REFERENCE.
  v_seuil := public.justice_seuil_procedure_simplifiee_jours();
  IF v_i.jours_reference > v_seuil THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_reservee_aux_peines_courtes',
                              'infraction', v_inf, 'jours_reference', v_i.jours_reference,
                              'seuil', v_seuil);
  END IF;

  -- SECOND CRITERE : LA CATEGORIE. Un crime ne passe JAMAIS par la procedure simplifiee, quelle
  -- que soit la duree que son bareme historique lui donne. Et la categorie doit etre PRESENTE :
  -- sans elle, on ne peut pas affirmer que ce n'est pas un crime -- voir l'en-tete.
  IF v_i.categorie IS NULL OR v_i.categorie = 'crime' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_exclut_les_crimes',
                              'infraction', v_inf, 'categorie', v_i.categorie,
                              'jours_reference', v_i.jours_reference);
  END IF;

  v_maj := jsonb_build_object('defendue_par', v_nom, 'defendue_le',
                              to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                              'defense_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                              'defense_issue', p_issue,
                              'defense_infraction', v_inf,
                              'procedure_simplifiee', true);
  IF p_issue = 'reussite_critique' THEN
    v_maj := v_maj || jsonb_build_object('status', 'jugee', 'resultatDefense', 'reussite_critique');
  ELSIF p_issue = 'attenuante' THEN
    v_maj := v_maj || jsonb_build_object('circonstanceAttenuante', true);
  ELSIF p_issue = 'aggravation' THEN
    v_maj := v_maj || jsonb_build_object('aggravation', true);
  END IF;

  v_data := v_data || v_maj;
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;
  PERFORM set_config('rp.verdict_interne', '', true);

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'defense_simplifiee',
    v_nom, NULL, NULL, v_inf,
    jsonb_build_object('issue', p_issue, 'jours_reference', v_i.jours_reference,
                       'categorie', v_i.categorie, 'seuil', v_seuil));

  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'affaire', v_data,
                            'infraction', v_inf, 'jours_reference', v_i.jours_reference,
                            'categorie', v_i.categorie);
END; $function$;

-- plainte_deposer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text, p_categorie text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_id text; v_data jsonb; v_cible text; v_cat text;
  v_pa integer; v_cost integer; v_n integer; v_paye jsonb;
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

  -- LA CATEGORIE ALLEGUEE EST LE PREMIER DES TROIS NIVEAUX DE QUALIFICATION, et c'est une
  -- DECLARATION du plaignant, pas une charge. Elle est validee contre les quatre categories
  -- generiques du code penal -- pour qu'elle veuille dire quelque chose -- mais elle n'engage
  -- rien : le parquet qualifiera ce qu'il veut, et le juge aussi.
  v_cat := nullif(btrim(coalesce(p_categorie, '')), '');
  IF v_cat IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.infractions_categories c WHERE c.id = v_cat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_inconnue', 'demande', v_cat);
  END IF;

  -- ANTI-SPAM : une seule plainte EN COURS DE TRAITEMENT par plaignant et par cible. Les statuts
  -- vivants sont ceux du parquet et du juge ; un dossier clos (non-lieu, arret, relaxe, jugee,
  -- abandonnee) n'empeche plus de deposer. VERIFIE AVANT LE PAIEMENT : un refus ne coute rien.
  IF EXISTS (SELECT 1 FROM public.plaintes_en_cours p
              WHERE p.country = v_pays
                AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
                AND (p.data::jsonb) ->> 'auteur' = v_nom
                AND (p.data::jsonb) ->> 'cible'  = v_cible
                AND (p.data::jsonb) ->> 'status' IN
                    ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande',
                     'deposee', 'enquete_ouverte')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plainte_deja_en_cours');
  END IF;

  -- LE COUT EST LU AU MIROIR, jamais ecrit ici. Fail closed.
  SELECT count(*) INTO v_n FROM public.ordres_couts o WHERE o.fn = 'plainte_police';
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_indetermine',
                              'fn', 'plainte_police', 'declarations', v_n);
  END IF;
  SELECT o.pa, o.cost INTO v_pa, v_cost FROM public.ordres_couts o WHERE o.fn = 'plainte_police';

  -- LE PAIEMENT PRECEDE LA CREATION, DANS LA MEME TRANSACTION (12 octobre 2026, inchange).
  v_paye := public.payer_ordre(v_nom, 'plainte_police', v_pa, v_cost);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paye ->> 'raison', 'paiement_refuse'),
                              'paiement', v_paye);
  END IF;

  v_id := 'plainte-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);

  -- LA PLAINTE EST UNE DECLARATION. Le serveur enregistre « v_nom affirme ceci contre v_cible »,
  -- et jamais « ceci est vrai ». Aucune instruction, aucune enquete, aucune garde a vue : le
  -- dossier arrive au parquet et attend.
  v_data := jsonb_build_object(
    'id', v_id, 'auteur', v_nom, 'cible', v_cible, 'motif', p_motif,
    'categorie_alleguee', v_cat,
    'jour', v_jour, 'city', v_ville, 'country', v_pays, 'status', 'au_parquet',
    'origine', 'plainte',
    'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text);

  PERFORM public.dossier_acte_consigner(v_id, v_pays, v_ville, 'plainte_deposee',
    v_nom, NULL, NULL, NULL,
    jsonb_build_object('cible', v_cible, 'categorie_alleguee', v_cat));

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,
                            'statut', 'au_parquet', 'paiement', v_paye);
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
  -- `classer` A DISPARU DE LA LISTE, et c'est le coeur du transfert d'autorite : l'opportunite
  -- des poursuites appartient au parquet. Un appel avec l'ancienne decision est refuse
  -- explicitement, pour que le defaut se voie au lieu d'etre avale.
  IF p_decision = 'classer' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'classement_reserve_au_parquet');
  END IF;
  IF p_decision <> 'enqueter' THEN
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
  -- L'ENQUETE N'EST POSSIBLE QUE SI LE PARQUET L'A ORDONNEE. C'est la regle : le Procureur
  -- dirige l'enquete, la police l'accomplit.
  IF coalesce(v_data ->> 'status', '') <> 'enquete' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enquete_non_diligentee',
                              'statut', v_data ->> 'status');
  END IF;
  IF coalesce((v_data ->> 'enquete_accomplie')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enquete_deja_accomplie');
  END IF;

  -- L'ACTE LUI-MEME EST INCHANGE : il cherche une trace non decouverte de la personne visee,
  -- la marque decouverte, traite la branche contre-espionnage, et ouvre une garde a vue.
  v_res := public.plainte_instruire_interne(v_pays, v_ville, v_data ->> 'cible',
                                            v_data ->> 'motif', v_nom);

  -- LE STATUT NE BOUGE PAS : le dossier reste `enquete`, donc au parquet. L'acte de police ne
  -- decide de rien -- il rapporte. C'est le Procureur qui en tirera un non-lieu ou des
  -- poursuites.
  UPDATE public.plaintes_en_cours
     SET data = (v_data || jsonb_build_object(
           'enquete_accomplie', true,
           'enquete_par_police', v_nom,
           'enquete_resultat', v_res ->> 'decision',
           'enquete_acte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_id;

  PERFORM public.dossier_acte_consigner(p_id, v_pays, v_ville, 'enquete_acte_police',
    v_nom, 'commissaire', NULL, NULL,
    jsonb_build_object('resultat', v_res ->> 'decision', 'acte', v_res ->> 'acte'));

  RETURN v_res || jsonb_build_object('id', p_id, 'statut', 'enquete');
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
  v_old jsonb; v_new jsonb; v_cle text; v_proc record;
  -- Champs qui disent l'issue judiciaire. Tout le reste (defense, pieces, circonstances) reste
  -- librement modifiable par les parties.
  v_verdict constant text[] := ARRAY['status','sentence','peine','jugement','juge',
                                     'circonstanceAttenuante','aggravation'];
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  -- LAISSEZ-PASSER DES PORTES DU CYCLE (10 octobre 2026). Il reste utilise par la defense de
  -- l'accuse, qui ecrit un champ de verdict pour le compte de quelqu'un qui n'est PAS une
  -- autorite. Le classement ministeriel, qui l'employait aussi, a disparu avec la porte.
  IF coalesce(current_setting('rp.verdict_interne', true), '') = 'on' THEN RETURN NEW; END IF;
  -- L'AUTORITE JUDICIAIRE DE LA VILLE : le juge, et le commissaire.
  IF public.affaire_autorite_de(NEW.city) THEN RETURN NEW; END IF;

  -- ET LE PARQUET (12 octobre 2026). Le Procureur est NATIONAL : son poste n'a pas de ville,
  -- donc `affaire_autorite_de` le refusait, et ce declencheur restaurait le `status` qu'il venait
  -- d'ecrire -- ses poursuites etaient engagees et sans effet. Il n'est pas une PARTIE a
  -- l'affaire, il est l'autorite qui conduit la procedure : la protection ne le vise pas. Le pays
  -- est verifie, parce qu'un procureur n'a d'autorite que sur les affaires du sien.
  SELECT * INTO v_proc FROM public.parquet_moi();
  IF v_proc.nom IS NOT NULL AND v_proc.pays IS NOT DISTINCT FROM NEW.country THEN
    RETURN NEW;
  END IF;

  -- L'auteur n'est ni l'autorite judiciaire, ni le parquet : on restaure les champs de verdict
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

-- police_delai_intervention_secondes() -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.police_delai_intervention_secondes()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT 10 $function$;

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
