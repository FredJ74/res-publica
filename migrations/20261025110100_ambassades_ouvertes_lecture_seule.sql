-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025210208.
-- ============================================================================
-- AMBASSADES : LA TABLE N'EST PLUS ECRITE PAR LE NAVIGATEUR (25/10/2026, audit R5 et R12)
-- ============================================================================
-- Ouvrir, nommer, demettre et expulser passent desormais par ambassade_ouvrir, ambassade_nommer,
-- ambassade_demettre et ambassade_expulser (SECURITY DEFINER), la fin d'expulsion par la passe de
-- nuit (service_role). Les droits d'ecriture directe des joueurs n'ont plus d'appelant ; les
-- garder laissait le ministre du pays hote reecrire la ligne d'une ambassade etrangere, nom de
-- l'ambassadeur compris (R12). La lecture reste ouverte. Idempotente. Aucun acte de joueur.
-- ============================================================================
REVOKE INSERT, UPDATE, DELETE ON public.ambassades_ouvertes FROM anon, authenticated;
DROP POLICY IF EXISTS "ambassade geree par l empire ou par l hote" ON public.ambassades_ouvertes;
DROP POLICY IF EXISTS "ambassade ouverte par les affaires etrangeres" ON public.ambassades_ouvertes;
