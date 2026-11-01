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

-- affaire_audience_ouverte(jsonb) -> boolean | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.affaire_audience_ouverte(p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$ SELECT coalesce(p_data ? 'audience_ouverte_le', false); $function$;

-- affaire_autorite_de(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_autorite_de(p_city text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- LE COMMISSAIRE, ET LE JUGE PJ : la fiche du compte authentifie, comme avant.
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('juge', 'commissaire')
       -- Juridiction : la ville du POSTE doit etre celle de l'affaire.
       -- coalesce a 'capitale' pour les affaires anterieures sans ville.
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  )
  -- LE JUGE, PAR SON RESOLVEUR UNIQUE. Il couvre le juge PJ (deja couvert ci-dessus, et c'est
  -- sans consequence) et le PNJ titulaire incarne par l'administration, dont la titularite est
  -- reverifiee a chaque appel. Sans cette branche, un verdict d'Honore est rendu et defait.
  OR EXISTS (
    SELECT 1 FROM public.juge_moi() j
     WHERE j.ville IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  );
$function$;

-- affaire_categorie_publique(jsonb) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.affaire_categorie_publique(p_data jsonb)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT i.categorie FROM public.infractions i
      WHERE i.id = coalesce(p_data ->> 'qualification_finale',
                            p_data ->> 'qualification_parquet',
                            p_data ->> 'infraction_constatee')),
    p_data ->> 'categorie_alleguee');
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

-- amende_imposer_interne(text,text,text,integer) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.amende_imposer_interne(p_id text, p_pays text, p_condamne text, p_montant integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r jsonb;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN 0; END IF;
  r := public.sanction_financiere_imposer_interne(p_id, coalesce(nullif(split_part(p_id, '-', 1), ''), 'sanction'), p_pays, p_condamne, p_montant, 'tresor');
  RETURN coalesce((r->>'preleve')::integer, 0);
END;
$function$;

-- amende_jugement_enregistrer() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.amende_jugement_enregistrer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE montant integer := coalesce(nullif(NEW.data->>'amende','')::integer, 0);
  instance text := coalesce(NEW.data->>'instance', 'premiere'); affaire text;
BEGIN
  affaire := CASE WHEN left(NEW.id, 4) = 'jug-' THEN substr(NEW.id, 5) END;
  IF instance = 'appel' THEN
    -- La décision d'appel remplace l'amende de première instance (jamais prélevée : appel suspensif).
    UPDATE public.amendes_tresor SET statut = 'remplacee_appel', updated_at = now()
     WHERE jugement_id = NEW.data->>'jugement_premiere_instance' AND statut IN ('suspendue','due') AND paye = 0;
    affaire := coalesce(affaire, substr(NEW.data->>'jugement_premiere_instance', 5));
  END IF;
  IF montant <= 0 OR coalesce(NEW.data->>'verdict','condamnation') IN ('relaxe','acquittement','annulation') THEN RETURN NEW; END IF;
  INSERT INTO public.amendes_tresor(jugement_id, pays, condamne, affaire_id, montant, statut, appel_jusqu_au_jour_pays)
  VALUES (NEW.id, NEW.country, NEW.accuse, affaire, montant,
          CASE WHEN instance IN ('appel','simplifiee') THEN 'due' ELSE 'suspendue' END,
          nullif(NEW.data->>'appel_jusqu_au_jour_pays','')::integer)
  ON CONFLICT (jugement_id) DO NOTHING;
  IF instance IN ('appel','simplifiee') THEN PERFORM public.amende_prelever_interne(NEW.id); END IF;
  RETURN NEW;
END;
$function$;

-- amende_prelever_interne(text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.amende_prelever_interne(p_jugement text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.amendes_tresor; dispo numeric; pris integer; nat jsonb; r jsonb; ancien text;
  aujourdhui date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT * INTO a FROM public.amendes_tresor WHERE jugement_id = p_jugement FOR UPDATE;
  IF NOT FOUND OR a.statut <> 'due' OR a.dernier_prelevement IS NOT DISTINCT FROM aujourdhui THEN RETURN 0; END IF;
  -- Destinataire vérifié AVANT tout débit : jamais d'argent prélevé sans être versé.
  IF a.destinataire = 'tresor' THEN
    SELECT data INTO nat FROM public.budgets_nationaux WHERE id = a.pays FOR UPDATE;
    IF NOT FOUND THEN RETURN 0; END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = substr(a.destinataire, 8)) THEN
    RETURN 0;
  END IF;
  SELECT greatest(0, coalesce(d.liquide,0)) + greatest(0, coalesce((SELECT c.solde FROM public.comptes_bancaires c
           WHERE c.personnage = d.name AND c.banque = 'nationale' LIMIT 1),0))
    INTO dispo FROM public.personnages_donnees d WHERE d.name = a.condamne FOR UPDATE;
  pris := least(a.montant - a.paye, floor(coalesce(dispo,0)))::integer;
  IF pris > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(a.condamne, pris) THEN pris := 0; END IF;
  END IF;
  IF pris > 0 THEN
    IF a.destinataire = 'tresor' THEN
      UPDATE public.budgets_nationaux
         SET data = jsonb_set(coalesce(nat,'{}'::jsonb), '{reserveJour}', to_jsonb(coalesce((nat->>'reserveJour')::numeric,0) + pris)), updated_at = now()
       WHERE id = a.pays;
    ELSE
      ancien := current_setting('rp.caisse_interne', true);
      PERFORM set_config('rp.caisse_interne', 'on', true);
      r := public.caisse_institution_mouvement(substr(a.destinataire, 8), pris, true);
      PERFORM set_config('rp.caisse_interne', coalesce(ancien, ''), true);
      IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'sanction_versement_refuse'; END IF;
    END IF;
  END IF;
  UPDATE public.amendes_tresor
     SET paye = paye + pris, dernier_prelevement = aujourdhui, updated_at = now(),
         statut = CASE WHEN paye + pris >= montant THEN 'soldee' ELSE 'due' END,
         paiements = CASE WHEN pris > 0 THEN paiements || jsonb_build_array(jsonb_build_object('date', aujourdhui, 'montant', pris)) ELSE paiements END
   WHERE jugement_id = p_jugement;
  IF pris > 0 THEN
    PERFORM public.mail_systeme_poser_interne(CASE WHEN a.destinataire = 'tresor' THEN 'Trésor national' ELSE 'Service des amendes' END,
      a.condamne, 'Amende — prélèvement',
      pris || ' FR prélevés au titre de votre amende. ' ||
      CASE WHEN a.paye + pris >= a.montant THEN 'Votre amende est entièrement payée.'
           ELSE 'Reste dû : ' || (a.montant - a.paye - pris) || ' FR, prélevés au fur et à mesure de vos rentrées d''argent.' END, NULL);
  END IF;
  RETURN pris;
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

-- audience_messages_append_only() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audience_messages_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'audience_messages est en ajout seul : ni modification ni suppression';
END $function$;

-- audience_peut_ecrire(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audience_peut_ecrire(p_affaire_id text, p_personne text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.audience_paroles a
                  WHERE a.affaire = p_affaire_id AND a.personne = p_personne
                    AND a.retiree_le IS NULL);
$function$;

-- audience_role_de(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audience_role_de(p_affaire_id text, p_personne text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_brut text; v_a jsonb; v_ville text; v_pays text; v_j record; v_p record;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN RETURN NULL; END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom = p_personne THEN RETURN 'juge'; END IF;
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom = p_personne AND v_p.pays IS NOT DISTINCT FROM v_pays THEN RETURN 'procureur'; END IF;
  IF coalesce(v_a ->> 'cible', '') = p_personne THEN RETURN 'prevenu'; END IF;
  IF public.defense_avocat_de(p_affaire_id) = p_personne THEN RETURN 'avocat'; END IF;
  IF EXISTS (SELECT 1 FROM public.temoins_citations c
              WHERE c.affaire = p_affaire_id AND c.temoin = p_personne) THEN RETURN 'temoin'; END IF;
  RETURN 'spectateur';
END $function$;

-- audition_consigner_interne(text,text,text,text,text,text,boolean,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.audition_consigner_interne(p_affaire text, p_pays text, p_ville text, p_personne text, p_qualite text, p_declaration text, p_refus boolean, p_jour integer, p_exiger_presence boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_decl text; v_refus boolean; v_id text; v_c record;
BEGIN
  IF p_qualite NOT IN ('prevenu', 'temoin') THEN
    RAISE EXCEPTION 'audition : qualite inconnue (%)', p_qualite;
  END IF;

  v_refus := coalesce(p_refus, false);
  v_decl  := nullif(btrim(coalesce(p_declaration, '')), '');
  -- UNE REPONSE EST EXIGEE, ET LE REFUS EN EST UNE. Ce qui est refuse ici, c'est la reponse VIDE :
  -- ni declaration, ni refus explicite. Le silence n'est pas une reponse procedurale, et ce n'est
  -- pas le serveur qui doit le choisir a la place du joueur.
  IF NOT v_refus AND v_decl IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_absente');
  END IF;
  -- Un refus EXPLICITE efface le texte : on n'enregistre pas deux reponses contradictoires.
  IF v_refus THEN v_decl := NULL; END IF;

  -- LA PRESENCE PHYSIQUE, QUAND L'APPELANT L'EXIGE. Le commissariat de la ville du tribunal
  -- competent, et aucun autre -- une deposition ne se fait pas depuis l'etranger ni de chez soi.
  IF coalesce(p_exiger_presence, false) THEN
    SELECT * INTO v_c FROM public.temoin_commissariat_competent(p_pays, p_ville);
    IF v_c.batiment IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'commissariat_indetermine', 'ville', p_ville);
    END IF;
    IF NOT public.acteur_present_sur_site(p_personne, p_pays, p_ville, v_c.batiment, v_c.piece) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_commissariat_requise',
                                'ville', p_ville, 'site', v_c.batiment, 'piece', v_c.piece);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.dossiers_auditions a
              WHERE a.affaire = p_affaire AND a.personne = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audition_deja_realisee');
  END IF;

  v_id := CASE WHEN p_qualite = 'temoin' THEN 'dep-' ELSE 'pv-' END
          || substr(md5(p_affaire || '|' || p_personne), 1, 16);
  INSERT INTO public.dossiers_auditions
    (id, affaire, pays, ville, personne, declaration, refus, jour_pv, qualite)
  VALUES (v_id, p_affaire, p_pays, p_ville, p_personne, v_decl, v_refus, p_jour, p_qualite);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'qualite', p_qualite,
                            'refus', v_refus, 'declaration', v_decl, 'jour', p_jour);
END $function$;

-- avocat_dossier(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_dossier(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_g record; v_quals text[];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF public.defense_avocat_de(p_affaire_id) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_dossier'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece); END IF;

  -- LES QUALIFICATIONS REELLEMENT RETENUES DANS CE DOSSIER, et elles seules. Une trace qui
  -- porterait sur un acte dont ce dossier ne parle pas n'est une preuve de rien ici.
  v_quals := ARRAY(SELECT DISTINCT x FROM unnest(ARRAY[
      v_a ->> 'infraction_constatee', v_a ->> 'qualification_parquet',
      v_a ->> 'qualification_finale']) AS x WHERE x IS NOT NULL);

  RETURN jsonb_build_object('ok', true,
    'affaire', p_affaire_id, 'ville', v_ville, 'pays', v_pays,
    'prevenu', v_a ->> 'cible',
    'plaignant', coalesce(v_a ->> 'plaignant', v_a ->> 'auteur'),
    'motif', v_a ->> 'motif',
    'categorie_alleguee', v_a ->> 'categorie_alleguee',
    'statut', v_a ->> 'status',
    'jour_depot', v_a ->> 'jour',
    'qualification_constatee', v_a ->> 'infraction_constatee',
    'qualification_parquet', v_a ->> 'qualification_parquet',
    'qualification_finale', v_a ->> 'qualification_finale',
    'delai_jugement_jour', v_a ->> 'delai_jugement_jour',
    'audience_ouverte', public.affaire_audience_ouverte(v_a),
    'audience_jour', v_a ->> 'audience_jour',
    'audition', (SELECT jsonb_build_object(
                   'personne', a.personne, 'refus', a.refus,
                   'declaration', a.declaration, 'jour', a.jour_pv, 'fait_le', a.fait_le,
                   'pv_a_libere_une_detention', (
                      SELECT coalesce((x.donnees ->> 'libere')::boolean, false)
                        FROM public.dossiers_judiciaires_actes x
                       WHERE x.affaire = p_affaire_id AND x.type = 'pv_audition'
                       ORDER BY x.rang DESC LIMIT 1))
                  FROM public.dossiers_auditions a
                 WHERE a.affaire = p_affaire_id AND a.personne = (v_a ->> 'cible')
                   AND a.qualite = 'prevenu'),
    -- LES TEMOINS CITES, QUI LES A CITES, ET OU ILS EN SONT.
    'temoins', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'temoin', c.temoin, 'cite_par', c.cite_par, 'qualite', c.cite_par_qualite,
                  'convocation', c.convocation_rang, 'echeance_jour', c.echeance_jour,
                  'etat', c.etat, 'issue', c.issue) ORDER BY c.rang), '[]'::jsonb)
                 FROM public.temoins_citations c WHERE c.affaire = p_affaire_id),
    -- LEURS DEPOSITIONS, VERBATIM, REFUS COMPRIS. Aucune interpretation, aucune note.
    'temoignages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                      'personne', a.personne, 'refus', a.refus, 'declaration', a.declaration,
                      'jour', a.jour_pv, 'fait_le', a.fait_le) ORDER BY a.fait_le), '[]'::jsonb)
                     FROM public.dossiers_auditions a
                    WHERE a.affaire = p_affaire_id AND a.qualite = 'temoin'),
    -- LES PREUVES REELLES, ET RIEN QUI LEUR RESSEMBLE. Une trace objective d'`actions_tracables`,
    -- non expiree, liant le prevenu a une qualification retenue dans CE dossier -- la meme notion
    -- que `justice_preuve_reelle`. Aucun texte libre, aucune rumeur, aucune declaration n'entre
    -- ici, et si la base n'en porte aucune le tableau est VIDE.
    'preuves', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'id', t.id, 'acte', t.type_action, 'jour', t.jour, 'ville', t.city,
                  'jour_expiration', t.jour_expiration) ORDER BY t.jour, t.id), '[]'::jsonb)
                 FROM public.actions_tracables t
                WHERE t.country IS NOT DISTINCT FROM v_pays
                  AND t.auteur = (v_a ->> 'cible')
                  AND t.type_action = ANY (v_quals)
                  AND coalesce(t.jour_expiration, 0) >= coalesce(
                        (SELECT d.day FROM public.personnages_donnees d
                          WHERE d.name = (v_a ->> 'cible')), 1)),
    'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                 'acteur', x.acteur, 'poste', x.acteur_poste,
                 'qualif_avant', x.qualif_avant, 'qualif_apres', x.qualif_apres,
                 'donnees', x.donnees, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                FROM public.dossiers_judiciaires_actes x
                JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
               WHERE x.affaire = p_affaire_id),
    'greffe', jsonb_build_object('batiment', v_g.batiment, 'piece', v_g.piece));
