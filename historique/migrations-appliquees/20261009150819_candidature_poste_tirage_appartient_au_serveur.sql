-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009150819 (UTC ; 17h08 a Paris), nom
-- `candidature_poste_tirage_appartient_au_serveur`. Le registre passe de 573 a 574 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e6e91bfc4af5d5975b32b4bb33e9303e, 13 092 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme le tirage au sort des postes nommes non tranches en 48h : le gagnant etait tire en
-- JavaScript, puis six ecritures independantes et avalees appliquaient la decision, et le drapeau
-- `traitee` n'etait ecrit qu'APRES la boucle entiere -- une coupure en cours de passe perdait TOUS
-- les drapeaux, et le rejeu de la nuit suivante pouvait designer un autre gagnant et diviser une
-- SECONDE fois la POP du nominateur. Le tirage est maintenant dans la transaction, apres la
-- revendication de la brique `actes_nocturnes`, qu'un rejeu n'atteint donc jamais.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `api/cron-minuit.js`
-- (`traiterCandidaturesPostesExpirees` ; `sbSupprimerTitulairePnjServeur` supprimee).
-- =============================================================================

-- Chantier 6 -- LE TIRAGE AU SORT APPARTIENT A LA TRANSACTION QUI L'APPLIQUE.
--
-- traiterCandidaturesPostesExpirees (api/cron-minuit.js:5145) tirait le gagnant en JavaScript
-- -- `candidatsEligibles[Math.floor(Math.random() * ...)]` -- puis demandait au serveur
-- d'appliquer, en SIX ecritures independantes toutes avalees : suppression du titulaire PNJ,
-- registre postes_attribues, fiche du gagnant, courrier au gagnant, division par deux de la POP
-- du nominateur reste passif, courrier au nominateur. Et le drapeau `traitee` du dossier n'etait
-- ecrit qu'APRES la boucle entiere, en un seul sbSetBatimentEtat : une coupure en cours de passe
-- perdait TOUS les drapeaux. Au rejeu, la nuit suivante, le tirage recommencait -- autre gagnant
-- possible, POP du nominateur divisee une SECONDE fois, deux courriers de plus.
--
-- La porte fait les six ecritures en une transaction, et le tirage est dedans : un rejeu
-- n'atteint jamais le `ORDER BY random()`, puisque la revendication le refuse avant.
--
-- LA REVENDICATION EST LA BRIQUE DU CHANTIER 6, pas une garde ecrite a la main.
-- acte_nocturne_revendiquer(pays, 'candidature_poste_tirage', '<poste>|<ville>') INSERT dans une
-- cle primaire (pays, mecanisme, sujet, jour) et rend false si la ligne existait. Elle est
-- appelee DANS cette transaction : si une etape ulterieure echoue, la revendication est annulee
-- avec elle et la nuit suivante retentera. C'est pourquoi acte_nocturne_revendiquer n'est
-- appelable ni par anon, ni par authenticated, NI PAR service_role -- revendiquer hors de la
-- transaction de l'effet serait exactement le defaut qu'on ferme.
--
-- ORDRE DES DEUX GARDES, ET IL COMPTE. Le poste deja tenu par un joueur est verifie AVANT la
-- revendication : ce n'est pas « deja fait aujourd'hui », c'est « il n'y a rien a faire ». La
-- journee reste donc ouverte, et le dossier sera reexamine -- comportement du code d'origine,
-- qui annulait sans sanction (§7 du lot du 25 aout 2026).
--
-- CE QUI RESTE EN JAVASCRIPT, ET POURQUOI. Le filtre d'eligibilite lit `regle.compatibles`, qui
-- n'existe PAS dans le miroir postes_nommes_regles : le serveur ne peut pas le reconstituer sans
-- qu'on l'invente. Le cron continue donc d'etablir la liste des candidats eligibles, et la porte
-- reverifie ce qu'elle peut seule (le personnage existe, il est du bon pays). Ce qui a change,
-- c'est que le CHOIX n'est plus fait dehors.
--
-- AUCUNE REGLE DE CANDIDATURE NE CHANGE : tirage uniforme, POP divisee par deux avec le meme
-- Math.floor et le meme plancher a zero, memes sujets et memes corps de courrier, meme source
-- 'tirage_au_sort_candidature' au registre. Et le courrier reste une NOTIFICATION : il passe par
-- mail_systeme_envoyer, qui ne casse jamais l'acte (doctrine du 9 octobre 2026).
--
-- Banc en transaction annulee : 7 epreuves vertes, dont le rejeu qui ne redivise pas la POP, ne
-- designe pas un autre gagnant et n'envoie pas un second courrier.
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
VALUES ('candidature_poste_tirage', false,
        'Nomination par tirage au sort d''une candidature a un poste nomme dont l''autorite n''a pas tranche dans les 48h. Un rejeu redesignerait un gagnant et rediviserait par deux la POP du nominateur. Un sujet par poste : « <poste_id>|<ville ou national> ».')
