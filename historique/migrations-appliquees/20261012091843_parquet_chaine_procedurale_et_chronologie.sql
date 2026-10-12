-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012091843 (UTC), nom
-- `parquet_chaine_procedurale_et_chronologie`.
-- Le registre passe de 672 a 673 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 de4c5fda7cafe1eb7566a9b35bde3a04, 35574 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (2/7) -- LA CHAINE PROCEDURALE ET LA CHRONOLOGIE APPEND-ONLY
--
-- LA CHAINE DEVIENT : plainte -> PARQUET -> (enquete) -> non-lieu OU poursuites -> saisine du
-- juge -> (abandon -> decision du juge) -> relaxe OU condamnation. Elle etait : plainte ->
-- COMMISSAIRE -> juge.
--
-- LA CHRONOLOGIE EST APPEND-ONLY A TROIS VERROUS : aucun GRANT client, aucune policy, et un
-- declencheur qui refuse tout UPDATE et tout DELETE -- y compris a service_role et aux fonctions
-- SECURITY DEFINER. Une chronologie qu'une porte pourrait reecrire ne serait pas une chronologie.
--
-- ET SES TYPES D'ACTES SONT UNE TABLE, PAS UNE CONTRAINTE CHECK. Les couches futures -- temoins,
-- audience, appel, execution de peine -- s'y ajoutent par une LIGNE, sans migration de
-- contrainte. C'est ce que le cahier des charges demandait pour ne pas refaire la table.
--
-- LA PRESENCE PHYSIQUE EST PORTEE PAR UNE GARDE UNIQUE, `parquet_garde`, que les cinq actes du
-- parquet appellent tous : aucun ne peut oublier une condition. Et le site competent n'est pas
-- recopie -- il est DERIVE de `villes.est_capitale`, parce que Luthecia a le batiment `tribunal`
-- et que les deux autres villes ont `tribunal-local`.
--
-- CETTE MIGRATION NE PORTE PAS DE BLOC DE PREUVES : son contenu est prouve par celui de la
-- migration 3/7, qui le verifie en meme temps que ses propres ajouts (P7 a P14).
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PARQUET DE REPUBLIA (2/2) -- LA CHAINE PROCEDURALE ET LA CHRONOLOGIE APPEND-ONLY
-- 12 octobre 2026
--
-- CE QUE CETTE MIGRATION REMPLACE. La chaine etait : plainte -> COMMISSAIRE -> juge. Le
-- commissaire decidait de l'opportunite des poursuites (`plainte_traiter` avec la decision
-- `classer`), et quand le commissaire de la ville etait un PNJ, `plainte_deposer` instruisait
-- IMMEDIATEMENT et automatiquement au depot -- jusqu'a ouvrir une garde a vue de deux jours. Le
-- Ministre de la Justice, de son cote, pouvait classer n'importe quelle plainte du pays par
-- `plainte_classer_ministere`.
--
-- LA CHAINE DEVIENT : plainte -> PARQUET -> (enquete) -> non-lieu OU poursuites -> saisine du
-- juge -> (abandon -> decision du juge) -> relaxe OU condamnation.
--
-- UNE SEULE AUTORITE PAR ETAPE, et c'est la regle qui a guide chaque suppression :
--   . l'opportunite des poursuites appartient au PROCUREUR, a lui seul ;
--   . les actes d'enquete appartiennent a la POLICE, mais sur ORDRE du parquet ;
--   . le jugement appartient au JUGE de la ville de l'affaire, a lui seul ;
--   . le Ministre de la Justice NOMME et REVOQUE le procureur, et rien d'autre.
--
-- TROIS PORTES PERDENT UNE AUTORITE :
--   . `plainte_classer_ministere` est SUPPRIMEE ;
--   . `plainte_traiter` perd la decision `classer` -- il ne reste au commissaire que l'execution
--     de l'enquete ordonnee, et elle n'est possible que sur un dossier ou le parquet l'a
--     diligentee ;
--   . `justice_rendre_sentence` exige desormais une SAISINE reguliere, et le JUGE de la ville --
--     plus le commissaire, qui pouvait juger parce que `affaire_autorite_de` les confond.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS : ni avocat, ni temoins, ni audience, ni appel, ni casier,
-- ni presse. La chronologie est concue pour les accueillir sans etre refaite -- ses types d'actes
-- sont une TABLE, pas une contrainte CHECK : une couche future ajoute une ligne.