END $function$;

-- avocat_est_qualifie(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_est_qualifie(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- L'ARBITRAGE EST RENDU : exercer comme avocat exige la carriere JUSTICE, initiale ou acquise
  -- a l'Universite comme seconde carriere. Il n'y a plus de registre vide, donc plus de porte
  -- fermee faute de decision.
  SELECT public.habilitation_ouverte(p_nom, 'avocat');
$function$;

-- avocat_ma_tarification() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_ma_tarification()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true,
    'qualifie', public.avocat_est_qualifie(public.mon_personnage()),
    'tarification', (SELECT a.tarification FROM public.avocats_barreau a
                      WHERE a.nom = public.mon_personnage()));
$function$;

-- avocat_publier_tarification(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_publier_tarification(p_tarification text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_t text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.avocat_est_qualifie(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'qualification_avocat_requise'); END IF;
  v_t := nullif(btrim(coalesce(p_tarification, '')), '');
  IF v_t IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tarification_absente'); END IF;
  IF length(v_t) > 200 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tarification_trop_longue'); END IF;

  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi;
  INSERT INTO public.avocats_barreau (nom, pays, tarification)
  VALUES (v_moi, coalesce(v_pays, 'republic'), v_t)
  ON CONFLICT (nom) DO UPDATE
    SET tarification = EXCLUDED.tarification, pays = EXCLUDED.pays, maj_le = now();
  RETURN jsonb_build_object('ok', true, 'tarification', v_t);
END $function$;

-- avocat_retirer_tarification() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.avocat_retirer_tarification()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  DELETE FROM public.avocats_barreau WHERE nom = v_moi;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'retire', v_n = 1);
END $function$;

-- casier_extrait_enquete(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.casier_extrait_enquete(p_personne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_piece text; v_inv jsonb;
        v_g record; v_jour integer; v_paye jsonb; v_doc jsonb; v_contenu jsonb;
        v_poste record; v_caisse text; v_caisse_trib text; v_solde numeric;
        v_affaire text; v_affaire_ville text; v_parquet record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_personne, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_manquante');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_introuvable');
  END IF;

  SELECT country, current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_bat, v_piece, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LE POSTE, LU EN BASE. `acteur_poste_courant` est la seule source d'autorite.
  SELECT * INTO v_poste FROM public.acteur_poste_courant();
  IF v_poste.poste_id IS NULL OR v_poste.poste_id NOT IN ('juge', 'commissaire', 'procureur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee');
  END IF;

  -- UNE AFFAIRE VIVANTE QUI VISE CETTE PERSONNE, ET DONT L'APPELANT EST L'AUTORITE.
  SELECT * INTO v_parquet FROM public.parquet_moi();
  SELECT p.id, p.city INTO v_affaire, v_affaire_ville
    FROM public.plaintes_en_cours p
   WHERE p.country = v_pays
     AND left(btrim(coalesce(p.data, '')), 1) = '{'
     AND (p.data::jsonb ->> 'cible') = p_personne
     AND (p.data::jsonb ->> 'status') IN ('au_parquet', 'enquete', 'poursuites', 'saisie',
                                          'abandon_demande', 'appel')
     AND (public.affaire_autorite_de(p.city)
          OR (v_parquet.nom IS NOT NULL AND v_parquet.pays IS NOT DISTINCT FROM p.country))
   ORDER BY p.created_at
   LIMIT 1;
  IF v_affaire IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_enquete_sur_cette_personne',
                              'personne', p_personne);
  END IF;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- LA CAISSE DE SON INSTITUTION, et elle est nommee par son POSTE.
  v_caisse := CASE v_poste.poste_id
    WHEN 'commissaire' THEN v_pays || '_commissariat_' || coalesce(v_poste.poste_city, 'capitale')
    WHEN 'juge'        THEN v_pays || '_tribunal_'     || coalesce(v_poste.poste_city, 'capitale')
    ELSE                    v_pays || '_tribunal_'     || coalesce(v_affaire_ville, 'capitale')
  END;
  v_caisse_trib := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');

  -- LE VERROU AVANT LE PAIEMENT. La caisse est lue FOR UPDATE : son solde ne peut plus changer
  -- avant la fin de la transaction, donc le debit qui suit ne peut plus manquer de fonds. Sans
  -- cela, un refus apres le prelevement des PA laisserait le PA consomme sans document.
  SELECT coalesce((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF v_solde IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_institution_introuvable',
                              'caisse', v_caisse);
  END IF;
  IF v_solde < 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_institution_insuffisante',
                              'caisse', v_caisse, 'solde', v_solde, 'requis', 100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse_trib) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse_trib);
  END IF;

  -- LE PA EST CELUI DU MAGISTRAT, ET LUI SEUL : zero FR sur son portefeuille.
  v_paye := public.payer_ordre(v_moi, 'casier_extrait_enquete', 1, 0);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  -- LE DEBIT INSTITUTIONNEL PASSE PAR LA PORTE INTERNE : l'autorite a ete verifiee ci-dessus
  -- (c'est la caisse de SON institution), et le controle generique de la porte, concu pour un
  -- appel client direct, refuserait un debit qu'aucun poste « proprietaire de caisse » ne couvre.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.caisse_institution_mouvement(v_caisse, -100, true);
  PERFORM public.caisse_institution_mouvement(v_caisse_trib, 100, true);
  PERFORM set_config('rp.caisse_interne', '', true);

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_contenu := public.casier_judiciaire_contenu(p_personne, v_pays);

  v_doc := public.document_officiel_emettre(
    'casier_extrait', 'casier_extrait', true,
    v_pays, v_ville, p_personne, NULL, NULL, v_moi, v_moi, v_jour,
    'Extrait de casier judiciaire — ' || p_personne,
    'Delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit l''etat du casier '
      || 'au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'enquete', 'affaire', v_affaire,
                       'poste', v_poste.poste_id, 'caisse', v_caisse));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'casier_extrait_enquete : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'document', v_doc ->> 'document',
    'personne', p_personne, 'jour', v_jour, 'tribunal', v_ville,
    'emis_par', v_doc ->> 'emis_par', 'affaire', v_affaire,
    'caisse_debitee', v_caisse,
    'vierge', (v_contenu ->> 'vierge')::boolean,
    'condamnations', jsonb_array_length(v_contenu -> 'condamnations'));
END;
$function$;

