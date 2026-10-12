-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012205443 (UTC), nom
-- `universite_delivre_une_seconde_carriere_pas_un_diplome`.
-- Le registre passe de 697 a 698 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6e98aefc06a75acd09a3ea1b26be3c39, 16962 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'UNIVERSITE DELIVRE UNE SECONDE CARRIERE, PAS UNE COLLECTION DE DIPLOMES
--
-- CE QUI ETAIT FAUX, ET C'ETAIT LE VOCABULAIRE AVANT D'ETRE LE MODELE. Le socle du matin parlait
-- de « qualification supplementaire » et ecrivait dans `personnages_qualifications`, une table a
-- cle primaire (personnage, qualification) : elle peut donc porter autant de lignes qu'on veut.
-- La borne « une seule » n'etait qu'un index unique partiel -- vrai, mais place sur une table
-- dont la forme dit l'inverse, et dont le nom promet une collection.
--
-- LE SLOT DEMENAGE DANS `carrieres_acquises`, DONT LA CLE PRIMAIRE EST LE PERSONNAGE. La borne
-- n'est plus une condition dans un corps de fonction ni un index a lire de travers : c'est la
-- forme meme de la table.
--
-- RIEN N'EST DETRUIT : les quatre tables de l'Universite etaient VIDES (releve avant la
-- migration), donc le renommage de `qualification` en `carriere` n'a aucune ligne a convertir.
-- `personnages_qualifications` et `qualifications` SURVIVENT -- elles portent l'autre axe, celui
-- des qualifications de metier -- mais leur `source` ne peut plus valoir 'universite'.
--
-- LES REGLES DE CURSUS NE BOUGENT PAS : un seul cursus actif, echeance au double de la duree
-- theorique, pas d'acceleration, jalons hebdomadaires, la reussite consomme le slot, l'abandon et
-- l'expiration ne le consomment pas. LES CATALOGUES RESTENT VIDES.
--
-- PREUVES STRUCTURELLES -- 12.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'UNIVERSITE DELIVRE UNE SECONDE CARRIERE, PAS UNE COLLECTION DE DIPLOMES
-- 12 octobre 2026, nuit -- lot 3
--
-- CE QUI ETAIT FAUX, ET C'ETAIT LE VOCABULAIRE AVANT D'ETRE LE MODELE. Le socle du 12 octobre au
-- matin parlait de « qualification supplementaire » et ecrivait dans
-- `personnages_qualifications`, une table a cle primaire (personnage, qualification) : elle peut
-- donc porter AUTANT DE LIGNES QU'ON VEUT par personnage. La borne « une seule » n'etait qu'un
-- INDEX UNIQUE PARTIEL sur `source = 'universite'` -- vrai, mais place sur une table dont la
-- forme dit l'inverse, et dont le nom promet une collection.
--
-- LA REGLE REELLE : un personnage a UNE carriere initiale et AU MAXIMUM UNE seconde, acquise a
-- l'Universite, pour toute son existence. Jamais trois, meme s'il abandonne un metier, perd un
-- poste, ne pratique jamais la seconde, change de ville ou d'empire.
--
-- LE SLOT DEMENAGE DANS `carrieres_acquises`, dont la CLE PRIMAIRE EST LE PERSONNAGE. La borne
-- n'est plus une condition dans un corps de fonction ni un index a lire de travers : c'est la
-- forme meme de la table. Une troisieme carriere ne peut pas s'ecrire.
--
-- LE CURSUS MENE A UNE CARRIERE, ET LA COLONNE LE DIT. `universite_cursus.qualification` devient
-- `carriere`, avec une cle etrangere vers le registre des 10 familles. Un cursus ne peut donc
-- plus promettre une qualification qui n'est pas une carriere.
--
-- RIEN N'EST DETRUIT : les quatre tables de l'Universite sont VIDES (releve en base avant la
-- migration), donc le renommage n'a aucune ligne a convertir. `personnages_qualifications` et
-- `qualifications` SURVIVENT -- elles portent l'autre axe, celui des qualifications de metier
-- de plateau-commerce.js -- mais leur `source` ne peut plus valoir 'universite' : l'Universite
-- n'ecrit plus la, et laisser la valeur ouverte serait laisser deux verites possibles.
--
-- LES REGLES DE CURSUS DEJA VALIDEES NE BOUGENT PAS : un seul cursus actif, echeance au double
-- de la duree theorique, pas d'acceleration, jalons hebdomadaires, la reussite consomme le slot,
-- l'abandon et l'expiration ne le consomment pas. LES CATALOGUES RESTENT VIDES : les durees, les
-- couts et les contenus des cursus ne sont pas arbitres, et on n'invente pas un programme.
--
-- PREUVES STRUCTURELLES -- 12.

