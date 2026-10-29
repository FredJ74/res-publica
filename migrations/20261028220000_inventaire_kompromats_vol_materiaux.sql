-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registres Supabase 20261028211659
-- (inventaire_kompromats), 20261028211725 (inventaire_vol_materiaux_et_redaction), puis deux
-- correctifs en place 20261028211814 (inventaire et revision rendus par le piege) et
-- 20261028211853 (tentative discrete tracee) : ce fichier est leur etat final.
-- Eprouvee au role authenticated en transaction annulee : kompromat paye une fois et rejoue sans
-- second debit, texte pose une seule fois, cible soi-meme refusee ; 30 pieges (12 reussis) et faux
-- cout refuse ; 13 vols : stock du chantier 500 -> 469 et inventaire +31 bois / +3 minerai, stock
-- vide refuse sans paiement, detection -> avis de recherche.
-- ============================================================================
-- INVENTAIRE : KOMPROMATS ET VOL DE MATERIAUX PAR LE SERVEUR (28 octobre 2026, Claude)
-- ============================================================================
-- Les trois derniers sites ou l'ecran fabriquait lui-meme un objet :
--   * fabriquer un kompromat chez une escort (300) -> kompromat_fabriquer ;
--   * la rencontre piege (3 PA, 800) -> escort_piege_tenter : jet, effets, kompromat ;
--   * voler du materiel de chantier (2 PA) -> crime_voler_materiaux : jet, stock du chantier,
--     depot, trace, avis de recherche.
-- Le texte ecrit par l'IA reste un habillage : l'objet est depose avec un texte provisoire, puis
-- kompromat_rediger le remplace UNE fois (cible, type, legalite et prix restent ceux du serveur).
-- Regles reprises a l'identique de l'ecran (formules, couts, plafonds de vol 20/10/6-7-7).
-- Ecarts assumes : la caracteristique DUP est celle de la fiche (pas la moyenne du groupe) ; la
-- benediction reste declaree par l'ecran (+5 au plus), comme pour les autres crimes : elle
-- n'existe dans aucune colonne.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.kompromat_objet_interne(p_cible text, p_desc text, p_expire integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE sql VOLATILE SET search_path TO 'public', 'pg_temp'
AS $$ SELECT jsonb_build_object('id', 'kompromat-' || replace(gen_random_uuid()::text, '-', ''),
         'name', 'Kompromat sur ' || p_cible, 'icon', 'ti-file-shredder', 'type', 'kompromat',
         'cible', p_cible, 'desc', p_desc, 'descProvisoire', true, 'legal', false)
       || CASE WHEN p_expire IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('expireDay', p_expire) END $$;

-- Ajuste inf / pop (0-100) dans resources.
CREATE OR REPLACE FUNCTION public.ressource_ajuster_interne(p_nom text, p_cle text, p_delta integer)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, ARRAY[p_cle],
               to_jsonb(least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> p_cle) = 'number'
                                                              THEN (resources ->> p_cle)::numeric END, 0) + p_delta))))
       WHERE name = p_nom AND p_cle IN ('inf', 'pop') $$;

