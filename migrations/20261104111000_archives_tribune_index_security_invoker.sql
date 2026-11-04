-- Reprise de la PR #76 (04/11/2026) : la vue des archives de presse respecte les droits du demandeur.
-- La table source journal_editions est en lecture publique (politique using=true) : aucun changement
-- visible ; banc annulé joué avant (anon voit 52 éditions avant et après). Corrige l'alerte Advisor.
ALTER VIEW public.archives_tribune_index SET (security_invoker = true);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.archives_tribune_index'::regclass
                 AND 'security_invoker=true' = ANY(reloptions)) THEN
    RAISE EXCEPTION 'archives_tribune_index: security_invoker absent'; END IF;
END $$;
