-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012191634 (UTC), nom
-- `tribunal_avocat_pj_barreau_demandes_et_dossier`.
-- Le registre passe de 693 a 694 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 2ec063086dc78bc6953ca2d547d17093, 49527 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'AVOCAT PJ : LE BARREAU, LES DEMANDES, ET LE DOSSIER AU GREFFE
--
-- CE QU'ELLE CONSTRUIT -- §C a §H du cahier des charges, et le strict minimum de §O.
--
-- LE BARREAU, ET SON REGISTRE VIDE EXPRES. `justice_barreau_qualifications` dit quelles
-- qualifications universitaires ouvrent la profession. Elle est semee VIDE : l'arbitrage du
-- cursus n'est pas rendu, et la consigne interdit d'inventer un diplome. Consequence assumee :
-- `avocat_est_qualifie` rend `false` pour tout le monde en production, la fonctionnalite est donc
-- INERTE jusqu'a ce que l'arbitrage arrive -- et les trois avocats commis d'office PNJ a CHA 16
-- continuent de plaider seuls. Le jour ou la qualification sera nommee, une seule ligne l'ouvre.
--
-- LA TARIFICATION EST CE QUI MET UN AVOCAT DANS LA LISTE. `avocats_barreau` a QUATRE colonnes :
-- nom, pays, tarification, date. Il n'y a PAS de colonne de caracteristique, et c'est le moyen le
-- plus sur de ne jamais la laisser fuir : `justice_avocats_disponibles` ne peut pas montrer un
-- CHA qui n'existe pas dans la table qu'elle lit. Pas de bouton disponible/indisponible non plus :
-- publier ou retirer sa tarification EST la disponibilite.
--
-- LE PREMIER QUI ACCEPTE GAGNE, ET C'EST STRUCTUREL. Deux index uniques partiels font le travail
-- qu'une relecture ne ferait pas : un avocat retenu au plus par affaire
-- (`WHERE etat = 'acceptee'`), une demande vivante au plus par couple affaire/avocat
-- (`WHERE etat = 'en_attente'`). La concurrence ne depend d'aucun etat affiche par le client.
--
-- LE DOSSIER NE SE LIT QU'AU GREFFE COMPETENT. `avocat_dossier` exige l'acceptation ET la
-- presence physique, par `acteur_present_sur_site` -- la regle unique de localisation. Il rend le
-- dossier ENTIER (plaignant, motif, qualifications et leur evolution, chronologie, audition
-- verbatim) et RIEN d'autre : aucun casier, aucun jugement, aucune recherche, aucune trace de
-- police. Le prevenu n'est pas averti de ce que son avocat lit : l'asymetrie est voulue.
--
-- L'AUDIENCE, AU MINIMUM. Ouvrir l'audience verrouille la defense ; `audience_paroles` et
-- `audience_peut_ecrire` donnent au juge le pouvoir code de donner et retirer la parole. Le chat
-- n'est PAS de cette tranche.
--
-- PREUVES STRUCTURELLES -- 18.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'AVOCAT PJ : LE BARREAU, LES DEMANDES, ET LE DOSSIER AU GREFFE
-- 12 octobre 2026 -- §C a §H du cahier des charges, et le minimum de §O
--
-- CE QUI EXISTAIT, ET CE QUI MANQUAIT. Trois avocats commis d'office PNJ a CHA 16, et rien
-- d'autre : aucun moyen pour un joueur d'etre avocat, aucune relation entre un prevenu et un
-- defenseur, aucun acces au dossier. Les PNJ restent le FALLBACK -- ils ne disparaissent pas.
--
-- LA QUALIFICATION N'EST PAS INVENTEE, ET C'EST LE SEUL RACCORD QUI RESTE. Le catalogue
-- universitaire est VIDE par decision (socle du 12 octobre : `qualifications`,
-- `universite_cursus` et `personnages_qualifications` comptent zero ligne). `avocat_est_qualifie`
-- lit donc un REGISTRE -- `justice_barreau_qualifications` -- qui est seme VIDE, et elle est
-- FERMEE PAR DEFAUT : aucun joueur n'est avocat tant que ce registre n'a pas sa ligne. Inventer
-- un diplome ici serait decider a la place du game design ; laisser la garde absente serait
-- ouvrir le barreau a tout le monde. Le raccord est donc UNE LIGNE de registre, le jour ou la
-- qualification sera arbitree.
--
-- LA CARACTERISTIQUE DE L'AVOCAT N'EXISTE PAS DANS CE MODELE, ET C'EST LA GARANTIE LA PLUS
-- SOLIDE. Le cahier des charges interdit d'exposer cette donnee mecanique au prevenu : plutot
-- que de la filtrer a l'affichage -- ce qu'une porte voisine pourrait oublier -- la table du
-- barreau N'A PAS la colonne, et la lecture destinee au prevenu ne joint jamais
-- `personnages_donnees`. Il n'y a rien a fuiter.
--
-- LA TARIFICATION EST UN TEXTE LIBRE, ET HG N'EN FAIT RIEN. « 500 FR », « gratuit », « selon
-- affaire », « a negocier » : aucune validation economique, aucun prelevement, aucun contrat. Le
-- serveur ne lit jamais ce champ pour en tirer une consequence -- il le transporte. Le prix, la
-- faveur, la dette et la gratuite se reglent entre humains. Et c'est elle qui fait l'inscription :
-- pas de bouton Disponible/Indisponible, l'avocat disposant deja du droit de refuser une affaire.
--
-- LE PREMIER ACCEPTANT GAGNE, ET CE N'EST PAS UNE RELECTURE. Un INDEX UNIQUE PARTIEL sur
-- `(affaire) WHERE etat = 'acceptee'` rend structurellement impossible qu'une affaire ait deux
-- avocats : deux acceptations simultanees, une seule ligne possible, l'autre recoit
-- `avocat_deja_retenu`. Aucun etat affiche par un navigateur n'entre dans cette decision.
--
-- AVANT ACCEPTATION, L'AVOCAT SOLLICITE NE VOIT RIEN DU DOSSIER. `defense_mes_demandes` rend le
-- nom du prevenu, la ville et la date -- de quoi decider d'accepter, pas de quoi plaider.
--
-- LE DOSSIER SE LIT AU GREFFE DU TRIBUNAL COMPETENT, et nulle part ailleurs. Ni depuis chez lui,
-- ni depuis le Bureau des magistrats, ni depuis une autre ville : `acteur_present_sur_site` est
-- la regle unique de localisation, et c'est elle qui tranche.
--
-- ET IL N'Y A AUCUN BOUTON VERS LE CASIER. L'acces est borne au DOSSIER DE L'AFFAIRE. Si le
-- client ne parle pas de ses antecedents a son avocat, l'avocat ne les apprendra pas ici.
--
-- L'AUDIENCE OUVERTE EST POSEE ICI PARCE QUE LES VERROUS EN DEPENDENT. §F verrouille la defense
-- « des que l'audience est officiellement ouverte » : sans ce fait serveur, le verrou n'existe
-- pas. On pose donc le strict minimum -- une porte du juge, un predicat, et le droit de parole
-- d'un temoin -- pour ne pas refaire le modele a la tranche suivante. AUCUN chat, aucun tour de
-- parole automatique, aucune IA.
--
-- UNE PREUVE S'EST TROMPEE SUR ELLE-MEME, ET LA LECON EST GARDEE. P3 mesure l'absence de la
-- caracteristique mecanique dans la liste offerte au prevenu. Ecrite sur le mot nu, elle a
-- echoue sur le mot « CHAMPS » d'un de mes propres commentaires. Elle porte desormais sur le
-- LITTERAL entre apostrophes et sur les deux tables qui portent les caracteristiques : c'est le
-- meme piege du commentaire, pour la cinquieme fois en trois jours, et c'est la meme reponse --
-- mesurer une expression, jamais un mot.
--
-- PREUVES STRUCTURELLES -- 18.

