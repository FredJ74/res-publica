-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009141441 (UTC ; 16h14 a Paris), nom
-- `detention_moteur_partage_et_drapeau_qhs`. Le registre passe de 569 a 570 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 9704f82d9f6620bba306ca5ead5a2731, 13 018 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme la branche « sur soi-meme » de la prolongation de peine, qui enchainait deux ecritures
-- clientes avalees sous un `return true` inconditionnel, et qui avait DIVERGE de la branche du juge
-- (elle ne posait ni le drapeau QHS ni le registre du QHS). Le corps de la RPC devient un moteur,
-- `detention_prolonger_interne`, que deux portes d'autorite appellent. Et le drapeau `detention_qhs`
-- n'a plus qu'un seul ecrivain cote acte : le navigateur y deposait un SCALAIRE de type string, que
-- `pa_repos_nocturne` ne sait pas lire, si bien que le plafond de PA du QHS ne s'appliquait pas.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `plateau-justice-economie.js` (`prolongerDetentionActive`).
-- =============================================================================

-- Chantier 5 -- UN MOTEUR DE PROLONGATION, DEUX PORTES D'AUTORITE, ET UN SEUL ECRIVAIN DU QHS.
--
-- prolongerDetentionActive (plateau-justice-economie.js) etait deja coupee en deux : la branche
-- « tiers » passe par justice_prolonger_peine et LIT son verdict depuis le 13 septembre ; la
-- branche « soi » enchainait deux ecritures clientes avalees, et son `return true` etait
-- inconditionnel. Les deux branches avaient en outre DIVERGE : la RPC posait le drapeau QHS et
-- inscrivait au registre du QHS, la branche cliente ne le faisait pas.
--
-- Plutot que de dupliquer la RPC, son corps devient un MOTEUR -- detention_prolonger_interne --
-- que deux portes appellent : justice_prolonger_peine (un juge, sur un tiers) et
-- detention_prolonger_soi (le detenu, sur lui-meme). C'est le patron que ce schema utilise deja
-- pour l'incarceration : detention_ouvrir_interne et ses quatre portes d'autorite.
--
-- ET LE DRAPEAU QHS N'A PLUS QU'UN SEUL ECRIVAIN COTE ACTE. Le navigateur ecrivait
-- `detention_qhs: JSON.stringify({enQHS:true,...})` sur une colonne jsonb, ce qui y depose un
-- SCALAIRE de type string -- alors que pa_repos_nocturne exige `jsonb_typeof = 'object'` avant
-- de lire enQHS. Le plafond de PA du quartier de haute securite ne s'appliquait donc pas aux
-- QHS poses par un client. Le depot atteste que le cas s'est produit en production.
--
-- Banc en transaction annulee : 5 preuves vertes, dont le refus d'autorite eprouve SOUS LE ROLE
-- authenticated -- en appel serveur, exiger_poste() rend NULL sans lever, et le refus ne
-- s'observe donc pas depuis postgres.
CREATE OR REPLACE FUNCTION public.detention_qhs_poser_interne(
  p_nom text, p_detention_id text, p_raison text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_det record; v_peine jsonb;
BEGIN
  SELECT country, city, jour_debut, jour_fin INTO v_det
    FROM public.detentions WHERE id = p_detention_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  UPDATE public.detentions SET qhs = true WHERE id = p_detention_id;

  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
   WHERE name = p_nom FOR UPDATE;
  UPDATE public.personnages_donnees
     SET est_emprisonne = CASE
           WHEN v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object'
           THEN v_peine || jsonb_build_object('qhs', true) ELSE v_peine END,
         -- OBJET, jamais une chaine : c'est la forme que pa_repos_nocturne sait lire.
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false)
   WHERE name = p_nom;

  IF NOT EXISTS (SELECT 1 FROM public.prisonniers_qhs
                  WHERE data ->> 'nom' = p_nom AND coalesce(statut, '') <> 'transfere') THEN
    INSERT INTO public.prisonniers_qhs (id, statut, data)
    VALUES ('qhs-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
              || substr(md5(random()::text), 1, 6), 'detenu',
            jsonb_build_object('pays', v_det.country, 'nom', p_nom,
                               'raison', coalesce(nullif(btrim(p_raison), ''), 'Sentence'),
                               'jourDebut', v_det.jour_debut, 'jourFin', v_det.jour_fin));
  END IF;
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_prolonger_interne(
  p_nom text, p_motifs jsonb, p_forcer_qhs boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_peine jsonb; v_det record; v_jours_supp int; v_nouveau int; v_motifs jsonb;
BEGIN
  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' OR jsonb_array_length(p_motifs) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motifs_absents');
  END IF;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;
  SELECT coalesce(sum((m ->> 'jours')::int), 0) INTO v_jours_supp
    FROM jsonb_array_elements(p_motifs) m;
  v_nouveau := coalesce(v_det.jour_fin, 0) + v_jours_supp;
  -- Les motifs sont relus SOUS VERROU puis concatenes. La branche cliente, elle, les lisait
  -- avec `.catch(() => [])` : un echec de lecture ECRASAIT tous les motifs existants.
  SELECT coalesce(motifs, '[]'::jsonb) INTO v_motifs
    FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  UPDATE public.detentions
     SET motifs = v_motifs || p_motifs, jour_fin = v_nouveau
   WHERE id = v_det.id;
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
   WHERE name = p_nom FOR UPDATE;
  IF v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object' THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine
             || jsonb_build_object('jours', coalesce((v_peine ->> 'jours')::int, 0) + v_jours_supp)
             || jsonb_build_object('jourFin', v_nouveau)
     WHERE name = p_nom;
  END IF;
  IF p_forcer_qhs THEN
    PERFORM public.detention_qhs_poser_interne(p_nom, v_det.id,
              coalesce(p_motifs -> 0 ->> 'type', 'Sentence'));
  END IF;
  RETURN jsonb_build_object('ok', true, 'cible', p_nom, 'detention_id', v_det.id,
                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau);
