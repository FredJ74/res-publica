-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012205024 (UTC), nom
-- `justice_temoins_du_plaignant_au_depot_et_preuves_au_dossier`.
-- Le registre passe de 695 a 696 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 eb6650903f1b796a678fa3039f2782f3, 21250 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PLAIGNANT CITE SES TEMOINS AU DEPOT, ET NULLE PART AILLEURS
--
-- CE QUI N'ALLAIT PAS, ET C'ETAIT UNE FENETRE AU LIEU D'UN INSTANT. `temoin_citer` reconnaissait
-- le plaignant TANT QUE le dossier etait `au_parquet` -- potentiellement des jours. La regle
-- validee est autre : il cite ses temoins AU MOMENT DU DEPOT, et ne recupere jamais ce droit.
--
-- UN INSTANT NE SE GARDE PAS AVEC UN STATUT, IL SE GARDE AVEC UNE TRANSACTION. Les temoins du
-- plaignant sont desormais un PARAMETRE de `plainte_deposer`, cites dans la meme transaction que
-- la plainte. La branche `plaignant` de `temoin_citer` est SUPPRIMEE -- pas restreinte : il ne
-- reste rien a contourner. La signature de `plainte_deposer` change, donc elle est DROPPEE
-- d'abord : `CREATE OR REPLACE` a parametres differents aurait cree une SURCHARGE, et l'ancienne
-- porte -- celle qui ne sait pas citer de temoin -- serait restee vivante a cote de la neuve.
--
-- ET LE DOSSIER DE L'AVOCAT MONTRE LES ELEMENTS. Trois choses manquaient, toutes trois deja en
-- base : les TEMOINS cites, leurs DEPOSITIONS verbatim (refus compris), et les PREUVES REELLES --
-- une trace objective d'`actions_tracables`, non expiree, liant le prevenu a une qualification
-- retenue dans CE dossier. C'est exactement ce que `justice_preuve_reelle` reconnait depuis la
-- procedure simplifiee. Ni rumeur, ni commentaire, ni texte libre, ni declaration non enregistree
-- n'est promu au rang de preuve, et si la base n'en porte aucune le tableau est VIDE.
-- TOUJOURS AUCUN CASIER : ni jugements, ni autres affaires, ni avis de recherche.
--
-- PREUVES STRUCTURELLES -- 10.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PLAIGNANT CITE SES TEMOINS AU DEPOT, ET NULLE PART AILLEURS
-- 12 octobre 2026, nuit -- §A et §B du lot 1
--
-- CE QUI N'ALLAIT PAS, ET C'ETAIT UNE FENETRE AU LIEU D'UN INSTANT. `temoin_citer` reconnaissait
-- le plaignant TANT QUE le dossier etait `au_parquet` -- c'est-a-dire pendant toute la duree ou le
-- parquet n'avait pas encore bouge, soit potentiellement des jours. La regle validee est autre :
-- le plaignant cite ses temoins AU MOMENT DU DEPOT, et ne recupere jamais ce droit ensuite.
--
-- UN INSTANT NE SE GARDE PAS AVEC UN STATUT, IL SE GARDE AVEC UNE TRANSACTION. Les temoins du
-- plaignant sont desormais un PARAMETRE de `plainte_deposer` : ils sont cites dans la meme
-- transaction que la plainte, par la meme porte, et il n'existe aucune autre porte serveur par
-- laquelle un plaignant puisse en ajouter un. La branche `plaignant` de `temoin_citer` est
-- SUPPRIMEE -- pas restreinte, supprimee : il ne reste donc rien a contourner.
--
-- LA SIGNATURE DE `plainte_deposer` CHANGE, DONC ELLE EST DROPPEE D'ABORD. `CREATE OR REPLACE`
-- avec une liste de parametres differente ne remplace pas : il CREE UNE SURCHARGE, et l'ancienne
-- porte -- celle qui ne sait pas citer de temoin -- resterait vivante a cote de la neuve. Le
-- depot a trois arguments continue de fonctionner : le quatrieme a un DEFAUT.
--
-- §B -- LE DOSSIER DE L'AVOCAT MONTRE LES ELEMENTS, PAS SEULEMENT LA CHRONOLOGIE. Il manquait
-- trois choses, et toutes trois existaient deja en base sans etre exposees : les TEMOINS cites,
-- leurs DEPOSITIONS verbatim (refus compris), et les PREUVES REELLES.
--
-- CE QU'EST UNE PREUVE REELLE DANS CE DEPOT, ET CE QU'ELLE N'EST PAS. C'est une TRACE OBJECTIVE
-- d'`actions_tracables`, non expiree, qui lie le prevenu a une qualification REELLEMENT retenue
-- dans ce dossier. C'est exactement ce que `justice_preuve_reelle` reconnait depuis la procedure
-- simplifiee -- ou elle pese 35 points -- et rien d'autre n'est promu au rang de preuve : ni une
-- rumeur, ni un commentaire, ni le texte libre du plaignant, ni une declaration non enregistree.
-- Aucune preuve n'est inventee : si la base n'en porte aucune, le tableau est VIDE.
--
-- CE QUE LE DOSSIER NE DONNE TOUJOURS PAS : le casier du client, ses autres affaires, les avis de
-- recherche, les donnees de police etrangeres au dossier. Et le prevenu n'apprend rien de ce que
-- son avocat lit.
--
-- PREUVES STRUCTURELLES -- 10.

