-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030192157.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- RÉGULARISATION : 150 000 FR DE JEAN JAAJ PERDUS AU RETRAIT HELVETIA (30/10/2026, Claude).
-- NON APPLIQUÉE. Décision de Fred (30/10, « solution 1 ») : les 150 000 FR lui sont rendus en
-- liquide, le prêt Helvetia reste dû.
--
-- Faits (fiche_hausses_observees) : n° 1370, 30/10 18:57 UTC, prêt Helvetia de 150 000 FR, ajout à
-- la fortune (arg) annulé par la garde de la vue ; n° 1371, 19:00 UTC, retrait de 150 000 FR en
-- liquide, compte Helvetia débité (160 000 -> 10 000) mais ajout aux espèces annulé. Cause et
-- correctif : 20261030210000 et 20261030211000.
-- Remise en état : liquide +150 000 et arg +150 000, ce que les deux opérations devaient produire.
--
-- Une seule fois : registre `regularisations_fiche` (clé = référence), réutilisable pour toute
-- correction de fiche décidée par le game designer, lisible par le serveur seulement.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS public.regularisations_fiche (
  reference   text PRIMARY KEY,
  personnage  text NOT NULL,
  liquide     numeric NOT NULL DEFAULT 0,
  arg         numeric NOT NULL DEFAULT 0,
  motif       text NOT NULL,
  decide_par  text NOT NULL,
  applique_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.regularisations_fiche ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.regularisations_fiche FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_ref text := 'helvetia-retrait-jaaj-20261030';
  v_inseree text;
BEGIN
  -- Les faits doivent être ceux relevés : sinon, on n'invente rien.
  IF NOT EXISTS (SELECT 1 FROM public.fiche_hausses_observees
                  WHERE id = 1371 AND personnage = 'Jean Jaaj' AND colonne = 'liquide' AND delta = 150000)
     OR NOT EXISTS (SELECT 1 FROM public.fiche_hausses_observees
                  WHERE id = 1370 AND personnage = 'Jean Jaaj' AND colonne = 'arg' AND delta = 150000) THEN
    RAISE EXCEPTION 'régularisation Jaaj : traces 1370/1371 introuvables ou différentes';
  END IF;

  INSERT INTO public.regularisations_fiche (reference, personnage, liquide, arg, motif, decide_par)
  VALUES (v_ref, 'Jean Jaaj', 150000, 150000,
          'Prêt Helvetia retiré en liquide le 30/10 : espèces jamais créditées (défaut corrigé par 20261030210000). Prêt maintenu.',
          'Fred (game designer), 30/10/2026')
  ON CONFLICT (reference) DO NOTHING
  RETURNING reference INTO v_inseree;

  IF v_inseree IS NULL THEN RETURN; END IF;  -- déjà appliquée

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide, 0) + 150000,
         arg     = coalesce(arg, 0) + 150000
   WHERE name = 'Jean Jaaj';
  IF NOT FOUND THEN RAISE EXCEPTION 'régularisation Jaaj : personnage introuvable'; END IF;

  PERFORM public.mail_systeme_poser_interne('Banque Helvetia', 'Jean Jaaj', 'Régularisation de votre retrait',
    'Votre retrait de 150 000 FR du 30 octobre n''avait pas été remis en espèces à la suite d''une erreur '
    || 'de nos services. La somme vient de vous être versée en liquide. Votre prêt reste en vigueur '
    || 'aux conditions signées.');
END $migration$;
