-- A APPLIQUER par Claude via MCP apply_migration, APRES 20261027110100.
-- ============================================================================
-- VOLER ET EMPOISONNER : PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », famille « Crime », second lot.
--   1. Voler : jet, butin, sanctions d'echec par empire et courrier a la victime etaient decides par
--      l'ecran du voleur, et vols_en_attente acceptait n'importe quelle ligne signee du voleur :
--      un montant quelconque (vider une victime) ou negatif (s'offrir de l'argent par la victime).
--      crime_voler fait tout : 2 PA (le cout affiche, jamais preleve jusqu'ici), jet
--      50 + PER + CHA - (PER + INT de la cible) + carriere - securite / 3 + benediction (+5)
--      +/- 25 ; < 25 echec et sanction de l'empire ; 25-49 reussite, voleur reconnu ; 50-74
--      reussite, auteur inconnu ; >= 75 reussite discrete. Le butin est lu sur la fiche reelle de
--      la victime ; l'argent est credite au voleur par le serveur, le retrait chez la victime reste
--      differe (vols_en_attente, applique par son ecran). Sur un PNJ : rien a voler.
--   2. Empoisonner : jet, poison consomme, effet, courrier, annonce, trace et detection etaient
--      decides par l'ecran -- et l'effet n'atteignait JAMAIS la victime (impact refuse, colonnes
--      absentes). crime_empoisonner : taux = 40 - 5 (PER de reference de la cible) + empire
--      (narco +20, soviet -10) + 15 (carriere criminelle) - malus de securite, 4 paliers comme
--      Neutraliser. L'effet est depose (poison_start, avec le type de poison et deux statistiques
--      touchees, colonne details ajoutee).
--   3. Neutraliser et explosifs posaient les PV sur le serveur mais ne prevenaient plus l'ecran de
--      la victime (hospitalisation, statistiques affaiblies). Ils deposent desormais aussi
--      l'impact hp_set, comme avant le 27/10.
-- Restent a l'ecran : le prealable « Se cacher » de l'empoisonnement et la benediction (etats non
-- tenus par le serveur), et les suites chez la victime (sommeil, centre anti-poison).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

ALTER TABLE public.impacts_indices_attente ADD COLUMN IF NOT EXISTS details jsonb;
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('voler', 2, 0) ON CONFLICT DO NOTHING;

-- 3. L'impact hp_set revient chez la victime.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.crime_neutraliser(text,text,integer)'::regprocedure);
  IF position('agression-' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'    UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), v_pv) WHERE name = p_cible;\n',
      E'    UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), v_pv) WHERE name = p_cible;\n'
      || E'    INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite)\n'
      || E'    VALUES (''agression-'' || gen_random_uuid(), p_cible, ''hp_set'', least(coalesce(c.hp, 100), v_pv), v_palier, false);\n');
    IF position('agression-' IN v_def) = 0 THEN RAISE EXCEPTION 'crime_neutraliser : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
  v_def := pg_get_functiondef('public.crime_explosifs(text)'::regprocedure);
  IF position('explosion-' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'      UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), 15) WHERE name = v_v.name;\n',
      E'      UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), 15) WHERE name = v_v.name;\n'
      || E'      INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, traite)\n'
      || E'      SELECT ''explosion-'' || gen_random_uuid(), v_v.name, ''hp_set'', hp, false FROM public.personnages_donnees WHERE name = v_v.name;\n');
    IF position('explosion-' IN v_def) = 0 THEN RAISE EXCEPTION 'crime_explosifs : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;

CREATE OR REPLACE FUNCTION public.crime_trace_rumeur_interne(p_auteur text, p_type text, p_cible text)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
      SELECT 'action-' || replace(gen_random_uuid()::text, '-', ''), name, p_cible, p_type, country, current_city,
             coalesce(day, 1), coalesce(day, 1) + 7
        FROM public.personnages_donnees WHERE name = p_auteur $$;

