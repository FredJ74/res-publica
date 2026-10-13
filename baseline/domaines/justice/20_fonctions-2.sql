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
  IF NOT public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site, NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_requise',
                              'ville', v_ville, 'site', v_site);
  END IF;

  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom, 'pays', v_pays,
                            'ville', v_ville, 'affaire', v_a);
END $function$;

-- parquet_moi() -> TABLE(nom text, pays text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.parquet_moi()
 RETURNS TABLE(nom text, pays text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inc text; v_pays text; v_pnj text;
BEGIN
  -- CHEMIN NORMAL, INCHANGE : le PJ qui porte le poste. Il a toujours la priorite.
  RETURN QUERY
    SELECT d.name, d.country FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'procureur'
     LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- INCARNATION ADMINISTRATIVE. La titularite est REVERIFIEE ICI, et pas seulement a la porte :
  -- un PJ qui prend le poste ferme l'incarnation au moment meme de l'acte.
  v_inc := public.incarnation_courante();
  IF v_inc IS NULL THEN RETURN; END IF;
  v_pays := public.incarnation_pays();
  IF v_pays IS NULL THEN RETURN; END IF;
  v_pnj := public.admin_pnj_titulaire(v_pays, 'procureur', NULL);
  IF v_pnj IS NULL OR v_pnj IS DISTINCT FROM v_inc THEN RETURN; END IF;
  RETURN QUERY SELECT v_pnj, v_pays;
END $function$;

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

-- plainte_defendre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
  v_inf text; v_i record; v_seuil integer; v_pays text; v_ville text;
  v_av record; v_cha integer; v_preuve boolean; v_taux integer; v_jet integer;
  v_reussi boolean; v_relaxe boolean; v_b jsonb; v_juge text;
  v_jours integer; v_amende integer; v_lib text; v_peine text; v_motifs jsonb;
  v_jug text; v_n integer; v_det record; v_exec jsonb; v_executee boolean := false;
  v_statut text; v_verdict text; v_statut_relu text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

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
  v_inf := coalesce(public.infraction_canonique(v_inf), v_inf);
  SELECT i.jours_reference, i.categorie INTO v_i
    FROM public.infractions i WHERE i.id = v_inf;
  IF v_i.jours_reference IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_hors_catalogue',
                              'infraction', v_inf);
  END IF;

  -- PREMIER CRITERE : LA DUREE DE REFERENCE. Inchange.
  v_seuil := public.justice_seuil_procedure_simplifiee_jours();
  IF v_i.jours_reference > v_seuil THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_reservee_aux_peines_courtes',
                              'infraction', v_inf, 'jours_reference', v_i.jours_reference,
                              'seuil', v_seuil);
  END IF;

  -- SECOND CRITERE : LA CATEGORIE. Un crime ne passe JAMAIS par la procedure simplifiee, et une
  -- categorie ABSENTE ferme aussi la porte -- on ne peut pas affirmer qu'une infraction sans
  -- categorie n'est pas un crime. Inchange.
  IF v_i.categorie IS NULL OR v_i.categorie = 'crime' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_exclut_les_crimes',
                              'infraction', v_inf, 'categorie', v_i.categorie,
                              'jours_reference', v_i.jours_reference);
  END IF;

  -- L'AVOCAT COMMIS D'OFFICE DE LA VILLE. Sans lui, personne ne plaide.
  SELECT * INTO v_av FROM public.justice_avocat_commis(v_pays, v_ville);
  IF v_av.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_d_avocat_commis_d_office',
                              'ville', v_ville);
  END IF;

  -- LE TRIBUNAL QUI PRONONCERA.
  v_juge := public.justice_juge_titulaire(v_pays, v_ville);
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_tribunal', 'ville', v_ville);
  END IF;

  v_b := public.infraction_peine_bornes(v_inf);
  IF coalesce((v_b ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_b; END IF;
  v_lib := v_b ->> 'libelle';

  -- LE JET EST ICI, ET NULLE PART AILLEURS.
  v_cha    := public.justice_cha_personnel(v_nom);
  v_preuve := public.justice_preuve_reelle(v_pays, v_nom, v_inf);
  v_taux   := public.justice_defense_taux(v_av.cha, v_cha, v_preuve);
  v_jet    := floor(random() * 100)::integer + 1;
  v_reussi := (v_jet <= v_taux);
  v_relaxe := v_reussi
              AND (floor(random() * 100)::integer + 1) <= public.justice_defense_part_relaxe();

  IF NOT v_reussi THEN
    -- ECHEC : LA PEINE NORMALE, celle du catalogue, sans attenuation.
    v_jours  := (v_b ->> 'jours_reference')::integer;
    v_amende := (v_b ->> 'amende_reference')::integer;
  ELSIF v_relaxe THEN
    v_jours := 0; v_amende := 0;
  ELSE
    -- REUSSITE SANS RELAXE : les bornes basses du catalogue. `jours_min` porte deja le plancher
    -- carceral incompressible d'un jour ; `amende_min` n'en a aucun.
    v_jours  := (v_b ->> 'jours_min')::integer;
    v_amende := (v_b ->> 'amende_min')::integer;
  END IF;

  v_verdict := CASE WHEN v_relaxe THEN 'relaxe' ELSE 'condamnation' END;
  v_statut  := CASE WHEN v_relaxe THEN 'relaxe' ELSE 'jugee' END;
  v_peine   := CASE
    WHEN v_relaxe THEN NULL
    WHEN v_jours > 0 AND v_amende > 0 THEN
      'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
      || ' + amende de ' || v_amende || ' FR'
    WHEN v_jours > 0 THEN
      'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
    ELSE 'Amende de ' || v_amende || ' FR'
  END;

  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_lib, 'infraction', v_inf, 'jours', v_jours, 'city', v_ville,
      'source', 'procedure_simplifiee',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  -- UNE RELAXE EST UN JUGEMENT, avec `peine` NULL -- pas une peine de zero, et surtout pas un
  -- statut pose sans trace. C'est la meme forme que `justice_relaxer`.
  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_nom, v_lib, v_peine, v_juge,
          coalesce((SELECT d.day FROM public.personnages_donnees d WHERE d.name = v_juge), 1),
          v_relaxe,
          jsonb_build_object(
            'verdict', v_verdict, 'instance', 'simplifiee',
            'procedure', 'simplifiee',
            'infraction', v_inf, 'infraction_libelle', v_lib,
            'jours', v_jours, 'amende', v_amende,
            'jours_reference', (v_b ->> 'jours_reference')::integer,
            'jours_min', (v_b ->> 'jours_min')::integer,
            'amende_reference', (v_b ->> 'amende_reference')::integer,
            'amende_min', (v_b ->> 'amende_min')::integer,
            'avocat', v_av.nom, 'avocat_cha', v_av.cha,
            'prevenu_cha', v_cha, 'preuve_reelle', v_preuve,
            'taux', v_taux, 'jet', v_jet, 'reussie', v_reussi,
            'appel_exclu', true,
            'motif_allegue', v_data ->> 'motif',
            'qualification_parquet', v_data ->> 'qualification_parquet',
            'motifs', v_motifs,
            'issue_judiciaire', coalesce(v_peine, 'relaxe')))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;

  -- IMMEDIATEMENT EXECUTOIRE : la detention s'ouvre ICI, comme pour une sentence de premiere
  -- instance. Une peine deja en cours interdit d'en ouvrir une seconde -- c'est la garde de
  -- `detention_ouvrir_interne`, et on la laisse en place.
  IF v_jours > 0 THEN
    SELECT * INTO v_det FROM public.detention_active(v_nom);
    IF v_det.id IS NULL THEN
      v_exec := public.detention_ouvrir_interne(
                  v_nom, v_lib, v_jours, coalesce(v_ville, 'capitale'), v_pays,
                  v_motifs, v_juge, coalesce(v_peine, 'condamnation_executee'));
      IF coalesce((v_exec ->> 'ok')::boolean, false) THEN v_executee := true; END IF;
    END IF;
  END IF;
  UPDATE public.jugements SET executee = (v_relaxe OR v_executee) WHERE id = v_jug;

  v_maj := jsonb_build_object(
    'status', v_statut,
    'verdict', v_verdict,
    'juge', v_juge,
    'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'procedure_simplifiee', true,
    'defendue_par', v_nom,
    'defense_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'defense_issue', CASE WHEN v_relaxe THEN 'relaxe'
                          WHEN v_reussi THEN 'peine_reduite'
                          ELSE 'peine_normale' END,
    'defense_infraction', v_inf,
    'defense_avocat', v_av.nom,
    'defense_taux', v_taux,
    'defense_jet', v_jet,
    'qualification_finale', v_inf,
    'qualification_libelle', v_lib,
    'peine_jours', v_jours,
    'peine_amende', v_amende,
    'peine_libelle', v_peine,
    'detention_id', v_exec ->> 'detention_id',
    'appel_exclu', true);

  -- LE LAISSEZ-PASSER, ET IL NE DURE QUE CETTE ECRITURE. `plaintes_epingler_verdict` restaurerait
  -- `status`, `juge` et `peine` : l'accuse n'est pas une autorite judiciaire.
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours SET data = (v_data || v_maj)::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'au_parquet';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM set_config('rp.verdict_interne', '', true);
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- ET L'EFFET EST RELU EN BASE, PAS SUPPOSE. « Decide au serveur » n'est pas « applique au
  -- serveur » : trois fois en deux jours un declencheur a defait une ecriture qui se croyait faite.
  SELECT p.data::jsonb ->> 'status' INTO v_statut_relu
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_statut_relu IS DISTINCT FROM v_statut THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_non_applique',
                              'statut', v_statut_relu, 'attendu', v_statut);
  END IF;

  -- LA CHRONOLOGIE PORTE LA PLAIDOIRIE **ET** LE VERDICT, dans cet ordre.
  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'defense_simplifiee',
    v_nom, 'accuse', NULL, v_inf,
    jsonb_build_object('avocat', v_av.nom, 'avocat_cha', v_av.cha, 'prevenu_cha', v_cha,
                       'preuve_reelle', v_preuve, 'taux', v_taux, 'jet', v_jet,
                       'reussie', v_reussi, 'jours_reference', v_i.jours_reference,
                       'categorie', v_i.categorie, 'seuil', v_seuil));
  IF v_relaxe THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'relaxe',
      v_juge, 'juge', v_data ->> 'qualification_parquet', v_inf,
      jsonb_build_object('accuse', v_nom, 'procedure', 'simplifiee'));
  ELSE
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'condamnation',
      v_juge, 'juge', v_data ->> 'qualification_parquet', v_inf,
      jsonb_build_object('accuse', v_nom, 'jours', v_jours, 'amende', v_amende,
                         'jours_reference', (v_b ->> 'jours_reference')::integer,
                         'executee', v_executee, 'instance', 'simplifiee',
                         'procedure', 'simplifiee'));
  END IF;

  SELECT p.data::jsonb INTO v_data FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  RETURN jsonb_build_object('ok', true,
    'affaire', v_data, 'affaire_id', p_affaire_id,
    'infraction', v_inf, 'libelle', v_lib,
    'avocat', v_av.nom, 'avocat_cha', v_av.cha,
    'prevenu_cha', v_cha, 'preuve_reelle', v_preuve,
    'taux', v_taux, 'jet', v_jet, 'reussie', v_reussi,
    'verdict', v_verdict, 'statut', v_statut,
    'jours', v_jours, 'amende', v_amende, 'peine', v_peine,
    'jugement_id', v_jug, 'juge', v_juge, 'executee', (v_relaxe OR v_executee),
    'detention_id', v_exec ->> 'detention_id',
    'appel_exclu', true);