-- ============================================================================================
-- 1. LES TYPES D'ACTES -- UN REGISTRE, PAS UNE CONTRAINTE
-- ============================================================================================
-- POURQUOI UNE TABLE ET PAS UN CHECK. Le cahier des charges demande que les couches futures
-- (temoignages, audience, appel, execution de peine) puissent s'ajouter SANS refaire la table.
-- Un CHECK imposerait une migration de contrainte a chaque couche ; un registre demande une
-- ligne. Meme idiome que `actes_nocturnes_mecanismes` et `subventions_familles`.
CREATE TABLE IF NOT EXISTS public.dossiers_judiciaires_actes_types (
  type      text PRIMARY KEY,
  libelle   text NOT NULL,
  -- Qui pose cet acte, pour que la chronologie soit relisible sans connaitre le code.
  pose_par  text NOT NULL CHECK (pose_par IN ('plaignant','police','parquet','juge','serveur')),
  note      text
);
COMMENT ON TABLE public.dossiers_judiciaires_actes_types IS
  'Liste blanche des actes qu''une chronologie judiciaire peut porter. Table et non contrainte CHECK : une couche future -- temoignages, audience, appel, execution de peine -- s''y ajoute par une ligne au lieu d''une migration de contrainte. Douze types au 12 octobre 2026, ceux de la chaine parquet.';

INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
  ('plainte_deposee',          'Plainte deposee',                              'plaignant',
   'La declaration d''un joueur. Le texte libre du plaignant est conserve sur le DOSSIER, pas recopie dans chaque acte.'),
  ('affaire_transmise_police', 'Affaire transmise par la police',               'police',
   'Un acte illegal decouvert et transmis au parquet par l''autorite judiciaire de la ville.'),
  ('enquete_diligentee',       'Enquete diligentee par le parquet',             'parquet', NULL),
  ('enquete_acte_police',      'Acte d''enquete accompli par la police',        'police',
   'Le parquet ordonne, la police accomplit. L''acte lui-meme reste celui qui existait.'),
  ('non_lieu',                 'Non-lieu prononce par le parquet',              'parquet',
   'Le parquet decide de ne pas poursuivre. Ne dit rien de la veracite de la plainte ni de l''innocence de la personne visee.'),
  ('poursuites_engagees',      'Poursuites engagees par le parquet',            'parquet',
   'Porte la qualification canonique retenue par le parquet.'),
  ('juge_saisi',               'Juge saisi',                                    'parquet', NULL),
  ('abandon_poursuites',       'Abandon des poursuites par le parquet',         'parquet', NULL),
  ('juge_arret_accepte',       'Le juge accepte l''arret de la procedure',      'juge',
   'Suite a un abandon du parquet apres saisine.'),
  ('juge_poursuite_maintenue', 'Le juge poursuit malgre l''abandon du parquet', 'juge',
   'Suite a un abandon du parquet apres saisine. Fait DISTINCT de l''abandon : les deux coexistent dans la chronologie.'),
  ('relaxe',                   'Relaxe prononcee',                              'juge',
   'Un verdict, pas une absence de peine.'),
  ('condamnation',             'Condamnation prononcee',                        'juge',
   'Porte la qualification finale et la peine validee par le bareme serveur.')
ON CONFLICT (type) DO UPDATE SET libelle = EXCLUDED.libelle,
  pose_par = EXCLUDED.pose_par, note = EXCLUDED.note;

