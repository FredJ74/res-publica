-- Forêt de Krasnov, remontées du test de Fred (22/11/2026, fin de nuit : GAME-DESIGN-FORET-TEST-20261122.md, points 5, 6, 7).
-- Point 5, groupes :
-- • Un membre ne perd que le droit de se déplacer : il coupe du bois en forêt profonde, pour lui seul, avec ses PA
--   (sovarka_foret_couper ne répond plus « quitter_groupe_pour_couper »). Sa coupe ne fait jamais apparaître de créature
--   ni Olga (fausses alertes possibles). Le chef reçoit sa propre récolte, jamais doublée par la présence des membres.
-- • Seul le chef déclenche une rencontre ou un combat (inchangé : combat_ouvrir_interne refuse un membre).
-- • Combat lancé par le chef : tous les membres présents sont engagés et frappent avec leur arme (constaté en production,
--   combat 341 : deux coups portés au premier round) ; le butin va au chef, une seule fois.
-- • Journal : chaque membre reçoit le récit des rencontres (Olga, bêtes, fausses alertes du chef, fuite, « se laisser faire »)
--   et l'issue du combat avec le butin (table sovarka_foret_journal, lue par sovarka_foret_journal_lire).
-- Point 6, rapport de combat : chaque round enregistre une ligne par combattant (nom, dégâts subis, état), et l'adversaire
--   est nommé (fin de « 1 à 2 soldats » pour une bête) — combats civils, squatteurs, faune et gardes ; batailles militaires
--   inchangées (estimation dégradée voulue).
-- Point 7, faune : la meute devient trois loups séparés (« Meute de 3 loups », « Loup 1/2/3 », 8 PA chacun, un groupe de
--   combat chacun : chacun frappe une cible au hasard, tombe ou fuit séparément) ; une morsure retire un tiers des dégâts
--   d'un coup de l'ancienne meute ; aucun plafond par round ; l'ours reste unique. Butin de la meute : 3 peaux et 2 viandes
--   par loup abattu (9 et 6 pour les trois, comme avant).
-- Fonctions communes modifiées par remplacement contrôlé (texte de production, marque unique, nombre d'ancrages vérifié) :
--   combat_ouvrir_interne, combat_finaliser_interne, militaire_bataille_combattants, militaire_bataille_appliquer,
--   militaire_bataille_rapport, militaire_bataille_etat. Fonctions de la forêt réécrites (texte de production + changements).
-- Rejouable. Aucun objet du goulag touché.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Journal des membres du groupe
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sovarka_foret_journal (
  id bigserial PRIMARY KEY,
  destinataire text NOT NULL,
  cle text NOT NULL,
  params jsonb NOT NULL DEFAULT '{}'::jsonb,
  bataille bigint,
  cree_le timestamptz NOT NULL DEFAULT now(),
  lu_le timestamptz
);
CREATE INDEX IF NOT EXISTS sovarka_foret_journal_non_lus ON public.sovarka_foret_journal (destinataire, id) WHERE lu_le IS NULL;
ALTER TABLE public.sovarka_foret_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_foret_journal FROM PUBLIC, anon, authenticated;

-- Membres du groupe du chef présents à l'exploitation forestière (le chef écrit son propre journal à l'écran).
CREATE OR REPLACE FUNCTION public.sovarka_foret_journal_groupe_interne(p_chef text, p_cle text, p_params jsonb, p_bataille bigint DEFAULT NULL)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n integer;
BEGIN
  INSERT INTO public.sovarka_foret_journal (destinataire, cle, params, bataille)
  SELECT g.membre, p_cle, coalesce(p_params, '{}'::jsonb) || jsonb_build_object('chef', p_chef), p_bataille
    FROM public.groupes_pj_adhesions g JOIN public.personnages_donnees d ON d.name = g.membre
   WHERE g.chef = p_chef AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production'
   ORDER BY g.membre;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_journal_groupe_interne(text, text, jsonb, bigint) FROM PUBLIC, anon, authenticated;

