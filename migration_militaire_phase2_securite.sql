-- =====================================================================================
-- PHASE 2 — SECURITE : fermeture de engagements_militaires — 18 septembre 2026
--
-- ORDRE RESPECTE, et il est la clef : les producteurs legitimes (filiere officier ET filiere
-- soldat) ont ete migres vers des RPC attestees ET DEPLOYES avant cette fermeture. Poser les
-- droits d'abord aurait fait echouer les candidatures en silence -- la lecon de la passe 3.
--
-- La table et les RPC productrices appartiennent a postgres, relforcerowsecurity est faux : le
-- proprietaire contourne la RLS, donc les SECURITY DEFINER continuent d'ecrire. Verifie avant.
--
-- LECTURE OUVERTE, ECRITURE FERMEE : un Commandant et un Capitaine doivent voir les candidatures
-- qui leur sont adressees. Seules les ecritures directes disparaissent.
--
-- UNE PANNE REELLE CORRIGEE AU PASSAGE. confirmerAffectationSection ecrivait personnages.poste DU
-- CANDIDAT par sbUpdate, ce que la RLS refuse depuis le chantier B -- et sbUpdate ne leve pas. Le
-- candidat n'obtenait donc JAMAIS son poste de Lieutenant : la « promotion fantome » que le
-- commentaire du code disait avoir corrigee en aout etait revenue, silencieusement.
--
-- BANC HOSTILE 9/9, avec vrais SET ROLE et claims :
--   anon INSERT (faux candidat)            -> permission denied
--   authenticated INSERT (faux candidat)   -> permission denied
--   candidature par la RPC                 -> ACCEPTE, statut attente_commandant
--   authenticated UPDATE de son statut     -> permission denied
--   Capitaine saute l'etape du Commandant  -> 'etape_invalide' (l'ETAT PRECEDENT est verifie)
--   Capitaine usurpe le Commandant         -> 'autorite_insuffisante'
--   Commandant affecte a la compagnie      -> ACCEPTE, attente_capitaine
--   Capitaine installe le Lieutenant       -> ACCEPTE, ET LE POSTE EST REELLEMENT POSE
--   rejeu de la meme affectation           -> 'etape_invalide'
-- =====================================================================================
ALTER TABLE public.engagements_militaires ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS engagements_militaires_lecture ON public.engagements_militaires;
CREATE POLICY engagements_militaires_lecture ON public.engagements_militaires
  FOR SELECT TO authenticated USING (true);
REVOKE ALL ON TABLE public.engagements_militaires FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.engagements_militaires FROM authenticated;
GRANT SELECT ON TABLE public.engagements_militaires TO authenticated;

-- ============================================================================
-- FERMETURE DES VERBES DESTRUCTEURS (18 septembre 2026)
-- Applique via MCP sous le nom `fermeture_truncate_et_delete_anon`.
--
-- DECOUVERT EN VERIFIANT LE VIREMENT MIN_DEF -> CASERNE (section 15 du prompt de cloture).
-- 46 tables avaient RLS desactivee ET DELETE/TRUNCATE ouverts a `anon`, c'est-a-dire a un
-- visiteur non authentifie. Banc hostile, en transaction annulee : anon a pu fixer
-- virementJournalierCaserne a 50000, supprimer le budget de khalija, et TRUNCATE la table
-- des budgets nationaux. Les trois ont reussi.
--
-- Cause systemique : les DEFAULT PRIVILEGES du schema public accordent arwdDxtm a anon et
-- authenticated sur CHAQUE table creee. La derniere ligne du lot ferme cette cause pour les
-- tables futures -- sans quoi la meme faille reapparaitrait a la prochaine migration.
-- ============================================================================
DO $$
DECLARE
  r record;
  c_delete_legitime constant text[] := ARRAY[
    'actions_tracables','forum_posts','forum_topics','invitations_diner','locations_actives',
    'mails','objets_abandonnes','objets_recus','organisations','plaintes_en_cours',
    'salons_membres','titulaires_pnj','personnages','personnages_donnees','presences',
    'dons_en_attente','votes_electoraux','candidatures'];
BEGIN
  FOR r IN SELECT c.relname FROM pg_class c
            WHERE c.relnamespace='public'::regnamespace AND c.relkind='r' LOOP
    EXECUTE format('REVOKE TRUNCATE ON public.%I FROM anon, authenticated, PUBLIC', r.relname);
    IF NOT (r.relname = ANY (c_delete_legitime)) THEN
      EXECUTE format('REVOKE DELETE ON public.%I FROM anon, authenticated, PUBLIC', r.relname);
    END IF;
  END LOOP;
END $$;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE, DELETE ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE ON TABLES FROM authenticated;

-- Banc de non-regression, 18/09 : 4 attaques refusees (anon TRUNCATE et DELETE sur
-- budgets_nationaux, authenticated DELETE sur prets, authenticated TRUNCATE sur mails) ET
-- 7 suppressions legitimes toujours autorisees (mails, objets_recus, locations_actives,
-- invitations_diner, titulaires_pnj, forum_posts, la vue personnages).
--
-- RESTE OUVERT, VOLONTAIREMENT : UPDATE et INSERT. Des dizaines de producteurs clients ecrivent
-- encore ces tables en direct ; les fermer avant migration casserait le jeu. C'est le prochain
-- lot d'autorite, pas celui-ci.
