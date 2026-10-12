-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012102519 (UTC), nom
-- `parquet_la_defense_retrouve_un_statut_qui_existe`.
-- Le registre passe de 678 a 679 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e0da1e959f77cfa421ded73ee1dc59ff, 8939 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (8/8) -- LA DEFENSE DE L'ACCUSE RETROUVE UN STATUT QUI EXISTE
--
-- CELLE-CI REPARE UN DEFAUT QUE LES SEPT PRECEDENTES ONT CREE, et c'est le banc du cycle des
-- plaintes qui l'a nomme en voulant etre rejoue. `plainte_defendre` gardait l'accuse sur
-- `status = 'deposee'`. Ce statut est mort cette nuit : plus aucune porte ne le produit. La
-- defense etait donc devenue IMPOSSIBLE SUR TOUT DOSSIER -- et le navigateur offrait toujours le
-- bouton, a 2 PA et 300 FR par tentative refusee.
--
-- LA TRADUCTION EST UN STATUT POUR UN STATUT. `deposee` ne voulait pas dire « une affaire
-- vivante contre moi » : l'ancienne chaine avait DEUX statuts vivants avant jugement --
-- `deposee` et `enquete_ouverte` -- et la porte n'acceptait que le premier. La regle etait donc
-- « on se defend tant qu'aucune autorite n'a agi », et son homologue exact est `au_parquet`,
-- seul. Ouvrir la defense aux cinq statuts vivants du parquet aurait CREE un pouvoir que
-- l'ancienne regle ne donnait pas : un arbitrage de game design, pas une migration. Le filtre
-- client, qui avait pris cette liberte quelques heures plus tot dans la meme passe, est ramene
-- au meme statut unique.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA DEFENSE DE L'ACCUSE RETROUVE UN STATUT QUI EXISTE
-- 12 octobre 2026, nuit -- huitieme et derniere migration de la tranche du parquet
--
-- LE DEFAUT, ET IL EST ENTIEREMENT DE CETTE TRANCHE. `plainte_defendre` garde l'accuse sur
-- `status = 'deposee'`. Or `deposee` EST UN STATUT MORT depuis cette nuit : plus aucune porte ne
-- le produit -- `plainte_deposer` ecrit `au_parquet`, `affaire_transmettre` aussi. La condition
-- etait donc devenue impossible a satisfaire, et se defendre impossible SUR TOUT DOSSIER. Le
-- navigateur, lui, offrait toujours le bouton : un ordre paye 2 PA et 300 FR, puis un refus
-- `affaire_non_defendable` a tous les coups.
--
-- LA TRADUCTION EST UN STATUT POUR UN STATUT, ET C'EST VOULU. `deposee` ne voulait pas dire
-- « une affaire vivante contre moi » : l'ancienne chaine avait DEUX statuts vivants avant
-- jugement -- `deposee` et `enquete_ouverte` -- et cette porte n'acceptait que le premier. La
-- regle de jeu etait donc : on se defend TANT QU'AUCUNE AUTORITE N'A AGI, et plus une fois
-- l'enquete ouverte. Son homologue exact dans la chaine du parquet est `au_parquet`, et lui seul.
-- Ouvrir la defense aux cinq statuts vivants du parquet -- enquete, poursuites, saisie,
-- abandon_demande -- serait CREER une possibilite que l'ancienne regle ne donnait pas : un
-- arbitrage de game design, pas une migration. L'ancien `enquete_ouverte` reste refuse comme
-- avant, par le simple fait qu'il n'est pas `au_parquet`.
--
-- CE QUI N'EST PAS TOUCHE, ET POURQUOI. La reussite critique continue de poser `status: 'jugee'`,
-- donc de clore le dossier avant que le Procureur ne l'ait regarde. Ce n'est pas une nouveaute :
-- au stade `deposee`, l'ancienne chaine le permettait exactement de la meme facon. On ne retire
-- pas un pouvoir en passant, et on n'en ajoute pas.
--
-- PREUVES STRUCTURELLES -- 6. Elles ne prouvent pas un comportement : c'est l'office de
-- banc-cycle-plaintes-2.sql, qui joue la defense pour de vrai.

