-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926144436
-- Nom original      : socle_pnj_bascule_lecture_mutinerie_camps
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 14:44:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : dd7b65c678aa2591d0aa1aeef9d0b965
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
-- BASCULE DE LECTURE : mutinerie_camps_presents lit le socle. 26 septembre 2026.
--
-- SEMANTIQUE DE L'ANCIENNE LECTURE, conservee a l'identique :
--   « Quels camps sont representes, physiquement, dans cette piece ? »
--   Deux sources unies :
--     1) les SOLDATS PNJ du pays, presents, VIVANTS (pa > 0), dont le camp vaut
--        coalesce(mutin, pays de la compagnie) ;
--     2) les SOLDATS PJ en service actif, presents, vivants, dont le camp vaut
--        coalesce(mutinerie_camp_de(nom), pays).
--
-- FILTRES METIER CONSERVES, un par un :
--   * SECTIONS SEULEMENT -- l'ancienne lecture ne balayait jamais data->'reserve'. Le socle
--     contient les 96 : sans `en_reserve = false`, les 72 reservistes de la caserne
--     ajouteraient leur camp des qu'un joueur s'y trouve. C'est le piege deja rencontre.
--   * NOT pj -- sans objet dans le socle, qui ne contient QUE des PNJ (la copie et le miroir
--     sautent explicitement les entrees pj:true). La garantie est donc structurelle, et la
--     branche PJ reste traitee separement, inchangee.
--   * pa > 0 -- un mort ne compte pas. Conserve tel quel.
--   * presence : stationne a la position exacte OU accompagnant un chef qui y est. C'est
--     precisement ce que pnj_position_effective resout en une fois.
--   * camp = coalesce(mutin, pays) -- d'ou l'ajout de mutin a la table metier.

CREATE OR REPLACE FUNCTION public.mutinerie_camps_presents(
  p_pays text, p_ville text, p_bat text, p_piece text)
RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT coalesce(array_agg(DISTINCT t.camp), '{}'::text[]) FROM (
    SELECT coalesce(sm.mutin, m.pays) AS camp
      FROM public.pnj_membres m
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
     WHERE m.famille = 'soldat'
       AND m.statut  = 'actif'
       AND sm.en_reserve = false
       AND m.pays = p_pays
       AND coalesce(m.pa, 0) > 0
       AND pe.ville = p_ville AND pe.building_id = p_bat AND pe.room_id = p_piece
    UNION ALL
    SELECT coalesce(public.mutinerie_camp_de(pd.name), pd.country)
      FROM public.personnages_donnees pd
      JOIN public.services_militaires sm2 ON sm2.personnage = pd.name AND sm2.fin_ts IS NULL
     WHERE pd.country = p_pays AND pd.current_city = p_ville
       AND pd.current_building = p_bat AND pd.current_room = p_piece
       AND coalesce(pd.pa, 0) > 0
  ) t;
$function$;