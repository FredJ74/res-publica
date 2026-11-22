-- Santé — maladies, MST, escort, médicaments, fontaines (Fred, 22/11/2026, après-midi : GAME-DESIGN-SANTE-20261122.md,
-- points 4, 5, 6, 13 et 20). Suppose le socle 20261122230000_sante_socle.sql appliqué (sante_param, sante_perdre_interne,
-- personnage_evenement_ajouter_interne, sante_reveil_interne). Le serveur décide de tout ; valeurs réglables par un MJ.
--
-- Point 4 — maladies_parametres.perte_sante (intoxication 10, grippe 10, coup de chaleur 5, gueule de bois 3, MST 10) :
--   maladie_contracter_interne (seule porte de contraction : tirages, contagion, MJ, MST) retire cette Santé au moment de
--   la contraction (sante_perdre_interne, jamais modulée par le Moral) et renvoie 'sante_perdue'.
-- Point 5 — MST (clé « mst ») : −2 CHA, symptôme visible « démangeaisons très gênantes » (texte du navigateur, jamais le
--   nom), non contagieuse, jamais de guérison spontanée (nouvelle colonne guerison_spontanee = false : fin dans 100 ans),
--   guérie par l'antibiotique (nouveau médicament) au prochain Dormir comme les autres (maladies_nuit_interne inchangée).
--   Risque à chaque « faire l'amour » (escort_intimite) : n = escorts DIFFÉRENTES vues sur mst_fenetre_jours jours glissants,
--   celle-ci comprise (table escort_relations) ; si n ≥ mst_seuil_partenaires, risque = mst_risque_par_partenaire × (n − 1).
--   Tirage à l'acte (mst_en_attente), révélation au réveil suivant : sante_reveil_interne (accroche du socle, réécrite ici)
--   contracte la MST (perte de Santé) et écrit le journal d'événements, jamais un courrier.
-- Point 6 — escort_intimite ne donne plus aucune Santé (gain_hp = 0) ; Moral et ENT inchangés.
-- Point 13 — un seul ordre « Produire des médicaments » (produire_medicaments, inchangé côté coûts) : le producteur choisit
--   le médicament (produire_medicament) ; mêmes matières (5 plantes), même salaire, même plafond pour tous ; le produit
--   alimente un stock national par médicament (medicaments_stocks), vendu en priorité dans les points de vente existants
--   (pharmacies_points_vente, inchangés) ; la recette de ces unités revient à la caisse de l'usine qui a payé le salaire.
--   La dotation quotidienne de l'État (stock_journalier) et la règle de prix (pharmacie_prix_pays_interne) sont inchangées.
--   L'antibiotique est vendu partout où se vendent les autres.
-- Point 20 — fontaines : vérifié, aucun tirage (point_eau_puiser ne tire rien ; la bouteille d'eau n'est ni aliment ni
--   boisson pour inventaire_consommer) : rien à neutraliser, contrôle final ci-dessous.
--
-- Remplacements contrôlés (texte de production, ancrage compté, marque unique) : maladie_contracter_interne,
--   admin_maladie_modifier, escort_intimite. Réécrites (texte de production + changements) : pharmacie_etat,
--   pharmacie_acheter_interne, sante_reveil_interne (accroche vide du socle). Nouvelles : mst_relation_interne,
--   medicament_stock_pays_interne, usine_medicaments_chaine_interne, usine_medicaments_crediter_interne,
--   produire_medicament, usine_medicaments_etat.
-- Aucune Santé actuelle modifiée (point 16). Rejouable. Rien du goulag.
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
-- 1. Catalogue des maladies : perte de Santé, guérison spontanée, MST
-- ---------------------------------------------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'maladies_parametres'
                    AND column_name = 'perte_sante') THEN
    ALTER TABLE public.maladies_parametres ADD COLUMN perte_sante integer NOT NULL DEFAULT 0
      CONSTRAINT maladies_parametres_perte_sante_check CHECK (perte_sante BETWEEN 0 AND 100);
    -- Valeurs de Fred, posées une seule fois (un réglage ultérieur du MJ n'est jamais écrasé par un rejeu).
    UPDATE public.maladies_parametres SET perte_sante = CASE cle WHEN 'intoxication' THEN 10 WHEN 'grippe' THEN 10
      WHEN 'coup_de_chaleur' THEN 5 WHEN 'gueule_de_bois' THEN 3 ELSE 0 END;
  END IF;
END $$;
ALTER TABLE public.maladies_parametres ADD COLUMN IF NOT EXISTS guerison_spontanee boolean NOT NULL DEFAULT true;

INSERT INTO public.maladies_parametres (cle, actif, deltas, pa_max, sans_bonus_arme, duree_heures, medicament, contagieuse, risques,
                                        prix_fixe, stock_journalier, perte_sante, guerison_spontanee)
VALUES ('mst', true, '{"CHA":-2}'::jsonb, NULL, false, 2400, 'antibiotique', false, '{}'::jsonb, NULL, 20, 10, false)
ON CONFLICT (cle) DO NOTHING;

-- Réglages chiffrés du lot (MST : mst_fenetre_jours, mst_seuil_partenaires, mst_risque_par_partenaire sont dans le socle).
INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('medicament_matiere_par_pa', 5, 'medicaments', 'Produire des médicaments : plantes consommées par PA'),
  ('medicament_produits_par_pa', 10, 'medicaments', 'Produire des médicaments : boîtes produites par PA'),
  ('medicament_stock_max', 50, 'medicaments', 'Stock national maximal de chaque médicament produit')
ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Point 4 : la contraction retire la Santé ; une maladie sans guérison spontanée dure jusqu'au médicament
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.maladie_contracter_interne(text,text,text)'::regprocedure,
  $a$DECLARE m public.maladies_parametres; v_id bigint;$a$,
  $b$DECLARE m public.maladies_parametres; v_id bigint; v_sante jsonb; /* sante_maladies_v1_decl */$b$,
  1, 'sante_maladies_v1_decl');
