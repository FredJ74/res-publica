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

-- police_signalement_resoudre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_signalement_resoudre(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_s record; v_c record; v_n integer; v_res jsonb;
  v_issue text; v_motifs jsonb; v_jour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_s FROM public.signalements_police WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'signalement_absent'); END IF;
  -- SEUL LE SIGNALEUR RESOUT SON APPEL. Personne d'autre n'en connait l'identifiant, mais la
  -- garde ne repose pas sur ce secret.
  IF v_s.signaleur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_signalement'); END IF;
  IF v_s.resolu_le IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolu', true, 'issue', v_s.issue); END IF;
  -- LE DELAI EST UNE CONDITION SERVEUR. Un compte a rebours trafique arrive trop tot et se fait
  -- refuser : il ne peut pas avancer l'intervention.
  IF now() < v_s.echeance THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
      'echeance', to_char(v_s.echeance AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')); END IF;

  -- LA REVALIDATION : LA CIBLE EST-ELLE ENCORE DANS EXACTEMENT CETTE PIECE ?
  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_c
    FROM public.presences pr WHERE pr.name = v_s.cible;
  v_issue := CASE
    WHEN v_c IS NOT NULL
     AND v_c.country     IS NOT DISTINCT FROM v_s.pays
     AND v_c.city        IS NOT DISTINCT FROM v_s.ville
     AND v_c.building_id IS NOT DISTINCT FROM v_s.building_id
     AND v_c.room_id     IS NOT DISTINCT FROM v_s.room_id
    THEN 'arrestation' ELSE 'cible_partie' END;

  -- COMPARE-AND-SWAP : deux onglets arrivant ensemble a l'echeance n'arretent qu'une fois.
  UPDATE public.signalements_police
     SET resolu_le = now(), issue = v_issue
   WHERE id = p_id AND resolu_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolu', true); END IF;

  IF v_issue = 'cible_partie' THEN
    -- AUCUNE POURSUITE AILLEURS, ET LE STATUT EST CONSERVE : la police s'est deplacee pour rien.
    RETURN jsonb_build_object('ok', true, 'issue', 'cible_partie', 'cible', v_s.cible,
      'arrestation', false); END IF;

  -- L'ARRESTATION PASSE PAR LA CHAINE EXISTANTE, et pour la meme duree qu'une arrestation
  -- d'urgence : un jour. Le PV d'audition est ce qui l'ouvrira ensuite.
  v_jour := coalesce(public.jour_de_jeu_pays(v_s.pays), 1);
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Interpellation sur signalement', 'jour_fait', v_jour,
    'city', v_s.ville, 'jours', 1, 'source', 'signalement_police',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
             v_s.cible, 'Interpellation sur signalement', 1, v_s.ville, v_s.pays,
             v_motifs, 'Police de ' || v_s.ville, 'arrestation_sur_signalement');
  IF coalesce((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
    -- La detention n'a pas pu s'ouvrir -- deja detenu, par exemple. Le signalement reste resolu :
    -- la police est venue, et on ne raconte pas une arrestation qui n'a pas eu lieu.
    RETURN jsonb_build_object('ok', true, 'issue', 'arrestation', 'arrestation', false,
      'cible', v_s.cible, 'raison_detention', v_res ->> 'raison'); END IF;

  RETURN jsonb_build_object('ok', true, 'issue', 'arrestation', 'arrestation', true,
    'cible', v_s.cible, 'detention_id', v_res ->> 'detention_id', 'ville', v_s.ville);
END;
$function$;

-- police_signaler(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.police_signaler(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_m record; v_c record; v_id text; v_ech timestamptz; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF p_cible = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur'); END IF;

  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi;
  -- BORNE A REPUBLIA, et c'est explicite : ailleurs, la question de l'arrestation citoyenne n'est
  -- pas tranchee, et une porte ouverte « au cas ou » serait une decision prise en passant.
  IF v_pays IS DISTINCT FROM 'republic' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'signalement_reserve_a_republia',
                              'pays', v_pays); END IF;

  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_m
    FROM public.presences pr WHERE pr.name = v_moi;
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_inconnue'); END IF;

  -- LA CIBLE DOIT ETRE DANS LA MEME PIECE AU DECLENCHEMENT. Quatre coordonnees, pas trois : un
  -- filtre sans `room_id` aurait permis de signaler quelqu'un a l'autre bout du batiment.
  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_c
    FROM public.presences pr WHERE pr.name = p_cible;
  IF v_c IS NULL
     OR v_c.country IS DISTINCT FROM v_m.country OR v_c.city IS DISTINCT FROM v_m.city
     OR v_c.building_id IS DISTINCT FROM v_m.building_id
     OR v_c.room_id IS DISTINCT FROM v_m.room_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_la_piece'); END IF;

  IF NOT public.justice_est_recherche(p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_recherchee'); END IF;

  -- RAMASSAGE DES SIGNALEMENTS OUBLIES. Un navigateur ferme avant l'echeance laisserait sa cible
  -- protegee a vie par l'index unique partiel : on clot ceux dont l'echeance est passee d'une
  -- minute, et eux seuls -- jamais un signalement encore en cours.
  UPDATE public.signalements_police
     SET resolu_le = now(), issue = 'abandonne'
   WHERE resolu_le IS NULL AND echeance < now() - interval '1 minute';

  v_ech := now() + make_interval(secs => public.police_delai_intervention_secondes());
  v_id := 'sig-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
          || substr(md5(v_moi || '|' || p_cible), 1, 6);

  BEGIN
    INSERT INTO public.signalements_police
      (id, pays, ville, building_id, room_id, signaleur, cible, echeance)
    VALUES (v_id, v_m.country, v_m.city, v_m.building_id, v_m.room_id, v_moi, p_cible, v_ech);
  EXCEPTION WHEN unique_violation THEN
    -- L'INDEX UNIQUE PARTIEL A MORDU : une intervention est deja en route sur cette personne.
    RETURN jsonb_build_object('ok', false, 'raison', 'intervention_deja_en_route');
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'cible', p_cible,
    'delai_secondes', public.police_delai_intervention_secondes(),
    'echeance', to_char(v_ech AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
END;
$function$;

-- presidence_gracier(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_gracier(p_condamne text, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_president text; v_peine jsonb; v_r jsonb;
BEGIN
  v_president := public.exiger_poste('president');
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
   WHERE name = p_condamne FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'libere', false, 'raison', 'non_detenu');
  END IF;
  v_r := public.detention_clore_interne(p_condamne, 'grace_presidentielle', p_jour);
  RETURN jsonb_build_object('ok', true, 'libere', true,
                            'president', v_president, 'condamne', p_condamne) || v_r;
END; $function$;

-- pv_audition_realiser(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pv_audition_realiser(p_affaire_id text, p_declaration text DEFAULT NULL::text, p_refus boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_decl text; v_refus boolean; v_det record; v_libere boolean := false;
  v_echeance integer; v_n integer; v_pv_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_refus := coalesce(p_refus, false);
  v_decl  := nullif(btrim(coalesce(p_declaration, '')), '');
  -- UNE REPONSE EST EXIGEE, ET LE REFUS EN EST UNE. Ce qui est refuse ici, c'est le PV VIDE :
  -- ni declaration, ni refus explicite. Le silence n'est pas une reponse procedurale, et ce
  -- n'est pas le serveur qui doit le choisir a la place du joueur.
  IF NOT v_refus AND v_decl IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_absente');
  END IF;
  -- Un refus EXPLICITE efface le texte : on n'enregistre pas deux reponses contradictoires.
  IF v_refus THEN v_decl := NULL; END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  -- L'AUDITION EST CELLE DE LA PERSONNE MISE EN CAUSE, ET D'ELLE SEULE.
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  IF coalesce(v_a ->> 'status', '') NOT IN
     ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_close',
                              'statut', v_a ->> 'status');
  END IF;
  IF EXISTS (SELECT 1 FROM public.dossiers_auditions a
              WHERE a.affaire = p_affaire_id AND a.personne = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audition_deja_realisee');
  END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_echeance := v_jour + public.justice_delai_jugement_jours();

  v_pv_id := 'pv-' || substr(md5(p_affaire_id || '|' || v_moi), 1, 16);
  INSERT INTO public.dossiers_auditions
    (id, affaire, pays, ville, personne, declaration, refus, jour_pv)
  VALUES (v_pv_id, p_affaire_id, v_pays, v_ville, v_moi, v_decl, v_refus, v_jour);

  -- LE DOSSIER PORTE DESORMAIS SON ECHEANCE, et c'est ce qui rend le delai OPPOSABLE sans
  -- qu'aucune autorite n'ait a y penser. Compare-and-swap sur le statut : une transition
  -- concurrente du parquet ne se fait pas ecraser.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'pv_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'pv_jour', v_jour,
           'pv_refus', v_refus,
           'inculpe_depuis_jour', v_jour,
           'delai_jugement_jour', v_echeance))::text
   WHERE id = p_affaire_id
     AND (data::jsonb ->> 'status') = (v_a ->> 'status');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- LA LIBERATION NE CONCERNE QUE LA DETENTION D'AVANT JUGEMENT. Une peine en cours d'execution
  -- pour une AUTRE affaire n'est pas touchee : ce PV ne purge rien.
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.detentions d
                  WHERE d.id = v_det.id
                    AND coalesce(d.issue_judiciaire, '') IN ('arrestation_urgence', 'garde_a_vue')) THEN
    PERFORM public.detention_clore_interne(v_moi, 'pv_audition_realise', v_jour);
    v_libere := true;
  END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'pv_audition',
    v_moi, NULL, NULL, NULL,
    jsonb_build_object('refus', v_refus, 'declaration', v_decl,
                       'jour_pv', v_jour, 'delai_jugement_jour', v_echeance,
                       'libere', v_libere));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'refus', v_refus,
                            'jour_pv', v_jour, 'delai_jugement_jour', v_echeance,
                            'libere', v_libere);
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

-- recherche_inscrire(jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recherche_inscrire(p_entree jsonb, p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_cible text; v_id text; v_apres jsonb; v_n integer;
BEGIN
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL THEN
    -- UN JOUEUR N'INSCRIT QUE SUR SA PROPRE FICHE. Condamner autrui est un pouvoir, et il a sa
    -- porte : justice_condamner, qui relit le poste de l'appelant.
    IF p_cible IS NOT NULL AND p_cible <> v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_fiche');
    END IF;
    v_cible := v_moi;
  ELSE
    IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_manquante');
    END IF;
    v_cible := p_cible;
  END IF;

  PERFORM set_config('rp.recherche_interne', 'on', true);

  -- IDEMPOTENCE PAR IDENTIFIANT, quand l'entree en porte un. C'est le cas du mandat d'arret des
  -- tracts calomnieux, dont le client verifiait deja l'absence avant de le refleter. Un crime
  -- ordinaire, lui, n'a pas d'identifiant : il peut etre commis deux fois, et doit s'inscrire
  -- deux fois.
  v_id := nullif(p_entree ->> 'id', '');
  IF v_id IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche)='array'
                                     THEN d.recherche ELSE '[]'::jsonb END) e
     WHERE d.name = v_cible AND e ->> 'id' = v_id;
    IF v_n > 0 THEN
      SELECT coalesce(recherche, '[]'::jsonb) INTO v_apres
        FROM public.personnages_donnees WHERE name = v_cible;
      RETURN jsonb_build_object('ok', true, 'action', 'deja_inscrite',
                                'recherche', coalesce(v_apres, '[]'::jsonb));
    END IF;
  END IF;

  -- L'AJOUT EST ATOMIQUE : aucune relecture, donc aucune fenetre de perte.
  UPDATE public.personnages_donnees
     SET recherche = (CASE WHEN jsonb_typeof(recherche) = 'array'
                           THEN recherche ELSE '[]'::jsonb END) || jsonb_build_array(p_entree)
   WHERE name = v_cible
  RETURNING recherche INTO v_apres;
  PERFORM set_config('rp.recherche_interne', '', true);   -- la portee s'arrete ici
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', 'inscrite',
                            'recherche', coalesce(v_apres, '[]'::jsonb));
END; $function$;

-- recherche_retirer(text[],text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recherche_retirer(p_actes text[], p_pays text DEFAULT NULL::text, p_cible text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_cible text; v_avant jsonb; v_apres jsonb;
BEGIN
  IF p_actes IS NULL OR array_length(p_actes, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'actes_manquants');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL THEN
    IF p_cible IS NOT NULL AND p_cible <> v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_fiche');
    END IF;
    v_cible := v_moi;
  ELSE
    IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_manquante');
    END IF;
    v_cible := p_cible;
  END IF;

  SELECT CASE WHEN jsonb_typeof(recherche)='array' THEN recherche ELSE '[]'::jsonb END
    INTO v_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_avant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  PERFORM set_config('rp.recherche_interne', 'on', true);

  -- LE FILTRE EST EXACTEMENT `estMienne` DU CLIENT : l'acte, et le pays quand l'entree en porte
  -- un. UN MOTIF N'EN EFFACE JAMAIS UN AUTRE -- ni celui d'un autre acte, ni celui d'un autre
  -- empire. C'est la regle posee le 13 septembre 2026, reprise ici sans un mot de plus.
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_apres
    FROM jsonb_array_elements(v_avant) e
   WHERE NOT ( (e ->> 'acte') = ANY (p_actes)
               AND ( p_pays IS NULL
                     OR coalesce(nullif(e ->> 'country', ''), p_pays) = p_pays ) );

  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = v_cible;
  PERFORM set_config('rp.recherche_interne', '', true);   -- la portee s'arrete ici

  RETURN jsonb_build_object('ok', true, 'action', 'retires',
    'retires', jsonb_array_length(v_avant) - jsonb_array_length(v_apres),
    'recherche', v_apres);
END; $function$;
