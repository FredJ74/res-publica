-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009142903 (UTC ; 16h29 a Paris), nom
-- `detention_clore_et_transferer_au_qhs`. Le registre passe de 571 a 572 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 38813be3a6521fee60467efe9918410a, 13 244 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme deux chaines. La FIN DE PEINE ne persistait JAMAIS `est_emprisonne = null` : elle vidait
-- `state.estEmprisonne` en memoire, de sorte qu'un joueur libere qui fermait son onglet restait
-- incarcere en base, drapeau QHS leve et plafond de PA applique. Le TRANSFERT AU QHS faisait quatre
-- ecritures independantes, chacune avalee, pour une seule bascule. Les deux portes garantissent
-- desormais, quel que soit le nombre d'appels, exactement UNE peine en cours et UNE ligne au registre
-- du QHS -- sans rendre le transfert idempotent, car une seconde rebellion n'est pas un rejeu.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `plateau-justice-economie.js`
-- (`verifierLiberationPrisonniers`, `doSeRebeller`).
-- =============================================================================

-- Chantier 5 -- LA FIN D'UNE PEINE EST UNE OPERATION, PAS DEUX ECRITURES AVALEES.
--
-- Deux chaines se fermaient ici, toutes deux dans plateau-justice-economie.js.
--
-- FIN DE DETENTION (verifierLiberationPrisonniers, ~1289). Le navigateur ecrivait
-- `detentions.mode_fin = 'purgee'` puis `personnages.detention_qhs`, les deux avalees -- et, ce
-- que l'inventaire n'avait pas vu, IL NE PERSISTAIT JAMAIS `est_emprisonne = null`. Il se
-- contentait de vider `state.estEmprisonne` en memoire, en comptant sur un `sbSavePersonnage`
-- ulterieur. Un joueur libere qui fermait son onglet restait donc incarcere en base : la peine
-- purgee se « reliberait » a chaque session, le drapeau QHS restait leve, et le plafond de PA du
-- quartier de haute securite continuait de s'appliquer. La porte vide la fiche DANS LA MEME
-- TRANSACTION que la cloture de la ligne. Ce n'est pas une regle nouvelle : le client se
-- considerait deja libre : c'est la base qui ne le savait pas.
--
-- Et le drapeau tombait sous la forme `JSON.stringify({enQHS:false})`, donc un SCALAIRE de type
-- string sur une colonne jsonb -- illisible pour pa_repos_nocturne, qui exige un objet. Le
-- drapeau est desormais abaisse en OBJET, et la ligne du registre du QHS passe a 'libere' : sans
-- cela un detenu libere restait affiche comme detenu au ministere de la Justice.
--
-- TRANSFERT AU QHS (doSeRebeller, branche « rebellion matee », ~1893). Trois tables, trois
-- `.catch(() => {})` : `detentions` (cloture par transfert), `prisonniers_qhs` (inscription),
-- `personnages` (drapeau), puis une QUATRIEME ecriture via enregistrerDetention pour la nouvelle
-- peine. Quatre ecritures independantes pour une seule bascule : le detenu pouvait se retrouver
-- sans peine en cours, ou avec deux, ou au QHS sans peine.
--
-- CE QUI N'EST PAS DEVENU IDEMPOTENT, ET POURQUOI. Un second transfert n'est pas un rejeu : c'est
-- une seconde rebellion, et le jeu la permet -- le comportement d'origine faisait exactement cela.
-- Refuser le second appel changerait une regle de jeu, ce que ce lot n'a pas le droit de faire.
-- Ce que la porte garantit, c'est l'invariant que le cahier des charges demande reellement :
-- quel que soit le nombre d'appels, exactement UNE peine en cours, chainee a la precedente par
-- detention_precedente_id, aucune ligne a demi fermee, et UNE SEULE ligne au registre du QHS.
-- La cloture, elle, est bien idempotente : rejouee, elle rend « non_detenu » sans rien reecrire.
--
-- Banc en transaction annulee : 7 epreuves vertes.
CREATE OR REPLACE FUNCTION public.detention_clore_purgee()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb; v_fin integer; v_qhs boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  -- LE JOUR DE REFERENCE EST CELUI DE LA FICHE, jamais un parametre : sinon la liberation serait
  -- a la main du navigateur. C'est exactement la condition du client (state.day >= jourFin),
  -- lue sur la colonne dont state.day est le miroir.
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_fin := coalesce((v_peine ->> 'jourFin')::integer, v_det.jour_fin);
  IF v_fin IS NULL OR v_jour < v_fin THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_non_purgee','jour',v_jour,'jour_fin',v_fin);
  END IF;
  v_qhs := coalesce((v_peine ->> 'qhs')::boolean, false) OR coalesce(v_det.qhs, false);
  IF v_det.id IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin='purgee', jour_fin_effective=v_jour, date_fin_effective=now()
     WHERE id = v_det.id AND mode_fin IS NULL;
  END IF;
  UPDATE public.personnages_donnees
     SET est_emprisonne = NULL,
         -- Le drapeau tombe en OBJET, et seulement s'il etait leve : une peine ordinaire ne doit
         -- pas poser un drapeau QHS absent.
         detention_qhs = CASE WHEN v_qhs
           THEN jsonb_build_object('enQHS', false, 'paLimite1Jour', false) ELSE detention_qhs END
   WHERE name = v_moi;
  IF v_qhs THEN
    UPDATE public.prisonniers_qhs SET statut='libere'
     WHERE data ->> 'nom' = v_moi AND coalesce(statut,'') = 'detenu';
  END IF;
  RETURN jsonb_build_object('ok',true,'detention_id',v_det.id,'jour',v_jour,
                            'sortait_du_qhs',v_qhs,'retour_ville',v_peine ->> 'retourVille');
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_transferer_qhs(
  p_raison text, p_jours integer, p_city text DEFAULT NULL, p_motifs jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_det record; v_jour integer; v_peine jsonb; v_r jsonb; v_prec text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_jours IS NULL OR p_jours <= 0 OR p_jours > 3650 THEN
    RETURN jsonb_build_object('ok',false,'raison','duree_invalide'); END IF;
  SELECT coalesce(day,1), est_emprisonne INTO v_jour, v_peine
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  v_prec := v_det.id;
  -- 1. L'ANCIENNE LIGNE EST CLOSE EXPLICITEMENT. La laisser a NULL la ferait apparaitre comme
  --    encore en cours dans le registre, ce qui est faux : elle est terminee, juste pas par une
  --    liberation. Commentaire d'origine du client, conserve parce qu'il dit le vrai.
  IF v_prec IS NOT NULL THEN
    UPDATE public.detentions
       SET mode_fin='transfert_qhs', jour_fin_effective=v_jour, date_fin_effective=now()
     WHERE id = v_prec;
  END IF;
  -- 2. est_emprisonne est vide AVANT la reouverture : la primitive refuse une cible deja detenue.
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = v_moi;
  -- 3. La nouvelle peine passe par la primitive canonique, qui la chaine a la precedente.
  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours,
           coalesce(nullif(btrim(p_city),''), v_det.city, 'qhs'),
           coalesce(v_det.country, (SELECT country FROM public.personnages_donnees WHERE name=v_moi)),
           CASE WHEN jsonb_typeof(p_motifs)='array' AND jsonb_array_length(p_motifs) > 0 THEN p_motifs
                ELSE jsonb_build_array(jsonb_build_object('type',coalesce(p_raison,'Transfert QHS'),
                       'jour_fait',v_jour,'jours',p_jours,'source','detention_transferer_qhs')) END,
           NULL, NULL,
           jsonb_build_object('detention_precedente_id', v_prec,
                              'retour_ville', v_peine ->> 'retourVille'));
  -- 4. SI LA REOUVERTURE ECHOUE, RIEN NE RESTE : on LEVE, et la transaction de la RPC emporte la
  --    cloture de l'etape 1. Rendre un verdict ici laisserait un detenu sans peine en cours.
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN
    RAISE EXCEPTION 'detention_transferer_qhs : reouverture impossible (%)', v_r ->> 'raison';
  END IF;
  PERFORM public.detention_qhs_poser_interne(v_moi, v_r ->> 'detention_id', p_raison);
  RETURN v_r || jsonb_build_object('qhs', true, 'detention_precedente', v_prec);
