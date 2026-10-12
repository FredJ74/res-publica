-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012141608 (UTC), nom
-- `tribunal_procedure_simplifiee_aucun_crime`.
-- Le registre passe de 683 a 684 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 1dd96586b08e4cb018f0b3edb1ab5c5e, 11085 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL, CHEMIN CRITIQUE (1/6) -- AUCUN CRIME NE PASSE PAR LA PROCEDURE SIMPLIFIEE
--
-- LE SEUIL DES 2 JOURS NE SUFFISAIT PAS : quatre infractions de categorie `crime` portent un
-- bareme historique de 2 jours -- `acheter_bombe_illegale`, `empoisonnement`, `incendier`,
-- `utiliser_explosifs`. Un incendie volontaire se reglait donc par un jet de defense. Le critere
-- devient double : reference <= 2 jours ET categorie canonique PRESENTE et differente de `crime`.
--
-- LA CATEGORIE ABSENTE FERME AUSSI LA PORTE, et c'est un refus FERME : onze infractions a
-- <= 2 jours ont une categorie nulle -- dont `assassinat`, `tentative_assassinat` -- et
-- `NULL <> 'crime'` ne vaut PAS vrai en SQL. On ne peut donc pas AFFIRMER qu'une telle infraction
-- n'est pas un crime, et cette procedure est automatique et DEFINITIVE. Mesure : 13 infractions
-- sur 39 y relevent desormais, et non 24. LE CATALOGUE N'EST PAS CORRIGE -- la consigne
-- l'interdit : remplir ces onze categories les y ramenera sans toucher une ligne de code.
--
-- CE QUI RESTE ARRETE, ET LES DEUX VALEURS QUI MANQUENT. La resolution automatique exige le CHA
-- de l'avocat commis d'office. Mesure : `pnj_fonctions` declare bien une fonction `avocat`, avec
-- `metier_beta = false` -- un role de DECOR -- donc AUCUNE ligne `avocat` dans
-- `pnj_metiers_profils`, et aucun `car_cha` d'avocat nulle part. Manquent (1) ce CHA et (2)
-- l'operation qui le combine a celui du prevenu. Les inventer serait decider des probabilites.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- AUCUN CRIME NE PASSE PAR LA PROCEDURE SIMPLIFIEE
-- 12 octobre 2026 -- critere definitif du §A
--
-- LE SEUIL DES 2 JOURS NE SUFFISAIT PAS, et le catalogue penal explique pourquoi : quatre
-- infractions de categorie `crime` portent un bareme historique de 2 jours --
-- `acheter_bombe_illegale`, `empoisonnement`, `incendier`, `utiliser_explosifs`. Avec le seul
-- seuil de duree, un incendie volontaire se reglait par un jet de defense automatique. Le critere
-- devient donc double : peine de reference <= 2 jours ET categorie canonique differente de
-- `crime`.
--
-- ET LA CATEGORIE DOIT ETRE PRESENTE : LE REFUS EST FERME. Onze infractions a <= 2 jours ont une
-- categorie NULLE -- ce sont celles qui portent leur propre bareme sans passer par une categorie
-- generique, et `assassinat` (2 j) en fait partie, comme `tentative_assassinat` et
-- `tentative_empoisonnement`. En SQL, `NULL <> 'crime'` ne vaut PAS vrai : il ne vaut rien. On ne
-- peut donc pas AFFIRMER qu'une telle infraction n'est pas un crime, et la procedure simplifiee
-- est automatique et DEFINITIVE -- elle ne peut pas tourner sur un critere invérifiable. Le
-- critere exige donc une categorie PRESENTE et differente de `crime`.
--
-- CONSEQUENCE MESUREE, ET RAPPORTEE : 13 infractions sur 39 relevent desormais de la procedure
-- simplifiee, et non 24. Les onze a categorie nulle en sortent -- dont des faits mineurs
-- (`diffamation`, `hooliganisme`, `violation_couvre_feu`, `achat_arme_illegal`,
-- `corruption_fonctionnaire`, `possession_illegale_douane`, `justification_rejetee`,
-- `non_presentation_convocation`) qui devraient vraisemblablement y rester. LE CATALOGUE N'EST
-- PAS CORRIGE ICI : la consigne l'interdit explicitement. Remplir la categorie de ces onze
-- lignes les y ramenera sans toucher une ligne de code.
--
-- CE QUI N'EST PAS LIVRE, ET LE CHOIX EXACT QUI MANQUE. La resolution automatique
-- serveur-authoritative reste ARRETEE, et la raison a change : ce n'est plus le CHA effectif
-- client (le §1 de la consigne tranche d'en sortir le groupe et la sante), c'est LE CHA DE
-- L'AVOCAT COMMIS D'OFFICE. Mesure faite : `pnj_fonctions` declare bien une fonction `avocat`,
-- mais avec `metier_beta = false` -- c'est un role de DECOR, pas un metier employable. Il n'existe
-- donc AUCUNE ligne `avocat` dans `pnj_metiers_profils`, et donc AUCUN `car_cha` d'avocat nulle
-- part dans le depot. Deux valeurs manquent, et aucune ne se deduit :
--    (1) le CHA des trois avocats commis d'office ;
--    (2) l'operation exacte entre le CHA du prevenu et celui de l'avocat (l'ancien code annonce
--        « CHA de l'avocat au maximum autorise, bonus lie au CHA du prevenu » sans aucun
--        coefficient).
-- Les inventer serait decider des probabilites a la place du game design.
--
-- PREUVES STRUCTURELLES -- 6.

CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
  v_inf text; v_i record; v_seuil integer; v_pays text; v_ville text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_issue NOT IN ('reussite_critique', 'attenuante', 'aggravation', 'infructueuse') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'issue_inconnue');
  END IF;

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
  SELECT i.jours_reference, i.categorie INTO v_i
    FROM public.infractions i WHERE i.id = v_inf;
  IF v_i.jours_reference IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_hors_catalogue',
                              'infraction', v_inf);
  END IF;

  -- PREMIER CRITERE : LA DUREE DE REFERENCE.
  v_seuil := public.justice_seuil_procedure_simplifiee_jours();
  IF v_i.jours_reference > v_seuil THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_reservee_aux_peines_courtes',
                              'infraction', v_inf, 'jours_reference', v_i.jours_reference,
                              'seuil', v_seuil);
  END IF;

  -- SECOND CRITERE : LA CATEGORIE. Un crime ne passe JAMAIS par la procedure simplifiee, quelle
  -- que soit la duree que son bareme historique lui donne. Et la categorie doit etre PRESENTE :
  -- sans elle, on ne peut pas affirmer que ce n'est pas un crime -- voir l'en-tete.
  IF v_i.categorie IS NULL OR v_i.categorie = 'crime' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'procedure_simplifiee_exclut_les_crimes',
                              'infraction', v_inf, 'categorie', v_i.categorie,
                              'jours_reference', v_i.jours_reference);
  END IF;

  v_maj := jsonb_build_object('defendue_par', v_nom, 'defendue_le',
                              to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                              'defense_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                              'defense_issue', p_issue,
                              'defense_infraction', v_inf,
                              'procedure_simplifiee', true);
  IF p_issue = 'reussite_critique' THEN
    v_maj := v_maj || jsonb_build_object('status', 'jugee', 'resultatDefense', 'reussite_critique');
  ELSIF p_issue = 'attenuante' THEN
    v_maj := v_maj || jsonb_build_object('circonstanceAttenuante', true);
  ELSIF p_issue = 'aggravation' THEN
    v_maj := v_maj || jsonb_build_object('aggravation', true);
  END IF;

  v_data := v_data || v_maj;
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;
  PERFORM set_config('rp.verdict_interne', '', true);

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'defense_simplifiee',
    v_nom, NULL, NULL, v_inf,
    jsonb_build_object('issue', p_issue, 'jours_reference', v_i.jours_reference,
                       'categorie', v_i.categorie, 'seuil', v_seuil));

  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'affaire', v_data,
                            'infraction', v_inf, 'jours_reference', v_i.jours_reference,
                            'categorie', v_i.categorie);