END $function$;

-- plainte_deposer(text,text,text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text, p_categorie text DEFAULT NULL::text, p_temoins text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_id text; v_data jsonb; v_cible text; v_cat text;
  v_pa integer; v_cost integer; v_n integer; v_paye jsonb;
  v_t text; v_r jsonb; v_cites jsonb := '[]'::jsonb; v_ecartes jsonb := '[]'::jsonb;
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

  v_cat := nullif(btrim(coalesce(p_categorie, '')), '');
  IF v_cat IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.infractions_categories c WHERE c.id = v_cat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_inconnue', 'demande', v_cat);
  END IF;

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

  SELECT count(*) INTO v_n FROM public.ordres_couts o WHERE o.fn = 'plainte_police';
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_indetermine',
                              'fn', 'plainte_police', 'declarations', v_n);
  END IF;
  SELECT o.pa, o.cost INTO v_pa, v_cost FROM public.ordres_couts o WHERE o.fn = 'plainte_police';

  v_paye := public.payer_ordre(v_nom, 'plainte_police', v_pa, v_cost);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paye ->> 'raison', 'paiement_refuse'),
                              'paiement', v_paye);
  END IF;

  v_id := 'plainte-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);

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

  -- LES TEMOINS DU PLAIGNANT, ICI ET NULLE PART AILLEURS. Meme transaction, meme porte. Un nom
  -- inconnu ou repete est ECARTE et nomme dans la reponse : il ne fait pas echouer le depot, qui
  -- est deja paye. Le prevenu lui-meme ne peut pas etre cite comme temoin.
  IF p_temoins IS NOT NULL THEN
    FOREACH v_t IN ARRAY p_temoins LOOP
      v_t := nullif(btrim(coalesce(v_t, '')), '');
      CONTINUE WHEN v_t IS NULL;
      IF v_t = v_nom OR v_t = v_cible THEN
        v_ecartes := v_ecartes || jsonb_build_object('temoin', v_t,
          'raison', CASE WHEN v_t = v_nom THEN 'pas_soi_meme'
                         ELSE 'le_prevenu_n_est_pas_temoin' END);
        CONTINUE;
      END IF;
      v_r := public.temoin_citer_interne(v_id, v_pays, v_ville, v_t, v_nom, 'plaignant', v_jour);
      IF coalesce((v_r ->> 'ok')::boolean, false) THEN
        v_cites := v_cites || jsonb_build_object('temoin', v_t,
          'echeance_jour', v_r ->> 'echeance_jour', 'commissariat', v_r ->> 'commissariat');
      ELSE
        v_ecartes := v_ecartes || jsonb_build_object('temoin', v_t, 'raison', v_r ->> 'raison');
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,
                            'statut', 'au_parquet', 'paiement', v_paye,
                            'temoins_cites', v_cites, 'temoins_ecartes', v_ecartes);