-- ============================================================================================
-- 2. LA CHRONOLOGIE -- APPEND-ONLY, ET A TROIS VERROUS
-- ============================================================================================
-- `rang` donne l'ordre reel des actes sur une affaire, independamment de l'horloge : deux actes
-- posees dans la meme transaction partagent `now()`, donc un tri par date serait indecidable --
-- piege rencontre le 12 octobre 2026 au matin sur le banc universitaire.
--
-- `qualif_avant` / `qualif_apres` sont les DEUX colonnes qui rendent la requalification lisible
-- sans relire le dossier : elles referencent le catalogue canonique, donc elles ne peuvent pas
-- porter une infraction inventee.
CREATE TABLE IF NOT EXISTS public.dossiers_judiciaires_actes (
  id            text PRIMARY KEY,
  affaire       text NOT NULL,
  pays          text NOT NULL,
  ville         text,
  rang          integer NOT NULL CHECK (rang >= 1),
  type          text NOT NULL REFERENCES public.dossiers_judiciaires_actes_types(type),
  -- Le personnage qui a agi, et le POSTE au titre duquel il a agi. Les deux, parce qu'un meme
  -- joueur peut tenir un poste puis un autre : l'acte doit garder la qualite d'alors.
  acteur        text,
  acteur_poste  text,
  qualif_avant  text REFERENCES public.infractions(id),
  qualif_apres  text REFERENCES public.infractions(id),
  -- Strictement les donnees de l'acte. AUCUNE opinion, aucune interpretation, aucun resume.
  donnees       jsonb,
  fait_le       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dossiers_actes_un_rang_par_affaire UNIQUE (affaire, rang)
);
CREATE INDEX IF NOT EXISTS dossiers_actes_par_affaire
  ON public.dossiers_judiciaires_actes (affaire, rang);
COMMENT ON TABLE public.dossiers_judiciaires_actes IS
  'La chronologie procedurale d''un dossier judiciaire : des FAITS dates par le serveur, APPEND-ONLY. Trois verrous : aucun GRANT client, aucune policy, et un declencheur qui refuse tout UPDATE et tout DELETE. Elle n''enregistre jamais d''opinion, de credibilite, d''intention supposee ni de resume -- la presse et les joueurs interpreteront. `rang` donne l''ordre reel des actes, parce que deux actes de la meme transaction partagent now().';

-- LE DECLENCHEUR QUI REND LA TABLE APPEND-ONLY. Les GRANTs et la RLS protegent des clients ; ce
-- declencheur protege aussi des fonctions SECURITY DEFINER et de service_role. Une chronologie
-- qu'une porte serveur pourrait reecrire ne serait pas une chronologie.
CREATE OR REPLACE FUNCTION public.dossiers_actes_append_only()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'dossiers_judiciaires_actes est append-only : % refuse', TG_OP;
END;
$$;
DROP TRIGGER IF EXISTS trg_dossiers_actes_append_only ON public.dossiers_judiciaires_actes;
CREATE TRIGGER trg_dossiers_actes_append_only
  BEFORE UPDATE OR DELETE ON public.dossiers_judiciaires_actes
  FOR EACH ROW EXECUTE FUNCTION public.dossiers_actes_append_only();

ALTER TABLE public.dossiers_judiciaires_actes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dossiers_judiciaires_actes_types ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.dossiers_judiciaires_actes       FROM anon, authenticated;
REVOKE ALL ON public.dossiers_judiciaires_actes_types FROM anon, authenticated;

-- ============================================================================================
-- 3. CONSIGNER UN ACTE -- PORTE INTERNE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.dossier_acte_consigner(
  p_affaire text, p_pays text, p_ville text, p_type text,
  p_acteur text DEFAULT NULL, p_acteur_poste text DEFAULT NULL,
  p_qualif_avant text DEFAULT NULL, p_qualif_apres text DEFAULT NULL,
  p_donnees jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_rang integer; v_id text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types t WHERE t.type = p_type) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_acte_inconnu', 'type', p_type);
  END IF;
  -- LE RANG EST CALCULE SOUS VERROU DE LA LIGNE SUIVANTE. La contrainte UNIQUE (affaire, rang)
  -- fait le reste : deux actes simultanes sur la meme affaire ne peuvent pas partager un rang.
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
$$;
COMMENT ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) IS
  'Ajoute un acte a la chronologie d''un dossier. INTERNE : aucun client ne l''appelle, sinon un navigateur pourrait fabriquer un fait procedural. Le type est valide contre la liste blanche, le rang calcule par le serveur.';