ON CONFLICT (mecanisme) DO NOTHING;

CREATE OR REPLACE FUNCTION public.candidature_poste_tirage_appliquer(
  p_pays text, p_poste_id text, p_city text, p_label text,
  p_candidats text[], p_autorite text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_pays text := lower(btrim(coalesce(p_pays,''))); v_poste text := btrim(coalesce(p_poste_id,''));
  v_city text := nullif(btrim(coalesce(p_city,'')),'');
  v_lib text; v_sujet text; v_gagnant text; v_titulaire text;
  v_res jsonb; v_pop_avant numeric; v_pop_apres numeric; v_sanction boolean := false;
BEGIN
  -- FAIL-CLOSED : une identite incomplete LEVE. Rendre un verdict voudrait dire « rien a faire ».
  IF v_pays = '' OR v_poste = '' THEN
    RAISE EXCEPTION 'candidature_poste_tirage_appliquer : pays et poste sont obligatoires (pays=%, poste=%)', p_pays, p_poste_id;
  END IF;
  IF p_candidats IS NULL OR array_length(p_candidats, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_candidat');
  END IF;
  v_lib := coalesce(nullif(btrim(coalesce(p_label,'')),''), v_poste);
  v_sujet := v_poste || '|' || coalesce(v_city, 'national');

  -- 1. RIEN A FAIRE ? Le registre fait autorite depuis le 15 septembre 2026. Verifie AVANT la
  --    revendication, pour ne pas consommer la journee d'un dossier qu'on n'a pas traite.
  SELECT titulaire INTO v_titulaire FROM public.postes_attribues
   WHERE country = v_pays AND poste_id = v_poste AND city IS NOT DISTINCT FROM v_city FOR UPDATE;
  IF v_titulaire IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_titulaire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_attribue', 'titulaire', v_titulaire);
  END IF;

  -- 2. LA REVENDICATION, dans cette transaction.
  IF NOT public.acte_nocturne_revendiquer(v_pays, 'candidature_poste_tirage', v_sujet,
         jsonb_build_object('poste', v_poste, 'ville', v_city)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traite_aujourdhui');
  END IF;

  -- 3. LE TIRAGE. Uniforme, comme Math.random() cote JavaScript, mais ici il est INDISSOCIABLE
  --    de ses consequences : un rejeu ne l'atteint pas.
  SELECT d.name INTO v_gagnant FROM public.personnages_donnees d
   WHERE d.name = ANY (p_candidats) AND d.country = v_pays ORDER BY random() LIMIT 1;
  IF v_gagnant IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'gagnant', NULL, 'raison', 'aucun_candidat_eligible');
  END IF;

  -- 4. LES CONSEQUENCES. REGISTRE D'ABORD : la fiche n'est plus une preuve, c'est
  --    postes_attribues qui atteste qu'un joueur occupe une fonction nommee.
  DELETE FROM public.titulaires_pnj
   WHERE id = v_pays || '_' || v_poste || '_' || coalesce(v_city, 'national');
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES (v_pays || '_' || v_poste || '_' || coalesce(v_city,'national'),
          v_pays, v_poste, v_city, v_gagnant, 'tirage_au_sort_candidature')
  ON CONFLICT (id) DO UPDATE
     SET titulaire = EXCLUDED.titulaire, source = EXCLUDED.source, updated_at = now();
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', v_poste, 'name', v_lib, 'city', v_city,
                   'nommeLe', (extract(epoch from clock_timestamp())*1000)::bigint)
   WHERE name = v_gagnant;
  PERFORM public.mail_systeme_envoyer('Système', v_gagnant, 'Nomination automatique — ' || v_lib,
    'L''autorité de nomination n''a pas tranché dans le délai de 48h imparti. Vous avez été désigné(e) par tirage au sort parmi les candidats éligibles au poste de ' || v_lib || '.');

  -- 5. LA SANCTION DU NOMINATEUR RESTE PASSIF. resources.pop, JAMAIS une colonne racine `pop` :
  --    ecrire au mauvais endroit ne serait jamais lu par le client.
  IF nullif(btrim(coalesce(p_autorite,'')),'') IS NOT NULL THEN
    SELECT resources INTO v_res FROM public.personnages_donnees
     WHERE name = btrim(p_autorite) FOR UPDATE;
    IF v_res IS NOT NULL THEN
      v_pop_avant := coalesce(CASE WHEN jsonb_typeof(v_res->'pop')='number'
                                   THEN (v_res->>'pop')::numeric END, 0);
      v_pop_apres := greatest(0, floor(v_pop_avant / 2));
      UPDATE public.personnages_donnees
         SET resources = jsonb_set(v_res, '{pop}', to_jsonb(v_pop_apres))
       WHERE name = btrim(p_autorite);
      v_sanction := true;
      PERFORM public.mail_systeme_envoyer('Système', btrim(p_autorite), 'Décision non prise — ' || v_lib,
        'Vous n''avez pas tranché entre les candidats au poste de ' || v_lib
        || ' dans le délai de 48h. ' || v_gagnant || ' a été nommé(e) par tirage au sort. '
        || 'Votre popularité a été divisée par deux (' || round(v_pop_avant)::text
        || ' → ' || v_pop_apres::text || ').');
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'gagnant', v_gagnant, 'sanction', v_sanction,
                            'pop_avant', v_pop_avant, 'pop_apres', v_pop_apres);