-- ============================================================================================
-- 1. LE CURSUS MENE A UNE CARRIERE
-- ============================================================================================
ALTER TABLE public.universite_cursus DROP CONSTRAINT IF EXISTS universite_cursus_qualification_fkey;
ALTER TABLE public.universite_cursus RENAME COLUMN qualification TO carriere;
ALTER TABLE public.universite_cursus
  ADD CONSTRAINT universite_cursus_carriere_fkey FOREIGN KEY (carriere) REFERENCES public.carrieres(id);

-- ============================================================================================
-- 2. L'AUTRE AXE NE PEUT PLUS SE RECLAMER DE L'UNIVERSITE
-- ============================================================================================
DROP INDEX IF EXISTS public.personnages_une_seule_qualif_universitaire;
ALTER TABLE public.personnages_qualifications
  DROP CONSTRAINT IF EXISTS personnages_qualifications_source_check;
ALTER TABLE public.personnages_qualifications
  ADD CONSTRAINT personnages_qualifications_source_check
  CHECK (source = ANY (ARRAY['creation'::text, 'autre'::text]));

-- ============================================================================================
-- 3. LE SLOT SE LIT LA OU IL VIT DESORMAIS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_slot_consomme(p_nom text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.carrieres_acquises a WHERE a.personnage = p_nom);
$$;

-- ============================================================================================
-- 4. S'INSCRIRE -- ON N'APPREND PAS LE METIER QU'ON EXERCE DEJA
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_inscrire(p_cursus text, p_requete text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_cur record; v_id text; v_debut timestamptz := now(); v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NOT NULL AND p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  IF p_requete IS NOT NULL THEN
    SELECT id INTO v_id FROM public.universite_inscriptions WHERE requete = p_requete;
    IF v_id IS NOT NULL THEN
      RETURN jsonb_build_object('ok', true, 'rejeu', true, 'inscription', v_id);
    END IF;
  END IF;

  SELECT * INTO v_cur FROM public.universite_cursus WHERE id = p_cursus;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cursus_inconnu'); END IF;

  -- LE SLOT A VIE. Une seconde carriere deja acquise ferme definitivement la porte.
  IF public.universite_slot_consomme(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seconde_carriere_deja_acquise');
  END IF;

  -- ON NE DEPENSE PAS SON UNIQUE SLOT POUR CE QU'ON A DEJA. Ce n'est pas une punition : c'est le
  -- refus d'un gachis irreversible.
  IF public.carriere_possede(v_moi, v_cur.carriere) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_deja_detenue',
                              'carriere', v_cur.carriere);
  END IF;

  IF EXISTS (SELECT 1 FROM public.universite_inscriptions
              WHERE personnage = v_moi AND statut = 'en_cours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_deja_en_cours');
  END IF;

  v_id := 'ins-' || left(md5(v_moi || '|' || p_cursus || '|' || coalesce(p_requete, v_debut::text)), 20);

  INSERT INTO public.universite_inscriptions
    (id, personnage, cursus, semaines_theoriques, debut_le, fin_theorique_le, limite_le, statut, requete)
  VALUES (v_id, v_moi, p_cursus, v_cur.semaines_theoriques, v_debut,
          public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques),
          public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques * 2),
          'en_cours', p_requete)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inscription_deja_posee'); END IF;

  RETURN jsonb_build_object('ok', true, 'inscription', v_id, 'carriere', v_cur.carriere,
    'semaines_theoriques', v_cur.semaines_theoriques,
    'fin_theorique_le', public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques),
    'limite_le', public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques * 2));
END;
$$;

