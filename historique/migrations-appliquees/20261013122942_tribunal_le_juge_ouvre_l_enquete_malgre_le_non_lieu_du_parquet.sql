-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013122942 (UTC), nom
-- `tribunal_le_juge_ouvre_l_enquete_malgre_le_non_lieu_du_parquet`.
-- Le registre passe de 706 a 707 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 06191d152112a45ab4c33a6df8bae469, 14645 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 95921ef850033abef8e3e08a773ce0f2, 14646 caracteres. Les deux ont ete compares : le corps
-- archive ici est, au saut de ligne final pres, OCTET POUR OCTET celui que Supabase a
-- enregistre. L'empreinte declaree ci-dessus est celle du corps tel que le verificateur le
-- mesure, c'est-a-dire debarrasse de ses sauts de ligne de bordure.
--
-- LE NON-LIEU DU PARQUET NE FERME PLUS LA JUSTICE A LUI SEUL
--
-- Le juge pouvait deja contredire le parquet APRES la saisine (`juge_suite_apres_abandon`).
-- AVANT, le non-lieu etait sans recours : n'importe quel Procureur enterrait n'importe quelle
-- affaire sans contrepoids.
--
-- LE POUVOIR AJOUTE, ET AUCUN AUTRE : le juge de la ville peut OUVRIR UNE ENQUETE sur un dossier
-- clos par un non-lieu. Il ne poursuit pas, ne qualifie pas, ne se saisit pas. L'affaire repasse
-- en `enquete` et la chaine qui suit est exactement celle qui existait.
--
-- LES DEUX DECISIONS COEXISTENT : le non-lieu reste a la chronologie et sur le dossier, et
-- l'ouverture est un acte DISTINCT, avec son auteur et sa date -- comme `abandon_poursuites` et
-- `juge_poursuite_maintenue`. Le journal l'apprend, parce que le non-lieu y etait deja.
--
-- PREUVES STRUCTURELLES -- 9.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE NON-LIEU DU PARQUET NE FERME PLUS LA JUSTICE A LUI SEUL.
--
-- CE QUI EXISTAIT, ET CE QUI MANQUAIT. Le juge pouvait deja contredire le parquet UNE FOIS
-- SAISI : `juge_suite_apres_abandon` lui permet, quand le Procureur se retire APRES la saisine,
-- d'accepter l'arret ou de maintenir les poursuites. Mais AVANT la saisine, le non-lieu du
-- parquet etait une porte fermee a clef : l'affaire mourait au parquet et aucune autorite
-- judiciaire ne pouvait la rouvrir. Un Procureur -- joueur ou PNJ -- enterrait donc n'importe
-- quelle affaire sans contrepoids.
--
-- LE POUVOIR AJOUTE, ET AUCUN AUTRE. Le juge de la ville de l'affaire peut OUVRIR UNE ENQUETE
-- sur un dossier que le parquet a clos par un non-lieu. C'est tout. Il ne poursuit pas lui-meme,
-- il ne qualifie pas les faits, il ne se saisit pas : l'affaire repasse au statut `enquete`, ou
-- la police peut accomplir des actes et ou le parquet peut encore engager des poursuites. La
-- chaine qui suit est EXACTEMENT celle qui existait.
--
-- LES DEUX DECISIONS COEXISTENT, et c'est le point. Le non-lieu reste a la chronologie -- l'acte
-- `non_lieu`, son auteur, son motif declare -- et les cles `non_lieu_par`, `non_lieu_le`,
-- `non_lieu_motif_declare` restent sur le dossier : rien n'est efface. L'ouverture par le juge
-- est un FAIT DISTINCT, avec son propre type d'acte, son auteur et sa date. Le dossier raconte
-- donc une histoire a deux voix, exactement comme `abandon_poursuites` et
-- `juge_poursuite_maintenue` le font deja depuis le 12 octobre.
--
-- AUCUNE LIMITE DE REPETITION N'EST INVENTEE. Si le parquet prononce un second non-lieu, le juge
-- peut rouvrir une seconde fois : deux joueurs qui ne sont pas d'accord restent deux joueurs qui
-- ne sont pas d'accord, et chaque aller-retour coute un acte a chacun. Le serveur ne tranche pas
-- ce desaccord ; il garantit seulement que les deux decisions sont tracees.
--
-- LE DELAI RESTE OPPOSABLE. Rouvrir une enquete sur un dossier dont le delai de jugement a
-- expire le ressusciterait : c'est la meme raison qui rend le delai opposable au juge dans
-- `juge_suite_apres_abandon`.
--
-- LE JOURNAL L'APPREND, PARCE QUE LE NON-LIEU Y ETAIT DEJA. Laisser l'ouverture silencieuse
-- laisserait le registre public sur sa derniere phrase -- « le parquet a prononce un non-lieu » --
-- alors que l'affaire est rouverte. La phrase est FACTUELLE et calquee sur celle qui existe pour
-- la poursuite maintenue : elle dit ce que le juge a decide, jamais ce qui est vrai.