END; $fn$;

COMMENT ON FUNCTION public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text) IS
'Nomme par tirage au sort le titulaire d''un poste nomme dont l''autorite n''a pas tranche dans les
48h, et sanctionne cette autorite -- le tout en UNE transaction, revendiquee par
acte_nocturne_revendiquer(''candidature_poste_tirage''). Le TIRAGE est ici, pas chez l''appelant :
un rejeu ne peut donc pas designer un autre gagnant. Verdicts : aucun_candidat,
poste_deja_attribue (la journee reste ouverte), deja_traite_aujourdhui, aucun_candidat_eligible,
puis ok avec gagnant, sanction, pop_avant et pop_apres. Non appelable depuis le reseau.';

DO $$
DECLARE v_def text; v_droits text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='candidature_poste_tirage_appliquer';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la porte n''existe pas'; END IF;

  -- P1 : LE TIRAGE EST DANS LA PORTE, et il est APRES la revendication.
  IF position('ORDER BY random() LIMIT 1' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- aucun tirage dans la porte'; END IF;
  IF position('acte_nocturne_revendiquer' in v_def) >= position('ORDER BY random()' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le tirage precede la revendication'; END IF;

  -- P2 : les six consequences sont dans la meme fonction, donc la meme transaction.
  IF position('DELETE FROM public.titulaires_pnj' in v_def) = 0
     OR position('INSERT INTO public.postes_attribues' in v_def) = 0
     OR position('UPDATE public.personnages_donnees' in v_def) = 0
     OR position('jsonb_set(v_res, ''{pop}''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- une consequence manque'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, 'mail_systeme_envoyer', 'g');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % courrier(s) au lieu de 2', v_n; END IF;
  IF v_def ~ 'INSERT INTO public\.mails' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- un courrier est ecrit en direct, hors de la porte des mails'; END IF;

  -- P3 : le registre est ecrit AVANT la fiche (la fiche n'est pas une preuve).
  IF position('INSERT INTO public.postes_attribues' in v_def)
     >= position('UPDATE public.personnages_donnees' in v_def) THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la fiche est ecrite avant le registre'; END IF;

  -- P4 : le mecanisme est inscrit a la liste blanche, et la cle etrangere le protege.
  SELECT count(*) INTO v_n FROM public.actes_nocturnes_mecanismes
   WHERE mecanisme='candidature_poste_tirage' AND sujet_singleton = false;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- mecanisme absent ou singleton'; END IF;

  -- P5 : les droits. La porte est un acte de minuit : elle n'est pas appelable depuis le reseau.
  IF has_function_privilege('authenticated','public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text)','EXECUTE')
     OR has_function_privilege('anon','public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un navigateur peut nommer par tirage au sort'; END IF;
  IF NOT has_function_privilege('service_role','public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le cron ne peut pas appeler la porte'; END IF;
  SELECT string_agg(coalesce(r.rolname,'PUBLIC'), ',' ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname='acte_nocturne_revendiquer';
  IF v_droits IS DISTINCT FROM 'postgres' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la revendication a cesse d''etre reservee a la transaction : %', v_droits; END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.actes_nocturnes;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % acte(s) nocturne(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.mails;
  IF v_n <> 28 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % courriers au lieu de 28', v_n; END IF;
  IF (SELECT resources->>'pop' FROM public.personnages_donnees WHERE name='Arnie') <> '9' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la POP du personnage du banc a bouge'; END IF;
  IF (SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(poste::text,'~'),'|' ORDER BY name COLLATE "C"))
        FROM public.personnages_donnees) IS DISTINCT FROM '4cc736d7cc7664ba679b8d72fe481aab' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les postes ont bouge';
  END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;