-- ============================================================================================
-- 4. LE SITE COMPETENT, ET LA PRESENCE PHYSIQUE
-- ============================================================================================
-- DEUX TRIBUNAUX DIFFERENTS, ET CE N'EST PAS UN DETAIL. Luthecia a le batiment `tribunal` ;
-- Port-Sainte-Marie et Montrouge ont `tribunal-local`, qui n'a qu'une piece. La competence
-- territoriale se lit donc en deux temps : la ville de l'affaire, puis le batiment que cette
-- ville possede. `villes.est_capitale` est la source -- pas une liste recopiee ici.
CREATE OR REPLACE FUNCTION public.parquet_site_competent(p_pays text, p_ville text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN v.est_capitale THEN 'tribunal' ELSE 'tribunal-local' END
    FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville;
$$;
COMMENT ON FUNCTION public.parquet_site_competent(text, text) IS
  'Le batiment ou siege la justice d''une ville : `tribunal` dans la capitale, `tribunal-local` ailleurs. Lu depuis le referentiel villes, jamais recopie -- une ville inconnue rend NULL, donc fail closed.';

-- ============================================================================================
-- 5. QUI EST LE PROCUREUR, ET QUI EST LE JUGE
-- ============================================================================================
-- LE PROCUREUR EST NATIONAL : aucune ville n'entre dans cette question. Le poste porte par la
-- fiche est deja atteste par declencheur, donc on peut s'y fier.
CREATE OR REPLACE FUNCTION public.parquet_moi()
RETURNS TABLE(nom text, pays text) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT d.name, d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'procureur'
   LIMIT 1;
$$;
COMMENT ON FUNCTION public.parquet_moi() IS
  'Rend le Procureur en exercice s''il s''agit de l''appelant, rien sinon. Le poste est national : aucune ville n''entre dans la question. Le `poste` de la fiche est atteste par trg_personnages_attester_poste, donc il ne peut pas etre auto-declare.';

-- LE JUGE DE LA VILLE, ET LUI SEUL. `affaire_autorite_de` confond juge et COMMISSAIRE -- c'est la
-- regle de la policy de lecture, ou l'acces du commissaire a une affaire de sa ville est
-- legitime. Mais JUGER n'a jamais ete son office, et avec le parquet il n'a plus rien a decider
-- sur l'opportunite non plus. Les portes du jugement passent donc par cette fonction-ci.
CREATE OR REPLACE FUNCTION public.juge_de_la_ville(p_ville text)
RETURNS TABLE(nom text, pays text) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT d.name, d.country FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge'
     AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_ville, 'capitale')
   LIMIT 1;
$$;
COMMENT ON FUNCTION public.juge_de_la_ville(text) IS
  'Rend le JUGE de la ville donnee s''il s''agit de l''appelant. A ne pas confondre avec affaire_autorite_de, qui accepte aussi le commissaire : celle-la sert la lecture des dossiers, celle-ci le jugement.';

-- ============================================================================================
-- 6. LA GARDE COMMUNE DES ACTES DU PARQUET
-- ============================================================================================
-- Une seule fonction porte TOUTES les conditions d'un acte du parquet sur un dossier : identite,
-- poste, pays, statut attendu, et PRESENCE PHYSIQUE dans le tribunal de la ville competente.
-- Les cinq portes du parquet l'appellent, donc aucune ne peut oublier une condition.
CREATE OR REPLACE FUNCTION public.parquet_garde(p_affaire_id text, p_statuts text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  -- LA PRESENCE PHYSIQUE. Le poste est national, l'ACTE est local : le Procureur doit etre dans
  -- le tribunal de la ville de l'affaire. La piece n'est pas exigee -- le tribunal de la capitale
  -- en a plusieurs, celui des villes une seule.
  v_site := public.parquet_site_competent(v_pays, v_ville);
  IF v_site IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_inconnue', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site, NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_requise',
                              'ville', v_ville, 'site', v_site);
  END IF;

  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom, 'pays', v_pays,
                            'ville', v_ville, 'affaire', v_a);
