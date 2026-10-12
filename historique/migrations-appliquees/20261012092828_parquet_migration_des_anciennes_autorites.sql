-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012092828 (UTC), nom
-- `parquet_migration_des_anciennes_autorites`.
-- Le registre passe de 673 a 674 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 d841e096ea218aa4f17f617dffc75081, 39842 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (3/7) -- LES ANCIENNES AUTORITES SONT MIGREES OU SUPPRIMEES
--
-- UNE SEULE AUTORITE PAR ETAPE, et c'est la regle qui a guide chaque suppression :
--   . `plainte_classer_ministere` est SUPPRIMEE -- le Ministre de la Justice classait lui-meme
--     n'importe quelle plainte du pays ;
--   . `plainte_traiter` perd la decision `classer` ; il ne reste au commissaire que l'ACTE
--     d'enquete, et seulement sur un dossier ou le parquet l'a ordonnee ;
--   . `plainte_deposer` n'instruit plus au depot -- c'etait le defaut le plus silencieux de
--     l'ancienne chaine : avec un commissaire PNJ, deposer une plainte ouvrait immediatement une
--     enquete et pouvait placer la personne visee en garde a vue DEUX JOURS, sans qu'aucune
--     autorite n'ait rien decide ;
--   . `justice_rendre_sentence` exige une SAISINE et le JUGE DE LA VILLE -- l'ancienne garde
--     acceptait aussi le commissaire, qui pouvait donc rendre une sentence ;
--   . `affaire_transmettre` transmet AU PARQUET et non plus au role du tribunal.
--
-- CONSEQUENCE ASSUMEE ET RAPPORTEE : tant que le parquet est tenu par un PNJ, aucune plainte ne
-- recoit de reponse automatique. C'est la doctrine du projet -- un titulaire PNJ n'agit pas -- et
-- inventer une decision automatique du parquet serait inventer du game design. Avant, la reponse
-- etait automatique ET sans auteur.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PARQUET DE REPUBLIA (3/3) -- LES ANCIENNES AUTORITES SONT MIGREES OU SUPPRIMEES
-- 12 octobre 2026
--
-- UNE SEULE AUTORITE PAR ETAPE. Cette migration enleve aux portes historiques ce que le parquet
-- reprend, et nulle part elle ne laisse les deux chaines coexister.
--
--   . `plainte_classer_ministere` : SUPPRIMEE. Le Ministre de la Justice classait lui-meme
--     n'importe quelle plainte du pays. Il nomme et revoque le Procureur -- par le systeme
--     generique des postes nommes, migration 1/3 -- et c'est desormais tout ce qu'il peut faire
--     sur une procedure. Faire pression sur le Procureur reste possible : c'est une interaction
--     humaine, pas une porte serveur.
--
--   . `plainte_traiter` : perd la decision `classer`. Le commissaire ne decide plus de
--     l'opportunite des poursuites. Il lui reste l'ACTE D'ENQUETE -- le meme qu'avant, celui qui
--     decouvre une trace et ouvre une garde a vue -- et il n'est possible que sur un dossier ou
--     le PARQUET a diligente une enquete. Le parquet ordonne, la police accomplit.
--
--   . `plainte_deposer` : n'instruit plus automatiquement au depot. C'etait le defaut le plus
--     silencieux de l'ancienne chaine : quand le commissaire de la ville etait un PNJ, le simple
--     depot d'une plainte declenchait immediatement une enquete et pouvait placer la personne
--     visee en garde a vue pour deux jours, sans qu'aucune autorite n'ait rien decide. La plainte
--     arrive maintenant AU PARQUET et y attend une decision.
--
--   . `justice_rendre_sentence` : exige une SAISINE reguliere, et le JUGE DE LA VILLE. L'ancienne
--     garde confondait juge et commissaire ; juger n'a jamais ete l'office du commissaire, et
--     avec le parquet il n'a plus rien a decider sur l'opportunite non plus.
--
--   . `affaire_transmettre` : la police transmet desormais AU PARQUET, pas directement au role du
--     tribunal. Elle ecrivait `status = 'deposee'`, ce qui plongeait l'affaire dans l'ancien
--     circuit sans passer par aucune decision du parquet.
--
-- CONSEQUENCE A ASSUMER, ET ELLE EST RAPPORTEE : tant que le parquet est tenu par un PNJ, aucune
-- plainte ne recoit de reponse automatique. C'est la doctrine du projet -- un titulaire PNJ
-- n'agit pas, les neuf deputes PNJ s'abstiennent toujours -- et inventer une decision automatique
-- du parquet serait inventer du game design. Avant, la reponse etait automatique ET sans auteur.