END $function$;

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

-- plaintes_temoins_sur_cloture() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.plaintes_temoins_sur_cloture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant text; v_apres text;
BEGIN
  IF NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN RETURN NULL; END IF;
  BEGIN
    v_apres := NEW.data::jsonb ->> 'status';
    v_avant := CASE WHEN OLD.data IS NOT NULL AND left(btrim(OLD.data), 1) = '{'
                    THEN OLD.data::jsonb ->> 'status' END;
  EXCEPTION WHEN OTHERS THEN RETURN NULL;
  END;
  IF v_apres IS NOT DISTINCT FROM v_avant THEN RETURN NULL; END IF;
  -- LA LISTE DES CLOTURES, ET ELLE REGARDE LE STATUT -- JAMAIS L'APPELANT. Une neuvieme porte de
  -- cloture heritera donc de cette extinction sans qu'on y pense.
  IF v_apres NOT IN ('non_lieu', 'abandonnee', 'arret', 'relaxe', 'jugee',
                     'jugee_appel', 'delai_expire') THEN RETURN NULL; END IF;
  PERFORM public.temoins_citations_eteindre_interne(NEW.id);
  RETURN NULL;
END $function$;

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
  v_det record; v_libere boolean := false; v_echeance integer; v_n integer; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

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

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_echeance := v_jour + public.justice_delai_jugement_jours();

  -- LA RACINE COMMUNE. `p_exiger_presence` vaut FALSE : le PV du prevenu n'a jamais exige sa
  -- presence au commissariat, et cette tranche ne change pas une mecanique validee. Voir
  -- l'en-tete : c'est la seule valeur a confirmer.
  v_r := public.audition_consigner_interne(p_affaire_id, v_pays, v_ville, v_moi, 'prevenu',
           p_declaration, p_refus, v_jour, false);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;

  -- LE DOSSIER PORTE DESORMAIS SON ECHEANCE, et c'est ce qui rend le delai OPPOSABLE sans
  -- qu'aucune autorite n'ait a y penser. Compare-and-swap sur le statut : une transition
  -- concurrente du parquet ne se fait pas ecraser.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'pv_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'pv_jour', v_jour,
           'pv_refus', coalesce((v_r ->> 'refus')::boolean, false),
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
    jsonb_build_object('refus', coalesce((v_r ->> 'refus')::boolean, false),
                       'declaration', v_r ->> 'declaration',
                       'jour_pv', v_jour, 'delai_jugement_jour', v_echeance,
                       'libere', v_libere));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'refus', coalesce((v_r ->> 'refus')::boolean, false),
                            'jour_pv', v_jour, 'delai_jugement_jour', v_echeance,
                            'libere', v_libere);
