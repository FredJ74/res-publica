-- =============================================================================================
-- CONFIER SES HOMMES : SEULEMENT A UN SOLDAT JOUEUR DE SA PROPRE SECTION (24 septembre 2026)
-- =============================================================================================
-- CE QUI EST AJOUTE, ET RIEN D'AUTRE : une garde d'appartenance.
--
-- militaire_affecter_leader confie la CONDUITE d'un groupe : elle ne touche que
-- sections[].soldats[].leaderCourant. Elle n'ecrit ni lieutenantNom, ni personnages_donnees.poste,
-- ni aucune autre table -- l'autorite structurelle reste au Lieutenant, qui seul peut reprendre
-- ses hommes. C'est exactement ce que l'arbitrage autorise : mener, pas commander.
--
-- CE QU'ELLE NE VERIFIAIT PAS. La cible etait libre : n'importe quelle ligne de
-- personnages_donnees du meme pays, presente dans la meme piece, faisait un leader valide. Un
-- CIVIL de passage pouvait donc se voir confier vingt-quatre hommes, tout comme un militaire
-- d'une AUTRE section. Les seuls garde-fous etaient la co-presence et la nationalite.
--
-- L'arbitrage est net : on ne confie ses hommes qu'a un autre JOUEUR de SA PROPRE SECTION. La
-- garde est posee ICI, cote serveur, et non dans l'ecran : un client modifie ne doit pas pouvoir
-- la contourner. Un soldat joueur est identifie dans le blob par pj = true ; un PNJ ne peut donc
-- jamais etre designe, ce qui est coherent -- il n'a pas d'inventaire et ne porte rien.
--
-- Nouveau motif de refus : leader_hors_section.
--
-- TOUT LE RESTE EST REPRIS A L'IDENTIQUE depuis la definition en production : autorite via
-- militaire_section_de_moi, nombre valide, leader non vide et different de soi, existence,
-- juridiction, co-presence stricte, disponibilite, puis la reecriture des leaderCourant par
-- rang. La seule difference est le bloc marque ci-dessous.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.militaire_affecter_leader(p_compagnie_id text, p_section_id text, p_nb integer, p_leader text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; v_sec jsonb; v_sols jsonb; v_dispo int;
        v_mv text; v_mb text; v_mr text; v_lv text; v_lb text; v_lr text; v_pays_l text; v_pays_m text;
        v_membre boolean;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF COALESCE(p_nb,0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'nombre_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_leader,'')),'') = '' OR p_leader = g.o_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_invalide');
  END IF;

  SELECT current_city, current_building, current_room, country INTO v_mv, v_mb, v_mr, v_pays_m
    FROM public.personnages_donnees WHERE name = g.o_moi;
  SELECT current_city, current_building, current_room, country INTO v_lv, v_lb, v_lr, v_pays_l
    FROM public.personnages_donnees WHERE name = p_leader;
  IF v_pays_l IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable');
  END IF;
  IF v_pays_l IS DISTINCT FROM v_pays_m THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_juridiction');
  END IF;
  IF v_lv IS DISTINCT FROM v_mv OR v_lb IS DISTINCT FROM v_mb OR v_lr IS DISTINCT FROM v_mr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_absent');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;

  -- ------------------------------------------------------------------------------------------
  -- LA GARDE AJOUTEE : la cible doit etre un SOLDAT JOUEUR DE CETTE SECTION.
  -- Un soldat joueur vit dans le blob sous la forme { pj: true, nom: '...' }. Exiger pj = true
  -- exclut du meme coup les PNJ -- qui n'ont ni inventaire ni existence hors de la section --
  -- et l'absence de la cible dans soldats[] exclut les civils et les militaires d'une autre
  -- section, meme presents dans la piece.
  -- ------------------------------------------------------------------------------------------
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false) AND s->>'nom' = p_leader
  ) INTO v_membre;
  IF NOT v_membre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_hors_section');
  END IF;

  SELECT count(*) INTO v_dispo FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'leaderCourant' = g.o_moi;
  IF v_dispo < p_nb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_assez_avec_vous', 'disponibles', v_dispo);
  END IF;

  SELECT COALESCE(jsonb_agg(
      CASE WHEN avec AND ord <= p_nb
           THEN sol || jsonb_build_object('leaderCourant', p_leader) ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols
    FROM (SELECT sol, pos, (sol->>'leaderCourant' = g.o_moi) AS avec,
                 row_number() OVER (PARTITION BY (sol->>'leaderCourant' = g.o_moi) ORDER BY pos) AS ord
            FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) WITH ORDINALITY AS t(sol, pos)) x;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'affectes', p_nb, 'leader', p_leader);
END;
$function$;
