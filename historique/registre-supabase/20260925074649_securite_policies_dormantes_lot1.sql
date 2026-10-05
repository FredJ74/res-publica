-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925074649
-- Nom original      : securite_policies_dormantes_lot1
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:46:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 797fffd683de10213726ad5cf2994216
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =============================================================================================
-- POLICIES DORMANTES : LES SIX TABLES DONT LA REGLE IG EST CERTAINE (25 septembre 2026)
-- =============================================================================================
-- Rappel du piege : ces tables portaient des policies `USING(true)` INERTES faute de RLS activee.
-- Activer la RLS sans les retirer d'abord ne fermerait rien -- les policies permissives se
-- combinent par OU. Chaque bloc commence donc par les supprimer.
--
-- Cinq autres tables du lot (budgets_nationaux, budgets_municipaux, budgets_clubs,
-- registre_ventes_armes, transferts_clubs) restent EN ATTENTE : l'interface ne suffit pas a y
-- trancher une regle. Les raisons sont dans le rapport.

-- ============================================================ militants_recrutes
-- Le jeu ne propose a aucun moment de consulter les militants d'autrui : les deux seules lectures
-- passent deja le nom du joueur en filtre (plateau-navigation.js:722, plateau-organisations-
-- quetes.js:3458). Le recrutement se fait toujours en son propre nom.
DROP POLICY IF EXISTS "Lecture publique militants"  ON public.militants_recrutes;
DROP POLICY IF EXISTS "Ecriture publique militants" ON public.militants_recrutes;
ALTER TABLE public.militants_recrutes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "militants : les siens, et rien d autre" ON public.militants_recrutes
  FOR SELECT TO authenticated USING (recruteur = (SELECT public.mon_personnage()));
CREATE POLICY "militants recrutes en son propre nom" ON public.militants_recrutes
  FOR INSERT TO authenticated WITH CHECK (recruteur = (SELECT public.mon_personnage()));
REVOKE ALL ON public.militants_recrutes FROM anon;

-- ============================================================ propositions_diplomatiques
-- Affaire entre deux Ministres des Affaires etrangeres. Le filtre client de
-- sbGetPropositionsDiplomatiques (supabase.js:2768) dit exactement la regle : proposeur ou cible.
DROP POLICY IF EXISTS "Lecture publique propositions diplomatiques" ON public.propositions_diplomatiques;
DROP POLICY IF EXISTS "Ecriture publique propositions diplomatiques" ON public.propositions_diplomatiques;
DROP POLICY IF EXISTS "Maj publique propositions diplomatiques" ON public.propositions_diplomatiques;
ALTER TABLE public.propositions_diplomatiques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "diplomatie lue par les deux chancelleries" ON public.propositions_diplomatiques
  FOR SELECT TO authenticated
  USING (public.mon_poste_est_dans('min_ae', data ->> 'empireProposeur')
      OR public.mon_poste_est_dans('min_ae', data ->> 'empireCible'));
CREATE POLICY "proposition faite par le min_ae du pays proposeur" ON public.propositions_diplomatiques
  FOR INSERT TO authenticated
  WITH CHECK (public.mon_poste_est_dans('min_ae', data ->> 'empireProposeur'));
CREATE POLICY "reponse donnee par le min_ae du pays cible" ON public.propositions_diplomatiques
  FOR UPDATE TO authenticated
  USING (public.mon_poste_est_dans('min_ae', data ->> 'empireCible'))
  WITH CHECK (public.mon_poste_est_dans('min_ae', data ->> 'empireCible'));
REVOKE ALL ON public.propositions_diplomatiques FROM anon;

-- ============================================================ batiments_fermes
-- Lecture publique VOULUE : tout le monde doit voir qu'un batiment est ferme, sinon le blocage de
-- navigation devient incoherent. L'incendie n'est pas une prerogative : n'importe quel joueur peut
-- le commettre -- mais en son propre nom.
DROP POLICY IF EXISTS "Lecture publique des fermetures"   ON public.batiments_fermes;
DROP POLICY IF EXISTS "Insertion publique des fermetures" ON public.batiments_fermes;
ALTER TABLE public.batiments_fermes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fermetures visibles de tous les joueurs" ON public.batiments_fermes
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "fermeture inscrite en son propre nom" ON public.batiments_fermes
  FOR INSERT TO authenticated
  WITH CHECK (auteur = (SELECT public.mon_personnage()));
REVOKE ALL ON public.batiments_fermes FROM anon;

