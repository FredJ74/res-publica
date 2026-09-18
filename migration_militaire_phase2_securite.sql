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

-- ============================================================================
-- SUBTILISATION D'EXPLOSIF : RESOLUTION ENTIEREMENT SERVEUR (18 septembre 2026)
-- Applique sous le nom `militaire_subtiliser_resolution_serveur`.
-- Voir la source complete dans pg_proc : militaire_subtiliser_tenter(text).
--
-- Avant : Math.random() cote navigateur decidait de la reussite, puis le client FABRIQUAIT
-- lui-meme l'explosif (poserObjetMilitaire). Deux failles distinctes -- forcer la reussite, et
-- creer un explosif sans aucun jet.
--
-- La formule n'a PAS ete retouchee : bonus = (DUP-10)*2 - (ISN-45)/3 + palier de reputation
-- criminelle ; score = borner(50 + bonus + 1d100 - 50, 0, 100) ; <20 detecte, <66 echec, >=66
-- reussite. Banc du 18/09, 80 tentatives : a bonus -7, 30 % de reussites et 25 % de detections
-- (attendu 28 % / 26 %) ; a bonus +36, 23 reussites sur 40 et ZERO detection (le score plancher
-- passe a 37, donc la detection devient impossible -- conforme).
--
-- DEUX TERMES NON PORTES, signales plutot que devines : bonusFormation (+2 temporaire) et le
-- bonus de benediction n'existent qu'en memoire cliente. Les faire declarer par le client aurait
-- rouvert la faille. Ecart assume, a arbitrer par le GD.
--
-- PIEGE RENCONTRE AU BANC : `budgets_armurerie_verrou` (BEFORE UPDATE sur budgets_nationaux)
-- ANNULE toute ecriture de stockArmurerieMilitaire / lotsMilitaires qui ne vient pas d'un appel
-- serveur ou ne pose pas `rp.armurerie_militaire = '1'`. Une fixture de banc posant des claims
-- authenticated est donc silencieusement revertie. Le verrou est correct ; c'etait le banc qui
-- mentait.
REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- CALEPIN DE CAMPAGNE + DECORATIONS (18 septembre 2026)
-- Applique sous `militaire_calepin_campagne`, `decorations_militaires`,
-- `militaire_decorer_poste_scalaire`, `militaire_calepin_decorations`.
--
-- Le calepin est une PROJECTION (services_militaires + competences_militaires + soldes_militaires
-- + decorations_militaires). Aucune table de calepin : elle aurait cree une seconde verite.
--
-- Decorations : AUCUNE grille de merite, AUCUN catalogue de medailles. L'intitule est saisi par
-- celui qui decore. Le NIVEAU n'est pas un parametre, il est deduit du poste atteste :
-- commandant -> compagnie, min_def -> armee, president -> etat.
--
-- PIEGE CORRIGE AU BANC : acteur_poste_courant() renvoie TABLE(nom, poste_id, poste_city, pays).
-- L'affecter a une variable text donnait "(zztestCmdt,,,republic)" et AUCUN poste ne
-- correspondait jamais -- la fonction etait integralement morte, en fail-closed. Visible
-- uniquement parce que le banc rapporte le MOTIF du refus et pas seulement son existence.
--
-- Banc : 8/8 -- sans autorite refuse, auto-decoration refusee, hors juridiction refusee, le
-- Commandant obtient bien le niveau 'compagnie', rejeu exact refuse, autre intitule accepte,
-- INSERT et DELETE directs refuses par les GRANT.

-- ============================================================================
-- MODELE CANONIQUE DE BATAILLE + GILET FRAGILISE (18 septembre 2026)
-- Applique sous `batailles_modele_canonique_et_gilet`.
--
-- BATAILLES : PREPARATION, pas implementation. Le moteur physique de combat n'est pas construit
-- ici. Ce qui est pose, c'est l'endroit ou il ecrira, pour qu'il n'ait pas a inventer son propre
-- format le jour venu. `batailles` porte le FAIT, `batailles_engagements` porte QUI y etait et
-- dans quel etat il en est sorti -- avec une contrainte qui impose qu'un participant soit un PJ
-- (nom) OU un PNJ (matricule), jamais les deux.
--
-- Pourquoi pas chronique_nationale : elle restera le RECIT public, lu par la Tribune. Mais un
-- recit ne se requete pas -- on ne peut pas lui demander les pertes d'une compagnie. Meme
-- partage que services_militaires (canonique) et le calepin (projection).
--
-- `issue` est volontairement du texte libre : figer les issues possibles serait decider a la
-- place du moteur qui n'existe pas encore.
--
-- GILET : 50 % cote serveur. La protection balistique ne peut pas etre un tirage du navigateur de
-- celui qu'on vise. Un gilet qui a encaisse devient `fragilise` et ne protege plus -- il ne
-- disparait pas, il temoigne. La REPARATION n'est pas construite : elle suppose un atelier, une
-- recette et un cout, decisions GD non rendues. Dette assumee.
--
-- Banc : 7/7 -- appel client refuse au niveau du GRANT, INSERT de bataille par un joueur refuse,
-- deux impacts fragilisent les deux gilets, le troisieme ne trouve plus de gilet intact, et
-- AUCUN objet n'est detruit.