-- Lecture (et acquittement) de mes entrées non lues.
CREATE OR REPLACE FUNCTION public.sovarka_foret_journal_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); r jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  WITH u AS (
    UPDATE public.sovarka_foret_journal SET lu_le = now() WHERE destinataire = a AND lu_le IS NULL
    RETURNING id, cle, params, bataille, cree_le)
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'cle', cle, 'params', params, 'bataille', bataille, 'ts', cree_le) ORDER BY id), '[]'::jsonb)
    INTO r FROM u;
  RETURN jsonb_build_object('ok', true, 'evenements', r);
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_journal_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_journal_lire() TO authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Créatures : trois loups séparés
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_foret_creature_interne(p_type text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  -- combat_faune_hostilite_v1 : bêtes renforcées (Fred, 14/11/2026).
  -- foret_meute_trois_loups_v1 (Fred, 22/11/2026) : la meute = trois loups de 8 PA ; « morsure » = part des dégâts d'un
  -- coup ordinaire (un tiers de l'ancienne meute) ; butin de la meute PAR LOUP abattu.
  SELECT CASE p_type
    WHEN 'loup'  THEN '{"nom":"Loup solitaire","vol":12,"per":10,"dup":10,"pa":14,"griffes":4,"butin":[{"cle":"textile","qte":3},{"cle":"viande","qte":3}]}'::jsonb
    WHEN 'meute' THEN '{"nom":"Meute de 3 loups","nom_unite":"Loup","loups":3,"vol":18,"per":12,"dup":12,"pa":8,"griffes":8,"morsure":0.34,"butin":[{"cle":"textile","qte":3},{"cle":"viande","qte":2}]}'::jsonb
    WHEN 'ours'  THEN '{"nom":"Ours","vol":26,"per":12,"dup":12,"pa":36,"griffes":12,"butin":[{"cle":"textile","qte":10},{"cle":"viande","qte":9}],"dents":2}'::jsonb
  END;
$function$;

-- Identifiant de la rencontre d'un PNJ de faune : « faune:krasnov:26:2 » (Loup 2) → « faune:krasnov:26 ».
CREATE OR REPLACE FUNCTION public.sovarka_foret_pnj_racine_interne(p_pnj text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT regexp_replace(p_pnj, '^(faune:krasnov:[0-9]+):[0-9]+$', '\1') $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_pnj_racine_interne(text) FROM PUBLIC, anon, authenticated;

-- Création d'une rencontre et de ses PNJ (un seul, ou trois loups : Loup 1 garde l'identifiant de la rencontre).
CREATE OR REPLACE FUNCTION public.sovarka_foret_faune_creer_interne(p_acteur text, p_vue integer, p_type text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c jsonb := public.sovarka_foret_creature_interne(p_type); v_id bigint; v_pnj text; n integer; i integer; v_ident text; v_nom text;
        v_noms jsonb := '[]'::jsonb;
BEGIN
  INSERT INTO public.sovarka_foret_rencontres (bucheron, vue, creature, statut) VALUES (p_acteur, p_vue, p_type, 'en_attente') RETURNING id INTO v_id;
  v_pnj := 'faune:krasnov:' || v_id;
  n := greatest(1, coalesce((c->>'loups')::integer, 1));
  FOR i IN 1..n LOOP
    v_ident := v_pnj || CASE WHEN i = 1 THEN '' ELSE ':' || i END;
    v_nom := CASE WHEN n > 1 THEN coalesce(c->>'nom_unite', 'Loup') || ' ' || i ELSE c->>'nom' END;
    INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, proprietaire_institution, proprietaire_perimetre, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_ident, 'employe', v_nom, 'soviet', 'ville_b', 'zone-production', 'foret_vue_' || p_vue, 'beta', coalesce((c->>'pa')::integer, public.pnj_pa_max()) /* combat_faune_hostilite_v1 */, 'faune', 'soviet:ville_b:foret',
            4, 4, (c->>'vol')::integer, (c->>'per')::integer, (c->>'dup')::integer, 4)
    ON CONFLICT (id) DO NOTHING;
    v_noms := v_noms || to_jsonb(v_nom);
  END LOOP;
  UPDATE public.sovarka_foret_rencontres SET pnj_id = v_pnj WHERE id = v_id;
  RETURN jsonb_build_object('creature', p_type, 'nom', c->>'nom', 'pnj', v_pnj, 'id', v_id, 'combattants', v_noms);
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_faune_creer_interne(text, integer, text) FROM PUBLIC, anon, authenticated;

-- Retrait des bêtes encore actives d'une rencontre (fuite, « se laisser faire », fin de combat).
CREATE OR REPLACE FUNCTION public.sovarka_foret_faune_retirer_interne(p_pnj text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now()
   WHERE (id = p_pnj OR id LIKE p_pnj || ':%') AND statut = 'actif';
$function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_faune_retirer_interne(text) FROM PUBLIC, anon, authenticated;

-- Morsure : une bête dotée d'un facteur « morsure » ne retire que cette part d'un coup ordinaire (au moins 1 PA).
CREATE OR REPLACE FUNCTION public.sovarka_foret_morsure_interne(p_att_eng bigint, p_pa integer, p_new integer)
 RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pnj text; f numeric;
BEGIN
  IF p_new IS NULL OR p_pa IS NULL OR p_new >= p_pa THEN RETURN p_new; END IF;
  SELECT pnj_id INTO v_pnj FROM public.batailles_engagements WHERE id = p_att_eng;
  IF v_pnj IS NULL OR v_pnj NOT LIKE 'faune:%' THEN RETURN p_new; END IF;
  SELECT (public.sovarka_foret_creature_interne(r.creature)->>'morsure')::numeric INTO f
    FROM public.sovarka_foret_rencontres r WHERE r.pnj_id = public.sovarka_foret_pnj_racine_interne(v_pnj) LIMIT 1;
  IF f IS NULL OR f <= 0 OR f >= 1 THEN RETURN p_new; END IF;
  RETURN greatest(0, p_pa - greatest(1, round((p_pa - p_new) * f)::integer));
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_morsure_interne(bigint, integer, integer) FROM PUBLIC, anon, authenticated;

-- Les autres loups de la meute entrent au combat, chacun dans son propre groupe (il tombe ou fuit seul).
CREATE OR REPLACE FUNCTION public.sovarka_foret_combat_meute_interne(p_bataille bigint, p_pnj text)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n integer;
BEGIN
  INSERT INTO public.batailles_engagements (bataille_id, camp, pnj_id, matricule, groupe_id, pa_initial)
  SELECT p_bataille, 'defenseur', m.id, m.id, 'defenseur|pnj:' || m.id, m.pa
    FROM public.pnj_membres m
   WHERE m.id LIKE p_pnj || ':%' AND m.statut = 'actif' AND m.pa > 0
     AND NOT EXISTS (SELECT 1 FROM public.batailles_engagements e WHERE e.bataille_id = p_bataille AND e.pnj_id = m.id)
   ORDER BY m.id;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_combat_meute_interne(bigint, text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Coupe : le membre coupe pour lui ; seul le chef fait surgir une rencontre
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_foret_couper(p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); x record; s record; v_vue integer; v_k integer; v_max integer; v_paie jsonb;
        v_q integer; v_dep jsonb; r jsonb; v_type text; c jsonb; v_nourris jsonb; v_bonus integer; v_alerte text; v_reg jsonb;
        v_chef text; v_membre boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:foret:' || a, 0));
  SELECT * INTO x FROM public.sovarka_foret_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  -- foret_groupe_membres_v1 (Fred, 22/11/2026) : un membre ne perd que le droit de se déplacer ; il coupe pour lui seul.
  v_chef := coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre = a), a);
  v_membre := v_chef <> a;
  PERFORM 1 FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF coalesce(v_vue, 0) NOT BETWEEN 1 AND 4 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_foret_profonde'); END IF; /* foret_clairiere_v1 */
  IF EXISTS (SELECT 1 FROM public.detention_active(a)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron IN (a, v_chef) AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rencontre_en_cours'); END IF;
  SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = a FOR UPDATE;
  IF NOT FOUND OR s.vue <> v_vue THEN
    DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
    INSERT INTO public.sovarka_foret_visites (bucheron, vue) VALUES (a, v_vue) RETURNING * INTO s;
  END IF;
  v_k := s.coupes + 1;
  v_max := 2;
  IF v_k > v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'coupes_epuisees'); END IF;
  IF NOT (v_vue = 3 AND v_k = 2 AND NOT v_membre)
     AND (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 12 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_reg := public.regulation_production_refus_interne(a, 'soviet', 'ville_b', 'Bois');
  IF v_reg IS NOT NULL THEN RETURN v_reg; END IF;
  v_paie := public.payer_ordre(a, 'foret_couper', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS TRUE THEN
    PERFORM public.regulation_production_compter_interne(a, 'soviet', 'ville_b', 'Bois');
  END IF;
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.sovarka_foret_visites SET coupes = v_k WHERE bucheron = a;

  IF v_vue = 4 AND v_k = 2 AND NOT v_membre THEN
    SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'repas_olga';
    WITH g AS (
      SELECT d.name FROM public.personnages_donnees d
       WHERE (d.name = a OR d.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = a))
         AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production' AND d.current_room = 'foret_vue_4'
    ), u AS (
      UPDATE public.personnages_donnees d SET bonus_pa_differe = least(30, coalesce(d.bonus_pa_differe, 0) + v_bonus), updated_at = now()
        FROM g WHERE d.name = g.name RETURNING d.name)
    SELECT coalesce(jsonb_agg(name ORDER BY name), '[]'::jsonb) INTO v_nourris FROM u;
    INSERT INTO public.sovarka_foret_rencontres (bucheron, vue, creature, statut, clos_le) VALUES (a, 4, 'olga', 'nourri', now());
    -- Olga donne aussi le bois de la seconde coupe (Fred, 10/11).
    v_q := 12; /* regulation_production_v1 */
    v_dep := public.inventaire_deposer_interne(a, public.sovarka_matiere_objet_interne('bois', v_q, 'Coupé dans la forêt profonde de Krasnov.'));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'sovarka_foret_couper: depot refuse %', v_dep; END IF;
    UPDATE public.sovarka_foret_visites SET bois = bois + v_q WHERE bucheron = a;
    PERFORM public.sovarka_foret_journal_groupe_interne(a, 'olga', jsonb_build_object('bonus', v_bonus, 'nourris', v_nourris)); /* foret_journal_groupe_v1 */
    r := jsonb_build_object('ok', true, 'rencontre', 'olga', 'nourris', v_nourris, 'bonus', v_bonus, 'quantite', v_q);

  ELSIF v_vue = 3 AND v_k = 2 AND NOT v_membre THEN
    v_type := (ARRAY['loup', 'meute', 'ours'])[1 + floor(random() * 3)::integer];
    c := public.sovarka_foret_faune_creer_interne(a, 3, v_type);
    PERFORM public.sovarka_foret_journal_groupe_interne(a, 'rencontre', jsonb_build_object('creature', v_type, 'nom', c->>'nom'));
    r := jsonb_build_object('ok', true, 'rencontre', 'attaque', 'creature', v_type, 'nom', c->>'nom', 'pnj', c->>'pnj',
      'id', (c->>'id')::bigint, 'combattants', c->'combattants');

  ELSE
    v_q := 12; /* regulation_production_v1 */
    v_dep := public.inventaire_deposer_interne(a, public.sovarka_matiere_objet_interne('bois', v_q, 'Coupé dans la forêt profonde de Krasnov.'));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'sovarka_foret_couper: depot refuse %', v_dep; END IF;
    UPDATE public.sovarka_foret_visites SET bois = bois + v_q WHERE bucheron = a;
    -- Un membre peut entendre une fausse alerte à sa seconde coupe, dans toute vue ; jamais une vraie bête.
    IF (v_vue IN (1, 2) OR v_membre) AND v_k = 2 AND random() < 0.5 THEN
      v_alerte := (ARRAY['Ce n''était qu''un lièvre, qui détale dans la neige.',
                         'Un tractoriste perdu sort des fourrés et vous demande le chemin du kolkhoze.',
                         'Une branche cède sous le poids de la neige. Rien de plus.',
                         'Un élan vous regarde un long moment, puis s''en va sans se presser.',
                         'Un vieux chasseur vous salue d''un signe de tête et disparaît entre les troncs.'])[1 + floor(random() * 5)::integer];
    END IF;
    IF v_alerte IS NOT NULL AND NOT v_membre THEN
      PERFORM public.sovarka_foret_journal_groupe_interne(a, 'fausse_alerte', jsonb_build_object('texte', v_alerte));
    END IF;
    r := jsonb_build_object('ok', true, 'quantite', v_q, 'fausse_alerte', v_alerte, 'membre', v_membre,
      'coupes_restantes', CASE WHEN v_vue IN (1, 2) OR v_membre THEN 2 - v_k ELSE 0 END);
  END IF;

  r := r || jsonb_build_object('vue', v_vue, 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg')
         || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory');
  RETURN r;
END $function$;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_couper(uuid) TO authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Rencontre à l'arrivée (ajoutée le 22/11) : trois loups, journal des membres
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_foret_rencontre_arrivee_interne(p_acteur text, p_vue integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_type text; c jsonb;
BEGIN
  IF p_acteur IS NULL OR coalesce(p_vue, 0) NOT BETWEEN 1 AND 4 THEN RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron = p_acteur AND statut = 'en_attente') THEN RETURN NULL; END IF;
  IF random() * 100 >= public.aliments_param_interne('foret_rencontre_arrivee_pct', 15) THEN RETURN NULL; END IF;
  v_type := (ARRAY['loup', 'meute', 'ours'])[1 + floor(random() * 3)::integer];
  c := public.sovarka_foret_faune_creer_interne(p_acteur, p_vue, v_type);   -- foret_meute_trois_loups_v1
  PERFORM public.sovarka_foret_journal_groupe_interne(p_acteur, 'rencontre', jsonb_build_object('creature', v_type, 'nom', c->>'nom', 'a_l_arrivee', true));
  RETURN jsonb_build_object('rencontre', 'attaque', 'a_l_arrivee', true, 'creature', v_type, 'nom', c->>'nom', 'pnj', c->>'pnj',
    'id', (c->>'id')::bigint, 'combattants', c->'combattants');
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_rencontre_arrivee_interne(text, integer) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Issue du combat : butin au chef, une fois, selon les bêtes abattues ; journal des membres engagés
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_foret_issue_combat_interne(p_pnj text, p_leader text, p_issue text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE e record; c jsonb; o jsonb; v_dep jsonb; v_livre jsonb := '[]'::jsonb; k integer := 0; v_b bigint;
        v_total integer; v_abattus integer := 0; v_mult integer;
BEGIN
  -- combat_faune_hostilite_v1
  -- foret_combat_journal_v1 : l'issue s'écrit dans le journal du joueur, plus dans sa boîte mail.
  -- foret_meute_butin_v1 (Fred, 22/11/2026) : tout le butin au chef, une seule fois ; pour la meute, par loup abattu.
  SELECT * INTO e FROM public.sovarka_foret_rencontres WHERE pnj_id = p_pnj FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue); END IF;
  PERFORM public.sovarka_foret_faune_retirer_interne(p_pnj);
  IF e.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'deja', true); END IF;
  c := public.sovarka_foret_creature_interne(e.creature);
  v_total := greatest(1, coalesce((c->>'loups')::integer, 1));
  SELECT b.id INTO v_b FROM public.batailles b WHERE b.contexte->>'type' = 'faune' AND b.contexte->>'cible' = p_pnj ORDER BY b.id DESC LIMIT 1;
  IF v_b IS NOT NULL THEN
    SELECT count(*) INTO v_abattus FROM public.batailles_engagements be JOIN public.batailles b ON b.id = be.bataille_id
     WHERE be.bataille_id = v_b AND be.camp = b.camp_b AND be.pnj_id IS NOT NULL AND be.sorti_round IS NOT NULL
       AND coalesce(be.etat_final, '') NOT IN ('replie', 'indisponible');
  END IF;
  v_mult := CASE WHEN p_issue NOT IN ('tues', 'neutralises') THEN 0
                 WHEN v_total > 1 THEN least(v_total, greatest(1, v_abattus)) ELSE 1 END;
  IF v_total = 1 THEN v_abattus := CASE WHEN p_issue IN ('tues', 'neutralises') THEN 1 ELSE 0 END; END IF;
  IF p_issue IN ('tues', 'neutralises', 'fuite') THEN
    FOR o IN SELECT public.sovarka_matiere_objet_interne(b->>'cle', (b->>'qte')::integer * v_mult, 'Butin : ' || lower(c->>'nom') || ' de la forêt de Krasnov.')
               FROM jsonb_array_elements(c->'butin') b WHERE v_mult > 0
             UNION ALL
             SELECT public.sovarka_matiere_objet_interne('bois', (floor(random() * 2)::integer + 1) * 2, 'Seconde coupe dans la forêt profonde de Krasnov.')
             UNION ALL
             SELECT jsonb_build_object('name', 'Dent d''ours', 'icon', 'ti-trophy', 'stackable', true, 'stackKey', 'dent_ours',
                      'qty', (c->>'dents')::integer, 'legal', true, 'desc', 'Trophée de la forêt profonde de Krasnov : la preuve qu''on a vaincu un ours.')
              WHERE c ? 'dents' AND v_mult > 0
             UNION ALL  /* krasnov_graisse_ours_v1 : 10 pots de graisse d'ours par ours tué */
             SELECT public.graisse_objet_interne('graisse_ours', 10) WHERE e.creature = 'ours' AND v_mult > 0 LOOP
      k := k + 1;
      v_dep := public.inventaire_deposer_interne(p_leader, o);
      IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN
        INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
        VALUES ('foret-krasnov-' || e.id || '-' || k, p_leader, 'Forêt de Krasnov', to_jsonb(o::text)) ON CONFLICT (id) DO NOTHING;
      END IF;
      v_livre := v_livre || o;
    END LOOP;
  END IF;
  IF p_issue IN ('tues', 'neutralises') THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'vaincu', clos_le = now() WHERE id = e.id;
  ELSIF p_issue = 'fuite' THEN
    UPDATE public.sovarka_foret_rencontres SET statut = 'fuite', clos_le = now() WHERE id = e.id;
  ELSE
    UPDATE public.sovarka_foret_rencontres SET statut = 'perdu', clos_le = now() WHERE id = e.id;
  END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = e.bucheron;
  -- Journal : chaque membre engagé reçoit l'issue et le butin remis au chef (le chef l'écrit à l'écran).
  IF v_b IS NOT NULL THEN
    INSERT INTO public.sovarka_foret_journal (destinataire, cle, params, bataille)
    SELECT DISTINCT be.personnage, 'combat', jsonb_build_object('chef', p_leader, 'creature', e.creature, 'nom', c->>'nom', 'issue', p_issue,
             'abattus', v_abattus, 'total', v_total,
             'butin', (SELECT coalesce(jsonb_agg(jsonb_build_object('nom', x->>'name', 'qte', (x->>'qty')::integer)), '[]'::jsonb) FROM jsonb_array_elements(v_livre) x)), v_b
      FROM public.batailles_engagements be
     WHERE be.bataille_id = v_b AND be.personnage IS NOT NULL AND be.personnage <> p_leader;
  END IF;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'creature', e.creature, 'butin', v_livre, 'abattus', v_abattus, 'total', v_total);
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_issue_combat_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 6. Rapport de combat : une ligne par combattant et par round, adversaire nommé (hors batailles militaires)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.combat_rapport_lignes_interne(p_bataille bigint, p_camp text, p_round integer, p_actions jsonb)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE b public.batailles%ROWTYPE; v_lignes jsonb; v_debout text; n integer; v_nom text;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille;
  IF NOT FOUND OR coalesce(b.contexte->>'type', '') NOT IN ('civil', 'squatteurs', 'faune', 'garde_acces') THEN RETURN '{}'::jsonb; END IF;
  WITH l AS (
    SELECT e.id, (e.camp = p_camp) AS mien,
           CASE WHEN e.personnage IS NOT NULL THEN
                  CASE WHEN e.camp = p_camp OR b.contexte->>'type' IN ('faune', 'garde_acces') THEN e.personnage
                       ELSE coalesce(public.crim_designation_bataille_interne(b.id, e.personnage), e.personnage) END
                ELSE coalesce(m.nom, 'Adversaire') END AS nom,
           (e.personnage IS NOT NULL AND e.personnage IN (coalesce(b.leader_a, ''), coalesce(b.leader_b, ''), coalesce(b.contexte->>'acteur', ''))) AS chef,
           coalesce((SELECT sum(coalesce((a->>'perte')::integer, 0)) FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
                      WHERE a->>'cib_eng' = e.id::text), 0)::integer AS perte,
           CASE WHEN e.sorti_round IS NOT NULL AND e.sorti_round <= p_round THEN
                  CASE e.etat_final WHEN 'mort' THEN 'mort' WHEN 'neutralise' THEN 'coma' WHEN 'replie' THEN 'fuite'
                                    WHEN 'rendu' THEN 'rendu' WHEN 'capture' THEN 'capture'
                                    ELSE CASE WHEN e.personnage IS NOT NULL THEN 'coma' ELSE 'fuite' END END
                WHEN e.personnage IS NOT NULL AND (coalesce(d.pa, 0) <= 0 OR coalesce(d.hp, 100) <= 0) THEN 'coma'
                WHEN e.personnage IS NULL AND m.statut = 'mort' THEN 'mort' END AS etat,
           CASE WHEN e.camp = p_camp AND e.personnage IS NOT NULL THEN greatest(0, coalesce(d.pa, 0)) END AS pa
      FROM public.batailles_engagements e
      LEFT JOIN public.personnages_donnees d ON d.name = e.personnage
      LEFT JOIN public.pnj_membres m ON m.id = e.pnj_id
     WHERE e.bataille_id = p_bataille
  )
  SELECT jsonb_agg(jsonb_build_object('eng', id, 'mien', mien, 'nom', nom, 'chef', chef, 'perte', perte, 'etat', etat, 'pa', pa)
                   ORDER BY (NOT mien), (NOT chef), id),
         string_agg(nom, ', ' ORDER BY id) FILTER (WHERE NOT mien AND etat IS NULL),
         count(*) FILTER (WHERE NOT mien AND etat IS NULL)
    INTO v_lignes, v_debout, n FROM l;
  v_nom := CASE WHEN b.contexte->>'type' = 'faune'
                THEN public.sovarka_foret_creature_interne((SELECT r.creature FROM public.sovarka_foret_rencontres r WHERE r.pnj_id = b.contexte->>'cible' LIMIT 1))->>'nom' END;
  RETURN jsonb_build_object('lignes', coalesce(v_lignes, '[]'::jsonb), 'adversaire_nom', v_nom,
    'adversaire_estime', CASE WHEN coalesce(n, 0) = 0 THEN jsonb_build_object('libelle', 'plus aucun adversaire debout')
                              ELSE jsonb_build_object('libelle', v_debout, 'effectif_min', n, 'effectif_max', n) END);
END $function$;
REVOKE ALL ON FUNCTION public.combat_rapport_lignes_interne(bigint, text, integer, jsonb) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 7. Raccords contrôlés dans les fonctions communes (texte de production)
-- ---------------------------------------------------------------------------------------------------------------
-- 7a. Rapport du round : lignes par combattant.
SELECT pg_temp.rp_remplacer('public.militaire_bataille_rapport(bigint,text,text,integer,jsonb,integer,integer)'::regprocedure,
  $a$'termine', (p_reste_moi = 0 OR p_reste_adverse = 0));$a$,
  $b$'termine', (p_reste_moi = 0 OR p_reste_adverse = 0)) || public.combat_rapport_lignes_interne(p_bataille_id, p_camp, p_round, p_actions); /* combat_rapport_lignes_v1 */$b$,
  1, 'combat_rapport_lignes_v1');