SELECT pg_temp.rp_remplacer('public.maladie_contracter_interne(text,text,text)'::regprocedure,
  $a$now() + make_interval(hours => m.duree_heures)) RETURNING id INTO v_id;$a$,
  $b$now() + CASE WHEN coalesce(m.guerison_spontanee, true) THEN make_interval(hours => m.duree_heures)
          ELSE interval '100 years' END /* sante_maladies_v1_duree */) RETURNING id INTO v_id;$b$,
  1, 'sante_maladies_v1_duree');
SELECT pg_temp.rp_remplacer('public.maladie_contracter_interne(text,text,text)'::regprocedure,
  $a$  RETURN jsonb_build_object('id', v_id, 'cle', p_cle, 'nom_mj', m.nom_mj, 'symptome_mj', m.symptome_mj, 'duree_heures', m.duree_heures);$a$,
  $b$  IF coalesce(m.perte_sante, 0) > 0 THEN /* sante_maladies_v1_perte */
    v_sante := public.sante_perdre_interne(p_nom, m.perte_sante, 'maladie_' || p_cle, jsonb_build_object('maladie', p_cle));
  END IF;
  RETURN jsonb_build_object('id', v_id, 'cle', p_cle, 'nom_mj', m.nom_mj, 'symptome_mj', m.symptome_mj, 'duree_heures', m.duree_heures,
    'sante_perdue', coalesce(-(v_sante->>'gain')::integer, 0), 'sante', (v_sante->>'apres')::integer);$b$,
  1, 'sante_maladies_v1_perte');

-- MJ : les deux nouveaux réglages sont modifiables comme les autres.
SELECT pg_temp.rp_remplacer('public.admin_maladie_modifier(text,jsonb)'::regprocedure,
  $a$'prix_fixe','stock_journalier','nom_mj','symptome_mj') THEN$a$,
  $b$'prix_fixe','stock_journalier','nom_mj','symptome_mj','perte_sante','guerison_spontanee' /* sante_maladies_v1_admin_cles */) THEN$b$,
  1, 'sante_maladies_v1_admin_cles');