CREATE OR REPLACE FUNCTION public.plainte_defendre(p_affaire_id text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_nom text; v_brut text; v_data jsonb; v_maj jsonb;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  -- LISTE CLOSE DES QUATRE ISSUES de la formule de defense de `data.js` : reussite eclatante
  -- (classe l'affaire), reussite simple (circonstance attenuante), echec flagrant (aggravation),
  -- echec simple (aucun effet).
  IF p_issue NOT IN ('reussite_critique', 'attenuante', 'aggravation', 'infructueuse') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'issue_inconnue');
  END IF;

  SELECT data INTO v_brut FROM public.plaintes_en_cours WHERE id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_data := v_brut::jsonb;
  -- `affaire_me_concerne` accordait l'ecriture a la cible ET au plaignant, sur le blob entier.
  -- Se defendre est le fait de l'ACCUSE, et de lui seul.
  IF coalesce(v_data ->> 'cible', '') IS DISTINCT FROM v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire');
  END IF;
  -- LE DOSSIER DOIT ETRE AU PARQUET, ET RIEN D'AUTRE. C'est la meme regle qu'avant, dite dans la
  -- nomenclature du parquet : on se defend tant qu'aucune autorite n'a agi. Le statut nomme ici
  -- est celui qu'ecrivent `plainte_deposer` et `affaire_transmettre` -- une porte qui garde sur
  -- un statut que plus rien ne produit est une porte fermee, et c'etait le cas pendant quelques
  -- heures cette nuit. Arretee sous verrou : un dossier deja qualifie, poursuivi, juge ou classe
  -- ne peut plus etre rouvert par une defense partie d'un ecran perime.
  IF coalesce(v_data ->> 'status', '') IS DISTINCT FROM 'au_parquet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_defendable',
                              'statut', v_data ->> 'status');
  END IF;

  -- UNE DEFENSE PEUT ETRE RETENTEE, et c'est la regle existante : les trois issues qui ne
  -- classent pas l'affaire la laissent au parquet, et l'ordre est payant a chaque fois (2 PA et
  -- 300 FR, preleves par `deduireCoutOrdre` avant l'appel). On ne la verrouille donc pas.
  v_maj := jsonb_build_object('defendue_par', v_nom, 'defendue_le',
                              to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  IF p_issue = 'reussite_critique' THEN
    v_maj := v_maj || jsonb_build_object('status', 'jugee', 'resultatDefense', 'reussite_critique');
  ELSIF p_issue = 'attenuante' THEN
    v_maj := v_maj || jsonb_build_object('circonstanceAttenuante', true);
  ELSIF p_issue = 'aggravation' THEN
    v_maj := v_maj || jsonb_build_object('aggravation', true);
  END IF;

  v_data := v_data || v_maj;
  -- Le laissez-passer ne dure que cette ecriture (voir le trigger `plaintes_epingler_verdict`).
  PERFORM set_config('rp.verdict_interne', 'on', true);
  UPDATE public.plaintes_en_cours SET data = v_data::text WHERE id = p_affaire_id;
  PERFORM set_config('rp.verdict_interne', '', true);
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'affaire', v_data);
END; $$;

COMMENT ON FUNCTION public.plainte_defendre(text, text) IS
  'La defense de l''accuse, et de lui seul. Le dossier doit etre AU PARQUET : c''est la traduction exacte de l''ancienne garde sur `deposee` -- on se defend tant qu''aucune autorite n''a agi -- et non la reunion des cinq statuts vivants du parquet, qui donnerait un pouvoir que l''ancienne regle ne donnait pas. La reussite critique clot le dossier, comme avant.';

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : UNE SEULE SIGNATURE. Un CREATE OR REPLACE avec un parametre de plus CREE une fonction.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- % signature(s) de plainte_defendre au lieu d''une', v_n; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plainte_defendre';

  -- P2 : LA GARDE NOMME `au_parquet`. Assertion POSITIVE sur l'expression entiere, pas sur le
  -- mot seul : le commentaire de la fonction cite `deposee` pour expliquer ce qu'il remplace, et
  -- une assertion d'absence du mot echouerait sur son propre commentaire -- le piege du
  -- commentaire, rencontre trois fois en deux jours sur ce depot.
  IF position('IS DISTINCT FROM ''au_parquet''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la garde de la defense ne nomme pas au_parquet'; END IF;

  -- P3 : PLUS AUCUNE PORTE DU SCHEMA NE GARDE SUR `deposee`. On cherche l'EXPRESSION de garde,
  -- jamais le mot : `plainte_deposer` garde deliberement `deposee` et `enquete_ouverte` dans sa
  -- liste anti-spam, pour couvrir une eventuelle ligne de l'ancienne chaine restee ouverte.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prokind IN ('f','p')
     AND position('IS DISTINCT FROM ''deposee''' IN p.prosrc) > 0;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- % fonction(s) gardent encore sur le statut mort deposee', v_n; END IF;

  -- P4 : LE STATUT NOMME PAR LA GARDE EST REELLEMENT PRODUIT. Une garde sur un statut que rien
  -- n'ecrit est une porte fermee : c'est exactement le defaut que cette migration repare.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prokind IN ('f','p')
     AND position('''status'', ''au_parquet''' IN p.prosrc) > 0;
  IF v_n < 2 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- seules % porte(s) ecrivent le statut au_parquet', v_n; END IF;

  -- P5 : LES QUATRE ISSUES SONT INTACTES. Rien de la formule de defense n'a bouge.
  IF position('''reussite_critique'', ''attenuante'', ''aggravation'', ''infructueuse''' IN v_txt) = 0
     OR position('''status'', ''jugee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la liste des issues ou la cloture par reussite critique a bouge'; END IF;

  -- P6 : LE LAISSEZ-PASSER DU DECLENCHEUR EST TOUJOURS POSE PUIS RETIRE. Sans lui,
  -- `plaintes_epingler_verdict` restaurerait les champs que la defense vient d'ecrire -- l'accuse
  -- n'est jamais une autorite judiciaire. Et sans le retrait, il durerait toute la transaction.
  IF position('set_config(''rp.verdict_interne'', ''on'', true)' IN v_txt) = 0
     OR position('set_config(''rp.verdict_interne'', '''', true)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- le laissez-passer du declencheur n''est pas pose puis retire'; END IF;

  RAISE NOTICE 'LES 6 PREUVES SONT VERTES.';
END $preuves$;
