-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009143302 (UTC ; 16h33 a Paris), nom
-- `justice_rendre_sentence_porte_atomique`. Le registre passe de 572 a 573 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 c643e5dbc36987de2311ac245ae2db7e, 8 190 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle ferme la chaine de la sentence : `appliquerSentence` terminait sur deux ecritures avalees puis
-- annoncait sans condition le toast, l'evenement public et le courrier au condamne -- le tribunal
-- pouvait donc proclamer une condamnation dont il ne restait aucune trace, l'affaire retombant en
-- « deposee ». Le juge cesse par la meme occasion d'etre un parametre : le client envoyait
-- `juge: state.char?.name || 'PNJ'`, une chaine librement composee et inscrite telle quelle au
-- registre. L'autorite passe par `affaire_autorite_de`, la regle qui existait deja.
--
-- ELLE VA PAR PAIRE AVEC LE DEPOT : `plateau-justice-economie.js` (`appliquerSentence`).
-- =============================================================================

-- Chantier 5 -- UNE SENTENCE RENDUE EST UNE ECRITURE, PAS UNE ANNONCE.
--
-- appliquerSentence (plateau-justice-economie.js:2353) terminait sur deux ecritures avalees :
-- `sbCreerJugement(...).catch(() => {})` puis `sbSavePlainte(affaire).catch(() => {})` -- et
-- enchainait sans condition le toast « Sentence rendue », l'evenement public « JUGEMENT : … » et
-- le courrier au condamne. Le tribunal pouvait donc annoncer une condamnation dont il ne restait
-- aucune trace : ni au registre des jugements, ni sur l'affaire, qui retombait en « deposee ».
--
-- Et l'affaire etait ecrite DEUX fois : une premiere en tete de fonction (status = 'jugee', pour
-- empecher un second jugement), une seconde a la fin. La premiere etait elle aussi avalee, et
-- rien ne garantissait qu'elle aboutisse : une affaire pouvait etre jugee deux fois.
--
-- LE JUGE N'EST PLUS UN PARAMETRE. Le client envoyait `juge: state.char?.name || 'PNJ'` --
-- une chaine librement composee par le navigateur, inscrite telle quelle au registre. Le
-- magistrat est desormais lu par le serveur, et une tentative d'usurpation est ignoree ; le banc
-- l'eprouve avec un `juge: 'Napoleon'` qui ne franchit pas la porte.
--
-- L'AUTORITE PASSE PAR affaire_autorite_de, LA REGLE QUI EXISTAIT DEJA : juge ou commissaire, et
-- la ville du POSTE doit etre celle de l'affaire. C'est une garde FERMEE, contrairement a
-- exiger_poste() : elle s'appuie sur auth.uid(), donc un appel serveur ne la traverse pas.
-- Aucune regle de competence n'est inventee ici -- la fonction est reprise telle quelle.
--
-- Banc en transaction annulee : 7 epreuves vertes, dont le refus sans poste, le refus du juge
-- d'une autre ville, l'usurpation ignoree et le rejeu (« affaire_deja_jugee », un seul jugement,
-- peine non reecrite).
CREATE OR REPLACE FUNCTION public.justice_rendre_sentence(p_affaire jsonb, p_peine text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_juge text; v_aff text; v_ville text; v_pays text; v_jour integer;
  v_existante jsonb; v_jug text; v_n integer;
BEGIN
  v_juge := public.mon_personnage();
  IF v_juge IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_affaire IS NULL OR jsonb_typeof(p_affaire) <> 'object'
     OR coalesce(btrim(p_affaire->>'id'),'') = '' THEN
    RETURN jsonb_build_object('ok',false,'raison','affaire_invalide'); END IF;
  v_aff   := btrim(p_affaire->>'id');
  v_ville := nullif(btrim(coalesce(p_affaire->>'city','')),'');
  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok',false,'raison','autorite_refusee','ville',v_ville); END IF;
  SELECT country, coalesce(day,1) INTO v_pays, v_jour
    FROM public.personnages_donnees WHERE name = v_juge;
  v_pays := coalesce(nullif(btrim(coalesce(p_affaire->>'country','')),''), v_pays, 'republic');

  -- LE VERROU SUR L'AFFAIRE EST LA REVENDICATION : deux juges simultanes se serialisent ici, et
  -- le second lit « jugee ».
  SELECT CASE WHEN data IS NULL THEN NULL ELSE data::jsonb END INTO v_existante
    FROM public.plaintes_en_cours WHERE id = v_aff FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'raison','affaire_absente'); END IF;
  IF coalesce(v_existante->>'status','') = 'jugee' THEN
    RETURN jsonb_build_object('ok',false,'raison','affaire_deja_jugee'); END IF;

  -- L'IDENTIFIANT DU JUGEMENT EST DERIVE DE L'AFFAIRE, pas d'une horloge : un rejeu ne peut pas
  -- produire une seconde ligne, meme si la garde de statut etait un jour contournee.
  v_jug := 'jug-' || v_aff;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee)
  VALUES (v_jug, v_pays, coalesce(v_ville,'capitale'), p_affaire->>'cible',
          p_affaire->>'motif', p_peine, v_juge, v_jour, false)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- L'affaire conserve ses champs connus du serveur et recoit ceux que le client a modifies ;
  -- `status` est impose, jamais lu de l'appelant.
  UPDATE public.plaintes_en_cours
     SET data = (coalesce(v_existante,'{}'::jsonb) || p_affaire
                 || jsonb_build_object('status','jugee'))::text,
         country = v_pays, city = v_ville
   WHERE id = v_aff;

  RETURN jsonb_build_object('ok',true,'jugement_id',v_jug,'affaire',v_aff,
                            'juge',v_juge,'jour',v_jour,'jugement_cree',v_n = 1);
