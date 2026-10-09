-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009142500 (UTC ; 16h25 a Paris), nom
-- `detention_porte_du_detenu_sur_lui_meme`. Le registre passe de 570 a 571 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 1c05b66e42058cc41ed6f06e76b1f558, 17 075 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ouvre la septieme porte de `detention_ouvrir_interne` -- celle du detenu sur lui-meme --, qui
-- manquait : les sept appelants de `enregistrerDetention()` visent tous `state.char.name`, et aucun
-- navigateur ne pouvait atteindre la primitive. La chaine ecrivait `detentions` (retour jamais teste)
-- puis `est_emprisonne` (avale) ; quand l'insertion echouait, `detentionId: null` partait quand meme,
-- rendant la peine introuvable pour toute prolongation ou liberation. La primitive gagne un seul
-- parametre, `p_extras`, qui porte les six metadonnees judiciaires que le client transmettait.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `plateau-justice-economie.js`, `plateau-core.js`,
-- `plateau-personnage.js`, `plateau-communication.js` et `plateau-politique.js` ; `sbCreerDetention`,
-- `sbCreerJugement` et `sbCreerPrisonnierQHS` sont supprimees de `supabase.js`.
-- =============================================================================

-- Chantier 5 -- LA PORTE PAR LAQUELLE UN DETENU S'INCARCERE LUI-MEME.
--
-- enregistrerDetention() (plateau-justice-economie.js:10784) est le point de passage de TOUTE
-- incarceration decidee par le navigateur. L'inventaire de ses appelants est sans exception :
-- flagrant delit sur soi (1164), placerAuQHS (1267), rebellion matee (1903), execution d'un avis
-- de recherche SUR SOI (11305), tracts calomnieux (plateau-communication:1075), sentence
-- (plateau-politique:2499). Les sept visent `state.char.name`. La cible, c'est toujours soi --
-- l'arrestation d'un TIERS passe deja par justice_executer_condamnation depuis le 16 septembre.
--
-- Cette chaine ecrivait `detentions` (retour lu mais jamais teste) puis
-- `personnages.est_emprisonne` (avale). Les deux ecritures etant independantes, un detenu pouvait
-- exister dans une table et pas dans l'autre -- et quand c'est l'insertion qui echouait,
-- `detentionId: null` partait quand meme dans est_emprisonne, rendant la peine introuvable pour
-- toute prolongation ou liberation ulterieure.
--
-- detention_ouvrir_interne existait DEJA et portait exactement cette sequence, en une transaction,
-- avec sa garde de rejeu (« cible_deja_detenue ») -- mais aucun navigateur ne pouvait l'appeler :
-- il manquait une porte d'autorite pour le cas « sur soi-meme ». On n'ecrit donc pas une primitive
-- de plus, on lui ouvre sa septieme porte.
--
-- LA PRIMITIVE GAGNE UN SEUL PARAMETRE, p_extras, et pas six. Le client transmettait six
-- metadonnees judiciaires que la primitive ne savait pas porter (ville_condamnation distincte de
-- la ville de detention, jour_affaire, detention_precedente_id, reliquat_jours, retour_ville).
-- Les nommer une par une porterait la signature a quatorze parametres ; p_extras transcrit tel
-- quel l'objet `opts` que le client manipule deja, avec les memes noms que les colonnes. Les six
-- appelants serveur existants passent huit arguments et continuent de resoudre -- le banc le
-- prouve, et prouve aussi qu'ils obtiennent le comportement d'avant, a la valeur pres.
--
-- Banc en transaction annulee : 6 epreuves vertes, dont le rejeu (« cible_deja_detenue », une
-- seule peine), le refus sans identite (aucune ligne creee), et la compatibilite a huit arguments.
DROP FUNCTION IF EXISTS public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text);
CREATE FUNCTION public.detention_ouvrir_interne(
  p_nom text, p_raison text, p_jours integer, p_city text, p_country text,
  p_motifs jsonb, p_autorite text, p_issue text, p_extras jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_id text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6);
  v_jour_cible integer; v_deja jsonb; v_pnj record; v_cellule text;
  v_x jsonb := CASE WHEN jsonb_typeof(p_extras)='object' THEN p_extras ELSE '{}'::jsonb END;
  v_ville_cond text; v_jour_aff integer; v_prec text; v_reliquat integer; v_retour text;
