-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012115640 (UTC), nom
-- `tribunal_pv_audition_et_infraction_constatee`.
-- Le registre passe de 679 a 680 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 f750db29259f7eeec95bf0fd5cb35a68, 26239 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL (1/4) -- LE PV D'AUDITION, ET L'INFRACTION QUE LE DOSSIER PORTE ENFIN
--
-- DEUX MANQUES MESURES AVANT D'ECRIRE. (1) Aucun dossier ne savait de quelle INFRACTION il
-- parlait avant la qualification du parquet : `affaire_transmettre` enregistre un motif en texte
-- LIBRE, et la procedure simplifiee se decide sur la peine de REFERENCE du catalogue penal. La
-- police fait desormais voyager l'infraction qu'elle constate, par le jsonb `p_fait` qui porte
-- deja la victime et la reference du fait -- aucune signature ne change. (2) Un PJ arrete pouvait
-- rester detenu INDEFINIMENT si aucun Procureur ni aucun juge n'etait joue : rien ne refermait la
-- detention. Le PV d'audition est la porte qui sort de la, et il appartient A L'ACCUSE -- il ne
-- depend donc d'aucun poste institutionnel occupe.
--
-- LE REFUS DE REPONDRE EST UNE REPONSE PROCEDURALE VALIDE : ni aveu, ni faute, aucun malus. La
-- declaration est consignee VERBATIM, aucune IA ne la lit, et le serveur n'en juge ni la
-- credibilite ni la coherence. APPEND-ONLY par trois verrous, comme la chronologie.
--
-- SA PROPRE PREUVE P1 A REFUSE LE PREMIER ENVOI, et le fait vaut d'etre garde : une table neuve
-- nait avec ALL accorde a anon et authenticated par `ALTER DEFAULT PRIVILEGES` de la plateforme.
-- Le chantier du 9 octobre 2026 avait ferme ce defaut POUR LES FONCTIONS ; il reste ouvert pour
-- les TABLES. Sans le REVOKE explicite, le premier des trois verrous n'existait pas.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PV D'AUDITION, ET L'INFRACTION QUE LE DOSSIER PORTE ENFIN
-- 12 octobre 2026, nuit -- premiere migration de la tranche du Tribunal
--
-- DEUX MANQUES MESURES AVANT D'ECRIRE, ET C'EST LE MEME DOSSIER QUI LES PORTE.
--
-- 1. AUCUN DOSSIER NE SAIT DE QUELLE INFRACTION IL PARLE AVANT LA QUALIFICATION DU PARQUET.
--    `affaire_transmettre` enregistre un `motif` en TEXTE LIBRE tape par le policier, et
--    `plainte_deposer` une categorie ALLEGUEE qui n'engage rien. Or la procedure simplifiee se
--    decide sur la PEINE DE REFERENCE du catalogue penal : sans infraction canonique sur le
--    dossier, le seuil des 2 jours n'est pas calculable. La police, elle, CONNAIT l'acte quand
--    elle demasque un fait trace -- il est dans `actions_tracables.type_action`, et c'est un
--    identifiant du catalogue. On le fait donc voyager, par le jsonb `p_fait` qui transporte
--    deja la victime, le jour du fait et la reference technique : aucune signature ne change,
--    donc aucun appelant ne casse. L'infraction est VALIDEE par `infraction_canonique` : un
--    motif libre ne devient jamais une qualification.
--
-- 2. UN PJ ARRETE PEUT RESTER DETENU INDEFINIMENT SI AUCUN PROCUREUR NI AUCUN JUGE N'EST JOUE.
--    `arrestation_urgence` et `enquete_garde_a_vue` ouvrent une detention ; rien ne la referme
--    si personne ne juge. Le PV d'audition est la porte qui sort de la : il appartient A
--    L'ACCUSE -- c'est lui qui parle ou refuse de parler -- donc il ne depend d'aucun poste
--    institutionnel occupe. C'est tout l'interet : la protection temporelle ne peut pas etre
--    bloquee par l'absence d'un titulaire.
--
-- CE QUE LE PV EST, ET CE QU'IL N'EST PAS. Un FAIT : « X a declare ceci », verbatim, ou « X a
-- refuse de repondre ». Le refus est une reponse procedurale VALIDE, enregistree comme telle,
-- sans malus et sans justification exigee. Rien n'est juge : ni la credibilite, ni la coherence,
-- ni l'opportunite. Aucune IA ne lit ce texte. Le joueur peut y ecrire qu'il ne parlera qu'en
-- presence de son avocat : le serveur n'a pas a le comprendre, seulement a l'enregistrer.
--
-- APPEND-ONLY PAR LES TROIS MEMES VERROUS QUE LA CHRONOLOGIE : aucun GRANT client, aucune policy,
-- et un declencheur qui refuse UPDATE et DELETE -- opposable a service_role comme a une fonction
-- SECURITY DEFINER. Un proces-verbal qu'on peut reecrire n'est pas un proces-verbal.
--
-- UNE TABLE NEUVE NAIT OUVERTE, ET LA PREUVE P1 L'A ATTRAPE. Le premier envoi de cette migration
-- a ete REFUSE par sa propre preuve : `ALTER DEFAULT PRIVILEGES` de la plateforme accorde ALL
-- aux roles clients sur toute table creee dans `public`. Le chantier du 9 octobre 2026 avait
-- ferme ce defaut POUR LES FONCTIONS ; il reste ouvert pour les TABLES. Le REVOKE ci-dessous
-- n'est donc pas une precaution de style : sans lui, le premier des trois verrous de
-- l'append-only n'existait pas, et un navigateur pouvait INSERER un proces-verbal.
--
-- PREUVES STRUCTURELLES -- 10.

