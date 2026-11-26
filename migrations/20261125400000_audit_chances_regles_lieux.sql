-- Mission du soir du 25/11/2026 (Claude), bloc 1A (points 1.1, 1.3, 1.4) — APPLIQUÉE en production le 25/11/2026 en fin de soirée (feu vert de Fred, contrôlée en lecture). Après 20261125130000 (chances réelles).
-- Audit des chances (docs/nuit/AUDIT-CHANCES-20261125.md), décisions de Fred du 25/11 au soir :
--   • 1.3e Falsifier les listes électorales : un échec coûte 2 jours de détention (au lieu de 20).
--   • 1.4b Truquer le dépouillement : un échec coûte 3 jours (au lieu de 20) ; Bourrer les urnes reste à 1 jour.
--   • 1.4a Contrebande au port : chance plafonnée à 85 % ; la douane peut repérer la manœuvre sur un échec comme sur une
--     réussite ; un échec repéré = saisie de la marchandise de contrebande portée sur soi et avis de recherche.
--   • 1.3b « Écouter les rumeurs » chez Galina Karpova, poissonnière de Novomirsk (étal) : lieu déclaré au serveur (95 %, 0 PA).
--   • 1.3c « Inspecter les cargaisons » : le quai de Sovarka est dans le bâtiment port-novomirsk (data.js) ; le serveur
--     attendait port-sovarka. Les deux sont acceptés.
--   • 1.3a « Mobiliser les membres » (siège syndical) ne passe plus par l'intervention de police : l'écran ouvre les actions de
--     l'organisation syndicale du joueur (manifestation, grève), chacune à son propre coût. Le tarif de l'ordre « mobiliser »
--     passe de 2 PA (jamais débités par un serveur) à 0 dans ordres_couts, comme data.js et le seed régénéré.
--   • 1.1 « Vos chances réelles : X % » : la chance d'un ordre est sortie dans une fonction que l'ordre ET la lecture des
--     chances appellent (même formule, aucune règle changée) : fraudes électorales, contrebande, évasion, rébellion,
--     écouter les rumeurs, inspecter les cargaisons, contester des résultats, falsifier un document, voler du matériel de
--     chantier, incendier (même brique crim_incendie_taux_interne que l'ordre), corruption du directeur et d'un gardien du QHS, ordres génériques (fuite d'information, soins sans trace).
--     ordres_chances_lire les lit par ordres_chances_audit_interne (raccord contrôlé, marque audit_chances_soir_v1).
-- Sans cette migration : l'écran n'affiche pas de chance pour ces ordres (lecture vide, aucune erreur) et le serveur garde
-- ses règles actuelles.
--
-- Contrôles en lecture après application :
--   SELECT position('audit_chances_fraude_jours_v1' in pg_get_functiondef('public.fraude_electorale_tenter(text,text,text,text,integer)'::regprocedure)) > 0
--      AND position('audit_chances_fraude_taux_v1' in pg_get_functiondef('public.fraude_electorale_tenter(text,text,text,text,integer)'::regprocedure)) > 0;  -- vrai
--   SELECT position('audit_chances_contrebande_v1' in pg_get_functiondef('public.crime_contrebande(integer,integer)'::regprocedure)) > 0;        -- vrai
--   SELECT position('audit_chances_evasion_v1' in pg_get_functiondef('public.detention_tenter_evasion(integer,integer,boolean)'::regprocedure)) > 0
--      AND position('audit_chances_rebellion_v1' in pg_get_functiondef('public.detention_se_rebeller(integer,integer)'::regprocedure)) > 0;       -- vrai
--   SELECT position('audit_chances_poissonniere_v1' in pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure)) > 0;     -- vrai
--   SELECT position('audit_chances_port_novomirsk_v1' in pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure)) > 0
--      AND position('audit_chances_inspection_v1' in pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure)) > 0;    -- vrai
--   SELECT position('audit_chances_contester_v1' in pg_get_functiondef('public.election_contester(text,text,integer,integer)'::regprocedure)) > 0
--      AND position('audit_chances_falsifier_v1' in pg_get_functiondef('public.crime_falsifier(text,integer,integer)'::regprocedure)) > 0
--      AND position('audit_chances_vol_chantier_v1' in pg_get_functiondef('public.crime_voler_materiaux(text,text,integer,integer,boolean)'::regprocedure)) > 0;  -- vrai
--   SELECT position('audit_chances_soir_v1' in pg_get_functiondef('public.ordres_chances_lire(text[],text)'::regprocedure)) > 0;              -- vrai
--   SELECT string_agg(pa || '/' || cost, ',') FROM public.ordres_couts WHERE fn = 'mobiliser';                                             -- 0/0
--   SELECT has_function_privilege('authenticated', 'public.ordres_chances_audit_interne(text,text)', 'EXECUTE');                           -- faux
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

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder_re(p_fn regprocedure, p_motif text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  SELECT count(*) INTO n FROM regexp_matches(d, p_motif, 'g');
  IF n <> 1 THEN RAISE EXCEPTION '% : ancrage introuvable ou multiple (% occurrences)', p_fn, n; END IF;
  EXECUTE regexp_replace(d, p_motif, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Fraudes électorales : jours de détention (1.3e, 1.4b) et chance unique ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fraude_taux_interne(p_base integer, p_dis numeric)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT greatest(5, least(95, p_base + round((coalesce(p_dis, 50) - 50) / 5)::integer)) /* audit_chances_fraude_taux_v1 */
$$;

CREATE OR REPLACE FUNCTION public.fraude_chance_interne(p_nom text, p_type text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.fraude_taux_interne(CASE p_type WHEN 'falsification_listes' THEN 70 WHEN 'bourrage_urnes' THEN 60
                                                WHEN 'trucage_depouillement' THEN 75 END,
           coalesce(CASE WHEN jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric END, 50))
    FROM public.personnages_donnees d WHERE d.name = p_nom AND p_type IN ('falsification_listes', 'bourrage_urnes', 'trucage_depouillement')
$$;

SELECT pg_temp.rp_remplacer('public.fraude_electorale_tenter(text,text,text,text,integer)'::regprocedure,
  $a$v_base := 70; v_jours := 20;
    WHEN 'bourrage_urnes' THEN v_fn := 'bourrer_urnes'; v_pa := 1; v_base := 60; v_jours := 1;
    WHEN 'trucage_depouillement' THEN v_fn := 'truquer_depouillement'; v_pa := 2; v_base := 75; v_jours := 20;$a$,
  $b$v_base := 70; v_jours := 2; /* audit_chances_fraude_jours_v1 : décision de Fred, 25/11 */
    WHEN 'bourrage_urnes' THEN v_fn := 'bourrer_urnes'; v_pa := 1; v_base := 60; v_jours := 1;
    WHEN 'trucage_depouillement' THEN v_fn := 'truquer_depouillement'; v_pa := 2; v_base := 75; v_jours := 3;$b$,
  1, 'audit_chances_fraude_jours_v1');

SELECT pg_temp.rp_remplacer('public.fraude_electorale_tenter(text,text,text,text,integer)'::regprocedure,
  $a$v_taux := greatest(5, least(95, v_base + round((v_dis - 50) / 5)::integer));$a$,
  $b$v_taux := public.fraude_taux_interne(v_base, v_dis); /* audit_chances_fraude_taux_v1 */$b$,
  1, 'audit_chances_fraude_taux_v1');

-- ── Contrebande au port (1.4a) ─────────────────────────────────────────────────────────────────────────────────────
-- Chance avant la dissuasion des hommes armés : 55 + DIS/10 + DUP/10 + 15 + pays − malus ISN, au moins 5, au plus 85.
CREATE OR REPLACE FUNCTION public.crim_contrebande_taux_interne(p_nom text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(85, greatest(5, 55 + floor(coalesce(CASE WHEN jsonb_typeof(m.resources -> 'dis') = 'number' THEN (m.resources ->> 'dis')::numeric END, 8) / 10)::integer
            + floor(coalesce((m.stats ->> 'DUP')::numeric, 8) / 10)::integer + 15
            + CASE m.country WHEN 'narco' THEN 25 WHEN 'soviet' THEN -20 WHEN 'khalija' THEN 10 ELSE 0 END
            - public.crime_malus_isn_interne(m.country, m.current_city))) /* audit_chances_contrebande_v1 */
    FROM public.personnages_donnees m WHERE m.name = p_nom
$$;

CREATE OR REPLACE FUNCTION public.crime_contrebande(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false; v_saisie integer := 0; v_inv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_paie := public.payer_ordre(v_moi, 'contrebande_port', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := public.crim_contrebande_taux_interne(v_moi);
  v_roll := least(100, floor(random() * 100)::integer + 1 + public.securite_malus_lieu_interne(v_moi)); /* securite_dissuasion */
  IF v_roll <= v_taux THEN
    UPDATE public.personnages_donnees
       SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
         || jsonb_build_array(jsonb_build_object('id', 'contrebande-' || replace(gen_random_uuid()::text, '-', ''),
              'type', 'contrebande', 'name', 'Cargaison de contrebande', 'icon', 'ti-package-off', 'legal', false,
              'desc', 'Marchandises importées illégalement.'))
     WHERE name = v_moi;
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
  END IF;
  -- La douane peut repérer la manœuvre, qu'elle réussisse ou non (décision de Fred, 25/11) : avis de recherche.
  v_repere := public.crime_detecter_interne(v_moi, 'contrebande_port', true);
  IF v_repere AND v_roll > v_taux THEN
    -- Échec repéré : la marchandise de contrebande portée sur soi est saisie.
    SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    SELECT count(*) INTO v_saisie FROM jsonb_array_elements(v_inv) o WHERE o ->> 'type' = 'contrebande';
    IF v_saisie > 0 THEN
      UPDATE public.personnages_donnees
         SET inventory = (SELECT coalesce(jsonb_agg(o ORDER BY n), '[]'::jsonb) FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(o, n)
                           WHERE o ->> 'type' IS DISTINCT FROM 'contrebande')
       WHERE name = v_moi;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'saisie', v_saisie, 'taux', v_taux, 'jet', v_roll,
    'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))
    || public.crime_etat_acteur_interne(v_moi); /* audit_chances_contrebande_v1 */
END; $function$;

-- ── Évasion (1.4c) : règle du serveur gardée, chance sortie dans une fonction ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.detention_evasion_taux_interne(p_nom text, p_benediction boolean DEFAULT false)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p public.personnages_donnees%ROWTYPE; v_det record; v_pays text; v_ville text; v_isn numeric; v_dup numeric;
        v_taux integer; v_bonus integer := 0;
BEGIN
  SELECT * INTO p FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT * INTO v_det FROM public.detention_active(p_nom);
  IF v_det.id IS NULL THEN RETURN NULL; END IF;
  v_pays := coalesce(v_det.country, p.country, 'republic');
  v_ville := coalesce(v_det.city, p.current_city, 'capitale');
  v_isn := coalesce((SELECT CASE WHEN jsonb_typeof(data -> 'isn') = 'number' THEN (data ->> 'isn')::numeric END
                       FROM public.indices_villes WHERE id = v_pays || '_' || v_ville), 30);
  v_dup := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'DUP') = 'number' THEN (p.stats ->> 'DUP')::numeric END, 8);
  v_taux := greatest(2, least(40, round(10 + (v_dup - 10) * 2 - (v_isn - 45) / 3
                                        + CASE WHEN p_benediction THEN 5 ELSE 0 END)))::integer;
  -- Bonus du déserteur : appliqué APRÈS le plafond ordinaire de 40 %, maximum absolu 90 %.
  IF p.requisition ->> 'statut' = 'deserteur' THEN
    v_bonus := least(50, greatest(0, coalesce(p.day, 1) - coalesce(v_det.jour_debut, coalesce(p.day, 1))) * 10);
    v_taux := least(90, v_taux + v_bonus);
  END IF;
  v_bonus := public.crim_grilles_bonus_interne(v_pays, v_ville);
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;
  v_bonus := public.crim_corruption_evasion_bonus_interne(p_nom, v_det.id);
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;
  RETURN v_taux; /* audit_chances_evasion_v1 */
END $$;

SELECT pg_temp.rp_raccorder_re('public.detention_tenter_evasion(integer,integer,boolean)'::regprocedure,
  $re$  v_isn := coalesce\(\(SELECT CASE WHEN jsonb_typeof\(data -> 'isn'\).*?/\* crim_corruption_evasion_v1 \*/\n  IF v_bonus > 0 THEN v_taux := least\(90, v_taux \+ v_bonus\); END IF;$re$,
  $r$  v_taux := public.detention_evasion_taux_interne(v_moi, p_benediction); /* audit_chances_evasion_v1 crim_grilles_evasion_v1 crim_corruption_evasion_v1 */$r$,
  'audit_chances_evasion_v1');

-- ── Rébellion (1.4d) : règle du serveur gardée, chance sortie dans une fonction ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.detention_rebellion_taux_interne(p_nom text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(60, floor(coalesce(CASE WHEN jsonb_typeof(p.stats -> 'VOL') = 'number' THEN (p.stats ->> 'VOL')::numeric END, 8) * 3
           + floor(coalesce((SELECT greatest(0, least(20, coalesce(CASE WHEN jsonb_typeof(e -> 'stats' -> 'FOR') = 'number'
                                                                     THEN (e -> 'stats' ->> 'FOR')::numeric END, 0)))
                               FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes) = 'array' THEN p.employes ELSE '[]'::jsonb END) e
                              WHERE e ->> 'job' = 'codetenu' LIMIT 1), 0) / 2)))::integer /* audit_chances_rebellion_v1 */
    FROM public.personnages_donnees p WHERE p.name = p_nom
$$;

SELECT pg_temp.rp_remplacer('public.detention_se_rebeller(integer,integer)'::regprocedure,
  $a$  v_taux := least(60, floor(v_vol * 3 + floor(coalesce(v_for, 0) / 2)))::integer;$a$,
  $b$  v_taux := public.detention_rebellion_taux_interne(v_moi); /* audit_chances_rebellion_v1 */$b$,
  1, 'audit_chances_rebellion_v1');

-- ── Écouter les rumeurs (1.3b) : lieux tenus en un seul endroit, poissonnière de Novomirsk déclarée ───────────────
CREATE OR REPLACE FUNCTION public.rumeur_ecoute_lieu_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'capitale' AND p_batiment = 'hotel-republica' AND p_piece = 'restaurant' THEN '{"taux": 95, "pa": 0}'::jsonb
    WHEN p_ville = 'capitale' AND p_batiment = 'hotel-republica' AND p_piece = 'bar' THEN '{"taux": 90, "pa": 0, "source": "Marco"}'::jsonb
    WHEN p_ville = 'capitale' AND p_batiment = 'assemblee' AND p_piece = 'couloirs' THEN '{"taux": 70, "pa": 1}'::jsonb
    WHEN p_pays = 'republic' AND p_ville = 'ville_a' AND p_batiment = 'bar-des-pecheurs' AND p_piece = 'salle_bar' THEN '{"taux": 85, "pa": 0, "source": "Marin Dulac"}'::jsonb
    WHEN p_pays = 'republic' AND p_ville = 'ville_a' AND p_batiment = 'capitaine-sauvage' AND p_piece = 'salle_principale' THEN '{"taux": 95, "pa": 0}'::jsonb
    WHEN p_pays = 'soviet' AND p_ville = 'ville_a' AND p_batiment = 'hotel-mineur' AND p_piece = 'hall_mineur' THEN '{"taux": 90, "pa": 0, "source": "Aldar Zhamsuev"}'::jsonb
    -- Galina Karpova, poissonnière de Novomirsk (data.js : poissonniere-novomirsk, étal ; « Tendre l'oreille », 0 PA, 95 %).
    WHEN p_pays = 'soviet' AND p_ville = 'capitale' AND p_batiment = 'poissonniere-novomirsk' AND p_piece = 'etal_poissonniere' THEN '{"taux": 95, "pa": 0, "source": "Galina Karpova"}'::jsonb
  END /* audit_chances_poissonniere_v1 */
$$;

SELECT pg_temp.rp_raccorder_re('public.rumeur_ecoute_jauges_interne(text)'::regprocedure,
  $re$ IF a\.current_city='capitale'AND a\.current_building='hotel-republica'AND a\.current_room='restaurant'THEN taux:=95;cout_pa:=0;.*?ELSE RETURN jsonb_build_object\('ok',false,'raison','pas_sur_place'\);END IF;$re$,
  $r$ taux:=(public.rumeur_ecoute_lieu_interne(a.country,a.current_city,a.current_building,a.current_room)->>'taux')::integer; /* audit_chances_poissonniere_v1 */
 IF taux IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 cout_pa:=(public.rumeur_ecoute_lieu_interne(a.country,a.current_city,a.current_building,a.current_room)->>'pa')::integer;
 source:=public.rumeur_ecoute_lieu_interne(a.country,a.current_city,a.current_building,a.current_room)->>'source';$r$,
  'audit_chances_poissonniere_v1');

-- ── Inspecter les cargaisons (1.3c) : quai de Novomirsk, et chance sortie dans une fonction ──────────────────────
SELECT pg_temp.rp_remplacer('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$(a.current_building='port-sovarka' AND a.current_room='quai_sovarka')$a$,
  $b$(a.current_building IN ('port-novomirsk','port-sovarka') AND a.current_room='quai_sovarka'/* audit_chances_port_novomirsk_v1 */)$b$,
  1, 'audit_chances_port_novomirsk_v1');

-- INT effective (moyenne du PJ et des PNJ actifs de son groupe, plus les bonus temporaires actifs), puis la formule existante.
CREATE OR REPLACE FUNCTION public.jauges_inspection_taux_interne(p_nom text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a public.personnages_donnees; v_int numeric; v_bonus_int numeric;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT avg(x.valeur) INTO v_int FROM (
    SELECT CASE WHEN jsonb_typeof(a.stats->'INT')='number' THEN (a.stats->>'INT')::numeric ELSE 8::numeric END valeur
    UNION ALL
    SELECT m.car_int::numeric FROM public.pnj_membres m WHERE m.leader_pj=a.name AND m.statut='actif' AND m.car_int IS NOT NULL)x;
  SELECT coalesce(sum(CASE WHEN jsonb_typeof(e.obj->'deltas'->'INT')='number' THEN (e.obj->'deltas'->>'INT')::numeric ELSE 0 END),0)
    INTO v_bonus_int
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.effets_actifs)='array' THEN a.effets_actifs ELSE '[]'::jsonb END) e(obj)
   WHERE CASE WHEN jsonb_typeof(e.obj->'expireA')='number'
     THEN (e.obj->>'expireA')::numeric > extract(epoch FROM clock_timestamp())*1000 ELSE false END;
  v_int := round(coalesce(v_int,8)+coalesce(v_bonus_int,0));
  RETURN greatest(5,80+floor(v_int/10)::integer+CASE WHEN a.country='soviet' THEN 15 ELSE 0 END); /* audit_chances_inspection_v1 */
END $$;

SELECT pg_temp.rp_remplacer('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$    v_taux:=greatest(5,80+floor(v_int/10)::integer
      +CASE WHEN a.country='soviet' THEN 15 ELSE 0 END);$a$,
  $b$    v_taux:=public.jauges_inspection_taux_interne(a.name); /* audit_chances_inspection_v1 */$b$,
  1, 'audit_chances_inspection_v1');

-- ── Contester des résultats : chance sortie dans une fonction ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.election_contester_taux_interne(p_int numeric)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT greatest(5, least(95, round(60 + 5 * (coalesce(p_int, 8) - 13))::integer)) /* audit_chances_contester_v1 */
$$;
SELECT pg_temp.rp_remplacer('public.election_contester(text,text,integer,integer)'::regprocedure,
  $a$  v_taux := greatest(5, least(95, round(60 + 5 * (v_int - 13))::integer));$a$,
  $b$  v_taux := public.election_contester_taux_interne(v_int); /* audit_chances_contester_v1 */$b$,
  1, 'audit_chances_contester_v1');

-- ── Falsifier un document : chance sortie dans une fonction (la dissuasion s'ajoute au jet, comme avant) ─────────
CREATE OR REPLACE FUNCTION public.crim_falsifier_taux_interne(p_pays text, p_ville text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(5, 45 - public.crime_malus_isn_interne(p_pays, p_ville)) /* audit_chances_falsifier_v1 */
$$;
SELECT pg_temp.rp_remplacer('public.crime_falsifier(text,integer,integer)'::regprocedure,
  $a$  v_taux := greatest(5, 45 - public.crime_malus_isn_interne(m.country, m.current_city));$a$,
  $b$  v_taux := public.crim_falsifier_taux_interne(m.country, m.current_city); /* audit_chances_falsifier_v1 */$b$,
  1, 'audit_chances_falsifier_v1');

-- ── Voler du matériel de chantier (1.4f) : bonus sorti dans une fonction ; l'agent de sécurité posté protège ─────
-- Le vol réussit quand 50 + bonus − dissuasion + (jet − 50) ≥ 50 : chance ≈ 50 + bonus − dissuasion (bornée 0-100).
-- La dissuasion est celle des agents de sécurité présents (securite_malus_lieu_interne, règle #135).
CREATE OR REPLACE FUNCTION public.crim_vol_chantier_bonus_interne(p_nom text, p_benediction boolean DEFAULT false)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (coalesce((a.stats ->> 'DUP')::numeric, 8) - 10) * 2
         - (coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                       WHERE id = a.country || '_' || coalesce(a.current_city, 'capitale')), 30) - 45) / 3
         + CASE WHEN coalesce(a.reputation_criminelle, 0) >= 70 THEN 15 WHEN coalesce(a.reputation_criminelle, 0) >= 40 THEN 10
                WHEN coalesce(a.reputation_criminelle, 0) >= 20 THEN 5 ELSE 0 END
         + CASE WHEN p_benediction THEN 5 ELSE 0 END /* audit_chances_vol_chantier_v1 */
    FROM public.personnages_donnees a WHERE a.name = p_nom
$$;
SELECT pg_temp.rp_raccorder_re('public.crime_voler_materiaux(text,text,integer,integer,boolean)'::regprocedure,
  $re$  v_bonus := \(coalesce\(\(a\.stats ->> 'DUP'\)::numeric, 8\) - 10\) \* 2 - \(v_isn - 45\) / 3.*?\+ CASE WHEN p_benediction THEN 5 ELSE 0 END;$re$,
  $r$  v_bonus := public.crim_vol_chantier_bonus_interne(a.name, p_benediction); /* audit_chances_vol_chantier_v1 */$r$,
  'audit_chances_vol_chantier_v1');

-- ── Ordres génériques : chance d'un plein effet (réussite ou réussite critique) ───────────────────────────────────
-- ordre_generique_executer : jet de 1 à 100 ; plein effet quand jet > 100 − 0,4 × taux (taux au moins 5, 99 à partir de 98).
CREATE OR REPLACE FUNCTION public.ordre_generique_chance_interne(p_fn text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN o.toujours_reussi THEN 100
              ELSE ceil(0.4 * greatest(5, CASE WHEN o.taux_reussite >= 98 THEN 99 ELSE o.taux_reussite END))::integer END
    FROM public.ordres_generiques o WHERE o.fn = p_fn
$$;

-- ── Lecture des chances des ordres de l'audit (personnage connecté, lieu tenu par le serveur) ─────────────────────
CREATE OR REPLACE FUNCTION public.ordres_chances_audit_interne(a text, f text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d public.personnages_donnees; e jsonb;
BEGIN
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a;
  IF NOT FOUND THEN RETURN NULL; END IF;
  CASE f
    WHEN 'bourrer_urnes' THEN RETURN public.fraude_chance_interne(a, 'bourrage_urnes');
    WHEN 'falsifier_listes_electorales' THEN RETURN public.fraude_chance_interne(a, 'falsification_listes');
    WHEN 'truquer_depouillement' THEN RETURN public.fraude_chance_interne(a, 'trucage_depouillement');
    WHEN 'contrebande_port' THEN RETURN greatest(0, public.crim_contrebande_taux_interne(a) - coalesce(public.securite_malus_lieu_interne(a), 0));
    WHEN 'tentative_evasion' THEN RETURN public.detention_evasion_taux_interne(a, false);
    WHEN 'se_rebeller' THEN
      IF (SELECT id FROM public.detention_active(a)) IS NULL THEN RETURN NULL; END IF;
      RETURN public.detention_rebellion_taux_interne(a);
    WHEN 'ecouter_rumeurs' THEN
      RETURN (public.rumeur_ecoute_lieu_interne(d.country, d.current_city, d.current_building, d.current_room) ->> 'taux')::integer;
    WHEN 'inspecter_cargaisons' THEN RETURN public.jauges_inspection_taux_interne(a);
    WHEN 'contester_resultats' THEN
      RETURN public.election_contester_taux_interne(coalesce(CASE WHEN jsonb_typeof(d.stats -> 'INT') = 'number' THEN (d.stats ->> 'INT')::numeric END, 8));
    WHEN 'falsifier_document' THEN
      RETURN greatest(0, public.crim_falsifier_taux_interne(d.country, d.current_city) - coalesce(public.securite_malus_lieu_interne(a), 0));
    WHEN 'voler_materiel_chantier' THEN
      RETURN greatest(0, least(100, round(50 + public.crim_vol_chantier_bonus_interne(a, false) - coalesce(public.securite_malus_lieu_interne(a), 0))))::integer;
    WHEN 'corrompre_fonct', 'corrompre_gardien' THEN
      e := public.crim_corruption_qhs_etat_interne(a);
      IF NOT coalesce((e ->> 'detenu_qhs')::boolean, false) THEN RETURN NULL; END IF;
      RETURN public.crim_chance_bornee_interne(a, (e ->> 'taux')::numeric, public.crim_param_interne('corruption_qhs_min', 5),
                                               public.crim_param_interne('corruption_qhs_max', 75), false);
    WHEN 'incendier' THEN
      RETURN public.crim_chance_bornee_interne(a, public.crim_incendie_taux_interne(public.crim_stat_interne(a, 'dis', 50),
               public.crim_mode_action_interne(a) IN ('cache', 'cache_masque'), d.career,
               public.inventaire_quantite(d.inventory, 'carburant') >= 1,
               public.crim_climat_actif_interne('orage', d.country, d.current_city), public.crim_climat_actif_interne('canicule', d.country, d.current_city)),
               public.crim_param_interne('incendie_min', 5), public.crim_param_interne('incendie_max', 80), true);
    WHEN 'fuite_info', 'soins_discrets' THEN
      IF f = 'fuite_info' AND d.country = 'soviet' THEN RETURN NULL; END IF;   -- en Sovarka, la fuite est un acte sans jet
      RETURN public.ordre_generique_chance_interne(f);
    ELSE RETURN NULL;
  END CASE;
END $$;

SELECT pg_temp.rp_raccorder_re('public.ordres_chances_lire(text[],text)'::regprocedure,
  $re$      END IF;\n    EXCEPTION WHEN OTHERS THEN NULL;$re$,
  $r$      ELSIF public.ordres_chances_audit_interne(a, f) IS NOT NULL THEN /* audit_chances_soir_v1 */
        out := out || jsonb_build_object(f, public.ordres_chances_audit_interne(a, f));
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;$r$,
  'audit_chances_soir_v1');

-- ── « Mobiliser les membres » (1.3a) : plus de tarif fantôme ─────────────────────────────────────────────────────
DELETE FROM public.ordres_couts WHERE fn = 'mobiliser' AND (pa, cost) IS DISTINCT FROM (0, 0);
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'mobiliser', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'mobiliser' AND pa = 0 AND cost = 0);

REVOKE ALL ON FUNCTION public.fraude_taux_interne(integer, numeric), public.fraude_chance_interne(text, text),
  public.crim_contrebande_taux_interne(text), public.detention_evasion_taux_interne(text, boolean),
  public.detention_rebellion_taux_interne(text), public.rumeur_ecoute_lieu_interne(text, text, text, text),
  public.jauges_inspection_taux_interne(text), public.election_contester_taux_interne(numeric),
  public.crim_falsifier_taux_interne(text, text), public.crim_vol_chantier_bonus_interne(text, boolean),
  public.ordre_generique_chance_interne(text), public.ordres_chances_audit_interne(text, text) FROM PUBLIC, anon, authenticated;

COMMIT;
