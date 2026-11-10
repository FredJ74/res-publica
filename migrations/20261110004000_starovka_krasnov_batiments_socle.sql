-- STAROVKA ET KRASNOV : BATIMENTS DU SOCLE, LOCAUX, PARCELLES, SYNDICAT (Claude, 10/11/2026 ; reponses de
-- Fred du 09/11 au soir, GAME-DESIGN-NOVOMIRSK.md, « Reponses de Fred »).
--
-- 1. Pas de syndicat en Sovarka (reponse 2) : le siege syndical quitte les regles de Starovka et Krasnov.
-- 2. Batiments dessines par Fred et codables depuis le socle (reponse 5) : memes pieces que leur gabarit,
--    sortie depuis la rue qui porte leur enseigne. Starovka : marche, magasin de chasse (armurerie),
--    restaurant « Entre terre et mer » (gabarit du restaurant de PSM), lycee (universite), logements
--    collectifs « Baraquement Sibirsk-9 » (logements sociaux, comme Novomirsk), zone d'extraction du
--    petrole (zone de production). Krasnov : marche, ecole (universite), eglise du Tractorisme, musee,
--    bar-tabac, entree de l'exploitation forestiere (zone de production).
-- 3. Deux locaux simples rue « locaux a louer » de Starovka (reponse 4), demandes a la mairie.
--    Plafond propose : 50 PSK par jour (a valider par Fred).
-- 4. Terrain de Starovka : 4 parcelles (reponse 9). Le serveur nomme la parcelle n « terrain@pn » ; les
--    locaux et logements de la parcelle n portent le prefixe « pn_ » dans le batiment du terrain.
-- Logements de Starovka : 4 petits a 10 PSK et 4 grands a 20 PSK, comme Novomirsk (propose, a valider).
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.rue_noeuds_serveur WHERE country = 'soviet' AND noeud IN (
        'starovka-rue-petrole-ferme', 'starovka-rue-logements-collectifs', 'starovka-rue-restaurant-boutique',
        'starovka-rue-mairie-marche', 'starovka-rue-lycee-commissariat', 'starovka-rue-magasin-chasse',
        'starovka-rue-locaux-a-louer', 'krasnov-rue-marche-ferme', 'krasnov-rue-ecole-foret', 'krasnov-rue-eglise',
        'krasnov-rue-station-musee', 'krasnov-rue-tabac-bar')) <> 12 THEN
    RAISE EXCEPTION 'noeuds de rue de Starovka ou Krasnov absents du serveur';
  END IF;
END $$;

-- 1. Syndicat.
DELETE FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city IN ('ville_a', 'ville_b') AND building = 'siege-syndical';
DELETE FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville IN ('ville_a', 'ville_b') AND batiment = 'siege-syndical';

-- 2. Batiments du socle : pieces copiees de leur gabarit.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership)
SELECT 'soviet', v.ville, v.batiment, r.pieces, false, NULL
  FROM (VALUES ('ville_a', 'marche', 'soviet', 'capitale'), ('ville_a', 'armurerie', 'soviet', 'capitale'),
               ('ville_a', 'capitaine-sauvage', 'soviet', 'capitale'), ('ville_a', 'universite', 'soviet', 'capitale'),
               ('ville_a', 'logements-novomirsk', 'soviet', 'capitale'),
               ('ville_b', 'marche', 'soviet', 'capitale'), ('ville_b', 'universite', 'soviet', 'capitale'),
               ('ville_b', 'kolkhoze-spirituel', 'soviet', 'capitale'), ('ville_b', 'musee-novomirsk', 'soviet', 'capitale'),
               ('ville_b', 'cafe-tabac-cheminots-montrouge', 'republic', 'ville_b')) v(ville, batiment, src_pays, src_ville)
  JOIN public.navigation_lieux_regles r ON r.pays = v.src_pays AND r.ville = v.src_ville AND r.batiment = v.batiment
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_a', 'locaux-starovka', '["local_1", "local_2"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
  ('soviet', 'ville_a', 'starovka-rue-petrole-ferme',        'zone-production'),
  ('soviet', 'ville_a', 'starovka-rue-logements-collectifs', 'logements-novomirsk'),
  ('soviet', 'ville_a', 'starovka-rue-restaurant-boutique',  'capitaine-sauvage'),
  ('soviet', 'ville_a', 'starovka-rue-mairie-marche',        'marche'),
  ('soviet', 'ville_a', 'starovka-rue-lycee-commissariat',   'universite'),
  ('soviet', 'ville_a', 'starovka-rue-magasin-chasse',       'armurerie'),
  ('soviet', 'ville_a', 'starovka-rue-locaux-a-louer',       'locaux-starovka'),
  ('soviet', 'ville_b', 'krasnov-rue-marche-ferme',          'marche'),
  ('soviet', 'ville_b', 'krasnov-rue-ecole-foret',           'universite'),
  ('soviet', 'ville_b', 'krasnov-rue-ecole-foret',           'zone-production'),
  ('soviet', 'ville_b', 'krasnov-rue-eglise',                'kolkhoze-spirituel'),
  ('soviet', 'ville_b', 'krasnov-rue-station-musee',         'musee-novomirsk'),
  ('soviet', 'ville_b', 'krasnov-rue-tabac-bar',             'cafe-tabac-cheminots-montrouge')
ON CONFLICT DO NOTHING;

INSERT INTO public.logements_sociaux_historiques (pays, ville, batiment, piece, label, type_logement, loyer, bonus_moral, bonus_sante) VALUES
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_1', 'Petit appartement n°1', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_2', 'Petit appartement n°2', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_3', 'Petit appartement n°3', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'petit_appartement_4', 'Petit appartement n°4', 'petit', 10, 3, 4),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_1', 'Grand appartement n°1', 'grand', 20, 5, 7),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_2', 'Grand appartement n°2', 'grand', 20, 5, 7),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_3', 'Grand appartement n°3', 'grand', 20, 5, 7),
  ('soviet', 'ville_a', 'logements-novomirsk', 'grand_appartement_4', 'Grand appartement n°4', 'grand', 20, 5, 7)
