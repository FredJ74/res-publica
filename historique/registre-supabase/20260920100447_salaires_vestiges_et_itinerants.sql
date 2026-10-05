-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920100447
-- Nom original      : salaires_vestiges_et_itinerants
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 10:04:47 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b4d41937cf103c780e6ce632f5705c78
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
-- =====================================================================
-- ARBITRAGES APPLIQUES — VESTIGES, ALIAS, POSTES ITINERANTS
-- =====================================================================
-- §4 VESTIGES. senateur (1200), gouverneur (1500), prefet (900) n'existent pas
--    dans Res Publica. Inventaire fait AVANT suppression : ces trois cles
--    n'apparaissaient nulle part ailleurs que dans le tableau SALAIRES de
--    data.js -- ni dans postes_nommes_regles, ni dans une caisse, ni dans un
--    ordre, ni dans une RPC. Seule trace annexe : avatars.js teste la chaine
--    'prefet' dans un LIBELLE de role pour choisir une illustration, ce qui ne
--    depend pas du bareme. Rien ne casse.
--
-- §5 ALIAS. `maire_adjoint` devient canonique. `adj_maire` n'avait qu'UNE seule
--    occurrence dans tout le depot -- sa propre declaration -- contre 45 pour
--    `maire_adjoint`. Aucune compatibilite transitoire n'est donc necessaire :
--    il n'existait aucun consommateur vivant. Le salaire reste 500 FR, paye par
--    la caisse de la mairie de la ville.
--
-- §3 POSTES ITINERANTS. Secretaire administratif, commercant itinerant,
--    conseiller bancaire, hotesse d'accueil diplomatique : aucun employeur ne
--    les represente. Decision GD : aucun salaire. On les retire du miroir, ce
--    qui fait retomber leur titulaire sur le revenu universel -- il reste un
--    citoyen, il touche ce que touche tout citoyen. Leur role fonctionnel et
--    leurs places sont inchanges.

DELETE FROM public.salaires_civils_declares
 WHERE cle IN ('senateur','gouverneur','prefet','adj_maire',
               'secretaire_nationale','commercant_national','banquier_national','hotesse_ambassade');

DELETE FROM public.salaires_caisses WHERE poste_id = 'adj_maire';

-- Filet : si un bareme de poste reapparait sans caisse payeuse declaree, le
-- salaire est refuse plutot que verse ex nihilo. On le verifie par contrainte
-- plutot que par convention.
CREATE OR REPLACE FUNCTION public.salaires_coherence()
RETURNS TABLE(probleme text, cles text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
  SELECT 'bareme de poste sans caisse payeuse', string_agg(s.cle, ', ' ORDER BY s.cle)
    FROM public.salaires_civils_declares s
   WHERE s.categorie = 'poste'
     AND NOT EXISTS (SELECT 1 FROM public.salaires_caisses c WHERE c.poste_id = s.cle)
  HAVING count(*) > 0
  UNION ALL
  SELECT 'caisse payeuse sans bareme', string_agg(c.poste_id, ', ' ORDER BY c.poste_id)
    FROM public.salaires_caisses c
   WHERE NOT EXISTS (SELECT 1 FROM public.salaires_civils_declares s
                      WHERE s.cle = c.poste_id AND s.categorie = 'poste')
  HAVING count(*) > 0;
$$;
REVOKE ALL ON FUNCTION public.salaires_coherence() FROM PUBLIC, anon, authenticated;