END; $fn$;

GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(jsonb,text) TO authenticated;

COMMENT ON FUNCTION public.justice_rendre_sentence(jsonb,text) IS
'Archive un jugement et clot son affaire en une transaction, sous affaire_autorite_de(ville) :
juge ou commissaire de la ville de l''affaire. Le magistrat et le jour viennent du serveur, jamais
de l''appelant. Une affaire ne se juge qu''une fois (verdict affaire_deja_jugee), et l''identifiant
du jugement est derive de celui de l''affaire. Verdicts : acteur_non_authentifie, affaire_invalide,
autorite_refusee, affaire_absente, affaire_deja_jugee, puis ok avec jugement_id.';

DO $$
DECLARE v_def text; v_droits text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='justice_rendre_sentence';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la porte n''existe pas'; END IF;

  -- P1 : l'autorite est verifiee par la regle existante, et le magistrat est lu, pas recu.
  IF position('public.affaire_autorite_de(v_ville)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''autorite n''est pas verifiee'; END IF;
  IF position('v_juge := public.mon_personnage()' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le magistrat n''est pas lu'; END IF;
  IF v_def ~ 'p_affaire\s*->>\s*''juge''' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le juge est dicte par l''appelant'; END IF;

  -- P2 : les deux ecritures sont dans la meme fonction, donc la meme transaction.
  IF position('INSERT INTO public.jugements' in v_def) = 0
     OR position('UPDATE public.plaintes_en_cours' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- les deux tables ne sont pas ecrites ensemble'; END IF;
  IF position('FOR UPDATE' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''affaire n''est pas verrouillee'; END IF;
  IF position('ON CONFLICT (id) DO NOTHING' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- un rejeu pourrait creer un second jugement'; END IF;
  IF position('''jug-'' || v_aff' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''identifiant du jugement n''est pas derive de l''affaire'; END IF;
  IF position('''status'',''jugee''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le statut n''est pas impose'; END IF;

  -- P3 : les droits.
  SELECT string_agg(coalesce(r.rolname,'PUBLIC'), ',' ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname='justice_rendre_sentence';
  IF v_droits IS DISTINCT FROM 'authenticated,postgres,service_role' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- droits : %', v_droits; END IF;

  -- P4 : AUCUNE DONNEE TOUCHEE, et aucun residu du banc.
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours WHERE id LIKE '%banc%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % affaire(s) de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.jugements WHERE id LIKE '%banc%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % jugement(s) de banc', v_n; END IF;
  IF (SELECT poste FROM public.personnages_donnees WHERE name='Ben') IS NOT NULL THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le poste pose par le banc subsiste'; END IF;
  IF (SELECT md5(string_agg(name||':'||coalesce(arg::text,'~')||':'||coalesce(liquide::text,'~'),'|' ORDER BY name COLLATE "C"))
        FROM public.personnages_donnees) IS DISTINCT FROM 'db4a44dee1b87f6ccd06610120f305ed' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- les personnages ont bouge';
  END IF;

  RAISE NOTICE 'QUATRE PREUVES STRUCTURELLES VERTES.';
END $$;