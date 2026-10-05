-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918075548
-- Nom original      : militaire_subtiliser_resolution_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 07:55:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1d1db973c8c5e1f1ef8990a569aeb65a
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
-- SUBTILISATION D'EXPLOSIF : RESOLUTION ENTIEREMENT SERVEUR (18 septembre 2026)
--
-- Avant : le navigateur tirait le de (Math.random), decidait de la reussite, puis appelait
-- militaire_subtiliser pour decrementer le stock et FABRIQUAIT LUI-MEME l'explosif dans son
-- inventaire (poserObjetMilitaire). Deux failles distinctes : forcer la reussite depuis la
-- console, et surtout creer un explosif sans passer par le jet du tout.
--
-- La formule n'est PAS retouchee -- ce sont exactement les termes du vol de materiaux de
-- chantier, transposes tels quels :
--   bonus = (DUP - 10) * 2 - (ISN - 45) / 3 + bonus de reputation criminelle
--   score = borner(50 + bonus + (1d100 - 50), 0, 100)
--   score < 20 : echec DETECTE ; < 66 : echec discret ; >= 66 : reussite (35 % a bonus nul)
--
-- DEUX TERMES NE SONT PAS PORTABLES, et c'est signale plutot que devine :
--   * bonusFormation (+2 temporaire jusqu'au prochain sommeil) n'existe qu'en memoire cliente ;
--   * le bonus de benediction est un effet consomme cote client.
-- Les inclure aurait exige de les faire declarer par le client -- c'est-a-dire de rouvrir la
-- faille qu'on ferme. Ils sont donc absents du jet serveur : un joueur beni ou fraichement forme
-- est legerement moins avantage qu'avant sur CE seul ordre. A arbitrer par le GD.
CREATE OR REPLACE FUNCTION public.militaire_subtiliser_tenter(p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c_seuil_detection constant integer := 20;
  c_seuil_reussite  constant integer := 66;
  c_isn_defaut      constant integer := 30;
  v_moi text; v_pj public.personnages_donnees%ROWTYPE;
  v_dup numeric; v_isn integer; v_rep integer; v_bonus_rep integer;
  v_bonus numeric; v_jet integer; v_score integer;
  v_stock jsonb; v_objet jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF coalesce(v_pj.current_building,'') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LE PA EST DEBITE AVANT LE JET, comme pour toute tentative : on paie l'essai, pas le resultat.
  IF coalesce(v_pj.pa, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', 2);
  END IF;

  -- DUP effective : meme regle que getStatEffective -- une caracteristique affaiblie est
  -- proportionnelle aux points de vie, jamais en dessous de 1.
  v_dup := coalesce((v_pj.stats->>'DUP')::numeric, 8);
  IF v_pj.stats_affaiblies ? 'DUP' THEN
    v_dup := greatest(1, round(v_dup * greatest(0, least(1, coalesce(v_pj.hp,0)::numeric / 100))));
  END IF;

  -- ISN de la zone. La caserne n'a pas d'indices propres : repli sur le defaut, exactement comme
  -- getIndiceVille cote client.
  SELECT coalesce((data->>'isn')::integer, c_isn_defaut) INTO v_isn
    FROM public.indices_villes WHERE id = p_pays || '_' || coalesce(v_pj.current_city,'');
  v_isn := coalesce(v_isn, c_isn_defaut);

  v_rep := greatest(0, least(100, coalesce(v_pj.reputation_criminelle, 0)));
  v_bonus_rep := CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END;

  v_bonus := (v_dup - 10) * 2 - (v_isn - 45)::numeric / 3 + v_bonus_rep;
  v_jet := floor(random() * 100)::integer + 1 - 50;
  v_score := greatest(0, least(100, round(50 + v_bonus + v_jet)::integer));

  UPDATE public.personnages_donnees SET pa = greatest(0, coalesce(pa,0) - 2) WHERE name = v_moi;

  IF v_score < c_seuil_reussite THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false,
      'detecte', v_score < c_seuil_detection, 'score', v_score);
  END IF;

  -- REUSSITE. Le stock est decremente AVANT que l'objet n'existe : jamais d'explosif cree de rien.
  v_stock := public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
  IF coalesce((v_stock->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussite', false, 'detecte', false,
      'score', v_score, 'raison', 'stock_insuffisant');
  END IF;

  -- ...et c'est le SERVEUR qui le pose dans l'inventaire, plus le navigateur.
  v_objet := jsonb_build_object(
    'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
    'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
    'lot', coalesce(v_stock->'lots'->0->>'lot', 'legacy'),
    'produitMilitaire', 'explosif_militaire', 'name', 'Explosif militaire',
    'icon', 'ti-bomb', 'legal', true, 'imageUrl', NULL,
    'desc', 'Explosif militaire. Lot ' || coalesce(v_stock->'lots'->0->>'lot', 'legacy') || '.');

  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END)
                     || jsonb_build_array(v_objet)
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'reussite', true, 'detecte', false,
    'score', v_score, 'objet', v_objet, 'lot', v_objet->>'lot');
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_subtiliser_tenter(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_subtiliser_tenter(text) TO authenticated;

-- L'ancienne primitive ne doit plus etre appelable par un client : elle decremente le stock sans
-- aucun jet, ce qui est exactement le robinet qu'on ferme.
REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM PUBLIC, anon, authenticated;