END $function$;

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

-- recherche_retirer_par_id(text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recherche_retirer_par_id(p_cible text, p_id text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant jsonb; v_apres jsonb;
BEGIN
  IF coalesce(btrim(coalesce(p_cible, '')), '') = ''
     OR coalesce(btrim(coalesce(p_id, '')), '') = '' THEN RETURN 0; END IF;

  SELECT CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END
    INTO v_avant FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  IF v_avant IS NULL THEN RETURN 0; END IF;

  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_apres
    FROM jsonb_array_elements(v_avant) e WHERE (e ->> 'id') IS DISTINCT FROM p_id;

  IF jsonb_array_length(v_apres) = jsonb_array_length(v_avant) THEN RETURN 0; END IF;
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees SET recherche = v_apres WHERE name = p_cible;
  PERFORM set_config('rp.recherche_interne', '', true);
  RETURN jsonb_array_length(v_avant) - jsonb_array_length(v_apres);
END $function$;

-- temoin_citer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_citer(p_affaire_id text, p_temoin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_t text;
  v_qualite text; v_p record; v_j record; v_jour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_t := nullif(btrim(coalesce(p_temoin, '')), '');
  IF v_t IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'temoin_manquant'); END IF;
  IF v_t = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_soi_meme'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF coalesce(v_a ->> 'status', '') NOT IN
     ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_close', 'statut', v_a ->> 'status'); END IF;
  IF v_t = coalesce(v_a ->> 'cible', '') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'le_prevenu_n_est_pas_temoin'); END IF;

  -- TROIS AUTORITES, ET TROIS SEULEMENT. Le plaignant n'en fait plus partie : il a cite ses
  -- temoins au depot, dans la transaction de `plainte_deposer`, et il ne recupere jamais ce
  -- droit -- ni au parquet, ni ailleurs, ni par cette porte.
  v_qualite := NULL;
  IF public.defense_avocat_de(p_affaire_id) = v_moi THEN
    IF public.affaire_audience_ouverte(v_a) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;
    v_qualite := 'avocat';
  ELSE
    SELECT * INTO v_p FROM public.parquet_moi();
    IF v_p.nom = v_moi AND v_p.pays IS NOT DISTINCT FROM v_pays THEN
      v_qualite := 'parquet';
    ELSE
      SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
      IF v_j.nom = v_moi THEN v_qualite := 'juge'; END IF;
    END IF;
  END IF;
  IF v_qualite IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  RETURN public.temoin_citer_interne(p_affaire_id, v_pays, v_ville, v_t, v_moi, v_qualite, v_jour);
END $function$;

-- temoin_citer_interne(text,text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_citer_interne(p_affaire text, p_pays text, p_ville text, p_temoin text, p_par text, p_qualite text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ech integer; v_rang bigint; v_c record;
BEGIN
  -- AUCUN FILTRE SUR LE TEMOIN AU-DELA DE SON EXISTENCE. N'importe quel PJ, de n'importe quel
  -- empire : le serveur ne sait pas ce qu'un humain a vu, et il ne doit pas en decider.
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_temoin) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'temoin_introuvable', 'temoin', p_temoin);
  END IF;

  v_ech := p_jour + public.justice_delai_convocation_temoin_jours();
  SELECT * INTO v_c FROM public.temoin_commissariat_competent(p_pays, p_ville);
  BEGIN
    INSERT INTO public.temoins_citations
      (affaire, pays, ville, temoin, cite_par, cite_par_qualite, echeance_jour)
    VALUES (p_affaire, p_pays, p_ville, p_temoin, p_par, p_qualite, v_ech)
    RETURNING rang INTO v_rang;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'temoin_deja_cite', 'temoin', p_temoin);
  END;

  PERFORM public.dossier_acte_consigner(p_affaire, p_pays, p_ville, 'temoin_cite',
    p_par, p_qualite, NULL, NULL,
    jsonb_build_object('temoin', p_temoin, 'convocation', 1, 'echeance_jour', v_ech,
                       'commissariat', v_c.batiment));

  RETURN jsonb_build_object('ok', true, 'citation', v_rang, 'affaire', p_affaire,
    'temoin', p_temoin, 'par', p_par, 'qualite', p_qualite,
    'convocation', 1, 'echeance_jour', v_ech,
    'commissariat', v_c.batiment, 'piece', v_c.piece);