SELECT pg_temp.rp_remplacer('public.admin_maladie_modifier(text,jsonb)'::regprocedure,
  $a$    updated_at = now(), updated_by = v_admin$a$,
  $b$    perte_sante     = CASE WHEN p_parametres ? 'perte_sante' THEN (p_parametres->>'perte_sante')::integer ELSE m.perte_sante END,
    guerison_spontanee = CASE WHEN p_parametres ? 'guerison_spontanee' THEN (p_parametres->>'guerison_spontanee')::boolean ELSE m.guerison_spontanee END,
    updated_at = now(), updated_by = v_admin /* sante_maladies_v1_admin_maj */$b$,
  1, 'sante_maladies_v1_admin_maj');

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Point 5 : relations avec les escorts, tirage à l'acte, révélation au réveil
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escort_relations (
  id bigserial PRIMARY KEY,
  client text NOT NULL,
  escort text NOT NULL,              -- identifiant du PNJ escort (pnj_membres.id)
  cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS escort_relations_client ON public.escort_relations (client, cree_le);
ALTER TABLE public.escort_relations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.escort_relations FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.mst_en_attente (
  id bigserial PRIMARY KEY,
  nom text NOT NULL,
  partenaires integer NOT NULL,
  risque numeric NOT NULL,
  tire_le timestamptz NOT NULL DEFAULT now(),
  revelee_le timestamptz,
  resultat jsonb
);
CREATE INDEX IF NOT EXISTS mst_en_attente_non_revelees ON public.mst_en_attente (nom, id) WHERE revelee_le IS NULL;
ALTER TABLE public.mst_en_attente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mst_en_attente FROM PUBLIC, anon, authenticated;

-- Une relation : trace, compte des escorts différentes sur la fenêtre glissante, tirage. Rien n'est dit au joueur ici.
CREATE OR REPLACE FUNCTION public.mst_relation_interne(p_client text, p_escort text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jours numeric := public.sante_param('mst_fenetre_jours', 10);
        v_seuil integer := public.sante_param('mst_seuil_partenaires', 2)::integer;
        v_pas numeric := public.sante_param('mst_risque_par_partenaire', 0.15);
        v_n integer; v_risque numeric := 0; v_tire boolean := false;
BEGIN
  IF p_client IS NULL OR p_escort IS NULL THEN RETURN NULL; END IF;
  INSERT INTO public.escort_relations (client, escort) VALUES (p_client, p_escort);
  SELECT count(DISTINCT escort) INTO v_n FROM public.escort_relations
   WHERE client = p_client AND cree_le > now() - make_interval(secs => (v_jours * 86400)::double precision);
  IF v_n >= v_seuil THEN v_risque := least(1, greatest(0, v_pas * (v_n - 1))); END IF;
  IF v_risque > 0
     AND NOT EXISTS (SELECT 1 FROM public.personnages_maladies WHERE nom = p_client AND cle = 'mst' AND guerie_le IS NULL)
     AND NOT EXISTS (SELECT 1 FROM public.mst_en_attente WHERE nom = p_client AND revelee_le IS NULL)
     AND EXISTS (SELECT 1 FROM public.maladies_parametres WHERE cle = 'mst' AND actif)
     AND random() < v_risque THEN
    INSERT INTO public.mst_en_attente (nom, partenaires, risque) VALUES (p_client, v_n, v_risque);
    v_tire := true;
  END IF;
  RETURN jsonb_build_object('partenaires', v_n, 'risque', v_risque, 'tire', v_tire); /* sante_maladies_v1 */
END $function$;

-- Point 6 + tirage : escort_intimite ne donne plus de Santé ; la relation est tracée et tirée à l'acte.
SELECT pg_temp.rp_remplacer('public.escort_intimite(uuid,text,integer)'::regprocedure,
  $a$  v_hp    := (ARRAY[5, 6, 7, 10])[v_palier + 1];$a$,
  $b$  v_hp    := 0; /* sante_maladies_v1_escort_sans_sante */$b$,
  1, 'sante_maladies_v1_escort_sans_sante');
SELECT pg_temp.rp_remplacer('public.escort_intimite(uuid,text,integer)'::regprocedure,
  $a$     SET moral = least(100, coalesce(moral, 75) + v_moral), hp = least(100, coalesce(hp, 100) + v_hp), updated_at = now()$a$,
  $b$     SET moral = least(100, coalesce(moral, 75) + v_moral), updated_at = now() /* sante_maladies_v1_escort_hp */$b$,
  1, 'sante_maladies_v1_escort_hp');
SELECT pg_temp.rp_remplacer('public.escort_intimite(uuid,text,integer)'::regprocedure,
  $a$  v_ent_gagne := public.ent_gain_quotidien_interne(moi, v_ent);$a$,
  $b$  v_ent_gagne := public.ent_gain_quotidien_interne(moi, v_ent);
  PERFORM public.mst_relation_interne(moi, v_pnj); /* sante_maladies_v1_escort_mst */$b$,
  1, 'sante_maladies_v1_escort_mst');

-- Réveil (Dormir) : révèle les MST tirées depuis le dernier réveil. Remplace l'accroche vide du socle.
CREATE OR REPLACE FUNCTION public.sante_reveil_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v jsonb; v_perte integer; v_texte text; v_out jsonb := '[]'::jsonb;
        v_jours integer := public.sante_param('mst_fenetre_jours', 10)::integer;
BEGIN
  IF p_nom IS NULL THEN RETURN v_out; END IF;
  FOR r IN SELECT * FROM public.mst_en_attente WHERE nom = p_nom AND revelee_le IS NULL ORDER BY id FOR UPDATE LOOP
    v := public.maladie_contracter_interne(p_nom, 'mst', 'escort');
    IF v IS NOT NULL THEN
      v_perte := coalesce((v->>'sante_perdue')::integer, 0);
      v_texte := 'Ces ' || v_jours || ' derniers jours, vous avez eu des relations avec ' || r.partenaires
        || ' partenaires. L''un d''eux ou l''une d''elles vous a transmis une MST. −' || v_perte || ' points de Santé.';
      PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'mst_revelee', v_texte,
        jsonb_build_object('partenaires', r.partenaires, 'jours', v_jours, 'perte', v_perte, 'maladie', 'mst'));
      v_out := v_out || jsonb_build_array(jsonb_build_object('cle', 'mst_revelee', 'texte', v_texte, 'perte', v_perte,
        'partenaires', r.partenaires));
    END IF;
    UPDATE public.mst_en_attente SET revelee_le = now(), resultat = v WHERE id = r.id;
  END LOOP;
  RETURN v_out; /* sante_maladies_v1_reveil */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Point 13 : un seul ordre « Produire des médicaments », le producteur choisit le médicament
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.medicaments_stocks (
  pays text NOT NULL,
  medicament text NOT NULL,
  quantite integer NOT NULL DEFAULT 0 CHECK (quantite >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, medicament)
);
ALTER TABLE public.medicaments_stocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.medicaments_stocks FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.medicament_stock_pays_interne(p_pays text, p_medicament text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce((SELECT quantite FROM public.medicaments_stocks WHERE pays = p_pays AND medicament = p_medicament), 0) $function$;

-- Chaîne « medicaments » du pays (même recherche que produire_en_usine : chaines_production_pays, sinon le gabarit).
CREATE OR REPLACE FUNCTION public.usine_medicaments_chaine_interne(p_pays text)
 RETURNS TABLE (ville text, building_id text, matiere text, salaire_pa numeric)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT x.ville, x.building_id, x.matiere,
         coalesce((SELECT s.salaire_pa FROM public.salaires_production_pays s WHERE s.pays = p_pays AND s.produit = 'medicaments'), x.salaire_pa)::numeric
    FROM (SELECT c.ville, c.building_id, c.matiere, c.salaire_pa, 1 AS o FROM public.chaines_production_pays c
           WHERE c.pays = p_pays AND c.produit = 'medicaments'
          UNION ALL
          SELECT u.ville, u.building_id, u.matiere, u.salaire_pa, 2 FROM public.chaines_production_usine u WHERE u.produit = 'medicaments') x
   ORDER BY x.o LIMIT 1;
$function$;

-- Recette des boîtes produites : à la caisse de l'usine du pays, qui a payé le salaire de production.
CREATE OR REPLACE FUNCTION public.usine_medicaments_crediter_interne(p_pays text, p_montant numeric)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_id text; v_etat jsonb; v_usine jsonb;
BEGIN
  IF coalesce(p_montant, 0) <= 0 THEN RETURN true; END IF;
  SELECT * INTO c FROM public.usine_medicaments_chaine_interne(p_pays);
  IF c.ville IS NULL THEN RETURN false; END IF;
  v_id := p_pays || '_' || c.ville || '_' || c.building_id;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN false; END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine || jsonb_build_object('caisse',
           coalesce((v_usine->>'caisse')::numeric, 0) + p_montant)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN true; /* sante_maladies_v1 */
END $function$;

-- Produire des médicaments : mêmes règles que produire_en_usine (présence, lois, matière, caisse, plafond, pénurie,
-- salaire versé en liquide depuis la caisse de l'usine) ; le produit est le médicament choisi.
CREATE OR REPLACE FUNCTION public.produire_medicament(p_acteur text, p_pays text, p_medicament text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_id text; v_etat jsonb; v_usine jsonb; v_sm jsonb; v_caisse numeric; v_stock_mat numeric; v_stock integer;
        v_place integer; v_produits integer; v_arg numeric; v_liquide numeric;
        v_mat_pa integer := public.sante_param('medicament_matiere_par_pa', 5)::integer;
        v_prod_pa integer := public.sante_param('medicament_produits_par_pa', 10)::integer;
        v_max integer := public.sante_param('medicament_stock_max', 50)::integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF NOT EXISTS (SELECT 1 FROM public.maladies_parametres WHERE medicament = p_medicament AND actif) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'medicament_inconnu'); END IF;
  SELECT * INTO c FROM public.usine_medicaments_chaine_interne(p_pays);
  IF c.ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'chaine_inconnue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_acteur AND country = p_pays
                    AND current_city = c.ville AND current_building = c.building_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.matiere_refus_circuit_legal(p_acteur, 'medicaments', 'production') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, 'medicaments', 'production'); END IF;
  IF public.matiere_refus_circuit_legal(p_acteur, c.matiere, 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, c.matiere, 'transformation'); END IF;

  v_id := p_pays || '_' || c.ville || '_' || c.building_id;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);
  v_stock_mat := coalesce((v_sm->>c.matiere)::numeric, 0);
  INSERT INTO public.medicaments_stocks (pays, medicament) VALUES (p_pays, p_medicament) ON CONFLICT DO NOTHING;
  SELECT quantite INTO v_stock FROM public.medicaments_stocks WHERE pays = p_pays AND medicament = p_medicament FOR UPDATE;

  IF v_stock_mat < v_mat_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'matiere', c.matiere); END IF;
  IF v_caisse < c.salaire_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  v_place := greatest(0, v_max - v_stock);
  IF v_place <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein'); END IF;
  v_produits := least(floor(v_prod_pa * public.penurie_coef_interne(p_pays, c.ville, 'medicaments')), v_place)::integer;
  IF v_produits <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'penurie', 'produit', 'medicaments'); END IF;

  v_sm := jsonb_set(v_sm, ARRAY[c.matiere], to_jsonb(v_stock_mat - v_mat_pa));
  v_caisse := v_caisse - c.salaire_pa;
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine || jsonb_build_object('caisse', v_caisse, 'stockMatieres', v_sm)))::text),
         updated_at = now()
   WHERE id = v_id;
  UPDATE public.medicaments_stocks SET quantite = quantite + v_produits, updated_at = now()
   WHERE pays = p_pays AND medicament = p_medicament;
  UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + c.salaire_pa, liquide = coalesce(liquide, 0) + c.salaire_pa
   WHERE name = p_acteur RETURNING arg, liquide INTO v_arg, v_liquide;
  IF v_arg IS NULL THEN RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501'; END IF;
  RETURN jsonb_build_object('ok', true, 'medicament', p_medicament, 'produits', v_produits, 'salaire', c.salaire_pa,
    'arg', v_arg, 'liquide', v_liquide, 'caisse_usine', v_caisse, 'stock_produit', v_stock + v_produits,
    'stock_max', v_max, 'stock_matiere', v_stock_mat - v_mat_pa); /* sante_maladies_v1 */