-- ---------------------------------------------------------------------------------------------
-- 1. LE TYPE D'ACTE
-- ---------------------------------------------------------------------------------------------
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
  ('juge_enquete_ouverte', 'Le juge ouvre une enquete malgre le non-lieu du parquet', 'juge',
   'Pose par le juge de la ville de l''affaire sur un dossier que le parquet a clos par un non-lieu. Fait DISTINCT du non-lieu : les deux coexistent dans la chronologie. Il ouvre une enquete et rien de plus -- il ne poursuit pas, ne qualifie pas et ne se saisit pas.')
ON CONFLICT (type) DO NOTHING;

-- ---------------------------------------------------------------------------------------------
-- 2. LA PHRASE PUBLIQUE
-- ---------------------------------------------------------------------------------------------
INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES
  ('juge_enquete_ouverte', 'justice_enquete_ouverte_par_le_juge',
   'Le juge a ouvert une enquete sur %s malgre le non-lieu du parquet',
   'Calquee sur celle de la poursuite maintenue. Elle dit la DECISION du juge, jamais la culpabilite de la personne visee -- pas plus que la phrase du non-lieu ne disait son innocence.')
ON CONFLICT (type_acte) DO NOTHING;

-- ---------------------------------------------------------------------------------------------
-- 3. LA PORTE
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.juge_ouvrir_enquete_malgre_non_lieu(p_affaire_id text, p_motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_motif text; v_n integer;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  -- L'AUTORITE EST CELLE DE LA VILLE DE L'AFFAIRE, la regle de toutes les portes du juge.
  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville);
  END IF;

  -- CE POUVOIR NE S'EXERCE QUE SUR UN NON-LIEU. Il n'autorise pas le juge a prendre la main sur
  -- un dossier que le parquet instruit encore, ni a ressusciter une affaire jugee, relaxee ou
  -- perimee : la decision contredite est NOMMEE, et c'est la seule.
  IF coalesce(v_a ->> 'status', '') <> 'non_lieu' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status');
  END IF;

  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_motif := nullif(btrim(coalesce(p_motif, '')), '');

  -- LE NON-LIEU N'EST PAS EFFACE : seules des cles sont AJOUTEES. `non_lieu_par`, `non_lieu_le`
  -- et `non_lieu_motif_declare` restent lisibles sur le dossier apres la reouverture.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'enquete',
           'juge_enquete_ouverte_par', v_j.nom,
           'juge_enquete_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'juge_enquete_motif_declare', v_motif))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'non_lieu';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'juge_enquete_ouverte',
    v_j.nom, 'juge', NULL, NULL,
    CASE WHEN v_motif IS NULL THEN NULL
         ELSE jsonb_build_object('motif_declare', v_motif) END);

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'statut', 'enquete',
                            'juge', v_j.nom, 'non_lieu_par', v_a ->> 'non_lieu_par');
END;
$function$;

