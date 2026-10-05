-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927004102
-- Nom original      : socle_pnj_fermer_fuites_ordre_de_bataille
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 00:41:02 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ee5f5bd4a4f2571870ffa7ac804bdfa2
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
-- FERMETURE DES FUITES D'ORDRE DE BATAILLE (27 septembre 2026)
--
-- CE QUI S'EST PASSE, et c'est ma regression. La migration du 21 septembre avait ferme la
-- lecture publique de compagnies_militaires : « L'ORDRE DE BATAILLE N'EST PLUS PUBLIC », parce
-- qu'un visiteur lisait les sections, matricules, positions, armes et formations des quatre
-- empires, ce qui court-circuitait reconnaissance, camouflage et jumelles.
-- Mes propres fonctions du socle l'ont REOUVERTE par la porte de service. Prouve par appel
-- REST reel avec une session qui n'a meme pas de personnage :
--   pnj_comparer_soldats    -> ordre de bataille complet (96/96, matricules dans les details)
--   pnj_position_effective  -> position exacte d'un soldat nomme, et s'il suit un chef
--   pnj_membres_ici         -> 96 PNJ avec id, PA, argent, leader, proprietaire, SANS
--                              degradation pour l'etranger et SANS filtre reserve
-- La popup ne montrait 24 que par un filtre CLIENT -- ce que la doctrine de ce projet rejette :
-- une interface qui cache n'est pas une preuve de securite.
--
-- CAUSE TECHNIQUE : Supabase applique un ALTER DEFAULT PRIVILEGES qui accorde EXECUTE a
-- `authenticated` sur toute fonction nouvellement creee dans public. Mes REVOKE ne visaient que
-- PUBLIC et anon. Il faut donc revoquer NOMMEMENT a authenticated.

-- 1) Les fonctions purement techniques : reservees au serveur.
REVOKE ALL ON FUNCTION public.pnj_comparer_soldats(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_position_effective(text)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_titulaire_du_poste(text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_administrateur(text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_peut_commander(text,text)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_axe_partage_verrouille(text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_miroir_compagnie_trg()        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pas_de_sous_hierarchie()      FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_comparer_soldats(text)        TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_position_effective(text)      TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_titulaire_du_poste(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_administrateur(text)          TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_peut_commander(text,text)     TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_axe_partage_verrouille(text[]) TO service_role;

-- 2) pnj_membres_ici : ne rend plus QUE ce que l'appelant a le droit de voir.
--
-- L'ancienne version rendait tout PNJ present, toutes familles, tous pays, avec ses PA, son
-- argent, son proprietaire. Elle remplacait des lectures qui, elles, degradaient l'information.
--
-- LA REGLE POSEE, qui reprend la semantique historique sans rien inventer :
--   * un PNJ que l'appelant MENE ou ADMINISTRE  -> detail complet (c'est le sien) ;
--   * tout autre PNJ de SON pays               -> presence seulement, sans PA ni argent ni id ;
--   * un PNJ d'un pays ETRANGER                -> rien du tout par cette primitive. La
--     presence ennemie reste du ressort des lectures metier (militaire_detachement_ici,
--     militaire_observer), qui appliquent militaire_degrader. Une primitive generique n'a pas
--     a arbitrer le brouillard de guerre.
--   * les soldats en RESERVE ne sont jamais exposes : aucune lecture historique ne les montrait.
CREATE OR REPLACE FUNCTION public.pnj_membres_ici(
  p_pays text, p_ville text, p_building text, p_room text, p_rue_noeud text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_moi text; v_mon_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_mon_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_mon_pays IS DISTINCT FROM p_pays THEN
    -- On ne renseigne pas un joueur sur un autre pays par une primitive generique.
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  RETURN jsonb_build_object('ok', true, 'membres', COALESCE((
    SELECT jsonb_agg(CASE WHEN a.mien THEN
             jsonb_build_object('id', a.id, 'nom', a.nom, 'famille', a.famille,
               'pa', a.pa, 'liquide', a.liquide, 'statut', a.statut,
               'leader_pj', a.leader_pj, 'leader_pnj_id', a.leader_pnj_id,
               'porte', a.porte, 'mien', true)
           ELSE
             -- Presence nue : ni id, ni PA, ni argent, ni proprietaire.
             jsonb_build_object('nom', a.nom, 'famille', a.famille, 'mien', false)
           END ORDER BY a.mien DESC, a.nom)
      FROM (
        SELECT m.id, m.nom, m.famille, m.pa, m.liquide, m.statut,
               m.leader_pj, m.leader_pnj_id, pe.porte,
               (m.leader_pj = v_moi
                OR v_moi = public.pnj_administrateur(m.id)) AS mien
          FROM public.pnj_membres m
          JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
          LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
         WHERE m.statut = 'actif'
           AND m.pays = p_pays
           AND COALESCE(sm.en_reserve, false) = false   -- la reserve n'est jamais exposee
           AND pe.ville IS NOT DISTINCT FROM p_ville
           AND pe.building_id IS NOT DISTINCT FROM p_building
           AND pe.room_id IS NOT DISTINCT FROM p_room
           AND (p_rue_noeud IS NULL OR pe.rue_noeud_id IS NOT DISTINCT FROM p_rue_noeud)
      ) a), '[]'::jsonb));
END; $fn$;

REVOKE ALL ON FUNCTION public.pnj_membres_ici(text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_membres_ici(text,text,text,text,text) TO authenticated, service_role;