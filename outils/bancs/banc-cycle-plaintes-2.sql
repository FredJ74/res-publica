-- BANC DU CYCLE DE VIE D'UNE AFFAIRE -- 2/3 : LA DEFENSE DE L'ACCUSE
-- Chantier 5, les trois `sbSavePlainte` avales (10 octobre 2026).
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION. Voir le fichier 1
-- pour la raison du decoupage en trois (limite de transport du canal SQL).
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
--     laissez-passer `rp.verdict_interne`, et l'epreuve qui verifie qu'il est bien REFERME --
--     sans quoi une sauvegarde cliente en bloc, juste apres, passerait a son tour.
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
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  v_poste constant jsonb := '{"id":"commissaire","city":"ville_a"}'::jsonb;
  -- Une affaire dont BEN est l'accuse, et une autre dont il ne l'est pas.
  AFF constant text := 'aff-ben';
  AUTRE constant text := 'aff-may';
BEGIN
  -- ------------------------------------------------- 1. CONTRE-EPREUVE DE LA TRANSMISSION
  -- L'ancien chemin composait `'affaire-' + Date.now()` : la meme conclusion d'enquete rejouee
  -- (double clic, second passage du differe) creait DEUX affaires contre la meme personne.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = v_poste WHERE name = 'Ben';
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES ('affaire-' || (extract(epoch from clock_timestamp()) * 1000)::bigint, 'republic', 'ville_a',
          '{"cible":"May","motif":"Vol aggrave","jour":1,"status":"deposee"}');
  PERFORM pg_sleep(0.01);
  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES ('affaire-' || (extract(epoch from clock_timestamp()) * 1000)::bigint, 'republic', 'ville_a',
          '{"cible":"May","motif":"Vol aggrave","jour":1,"status":"deposee"}');
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO c FROM public.plaintes_en_cours;
  n := n + 1; IF c <> 2 THEN ko := ko || ('1 LA CONTRE-EPREUVE NE REPRODUIT PAS LE DEFAUT : '
    || 'l ancien chemin a cree ' || c || ' affaire(s) au lieu de 2 -- le banc ne prouve rien'); END IF;
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
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (AFF, 'republic', 'ville_a',
     '{"id":"aff-ben","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"deposee"}'),
    (AUTRE, 'republic', 'ville_a',
     '{"id":"aff-may","country":"republic","city":"ville_a","cible":"May","motif":"Vol","jour":1,"status":"deposee"}');

  -- ------------------------------------------------- 3. LES REFUS NOMMES
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_defendre(AFF, 'jackpot');
  n := n + 1; IF v ->> 'raison' <> 'issue_inconnue'
    THEN ko := ko || ('3 une issue hors liste close est acceptee : ' || v::text); END IF;
  v := public.plainte_defendre('aff-inexistante', 'attenuante');
  n := n + 1; IF v ->> 'raison' <> 'affaire_absente' THEN ko := ko || '4 affaire absente acceptee'; END IF;
  -- SE DEFENDRE EST LE FAIT DE L'ACCUSE. L'ancienne policy accordait l'ecriture a la cible ET au
  -- plaignant, sur le blob entier.
  v := public.plainte_defendre(AUTRE, 'reussite_critique');
  n := n + 1; IF v ->> 'raison' <> 'pas_mon_affaire'
    THEN ko := ko || ('5 on se defend sur l affaire d un autre : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AUTRE;
  n := n + 1; IF d ->> 'status' <> 'deposee'
    THEN ko := ko || '6 l affaire d un autre a bouge malgre le refus'; END IF;

  -- ------------------------------------------------- 4. LES QUATRE ISSUES, LUES EN BASE
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_defendre(AFF, 'attenuante');
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF NOT (v ->> 'ok' = 'true' AND (d -> 'circonstanceAttenuante') = 'true'::jsonb)
    THEN ko := ko || ('7 la circonstance attenuante n est pas EN BASE : ' || d::text); END IF;
  n := n + 1; IF d ->> 'status' <> 'deposee'
    THEN ko := ko || '8 une reussite simple a clos l affaire'; END IF;
  n := n + 1; IF d ->> 'defendue_par' <> 'Ben' THEN ko := ko || '9 le defenseur n est pas nomme'; END IF;

  -- LE CUMUL RESTE POSSIBLE, et c'est la regle existante : les trois issues qui ne classent pas
  -- laissent l'affaire « deposee », et l'ordre est payant a chaque tentative.
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.plainte_defendre(AFF, 'aggravation');
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF (d -> 'aggravation') <> 'true'::jsonb
    THEN ko := ko || ('10 l aggravation n est pas EN BASE : ' || d::text); END IF;

  -- L'ECHEC SIMPLE N'AJOUTE AUCUN DRAPEAU.
  UPDATE public.plaintes_en_cours SET data =
    '{"id":"aff-ben","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"deposee"}'
   WHERE id = AFF;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.plainte_defendre(AFF, 'infructueuse');
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF (d ? 'circonstanceAttenuante') OR (d ? 'aggravation')
    THEN ko := ko || ('11 un echec simple a pose un drapeau : ' || d::text); END IF;
  n := n + 1; IF NOT (d ? 'defendue_le') THEN ko := ko || '12 la tentative n est pas horodatee'; END IF;

  -- LA REUSSITE ECLATANTE CLASSE L'AFFAIRE -- la seule des trois portes du cycle qui pose
  -- « jugee », parce que c'est la regle de jeu existante.
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.plainte_defendre(AFF, 'reussite_critique');
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF NOT (d ->> 'status' = 'jugee' AND d ->> 'resultatDefense' = 'reussite_critique')
    THEN ko := ko || ('13 la reussite eclatante ne classe pas l affaire EN BASE : ' || d::text); END IF;

  -- ------------------------------------------------- 5. ON NE REPUBLIE PAS UN ETAT ANCIEN
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_defendre(AFF, 'attenuante');
  n := n + 1; IF NOT (v ->> 'raison' = 'affaire_non_defendable' AND v ->> 'statut' = 'jugee')
    THEN ko := ko || ('14 une affaire jugee se laisse redefendre : ' || v::text); END IF;

  -- ------------------------------------------------- 6. CONTRE-EPREUVE DE LA DEFENSE
  -- L'ANCIEN CHEMIN, REFAIT A L'IDENTIQUE : `sbSavePlainte` est un upsert du blob ENTIER. Sur une
  -- ligne existante, c'est un UPDATE, donc le trigger du verdict s'applique.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.plaintes_en_cours SET data =
    '{"id":"aff-ben","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"deposee"}'
   WHERE id = AFF;
  PERFORM set_config('role', 'authenticated', true);
  UPDATE public.plaintes_en_cours
     SET data = '{"id":"aff-ben","country":"republic","city":"ville_a","cible":"Ben","motif":"Vol","jour":1,"status":"deposee","circonstanceAttenuante":true}'
   WHERE id = AFF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF (d ? 'circonstanceAttenuante') THEN
    ko := ko || ('15 LA CONTRE-EPREUVE NE REPRODUIT PAS LE DEFAUT : l ancien chemin a bien '
      || 'inscrit la circonstance attenuante -- le banc ne prouve donc rien : ' || d::text);
  END IF;

  -- ET LA PORTE, SUR LA MEME AFFAIRE, L'INSCRIT.
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.plainte_defendre(AFF, 'attenuante');
  -- PUIS LE LAISSEZ-PASSER EST REFERME : une sauvegarde cliente en bloc, juste apres, ne doit
  -- plus rien pouvoir poser. C'est le defaut que le banc du lot precedent avait trouve sur
  -- `rp.recherche_interne`.
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || '{"status":"jugee","aggravation":true}'::jsonb)::text
   WHERE id = AFF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF (d -> 'circonstanceAttenuante') <> 'true'::jsonb
    THEN ko := ko || ('16 la porte n inscrit pas ce que l ancien chemin perdait : ' || d::text); END IF;
  n := n + 1; IF (d ->> 'status' <> 'deposee') OR (d ? 'aggravation') THEN
    ko := ko || ('17 LE LAISSEZ-PASSER EST RESTE OUVERT : une ecriture cliente en bloc a pose un '
      || 'statut apres la porte : ' || d::text);
  END IF;

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DE LA DEFENSE SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %',
      array_length(ko, 1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