-- ============================================================================================
-- 1. L'ACCUSE DEVIENT UN AUTEUR D'ACTE, ET DEUX ACTES DE PLUS AU REGISTRE
-- ============================================================================================
-- `pose_par` est une contrainte CHECK et non un registre : cinq auteurs y etaient declares, et
-- l'accuse n'en etait pas. Il le devient, parce qu'il pose desormais un acte de procedure.
ALTER TABLE public.dossiers_judiciaires_actes_types
  DROP CONSTRAINT dossiers_judiciaires_actes_types_pose_par_check;
ALTER TABLE public.dossiers_judiciaires_actes_types
  ADD CONSTRAINT dossiers_judiciaires_actes_types_pose_par_check
  CHECK (pose_par = ANY (ARRAY['plaignant','police','parquet','juge','accuse','serveur']));

INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
 ('pv_audition', 'Proces-verbal d''audition', 'accuse',
  'La declaration de la personne mise en cause, ou son refus explicite de repondre. Le refus est une reponse procedurale valide : il n''est ni un aveu, ni une faute, et n''emporte aucun malus. Le texte est consigne VERBATIM et n''est lu par aucune IA.'),
 ('charges_abandonnees_delai', 'Charges abandonnees -- delai de jugement expire', 'serveur',
  'Le delai de jugement de premiere instance a expire sans jugement. Ce n''est ni une relaxe ni un non-lieu : c''est la cloture d''une procedure qui n''a pas abouti dans le temps imparti.');

-- ============================================================================================
-- 2. L'INFRACTION DE REFERENCE D'UN DOSSIER, A UN SEUL ENDROIT
-- ============================================================================================
-- TROIS NIVEAUX DE QUALIFICATION COEXISTENT SUR UN DOSSIER, et l'ordre de preseance n'est pas
-- une opinion : la qualification FINALE du juge prime, puis celle du parquet, puis l'infraction
-- CONSTATEE par la police. La categorie ALLEGUEE par le plaignant n'en fait pas partie -- c'est
-- une declaration, pas une qualification, et elle nomme une categorie, pas une infraction.
CREATE OR REPLACE FUNCTION public.affaire_infraction_de(p_data jsonb)
RETURNS text LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT nullif(btrim(coalesce(
    p_data ->> 'qualification_finale',
    p_data ->> 'qualification_parquet',
    p_data ->> 'infraction_constatee', '')), '');