END; $fn$;

-- La porte du juge garde sa signature -- donc ses droits et son commentaire -- et delegue.
-- NOTE, COMPORTEMENT D'ORIGINE CONSERVE TEL QUEL : exiger_poste() rend NULL sans lever en appel
-- serveur (« le serveur traverse »). Un appel service_role traverse donc sans controle de poste.
CREATE OR REPLACE FUNCTION public.justice_prolonger_peine(
  p_cible text, p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_juge text; v_r jsonb;
BEGIN
  v_juge := public.exiger_poste('juge');
  v_r := public.detention_prolonger_interne(p_cible, p_motifs, p_forcer_qhs);
  IF coalesce((v_r ->> 'ok')::boolean, false) THEN
    RETURN v_r || jsonb_build_object('juge', v_juge);
  END IF;
  RETURN v_r;
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_prolonger_soi(
  p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN public.detention_prolonger_interne(v_moi, p_motifs, p_forcer_qhs);
END; $fn$;

GRANT EXECUTE ON FUNCTION public.detention_prolonger_soi(jsonb, boolean) TO authenticated;

COMMENT ON FUNCTION public.detention_prolonger_interne(text, jsonb, boolean) IS
'MOTEUR de prolongation de peine : concatene les motifs sous verrou, repousse jour_fin, aligne
est_emprisonne, et pose le drapeau QHS si demande. N''a AUCUN controle d''autorite -- c''est le
role de ses portes : justice_prolonger_peine (un juge, sur un tiers) et detention_prolonger_soi
(le detenu, sur lui-meme). Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_qhs_poser_interne(text, text, text) IS
'SEUL ECRIVAIN du caractere QHS au moment de l''acte : pose detentions.qhs, est_emprisonne.qhs et
detention_qhs -- ce dernier en OBJET et non en chaine, forme que pa_repos_nocturne exige pour
appliquer le plafond de PA -- puis inscrit au registre du QHS une seule fois. Non appelable
depuis le reseau.';
COMMENT ON FUNCTION public.detention_prolonger_soi(jsonb, boolean) IS
'Prolonge SA PROPRE peine : rebellion en cellule, placement au QHS. L''identite vient de
mon_personnage(), jamais d''un parametre. Verdicts : acteur_non_authentifie, motifs_absents,
cible_non_detenue, puis ok avec jours_ajoutes et jour_fin.';

DO $$
DECLARE v_def text; v_droits text; v_n int; v_ecrivains text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'detention_prolonger_interne';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- le moteur n''existe pas'; END IF;
  IF position('UPDATE public.detentions' in v_def) = 0
     OR position('UPDATE public.personnages_donnees' in v_def) = 0
     OR position('detention_qhs_poser_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le moteur ne fait pas les trois ecritures';
  END IF;
  IF position('FOR UPDATE' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- les motifs ne sont pas relus sous verrou';
  END IF;

  -- P2 : LA PORTE DU JUGE DELEGUE, elle ne duplique plus -- son corps n'ecrit plus rien.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'justice_prolonger_peine';
  IF position('detention_prolonger_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte du juge ne delegue pas au moteur';
  END IF;
  IF v_def ~ 'UPDATE public\.(detentions|personnages_donnees)'
     OR v_def ~ 'INSERT INTO public\.prisonniers_qhs' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte du juge ecrit encore elle-meme';
  END IF;
  IF position('exiger_poste(''juge'')' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte du juge a perdu son controle d''autorite';
  END IF;

  -- P3 : la porte du detenu lit son identite, elle ne la recoit pas.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'detention_prolonger_soi';
  IF position('public.mon_personnage()' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''identite n''est pas lue';
  END IF;
  IF v_def ~ 'p_nom|p_cible' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un parametre nomme la cible : elle serait falsifiable';
  END IF;

  -- P4 : le drapeau QHS est ecrit en OBJET, et l'ENSEMBLE de ses ecrivains est connu et nomme.
  -- justice_prolonger_peine en sort (elle delegue), detention_qhs_poser_interne y entre.
  -- Les trois autres sont legitimes : qhs_pouvoir (les actes du ministre), pa_repos_nocturne
  -- (qui consomme paLimite1Jour) et personnages_vue_modifier (le declencheur de la vue, qui
  -- recopie toutes les colonnes).
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'detention_qhs_poser_interne';
  IF position('detention_qhs = jsonb_build_object(''enQHS'', true, ''paLimite1Jour'', false)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le drapeau QHS n''est pas un objet';
  END IF;
  SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_ecrivains
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE pg_get_functiondef(p.oid) ~ 'detention_qhs\s*=';
  IF v_ecrivains IS DISTINCT FROM
     'detention_qhs_poser_interne, pa_repos_nocturne, personnages_vue_modifier, qhs_pouvoir' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- les ecrivains de detention_qhs sont « % »', v_ecrivains;
  END IF;

  -- P5 : les droits. Moteurs injoignables depuis le reseau, portes ouvertes, juge inchange.
  IF has_function_privilege('authenticated', 'public.detention_prolonger_interne(text,jsonb,boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.detention_prolonger_interne(text,jsonb,boolean)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.detention_qhs_poser_interne(text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un moteur interne est appelable depuis le reseau';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.detention_prolonger_soi(jsonb,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le detenu ne peut pas appeler sa porte';
  END IF;
  SELECT string_agg(coalesce(r.rolname,'PUBLIC')||':'||ae.privilege_type, ', '
                    ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname = 'justice_prolonger_peine';
  IF v_droits IS DISTINCT FROM 'authenticated:EXECUTE, postgres:EXECUTE, service_role:EXECUTE' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la reecriture a change les droits du juge : %', v_droits;
  END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % detention(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.prisonniers_qhs;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % ligne(s) QHS au lieu de 1', v_n; END IF;
  IF (SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~'),'|' ORDER BY name COLLATE "C"))
        FROM public.personnages_donnees) IS DISTINCT FROM 'db4a44dee1b87f6ccd06610120f305ed' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les personnages ont bouge';
  END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;