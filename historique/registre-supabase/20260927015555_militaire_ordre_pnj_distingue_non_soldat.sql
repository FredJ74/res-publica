-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927015555
-- Nom original      : militaire_ordre_pnj_distingue_non_soldat
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:55:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 43199a5c123c1a9c8c9913f6503dceb8
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
-- UN PNJ QUI N'EST PAS SOLDAT N'EST PAS UN PNJ INTROUVABLE (27 septembre 2026)
--
-- La recette navigateur a montre le defaut : demander une ration pour un PNJ employe renvoyait
-- `pnj_introuvable`, parce que la fonction ne cherchait que dans pnj_soldats_metier. Le joueur
-- lisait « PNJ introuvable » d'un PNJ qu'il avait sous les yeux. Un refus doit dire vrai : ce
-- PNJ existe, il n'est simplement pas soldat, et nourrir n'est pas un verbe du socle.
CREATE OR REPLACE FUNCTION public.militaire_ordre_pnj(p_pnj_id text, p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; s record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT m.id, m.statut, m.leader_pj, m.famille,
         sm.compagnie_id, sm.section_id, sm.matricule, sm.en_reserve
    INTO s
    FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.id = p_pnj_id;
  IF s.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_introuvable'); END IF;
  IF s.matricule IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_soldat', 'famille', s.famille); END IF;
  IF s.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_inactif', 'statut', s.statut); END IF;
  IF s.en_reserve OR s.section_id IS NULL OR s.compagnie_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_en_reserve'); END IF;
  RETURN public.militaire_ordre_collectif(s.compagnie_id, s.section_id, p_action,
                                          s.leader_pj, ARRAY[s.matricule]);
END; $$;

REVOKE ALL ON FUNCTION public.militaire_ordre_pnj(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_ordre_pnj(text,text) TO authenticated, service_role;