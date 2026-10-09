-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine divers et technique -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.actes_nocturnes.details IS 'Ce que l''acte a REELLEMENT fait, ecrit apres l''effet : montant, reste du, verdict. La table
est ainsi un journal autant qu''un verrou.';
COMMENT ON COLUMN public.actes_nocturnes.jour IS 'Journee de jeu en Europe/Paris, de type date et non de type texte. Elle n''est JAMAIS un
parametre : acte_nocturne_revendiquer() la calcule. Un appelant qui choisirait le jour pourrait
rejouer l''effet autant de fois qu''il a de dates a proposer.';
COMMENT ON COLUMN public.actes_nocturnes.sujet IS 'Identifiant du sujet -- un bail, un pret, un dossier. Le litteral ''-'' quand le mecanisme n''a
qu''un sujet par pays (voir actes_nocturnes_mecanismes.sujet_singleton).';
COMMENT ON COLUMN public.actes_nocturnes_mecanismes.note IS 'A quoi sert ce mecanisme et ce qu''un rejeu produirait sans la revendication.';
COMMENT ON COLUMN public.actes_nocturnes_mecanismes.sujet_singleton IS 'true quand le mecanisme n''a QU''UN sujet par pays ; le sujet vaut alors ''-''.';
COMMENT ON TABLE public.actes_nocturnes IS 'L''IDEMPOTENCE DES TACHES NOCTURNES VIT DANS CETTE CLE PRIMAIRE. Revendiquer un acte, c''est
INSERER sa ligne ; un second passage le meme jour obtient un conflit de cle et ne produit rien.
Ce n''est plus un marqueur qu''une ecriture avalee peut perdre, c''est une contrainte resolue en
une instruction. Generalise repartitions_versements(pays, source, beneficiaire, jour).
Une cle primaire ne protege que ce qui COMMITE avec elle : voir acte_nocturne_revendiquer().
RETENTION : ajout seul, quelques dizaines de lignes par jour ; aucune purge posee, non-decision
assumee -- le jour venu, DELETE ... WHERE jour < current_date - 180.';
COMMENT ON TABLE public.actes_nocturnes_mecanismes IS 'LISTE BLANCHE des mecanismes de la passe de minuit. Revendiquer un mecanisme absent LEVE une
violation de cle etrangere : un nom mal orthographie ne peut pas ouvrir un second espace de noms
en silence, ce qui reviendrait a ne plus proteger le vrai. Ajouter un mecanisme est une
migration, et c''est voulu -- la liste des taches nocturnes devient lisible en un endroit.';