END $function$;

-- Fenêtre de production : médicaments au choix et stock national de chacun, pour mon pays.
CREATE OR REPLACE FUNCTION public.usine_medicaments_etat()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'stock_max', public.sante_param('medicament_stock_max', 50)::integer,
    'matiere_par_pa', public.sante_param('medicament_matiere_par_pa', 5)::integer,
    'produits_par_pa', public.sante_param('medicament_produits_par_pa', 10)::integer,
    'medicaments', (SELECT coalesce(jsonb_agg(jsonb_build_object('medicament', m.medicament, 'maladie', m.cle,
        'stock', public.medicament_stock_pays_interne(v_pays, m.medicament)) ORDER BY m.cle), '[]'::jsonb)
      FROM public.maladies_parametres m WHERE m.actif)); /* sante_maladies_v1 */
END $function$;

-- Pharmacie : le stock produit s'ajoute à la dotation du jour (texte de production + stock national).
CREATE OR REPLACE FUNCTION public.pharmacie_etat()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); pv public.pharmacies_points_vente; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  pv := public.pharmacie_point_interne(a);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  RETURN jsonb_build_object('ok', true, 'point', pv.id, 'prix_bandelette', public.aliments_param_interne('prix_bandelette', 4), /* aliments_bandelettes_v1 */ 'medicaments', (
    SELECT coalesce(jsonb_agg(jsonb_build_object('medicament', m.medicament, 'maladie', m.cle, 'nom_mj', m.nom_mj,
             'prix', public.pharmacie_prix_pays_interne(m.cle, pv.pays) /* climat_prix_pays_v1 */,
             'restant', greatest(0, public.pharmacie_stock_point_interne(pv.id, m.cle) - coalesce(s.vendus, 0))
                        + public.medicament_stock_pays_interne(pv.pays, m.medicament)) /* maladies_repartition_v1 */ /* sante_maladies_v1 */ ORDER BY m.cle), '[]'::jsonb)
      FROM public.maladies_parametres m
      LEFT JOIN public.pharmacies_ventes s ON s.point = pv.id AND s.jour = v_jour AND s.medicament = m.medicament
     WHERE m.actif));
