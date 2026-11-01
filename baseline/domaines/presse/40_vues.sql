-- Vues
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 40 : vues
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- Vue archives_tribune_index | reloptions = AUCUNE
-- SECURITY DEFINER (par defaut : reloptions vide). Cette vue s'execute donc
-- avec les droits de son PROPRIETAIRE, et les policies RLS des tables
-- sous-jacentes sont evaluees pour lui, pas pour l'appelant.
-- Intentionnel ou vestigial ? La reponse est dans
-- baseline/DIFFERENCES-DELIBEREES.json, cle vues_security_definer.
CREATE OR REPLACE VIEW public.archives_tribune_index AS
 SELECT id,
    journal_id,
    date_edition,
    (EXISTS ( SELECT 1
           FROM jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(e.faits_sources -> 'FACTS'::text) = 'array'::text THEN e.faits_sources -> 'FACTS'::text
                    ELSE '[]'::jsonb
                END) f(value)
          WHERE (f.value ->> 'estPJ'::text) = 'true'::text)) AS contient_pj,
    COALESCE(((une -> 'sujets'::text) -> 0) ->> 'titre'::text, 'Édition du '::text || date_edition::text) AS titre
   FROM journal_editions e
  WHERE statut = 'publiee'::text AND journal_id = 'republic_autruche-entravee'::text;