-- casier_judiciaire_contenu(text,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.casier_judiciaire_contenu(p_personne text, p_pays text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH retenues AS (
    SELECT j.id, j.jour, j.city, j.peine, j.juge, j.motif, j.data, j.created_at
      FROM public.jugements j
     WHERE j.accuse = p_personne
       AND j.country IS NOT DISTINCT FROM p_pays
       AND (j.data ->> 'verdict') = 'condamnation'
       AND NOT EXISTS (
             SELECT 1 FROM public.jugements a
              WHERE j.id LIKE 'jug-%'
                AND j.id NOT LIKE 'jug-app-%'
                AND a.id = 'jug-app-' || right(j.id, length(j.id) - 4)
                AND (a.data ->> 'verdict') = 'relaxe')
  )
  SELECT jsonb_build_object(
    'personne', p_personne,
    'pays', p_pays,
    'vierge', (SELECT count(*) FROM retenues) = 0,
    'condamnations', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'jugement',  r.id,
               'jour',      r.jour,
               'ville',     r.city,
               'infraction', r.data ->> 'infraction',
               'libelle',   coalesce(r.data ->> 'infraction_libelle', r.motif),
               'peine',     r.peine,
               'instance',  coalesce(r.data ->> 'instance', 'premiere'),
               'juge',      r.juge)
             ORDER BY r.jour, r.created_at)
        FROM retenues r), '[]'::jsonb));
$function$;

-- casier_mon_extrait() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.casier_mon_extrait()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_piece text;
        v_g record; v_jour integer; v_paye jsonb; v_doc jsonb; v_contenu jsonb;
        v_caisse text; v_inv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country, current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_bat, v_piece, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_caisse := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse);
  END IF;

  -- LE PAIEMENT D'ABORD, ET C'EST LUI QUI PEUT REFUSER. Tout ce qui suit est garanti.
  v_paye := public.payer_ordre(v_moi, 'casier_mon_extrait', 1, 100);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  -- LES 100 FR NE SONT PAS DETRUITS : ils entrent dans la caisse du tribunal.
  PERFORM public.caisse_institution_mouvement(v_caisse, 100, true);

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_contenu := public.casier_judiciaire_contenu(v_moi, v_pays);

  v_doc := public.document_officiel_emettre(
    'casier_extrait', 'casier_extrait', true,
    v_pays, v_ville, v_moi, NULL, NULL, v_moi, v_moi, v_jour,
    'Extrait de casier judiciaire — ' || v_moi,
    'Delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit l''etat du casier '
      || 'au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'demande_personnelle'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    -- L'EMISSION A ECHOUE APRES LE PAIEMENT : on LEVE, ce qui annule le paiement avec le reste.
    -- Un refus rendu ici laisserait les 100 FR preleves sans document.
    RAISE EXCEPTION 'casier_mon_extrait : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'document', v_doc ->> 'document',
    'jour', v_jour, 'tribunal', v_ville, 'emis_par', v_doc ->> 'emis_par',
    'vierge', (v_contenu ->> 'vierge')::boolean,
    'condamnations', jsonb_array_length(v_contenu -> 'condamnations'));
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