END $function$;

-- Achat : le stock produit part en premier (recette à l'usine), puis la dotation du jour (recette au point de vente).
CREATE OR REPLACE FUNCTION public.pharmacie_acheter_interne(p_acteur text, p_medicament text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE pv public.pharmacies_points_vente; m public.maladies_parametres; v jsonb; v_prix integer; v_total numeric;
        v_vendus integer; v_fonds numeric; v_debit numeric; v_dep jsonb; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_stock_point integer; v_rep jsonb; v_flag text; /* maladies_repartition_v1 */
        v_prod integer; v_dotation integer; v_de_prod integer; v_de_dotation integer; v_total_point numeric; /* sante_maladies_v1 */
BEGIN
  IF p_qte IS NULL OR p_qte < 1 OR p_qte > 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  pv := public.pharmacie_point_interne(p_acteur);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  SELECT * INTO m FROM public.maladies_parametres WHERE medicament = p_medicament AND actif;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'medicament_inconnu'); END IF;
  v_stock_point := public.pharmacie_stock_point_interne(pv.id, m.cle);
  INSERT INTO public.pharmacies_ventes (point, jour, medicament, vendus) VALUES (pv.id, v_jour, p_medicament, 0) ON CONFLICT DO NOTHING;
  SELECT vendus INTO v_vendus FROM public.pharmacies_ventes WHERE point = pv.id AND jour = v_jour AND medicament = p_medicament FOR UPDATE;
  v_prod := coalesce((SELECT quantite FROM public.medicaments_stocks WHERE pays = pv.pays AND medicament = p_medicament FOR UPDATE), 0);
  v_dotation := greatest(0, v_stock_point - v_vendus);
  IF v_dotation + v_prod <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture'); END IF;
  IF p_qte > v_dotation + v_prod THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'restant', v_dotation + v_prod); END IF;
  v_de_prod := least(p_qte, v_prod);
  v_de_dotation := p_qte - v_de_prod;
  v_prix := public.pharmacie_prix_pays_interne(m.cle, pv.pays) /* climat_prix_pays_v1 */;
  v_total := v_prix * p_qte;
  v_total_point := v_prix * v_de_dotation;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = p_acteur;
  IF v_fonds < v_total THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total, 'disponible', v_fonds); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, 'pharmacie_medicaments', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(p_acteur, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'pharmacie_acheter: debit incomplet % / %', v_debit, v_total; END IF;
  UPDATE public.pharmacies_ventes SET vendus = vendus + v_de_dotation WHERE point = pv.id AND jour = v_jour AND medicament = p_medicament;
  IF v_de_prod > 0 THEN
    UPDATE public.medicaments_stocks SET quantite = quantite - v_de_prod, updated_at = now() WHERE pays = pv.pays AND medicament = p_medicament;
    IF NOT public.usine_medicaments_crediter_interne(pv.pays, v_prix * v_de_prod) THEN
      RAISE EXCEPTION 'pharmacie_acheter: caisse de l''usine introuvable (%)', pv.pays; END IF;
  END IF;
  IF pv.caisse_entreprise IS NOT NULL AND v_total_point > 0 THEN
    UPDATE public.entreprises SET data = jsonb_set(data, '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_total_point)), updated_at = now()
     WHERE id = pv.caisse_entreprise;
  END IF;
  IF pv.caisse_institution IS NOT NULL AND v_total_point > 0 THEN
    v_flag := current_setting('rp.caisse_interne', true);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(pv.caisse_institution, v_total_point, true);
    PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
    IF (v_rep->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'pharmacie_acheter: caisse refusee %', v_rep; END IF;
  END IF;
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', CASE p_medicament WHEN 'antinauseeux' THEN 'Anti-nauséeux' WHEN 'aspirine' THEN 'Aspirine' WHEN 'antigrippal' THEN 'Antigrippal' WHEN 'sels_rehydratation' THEN 'Sels de réhydratation' WHEN 'antibiotique' THEN 'Antibiotique' ELSE p_medicament END, 'icon', 'ti-pill',
    'type', 'medicament_maladie', 'medicament', p_medicament, 'soigne', m.cle,
    'stackable', true, 'stackKey', 'medicament_' || p_medicament, 'qty', p_qte));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'pharmacie_acheter: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'medicament', p_medicament, 'quantite', p_qte, 'prix', v_prix, 'paye', v_total,
    'restant', v_dotation + v_prod - p_qte)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide) FROM public.personnages_donnees WHERE name = p_acteur);