END;
$$;
COMMENT ON FUNCTION public.parquet_garde(text, text[]) IS
  'TOUTES les conditions d''un acte du parquet sur un dossier, en une seule fonction : etre le Procureur en exercice, le pays, le statut procedural attendu, et la PRESENCE PHYSIQUE dans le tribunal de la ville competente. Les cinq portes du parquet l''appellent, donc aucune ne peut oublier une condition.';

-- ============================================================================================
-- 7. LES DOSSIERS DU PARQUET -- LECTURE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.parquet_dossiers()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;
COMMENT ON FUNCTION public.parquet_dossiers() IS
  'Les dossiers du pays qui relevent encore du parquet, avec leur chronologie et un drapeau de PRESENCE par dossier -- l''ecran sait donc avant le clic sur quelle affaire le Procureur peut agir d''ou il se tient. Lecture seule, reservee au Procureur en exercice.';

-- ============================================================================================
-- 8. DILIGENTER UNE ENQUETE
-- ============================================================================================
-- LE PARQUET ORDONNE, LA POLICE ACCOMPLIT. Cette porte ne fait AUCUN acte d'enquete : elle pose
-- l'ordre. L'acte lui-meme reste `plainte_traiter` cote commissaire, qui n'est desormais
-- possible que sur un dossier portant cet ordre.
CREATE OR REPLACE FUNCTION public.parquet_enqueter(p_affaire_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['au_parquet']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'enquete',
           'enquete_par', v_g ->> 'procureur',
           'enquete_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'enquete_diligentee', v_g ->> 'procureur', 'procureur');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'enquete');
END;
$$;

-- ============================================================================================
-- 9. LE NON-LIEU
-- ============================================================================================
-- Possible SANS enquete prealable, et aussi apres. C'est la seule facon de ne pas imposer au
-- parquet une enquete qu'il ne juge pas utile.
CREATE OR REPLACE FUNCTION public.parquet_non_lieu(p_affaire_id text, p_motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_motif text;
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
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'non_lieu', v_g ->> 'procureur', 'procureur', NULL, NULL,
    CASE WHEN v_motif IS NULL THEN NULL
         ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'non_lieu');
END;
$$;
COMMENT ON FUNCTION public.parquet_non_lieu(text, text) IS
  'Le parquet decide de ne pas poursuivre. Possible SANS enquete prealable. Le serveur enregistre la DECISION, jamais une conclusion sur les faits : un non-lieu ne dit ni que la plainte etait mensongere, ni que la personne visee est innocente. Le motif eventuel est le texte du Procureur, conserve comme declaration.';

-- ============================================================================================
-- 10. ENGAGER LES POURSUITES -- LA QUALIFICATION DU PARQUET
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.parquet_poursuivre(p_affaire_id text, p_infraction text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_inf text; v_lib text;
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
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'poursuites_engagees', v_g ->> 'procureur', 'procureur', NULL, v_inf,
    jsonb_build_object('accuse', v_a ->> 'cible',
                       'categorie_alleguee', v_a ->> 'categorie_alleguee'));
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'poursuites',
                            'qualification', v_inf, 'libelle', v_lib);
END;
$$;
COMMENT ON FUNCTION public.parquet_poursuivre(text, text) IS
  'Le parquet engage les poursuites sous une infraction CANONIQUE, qu''il choisit et qui peut differer de la categorie alleguee par le plaignant. La qualification est validee contre le catalogue : un identifiant invente, ou un nom de categorie generique, est refuse. Fait serveur date, consigne a la chronologie.';

