-- NON APPLIQUÉE — à faire valider par Fred avant application (Claude l'applique).
-- Bloc 4 de la mission « Novomirsk, PNJ, interface et suites des rapports » : lieux de Krasnov (Fred, 23/11/2026 ;
-- GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 29, 32 et 34). Rejouable : chaque étape est idempotente
-- (ON CONFLICT, gardes, marque dans le code de fonction). Rien n'est touché au goulag, aux postes ni aux personnages.
--
-- Points 30, 31 et 33 n'ont besoin d'aucun changement serveur :
--  * 30 : le transfert en clinique privée vaut déjà 0 PA et 400 PSK en Sovarka (table MJ ordres_couts_pays, migration
--         20261110003000) ; seul l'écran change de pièce (salle d'attente → chambre).
--  * 31 : « Demander ce local à la mairie » est l'ordre existant sovarka_demande_location (1 PA, payer_ordre).
--  * 33 : « Chanter l'hymne au Tracteur » garde son ordre et son résultat (prier) ; seule l'animation est ajoutée.

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- Point 29 — Musée de Krasnov : le directeur est supprimé, le guide Arkadi Pamiatnikov reçoit la solution.
-- Le jugement reste celui de enigme_krasnov_repondre_interne (krasnov_ecole_agir, action repondre_enigme), inchangé.
-- (a) L'ordre de pièce « Soumettre la solution de l'énigme au directeur » disparaît : sa ligne de tarif aussi.
--     krasnov_ecole_agir ne la lit pas (la réponse est gratuite et ne passe pas par payer_ordre).
DELETE FROM public.ordres_couts WHERE fn = 'repondre_enigme_krasnov' AND pa = 0 AND cost = 0;
-- (b) Carnet de l'énigme : la feuille volante dit à qui donner sa solution (feuilles achetées à partir de maintenant).
SELECT pg_temp.rp_remplacer('public.krasnov_feuille_objet_interne()'::regprocedure,
  $a$Ici commence l''énigme de Krasnov.'$a$,
  $b$Ici commence l''énigme de Krasnov. Soumettez votre solution au guide du musée.' /* carnet_guide_musee_v1 */$b$,
  1, 'carnet_guide_musee_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- Point 32 — Centre d'affaires de Krasnov : quatre bureaux attribués par la mairie (2 côté maison bleue, 2 côté
-- hôpital), plafond de loyer 40 PSK par jour (colonne plafond de sovarka_locaux, réglable par le MJ ; le maire fixe le
-- loyer sous ce plafond). Loyer de départ = plafond, comme les box des centres commerciaux de Krasnov.
-- Les trois « locaux fantômes » du gabarit (bureau_prestige, bureau_standard, open_space), absents du parcours du
-- bâtiment depuis le 15/11 (navigation_lieux_regles), sont retirés s'ils ne sont ni demandés ni exploités.
-- local_louer refuse déjà tout local déclaré dans sovarka_locaux (attribution_municipale) : l'ancienne location
-- « Louer ce bureau (500 PSK/jour) » est donc fermée côté serveur.
DO $bureaux$
BEGIN
  IF EXISTS (SELECT 1 FROM public.locations_actives
              WHERE country = 'soviet' AND data->>'city' = 'ville_b' AND data->>'buildingId' = 'centre-affaires') THEN
    RAISE EXCEPTION 'Bail actif au centre d''affaires de Krasnov : arbitrage requis avant de passer à l''attribution municipale';
  END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_demandes
              WHERE pays = 'soviet' AND ville = 'ville_b'
                AND (local_souhaite_batiment = 'centre-affaires' OR local_batiment = 'centre-affaires')
                AND local_souhaite_piece IN ('bureau_prestige', 'bureau_standard', 'open_space')) THEN
    RAISE EXCEPTION 'Demande en cours sur un ancien bureau du gabarit à Krasnov : arbitrage requis';
  END IF;
END
$bureaux$;

INSERT INTO public.sovarka_locaux (pays, ville, batiment, piece, label, origine, plafond, loyer)
VALUES ('soviet', 'ville_b', 'centre-affaires', 'bureau_1', 'Bureau 1 (côté maison bleue)', 'centre', 40, 40),
       ('soviet', 'ville_b', 'centre-affaires', 'bureau_2', 'Bureau 2 (côté maison bleue)', 'centre', 40, 40),
       ('soviet', 'ville_b', 'centre-affaires', 'bureau_3', 'Bureau 3 (côté hôpital)',      'centre', 40, 40),
       ('soviet', 'ville_b', 'centre-affaires', 'bureau_4', 'Bureau 4 (côté hôpital)',      'centre', 40, 40)
ON CONFLICT (pays, ville, batiment, piece) DO NOTHING;

DELETE FROM public.sovarka_locaux l
 WHERE l.pays = 'soviet' AND l.ville = 'ville_b' AND l.batiment = 'centre-affaires'
   AND l.piece IN ('bureau_prestige', 'bureau_standard', 'open_space')
   AND l.demande_id IS NULL
   AND public.sovarka_exploitant_interne(l.ville, l.batiment, l.piece) IS NULL;

-- ---------------------------------------------------------------------------------------------------------------
-- Point 34 — Groupe électrogène : la station-service de Krasnov ouvre la boutique « Équipements contre les
-- intempéries » (même boutique que le garage de Novomirsk ; prix : aliments_param prix_groupe_electrogene). Les bidons
-- restent vendus par l'ordre propre de la station (station_carburant).
INSERT INTO public.climat_boutiques (id, pays, ville, batiment, piece, cles)
VALUES ('station-service-krasnov', 'soviet', 'ville_b', 'station-service-krasnov', 'boutique_station', ARRAY['groupe_electrogene'])
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.climat_lieux_vente (cle, pays, ville, chez)
VALUES ('groupe_electrogene', 'soviet', 'ville_b', 'à la station-service de Krasnov')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- Contrôles.
DO $verif$
BEGIN
  IF EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'repondre_enigme_krasnov') THEN
    RAISE EXCEPTION 'Tarif de l''ordre supprimé encore présent';
  END IF;
  IF position('Soumettez votre solution au guide du musée.' IN public.krasnov_feuille_objet_interne()->>'desc') = 0 THEN
    RAISE EXCEPTION 'Carnet de l''énigme non mis à jour';
  END IF;
  IF (SELECT count(*) FROM public.sovarka_locaux WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'centre-affaires'
        AND piece IN ('bureau_1', 'bureau_2', 'bureau_3', 'bureau_4') AND plafond = 40) <> 4 THEN
    RAISE EXCEPTION 'Bureaux du centre d''affaires de Krasnov non déclarés';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.climat_boutiques WHERE id = 'station-service-krasnov'
                   AND 'groupe_electrogene' = ANY (cles)) THEN
    RAISE EXCEPTION 'Boutique climat de la station de Krasnov absente';
  END IF;
END
$verif$;