-- 7b. Morsure des loups (un tiers d'un coup ordinaire).
SELECT pg_temp.rp_remplacer('public.militaire_bataille_appliquer(bigint,jsonb,integer)'::regprocedure,
  $a$v_new := public.militaire_pa_restants(v_pa, v_degre);$a$,
  $b$v_new := public.militaire_pa_restants(v_pa, v_degre);
    v_new := public.sovarka_foret_morsure_interne((act->>'att_eng')::bigint, v_pa, v_new); /* foret_morsure_v1 */$b$,
  1, 'foret_morsure_v1');

-- 7c. Griffes : Loup 2 et Loup 3 retrouvent la créature de leur rencontre.
SELECT pg_temp.rp_remplacer('public.militaire_bataille_combattants(bigint,text)'::regprocedure,
  $a$WHERE r.pnj_id=m.id LIMIT 1$a$,
  $b$WHERE r.pnj_id=public.sovarka_foret_pnj_racine_interne(m.id) /* foret_meute_griffes_v1 */ LIMIT 1$b$,
  1, 'foret_meute_griffes_v1');

-- 7d. Ouverture : les autres loups de la meute entrent au combat, chacun dans son groupe.
SELECT pg_temp.rp_remplacer('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure,
  $a$PERFORM public.combat_bataille_completer_groupes_interne(b_id,'defenseur',p.current_city,p.current_building,p.current_room);$a$,
  $b$PERFORM public.combat_bataille_completer_groupes_interne(b_id,'defenseur',p.current_city,p.current_building,p.current_room);
  IF pnj LIKE 'faune:%' THEN PERFORM public.sovarka_foret_combat_meute_interne(b_id,pnj); END IF; /* foret_meute_engagements_v1 */$b$,
  1, 'foret_meute_engagements_v1');

-- 7e. Issue d'un combat de faune : un loup tué ne fait pas la victoire tant que d'autres loups sont debout.
SELECT pg_temp.rp_remplacer('public.combat_finaliser_interne(bigint)'::regprocedure,
  $a$ IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=b.camp_b AND etat_final='mort') THEN issue:='tues';$a$,
  $b$ IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=b.camp_b AND etat_final='mort')
    AND (b.contexte->>'type'<>'faune' OR NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=b.camp_b AND sorti_round IS NULL)) /* foret_meute_issue_v1 */ THEN issue:='tues';$b$,
  1, 'foret_meute_issue_v1');