-- ============================================================================================
-- 11. SAISIR LE JUGE
-- ============================================================================================
-- ACTE DISTINCT DES POURSUITES, et c'est ce qui donne un sens a l'abandon : tant que le juge
-- n'est pas saisi, le parquet est seul maitre de la procedure ; apres, il ne l'est plus.
CREATE OR REPLACE FUNCTION public.parquet_transmettre_juge(p_affaire_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb;
BEGIN
  v_g := public.parquet_garde(p_affaire_id, ARRAY['poursuites']);
  IF coalesce((v_g ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_g; END IF;
  v_a := v_g -> 'affaire';

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'saisie',
           'saisine_par', v_g ->> 'procureur',
           'saisine_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'juge_saisi', v_g ->> 'procureur', 'procureur', NULL, v_a ->> 'qualification_parquet');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'saisie');
END;
$$;

-- ============================================================================================
-- 12. ABANDONNER LES POURSUITES
-- ============================================================================================
-- DEUX ISSUES, SELON QUE LE JUGE EST SAISI OU NON, et la difference est tout l'interet de la
-- regle : avant la saisine l'abandon TERMINE la procedure ; apres, il ne fait qu'ouvrir une
-- question que le juge tranchera. L'abandon n'est JAMAIS une suppression du dossier.
CREATE OR REPLACE FUNCTION public.parquet_abandonner(p_affaire_id text, p_motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_g jsonb; v_a jsonb; v_avant text; v_apres text; v_motif text;
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
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_g ->> 'pays', v_g ->> 'ville',
    'abandon_poursuites', v_g ->> 'procureur', 'procureur', NULL, NULL,
    jsonb_build_object('apres_saisine', (v_avant = 'saisie'))
      || CASE WHEN v_motif IS NULL THEN '{}'::jsonb
              ELSE jsonb_build_object('motif_declare', v_motif) END);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', v_apres,
                            'apres_saisine', (v_avant = 'saisie'));
END;
$$;
COMMENT ON FUNCTION public.parquet_abandonner(text, text) IS
  'Le parquet abandonne les poursuites. AVANT la saisine du juge, la procedure s''arrete (statut abandonnee). APRES, l''abandon n''y met pas fin : il ouvre une question (statut abandon_demande) que le juge tranchera par juge_suite_apres_abandon. Les deux actes restent DISTINCTS dans la chronologie, et le dossier n''est jamais supprime.';

-- ============================================================================================
-- 13. LE JUGE DECIDE APRES UN ABANDON
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.juge_suite_apres_abandon(p_affaire_id text, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_statut text; v_type text;
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

  v_statut := CASE WHEN p_decision = 'arret' THEN 'arret' ELSE 'saisie' END;
  v_type := CASE WHEN p_decision = 'arret' THEN 'juge_arret_accepte'
                 ELSE 'juge_poursuite_maintenue' END;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', v_statut,
           'suite_abandon_par', v_j.nom,
           'suite_abandon_decision', p_decision,
           'suite_abandon_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, v_type, v_j.nom, 'juge');
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'decision', p_decision, 'statut', v_statut);
END;
$$;
COMMENT ON FUNCTION public.juge_suite_apres_abandon(text, text) IS
  'Apres un abandon du parquet sur une affaire DEJA SAISIE, le juge accepte l''arret ou poursuit la procedure. Deux faits serveur distincts (juge_arret_accepte / juge_poursuite_maintenue), consignes a cote de l''abandon et jamais fusionnes avec lui. Reserve au juge de la ville de l''affaire.';

-- ============================================================================================
-- 14. LA RELAXE -- UN VERDICT, PAS UNE ABSENCE DE PEINE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_relaxer(p_affaire_id text, p_infraction text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;
COMMENT ON FUNCTION public.justice_relaxer(text, text) IS
  'La relaxe : un VERDICT structure, pas une peine de zero ni une suppression de dossier. Elle a sa ligne au registre des jugements avec `peine` NULL et `data.verdict = relaxe`. Elle porte une qualification -- on relaxe DE quelque chose -- par defaut celle du parquet, que le juge peut requalifier avant, auquel cas la requalification est un acte distinct de la chronologie.';
