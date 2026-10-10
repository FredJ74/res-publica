-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010003550 (UTC), nom `detention_moteur_de_cloture_et_motifs_eteints`.
-- Le registre passe de 584 a 585 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 ac542307260840b9aa672cb2922edb56, 10 653 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- MOTEUR DE CLOTURE DE DETENTION, ET LES MOTIFS ETEINTS
--
-- `detention_clore_interne(nom, mode, jour)` fait les QUATRE ecritures d'une sortie de geole dans
une transaction : ligne close, `est_emprisonne` vide, drapeau QHS retire, registre QHS passe a
'libere'. `detention_clore_motif_eteint(mode)` l'expose au detenu pour les deux modes d'une
peine tenant SEULEMENT a la desertion -- liste fermee ('poursuites_eteintes','incorporation') --
avec sa precondition `motifDesertionSeul`.
--
-- ELLE VA PAR PAIRE AVEC : `plateau-politique.js` (`eteindrePoursuitesDesertion`, `doAccepterIncorporation`).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Chantier 5 -- UNE FIN DE DETENTION FAIT QUATRE ECRITURES, ET UN SEUL ENDROIT LES FAIT.
--
-- Fermer une detention, c'est toujours la meme chose : clore la ligne du registre avec son mode
-- de fin, vider `est_emprisonne`, abaisser le drapeau QHS s'il etait leve, et passer la ligne du
-- registre du QHS a « libere ». Le lot du 9 octobre a ecrit cette sequence TROIS FOIS -- peine
-- purgee, evasion, reduction liberatrice de l'avocat. C'etait la duplication que ce chantier
-- combat ailleurs, reintroduite par lui. detention_clore_interne est ce seul endroit : il ne
-- DECIDE rien -- ni precondition ni autorite, c'est le role de ses portes -- et n'est pas
-- appelable depuis le reseau.
--
-- PREMIERE INSTANCE DU DEFAUT FERMEE ICI : LES DEUX LIBERATIONS DE DESERTION
-- (plateau-politique.js, ~12586 demobilisation et ~12673 incorporation). Elles vidaient
-- `state.estEmprisonne` puis persistaient la fiche par sbSavePersonnage, mais NE CLOSAIENT JAMAIS
-- la ligne `detentions` : le registre carceral declarait detenu un personnage libre,
-- indefiniment. detention_clore_motif_eteint prend les deux, avec le mode de fin qui dit lequel.
--
-- LA REGLE DE JEU DE LA DESERTION PASSE DU NAVIGATEUR AU SERVEUR, inchangee : on ne libere que si
-- la detention ne tenait qu'a la desertion (est_emprisonne.motifDesertionSeul). La porte refuse
-- par « peine_pas_seulement_desertion », ce qui laisse l'appelant prendre sa branche
-- « incorporation differee a la liberation ».
--
-- LA PREUVE « AUCUNE DONNEE TOUCHEE » SE COMPARE DESORMAIS A ELLE-MEME. La beta rejoue depuis le
-- 9 octobre au soir -- un joueur a depense 400 FR, la passe de minuit a tourne deux fois. Une
-- constante en dur serait devenue fausse sans qu'aucun defaut existe, et aurait refuse une
-- migration correcte. L'etat est donc releve AVANT puis confronte APRES, dans la transaction meme.
--
-- Bancs en transaction annulee : 17 epreuves vertes sur le moteur et ses cinq portes, dont la
-- non-regression des trois clotures existantes.
CREATE TEMP TABLE zz_etat_avant AS
SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~')
                      ||':'||coalesce(est_emprisonne::text,'~')||':'||coalesce(detention_qhs::text,'~'),
                      '|' ORDER BY name COLLATE "C")) AS empreinte_personnages,
       (SELECT count(*) FROM public.detentions)      AS detentions,
       (SELECT md5(string_agg(id||':'||coalesce(statut,'~'),'|' ORDER BY id COLLATE "C"))
          FROM public.prisonniers_qhs)               AS empreinte_qhs
  FROM public.personnages_donnees;

