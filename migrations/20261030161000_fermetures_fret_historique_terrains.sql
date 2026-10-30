-- =====================================================================================
-- FERMETURE DE DEUX ANCIENS ACCÈS D'ÉCRAN (30/10/2026, Claude, clôture Luthécia). NON APPLIQUÉE.
-- Compatible avec l'écran en ligne : seuls les écrivains légitimes déjà identifiés restent ouverts.
--
-- 1. caisses_fret : tout joueur connecté pouvait créer une caisse au nom d'un autre et modifier
--    N'IMPORTE QUELLE caisse (statut, destinataire, listes de chargeurs et de réceptionnaires).
--    Écrivains légitimes de l'écran (plateau-justice-economie.js) : le chef de la caisse (création,
--    chargeurs, fermeture, expédition) et son destinataire (réceptionnaires). Les commandes serveur
--    (fret_objet_agir, fret_dedouaner…) sont SECURITY DEFINER et ne passent pas par ces règles.
--    Aucune caisse n'existe en production au 30/10 : aucune donnée de joueur concernée.
-- 2. terrains_historique_ventes : l'écran pouvait y inscrire une fausse vente. Son seul écrivain
--    d'écran (sbEnregistrerVenteTerrain) n'a plus aucun appelant ; le serveur l'alimente par
--    terrain_proprietaire_muter (SECURITY DEFINER). Écriture d'écran retirée.
-- Hors périmètre, signalés : budgets_clubs (championnat, Codex) reste écrivable par tout joueur ;
-- registre_ventes_armes reste alimenté par l'écran (armurerie, police : Codex).
-- =====================================================================================
DROP POLICY IF EXISTS caisses_fret_ecriture_acteur ON public.caisses_fret;
CREATE POLICY caisses_fret_ecriture_acteur ON public.caisses_fret FOR INSERT TO authenticated
  WITH CHECK (leader = public.mon_personnage());
DROP POLICY IF EXISTS caisses_fret_maj_acteur ON public.caisses_fret;
CREATE POLICY caisses_fret_maj_acteur ON public.caisses_fret FOR UPDATE TO authenticated
  USING (leader = public.mon_personnage() OR destinataire = public.mon_personnage())
  WITH CHECK (leader = public.mon_personnage() OR destinataire = public.mon_personnage());

REVOKE INSERT ON public.terrains_historique_ventes FROM authenticated, anon;
DROP POLICY IF EXISTS terrains_historique_ventes_ecriture_acteur ON public.terrains_historique_ventes;
