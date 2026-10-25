-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025204304.
-- ============================================================================
-- BUREAU NATIONAL DE L'EMPLOI : RETRAIT DE LA FORMULE D'AOUT (25 octobre 2026)
-- ============================================================================
-- Fred a remplace la formule d'aout (GAME-DESIGN-BNE.md) : plus d'emplois fictifs, plus
-- d'inscription. Le lot 1 avait vide le catalogue et le registre ; ce retrait supprime ce qui ne
-- sert plus a rien et ne doit plus pouvoir servir :
--   - bne_agir (prendre, reserver, trancher, demissionner) et bne_inscrire ;
--   - les salaires declares des trois emplois et leurs caisses payeuses ;
--   - les couts declares des deux ordres retires (inscription, demission).
-- La colonne demandeur_emploi reste (lue et ecrite par la sauvegarde du personnage, sans effet).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================
DROP FUNCTION IF EXISTS public.bne_agir(text, text, text);
DROP FUNCTION IF EXISTS public.bne_inscrire();
DELETE FROM public.salaires_civils_declares WHERE categorie = 'emploi';
DELETE FROM public.salaires_caisses WHERE poste_id IN ('serveur_luthecia', 'hotelier_montrouge', 'docker_psm');
DELETE FROM public.ordres_couts WHERE fn IN ('sinscrire_demandeur_emploi', 'demissionner_emploi_bne');
