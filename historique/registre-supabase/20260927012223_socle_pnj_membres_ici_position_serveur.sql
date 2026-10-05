-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927012223
-- Nom original      : socle_pnj_membres_ici_position_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:22:23 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1437c34c37c5b428fc18d7913c38a599
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
-- pnj_membres_ici : LA POSITION VIENT DU SERVEUR (27 septembre 2026)
--
-- CE QUI N'ALLAIT PAS. La fonction verifiait bien le PAYS contre le serveur, mais filtrait
-- ville/batiment/piece sur les coordonnees FOURNIES PAR LE CLIENT. Deux consequences :
--
--   1) Le client redevenait autorite sur la position, ce que le pilier position a explicitement
--      banni. Un cache en retard listait les PNJ d'un lieu ou le joueur n'etait plus.
--   2) Surtout, la liste et les actions ne disaient plus la meme chose. Depuis que consulter,
--      donner et retirer exigent la co-presence physique (lue, elle, sur le serveur), le popup
--      pouvait afficher un PNJ dont chaque bouton repondait ensuite `pas_co_presents`.
--
-- L'INVARIANT POSE ICI : listé equivaut a actionnable. On reutilise donc exactement le meme
-- predicat que les verbes -- pnj_co_present -- au lieu d'une seconde comparaison ecrite a la
-- main. Deux comparaisons de position tenues pour equivalentes finissent toujours par divergier.
--
-- Les parametres de position RESTENT dans la signature : le client les envoie encore, et casser
-- l'appel n'apporterait rien. Ils ne sont plus que DECLARATIFS, et la reponse renvoie la
-- position reellement employee pour que le client puisse constater un desaccord.
CREATE OR REPLACE FUNCTION public.pnj_membres_ici(
  p_pays text, p_ville text, p_building text, p_room text, p_rue_noeud text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS DISTINCT FROM p_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  RETURN jsonb_build_object('ok', true,
    -- La position employee, pour que le client voie son propre retard s'il y en a un.
    'position_serveur', jsonb_build_object('ville', a.current_city,
      'building_id', a.current_building, 'room_id', a.current_room),
    'membres', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'id', m.id, 'nom', m.nom, 'famille', m.famille, 'pa', m.pa,
             'liquide', m.liquide, 'statut', m.statut,
             'leader_pj', m.leader_pj, 'leader_pnj_id', m.leader_pnj_id,
             'porte', pe.porte, 'mien', true) ORDER BY m.nom)
      FROM public.pnj_membres m
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.statut = 'actif'
       AND m.pays = a.country
       AND COALESCE(sm.en_reserve, false) = false
       -- LES MIENS SEULEMENT : ceux que je mene, ou dont je detiens l'autorite.
       AND (m.leader_pj = v_moi OR public.pnj_peut_administrer(v_moi, m.id))
       -- LA MEME CO-PRESENCE QUE LES VERBES, pas une seconde ecriture du meme test.
       AND public.pnj_co_present(v_moi, m.id)
  ), '[]'::jsonb));
END; $$;