-- 7f. Panneau : la meute est nommée « Meute de 3 loups », pas du nom de son premier loup.
SELECT pg_temp.rp_remplacer('public.militaire_bataille_etat(bigint)'::regprocedure,
  $a$WHEN b.contexte->>'type' IN ('faune','garde_acces') THEN (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>'cible')$a$,
  $b$WHEN b.contexte->>'type' = 'faune' THEN coalesce(public.sovarka_foret_creature_interne((SELECT r.creature FROM public.sovarka_foret_rencontres r WHERE r.pnj_id = b.contexte->>'cible' LIMIT 1))->>'nom', (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>'cible')) /* foret_meute_nom_v1 */
      WHEN b.contexte->>'type' = 'garde_acces' THEN (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>'cible')$b$,
  1, 'foret_meute_nom_v1');

-- 7g. Aller : les coupes des membres repartent à zéro avec le groupe (une nouvelle vue = de nouvelles coupes).
SELECT pg_temp.rp_remplacer('public.sovarka_foret_aller(uuid,text)'::regprocedure,
  $a$DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;$a$,
  $b$DELETE FROM public.sovarka_foret_visites WHERE bucheron = a OR bucheron IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = a); /* foret_groupe_membres_v1 */$b$,
  1, 'foret_groupe_membres_v1');

