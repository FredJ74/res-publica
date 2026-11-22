-- LOT DE KRASNOV, POINT 3 : EAU (GAME-DESIGN-KRASNOV-LOT-20261120.md ; étape I de la mission du 22/11/2026, nuit).
-- « Une fontaine par ville sur une vue existante, à Krasnov sur la place de l'Ours. » La fontaine de Krasnov existe
-- (krasnov-fontaine-ours, migrations 20261121090000 et 20261121170000). On ajoute une fontaine sur la place principale
-- de chacune des cinq autres villes. Mêmes règles partout (point_eau_etat / point_eau_puiser, inchangées) : eau gratuite,
-- 1 PA par puisage, 10 bouteilles par tranche de 6 h. L'ordre vert « Puiser de l'eau » apparaît seul sur ces vues
-- (le navigateur lit climat_points_eau_lister) ; la consigne de canicule cite la fontaine de la ville.
-- Images attendues (emplacement prêt, la fenêtre s'en passe tant qu'elles manquent) : images/fontaines/<id>.webp.
-- Vues choisies par Claude (à faire valider par Fred) : la place de la mairie ou la place principale de chaque ville.
BEGIN;
INSERT INTO public.climat_points_eau (id, pays, ville, noeud, nom, image, actif) VALUES
  ('luthecia-fontaine-hotel-de-ville', 'republic', 'capitale', 'luthecia-hotel-de-ville',
     'la fontaine du parvis de l''Hôtel de Ville, à Luthécia', 'images/fontaines/luthecia-fontaine-hotel-de-ville.webp', true),
  ('montrouge-fontaine-place-du-rail', 'republic', 'ville_b', 'montrouge-vue-7',
     'la fontaine de la place du Rail, à Montrouge', 'images/fontaines/montrouge-fontaine-place-du-rail.webp', true),
  ('psm-fontaine-place-armes', 'republic', 'ville_a', 'psm-hotel-mairie-place',
     'la fontaine de la place d''Armes, à Port-Sainte-Marie', 'images/fontaines/psm-fontaine-place-armes.webp', true),
  ('novomirsk-fontaine-place-peuple', 'soviet', 'capitale', 'novomirsk-vue-1',
     'la fontaine de la place du Peuple, à Novomirsk', 'images/fontaines/novomirsk-fontaine-place-peuple.webp', true),
  ('starovka-fontaine-mairie', 'soviet', 'ville_a', 'starovka-rue-mairie-marche',
     'la fontaine de la place de la mairie, à Starovka', 'images/fontaines/starovka-fontaine-mairie.webp', true)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
  -- Une fontaine active par ville, et chacune sur une vue de rue qui existe.
  IF EXISTS (SELECT pays, ville FROM public.climat_points_eau WHERE actif GROUP BY pays, ville HAVING count(*) > 1)
     OR (SELECT count(DISTINCT (pays, ville)) FROM public.climat_points_eau WHERE actif) < 6
     OR EXISTS (SELECT 1 FROM public.climat_points_eau p WHERE p.actif AND NOT EXISTS (
          SELECT 1 FROM public.rue_noeuds_serveur n WHERE n.country = p.pays AND n.city = p.ville AND n.noeud = p.noeud)) THEN
    RAISE EXCEPTION 'points_eau_une_fontaine_par_ville : contrôle en échec';
  END IF;
END $$;
COMMIT;