BEGIN
  -- Chacune de ces cinq valeurs vaut NULL quand p_extras l'ignore : un appel a huit arguments
  -- produit donc exactement la ligne qu'il produisait avant ce lot.
  v_ville_cond := coalesce(nullif(v_x->>'ville_condamnation',''), p_city);
  v_jour_aff   := nullif(v_x->>'jour_affaire','')::integer;
  v_prec       := nullif(v_x->>'detention_precedente_id','');
  v_reliquat   := nullif(v_x->>'reliquat_jours','')::integer;
  v_retour     := nullif(v_x->>'retour_ville','');
  SELECT coalesce(d.day,1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_nom, p_country);
    IF v_pnj.systeme IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','cible_introuvable'); END IF;
    IF v_pnj.statut = 'detenu' THEN RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue'); END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok',false,'raison','cible_non_arretable','niveau_connu',v_pnj.niveau_connu,'niveau_requis',2);
    END IF;
    v_jour_cible := public.jour_de_jeu_pays(p_country);
    INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
             autorite,issue_judiciaire,ville_condamnation,provenance,jour_affaire,detention_precedente_id,reliquat_jours)
    VALUES (v_id,p_country,p_city,p_nom,p_raison,v_jour_cible,v_jour_cible+p_jours,false,p_motifs,
             p_autorite,p_issue,v_ville_cond,v_pnj.systeme,v_jour_aff,v_prec,v_reliquat);
    UPDATE public.agents_renseignement
       SET statut='detenu', detention_id=v_id, detenu_depuis=now(), leader_courant=NULL, maj_le=now()
     WHERE id = v_pnj.agent_id RETURNING cellule_id INTO v_cellule;
    PERFORM public.cellule_alerter_ministre(v_cellule, p_nom, 'Agent arrete — ' || p_nom,
      'Votre agent operant sous l''identite de couverture « ' || p_nom ||
      ' » a ete arrete par les autorites de ' || p_country || ' a ' || p_city ||
      '. Il ne peut plus collecter ni etre deplace.');
    RETURN jsonb_build_object('ok',true,'detention_id',v_id,'jour_debut',v_jour_cible,
                              'jour_fin',v_jour_cible+p_jours,'provenance',v_pnj.systeme);
  END IF;
  -- LA GARDE DE REJEU : une peine en cours interdit d'en ouvrir une seconde. C'est elle qui rend
  -- un double appel inoffensif, et elle existait avant ce lot.
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja)='object' THEN
    RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue');
  END IF;
  INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
           autorite,issue_judiciaire,ville_condamnation,jour_affaire,detention_precedente_id,reliquat_jours)
  VALUES (v_id,p_country,p_city,p_nom,p_raison,v_jour_cible,v_jour_cible+p_jours,false,p_motifs,
           p_autorite,p_issue,v_ville_cond,v_jour_aff,v_prec,v_reliquat);
  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object('jours',p_jours,'jourFin',v_jour_cible+p_jours,
           'raison',p_raison,'detentionId',v_id,'qhs',false,'city',p_city,'country',p_country,
           'debutTs',(extract(epoch from clock_timestamp())*1000)::bigint)
         || CASE WHEN v_retour IS NOT NULL THEN jsonb_build_object('retourVille',v_retour) ELSE '{}'::jsonb END
   WHERE name = p_nom;
  RETURN jsonb_build_object('ok',true,'detention_id',v_id,'jour_debut',v_jour_cible,'jour_fin',v_jour_cible+p_jours);
END; $fn$;

