-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.agents_renseignement.pays IS 'Pays de PRESENCE PHYSIQUE de l''agent pose. NULL tant qu''il n''a jamais ete pose. Ne jamais confondre avec pays_couverture, qui est purement narratif.';
COMMENT ON COLUMN public.agents_renseignement.pays_couverture IS 'Pays de la COUVERTURE : tenue, faux nom, profession fictive. Aucun effet mecanique. N''est JAMAIS une localisation (arbitrage du 22 septembre 2026).';
COMMENT ON COLUMN public.agents_renseignement.pnj_id IS 'Identite REELLE permanente de cet agent au socle (4 en tout, une par role). Cette table porte les OCCURRENCES DE MISSION : plusieurs lignes peuvent viser le meme pnj_id, une par cellule. Une cellule terminee ne detruit pas l''identite, elle termine l''incarnation.';
COMMENT ON COLUMN public.renseignement_identites_reelles.dup IS 'PERIME comme source depuis le 27/09/2026 : la DUP autoritaire est pnj_membres.car_dup des quatre identites (13 pour toutes). Colonne conservee parce que cellule_renseignement_creer la lit encore ; a declasser quand cet ecrivain aura bascule.';
COMMENT ON COLUMN public.renseignements_connus.jour_observe IS 'Journee mondiale (date Paris) SUR LAQUELLE porte le fait. A ne jamais confondre avec created_at, qui dit seulement quand le fait a ete consigne : la passe nocturne tourne apres minuit et consigne donc, le jour J, des faits qui portent sur J-1. Renseignee par DEFAULT pour que les fonctions d''observation n''aient pas a la citer.';
COMMENT ON COLUMN public.renseignements_connus.pays IS 'Lieu REEL de l''observation, fige au moment des faits. Rien a voir avec la couverture de la cellule : une cellule de couverture soviet peut observer un fait a Luthecia. NULL sur les faits anterieurs au 26 septembre 2026, dont le lieu n''est pas prouvable.';
COMMENT ON FUNCTION public.douane_payer_effectifs(text) IS 'Paye quotidienne des douaniers du port : 50 FR par standard, 100 par cynophile, sur la caisse du Ministere de l''Interieur. Montant et caisse calcules par le serveur, jamais choisis par l''appelant. Idempotente par journee mondiale ecoulee. Appelable par le cron meme si le poste chef_douanes est vacant : c''est le Ministere qui paie.';