-- ============================================================================================
-- 1. LA CITATION INTERNE, PARTAGEE PAR LES DEUX PORTES
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.temoin_citer_interne(
  p_affaire text, p_pays text, p_ville text, p_temoin text,
  p_par text, p_qualite text, p_jour integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

REVOKE ALL ON FUNCTION public.temoin_citer_interne(text,text,text,text,text,text,integer)
  FROM PUBLIC, anon, authenticated;

-- ============================================================================================
-- 2. `temoin_citer` -- TROIS AUTORITES, LE PLAIGNANT N'EN EST PLUS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.temoin_citer(p_affaire_id text, p_temoin text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

-- ============================================================================================
-- 3. `plainte_deposer` -- LES TEMOINS DU PLAIGNANT SONT UN PARAMETRE DU DEPOT
-- ============================================================================================
DROP FUNCTION IF EXISTS public.plainte_deposer(text, text, text);

CREATE OR REPLACE FUNCTION public.plainte_deposer(
  p_cible text, p_motif text, p_categorie text DEFAULT NULL::text,
  p_temoins text[] DEFAULT NULL::text[])
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

GRANT EXECUTE ON FUNCTION public.plainte_deposer(text, text, text, text[]) TO authenticated;

-- ============================================================================================
-- 4. `avocat_dossier` -- LES TEMOINS, LEURS DEPOSITIONS, ET LES PREUVES REELLES
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.avocat_dossier(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

-- ============================================================================================
-- PREUVES STRUCTURELLES -- 10
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_deposer';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % signature(s) de plainte_deposer', v_n; END IF;

  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_deposer'
     AND p.pronargs = 4;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE -- la porte de depot ne prend pas de temoins'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'temoin_citer';
  IF position('''plaignant''' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le plaignant est encore une autorite de citation'; END IF;
  IF v_txt !~ 'defense_avocat_de' OR v_txt !~ 'parquet_moi' OR v_txt !~ 'juge_de_la_ville' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- les trois autorites restantes ne sont pas toutes la'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'plainte_deposer';
  IF v_txt !~ 'temoin_citer_interne' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le depot ne cite aucun temoin'; END IF;
  IF v_txt !~ 'payer_ordre' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- le depot ne se paie plus'; END IF;

  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'temoin_citer_interne'
     AND NOT EXISTS (SELECT 1 FROM aclexplode(p.proacl) ae
                      JOIN pg_roles r ON r.oid = ae.grantee
                     WHERE r.rolname IN ('anon', 'authenticated'));
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- la citation interne est appelable par un client'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'avocat_dossier';
  IF v_txt !~ 'temoins_citations' OR v_txt !~ '''temoignages''' OR v_txt !~ '''preuves''' THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- le dossier n''expose ni temoins ni depositions ni preuves'; END IF;
  IF v_txt !~ 'actions_tracables' THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- les preuves ne viennent pas de la trace objective'; END IF;

  -- LE PIEGE DU COMMENTAIRE : la mesure porte sur des IDENTIFIANTS DE CODE, jamais sur des mots
  -- de prose. `prosrc` contient les commentaires de la fonction, et ils parlent du casier.
  IF v_txt ~ 'public\.jugements|public\.casier|d\.recherche|justice_est_recherche|signalements_police' THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- le dossier de l''avocat touche au casier ou a la police'; END IF;

  RAISE NOTICE 'LES 10 PREUVES SONT VERTES.';
END $preuves$;
