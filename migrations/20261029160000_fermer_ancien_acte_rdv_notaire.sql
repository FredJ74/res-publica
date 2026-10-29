-- =====================================================================================
-- À APPLIQUER JUSTE APRÈS LA LIVRAISON de l'écran qui appelle `terrain_rdv_notaire_accelerer`
-- (branche claude/terrains-immobilier-20261029). NON APPLIQUÉE.
--
-- Ferme l'ancien acte `achat_direct_accelerer` de `terrain_compromis_acte`, par lequel l'écran
-- posait lui-même la date du rendez-vous chez le notaire (voir 20261029095142). Après cette
-- migration, l'acte rend `acte_inconnu` ; le dépôt (`achat_direct_deposer`) reste inchangé.
-- Idempotente.
-- =====================================================================================
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_compromis_acte(text,text,jsonb)'::regprocedure);
  IF strpos(v_def, $f$'achat_direct_deposer', 'achat_direct_accelerer') THEN$f$) = 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$'achat_direct_deposer', 'achat_direct_accelerer') THEN$a$, $n$'achat_direct_deposer') THEN$n$);
  EXECUTE v_new;
END $mig$;