-- Le poseur du QHS garde la photo du detenu : c'est la seule donnee que sbCreerPrisonnierQHS
-- portait et que le poseur ne savait pas lire, et le registre du QHS l'affiche.
CREATE OR REPLACE FUNCTION public.detention_qhs_poser_interne(
  p_nom text, p_detention_id text, p_raison text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_det record; v_peine jsonb; v_photo text;
BEGIN
  SELECT country, city, jour_debut, jour_fin INTO v_det
    FROM public.detentions WHERE id = p_detention_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  UPDATE public.detentions SET qhs = true WHERE id = p_detention_id;
  SELECT est_emprisonne, photo_url INTO v_peine, v_photo
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  UPDATE public.personnages_donnees
     SET est_emprisonne = CASE
           WHEN v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object'
           THEN v_peine || jsonb_build_object('qhs', true) ELSE v_peine END,
         -- OBJET, jamais une chaine : c'est la forme que pa_repos_nocturne sait lire.
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false)
   WHERE name = p_nom;
  IF NOT EXISTS (SELECT 1 FROM public.prisonniers_qhs
                  WHERE data ->> 'nom' = p_nom AND coalesce(statut,'') <> 'transfere') THEN
    INSERT INTO public.prisonniers_qhs (id, statut, data)
    VALUES ('qhs-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
              || substr(md5(random()::text),1,6), 'detenu',
            jsonb_build_object('pays', v_det.country, 'nom', p_nom,
                               'raison', coalesce(nullif(btrim(p_raison),''),'Sentence'),
                               'photoUrl', v_photo,
                               'jourDebut', v_det.jour_debut, 'jourFin', v_det.jour_fin));
  END IF;
END; $fn$;

CREATE OR REPLACE FUNCTION public.detention_ouvrir_soi(
  p_raison text, p_jours integer, p_city text DEFAULT NULL,
  p_motifs jsonb DEFAULT NULL, p_qhs boolean DEFAULT false, p_extras jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_pays text; v_ville text; v_jour integer; v_r jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_jours IS NULL OR p_jours < 0 OR p_jours > 3650 THEN
    RETURN jsonb_build_object('ok',false,'raison','duree_invalide'); END IF;
  -- Le pays et le JOUR viennent de la fiche, jamais de l'appelant : jour_fin se calcule donc sur
  -- le compteur que le serveur detient, exactement comme pour une arrestation par un tiers.
  SELECT country, coalesce(nullif(btrim(p_city),''), current_city, 'capitale'), coalesce(day,1)
    INTO v_pays, v_ville, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  v_r := public.detention_ouvrir_interne(v_moi, p_raison, p_jours, v_ville, v_pays,
           CASE WHEN jsonb_typeof(p_motifs)='array' AND jsonb_array_length(p_motifs) > 0 THEN p_motifs
                ELSE jsonb_build_array(jsonb_build_object('type',coalesce(p_raison,'Detention'),
                       'jour_fait',v_jour,'city',v_ville,'jours',p_jours,
                       'source','detention_ouvrir_soi','date_evenement',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))) END,
           nullif(p_extras->>'autorite',''), nullif(p_extras->>'issue_judiciaire',''), p_extras);
  IF NOT coalesce((v_r->>'ok')::boolean,false) THEN RETURN v_r; END IF;
  IF p_qhs THEN
    PERFORM public.detention_qhs_poser_interne(v_moi, v_r->>'detention_id', p_raison);
    RETURN v_r || jsonb_build_object('qhs', true);
  END IF;
  RETURN v_r;
END; $fn$;

GRANT EXECUTE ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) TO authenticated;

COMMENT ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) IS
'PRIMITIVE d''incarceration : ouvre la ligne detentions et pose est_emprisonne dans la meme
transaction, refuse une cible deja detenue, et sait arreter un PNJ comme un PJ. AUCUN controle
d''autorite -- c''est le role de ses portes (justice_executer_condamnation, arrestation_urgence,
enquete_garde_a_vue, fraude_electorale_sanctionner, plainte_instruire_interne,
militaire_bataille_appliquer, detention_ouvrir_soi). p_extras porte les metadonnees judiciaires
optionnelles : ville_condamnation, jour_affaire, detention_precedente_id, reliquat_jours,
retour_ville. Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) IS
'S''incarcerer SOI-MEME : flagrant delit sur soi, placement au QHS, rebellion matee, sentence,
tracts calomnieux. L''identite, le pays et le jour viennent du serveur, jamais de l''appelant.
Verdicts : acteur_non_authentifie, duree_invalide, cible_deja_detenue, puis ok avec detention_id,
jour_debut et jour_fin.';

