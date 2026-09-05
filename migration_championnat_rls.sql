-- Verrouillage de la ligne historique championnat.id = 1 (chantier "durabilite championnat",
-- 5 septembre 2026). NON EXECUTEE a la redaction de ce fichier.
--
-- PROBLEME CORRIGE
-- ----------------
-- Deux reinitialisations parasites (1er et 4 septembre 2026) ont detruit la saison reelle. Cause
-- etablie par l'audit : des onglets clients restes ouverts plusieurs jours continuent d'executer
-- un ancien moteur football, qui (a) confond une erreur de lecture Supabase avec "aucun
-- championnat n'existe", (b) fabrique alors une saison neuve, et (c) l'ecrit par un PATCH aveugle
-- sur championnat id=1 -- ecrasant la vraie saison.
--
-- Le code a ete corrige (lecture explicite, creation atomique, ecriture uniquement en
-- compare-and-swap) et l'etat canonique deplace vers championnat id=2. Mais AUCUN correctif
-- JavaScript ne peut rien contre un bundle DEJA CHARGE en memoire : il ne contient tout
-- simplement pas nos nouvelles verifications. Ces onglets ont "id=eq.1" code en dur dans leur
-- propre copie de supabase.js. Seule une barriere COTE SERVEUR peut les arreter -- c'est l'objet
-- de cette migration.
--
-- DOCTRINE DU PROJET (deja etablie)
-- ---------------------------------
-- Voir migration_renseignements_connus.sql (executee le 22 aout 2026) et
-- migration_journal_editions_securisation.sql (3 septembre 2026) : RLS active + policy explicite
-- pour ce qui doit rester accessible, AUCUNE policy pour ce qui doit rester interdit. Le role
-- service_role (endpoints api/, cron) contourne nativement la RLS et n'est jamais affecte.
--
-- EFFET EXACT APRES APPLICATION
-- -----------------------------
--   SELECT sur championnat  : inchange pour tous (anon compris) -- les vieux onglets peuvent
--                             continuer a LIRE id=1, ce qui les rend inertes (la ligne est
--                             neutralisee : phase='terminee', resultatsFinales=null).
--   UPDATE de id=1          : la ligne devient INVISIBLE a l'UPDATE -> 0 ligne modifiee.
--   INSERT de id=1          : viole la clause WITH CHECK -> erreur "new row violates row-level
--                             security policy" (HTTP 401). La ligne ne peut donc pas etre
--                             recreee si elle venait a disparaitre.
--   UPDATE / INSERT id<>1   : autorises -> le nouveau client continue de fonctionner normalement
--                             sur id=2 (compare-and-swap et creation atomique inclus).
--   DELETE                  : AUCUNE policy -> interdit sur TOUTE la table. Aucun chemin
--                             fonctionnel du jeu ne supprime de championnat (verifie sur tout le
--                             depot) ; cela protege aussi id=2 d'un effacement accidentel, et
--                             empeche la sequence "DELETE id=1 puis INSERT id=1" qui contournerait
--                             la policy d'INSERT.
--
-- Traitement explicite du DELETE demande a l'audit : oui, il est traite, et volontairement REFUSE
-- pour toutes les lignes, pas seulement id=1.
--
-- PERIMETRE STRICTEMENT LIMITE A championnat (arbitrage du 5 septembre 2026)
-- ---------------------------------------------------------------------
-- Cette migration ne touche QUE la table championnat : aucune autre table, aucune policy,
-- aucun GRANT ailleurs. Un durcissement de paris_sportifs avait ete envisage, puis ECARTE :
-- ses policies actuelles n'ont pas pu etre inspectees avec certitude, et remplacer
-- dynamiquement les policies d'une table economique hors perimetre serait un risque
-- disproportionne. Il fera l'objet d'un chantier securite separe.
--
-- Residu connu et ACCEPTE pour ce chantier : apres une erreur de lecture, un tres ancien onglet
-- garde en memoire une saison fantome (jamais persistee) et peut encore publier un topic forum.
-- Sa portee est bornee et demontree : son fantome a toujours dateDebut = maintenant, donc
-- journeeCible = 0 et numero = 1 -- il ne peut viser que la journee 1 de la saison 1, pour
-- laquelle aucun pari n'existe ni ne peut plus etre place. Aucune consequence persistante.
--
-- IDEMPOTENTE : rejouable sans risque. Les policies existantes sont enumerees puis supprimees
-- avant recreation, ce qui evite tout doublon et neutralise une eventuelle policy permissive
-- heritee qui annulerait la protection.

ALTER TABLE public.championnat ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol record;
BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
             WHERE schemaname = 'public' AND tablename = 'championnat'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.championnat', pol.policyname);
  END LOOP;
END $$;

-- Lecture : strictement inchangee (le jeu lit le championnat depuis le client).
CREATE POLICY championnat_select_public
  ON public.championnat FOR SELECT
  TO anon, authenticated
  USING (true);

-- Ecriture : tout SAUF la ligne historique id = 1.
CREATE POLICY championnat_update_hors_ligne_historique
  ON public.championnat FOR UPDATE
  TO anon, authenticated
  USING (id <> 1)
  WITH CHECK (id <> 1);   -- interdit aussi de faire MIGRER une ligne vers id = 1

CREATE POLICY championnat_insert_hors_ligne_historique
  ON public.championnat FOR INSERT
  TO anon, authenticated
  WITH CHECK (id <> 1);

-- DELETE : aucune policy, donc interdit a tous les roles soumis a la RLS.