-- 1. Voler.
CREATE OR REPLACE FUNCTION public.crime_voler(p_cible text, p_genre text, p_benediction boolean DEFAULT false,
                                              p_per_pnj integer DEFAULT 9, p_int_pnj integer DEFAULT 9)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; c record; v_pj boolean; v_paie jsonb; v_isn numeric; v_jet integer; v_per integer; v_int integer;
  v_genre text; v_butin text := 'rien'; v_montant integer := 0; v_objet jsonb; v_vol_type text; v_vol_obj text;
  v_desc text; v_msg text := NULL; v_perte integer; v_jour integer; v_quand text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_genre := CASE WHEN p_genre = 'objet' THEN 'objet' ELSE 'argent' END;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT name, country, current_city, current_building, current_room, arg, inventory, stats INTO c
    FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  v_pj := FOUND;
  IF v_pj THEN
    IF c.country IS DISTINCT FROM m.country OR c.current_city IS DISTINCT FROM m.current_city
       OR c.current_building IS DISTINCT FROM m.current_building OR c.current_room IS DISTINCT FROM m.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
    v_per := coalesce((c.stats ->> 'PER')::numeric, 9)::integer; v_int := coalesce((c.stats ->> 'INT')::numeric, 9)::integer;
  ELSE
    v_per := greatest(0, least(20, coalesce(p_per_pnj, 9))); v_int := greatest(0, least(20, coalesce(p_int_pnj, 9)));
  END IF;
  v_paie := public.payer_ordre(v_moi, 'voler', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT arg, resources INTO m.arg, m.resources FROM public.personnages_donnees WHERE name = v_moi;
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                      WHERE id = m.country || '_' || coalesce(m.current_city, 'capitale')), 30);
  v_jet := greatest(0, least(100, round(50 + coalesce((m.stats ->> 'PER')::numeric, 8) + coalesce((m.stats ->> 'CHA')::numeric, 8)
             - (v_per + v_int)
             + CASE m.career WHEN 'criminal_c' THEN 15 WHEN 'intel' THEN 15 WHEN 'escort' THEN 15
                             WHEN 'magistrat' THEN -10 WHEN 'officer' THEN -10 WHEN 'clergy' THEN -10 WHEN 'doctor' THEN -10 ELSE 0 END
             - v_isn / 3 + CASE WHEN p_benediction THEN 5 ELSE 0 END + (random() * 50 - 25))::integer));
  v_jour := coalesce(m.day, 1);
  v_quand := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');

  IF v_jet < 25 THEN
    -- Sanction de l'empire (CONSEQUENCES_VOL_ECHEC).
    IF m.country = 'narco' THEN
      v_perte := floor(coalesce(m.arg, 0) * 0.5)::integer;
      UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_perte) WHERE name = v_moi;
      v_msg := 'Deux messieurs interviennent sans discussion. Vous perdez ' || v_perte || ' liquide. "La prochaine fois, on sera moins gentils."';
    ELSIF m.country = 'soviet' THEN
      UPDATE public.personnages_donnees
         SET arg = greatest(0, coalesce(arg, 0) - 100),
             resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
                           to_jsonb(greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 0) - 10)))
       WHERE name = v_moi;
      v_msg := 'Le collectif vous denonce publiquement. -10 POP, -100 FR (amende symbolique).';
    ELSIF m.country = 'khalija' THEN
      PERFORM public.crime_tracer_interne(v_moi, 'vol', p_cible);
      UPDATE public.personnages_donnees
         SET historique_crimes = jsonb_set(historique_crimes, ARRAY[(jsonb_array_length(historique_crimes) - 1)::text],
               (historique_crimes -> (jsonb_array_length(historique_crimes) - 1))
               || jsonb_build_object('expireJour', v_jour + 15,
                    'expireTs', to_char((now() + interval '15 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
       WHERE name = v_moi;
      v_msg := 'Sanction par decret. Affaire consignee pour 15 jours — la memoire du Sheikh est longue.';
    ELSE
      UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - 300) WHERE name = v_moi;
      PERFORM public.crime_tracer_interne(v_moi, 'vol', p_cible);
      v_msg := 'Un agent vous verbalise sur-le-champ. -300 FR. Inscrit au registre administratif.';
    END IF;
    RETURN jsonb_build_object('ok', true, 'issue', 'echec', 'jet', v_jet, 'message', v_msg)
      || (SELECT jsonb_build_object('arg', arg, 'pop', (resources ->> 'pop')::numeric) FROM public.personnages_donnees WHERE name = v_moi)
      || jsonb_build_object('paie', v_paie);
  END IF;

  IF v_pj THEN
    -- L'argent deja vole mais pas encore retire chez la victime ne se vole pas deux fois.
    c.arg := coalesce(c.arg, 0) - coalesce((SELECT sum(montant) FROM public.vols_en_attente
                                             WHERE victime = p_cible AND type_butin = 'argent' AND traite IS NOT TRUE AND montant > 0), 0);
    IF v_genre = 'argent' AND c.arg > 0 THEN
      v_butin := 'argent';
      v_montant := least(floor(random() * 150)::integer + 50, c.arg);
      v_vol_type := 'argent'; v_vol_obj := NULL; v_desc := v_montant || ' FR';
    ELSIF v_genre = 'objet' THEN
      SELECT i INTO v_objet
        FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.inventory) = 'array' THEN c.inventory ELSE '[]'::jsonb END) i
       WHERE coalesce(i ->> 'type', '') NOT IN ('acte_officiel', 'colis_secret_pat')
         AND ((coalesce((i ->> 'stackable')::boolean, false) AND coalesce(i ->> 'stackKey', '') <> '')
              OR ((i ->> 'origine' = 'objets_trouves' OR i ->> 'type' = 'arme') AND coalesce(i ->> 'id', '') <> ''))
       ORDER BY random() LIMIT 1;
      IF v_objet IS NOT NULL THEN
        v_butin := 'objet';
        IF coalesce((v_objet ->> 'stackable')::boolean, false) AND coalesce(v_objet ->> 'stackKey', '') <> '' THEN
          v_montant := least(floor(random() * 5)::integer + 1, greatest(1, coalesce((v_objet ->> 'qty')::numeric, 1)::integer));
          v_vol_type := 'matiere'; v_vol_obj := v_objet ->> 'stackKey';
          v_desc := v_montant || 'x ' || coalesce(v_objet ->> 'name', v_objet ->> 'stackKey');
        ELSE
          v_montant := 0; v_vol_type := 'objet'; v_vol_obj := v_objet ->> 'id';
          v_desc := '"' || coalesce(v_objet ->> 'name', 'un objet') || '"';
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_butin = 'rien' THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'rien', 'jet', v_jet, 'arg', m.arg) || jsonb_build_object('paie', v_paie);
  END IF;

  INSERT INTO public.vols_en_attente (id, victime, voleur, type_butin, montant, objet_id, traite)
  VALUES ('vol-' || replace(gen_random_uuid()::text, '-', ''), p_cible, v_moi, v_vol_type, v_montant, v_vol_obj, false);
  IF v_butin = 'argent' THEN
    UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = v_moi;
  END IF;
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'vol', p_cible);
  IF v_jet < 50 THEN
    PERFORM public.mail_systeme_poser_interne('Système', p_cible, 'Vous avez été volé(e)',
      v_moi || ' vous a dérobé ' || v_desc || '. Vous l''avez reconnu(e) sur le fait.', v_quand);
  ELSIF v_jet < 75 THEN
    PERFORM public.mail_systeme_poser_interne('Système', p_cible, 'Vous avez été volé(e)',
      'Quelqu''un vous a discrètement dérobé ' || v_desc || '. Vous n''avez pas pu identifier l''auteur.', v_quand);
  END IF;
  RETURN jsonb_build_object('ok', true, 'issue', 'reussite', 'butin', v_butin, 'description', v_desc, 'montant', v_montant,
    'jet', v_jet, 'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi)) || jsonb_build_object('paie', v_paie);
END; $function$;

REVOKE ALL ON FUNCTION public.crime_trace_rumeur_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.crime_voler(text, text, boolean, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_voler(text, text, boolean, integer, integer) TO authenticated;

-- Le depot de vol n'est plus ecrit par le voleur ; la victime ne peut plus que marquer « traite ».
DROP POLICY IF EXISTS "vols depot par le voleur" ON public.vols_en_attente;
REVOKE INSERT, UPDATE, DELETE ON public.vols_en_attente FROM anon, authenticated;
GRANT UPDATE (traite) ON public.vols_en_attente TO authenticated;