-- ============================================================================================
-- 0. DEUX QUALITES DE PLUS AU REGISTRE DES ACTES
-- ============================================================================================
-- `pose_par` etait borne a six qualites, et l'avocat n'en etait pas -- il n'existait pas. Le
-- temoin est ajoute dans le meme mouvement : la tranche suivante consigne ses depositions, et
-- deux migrations pour une liste de valeurs seraient deux migrations de trop.
ALTER TABLE public.dossiers_judiciaires_actes_types
  DROP CONSTRAINT IF EXISTS dossiers_judiciaires_actes_types_pose_par_check;
ALTER TABLE public.dossiers_judiciaires_actes_types
  ADD CONSTRAINT dossiers_judiciaires_actes_types_pose_par_check
  CHECK (pose_par = ANY (ARRAY['plaignant', 'police', 'parquet', 'juge', 'accuse',
                               'avocat', 'temoin', 'serveur']));

INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
  ('defense_constituee', 'Defense constituee -- avocat retenu', 'avocat',
   'Pose par l''avocat qui accepte la defense.'),
  ('defense_rompue',     'Defense rompue -- revocation ou abandon', 'avocat',
   'Pose par celui qui rompt : l''avocat qui abandonne, ou le prevenu qui revoque. L''acte lui-meme porte son auteur reel dans `acteur` et `acteur_poste`.')