-- ============================================================================================
-- 5. DIPLOMER -- LE SLOT SE CONSOMME EN ECRIVANT LA CARRIERE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_diplomer(p_requete text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_ins record; v_cur record; v_total integer; v_faits integer; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  IF now() > v_ins.limite_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_expire', 'limite_le', v_ins.limite_le);
  END IF;
  -- LA DUREE THEORIQUE EST UN MINIMUM, PAS UNE ESTIMATION.
  IF now() < v_ins.fin_theorique_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'duree_theorique_non_atteinte',
      'fin_theorique_le', v_ins.fin_theorique_le);
  END IF;

  SELECT count(*), count(a.jalon) INTO v_total, v_faits
    FROM public.universite_cursus_jalons j
    LEFT JOIN public.universite_jalons_accomplis a
           ON a.jalon = j.id AND a.inscription = v_ins.id
   WHERE j.cursus = v_ins.cursus;
  IF v_faits < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jalons_incomplets',
      'accomplis', v_faits, 'total', v_total);
  END IF;

  SELECT * INTO v_cur FROM public.universite_cursus WHERE id = v_ins.cursus;

  -- LE SLOT SE CONSOMME EN ECRIVANT LA CARRIERE, jamais en posant un drapeau. La CLE PRIMAIRE de
  -- `carrieres_acquises` est le personnage : deux appels simultanes ne peuvent pas en ecrire deux,
  -- et il n'existe aucune forme de la table ou une troisieme carriere tiendrait.
  INSERT INTO public.carrieres_acquises (personnage, carriere, source, inscription_id)
  VALUES (v_moi, v_cur.carriere, 'universite', v_ins.id)
  ON CONFLICT (personnage) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seconde_carriere_deja_acquise');
  END IF;

  UPDATE public.universite_inscriptions
     SET statut = 'diplome', clos_le = now()
   WHERE id = v_ins.id;

  RETURN jsonb_build_object('ok', true, 'inscription', v_ins.id,
    'carriere', v_cur.carriere, 'slot_consomme', true,
    'carrieres', to_jsonb(public.carrieres_de(v_moi)));
END;
$$;

-- ============================================================================================
-- 6. L'ETAT, DIT DANS LE BON VOCABULAIRE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_mon_etat()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_ins record; v_jalons jsonb; v_total integer; v_faits integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'cursus_actif', NULL,
      'slot_consomme', public.universite_slot_consomme(v_moi),
      'carriere_initiale', public.carriere_initiale(v_moi),
      'carrieres', to_jsonb(public.carrieres_de(v_moi)),
      'seconde_carriere', (SELECT jsonb_build_object('carriere', a.carriere,
                                   'libelle', c.libelle, 'acquise_le', a.acquise_le)
                             FROM public.carrieres_acquises a
                             LEFT JOIN public.carrieres c ON c.id = a.carriere
                            WHERE a.personnage = v_moi),
      -- LES CURSUS QUI MENENT A UNE CARRIERE QU'ON A DEJA SONT ECARTES DE LA LISTE : l'ecran ne
      -- propose donc pas de depenser l'unique slot pour rien.
      'cursus_disponibles', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'id', u.id, 'libelle', u.libelle, 'carriere', u.carriere,
          'carriere_libelle', c.libelle,
          'semaines_theoriques', u.semaines_theoriques,
          'cout_pa', u.cout_pa, 'cout_fr', u.cout_fr) ORDER BY u.id), '[]'::jsonb)
        FROM public.universite_cursus u
        LEFT JOIN public.carrieres c ON c.id = u.carriere
        WHERE NOT public.carriere_possede(v_moi, u.carriere)));
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', j.id, 'rang', j.rang, 'libelle', j.libelle, 'genre', j.genre,
      'batiment', j.batiment, 'ville', j.ville, 'piece', j.piece,
      'ouvre_le', public.universite_plus_semaines(v_ins.debut_le, j.rang - 1),
      'ouvert', now() >= public.universite_plus_semaines(v_ins.debut_le, j.rang - 1),
      'accompli', (a.jalon IS NOT NULL),
      'accompli_le', a.accompli_le) ORDER BY j.rang, j.id), '[]'::jsonb),
    count(*), count(a.jalon)
    INTO v_jalons, v_total, v_faits
    FROM public.universite_cursus_jalons j
    LEFT JOIN public.universite_jalons_accomplis a
           ON a.jalon = j.id AND a.inscription = v_ins.id
   WHERE j.cursus = v_ins.cursus;

  RETURN jsonb_build_object('ok', true,
    'slot_consomme', public.universite_slot_consomme(v_moi),
    'carriere_initiale', public.carriere_initiale(v_moi),
    'carrieres', to_jsonb(public.carrieres_de(v_moi)),
    'cursus_actif', jsonb_build_object(
      'inscription', v_ins.id, 'cursus', v_ins.cursus,
      'carriere', (SELECT u.carriere FROM public.universite_cursus u WHERE u.id = v_ins.cursus),
      'semaines_theoriques', v_ins.semaines_theoriques,
      'debut_le', v_ins.debut_le, 'fin_theorique_le', v_ins.fin_theorique_le,
      'limite_le', v_ins.limite_le,
      'duree_atteinte', now() >= v_ins.fin_theorique_le,
      'expire', now() > v_ins.limite_le,
      'jalons_total', v_total, 'jalons_accomplis', v_faits,
      'diplomable', (v_faits = v_total AND now() >= v_ins.fin_theorique_le AND now() <= v_ins.limite_le),
      'jalons', v_jalons));