END; $fn$;

GRANT EXECUTE ON FUNCTION public.detention_clore_purgee() TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) TO authenticated;

COMMENT ON FUNCTION public.detention_clore_purgee() IS
'Clot SA PROPRE peine quand elle est purgee : mode_fin = purgee, est_emprisonne vide, drapeau QHS
abaisse en OBJET et ligne du registre du QHS passee a libere -- en une transaction. Le jour de
reference vient de la fiche, jamais de l''appelant. Idempotente : rejouee, elle rend non_detenu.
Verdicts : acteur_non_authentifie, non_detenu, peine_non_purgee, puis ok.';
COMMENT ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) IS
'Bascule SA PROPRE detention en cours vers le quartier de haute securite : clot l''ancienne ligne
par transfert_qhs, en ouvre une nouvelle qui la cite via detention_precedente_id, et pose le
drapeau QHS -- en une transaction. N''est PAS idempotente a dessein : un second appel est une
seconde rebellion, que le jeu permet. L''invariant tenu est qu''exactement une peine reste en
cours. Verdicts : acteur_non_authentifie, duree_invalide, non_detenu, puis ok.';

DO $$
DECLARE v_def text; v_droits text; v_n int;
BEGIN
  -- P1 : la cloture lit son identite et son jour, et ne recoit ni l'un ni l'autre.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_clore_purgee';
  IF position('public.mon_personnage()' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''identite n''est pas lue'; END IF;
  IF pg_get_function_arguments((SELECT p.oid FROM pg_proc p
       JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
      WHERE p.proname='detention_clore_purgee')) <> '' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la cloture prend un parametre'; END IF;

  -- P2 : la cloture fait bien les QUATRE ecritures, dont celle que le client ne faisait pas.
  IF position('est_emprisonne = NULL' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- est_emprisonne n''est pas vide en base'; END IF;
  IF position('mode_fin=''purgee''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la ligne n''est pas close'; END IF;
  IF position('jsonb_build_object(''enQHS'', false, ''paLimite1Jour'', false)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le drapeau n''est pas abaisse en objet'; END IF;
  IF position('prisonniers_qhs SET statut=''libere''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le registre du QHS n''est pas mis a jour'; END IF;
  IF position('AND mode_fin IS NULL' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- une ligne deja close pourrait etre reecrite'; END IF;

  -- P3 : le transfert delegue la reouverture a la primitive et LEVE si elle refuse.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_transferer_qhs';
  IF position('public.detention_ouvrir_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le transfert duplique la primitive'; END IF;
  IF position('RAISE EXCEPTION' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un echec de reouverture laisserait la cloture en place'; END IF;
  IF position('''mode_fin'', ''transfert_qhs''' in v_def) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- forme inattendue de la cloture'; END IF;
  IF position('mode_fin=''transfert_qhs''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''ancienne ligne n''est pas close par transfert'; END IF;
  IF position('''detention_precedente_id'', v_prec' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la nouvelle peine ne cite pas la precedente'; END IF;
  IF v_def ~ 'p_nom|p_cible' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un parametre nomme la cible'; END IF;
  IF position('public.detention_qhs_poser_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le drapeau n''est pas pose par son unique ecrivain'; END IF;

  -- P4 : les droits des deux portes.
  SELECT string_agg(p.proname || '=' || coalesce(r.rolname,'PUBLIC'), ', ' ORDER BY p.proname, coalesce(r.rolname,'PUBLIC'))
    INTO v_droits
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname IN ('detention_clore_purgee','detention_transferer_qhs');
  IF v_droits IS DISTINCT FROM
     'detention_clore_purgee=authenticated, detention_clore_purgee=postgres, detention_clore_purgee=service_role, detention_transferer_qhs=authenticated, detention_transferer_qhs=postgres, detention_transferer_qhs=service_role' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- droits : %', v_droits; END IF;

  -- P5 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % detention(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.prisonniers_qhs;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % ligne(s) QHS au lieu de 1', v_n; END IF;
  IF (SELECT day FROM public.personnages_donnees WHERE name='Ben') <> 1 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le jour du personnage du banc a bouge'; END IF;
  IF (SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~'),'|' ORDER BY name COLLATE "C"))
        FROM public.personnages_donnees) IS DISTINCT FROM 'db4a44dee1b87f6ccd06610120f305ed' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- les personnages ont bouge';
  END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;