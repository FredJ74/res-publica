-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture) — mission « Purge » du 24/11/2026, bloc D (climat), point D.6 (consigne de Fred) :
-- « Bouteille d'eau à 4 PSK l'unité dans toutes les boutiques « Équipements contre les intempéries » de Sovarka. »
-- Constat (base lue le 24/11) : trois boutiques climat en Sovarka, aucune ne vendait d'eau : usine pharmaceutique de Novomirsk
-- (Pharmanov, sels), garage de Novomirsk (groupe électrogène, bidons), station-service de Krasnov (groupe électrogène).
-- Starovka n'a aucune boutique climat (rien créé : hors consigne). L'objet bouteille d'eau existe (climat_objet_interne
-- 'bouteille_eau', le même que celui des fontaines et des marchés de Républia à 3 FR).
-- • Réglage MJ aliments_parametres.prix_bouteille_eau_sovarka = 4 ; climat_prix_pays_interne le lit pour la Sovarka
--   (marque bouteille_eau_sovarka_v1) — la Républia garde prix_bouteille_eau (3 FR).
-- • 'bouteille_eau' ajoutée à l'offre de chaque boutique climat de Sovarka (climat_boutiques.cles), en tête de liste.
-- Rejouable (ON CONFLICT, garde sur la présence). Aucune fonction commune, aucun objet du goulag.
BEGIN;
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('prix_bouteille_eau_sovarka', 4) ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_prix_pays_interne(p_cle text, p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_cle = 'sels_rehydratation' THEN public.pharmacie_prix_pays_interne('coup_de_chaleur', p_pays)::numeric
              WHEN p_cle = 'bouteille_eau' AND p_pays = 'soviet' THEN public.aliments_param_interne('prix_bouteille_eau_sovarka', 4) /* bouteille_eau_sovarka_v1 */
              ELSE public.climat_prix_interne(p_cle) END;
$$;
REVOKE ALL ON FUNCTION public.climat_prix_pays_interne(text, text) FROM PUBLIC, anon, authenticated;

UPDATE public.climat_boutiques SET cles = ARRAY['bouteille_eau'] || cles WHERE pays = 'soviet' AND NOT ('bouteille_eau' = ANY (cles));

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.climat_boutiques WHERE pays = 'soviet' AND NOT ('bouteille_eau' = ANY (cles)))
     OR public.climat_prix_pays_interne('bouteille_eau', 'soviet') IS DISTINCT FROM public.aliments_param_interne('prix_bouteille_eau_sovarka', 4) THEN
    RAISE EXCEPTION 'bouteille_eau_sovarka : contrôle en échec';
  END IF;
END $$;
COMMIT;
