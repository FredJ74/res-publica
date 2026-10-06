-- ============================================================================
-- CHANTIER 3 -- AUTORITE (2/2) : UNE SEULE REGLE D'ECRITURE CLIENTE
--
-- Trois generations d'autorite coexistaient dans la base :
--
--   1. AUCUNE BARRIERE     25 tables sans RLS. Le GRANT etait la seule
--                          protection, et il etait large : n'importe quel
--                          compte anonyme -- la cle anon est publique, elle est
--                          dans supabase.js -- pouvait reecrire
--                          budgets_nationaux, indices_villes ou niveaux_prison
--                          sans meme posseder de personnage.
--   2. POLICY PERMISSIVE   28 policies « allow_all_<table> » ou « Ecriture
--                          publique ... », toutes USING (true) WITH CHECK
--                          (true) TO PUBLIC. Elles declarent une autorisation,
--                          pas une autorite.
--   3. SOCLE MODERNE       mon_personnage(), mon_poste_est_dans(),
--                          affaire_autorite_de(), bail_autorite_de()... 93
--                          policies conditionnelles qui, elles, derivent
--                          l'identite cote serveur.
--
-- Cette migration supprime les generations 1 et 2 et pose la generation 3
-- partout, au degre que le game design permet SANS arbitrage : ecrire dans le
-- monde exige d'etre un acteur du monde.
--
-- CE QUE CELA NE CHANGE PAS. Aucune regle de jeu. Un joueur qui pouvait deposer
-- une plainte, verser un budget ou vendre un terrain le peut encore, dans
-- exactement les memes cas. Ce qui disparait, c'est la possibilite de le faire
-- SANS ETRE PERSONNE. Les droits plus fins -- quel poste debite quelle caisse,
-- quel juge condamne dans quelle ville -- vivent dans les portes serveur et les
-- policies de la generation 3 ; ils ne sont ni ajoutes ni retires ici.
--
-- POURQUOI CE DEGRE, ET PAS UN AUTRE. Passer de « n'importe qui » a « le bon
-- titulaire » demanderait, table par table, de decider QUI a autorite : qui
-- inscrit une naissance, qui declare une greve, qui valide un transfert de
-- club. Ce sont des questions de game design. Passer de « n'importe qui » a
-- « un acteur » n'en demande aucune : on ne joue pas sans personnage.
--
-- POURQUOI UNE SEULE DECLARATION ET DES BOUCLES, et non 480 instructions
-- engendrees : la surface d'ecriture du navigateur est la SEULE donnee d'entree
-- de ce chantier. Ecrite une fois, elle gouverne les revocations ET les
-- policies, qui ne peuvent donc pas se contredire. L'etat final, lui, sera
-- rendu table par table dans baseline/domaines/*/60_rls-policies.sql.
--
-- VERIFIE AVANT ECRITURE
--   . service_role porte BYPASSRLS : les crons et les 16 fonctions de api/ ne
--     voient aucune de ces policies.
--   . Les 530 fonctions SECURITY DEFINER appartiennent a `postgres`, lui-meme
--     proprietaire des 252 tables, et aucune table ne porte FORCE ROW LEVEL
--     SECURITY : la RLS ne s'y applique pas.
--   . Les 7 personnages de la beta portent tous un user_id. mon_personnage()
--     leur repond : aucun joueur existant ne devient muet.
--   . La vue `personnages` n'a pas de RLS (c'est une vue) et n'est pas touchee :
--     son autorite vit dans ses trois declencheurs INSTEAD OF.
--   . L'upsert de `presences` (Prefer: resolution=merge-duplicates,
--     supabase.js:1428) est un INSERT ... ON CONFLICT DO UPDATE : il exige
--     UPDATE, qui est donc declare.
--
-- Idempotente : DROP POLICY IF EXISTS avant chaque CREATE POLICY, une RLS deja
-- active ne bouge pas, un REVOKE sur un privilege absent ne fait rien.
--
-- ----------------------------------------------------------------------------
-- ETAT DU BANC -- A REJOUER AVANT TOUTE APPLICATION
--
-- Cette migration n'a PAS encore ete eprouvee dans sa version actuelle.
--
--   . 5 octobre 2026, banc transactionnel : a trouve une vraie erreur --
--     « column reference "i" is ambiguous » (42702), l'alias de
--     generate_subscripts portant le meme nom que la variable plpgsql.
--     Corrigee : l'alias s'appelle desormais `idx` (voir la boucle A).
--   . 6 octobre 2026, deux tentatives de rejeu : interrompues AVANT d'atteindre
--     la base -- une erreur de transport MCP, puis un timeout de connexion.
--     Etat verifie intact apres chacune : `acteur_identifie` absente, 27 tables
--     sans RLS, 213 policies, 7 personnages, registre a 539 entrees.
--
-- A FAIRE, DANS CET ORDRE : rejouer le banc complet (BEGIN, migration
-- integrale, mesures, RAISE EXCEPTION, ROLLBACK), verifier qu'il ne reste
-- rien, PUIS seulement appliquer.
--
-- Ce qui est deja prouve hors ligne : la grammaire, par le vrai analyseur de
-- PostgreSQL 17.7 (pglast) ; et l'existence de chaque objet nomme ici -- 76
-- tables, 36 signatures, 28 policies --, par l'invariant 12 de
-- verifier-autorite.py. Ce que seul le banc peut dire : que les cinq boucles
-- se comportent comme annonce sur l'etat reel.
-- ----------------------------------------------------------------------------
-- ============================================================================

-- ----------------------------------------------------------------------------
-- LA BRIQUE : « est-ce que quelqu'un parle ? »
--
-- Une fonction, et non la meme expression recopiee dans 62 policies. Elle dit
-- la seule chose que toutes ces tables ont en commun : un appel serveur passe,
-- un compte qui porte un personnage passe, une session anonyme sans personnage
-- ne passe pas.
--
-- STABLE : evaluee une fois par requete, pas une fois par ligne.
-- SECURITY DEFINER : comme mon_personnage(), et pour la meme raison -- le
-- client n'a aucun droit sur personnages_donnees.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.acteur_identifie()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.est_appel_serveur() OR public.mon_personnage() IS NOT NULL;
$function$;

COMMENT ON FUNCTION public.acteur_identifie() IS
  'Vrai si l''appel vient du serveur, ou d''un compte qui porte un personnage. '
  'Socle des policies d''ecriture du chantier 3 : ecrire dans le monde exige '
  'd''etre un acteur du monde. Ne dit RIEN du poste ni de la presence -- ces '
  'questions ont leurs propres briques (mon_poste_est_dans, '
  'acteur_present_sur_site).';

GRANT EXECUTE ON FUNCTION public.acteur_identifie() TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- LA SURFACE, LES FERMETURES, LE SOCLE
-- ----------------------------------------------------------------------------

DO $$
DECLARE
  -- LA SURFACE D'ECRITURE DU NAVIGATEUR, relevee le 5 octobre 2026 dans les 58
  -- fichiers charges par index.html : 197 appels sbInsert/sbUpdate/sbDelete et
  -- 8 fetch PostgREST directs. I = INSERT, U = UPDATE, D = DELETE.
  --
  -- Une table absente de cette liste n'est ecrite par aucune ligne de code
  -- client. Un verbe absent d'une ligne n'est appele nulle part.
  --
  -- api/ n'y figure pas : ces 16 fonctions tournent cote serveur sous
  -- service_role, qui ignore droits clients et RLS. Ce sont des portes
  -- serveur, pas des acces directs.
  surface text[][] := ARRAY[
    ['actions_tracables','DI'],
    ['ambassades_ouvertes','IU'],
    ['batiments_fermes','I'],
    ['budgets_clubs','IU'],
    ['budgets_municipaux','IU'],
    ['budgets_nationaux','IU'],
    ['caisses_fret','IU'],
    ['candidatures','DI'],
    ['championnat','IU'],
    ['chat_piece','I'],
    ['chronique_nationale','I'],
    ['commandes_militaires','IU'],
    ['contenu_caisses_fret','IU'],
    ['contributions_piete','I'],
    ['cycles_electoraux','IU'],
    ['demandes_grace','IU'],
    ['demandes_manifestation','IU'],
    ['demandes_mariage','IU'],
    ['demandes_naturalisation','IU'],
    ['detentions','IU'],
    ['dons_en_attente','DU'],
    ['dossiers_urbanisme','I'],
    ['etat_civil_deces','I'],
    ['etat_civil_naissances','I'],
    ['etats_urgence','IU'],
    ['evenements_globaux','I'],
    ['forum_posts','DIU'],
    ['forum_topics','DIU'],
    ['fraudes_electorales','IU'],
    ['greves_generales','IU'],
    ['indices_villes','IU'],
    ['invitations_diner','DIU'],
    ['jugements','I'],
    ['lectures_chat','IU'],
    ['locations_actives','DIU'],
    ['logements_attributions_historique','I'],
    ['logements_demandes','IU'],
    ['mails','DIU'],
    ['mariages','IU'],
    ['messages_chat','I'],
    ['niveaux_prison','IU'],
    ['objets_abandonnes','DI'],
    ['objets_recus','D'],
    ['organisations','DIU'],
    ['personnages','DIU'],
    ['petites_annonces','IU'],
    ['plaintes_en_cours','DIU'],
    ['presences','DIU'],
    ['prets','IU'],
    ['prisonniers_qhs','IU'],
    ['propositions_diplomatiques','IU'],
    ['quetes_actives','IU'],
    ['rapports_renseignement','IU'],
    ['registre_ventes_armes','I'],
    ['reservations_salle_reception','I'],
    ['rumeurs_actives','IU'],
    ['salons_chat','I'],
    ['salons_membres','DI'],
    ['souvenirs_accueil','IU'],
    ['successions','IU'],
    ['terrains_etat','IU'],
    ['terrains_historique_ventes','I'],
    ['testaments','IU'],
    ['titulaires_pnj','DIU'],
    ['tournees','IU'],
    ['transferts_clubs','IU'],
    ['tribune_articles_etouffes','I'],
    ['vols_en_attente','IU'],
    ['votes_confiance','IU'],
    ['votes_electoraux','DI']
  ];
  lisibles_avant text[];
  r record;
  i integer;
  tbl text;
  verbes text;
  n_revoc integer := 0;
  n_rls integer := 0;
  n_drop integer := 0;
  n_lecture integer := 0;
  n_ecriture integer := 0;
BEGIN
  -- CE QUI EST LISIBLE AUJOURD'HUI, releve AVANT de toucher a quoi que ce soit.
  -- Deux facons de l'etre sans policy de lecture nommee : la RLS est eteinte,
  -- ou une policy FOR ALL permissive couvre tout. Les 100 tables dont la RLS
  -- est active SANS policy, elles, sont fermees VOLONTAIREMENT : elles ne
  -- doivent surtout pas recevoir de lecture publique.
  SELECT array_agg(DISTINCT c.relname::text) INTO lisibles_avant
    FROM pg_class c
    JOIN pg_namespace s ON s.oid = c.relnamespace AND s.nspname = 'public'
   WHERE c.relkind = 'r'
     AND EXISTS (SELECT 1 FROM aclexplode(c.relacl) a JOIN pg_roles ro ON ro.oid = a.grantee
                  WHERE ro.rolname IN ('anon','authenticated') AND a.privilege_type = 'SELECT')
     AND (NOT c.relrowsecurity
          OR EXISTS (SELECT 1 FROM pg_policy p
                      WHERE p.polrelid = c.oid AND p.polcmd::text = '*' AND p.polpermissive
                        AND coalesce(pg_get_expr(p.polqual, p.polrelid), 'true') = 'true'
                        AND coalesce(pg_get_expr(p.polwithcheck, p.polrelid), 'true') = 'true'));

  -- A. LES DROITS D'ECRITURE QUE LE NAVIGATEUR N'EXERCE PAS
  --    Tout verbe detenu par un role client et absent de la declaration part.
  --    `anon` n'en detient aucun depuis le chantier B : la boucle le confirme
  --    plutot que de le supposer.
  FOR r IN
    SELECT c.relname::text AS t, a.privilege_type::text AS p, ro.rolname::text AS role
      FROM pg_class c
      JOIN pg_namespace s ON s.oid = c.relnamespace AND s.nspname = 'public'
      CROSS JOIN LATERAL aclexplode(c.relacl) a
      JOIN pg_roles ro ON ro.oid = a.grantee
     WHERE c.relkind IN ('r','v','p','m')
       AND ro.rolname IN ('anon','authenticated')
       AND a.privilege_type IN ('INSERT','UPDATE','DELETE')
     ORDER BY 1, 3, 2
  LOOP
    -- l'alias de generate_subscripts ne peut pas s'appeler `i` : plpgsql
    -- resoudrait la reference vers sa propre variable et PostgreSQL refuse
    -- l'ambiguite (42702). Piege verifie au banc.
    verbes := NULL;
    SELECT surface[idx][2] INTO verbes
      FROM generate_subscripts(surface, 1) AS g(idx)
     WHERE surface[idx][1] = r.t;
    IF r.role = 'anon'
       OR verbes IS NULL
       OR position(substr(r.p, 1, 1) IN verbes) = 0 THEN
      EXECUTE format('REVOKE %s ON public.%I FROM %I', r.p, r.t, r.role);
      n_revoc := n_revoc + 1;
    END IF;
  END LOOP;

  -- B. LA RLS, PARTOUT
  --    Sans elle le GRANT etait la seule barriere. Les 2 tables hors baseline
  --    (compagnies_militaires_snapshot_20260926,
  --    rapports_cellules_artefacts_20260926) sont incluses : elles n'ont aucun
  --    droit client, l'activation est sans effet et l'invariant devient entier.
  FOR r IN
    SELECT c.relname::text AS t
      FROM pg_class c
      JOIN pg_namespace s ON s.oid = c.relnamespace AND s.nspname = 'public'
     WHERE c.relkind = 'r' AND NOT c.relrowsecurity
     ORDER BY 1
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.t);
    n_rls := n_rls + 1;
  END LOOP;

  -- C. LES POLICIES D'ECRITURE TOTALEMENT PERMISSIVES
  --    Designees par ce qu'elles FONT, pas par leur nom : permissive, portant
  --    sur une ecriture (ou sur tout), sans aucune condition. Aucune ne peut
  --    survivre a ce chantier, et aucune ne pourra revenir sans que
  --    verifier-autorite.py le voie.
  FOR r IN
    SELECT c.relname::text AS t, p.polname::text AS nom
      FROM pg_policy p
      JOIN pg_class c ON c.oid = p.polrelid
      JOIN pg_namespace s ON s.oid = c.relnamespace AND s.nspname = 'public'
     WHERE p.polpermissive
       AND p.polcmd::text <> 'r'
       AND coalesce(pg_get_expr(p.polqual, p.polrelid), 'true') = 'true'
       AND coalesce(pg_get_expr(p.polwithcheck, p.polrelid), 'true') = 'true'
     ORDER BY 1, 2
  LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.nom, r.t);
    n_drop := n_drop + 1;
  END LOOP;

  -- D1. LA LECTURE PUBLIQUE, LA OU ELLE EXISTAIT DEJA
  --     A l'identique : USING (true). On ne ferme rien qui etait ouvert, on le
  --     rend seulement explicite -- et donc verifiable.
  FOREACH tbl IN ARRAY coalesce(lisibles_avant, ARRAY[]::text[])
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_policy p
                     JOIN pg_class c ON c.oid = p.polrelid
                    WHERE c.relname = tbl AND c.relnamespace = 'public'::regnamespace
                      AND p.polcmd::text IN ('r','*')) THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', tbl || '_lecture_publique', tbl);
      EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO anon, authenticated USING (true)',
                     tbl || '_lecture_publique', tbl);
      n_lecture := n_lecture + 1;
    END IF;
  END LOOP;

  -- D2. L'ECRITURE D'ACTEUR, SUR CHAQUE VERBE DECLARE QUI N'A PAS DEJA SA
  --     POLICY. Une policy de la generation 3 -- celle qui sait QUI a autorite
  --     -- est toujours plus precise que acteur_identifie() : on ne la remplace
  --     pas, on comble seulement les trous.
  FOR i IN 1 .. array_length(surface, 1)
  LOOP
    FOR r IN
      SELECT * FROM (VALUES ('I','INSERT','a','ecriture_acteur'),
                            ('U','UPDATE','w','maj_acteur'),
                            ('D','DELETE','d','suppression_acteur')) AS v(code, verbe, cmd, suffixe)
    LOOP
      CONTINUE WHEN position(r.code IN surface[i][2]) = 0;
      -- une vue ne porte pas de RLS : son autorite est ailleurs
      CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_class c
                                 WHERE c.relname = surface[i][1]
                                   AND c.relnamespace = 'public'::regnamespace
                                   AND c.relkind = 'r');
      -- le droit a-t-il survecu a A ? sinon la policy serait decorative
      CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_class c
                                CROSS JOIN LATERAL aclexplode(c.relacl) a
                                JOIN pg_roles ro ON ro.oid = a.grantee
                                 WHERE c.relname = surface[i][1]
                                   AND c.relnamespace = 'public'::regnamespace
                                   AND ro.rolname = 'authenticated'
                                   AND a.privilege_type = r.verbe);
      CONTINUE WHEN EXISTS (SELECT 1 FROM pg_policy p
                             JOIN pg_class c ON c.oid = p.polrelid
                            WHERE c.relname = surface[i][1]
                              AND c.relnamespace = 'public'::regnamespace
                              AND p.polcmd::text IN (r.cmd, '*'));
      EXECUTE format('CREATE POLICY %I ON public.%I FOR %s TO authenticated %s',
                     surface[i][1] || '_' || r.suffixe, surface[i][1], r.verbe,
                     CASE r.code
                       WHEN 'I' THEN 'WITH CHECK (public.acteur_identifie())'
                       WHEN 'U' THEN 'USING (public.acteur_identifie()) WITH CHECK (public.acteur_identifie())'
                       ELSE 'USING (public.acteur_identifie())'
                     END);
      n_ecriture := n_ecriture + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'autorite : % droits revoques, % tables mises sous RLS, % policies permissives retirees, % lectures publiques posees, % ecritures d''acteur posees',
    n_revoc, n_rls, n_drop, n_lecture, n_ecriture;
END $$;