END $function$;

-- temoin_commissariat_competent(text,text) -> TABLE(batiment text, piece text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_commissariat_competent(p_pays text, p_ville text)
 RETURNS TABLE(batiment text, piece text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- LA VILLE EST CELLE DU TRIBUNAL COMPETENT POUR L'AFFAIRE, pas celle du temoin : une affaire
  -- de Montrouge se depose au commissariat de Montrouge, meme si le temoin habite Luthecia.
  SELECT CASE WHEN v.est_capitale THEN 'commissariat' ELSE 'commissariat-local' END,
         CASE WHEN v.est_capitale THEN 'accueil_police' ELSE 'accueil_loc' END
    FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville;
$function$;

-- temoin_deposer(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_deposer(p_affaire_id text, p_declaration text DEFAULT NULL::text, p_refus boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_c record; v_jour integer; v_r jsonb; v_n integer;
  v_det record; v_libere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_c FROM public.temoins_citations
   WHERE affaire = p_affaire_id AND temoin = v_moi AND etat <> 'close' FOR UPDATE;
  IF v_c.rang IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_citation_vivante'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_c.pays), 1);
  -- LA RACINE COMMUNE, AVEC LA PRESENCE EXIGEE. C'est elle qui refuse la reponse vide, efface le
  -- texte d'un refus explicite, et verifie le commissariat.
  v_r := public.audition_consigner_interne(p_affaire_id, v_c.pays, v_c.ville, v_moi, 'temoin',
           p_declaration, p_refus, v_jour, true);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;

  -- L'OBLIGATION EST SATISFAITE. Compare-and-swap : deux onglets ne closent pas deux fois.
  UPDATE public.temoins_citations
     SET etat = 'close',
         issue = CASE WHEN coalesce((v_r ->> 'refus')::boolean, false) THEN 'refus' ELSE 'deposition' END,
         clos_le = now()
   WHERE rang = v_c.rang AND etat <> 'close';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'citation_deja_close'); END IF;

  -- LA RECHERCHE POUR NON-PRESENTATION DISPARAIT, ET ELLE SEULE. Les autres causes subsistent.
  PERFORM public.recherche_retirer_par_id(v_moi, 'temoin-' || v_c.rang);

  -- ET UNE DETENTION QUI N'EXISTAIT QUE POUR CETTE NON-PRESENTATION CESSE. La mesure est
  -- precise : apres retrait de l'entree, ce joueur n'est plus recherche du tout. S'il l'est
  -- encore pour autre chose, sa detention n'existait pas « que pour cela » et elle reste.
  IF NOT public.justice_est_recherche(v_moi) THEN
    SELECT * INTO v_det FROM public.detention_active(v_moi);
    IF v_det.id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.detentions d
                    WHERE d.id = v_det.id
                      AND coalesce(d.issue_judiciaire, '') = 'arrestation_sur_signalement') THEN
      PERFORM public.detention_clore_interne(v_moi, 'deposition_de_temoin_realisee', v_jour);
      v_libere := true;
    END IF;
  END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_c.pays, v_c.ville, 'temoin_deposition',
    v_moi, 'temoin', NULL, NULL,
    jsonb_build_object('refus', coalesce((v_r ->> 'refus')::boolean, false),
                       'declaration', v_r ->> 'declaration',
                       'citation', v_c.rang, 'jour', v_jour, 'libere', v_libere));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'citation', v_c.rang,
    'refus', coalesce((v_r ->> 'refus')::boolean, false), 'jour', v_jour, 'libere', v_libere);