END $function$;

REVOKE ALL ON FUNCTION public.mst_relation_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_reveil_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medicament_stock_pays_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.usine_medicaments_chaine_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.usine_medicaments_crediter_interne(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.produire_medicament(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.produire_medicament(text, text, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.usine_medicaments_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.usine_medicaments_etat() TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Contrôles
-- ---------------------------------------------------------------------------------------------------------------
DO $$
DECLARE d text;
BEGIN
  IF (SELECT count(*) FROM public.maladies_parametres WHERE cle IN ('intoxication', 'grippe', 'coup_de_chaleur', 'gueule_de_bois', 'mst')) <> 5 THEN
    RAISE EXCEPTION 'sante_maladies : catalogue incomplet'; END IF;
  IF EXISTS (SELECT 1 FROM public.maladies_parametres WHERE cle = 'mst' AND (contagieuse OR guerison_spontanee OR medicament <> 'antibiotique')) THEN
    RAISE EXCEPTION 'sante_maladies : MST mal réglée'; END IF;
  -- Point 20 : aucune fontaine ne tire de maladie.
  d := pg_get_functiondef('public.point_eau_puiser(uuid,integer)'::regprocedure);
  IF d ~* 'maladie|intoxication' OR public.climat_objet_interne('bouteille_eau', 1) ? 'boisson'
     OR coalesce(public.climat_objet_interne('bouteille_eau', 1)->>'familleProduitMarche', '') = 'aliment' THEN
    RAISE EXCEPTION 'sante_maladies : un point d''eau tire une maladie'; END IF;
  IF position('sante_maladies_v1_escort_sans_sante' IN pg_get_functiondef('public.escort_intimite(uuid,text,integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'sante_maladies : escort_intimite non branchée'; END IF;
END $$;

COMMIT;
