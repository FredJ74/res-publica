-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010192001 (UTC), nom `les_deux_tables_neuves_declarent_leurs_droits_au_lieu_de_les_heriter`.
-- Le registre passe de 634 a 635 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 38697656c1f3952ab671d7b6ac4b1397, 5243 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- SEPTIEME OCCURRENCE DU PIEGE DES PRIVILEGES PAR DEFAUT SUPABASE
--
-- Les deux tables nees ce jour-la portaient un `SELECT` nomme a `anon` ET a `authenticated` alors
-- qu'aucune des dix migrations du lot ne contient un seul GRANT : le projet Supabase l'accorde
-- tout seul a toute table neuve, et c'est encore la relecture du diff du baseline -- aucun des dix
-- controles -- qui l'a vu. L'effet etait nul sur `subventions_familles` (RLS active sans policy),
-- mais le commentaire de la table et `classification-donnees.csv` affirmaient qu'aucun navigateur
-- ne la lit : le depot declarait une chose et la base en disait une autre, et cet ecart rend un
-- jour une protection fausse. La migration revoque donc ce SELECT sur `subventions_familles`, et
-- reecrit le commentaire de `subventions_municipales` pour ASSUMER celui qui y reste -- sans lui,
-- la policy qui publie les seules propositions closes serait inerte.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- SEPTIEME OCCURRENCE DU PIEGE DES PRIVILEGES PAR DEFAUT SUPABASE (10 octobre 2026)
--
-- CE QUE LA RELECTURE DU DIFF DU BASELINE A TROUVE, et qu'aucun des dix controles n'a vu : les
-- deux tables nees aujourd'hui portent un `SELECT` nomme a `anon` ET a `authenticated`, alors
-- qu'AUCUNE des dix migrations de ce lot ne contient un seul GRANT. Le projet Supabase accorde ce
-- droit tout seul a toute table neuve. C'est la quatrieme fois que c'est la relecture du diff, et
-- aucun controle, qui l'attrape.
--
-- POURQUOI CELA COMPTAIT MALGRE UN EFFET NUL. Sur `subventions_familles`, la RLS est active sans
-- aucune policy : la lecture etait donc deja neutralisee, et rien n'etait observable. Mais le
-- COMMENTAIRE de la table affirme « un navigateur ne lit pas cette table et ne peut donc pas
-- inventer une eligibilite », et `classification-donnees.csv` repete la meme chose. Le depot
-- declarait une chose et la base en disait une autre -- et c'est precisement ce genre d'ecart qui
-- rend un jour une protection fausse, quand quelqu'un ajoute une policy de lecture en croyant la
-- table fermee par ailleurs. Un droit non voulu doit etre retire, meme inerte.
--
-- CE QUI EST REVOQUE, ET CE QUI EST ASSUME.
--
--   * `subventions_familles` : le SELECT part pour les deux roles clients. Le registre
--     d'eligibilite se lit UNIQUEMENT par `subvention_organisations_locales`, qui filtre deja par
--     commune. Rien ne regresse : aucun ecran ne lit cette table.
--
--   * `subventions_municipales` : le SELECT RESTE, et pour les deux roles -- mais parce qu'on le
--     DECIDE ici, pas parce qu'on l'a herite. La policy `subventions_archives_publiques` ne laisse
--     voir que les propositions CLOSES, et l'arbitrage du 10 octobre 2026 veut ces trois issues
--     publiques. Sans le GRANT, la policy serait inerte et l'archive invisible. Le garder pour
--     `anon` est le meme choix que pour `terrains_etat` : une archive municipale consultable sans
--     etre connecte. Les propositions EN ATTENTE restent invisibles par la policy, pas par le
--     droit -- un visiteur ne voit donc pas les negociations en cours.

REVOKE SELECT ON public.subventions_familles FROM anon, authenticated;

COMMENT ON TABLE public.subventions_municipales IS
  'Les propositions de subvention d''une commune a une organisation eligible de son territoire. '
  'La RESERVE n''est pas une colonne : c''est la somme des lignes encore `proposee`. LE SELECT DE '
  '`anon` ET `authenticated` EST VOULU ET ASSUME (registre 635) : la policy '
  'subventions_archives_publiques ne laisse voir que les propositions CLOSES, et l''arbitrage du '
  '10 octobre 2026 veut les trois issues publiques -- sans ce droit, la policy serait inerte. '
  'Aucune ecriture cliente : les portes font tout.';

DO $p$
DECLARE v integer;
BEGIN
  -- P1 : plus aucun droit client sur le registre d'eligibilite.
  IF has_table_privilege('anon', 'public.subventions_familles', 'SELECT')
     OR has_table_privilege('authenticated', 'public.subventions_familles', 'SELECT') THEN
    RAISE EXCEPTION 'P1 : un client peut encore lire le registre d''eligibilite';
  END IF;

  -- P2 : ET AUCUNE ECRITURE NON PLUS, sur aucune des deux tables neuves. Le defaut Supabase
  -- n'accorde que SELECT, mais le verifier coute une ligne et le supposer coute une faille.
  SELECT count(*) INTO v FROM information_schema.role_table_grants
   WHERE table_schema = 'public'
     AND table_name IN ('subventions_familles', 'subventions_municipales')
     AND grantee IN ('anon', 'authenticated')
     AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE');
  IF v <> 0 THEN RAISE EXCEPTION 'P2 : % droit(s) d''ecriture client sur les tables neuves', v; END IF;

  -- P3 : la lecture des ARCHIVES reste ouverte -- la retirer rendrait la policy inerte et
  -- l'arbitrage de publicite inapplicable.
  IF NOT has_table_privilege('authenticated', 'public.subventions_municipales', 'SELECT')
     OR NOT has_table_privilege('anon', 'public.subventions_municipales', 'SELECT') THEN
    RAISE EXCEPTION 'P3 : les archives publiques ne sont plus lisibles';
  END IF;

  -- P4 : et c'est bien la POLICY qui borne ce qu'on y voit, pas le droit.
  SELECT count(*) INTO v FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'subventions_municipales'
     AND cmd = 'SELECT' AND qual LIKE '%proposee%';
  IF v <> 1 THEN
    RAISE EXCEPTION 'P4 : la policy qui cache les propositions en attente est absente (%)', v; END IF;

  -- P5 : la RLS est active sur les deux tables.
  SELECT count(*) INTO v FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relrowsecurity
     AND c.relname IN ('subventions_familles', 'subventions_municipales');
  IF v <> 2 THEN RAISE EXCEPTION 'P5 : la RLS manque sur une table neuve (%)', v; END IF;

  -- P6 : le service_role garde tout -- la cascade et l'expiration en ont besoin.
  IF NOT has_table_privilege('service_role', 'public.subventions_municipales', 'UPDATE')
     OR NOT has_table_privilege('service_role', 'public.subventions_familles', 'SELECT') THEN
    RAISE EXCEPTION 'P6 : le serveur a perdu des droits';
  END IF;

  RAISE NOTICE 'Droits des tables neuves : 6 preuves vertes.';
END $p$;
