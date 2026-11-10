-- SOVARKA : FORET PROFONDE DE KRASNOV (idee de Fred du 21/10/2026, issue #72 ; decisions du 09/11 a 23 h 41 et du
-- 10/11/2026 ; GAME-DESIGN-NOVOMIRSK.md, point 5 « Exploitation forestiere de Krasnov », qui prime sur l'issue).
--
-- - L'entree (zone de recolte de l'exploitation forestiere) est sure : extraction normale.
-- - « S'enfoncer dans la foret » : arrivee sur l'une des 4 vues de foret profonde (1 chance sur 4 chacune).
-- - Sur les 4 vues, « Couper du bois » rapporte le double d'une recolte (2 a 4 bois) : 2 coupes au plus sur les vues 1
--   et 2, 1 sur les vues 3 et 4. Sur les vues 3 et 4, la tentative suivante declenche la rencontre : vue 3 = un
--   attaquant tire au sort (loup solitaire, meute de loups, ours : un tiers chacun), vue 4 = toujours Olga, qui
--   nourrit tout le groupe (effet d'un repas ordinaire, +2 PA au prochain Dormir). A la seconde coupe des vues 1 et 2,
--   un bruit survient une fois sur deux et finit en fausse alerte.
-- - Face a l'attaquant : combattre (moteur de combat universel, la creature est un PNJ de combat comme les
--   squatteurs), fuir (on lache le bois coupe sur la vue et on retrouve l'entree de la foret), ou ne pas se defendre
--   (« se laisser bouffer » : memes suites qu'un combat perdu, les PA tombent a 0 et l'on se reveille a l'hopital).
--   Attaquant battu : le leader recoit le butin (loup 3 tissus + 3 viande ; meute 9 tissus + 6 viande ; ours
--   10 tissus + 9 viande + 2 dents d'ours, objet de collection).
-- - En groupe, la limite de coupes compte par groupe : seul le chef coupe (un membre doit quitter le groupe).
-- - « Revenir a l'entree de la foret » n'y mene qu'a 20 % ; sinon on retombe sur l'une des 4 vues (20 % chacune).
--   Aucun autre chemin : on ne sort pas de la foret profonde par la rue, ni ne choisit sa vue.
-- Valeurs proposees par Claude, a valider par Fred : 2 PA par coupe (comme la recolte), la tentative qui declenche
-- la rencontre coute aussi ses 2 PA ; les coupes de la foret profonde ne comptent pas dans les 2 recoltes du jour ;
-- caracteristiques de combat des creatures (loup 9 / meute 13 / ours 16 en combat rapproche).
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

-- 1. Les quatre vues : pieces de l'exploitation forestiere de Krasnov.
UPDATE public.navigation_lieux_regles
   SET pieces = '["zone_recolte", "foret_vue_1", "foret_vue_2", "foret_vue_3", "foret_vue_4"]'::jsonb
 WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'zone-production';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'ville_b'
       AND batiment = 'zone-production' AND pieces ? 'foret_vue_4') THEN
    RAISE EXCEPTION 'exploitation forestiere de Krasnov absente des regles de navigation';
  END IF;
END $$;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, 0 FROM (VALUES ('foret_couper', 2), ('foret_aller', 0), ('foret_rencontre', 0)) x(fn, pa)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = x.pa AND o.cost = 0);
INSERT INTO public.pa_bonus_differes (source, montant) VALUES ('repas_olga', 2) ON CONFLICT (source) DO NOTHING;

-- 2. Etat : la visite en cours du bucheron (chef du groupe) et les rencontres.
CREATE TABLE IF NOT EXISTS public.sovarka_foret_visites (
  bucheron text PRIMARY KEY,
  vue integer NOT NULL CHECK (vue BETWEEN 1 AND 4),
  coupes integer NOT NULL DEFAULT 0,
  bois integer NOT NULL DEFAULT 0,
  arrivee timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sovarka_foret_rencontres (
  id bigserial PRIMARY KEY,
  bucheron text NOT NULL,
  vue integer NOT NULL,
  creature text NOT NULL CHECK (creature IN ('loup', 'meute', 'ours', 'olga')),
  pnj_id text,
  statut text NOT NULL CHECK (statut IN ('en_attente', 'vaincu', 'perdu', 'fuite', 'devore', 'nourri')),
  cree_le timestamptz NOT NULL DEFAULT now(),
  clos_le timestamptz
);
CREATE INDEX IF NOT EXISTS sovarka_foret_rencontres_attente ON public.sovarka_foret_rencontres (bucheron) WHERE statut = 'en_attente';
CREATE TABLE IF NOT EXISTS public.sovarka_foret_actes (
  acteur text NOT NULL,
  requete uuid NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete)
);
ALTER TABLE public.sovarka_foret_visites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_foret_rencontres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_foret_actes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_foret_visites, public.sovarka_foret_rencontres, public.sovarka_foret_actes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.sovarka_foret_rencontres_id_seq FROM PUBLIC, anon, authenticated;

-- 3. Outils.
-- Vue de foret ou se tient le PJ (0 = entree, NULL = ailleurs).
CREATE OR REPLACE FUNCTION public.sovarka_foret_vue_interne(p_nom text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN d.current_room = 'zone_recolte' THEN 0
              WHEN d.current_room ~ '^foret_vue_[1-4]$' THEN right(d.current_room, 1)::integer END
    FROM public.personnages_donnees d
   WHERE d.name = p_nom AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production';
$$;

CREATE OR REPLACE FUNCTION public.sovarka_foret_creature_interne(p_type text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type
    WHEN 'loup' THEN '{"nom":"Loup solitaire","vol":9,"per":10,"dup":8,"butin":[{"cle":"textile","qte":3},{"cle":"viande","qte":3}]}'::jsonb
    WHEN 'meute' THEN '{"nom":"Meute de loups","vol":13,"per":12,"dup":10,"butin":[{"cle":"textile","qte":9},{"cle":"viande","qte":6}]}'::jsonb
    WHEN 'ours' THEN '{"nom":"Ours","vol":16,"per":12,"dup":6,"butin":[{"cle":"textile","qte":10},{"cle":"viande","qte":9}],"dents":2}'::jsonb
  END;
$$;

-- Deplace le chef et son groupe dans une piece de l'exploitation forestiere, par le moteur de navigation commun.
CREATE OR REPLACE FUNCTION public.sovarka_foret_deplacer_interne(p_nom text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('rp.foret_passage', 'on', true);
  v := public.navigation_commander_personnage_interne(p_nom, 'piece', 'zone-production', p_piece);
  PERFORM set_config('rp.foret_passage', 'off', true);
  RETURN v;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_deplacer_interne(text, text) FROM PUBLIC, anon, authenticated;

-- 4. Lecture : position, coupes restantes, rencontre en attente.
CREATE OR REPLACE FUNCTION public.sovarka_foret_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_vue integer; v_chef text; s record; r record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF v_vue IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_chef := coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre = a), a);
  SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = v_chef AND vue = v_vue;
  SELECT * INTO r FROM public.sovarka_foret_rencontres WHERE bucheron = v_chef AND statut = 'en_attente' ORDER BY id DESC LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'vue', v_vue, 'chef', v_chef, 'membre', v_chef <> a,
    'coupes', coalesce(s.coupes, 0), 'coupes_bois', CASE WHEN v_vue IN (1, 2) THEN 2 WHEN v_vue IN (3, 4) THEN 1 ELSE 0 END,
    'rencontre', CASE WHEN r.id IS NULL THEN NULL ELSE jsonb_build_object('id', r.id, 'creature', r.creature, 'pnj', r.pnj_id,
      'nom', public.sovarka_foret_creature_interne(r.creature)->>'nom') END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_lire() TO authenticated;

-- 5. S'enfoncer dans la foret / revenir a l'entree (tirages au serveur).
CREATE OR REPLACE FUNCTION public.sovarka_foret_aller(p_requete uuid, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); x record; v_vue integer; v_dest integer; v jsonb; r jsonb; v_piece text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_sens NOT IN ('enfoncer', 'revenir') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:foret:' || a, 0));
  SELECT * INTO x FROM public.sovarka_foret_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chef_de_groupe_requis'); END IF;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF v_vue IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF p_sens = 'enfoncer' AND v_vue <> 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_foret'); END IF;
  IF p_sens = 'revenir' AND v_vue = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_l_entree'); END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron = a AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rencontre_en_cours'); END IF;
  v_dest := CASE WHEN p_sens = 'enfoncer' THEN 1 + floor(random() * 4)::integer
                 ELSE CASE WHEN random() < 0.2 THEN 0 ELSE 1 + floor(random() * 4)::integer END END;
  v_piece := CASE WHEN v_dest = 0 THEN 'zone_recolte' ELSE 'foret_vue_' || v_dest END;
  v := public.sovarka_foret_deplacer_interne(a, v_piece);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
  IF v_dest > 0 THEN INSERT INTO public.sovarka_foret_visites (bucheron, vue) VALUES (a, v_dest); END IF;
  r := jsonb_build_object('ok', true, 'sens', p_sens, 'vue', v_dest, 'room', v_piece, 'perdu', p_sens = 'revenir' AND v_dest > 0,
    'membres', v->'membres', 'positions', v->'positions');
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r);
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_aller(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_aller(uuid, text) TO authenticated;

-- 6. Couper du bois en foret profonde.
CREATE OR REPLACE FUNCTION public.sovarka_foret_couper(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); x record; s record; v_vue integer; v_k integer; v_max integer; v_paie jsonb;
        v_q integer; v_dep jsonb; r jsonb; v_type text; c jsonb; v_id bigint; v_pnj text; v_nourris jsonb; v_bonus integer; v_alerte text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:foret:' || a, 0));
  SELECT * INTO x FROM public.sovarka_foret_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quitter_groupe_pour_couper'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF coalesce(v_vue, 0) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_foret_profonde'); END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active(a)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron = a AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rencontre_en_cours'); END IF;
  SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = a FOR UPDATE;
  IF NOT FOUND OR s.vue <> v_vue THEN
    DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
    INSERT INTO public.sovarka_foret_visites (bucheron, vue) VALUES (a, v_vue) RETURNING * INTO s;
  END IF;
  v_k := s.coupes + 1;
  v_max := 2;  -- vues 1 et 2 : deux coupes ; vues 3 et 4 : une coupe, puis la rencontre
  IF v_k > v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'coupes_epuisees'); END IF;
  IF NOT (v_vue IN (3, 4) AND v_k = 2)
     AND (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(a, 'foret_couper', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.sovarka_foret_visites SET coupes = v_k WHERE bucheron = a;

  IF v_vue = 4 AND v_k = 2 THEN
    -- Olga nourrit tout le groupe present.
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
    r := jsonb_build_object('ok', true, 'rencontre', 'olga', 'nourris', v_nourris, 'bonus', v_bonus);

  ELSIF v_vue = 3 AND v_k = 2 THEN
    v_type := (ARRAY['loup', 'meute', 'ours'])[1 + floor(random() * 3)::integer];
    c := public.sovarka_foret_creature_interne(v_type);
    INSERT INTO public.sovarka_foret_rencontres (bucheron, vue, creature, statut) VALUES (a, 3, v_type, 'en_attente') RETURNING id INTO v_id;
    v_pnj := 'faune:krasnov:' || v_id;
    -- PNJ de combat sans emploi ni proprietaire, comme les squatteurs (famille technique employe).
    INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_pnj, 'employe', c->>'nom', 'soviet', 'ville_b', 'zone-production', 'foret_vue_3', 'beta', public.pnj_pa_max(),
            4, 4, (c->>'vol')::integer, (c->>'per')::integer, (c->>'dup')::integer, 4)
    ON CONFLICT (id) DO NOTHING;
    UPDATE public.sovarka_foret_rencontres SET pnj_id = v_pnj WHERE id = v_id;
    r := jsonb_build_object('ok', true, 'rencontre', 'attaque', 'creature', v_type, 'nom', c->>'nom', 'pnj', v_pnj, 'id', v_id);

  ELSE
    v_q := (floor(random() * 2)::integer + 1) * 2;
    v_dep := public.inventaire_deposer_interne(a, public.sovarka_matiere_objet_interne('bois', v_q, 'Coupé dans la forêt profonde de Krasnov.'));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'sovarka_foret_couper: depot refuse %', v_dep; END IF;
    UPDATE public.sovarka_foret_visites SET bois = bois + v_q WHERE bucheron = a;
    IF v_vue IN (1, 2) AND v_k = 2 AND random() < 0.5 THEN
      v_alerte := (ARRAY['Ce n''était qu''un lièvre, qui détale dans la neige.',
                         'Un tractoriste perdu sort des fourrés et vous demande le chemin du kolkhoze.',
                         'Une branche cède sous le poids de la neige. Rien de plus.',
                         'Un élan vous regarde un long moment, puis s''en va sans se presser.',
                         'Un vieux chasseur vous salue d''un signe de tête et disparaît entre les troncs.'])[1 + floor(random() * 5)::integer];
    END IF;
    r := jsonb_build_object('ok', true, 'quantite', v_q, 'fausse_alerte', v_alerte,
      'coupes_restantes', CASE WHEN v_vue IN (1, 2) THEN 2 - v_k ELSE 0 END);
  END IF;

  r := r || jsonb_build_object('vue', v_vue, 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg')
         || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory');
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_couper(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_couper(uuid) TO authenticated;

-- 7. Face a l'attaquant : fuir ou ne pas se defendre (combattre passe par combat_ouvrir).
CREATE OR REPLACE FUNCTION public.sovarka_foret_rencontre(p_requete uuid, p_choix text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); x record; e record; s record; l jsonb; v_perdu integer := 0; v jsonb; r jsonb; v_victimes jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_choix NOT IN ('fuir', 'subir') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:foret:' || a, 0));
  SELECT * INTO x FROM public.sovarka_foret_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chef_de_groupe_requis'); END IF;
  SELECT * INTO e FROM public.sovarka_foret_rencontres WHERE bucheron = a AND statut = 'en_attente' ORDER BY id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_rencontre'); END IF;
  IF EXISTS (SELECT 1 FROM public.batailles_engagements be JOIN public.batailles b ON b.id = be.bataille_id
              WHERE be.pnj_id = e.pnj_id AND b.statut = 'en_cours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'combat_en_cours'); END IF;

  IF p_choix = 'fuir' THEN
    -- On lache le bois coupe sur cette vue (ce qu'il en reste dans l'inventaire du bucheron).
    SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = a;
    PERFORM 1 FROM public.personnages_donnees WHERE name = a FOR UPDATE;
    l := public.sovarka_inventaire_ligne_interne((SELECT inventory FROM public.personnages_donnees WHERE name = a), ARRAY['bois']);
    v_perdu := least(coalesce(s.bois, 0), (l->>'qte')::integer);
    IF v_perdu > 0 THEN PERFORM public.sovarka_inventaire_retirer_interne(a, l, v_perdu); END IF;
    UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = e.pnj_id AND statut = 'actif';
    UPDATE public.sovarka_foret_rencontres SET statut = 'fuite', clos_le = now() WHERE id = e.id;
    v := public.sovarka_foret_deplacer_interne(a, 'zone_recolte');
    IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'sovarka_foret_fuite: deplacement refuse %', v; END IF;
    DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
    r := jsonb_build_object('ok', true, 'choix', 'fuir', 'bois_perdu', v_perdu, 'room', 'zone_recolte', 'membres', v->'membres', 'positions', v->'positions');
  ELSE
    -- « Se laisser bouffer » : memes suites qu'un combat perdu ; PA a 0, hospitalisation automatique a la validation.
    UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = e.pnj_id AND statut = 'actif';
    UPDATE public.sovarka_foret_rencontres SET statut = 'devore', clos_le = now() WHERE id = e.id;
    DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
    WITH g AS (
      SELECT d.name FROM public.personnages_donnees d
       WHERE (d.name = a OR d.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = a))
         AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production' AND d.current_room = 'foret_vue_3'
    ), u AS (
      UPDATE public.personnages_donnees d SET pa = 0, updated_at = now() FROM g WHERE d.name = g.name AND coalesce(d.pa, 0) > 0 RETURNING d.name)
    SELECT coalesce(jsonb_agg(name ORDER BY name), '[]'::jsonb) INTO v_victimes FROM u;
    r := jsonb_build_object('ok', true, 'choix', 'subir', 'victimes', v_victimes, 'pa', 0);
  END IF;
  r := r || jsonb_build_object('creature', e.creature, 'nom', public.sovarka_foret_creature_interne(e.creature)->>'nom')
         || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory');
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_rencontre(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_rencontre(uuid, text) TO authenticated;

-- 8. Issue d'un combat contre une creature : butin au leader, la creature disparait.
CREATE OR REPLACE FUNCTION public.sovarka_foret_issue_combat_interne(p_pnj text, p_leader text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e record; c jsonb; o jsonb; v_dep jsonb; v_livre jsonb := '[]'::jsonb; k integer := 0;
BEGIN
  SELECT * INTO e FROM public.sovarka_foret_rencontres WHERE pnj_id = p_pnj FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue); END IF;
  UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = p_pnj AND statut = 'actif';
  IF e.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'deja', true); END IF;
  IF p_issue IN ('tues', 'neutralises') THEN
    c := public.sovarka_foret_creature_interne(e.creature);
    FOR o IN SELECT public.sovarka_matiere_objet_interne(b->>'cle', (b->>'qte')::integer, 'Butin : ' || lower(c->>'nom') || ' de la forêt de Krasnov.')
               FROM jsonb_array_elements(c->'butin') b
             UNION ALL
             SELECT jsonb_build_object('name', 'Dent d''ours', 'icon', 'ti-trophy', 'stackable', true, 'stackKey', 'dent_ours',
                      'qty', (c->>'dents')::integer, 'legal', true, 'desc', 'Trophée de la forêt profonde de Krasnov : la preuve qu''on a vaincu un ours.')
              WHERE c ? 'dents' LOOP
      k := k + 1;
      v_dep := public.inventaire_deposer_interne(p_leader, o);
      IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN
        -- Inventaire plein : le butin attend en reception, jamais perdu.
        INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
        VALUES ('foret-krasnov-' || e.id || '-' || k, p_leader, 'Forêt de Krasnov', to_jsonb(o::text)) ON CONFLICT (id) DO NOTHING;
      END IF;
      v_livre := v_livre || o;
    END LOOP;
    UPDATE public.sovarka_foret_rencontres SET statut = 'vaincu', clos_le = now() WHERE id = e.id;
    PERFORM public.mail_systeme_poser_interne('Événement', p_leader, 'Forêt de Krasnov',
      'Vous avez vaincu : ' || (c->>'nom') || '. Le butin (peaux, viande' || CASE WHEN c ? 'dents' THEN ', dents d''ours' ELSE '' END
      || ') vous revient, à partager avec votre groupe.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  ELSE
    UPDATE public.sovarka_foret_rencontres SET statut = 'perdu', clos_le = now() WHERE id = e.id;
  END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = e.bucheron;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'creature', e.creature, 'butin', v_livre);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_foret_issue_combat_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- 9. Raccords au moteur de combat (patchs en place, ancrages verifies).
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  -- Une creature de la foret n'est pas une victime : bataille de type « faune », jamais tracee comme agression.
  d := pg_get_functiondef('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure);
  IF position('sovarka_foret_faune_v1' IN d) = 0 THEN
    avant := E'jsonb_build_object(''type'',CASE WHEN terrain IS NULL THEN ''civil'' ELSE ''squatteurs'' END,';
    apres := E'jsonb_build_object(''type'',CASE WHEN terrain IS NOT NULL THEN ''squatteurs'' WHEN pnj LIKE ''faune:%'' THEN ''faune'' /* sovarka_foret_faune_v1 */ ELSE ''civil'' END,';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_ouvrir_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  d := pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure);
  IF position('sovarka_foret_faune_v1' IN d) = 0 THEN
    avant := E'b.contexte->>''type'' NOT IN (''civil'',''squatteurs'')';
    apres := E'b.contexte->>''type'' NOT IN (''civil'',''squatteurs'',''faune'')';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_finaliser_interne : ancrage 1 introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := E' IF b.contexte->>''type''=''squatteurs'' THEN';
    apres := E' -- sovarka_foret_faune_v1 : creature de la foret de Krasnov, butin au leader.\n'
          || E' IF b.contexte->>''type''=''faune'' THEN\n'
          || E'  v:=public.sovarka_foret_issue_combat_interne(b.contexte->>''cible'',b.contexte->>''acteur'',issue);\n'
          || E' ELSIF b.contexte->>''type''=''squatteurs'' THEN';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_finaliser_interne : ancrage 2 introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $raccord$;

-- 10. Navigation du joueur : on n'entre en foret profonde, on n'y change de vue et on n'en sort que par les ordres de
--     la foret (tirages au serveur). Les deplacements du moteur (hospitalisation, decrochage de combat) restent libres.
CREATE OR REPLACE FUNCTION public.navigation_commander_interne(p_mode text, p_destination text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; v_dans boolean; v_vers boolean;
BEGIN
  -- sovarka_foret_chemins_v1 (10/11/2026)
  IF moi IS NOT NULL AND current_setting('rp.foret_passage', true) IS DISTINCT FROM 'on' THEN
    SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = moi;
    IF p.country = 'soviet' AND p.current_city = 'ville_b' THEN
      v_dans := p.current_building = 'zone-production' AND coalesce(p.current_room, '') LIKE 'foret_vue_%';
      v_vers := p_mode = 'piece' AND p_destination = 'zone-production' AND coalesce(p_piece, '') LIKE 'foret_vue_%';
      IF (v_dans OR v_vers) AND (p_mode <> 'piece' OR p.current_building IS DISTINCT FROM p_destination OR p.current_room IS DISTINCT FROM p_piece) THEN
        RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN v_dans THEN 'foret_perdu' ELSE 'foret_chemin_aleatoire' END);
      END IF;
    END IF;
  END IF;
  RETURN public.navigation_commander_personnage_interne(moi, p_mode, p_destination, p_piece);
END $$;

-- 11. Controles structurels.
DO $$
BEGIN
  IF position('sovarka_foret_faune_v1' IN pg_get_functiondef('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure)) = 0
     OR position('sovarka_foret_faune_v1' IN pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure)) = 0
     OR position('sovarka_foret_chemins_v1' IN pg_get_functiondef('public.navigation_commander_interne(text,text,text)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'ville_b'
                     AND batiment = 'zone-production' AND pieces ? 'foret_vue_3') THEN
    RAISE EXCEPTION 'sovarka_foret_profonde : controle structurel en echec';
  END IF;
END $$;

COMMIT;
