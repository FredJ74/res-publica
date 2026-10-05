-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927004758
-- Nom original      : socle_pnj_membres_ici_seulement_les_miens
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 00:47:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fa0a9d687c0a06ec58460283fb2add6f
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
-- pnj_membres_ici NE REND QUE LES PNJ DE L'APPELANT (27 septembre 2026)
--
-- La version precedente rendait aussi une « presence nue » des PNJ d'autrui. C'etait deja bien
-- mieux que la fuite d'origine, mais encore trop : pour un soldat, `nom` EST son matricule, et
-- l'effectif d'une section restait deductible par simple comptage. Aucun usage ne le
-- justifiait -- la popup ne liste que les PNJ du joueur, et la presence d'autrui est rendue par
-- les lectures METIER (militaire_detachement_ici, militaire_observer), qui savent degrader
-- l'information via militaire_degrader.
--
-- REGLE FINALE : une primitive GENERIQUE ne doit pas arbitrer ce qu'un joueur apprend des PNJ
-- d'autrui. Elle ne repond que « voici les tiens, ici ». Le brouillard de guerre reste metier.
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
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  RETURN jsonb_build_object('ok', true, 'membres', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'id', m.id, 'nom', m.nom, 'famille', m.famille, 'pa', m.pa,
             'liquide', m.liquide, 'statut', m.statut,
             'leader_pj', m.leader_pj, 'leader_pnj_id', m.leader_pnj_id,
             'porte', pe.porte, 'mien', true) ORDER BY m.nom)
      FROM public.pnj_membres m
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.statut = 'actif'
       AND m.pays = p_pays
       AND COALESCE(sm.en_reserve, false) = false
       -- LES MIENS SEULEMENT : ceux que je mene, ou dont je detiens l'autorite.
       AND (m.leader_pj = v_moi OR v_moi = public.pnj_administrateur(m.id))
       AND pe.ville IS NOT DISTINCT FROM p_ville
       AND pe.building_id IS NOT DISTINCT FROM p_building
       AND pe.room_id IS NOT DISTINCT FROM p_room
       AND (p_rue_noeud IS NULL OR pe.rue_noeud_id IS NOT DISTINCT FROM p_rue_noeud)
  ), '[]'::jsonb));
END; $fn$;

REVOKE ALL ON FUNCTION public.pnj_membres_ici(text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_membres_ici(text,text,text,text,text) TO authenticated, service_role;