CREATE OR REPLACE FUNCTION public.detention_clore_interne(
  p_nom text, p_mode text, p_jour integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_jour integer; v_peine jsonb; v_det record; v_qhs boolean;
BEGIN
  IF coalesce(btrim(p_mode),'') = '' THEN
    RAISE EXCEPTION 'detention_clore_interne : le mode de fin est obligatoire';
  END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  -- Le caractere QHS se lit des DEUX cotes : la fiche peut le porter sans la ligne, et l'inverse.
  v_qhs := coalesce((v_peine->>'qhs')::boolean,false) OR coalesce(v_det.qhs,false);
  -- 1. La ligne. `AND mode_fin IS NULL` : une ligne deja close n'est pas reecrite.
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin = p_mode, jour_fin_effective = coalesce(p_jour, v_jour),
           date_fin_effective = now()
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  -- 2. et 3. La fiche, et le drapeau en OBJET -- la forme que pa_repos_nocturne sait lire.
  UPDATE public.personnages_donnees
     SET est_emprisonne = NULL,
         detention_qhs = CASE WHEN v_qhs
           THEN jsonb_build_object('enQHS', false, 'paLimite1Jour', false) ELSE detention_qhs END
   WHERE name = p_nom;
  -- 4. Le registre du QHS, sans quoi le Ministere voit un detenu libre.
  IF v_qhs THEN
    UPDATE public.prisonniers_qhs SET statut='libere'
     WHERE data ->> 'nom' = p_nom AND coalesce(statut,'') = 'detenu';
  END IF;
  RETURN jsonb_build_object('detention_id', v_det.id, 'sortait_du_qhs', v_qhs,
                            'jour', coalesce(p_jour, v_jour),
                            'retour_ville', v_peine ->> 'retourVille');
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_clore_motif_eteint(p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_peine jsonb; v_r jsonb;
BEGIN
  -- LISTE FERMEE : la porte ne sert que ces deux actes administratifs.
  IF p_mode NOT IN ('poursuites_eteintes','incorporation') THEN
    RAISE EXCEPTION 'detention_clore_motif_eteint : mode inconnu « % »', p_mode;
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  IF coalesce((v_peine->>'motifDesertionSeul')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_pas_seulement_desertion'); END IF;
  v_r := public.detention_clore_interne(v_moi, p_mode);
  RETURN v_r || jsonb_build_object('ok', true, 'mode', p_mode);
END; $fn$;

GRANT EXECUTE ON FUNCTION public.detention_clore_motif_eteint(text) TO authenticated;

COMMENT ON FUNCTION public.detention_clore_interne(text,text,integer) IS
'MOTEUR de fin de detention : clot la ligne du registre avec son mode de fin, vide est_emprisonne,
abaisse le drapeau QHS en OBJET s''il etait leve et passe la ligne du registre du QHS a libere --
les quatre ecritures, en une transaction. AUCUNE precondition, AUCUN controle d''autorite : c''est
le role de ses cinq portes (detention_clore_purgee, detention_clore_evasion,
detention_reduire_peine, detention_clore_motif_eteint, presidence_gracier). Non appelable depuis
le reseau.';
COMMENT ON FUNCTION public.detention_clore_motif_eteint(text) IS
'Clot SA PROPRE detention quand son motif est administrativement eteint : « poursuites_eteintes »
(demobilisation) ou « incorporation » (transfert a la caserne). Ne libere que si la detention ne
tenait qu''a la desertion -- regle de jeu existante, qui n''etait verifiee que par le navigateur.
Verdicts : acteur_non_authentifie, non_detenu, peine_pas_seulement_desertion, puis ok avec mode.';

DO $$
DECLARE v_def text; v_droits text; v_av record; v_emp text; v_n int;
BEGIN
  -- P1 : le moteur fait les QUATRE ecritures, n'a aucun controle d'autorite, et est injoignable.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_clore_interne';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- le moteur n''existe pas'; END IF;
  IF position('SET mode_fin = p_mode' in v_def) = 0
     OR position('est_emprisonne = NULL' in v_def) = 0
     OR position('jsonb_build_object(''enQHS'', false, ''paLimite1Jour'', false)' in v_def) = 0
     OR position('prisonniers_qhs SET statut=''libere''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- une des quatre ecritures manque'; END IF;
  IF position('AND mode_fin IS NULL' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- une ligne deja close pourrait etre reecrite'; END IF;
  IF v_def ~ 'mon_personnage|exiger_poste|exiger_acteur' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le moteur porte un controle d''autorite'; END IF;
  IF has_function_privilege('authenticated','public.detention_clore_interne(text,text,integer)','EXECUTE')
     OR has_function_privilege('anon','public.detention_clore_interne(text,text,integer)','EXECUTE') THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le moteur est appelable depuis le reseau'; END IF;

  -- P2 : la porte -- liste fermee, identite lue, regle de jeu conservee, cible non falsifiable.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='detention_clore_motif_eteint';
  IF position('''poursuites_eteintes'',''incorporation''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la liste des modes n''est pas fermee'; END IF;
  IF position('public.mon_personnage()' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''identite n''est pas lue'; END IF;
  IF position('motifDesertionSeul' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la regle de la desertion a disparu'; END IF;
  IF v_def ~ 'p_nom|p_cible' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- un parametre nomme la cible'; END IF;
  IF position('public.detention_clore_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte n''utilise pas le moteur'; END IF;

  -- P3 : les droits.
  SELECT string_agg(coalesce(r.rolname,'PUBLIC'), ',' ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid=ae.grantee
   WHERE p.proname='detention_clore_motif_eteint';
  IF v_droits IS DISTINCT FROM 'authenticated,postgres,service_role' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- droits de la porte : %', v_droits; END IF;

  -- P4 : AUCUNE DONNEE TOUCHEE -- compare a l'etat releve avant, pas a une constante.
  SELECT * INTO v_av FROM zz_etat_avant;
  SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~')
                        ||':'||coalesce(est_emprisonne::text,'~')||':'||coalesce(detention_qhs::text,'~'),
                        '|' ORDER BY name COLLATE "C")) INTO v_emp
    FROM public.personnages_donnees;
  IF v_emp IS DISTINCT FROM v_av.empreinte_personnages THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- les personnages ont bouge pendant cette migration'; END IF;
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> v_av.detentions THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- detentions % -> %', v_av.detentions, v_n; END IF;
  SELECT md5(string_agg(id||':'||coalesce(statut,'~'),'|' ORDER BY id COLLATE "C")) INTO v_emp
    FROM public.prisonniers_qhs;
  IF v_emp IS DISTINCT FROM v_av.empreinte_qhs THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le registre du QHS a bouge'; END IF;

  RAISE NOTICE 'QUATRE PREUVES STRUCTURELLES VERTES.';
END $$;

DROP TABLE zz_etat_avant;