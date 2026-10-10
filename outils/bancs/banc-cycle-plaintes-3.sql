-- BANC DU CYCLE DE VIE D'UNE AFFAIRE -- 3/3 : LE CLASSEMENT PAR LE MINISTRE DE LA JUSTICE
-- Chantier 5, les trois `sbSavePlainte` avales (10 octobre 2026).
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION. Voir le fichier 1
-- pour la raison du decoupage en trois (limite de transport du canal SQL).
--
-- CE QU'IL ETABLIT. L'ordre `annuler_poursuites` (`requiresPost: 'min_just'`, data.js) deduisait
-- 250 FR de la caisse du gouvernement par `sbCaisseMinistereMouvement` -- atomique et verifie --
-- puis posait `affaire.status = 'annulee'` par un `sbSavePlainte` avale.
--
-- LA CONTRE-EPREUVE, a la fin, montre que cette ecriture etait REFUSEE A TOUS LES COUPS : le
-- Ministre de la Justice n'est ni juge ni commissaire de la ville, et une affaire ne le
-- « concerne » pas au sens de `affaire_me_concerne` -- les deux seules branches de la policy
-- d'UPDATE. Les 250 FR quittaient donc la caisse et la plainte restait ouverte, a chaque fois.
--
-- L'autorite, elle, EXISTAIT DEJA en base a deux endroits : la policy de LECTURE de cette table
-- nomme `min_just`, et la caisse ministerielle refuse le mouvement a qui n'est pas le ministre en
-- exercice. On ne l'invente pas, on l'applique enfin a l'ecriture.
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
  AFF constant text := 'aff-may';
  AILLEURS constant text := 'aff-ailleurs';
BEGIN
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.plaintes_en_cours;
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (AFF, 'republic', 'ville_a',
     '{"id":"aff-may","country":"republic","city":"ville_a","cible":"May","motif":"Vol","jour":1,"status":"deposee"}'),
    (AILLEURS, 'empire_b', 'ville_b',
     '{"id":"aff-ailleurs","country":"empire_b","city":"ville_b","cible":"Zed","motif":"Vol","jour":1,"status":"deposee"}');

  -- ------------------------------------------------- 1. SANS LE PORTEFEUILLE, RIEN
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = 'Ben';
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_classer_ministere(AFF);
  n := n + 1; IF v ->> 'raison' <> 'autorite_refusee'
    THEN ko := ko || ('1 un simple joueur classe une plainte : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF d ->> 'status' <> 'deposee'
    THEN ko := ko || '2 l affaire a bouge malgre le refus d autorite'; END IF;
  -- Un commissaire n'est pas davantage ministre : l'autorite est le PORTEFEUILLE, pas la robe.
  UPDATE public.personnages_donnees SET poste = '{"id":"commissaire","city":"ville_a"}'::jsonb WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_classer_ministere(AFF);
  n := n + 1; IF v ->> 'raison' <> 'autorite_refusee'
    THEN ko := ko || ('3 le commissaire de la ville classe au nom du ministere : ' || v::text); END IF;

  -- ------------------------------------------------- 2. LE MINISTRE EN EXERCICE
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = '{"id":"min_just"}'::jsonb WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_classer_ministere(AFF);
  n := n + 1; IF v ->> 'ok' <> 'true' THEN ko := ko || ('4 le ministre ne peut pas classer : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF d ->> 'status' <> 'annulee'
    THEN ko := ko || ('5 le classement n est pas EN BASE : ' || d::text); END IF;
  n := n + 1; IF d ->> 'classee_par' <> 'Ben'
    THEN ko := ko || '6 le ministre qui classe n est pas nomme par le serveur'; END IF;
  n := n + 1; IF NOT (d ? 'classee_le') THEN ko := ko || '7 le classement n est pas horodate'; END IF;
  -- LE MOTIF ET LA CIBLE SURVIVENT : la porte fusionne, elle ne remplace pas le dossier.
  n := n + 1; IF NOT (d ->> 'cible' = 'May' AND d ->> 'motif' = 'Vol')
    THEN ko := ko || ('8 le classement a efface le dossier : ' || d::text); END IF;

  -- ------------------------------------------------- 3. « EN COURS AVANT JUGEMENT »
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_classer_ministere(AFF);
  n := n + 1; IF NOT (v ->> 'raison' = 'affaire_non_classable' AND v ->> 'statut' = 'annulee')
    THEN ko := ko || ('9 une affaire deja classee se reclasse : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.plaintes_en_cours SET data = (data::jsonb || '{"status":"jugee"}'::jsonb)::text WHERE id = AFF;
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_classer_ministere(AFF);
  n := n + 1; IF NOT (v ->> 'raison' = 'affaire_non_classable' AND v ->> 'statut' = 'jugee')
    THEN ko := ko || ('10 une affaire JUGEE se classe encore : ' || v::text); END IF;

  -- ------------------------------------------------- 4. LA JURIDICTION EST NATIONALE, PAS MONDIALE
  v := public.plainte_classer_ministere(AILLEURS);
  n := n + 1; IF v ->> 'raison' <> 'hors_juridiction'
    THEN ko := ko || ('11 le ministre classe une affaire d un autre empire : ' || v::text); END IF;
  v := public.plainte_classer_ministere('aff-inexistante');
  n := n + 1; IF v ->> 'raison' <> 'affaire_absente' THEN ko := ko || '12 affaire absente acceptee'; END IF;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.plainte_classer_ministere(AFF);
  n := n + 1; IF v ->> 'raison' <> 'acteur_non_authentifie'
    THEN ko := ko || ('13 un appel sans identite classe : ' || v::text); END IF;

  -- ------------------------------------------------- 5. CONTRE-EPREUVE
  -- L'ANCIEN CHEMIN, REFAIT A L'IDENTIQUE : le ministre upsert le blob avec `status: 'annulee'`.
  -- La policy d'UPDATE n'a que deux branches -- autorite judiciaire de la ville, ou affaire qui me
  -- concerne -- et il n'est ni l'une ni l'autre.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.plaintes_en_cours SET data =
    '{"id":"aff-may","country":"republic","city":"ville_a","cible":"May","motif":"Vol","jour":1,"status":"deposee"}'
   WHERE id = AFF;
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || '{"status":"annulee"}'::jsonb)::text
   WHERE id = AFF;
  GET DIAGNOSTICS c = ROW_COUNT;
  n := n + 1; IF c <> 0 THEN
    ko := ko || ('14 LA CONTRE-EPREUVE NE REPRODUIT PAS LE DEFAUT : l ecriture ministerielle a '
      || 'touche ' || c || ' ligne(s) alors qu elle etait censee etre refusee par la RLS');
  END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF d ->> 'status' <> 'deposee' THEN
    ko := ko || ('15 la plainte a change de statut par l ancien chemin : ' || d::text);
  END IF;
  -- ET LA PORTE, SUR LA MEME AFFAIRE, CLASSE REELLEMENT.
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.plainte_classer_ministere(AFF);
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.plaintes_en_cours WHERE id = AFF;
  n := n + 1; IF d ->> 'status' <> 'annulee'
    THEN ko := ko || ('16 la porte ne classe pas ce que l ancien chemin perdait : ' || d::text); END IF;

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DU CLASSEMENT MINISTERIEL SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %',
      array_length(ko, 1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
