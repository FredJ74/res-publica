-- Scierie Guy Tarembois (PSM) : l'atelier n'avait aucune ligne batiments_etat (04/11/2026).
--
-- Constat : « Catalogue des produits » répondait « Catalogue indisponible ». Les trois autres
-- usines ont une ligne créée par le cron de minuit (elles ont des chaînes de production) ; la
-- Scierie n'en a pas : sa ligne n'était créée que par l'ancienne écriture du navigateur
-- (sbSetBatimentEtat, fermée au chantier C de septembre). Depuis, catalogue, fabrication
-- (« atelier_introuvable »), achat et vente de matières à la Scierie étaient tous refusés.
--
-- Correctif : créer la ligne avec la dotation de départ décidée par Fred le 25/08/2026
-- (DOTATION_INITIALE_USINE, plateau-justice-economie.js) : caisse 3 000 FR, 150 bois, 20 minerai.
-- Même format que les autres usines (data = chaîne JSON). Ne touche jamais une ligne existante.
INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
VALUES ('republic_ville_a_zone-production', 'republic', 'ville_a', 'zone-production',
        to_jsonb('{"usine":{"caisse":3000,"venteDirecte":{},"stockMatieres":{"bois":150,"minerai":20},"stockProduits":{}}}'::text),
        now())
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.batiments_etat
                 WHERE id = 'republic_ville_a_zone-production'
                   AND public.batiment_etat_lire(data) ? 'usine') THEN
    RAISE EXCEPTION 'scierie_tarembois_atelier: ligne absente ou sans usine';
  END IF;
END $$;
