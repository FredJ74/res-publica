-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029191757.
-- Archivage documentaire seulement ; ne pas rejouer.
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

-- Même livraison : ferme `permis_accelerer` de `terrain_permis_acte` (remplacé par
-- `terrain_permis_corrompre`, 20261029122342) ; l'écran n'y envoie plus le permis.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  IF strpos(v_def, $f$'permis_decider',
                    'permis_accelerer', 'permis_plan_modifier') THEN$f$) = 0 THEN RETURN; END IF;
  -- permis_decider aussi : remplacé par `terrain_permis_decider` (20261029122748).
  v_new := replace(v_def, $a$'permis_decider',
                    'permis_accelerer', 'permis_plan_modifier') THEN$a$, $n$
                    'permis_plan_modifier') THEN$n$);
  EXECUTE v_new;
END $mig$;