ON CONFLICT (type) DO NOTHING;

-- ============================================================================================
-- 1. L'AUDIENCE : LE MINIMUM, ET RIEN DE PLUS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.affaire_audience_ouverte(p_data jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE
AS $$ SELECT coalesce(p_data ? 'audience_ouverte_le', false); $$;
COMMENT ON FUNCTION public.affaire_audience_ouverte(jsonb) IS
  'Vrai si l''audience de cette affaire est officiellement ouverte. Seule definition de ce fait.';

CREATE OR REPLACE FUNCTION public.justice_audience_ouvrir(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_n integer; v_jour integer;
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
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'audience_ouverte_jour', v_jour,
           'audience_ouverte_par', v_j.nom))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  -- ET L'EFFET EST RELU EN BASE. Le statut n'a pas bouge, donc le declencheur de verdict ne
  -- restaure rien ; mais une ecriture qu'on ne relit pas est une ecriture qu'on suppose.
  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ouverture_non_appliquee'); END IF;

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'juge', v_j.nom, 'jour', v_jour);
END $$;
GRANT EXECUTE ON FUNCTION public.justice_audience_ouvrir(text) TO authenticated;

-- LE DROIT D'ECRIRE A L'AUDIENCE EST DONNE PAR LE JUGE, ET PAR PERSONNE D'AUTRE. La structure
-- est posee maintenant pour que la tranche de l'audience n'ait pas a refaire le modele. Rien
-- ici ne distribue la parole tout seul : aucune file, aucun tour, aucune IA.
CREATE TABLE IF NOT EXISTS public.audience_paroles (
  affaire      text        NOT NULL,
  personne     text        NOT NULL,
  accordee_le  timestamptz NOT NULL DEFAULT now(),
  accordee_par text        NOT NULL,
  retiree_le   timestamptz,
  CONSTRAINT audience_paroles_pk PRIMARY KEY (affaire, personne)
);
REVOKE ALL ON TABLE public.audience_paroles FROM anon, authenticated;
ALTER TABLE public.audience_paroles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.audience_peut_ecrire(p_affaire_id text, p_personne text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.audience_paroles a
                  WHERE a.affaire = p_affaire_id AND a.personne = p_personne
                    AND a.retiree_le IS NULL);
$$;
COMMENT ON FUNCTION public.audience_peut_ecrire(text, text) IS
  'Un temoin n''ecrit a l''audience que si le juge lui a donne la parole et ne l''a pas retiree. Seule definition de ce droit.';

