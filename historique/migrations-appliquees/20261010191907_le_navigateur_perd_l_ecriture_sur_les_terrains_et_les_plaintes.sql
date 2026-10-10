-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010191907 (UTC), nom `le_navigateur_perd_l_ecriture_sur_les_terrains_et_les_plaintes`.
-- Le registre passe de 633 a 634 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 8280c5323821cfc8f2dafabb692cb0ef, 5894 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- RELIQUAT TECHNIQUE -- LE NAVIGATEUR PERD L'ECRITURE SUR LES TERRAINS ET LES PLAINTES
--
-- Les portes des 9 et 10 octobre ont retire du navigateur toute ecriture sur `terrains_etat` et
-- `plaintes_en_cours`, mais les droits restaient ouverts VOLONTAIREMENT : le precedent du
-- registre 584 exige de prouver d'abord, sur le code DEPLOYE et octet par octet, qu'aucun joueur
-- n'en a plus besoin. Cette preuve a ete faite le 10 octobre -- les 47 scripts de production relus,
-- chaque mention des deux tables classee, aucune ecriture ni contournement -- et la migration
-- revoque donc INSERT/UPDATE a `authenticated` puis supprime les 4 policies d'ecriture devenues
-- inertes mais trompeuses. Les lectures, les droits de `service_role` et les 15 portes restent :
-- six preuves le verifient avant de laisser la revocation tenir.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- RELIQUAT TECHNIQUE -- REVOCATION DES DROITS CLIENTS (10 octobre 2026)
--
-- Les portes des 9 et 10 octobre ont retire du navigateur toute ecriture sur `terrains_etat` et
-- `plaintes_en_cours`. Les droits etaient restes ouverts VOLONTAIREMENT : le precedent du depot
-- (registre 584) exige de prouver d'abord, sur le code DEPLOYE et octet par octet, qu'aucun
-- joueur n'en a plus besoin. Fermer avant la preuve, c'est casser le jeu en croyant le proteger.
--
-- LA PREUVE, FAITE LE 10 OCTOBRE 2026 ET DETAILLEE DANS
-- baseline/arbitrages/CHAINE-7-SUBVENTIONS-MUNICIPALES.md, tient en quatre points :
--   1. LE DEPLOYE EST LE DEPOT. Les 47 scripts de `plateau.html` en production ont ete
--      telecharges (6 533 336 octets) et les six fichiers qui portaient les ecritures sont
--      IDENTIQUES PAR EMPREINTE a leur version poussee -- supabase.js vaut
--      730c83728bcf51896a3f87ce031574e5, plateau-justice-economie.js cf8e75f227a92f342f5a36a518398779.
--   2. CHAQUE MENTION CLASSEE : 24 occurrences de `terrains_etat` et 4 de `plaintes_en_cours`
--      dans le deploye, toutes des COMMENTAIRES sauf six `sbGet` -- des lectures.
--   3. AUCUNE ECRITURE GENERIQUE : les cinq occurrences de `sb*(table` sont les DEFINITIONS des
--      helpers, pas des appels, et aucun litteral de table d'un appel d'ecriture ne vaut ces deux.
--   4. AUCUN CONTOURNEMENT : les fetch directs visent des RPC ou `/api/*`, jamais ces tables.
--
-- CONSERVE : le SELECT d'`authenticated` sur les deux tables et celui d'`anon` sur
-- `terrains_etat` -- six lectures en dependent ; et tous les droits de `service_role`, dont la
-- passe de minuit a besoin.
--
-- LES POLICIES D'ECRITURE PARTENT AUSSI. Sans droit, une policy d'ecriture est inerte mais
-- TROMPEUSE : elle decrit une surface qui n'existe plus, et un GRANT reaccorde par erreur la
-- rouvrirait en silence -- le piege des policies dormantes. Les deux policies de LECTURE restent.
--
-- LES PORTES NE SONT PAS CONCERNEES : SECURITY DEFINER, elles appartiennent au proprietaire des
-- tables. Un banc le verifie apres coup, parce qu'une preuve structurelle ne saurait pas le dire.

REVOKE INSERT, UPDATE ON public.terrains_etat FROM authenticated;
REVOKE INSERT, UPDATE ON public.plaintes_en_cours FROM authenticated;

