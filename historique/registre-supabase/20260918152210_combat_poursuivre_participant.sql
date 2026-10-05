-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918152210
-- Nom original      : combat_poursuivre_participant
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 15:22:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8eb640fdf15d33f853e57e046a01fcd9
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =========================================================================================
-- FAIRE AVANCER UNE BATAILLE SANS LE CHEF ADVERSE (19 septembre 2026)
-- =========================================================================================
-- `militaire_bataille_decider` est reserve au LEADER d'un camp : c'est lui qui engage sa decision.
-- Mais une bataille ne doit jamais s'arreter parce que le chef d'en face n'est pas connecte. Tout
-- participant ENGAGE peut donc pousser le round suivant ; la doctrine du camp absent repond a sa
-- place, immediatement, sans attendre aucun navigateur.
--
-- Consequence voulue : l'attaquant, qui est connecte par construction puisqu'il vient d'engager,
-- peut derouler toute la bataille seul contre un camp qui n'a personne devant l'ecran.
CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.militaire_bataille_mon_camp(p_bataille_id, v_moi) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_engage');
  END IF;
  RETURN public.militaire_bataille_avancer(p_bataille_id);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_bataille_poursuivre(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_poursuivre(bigint) TO authenticated;