CREATE OR REPLACE FUNCTION public.justice_audience_parole(p_affaire_id text, p_personne text, p_donner boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.justice_audience_parole(text, text, boolean) TO authenticated;

-- ============================================================================================
-- 2. LE BARREAU : LA QUALIFICATION, FERMEE PAR DEFAUT
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.justice_barreau_qualifications (
  qualification text NOT NULL,
  note          text,
  CONSTRAINT justice_barreau_qualifications_pk PRIMARY KEY (qualification)
);
REVOKE ALL ON TABLE public.justice_barreau_qualifications FROM anon, authenticated;
ALTER TABLE public.justice_barreau_qualifications ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.justice_barreau_qualifications IS
  'Les qualifications universitaires qui ouvrent le barreau. SEMEE VIDE EXPRES : le catalogue universitaire n''est pas arbitre, et inventer un diplome ici serait decider a la place du game design. Une ligne suffira le jour ou il le sera.';

CREATE OR REPLACE FUNCTION public.avocat_est_qualifie(p_nom text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  -- FERMEE PAR DEFAUT, ET C'EST VOULU. Le registre etant vide, cette fonction rend `false` pour
  -- tout le monde : le barreau n'existe pas encore, il n'est pas ouvert a tous.
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_qualifications q
      JOIN public.justice_barreau_qualifications b ON b.qualification = q.qualification
     WHERE q.personnage = p_nom);
$$;
COMMENT ON FUNCTION public.avocat_est_qualifie(text) IS
  'Ce joueur porte-t-il la qualification professionnelle d''avocat ? Seule definition de cette qualite. Ferme par defaut tant que justice_barreau_qualifications est vide.';

-- ============================================================================================
-- 3. LA TARIFICATION PUBLIEE : CE QUI INSCRIT UN AVOCAT A LA LISTE
-- ============================================================================================
-- QUATRE COLONNES, ET AUCUNE N'EST MECANIQUE. On ne filtre pas une donnee a l'affichage quand on
-- peut s'arranger pour qu'elle ne soit pas la.
CREATE TABLE IF NOT EXISTS public.avocats_barreau (
  nom           text        NOT NULL,
  pays          text        NOT NULL,
  tarification  text        NOT NULL,
  maj_le        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT avocats_barreau_pk PRIMARY KEY (nom),
  -- UNE TARIFICATION VIDE N'INSCRIT PERSONNE : c'est elle, et elle seule, qui fait l'inscription.
  CONSTRAINT avocats_barreau_tarification_non_vide CHECK (btrim(tarification) <> ''),
  -- Un champ libre reste un champ libre, mais pas un roman : de quoi dire un prix, une faveur ou
  -- « a negocier ».
  CONSTRAINT avocats_barreau_tarification_bornee CHECK (length(tarification) <= 200)
);
REVOKE ALL ON TABLE public.avocats_barreau FROM anon, authenticated;
ALTER TABLE public.avocats_barreau ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.avocat_publier_tarification(p_tarification text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.avocat_publier_tarification(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.avocat_retirer_tarification()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  DELETE FROM public.avocats_barreau WHERE nom = v_moi;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'retire', v_n = 1);
END $$;
GRANT EXECUTE ON FUNCTION public.avocat_retirer_tarification() TO authenticated;

CREATE OR REPLACE FUNCTION public.avocat_ma_tarification()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT jsonb_build_object('ok', true,
    'qualifie', public.avocat_est_qualifie(public.mon_personnage()),
    'tarification', (SELECT a.tarification FROM public.avocats_barreau a
                      WHERE a.nom = public.mon_personnage()));
$$;
GRANT EXECUTE ON FUNCTION public.avocat_ma_tarification() TO authenticated;

-- ============================================================================================
-- 4. LES DEMANDES DE DEFENSE
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.defenses_demandes (
  rang        bigserial   NOT NULL,
  affaire     text        NOT NULL,
  pays        text        NOT NULL,
  prevenu     text        NOT NULL,
  avocat      text        NOT NULL,
  demande_le  timestamptz NOT NULL DEFAULT now(),
  etat        text        NOT NULL DEFAULT 'en_attente',
  repondu_le  timestamptz,
  CONSTRAINT defenses_demandes_pk PRIMARY KEY (rang),
  CONSTRAINT defenses_demandes_etat CHECK (etat IN
    ('en_attente', 'acceptee', 'refusee', 'caduque', 'revoquee', 'abandonnee')),
  CONSTRAINT defenses_demandes_pas_soi_meme CHECK (prevenu <> avocat)
);
REVOKE ALL ON TABLE public.defenses_demandes FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.defenses_demandes_rang_seq FROM anon, authenticated;
ALTER TABLE public.defenses_demandes ENABLE ROW LEVEL SECURITY;

-- LE PREMIER ACCEPTANT GAGNE, ET C'EST STRUCTUREL. Deux acceptations simultanees ne peuvent pas
-- produire deux lignes `acceptee` sur la meme affaire : l'index le refuse, et la porte traduit ce
-- refus en `avocat_deja_retenu`. Aucune relecture, donc aucune fenetre.
CREATE UNIQUE INDEX IF NOT EXISTS defenses_un_avocat_retenu_par_affaire
  ON public.defenses_demandes (affaire) WHERE etat = 'acceptee';
-- ET PAS DEUX FOIS LA MEME DEMANDE EN ATTENTE. Un double clic ne remplit pas la boite.
CREATE UNIQUE INDEX IF NOT EXISTS defenses_une_demande_vivante_par_couple
  ON public.defenses_demandes (affaire, avocat) WHERE etat = 'en_attente';

-- ============================================================================================
-- 5. QUI DEFEND CETTE AFFAIRE ?
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.defense_avocat_de(p_affaire_id text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT d.avocat FROM public.defenses_demandes d
   WHERE d.affaire = p_affaire_id AND d.etat = 'acceptee' LIMIT 1;
$$;
COMMENT ON FUNCTION public.defense_avocat_de(text) IS
  'L''avocat PJ retenu pour cette affaire, ou NULL -- auquel cas le commis d''office PNJ reste le defenseur. Seule definition de cette relation.';

-- ============================================================================================
-- 6. LE GREFFE COMPETENT : UNE SEULE DEFINITION
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_greffe_competent(p_pays text, p_ville text)
RETURNS TABLE (batiment text, piece text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  -- Le BATIMENT est celui que `parquet_site_competent` designe deja -- une seule regle pour le
  -- tribunal competent. La PIECE est le greffe, et elle porte le meme nom dans les deux gabarits.
  SELECT public.parquet_site_competent(p_pays, p_ville), 'greffe'
   WHERE public.parquet_site_competent(p_pays, p_ville) IS NOT NULL;
$$;

-- ============================================================================================
-- 7. LA LISTE OFFERTE AU PREVENU
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_avocats_disponibles(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.justice_avocats_disponibles(text) TO authenticated;

-- ============================================================================================
-- 8. DEMANDER -- PLUSIEURS AVOCATS A LA FOIS, ET AUTANT DE FOIS QU'IL VEUT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.defense_demander(p_affaire_id text, p_avocats text[])
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.defense_demander(text, text[]) TO authenticated;

-- ============================================================================================
-- 9. CE QUE L'AVOCAT SOLLICITE VOIT -- ET CE QU'IL NE VOIT PAS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.defense_mes_demandes()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.defense_mes_demandes() TO authenticated;

-- ============================================================================================
-- 10. ACCEPTER OU REFUSER -- ET L'ATOMICITE DU PREMIER ACCEPTANT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.defense_repondre(p_rang bigint, p_accepte boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.defense_repondre(bigint, boolean) TO authenticated;

-- ============================================================================================
-- 11. REVOQUER, ABANDONNER -- JUSQU'A L'AUDIENCE, PAS APRES
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.defense_rompre(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.defense_rompre(text) TO authenticated;

-- ============================================================================================
-- 12. LE DOSSIER, AU GREFFE COMPETENT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.avocat_dossier(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- L'ACCES VIENT DE LA DEFENSE ACCEPTEE, ET D'ELLE SEULE. Une demande en attente n'ouvre rien ;
  -- une defense rompue ne rouvre rien.
  IF public.defense_avocat_de(p_affaire_id) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_dossier'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- LE DOSSIER SE LIT AU GREFFE DU TRIBUNAL COMPETENT. Pas depuis chez soi, pas depuis une autre
  -- ville, pas depuis le Bureau des magistrats.
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece); END IF;

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
    -- L'AUDITION DU PREVENU, VERBATIM, et les circonstances REELLEMENT enregistrees. Rien n'est
    -- deduit : si le dossier ne dit pas si le prevenu s'est presente de lui-meme, l'avocat ne le
    -- lira pas ici. `pv_a_libere_une_detention` est le seul fait de circonstance que la
    -- procedure consigne aujourd'hui -- il dit qu'une garde a vue a ete levee par ce PV.
    'audition', (SELECT jsonb_build_object(
                   'personne', a.personne, 'refus', a.refus,
                   'declaration', a.declaration, 'jour', a.jour_pv, 'fait_le', a.fait_le,
                   'pv_a_libere_une_detention', (
                      SELECT coalesce((x.donnees ->> 'libere')::boolean, false)
                        FROM public.dossiers_judiciaires_actes x
                       WHERE x.affaire = p_affaire_id AND x.type = 'pv_audition'
                       ORDER BY x.rang DESC LIMIT 1))
                  FROM public.dossiers_auditions a
                 WHERE a.affaire = p_affaire_id AND a.personne = (v_a ->> 'cible')),
    -- LA CHRONOLOGIE COMPLETE, telle que le greffe la tient. Les `donnees` de chaque acte sont
    -- ce que la procedure a REELLEMENT verse au dossier : c'est la, et pas ailleurs, que vivent
    -- les elements.
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
GRANT EXECUTE ON FUNCTION public.avocat_dossier(text) TO authenticated;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : AUCUN DROIT CLIENT SUR LES QUATRE TABLES NEUVES, et la RLS sans policy sur chacune.
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid IN ('public.audience_paroles'::regclass,
                   'public.justice_barreau_qualifications'::regclass,
                   'public.avocats_barreau'::regclass,
                   'public.defenses_demandes'::regclass)
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur le socle avocat', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_class c
   WHERE c.oid IN ('public.audience_paroles'::regclass,
                   'public.justice_barreau_qualifications'::regclass,
                   'public.avocats_barreau'::regclass,
                   'public.defenses_demandes'::regclass) AND c.relrowsecurity;
  IF v_n <> 4 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % table(s) sous RLS, 4 attendues', v_n; END IF;

  -- P2 : LE BARREAU EST FERME PAR DEFAUT. Le registre est VIDE, donc personne n'est avocat.
  SELECT count(*) INTO v_n FROM public.justice_barreau_qualifications;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le registre du barreau porte % ligne(s) : une qualification a ete inventee', v_n; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'avocat_est_qualifie';
  IF position('public.justice_barreau_qualifications' IN v_txt) = 0
     OR position('public.personnages_qualifications' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la qualification d''avocat ne repose pas sur le registre'; END IF;

  -- P3 : LA CARACTERISTIQUE MECANIQUE DE L'AVOCAT N'EXISTE PAS DANS CETTE CHAINE. La mesure
  --      porte sur le LITTERAL et sur les tables, jamais sur le mot nu : ecrite sur le mot, elle
  --      a echoue sur « CHAMPS » d'un commentaire -- cinquieme fois que ce piege se referme.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'avocats_barreau'
     AND lower(column_name) LIKE '%cha%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3 ECHOUEE -- la table du barreau porte une caracteristique'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_avocats_disponibles';
  IF v_txt IS NULL THEN RAISE EXCEPTION 'P3 ECHOUEE -- la liste du prevenu n''existe pas'; END IF;
  IF position('''CHA''' IN v_txt) > 0 OR position('justice_cha_personnel' IN v_txt) > 0
     OR position('personnages_donnees' IN v_txt) > 0 OR position('stats' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la liste offerte au prevenu touche aux caracteristiques'; END IF;

  -- P4 : LA TARIFICATION FAIT L'INSCRIPTION, et elle ne peut pas etre vide.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conrelid = 'public.avocats_barreau'::regclass
     AND conname = 'avocats_barreau_tarification_non_vide';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- une tarification vide pourrait inscrire un avocat'; END IF;
  IF (SELECT count(*) FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'avocats_barreau') <> 4 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la table du barreau porte autre chose que nom/pays/tarification/maj'; END IF;

  -- P5 : AUCUN BOUTON DISPONIBLE/INDISPONIBLE. Pas de colonne d'etat, pas de porte pour la poser.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'avocats_barreau'
     AND column_name IN ('disponible', 'actif', 'etat', 'ouvert');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- un etat de disponibilite a ete ajoute'; END IF;

  -- P6 : HG NE FAIT RIEN DE LA TARIFICATION. Aucune porte ne la lit pour en tirer un paiement.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosrc LIKE '%avocats_barreau%'
     AND (p.prosrc ~ 'payer_ordre|debiter|mouvement_|caisse_' );
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- % porte(s) lient la tarification a un paiement', v_n; END IF;

  -- P7 : LE PREMIER ACCEPTANT EST GARANTI PAR UN INDEX, pas par une relecture.
  SELECT count(*) INTO v_n FROM pg_index x JOIN pg_class ic ON ic.oid = x.indexrelid
   WHERE x.indrelid = 'public.defenses_demandes'::regclass
     AND ic.relname = 'defenses_un_avocat_retenu_par_affaire'
     AND x.indisunique AND x.indpred IS NOT NULL;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- l''unicite de l''avocat retenu n''est pas structurelle'; END IF;
  SELECT count(*) INTO v_n FROM pg_index x JOIN pg_class ic ON ic.oid = x.indexrelid
   WHERE x.indrelid = 'public.defenses_demandes'::regclass
     AND ic.relname = 'defenses_une_demande_vivante_par_couple'
     AND x.indisunique AND x.indpred IS NOT NULL;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- un double clic peut doubler une demande'; END IF;

  -- P8 : LA PORTE TRADUIT CE REFUS, ELLE NE LE SUPPOSE PAS.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'defense_repondre';
  IF position('WHEN unique_violation THEN' IN v_txt) = 0
     OR position('''avocat_deja_retenu''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la course a l''acceptation n''est pas arbitree'; END IF;

  -- P9 : LES AUTRES DEMANDES DEVIENNENT CADUQUES, et la porte garde sur `en_attente`.
  IF position('SET etat = ''caduque''' IN v_txt) = 0
     OR position('WHERE affaire = v_d.affaire AND etat = ''en_attente''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- les demandes concurrentes survivent a l''acceptation'; END IF;
  IF position('IF v_d.etat <> ''en_attente'' THEN' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- une demande caduque peut encore etre acceptee'; END IF;

  -- P10 : AVANT ACCEPTATION, AUCUNE DONNEE DU DOSSIER.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'defense_mes_demandes';
  IF position('motif' IN v_txt) > 0 OR position('qualification' IN v_txt) > 0
     OR position('dossiers_auditions' IN v_txt) > 0
     OR position('dossiers_judiciaires_actes' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- l''avocat sollicite voit le dossier avant d''accepter'; END IF;

  -- P11 : LE DOSSIER EXIGE LA DEFENSE ACCEPTEE **ET** LA PRESENCE AU GREFFE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'avocat_dossier';
  IF position('public.defense_avocat_de(p_affaire_id) IS DISTINCT FROM v_moi' IN v_txt) = 0
     OR position('''pas_mon_dossier''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- le dossier s''ouvre sans defense acceptee'; END IF;
  IF position('public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece)' IN v_txt) = 0
     OR position('''presence_au_greffe_requise''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- le dossier se lit a distance'; END IF;

  -- P12 : AUCUN ACCES AU CASIER, et aucune omniscience.
  IF position('public.jugements' IN v_txt) > 0 OR position('historique_crimes' IN v_txt) > 0
     OR position('recherche' IN v_txt) > 0 OR position('actions_tracables' IN v_txt) > 0
     OR position('casier' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le dossier de l''avocat deborde sur le casier'; END IF;

  -- P13 : LE DOSSIER NE LIT QUE CETTE AFFAIRE. Chaque lecture d'une table de dossier est bornee
  --       par `p_affaire_id`, et il y en a trois.
  IF (SELECT count(*) FROM regexp_matches(v_txt, 'affaire = p_affaire_id', 'g')) < 3 THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- une lecture du dossier n''est pas bornee a l''affaire'; END IF;

  -- P14 : LES DEUX RUPTURES SONT VERROUILLEES PAR L'AUDIENCE, et nommees separement.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'defense_rompre';
  IF position('public.affaire_audience_ouverte(v_a)' IN v_txt) = 0
     OR position('''audience_ouverte''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- la defense peut etre rompue apres l''ouverture de l''audience'; END IF;
  IF position('''revoquee''' IN v_txt) = 0 OR position('''abandonnee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- revocation et abandon ne sont pas distingues'; END IF;

  -- P15 : ON NE DEMANDE UN AVOCAT QUE POURSUIVI, ET PAS APRES L'OUVERTURE DE L'AUDIENCE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'defense_demander';
  IF position('''poursuites'', ''saisie'', ''abandon_demande''' IN v_txt) = 0
     OR position('''poursuites_non_engagees''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- on constitue sa defense avant d''etre poursuivi'; END IF;
  IF position('public.affaire_audience_ouverte(v_a)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- on demande un avocat apres l''ouverture de l''audience'; END IF;

  -- P16 : LES DEMANDES MULTIPLES SONT LA REGLE : la porte prend un TABLEAU et boucle.
  IF position('FOREACH v_av IN ARRAY p_avocats LOOP' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P16 ECHOUEE -- la demande ne traite qu''un avocat a la fois'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'defense_demander'
     AND pg_get_function_identity_arguments(p.oid) = 'p_affaire_id text, p_avocats text[]';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P16 ECHOUEE -- la signature n''accepte pas plusieurs avocats'; END IF;

  -- P17 : LE DROIT DE PAROLE A L'AUDIENCE APPARTIENT AU JUGE, et il est serveur-autoritaire.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_audience_parole';
  IF position('public.juge_de_la_ville(v_ville)' IN v_txt) = 0
     OR position('''pas_juge_de_cette_ville''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P17 ECHOUEE -- la parole n''est pas donnee par le juge'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'audience_peut_ecrire';
  IF position('a.retiree_le IS NULL' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P17 ECHOUEE -- une parole retiree laisse encore ecrire'; END IF;

  -- P18 : AUCUNE REACTION HUMAINE CODEE dans aucune des portes de cette tranche.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('defense_demander', 'defense_repondre', 'defense_rompre',
                       'avocat_dossier', 'justice_avocats_disponibles',
                       'avocat_publier_tarification', 'justice_audience_parole')
     AND p.prosrc ~* '(credibilit|sincerit|plaidoirie|score|conviction|qualite_defense)';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P18 ECHOUEE -- % porte(s) jugent un comportement humain', v_n; END IF;

  RAISE NOTICE 'LES 18 PREUVES SONT VERTES.';
END $preuves$;