DO $$
DECLARE v_def text; v_droits text; v_n int; v_ecrivains text;
BEGIN
  -- P1 : la primitive a NEUF parametres, le neuvieme est optionnel, et ses six appelants
  -- historiques existent toujours.
  SELECT pg_get_function_arguments(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_ouvrir_interne';
  IF v_def IS DISTINCT FROM 'p_nom text, p_raison text, p_jours integer, p_city text, p_country text, p_motifs jsonb, p_autorite text, p_issue text, p_extras jsonb DEFAULT NULL::jsonb' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- signature inattendue : %', v_def;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_ouvrir_interne';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % surcharges de la primitive', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname='public'
   WHERE p.proname IN ('arrestation_urgence','enquete_garde_a_vue','fraude_electorale_sanctionner',
                       'justice_executer_condamnation','militaire_bataille_appliquer','plainte_instruire_interne')
     AND pg_get_functiondef(p.oid) ~ 'detention_ouvrir_interne';
  IF v_n <> 6 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % appelants de la primitive au lieu de 6', v_n; END IF;

  -- P2 : les DEUX insertions portent les colonnes judiciaires, et la primitive n'ecrit jamais
  -- qhs = true elle-meme (c'est le poseur qui le fait, et lui seul).
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_ouvrir_interne';
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, 'detention_precedente_id,reliquat_jours', 'g');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % insertion(s) portent les colonnes judiciaires au lieu de 2', v_n; END IF;
  IF v_def ~ 'SET qhs' THEN RAISE EXCEPTION 'P2 ECHOUEE -- la primitive ecrit le QHS'; END IF;
  IF position('retourVille' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- retour_ville n''atteint pas est_emprisonne'; END IF;

  -- P3 : le poseur porte la photo.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_qhs_poser_interne';
  IF position('''photoUrl'', v_photo' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la photo du detenu n''est pas portee au registre du QHS'; END IF;

  -- P4 : la porte lit son identite et ne peut pas nommer une autre cible.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname='public'
   WHERE p.proname = 'detention_ouvrir_soi';
  IF position('public.mon_personnage()' in v_def) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- l''identite n''est pas lue'; END IF;
  IF v_def ~ 'p_nom|p_cible' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un parametre nomme la cible : elle serait falsifiable'; END IF;
  IF position('public.detention_ouvrir_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la porte duplique la primitive au lieu de l''appeler'; END IF;

  -- P5 : les droits. Primitive et poseur injoignables depuis le reseau, porte ouverte.
  IF has_function_privilege('authenticated','public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)','EXECUTE')
     OR has_function_privilege('authenticated','public.detention_qhs_poser_interne(text,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un interne est appelable depuis le reseau';
  END IF;
  SELECT string_agg(coalesce(r.rolname,'PUBLIC'), ',' ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname = 'detention_ouvrir_soi';
  IF v_droits IS DISTINCT FROM 'authenticated,postgres,service_role' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- droits de la porte : %', v_droits; END IF;

  -- P6 : l'ensemble des ecrivains du drapeau QHS est INCHANGE par ce lot.
  SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_ecrivains
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE pg_get_functiondef(p.oid) ~ 'detention_qhs\s*=';
  IF v_ecrivains IS DISTINCT FROM
     'detention_qhs_poser_interne, pa_repos_nocturne, personnages_vue_modifier, qhs_pouvoir' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les ecrivains de detention_qhs sont « % »', v_ecrivains;
  END IF;

  -- P7 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % detention(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.prisonniers_qhs;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % ligne(s) QHS au lieu de 1', v_n; END IF;
  IF (SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~'),'|' ORDER BY name COLLATE "C"))
        FROM public.personnages_donnees) IS DISTINCT FROM 'db4a44dee1b87f6ccd06610120f305ed' THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- les personnages ont bouge';
  END IF;

  RAISE NOTICE 'SEPT PREUVES STRUCTURELLES VERTES.';
END $$;