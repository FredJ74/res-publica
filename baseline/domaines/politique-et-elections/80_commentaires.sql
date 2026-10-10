-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.elections_tracts_pnj.canal IS 'tract | prospectus | conference | jean_lou -- origine de la voix, pour l''audit uniquement.';
COMMENT ON FUNCTION public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text) IS 'Nomme par tirage au sort le titulaire d''un poste nomme dont l''autorite n''a pas tranche dans les
48h, et sanctionne cette autorite -- le tout en UNE transaction, revendiquee par
acte_nocturne_revendiquer(''candidature_poste_tirage''). Le TIRAGE est ici, pas chez l''appelant :
un rejeu ne peut donc pas designer un autre gagnant. Verdicts : aucun_candidat,
poste_deja_attribue (la journee reste ouverte), deja_traite_aujourdhui, aucun_candidat_eligible,
puis ok avec gagnant, sanction, pop_avant et pop_apres. Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.election_resultats_consigner(text,jsonb,jsonb,jsonb) IS 'Consigne le resultat d''un scrutin en une transaction : le blob du cycle, l''evenement public et
la ligne de chronique nationale. La garde est un COMPARE-AND-SWAP sur `resultatsTraites` dans le
FILTRE de l''UPDATE -- zero ligne touchee signifie deja proclame, ou cycle inconnu, et dans les
deux cas aucune annonce ne part. Elle ne DEPOUILLE pas : le calcul est deterministe et reste chez
l''appelant, qui le partage a l''identique avec le client. Verdicts : deja_traite, puis ok avec
evenement_pose et chronique_posee. Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.election_voter(text,text,text,text) IS 'Enregistre le bulletin d''un joueur : la ligne de votes_electoraux ET l''entree du blob que le
depouillement compte, dans UNE transaction, sous verrou du cycle. L''electeur n''est pas un
parametre -- il vient de mon_personnage().
VERDICTS : acteur_non_authentifie, parametres_invalides, poste_inconnu, non_domicilie,
cycle_absent, cycle_illisible, cycle_sans_calendrier, vote_ferme (avec phase=mandat le cas
echeant), candidat_inconnu, deja_vote, puis ok avec le votant, le candidat et la cle du scrutin.
AUCUNE REGLE ELECTORALE N''EST DECIDEE ICI : fenetre, domicile et liste des candidats sont les
conditions deja appliquees par voterPour(), transcrites sur les champs du blob.';
COMMENT ON FUNCTION public.postes_nommes_regles_empreinte_reelle() IS 'Empreinte reelle du miroir des regles de nomination, sur les cinq colonnes et sur la valeur effective de autorite_scope (coalesce(autorite_scope, scope)), celle que lit poste_autorite_de. Pendant SQL de outils/generateurs/generer_postes_nommes.py. Chantier 4C.';
COMMENT ON FUNCTION public.vote_confiance_resoudre(text) IS 'Depouille UN vote de confiance echu, en une transaction : le tirage des sieges PNJ restants, la
cloture (statut = termine), l''evenement public et le courrier de censure. La transition d''etat
EST le verrou -- un rejeu lit « termine » et rend deja_resolu sans atteindre le tirage. Verdicts :
vote_introuvable, deja_resolu, pas_echu, puis ok avec resultat, pour, contre et sieges_tires.
Non appelable depuis le reseau.';