$$;
COMMENT ON FUNCTION public.affaire_infraction_de(jsonb) IS
  'L''infraction de reference d''un dossier, dans l''ordre de preseance : qualification finale du juge, puis du parquet, puis infraction constatee par la police. La categorie alleguee par le plaignant n''y figure pas : c''est une declaration, et elle nomme une categorie et non une infraction.';

-- ============================================================================================
-- 3. LA POLICE FAIT VOYAGER L'INFRACTION QU'ELLE CONSTATE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.affaire_transmettre(p_cible text, p_motif text, p_city text, p_fait jsonb DEFAULT NULL::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;
COMMENT ON FUNCTION public.affaire_transmettre(text, text, text, jsonb) IS
  'La police transmet au PARQUET un acte illegal decouvert. Depuis le 12 octobre 2026 elle peut faire voyager l''INFRACTION CONSTATEE, par la cle `infraction` de p_fait : c''est le seul moment ou le systeme connait l''acte canonique sans qu''aucune autorite n''ait decide quoi que ce soit, et c''est de lui que depend la peine de reference. Elle est validee par infraction_canonique, jamais devinee depuis le motif libre.';

-- ============================================================================================
-- 4. LE REGISTRE DES AUDITIONS
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.dossiers_auditions (
  id            text PRIMARY KEY,
  affaire       text NOT NULL,
  pays          text NOT NULL,
  ville         text,
  personne      text NOT NULL,
  declaration   text,
  refus         boolean NOT NULL DEFAULT false,
  jour_pv       integer NOT NULL,
  fait_le       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dossiers_auditions_un_pv_par_affaire_et_personne UNIQUE (affaire, personne),
  -- UNE DECLARATION OU UN REFUS, JAMAIS LES DEUX NI AUCUN DES DEUX. Le refus est une reponse,
  -- pas une absence de reponse : un PV vide ne serait ni l'un ni l'autre.
  CONSTRAINT dossiers_auditions_declaration_ou_refus
    CHECK ( (refus IS TRUE AND declaration IS NULL)
         OR (refus IS FALSE AND declaration IS NOT NULL AND btrim(declaration) <> '') )
);
ALTER TABLE public.dossiers_auditions ENABLE ROW LEVEL SECURITY;
-- LE PREMIER DES TROIS VERROUS, ET IL DOIT ETRE ECRIT. Voir l'en-tete : une table neuve nait
-- avec ALL accorde a anon et authenticated par le defaut de la plateforme.
REVOKE ALL ON TABLE public.dossiers_auditions FROM anon, authenticated;
CREATE INDEX IF NOT EXISTS dossiers_auditions_par_personne
  ON public.dossiers_auditions (personne, affaire);

COMMENT ON TABLE public.dossiers_auditions IS
  'LES PROCES-VERBAUX D''AUDITION. Un fait par dossier et par personne : ce qu''elle a declare, VERBATIM, ou son refus explicite de repondre. Le refus est une reponse procedurale valide -- ni aveu, ni faute, aucun malus. Aucune IA ne lit ce texte et le serveur n''en juge ni la credibilite ni la coherence. APPEND-ONLY par trois verrous : aucun GRANT client, aucune policy, et un declencheur qui refuse UPDATE et DELETE meme a service_role. C''est le PV qui fait courir le delai de jugement -- pas l''arrestation.';
COMMENT ON COLUMN public.dossiers_auditions.declaration IS
  'Le texte de la personne, tel qu''elle l''a ecrit. NULL quand elle a refuse de repondre.';
COMMENT ON COLUMN public.dossiers_auditions.refus IS
  'Refus explicite de repondre. C''est une REPONSE : la personne a accompli son audition, et la protection temporelle court comme avec une declaration.';
COMMENT ON COLUMN public.dossiers_auditions.jour_pv IS
  'Le jour de jeu ou le PV a ete realise. C''EST LUI LE POINT DE DEPART DU DELAI DE JUGEMENT, et non le jour de l''arrestation : une arrestation sans audition ne declenche aucune protection.';

CREATE OR REPLACE FUNCTION public.dossiers_auditions_append_only()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'dossiers_auditions est append-only : un proces-verbal ne se reecrit pas (% refuse)', TG_OP;
END;
$$;
COMMENT ON FUNCTION public.dossiers_auditions_append_only() IS
  'Le troisieme verrou de l''append-only des PV, et le seul qui tienne contre service_role et contre une fonction SECURITY DEFINER : les deux autres -- pas de GRANT, pas de policy -- ne ferment que les roles soumis a la RLS.';

DROP TRIGGER IF EXISTS trg_dossiers_auditions_append_only ON public.dossiers_auditions;
CREATE TRIGGER trg_dossiers_auditions_append_only
  BEFORE UPDATE OR DELETE ON public.dossiers_auditions
  FOR EACH ROW EXECUTE FUNCTION public.dossiers_auditions_append_only();

-- ============================================================================================
-- 5. LA PORTE DE L'AUDITION
-- ============================================================================================
-- LE DELAI EST UNE DONNEE DE GAME DESIGN, ECRITE UNE FOIS ICI : quinze jours de jeu a compter du
-- PV pour obtenir un jugement de PREMIERE INSTANCE.
CREATE OR REPLACE FUNCTION public.justice_delai_jugement_jours()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 15 $$;
COMMENT ON FUNCTION public.justice_delai_jugement_jours() IS
  'Le delai de jugement de PREMIERE INSTANCE, en jours de jeu, a compter du PV d''audition. Quinze. Une seule declaration pour tout le systeme : la porte qui ouvre le delai et celle qui le fait expirer lisent la meme.';

CREATE OR REPLACE FUNCTION public.pv_audition_realiser(
  p_affaire_id text, p_declaration text DEFAULT NULL, p_refus boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;
COMMENT ON FUNCTION public.pv_audition_realiser(text, text, boolean) IS
  'L''audition de la personne mise en cause, par elle-meme. Elle declare, ou elle refuse explicitement de repondre -- les deux sont des reponses, et le refus n''emporte aucun malus. LE PV FAIT COURIR LE DELAI DE JUGEMENT : c''est lui, et jamais l''arrestation. Il libere la detention d''AVANT JUGEMENT (arrestation d''urgence, garde a vue) et ne touche a aucune peine en cours d''execution. Une seule audition par dossier et par personne.';

REVOKE ALL ON FUNCTION public.pv_audition_realiser(text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pv_audition_realiser(text, text, boolean) TO authenticated;
REVOKE ALL ON FUNCTION public.affaire_infraction_de(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.justice_delai_jugement_jours() FROM PUBLIC;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LA TABLE EXISTE, SOUS RLS, SANS AUCUNE POLICY ET SANS AUCUN GRANT CLIENT.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'dossiers_auditions' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- dossiers_auditions absente ou sans RLS'; END IF;
  SELECT count(*) INTO v_n FROM pg_policy p
   WHERE p.polrelid = 'public.dossiers_auditions'::regclass;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % policy(s) sur dossiers_auditions', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid = 'public.dossiers_auditions'::regclass
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur dossiers_auditions', v_n; END IF;

  -- P2 : LE TROISIEME VERROU EST POSE, sur UPDATE ET sur DELETE. L'ASSERTION PORTE SUR LES DEUX
  -- MOTS ET NON SUR LEUR ORDRE : PostgreSQL normalise `BEFORE UPDATE OR DELETE` en
  -- « BEFORE DELETE OR UPDATE », et la premiere version de cette preuve a echoue dessus.
  SELECT count(*) INTO v_n FROM pg_trigger t
   WHERE t.tgrelid = 'public.dossiers_auditions'::regclass AND NOT t.tgisinternal
     AND t.tgname = 'trg_dossiers_auditions_append_only';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE -- declencheur append-only absent'; END IF;
  SELECT pg_get_triggerdef(t.oid) INTO v_txt FROM pg_trigger t
   WHERE t.tgrelid = 'public.dossiers_auditions'::regclass
     AND t.tgname = 'trg_dossiers_auditions_append_only';
  IF position(' UPDATE' IN v_txt) = 0 OR position(' DELETE' IN v_txt) = 0
     OR position('BEFORE' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le declencheur ne couvre pas UPDATE ET DELETE avant ecriture : %', v_txt; END IF;

  -- P3 : UN PV VIDE EST STRUCTURELLEMENT IMPOSSIBLE. La contrainte, pas la politesse de la porte.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conrelid = 'public.dossiers_auditions'::regclass
     AND conname = 'dossiers_auditions_declaration_ou_refus';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- la contrainte declaration-ou-refus manque'; END IF;

  -- P4 : UNE SEULE AUDITION PAR DOSSIER ET PAR PERSONNE, par contrainte.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conrelid = 'public.dossiers_auditions'::regclass
     AND conname = 'dossiers_auditions_un_pv_par_affaire_et_personne' AND contype = 'u';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- l''unicite du PV manque'; END IF;

  -- P5 : LES DEUX TYPES D'ACTES SONT AU REGISTRE, et l'accuse est un auteur reconnu.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types
   WHERE type IN ('pv_audition', 'charges_abandonnees_delai');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % type(s) d''acte neufs au lieu de 2', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types
   WHERE type = 'pv_audition' AND pose_par = 'accuse';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- le PV n''est pas pose par l''accuse'; END IF;

  -- P6 : LE DELAI EST DECLARE UNE SEULE FOIS, ET IL VAUT QUINZE.
  IF public.justice_delai_jugement_jours() <> 15 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- le delai de jugement ne vaut pas 15 jours'; END IF;

  -- P7 : LA PORTE DU PV LIT LE DELAI, elle ne le recopie pas.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'pv_audition_realiser';
  IF position('justice_delai_jugement_jours()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- la porte du PV recopie le delai au lieu de le lire'; END IF;

  -- P8 : LA LIBERATION EST BORNEE A LA DETENTION D'AVANT JUGEMENT. Assertion sur la liste
  -- EXACTE des deux issues : sans elle, un PV libererait un condamne en cours de peine.
  IF position('''arrestation_urgence'', ''garde_a_vue''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la liberation du PV n''est pas bornee aux detentions d''avant jugement'; END IF;

  -- P9 : L'INFRACTION CONSTATEE PASSE PAR LE CATALOGUE. Assertion sur l'APPEL, jamais sur le
  -- mot : le commentaire de la fonction explique precisement qu'un motif libre ne devient pas
  -- une qualification, et une assertion sur le mot passerait sur ce commentaire seul.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'affaire_transmettre';
  IF position('public.infraction_canonique(p_fait ->> ''infraction'')' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- l''infraction constatee ne passe pas par infraction_canonique'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'affaire_transmettre';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- % signature(s) d''affaire_transmettre au lieu d''une', v_n; END IF;

  -- P10 : L'ORDRE DE PRESEANCE DES TROIS QUALIFICATIONS EST A UN SEUL ENDROIT, et la categorie
  -- ALLEGUEE n'y figure pas -- une declaration de plaignant n'est pas une qualification.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'affaire_infraction_de';
  IF position('qualification_finale' IN v_txt) = 0
     OR position('qualification_parquet' IN v_txt) = 0
     OR position('infraction_constatee' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- les trois niveaux de qualification ne sont pas tous lus'; END IF;
  IF position('categorie_alleguee' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la categorie alleguee est lue comme une qualification'; END IF;

  RAISE NOTICE 'LES 10 PREUVES SONT VERTES.';
END $preuves$;
