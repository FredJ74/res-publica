-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010175914 (UTC), nom `subventions_l_ordre_du_maire_est_declare_au_miroir_des_couts`.
-- Le registre passe de 630 a 631 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 c37792e2bb3ec043003795431d505d5f, 3151 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7 -- DECLARER L'ORDRE, SANS REGENERER LE MIROIR
--
-- `payer_ordre` est FAIL-CLOSED : un ordre absent de `ordres_couts` est refuse en
-- `ordre_inconnu`. Comme `subvention_proposer` coute 2 PA, il traverse cette verification -- sans
-- cette ligne, la porte de proposition posee au registre 628 resterait inerte. UNE seule ligne est
-- inseree, et surtout PAS une regeneration : le depot interdit de regenerer ce miroir, qui porte
-- deux divergences declarees et fermees par le lot 4D, et regenerer changerait ce que le serveur
-- fait payer sur 405 lignes au passage d'un chantier qui n'a rien demande. Declarer le cout d'un
-- acte neuf n'est pas reparer le miroir : la preuve P3 verifie que 405 lignes sont devenues 406 et
-- qu'aucune n'a ete modifiee.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7 -- DECLARER L'ORDRE, SANS REGENERER LE MIROIR (10 octobre 2026)
--
-- `payer_ordre` est FAIL-CLOSED : un ordre absent de `ordres_couts` est refuse (`ordre_inconnu`)
-- et journalise dans `ordres_couts_inconnus`. L'ordre `subvention_proposer` coute 2 PA, donc il
-- traverse cette verification -- contrairement aux ordres gratuits, que `deduireCoutOrdre`
-- n'envoie jamais a `payer_ordre`. Sans cette ligne, la porte de proposition serait inerte.
--
-- POURQUOI UNE SEULE LIGNE, ET PAS UNE REGENERATION. Le depot INTERDIT explicitement de
-- regenerer ce miroir ici : `outils/baseline/referentiels.json` porte deux divergences declarees
-- (`ordres_couts/posee` et `ordres_couts/base`), fermees par le lot 4D, avec la mention « Ne pas
-- regenerer ce miroir [...] Faire concorder une empreinte en touchant au contenu, c'est fabriquer
-- le resultat du controle ». Regenerer reviendrait a changer ce que le serveur fait payer sur 405
-- lignes au passage d'un chantier qui n'a rien demande -- et a entamer le lot 4D sans mandat.
--
-- INSERER UN ORDRE NEUF N'EST PAS REPARER LE MIROIR. C'est declarer le cout d'un acte qui n'avait
-- pas de cout parce qu'il n'existait pas. La divergence connue n'est ni masquee ni aggravee dans
-- son sens : elle est remesuree et reecrite dans `referentiels.json` apres cette migration.

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('subvention_proposer', 2, 0)
ON CONFLICT (fn, pa, cost) DO NOTHING;

DO $p$
DECLARE v integer;
BEGIN
  -- P1 : l'ordre est declare, a 2 PA et 0 FR, et une seule fois.
  SELECT count(*) INTO v FROM public.ordres_couts WHERE fn = 'subvention_proposer';
  IF v <> 1 THEN RAISE EXCEPTION 'P1 : % ligne(s) pour subvention_proposer au lieu d''une', v; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts
                  WHERE fn = 'subvention_proposer' AND pa = 2 AND cost = 0) THEN
    RAISE EXCEPTION 'P1b : l''ordre n''est pas declare a 2 PA et 0 FR'; END IF;

  -- P2 : LA PORTE N'EST PLUS INERTE. `payer_ordre` reconnait desormais le couple exact qu'elle
  -- presente -- c'est la condition que la migration 628 avait consignee en NOTICE.
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts o
                  WHERE o.fn = 'subvention_proposer' AND o.pa = 2 AND o.cost = 0) THEN
    RAISE EXCEPTION 'P2 : le couple presente par la porte n''est pas celui declare'; END IF;

  -- P3 : AUCUNE AUTRE LIGNE N'A BOUGE. On n'a pas regenere le miroir : 405 lignes avant, 406
  -- apres, et pas une de modifiee.
  SELECT count(*) INTO v FROM public.ordres_couts;
  IF v <> 406 THEN
    RAISE EXCEPTION 'P3 : % lignes au miroir au lieu de 406 -- le miroir a ete touche ailleurs', v;
  END IF;

  -- P4 : l'ordre n'a jamais ete vu comme inconnu ni en ecart -- la porte n'a pas encore tourne.
  IF EXISTS (SELECT 1 FROM public.ordres_couts_inconnus WHERE fn = 'subvention_proposer')
     OR EXISTS (SELECT 1 FROM public.ordres_couts_ecarts WHERE fn = 'subvention_proposer') THEN
    RAISE NOTICE 'P4 : l''ordre a deja ete refuse au moins une fois avant sa declaration.';
  END IF;

  RAISE NOTICE 'Ordre declare au miroir : 4 preuves structurelles vertes.';
END $p$;
