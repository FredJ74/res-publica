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

COMMENT ON COLUMN public.candidatures.cle_scrutin IS 'Scrutin vise : cycles_electoraux.data->>dateDebutCandidatures en ms. Pose par le declencheur candidatures_cloture, jamais par le client. NULL sur les lignes anterieures au 11 octobre 2026.';
COMMENT ON COLUMN public.communications_salles.ordres IS 'Les ordres qu on peut prononcer depuis cette tribune. Sans cette liste, la porte n aurait valide que le COUT de l ordre -- et le miroir en declare 381 : n importe lequel aurait servi de conference de presse.';
COMMENT ON COLUMN public.conferences_presse.poste_libelle IS 'La fonction publique telle qu elle etait AU MOMENT de la communication. Figee ici expres : un ministre revoque le lendemain a bien parle comme ministre, et la presse doit pouvoir le citer ainsi.';
COMMENT ON COLUMN public.elections_tracts_pnj.canal IS 'tract | prospectus | conference | jean_lou -- origine de la voix, pour l''audit uniquement.';
COMMENT ON COLUMN public.presidence_memoire.source IS 'Provenance attestee, en liste fermee. C est elle qui rend la fabrication d un fait impossible : une source non declaree ne s enregistre pas.';
COMMENT ON COLUMN public.votes_electoraux.tour IS 'Tour vise : cycles_electoraux.data->>dateVote en ms, meme cle que elections_tracts_pnj.tour. Pose par election_voter. NULL sur les lignes anterieures au 11 octobre 2026.';
COMMENT ON FUNCTION public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text) IS 'Nomme par tirage au sort le titulaire d''un poste nomme dont l''autorite n''a pas tranche dans les
48h, et sanctionne cette autorite -- le tout en UNE transaction, revendiquee par
acte_nocturne_revendiquer(''candidature_poste_tirage''). Le TIRAGE est ici, pas chez l''appelant :
un rejeu ne peut donc pas designer un autre gagnant. Verdicts : aucun_candidat,
poste_deja_attribue (la journee reste ouverte), deja_traite_aujourdhui, aucun_candidat_eligible,
puis ok avec gagnant, sanction, pop_avant et pop_apres. Non appelable depuis le reseau.';
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
COMMENT ON TABLE public.communications_salles IS 'Qui peut prendre la parole officiellement, et depuis quelle piece. Registre d autorite du meme genre que caisses_autorites : c est lui qui distingue la tribune presidentielle de celle du Gouvernement, alors que les deux portent les memes noms d ordre (arbitrage du 11 octobre 2026).';
COMMENT ON TABLE public.conferences_presse IS 'En-tete d une conference de presse officielle : qui a parle, en quelle qualite, depuis quelle tribune, ce qu il a declare, et comment la conference s est terminee. La matiere de l echange est dans conferences_presse_echanges. Ne porte AUCUN jugement : ni veracite, ni credibilite, ni qualite (arbitrage du 11 octobre 2026).';
COMMENT ON TABLE public.conferences_presse_echanges IS 'La matiere brute d une conference : la question posee, la reponse EXACTE du joueur, ou son refus. Aucune porte ne modifie un echange deja renseigne -- la transcription est immuable. Une redaction peut la citer et la commenter ; elle ne peut pas la reecrire (regle propre a Republia, arbitrage du 11 octobre 2026).';
COMMENT ON TABLE public.presidence_memoire IS 'Memoire narrative des mandats presidentiels, pour le referent Huguette Papier. N accepte que des faits PUBLICS attestes par le serveur, et uniquement pendant un mandat tenu par un joueur. Ne porte AUCUN jugement : il n existe ni score, ni colonne de reussite, ni fonction qui en deduise une (arbitrage du 11 octobre 2026).';
