-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012154250 (UTC), nom
-- `tribunal_procedure_simplifiee_rend_son_jugement`.
-- Le registre passe de 689 a 690 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 83e01993423fc82260d7877e04a06654, 30404 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA PROCEDURE SIMPLIFIEE REND SON JUGEMENT -- FIN DE §A
--
-- IL MANQUAIT DEUX VALEURS, PAS DU CODE, et les deux sont arbitrees : le CHA des trois avocats
-- commis d'office (16, le meme dans les trois villes, donc +15 points) et l'operation qui le
-- combine a celui du prevenu. La formule vit desormais dans UNE fonction :
--     50 + (CHA_avocat - 13) * 5 + (CHA_prevenu - 13) * 3 - 35 si une preuve reelle existe,
--   bornee a [5 %, 80 %].
--
-- LE NAVIGATEUR NE DECIDE PLUS D'UNE PEINE. L'ancienne signature `plainte_defendre(text, text)`
-- -- celle qui acceptait une issue ANNONCEE par le client -- a ete SUPPRIMEE, pas remplacee.
--
-- « PREUVE REELLE » NE SE DEDUIT PLUS D'UN TEXTE. Le client cherchait le mot « tortur » dans le
-- motif de la plainte ; la preuve est maintenant la TRACE OBJECTIVE que le moteur a ecrite quand
-- l'acte a eu lieu -- `actions_tracables`, au nom de l'accuse, du type de l'infraction retenue,
-- non expiree sur l'horloge de l'accuse.
--
-- UNE RELAXE EST UN VRAI JUGEMENT. L'ancienne « reussite critique » posait `status = 'jugee'`
-- sans jugement : une relaxe sans trace ni ligne au registre. Les trois issues produisent
-- desormais une ligne de `jugements` -- `peine` NULL pour la relaxe, la peine du catalogue sinon
-- -- et la detention s'ouvre dans la porte elle-meme.
--
-- LA PART DE RELAXE EST LA SEULE VALEUR A CONFIRMER : `justice_defense_part_relaxe()` vaut 50.
-- Avec le plancher carceral d'un jour et un seuil de procedure a 2 jours, `jours_min` vaut
-- TOUJOURS 1 : la plage « entre -50 % et la relaxe » ne contient que les deux issues que le
-- cahier des charges enumere en a) et b), et un tirage uniforme entre deux issues nommees vaut
-- 50/50. La changer est une ligne.
--
-- EPROUVEE PAR outils/bancs/banc-defense-simplifiee.sql -- 22 epreuves, transaction annulee.
--
-- PREUVES STRUCTURELLES -- 12.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA PROCEDURE SIMPLIFIEE REND SON JUGEMENT
-- 12 octobre 2026 -- fin de §A du cahier des charges du Tribunal
--
-- CE QUI MANQUAIT, ET CE N'ETAIT PAS DU CODE. « Se defendre » verifiait son domaine au serveur
-- depuis la tranche precedente, mais le JET et l'ISSUE restaient au navigateur : il calculait un
-- taux depuis `getStatEffective('CHA')` -- qui agrege la moyenne du groupe de compagnons et la
-- fraction de PV sur les caracteristiques affaiblies, deux notions purement clientes -- puis
-- annoncait au serveur laquelle des quatre issues etait survenue. Le navigateur decidait donc
-- d'une peine. Il manquait DEUX VALEURS pour fermer : le CHA des avocats commis d'office, et
-- l'operation exacte entre ce CHA et celui du prevenu. Les deux sont arbitrees ; cette migration
-- ne fait que les poser et deplacer la decision.
--
-- LA FORMULE, TELLE QU'ARBITREE, et elle vit dans UNE seule fonction :
--     50 + (CHA_avocat - 13) * 5 + (CHA_prevenu - 13) * 3 - 35 si une preuve reelle existe
--   bornee a [5 %, 80 %]. Avec un avocat a CHA 16, sa contribution vaut +15 points, identique
--   dans les trois villes -- c'est l'egalite mecanique demandee.
--
-- LE CHA DU PREVENU EST CELUI DE SA FICHE, plus les modificateurs INDIVIDUELS que le serveur
-- connait deja -- l'excommunication et son -2 CHA, ecrite dans `personnages_donnees.excommunie`.
-- Sont EXCLUS, sur consigne : le groupe et les compagnons, la moyenne de groupe,
-- l'affaiblissement lie aux PV, et toute valeur calculee par le navigateur.
--
-- « PREUVE REELLE » NE SE DEDUIT PLUS D'UN TEXTE. Le navigateur cherchait le mot « tortur » dans
-- le MOTIF de la plainte -- une chaine libre -- avant d'aller voir s'il existait une action
-- tracable. Fabriquer une preuve depuis du texte est exactement ce qu'il ne faut pas faire : la
-- preuve est desormais la TRACE OBJECTIVE que le moteur a ecrite quand l'acte a eu lieu, une
-- ligne de `actions_tracables` au nom de l'accuse, du TYPE de l'infraction retenue au dossier, et
-- non encore expiree. Rien n'est cree, rien n'est interprete.
--
-- LA PEINE N'EST PLUS UN STATUT POSE A LA MAIN. L'ancienne « reussite critique » ecrivait
-- `status = 'jugee'` sans jugement : une relaxe sans trace, sans ligne au registre, invisible du
-- greffe. Les trois issues possibles produisent desormais un VRAI jugement :
--   . ECHEC            -> la peine de REFERENCE du catalogue, immediatement executoire (la
--                         detention s'ouvre ici), definitive, et l'appel reste ferme ;
--   . REUSSITE, -50 %  -> les bornes basses du catalogue : `jours_min`, qui porte deja le plancher
--                         carceral incompressible d'un jour, et `amende_min`, qui n'en a pas ;
--   . REUSSITE, RELAXE -> un jugement a `peine` NULL -- la difference entre « relaxe » et
--                         « condamne a rien » -- et le statut `relaxe`.
--
-- L'APPEL RESTE FERME SANS UNE LIGNE DE PLUS : `justice_appel_ouvrir` refuse deja
-- `appel_exclu_procedure_simplifiee` des que le dossier porte `procedure_simplifiee`.
--
-- LA PART DE RELAXE EST UNE CONSTANTE NOMMEE, ET C'EST UN POINT A CONFIRMER. Le resultat d'une
-- reussite doit etre tire « entre -50 % et la relaxe ». Avec le plancher d'un jour et un seuil de
-- procedure a 2 jours de reference, `jours_min` vaut TOUJOURS 1 : la plage ne contient donc que
-- DEUX issues atteignables, celles que le cahier des charges enumere lui-meme en a) et b). Un
-- tirage uniforme entre deux issues nommees vaut 50/50, et c'est la seule lecture sans parametre
-- libre -- un tirage continu sur la reduction rendrait la relaxe impossible (probabilite nulle
-- d'atteindre exactement 100 %). La valeur vit seule dans `justice_defense_part_relaxe()` : la
-- changer est une ligne.
--
-- PREUVES STRUCTURELLES -- 12.

-- ============================================================================================
-- 1. LES TROIS AVOCATS COMMIS D'OFFICE ONT UNE EFFICACITE, ET ELLE EST LA MEME
-- ============================================================================================
-- Un registre, pas un CASE dans une fonction : la quatrieme ville, ou le deuxieme empire,
-- s'ajoutent par une ligne. Les trois avocats existaient depuis la tranche precedente comme PNJ
-- de DECOR, sans aucune caracteristique ; c'est ici qu'ils en recoivent une, et une seule.
CREATE TABLE IF NOT EXISTS public.justice_avocats_commis (
  pays  text    NOT NULL,
  ville text    NOT NULL,
  nom   text    NOT NULL,
  cha   integer NOT NULL,
  CONSTRAINT justice_avocats_commis_pk PRIMARY KEY (pays, ville),
  CONSTRAINT justice_avocats_commis_cha_plage CHECK (cha BETWEEN 1 AND 20)
);

-- UNE TABLE NEUVE NAIT OUVERTE AUX ROLES CLIENTS : `ALTER DEFAULT PRIVILEGES` de la plateforme
-- accorde ALL a `anon` et `authenticated` sur toute table creee dans `public`. On referme, et la
-- preuve P1 le compte.
REVOKE ALL ON TABLE public.justice_avocats_commis FROM anon, authenticated;
ALTER TABLE public.justice_avocats_commis ENABLE ROW LEVEL SECURITY;

INSERT INTO public.justice_avocats_commis (pays, ville, nom, cha) VALUES
  ('republic', 'capitale', 'Maître Plaidoyer (PNJ)',        16),
  ('republic', 'ville_a',  'Maître Ali Bihanbéton (PNJ)',   16),
  ('republic', 'ville_b',  'Maître Henri Nossant (PNJ)',    16)
ON CONFLICT (pays, ville) DO UPDATE SET nom = EXCLUDED.nom, cha = EXCLUDED.cha;

CREATE OR REPLACE FUNCTION public.justice_avocat_commis(p_pays text, p_ville text)
RETURNS TABLE (nom text, cha integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT a.nom, a.cha FROM public.justice_avocats_commis a
   WHERE a.pays = p_pays AND a.ville = p_ville;
$$;
COMMENT ON FUNCTION public.justice_avocat_commis(text, text) IS
  'Avocat commis d''office de la ville, et son CHA. Ferme par defaut : une ville sans avocat ferme la procedure simplifiee.';

-- ============================================================================================
-- 2. LE CHA PERSONNEL DU PREVENU, CALCULE AU SERVEUR
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_cha_personnel(p_nom text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT greatest(1,
           coalesce((d.stats ->> 'CHA')::integer, 8)
           -- Excommunication : -2 CHA, reversible, deja ecrite au serveur
           -- (`personnages_donnees.excommunie`, JSONB nullable). Elle n'est PAS une notion
           -- cliente : elle est posee et levee par la carriere religieuse.
           + CASE WHEN d.excommunie IS NOT NULL
                   AND jsonb_typeof(d.excommunie) <> 'null' THEN -2 ELSE 0 END)
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$$;
COMMENT ON FUNCTION public.justice_cha_personnel(text) IS
  'CHA de la fiche + modificateurs INDIVIDUELS serveur-autoritaires. Exclut le groupe, la moyenne de groupe et l''affaiblissement lie aux PV.';

-- ============================================================================================
-- 3. LA PREUVE REELLE EST UNE TRACE, PAS UN MOT DANS UNE PHRASE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_preuve_reelle(p_pays text, p_accuse text, p_infraction text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
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
$$;
COMMENT ON FUNCTION public.justice_preuve_reelle(text, text, text) IS
  'Vrai si le moteur a ecrit une action tracable non expiree, au nom de l''accuse, du type de l''infraction retenue. Aucune lecture de texte libre, aucune interpretation.';

-- ============================================================================================
-- 4. LA FORMULE, ET ELLE N'EXISTE QU'ICI
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_defense_taux(
  p_cha_avocat integer, p_cha_prevenu integer, p_preuve_reelle boolean)
RETURNS integer
LANGUAGE sql IMMUTABLE
AS $$
  SELECT greatest(5, least(80,
    50 + (coalesce(p_cha_avocat, 13) - 13) * 5
       + (coalesce(p_cha_prevenu, 13) - 13) * 3
       - CASE WHEN coalesce(p_preuve_reelle, false) THEN 35 ELSE 0 END));
$$;
COMMENT ON FUNCTION public.justice_defense_taux(integer, integer, boolean) IS
  'Chance de reussite de la procedure simplifiee, en pourcentage, bornee a [5, 80].';

CREATE OR REPLACE FUNCTION public.justice_defense_part_relaxe()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 50 $$;
COMMENT ON FUNCTION public.justice_defense_part_relaxe() IS
  'Part de relaxe, en pourcentage, dans une defense reussie. L''autre part est la borne basse du catalogue (-50 %, plancher d''un jour). A CONFIRMER par le game design : c''est la seule valeur de cette tranche qui ne se derive pas d''une regle deja arbitree.';

-- ============================================================================================
-- 5. LE TRIBUNAL QUI PRONONCE, QU'IL SOIT TENU PAR UN PJ OU PAR UN PNJ
-- ============================================================================================
-- Une procedure simplifiee se plaide DEVANT LE TRIBUNAL de la ville : le jugement a un auteur, et
-- cet auteur est le titulaire du poste de juge -- le PJ s'il y en a un, le PNJ sinon. Ferme par
-- defaut : sans tribunal, pas de jugement expeditif.
CREATE OR REPLACE FUNCTION public.justice_juge_titulaire(p_pays text, p_ville text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(
    (SELECT d.name FROM public.personnages_donnees d
      WHERE d.country = p_pays AND (d.poste ->> 'id') = 'juge'
        AND (d.poste ->> 'city') IS NOT DISTINCT FROM p_ville LIMIT 1),
    (SELECT t.nom_pnj FROM public.titulaires_pnj t
      WHERE t.country = p_pays AND t.poste_id = 'juge'
        AND t.city IS NOT DISTINCT FROM p_ville LIMIT 1));
$$;
COMMENT ON FUNCTION public.justice_juge_titulaire(text, text) IS
  'Titulaire du poste de juge de la ville : le PJ atteste d''abord, le PNJ du casting ensuite.';

-- ============================================================================================
-- 6. « SE DEFENDRE » : LE JET, LA DECISION ET LA PEINE PASSENT AU SERVEUR
-- ============================================================================================
-- LA SIGNATURE CHANGE, DONC ON SUPPRIME. `CREATE OR REPLACE` avec une autre liste de parametres
-- creerait une SURCHARGE : les deux versions cohabiteraient et le navigateur pourrait choisir
-- l'ancienne, celle qui accepte une issue annoncee. Elle doit DISPARAITRE.
DROP FUNCTION IF EXISTS public.plainte_defendre(text, text);

CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
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
END $fn$;

COMMENT ON FUNCTION public.plainte_defendre(text) IS
  'Procedure simplifiee : le serveur tire, decide et prononce. Echec = peine de reference immediatement executoire ; reussite = relaxe ou borne basse du catalogue. Definitive, sans appel.';

GRANT EXECUTE ON FUNCTION public.plainte_defendre(text) TO authenticated;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text; v_t integer;
BEGIN
  -- P1 : LA TABLE DES AVOCATS N'EST PAS LISIBLE PAR LES CLIENTS.
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid = 'public.justice_avocats_commis'::regclass
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur justice_avocats_commis', v_n; END IF;

  -- P2 : LES TROIS AVOCATS EXISTENT, ET ILS ONT TOUS CHA 16.
  SELECT count(*) INTO v_n FROM public.justice_avocats_commis WHERE pays = 'republic' AND cha = 16;
  IF v_n <> 3 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % avocat(s) a CHA 16 en Republia, 3 attendus', v_n; END IF;
  SELECT count(DISTINCT cha) INTO v_n FROM public.justice_avocats_commis WHERE pays = 'republic';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE -- les avocats n''ont pas la meme efficacite'; END IF;

  -- P3 : LA FORMULE EST EXACTE. 50 + (16-13)*5 + (13-13)*3 = 65 sans preuve ; 30 avec.
  IF public.justice_defense_taux(16, 13, false) <> 65 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- taux(16,13,faux) = %, 65 attendu', public.justice_defense_taux(16, 13, false); END IF;
  IF public.justice_defense_taux(16, 13, true) <> 30 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le malus de preuve reelle ne vaut pas 35 points'; END IF;
  IF public.justice_defense_taux(16, 16, false) <> 74 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le CHA du prevenu ne pese pas 3 points'; END IF;

  -- P4 : LES DEUX BORNES TIENNENT. 5 % en bas, 80 % en haut.
  IF public.justice_defense_taux(1, 1, true) <> 5 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la borne basse n''est pas 5 %%'; END IF;
  IF public.justice_defense_taux(20, 20, false) <> 80 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la borne haute n''est pas 80 %%'; END IF;

  -- P5 : LA PORTE N'ACCEPTE PLUS D'ISSUE ANNONCEE. L'ancienne signature a DISPARU.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % signature(s) de plainte_defendre, 1 attendue', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre' AND p.pronargs = 1;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- plainte_defendre prend encore une issue'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';

  -- P6 : LE JET EST AU SERVEUR, et il porte sur le taux calcule ici.
  IF position('public.justice_defense_taux(v_av.cha, v_cha, v_preuve)' IN v_txt) = 0
     OR position('floor(random() * 100)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- le jet n''est pas tire au serveur'; END IF;

  -- P7 : LE CHA DU PREVENU EST LE CHA PERSONNEL SERVEUR, et aucune notion de groupe n'apparait.
  IF position('public.justice_cha_personnel(v_nom)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le CHA du prevenu ne vient pas de la porte serveur'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_cha_personnel';
  IF position('compagnon' IN lower(v_txt)) > 0 OR position('groupe' IN lower(v_txt)) > 0
     OR position('moyenne' IN lower(v_txt)) > 0 OR position('affaibli' IN lower(v_txt)) > 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le CHA personnel agrege une notion exclue'; END IF;
  IF position('excommunie' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- l''excommunication ne pese plus sur le CHA'; END IF;

  -- P8 : LA PREUVE REELLE NE LIT AUCUN TEXTE LIBRE. Ni motif, ni mot-cle.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_preuve_reelle';
  IF position('motif' IN lower(v_txt)) > 0 OR position('tortur' IN lower(v_txt)) > 0
     OR position('ilike' IN lower(v_txt)) > 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la preuve reelle se deduit encore d''un texte'; END IF;
  IF position('public.actions_tracables' IN v_txt) = 0
     OR position('t.type_action = p_infraction' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la preuve reelle ne repose pas sur la trace objective'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';

  -- P9 : LES DEUX CRITERES DU DOMAINE SONT TOUJOURS LA.
  IF position('''procedure_simplifiee_reservee_aux_peines_courtes''' IN v_txt) = 0
     OR position('''procedure_simplifiee_exclut_les_crimes''' IN v_txt) = 0
     OR position('v_i.categorie IS NULL OR v_i.categorie = ''crime''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le domaine de la procedure simplifiee a bouge'; END IF;

  -- P10 : UNE RELAXE EST UN VRAI JUGEMENT, pas un statut. La ligne au registre existe, avec une
  -- peine NULL, et le statut `relaxe` l'accompagne.
  IF position('INSERT INTO public.jugements' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la procedure simplifiee ne produit aucun jugement'; END IF;
  IF position('WHEN v_relaxe THEN NULL' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la relaxe n''a pas une peine NULL'; END IF;
  IF position('CASE WHEN v_relaxe THEN ''relaxe'' ELSE ''jugee'' END' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la relaxe n''a pas son statut'; END IF;

  -- P11 : LA PEINE EST IMMEDIATEMENT EXECUTOIRE, et l'effet est RELU en base.
  IF position('public.detention_ouvrir_interne(' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- la peine n''est pas immediatement executoire'; END IF;
  IF position('''statut_non_applique''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- l''ecriture n''est pas relue en base'; END IF;

  -- P12 : L'APPEL RESTE FERME. La porte pose `procedure_simplifiee`, et `justice_appel_ouvrir`
  -- refuse dessus. Les deux moities, verifiees ensemble.
  IF position('''procedure_simplifiee'', true' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le dossier ne porte pas la marque de la procedure simplifiee'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_appel_ouvrir';
  IF position('''appel_exclu_procedure_simplifiee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- l''appel ne refuse plus la procedure simplifiee'; END IF;

  RAISE NOTICE 'LES 12 PREUVES SONT VERTES.';
END $preuves$;
