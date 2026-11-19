-- CRIMINALITÉ — LOT 4 : cambriolage (GAME-DESIGN-CRIMINALITE.md §§ 6, 8, 15 ; GAME-DESIGN-SERRURES.md ; Fred, 18-19/11/2026).
-- Tout passe par la résolution commune crim_resoudre_interne (jet, dissuasion #135 une seule fois, échec critique, détection,
-- messages selon le mode, affaire crim_affaires, peine d'office) ; le vol devant témoin reprend les briques du lot 3.
-- • crim_crocheter(batiment, piece, requete) : 3 PA, kit de crochetage (usages_restants, détruit après 5 réussites).
--   30 % + 1 par tranche de 2 de DIS au-dessus de 50 + 15 carrière criminelle, 5-80. Échec : rien. Échec critique (2 % des
--   échecs) : le kit casse, trace sans nom pour le propriétaire. Réussite : porte ouverte sans trace, serrure intacte et
--   refermée derrière (passage personnel crim_intrusions lu par serrure_porte_fermee_interne / serrure_batiment_ferme_interne).
-- • crim_forcer_porte(batiment, piece, requete) : 2 PA, mains nues ou pied-de-biche (pris s'il est dans l'inventaire).
--   40 % + 3 par point de FOR au-dessus de 8 + 25 pied-de-biche + 10 carrière criminelle, 10-95. Réussite : serrure détruite
--   (jamais récupérable), propriétaire prévenu aussitôt, détection 60 (−10 masqué ; caché ne compte pas). Échec : la serrure
--   tient, propriétaire alerté sans nom.
-- • crim_cambriolage_lire() / crim_cambrioler(cible, ref, requete) : matériel installé, stock (10-20 % d'une pile),
--   caisse (10-30 %, 3 000 max), 2 PA. Lieu vide : pas de jet de réussite, détection 30 (−20 caché, −10 masqué, min 5),
--   constat au prochain passage du propriétaire ou à son prochain point de caisse. Personne présente (PJ, PNJ référencé,
--   employé au comptoir d'un commerce ouvert) : règles du vol sur une personne (réussite, remarqué, combat).
-- • Objets déposés ramassés après une effraction : pas un vol, mais une affaire au nom du propriétaire (plainte possible).
-- • voler_materiel(uuid) (ancienne route, 3 PA, jet DUP, arrestation) : redirigée vers la règle du cambriolage.
--   crime_voler_materiaux (matériaux d'un chantier en plein air) n'est pas un cambriolage : inchangé.
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia tant qu'ils n'ont pas les leurs) ─────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('crochetage_base', 30), ('crochetage_min', 5), ('crochetage_max', 80), ('crochetage_carriere', 15),
  ('crochetage_dis_pivot', 50), ('crochetage_dis_tranche', 2), ('kit_usages', 5),
  ('effraction_base', 40), ('effraction_min', 10), ('effraction_max', 95), ('effraction_carriere', 10),
  ('effraction_for_pivot', 8), ('effraction_for_pas', 3), ('effraction_pied_de_biche', 25), ('effraction_detection', 60),
  ('cambriolage_detection', 30), ('cambriolage_stock_min', 10), ('cambriolage_stock_max', 20),
  ('cambriolage_caisse_min', 10), ('cambriolage_caisse_max', 30), ('cambriolage_caisse_plafond', 3000),
  ('intrusion_minutes', 120), ('peine_jours_effraction_republic', 1)
ON CONFLICT (cle) DO NOTHING;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('crocheter', 3, 0), ('forcer_porte', 2, 0), ('cambrioler', 2, 0)
ON CONFLICT DO NOTHING;

-- Intrusions : qui est entré par crochetage ou effraction, où, chez qui (passage personnel du crocheteur ; objets ramassés).
CREATE TABLE IF NOT EXISTS public.crim_intrusions (
  id bigserial PRIMARY KEY, auteur text NOT NULL, serrure uuid, proprietaire text,
  pays text, ville text, batiment text, piece text, moyen text NOT NULL CHECK (moyen IN ('crochetage', 'effraction')),
  affaire bigint, cree_le timestamptz NOT NULL DEFAULT now(), expire_le timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS crim_intrusions_auteur ON public.crim_intrusions (auteur, expire_le);
ALTER TABLE public.crim_intrusions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_intrusions FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_intrusions_id_seq FROM anon, authenticated;

-- Constats différés : le propriétaire découvre le vol à son prochain passage dans le lieu ou à son prochain point de caisse.
CREATE TABLE IF NOT EXISTS public.crim_constats (
  id bigserial PRIMARY KEY, destinataire text NOT NULL, pays text, ville text, batiment text, piece text, entreprise text,
  titre text NOT NULL, corps text NOT NULL, affaire bigint, cree_le timestamptz NOT NULL DEFAULT now(), livre_le timestamptz
);
CREATE INDEX IF NOT EXISTS crim_constats_attente ON public.crim_constats (destinataire) WHERE livre_le IS NULL;
ALTER TABLE public.crim_constats ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_constats FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_constats_id_seq FROM anon, authenticated;

-- ── Formules (§ 8) ──────────────────────────────────────────────────────────────────────────────────────────────
-- Crocheter, avant dissuasion et bornes : 30 + 1 par tranche de 2 de DIS au-dessus de 50 + 15 carrière criminelle.
CREATE OR REPLACE FUNCTION public.crim_crocheter_taux_interne(p_dis numeric, p_carriere text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(public.crim_param_interne('crochetage_base', 30)
         + greatest(0, trunc((coalesce(p_dis, 50) - public.crim_param_interne('crochetage_dis_pivot', 50))
                             / public.crim_param_interne('crochetage_dis_tranche', 2)))
         + CASE WHEN p_carriere = 'criminal_c' THEN public.crim_param_interne('crochetage_carriere', 15) ELSE 0 END)::integer;
$$;

-- Forcer la porte, avant dissuasion et bornes : 40 + 3 par point de FOR au-dessus de 8 + 25 pied-de-biche + 10 carrière criminelle.
CREATE OR REPLACE FUNCTION public.crim_forcer_taux_interne(p_for numeric, p_pied_de_biche boolean, p_carriere text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(public.crim_param_interne('effraction_base', 40)
         + public.crim_param_interne('effraction_for_pas', 3) * greatest(0, coalesce(p_for, 8) - public.crim_param_interne('effraction_for_pivot', 8))
         + CASE WHEN p_pied_de_biche THEN public.crim_param_interne('effraction_pied_de_biche', 25) ELSE 0 END
         + CASE WHEN p_carriere = 'criminal_c' THEN public.crim_param_interne('effraction_carriere', 10) ELSE 0 END)::integer;
$$;

-- Le bruit trahit : être caché ne réduit pas la détection d'une effraction, le masque si.
CREATE OR REPLACE FUNCTION public.crim_forcer_mode_detection_interne(p_mode text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_mode WHEN 'cache' THEN 'decouvert' WHEN 'cache_masque' THEN 'masque' ELSE coalesce(p_mode, 'decouvert') END;
$$;

-- Part prélevée : stock 10-20 % de la pile (au moins une unité), caisse 10-30 % plafonnée à 3 000.
CREATE OR REPLACE FUNCTION public.crim_cambriolage_stock_qte_interne(p_pile numeric, p_part numeric)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN coalesce(p_pile, 0) <= 0 THEN 0
              ELSE least(floor(p_pile)::integer, greatest(1, floor(p_pile * coalesce(p_part, 0) / 100.0)::integer)) END;
$$;
CREATE OR REPLACE FUNCTION public.crim_cambriolage_caisse_montant_interne(p_caisse numeric, p_part numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(public.crim_param_interne('cambriolage_caisse_plafond', 3000),
               floor(greatest(0, coalesce(p_caisse, 0)) * coalesce(p_part, 0) / 100.0))::integer;
$$;

-- ── Porte visée : serrure posée et fermée, devant laquelle on se tient, sans en avoir la clé ──────────────────────
-- p_piece renseignée : porte d'un local (on est dans le bâtiment, hors du local) ; sinon entrée d'un bâtiment (on est dans la rue,
-- devant l'une de ses sorties).
CREATE OR REPLACE FUNCTION public.crim_porte_serrure_interne(p_auteur text, p_batiment text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a record; s public.serrures;
BEGIN
  IF coalesce(p_batiment, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT country, current_city, current_building, current_room, current_street INTO a FROM public.personnages_donnees WHERE name = p_auteur;
  IF p_piece IS NOT NULL THEN
    IF a.current_building IS DISTINCT FROM p_batiment OR a.current_room IS NOT DISTINCT FROM p_piece THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_devant_la_porte'); END IF;
    PERFORM public.serrures_fin_bail_interne(a.country, a.current_city, p_batiment, p_piece);
    SELECT * INTO s FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu'
       AND (pays, ville, batiment, piece) = (a.country, a.current_city, p_batiment, p_piece);
  ELSE
    IF a.current_building IS NOT NULL OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments r
         WHERE r.country = a.country AND r.city = a.current_city AND r.building = p_batiment AND r.noeud = a.current_street) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_devant_la_porte'); END IF;
    PERFORM public.serrures_fin_bail_interne(a.country, a.current_city, p_batiment, NULL);
    SELECT * INTO s FROM public.serrures WHERE statut = 'posee' AND cible = 'batiment'
       AND (pays, ville, batiment) = (a.country, a.current_city, p_batiment);
  END IF;
  IF s.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_serrure'); END IF;
  IF NOT s.fermee THEN RETURN jsonb_build_object('ok', false, 'raison', 'porte_ouverte'); END IF;
  IF public.serrure_cle_detenue_interne(p_auteur, s.id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'cle_detenue'); END IF;
  IF s.poseur = p_auteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'votre_porte'); END IF;
  RETURN jsonb_build_object('ok', true, 'serrure', s.id, 'numero', public.serrure_numero_interne(s.id), 'cible', s.cible,
    'proprietaire', s.poseur, 'pays', s.pays, 'ville', s.ville, 'batiment', s.batiment, 'piece', s.piece,
    'lieu', CASE WHEN s.cible = 'lieu' THEN 'votre local (' || s.piece || ', ' || s.batiment || ')' ELSE 'votre bâtiment (' || s.batiment || ')' END);
END $$;

-- Passage personnel du crocheteur : la serrure reste fermée pour tous les autres.
CREATE OR REPLACE FUNCTION public.crim_passage_valide_interne(p_nom text, p_serrure uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.crim_intrusions WHERE auteur = p_nom AND serrure = p_serrure AND moyen = 'crochetage' AND expire_le > now());
$$;

CREATE OR REPLACE FUNCTION public.crim_intrusion_noter_interne(p_auteur text, po jsonb, p_moyen text, p_affaire bigint)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.crim_intrusions (auteur, serrure, proprietaire, pays, ville, batiment, piece, moyen, affaire, expire_le)
  VALUES (p_auteur, (po ->> 'serrure')::uuid, po ->> 'proprietaire', po ->> 'pays', po ->> 'ville', po ->> 'batiment', po ->> 'piece',
          p_moyen, p_affaire, now() + make_interval(mins => public.crim_param_interne('intrusion_minutes', 120)::integer));
$$;

-- Nom de PJ d'un propriétaire (« pj:X » → X) ; une organisation ou un PNJ ne reçoit pas de constat.
CREATE OR REPLACE FUNCTION public.crim_proprietaire_pj_interne(p_proprietaire text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT d.name FROM public.personnages_donnees d WHERE d.name = regexp_replace(coalesce(p_proprietaire, ''), '^pj:', '');
$$;

-- Livraison des constats en attente : passage dans le lieu, ou point de caisse du commerce.
CREATE OR REPLACE FUNCTION public.crim_constats_livrer_interne(p_nom text, p_pays text, p_ville text, p_batiment text, p_piece text, p_entreprise text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; n integer := 0; v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
BEGIN
  IF p_nom IS NULL OR NOT EXISTS (SELECT 1 FROM public.crim_constats WHERE destinataire = p_nom AND livre_le IS NULL) THEN RETURN 0; END IF;
  FOR r IN SELECT * FROM public.crim_constats c WHERE c.destinataire = p_nom AND c.livre_le IS NULL
             AND ((p_entreprise IS NOT NULL AND c.entreprise = p_entreprise)
                  OR (p_batiment IS NOT NULL AND (c.pays, c.ville, c.batiment) = (p_pays, p_ville, p_batiment)
                      AND (c.piece IS NULL OR c.piece = p_piece)))
           ORDER BY c.id FOR UPDATE LOOP
    PERFORM public.mail_systeme_poser_interne('Événement', r.destinataire, r.titre, r.corps, v_date);
    UPDATE public.crim_constats SET livre_le = now() WHERE id = r.id;
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

-- ── Raccords ────────────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Résolution commune : l'échec critique peut ne pas coûter de moral (crochetage : seul le kit casse, § 8).
SELECT pg_temp.rp_raccorder('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $a$IF v_crit_e THEN$a$,
  $b$IF v_crit_e AND coalesce((p ->> 'critique_moral')::boolean, true) /* crim_critique_moral_v1 */ THEN$b$,
  'crim_critique_moral_v1');

-- Combat gagné pendant un cambriolage devant témoin : le butin est livré, comme pour le vol sur une personne.
SELECT pg_temp.rp_raccorder('public.crim_resoudre_suite_interne(bigint,text)'::regprocedure,
  $a$IF f.acte = 'voler' THEN PERFORM public.crim_voler_livrer_interne(f.id); END IF; /* crim_vol_combat_v1 */$a$,
  $b$IF f.acte = 'voler' THEN PERFORM public.crim_voler_livrer_interne(f.id); END IF; /* crim_vol_combat_v1 */
    IF f.acte = 'cambrioler' THEN PERFORM public.crim_cambrioler_livrer_interne(f.id); END IF; /* crim_cambriolage_combat_v1 */$b$,
  'crim_cambriolage_combat_v1');

-- Passage du crocheteur (porte d'un local, entrée d'un bâtiment).
SELECT pg_temp.rp_raccorder('public.serrure_porte_fermee_interne(text,text,text,text,text)'::regprocedure,
  $a$RETURN v_id IS NOT NULL AND NOT public.serrure_cle_detenue_interne(p_nom, v_id);$a$,
  $b$RETURN v_id IS NOT NULL AND NOT public.serrure_cle_detenue_interne(p_nom, v_id) AND NOT public.crim_passage_valide_interne(p_nom, v_id); /* crim_passage_v1 */$b$,
  'crim_passage_v1');
SELECT pg_temp.rp_raccorder('public.serrure_batiment_ferme_interne(text,text,text,text)'::regprocedure,
  $a$RETURN v_id IS NOT NULL AND NOT public.serrure_cle_detenue_interne(p_nom, v_id);$a$,
  $b$RETURN v_id IS NOT NULL AND NOT public.serrure_cle_detenue_interne(p_nom, v_id) AND NOT public.crim_passage_valide_interne(p_nom, v_id); /* crim_passage_v1 */$b$,
  'crim_passage_v1');

-- Constat au prochain passage du propriétaire dans le lieu.
SELECT pg_temp.rp_raccorder('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure,
  $a$UPDATE public.personnages_donnees SET current_building=p_batiment,current_room=p_piece,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;$a$,
  $b$UPDATE public.personnages_donnees SET current_building=p_batiment,current_room=p_piece,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;
  PERFORM public.crim_constats_livrer_interne(p_nom, p.country, p.current_city, p_batiment, p_piece, NULL); /* crim_constat_passage_v1 */$b$,
  'crim_constat_passage_v1');

-- Constat au prochain point de caisse (retrait ou apport de fonds du propriétaire).
SELECT pg_temp.rp_raccorder('public.retirer_caisse_fonds(text,text,integer)'::regprocedure,
  $a$SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;$a$,
  $b$PERFORM public.crim_constats_livrer_interne(p_acteur, NULL, NULL, NULL, NULL, p_fonds_id); /* crim_constat_caisse_v1 */
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;$b$,
  'crim_constat_caisse_v1');
SELECT pg_temp.rp_raccorder('public.alimenter_caisse_fonds(text,text,integer)'::regprocedure,
  $a$SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;$a$,
  $b$PERFORM public.crim_constats_livrer_interne(p_acteur, NULL, NULL, NULL, NULL, p_fonds_id); /* crim_constat_caisse_v1 */
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;$b$,
  'crim_constat_caisse_v1');

-- ── Crocheter (§ 8) ─────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_crocheter(p_batiment text, p_piece text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('batiment', p_batiment, 'piece', p_piece);
  v jsonb; m record; po jsonb; v_kit integer; v_usages integer; v_paie jsonb; v_taux integer; r jsonb; v_reste integer;
  v_detruit boolean := false; v_proprio text; v_out jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crim_crocheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, career, est_emprisonne, inventory INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  po := public.crim_porte_serrure_interne(a, p_batiment, p_piece);
  IF coalesce((po ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN po; END IF;
  -- Le kit le plus usé d'abord.
  SELECT (o - 1)::integer, coalesce((e ->> 'usages_restants')::integer, public.crim_param_interne('kit_usages', 5)::integer)
    INTO v_kit, v_usages
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY t(e, o)
   WHERE e ->> 'generique_id' = 'kit_crochetage'
   ORDER BY coalesce((e ->> 'usages_restants')::integer, 99), o LIMIT 1;
  IF v_kit IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'kit_requis'); END IF;

  v_paie := public.payer_ordre(a, 'crocheter', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_taux := public.crim_crocheter_taux_interne(public.crim_stat_interne(a, 'dis', 50), m.career);
  v_proprio := po ->> 'proprietaire';
  -- Aucune cible présente : personne ne remarque un échec ; la réussite ne laisse aucune trace (pas de détection).
  r := public.crim_resoudre_interne('crocheter', a, NULL, jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('crochetage_min', 5), 'max', public.crim_param_interne('crochetage_max', 80),
    'critique_identifie', false, 'critique_moral', false, 'combat', false, 'detection', false,
    'acte_peine_reussite', 'effraction', 'acte_peine_echec', 'effraction', 'type_recherche', 'delit_mineur',
    'indices', jsonb_build_object('outil', 'kit_crochetage'), 'serrure', po ->> 'serrure', 'porte', po - 'ok' - 'proprietaire',
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));
  -- L'affaire est enregistrée au nom du propriétaire (enquête sur plainte, lot 6).
  UPDATE public.crim_affaires SET cible = v_proprio, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;

  IF (r ->> 'reussi')::boolean THEN
    v_reste := v_usages - 1;
    IF v_reste <= 0 THEN
      UPDATE public.personnages_donnees SET inventory = inventory - v_kit WHERE name = a; v_detruit := true;
    ELSE
      UPDATE public.personnages_donnees SET inventory = jsonb_set(inventory, ARRAY[v_kit::text, 'usages_restants'], to_jsonb(v_reste)) WHERE name = a;
    END IF;
    PERFORM public.crim_intrusion_noter_interne(a, po, 'crochetage', (r ->> 'affaire')::bigint);
  ELSIF (r ->> 'echec_critique')::boolean THEN
    -- Le kit casse dans la serrure : le propriétaire trouve la trace d'une tentative, sans nom.
    UPDATE public.personnages_donnees SET inventory = inventory - v_kit WHERE name = a; v_detruit := true; v_reste := 0;
    UPDATE public.crim_affaires SET trace = true, remarque = true, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
    PERFORM public.mail_systeme_poser_interne('Événement', v_proprio, 'Tentative de crochetage',
      'Un crochet brisé est resté coincé dans la serrure n° ' || (po ->> 'numero') || ' de ' || (po ->> 'lieu')
      || ' : quelqu''un a tenté de la crocheter. La serrure a tenu.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  ELSE
    v_reste := v_usages;
  END IF;

  v_out := jsonb_build_object('ok', true, 'paie', v_paie, 'kit_usages_restants', greatest(0, v_reste), 'kit_detruit', v_detruit,
             'entrer', CASE WHEN (r ->> 'reussi')::boolean THEN jsonb_build_object('batiment', po ->> 'batiment', 'piece', po ->> 'piece') END)
    || (r - 'notifie' - 'affaire' - 'garde' - 'remarque')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche, 'inventory', inventory, 'revision', inventory_revision)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crim_crocheter', prm, v_out);
END $$;

-- ── Forcer la porte (§ 8) ───────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_forcer_porte(p_batiment text, p_piece text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('batiment', p_batiment, 'piece', p_piece);
  v jsonb; m record; po jsonb; v_pied boolean; v_paie jsonb; v_taux integer; v_mode text; r jsonb; v_out jsonb; v_lieu text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crim_forcer_porte', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, career, est_emprisonne, inventory INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  po := public.crim_porte_serrure_interne(a, p_batiment, p_piece);
  IF coalesce((po ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN po; END IF;
  v_pied := EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) e
                     WHERE e ->> 'generique_id' = 'pied_de_biche');

  v_paie := public.payer_ordre(a, 'forcer_porte', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_taux := public.crim_forcer_taux_interne(public.crim_stat_interne(a, 'FOR', 8), v_pied, m.career);
  v_mode := public.crim_mode_action_interne(a);
  v_lieu := replace(replace(po ->> 'lieu', '{', '('), '}', ')');
  -- Le propriétaire est la « victime » prévenue (absent : il ne voit pas l'auteur, d'où decouvert_identifie = false).
  r := public.crim_resoudre_interne('forcer_porte', a, po ->> 'proprietaire', jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('effraction_min', 10), 'max', public.crim_param_interne('effraction_max', 95),
    'critique_echec_part', 0, 'combat', false, 'remarque_echec', 100, 'decouvert_identifie', false,
    'mode', public.crim_forcer_mode_detection_interne(v_mode),
    'detection_base', public.crim_param_interne('effraction_detection', 60), 'detection_min', public.crim_param_interne('detection_min', 5),
    'acte_peine_reussite', 'effraction', 'acte_peine_echec', 'effraction', 'type_recherche', 'delit_mineur',
    'cible_info', jsonb_build_object('pj', true, 'nom', po ->> 'proprietaire'),
    'titre_reussite', 'Effraction', 'titre_echec', 'Tentative d''effraction',
    'msg_reussite', 'Votre porte a été forcée : ' || v_lieu || '. La serrure n° ' || (po ->> 'numero') || ' est détruite.',
    'msg_echec', 'Quelqu''un a tenté de forcer votre porte : ' || v_lieu || '. La serrure a tenu.',
    'indices', jsonb_build_object('outil', CASE WHEN v_pied THEN 'pied_de_biche' ELSE 'mains_nues' END),
    'mode_reel', v_mode, 'pied_de_biche', v_pied, 'serrure', po ->> 'serrure', 'porte', po - 'ok' - 'proprietaire',
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));

  IF (r ->> 'reussi')::boolean THEN
    -- Serrure détruite pour tout le monde (règle existante : jamais récupérable ; ses clés n'ouvrent plus rien).
    UPDATE public.serrures SET statut = 'detruite', fermee = false, detruite_le = now(), motif_destruction = 'effraction'
     WHERE id = (po ->> 'serrure')::uuid;
    PERFORM public.crim_intrusion_noter_interne(a, po, 'effraction', (r ->> 'affaire')::bigint);
  END IF;

  v_out := jsonb_build_object('ok', true, 'paie', v_paie, 'pied_de_biche', v_pied,
             'entrer', CASE WHEN (r ->> 'reussi')::boolean THEN jsonb_build_object('batiment', po ->> 'batiment', 'piece', po ->> 'piece') END)
    || (r - 'notifie' - 'affaire' - 'garde' - 'remarque' - 'mode')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche, 'resources', resources)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crim_forcer_porte', prm, v_out);
END $$;

-- ── À l'intérieur (§ 8) ─────────────────────────────────────────────────────────────────────────────────────────
-- Témoin d'un vol à l'intérieur : la personne présente la plus perceptive (PJ, même caché ; PNJ référencé en service ;
-- à défaut, l'employé au comptoir d'un commerce ouvert au public). NULL = lieu vide. Jamais un membre du groupe de l'auteur.
CREATE OR REPLACE FUNCTION public.crim_temoin_interne(p_auteur text, p_entreprise text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a record; v_def numeric := public.crim_param_interne('vol_per_defaut', 8); v_best jsonb; c jsonb; x record; v_proprio text; v_ouvert boolean;
BEGIN
  SELECT country, current_city, current_building, current_room INTO a FROM public.personnages_donnees WHERE name = p_auteur;
  FOR x IN SELECT d.name FROM public.personnages_donnees d
            WHERE (d.country, d.current_city, d.current_building, d.current_room) = (a.country, a.current_city, a.current_building, a.current_room)
              AND d.name <> p_auteur
              AND (coalesce(jsonb_typeof(d.est_emprisonne), 'null') = 'null' OR d.est_emprisonne = 'false'::jsonb)
              AND NOT EXISTS (SELECT 1 FROM public.groupe_participants_interne(p_auteur) g WHERE g.identifiant = d.name) LOOP
    c := jsonb_build_object('ok', true, 'pj', true, 'nom', x.name, 'via_jeton', false, 'per', public.crim_stat_interne(x.name, 'PER', v_def),
           'pays', a.country, 'ville', a.current_city, 'batiment', a.current_building, 'piece', a.current_room);
    IF v_best IS NULL OR (c ->> 'per')::numeric > (v_best ->> 'per')::numeric THEN v_best := c; END IF;
  END LOOP;
  FOR x IN SELECT p.id FROM public.pnj_membres p
            WHERE p.statut = 'actif' AND coalesce(p.classe, '') <> 'gamma' AND coalesce(p.pa, 0) > 0 AND public.pnj_co_present(p_auteur, p.id)
              AND NOT EXISTS (SELECT 1 FROM public.groupe_participants_interne(p_auteur) g WHERE g.identifiant = p.id) LOOP
    c := public.crim_cible_resoudre_interne(p_auteur, x.id);
    IF coalesce((c ->> 'ok')::boolean, false) AND (v_best IS NULL OR (c ->> 'per')::numeric > (v_best ->> 'per')::numeric) THEN v_best := c; END IF;
  END LOOP;
  IF v_best IS NULL AND p_entreprise IS NOT NULL THEN
    v_ouvert := NOT EXISTS (SELECT 1 FROM public.serrures s WHERE s.statut = 'posee' AND s.fermee AND s.pays = a.country AND s.ville = a.current_city
                             AND s.batiment = a.current_building AND (s.cible = 'batiment' OR (s.cible = 'lieu' AND s.piece = a.current_room)))
             -- Un commerce où l'on vient d'entrer par crochetage ou effraction n'est pas « ouvert » : pas d'employé au comptoir.
             AND NOT EXISTS (SELECT 1 FROM public.crim_intrusions i WHERE i.expire_le > now() AND i.pays = a.country AND i.ville = a.current_city
                             AND i.batiment = a.current_building AND (i.piece IS NULL OR i.piece = a.current_room));
    IF v_ouvert THEN
      SELECT public.crim_proprietaire_pj_interne(e.data ->> 'proprietaire') INTO v_proprio FROM public.entreprises e WHERE e.id = p_entreprise;
      v_best := jsonb_build_object('ok', true, 'pj', false, 'pnj_id', 'comptoir:' || p_entreprise, 'nom', 'l''employé(e) au comptoir',
        'via_jeton', false, 'per', v_def, 'employeur', v_proprio, 'pa', 1, 'profil_combat', false, 'comptoir', true,
        'pays', a.country, 'ville', a.current_city, 'batiment', a.current_building, 'piece', a.current_room);
    END IF;
  END IF;
  RETURN v_best;
END $$;

-- Libellé d'un produit de commerce (carte des commerces, recettes d'armurerie, quincaillerie), sinon son identifiant.
CREATE OR REPLACE FUNCTION public.crim_produit_libelle_interne(p_produit text, p_pays text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v text;
BEGIN
  SELECT label INTO v FROM public.recettes_commerce WHERE id = p_produit;
  IF v IS NULL THEN BEGIN EXECUTE 'SELECT label FROM public.recettes_production WHERE id = $1 AND pays = $2 LIMIT 1' INTO v USING p_produit, p_pays;
                  EXCEPTION WHEN others THEN v := NULL; END; END IF;
  RETURN coalesce(v, replace(p_produit, '_', ' '));
END $$;

CREATE OR REPLACE FUNCTION public.crim_cambriolage_description_interne(p_plan jsonb, p_devise text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_plan ->> 'genre'
    WHEN 'caisse' THEN (p_plan ->> 'montant') || ' ' || coalesce(p_devise, 'FR') || ' dans la caisse'
    WHEN 'stock' THEN (p_plan ->> 'qte') || ' × ' || coalesce(p_plan ->> 'label', p_plan ->> 'produit')
    ELSE coalesce(p_plan ->> 'nom', 'du matériel') END;
$$;

-- Livraison du butin (réussite immédiate ou combat gagné), revalidée sur l'état réel, dans la même transaction.
-- Le propriétaire (PJ) découvrira le vol à son prochain passage / point de caisse, sauf s'il en a été le témoin.
CREATE OR REPLACE FUNCTION public.crim_cambrioler_livrer_interne(p_affaire bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.crim_affaires%ROWTYPE; pl jsonb; e public.equipements_installes; v_data jsonb; v_dispo numeric; v_q integer; v_m integer;
  v_dep jsonb; v_desc text; v_proprio text; v_devise text; v_livre boolean := false;
BEGIN
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  IF NOT FOUND OR f.acte <> 'cambrioler' THEN RETURN jsonb_build_object('livre', false); END IF;
  pl := f.details #> '{params,butin_plan}';
  IF pl IS NULL OR coalesce((f.details ->> 'livre')::boolean, false) THEN RETURN jsonb_build_object('livre', false, 'deja', true); END IF;
  v_devise := coalesce(pl ->> 'devise', 'FR');
  IF pl ->> 'genre' = 'materiel' THEN
    SELECT * INTO e FROM public.equipements_installes WHERE id = (pl ->> 'equipement')::uuid FOR UPDATE;
    IF e.id IS NOT NULL AND (e.pays, e.ville, e.batiment, e.piece) IS NOT DISTINCT FROM (f.pays, f.ville, f.batiment, f.piece) THEN
      v_dep := public.inventaire_deposer_interne(f.auteur, e.objet, false);
      IF coalesce((v_dep ->> 'ok')::boolean, false) THEN DELETE FROM public.equipements_installes WHERE id = e.id; v_livre := true; END IF;
    END IF;
    v_desc := coalesce(pl ->> 'nom', 'du matériel');
  ELSE
    SELECT data INTO v_data FROM public.entreprises WHERE id = pl ->> 'entreprise' FOR UPDATE;
    IF v_data IS NOT NULL AND pl ->> 'genre' = 'stock' THEN
      v_dispo := greatest(0, coalesce((v_data -> 'stockProduits' ->> (pl ->> 'produit'))::numeric, 0));
      v_q := least((pl ->> 'qte')::integer, floor(v_dispo)::integer);
      IF v_q > 0 THEN
        v_dep := public.inventaire_deposer_interne(f.auteur, jsonb_build_object('name', coalesce(pl ->> 'label', pl ->> 'produit'), 'icon', 'ti-package',
                   'stackable', true, 'stackKey', 'marchandise_' || (pl ->> 'produit'), 'qty', v_q, 'marchandise', pl ->> 'produit',
                   'desc', 'Marchandise dérobée dans un commerce.'), false);
        v_q := CASE WHEN coalesce((v_dep ->> 'ok')::boolean, false) THEN coalesce((v_dep ->> 'qte')::integer, v_q) ELSE 0 END;
        IF v_q > 0 THEN
          UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockProduits', pl ->> 'produit'], to_jsonb(v_dispo - v_q)), updated_at = now()
           WHERE id = pl ->> 'entreprise';
          v_livre := true;
        END IF;
      END IF;
      v_desc := v_q || ' × ' || coalesce(pl ->> 'label', pl ->> 'produit');
    ELSIF v_data IS NOT NULL AND pl ->> 'genre' = 'caisse' THEN
      v_dispo := greatest(0, coalesce((v_data ->> 'caisse')::numeric, 0));
      v_m := least((pl ->> 'montant')::integer, floor(v_dispo)::integer);
      IF v_m > 0 THEN
        UPDATE public.entreprises SET data = jsonb_set(data, '{caisse}', to_jsonb(v_dispo - v_m)), updated_at = now() WHERE id = pl ->> 'entreprise';
        PERFORM public.argent_crediter_interne(f.auteur, v_m, 'liquide');
        v_livre := true;
      END IF;
      v_desc := coalesce(v_m, 0) || ' ' || v_devise || ' dans la caisse';
    END IF;
  END IF;
  UPDATE public.crim_affaires SET details = details || jsonb_build_object('livre', v_livre, 'butin_livre', v_desc), maj_le = now() WHERE id = f.id;
  v_proprio := public.crim_proprietaire_pj_interne(pl ->> 'proprietaire');
  IF v_livre AND v_proprio IS NOT NULL AND v_proprio <> f.auteur AND NOT (f.cible IS NOT DISTINCT FROM v_proprio AND f.remarque) THEN
    INSERT INTO public.crim_constats (destinataire, pays, ville, batiment, piece, entreprise, titre, corps, affaire)
    VALUES (v_proprio, f.pays, f.ville, f.batiment, f.piece, pl ->> 'entreprise', 'Vol constaté',
      CASE pl ->> 'genre'
        WHEN 'caisse' THEN 'En faisant le point, vous constatez qu''il manque ' || v_m || ' ' || v_devise || ' dans la caisse (' || f.batiment || '). Vous pouvez porter plainte pour vol.'
        WHEN 'stock' THEN 'Vous constatez qu''il manque ' || v_desc || ' dans votre stock (' || f.batiment || '). Vous pouvez porter plainte pour vol.'
        ELSE 'En revenant, vous constatez que votre matériel a disparu : ' || v_desc || ' (' || coalesce(f.piece, f.batiment) || '). Vous pouvez porter plainte pour vol.' END,
      f.id);
  END IF;
  RETURN jsonb_build_object('livre', v_livre, 'description', v_desc);
END $$;

-- Ce qui peut s'emporter ici (sans rien révéler des personnes présentes ni du montant de la caisse).
CREATE OR REPLACE FUNCTION public.crim_cambriolage_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_ent text; v_data jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_ent := public.commerce_de_la_piece_interne(a);
  SELECT data INTO v_data FROM public.entreprises WHERE id = v_ent;
  IF v_data IS NOT NULL AND (v_data ->> 'proprietaire' = a OR v_data ->> 'proprietaire' = 'pj:' || a) THEN v_data := NULL; END IF;
  RETURN jsonb_build_object('ok', true,
    'materiel', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'generique', e.generique_id, 'nom', e.objet ->> 'name') ORDER BY e.installe_le)
       FROM public.equipements_installes e WHERE (e.pays, e.ville, e.batiment, e.piece) = (d.country, d.current_city, d.current_building, d.current_room)
        AND e.generique_id <> 'armoire_souvenirs' AND NOT public.equipement_a_moi_interne(e.proprietaire, a)), '[]'::jsonb),
    'stock', coalesce((SELECT jsonb_agg(jsonb_build_object('produit', k, 'label', public.crim_produit_libelle_interne(k, d.country)) ORDER BY k)
       FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_data -> 'stockProduits') = 'object' THEN v_data -> 'stockProduits' ELSE '{}'::jsonb END) s(k, q)
      WHERE q ~ '^[0-9.]+$' AND q::numeric >= 1), '[]'::jsonb),
    'caisse', v_data IS NOT NULL AND coalesce(v_data ->> 'caisse', '') ~ '^[0-9]+(\.[0-9]+)?$' AND (v_data ->> 'caisse')::numeric >= 1);
END $$;

CREATE OR REPLACE FUNCTION public.crim_cambrioler_interne(a text, p_cible text, p_ref text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb := jsonb_build_object('cible', p_cible, 'ref', p_ref); v jsonb; m record; e public.equipements_installes;
  v_ent text; v_data jsonb; v_plan jsonb; v_part integer; v_pile numeric; v_paie jsonb; t jsonb; r jsonb; v_liv jsonb := '{}'::jsonb;
  v_desc text; v_devise text; v_dis numeric; v_per numeric; v_proprio text; v_out jsonb; v_jets jsonb; v_place integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_cible NOT IN ('materiel', 'stock', 'caisse') THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crim_cambrioler', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, career, country, current_city, current_building, current_room, est_emprisonne, inventory INTO m
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF m.current_building IS NULL OR m.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_devise := CASE WHEN m.country = 'soviet' THEN 'PSK' ELSE 'FR' END;
  v_place := public.inventaire_place_restante(m.inventory);
  v_jets := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END;

  IF p_cible = 'materiel' THEN
    IF coalesce(p_ref, '') !~ '^[0-9a-f-]{36}$' THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
    SELECT * INTO e FROM public.equipements_installes WHERE id = p_ref::uuid FOR UPDATE;
    IF e.id IS NULL OR e.generique_id = 'armoire_souvenirs' THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
    IF (e.pays, e.ville, e.batiment, e.piece) IS DISTINCT FROM (m.country, m.current_city, m.current_building, m.current_room) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
    IF public.equipement_a_moi_interne(e.proprietaire, a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_vous'); END IF;
    IF v_place < greatest(1, coalesce(nullif(e.objet ->> 'encombrement', '')::numeric, 1)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    v_plan := jsonb_build_object('genre', 'materiel', 'equipement', e.id, 'nom', coalesce(e.objet ->> 'name', e.generique_id),
                                 'generique', e.generique_id, 'proprietaire', e.proprietaire);
  ELSE
    v_ent := public.commerce_de_la_piece_interne(a);
    SELECT data INTO v_data FROM public.entreprises WHERE id = v_ent;
    IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_commerce'); END IF;
    IF v_data ->> 'proprietaire' = a OR v_data ->> 'proprietaire' = 'pj:' || a THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_vous'); END IF;
    IF p_cible = 'stock' THEN
      v_pile := CASE WHEN coalesce(v_data -> 'stockProduits' ->> coalesce(p_ref, ''), '') ~ '^[0-9.]+$' THEN (v_data -> 'stockProduits' ->> p_ref)::numeric ELSE 0 END;
      IF v_pile < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_vide'); END IF;
      IF v_place < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
      v_part := public.crim_param_interne('cambriolage_stock_min', 10)::integer
                + floor(random() * (public.crim_param_interne('cambriolage_stock_max', 20) - public.crim_param_interne('cambriolage_stock_min', 10) + 1))::integer;
      v_plan := jsonb_build_object('genre', 'stock', 'entreprise', v_ent, 'produit', p_ref, 'part', v_part,
                  'qte', least(v_place, public.crim_cambriolage_stock_qte_interne(v_pile, v_part)),
                  'label', public.crim_produit_libelle_interne(p_ref, m.country), 'proprietaire', v_data ->> 'proprietaire');
    ELSE
      IF coalesce(v_data ->> 'caisse', '') !~ '^[0-9]+(\.[0-9]+)?$' OR (v_data ->> 'caisse')::numeric < 1 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide'); END IF;
      v_part := public.crim_param_interne('cambriolage_caisse_min', 10)::integer
                + floor(random() * (public.crim_param_interne('cambriolage_caisse_max', 30) - public.crim_param_interne('cambriolage_caisse_min', 10) + 1))::integer;
      v_plan := jsonb_build_object('genre', 'caisse', 'entreprise', v_ent, 'part', v_part, 'devise', v_devise,
                  'montant', public.crim_cambriolage_caisse_montant_interne((v_data ->> 'caisse')::numeric, v_part),
                  'proprietaire', v_data ->> 'proprietaire');
      IF (v_plan ->> 'montant')::integer <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide'); END IF;
    END IF;
  END IF;

  v_paie := public.payer_ordre(a, 'cambrioler', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_desc := replace(replace(public.crim_cambriolage_description_interne(v_plan, v_devise), '{', '('), '}', ')');
  t := public.crim_temoin_interne(a, v_ent);

  IF t IS NULL THEN
    -- Lieu vide : pas de jet de réussite, mais un jet de détection par vol (30, −20 caché, −10 masqué, min 5).
    r := public.crim_resoudre_interne('cambrioler', a, NULL, jsonb_build_object(
      'reussite_auto', true, 'detection_base', public.crim_param_interne('cambriolage_detection', 30),
      'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur',
      'indices', jsonb_build_object('butin', p_cible), 'butin', p_cible, 'butin_plan', v_plan, 'lieu_vide', true, 'jets', v_jets));
    v_proprio := public.crim_proprietaire_pj_interne(v_plan ->> 'proprietaire');
    UPDATE public.crim_affaires SET cible = coalesce(v_proprio, v_plan ->> 'proprietaire'), maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
  ELSE
    -- Personne présente : règles du vol sur une personne (lot 3) ; caisse = argent, matériel et stock = objet.
    v_dis := public.crim_stat_interne(a, 'dis', 50);
    v_per := public.crim_per_groupe_interne(t);
    r := public.crim_resoudre_interne('cambrioler', a, CASE WHEN (t ->> 'pj')::boolean THEN t ->> 'nom' ELSE t ->> 'pnj_id' END, jsonb_build_object(
      'taux', public.crim_voler_taux_interne(CASE WHEN p_cible = 'caisse' THEN 'argent' ELSE 'hasard' END, v_dis, v_per, m.career),
      'min', public.crim_param_interne('vol_min', 5), 'max', public.crim_param_interne('vol_max', 85),
      'critique_reussite_part', public.crim_param_interne('vol_critique_reussite_part', 5), 'critique_sans_detection', true,
      'combat', true, 'per_victime', (t ->> 'per')::numeric, 'remarque_echec', public.crim_voler_remarque_interne(v_per, v_dis),
      'detection_base', public.crim_param_interne('cambriolage_detection', 30), 'detection_min', public.crim_param_interne('detection_min', 5),
      'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur', 'cible_info', t,
      'titre_reussite', 'Vol', 'titre_echec', 'Tentative de vol',
      'msg_reussite', '{Auteur} a dérobé ' || v_desc || ' sous vos yeux.',
      'msg_echec', '{Auteur} a tenté de dérober ' || v_desc || ' sous vos yeux.',
      'msg_employeur_reussite', '{Auteur} a dérobé ' || v_desc || ' sous les yeux de votre employé(e) {cible}. Une plainte a été déposée.',
      'msg_employeur_echec', '{Auteur} a tenté de dérober ' || v_desc || ' sous les yeux de votre employé(e) {cible}. Une plainte a été déposée.',
      'motif_plainte', 'Vol dans votre commerce ou votre local',
      'indices', jsonb_build_object('butin', p_cible), 'butin', p_cible, 'butin_plan', v_plan, 'temoin_comptoir', coalesce((t ->> 'comptoir')::boolean, false),
      'jets', v_jets));
  END IF;

  IF r ->> 'issue' = 'reussite' THEN
    v_liv := public.crim_cambrioler_livrer_interne((r ->> 'affaire')::bigint);
  ELSIF r ->> 'issue' = 'combat' THEN
    r := public.crim_combat_ouvrir_interne(a, r, t, 'mains', p_requete);
  END IF;
  IF r ->> 'issue' = 'reussite' AND coalesce((v_liv ->> 'livre')::boolean, false) THEN
    PERFORM public.crime_trace_rumeur_interne(a, 'vol', coalesce(public.crim_proprietaire_pj_interne(v_plan ->> 'proprietaire'), v_plan ->> 'proprietaire'));
  END IF;

  v_out := jsonb_build_object('ok', true, 'cible', p_cible, 'paie', v_paie, 'lieu_vide', t IS NULL,
             'livre', coalesce((v_liv ->> 'livre')::boolean, false), 'description', v_liv ->> 'description')
    || (r - 'notifie' - 'affaire' - 'garde')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche, 'liquide', liquide, 'arg', arg,
                                  'inventory', inventory, 'revision', inventory_revision)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crim_cambrioler', prm, v_out);
END $$;

CREATE OR REPLACE FUNCTION public.crim_cambrioler(p_cible text, p_ref text, p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_cambrioler_interne(public.mon_personnage(), p_cible, p_ref, p_requete);
$$;

-- Ancienne route du matériel installé (3 PA, jet de duplicité, arrestation) : désormais la règle du cambriolage (2 PA, sans jet
-- dans un lieu vide, détection par vol). Réponse enrichie de « reussi » / « repere » pour l'ancien écran.
CREATE OR REPLACE FUNCTION public.voler_materiel(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r jsonb;
BEGIN
  r := public.crim_cambrioler_interne(public.mon_personnage(), 'materiel', p_id::text, gen_random_uuid());
  IF coalesce((r ->> 'ok')::boolean, false) THEN
    r := r || jsonb_build_object('reussi', coalesce((r ->> 'livre')::boolean, false), 'repere', false, 'generique', NULL);
  END IF;
  RETURN r;
END $$;

-- Objets déposés ramassés après une effraction : pas un vol (§ 8), mais une affaire au nom du propriétaire, qui l'apprend
-- à son prochain passage et peut porter plainte pour vol.
CREATE OR REPLACE FUNCTION public.crim_ramasser_constater_interne(p_nom text, p_objet jsonb)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; i public.crim_intrusions; r jsonb; v_nom text := coalesce(p_objet ->> 'name', 'un objet');
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_nom;
  SELECT * INTO i FROM public.crim_intrusions x
   WHERE x.auteur = p_nom AND x.expire_le > now() AND (x.pays, x.ville, x.batiment) = (d.country, d.current_city, d.current_building)
     AND (x.piece IS NULL OR x.piece = d.current_room) AND x.proprietaire IS DISTINCT FROM p_nom
   ORDER BY x.id DESC LIMIT 1;
  IF i.id IS NULL THEN RETURN NULL; END IF;
  r := public.crim_resoudre_interne('ramasser', p_nom, NULL, jsonb_build_object('reussite_auto', true, 'detection', false,
         'indices', jsonb_build_object('objet', v_nom), 'objet', v_nom, 'intrusion', i.id));
  UPDATE public.crim_affaires SET cible = i.proprietaire, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
  IF public.crim_proprietaire_pj_interne(i.proprietaire) IS NOT NULL THEN
    INSERT INTO public.crim_constats (destinataire, pays, ville, batiment, piece, titre, corps, affaire)
    VALUES (i.proprietaire, d.country, d.current_city, d.current_building, d.current_room, 'Objet disparu',
            'En repassant, vous constatez que « ' || replace(replace(v_nom, '{', '('), '}', ')') || ' », que vous aviez déposé ici ('
            || coalesce(d.current_room, d.current_building) || '), a disparu. Vous pouvez porter plainte pour vol.', (r ->> 'affaire')::bigint);
  END IF;
  RETURN (r ->> 'affaire')::bigint;
END $$;

SELECT pg_temp.rp_raccorder('public.objet_abandonne_ramasser(text)'::regprocedure,
  $a$UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;$a$,
  $b$UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  PERFORM public.crim_ramasser_constater_interne(v_moi, v_objet); /* crim_ramasser_v1 */$b$,
  'crim_ramasser_v1');

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_crocheter_taux_interne(numeric,text)', 'crim_forcer_taux_interne(numeric,boolean,text)',
    'crim_cambriolage_stock_qte_interne(numeric,numeric)', 'crim_cambriolage_caisse_montant_interne(numeric,numeric)',
    'crim_porte_serrure_interne(text,text,text)', 'crim_passage_valide_interne(text,uuid)', 'crim_intrusion_noter_interne(text,jsonb,text,bigint)',
    'crim_proprietaire_pj_interne(text)', 'crim_constats_livrer_interne(text,text,text,text,text,text)', 'crim_temoin_interne(text,text)',
    'crim_produit_libelle_interne(text,text)', 'crim_cambrioler_livrer_interne(bigint)', 'crim_cambrioler_interne(text,text,text,uuid)',
    'crim_ramasser_constater_interne(text,jsonb)', 'crim_forcer_mode_detection_interne(text)', 'crim_cambriolage_description_interne(jsonb,text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crim_crocheter(text,text,uuid)', 'crim_forcer_porte(text,text,uuid)', 'crim_cambriolage_lire()',
    'crim_cambrioler(text,text,uuid)', 'voler_materiel(uuid)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