END $function$;

-- temoin_mes_convocations() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoin_mes_convocations()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  RETURN jsonb_build_object('ok', true, 'temoin', v_moi,
    'convocations', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'citation', c.rang, 'affaire', c.affaire, 'pays', c.pays, 'ville', c.ville,
        'convocation', c.convocation_rang, 'echeance_jour', c.echeance_jour,
        'etat', c.etat,
        'jour_courant', public.jour_de_jeu_pays(c.pays),
        'site', (SELECT k.batiment FROM public.temoin_commissariat_competent(c.pays, c.ville) k),
        'piece', (SELECT k.piece FROM public.temoin_commissariat_competent(c.pays, c.ville) k),
        'sur_place', public.acteur_present_sur_site(v_moi, c.pays, c.ville,
                       (SELECT k.batiment FROM public.temoin_commissariat_competent(c.pays, c.ville) k),
                       (SELECT k.piece FROM public.temoin_commissariat_competent(c.pays, c.ville) k))
        ) ORDER BY c.rang), '[]'::jsonb)
      FROM public.temoins_citations c
     WHERE c.temoin = v_moi AND c.etat <> 'close'));
END $function$;

-- temoins_citations_eteindre_interne(text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoins_citations_eteindre_interne(p_affaire text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_c record; v_n integer := 0;
BEGIN
  FOR v_c IN SELECT * FROM public.temoins_citations
              WHERE affaire = p_affaire AND etat <> 'close' LOOP
    UPDATE public.temoins_citations
       SET etat = 'close', issue = 'affaire_close', clos_le = now()
     WHERE rang = v_c.rang AND etat <> 'close';
    IF NOT FOUND THEN CONTINUE; END IF;
    v_n := v_n + 1;
    -- ON NE RETIRE QUE L'ENTREE DE CETTE CITATION. Une autre affaire, une autre citation, une
    -- infraction : rien de tout cela n'est touche.
    PERFORM public.recherche_retirer_par_id(v_c.temoin, 'temoin-' || v_c.rang);
    PERFORM public.dossier_acte_consigner(v_c.affaire, v_c.pays, v_c.ville,
      'temoin_citation_eteinte', 'Greffe', 'serveur', NULL, NULL,
      jsonb_build_object('temoin', v_c.temoin, 'citation', v_c.rang));
  END LOOP;
  RETURN v_n;
END $function$;

-- temoins_convocations_echues() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.temoins_convocations_echues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_c record; v_jour integer; v_relances integer := 0; v_recherches integer := 0; v_ech integer;
BEGIN
  FOR v_c IN SELECT * FROM public.temoins_citations
              WHERE etat = 'convoquee' ORDER BY rang LOOP
    v_jour := coalesce(public.jour_de_jeu_pays(v_c.pays), 1);
    -- AU JOUR DE L'ECHEANCE, RIEN N'EST ECHU. Le deuxieme jour est encore a lui -- meme
    -- convention que le delai de jugement.
    CONTINUE WHEN v_jour <= v_c.echeance_jour;

    IF v_c.convocation_rang = 1 THEN
      v_ech := v_jour + public.justice_delai_convocation_temoin_jours();
      UPDATE public.temoins_citations
         SET convocation_rang = 2, echeance_jour = v_ech
       WHERE rang = v_c.rang AND etat = 'convoquee' AND convocation_rang = 1;
      IF FOUND THEN
        v_relances := v_relances + 1;
        PERFORM public.dossier_acte_consigner(v_c.affaire, v_c.pays, v_c.ville,
          'temoin_convocation_renouvelee', 'Greffe', 'serveur', NULL, NULL,
          jsonb_build_object('temoin', v_c.temoin, 'convocation', 2,
                             'echeance_jour', v_ech, 'citation', v_c.rang));
      END IF;
    ELSE
      -- SECONDE ABSENCE : LA RECHERCHE, ET RIEN D'AUTRE. Aucune autre consequence automatique --
      -- la preuve P11 le mesure sur les identifiants de code.
      UPDATE public.temoins_citations SET etat = 'recherche'
       WHERE rang = v_c.rang AND etat = 'convoquee' AND convocation_rang = 2;
      IF FOUND THEN
        v_recherches := v_recherches + 1;
        PERFORM public.recherche_inscrire(jsonb_build_object(
          'id', 'temoin-' || v_c.rang,
          'acte', 'non_presentation_temoin',
          'type', 'temoin',
          'affaire', v_c.affaire,
          'citation', v_c.rang,
          'country', v_c.pays,
          'ville', v_c.ville,
          'jour', v_jour), v_c.temoin);
        PERFORM public.dossier_acte_consigner(v_c.affaire, v_c.pays, v_c.ville,
          'temoin_recherche', 'Greffe', 'serveur', NULL, NULL,
          jsonb_build_object('temoin', v_c.temoin, 'citation', v_c.rang, 'jour', v_jour));
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'secondes_convocations', v_relances,
                            'recherches_ouvertes', v_recherches);
END $function$;
