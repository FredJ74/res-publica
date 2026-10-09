-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.prets.jour_dernier_prelevement IS 'Journee partagee ISO (YYYY-MM-DD) du dernier prelevement nocturne. Marqueur anti-rejeu du cron. NULL = jamais preleve.';
COMMENT ON FUNCTION public.compromis_expire_resoudre(text,text) IS 'Resout en UNE transaction un compromis arrive a echeance, pour les deux familles : p_type
« terrain » (terrains_etat, blob texte, clause permis du maire) ou « entreprise » (entreprises,
blob jsonb). Le TIRAGE du pret est ici, pas chez l''appelant. Identifiants deterministes
(compromis-<bien>-<jour>, pret-<type>-<bien>-<jour>) : un rejeu ne cree ni second pret ni seconde
ligne d''historique. Un bien Helvetia est refuse et reste sur resoudre_compromis_helvetia_expire.
Verdicts : non_applicable, helvetia, pas_encore_expire, pret_accorde_compromis_gele,
pret_en_attente_finalisation, rembourse, perdu. Non appelable depuis le reseau.';
