-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027190040.
-- Eprouvee au role authenticated : marche noir direct refuse, achats d'arme (reussite, denonciation et convocation, rupture), explosifs en inventaire avec revision.
-- ============================================================================
-- MARCHE NOIR : ARMES ET EXPLOSIFS PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », famille « Crime ». Le jet d'achat au marche noir (le vendeur accepte,
-- ou denonce) etait tire par l'ecran, ainsi que la trace decouvrable et la denonciation : un
-- tricheur achetait sans risque, et l'achat d'arme pouvait meme etre demande directement au serveur
-- (commerce_vendre_produit, mode marche_noir) sans aucun jet.
--   * crime_acheter_arme_noire : jet 50 + carriere (BONUS_CARRIERE_VOL) - securite / 3 +
--     benediction, borne 5-95 ; echec : avis de recherche, convocation sous 24 h et courrier du
--     commissaire ; reussite : vente au triple du prix (commerce_vendre_produit_interne), trace
--     « achat_arme_illegal » decouvrable. Le mode marche_noir n'est plus accessible directement.
--   * crime_acheter_explosifs : 2 PA a la tentative ; jet 35 + empire (narco +20, soviet -10) +
--     15 (carriere criminelle) - malus de securite, borne 5-95 ; echec : avis de recherche ;
--     reussite : 1 200 preleves, explosif depose en inventaire, trace « acheter_bombe_illegale ».
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('acheter_bombe_illegale#reussite', 0, 1200)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 27/10/2026 : le marche noir passe par crime_acheter_arme_noire (jet, denonciation, trace).
  IF p_mode = 'marche_noir' THEN RETURN jsonb_build_object('ok', false, 'raison', 'marche_noir_par_le_serveur'); END IF;
  RETURN public.commerce_vendre_produit_interne(p_acteur, p_entreprise, p_produits, p_mode, p_ordre, p_pa, p_cost, p_regle_pa, NULL);
END; $function$;

CREATE OR REPLACE FUNCTION public.crime_acheter_arme_noire(p_entreprise text, p_arme text, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_isn numeric; v_taux integer; v_roll numeric; v_r jsonb; v_commissaire text; v_conv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, career, day, convocations INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes
                      WHERE id = m.country || '_' || coalesce(m.current_city, 'capitale')), 30);
  v_taux := greatest(5, least(95, round(50 + CASE m.career WHEN 'criminal_c' THEN 15 WHEN 'intel' THEN 15 WHEN 'escort' THEN 15
              WHEN 'magistrat' THEN -10 WHEN 'officer' THEN -10 WHEN 'clergy' THEN -10 WHEN 'doctor' THEN -10 ELSE 0 END
              - v_isn / 3 + CASE WHEN p_benediction THEN 5 ELSE 0 END)::integer));
  v_roll := random() * 100;
  IF v_roll > v_taux THEN
    PERFORM public.crime_rechercher_interne(v_moi, 'achat_arme_illegal', 'delit_mineur');
    v_conv := jsonb_build_object('id', 'conv-' || replace(gen_random_uuid()::text, '-', ''), 'motif', 'achat_arme_illegal',
      'jourEmission', coalesce(m.day, 1), 'heureEmission', extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,
      'jourLimite', coalesce(m.day, 1) + 1, 'heureLimite', extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,
      'traitee', false, 'limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    UPDATE public.personnages_donnees
       SET convocations = (CASE WHEN jsonb_typeof(convocations) = 'array' THEN convocations ELSE '[]'::jsonb END) || jsonb_build_array(v_conv)
     WHERE name = v_moi;
    v_commissaire := CASE m.country WHEN 'narco' THEN 'El Capitan Gordo' WHEN 'soviet' THEN 'Camarade Borodine'
                       WHEN 'khalija' THEN 'Chambellan Ibn Protocole' ELSE 'Raoul Toufaud' END;
    PERFORM public.mail_systeme_poser_interne(v_commissaire, v_moi, 'Convocation officielle',
      'L''armurier a refusé la vente et vous a dénoncé. Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux)
      || (SELECT jsonb_build_object('recherche', recherche, 'convocations', convocations) FROM public.personnages_donnees WHERE name = v_moi);
  END IF;
  v_r := public.commerce_vendre_produit_interne(v_moi, p_entreprise, jsonb_build_array(jsonb_build_object('produit', p_arme, 'qte', 1)),
           'marche_noir', 'choisir_arme', 1, 0, NULL, NULL);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  PERFORM public.crime_tracer_interne(v_moi, 'achat_arme_illegal', NULL);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'achat_arme_illegal', NULL);
  RETURN v_r || jsonb_build_object('reussi', true, 'taux', v_taux);
END; $function$;

CREATE OR REPLACE FUNCTION public.crime_acheter_explosifs(p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_fonds numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT d.country, d.current_city, d.career, coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale'), 0) AS fonds
    INTO m FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF m.fonds < 1200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  v_paie := public.payer_ordre(v_moi, 'acheter_bombe_illegale', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, least(95, 35 + CASE m.country WHEN 'narco' THEN 20 WHEN 'soviet' THEN -10 ELSE 0 END
              + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city)));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    PERFORM public.crime_rechercher_interne(v_moi, 'acheter_bombe_illegale', 'crime');
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
  END IF;
  v_paie := public.payer_ordre(v_moi, 'acheter_bombe_illegale#reussite', 0, 1200);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'raison', 'fonds_insuffisants') || public.crime_etat_acteur_interne(v_moi);
  END IF;
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
       || jsonb_build_array(jsonb_build_object('id', 'explosif-' || replace(gen_random_uuid()::text, '-', ''),
            'type', 'explosif', 'name', 'Explosifs de chantier', 'icon', 'ti-bomb', 'legal', false,
            'desc', 'Non enregistré. Usage unique.', 'imageUrl', 'images/explosifs-marche-noir.webp'))
   WHERE name = v_moi;
  PERFORM public.crime_tracer_interne(v_moi, 'acheter_bombe_illegale', NULL);
  PERFORM public.crime_trace_rumeur_interne(v_moi, 'acheter_bombe_illegale', NULL);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_roll) || public.crime_etat_acteur_interne(v_moi);
END; $function$;

REVOKE ALL ON FUNCTION public.crime_acheter_arme_noire(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_acheter_arme_noire(text, text, boolean) TO authenticated;
REVOKE ALL ON FUNCTION public.crime_acheter_explosifs(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_acheter_explosifs(integer, integer) TO authenticated;
