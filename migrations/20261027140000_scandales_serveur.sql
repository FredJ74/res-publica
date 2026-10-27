-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027184213.
-- ============================================================================
-- LE SCANDALE DE LA NUIT : TIRE PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », passe de minuit cliente. checkScandale tirait, dans le navigateur
-- de CHAQUE joueur connecte a minuit, 15 % de chances de publier un scandale au hasard dans la
-- liste SCANDALES_PREDEFINIS : autant de tirages que de joueurs en ligne, aucun les nuits vides,
-- et un joueur pouvait publier ce qu'il voulait sous ce titre. Desormais la passe de nuit tire
-- une fois par pays et par date de Paris (15 %), dans la meme liste, et publie l'annonce.
-- Idempotente (un rejeu la meme nuit ne tire rien de plus). Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.scandales_predefinis (
  id    integer PRIMARY KEY,
  texte text NOT NULL
);
ALTER TABLE public.scandales_predefinis ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.scandales_predefinis FROM anon, authenticated;
INSERT INTO public.scandales_predefinis (id, texte) VALUES
  (1, 'Le Ministre des Finances a été surpris à frauder sa propre déclaration d''impôts. Il invoque ''une erreur de formulaire en triple exemplaire''.'),
  (2, 'Le Premier Ministre a été aperçu au Laboratoire de Prière d''El Estado. Il parle d''un ''voyage diplomatique culturel intensif''.'),
  (3, 'Le Président refuse de signer un décret car il manque le tampon numéro 7. Le pays est paralysé depuis 48 heures.'),
  (4, 'Le Grand Prêtre du Papyrusisme a été surpris sans ses formulaires. Le Tabernacle est en état de choc.'),
  (5, 'Un député s''est endormi pendant le vote d''une loi et a voté Pour et Contre simultanément. La loi est en suspens.'),
  (6, 'Le Commissaire Raoul Toufaud a perdu ses menottes. Il s''est menotté lui-même par erreur en cherchant à les retrouver.'),
  (7, 'Le Ministre de l''Information a censuré son propre communiqué de presse par inadvertance.'),
  (8, 'Un loukoum contaminé sème la panique à Al-Khalija. Le Grand Confiseur Abdul Loukoum est introuvable.'),
  (9, 'Le Camarade Pontife Tractorenko a béni un tracteur privé par erreur. L''hérésie est totale.'),
  (10, 'Le Juge Honoré Cozetoujours a condamné son propre greffier avant d''entendre l''affaire. Il ''assume pleinement''.')
ON CONFLICT (id) DO UPDATE SET texte = EXCLUDED.texte;

CREATE TABLE IF NOT EXISTS public.scandales_tirages (
  pays     text NOT NULL,
  jour     date NOT NULL,
  scandale integer,
  tire_le  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, jour)
);
ALTER TABLE public.scandales_tirages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.scandales_tirages FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.minuit_scandale(p_pays text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_id integer; v_texte text;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_manquant'); END IF;
  IF EXISTS (SELECT 1 FROM public.scandales_tirages WHERE pays = p_pays AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', true, 'deja_tire', true);
  END IF;
  IF random() < 0.15 THEN
    SELECT id, texte INTO v_id, v_texte FROM public.scandales_predefinis ORDER BY random() LIMIT 1;
  END IF;
  INSERT INTO public.scandales_tirages (pays, jour, scandale) VALUES (p_pays, v_jour, v_id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'deja_tire', true); END IF;
  IF v_texte IS NOT NULL THEN
    PERFORM public.annonce_publique_interne(p_pays, '🔴 SCANDALE : ' || v_texte);
  END IF;
  RETURN jsonb_build_object('ok', true, 'scandale', v_id);
END; $function$;
REVOKE ALL ON FUNCTION public.minuit_scandale(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.minuit_scandale(text) TO service_role;