DROP POLICY IF EXISTS terrains_etat_ecriture_acteur ON public.terrains_etat;
DROP POLICY IF EXISTS terrains_etat_maj_acteur ON public.terrains_etat;
DROP POLICY IF EXISTS plaintes_insertion_affaires ON public.plaintes_en_cours;
DROP POLICY IF EXISTS plaintes_maj_affaires ON public.plaintes_en_cours;

DO $p$
DECLARE v integer;
BEGIN
  -- P1 : le navigateur n'ecrit plus, sur aucune des deux tables.
  IF has_table_privilege('authenticated', 'public.terrains_etat', 'INSERT')
     OR has_table_privilege('authenticated', 'public.terrains_etat', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.plaintes_en_cours', 'INSERT')
     OR has_table_privilege('authenticated', 'public.plaintes_en_cours', 'UPDATE')
     OR has_table_privilege('anon', 'public.terrains_etat', 'INSERT')
     OR has_table_privilege('anon', 'public.plaintes_en_cours', 'INSERT') THEN
    RAISE EXCEPTION 'P1 : un droit d''ecriture client subsiste';
  END IF;

  -- P2 : MAIS IL LIT TOUJOURS. Fermer ces lectures serait une regression, pas un durcissement.
  IF NOT has_table_privilege('authenticated', 'public.terrains_etat', 'SELECT')
     OR NOT has_table_privilege('authenticated', 'public.plaintes_en_cours', 'SELECT')
     OR NOT has_table_privilege('anon', 'public.terrains_etat', 'SELECT') THEN
    RAISE EXCEPTION 'P2 : une lecture legitime a ete fermee au passage';
  END IF;

  -- P3 : la passe de minuit garde ses droits.
  IF NOT has_table_privilege('service_role', 'public.terrains_etat', 'UPDATE')
     OR NOT has_table_privilege('service_role', 'public.plaintes_en_cours', 'UPDATE')
     OR NOT has_table_privilege('service_role', 'public.terrains_etat', 'DELETE') THEN
    RAISE EXCEPTION 'P3 : le cron a perdu des droits';
  END IF;

  -- P4 : plus aucune policy d'ecriture, et les deux lectures sont toujours la.
  SELECT count(*) INTO v FROM pg_policies
   WHERE schemaname = 'public' AND tablename IN ('terrains_etat', 'plaintes_en_cours')
     AND cmd <> 'SELECT';
  IF v <> 0 THEN RAISE EXCEPTION 'P4 : % policy d''ecriture subsiste(nt)', v; END IF;
  SELECT count(*) INTO v FROM pg_policies
   WHERE schemaname = 'public' AND tablename IN ('terrains_etat', 'plaintes_en_cours')
     AND cmd = 'SELECT';
  IF v <> 2 THEN RAISE EXCEPTION 'P4b : % policy de lecture au lieu de 2', v; END IF;

  -- P5 : la RLS reste active -- sans elle, la policy de lecture des affaires ne filtrerait plus.
  SELECT count(*) INTO v FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname IN ('terrains_etat', 'plaintes_en_cours')
     AND c.relrowsecurity;
  IF v <> 2 THEN RAISE EXCEPTION 'P5 : la RLS n''est plus active sur les deux tables (%)', v; END IF;

  -- P6 : LES QUINZE PORTES SONT TOUJOURS LA. C'est par elles que les ecritures passent : si
  -- l'une manquait, cette revocation aurait casse le jeu.
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosecdef AND p.proname IN
     ('terrain_etat_verrouiller_interne', 'terrain_etat_fusionner_interne',
      'terrain_compromis_acte', 'terrain_permis_acte', 'terrain_chantier_acte',
      'terrain_lots_acte', 'terrain_reamenagement_poser', 'terrain_succession_geler',
      'terrain_succession_annuler_compromis', 'terrain_proprietaire_muter',
      'plainte_deposer', 'plainte_traiter', 'plainte_defendre',
      'plainte_classer_ministere', 'affaire_transmettre');
  IF v < 15 THEN RAISE EXCEPTION 'P6 : % porte(s) sur 15 -- ne pas fermer sans elles', v; END IF;

  RAISE NOTICE 'Revocation des ecritures clientes : 6 preuves vertes.';
END $p$;
