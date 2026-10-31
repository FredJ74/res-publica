-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024123600_terrains_referentiel_acquisition.sql ; aucun changement de règle.
-- GENERE par outils/generateurs/generer_terrains_occupation.cjs --sql ; jamais de donnees joueur.
BEGIN;
CREATE TABLE IF NOT EXISTS public.terrains_referentiel (
 pays text NOT NULL,ville text NOT NULL,batiment text NOT NULL,surface numeric,prix_achat numeric,
 PRIMARY KEY(pays,ville,batiment),CHECK(surface IS NULL OR surface>0),
 CHECK(prix_achat IS NULL OR prix_achat>=0 AND prix_achat=trunc(prix_achat))
);
ALTER TABLE public.terrains_referentiel ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrains_referentiel FROM PUBLIC,anon,authenticated;
INSERT INTO public.terrains_referentiel(pays,ville,batiment,surface,prix_achat) VALUES
('khalija','capitale','terrain-a-batir-1',2150,25800),
('khalija','capitale','terrain-a-batir-4',1850,22200),
('khalija','capitale','terrain-a-batir-5',2750,33000),
('khalija','capitale','terrain-a-batir-6',NULL,25000),
('khalija','capitale','terrain-a-batir-7',NULL,25000),
('khalija','ville_a','terrain-a-batir-3',2300,27600),
('khalija','ville_b','terrain-a-batir-2',2300,27600),
('narco','capitale','terrain-a-batir-1',2150,25800),
('narco','capitale','terrain-a-batir-4',1850,22200),
('narco','capitale','terrain-a-batir-5',2750,33000),
('narco','capitale','terrain-a-batir-6',NULL,25000),
('narco','capitale','terrain-a-batir-7',NULL,25000),
('narco','ville_a','terrain-a-batir-3',2300,27600),
('narco','ville_b','terrain-a-batir-2',2300,27600),
('republic','capitale','terrain-a-batir-1',2150,25800),
('republic','capitale','terrain-a-batir-2',2300,27600),
('republic','capitale','terrain-a-batir-3',2300,27600),
('republic','capitale','terrain-a-batir-4',1850,22200),
('republic','capitale','terrain-a-batir-5',2750,33000),
('republic','ville_a','terrain-a-batir-10',NULL,3500),
('republic','ville_a','terrain-a-batir-11',NULL,3500),
('republic','ville_a','terrain-a-batir-8',NULL,3500),
('republic','ville_a','terrain-a-batir-9',NULL,3500),
('republic','ville_b','terrain-a-batir-6',NULL,25000),
('republic','ville_b','terrain-a-batir-montrouge-12',3000,36000),
('republic','ville_b','terrain-a-batir-montrouge-3',1500,18000),
('republic','ville_b','terrain-a-batir-montrouge-7',1800,21600),
('republic','ville_b','terrain-a-batir-montrouge-8',2200,26400),
('republic','ville_b','terrain-a-batir-montrouge-9',2500,30000),
('soviet','capitale','terrain-a-batir-1',2150,25800),
('soviet','capitale','terrain-a-batir-4',1850,22200),
('soviet','capitale','terrain-a-batir-5',2750,33000),
('soviet','capitale','terrain-a-batir-6',NULL,25000),
('soviet','capitale','terrain-a-batir-7',NULL,25000),
('soviet','ville_a','terrain-a-batir-3',2300,27600),
('soviet','ville_b','terrain-a-batir-2',2300,27600)
ON CONFLICT(pays,ville,batiment) DO NOTHING;
DO $verification$ BEGIN
 IF EXISTS(WITH attendu(pays,ville,batiment,surface,prix_achat) AS (VALUES ('khalija','capitale','terrain-a-batir-1',2150,25800),
('khalija','capitale','terrain-a-batir-4',1850,22200),
('khalija','capitale','terrain-a-batir-5',2750,33000),
('khalija','capitale','terrain-a-batir-6',NULL,25000),
('khalija','capitale','terrain-a-batir-7',NULL,25000),
('khalija','ville_a','terrain-a-batir-3',2300,27600),
('khalija','ville_b','terrain-a-batir-2',2300,27600),
('narco','capitale','terrain-a-batir-1',2150,25800),
('narco','capitale','terrain-a-batir-4',1850,22200),
('narco','capitale','terrain-a-batir-5',2750,33000),
('narco','capitale','terrain-a-batir-6',NULL,25000),
('narco','capitale','terrain-a-batir-7',NULL,25000),
('narco','ville_a','terrain-a-batir-3',2300,27600),
('narco','ville_b','terrain-a-batir-2',2300,27600),
('republic','capitale','terrain-a-batir-1',2150,25800),
('republic','capitale','terrain-a-batir-2',2300,27600),
('republic','capitale','terrain-a-batir-3',2300,27600),
('republic','capitale','terrain-a-batir-4',1850,22200),
('republic','capitale','terrain-a-batir-5',2750,33000),
('republic','ville_a','terrain-a-batir-10',NULL,3500),
('republic','ville_a','terrain-a-batir-11',NULL,3500),
('republic','ville_a','terrain-a-batir-8',NULL,3500),
('republic','ville_a','terrain-a-batir-9',NULL,3500),
('republic','ville_b','terrain-a-batir-6',NULL,25000),
('republic','ville_b','terrain-a-batir-montrouge-12',3000,36000),
('republic','ville_b','terrain-a-batir-montrouge-3',1500,18000),
('republic','ville_b','terrain-a-batir-montrouge-7',1800,21600),
('republic','ville_b','terrain-a-batir-montrouge-8',2200,26400),
('republic','ville_b','terrain-a-batir-montrouge-9',2500,30000),
('soviet','capitale','terrain-a-batir-1',2150,25800),
('soviet','capitale','terrain-a-batir-4',1850,22200),
('soviet','capitale','terrain-a-batir-5',2750,33000),
('soviet','capitale','terrain-a-batir-6',NULL,25000),
('soviet','capitale','terrain-a-batir-7',NULL,25000),
('soviet','ville_a','terrain-a-batir-3',2300,27600),
('soviet','ville_b','terrain-a-batir-2',2300,27600))
 SELECT 1 FROM attendu a LEFT JOIN public.terrains_referentiel r USING(pays,ville,batiment)
 WHERE r.batiment IS NULL OR r.surface IS DISTINCT FROM a.surface OR r.prix_achat IS DISTINCT FROM a.prix_achat)
 THEN RAISE EXCEPTION 'catalogue_terrain_divergent';END IF;
END;$verification$;
COMMIT;
