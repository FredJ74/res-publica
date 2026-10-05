-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922070614
-- Nom original      : renseignement_contre_espionnage_position_reelle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 07:06:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 44e341818ce941722f3bc3d6620255d1
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
-- PRESENCE LOCALE VUE PAR LE CONTRE-ESPIONNAGE. On voyait un agent « ici » si sa COUVERTURE
-- etait du pays ou l'on se trouve : un agent sous couverture etrangere etait donc invisible.
-- Desormais c'est la presence PHYSIQUE effective qui compte, celle d'un agent porte comprise --
-- il circule reellement dans la piece.
CREATE OR REPLACE FUNCTION public.agents_renseignement_ici()
RETURNS TABLE(nom_couverture text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_room text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;

  SELECT d.country, d.current_city, d.current_building, d.current_room
    INTO v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_pays IS NULL OR v_bat IS NULL OR v_room IS NULL THEN RETURN; END IF;

  RETURN QUERY
    SELECT a.nom_couverture
      FROM public.agents_renseignement a
      LEFT JOIN LATERAL public.agent_position_effective(a.id) pe ON true
     WHERE a.statut = 'actif'
       AND pe.pays        IS NOT DISTINCT FROM v_pays
       AND pe.ville       IS NOT DISTINCT FROM v_ville
       AND pe.building_id IS NOT DISTINCT FROM v_bat
       AND pe.room_id     IS NOT DISTINCT FROM v_room
       AND a.leader_courant IS DISTINCT FROM v_moi   -- on ne se detecte pas soi-meme
     ORDER BY a.nom_couverture;
END;
$fn$;

-- CIBLE D'UNE DETENTION. La juridiction competente est celle de la PRESENCE REELLE.
-- La condition « pose, pas en deplacement » est conservee telle quelle : c'est une regle de
-- jeu existante (on n'arrete pas quelqu'un qui traverse dans le groupe d'un autre), sans
-- rapport avec la conflation qu'on corrige ici.
CREATE OR REPLACE FUNCTION public.detention_cible_pnj(p_nom text, p_pays_autorite text)
RETURNS TABLE(systeme text, pays text, ville text, building_id text, room_id text,
              agent_id text, statut text, niveau_connu integer, arretable boolean)
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
  SELECT 'agent_renseignement'::text,
         pe.pays, pe.ville, pe.building_id, pe.room_id,
         ag.id, ag.statut,
         public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture),
         (    ag.statut = 'actif'
          AND ag.leader_courant IS NULL
          AND pe.ville IS NOT NULL
          AND pe.pays = p_pays_autorite
          AND public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture) >= 2)
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.nom_couverture = p_nom
     AND pe.pays IS NOT DISTINCT FROM p_pays_autorite
     AND c.statut = 'active'
   LIMIT 1;
$fn$;

-- CONTRE-ESPIONNAGE. Le commissaire enquete sur quelqu'un qu'il voit passer CHEZ LUI : la
-- cible se resout donc sur la presence physique, pas sur le pays de la fausse identite.
CREATE OR REPLACE FUNCTION public.contre_espionnage_resoudre(
  p_pays text, p_couverture text, p_instructeur text, p_ref text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_ag record; v_per numeric; v_is numeric;
  v_mod integer; v_de integer; v_score integer; v_palier integer;
  v_avant integer; v_apres integer;
BEGIN
  SELECT ag.dup, ag.vrai_nom, ag.nom_couverture, c.pays_proprietaire
    INTO v_ag
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE pe.pays IS NOT DISTINCT FROM p_pays
     AND ag.nom_couverture = p_couverture
     AND ag.statut IN ('actif', 'detenu')
     AND c.statut = 'active';
  IF v_ag.dup IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_agent');
  END IF;

  SELECT public.assemblee_stat_base(d.stats, 'PER') INTO v_per
    FROM public.personnages_donnees d WHERE d.name = p_instructeur;
  v_per := coalesce(v_per, 8);
  v_is  := public.is_national(p_pays);

  v_mod    := public.contre_espionnage_modificateur(v_per, v_ag.dup, v_is);
  v_de     := floor(random() * 100)::integer + 1;
  v_score  := greatest(0, least(100, v_de + v_mod));
  v_palier := public.contre_espionnage_palier(v_score);

  v_avant := public.contre_espionnage_niveau_connu(p_pays, p_couverture);
  v_apres := public.contre_espionnage_memoriser(p_pays, p_couverture, v_palier,
               v_ag.vrai_nom, v_ag.pays_proprietaire, p_instructeur, p_ref);

  RETURN jsonb_build_object('ok', true, 'score', v_score, 'palier', v_palier,
    'niveau_avant', v_avant, 'niveau', v_apres,
    'progression', v_apres > v_avant);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.contre_espionnage_approfondir(p_couverture text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE v_nom text; v_poste text; v_pays text; v_statut text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('commissaire', 'juge') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT ag.statut INTO v_statut
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE pe.pays IS NOT DISTINCT FROM v_pays AND ag.nom_couverture = p_couverture
     AND c.statut = 'active';
  IF v_statut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_inconnue');
  END IF;
  IF v_statut <> 'detenu' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  BEGIN
    INSERT INTO public.contre_espionnage_tentatives (pays, couverture, jour_paris, instructeur)
    VALUES (v_pays, p_couverture, (now() AT TIME ZONE 'Europe/Paris')::date, v_nom);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_tente_aujourdhui');
  END;

  RETURN public.contre_espionnage_resoudre(v_pays, p_couverture, v_nom, 'detention');
END;
$fn$;