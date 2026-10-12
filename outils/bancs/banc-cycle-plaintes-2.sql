-- BANC DU CYCLE DE VIE D'UNE AFFAIRE -- 2/3 : LA DEFENSE DE L'ACCUSE
-- Chantier 5, les trois `sbSavePlainte` avales (10 octobre 2026).
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION. Voir le fichier 1
-- pour la raison du decoupage en trois (limite de transport du canal SQL).
--
-- RELU DANS LA NUIT DU 12 OCTOBRE 2026 (tranche du parquet). Le statut d'une affaire ouverte
-- n'est plus `deposee` mais `au_parquet` : c'est la seule chose qui change ici, et elle change
-- partout -- le decor comme les trois assertions qui exigent qu'un refus ne fasse rien bouger.
-- La porte `plainte_defendre` a suivi le meme chemin par la migration 20261012102519 : elle
-- gardait sur un statut que plus aucune porte ne produisait, donc se defendre etait devenu
-- impossible sur tout dossier. Ce banc est ce qui l'a fait voir.
--
-- CE QU'IL ETABLIT. `plainte_defendre` remplace l'upsert du blob entier par l'accuse, et c'est
-- ici qu'on trouve LE DEFAUT LE PLUS GRAVE DU CYCLE -- plus grave que ce que l'audit disait.
--
-- LES DEUX CONTRE-EPREUVES, a la fin, sont le coeur de ce banc :
--
--   * L'ANCIEN CHEMIN N'INSCRIVAIT RIEN DU TOUT. `plaintes_en_cours` porte un trigger
--     BEFORE UPDATE, `plaintes_epingler_verdict`, qui restaure sept champs -- dont `status`,
--     `circonstanceAttenuante` et `aggravation` -- des que l'auteur n'est pas l'autorite
--     judiciaire de la ville. L'accuse n'en est jamais une. Sa defense etait donc
--     SYSTEMATIQUEMENT annulee, pour 2 PA et 300 FR, a chaque fois, pour tout le monde. La
--     contre-epreuve refait cet upsert a l'identique et montre le champ disparaitre.
--
--   * ET CE TRIGGER AURAIT AUSSI NEUTRALISE LA PORTE. `est_appel_serveur()` lit le GUC `role`,
--     que `SECURITY DEFINER` ne change pas : la porte annoncait `ok: true` avec un blob complet,
--     et la base ne gardait rien. C'est la mesure qui l'a trouve, pas la relecture. D'ou le
--     laissez-passer `rp.verdict_interne`, et l'epreuve qui verifie qu'une sauvegarde cliente en
--     bloc, juste apres la porte, ne passe pas a son tour.
--
-- CE QUE LES CONTRE-EPREUVES MESURENT DEPUIS LE REGISTRE 634. Ce registre a revoque INSERT et
-- UPDATE a `authenticated` sur `plaintes_en_cours` et supprime ses policies d'ecriture. Les trois
-- ecritures clientes directes de ce banc -- les deux INSERT doublons (epreuve 1), l'upsert de la
-- defense (15) et la sauvegarde en bloc apres la porte (17) -- sont conservees mot pour mot, mais
-- elles LEVENT maintenant `42501 permission denied` au lieu d'aboutir, de renvoyer 0 ligne ou
-- d'etre defaites par le trigger. Chaque contre-epreuve attrape ce refus-la, et lui seul -- jamais
-- `others`, qui la ferait passer sur une faute de frappe ou une table absente -- et c'est l'
-- ABSENCE d'exception qui est desormais l'echec. La garantie est plus forte : le chemin client
-- n'est plus seulement perdant, il est ferme. En echange, l'epreuve 17 ne mesure plus l'etat du
-- laissez-passer lui-meme (le droit arrete l'ecriture avant le trigger) ; c'est le banc du lot
-- precedent, sur `rp.recherche_interne`, qui garde cette mesure-la.
--
-- COMMENT IL A REELLEMENT TOURNE. Tel quel sous psql. Par le canal MCP de ce depot, qui plafonne
-- a ~12 500 caracteres de SQL, il a ete envoye DEBARRASSE DE SES LIGNES DE COMMENTAIRE -- le code
-- execute est donc exactement celui de ce fichier, aux commentaires pres :
--     python3 -c "print('\n'.join(l for l in open('<ce fichier>').read().split('\n') if l.strip() and not l.strip().startswith('--')))"
BEGIN;
DO $banc$
DECLARE
  ko text[] := '{}'; n integer := 0;
  v jsonb; c integer; d jsonb;
  -- Vrai quand l'ecriture cliente directe a bien ete refusee par le PRIVILEGE (registre 634).
  v_refuse boolean;
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  v_poste constant jsonb := '{"id":"commissaire","city":"ville_a"}'::jsonb;
  -- Une affaire dont BEN est l'accuse, et une autre dont il ne l'est pas.
  AFF constant text := 'aff-ben';
  AUTRE constant text := 'aff-may';
BEGIN
  -- ------------------------------------------------- 1. CONTRE-EPREUVE DE LA TRANSMISSION
  -- L'ancien chemin composait `'affaire-' + Date.now()` : la meme conclusion d'enquete rejouee
  -- (double clic, second passage du differe) creait DEUX affaires contre la meme personne. Ce
  -- doublon est maintenant impossible un cran plus tot que la policy : le registre 634 a revoque
  -- INSERT et UPDATE a `authenticated` sur `plaintes_en_cours`, et les deux INSERT -- conserves
  -- mot pour mot ci-dessous -- LEVENT `42501 permission denied` au lieu d'aboutir. On attrape ce
  -- refus-la, et lui seul : jamais `others`, qui ferait passer l'epreuve sur une faute de frappe.
  -- C'est desormais l'ABSENCE d'exception qui est l'echec, et la garantie est plus forte qu'avant.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = v_poste WHERE name = 'Ben';
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v_refuse := false;
  BEGIN
    -- `deposee` EST CONSERVE DANS LES ECRITURES CLIENTES REFAITES A L'IDENTIQUE : c'est le
    -- statut que l'ancien chemin posait, et le refus porte sur le PRIVILEGE, pas sur le
    -- contenu. Les decors, eux, sont passes a `au_parquet` -- la porte garde desormais
    -- dessus.
    INSERT INTO public.plaintes_en_cours (id, country, city, data)
    VALUES ('affaire-' || (extract(epoch from clock_timestamp()) * 1000)::bigint, 'republic', 'ville_a',
            '{"cible":"May","motif":"Vol aggrave","jour":1,"status":"deposee"}');
    PERFORM pg_sleep(0.01);
    INSERT INTO public.plaintes_en_cours (id, country, city, data)
    VALUES ('affaire-' || (extract(epoch from clock_timestamp()) * 1000)::bigint, 'republic', 'ville_a',
            '{"cible":"May","motif":"Vol aggrave","jour":1,"status":"deposee"}');
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF NOT v_refuse OR c <> 0 THEN
    ko := ko || ('1 L INSERTION CLIENTE DIRECTE EST ENCORE POSSIBLE : l ancien chemin a cree '
      || c || ' affaire(s) (refus de privilege ' || v_refuse::text || ')'); END IF;
  DELETE FROM public.plaintes_en_cours;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.affaire_transmettre('May', 'Vol aggrave', 'ville_a', NULL);
  PERFORM public.affaire_transmettre('May', 'Vol aggrave', 'ville_a', NULL);
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF c <> 1 THEN ko := ko || ('2 la porte a cree ' || c || ' affaire(s) au lieu de 1'); END IF;

  -- ------------------------------------------------- 2. DECOR DE LA DEFENSE
  DELETE FROM public.plaintes_en_cours;
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = 'Ben';
  -- L'AFFAIRE DE BEN PORTE DESORMAIS UNE INFRACTION CANONIQUE COURTE (12 octobre 2026, soir).
  -- Sans elle, la porte refuserait `infraction_non_determinee` avant tout le reste : la procedure
  -- simplifiee a un DOMAINE, et c'est `banc-defense-simplifiee.sql` qui l'eprouve en entier.
  -- `aff-ben-2` sert la contre-epreuve finale : un jugement porte l'identifiant de son affaire,
  -- donc une seconde defense reussie ne peut pas se jouer sur le meme dossier.
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (AFF, 'republic', 'ville_a',
     '{"id":"aff-ben","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"au_parquet","infraction_constatee":"vol"}'),
    ('aff-ben-2', 'republic', 'ville_a',
     '{"id":"aff-ben-2","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"au_parquet","infraction_constatee":"vol"}'),
    (AUTRE, 'republic', 'ville_a',
     '{"id":"aff-may","country":"republic","city":"ville_a","cible":"May","motif":"Vol","jour":1,"status":"au_parquet"}');

  -- ------------------------------------------------- 3. LES REFUS NOMMES
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  -- L'ISSUE ANNONCEE N'EXISTE PLUS, ET C'EST L'EPREUVE (12 octobre 2026, soir). Cette ligne
  -- verifiait qu'une issue hors liste close etait refusee -- une bonne garde sur une mauvaise
  -- architecture : c'etait le NAVIGATEUR qui disait laquelle des quatre etait survenue, donc qui
  -- decidait d'une peine. La signature a deux parametres a ete SUPPRIMEE, pas elargie, et il n'en
  -- reste qu'une. Mesure sur le catalogue, pas sur un appel.
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'plainte_defendre';
  n := n + 1; IF c <> 1 THEN ko := ko || ('3 ' || c || ' signature(s) de plainte_defendre'); END IF;
  SELECT count(*) INTO c FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'plainte_defendre' AND p.pronargs = 1;
  n := n + 1; IF c <> 1 THEN ko := ko || '3b la porte accepte encore une issue annoncee'; END IF;
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_defendre('aff-inexistante');
  n := n + 1; IF v ->> 'raison' <> 'affaire_absente' THEN ko := ko || '4 affaire absente acceptee'; END IF;
  -- SE DEFENDRE EST LE FAIT DE L'ACCUSE. L'ancienne policy accordait l'ecriture a la cible ET au
  -- plaignant, sur le blob entier.
  v := public.plainte_defendre(AUTRE);
  n := n + 1; IF v ->> 'raison' <> 'pas_mon_affaire'
    THEN ko := ko || ('5 on se defend sur l affaire d un autre : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AUTRE;
  n := n + 1; IF d ->> 'status' <> 'au_parquet'
    THEN ko := ko || '6 l affaire d un autre a bouge malgre le refus'; END IF;

  -- --------------------------------------- 4. LE VERDICT EST CELUI DU SERVEUR, LU EN BASE
  -- CETTE SECTION MESURAIT LES QUATRE ISSUES. Elles n'existent plus : le serveur tire, decide,
  -- prononce et execute. Ce qu'elle mesure desormais, c'est que l'issue rendue est l'une des
  -- DEUX possibles, qu'elle est accompagnee d'un VRAI jugement -- l'ancienne « reussite
  -- critique » posait `status = 'jugee'` sans aucune ligne au registre -- et que le dossier
  -- porte la marque de la procedure.
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_defendre(AFF);
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF v ->> 'ok' <> 'true'
    THEN ko := ko || ('7 la defense a echoue : ' || v::text); END IF;
  n := n + 1; IF (v ->> 'verdict') NOT IN ('condamnation', 'relaxe')
    OR (d ->> 'status') NOT IN ('jugee', 'relaxe')
    THEN ko := ko || ('8 le verdict n est pas EN BASE : ' || d::text); END IF;
  n := n + 1; IF d ->> 'defendue_par' <> 'Ben' THEN ko := ko || '9 le defenseur n est pas nomme'; END IF;

  -- LE JUGEMENT EXISTE, ET SA PEINE DIT LE VERDICT : NULL pour une relaxe, un libelle sinon.
  SELECT count(*) INTO c FROM public.jugements WHERE id = 'jug-' || AFF;
  n := n + 1; IF c <> 1 THEN ko := ko || ('10 aucune ligne de jugement (' || c || ')'); END IF;
  n := n + 1; IF ((v ->> 'verdict') = 'relaxe')
    <> ((SELECT peine FROM public.jugements WHERE id = 'jug-' || AFF) IS NULL)
    THEN ko := ko || '10b la peine du jugement ne correspond pas au verdict'; END IF;

  -- LE NAVIGATEUR N'A RIEN POSE : aucun des trois drapeaux de l'ancienne mecanique.
  n := n + 1; IF (d ? 'circonstanceAttenuante') OR (d ? 'aggravation') OR (d ? 'resultatDefense')
    THEN ko := ko || ('11 un drapeau de l ancienne mecanique survit : ' || d::text); END IF;
  -- `defendue_le` A DISPARU AU PROFIT DE `defense_le`, ET C'ETAIT UN DOUBLON : les deux portaient
  -- le MEME horodatage, et seul `defense_le` etait lu -- c'est lui que le filtre du navigateur
  -- interroge pour savoir qu'une defense a deja ete plaidee. Garder deux cles pour un fait, c'est
  -- preparer le jour ou elles divergent.
  n := n + 1; IF NOT (d ? 'defense_le') OR NOT (d ? 'defense_avocat') OR NOT (d ? 'defense_taux')
    THEN ko := ko || ('12 la defense n est pas horodatee ni attribuee : ' || d::text); END IF;

  -- ET LA MARQUE DE LA PROCEDURE EST POSEE : c'est elle qui ferme l'appel.
  n := n + 1; IF (d -> 'procedure_simplifiee') <> 'true'::jsonb
    THEN ko := ko || ('13 le dossier ne porte pas la marque de la procedure simplifiee'); END IF;
  PERFORM set_config('role', 'authenticated', true);
  v := public.justice_appel_ouvrir(AFF);
  n := n + 1; IF v ->> 'raison' <> 'appel_exclu_procedure_simplifiee'
    THEN ko := ko || ('13b un appel est possible : ' || v::text); END IF;

  -- ------------------------------------------------- 5. ON NE REPUBLIE PAS UN ETAT ANCIEN
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_defendre(AFF);
  n := n + 1; IF (v ->> 'raison') NOT IN ('affaire_non_defendable', 'defense_deja_plaidee')
    THEN ko := ko || ('14 une affaire jugee se laisse redefendre : ' || v::text); END IF;

  -- LA PEINE EST IMMEDIATEMENT EXECUTOIRE : on rend sa liberte a Ben avant la suite, sinon la
  -- defense de `aff-ben-2` buterait sur une peine en cours -- pour une raison qui n'a rien a voir
  -- avec ce que la contre-epreuve mesure.
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.detentions WHERE nom = 'Ben';
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = 'Ben';

  -- ------------------------------------------------- 6. CONTRE-EPREUVE DE LA DEFENSE
  -- L'ANCIEN CHEMIN, REFAIT A L'IDENTIQUE : `sbSavePlainte` est un upsert du blob ENTIER. Sur une
  -- ligne existante, c'est un UPDATE, donc le trigger du verdict s'applique -- et effacait la
  -- defense. Depuis le registre 634 ce trigger n'est meme plus atteint : UPDATE est revoque a
  -- `authenticated` sur `plaintes_en_cours`, et l'upsert conserve mot pour mot LEVE `42501
  -- permission denied`. On attrape ce refus-la uniquement, et l'absence d'exception serait
  -- l'echec. La defense n'est donc plus seulement annulee apres coup, elle est refusee d'entree.
  PERFORM set_config('role', 'authenticated', true);
  v_refuse := false;
  BEGIN
    UPDATE public.plaintes_en_cours
       SET data = '{"id":"aff-ben-2","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"deposee","circonstanceAttenuante":true}'
     WHERE id = 'aff-ben-2';
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = 'aff-ben-2';
  n := n + 1; IF NOT v_refuse OR (d ? 'circonstanceAttenuante') THEN
    ko := ko || ('15 L ECRITURE CLIENTE DIRECTE EST ENCORE POSSIBLE : l ancien chemin a pu tenter '
      || 'la circonstance attenuante (refus de privilege ' || v_refuse::text || ') : ' || d::text);
  END IF;

  -- ET LA PORTE, SUR LA MEME AFFAIRE, L'INSCRIT.
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.plainte_defendre('aff-ben-2');
  -- PUIS L'ECRITURE CLIENTE EN BLOC, JUSTE APRES LA PORTE, NE DOIT RIEN POUVOIR POSER. Elle etait
  -- jusqu'ici arretee par le trigger du verdict -- le laissez-passer `rp.verdict_interne` etant
  -- bien REFERME par la porte, le defaut que le banc du lot precedent avait trouve sur
  -- `rp.recherche_interne`. Depuis le registre 634 elle est arretee AVANT, par le DROIT : le meme
  -- UPDATE, conserve mot pour mot, leve `42501 permission denied`. L'epreuve 17 mesure donc
  -- maintenant ce refus de privilege (et lui seul), ce qui vaut pour TOUT ce que le client
  -- pourrait poser -- et non plus la seule fermeture du laissez-passer, qui n'est plus atteignable
  -- par ce chemin. L'absence d'exception serait l'echec.
  v_refuse := false;
  BEGIN
    UPDATE public.plaintes_en_cours
       SET data = (data::jsonb || '{"status":"au_parquet","aggravation":true}'::jsonb)::text
     WHERE id = 'aff-ben-2';
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = 'aff-ben-2';
  -- CE QUE LA PORTE INSCRIT N'EST PLUS UN DRAPEAU MAIS UN VERDICT : l'avocat qui a plaide, le
  -- taux calcule au serveur, et le statut du jugement.
  n := n + 1; IF NOT (d ? 'defense_avocat') OR NOT (d ? 'defense_taux')
    THEN ko := ko || ('16 la porte n inscrit pas ce que l ancien chemin perdait : ' || d::text); END IF;
  n := n + 1; IF NOT v_refuse OR (d ->> 'status') NOT IN ('jugee', 'relaxe') OR (d ? 'aggravation') THEN
    ko := ko || ('17 L ECRITURE CLIENTE EN BLOC APRES LA PORTE EST ENCORE POSSIBLE : refus de '
      || 'privilege ' || v_refuse::text || ', dossier ' || d::text);
  END IF;

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DE LA DEFENSE SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %',
      array_length(ko, 1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