REVOKE ALL ON FUNCTION public.juge_ouvrir_enquete_malgre_non_lieu(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.juge_ouvrir_enquete_malgre_non_lieu(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 4. LE JUGE VOIT LES NON-LIEUX DE SA VILLE
-- ---------------------------------------------------------------------------------------------
-- Sans cela le pouvoir serait inatteignable : `juge_dossiers` ne rendait que les dossiers dont
-- le juge est SAISI, et un non-lieu n'en fait pas partie. Aucune donnee nouvelle n'est exposee --
-- la RLS de `plaintes_en_cours` accorde deja la ligne a l'autorite judiciaire de la ville
-- (`affaire_autorite_de`), et c'est cette meme autorite qui est lue ici.
CREATE OR REPLACE FUNCTION public.juge_dossiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j record;
BEGIN
  SELECT * INTO v_j FROM public.juge_moi();
  IF v_j.nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge'); END IF;

  RETURN jsonb_build_object('ok', true, 'juge', v_j.nom, 'ville', coalesce(v_j.ville, 'capitale'),
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
     WHERE p.country = v_j.pays AND p.city IS NOT DISTINCT FROM coalesce(v_j.ville, 'capitale')
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande', 'appel', 'non_lieu')));
END $function$;

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_n integer; v_src text;
BEGIN
  -- P1. Le type d acte existe, il est pose par le juge, et le registre en compte 31.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types
   WHERE type = 'juge_enquete_ouverte' AND pose_par = 'juge';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE : le type d acte du juge n est pas au registre'; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types;
  IF v_n <> 31 THEN RAISE EXCEPTION 'P1b ECHOUEE : % types d actes au registre, 31 attendus', v_n; END IF;

  -- P2. La phrase publique existe, elle est factuelle, et le registre en compte 13.
  SELECT count(*) INTO v_n FROM public.justice_faits_publics
   WHERE type_acte = 'juge_enquete_ouverte'
     AND chronique_type = 'justice_enquete_ouverte_par_le_juge'
     AND phrase LIKE '%malgre le non-lieu du parquet%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE : la phrase publique n est pas declaree'; END IF;
  SELECT count(*) INTO v_n FROM public.justice_faits_publics;
  IF v_n <> 13 THEN RAISE EXCEPTION 'P2b ECHOUEE : % faits publics declares, 13 attendus', v_n; END IF;

  -- P3. La porte est DEFINER a search_path fige, sans surcharge.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_ouvrir_enquete_malgre_non_lieu'
     AND p.prosecdef AND array_to_string(p.proconfig, ',') LIKE '%search_path=public, pg_temp%';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P3 ECHOUEE : % porte(s) DEFINER a search_path fige, 1 attendue', v_n;
  END IF;

  -- P4. ELLE EST APPELABLE PAR UN JOUEUR, et par personne d autre. Une fonction neuve n a par
  -- defaut AUCUN droit depuis le 9 octobre : sans ce GRANT le pouvoir serait decoratif.
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND routine_name = 'juge_ouvrir_enquete_malgre_non_lieu'
     AND grantee = 'authenticated' AND privilege_type = 'EXECUTE';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 ECHOUEE : la porte n est pas appelable par un joueur'; END IF;
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND routine_name = 'juge_ouvrir_enquete_malgre_non_lieu'
     AND grantee IN ('anon', 'PUBLIC');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4b ECHOUEE : % droit(s) anonyme(s) sur la porte', v_n; END IF;

  -- P5. LES TROIS GARDES SONT NOMMEES DANS LA SOURCE, commentaires retires : l autorite de
  -- ville, le statut contredit, et le delai opposable.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_ouvrir_enquete_malgre_non_lieu';
  IF v_src !~ 'juge_de_la_ville' OR v_src !~ 'non_lieu' OR v_src !~ 'affaire_delai_expire' THEN
    RAISE EXCEPTION 'P5 ECHOUEE : la porte ne porte pas ses trois gardes';
  END IF;

  -- P6. ELLE N INVENTE AUCUN AUTRE POUVOIR : elle n ecrit ni qualification, ni peine, ni
  -- jugement, et ne touche ni `jugements` ni `detentions`.
  IF v_src ~ 'qualification_parquet'
     OR v_src ~ 'INSERT INTO public.jugements'
     OR v_src ~ 'detention'
     OR v_src ~ 'justice_peine_calcul'
     OR v_src ~ '''saisie''' THEN
    RAISE EXCEPTION 'P6 ECHOUEE : la porte du juge fait plus qu ouvrir une enquete';
  END IF;

  -- P7. LE MECANISME EXISTANT EST INTACT. `juge_suite_apres_abandon` continue de ne connaitre
  -- que `abandon_demande` : le pouvoir neuf est DISTINCT, il ne le remplace pas.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_suite_apres_abandon';
  IF v_src !~ 'abandon_demande' OR v_src ~ 'juge_enquete_ouverte' THEN
    RAISE EXCEPTION 'P7 ECHOUEE : le mecanisme post-saisine a ete modifie';
  END IF;

  -- P8. LE JUGE VOIT DESORMAIS LES NON-LIEUX DE SA VILLE, et toujours les trois autres etats.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_dossiers';
  IF v_src !~ '''saisie'', ''abandon_demande'', ''appel'', ''non_lieu''' THEN
    RAISE EXCEPTION 'P8 ECHOUEE : juge_dossiers ne rend pas les non-lieux de la ville';
  END IF;
  -- Et elle reste bornee a SA ville et a SON pays : le pouvoir ne voit pas au-dela.
  IF v_src !~ 'p.city IS NOT DISTINCT FROM' OR v_src !~ 'p.country = v_j.pays' THEN
    RAISE EXCEPTION 'P8b ECHOUEE : juge_dossiers a perdu sa borne de ville ou de pays';
  END IF;

  -- P9. AUCUNE AFFAIRE N EST TOUCHEE : aucun non-lieu existant n est rouvert par la migration.
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours p
   WHERE left(btrim(coalesce(p.data,'')), 1) = '{'
     AND (p.data::jsonb ->> 'status') = 'non_lieu';
  RAISE NOTICE 'P9 : % non-lieu(x) existant(s), aucun rouvert par cette migration.', v_n;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE type = 'juge_enquete_ouverte';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9b ECHOUEE : % acte(s) deja poses par la migration', v_n; END IF;

  RAISE NOTICE 'LES 9 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
