-- =====================================================================
-- TRACE — LOT B (19 septembre 2026)
-- Audit lecture seule de l'ordre « Lancer une operation de renseignement »
-- (Ministre de la Defense) + fermeture de la seule faille TECHNIQUE et
-- INCONTESTABLE constatee pendant l'audit.
--
-- CE FICHIER N'EST QU'UNE TRACE. Il n'est pas execute par le jeu : la
-- migration a deja ete appliquee en production sous le nom
--   securite_rapports_renseignement
-- Il sert a relire, plus tard, ce qui a ete change et POURQUOI.
-- =====================================================================
--
-- CE QUI N'A PAS ETE TOUCHE, ET POURQUOI
-- --------------------------------------
-- L'ordre lui-meme (formule, cout, autorite, informations revelees, RNG
-- cote navigateur) est laisse EXACTEMENT en l'etat : la refonte de game
-- design est en attente d'arbitrage. Voir le rapport d'audit.
--
-- Deux autres trous mesures pendant l'audit sont SIGNALES, PAS FERMES,
-- parce que les fermer suppose une decision qui n'est pas technique :
--   1. caisse_institution_mouvement() n'exige qu'« un personnage
--      authentifie ». Banc (transaction annulee) : un simple citoyen sans
--      aucun poste a ramene la caisse du Ministere de la Defense de
--      65 292 FR a 0. Fermer cela demande un modele d'autorite par caisse
--      (quel poste peut depenser quelle caisse) : 12+ sites appelants.
--   2. compagnies_militaires a une policy de lecture « USING (true) »
--      ouverte a anon ET authenticated. Banc : anon a lu en clair le
--      capitaine, le lieutenant, l'effectif et l'armement d'une compagnie
--      etrangere. C'est le brouillard de guerre, donc du game design.
--
-- CE QUI A ETE FERME
-- ------------------
-- rapports_renseignement : RLS etait DESACTIVEE (relrowsecurity = false),
-- ses trois policies « publique » etaient donc inertes, et anon detenait
-- SELECT / INSERT / UPDATE.
--
-- Banc hostile, en transaction annulee, AVANT correctif :
--   H2  anon INSERT un rapport forge ................ ACCEPTE
--   H3  anon SELECT tous les rapports ............... 1 ligne lue
--   H4  anon UPDATE le contenu d'un rapport ......... ACCEPTE
--
-- Banc APRES correctif, en transaction annulee :
--   anon SELECT ..................................... permission denied
--   Arnie lit les rapports .......................... uniquement le sien
--   Arnie reecrit le rapport de Phileas ............. REFUSE (0 ligne)
--
-- Table vide (0 ligne) au moment de la migration : aucune donnee de jeu
-- existante n'est affectee. La policy de lecture reproduit EXACTEMENT le
-- filtre que le navigateur applique deja dans
-- sbGetRapportsRenseignementNonRemontes() — aucune regle de jeu ne change.
--
-- L'autorite « seul le Ministre de la Defense declenche l'operation »
-- n'est volontairement PAS posee : elle releve de la refonte.

ALTER TABLE public.rapports_renseignement ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ecriture publique rapports renseignement" ON public.rapports_renseignement;
DROP POLICY IF EXISTS "Lecture publique rapports renseignement"  ON public.rapports_renseignement;
DROP POLICY IF EXISTS "Maj publique rapports renseignement"      ON public.rapports_renseignement;

-- REVOKE sur PUBLIC autant que sur anon : les DEFAULT PRIVILEGES du schema
-- public accordent arwdDxtm a anon sur toute table creee (piege connu).
REVOKE ALL ON public.rapports_renseignement FROM PUBLIC;
REVOKE ALL ON public.rapports_renseignement FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.rapports_renseignement TO authenticated;

-- Lecture : le rapport n'existe que pour son destinataire.
CREATE POLICY "rens lecture destinataire" ON public.rapports_renseignement
  FOR SELECT TO authenticated
  USING (data ->> 'lieutenantNom' = public.mon_personnage());

-- Creation : acteur authentifie porteur d'un personnage. Le rapport est
-- adresse a un TIERS (le lieutenant) : la propriete ne peut pas etre
-- exigee ici sans casser le parcours legitime du Ministre.
CREATE POLICY "rens creation acteur" ON public.rapports_renseignement
  FOR INSERT TO authenticated
  WITH CHECK (public.mon_personnage() IS NOT NULL);

-- Maj : uniquement son propre rapport (sbMarquerRapportRemonte), et il
-- reste le sien apres coup.
CREATE POLICY "rens maj destinataire" ON public.rapports_renseignement
  FOR UPDATE TO authenticated
  USING      (data ->> 'lieutenantNom' = public.mon_personnage())
  WITH CHECK (data ->> 'lieutenantNom' = public.mon_personnage());
