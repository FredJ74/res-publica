-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010000644 (UTC), nom `droits_clients_retires_apres_deploiement`.
-- Le registre passe de 583 a 584 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 21bcffda1ab6b7043377b29952531841, 7423 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- DROITS CLIENTS RETIRES APRES DEPLOIEMENT
--
-- Le code du lot precedent etant verifie octet par octet comme etant celui deploye, les droits
d'ecriture clients devenus inutiles sont revoques : INSERT et UPDATE sur `detentions` et
`prisonniers_qhs`, INSERT sur `votes_electoraux` et `jugements`. L'ACL cliente finale est prouvee
exactement -- 6 entrees, dont le seul DELETE conserve (un electeur retire son bulletin). Les 20
SELECT colonne par colonne sur `detentions` sont conserves, `qhs` toujours exclu ; 11 policies,
la RLS des quatre tables et les 13 portes appelables par `authenticated` sont intactes.
--
-- ELLE VA PAR PAIRE AVEC : `supabase.js` (suppression de `sbMajPrisonnierQHS`, sans appelant) et
-- `outils/baseline/autorite.json` (surface cliente declaree reduite d'autant).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Chantier 5 -- LA LISTE DES ECRITURES CLIENTES RETRECIT, ET C'EST MESURE AVANT D'ETRE FAIT.
--
-- Le lot du 9 octobre a descendu sept chaines judiciaires et le bulletin electoral derriere des
-- portes serveur, en laissant volontairement les GRANT clients en place : la base ne doit pas
-- passer devant le code deploye. Ce lot les retire, et seulement apres avoir PROUVE que le code
-- de ce lot EST celui qui tourne.
--
-- LA PREUVE DU DEPLOIEMENT, et ce n'est pas une inspection de date. Les sept fichiers
-- JavaScript touches ont ete telecharges depuis res-publica.vercel.app et compares OCTET A OCTET
-- a leur version du depot : supabase.js, plateau-politique.js, plateau-justice-economie.js,
-- plateau-core.js, plateau-personnage.js, plateau-communication.js, plateau-navigation.js --
-- sept empreintes md5 identiques. Dans le code SERVI, les trois helpers supprimes
-- (sbVoterPour, sbCreerDetention, sbCreerJugement, sbCreerPrisonnierQHS) sont absents, et les
-- neuf appels aux portes neuves sont presents.
--
-- CE QUI EST RETIRE, ET CE QUI RESTE -- chaque ligne justifiee par un chemin client reel :
--
--   detentions        INSERT + UPDATE retires. Le seul acces client restant est sbGetDetenusActifs
--                     (supabase.js). Les vingt droits de colonne en SELECT sont INTACTS, et la
--                     colonne `qhs` reste hors de leur portee -- le secret du QHS du 25 septembre
--                     2026 est un droit de colonne, et une revocation d'ecriture ne doit pas y
--                     toucher.
--   prisonniers_qhs   INSERT + UPDATE retires. Six sites de lecture restent. L'UPDATE n'avait plus
--                     qu'un seul appelant possible, sbMajPrisonnierQHS, qui est SANS APPELANT --
--                     les pouvoirs du Ministre passent par qhs_pouvoir, qui rend un verdict.
--   votes_electoraux  INSERT retire. Le DELETE est CONSERVE : sbDeletePersonnage efface les
--                     bulletins d'un personnage detruit volontairement, et c'est un chemin client
--                     legitime, appele par plateau-personnage.js.
--   jugements         INSERT retire. Le seul acces restant est sbLoadJugements.
--
-- LES ONZE POLICIES RESTENT, et elles doivent rester. Un droit retire et une policy sont deux
-- barrieres, pas une redondance : si un GRANT etait un jour re-accorde par accident,
-- `votes_electoraux_vote_soi` (votant = mon_personnage()) empeche encore de voter au nom d'un
-- autre.
--
-- Banc en transaction annulee : 2 epreuves, dont les CINQ ecritures refusees sous
-- `role = authenticated` et les CINQ chemins legitimes qui traversent -- quatre lectures et la
-- suppression des bulletins d'un personnage detruit.
REVOKE INSERT, UPDATE ON TABLE public.detentions       FROM authenticated, anon, PUBLIC;
REVOKE INSERT, UPDATE ON TABLE public.prisonniers_qhs  FROM authenticated, anon, PUBLIC;
REVOKE INSERT         ON TABLE public.votes_electoraux FROM authenticated, anon, PUBLIC;
REVOKE INSERT         ON TABLE public.jugements        FROM authenticated, anon, PUBLIC;

DO $$
DECLARE v_acl text; v_n int;
BEGIN
  -- P1 : L'ACL CLIENTE FINALE EST EXACTEMENT CELLE VOULUE, verbe par verbe et role par role.
  -- `detentions` disparait entierement de cette liste : sa lecture est un droit de COLONNE.
  SELECT string_agg(c.relname||':'||coalesce(r.rolname,'PUBLIC')||':'||ae.privilege_type, ' | '
                    ORDER BY c.relname, coalesce(r.rolname,'PUBLIC'), ae.privilege_type)
    INTO v_acl
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(c.relacl) ae LEFT JOIN pg_roles r ON r.oid=ae.grantee
   WHERE c.relname IN ('detentions','prisonniers_qhs','votes_electoraux','jugements')
     AND coalesce(r.rolname,'PUBLIC') IN ('anon','authenticated','PUBLIC');
  IF v_acl IS DISTINCT FROM
     'jugements:anon:SELECT | jugements:authenticated:SELECT | prisonniers_qhs:authenticated:SELECT | votes_electoraux:anon:SELECT | votes_electoraux:authenticated:DELETE | votes_electoraux:authenticated:SELECT' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- ACL cliente finale : %', v_acl;
  END IF;

  -- P2 : LE SECRET DU QHS TIENT. Vingt colonnes de `detentions` lisibles, et `qhs` n'en est pas.
  SELECT count(*) INTO v_n FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(a.attacl) ae LEFT JOIN pg_roles r ON r.oid=ae.grantee
   WHERE c.relname='detentions' AND r.rolname='authenticated' AND ae.privilege_type='SELECT';
  IF v_n <> 20 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % colonne(s) lisibles au lieu de 20', v_n; END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute a
      JOIN pg_class c ON c.oid=a.attrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
      CROSS JOIN LATERAL aclexplode(a.attacl) ae LEFT JOIN pg_roles r ON r.oid=ae.grantee
     WHERE c.relname='detentions' AND a.attname='qhs'
       AND coalesce(r.rolname,'PUBLIC') IN ('anon','authenticated','PUBLIC')) THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la colonne qhs est redevenue lisible par un client';
  END IF;

  -- P3 : LES DEUX BARRIERES. Les onze policies des quatre tables sont intactes, et la RLS est
  -- toujours active -- un droit retire ne remplace pas une policy, il s'y ajoute.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname='public'
     AND tablename IN ('detentions','prisonniers_qhs','votes_electoraux','jugements');
  IF v_n <> 11 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % policies au lieu de 11', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
   WHERE c.relname IN ('detentions','prisonniers_qhs','votes_electoraux','jugements')
     AND c.relrowsecurity;
  IF v_n <> 4 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % table(s) avec RLS active au lieu de 4', v_n; END IF;

  -- P4 : LES PORTES SERVEUR, ELLES, SONT INTACTES. Treize fonctions doivent rester appelables
  -- par un joueur -- sinon cette revocation aurait ferme le jeu au lieu de le proteger.
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname IN ('election_voter','detention_ouvrir_soi','detention_prolonger_soi',
         'detention_clore_purgee','detention_transferer_qhs','detention_reduire_peine',
         'detention_clore_evasion','justice_rendre_sentence','justice_prolonger_peine',
         'justice_condamner','justice_executer_condamnation','qhs_pouvoir','affaire_autorite_de')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_n <> 13 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- % porte(s) appelables par un joueur au lieu de 13', v_n; END IF;

  -- P5 : AUCUNE DONNEE TOUCHEE.
  SELECT count(*) INTO v_n FROM public.detentions;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % detention(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.prisonniers_qhs;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % ligne(s) QHS au lieu de 1', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.votes_electoraux;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % bulletin(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.jugements;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % jugement(s)', v_n; END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;