ON CONFLICT DO NOTHING;

-- 3. Locaux a louer de Starovka.
INSERT INTO public.sovarka_locaux (pays, ville, batiment, piece, label, origine, loyer, plafond) VALUES
  ('soviet', 'ville_a', 'locaux-starovka', 'local_1', 'Local à louer n°1', 'centre', 0, 50),
  ('soviet', 'ville_a', 'locaux-starovka', 'local_2', 'Local à louer n°2', 'centre', 0, 50)
ON CONFLICT DO NOTHING;

-- 4. Quatre parcelles sur le terrain de Starovka.
CREATE OR REPLACE FUNCTION public.sovarka_terrains(p_ville text)
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_ville
    WHEN 'capitale' THEN ARRAY['terrain-a-batir-1','terrain-a-batir-4','terrain-a-batir-5','terrain-a-batir-6','terrain-a-batir-7']
    -- 4 parcelles (Fred, 09/11/2026) : la parcelle n s'ecrit « terrain@pn ».
    WHEN 'ville_a'  THEN ARRAY['terrain-a-batir-3','terrain-a-batir-3@p2','terrain-a-batir-3@p3','terrain-a-batir-3@p4']
    WHEN 'ville_b'  THEN ARRAY['terrain-a-batir-2']
    ELSE ARRAY[]::text[] END $function$;

DO $parcelles$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.sovarka_urbanisme_passe(date)'::regprocedure);
  IF position('sovarka_parcelles_v1' IN d) > 0 THEN RETURN; END IF;
  avant := E'      VALUES (''soviet'', i.ville, i.terrain, ''local_''||k, ''Local commercial n°''||k, ''immeuble'', i.id, public.sovarka_param(''plafond_local_immeuble''))';
  apres := E'      -- sovarka_parcelles_v1 : la parcelle n d''un terrain (« terrain@pn ») range ses locaux dans le terrain, prefixe « pn_ ».\n'
        || E'      VALUES (''soviet'', i.ville, split_part(i.terrain, ''@'', 1),\n'
        || E'              CASE WHEN i.terrain LIKE ''%@%'' THEN split_part(i.terrain, ''@'', 2) || ''_'' ELSE '''' END || ''local_''||k,\n'
        || E'              CASE WHEN i.terrain LIKE ''%@%'' THEN ''Parcelle '' || substr(split_part(i.terrain, ''@'', 2), 2) || '' — local n°'' ELSE ''Local commercial n°'' END || k,\n'
        || E'              ''immeuble'', i.id, public.sovarka_param(''plafond_local_immeuble''))';
  IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'urbanisme : ancrage des locaux introuvable'; END IF;
  d := replace(d, avant, apres);
  avant := E'      VALUES (''soviet'', i.ville, i.terrain, ''logement_''||k, ''Logement n°''||k, ''petit'', public.sovarka_param(''loyer_logement''), 3, 4)';
  apres := E'      VALUES (''soviet'', i.ville, split_part(i.terrain, ''@'', 1),\n'
        || E'              CASE WHEN i.terrain LIKE ''%@%'' THEN split_part(i.terrain, ''@'', 2) || ''_'' ELSE '''' END || ''logement_''||k,\n'
        || E'              CASE WHEN i.terrain LIKE ''%@%'' THEN ''Parcelle '' || substr(split_part(i.terrain, ''@'', 2), 2) || '' — logement n°'' ELSE ''Logement n°'' END || k,\n'
        || E'              ''petit'', public.sovarka_param(''loyer_logement''), 3, 4)';
  IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'urbanisme : ancrage des logements introuvable'; END IF;
  EXECUTE replace(d, avant, apres);
END
$parcelles$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville IN ('ville_a', 'ville_b') AND batiment = 'siege-syndical')
     OR (SELECT count(*) FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville IN ('ville_a', 'ville_b')
           AND batiment IN ('marche', 'armurerie', 'capitaine-sauvage', 'universite', 'logements-novomirsk', 'locaux-starovka',
                            'kolkhoze-spirituel', 'musee-novomirsk', 'cafe-tabac-cheminots-montrouge')) <> 11
     OR EXISTS (SELECT 1 FROM public.rue_sorties_batiments s WHERE s.country = 'soviet' AND s.city IN ('ville_a', 'ville_b')
                  AND NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles r WHERE r.pays = 'soviet' AND r.ville = s.city AND r.batiment = s.building))
     OR (SELECT count(*) FROM public.sovarka_locaux WHERE batiment = 'locaux-starovka') <> 2
     OR cardinality(public.sovarka_terrains('ville_a')) <> 4
     OR position('sovarka_parcelles_v1' IN pg_get_functiondef('public.sovarka_urbanisme_passe(date)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'starovka_krasnov_batiments_socle_incomplet';
  END IF;
END $$;

COMMIT;