-- 7h. Fuir / se laisser faire : toutes les bêtes de la rencontre se retirent ; les membres l'apprennent par le journal.
SELECT pg_temp.rp_remplacer('public.sovarka_foret_rencontre(uuid,text)'::regprocedure,
  $a$UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = e.pnj_id AND statut = 'actif';$a$,
  $b$PERFORM public.sovarka_foret_faune_retirer_interne(e.pnj_id); /* foret_meute_retrait_v1 */$b$,
  2, 'foret_meute_retrait_v1');
SELECT pg_temp.rp_remplacer('public.sovarka_foret_rencontre(uuid,text)'::regprocedure,
  $a$  r := r || jsonb_build_object('creature', e.creature, 'nom', public.sovarka_foret_creature_interne(e.creature)->>'nom')$a$,
  $b$  PERFORM public.sovarka_foret_journal_groupe_interne(a, CASE WHEN p_choix = 'fuir' THEN 'fuite' ELSE 'subir' END,
    jsonb_build_object('creature', e.creature, 'nom', public.sovarka_foret_creature_interne(e.creature)->>'nom')); /* foret_journal_groupe_v1 */
  r := r || jsonb_build_object('creature', e.creature, 'nom', public.sovarka_foret_creature_interne(e.creature)->>'nom')$b$,
  1, 'foret_journal_groupe_v1');

-- 7i. Lecture de la forêt : un membre voit ses propres coupes (le reste vient du chef).
SELECT pg_temp.rp_remplacer('public.sovarka_foret_lire()'::regprocedure,
  $a$SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = v_chef AND vue = v_vue;$a$,
  $b$SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = a AND vue = v_vue; /* foret_groupe_membres_v1 */$b$,
  1, 'foret_groupe_membres_v1');

COMMIT;
