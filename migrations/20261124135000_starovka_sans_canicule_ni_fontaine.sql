-- NON APPLIQUÉE — mission « Purge » du 24/11/2026, bloc D (climat), point D.5 (consigne de Fred) :
-- « Starovka est exclue des canicules. Pas de fontaine à Starovka : retire-la avec redirections, et ajoute un banc. »
-- Constat (base lue le 24/11) : aucune canicule n'est réglée en Sovarka (climat_parametres n'a pas de ligne canicule/soviet),
-- donc aucune canicule n'a jamais été tirée à Starovka ; l'exclusion est désormais écrite, pour qu'un réglage futur ou une
-- création MJ ne puisse pas la contourner. La fontaine starovka-fontaine-mairie (migration 20261122161000, sans image) est active.
-- • climat_villes_exclues : ligne canicule / soviet / ville_a (Starovka). La table est créée par 20261124132000 (D.2) ; elle est
--   recréée ici à l'identique si besoin (IF NOT EXISTS) pour que cette migration reste autonome.
-- • Fontaine de Starovka désactivée (actif = faux). Redirections : la liste du navigateur (climat_points_eau_lister) ne la
--   renvoie plus, l'ordre « Puiser de l'eau » disparaît de la vue starovka-rue-mairie-marche, point_eau_etat y répond
--   « pas_de_point_eau » (texte du navigateur : Starovka n'a pas de fontaine) ; la consigne de canicule ne la cite plus.
--   Rien d'autre ne la référence (recherche dans le code, l'aide, les catalogues, les quêtes et les bancs).
-- • Canicules planifiées à Starovka (aucune le 24/11) : annulées.
-- Rejouable. Aucune fonction commune, aucun objet du goulag.
BEGIN;
CREATE TABLE IF NOT EXISTS public.climat_villes_exclues (
  type text NOT NULL, pays text NOT NULL, ville text NOT NULL, raison text,
  PRIMARY KEY (type, pays, ville));
ALTER TABLE public.climat_villes_exclues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_villes_exclues FROM PUBLIC, anon, authenticated;
INSERT INTO public.climat_villes_exclues (type, pays, ville, raison) VALUES
  ('canicule', 'soviet', 'ville_a', 'Fred, 24/11/2026 (D.5) : Starovka est exclue des canicules')
ON CONFLICT DO NOTHING;

UPDATE public.climat_evenements SET annule = true
 WHERE type = 'canicule' AND pays = 'soviet' AND ville = 'ville_a' AND NOT annule AND debut > now();

UPDATE public.climat_points_eau SET actif = false WHERE id = 'starovka-fontaine-mairie' AND actif;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.climat_points_eau WHERE actif AND pays = 'soviet' AND ville = 'ville_a')
     OR EXISTS (SELECT 1 FROM public.climat_points_eau p WHERE p.remplace_par IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.climat_points_eau q WHERE q.id = p.remplace_par AND q.actif)) THEN
    RAISE EXCEPTION 'starovka_sans_canicule_ni_fontaine : contrôle en échec';
  END IF;
END $$;
COMMIT;