CREATE OR REPLACE FUNCTION public.kompromat_fabriquer(p_requete uuid, p_agent text, p_cible text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; params jsonb; v jsonb; o jsonb;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_agent), '') = '' OR length(p_agent) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  params := jsonb_build_object('agent', p_agent, 'cible', p_cible);
  v := public.inventaire_action_rejouer_interne(a.name, p_requete, 'kompromat', params); IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cible IS NULL OR p_cible = a.name OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF public.inventaire_place_restante(a.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  PERFORM 1 FROM public.comptes_bancaires WHERE personnage = a.name AND banque = 'nationale' FOR UPDATE;
  IF NOT public.helvetia_debiter_fonds_ordinaires(a.name, 300) THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  o := public.kompromat_objet_interne(p_cible, 'Information confidentielle obtenue.');
  v := public.inventaire_deposer_interne(a.name, o);
  IF (v ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'kompromat: depot refuse'; END IF;
  PERFORM public.ressource_ajuster_interne(a.name, 'inf', 5);
  v := v - 'qte' || jsonb_build_object('objet_id', o ->> 'id')
       || (SELECT jsonb_build_object('arg', arg, 'liquide', liquide, 'inf', resources -> 'inf') FROM public.personnages_donnees WHERE name = a.name);
  INSERT INTO public.inventaire_actions_recus VALUES (a.name, p_requete, 'kompromat', params, v, now());
  RETURN v;
END; $function$;

CREATE OR REPLACE FUNCTION public.escort_piege_tenter(p_requete uuid, p_cible text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; params jsonb; v jsonb; o jsonb; v_paie jsonb;
  v_dup integer; v_dis integer; c_dup integer; c_dis integer; v_taux integer; v_roll integer;
  v_t_enq integer; v_t_id integer; v_enquete boolean := false; v_identifie boolean := false;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  params := jsonb_build_object('cible', p_cible, 'pa', p_pa, 'cost', p_cost);
  v := public.inventaire_action_rejouer_interne(a.name, p_requete, 'escort_piege', params); IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cible IS NULL OR p_cible = a.name OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF public.inventaire_place_restante(a.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(a.name, 'escort_piege', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dup := coalesce((a.stats ->> 'DUP')::numeric, 8)::integer;
  v_dis := coalesce(CASE WHEN jsonb_typeof(a.resources -> 'dis') = 'number' THEN (a.resources ->> 'dis')::numeric END, 50)::integer;
  -- Statistiques de la cible simulees, exactement comme l'ecran.
  c_dup := floor(random() * 6)::integer + 6;
  c_dis := floor(random() * 40)::integer + 30;
  v_taux := least(80, 30 + v_dup * 2 - floor(c_dup * 1.5)::integer);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    PERFORM public.ressource_ajuster_interne(a.name, 'inf', 10);
    PERFORM public.ressource_ajuster_interne(a.name, 'pop', 5);
    o := public.kompromat_objet_interne(p_cible, p_cible || ' impliqué(e) dans un scandale compromettant avec une escort.', coalesce(a.day, 1) + 10);
    v := public.inventaire_deposer_interne(a.name, o);
    IF (v ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'escort_piege: depot refuse'; END IF;
    v := v - 'qte' || jsonb_build_object('reussi', true, 'objet_id', o ->> 'id');
  ELSE
    v_t_enq := least(70, c_dup * 4 + c_dis / 10);
    IF floor(random() * 100)::integer + 1 <= v_t_enq THEN
      v_enquete := true;
      v_t_id := least(80, v_t_enq - v_dup * 2 - v_dis / 10);
      IF floor(random() * 100)::integer + 1 <= v_t_id THEN
        v_identifie := true;
        PERFORM public.ressource_ajuster_interne(a.name, 'pop', -15);
        PERFORM public.crime_dis_ajuster_interne(a.name, -10);
      END IF;
    END IF;
    v := jsonb_build_object('ok', true, 'reussi', false, 'enquete', v_enquete, 'identifie', v_identifie);
  END IF;
  v := v || jsonb_build_object('taux', v_taux, 'jet', v_roll)
       || (SELECT jsonb_build_object('pa', pa, 'arg', arg, 'liquide', liquide, 'inf', resources -> 'inf', 'pop', resources -> 'pop', 'dis', resources -> 'dis',
                                     'inventory', inventory, 'revision', inventory_revision)
             FROM public.personnages_donnees WHERE name = a.name);
  INSERT INTO public.inventaire_actions_recus VALUES (a.name, p_requete, 'escort_piege', params, v, now());
  RETURN v;
END; $function$;

-- Le texte ecrit par l'IA remplace UNE fois le texte provisoire d'un kompromat qu'on possede.
CREATE OR REPLACE FUNCTION public.kompromat_rediger(p_objet text, p_texte text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v_pos integer; v_txt text;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_txt := left(btrim(coalesce(p_texte, '')), 600);
  IF v_txt = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_requis'); END IF;
  SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.inventory) = 'array' THEN a.inventory ELSE '[]'::jsonb END)
    WITH ORDINALITY x(e, o) WHERE e ->> 'id' = p_objet AND e ->> 'type' = 'kompromat' AND (e ->> 'descProvisoire')::boolean IS TRUE LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_introuvable'); END IF;
  UPDATE public.personnages_donnees
     SET inventory = jsonb_set(inventory, ARRAY[v_pos::text], (inventory -> v_pos) - 'descProvisoire' || jsonb_build_object('desc', v_txt))
   WHERE name = a.name;
  RETURN jsonb_build_object('ok', true)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a.name);
END; $function$;

CREATE OR REPLACE FUNCTION public.crime_voler_materiaux(p_terrain text, p_matiere text, p_pa integer, p_cost integer, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v_paie jsonb; v_lu jsonb; v_etat jsonb; v_ch jsonb; v_stock jsonb;
  v_isn numeric; v_rep integer; v_bonus numeric; v_vig integer; v_score integer; v_jour integer; v_plafond integer;
  v_dispo integer; v_q integer; v_dep jsonb; v_final jsonb; v_ville text; v_repere boolean := false;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_matiere IS NULL OR p_matiere NOT IN ('bois', 'minerai', 'metal') THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_inconnue'); END IF;
  IF p_terrain IS NULL OR a.current_building IS DISTINCT FROM p_terrain THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_lu := public.terrain_etat_verrouiller_interne(p_terrain);
  IF (v_lu ->> 'gele')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele'); END IF;
  v_etat := v_lu -> 'etat'; v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent'); END IF;
  v_stock := CASE WHEN jsonb_typeof(v_ch -> 'stockMateriaux') = 'object' THEN v_ch -> 'stockMateriaux' ELSE '{}'::jsonb END;
  v_dispo := greatest(0, floor(coalesce(CASE WHEN jsonb_typeof(v_stock -> p_matiere) = 'number' THEN (v_stock ->> p_matiere)::numeric END, 0)))::integer;
  IF v_dispo <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_vide'); END IF;
  IF public.inventaire_place_restante(a.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(a.name, 'voler_materiel_chantier', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_ville := coalesce(a.current_city, 'capitale');
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes WHERE id = a.country || '_' || v_ville), 30);
  v_rep := coalesce(a.reputation_criminelle, 0);
  -- Memes termes que l'ecran : (DUP-10)*2 - (ISN-45)/3 + palier criminel + benediction.
  v_bonus := (coalesce((a.stats ->> 'DUP')::numeric, 8) - 10) * 2 - (v_isn - 45) / 3
             + CASE WHEN v_rep >= 70 THEN 15 WHEN v_rep >= 40 THEN 10 WHEN v_rep >= 20 THEN 5 ELSE 0 END
             + CASE WHEN p_benediction THEN 5 ELSE 0 END;
  v_vig := CASE WHEN jsonb_typeof(v_ch -> 'vigiles') = 'array' THEN jsonb_array_length(v_ch -> 'vigiles')
                ELSE greatest(0, floor(coalesce(CASE WHEN jsonb_typeof(v_ch -> 'vigiles') = 'number' THEN (v_ch ->> 'vigiles')::numeric END, 0)))::integer END;
  -- UN SEUL JET : ecart de -49 a +50 autour de 50.
  v_score := greatest(0, least(100, round(50 + v_bonus - CASE WHEN v_vig <= 0 THEN 0 ELSE 20 + (v_vig - 1) * 10 END
                                          + (floor(random() * 100) + 1 - 50))))::integer;

  IF v_score >= 50 THEN
    v_jour := floor(greatest(0, coalesce((v_ch ->> 'progressionJours')::numeric, 0)))::integer + 1;
    v_plafond := CASE p_matiere WHEN 'bois' THEN 20 WHEN 'minerai' THEN 10 ELSE (ARRAY[6, 7, 7])[((v_jour - 1) % 3) + 1] END;
    v_q := least(v_plafond, v_dispo, greatest(1, round((v_score - 50)::numeric / 50 * v_plafond)::integer));
    v_q := least(v_q, public.inventaire_place_restante(a.inventory));
    v_dep := public.inventaire_deposer_interne(a.name, jsonb_build_object(
      'name', CASE p_matiere WHEN 'bois' THEN 'Bois' WHEN 'minerai' THEN 'Minerai' ELSE 'Métal' END,
      'icon', CASE p_matiere WHEN 'bois' THEN 'ti-trees' WHEN 'minerai' THEN 'ti-mountain' ELSE 'ti-bolt' END,
      'stackable', true, 'stackKey', p_matiere, 'qty', v_q, 'desc', 'Dérobé sur un chantier.'));
    IF (v_dep ->> 'ok')::boolean IS DISTINCT FROM true OR (v_dep ->> 'qte')::integer <> v_q THEN RAISE EXCEPTION 'vol materiaux: depot incomplet'; END IF;
    v_ch := v_ch || jsonb_build_object('stockMateriaux', v_stock || jsonb_build_object(p_matiere, v_dispo - v_q))
                 || jsonb_build_object('evenements', coalesce(v_ch -> 'evenements', '[]'::jsonb)
                      || jsonb_build_array(jsonb_build_object('cle', 'vol_materiaux', 'jour', coalesce(a.day, 1), 'matiere', p_matiere, 'quantite', v_q)));
    v_final := public.terrain_etat_fusionner_interne(p_terrain, jsonb_build_object('chantier', v_ch), a.country);
    UPDATE public.indices_villes
       SET data = jsonb_set(data, '{social}', to_jsonb(greatest(0, least(100,
                    coalesce(CASE WHEN jsonb_typeof(data -> 'social') = 'number' THEN (data ->> 'social')::numeric END, 50) - 1))))
     WHERE id = a.country || '_' || v_ville;
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
    VALUES ('vol-chantier-' || gen_random_uuid(), a.name, v_etat ->> 'proprietaire', 'vol_materiel_chantier', a.country, v_ville,
            coalesce(a.day, 1), coalesce(a.day, 1) + 15);
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'score', v_score, 'matiere', p_matiere, 'quantite', v_q, 'etat', v_final)
      || (v_dep - 'ok' - 'qte') || jsonb_build_object('pa', v_paie -> 'pa');
  END IF;
  IF v_score < 20 THEN
    PERFORM public.crime_rechercher_interne(a.name, 'vol_materiel_chantier', 'delit_mineur');
    v_repere := true;
  ELSE
    -- Echec discret : la tentative reste tracable sur enquete, comme a l'ecran.
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
    VALUES ('voltentative-' || gen_random_uuid(), a.name, v_etat ->> 'proprietaire', 'tentative_vol_materiel_chantier', a.country, v_ville,
            coalesce(a.day, 1), coalesce(a.day, 1) + 15);
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'detecte', v_repere, 'score', v_score, 'pa', v_paie -> 'pa')
    || (SELECT jsonb_build_object('recherche', recherche) FROM public.personnages_donnees WHERE name = a.name);
END; $function$;

REVOKE ALL ON FUNCTION public.kompromat_objet_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ressource_ajuster_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kompromat_fabriquer(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kompromat_fabriquer(uuid, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.escort_piege_tenter(uuid, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escort_piege_tenter(uuid, text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.kompromat_rediger(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kompromat_rediger(text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_voler_materiaux(text, text, integer, integer, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_voler_materiaux(text, text, integer, integer, boolean) TO authenticated;
