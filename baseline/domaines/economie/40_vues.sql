-- Vues
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 40 : vues
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- Vue catalogue_generiques_raccordes | reloptions = AUCUNE
-- SECURITY DEFINER (par defaut : reloptions vide). Cette vue s'execute donc
-- avec les droits de son PROPRIETAIRE, et les policies RLS des tables
-- sous-jacentes sont evaluees pour lui, pas pour l'appelant.
-- Intentionnel ou vestigial ? La reponse est dans
-- baseline/DIFFERENCES-DELIBEREES.json, cle vues_security_definer.
CREATE OR REPLACE VIEW public.catalogue_generiques_raccordes AS
 SELECT g.id AS generique_id,
    count(c.id)::integer AS nb_correspondances
   FROM catalogue_generiques g
     LEFT JOIN catalogue_correspondance_legacy c ON c.generique_id = g.id
  GROUP BY g.id;