-- convocation_detention_interne(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.convocation_detention_interne(p_nom text, p_raison text, p_jours integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record;
BEGIN
  SELECT country, coalesce(current_city, 'capitale') AS city INTO d FROM public.personnages_donnees WHERE name = p_nom;
  RETURN public.detention_ouvrir_interne(p_nom, p_raison, p_jours, d.city, d.country,
    jsonb_build_array(jsonb_build_object('type', p_raison, 'jours', p_jours, 'city', d.city, 'source', 'convocation',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
    'Commissariat', 'convocation');
END; $function$;

-- convocation_echue_interne(jsonb) -> boolean | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.convocation_echue_interne(p_c jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$ SELECT NOT coalesce((p_c ->> 'traitee')::boolean, false)
         AND (coalesce((p_c ->> 'echue')::boolean, false)
              OR (p_c ? 'limiteTs' AND now() >= (p_c ->> 'limiteTs')::timestamptz)) $function$;

-- convocation_marquer_interne(text,jsonb) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.convocation_marquer_interne(p_nom text, p_c jsonb)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ UPDATE public.personnages_donnees
         SET convocations = (SELECT jsonb_agg(CASE WHEN public.assemblee_cle_convocation(e) = public.assemblee_cle_convocation(p_c)
                                                   THEN e || jsonb_build_object('traitee', true) ELSE e END)
                               FROM jsonb_array_elements(convocations) e)
       WHERE name = p_nom $function$;

-- convocation_se_justifier(integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.convocation_se_justifier(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_convs jsonb; v_c jsonb; v_stats jsonb; v_taux integer; v_roll integer; v_paie jsonb; v_det jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT convocations, stats INTO v_convs, v_stats FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT e INTO v_c FROM jsonb_array_elements(coalesce(v_convs, '[]'::jsonb)) e
   WHERE NOT coalesce((e ->> 'traitee')::boolean, false) LIMIT 1;
  IF v_c IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation'); END IF;
  IF public.convocation_echue_interne(v_c) THEN
    PERFORM public.convocation_marquer_interne(v_moi, v_c);
    v_det := public.convocation_detention_interne(v_moi, 'Non-présentation à une convocation', 2);
    RETURN jsonb_build_object('ok', true, 'issue', 'non_presentation', 'jours', 2,
      'detention_ouverte', coalesce((v_det ->> 'ok')::boolean, false), 'detention_id', v_det ->> 'detention_id');
  END IF;
  v_paie := public.payer_ordre(v_moi, 'se_justifier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  PERFORM public.convocation_marquer_interne(v_moi, v_c);
  v_taux := greatest(0, least(100, round(50 + (coalesce((v_stats ->> 'CHA')::numeric, 8) + coalesce((v_stats ->> 'DUP')::numeric, 8)) / 2)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    PERFORM set_config('rp.recherche_interne', 'on', true);
    UPDATE public.personnages_donnees
       SET recherche = (SELECT coalesce(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(
                          CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END) e
                         WHERE e ->> 'acte' IS DISTINCT FROM v_c ->> 'motif')
     WHERE name = v_moi;
    PERFORM set_config('rp.recherche_interne', '', true);
    RETURN jsonb_build_object('ok', true, 'issue', 'classee', 'motif', v_c ->> 'motif', 'taux', v_taux,
      'recherche', (SELECT coalesce(recherche, '[]'::jsonb) FROM public.personnages_donnees WHERE name = v_moi)) || jsonb_build_object('paie', v_paie);
  END IF;
  v_det := public.convocation_detention_interne(v_moi, 'Justification rejetée au commissariat', 1);
  RETURN jsonb_build_object('ok', true, 'issue', 'rejetee', 'jours', 1, 'motif', v_c ->> 'motif', 'taux', v_taux,
    'detention_ouverte', coalesce((v_det ->> 'ok')::boolean, false), 'detention_id', v_det ->> 'detention_id')
    || jsonb_build_object('paie', v_paie);
END; $function$;

-- crime_acheter_arme_noire(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_acheter_arme_noire(p_entreprise text, p_arme text, p_benediction boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_isn numeric; v_taux integer; v_roll numeric; v_r jsonb; v_commissaire text; v_conv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, career, day, convocations INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                      WHERE id = m.country || '_' || coalesce(m.current_city, 'capitale')), 30);
  v_taux := greatest(5, least(95, round(50 + CASE m.career WHEN 'criminal_c' THEN 15 WHEN 'intel' THEN 15 WHEN 'escort' THEN 15
              WHEN 'magistrat' THEN -10 WHEN 'officer' THEN -10 WHEN 'clergy' THEN -10 WHEN 'doctor' THEN -10 ELSE 0 END
              - v_isn / 3 + CASE WHEN p_benediction THEN 5 ELSE 0 END)::integer));
  v_roll := random() * 100;
  IF v_roll > v_taux THEN
    PERFORM public.crime_rechercher_interne(v_moi, 'achat_arme_illegal', 'delit_mineur');
    v_conv := jsonb_build_object('id', 'conv-' || replace(gen_random_uuid()::text, '-', ''), 'motif', 'achat_arme_illegal',
      'jourEmission', coalesce(m.day, 1), 'heureEmission', extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,
      'jourLimite', coalesce(m.day, 1) + 1, 'heureLimite', extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,
      'traitee', false, 'limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    UPDATE public.personnages_donnees
       SET convocations = (CASE WHEN jsonb_typeof(convocations) = 'array' THEN convocations ELSE '[]'::jsonb END) || jsonb_build_array(v_conv)
     WHERE name = v_moi;
    v_commissaire := CASE m.country WHEN 'narco' THEN 'El Capitan Gordo' WHEN 'soviet' THEN 'Camarade Borodine'
                       WHEN 'khalija' THEN 'Chambellan Ibn Protocole' ELSE 'Raoul Toufaud' END;
    PERFORM public.mail_systeme_poser_interne(v_commissaire, v_moi, 'Convocation officielle',
      'L''armurier a refusé la vente et vous a dénoncé. Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux)
      || (SELECT jsonb_build_object('recherche', recherche, 'convocations', convocations) FROM public.personnages_donnees WHERE name = v_moi);
  END IF;
  v_r := public.commerce_vendre_produit_interne(v_moi, p_entreprise, jsonb_build_array(jsonb_build_object('produit', p_arme, 'qte', 1)),
           'marche_noir', 'choisir_arme', 1, 0, NULL, NULL);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  -- L'arme est deposee par le serveur (27/10/2026, chantier inventaire).
  v_r := v_r || (public.inventaire_deposer_interne(v_moi, coalesce(public.arme_modele_interne(p_entreprise, p_arme, v_moi), '{}'::jsonb)
           || jsonb_build_object('legal', false), true) - 'ok' - 'qte');
  PERFORM public.crime_tracer_interne(v_moi, 'achat_arme_illegal', NULL);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'achat_arme_illegal', NULL);
  RETURN v_r || jsonb_build_object('reussi', true, 'taux', v_taux);
END; $function$;

-- crime_acheter_arme_noire(uuid,text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_acheter_arme_noire(p_requete uuid, p_entreprise text, p_arme text, p_benediction boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('entreprise', p_entreprise, 'arme', p_arme, 'benediction', p_benediction);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_acheter_arme_noire', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.crime_acheter_arme_noire(p_entreprise, p_arme, p_benediction);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_acheter_arme_noire', prm, v);
END; $function$;

-- crime_acheter_explosifs(integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_acheter_explosifs(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_fonds numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT d.country, d.current_city, d.career, coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale'), 0) AS fonds
    INTO m FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF m.fonds < 1200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  v_paie := public.payer_ordre(v_moi, 'acheter_bombe_illegale', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, least(95, 35 + CASE m.country WHEN 'narco' THEN 20 WHEN 'soviet' THEN -10 ELSE 0 END
              + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city)));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    PERFORM public.crime_rechercher_interne(v_moi, 'acheter_bombe_illegale', 'crime');
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
  END IF;
  v_paie := public.payer_ordre(v_moi, 'acheter_bombe_illegale#reussite', 0, 1200);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'raison', 'fonds_insuffisants') || public.crime_etat_acteur_interne(v_moi);
  END IF;
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
       || jsonb_build_array(jsonb_build_object('id', 'explosif-' || replace(gen_random_uuid()::text, '-', ''),
            'type', 'explosif', 'name', 'Explosifs de chantier', 'icon', 'ti-bomb', 'legal', false,
            'desc', 'Non enregistré. Usage unique.', 'imageUrl', 'images/explosifs-marche-noir.webp'))
   WHERE name = v_moi;
  PERFORM public.crime_tracer_interne(v_moi, 'acheter_bombe_illegale', NULL);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'acheter_bombe_illegale', NULL);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- crime_acheter_explosifs(uuid,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_acheter_explosifs(p_requete uuid, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_acheter_explosifs', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.crime_acheter_explosifs(p_pa, p_cost);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_acheter_explosifs', prm, v);
END; $function$;

-- crime_contrebande(integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_contrebande(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false; v_dis numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_paie := public.payer_ordre(v_moi, 'contrebande_port', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT country, current_city, stats, resources INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_dis := coalesce(CASE WHEN jsonb_typeof(m.resources -> 'dis') = 'number' THEN (m.resources ->> 'dis')::numeric END, 8);
  v_taux := greatest(5, 55 + floor(v_dis / 10)::integer + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer + 15
            + CASE m.country WHEN 'narco' THEN 25 WHEN 'soviet' THEN -20 WHEN 'khalija' THEN 10 ELSE 0 END
            - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    UPDATE public.personnages_donnees
       SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
         || jsonb_build_array(jsonb_build_object('id', 'contrebande-' || replace(gen_random_uuid()::text, '-', ''),
              'type', 'contrebande', 'name', 'Cargaison de contrebande', 'icon', 'ti-package-off', 'legal', false,
              'desc', 'Marchandises importées illégalement.'))
     WHERE name = v_moi;
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
    v_repere := public.crime_detecter_interne(v_moi, 'contrebande_port', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- crime_corrompre(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_corrompre(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fn NOT IN ('corrompre_fonct', 'corrompre_police', 'corrompre_gardien')
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = p_fn AND pa = p_pa AND cost = p_cost) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  SELECT d.country, d.current_city, coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale'), 0) AS fonds
    INTO m FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF m.fonds < p_cost THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  v_paie := public.payer_ordre(v_moi, p_fn || '#tentative', p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, 65 - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
  END IF;
  v_paie := public.payer_ordre(v_moi, p_fn || '#reussite', 0, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'raison', 'fonds_insuffisants') || public.crime_etat_acteur_interne(v_moi);
  END IF;
  PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'corruption', NULL);
  v_repere := public.crime_detecter_interne(v_moi, p_fn, true);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- crime_corrompre_douanier(integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_corrompre_douanier(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_paie := public.payer_ordre(v_moi, 'corrompre_douanier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT stats, resources INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, 55 + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer
            + floor(coalesce(CASE WHEN jsonb_typeof(m.resources -> 'inf') = 'number' THEN (m.resources ->> 'inf')::numeric END, 0) / 10)::integer + 20);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
    v_repere := public.crime_detecter_interne(v_moi, 'corrompre_douanier', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- crime_detecter_interne(text,text,boolean,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_detecter_interne(p_nom text, p_acte text, p_selon_checkdetection boolean, p_acte_recherche text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a record; d record; v_dis numeric; v_taux integer;
BEGIN
  SELECT * INTO a FROM public.actes_illegaux WHERE fn = p_acte;
  IF NOT FOUND THEN RETURN false; END IF;
  SELECT poste ->> 'id' AS poste, resources INTO d FROM public.personnages_donnees WHERE name = p_nom;
  v_dis := coalesce(CASE WHEN jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric END, 50);
  IF p_selon_checkdetection THEN
    IF d.poste = 'president' THEN RETURN false; END IF;
    IF d.poste IN ('pm','min_int','min_fin','min_just','min_def','min_info','min_ae') AND a.type = 'delit_mineur' THEN RETURN false; END IF;
    v_taux := greatest(5, a.detect_rate - floor(v_dis / 10)::integer);
  ELSE
    v_taux := a.detect_rate;
  END IF;
  IF floor(random() * 100)::integer + 1 > v_taux THEN RETURN false; END IF;
  PERFORM public.crime_rechercher_interne(p_nom, coalesce(p_acte_recherche, p_acte), a.type);
  IF p_selon_checkdetection THEN
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                                 '{dis}', to_jsonb(greatest(0, v_dis - 10)))
     WHERE name = p_nom;
  END IF;
  RETURN true;
END; $function$;

-- crime_dis_ajuster_interne(text,integer) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_dis_ajuster_interne(p_nom text, p_delta integer)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}',
               to_jsonb(least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'dis') = 'number'
                                                              THEN (resources ->> 'dis')::numeric END, 50) + p_delta))))
       WHERE name = p_nom $function$;

-- crime_empoisonner(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_empoisonner(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; c record; v_pos integer; v_type text; v_taux integer; v_roll integer; v_palier text;
  v_stats jsonb; v_repere boolean := false; v_quand text; v_msg text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT name, country, current_city, current_building, current_room INTO c FROM public.personnages_donnees WHERE name = p_cible;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF c.country IS DISTINCT FROM m.country OR c.current_city IS DISTINCT FROM m.current_city
     OR c.current_building IS DISTINCT FROM m.current_building OR c.current_room IS DISTINCT FROM m.current_room THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
  SELECT (o.ord - 1)::integer, o.item ->> 'poisonType' INTO v_pos, v_type
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(item, ord)
   WHERE o.item ->> 'type' = 'poison' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poison_manquant'); END IF;
  v_type := CASE WHEN v_type IN ('parapluie', 'ghb', 'polonium', 'vipere') THEN v_type ELSE 'parapluie' END;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = v_moi;

  v_taux := greatest(5, 40 - 5 + CASE m.country WHEN 'narco' THEN 20 WHEN 'soviet' THEN -10 ELSE 0 END
            + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux / 2.0 THEN v_palier := 'totale';
  ELSIF v_roll <= v_taux THEN v_palier := 'partielle';
  ELSIF v_roll <= v_taux + (100 - v_taux) / 2.0 THEN v_palier := 'echec_partiel';
  ELSE v_palier := 'echec_total'; END IF;

  IF v_palier <> 'echec_total' THEN
    SELECT jsonb_agg(s) INTO v_stats FROM (SELECT s FROM unnest(ARRAY['INT','CHA','VOL','PER','DUP','ENT']) s ORDER BY random() LIMIT 2) x;
    INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite, details)
    VALUES ('poison-' || gen_random_uuid(), p_cible, 'poison_start', 0, v_palier, false,
            jsonb_build_object('poisonType', v_type, 'statsTouchees', v_stats));
    v_quand := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
    v_msg := CASE v_type
      WHEN 'ghb' THEN 'Votre esprit devient confus. Vous avez la tête qui tourne et vos sens sont perturbés. Vous avez l''impression d''avoir été drogué(e), mais par qui ? Vous perdez 2 PA.'
      WHEN 'polonium' THEN 'Vous vous sentez subitement faible. En passant la main dans vos cheveux, ils se décrochent par paquets de votre crâne, comme si vous aviez été mis(e) en contact avec quelque chose de radioactif. Vous perdez 2 PA.'
      WHEN 'vipere' THEN 'Vous ressentez une violente douleur au niveau du mollet. Deux petits trous douloureux et rouges sont visibles. Un serpent vous aurait-il mordu(e) ? Vous perdez 2 PA.'
      ELSE 'Quelque chose vous pique dans le dos. Une douleur irradie dans tout votre corps et s''intensifie d''heure en heure. Était-ce en lien avec cette personne qui vous a touché avec le bout de son parapluie et s''est excusée ? Vous perdez 2 PA.' END;
    PERFORM public.mail_systeme_poser_interne('Événement mystérieux', p_cible, 'Vous vous sentez mal...', v_msg, v_quand);
    PERFORM public.annonce_publique_interne(m.country, 'MYSTÈRE : ' || p_cible || ' se sent soudainement très mal...');
    PERFORM public.crime_tracer_interne(v_moi, 'empoisonnement', p_cible);
    PERFORM public.crime_trace_rumeur_interne(v_moi, 'empoisonnement', p_cible);
    v_repere := public.crime_detecter_interne(v_moi, 'empoisonnement', true);
  ELSE
    PERFORM public.crime_rechercher_interne(v_moi, 'tentative_empoisonnement', 'crime');
    v_repere := true;
  END IF;
  RETURN jsonb_build_object('ok', true, 'palier', v_palier, 'reussi', v_palier IN ('totale', 'partielle'), 'repere', v_repere,
    'taux', v_taux, 'jet', v_roll, 'inventaire', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi), 'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi), 'revision', (SELECT inventory_revision FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

-- crime_etat_acteur_interne(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_etat_acteur_interne(p_nom text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT jsonb_build_object('pa', pa, 'arg', arg, 'liquide', liquide, 'dis', resources -> 'dis',
              'recherche', recherche, 'inventaire', inventory, 'inventory', inventory, 'revision', inventory_revision)
        FROM public.personnages_donnees WHERE name = p_nom $function$;

-- crime_explosifs(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_explosifs(p_nom_batiment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_pos integer; v_taux integer; v_roll integer; v_reussi boolean;
  v_repere boolean; v_nom text; v_victimes text[] := ARRAY[]::text[]; v_v record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, career, inventory INTO m
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  SELECT (o.ord - 1)::integer INTO v_pos
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(item, ord)
   WHERE o.item ->> 'type' = 'explosif' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'explosif_manquant'); END IF;
  v_nom := left(coalesce(nullif(btrim(p_nom_batiment), ''), m.current_building), 80);
  v_paie := public.payer_ordre(v_moi, 'utiliser_explosifs', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = v_moi;

  v_taux := greatest(5, 35 + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city)
            - CASE WHEN m.current_building IN ('palais-presidentiel','palais-gouvernement','assemblee','tribunal','commissariat',
                                               'banque-nationale','banque-privee','mairie-capitale','mairie','commissariat-local','tribunal-local','banque-locale') THEN 30 ELSE 0 END);
  v_roll := floor(random() * 100)::integer + 1;
  v_reussi := v_roll <= v_taux;
  IF v_reussi THEN
    INSERT INTO public.batiments_fermes (pays, ville, batiment_id, duree_jours, motif, auteur, jour_fin)
    VALUES (m.country, m.current_city, m.current_building, 5, 'explosifs', v_moi, 0);
    FOR v_v IN SELECT name FROM public.personnages_donnees
                WHERE country = m.country AND current_city = m.current_city AND current_building = m.current_building
                  AND current_room IS NOT DISTINCT FROM m.current_room AND name <> v_moi FOR UPDATE LOOP
      UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), 15) WHERE name = v_v.name;
      INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, traite)
      SELECT 'explosion-' || gen_random_uuid(), v_v.name, 'hp_set', hp, false FROM public.personnages_donnees WHERE name = v_v.name;
      PERFORM public.mail_systeme_poser_interne('Événement', v_v.name, 'Explosion !',
        'Une explosion s''est produite dans la pièce où vous vous trouviez. Vous êtes gravement blessé(e).',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
      v_victimes := v_victimes || v_v.name;
    END LOOP;
    PERFORM public.annonce_publique_interne(m.country, 'EXPLOSION : ' || v_nom || ' dévasté par un attentat à l''explosif. Fermé 5 jours.'
      || CASE WHEN array_length(v_victimes, 1) > 0 THEN ' ' || array_length(v_victimes, 1) || ' blessé(s).' ELSE '' END);
    v_repere := public.crime_detecter_interne(v_moi, 'utiliser_explosifs', false);
    IF NOT v_repere THEN PERFORM public.crime_tracer_interne(v_moi, 'utiliser_explosifs', m.current_building); END IF;
  ELSE
    PERFORM public.crime_rechercher_interne(v_moi, 'utiliser_explosifs', 'crime');
    v_repere := true;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'repere', v_repere, 'victimes', to_jsonb(v_victimes),
    'taux', v_taux, 'jet', v_roll, 'inventaire', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi), 'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi), 'revision', (SELECT inventory_revision FROM public.personnages_donnees WHERE name = v_moi))
    || jsonb_build_object('paie', v_paie);
END; $function$;

-- crime_falsifier(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_falsifier(p_doc text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false; v_doc jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_doc := CASE p_doc
    WHEN 'fausse_identite' THEN '{"name":"Fausse identite","icon":"ti-id-badge","desc":"Change votre nom affiche dans le jeu temporairement."}'
    WHEN 'faux_permis' THEN '{"name":"Faux permis de construire","icon":"ti-building","desc":"Permet de construire sans passer par la mairie."}'
    WHEN 'faux_contrat' THEN '{"name":"Faux contrat commercial","icon":"ti-file-text","desc":"Legitime une transaction illegale ou un transfert."}'
    WHEN 'fausse_convocation' THEN '{"name":"Fausse convocation officielle","icon":"ti-mail","desc":"Attire un PJ dans un lieu de votre choix."}'
  END::jsonb;
  IF v_doc IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'document_inconnu'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'falsifier_document' AND pa = p_pa AND cost = p_cost) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  v_paie := public.payer_ordre(v_moi, 'falsifier_document#tentative', p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi;
  v_taux := greatest(5, 45 - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
  END IF;
  v_paie := public.payer_ordre(v_moi, 'falsifier_document#reussite', 0, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'raison', 'fonds_insuffisants') || public.crime_etat_acteur_interne(v_moi);
  END IF;
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
       || jsonb_build_array(v_doc || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
            'type', 'document_falsifie', 'docId', p_doc, 'legal', false))
   WHERE name = v_moi;
  v_repere := public.crime_detecter_interne(v_moi, 'falsifier_document', true);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'repere', v_repere, 'nom_document', v_doc ->> 'name', 'taux', v_taux, 'jet', v_roll)
    || public.crime_etat_acteur_interne(v_moi);
END; $function$;

-- crime_incendier(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_incendier(p_nom_batiment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_jours integer := 0; v_repere boolean; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, career INTO m FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_nom := left(coalesce(nullif(btrim(p_nom_batiment), ''), m.current_building), 80);
  v_paie := public.payer_ordre(v_moi, 'incendier', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, 30 + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city)
            - CASE WHEN m.current_building IN ('palais-presidentiel','palais-gouvernement','assemblee','tribunal','commissariat',
                                               'banque-nationale','banque-privee','mairie-capitale','mairie','commissariat-local','tribunal-local','banque-locale') THEN 30 ELSE 0 END);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux * 0.5 THEN v_jours := 3; ELSIF v_roll <= v_taux * 0.8 THEN v_jours := 2; ELSIF v_roll <= v_taux THEN v_jours := 1; END IF;
  IF v_jours > 0 THEN
    INSERT INTO public.batiments_fermes (pays, ville, batiment_id, duree_jours, motif, auteur, jour_fin)
    VALUES (m.country, m.current_city, m.current_building, v_jours, 'incendie', v_moi, 0);
    PERFORM public.annonce_publique_interne(m.country, 'INCENDIE : ' || v_nom || ' ravagé par les flammes. Fermé ' || v_jours || ' jour(s).');
  END IF;
  v_repere := public.crime_detecter_interne(v_moi, 'incendier', false);
  IF NOT v_repere AND v_jours > 0 THEN PERFORM public.crime_tracer_interne(v_moi, 'incendier', m.current_building); END IF;
  RETURN jsonb_build_object('ok', true, 'jours', v_jours, 'repere', v_repere, 'taux', v_taux, 'jet', v_roll) || jsonb_build_object('paie', v_paie);
END; $function$;

-- crime_malus_isn_interne(text,text) -> integer | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_malus_isn_interne(p_pays text, p_ville text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT CASE WHEN v <= 20 THEN 0 WHEN v <= 40 THEN 5 WHEN v <= 60 THEN 10 WHEN v <= 80 THEN 15 ELSE 25 END
        FROM (SELECT coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                                WHERE id = p_pays || '_' || coalesce(p_ville, 'capitale')), 30) AS v) x $function$;

-- crime_neutraliser(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_neutraliser(p_cible text, p_mode text, p_per_pnj integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; c record; v_pj boolean; v_stat text; v_base integer; v_cap integer; v_pa integer; v_sous text[];
  v_per numeric; v_paie jsonb; v_dis numeric; v_taux integer; v_roll integer; v_palier text; v_pv integer; v_reussi boolean;
  v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  CASE p_mode
    WHEN 'mains' THEN v_stat := 'FOR'; v_base := 15; v_cap := 65; v_pa := 2; v_sous := NULL;
    WHEN 'arme'  THEN v_stat := 'DUP'; v_base := 25; v_cap := 75; v_pa := 2; v_sous := ARRAY['blanche'];
    WHEN 'feu'   THEN v_stat := 'PER'; v_base := 35; v_cap := 85; v_pa := 3; v_sous := ARRAY['poing', 'carabine'];
    ELSE RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END CASE;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT name, country, current_city, current_building, current_room, hp INTO c FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  v_pj := FOUND;
  IF v_pj THEN
    IF c.country IS DISTINCT FROM m.country OR c.current_city IS DISTINCT FROM m.current_city
       OR c.current_building IS DISTINCT FROM m.current_building OR c.current_room IS DISTINCT FROM m.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
    v_per := 10;
  ELSE
    v_per := greatest(0, least(20, coalesce(p_per_pnj, 10)));
  END IF;
  IF v_sous IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) i
        WHERE i ->> 'type' = 'arme' AND i ->> 'sousType' = ANY (v_sous)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'arme_manquante'); END IF;

  v_paie := public.payer_ordre(v_moi, 'neutraliser_' || p_mode, v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_dis := coalesce(CASE WHEN jsonb_typeof(m.resources -> 'dis') = 'number' THEN (m.resources ->> 'dis')::numeric END, 50);
  IF p_mode = 'feu' THEN
    v_dis := greatest(0, v_dis - 20);
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}', to_jsonb(v_dis))
     WHERE name = v_moi;
  END IF;
  v_taux := greatest(0, least(v_cap, round(v_base + 2 * coalesce((m.stats ->> v_stat)::numeric, 8)
              + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - v_per / 2)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux / 2.0 THEN v_palier := 'totale'; v_pv := 0; v_reussi := true;
  ELSIF v_roll <= v_taux THEN v_palier := 'partielle'; v_pv := 25; v_reussi := true;
  ELSIF v_roll <= v_taux + (100 - v_taux) / 2.0 THEN v_palier := 'echec_partiel'; v_pv := 50; v_reussi := false;
  ELSE v_palier := 'echec_total'; v_pv := NULL; v_reussi := false; END IF;

  IF v_pj AND v_pv IS NOT NULL THEN
    UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), v_pv) WHERE name = p_cible;
    INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite)
    VALUES ('agression-' || gen_random_uuid(), p_cible, 'hp_set', least(coalesce(c.hp, 100), v_pv), v_palier, false);
    PERFORM public.mail_systeme_poser_interne('Événement', p_cible, 'Agression',
      'Vous avez été agressé(e). ' || CASE WHEN v_pv = 0 THEN 'Vous êtes hors de combat.' ELSE 'Vous êtes blessé(e).' END,
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  END IF;
  IF v_reussi THEN
    PERFORM public.crime_tracer_interne(v_moi, 'assassinat', p_cible);
    v_repere := public.crime_detecter_interne(v_moi, 'assassiner_' || p_mode, true);
  ELSE
    PERFORM public.crime_rechercher_interne(v_moi, 'tentative_assassinat', 'crime');
    v_repere := true;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'palier', v_palier, 'taux', v_taux, 'jet', v_roll,
    'repere', v_repere, 'dis', v_dis, 'cible_pj', v_pj) || jsonb_build_object('paie', v_paie);
END; $function$;

-- crime_peine_interne(text,boolean) -> TABLE(jours integer, amende integer) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_peine_interne(p_acte text, p_demasque boolean)
 RETURNS TABLE(jours integer, amende integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT (coalesce(a.peine_jours, CASE a.type WHEN 'delit_grave' THEN 4 WHEN 'crime' THEN 8 WHEN 'crime_etat' THEN 30 ELSE 2 END)
               * CASE WHEN p_demasque AND a.peine_jours IS NOT NULL THEN 2 ELSE 1 END)::integer,
              (coalesce(a.amende, CASE a.type WHEN 'delit_grave' THEN 1500 WHEN 'crime' THEN 5000 WHEN 'crime_etat' THEN 0 ELSE 500 END)
               * CASE WHEN p_demasque AND a.peine_jours IS NOT NULL THEN 2 ELSE 1 END)::integer
        FROM (SELECT * FROM public.actes_illegaux WHERE fn = p_acte
              UNION ALL SELECT p_acte, 'delit_mineur', 25, NULL, NULL, false, now()
              WHERE NOT EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = p_acte)) a LIMIT 1 $function$;

-- crime_rechercher_interne(text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_rechercher_interne(p_nom text, p_acte text, p_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees
     SET recherche = (CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END)
                     || jsonb_build_array(jsonb_build_object('acte', p_acte, 'type', p_type, 'jour', coalesce(day, 1), 'country', country))
   WHERE name = p_nom;
  PERFORM set_config('rp.recherche_interne', '', true);
END; $function$;

-- crime_trace_rumeur_interne(text,text,text) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_trace_rumeur_interne(p_auteur text, p_type text, p_cible text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
      SELECT 'action-' || replace(gen_random_uuid()::text, '-', ''), name, p_cible, p_type, country, current_city,
             coalesce(day, 1), coalesce(day, 1) + 7
        FROM public.personnages_donnees WHERE name = p_auteur $function$;

-- crime_tracer_interne(text,text,text) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_tracer_interne(p_nom text, p_acte text, p_cible text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ UPDATE public.personnages_donnees
         SET historique_crimes = (CASE WHEN jsonb_typeof(historique_crimes) = 'array' THEN historique_crimes ELSE '[]'::jsonb END)
           || jsonb_build_array(jsonb_build_object('id', 'crime-' || replace(gen_random_uuid()::text, '-', ''),
                'acte', p_acte, 'cible', p_cible, 'jour', coalesce(day, 1), 'expireJour', coalesce(day, 1) + 8,
                'origine', 'serveur',
                'expireTs', to_char((now() + interval '8 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
       WHERE name = p_nom $function$;

-- crime_voler(text,text,boolean,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_voler(p_cible text, p_genre text, p_benediction boolean DEFAULT false, p_per_pnj integer DEFAULT 9, p_int_pnj integer DEFAULT 9)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; c record; v_pj boolean; v_paie jsonb; v_isn numeric; v_jet integer; v_per integer; v_int integer;
  v_genre text; v_butin text := 'rien'; v_montant integer := 0; v_objet jsonb; v_vol_type text; v_vol_obj text;
  v_desc text; v_msg text := NULL; v_perte integer; v_jour integer; v_quand text;
  v_pos integer; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_genre := CASE WHEN p_genre = 'objet' THEN 'objet' ELSE 'argent' END;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT name, country, current_city, current_building, current_room, arg, inventory, stats INTO c
    FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  v_pj := FOUND;
  IF v_pj THEN
    IF c.country IS DISTINCT FROM m.country OR c.current_city IS DISTINCT FROM m.current_city
       OR c.current_building IS DISTINCT FROM m.current_building OR c.current_room IS DISTINCT FROM m.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
    v_per := coalesce((c.stats ->> 'PER')::numeric, 9)::integer; v_int := coalesce((c.stats ->> 'INT')::numeric, 9)::integer;
  ELSE
    v_per := greatest(0, least(20, coalesce(p_per_pnj, 9))); v_int := greatest(0, least(20, coalesce(p_int_pnj, 9)));
  END IF;
  v_paie := public.payer_ordre(v_moi, 'voler', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT arg, resources INTO m.arg, m.resources FROM public.personnages_donnees WHERE name = v_moi;
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                      WHERE id = m.country || '_' || coalesce(m.current_city, 'capitale')), 30);
  v_jet := greatest(0, least(100, round(50 + coalesce((m.stats ->> 'PER')::numeric, 8) + coalesce((m.stats ->> 'CHA')::numeric, 8)
             - (v_per + v_int)
             + CASE m.career WHEN 'criminal_c' THEN 15 WHEN 'intel' THEN 15 WHEN 'escort' THEN 15
                             WHEN 'magistrat' THEN -10 WHEN 'officer' THEN -10 WHEN 'clergy' THEN -10 WHEN 'doctor' THEN -10 ELSE 0 END
             - v_isn / 3 + CASE WHEN p_benediction THEN 5 ELSE 0 END + (random() * 50 - 25))::integer));
  v_jour := coalesce(m.day, 1);
  v_quand := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');

  IF v_jet < 25 THEN
    -- Sanction de l'empire (CONSEQUENCES_VOL_ECHEC).
    IF m.country = 'narco' THEN
      v_perte := floor(coalesce(m.arg, 0) * 0.5)::integer;
      UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_perte) WHERE name = v_moi;
      v_msg := 'Deux messieurs interviennent sans discussion. Vous perdez ' || v_perte || ' liquide. "La prochaine fois, on sera moins gentils."';
    ELSIF m.country = 'soviet' THEN
      UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
                           to_jsonb(greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 0) - 10)))
       WHERE name = v_moi;
      PERFORM public.sanction_financiere_imposer_interne('vol-echec-' || v_moi || '-' || txid_current(), 'vol_echec', m.country, v_moi, 100, 'tresor');
      v_msg := 'Le collectif vous denonce publiquement. -10 POP, -100 FR (amende symbolique).';
    ELSIF m.country = 'khalija' THEN
      PERFORM public.crime_tracer_interne(v_moi, 'vol', p_cible);
      UPDATE public.personnages_donnees
         SET historique_crimes = jsonb_set(historique_crimes, ARRAY[(jsonb_array_length(historique_crimes) - 1)::text],
               (historique_crimes -> (jsonb_array_length(historique_crimes) - 1))
               || jsonb_build_object('expireJour', v_jour + 15,
                    'expireTs', to_char((now() + interval '15 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
       WHERE name = v_moi;
      v_msg := 'Sanction par decret. Affaire consignee pour 15 jours — la memoire du Sheikh est longue.';
    ELSE
      PERFORM public.sanction_financiere_imposer_interne('vol-echec-' || v_moi || '-' || txid_current(), 'vol_echec', m.country, v_moi, 300, 'tresor');
      PERFORM public.crime_tracer_interne(v_moi, 'vol', p_cible);
      v_msg := 'Un agent vous verbalise sur-le-champ. -300 FR. Inscrit au registre administratif.';
    END IF;
    RETURN jsonb_build_object('ok', true, 'issue', 'echec', 'jet', v_jet, 'message', v_msg)
      || (SELECT jsonb_build_object('arg', arg, 'pop', (resources ->> 'pop')::numeric) FROM public.personnages_donnees WHERE name = v_moi)
      || jsonb_build_object('paie', v_paie);
  END IF;

  IF v_pj THEN
    -- L'argent deja vole mais pas encore retire chez la victime ne se vole pas deux fois.
    c.arg := coalesce(c.arg, 0) - coalesce((SELECT sum(montant) FROM public.vols_en_attente
                                             WHERE victime = p_cible AND type_butin = 'argent' AND traite IS NOT TRUE AND montant > 0), 0);
    IF v_genre = 'argent' AND c.arg > 0 THEN
      v_butin := 'argent';
      v_montant := least(floor(random() * 150)::integer + 50, c.arg);
      v_vol_type := 'argent'; v_vol_obj := NULL; v_desc := v_montant || ' FR';
    ELSIF v_genre = 'objet' THEN
      SELECT i INTO v_objet
        FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.inventory) = 'array' THEN c.inventory ELSE '[]'::jsonb END) i
       WHERE coalesce(i ->> 'type', '') NOT IN ('acte_officiel', 'colis_secret_pat')
         AND ((coalesce((i ->> 'stackable')::boolean, false) AND coalesce(i ->> 'stackKey', '') <> '')
              OR ((i ->> 'origine' = 'objets_trouves' OR i ->> 'type' = 'arme') AND coalesce(i ->> 'id', '') <> ''))
       ORDER BY random() LIMIT 1;
      IF v_objet IS NOT NULL THEN
        v_butin := 'objet';
        IF coalesce((v_objet ->> 'stackable')::boolean, false) AND coalesce(v_objet ->> 'stackKey', '') <> '' THEN
          v_montant := least(floor(random() * 5)::integer + 1, greatest(1, coalesce((v_objet ->> 'qty')::numeric, 1)::integer));
          v_vol_type := 'matiere'; v_vol_obj := v_objet ->> 'stackKey';
          v_desc := v_montant || 'x ' || coalesce(v_objet ->> 'name', v_objet ->> 'stackKey');
        ELSE
          v_montant := 0; v_vol_type := 'objet'; v_vol_obj := v_objet ->> 'id';
          v_desc := '"' || coalesce(v_objet ->> 'name', 'un objet') || '"';
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_butin = 'rien' THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'rien', 'jet', v_jet, 'arg', m.arg) || jsonb_build_object('paie', v_paie);
  END IF;

  -- TRANSFERT IMMEDIAT PAR LE SERVEUR (28/10/2026) : la victime perd, le voleur recoit, ici.
  IF v_butin = 'argent' THEN
    UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_montant) WHERE name = p_cible;
    UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = v_moi;
  ELSE
    SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(c.inventory) WITH ORDINALITY x(e, o)
     WHERE CASE WHEN v_vol_type = 'matiere' THEN coalesce((e ->> 'stackable')::boolean, false) AND e ->> 'stackKey' = v_vol_obj
                ELSE e ->> 'id' = v_vol_obj END ORDER BY o LIMIT 1;
    IF v_pos IS NULL THEN
      RETURN jsonb_build_object('ok', true, 'issue', 'rien', 'jet', v_jet, 'arg', m.arg) || jsonb_build_object('paie', v_paie);
    END IF;
    IF v_vol_type = 'matiere' THEN
      v_montant := least(v_montant, greatest(0, floor(coalesce((c.inventory -> v_pos ->> 'qty')::numeric, 1)))::integer);
      UPDATE public.personnages_donnees
         SET inventory = CASE WHEN coalesce((inventory -> v_pos ->> 'qty')::numeric, 1) - v_montant <= 0 THEN inventory - v_pos
                              ELSE jsonb_set(inventory, ARRAY[v_pos::text, 'qty'], to_jsonb(coalesce((inventory -> v_pos ->> 'qty')::numeric, 1) - v_montant)) END
       WHERE name = p_cible;
      v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('name', coalesce(v_objet ->> 'name', v_vol_obj), 'icon', v_objet -> 'icon',
                 'stackable', true, 'stackKey', v_vol_obj, 'qty', v_montant), true);
    ELSE
      UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = p_cible;
      v_dep := public.inventaire_deposer_interne(v_moi, c.inventory -> v_pos, true);
    END IF;
    IF (v_dep ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'crime_voler: depot refuse %', v_dep; END IF;
  END IF;
  INSERT INTO public.vols_en_attente (id, victime, voleur, type_butin, montant, objet_id, traite)
  VALUES ('vol-' || replace(gen_random_uuid()::text, '-', ''), p_cible, v_moi, v_vol_type, v_montant, v_vol_obj, true);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'vol', p_cible);
  IF v_jet < 50 THEN
    PERFORM public.mail_systeme_poser_interne('Système', p_cible, 'Vous avez été volé(e)',
      v_moi || ' vous a dérobé ' || v_desc || '. Vous l''avez reconnu(e) sur le fait.', v_quand);
  ELSIF v_jet < 75 THEN
    PERFORM public.mail_systeme_poser_interne('Système', p_cible, 'Vous avez été volé(e)',
      'Quelqu''un vous a discrètement dérobé ' || v_desc || '. Vous n''avez pas pu identifier l''auteur.', v_quand);
  END IF;
  RETURN jsonb_build_object('ok', true, 'issue', 'reussite', 'butin', v_butin, 'description', v_desc, 'montant', v_montant,
    'jet', v_jet, 'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi)) || jsonb_build_object('paie', v_paie)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'livre', true) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- crime_voler_materiaux(text,text,integer,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.crime_voler_materiaux(p_terrain text, p_matiere text, p_pa integer, p_cost integer, p_benediction boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v_paie jsonb; v_lu jsonb; v_etat jsonb; v_ch jsonb; v_stock jsonb;
  v_isn numeric; v_rep integer; v_bonus numeric; v_vig integer; v_score integer; v_jour integer; v_plafond integer;
  v_dispo integer; v_q integer; v_dep jsonb; v_final jsonb; v_ville text; v_repere boolean := false;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_matiere IS NULL OR p_matiere NOT IN ('bois', 'minerai', 'metal') THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_inconnue'); END IF;
  IF p_terrain IS NULL OR a.current_building IS DISTINCT FROM p_terrain THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_lu := public.terrain_etat_verrouiller_interne(p_terrain);
  IF (v_lu ->> 'gele')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele'); END IF;
  v_etat := v_lu -> 'etat'; v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent'); END IF;
  v_stock := CASE WHEN jsonb_typeof(v_ch -> 'stockMateriaux') = 'object' THEN v_ch -> 'stockMateriaux' ELSE '{}'::jsonb END;
  v_dispo := greatest(0, floor(coalesce(CASE WHEN jsonb_typeof(v_stock -> p_matiere) = 'number' THEN (v_stock ->> p_matiere)::numeric END, 0)))::integer;
  IF v_dispo <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_vide'); END IF;
  IF public.inventaire_place_restante(a.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(a.name, 'voler_materiel_chantier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_ville := coalesce(a.current_city, 'capitale');
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes WHERE id = a.country || '_' || v_ville), 30);
  v_rep := coalesce(a.reputation_criminelle, 0);
  v_bonus := (coalesce((a.stats ->> 'DUP')::numeric, 8) - 10) * 2 - (v_isn - 45) / 3
             + CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END
             + CASE WHEN p_benediction THEN 5 ELSE 0 END;
  v_vig := CASE WHEN jsonb_typeof(v_ch -> 'vigiles') = 'array' THEN jsonb_array_length(v_ch -> 'vigiles')
                ELSE greatest(0, floor(coalesce(CASE WHEN jsonb_typeof(v_ch -> 'vigiles') = 'number' THEN (v_ch ->> 'vigiles')::numeric END, 0)))::integer END;
  v_score := greatest(0, least(100, round(50 + v_bonus - CASE WHEN v_vig <= 0 THEN 0 ELSE 20 + (v_vig - 1) * 10 END
                                          + (floor(random() * 100) + 1 - 50))))::integer;

  IF v_score >= 50 THEN
    v_jour := floor(greatest(0, coalesce((v_ch ->> 'progressionJours')::numeric, 0)))::integer + 1;
    v_plafond := CASE p_matiere WHEN 'bois' THEN 20 WHEN 'minerai' THEN 10 ELSE (ARRAY[6, 7, 7])[((v_jour - 1) % 3) + 1] END;
    v_q := least(v_plafond, v_dispo, greatest(1, round((v_score - 50)::numeric / 50 * v_plafond)::integer));
    v_q := least(v_q, public.inventaire_place_restante(a.inventory));
    v_dep := public.inventaire_deposer_interne(a.name, jsonb_build_object(
      'name', CASE p_matiere WHEN 'bois' THEN 'Bois' WHEN 'minerai' THEN 'Minerai' ELSE 'Métal' END,
      'icon', CASE p_matiere WHEN 'bois' THEN 'ti-trees' WHEN 'minerai' THEN 'ti-mountain' ELSE 'ti-bolt' END,
      'stackable', true, 'stackKey', p_matiere, 'qty', v_q, 'desc', 'Dérobé sur un chantier.'));
    IF (v_dep ->> 'ok')::boolean IS DISTINCT FROM true OR (v_dep ->> 'qte')::integer <> v_q THEN RAISE EXCEPTION 'vol materiaux: depot incomplet'; END IF;
    v_ch := v_ch || jsonb_build_object('stockMateriaux', v_stock || jsonb_build_object(p_matiere, v_dispo - v_q))
                 || jsonb_build_object('evenements', coalesce(v_ch -> 'evenements', '[]'::jsonb)
                      || jsonb_build_array(jsonb_build_object('cle', 'vol_materiaux', 'jour', coalesce(a.day, 1), 'matiere', p_matiere, 'quantite', v_q)));
    v_final := public.terrain_etat_fusionner_interne(p_terrain, jsonb_build_object('chantier', v_ch), a.country);
    UPDATE public.indices_villes
       SET data = jsonb_set(data, '{social}', to_jsonb(greatest(0, least(100,
                    coalesce(CASE WHEN jsonb_typeof(data -> 'social') = 'number' THEN (data ->> 'social')::numeric END, 50) - 1))))
     WHERE id = a.country || '_' || v_ville;
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
    VALUES ('vol-chantier-' || gen_random_uuid(), a.name, v_etat ->> 'proprietaire', 'vol_materiel_chantier', a.country, v_ville,
            coalesce(a.day, 1), coalesce(a.day, 1) + 15);
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'score', v_score, 'matiere', p_matiere, 'quantite', v_q, 'etat', v_final)
      || (v_dep - 'ok' - 'qte') || jsonb_build_object('pa', v_paie -> 'pa');
  END IF;
  IF v_score < 20 THEN
    PERFORM public.crime_rechercher_interne(a.name, 'vol_materiel_chantier', 'delit_mineur');
    v_repere := true;
  ELSE
    -- Echec discret : la tentative reste tracable sur enquete, comme a l'ecran.
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
    VALUES ('voltentative-' || gen_random_uuid(), a.name, v_etat ->> 'proprietaire', 'tentative_vol_materiel_chantier', a.country, v_ville,
            coalesce(a.day, 1), coalesce(a.day, 1) + 15);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'detecte', v_repere, 'score', v_score, 'pa', v_paie -> 'pa')
    || (SELECT jsonb_build_object('recherche', recherche) FROM public.personnages_donnees WHERE name = a.name);
END; $function$;

-- defense_avocat_de(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_avocat_de(p_affaire_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT d.avocat FROM public.defenses_demandes d
   WHERE d.affaire = p_affaire_id AND d.etat = 'acceptee' LIMIT 1;
$function$;

-- defense_demander(text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_demander(p_affaire_id text, p_avocats text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_pays text; v_av text;
  v_envoyees text[] := '{}'; v_refusees jsonb := '[]'::jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_avocats IS NULL OR array_length(p_avocats, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_avocat_designe'); END IF;

  SELECT p.data, p.country INTO v_brut, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;

  -- ON NE CONSTITUE SA DEFENSE QUE QUAND ON EST POURSUIVI. Avant les poursuites il n'y a pas
  -- encore d'accusation a defendre, et le dossier n'existe pas comme tel.
  IF coalesce(v_a ->> 'status', '') NOT IN ('poursuites', 'saisie', 'abandon_demande') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poursuites_non_engagees',
                              'statut', v_a ->> 'status'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;
  IF public.defense_avocat_de(p_affaire_id) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'avocat_deja_retenu',
                              'avocat', public.defense_avocat_de(p_affaire_id)); END IF;

  FOREACH v_av IN ARRAY p_avocats LOOP
    v_av := nullif(btrim(coalesce(v_av, '')), '');
    CONTINUE WHEN v_av IS NULL OR v_av = v_moi;
    -- SOLLICITER, C'EST SOLLICITER UN AVOCAT INSCRIT : qualifie, et ayant publie sa tarification.
    IF NOT EXISTS (SELECT 1 FROM public.avocats_barreau b
                    WHERE b.nom = v_av AND b.pays = v_pays AND public.avocat_est_qualifie(b.nom)) THEN
      v_refusees := v_refusees || jsonb_build_object('avocat', v_av, 'raison', 'avocat_non_inscrit');
      CONTINUE;
    END IF;
    BEGIN
      INSERT INTO public.defenses_demandes (affaire, pays, prevenu, avocat)
      VALUES (p_affaire_id, v_pays, v_moi, v_av);
      v_envoyees := v_envoyees || v_av;
    EXCEPTION WHEN unique_violation THEN
      -- L'INDEX PARTIEL A PARLE : une demande est deja en attente pour ce couple. Ce n'est pas
      -- une erreur, c'est un doublon, et on le dit.
      v_refusees := v_refusees || jsonb_build_object('avocat', v_av, 'raison', 'demande_deja_en_attente');
    END;
  END LOOP;

  RETURN jsonb_build_object('ok', array_length(v_envoyees, 1) IS NOT NULL,
    'raison', CASE WHEN array_length(v_envoyees, 1) IS NULL THEN 'aucune_demande_envoyee' END,
    'affaire', p_affaire_id, 'envoyees', to_jsonb(v_envoyees), 'ecartees', v_refusees);
END $function$;

-- defense_mes_demandes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_mes_demandes()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  RETURN jsonb_build_object('ok', true, 'avocat', v_moi,
    'qualifie', public.avocat_est_qualifie(v_moi),
    -- AVANT ACCEPTATION, RIEN DU DOSSIER. Le nom du prevenu, la ville et la date : de quoi
    -- decider d'accepter, pas de quoi plaider.
    'demandes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', d.rang, 'affaire', d.affaire, 'prevenu', d.prevenu,
                   'ville', p.city, 'demande_le', d.demande_le) ORDER BY d.rang DESC), '[]'::jsonb)
                  FROM public.defenses_demandes d
                  LEFT JOIN public.plaintes_en_cours p ON p.id = d.affaire
                 WHERE d.avocat = v_moi AND d.etat = 'en_attente'),
    'defenses', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'affaire', d.affaire, 'prevenu', d.prevenu, 'ville', p.city,
                   'site', (SELECT g.batiment FROM public.justice_greffe_competent(p.country, p.city) g),
                   'piece', (SELECT g.piece FROM public.justice_greffe_competent(p.country, p.city) g),
                   'audience_ouverte', public.affaire_audience_ouverte(
                      CASE WHEN left(btrim(coalesce(p.data, '')), 1) = '{'
                           THEN p.data::jsonb ELSE '{}'::jsonb END)
                   ) ORDER BY d.rang DESC), '[]'::jsonb)
                  FROM public.defenses_demandes d
                  JOIN public.plaintes_en_cours p ON p.id = d.affaire
                 WHERE d.avocat = v_moi AND d.etat = 'acceptee'));
END $function$;

-- defense_repondre(bigint,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_repondre(p_rang bigint, p_accepte boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d record; v_a jsonb; v_n integer; v_caduques integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_d FROM public.defenses_demandes WHERE rang = p_rang FOR UPDATE;
  IF v_d.rang IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_absente'); END IF;
  IF v_d.avocat IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_demande'); END IF;
  IF v_d.etat <> 'en_attente' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_close', 'etat', v_d.etat); END IF;

  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = v_d.affaire;
  IF v_a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  IF NOT coalesce(p_accepte, false) THEN
    UPDATE public.defenses_demandes SET etat = 'refusee', repondu_le = now()
     WHERE rang = p_rang AND etat = 'en_attente';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_close'); END IF;
    RETURN jsonb_build_object('ok', true, 'accepte', false, 'affaire', v_d.affaire);
  END IF;

  -- L'ACCEPTATION EST LA COURSE, ET C'EST L'INDEX QUI L'ARBITRE. Deux onglets, deux avocats, la
  -- meme milliseconde : une seule ligne peut porter `acceptee` sur cette affaire.
  BEGIN
    UPDATE public.defenses_demandes SET etat = 'acceptee', repondu_le = now()
     WHERE rang = p_rang AND etat = 'en_attente';
    GET DIAGNOSTICS v_n = ROW_COUNT;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'avocat_deja_retenu',
                              'avocat', public.defense_avocat_de(v_d.affaire));
  END;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_close'); END IF;

  -- TOUTES LES AUTRES DEMANDES DEVIENNENT CADUQUES, et ne pourront plus etre acceptees : leur
  -- etat n'est plus `en_attente`, et la porte garde dessus.
  UPDATE public.defenses_demandes SET etat = 'caduque', repondu_le = now()
   WHERE affaire = v_d.affaire AND etat = 'en_attente';
  GET DIAGNOSTICS v_caduques = ROW_COUNT;

  PERFORM public.dossier_acte_consigner(v_d.affaire, v_d.pays,
    (SELECT p.city FROM public.plaintes_en_cours p WHERE p.id = v_d.affaire),
    'defense_constituee', v_moi, 'avocat', NULL, NULL,
    jsonb_build_object('prevenu', v_d.prevenu, 'avocat', v_moi));

  RETURN jsonb_build_object('ok', true, 'accepte', true, 'affaire', v_d.affaire,
                            'prevenu', v_d.prevenu, 'demandes_caduques', v_caduques);
END $function$;

-- defense_rompre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.defense_rompre(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d record; v_a jsonb; v_ville text; v_qui text; v_etat text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_d FROM public.defenses_demandes
   WHERE affaire = p_affaire_id AND etat = 'acceptee' FOR UPDATE;
  IF v_d.rang IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_defense_constituee'); END IF;

  SELECT p.data::jsonb, p.city INTO v_a, v_ville FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  -- LE VERROU DE L'AUDIENCE. Une fois ouverte, la defense ne change plus jusqu'au jugement.
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  IF v_moi = v_d.prevenu THEN v_qui := 'prevenu'; v_etat := 'revoquee';
  ELSIF v_moi = v_d.avocat THEN v_qui := 'avocat'; v_etat := 'abandonnee';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  UPDATE public.defenses_demandes SET etat = v_etat, repondu_le = now()
   WHERE rang = v_d.rang AND etat = 'acceptee';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'defense_deja_rompue'); END IF;

  -- L'ACCES FUTUR TOMBE IMMEDIATEMENT : `defense_avocat_de` ne le nomme plus, et toutes les
  -- portes de l'avocat passent par elle. CE QU'IL A DEJA LU, IL LE SAIT -- on n'efface pas la
  -- memoire d'un joueur, et on ne tente pas de le faire.
  PERFORM public.dossier_acte_consigner(p_affaire_id, v_d.pays, v_ville,
    'defense_rompue', v_moi, CASE WHEN v_qui = 'avocat' THEN 'avocat' ELSE 'accuse' END, NULL, NULL,
    jsonb_build_object('par', v_qui, 'prevenu', v_d.prevenu, 'avocat', v_d.avocat));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'par', v_qui,
                            'etat', v_etat, 'avocat', v_d.avocat);
END $function$;

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
DECLARE
  v_moi text;
  v_peine jsonb;
  v_det record;
  v_debut_ts numeric;
  v_jours numeric;
  v_jour_debut date;
  v_jour_fin date;
  v_aujourdhui date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
  END IF;
  SELECT est_emprisonne INTO v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu');
  END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- Fail-closed si l'ancre est absente : aucune libération devinée.
  IF coalesce(v_peine->>'debutTs','') !~ '^[0-9]+(\.[0-9]+)?$'
     OR coalesce(v_peine->>'jours','') !~ '^[0-9]+(\.[0-9]+)?$' THEN
    RETURN jsonb_build_object('ok',false,'raison','ancre_calendaire_absente');
  END IF;
  v_debut_ts := (v_peine->>'debutTs')::numeric;
  v_jours := (v_peine->>'jours')::numeric;
  IF v_debut_ts <= 0 OR v_jours <= 0 OR v_jours > 36500 THEN
    RETURN jsonb_build_object('ok',false,'raison','ancre_calendaire_invalide');
  END IF;
  v_jour_debut := (to_timestamp(v_debut_ts / 1000) AT TIME ZONE 'Europe/Paris')::date;
  v_jour_fin := v_jour_debut + ceil(v_jours)::integer;
  IF v_aujourdhui < v_jour_fin THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_non_purgee',
                              'jour_fin',v_jour_fin,'aujourdhui',v_aujourdhui);
  END IF;
  RETURN public.detention_clore_interne(v_moi,'purgee')
         || jsonb_build_object('ok',true,'jour_fin',v_jour_fin);
END;
$function$;

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
  -- Asile politique (25/10/2026) : un refugie au Quartier des Ambassades n'est pas arretable.
  IF FOUND AND public.ambassade_refugie_protege(p_nom) THEN
    RETURN jsonb_build_object('ok',false,'raison','refugie_protege');
  END IF;
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

-- document_officiel_emettre(text,text,boolean,text,text,text,text,text,text,text,integer,text,text,text,jsonb,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.document_officiel_emettre(p_genre text, p_genre_apparent text, p_authentique boolean, p_pays text, p_ville text, p_sujet text, p_organisation text, p_affaire text, p_porteur text, p_demande_par text, p_jour integer, p_nom text, p_desc text, p_icone text, p_contenu jsonb, p_donnees jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_inv jsonb; v_objet jsonb; v_signataire text; v_le text;
BEGIN
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv
    FROM public.personnages_donnees WHERE name = p_porteur FOR UPDATE;
  IF v_inv IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'porteur_introuvable');
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_id := 'doc-' || replace(gen_random_uuid()::text, '-', '');
  v_signataire := public.greffe_signataire(p_pays, p_ville);
  v_le := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');

  INSERT INTO public.documents_officiels
    (id, genre, genre_apparent, authentique, pays, tribunal_ville, sujet, organisation, affaire,
     porteur, emis_par, demande_par, emis_jour, contenu, donnees)
  VALUES (v_id, p_genre, p_genre_apparent, p_authentique, p_pays, p_ville, p_sujet,
          p_organisation, p_affaire, p_porteur, coalesce(v_signataire, 'Greffe'), p_demande_par,
          p_jour, p_contenu, p_donnees);

  -- L'OBJET NE PORTE NI `authentique`, NI LE GENRE REEL. Un vrai extrait et un faux extrait
  -- produisent ici exactement le meme objet : c'est la regle, et c'est pourquoi la provenance
  -- vit ailleurs. Aucun `stackKey` : un document ne s'empile pas avec un autre.
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'name',         p_nom,
    'type',         'document_officiel',
    'stackable',    false,
    'qty',          1,
    'encombrement', 1,
    'icon',         coalesce(p_icone, 'ti-file-certificate'),
    'desc',         p_desc,
    'document',     v_id,
    'genre',        p_genre_apparent,
    'pays',         p_pays,
    'tribunal',     p_ville,
    'sujet',        p_sujet,
    'organisation', p_organisation,
    'affaire',      p_affaire,
    'emis_par',     coalesce(v_signataire, 'Greffe'),
    'emis_le',      v_le,
    'emis_jour',    p_jour,
    'contenu',      p_contenu));

  UPDATE public.personnages_donnees
     SET inventory = coalesce(inventory, '[]'::jsonb) || jsonb_build_array(v_objet)
   WHERE name = p_porteur;

  RETURN jsonb_build_object('ok', true, 'document', v_id, 'porteur', p_porteur,
                            'emis_par', v_signataire, 'emis_jour', p_jour, 'objet', v_objet);
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

-- dossier_judiciaire_copie(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dossier_judiciaire_copie(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_brut text; v_a jsonb; v_ville text; v_pays text; v_quals text[];
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  v_quals := ARRAY(SELECT DISTINCT x FROM unnest(ARRAY[
      v_a ->> 'infraction_constatee', v_a ->> 'qualification_parquet',
      v_a ->> 'qualification_finale']) AS x WHERE x IS NOT NULL);

  RETURN jsonb_build_object('ok', true,
    'affaire', p_affaire_id, 'ville', v_ville, 'pays', v_pays,
    'prevenu', v_a ->> 'cible',
    'plaignant', coalesce(v_a ->> 'plaignant', v_a ->> 'auteur'),
    'motif', v_a ->> 'motif',
    'categorie_alleguee', v_a ->> 'categorie_alleguee',
    'statut', v_a ->> 'status',
    'jour_depot', v_a ->> 'jour',
    'qualification_constatee', v_a ->> 'infraction_constatee',
    'qualification_parquet', v_a ->> 'qualification_parquet',
    'qualification_finale', v_a ->> 'qualification_finale',
    'delai_jugement_jour', v_a ->> 'delai_jugement_jour',
    'audience_ouverte', public.affaire_audience_ouverte(v_a),
    'audience_jour', v_a ->> 'audience_jour',
    'audition', (SELECT jsonb_build_object(
                   'personne', a.personne, 'refus', a.refus,
                   'declaration', a.declaration, 'jour', a.jour_pv, 'fait_le', a.fait_le)
                  FROM public.dossiers_auditions a
                 WHERE a.affaire = p_affaire_id AND a.personne = (v_a ->> 'cible')
                   AND a.qualite = 'prevenu'),
    'temoins', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'temoin', c.temoin, 'cite_par', c.cite_par, 'qualite', c.cite_par_qualite,
                  'convocation', c.convocation_rang, 'echeance_jour', c.echeance_jour,
                  'etat', c.etat, 'issue', c.issue) ORDER BY c.rang), '[]'::jsonb)
                 FROM public.temoins_citations c WHERE c.affaire = p_affaire_id),
    'temoignages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                      'personne', a.personne, 'refus', a.refus, 'declaration', a.declaration,
                      'jour', a.jour_pv, 'fait_le', a.fait_le) ORDER BY a.fait_le), '[]'::jsonb)
                     FROM public.dossiers_auditions a
                    WHERE a.affaire = p_affaire_id AND a.qualite = 'temoin'),
    'preuves', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'id', t.id, 'acte', t.type_action, 'jour', t.jour, 'ville', t.city,
                  'jour_expiration', t.jour_expiration) ORDER BY t.jour, t.id), '[]'::jsonb)
                 FROM public.actions_tracables t
                WHERE t.country IS NOT DISTINCT FROM v_pays
                  AND t.auteur = (v_a ->> 'cible')
                  AND t.type_action = ANY (v_quals)),
    'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                 'acteur', x.acteur, 'poste', x.acteur_poste,
                 'qualif_avant', x.qualif_avant, 'qualif_apres', x.qualif_apres,
                 'donnees', x.donnees, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                FROM public.dossiers_judiciaires_actes x
                JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
               WHERE x.affaire = p_affaire_id));
END $function$;
