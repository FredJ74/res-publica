-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012192823 (UTC), nom
-- `tribunal_temoins_citations_convocations_et_racine_commune`.
-- Le registre passe de 694 a 695 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6a72e6355f66668b1b2d3e7e8afd2abd, 45780 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LES TEMOINS : UNE RACINE COMMUNE, DEUX CONVOCATIONS, ET UNE RECHERCHE QUI S'ETEINT
--
-- CE QU'ELLE CONSTRUIT -- §I a §N du cahier des charges.
--
-- UNE SEULE RACINE D'AUDITION, ET C'ETAIT LA CONSIGNE. `audition_consigner_interne` porte ce qui
-- est commun au PV du prevenu et a la deposition du temoin : refuser une reponse absente, effacer
-- le texte sur un refus explicite, consigner VERBATIM, refuser une seconde audition. La qualite
-- (`prevenu` / `temoin`) distingue les deux actes sans faire deux moteurs. `pv_audition_realiser`
-- l'appelle avec `p_exiger_presence = false` -- son comportement est inchange, delai de 15 jours
-- compris -- et `temoin_deposer` avec `true`. Ce delai n'est JAMAIS applique au temoin.
--
-- QUI PEUT CITER, ET CE QUE LE SERVEUR NE SAIT PAS. Quatre autorites, dans cet ordre : l'avocat
-- retenu (refuse des que l'audience est ouverte), le parquet, le juge de la ville, le plaignant
-- tant que l'affaire est au parquet. Et AUCUN filtre sur le temoin au-dela de son existence : ni
-- presence aux faits, ni pertinence, ni ville, ni pays, ni relation. Le serveur ne sait pas ce
-- qu'un humain sait reellement.
--
-- DEUX JOURS, PUIS DEUX JOURS, PUIS RECHERCHE -- ET RIEN D'AUTRE. `temoins_convocations_echues`
-- emet la seconde convocation a l'echeance de la premiere, puis ouvre une recherche pour
-- non-presentation. Aucune amende, aucune perte de popularite, aucune sanction morale, aucune
-- interpretation de l'absence.
--
-- LA RECHERCHE S'ETEINT PAR UN DECLENCHEUR, PAS PAR HUIT CROCHETS.
-- `trg_plaintes_temoins_sur_cloture` surveille le STATUT du dossier : toute cloture definitive
-- eteint les citations de CETTE affaire et retire les recherches de non-presentation qui en
-- dependent -- et CELLES-LA SEULEMENT. `recherche_retirer_par_id` filtre sur l'identifiant de
-- l'entree, jamais sur l'acte : `recherche_retirer` aurait efface TOUTES les recherches de
-- temoin d'un joueur, pour d'autres affaires. Une neuvieme porte de cloture heritera de
-- l'extinction sans qu'on y pense.
--
-- LA TERRITORIALITE N'A DEMANDE AUCUN CODE. `police_signaler` est deja borne a Republia et exige
-- la co-presence physique ; `acteur_present_sur_site` compare le pays de la personne a celui du
-- site. Un temoin etranger doit donc VENIR, et rien ne le contraint hors du territoire.
--
-- PREUVES STRUCTURELLES -- 20.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LES TEMOINS : UNE RACINE COMMUNE, DEUX CONVOCATIONS, ET UNE RECHERCHE QUI S'ETEINT
-- 12 octobre 2026 -- §I a §N du cahier des charges
--
-- UNE SEULE RACINE D'AUDITION, ET C'ETAIT LA CONSIGNE. Le PV du prevenu existait depuis la
-- veille ; la deposition d'un temoin lui ressemble trait pour trait -- une reponse libre OU un
-- refus explicite, enregistres VERBATIM, sans aucune interpretation. Plutot que deux moteurs
-- paralleles qui divergeraient au premier correctif, `audition_consigner_interne` porte le
-- principe commun et les deux portes l'appellent. `dossiers_auditions` gagne une colonne
-- `qualite` : le PV du prevenu et la deposition du temoin restent DISTINGUES, sans etre separes.
--
-- CE QUE LA RACINE NE PARTAGE PAS, ET C'EST DELIBERE. Le delai de jugement de quinze jours part
-- du PV DU PREVENU, et de lui seul : c'est son audition qui le declenche. Une deposition de
-- temoin ne touche a aucune echeance -- l'appliquer serait offrir au premier temoin le pouvoir
-- de redemarrer l'horloge du dossier.
--
-- LA PRESENCE PHYSIQUE EST EXIGEE DU TEMOIN, PAS DU PREVENU, et ce n'est pas un oubli. Le
-- cahier des charges exige le commissariat competent pour le temoin ; le PV du prevenu, livre et
-- valide la veille, ne l'a jamais exige. Toucher a sa porte serait changer une mecanique deja
-- arbitree sans qu'on me l'ait demande. La racine prend donc un parametre
-- `p_exiger_presence` : le temoin passe `true`, le prevenu garde `false`, et aligner le second
-- sur le premier sera UNE VALEUR a changer -- pas une reecriture. C'est le seul point de cette
-- tranche qui attend une confirmation.
--
-- DEUX CONVOCATIONS, DEUX JOURS CHACUNE, PUIS LA RECHERCHE. Et rien d'autre : aucun prelevement,
-- aucune mesure sociale touchee, aucune sanction morale, aucune lecture de l'absence. La seule
-- consequence automatique est le statut judiciaire.
--
-- LA RECHERCHE D'UN TEMOIN EST ATTACHEE A SA CITATION, par un identifiant. C'est ce qui permet
-- de l'eteindre SEULE : `recherche_retirer` filtre par acte et par pays, ce qui aurait efface
-- toutes les non-presentations du meme joueur d'un coup. La nouvelle porte interne filtre par
-- l'identifiant de l'entree, et n'en touche aucune autre -- ni celle d'une autre affaire, ni
-- celle d'une infraction.
--
-- LA TERRITORIALITE NE SE CODE PAS ICI, PARCE QU'ELLE EST DEJA STRUCTURELLE. Une recherche n'est
-- coercitive que par `police_signaler`, qui est bornee a Republia et exige la CO-PRESENCE
-- physique dans la piece. Un temoin etranger qui reste chez lui n'est donc jamais joignable ; le
-- jour ou il entre en Republia, il l'est, par le mecanisme normal. Aucune recherche
-- internationale n'a besoin d'exister -- et aucune n'est creee.
--
-- L'EXTINCTION A LA CLOTURE PASSE PAR UN DECLENCHEUR, et c'est la seule facon de ne pas en
-- oublier une. Huit portes closent une affaire aujourd'hui -- non-lieu, abandon, arret, relaxe,
-- condamnation, procedure simplifiee, jugement d'appel, expiration du delai -- et d'autres
-- viendront. Les crocheter une par une, c'est garantir qu'une neuve sera oubliee. Le declencheur
-- regarde le STATUT, pas l'appelant.
--
-- AUCUNE REACTION HUMAINE N'EST CODEE. Pas de mesure de credibilite, pas de sincerite, pas de
-- malus parce qu'un temoin refuse. Le refus est un FAIT, consigne ; ce que le Procureur en fera
-- releve de lui, et des regles judiciaires ordinaires.
--
-- DEUX DETAILS ONT REFUSE LES PREMIERS ENVOIS, ET LES DEUX SONT DES LECONS DEJA CONNUES.
--   1. `pv_audition_realiser` porte des VALEURS PAR DEFAUT sur deux parametres, et PostgreSQL
--      refuse de les retirer par CREATE OR REPLACE. Les reecrire a l'identique fait partie du
--      contrat : les omettre aurait casse tous ses appelants.
--   2. LE PIEGE DU COMMENTAIRE S'EST REFERME DANS LA MIGRATION QUI EN PARLE. Une preuve
--      negative ecrite sur des mots de prose -- « amende », « indice » -- a echoue sur mon
--      propre commentaire « aucun indice touche ». Les preuves negatives de cette migration
--      portent donc sur des IDENTIFIANTS DE CODE (noms de fonction et de table), jamais sur des
--      mots qu'un commentaire peut employer. Sixieme fois en trois jours.
--
-- PREUVES STRUCTURELLES -- 20.

-- ============================================================================================
-- 1. LA COLONNE QUI DISTINGUE SANS SEPARER
-- ============================================================================================
ALTER TABLE public.dossiers_auditions
  ADD COLUMN IF NOT EXISTS qualite text NOT NULL DEFAULT 'prevenu';
ALTER TABLE public.dossiers_auditions
  DROP CONSTRAINT IF EXISTS dossiers_auditions_qualite;
ALTER TABLE public.dossiers_auditions
  ADD CONSTRAINT dossiers_auditions_qualite CHECK (qualite IN ('prevenu', 'temoin'));
COMMENT ON COLUMN public.dossiers_auditions.qualite IS
  'A quel titre cette personne a ete entendue : `prevenu` (son PV d''audition, qui fait courir le delai de jugement) ou `temoin` (sa deposition, qui ne touche aucune echeance).';

-- ============================================================================================
-- 2. LE COMMISSARIAT COMPETENT ET LE DELAI : UNE SEULE DEFINITION CHACUN
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.temoin_commissariat_competent(p_pays text, p_ville text)
RETURNS TABLE (batiment text, piece text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  -- LA VILLE EST CELLE DU TRIBUNAL COMPETENT POUR L'AFFAIRE, pas celle du temoin : une affaire
  -- de Montrouge se depose au commissariat de Montrouge, meme si le temoin habite Luthecia.
  SELECT CASE WHEN v.est_capitale THEN 'commissariat' ELSE 'commissariat-local' END,
         CASE WHEN v.est_capitale THEN 'accueil_police' ELSE 'accueil_loc' END
    FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville;
$$;

CREATE OR REPLACE FUNCTION public.justice_delai_convocation_temoin_jours()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 2 $$;

-- ============================================================================================
-- 3. LA RACINE COMMUNE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.audition_consigner_interne(
  p_affaire text, p_pays text, p_ville text, p_personne text, p_qualite text,
  p_declaration text, p_refus boolean, p_jour integer, p_exiger_presence boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
COMMENT ON FUNCTION public.audition_consigner_interne(text, text, text, text, text, text, boolean, integer, boolean) IS
  'Racine commune du PV du prevenu et de la deposition du temoin : une reponse libre OU un refus explicite, verbatim, sans aucune interpretation. Aucun droit client -- les deux portes metier seules l''appellent.';

-- ============================================================================================
-- 4. LE PV DU PREVENU PASSE PAR LA RACINE -- ET RIEN D'AUTRE NE CHANGE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.pv_audition_realiser(
  p_affaire_id text, p_declaration text DEFAULT NULL::text, p_refus boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

-- ============================================================================================
-- 5. LES CITATIONS DE TEMOIN
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.temoins_citations (
  rang             bigserial   NOT NULL,
  affaire          text        NOT NULL,
  pays             text        NOT NULL,
  ville            text,
  temoin           text        NOT NULL,
  cite_par         text        NOT NULL,
  cite_par_qualite text        NOT NULL,
  cite_le          timestamptz NOT NULL DEFAULT now(),
  convocation_rang integer     NOT NULL DEFAULT 1,
  echeance_jour    integer     NOT NULL,
  etat             text        NOT NULL DEFAULT 'convoquee',
  issue            text,
  clos_le          timestamptz,
  CONSTRAINT temoins_citations_pk PRIMARY KEY (rang),
  -- UN TEMOIN N'EST CITE QU'UNE FOIS PAR AFFAIRE. Deux citations seraient deux obligations pour
  -- une seule deposition possible (`dossiers_auditions` est unique par affaire et par personne).
  CONSTRAINT temoins_citations_une_par_affaire UNIQUE (affaire, temoin),
  CONSTRAINT temoins_citations_etat CHECK (etat IN ('convoquee', 'recherche', 'close')),
  CONSTRAINT temoins_citations_rang_convocation CHECK (convocation_rang IN (1, 2)),
  CONSTRAINT temoins_citations_qualite CHECK (cite_par_qualite IN
    ('avocat', 'parquet', 'juge', 'plaignant')),
  CONSTRAINT temoins_citations_issue CHECK (issue IS NULL OR issue IN
    ('deposition', 'refus', 'affaire_close')),
  -- Close, c'est close PAR quelque chose : les deux colonnes vont ensemble ou aucune.
  CONSTRAINT temoins_citations_cloture CHECK (
    (etat = 'close' AND issue IS NOT NULL AND clos_le IS NOT NULL)
    OR (etat <> 'close' AND issue IS NULL AND clos_le IS NULL))
);
REVOKE ALL ON TABLE public.temoins_citations FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.temoins_citations_rang_seq FROM anon, authenticated;
ALTER TABLE public.temoins_citations ENABLE ROW LEVEL SECURITY;

-- ============================================================================================
-- 6. CITER UN TEMOIN -- N'IMPORTE QUEL PJ, DE N'IMPORTE QUEL EMPIRE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.temoin_citer(p_affaire_id text, p_temoin text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_t text;
  v_qualite text; v_p record; v_j record; v_jour integer; v_ech integer; v_rang bigint;
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

  -- LES QUATRE AUTORITES, DANS L'ORDRE OU ELLES SE RECONNAISSENT.
  v_qualite := NULL;
  IF public.defense_avocat_de(p_affaire_id) = v_moi THEN
    -- L'AVOCAT PERD CE POUVOIR A L'OUVERTURE DE L'AUDIENCE, et lui seul : le cahier des charges
    -- ne retire rien au juge ni au parquet, et on ne leur retire donc rien.
    IF public.affaire_audience_ouverte(v_a) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;
    v_qualite := 'avocat';
  ELSE
    SELECT * INTO v_p FROM public.parquet_moi();
    IF v_p.nom = v_moi AND v_p.pays IS NOT DISTINCT FROM v_pays THEN
      v_qualite := 'parquet';
    ELSE
      SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
      IF v_j.nom = v_moi THEN
        v_qualite := 'juge';
      ELSIF coalesce(v_a ->> 'plaignant', v_a ->> 'auteur') = v_moi
            AND coalesce(v_a ->> 'status', '') = 'au_parquet' THEN
        -- LE PLAIGNANT CITE SES TEMOINS AU MOMENT DU DEPOT, et c'est rendu par la fenetre ou son
        -- dossier n'a encore ete touche par personne : `au_parquet`. Des que le parquet agit, ce
        -- n'est plus le moment du depot.
        v_qualite := 'plaignant';
      END IF;
    END IF;
  END IF;
  IF v_qualite IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee'); END IF;

  -- AUCUN FILTRE SUR LE TEMOIN, ET C'EST LA REGLE. N'importe quel PJ, de n'importe quel empire :
  -- le serveur ne sait pas ce qu'un humain a vu, et il ne doit pas en decider.
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = v_t) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'temoin_introuvable'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_ech := v_jour + public.justice_delai_convocation_temoin_jours();
  BEGIN
    INSERT INTO public.temoins_citations
      (affaire, pays, ville, temoin, cite_par, cite_par_qualite, echeance_jour)
    VALUES (p_affaire_id, v_pays, v_ville, v_t, v_moi, v_qualite, v_ech)
    RETURNING rang INTO v_rang;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'temoin_deja_cite');
  END;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'temoin_cite',
    v_moi, v_qualite, NULL, NULL,
    jsonb_build_object('temoin', v_t, 'convocation', 1, 'echeance_jour', v_ech,
                       'commissariat', (SELECT c.batiment FROM public.temoin_commissariat_competent(v_pays, v_ville) c)));

  RETURN jsonb_build_object('ok', true, 'citation', v_rang, 'affaire', p_affaire_id,
    'temoin', v_t, 'par', v_moi, 'qualite', v_qualite,
    'convocation', 1, 'echeance_jour', v_ech,
    'commissariat', (SELECT c.batiment FROM public.temoin_commissariat_competent(v_pays, v_ville) c),
    'piece', (SELECT c.piece FROM public.temoin_commissariat_competent(v_pays, v_ville) c));
END $$;
GRANT EXECUTE ON FUNCTION public.temoin_citer(text, text) TO authenticated;

-- ============================================================================================
-- 7. CE QUE LE TEMOIN VOIT DE SES CONVOCATIONS
-- ============================================================================================
-- IL VOIT SON OBLIGATION, PAS LE DOSSIER. L'affaire, la ville, le commissariat, l'echeance et le
-- rang de la convocation : de quoi se presenter. Ni le prevenu, ni la qualification.
CREATE OR REPLACE FUNCTION public.temoin_mes_convocations()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.temoin_mes_convocations() TO authenticated;

-- ============================================================================================
-- 8. RETIRER UNE SEULE ENTREE D'AVIS DE RECHERCHE, PAR SON IDENTIFIANT
-- ============================================================================================
-- `recherche_retirer` filtre par ACTE et par PAYS : elle aurait efface toutes les
-- non-presentations du meme joueur d'un coup, donc celles d'autres affaires. Celle-ci filtre par
-- l'IDENTIFIANT de l'entree, et ne touche rien d'autre. Aucun droit client : elle est interne.
CREATE OR REPLACE FUNCTION public.recherche_retirer_par_id(p_cible text, p_id text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

-- ============================================================================================
-- 9. DEPOSER, OU REFUSER DE TEMOIGNER
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.temoin_deposer(
  p_affaire_id text, p_declaration text DEFAULT NULL::text, p_refus boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;
GRANT EXECUTE ON FUNCTION public.temoin_deposer(text, text, boolean) TO authenticated;

-- ============================================================================================
-- 10. LA PASSE DES ECHEANCES : SECONDE CONVOCATION, PUIS RECHERCHE
-- ============================================================================================
-- RESERVEE AU SERVEUR : aucun droit client. Un joueur qui l'appellerait obtient un refus de
-- privilege -- le GRANT est la vraie porte, pas un test dans le corps.
CREATE OR REPLACE FUNCTION public.temoins_convocations_echues()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

-- ============================================================================================
-- 11. L'EXTINCTION A LA CLOTURE DE L'AFFAIRE -- PAR UN DECLENCHEUR, PAS PAR HUIT CROCHETS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.temoins_citations_eteindre_interne(p_affaire text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

CREATE OR REPLACE FUNCTION public.plaintes_temoins_sur_cloture()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
END $$;

DROP TRIGGER IF EXISTS trg_plaintes_temoins_sur_cloture ON public.plaintes_en_cours;
CREATE TRIGGER trg_plaintes_temoins_sur_cloture
  AFTER UPDATE OF data ON public.plaintes_en_cours
  FOR EACH ROW EXECUTE FUNCTION public.plaintes_temoins_sur_cloture();

-- ============================================================================================
-- 12. CINQ TYPES D'ACTES NEUFS
-- ============================================================================================
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
  ('temoin_cite', 'Temoin cite a comparaitre', 'juge',
   'Pose par l''autorite qui cite : avocat, parquet, juge, ou plaignant au moment du depot. L''acte porte sa qualite reelle dans `acteur_poste`.'),
  ('temoin_deposition', 'Deposition de temoin', 'temoin',
   'La deposition ou le refus de temoigner, consignes verbatim. Aucune interpretation.'),
  ('temoin_convocation_renouvelee', 'Seconde convocation d''un temoin', 'serveur',
   'Posee par la passe de minuit a l''echeance de la premiere convocation.'),
  ('temoin_recherche', 'Temoin recherche -- non-presentation', 'serveur',
   'Posee par la passe de minuit a l''echeance de la seconde convocation. Seule consequence automatique de l''absence.'),
  ('temoin_citation_eteinte', 'Citation de temoin eteinte -- affaire close', 'serveur',
   'Posee a la cloture definitive de l''affaire.')
ON CONFLICT (type) DO NOTHING;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : AUCUN DROIT CLIENT SUR LES CITATIONS, RLS sans policy.
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid = 'public.temoins_citations'::regclass
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur temoins_citations', v_n; END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.temoins_citations'::regclass) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- temoins_citations n''est pas sous RLS'; END IF;

  -- P2 : LA RACINE EST COMMUNE, ET LES DEUX PORTES L'APPELLENT.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname IN ('pv_audition_realiser', 'temoin_deposer')
     AND p.prosrc LIKE '%public.audition_consigner_interne(%';
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- % porte(s) sur 2 passent par la racine commune', v_n; END IF;

  -- P3 : LES FONCTIONS INTERNES NE SONT PAS APPELABLES PAR UN CLIENT. Le GRANT est la vraie porte.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('audition_consigner_interne', 'recherche_retirer_par_id',
                       'temoins_convocations_echues', 'temoins_citations_eteindre_interne')
     AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
          OR has_function_privilege('anon', p.oid, 'EXECUTE'));
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- % fonction(s) interne(s) appelable(s) par un client', v_n; END IF;

  -- P4 : LE PRINCIPE COMMUN EST DANS LA RACINE, PAS RECOPIE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'audition_consigner_interne';
  IF position('''reponse_absente''' IN v_txt) = 0
     OR position('IF v_refus THEN v_decl := NULL; END IF;' IN v_txt) = 0
     OR position('''audition_deja_realisee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le principe commun n''est pas dans la racine'; END IF;

  -- P5 : AUCUNE INTERPRETATION, NULLE PART. La mesure porte sur des IDENTIFIANTS DE CODE --
  --      jamais sur un mot de prose, qu'un commentaire pourrait employer.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('audition_consigner_interne', 'temoin_deposer', 'pv_audition_realiser',
                       'temoin_citer', 'temoins_convocations_echues')
     AND p.prosrc ~ '(deepseek|openai|ia_|_ia\(|analyse_|evaluer_|noter_)';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % porte(s) analysent une deposition', v_n; END IF;

  -- P6 : LE DELAI DE QUINZE JOURS RESTE AU PREVENU, ET N'ATTEINT PAS LE TEMOIN.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'pv_audition_realiser';
  IF position('public.justice_delai_jugement_jours()' IN v_txt) = 0
     OR position('''delai_jugement_jour'', v_echeance' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- le PV du prevenu ne fait plus courir le delai'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoin_deposer';
  IF position('justice_delai_jugement_jours' IN v_txt) > 0
     OR position('delai_jugement_jour' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la deposition d''un temoin touche au delai de jugement'; END IF;

  -- P7 : LE PV DU PREVENU N'A PAS GAGNE DE GARDE DE PRESENCE. Il passe `false`, et c'est ecrit.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'pv_audition_realiser';
  IF position('p_declaration, p_refus, v_jour, false)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le PV du prevenu a change de regle de presence'; END IF;

  -- P8 : LE TEMOIN, LUI, DOIT ETRE AU BON COMMISSARIAT.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoin_deposer';
  IF position('p_declaration, p_refus, v_jour, true)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la deposition ne verifie pas la presence'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'audition_consigner_interne';
  IF position('''presence_au_commissariat_requise''' IN v_txt) = 0
     OR position('public.acteur_present_sur_site(p_personne, p_pays, p_ville, v_c.batiment, v_c.piece)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la presence n''est pas verifiee par la regle unique'; END IF;

  -- P9 : LE COMMISSARIAT EST CELUI DE LA VILLE DU TRIBUNAL, ET IL A UNE SEULE DEFINITION.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoin_commissariat_competent';
  IF position('est_capitale' IN v_txt) = 0 OR position('commissariat-local' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le commissariat competent n''est pas derive de la ville'; END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'temoin_commissariat_competent') <> 1 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le commissariat competent a plusieurs definitions'; END IF;

  -- P10 : DEUX JOURS, DECLARES UNE FOIS.
  IF public.justice_delai_convocation_temoin_jours() <> 2 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- le delai de convocation ne vaut pas 2 jours'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoins_convocations_echues';
  IF position('public.justice_delai_convocation_temoin_jours()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la passe recalcule le delai au lieu de le lire'; END IF;

  -- P11 : DEUX CONVOCATIONS, PUIS LA RECHERCHE -- ET RIEN D'AUTRE. Mesure sur les IDENTIFIANTS
  --       des portes qui preleveraient ou toucheraient une mesure sociale, jamais sur la prose.
  IF position('convocation_rang = 2' IN v_txt) = 0 OR position('''recherche''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- la seconde convocation ou la recherche manque'; END IF;
  IF v_txt ~ '(payer_ordre|debiter_|personnage_ajuster_pop|mouvement_|caisse_|indices_|justice_condamner|detention_ouvrir)' THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- l''absence d''un temoin a une consequence hors recherche'; END IF;

  -- P12 : L'ECHEANCE N'EST PAS ECHUE LE JOUR MEME.
  IF position('CONTINUE WHEN v_jour <= v_c.echeance_jour;' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- une convocation expire le jour de son echeance'; END IF;

  -- P13 : LA RECHERCHE PORTE UN IDENTIFIANT LIE A LA CITATION.
  IF position('''id'', ''temoin-'' || v_c.rang' IN v_txt) = 0
     OR position('''acte'', ''non_presentation_temoin''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- la recherche d''un temoin n''est pas identifiee'; END IF;

  -- P14 : LE RETRAIT EST CHIRURGICAL. La porte interne filtre par IDENTIFIANT, jamais par acte.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'recherche_retirer_par_id';
  IF position('(e ->> ''id'') IS DISTINCT FROM p_id' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- le retrait ne porte pas sur l''identifiant seul'; END IF;
  IF position('''acte''' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- le retrait filtre encore par acte, donc efface trop'; END IF;

  -- P15 : DEPOSER OU REFUSER SATISFAIT LA COMPARUTION, ET RETIRE LA RECHERCHE CORRESPONDANTE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoin_deposer';
  IF position('SET etat = ''close''' IN v_txt) = 0
     OR position('public.recherche_retirer_par_id(v_moi, ''temoin-'' || v_c.rang)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- la deposition ne satisfait pas la comparution'; END IF;
  IF position('''refus''' IN v_txt) = 0 OR position('''deposition''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- le refus et la deposition ne sont pas distingues'; END IF;

  -- P16 : AUCUNE SANCTION DU REFUS LUI-MEME. La porte n'ouvre aucune peine, ne preleve rien, et
  --       la SEULE detention qu'elle touche est celle qu'elle CLOT.
  IF v_txt ~ '(payer_ordre|debiter_|personnage_ajuster_pop|justice_condamner|detention_ouvrir)' THEN
    RAISE EXCEPTION 'P16 ECHOUEE -- le refus de temoigner est sanctionne automatiquement'; END IF;
  IF position('public.detention_clore_interne(' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P16 ECHOUEE -- la porte ne sait pas lever une detention'; END IF;

  -- P17 : LA DETENTION QUI N'EXISTAIT QUE POUR CETTE NON-PRESENTATION CESSE, et la mesure est
  --       precise : elle passe par « n'est plus recherche du tout ».
  IF position('NOT public.justice_est_recherche(v_moi)' IN v_txt) = 0
     OR position('''arrestation_sur_signalement''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P17 ECHOUEE -- la detention de non-presentation ne cesse pas, ou cesse trop'; END IF;

  -- P18 : LES QUATRE AUTORITES DE CITATION, ET AUCUNE AUTRE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoin_citer';
  IF position('public.defense_avocat_de(p_affaire_id) = v_moi' IN v_txt) = 0
     OR position('public.parquet_moi()' IN v_txt) = 0
     OR position('public.juge_de_la_ville(v_ville)' IN v_txt) = 0
     OR position('''plaignant''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P18 ECHOUEE -- les quatre autorites de citation ne sont pas toutes la'; END IF;
  IF position('''autorite_refusee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P18 ECHOUEE -- un tiers peut citer un temoin'; END IF;

  -- P19 : AUCUN FILTRE SUR LE TEMOIN. Ni ville, ni pays, ni relation.
  IF v_txt ~ '(d\.country\s*=|d\.current_city|d\.city)' THEN
    RAISE EXCEPTION 'P19 ECHOUEE -- la citation filtre le temoin sur un critere interdit'; END IF;
  IF position('d.name = v_t' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P19 ECHOUEE -- la citation ne verifie meme pas que le temoin existe'; END IF;

  -- P20 : L'EXTINCTION A LA CLOTURE EST UN DECLENCHEUR QUI REGARDE LE STATUT.
  SELECT count(*) INTO v_n FROM pg_trigger t
   WHERE t.tgrelid = 'public.plaintes_en_cours'::regclass
     AND t.tgname = 'trg_plaintes_temoins_sur_cloture' AND NOT t.tgisinternal;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P20 ECHOUEE -- l''extinction a la cloture n''est pas accrochee'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plaintes_temoins_sur_cloture';
  IF position('''non_lieu'', ''abandonnee'', ''arret'', ''relaxe'', ''jugee''' IN v_txt) = 0
     OR position('''jugee_appel'', ''delai_expire''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P20 ECHOUEE -- la liste des clotures est incomplete'; END IF;
  IF position('v_apres IS NOT DISTINCT FROM v_avant' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P20 ECHOUEE -- le declencheur travaille sur une ecriture qui ne change rien'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'temoins_citations_eteindre_interne';
  IF position('public.recherche_retirer_par_id(v_c.temoin, ''temoin-'' || v_c.rang)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P20 ECHOUEE -- la cloture n''eteint pas la recherche correspondante'; END IF;

  RAISE NOTICE 'LES 20 PREUVES SONT VERTES.';
END $preuves$;
