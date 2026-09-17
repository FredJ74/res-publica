-- =====================================================================================
-- P0 : FERMETURE DU SAS objets_recus — Res Publica, 17 septembre 2026
--
-- L'ETAT TROUVE. objets_recus est le sas par lequel transite TOUT objet entre joueurs. Il avait :
--   - la RLS DESACTIVEE ;
--   - zero policy ;
--   - INSERT/SELECT/UPDATE/DELETE/TRUNCATE accordes a anon.
-- N'importe qui, meme non authentifie, pouvait donc fabriquer un objet arbitraire au profit de
-- n'importe quel joueur (robinet de creation d'objets), lire ce que recoivent les autres, ou
-- supprimer un objet en transit pour le faire disparaitre.
--
-- CAUSE SYSTEMIQUE, et c'est le point le plus important de ce correctif : ce n'etait PAS une
-- erreur propre a cette table. Les DEFAULT PRIVILEGES du schema public accordent
-- « arwdDxtm » (tous droits DML) a anon, authenticated et service_role sur CHAQUE NOUVELLE TABLE
-- (pg_default_acl, defaclobjtype='r'), et « X » sur chaque nouvelle fonction. Toute table creee
-- dans public nait donc totalement ouverte a anon. Le seul rempart est la RLS -- ce qui rend
-- « activer la RLS » non pas une precaution mais une OBLIGATION a chaque creation de table.
--
-- ORDRE D'EXECUTION SUIVI, et il importe : les producteurs legitimes ont ete migres et DEPLOYES
-- (commit 169d15d) AVANT toute fermeture de droits. Poser la RLS d'abord aurait fait echouer en
-- silence la remise des butins de vol et des documents d'urbanisme -- exactement l'erreur commise
-- en passe 3 avec le Lieutenant.
--
-- POURQUOI LES RPC CONTINUENT DE FONCTIONNER. La table et toutes les fonctions productrices
-- (objet_sas_deposer, inventaire_donner, acheter_produit_commerce, tracts_donner_joueur,
-- tracts_reclamer_don, restituer_reliquats_chantier) appartiennent a postgres, et
-- relforcerowsecurity = false : le proprietaire contourne la RLS. Verifie avant d'agir.
--
-- BANC 19/19 en transaction annulee, zero residu, etat juge a chaque scenario :
--   anon      : INSERT / SELECT / DELETE / RPC          -> permission denied (4/4)
--   joueur A  : INSERT direct (creation arbitraire)     -> permission denied
--   joueur A  : UPDATE direct                           -> permission denied
--   joueur A  : lecture du sas d'autrui                 -> 0 ligne visible
--   joueur A  : suppression du sas d'autrui             -> AUCUNE erreur mais 0 ligne supprimee,
--               ligne d'autrui intacte (le cas « faux succes » : seul l'etat le revele)
--   joueur A  : lecture / reclamation de SA ligne       -> voit 1, supprime 1
--   butin     : victime legitime -> depose + type_butin bascule dans la MEME transaction
--   butin     : non-victime -> pas_la_victime ; deja confirme -> butin_deja_confirme
--   urbanisme : bon demandeur -> depose ; autre -> destinataire_pas_le_demandeur
--   motif invente -> motif_non_declare
--   Donner PJ->PJ (inventaire_donner) -> objet RETIRE de l'inventaire (1->0) ET depose (1 ligne)
--   Donner en usurpant un autre acteur -> acteur_non_authentifie
--   joueur B  : voit bien ses 3 lignes recues
-- =====================================================================================
ALTER TABLE public.objets_recus ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS objets_recus_lire_le_sien ON public.objets_recus;
DROP POLICY IF EXISTS objets_recus_reclamer_le_sien ON public.objets_recus;

-- mon_personnage() est SECURITY DEFINER : une policy ne doit jamais interroger
-- personnages_donnees directement (authenticated n'a aucun droit dessus, la policy refuserait
-- alors tout le monde en silence).
CREATE POLICY objets_recus_lire_le_sien ON public.objets_recus
  FOR SELECT TO authenticated USING (destinataire = public.mon_personnage());

CREATE POLICY objets_recus_reclamer_le_sien ON public.objets_recus
  FOR DELETE TO authenticated USING (destinataire = public.mon_personnage());

-- AUCUNE policy INSERT ni UPDATE : plus aucun client ne depose ni ne modifie directement.

REVOKE ALL ON TABLE public.objets_recus FROM anon;
REVOKE INSERT, UPDATE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.objets_recus FROM authenticated;
GRANT SELECT, DELETE ON TABLE public.objets_recus TO authenticated;

-- Le corps de objet_sas_deposer est celui de la migration « objet_sas_deposer_atteste ».