-- ============================================================================================
-- 1. LA PORTE DU MINISTRE DISPARAIT
-- ============================================================================================
DROP FUNCTION IF EXISTS public.plainte_classer_ministere(text);

-- ============================================================================================
-- 2. LE DEPOT DE PLAINTE -- VERS LE PARQUET, SANS INSTRUCTION AUTOMATIQUE
-- ============================================================================================
-- L'ANCIENNE SIGNATURE A DEUX PARAMETRES EST SUPPRIMEE AVANT, et c'est indispensable :
-- `CREATE OR REPLACE` avec un parametre de plus CREE une seconde fonction, et l'ancienne -- celle
-- qui envoie encore la plainte au commissaire -- resterait appelable par son nom. Piege rencontre
-- deux fois : `election_resultats_consigner` le 11 octobre, `justice_rendre_sentence` le 12.
DROP FUNCTION IF EXISTS public.plainte_deposer(text, text);

CREATE OR REPLACE FUNCTION public.plainte_deposer(
  p_cible text, p_motif text, p_categorie text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;
COMMENT ON FUNCTION public.plainte_deposer(text, text, text) IS
  'Depot d''une plainte : une DECLARATION de joueur, payee dans la meme transaction, qui arrive AU PARQUET et n''y declenche rien automatiquement. Elle n''instruit plus au depot -- c''etait le defaut le plus silencieux de l''ancienne chaine : avec un commissaire PNJ, deposer une plainte ouvrait immediatement une enquete et pouvait mettre la personne visee en garde a vue deux jours, sans qu''aucune autorite n''ait rien decide. La categorie alleguee est le premier des trois niveaux de qualification et n''engage rien.';

-- ============================================================================================
-- 3. LE COMMISSAIRE : L'ACTE D'ENQUETE, ET PLUS L'OPPORTUNITE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.plainte_traiter(p_id text, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;
COMMENT ON FUNCTION public.plainte_traiter(text, text) IS
  'L''ACTE D''ENQUETE de la police, et plus rien d''autre. La decision `classer` a disparu : l''opportunite des poursuites appartient au parquet, et un appel qui l''emploie encore est refuse explicitement (classement_reserve_au_parquet). L''enquete n''est possible que sur un dossier ou le Procureur l''a DILIGENTEE, une seule fois, et elle ne change pas le statut : la police rapporte, le parquet decide.';

-- ============================================================================================
-- 4. LA POLICE TRANSMET AU PARQUET
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.affaire_transmettre(
  p_cible text, p_motif text, p_city text, p_fait jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nom text; v_pays text; v_jour integer; v_ville text;
  v_cible text; v_motif text; v_id text; v_data jsonb; v_n integer;
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

  SELECT d.country, coalesce(d.day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees d WHERE d.name = v_nom LIMIT 1;
  v_pays := coalesce(v_pays, 'republic');

  v_id := 'affaire-' || v_pays || '-' || v_ville || '-' || v_jour || '-'
          || substr(md5(v_cible || '|' || v_motif || '|' || coalesce(p_fait ->> 'refId', '')), 1, 12);

  -- LE STATUT EST `au_parquet`, PLUS `deposee`. La police transmet au PARQUET : elle ne saisit
  -- pas le tribunal elle-meme, et elle ne decide pas des poursuites.
  v_data := jsonb_build_object('id', v_id, 'country', v_pays, 'city', v_ville,
                               'cible', v_cible, 'motif', v_motif, 'jour', v_jour,
                               'status', 'au_parquet', 'origine', 'police',
                               'transmise_par', v_nom,
                               'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
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
    v_nom, 'commissaire', NULL, NULL,
    jsonb_build_object('cible', v_cible, 'ref_type', p_fait ->> 'refType',
                       'ref_id', p_fait ->> 'refId'));
  RETURN jsonb_build_object('ok', true, 'deja_transmise', false, 'affaire', v_data, 'id', v_id);
END;
$$;
COMMENT ON FUNCTION public.affaire_transmettre(text, text, text, jsonb) IS
  'La police transmet au PARQUET un acte illegal decouvert. Le statut est `au_parquet` et plus `deposee` : elle ne saisit pas le tribunal elle-meme et ne decide pas des poursuites. L''identifiant reste derive de l''acte, donc une meme affaire transmise deux fois le meme jour est la MEME ligne.';

-- ============================================================================================
-- 5. LES DOSSIERS DU JUGE -- LECTURE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.juge_dossiers()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande')));
END;
$$;
COMMENT ON FUNCTION public.juge_dossiers() IS
  'Les dossiers REGULIEREMENT SAISIS du tribunal du juge, avec leur chronologie complete -- donc la qualification du parquet et tout ce qui a precede. Un dossier au parquet n''y figure pas : le juge ne voit que ce dont il est saisi.';

-- ============================================================================================
-- 6. LA SENTENCE EXIGE UNE SAISINE, ET LE JUGE DE LA VILLE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_rendre_sentence(
  p_affaire_id text, p_infraction text, p_genre text,
  p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_calc jsonb; v_jours integer; v_amende integer; v_libelle text; v_peine text;
  v_jug text; v_n integer; v_motifs jsonb; v_parquet text;
BEGIN
  IF coalesce(btrim(coalesce(p_affaire_id, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_invalide'); END IF;

  -- LE VERROU SUR L'AFFAIRE EST LA REVENDICATION : deux juges simultanes se serialisent ici.
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- LE JUGE DE LA VILLE. L'ancienne garde acceptait aussi le COMMISSAIRE, qui pouvait donc
  -- rendre une sentence : juger n'a jamais ete son office.
  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;

  -- ON NE JUGE QUE CE DONT ON EST SAISI. Sans saisine du parquet, il n'y a pas de proces.
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status'); END IF;

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

  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_j.nom;
  v_jour := coalesce(v_jour, 1);
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
            'verdict', 'condamnation',
            'infraction', v_calc ->> 'infraction',
            'infraction_libelle', v_libelle,
            'genre', p_genre,
            'jours', v_jours, 'amende', v_amende,
            'jours_reference', (v_calc ->> 'jours_reference')::integer,
            'jours_min', (v_calc ->> 'jours_min')::integer,
            'jours_max', (v_calc ->> 'jours_max')::integer,
            'amende_reference', (v_calc ->> 'amende_reference')::integer,
            -- LES TROIS NIVEAUX DE QUALIFICATION, COTE A COTE ET SANS QUE L'UN EFFACE L'AUTRE :
            -- la categorie alleguee par le plaignant, celle retenue par le parquet, celle du juge.
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

  -- LA REQUALIFICATION EST UN FAIT DISTINCT, consigne AVANT le verdict et seulement si elle a
  -- eu lieu. La qualification du parquet n'est pas effacee : elle reste sur le dossier.
  IF v_parquet IS NOT NULL AND (v_calc ->> 'infraction') IS DISTINCT FROM v_parquet THEN
    PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
      'requalification', v_j.nom, 'juge', v_parquet, v_calc ->> 'infraction');
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'jugee',
           'verdict', 'condamnation',
           'juge', v_j.nom,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_calc ->> 'infraction',
           'qualification_libelle', v_libelle,
           'peine_genre', p_genre,
           'peine_jours', v_jours,
           'peine_amende', v_amende,
           'peine_libelle', v_peine))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'condamnation',
    v_j.nom, 'juge', v_parquet, v_calc ->> 'infraction',
    jsonb_build_object('accuse', v_a ->> 'cible', 'genre', p_genre,
                       'jours', v_jours, 'amende', v_amende,
                       'jours_reference', (v_calc ->> 'jours_reference')::integer));

  RETURN jsonb_build_object('ok', true, 'jugement_id', v_jug, 'affaire', p_affaire_id,
    'juge', v_j.nom, 'jour', v_jour, 'jugement_cree', true,
    'infraction', v_calc ->> 'infraction', 'infraction_libelle', v_libelle,
    'qualification_parquet', v_parquet,
    'requalifiee', (v_parquet IS NOT NULL AND (v_calc ->> 'infraction') IS DISTINCT FROM v_parquet),
    'genre', p_genre, 'jours', v_jours, 'amende', v_amende, 'peine', v_peine,
    'motifs', v_motifs);
END;
$$;
COMMENT ON FUNCTION public.justice_rendre_sentence(text, text, text, integer, integer) IS
  'La condamnation. Exige une SAISINE reguliere du parquet et le JUGE DE LA VILLE -- l''ancienne garde acceptait aussi le commissaire. La peine reste calculee et bornee par justice_peine_calcul (reference +/- 50 %). Une requalification est consignee comme un FAIT DISTINCT et n''efface pas la qualification du parquet : les trois niveaux -- categorie alleguee, parquet, juge -- coexistent sur le jugement.';

-- ============================================================================================
-- 7. DROITS
-- ============================================================================================
REVOKE ALL ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_site_competent(text, text)   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_moi()                        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juge_de_la_ville(text)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_garde(text, text[])          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_dossiers()                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_enqueter(text)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_non_lieu(text, text)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_poursuivre(text, text)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_transmettre_juge(text)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parquet_abandonner(text, text)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juge_suite_apres_abandon(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juge_dossiers()                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.justice_relaxer(text, text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dossiers_actes_append_only()         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.plainte_deposer(text, text, text)    FROM PUBLIC, anon, authenticated;

-- CONSIGNER UN ACTE N'EST ACCORDE A PERSONNE D'AUTRE QUE LE SERVEUR. C'est le troisieme verrou
-- de la chronologie, apres l'absence de GRANT sur la table et le declencheur append-only : un
-- navigateur ne peut pas fabriquer un fait procedural.
GRANT EXECUTE ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_site_competent(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_garde(text, text[])        TO service_role;

-- Les cinq actes du parquet, ses deux lectures, les trois actes du juge.
GRANT EXECUTE ON FUNCTION public.parquet_moi()                        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.juge_de_la_ville(text)               TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parquet_dossiers()                   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parquet_enqueter(text)               TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parquet_non_lieu(text, text)         TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parquet_poursuivre(text, text)       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parquet_transmettre_juge(text)       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.parquet_abandonner(text, text)       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.juge_suite_apres_abandon(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.juge_dossiers()                      TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.justice_relaxer(text, text)          TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text, text, text)    TO authenticated, service_role;

-- ============================================================================================
-- 8. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text; v_args text;
BEGIN
  -- P1 : LA PORTE DU MINISTRE N'EXISTE PLUS.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_classer_ministere';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- plainte_classer_ministere survit'; END IF;

  -- P2 : UNE SEULE VERSION DE plainte_deposer, ET ELLE PORTE LA CATEGORIE ALLEGUEE. L'ancienne a
  --      deux parametres envoyait la plainte au commissaire : deux surcharges auraient laisse les
  --      deux chaines coexister. L'assertion porte sur le NOMBRE de parametres et sur la presence
  --      du troisieme -- pas sur l'egalite stricte de la signature rendue, qui inclut les NOMS
  --      des parametres et pas seulement leurs types.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_deposer';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % version(s) de plainte_deposer', v_n; END IF;
  SELECT pg_get_function_identity_arguments(p.oid), p.pronargs INTO v_args, v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_deposer';
  IF v_n <> 3 OR position('p_categorie text' IN v_args) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- signature inattendue : % (% parametres)', v_args, v_n; END IF;

  -- P3 : LE DEPOT N'INSTRUIT PLUS. Aucun appel a l'instruction automatique dans son corps.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_deposer';
  IF position('plainte_instruire_interne' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le depot instruit encore automatiquement'; END IF;
  IF position('''au_parquet''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le depot ne pose pas le statut au_parquet'; END IF;
  -- Et il paie toujours AVANT d'inserer : l'acquis du matin ne doit pas avoir ete perdu.
  IF position('v_paye := public.payer_ordre' IN v_txt)
     > position('INSERT INTO public.plaintes_en_cours' IN v_txt) THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le paiement est repasse APRES l''insertion'; END IF;

  -- P4 : LE COMMISSAIRE NE CLASSE PLUS, et le refus est nomme.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_traiter';
  IF position('classement_reserve_au_parquet' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le commissaire peut encore classer'; END IF;
  IF position('enquete_non_diligentee' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- l''enquete de police ne verifie pas l''ordre du parquet'; END IF;

  -- P5 : LA POLICE TRANSMET AU PARQUET.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'affaire_transmettre';
  IF position('''status'', ''au_parquet''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la police ne transmet pas au parquet'; END IF;

  -- P6 : LA SENTENCE EXIGE UNE SAISINE ET LE JUGE DE LA VILLE.
  --      LE TEST PORTE SUR L'APPEL, PAS SUR LE MOT. Chercher « affaire_autorite_de » nu le
  --      trouvait dans le COMMENTAIRE qui explique precisement qu'elle a ete retiree -- troisieme
  --      fois que ce piege se referme en deux jours. On cherche donc la parenthese d'appel.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'justice_rendre_sentence';
  IF position('affaire_non_saisie' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- on peut juger sans saisine'; END IF;
  IF position('public.juge_de_la_ville(' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la sentence ne passe pas par le juge de la ville'; END IF;
  IF position('affaire_autorite_de(' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la sentence appelle encore l''ancienne garde'; END IF;

  -- P7 : LES CINQ ACTES DU PARQUET PASSENT TOUS PAR LA GARDE COMMUNE -- donc aucun ne peut
  --      oublier la presence physique.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('parquet_enqueter','parquet_non_lieu','parquet_poursuivre',
                       'parquet_transmettre_juge','parquet_abandonner')
     AND position('public.parquet_garde(' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- % acte(s) du parquet sur 5 passent par la garde', v_n; END IF;

  -- P8 : LA GARDE EXIGE LA PRESENCE PHYSIQUE, et sur le site de la VILLE de l'affaire.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'parquet_garde';
  IF position('acteur_present_sur_site(' IN v_txt) = 0
     OR position('parquet_site_competent(' IN v_txt) = 0
     OR position('presence_requise' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la garde du parquet n''exige pas la presence physique'; END IF;

  -- P9 : LA CHRONOLOGIE EST APPEND-ONLY -- declencheur present sur UPDATE ET DELETE.
  SELECT count(*) INTO v_n FROM pg_trigger t
   WHERE t.tgrelid = 'public.dossiers_judiciaires_actes'::regclass AND NOT t.tgisinternal;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P9 ECHOUEE -- % declencheur(s) sur la chronologie', v_n; END IF;
  SELECT pg_get_triggerdef(t.oid, true) INTO v_txt FROM pg_trigger t
   WHERE t.tgrelid = 'public.dossiers_judiciaires_actes'::regclass AND NOT t.tgisinternal;
  IF position('UPDATE' IN v_txt) = 0 OR position('DELETE' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le declencheur ne couvre pas UPDATE et DELETE : %', v_txt; END IF;

  -- P10 : AUCUN DROIT CLIENT SUR LA CHRONOLOGIE NI SUR SES TYPES.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND grantee IN ('anon','authenticated')
     AND table_name IN ('dossiers_judiciaires_actes','dossiers_judiciaires_actes_types');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- % droit(s) client sur la chronologie', v_n; END IF;

  -- P11 : CONSIGNER UN ACTE N'EST PAS ACCORDE AU CLIENT. Troisieme verrou.
  SELECT count(*) INTO v_n FROM pg_proc p, aclexplode(p.proacl) ae
   LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'dossier_acte_consigner'
     AND coalesce(r.rolname, 'PUBLIC') IN ('anon', 'authenticated', 'PUBLIC');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- un client peut consigner un acte procedural'; END IF;

  -- P12 : LES DOUZE TYPES D'ACTES SONT DECLARES, et le type est une TABLE (pas un CHECK) pour
  --       que les couches futures s'ajoutent par une ligne.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types;
  IF v_n <> 12 THEN RAISE EXCEPTION 'P12 ECHOUEE -- % type(s) d''acte au lieu de 12', v_n; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint k
                  WHERE k.conrelid = 'public.dossiers_judiciaires_actes'::regclass
                    AND k.contype = 'f'
                    AND k.confrelid = 'public.dossiers_judiciaires_actes_types'::regclass) THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le type d''acte n''est pas une cle etrangere vers le registre';
  END IF;

  -- P13 : L'ABANDON ET LA DECISION DU JUGE SONT DEUX TYPES DISTINCTS, jamais fusionnes.
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types WHERE type = 'abandon_poursuites')
     OR NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types WHERE type = 'juge_arret_accepte')
     OR NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types WHERE type = 'juge_poursuite_maintenue') THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- les trois faits de l''abandon ne sont pas distincts';
  END IF;

  -- P14 : LA RELAXE EST UN VERDICT, pas une peine de zero : elle ecrit `peine` NULL et un
  --       `verdict` explicite.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'justice_relaxer';
  IF position('''verdict'', ''relaxe''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- la relaxe n''ecrit pas de verdict explicite'; END IF;
  IF position('v_lib, NULL,' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- la relaxe n''ecrit pas une peine NULL'; END IF;

  -- P15 : LES TROIS NIVEAUX DE QUALIFICATION SONT TOUS CONSERVES SUR LE JUGEMENT.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'justice_rendre_sentence';
  IF position('''categorie_alleguee''' IN v_txt) = 0
     OR position('''motif_allegue''' IN v_txt) = 0
     OR position('''qualification_parquet''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- les trois niveaux de qualification ne coexistent pas'; END IF;

  -- P16 : AUCUNE DES PORTES NEUVES N'EST OUVERTE A anon NI A PUBLIC.
  SELECT count(*) INTO v_n FROM pg_proc p, aclexplode(p.proacl) ae
   LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('parquet_moi','parquet_garde','parquet_dossiers','parquet_enqueter',
                       'parquet_non_lieu','parquet_poursuivre','parquet_transmettre_juge',
                       'parquet_abandonner','juge_suite_apres_abandon','juge_dossiers',
                       'justice_relaxer','juge_de_la_ville','parquet_site_competent',
                       'dossier_acte_consigner','plainte_deposer')
     AND coalesce(r.rolname, 'PUBLIC') IN ('anon', 'PUBLIC');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P16 ECHOUEE -- % droit(s) anon/PUBLIC', v_n; END IF;

  RAISE NOTICE 'LES 16 PREUVES SONT VERTES.';
END
$preuves$;