END;
$$;

-- ============================================================================================
-- PREUVES STRUCTURELLES -- 12
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT count(*) INTO v_n FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
   WHERE c.relname = 'universite_cursus' AND a.attname = 'carriere' AND a.attnum > 0;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- le cursus ne mene pas a une carriere'; END IF;

  SELECT count(*) INTO v_n FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
   WHERE c.relname = 'universite_cursus' AND a.attname = 'qualification' AND a.attnum > 0
     AND NOT a.attisdropped;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- l''ancienne colonne de qualification survit'; END IF;

  SELECT count(*) INTO v_n FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid
   WHERE c.relname = 'universite_cursus' AND k.contype = 'f'
     AND pg_get_constraintdef(k.oid) LIKE '%carrieres(id)%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- un cursus peut mener ailleurs qu''a une carriere'; END IF;

  SELECT count(*) INTO v_n FROM pg_index x JOIN pg_class ic ON ic.oid = x.indexrelid
   WHERE ic.relname = 'personnages_une_seule_qualif_universitaire';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- l''ancien verrou de slot survit sur l''autre axe'; END IF;

  SELECT pg_get_constraintdef(k.oid) INTO v_txt FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid
   WHERE c.relname = 'personnages_qualifications' AND k.conname = 'personnages_qualifications_source_check';
  IF v_txt IS NULL OR position('universite' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- l''autre axe peut encore se reclamer de l''Universite'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'universite_slot_consomme';
  IF v_txt !~ 'carrieres_acquises' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- le slot ne se lit pas dans carrieres_acquises'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'universite_diplomer';
  IF v_txt !~ 'carrieres_acquises' THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le diplome n''ecrit pas la seconde carriere'; END IF;
  IF v_txt ~ 'personnages_qualifications' THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- le diplome ecrit encore sur l''autre axe'; END IF;
  IF v_txt !~ 'fin_theorique_le' OR v_txt !~ 'limite_le' OR v_txt !~ 'jalons_incomplets' THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- les regles de cursus validees ont bouge'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'universite_inscrire';
  IF v_txt !~ 'carriere_possede' THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- on peut depenser son unique slot pour une carriere deja detenue'; END IF;
  -- L'ABANDON ET L'EXPIRATION NE CONSOMMENT PAS LE SLOT : ni l'une ni l'autre porte n'ecrit
  -- dans la table ou vit la seconde carriere.
  SELECT count(*) INTO v_n FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace
     AND proname IN ('universite_abandonner', 'universite_expirer_echues')
     AND prosrc ~ 'carrieres_acquises';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P11 ECHOUEE -- un abandon ou une expiration consomme le slot'; END IF;

  SELECT count(*) INTO v_n FROM public.universite_cursus;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12 ECHOUEE -- un cursus a ete invente : % ligne(s)', v_n; END IF;

  RAISE NOTICE 'LES 12 PREUVES SONT VERTES.';
END $preuves$;
