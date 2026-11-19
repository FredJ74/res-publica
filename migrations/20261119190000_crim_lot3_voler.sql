-- CRIMINALITÉ — LOT 3 : vol sur une personne (GAME-DESIGN-CRIMINALITE.md §§ 6, 7, 15 ; Fred, 18-19/11/2026).
-- • crime_voler(cible, butin, type, requete) : UNE seule fonction serveur de vol sur une personne (PJ, individu masqué par jeton,
--   PNJ référencé), résolue par la résolution commune crim_resoudre_interne (jet, dissuasion #135 une fois, réussite critique,
--   échec critique, passage au combat, remarque de l'échec, détection, messages selon le mode, plainte de l'employeur, affaire,
--   peine d'office). Aucune copie de jet, de détection ni de combat ici.
--   Butin : argent liquide (jamais la banque), objet au hasard, objet précis (un TYPE, sans voir l'inventaire).
--   Coûts 2 / 2 / 3 PA. Réussite 55 / 45 / 25 + DIS/3 au-dessus de 50 − 3 × (PER − 8) (PER de groupe) + 15 carrière
--   (criminelle, renseignement, escort), bornes 5-85. Butin 10-30 % du liquide, plafond 2 000 par vol. Une unité par pile.
--   Réussite critique (5 % des réussites) : découverte au prochain réveil (pa_repos_nocturne), sans détection.
--   Voleur identifié : 1 jour de prison d'office (Républia, paramètre par empire).
-- • L'ancienne signature crime_voler(text, text, boolean, integer, integer) répond « ordre_remplace ».
-- • crim_combat_ouvrir_interne : ouverture du combat commune (Neutraliser raccordé, Voler l'utilise).
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia tant qu'ils n'ont pas les leurs) ─────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('vol_base_argent', 55), ('vol_base_hasard', 45), ('vol_base_precis', 25), ('vol_min', 5), ('vol_max', 85),
  ('vol_carriere', 15), ('vol_per_pivot', 8), ('vol_per_defaut', 8), ('vol_dis_pivot', 50),
  ('vol_detection', 30), ('vol_critique_reussite_part', 5),
  ('vol_remarque_base', 50), ('vol_remarque_min', 10), ('vol_remarque_max', 90),
  ('vol_part_min', 10), ('vol_part_max', 30), ('vol_part_carriere', 5), ('vol_plafond', 2000),
  ('peine_jours_vol_republic', 1)
ON CONFLICT (cle) DO NOTHING;

-- Objet précis : 3 PA (variante tarifaire de l'ordre « voler », déclarée à l'écran dans plateau-criminalite.js).
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('voler', 3, 0) ON CONFLICT DO NOTHING;

-- Découvertes différées (réussite critique : la victime ne s'aperçoit du vol qu'au prochain réveil).
CREATE TABLE IF NOT EXISTS public.crim_vols_differes (
  id bigserial PRIMARY KEY,
  destinataire text NOT NULL, titre text NOT NULL, corps text NOT NULL, affaire bigint,
  cree_le timestamptz NOT NULL DEFAULT now(), livre_le timestamptz
);
CREATE INDEX IF NOT EXISTS crim_vols_differes_attente ON public.crim_vols_differes (destinataire) WHERE livre_le IS NULL;
ALTER TABLE public.crim_vols_differes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_vols_differes FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_vols_differes_id_seq FROM anon, authenticated;

-- ── Formules (§ 7) ──────────────────────────────────────────────────────────────────────────────────────────────
-- Réussite avant dissuasion et bornes : base + 1 par tranche de 3 de DIS au-dessus de 50 (−1 en dessous)
-- − 3 par point de PER (ou PER de groupe) au-dessus de 8 (+3 en dessous) + 15 carrière criminelle / renseignement / escort.
CREATE OR REPLACE FUNCTION public.crim_voler_taux_interne(p_butin text, p_dis numeric, p_per numeric, p_carriere text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(CASE p_butin WHEN 'argent' THEN public.crim_param_interne('vol_base_argent', 55)
                            WHEN 'hasard' THEN public.crim_param_interne('vol_base_hasard', 45)
                            ELSE public.crim_param_interne('vol_base_precis', 25) END
         + trunc((coalesce(p_dis, 50) - public.crim_param_interne('vol_dis_pivot', 50)) / 3.0)
         - 3 * (coalesce(p_per, 8) - public.crim_param_interne('vol_per_pivot', 8))
         + CASE WHEN p_carriere IN ('criminal_c', 'intel', 'escort') THEN public.crim_param_interne('vol_carriere', 15) ELSE 0 END)::integer;
$$;

-- Échec ordinaire remarqué : 50 + 3 par point de PER (ou de groupe) au-dessus de 8 − 1 par tranche de 3 de DIS au-dessus de 50, 10-90.
CREATE OR REPLACE FUNCTION public.crim_voler_remarque_interne(p_per numeric, p_dis numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(public.crim_param_interne('vol_remarque_min', 10), least(public.crim_param_interne('vol_remarque_max', 90), round(
           public.crim_param_interne('vol_remarque_base', 50)
           + 3 * greatest(0, coalesce(p_per, 8) - public.crim_param_interne('vol_per_pivot', 8))
           - greatest(0, trunc((coalesce(p_dis, 50) - public.crim_param_interne('vol_dis_pivot', 50)) / 3.0)))))::integer;
$$;

-- Part du liquide volée (%) : tirage 10-30 + 1 par tranche de 10 de DIS au-dessus de 50 (−1 en dessous)
-- − 1 par point de PER (ou de groupe) au-dessus de 8 (+1 en dessous) + 5 carrière criminelle ; bornée 10-30.
CREATE OR REPLACE FUNCTION public.crim_voler_part_interne(p_tirage numeric, p_dis numeric, p_per numeric, p_criminel boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(public.crim_param_interne('vol_part_min', 10), least(public.crim_param_interne('vol_part_max', 30), round(
           coalesce(p_tirage, 20)
           + trunc((coalesce(p_dis, 50) - public.crim_param_interne('vol_dis_pivot', 50)) / 10.0)
           - (coalesce(p_per, 8) - public.crim_param_interne('vol_per_pivot', 8))
           + CASE WHEN p_criminel THEN public.crim_param_interne('vol_part_carriere', 5) ELSE 0 END)))::integer;
$$;

CREATE OR REPLACE FUNCTION public.crim_voler_montant_interne(p_liquide numeric, p_part numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(public.crim_param_interne('vol_plafond', 2000), floor(greatest(0, coalesce(p_liquide, 0)) * coalesce(p_part, 0) / 100.0))::integer;
$$;

-- PER de groupe (règle existante de détection #135 : moyenne des membres présents + effectif − 1) ; seul : sa PER.
-- Groupe d'un PJ : groupe_participants_interne (PJ du groupe et PNJ qui les suivent) ; d'un PNJ : celui du PJ qu'il suit.
CREATE OR REPLACE FUNCTION public.crim_per_groupe_interne(p_ci jsonb)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_racine text; v_moy numeric; v_n integer; v_seul numeric; v_defaut numeric := public.crim_param_interne('vol_per_defaut', 8);
BEGIN
  IF coalesce((p_ci ->> 'pj')::boolean, false) THEN
    v_racine := p_ci ->> 'nom'; v_seul := public.crim_stat_interne(v_racine, 'PER', v_defaut);
  ELSE
    SELECT leader_pj INTO v_racine FROM public.pnj_membres WHERE id = p_ci ->> 'pnj_id';
    v_seul := coalesce((p_ci ->> 'per')::numeric, v_defaut);
  END IF;
  IF v_racine IS NULL THEN RETURN v_seul; END IF;
  SELECT avg(CASE WHEN g.est_pj THEN public.crim_stat_interne(g.identifiant, 'PER', v_defaut)
                  ELSE coalesce((SELECT m.car_per FROM public.pnj_membres m WHERE m.id = g.identifiant), v_defaut) END), count(*)
    INTO v_moy, v_n
    FROM public.groupe_participants_interne(v_racine) g
   WHERE g.statut = 'actif' AND g.pays IS NOT DISTINCT FROM p_ci ->> 'pays' AND g.ville IS NOT DISTINCT FROM p_ci ->> 'ville'
     AND g.batiment IS NOT DISTINCT FROM p_ci ->> 'batiment' AND g.piece IS NOT DISTINCT FROM p_ci ->> 'piece';
  IF coalesce(v_n, 0) < 2 THEN RETURN v_seul; END IF;
  RETURN round(v_moy + v_n - 1, 2);
END $$;

-- ── Objets volables (§ 7) ───────────────────────────────────────────────────────────────────────────────────────
-- NULL = non volable : revêtu / porté, documents, actes, titres et biens, objets de quête, objets liés au poste (dotation).
-- Sinon le TYPE que le voleur peut nommer : arme, cle, medicament, nourriture, vetement, graisse — ou 'autre'.
CREATE OR REPLACE FUNCTION public.crim_vol_categorie_interne(p_item jsonb)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE
    WHEN p_item IS NULL OR jsonb_typeof(p_item) <> 'object' THEN NULL
    WHEN coalesce(p_item ->> 'porte_par', '') <> '' THEN NULL
    WHEN coalesce(p_item ->> 'type', '') ~ '^(document|acte|titre|extrait|certificat|condamnation|recepisse|permis|passeport|diplome|medaille|bail|contrat|carte_)'
      OR coalesce(p_item ->> 'type', '') IN ('colis_secret_pat', 'tract') THEN NULL
    WHEN p_item ?| ARRAY['calepinEnigme1', 'quete', 'lie_poste', 'liePoste', 'origineMilitaire', 'titre_propriete', 'bien_id'] THEN NULL
    WHEN coalesce(p_item ->> 'type', '') = 'arme' THEN 'arme'
    WHEN coalesce(p_item ->> 'type', '') ~ '^cle' OR coalesce(p_item ->> 'stackKey', '') ~ '^cle' THEN 'cle'
    WHEN coalesce(p_item ->> 'type', '') = 'graisse' OR coalesce(p_item ->> 'stackKey', '') = ANY (public.graisse_cles_interne()) THEN 'graisse'
    WHEN coalesce(p_item ->> 'type', '') ~ '^(soin|medicament|pharmacie)' OR coalesce(p_item ->> 'stackKey', '') ~ '^medicament' THEN 'medicament'
    WHEN public.aliment_objet_comestible_interne(p_item) OR coalesce(p_item ->> 'stackKey', '') IN ('cereales', 'produits_exotiques', 'viande_renne')
      OR coalesce(p_item ->> 'type', '') IN ('nourriture', 'aliment', 'repas') THEN 'nourriture'
    WHEN coalesce(p_item ->> 'type', '') = 'vetement' OR coalesce((p_item ->> 'revetable')::text, '') = 'true'
      OR public.crim_objet_categorie_interne(p_item) IS NOT NULL OR coalesce(p_item ->> 'famille', '') = 'habillement' THEN 'vetement'
    ELSE 'autre' END;
$$;

-- Choix de l'objet : parmi les volables de la victime (inventaire d'un PJ, possessions d'un PNJ), au hasard, filtré par type.
-- Rend {ligne (index PJ) | possession (id PNJ), objet, pile, nom} ou NULL.
CREATE OR REPLACE FUNCTION public.crim_vol_objet_choisir_interne(p_ci jsonb, p_type text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT x FROM (
    SELECT jsonb_build_object('ligne', (o - 1)::integer, 'objet', e) AS x, e
      FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) WITH ORDINALITY t(e, o)
     WHERE coalesce((p_ci ->> 'pj')::boolean, false) AND d.name = p_ci ->> 'nom'
    UNION ALL
    SELECT jsonb_build_object('possession', p.id, 'objet', p.objet), p.objet
      FROM public.pnj_possessions p
     WHERE NOT coalesce((p_ci ->> 'pj')::boolean, false) AND p.pnj_id = p_ci ->> 'pnj_id'
  ) s
  WHERE public.crim_vol_categorie_interne(e) IS NOT NULL AND (p_type IS NULL OR public.crim_vol_categorie_interne(e) = p_type)
  ORDER BY random() LIMIT 1;
$$;

-- Description du butin pour les messages : « 340 FR », « votre Revolver .38 », « 1 × viande ».
CREATE OR REPLACE FUNCTION public.crim_vol_description_interne(p_plan jsonb)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_plan ->> 'genre' = 'argent' THEN (p_plan ->> 'montant') || ' ' || coalesce(p_plan ->> 'devise', 'FR')
              WHEN coalesce((p_plan #>> '{objet,stackable}')::boolean, false) AND coalesce(p_plan #>> '{objet,stackKey}', '') <> ''
                THEN '1 × ' || coalesce(p_plan #>> '{objet,name}', p_plan #>> '{objet,stackKey}')
              ELSE 'votre ' || coalesce(p_plan #>> '{objet,name}', 'objet') END;
$$;

-- Livraison du butin (réussite immédiate ou combat gagné) : la victime perd, le voleur reçoit, dans la même transaction.
-- Revalide sur la fiche réelle (l'objet a pu partir entre-temps). Rend {livre, montant | objet}.
CREATE OR REPLACE FUNCTION public.crim_voler_livrer_interne(p_affaire bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.crim_affaires%ROWTYPE; pl jsonb; v_m numeric; v_dispo numeric; v_pos integer; v_inv jsonb; e jsonb; v_un jsonb;
  v_pile boolean; v_q numeric; v_dep jsonb; v_pos_obj jsonb;
BEGIN
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  IF NOT FOUND OR f.acte <> 'voler' THEN RETURN jsonb_build_object('livre', false); END IF;
  pl := f.details #> '{params,butin_plan}';
  IF pl IS NULL OR coalesce((f.details ->> 'livre')::boolean, false) THEN RETURN jsonb_build_object('livre', false, 'deja', true); END IF;
  IF pl ->> 'genre' = 'argent' THEN
    v_m := (pl ->> 'montant')::numeric;
    IF f.cible_pnj IS NULL THEN
      v_m := public.argent_debiter_interne(f.cible, v_m, 'liquide');
    ELSE
      SELECT greatest(0, coalesce(liquide, 0)) INTO v_dispo FROM public.pnj_membres WHERE id = f.cible_pnj FOR UPDATE;
      v_m := least(v_m, coalesce(v_dispo, 0));
      UPDATE public.pnj_membres SET liquide = liquide - v_m, maj_le = now() WHERE id = f.cible_pnj;
    END IF;
    IF v_m > 0 THEN PERFORM public.argent_crediter_interne(f.auteur, v_m, 'liquide'); END IF;
    UPDATE public.crim_affaires SET details = details || jsonb_build_object('livre', v_m > 0, 'montant_livre', v_m), maj_le = now() WHERE id = f.id;
    RETURN jsonb_build_object('livre', v_m > 0, 'montant', v_m);
  END IF;
  -- Objet : une unité d'une pile, ou l'objet entier.
  e := pl -> 'objet';
  v_pile := coalesce((e ->> 'stackable')::boolean, false) AND coalesce(e ->> 'stackKey', '') <> '';
  IF f.cible_pnj IS NULL THEN
    SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = f.cible FOR UPDATE;
    SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_inv) = 'array' THEN v_inv ELSE '[]'::jsonb END) WITH ORDINALITY t(x, o)
     WHERE public.crim_vol_categorie_interne(x) IS NOT NULL
       AND CASE WHEN v_pile THEN coalesce((x ->> 'stackable')::boolean, false) AND x ->> 'stackKey' = e ->> 'stackKey'
                WHEN coalesce(e ->> 'id', '') <> '' THEN x ->> 'id' = e ->> 'id' ELSE x = e END
     ORDER BY (o - 1 = coalesce((pl ->> 'ligne')::integer, -1)) DESC, o LIMIT 1;
    IF v_pos IS NULL THEN RETURN jsonb_build_object('livre', false); END IF;
    e := v_inv -> v_pos; v_q := coalesce((e ->> 'qty')::numeric, 1);
    IF v_pile AND v_q > 1 THEN
      UPDATE public.personnages_donnees SET inventory = jsonb_set(inventory, ARRAY[v_pos::text, 'qty'], to_jsonb(v_q - 1)) WHERE name = f.cible;
    ELSE
      UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = f.cible;
    END IF;
  ELSE
    SELECT to_jsonb(p) INTO v_pos_obj FROM public.pnj_possessions p WHERE p.id = (pl ->> 'possession')::bigint AND p.pnj_id = f.cible_pnj FOR UPDATE;
    IF v_pos_obj IS NULL THEN RETURN jsonb_build_object('livre', false); END IF;
    e := v_pos_obj -> 'objet'; v_q := coalesce((e ->> 'qty')::numeric, 1);
    IF v_pile AND v_q > 1 THEN
      UPDATE public.pnj_possessions SET objet = jsonb_set(objet, '{qty}', to_jsonb(v_q - 1)) WHERE id = (pl ->> 'possession')::bigint;
    ELSE
      DELETE FROM public.pnj_possessions WHERE id = (pl ->> 'possession')::bigint;
    END IF;
  END IF;
  v_un := (e - 'porte_par') || CASE WHEN v_pile THEN jsonb_build_object('qty', 1) ELSE '{}'::jsonb END;
  v_dep := public.inventaire_deposer_interne(f.auteur, v_un, true);
  IF (v_dep ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'crim_voler_livrer_interne : dépôt refusé %', v_dep; END IF;
  UPDATE public.crim_affaires SET details = details || jsonb_build_object('livre', true, 'objet_livre', v_un ->> 'name'), maj_le = now() WHERE id = f.id;
  RETURN jsonb_build_object('livre', true, 'objet', v_un ->> 'name');
END $$;

-- Découverte au prochain réveil (réussite critique) : branchée sur pa_repos_nocturne (ordre « Dormir »).
CREATE OR REPLACE FUNCTION public.crim_vols_reveil_interne(p_nom text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; n integer := 0; v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
BEGIN
  FOR r IN SELECT * FROM public.crim_vols_differes WHERE destinataire = p_nom AND livre_le IS NULL ORDER BY id FOR UPDATE LOOP
    PERFORM public.mail_systeme_poser_interne('Événement', r.destinataire, r.titre, r.corps, v_date);
    UPDATE public.crim_vols_differes SET livre_le = now() WHERE id = r.id;
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

-- ── Ouverture du combat commune (moteur inchangé) : Neutraliser et Voler ──────────────────────────────────────────
-- L'auteur s'est montré : il perd sa cachette, garde son masque. Combat impossible = échec ordinaire (suite 'sans_combat').
CREATE OR REPLACE FUNCTION public.crim_combat_ouvrir_interne(p_auteur text, p_r jsonb, p_ci jsonb, p_mode text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r jsonb := p_r; v_comb jsonb; v_suite jsonb;
  v_cible text := CASE WHEN coalesce((p_ci ->> 'pj')::boolean, false) THEN p_ci ->> 'nom' ELSE p_ci ->> 'pnj_id' END;
BEGIN
  PERFORM public.crim_debusquer_interne(p_auteur, 'combat');
  IF NOT coalesce((p_ci ->> 'pj')::boolean, false) AND NOT coalesce((p_ci ->> 'profil_combat')::boolean, false) THEN
    v_comb := jsonb_build_object('ok', false, 'raison', 'profil_combattant_incomplet');
  ELSE
    PERFORM set_config('rp.crim_neutraliser', 'on', true);
    v_comb := public.combat_ouvrir_interne(v_cible, p_mode, p_requete);
    PERFORM set_config('rp.crim_neutraliser', '', true);
  END IF;
  IF coalesce((v_comb ->> 'ok')::boolean, false) THEN
    UPDATE public.batailles SET contexte = contexte || jsonb_build_object('crim_affaire', (r ->> 'affaire')::bigint, 'crim_mode', r ->> 'mode')
     WHERE id = (v_comb ->> 'bataille')::bigint;
    UPDATE public.crim_affaires SET bataille = (v_comb ->> 'bataille')::bigint, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
    r := r || jsonb_build_object('bataille', (v_comb ->> 'bataille')::bigint, 'phase', v_comb ->> 'phase');
  ELSE
    v_suite := public.crim_resoudre_suite_interne((r ->> 'affaire')::bigint, 'sans_combat');
    r := r || jsonb_build_object('issue', 'echec', 'combat_refuse', v_comb ->> 'raison');
  END IF;
  RETURN r;
END $$;

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

-- Neutraliser ouvre désormais son combat par la brique commune (même code que Voler).
SELECT pg_temp.rp_raccorder('public.crime_neutraliser(text,text,uuid)'::regprocedure,
  $a$    PERFORM public.crim_debusquer_interne(a, 'combat');
    IF NOT (ci ->> 'pj')::boolean AND NOT coalesce((ci ->> 'profil_combat')::boolean, false) THEN
      v_comb := jsonb_build_object('ok', false, 'raison', 'profil_combattant_incomplet');
    ELSE
      PERFORM set_config('rp.crim_neutraliser', 'on', true);
      v_comb := public.combat_ouvrir_interne(v_cible_id, p_mode, p_requete);
      PERFORM set_config('rp.crim_neutraliser', '', true);
    END IF;
    IF coalesce((v_comb ->> 'ok')::boolean, false) THEN
      UPDATE public.batailles SET contexte = contexte || jsonb_build_object('crim_affaire', (r ->> 'affaire')::bigint, 'crim_mode', r ->> 'mode')
       WHERE id = (v_comb ->> 'bataille')::bigint;
      UPDATE public.crim_affaires SET bataille = (v_comb ->> 'bataille')::bigint, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
      r := r || jsonb_build_object('bataille', (v_comb ->> 'bataille')::bigint, 'phase', v_comb ->> 'phase');
    ELSE
      v_suite := public.crim_resoudre_suite_interne((r ->> 'affaire')::bigint, 'sans_combat');
      r := r || jsonb_build_object('issue', 'echec', 'combat_refuse', v_comb ->> 'raison');
    END IF;
$a$,
  $b$    r := public.crim_combat_ouvrir_interne(a, r, ci, p_mode, p_requete); /* crim_combat_commun_v1 */
$b$,
  'crim_combat_commun_v1');

-- Combat gagné par un voleur = réussite (§ 2 appliqué au § 7) : le butin est livré avant les messages.
SELECT pg_temp.rp_raccorder('public.crim_resoudre_suite_interne(bigint,text)'::regprocedure,
  $a$    v_det := public.crim_detection_interne(f.id, NULL);$a$,
  $b$    IF f.acte = 'voler' THEN PERFORM public.crim_voler_livrer_interne(f.id); END IF; /* crim_vol_combat_v1 */
    v_det := public.crim_detection_interne(f.id, NULL);$b$,
  'crim_vol_combat_v1');

-- Réussite critique : la victime découvre le vol au réveil (ordre « Dormir »).
SELECT pg_temp.rp_raccorder('public.pa_repos_nocturne(text)'::regprocedure,
  $a$  PERFORM public.maladies_nuit_interne(p_acteur);$a$,
  $b$  PERFORM public.maladies_nuit_interne(p_acteur);
  PERFORM public.crim_vols_reveil_interne(p_acteur); /* crim_vol_reveil_v1 */$b$,
  'crim_vol_reveil_v1');

-- ── Voler (§ 7) ─────────────────────────────────────────────────────────────────────────────────────────────────
-- p_butin : 'argent' | 'hasard' | 'precis' ; p_type (précis) : arme | cle | medicament | nourriture | vetement | graisse.
CREATE OR REPLACE FUNCTION public.crime_voler(p_cible text, p_butin text, p_type text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cible', p_cible, 'butin', p_butin, 'type', p_type);
  v jsonb; m record; ci jsonb; v_cible_id text; v_pa integer; v_paie jsonb; v_dis numeric; v_per numeric; v_taux integer;
  v_plan jsonb; v_choix jsonb; v_liquide numeric; v_part integer; v_montant integer; v_desc text; r jsonb; v_liv jsonb := '{}'::jsonb;
  v_devise text; v_out jsonb; v_sans jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_butin NOT IN ('argent', 'hasard', 'precis') THEN RETURN jsonb_build_object('ok', false, 'raison', 'butin_invalide'); END IF;
  IF p_butin = 'precis' AND coalesce(p_type, '') NOT IN ('arme', 'cle', 'medicament', 'nourriture', 'vetement', 'graisse') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  v_pa := CASE WHEN p_butin = 'precis' THEN 3 ELSE 2 END;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_voler', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, career, country, est_emprisonne INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  ci := public.crim_cible_resoudre_interne(a, p_cible);
  IF coalesce((ci ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN ci; END IF;
  v_cible_id := CASE WHEN (ci ->> 'pj')::boolean THEN ci ->> 'nom' ELSE ci ->> 'pnj_id' END;
  IF NOT (ci ->> 'pj')::boolean AND coalesce((ci ->> 'pa')::integer, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_indisponible'); END IF;
  IF EXISTS (SELECT 1 FROM public.groupe_participants_interne(a) g WHERE g.identifiant = v_cible_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'meme_groupe'); END IF;

  v_paie := public.payer_ordre(a, 'voler', v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_dis := public.crim_stat_interne(a, 'dis', 50);
  v_per := public.crim_per_groupe_interne(ci);
  v_devise := CASE WHEN m.country = 'soviet' THEN 'PSK' ELSE 'FR' END;

  -- Butin visé, décidé avant le jet (sans rien montrer au voleur). Rien à prendre : échec sans autre risque, PA perdus.
  IF p_butin = 'argent' THEN
    v_liquide := CASE WHEN (ci ->> 'pj')::boolean THEN (SELECT coalesce(liquide, 0) FROM public.personnages_donnees WHERE name = v_cible_id)
                      ELSE (SELECT coalesce(liquide, 0) FROM public.pnj_membres WHERE id = v_cible_id) END;
    v_part := public.crim_voler_part_interne((10 + floor(random() * 21))::numeric, v_dis, v_per, m.career = 'criminal_c');
    v_montant := public.crim_voler_montant_interne(v_liquide, v_part);
    IF v_montant > 0 THEN v_plan := jsonb_build_object('genre', 'argent', 'montant', v_montant, 'part', v_part, 'devise', v_devise); END IF;
  ELSE
    v_choix := public.crim_vol_objet_choisir_interne(ci, CASE WHEN p_butin = 'precis' THEN p_type END);
    IF v_choix IS NOT NULL THEN v_plan := v_choix || jsonb_build_object('genre', 'objet'); END IF;
  END IF;
  IF v_plan IS NULL THEN
    v_sans := jsonb_build_object('ok', true, 'issue', 'echec', 'sans_risque', true, 'butin', p_butin,
      'raison_echec', CASE WHEN p_butin = 'precis' THEN 'type_absent' ELSE 'rien_a_voler' END, 'paie', v_paie);
    RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_voler', prm, v_sans);
  END IF;
  v_desc := public.crim_vol_description_interne(v_plan);

  v_taux := public.crim_voler_taux_interne(p_butin, v_dis, v_per, m.career);
  r := public.crim_resoudre_interne('voler', a, v_cible_id, jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('vol_min', 5), 'max', public.crim_param_interne('vol_max', 85),
    'critique_reussite_part', public.crim_param_interne('vol_critique_reussite_part', 5), 'critique_sans_detection', true,
    'combat', true, 'per_victime', (ci ->> 'per')::numeric,
    'remarque_echec', public.crim_voler_remarque_interne(v_per, v_dis),
    'detection_base', public.crim_param_interne('vol_detection', 30), 'detection_min', public.crim_param_interne('detection_min', 5),
    'acte_peine_reussite', 'vol', 'acte_peine_echec', 'vol', 'type_recherche', 'delit_mineur', 'cible_info', ci,
    'titre_reussite', 'Vol', 'titre_echec', 'Tentative de vol',
    'msg_reussite', '{Auteur} vous a dérobé ' || replace(replace(v_desc, '{', '('), '}', ')') || '.',
    'msg_echec', '{Auteur} a tenté de vous voler.',
    'msg_employeur_reussite', 'Votre employé(e) {cible} s''est fait dérober ' || replace(replace(v_desc, '{', '('), '}', ')') || ' par {auteur}. Une plainte a été déposée.',
    'msg_employeur_echec', '{Auteur} a tenté de voler votre employé(e) {cible}. Une plainte a été déposée.',
    'motif_plainte', 'Vol sur votre employé(e)',
    'indices', jsonb_build_object('butin', p_butin),
    'butin', p_butin, 'type_vise', p_type, 'per_groupe', v_per, 'butin_plan', v_plan,
    -- Essais annulés seulement (console d'administration, jamais un joueur : session « postgres ») : jets imposés.
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));

  IF r ->> 'issue' = 'reussite' THEN
    v_liv := public.crim_voler_livrer_interne((r ->> 'affaire')::bigint);
    IF coalesce((r ->> 'reussite_critique')::boolean, false) THEN
      -- La victime (ou l'employeur d'un PNJ) ne s'en aperçoit qu'au réveil, sans pouvoir le relier à une rencontre.
      INSERT INTO public.crim_vols_differes (destinataire, titre, corps, affaire)
      SELECT dest, 'Vol', corps, (r ->> 'affaire')::bigint FROM (
        SELECT CASE WHEN (ci ->> 'pj')::boolean THEN v_cible_id ELSE ci ->> 'employeur' END AS dest,
               CASE WHEN (ci ->> 'pj')::boolean THEN 'En vous réveillant, vous constatez qu''on vous a dérobé ' || v_desc || '. Impossible de dire quand, ni qui.'
                    ELSE 'Votre employé(e) ' || (ci ->> 'nom') || ' constate qu''on lui a dérobé ' || v_desc || ', sans savoir quand ni qui.' END AS corps) s
      WHERE dest IS NOT NULL AND coalesce((v_liv ->> 'livre')::boolean, false);
    END IF;
  ELSIF r ->> 'issue' = 'combat' THEN
    r := public.crim_combat_ouvrir_interne(a, r, ci, 'mains', p_requete);
  END IF;

  -- Rumeurs vraies (règle existante) : un vol réussi laisse une trace de rumeur visant le coupable.
  IF r ->> 'issue' = 'reussite' AND coalesce((v_liv ->> 'livre')::boolean, false) THEN
    PERFORM public.crime_trace_rumeur_interne(a, 'vol', ci ->> 'nom');
  END IF;

  -- Réponse à l'écran : jamais le nom d'une cible désignée par jeton.
  v_out := jsonb_build_object('ok', true, 'butin', p_butin, 'cible_pj', (ci ->> 'pj')::boolean, 'paie', v_paie,
             'description', CASE WHEN coalesce((v_liv ->> 'livre')::boolean, false) THEN
                              CASE WHEN v_plan ->> 'genre' = 'argent' THEN (v_liv ->> 'montant') || ' ' || v_devise ELSE v_liv ->> 'objet' END END,
             'livre', coalesce((v_liv ->> 'livre')::boolean, false))
    || (r - 'notifie' - 'affaire' - 'garde')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche, 'liquide', liquide, 'arg', arg,
                                  'inventory', inventory, 'revision', inventory_revision)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_voler', prm, v_out);
END $$;

-- Ancienne route (jet à paliers, butin 50-199 FR, amende d'empire) : remplacée.
CREATE OR REPLACE FUNCTION public.crime_voler(p_cible text, p_genre text, p_benediction boolean DEFAULT false,
                                              p_per_pnj integer DEFAULT 9, p_int_pnj integer DEFAULT 9)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'ordre_remplace', 'remplacant', 'crime_voler(p_cible, p_butin, p_type, p_requete)');
$$;

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_voler_taux_interne(text,numeric,numeric,text)', 'crim_voler_remarque_interne(numeric,numeric)',
    'crim_voler_part_interne(numeric,numeric,numeric,boolean)', 'crim_voler_montant_interne(numeric,numeric)',
    'crim_per_groupe_interne(jsonb)', 'crim_vol_categorie_interne(jsonb)', 'crim_vol_objet_choisir_interne(jsonb,text)',
    'crim_vol_description_interne(jsonb)', 'crim_voler_livrer_interne(bigint)', 'crim_vols_reveil_interne(text)',
    'crim_combat_ouvrir_interne(text,jsonb,jsonb,text,uuid)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crime_voler(text,text,text,uuid)', 'crime_voler(text,text,boolean,integer,integer)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