END; $$;
COMMENT ON FUNCTION public.plainte_defendre(text, text) IS
  'LA PROCEDURE SIMPLIFIEE, et son domaine est double : peine de reference <= 2 jours ET categorie canonique PRESENTE et differente de `crime`. Aucun crime n''y passe, meme avec un bareme historique de 1 ou 2 jours -- quatre infractions de categorie crime sont dans ce cas. Une categorie absente ferme egalement la porte : on ne peut pas affirmer qu''une infraction sans categorie n''est pas un crime, et cette procedure est automatique et definitive. DEFINITIVE : une seule defense par affaire. La resolution automatique en relaxe ou reduction de 50 % reste ARRETEE : le CHA de l''avocat commis d''office n''existe nulle part (aucun metier `avocat` dans pnj_metiers_profils), ni l''operation qui le combine a celui du prevenu.';

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';

  -- P1 : LE SECOND CRITERE EXISTE, ET IL EXIGE UNE CATEGORIE PRESENTE.
  IF position('v_i.categorie IS NULL OR v_i.categorie = ''crime''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le critere de categorie est absent ou permissif'; END IF;
  IF position('procedure_simplifiee_exclut_les_crimes' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le refus n''est pas nomme'; END IF;

  -- P2 : LES DEUX CRITERES PRECEDENT L'APPLICATION DE L'ISSUE. Une reussite critique ne doit
  -- atteindre ni un crime, ni une peine longue : on verifie l'ORDRE dans le corps.
  IF position('procedure_simplifiee_exclut_les_crimes' IN v_txt)
     > position('''status'', ''jugee''' IN v_txt)
     OR position('procedure_simplifiee_reservee_aux_peines_courtes' IN v_txt)
     > position('''status'', ''jugee''' IN v_txt) THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''issue est appliquee avant un des deux criteres'; END IF;

  -- P3 : LES QUATRE CRIMES A BAREME COURT SONT BIEN DANS LE CATALOGUE, et c'est la raison d'etre
  -- du second critere. Si ce compte tombe a zero, le critere n'a plus d'objet et il faut le dire.
  SELECT count(*) INTO v_n FROM public.infractions
   WHERE jours_reference <= 2 AND categorie = 'crime';
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- % crime(s) a bareme court au lieu de 4 : le catalogue a bouge', v_n; END IF;

  -- P4 : LE DOMAINE REEL EST MESURE, PAS SUPPOSE. Treize infractions, et le rapport le dit.
  SELECT count(*) INTO v_n FROM public.infractions
   WHERE jours_reference <= 2 AND categorie IS NOT NULL AND categorie <> 'crime';
  IF v_n <> 13 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- % infraction(s) eligibles au lieu de 13', v_n; END IF;

  -- P5 : LA RESOLUTION AUTOMATIQUE EST TOUJOURS ARRETEE, PAS A MOITIE ECRITE.
  IF position('detention_ouvrir' IN v_txt) > 0 OR position('INSERT INTO public.jugements' IN v_txt) > 0
     OR position('justice_peine_calcul' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la defense applique une peine alors que l''arbitrage est remonte'; END IF;

  -- P6 : LES GARDES DE LA TRANCHE PRECEDENTE SONT INTACTES.
  IF position('defense_deja_plaidee' IN v_txt) = 0
     OR position('infraction_non_determinee' IN v_txt) = 0
     OR position('''defense_simplifiee''' IN v_txt) = 0
     OR position('''reussite_critique'', ''attenuante'', ''aggravation'', ''infructueuse''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- une garde de la tranche precedente a disparu'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % signature(s)', v_n; END IF;

  RAISE NOTICE 'LES 6 PREUVES SONT VERTES.';
END $preuves$;