-- ============================================================ rumeurs_actives
-- LA LECTURE LARGE EST LE MECANISME : une rumeur qu'on ne peut pas entendre ne sert a rien, et le
-- tri par cible se fait cote client sur un SELECT global. Elle reste donc ouverte a tout JOUEUR --
-- et a eux seuls : un visiteur sans compte n'entend pas les rumeurs de Republia.
-- L'ecriture, elle, a deux formes precises : le Ministre de la Justice qui se cree un scandale a
-- lui-meme en torturant (seul producteur du depot), et le dementi officiel qui marque la rumeur
-- resolue -- reserve aux membres du gouvernement.
DROP POLICY IF EXISTS "Lecture publique rumeurs actives"  ON public.rumeurs_actives;
DROP POLICY IF EXISTS "Ecriture publique rumeurs actives" ON public.rumeurs_actives;
DROP POLICY IF EXISTS "Maj publique rumeurs actives"      ON public.rumeurs_actives;
ALTER TABLE public.rumeurs_actives ENABLE ROW LEVEL SECURITY;
CREATE POLICY "les rumeurs courent entre joueurs" ON public.rumeurs_actives
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "rumeur creee sur soi-meme" ON public.rumeurs_actives
  FOR INSERT TO authenticated
  WITH CHECK ((data ->> 'cible') = (SELECT public.mon_personnage()));
CREATE POLICY "dementi par un membre du gouvernement" ON public.rumeurs_actives
  FOR UPDATE TO authenticated
  USING (public.mon_poste_est('president') OR public.mon_poste_est('pm')
      OR public.mon_poste_est('min_int')  OR public.mon_poste_est('min_fin')
      OR public.mon_poste_est('min_just') OR public.mon_poste_est('min_def')
      OR public.mon_poste_est('min_info') OR public.mon_poste_est('min_ae'))
  WITH CHECK (true);
REVOKE ALL ON public.rumeurs_actives FROM anon;

-- ============================================================ ambassades_ouvertes
-- Lecture ouverte aux joueurs : ce cache alimente la garde `ambassadeur_local` elle-meme, la
-- restreindre casserait l'acces aux bureaux. Ecriture reservee aux Affaires etrangeres -- celles
-- de l'empire qui ouvre et nomme, celles du pays hote qui expulse.
DROP POLICY IF EXISTS "Lecture publique ambassades"  ON public.ambassades_ouvertes;
DROP POLICY IF EXISTS "Ecriture publique ambassades" ON public.ambassades_ouvertes;
ALTER TABLE public.ambassades_ouvertes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ambassades visibles des joueurs" ON public.ambassades_ouvertes
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "ambassade ouverte par les affaires etrangeres" ON public.ambassades_ouvertes
  FOR INSERT TO authenticated
  WITH CHECK (public.mon_poste_est_dans('min_ae', empire));
CREATE POLICY "ambassade geree par l empire ou par l hote" ON public.ambassades_ouvertes
  FOR UPDATE TO authenticated
  USING (public.mon_poste_est_dans('min_ae', empire) OR public.mon_poste_est_dans('min_ae', pays_hote))
  WITH CHECK (public.mon_poste_est_dans('min_ae', empire) OR public.mon_poste_est_dans('min_ae', pays_hote));
REVOKE ALL ON public.ambassades_ouvertes FROM anon;

-- ============================================================ reservations_salle_reception
-- « La Salle est deja reservee aujourd'hui par <empire> » est une information volontairement
-- partagee entre ambassades concurrentes : la lecture reste ouverte aux joueurs. Reserver exige
-- d'etre l'ambassadeur accredite dans le pays hote, ce que porte ambassades_ouvertes.
DROP POLICY IF EXISTS "Lecture publique reservations salle"  ON public.reservations_salle_reception;
DROP POLICY IF EXISTS "Ecriture publique reservations salle" ON public.reservations_salle_reception;
ALTER TABLE public.reservations_salle_reception ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reservations visibles des joueurs" ON public.reservations_salle_reception
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "salle reservee par un ambassadeur accredite" ON public.reservations_salle_reception
  FOR INSERT TO authenticated
  WITH CHECK (
    (data ->> 'reservePar') = (SELECT public.mon_personnage())
    AND EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                 WHERE a.pays_hote = reservations_salle_reception.pays_hote
                   AND a.empire    = (data ->> 'empire')
                   AND (a.data ->> 'ambassadeur') = (SELECT public.mon_personnage()))
  );
REVOKE ALL ON public.reservations_salle_reception FROM anon;