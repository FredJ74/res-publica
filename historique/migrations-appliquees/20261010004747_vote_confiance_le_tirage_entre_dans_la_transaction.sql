-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010004747 (UTC), nom `vote_confiance_le_tirage_entre_dans_la_transaction`.
-- Le registre passe de 587 a 588 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6d1af90a998c1e58690b9a9bd2ec1ca2, 10 499 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- VOTE DE CONFIANCE : LE TIRAGE ENTRE DANS LA TRANSACTION
--
-- `vote_confiance_resoudre(vote)` verrouille le vote, refuse ce qui n'est pas echu ou deja resolu,
compte les bulletins des deputes PJ, lit l'ISN, et tire les abstentions des deputes absents DANS
LA TRANSACTION qui en porte les consequences -- resultat, delai de demission de 48 h, evenement,
courrier de censure. Le tirage se faisait avant, dans le navigateur du cron. Pas d'acte
nocturne : la transition 'en_cours' -> 'termine' est deja le verrou juste.
--
-- ELLE VA PAR PAIRE AVEC : `api/cron-minuit.js` (`resoudreVotesConfianceEchusServeur`, 4148 -> 2278 caracteres).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Chantier 6, famille B -- UN VOTE DE CONFIANCE NE DOIT PAS POUVOIR ETRE DEPOUILLE DEUX FOIS.
--
-- CE QUI SE PASSAIT. `resoudreVotesConfianceEchusServeur` (api/cron-minuit.js) tirait les sieges
-- PNJ restants avec `Math.random()` EN JAVASCRIPT, puis ecrivait la cloture
-- (`statut = 'termine'`, `resultat`) dans un `.catch(() => {})`, puis posait l'evenement public et
-- le courrier de censure -- avales aussi.
--
-- Si la cloture mordait APRES que l'evenement public et le courrier au Premier Ministre aient
-- annonce le verdict, le rejeu REDEPOUILLAIT : le meme vote pouvait passer de confiance a
-- censure, PUBLIQUEMENT, deux fois, avec deux evenements contradictoires dans la chronique
-- nationale.
--
-- LA BRIQUE actes_nocturnes N'EST PAS UTILISEE ICI, ET C'EST LE BON CHOIX. La transition d'etat
-- EST le verrou : `statut` passe de 'en_cours' a 'termine' dans la MEME transaction que le
-- tirage, sous `SELECT ... FOR UPDATE`. Un rejeu lit 'termine' et rend « deja_resolu » sans
-- jamais atteindre le `random()`. Ajouter une revendication par jour serait non seulement inutile
-- mais FAUX : un vote de confiance se depouille une fois dans sa vie, pas une fois par jour.
--
-- AUCUNE REGLE POLITIQUE NE CHANGE : 9 sieges (3 reels par ville), meme formule de chance
-- `min(85, 30 + ISN/2)` avec l'ISN de la capitale comme proxy et 30 en repli, meme regle de
-- majorite (`pour > contre`), meme delai politique de 48 heures reelles, memes libelles
-- d'evenement et de courrier -- et la meme convention de depouillement, y compris sa subtilite :
-- tout bulletin PRESENT qui n'est pas exactement « pour » compte CONTRE.
--
-- Le courrier passe par mail_systeme_poser_interne, l'unique ecrivain des courriers : son echec
-- est consigne et n'annule pas la censure.
--
-- Banc en transaction annulee : 5 epreuves vertes, dont le rejeu qui ne change plus le resultat
-- et ne pose pas un second evenement public.
CREATE OR REPLACE FUNCTION public.vote_confiance_resoudre(p_vote_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_vote record; v_bulletins jsonb; v_pour int := 0; v_contre int := 0;
  v_votants int := 0; v_isn numeric := 30; v_chance numeric; v_sieges int;
  v_confiance boolean; v_resultat text; v_i int;
BEGIN
  -- LE VERROU SUR LE VOTE EST LA REVENDICATION : deux passes simultanees se serialisent ici, et
  -- la seconde lit 'termine'.
  SELECT * INTO v_vote FROM public.votes_confiance WHERE id = p_vote_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','vote_introuvable'); END IF;
  IF coalesce(v_vote.statut,'') <> 'en_cours' THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_resolu','statut',v_vote.statut); END IF;
  IF v_vote.cloture_ts IS NULL OR now() < v_vote.cloture_ts THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_echu'); END IF;

  v_bulletins := coalesce(v_vote.bulletins, '{}'::jsonb);
  -- LES DEPUTES PJ REELLEMENT EN POSTE, et seuls ceux qui ont vote. Meme regle qu'avant :
  -- poste_depute.id = 'depute' sur une fiche du pays du vote. Et meme convention de
  -- depouillement : un bulletin present qui n'est pas « pour » compte CONTRE.
  SELECT count(*) FILTER (WHERE v_bulletins ->> d.name = 'pour'),
         count(*) FILTER (WHERE (v_bulletins ? d.name) AND v_bulletins ->> d.name <> 'pour'),
         count(*) FILTER (WHERE v_bulletins ? d.name)
    INTO v_pour, v_contre, v_votants
    FROM public.personnages_donnees d
   WHERE d.country = v_vote.country
     AND (d.poste_depute ->> 'id') = 'depute';

  -- Pas d'ISN national persiste cote serveur : l'ISN de la capitale est le meilleur proxy
  -- disponible, avec 30 en repli -- meme ecart d'architecture qu'avant, sciemment non traite.
  IF v_vote.country = 'republic' THEN
    SELECT coalesce(nullif(i.data ->> 'isn','')::numeric, 30) INTO v_isn
      FROM public.indices_villes i WHERE i.id = v_vote.country || '_capitale';
    v_isn := coalesce(v_isn, 30);
  END IF;
  v_chance := least(85, 30 + v_isn / 2);
  -- 9 sieges : 3 reels par ville. LE TIRAGE DES SIEGES RESTANTS EST ICI, dans la transaction qui
  -- ecrit le resultat : un rejeu ne peut plus le refaire.
  v_sieges := greatest(0, 9 - v_votants);
  FOR v_i IN 1 .. v_sieges LOOP
    IF random() * 100 < v_chance THEN v_contre := v_contre + 1; ELSE v_pour := v_pour + 1; END IF;
  END LOOP;

  v_confiance := v_pour > v_contre;
  v_resultat  := CASE WHEN v_confiance THEN 'confiance' ELSE 'censure' END;

  -- Le Premier Ministre n'est PLUS destitue automatiquement (arbitrage du 4 septembre 2026) :
  -- seule une consequence differee s'applique s'il n'a pas demissionne a l'echeance.
  UPDATE public.votes_confiance
     SET statut = 'termine', resultat = v_resultat,
         demission_limite_ts = CASE WHEN v_confiance THEN NULL
                                    ELSE now() + interval '48 hours' END
   WHERE id = p_vote_id;

  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (v_vote.country, NULL,
    '🏛 Vote de confiance : ' || v_pour::text || ' POUR / ' || v_contre::text || ' CONTRE. ' ||
    CASE WHEN v_confiance
      THEN 'Le gouvernement de ' || v_vote.pm_nom || ' obtient la confiance.'
      ELSE 'Le gouvernement de ' || v_vote.pm_nom || ' est CENSURÉ. Le Premier Ministre est politiquement appelé à démissionner sous 48h.'
    END, NULL);

  IF NOT v_confiance THEN
    PERFORM public.mail_systeme_poser_interne('Assemblée Nationale', v_vote.pm_nom,
      'Motion de censure adoptée',
      'L''Assemblée Nationale a retiré sa confiance à votre gouvernement (' || v_pour::text ||
      ' pour / ' || v_contre::text || ' contre). Vous êtes politiquement appelé(e) à démissionner sous 48h réelles. Passé ce délai sans démission, votre popularité et celle de tout le gouvernement tomberont à zéro -- vos postes ne seront cependant jamais retirés automatiquement.',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'));
  END IF;

  RETURN jsonb_build_object('ok',true,'vote_id',p_vote_id,'country',v_vote.country,
                            'resultat',v_resultat,'pour',v_pour,'contre',v_contre,
                            'sieges_tires',v_sieges);
END; $fn$;

COMMENT ON FUNCTION public.vote_confiance_resoudre(text) IS
'Depouille UN vote de confiance echu, en une transaction : le tirage des sieges PNJ restants, la
cloture (statut = termine), l''evenement public et le courrier de censure. La transition d''etat
EST le verrou -- un rejeu lit « termine » et rend deja_resolu sans atteindre le tirage. Verdicts :
vote_introuvable, deja_resolu, pas_echu, puis ok avec resultat, pour, contre et sieges_tires.
Non appelable depuis le reseau.';

DO $$
DECLARE v_def text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='vote_confiance_resoudre';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la porte n''existe pas'; END IF;

  -- P1 : LE TIRAGE EST DANS LA PORTE, APRES le verrou et AVANT la cloture.
  IF position('random() * 100 < v_chance' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- aucun tirage dans la porte'; END IF;
  IF position('FOR UPDATE' in v_def) >= position('random() * 100' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le tirage precede le verrou'; END IF;
  IF position('random() * 100' in v_def) >= position('SET statut = ''termine''' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la cloture precede le tirage'; END IF;

  -- P2 : LA TRANSITION D'ETAT EST LE VERROU, et la brique nocturne n'est PAS forcee.
  IF position('<> ''en_cours''' in v_def) = 0 OR position('deja_resolu' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- rien n''empeche un second depouillement'; END IF;
  IF position('acte_nocturne_revendiquer' in v_def) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- une revendication par jour empecherait... rien, et serait fausse';
  END IF;

  -- P3 : LES REGLES POLITIQUES SONT CELLES DU JEU, AU CHIFFRE PRES.
  IF position('greatest(0, 9 - v_votants)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le nombre de sieges a change'; END IF;
  IF position('least(85, 30 + v_isn / 2)' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la formule de chance a change'; END IF;
  IF position('v_pour > v_contre' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la regle de majorite a change'; END IF;
  IF position('interval ''48 hours''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le delai politique a change'; END IF;
  IF position('<> ''pour''' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la convention « tout bulletin non-pour compte contre » a disparu';
  END IF;
  IF position('est CENSURÉ' in v_def) = 0 OR position('obtient la confiance' in v_def) = 0
     OR position('Motion de censure adoptée' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un libelle a change'; END IF;

  -- P4 : le courrier passe par l'unique ecrivain, jamais par un INSERT direct.
  IF position('public.mail_systeme_poser_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le courrier ne passe pas par la porte des courriers'; END IF;
  IF v_def ~* 'insert into\s+(public\.)?mails\s*\(' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un courrier est ecrit en direct'; END IF;

  -- P5 : droits. Acte de minuit : injoignable depuis le reseau.
  IF has_function_privilege('authenticated','public.vote_confiance_resoudre(text)','EXECUTE')
     OR has_function_privilege('anon','public.vote_confiance_resoudre(text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un navigateur peut depouiller un vote de confiance'; END IF;
  IF NOT has_function_privilege('service_role','public.vote_confiance_resoudre(text)','EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le cron ne peut pas appeler la porte'; END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE, aucun residu de banc.
  SELECT count(*) INTO v_n FROM public.votes_confiance;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % vote(s) de confiance', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.evenements_globaux WHERE texte LIKE '%Vote de confiance%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % evenement(s) de vote', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees WHERE poste_depute IS NOT NULL;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % depute(s) pose(s) par le banc', v_n; END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;