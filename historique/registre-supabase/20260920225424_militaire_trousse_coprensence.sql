-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225424
-- Nom original      : militaire_trousse_coprensence
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:54:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4dbbf43e7148499b278e66b6e98215b5
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
-- =====================================================================
-- TROUSSE DE PREMIERS SECOURS : LE SOIGNANT DOIT ETRE LA (21 septembre 2026)
-- =====================================================================
-- militaire_trousse_utiliser(p_cible) n'imposait AUCUNE proximite : p_cible
-- pouvait designer n'importe quel personnage, ou qu'il soit dans le monde. On
-- pouvait donc rendre 6 PA a un allie situe sur un autre continent, depuis un
-- appel direct a la RPC, sans jamais le rencontrer.
--
-- CE N'EST PAS UN ARBITRAGE DE GAME DESIGN, C'EST UN CONSTAT. Tout l'existant
-- decrit un soin PHYSIQUE DE TERRAIN : la trousse est fabriquee a l'infirmerie
-- de la caserne, elle est a usage unique, son efficacite depend du Secourisme DU
-- SOIGNANT -- et l'ecran de soin (plateau-personnage.js, ouvrirSoinTrousse) ne
-- propose QUE les personnes presentes dans la piece, jusqu'a afficher « Personne
-- d'autre n'est present ici » quand on y est seul. Le serveur ne faisait que ne
-- pas verifier ce que le client tenait deja pour acquis.
--
-- MOTIF REPRIS DE impact_deposer : pays + ville + batiment + piece identiques.
-- Le soin sur SOI-MEME reste evidemment libre.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.militaire_trousse_utiliser(p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max_pj constant integer := 30;
  v_moi text; v_inv jsonb; v_pos integer; v_sec numeric; v_gain integer;
  v_cible text; v_pa_avant integer; v_pa_apres integer;
  m record; c record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := coalesce(nullif(btrim(coalesce(p_cible,'')), ''), v_moi);

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END,
         coalesce((competences_militaires->>'secourisme')::numeric, 0)
    INTO v_inv, v_sec FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- CO-PRESENCE. On soigne qui l'on touche : meme pays, meme ville, meme batiment,
  -- meme piece. Verifiee AVANT toute ecriture, pour qu'un refus ne consomme pas la
  -- trousse.
  IF v_cible <> v_moi THEN
    SELECT country, current_city, current_building, current_room INTO m
      FROM public.personnages_donnees WHERE name = v_moi;
    SELECT name, country, current_city, current_building, current_room INTO c
      FROM public.personnages_donnees WHERE name = v_cible;
    IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
    IF m.current_building IS NULL OR m.current_room IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;
    IF m.country IS DISTINCT FROM c.country
       OR m.current_city IS DISTINCT FROM c.current_city
       OR m.current_building IS DISTINCT FROM c.current_building
       OR m.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
  END IF;

  SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'trousse_secours' ORDER BY pos LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_trousse'); END IF;

  -- +2 de base, +1 par tranche COMPLETE de 25 de Secourisme DU SOIGNANT.
  v_gain := 2 + floor(least(100, greatest(0, v_sec)) / 25)::integer;

  SELECT coalesce(pa, 0) INTO v_pa_avant FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  IF v_pa_avant IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable'); END IF;
  v_pa_apres := least(c_pa_max_pj, v_pa_avant + v_gain);

  -- USAGE UNIQUE : la trousse quitte l'inventaire dans la MEME transaction que le gain.
  SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  UPDATE public.personnages_donnees SET pa = v_pa_apres WHERE name = v_cible;

  RETURN jsonb_build_object('ok', true, 'soignant', v_moi, 'cible', v_cible,
    'secourisme', v_sec, 'gain_theorique', v_gain,
    'pa_avant', v_pa_avant, 'pa_apres', v_pa_apres, 'gain_reel', v_pa_apres - v_pa_avant);
END; $function$;

REVOKE ALL ON FUNCTION public.militaire_trousse_utiliser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_trousse_utiliser(text) TO authenticated, service_role;
