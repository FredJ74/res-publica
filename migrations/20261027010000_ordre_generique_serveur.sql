-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261026230447.
-- Eprouvee apres application en transaction annulee (soins, lieu refuse, rachat refuse, 12 fuites tirees par le serveur). Baseline NON reextrait.
-- ============================================================================
-- L'ORDRE GENERIQUE PAR LE SERVEUR (27 octobre 2026, audit « une seule verite » §3.1)
-- ============================================================================
-- Les ordres sans traitement dedie passaient par executerOrdreGenerique (plateau-router.js) :
-- le serveur prelevait le cout, mais le jet de reussite et ses effets (sante, moral, influence,
-- popularite, discretion) etaient tires et appliques par le navigateur.
-- Mesure du 27/10 : seuls CINQ ordres reels y arrivent encore (les autres ont leur traitement) :
--   soins_urgence et soins_discrets (chambres de la clinique privee), fuite_info (archives du
--   gouvernement, tout titulaire d'un poste), deliberer_loge (loge maconnique), interroger (salle
--   d'interrogatoire du QHS, commissaire).
-- Desormais ordre_generique_executer fait tout : lieu, poste, paiement, jet, effets, et le
-- remboursement de 30 % du cout en cas d'echec simple, dans une seule transaction. Les regles
-- sont celles d'avant, recopiees de data.js (taux du bouton, ORDER_EFFECTS, liste des ordres a
-- reussite garantie) dans la table ordres_generiques. Un ordre absent de la table est refuse.
-- Le malus de securite militaire que le navigateur ajoutait (state.malusSecuriteMilitaire) n'a
-- aucune source serveur : il n'est pas repris.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ordres_generiques (
  fn               text PRIMARY KEY,
  taux_reussite    integer NOT NULL CHECK (taux_reussite BETWEEN 1 AND 100),
  toujours_reussi  boolean NOT NULL DEFAULT false,
  effets           jsonb   NOT NULL DEFAULT '{}'::jsonb,
  batiments        text[]  NOT NULL,
  poste_requis     text,            -- NULL : aucun ; '*' : n'importe quel poste ; sinon l'id du poste
  maj_le           timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ordres_generiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ordres_generiques FROM anon, authenticated;

INSERT INTO public.ordres_generiques (fn, taux_reussite, toujours_reussi, effets, batiments, poste_requis) VALUES
  ('soins_urgence',  100, true,  '{"hp":40}',            ARRAY['clinique-privee'], NULL),
  ('soins_discrets',  95, false, '{"hp":30,"dis":-2}',   ARRAY['clinique-privee'], NULL),
  ('fuite_info',      60, false, '{"pop":10,"inf":5}',   ARRAY['palais-gouvernement'], '*'),
  ('deliberer_loge', 100, true,  '{"inf":3}',            ARRAY['loge-maconnique'], NULL),
  ('interroger',      75, false, '{"inf":5}',            ARRAY['qhs-prison'], 'commissaire')
ON CONFLICT (fn) DO UPDATE SET taux_reussite = EXCLUDED.taux_reussite, toujours_reussi = EXCLUDED.toujours_reussi,
  effets = EXCLUDED.effets, batiments = EXCLUDED.batiments, poste_requis = EXCLUDED.poste_requis, maj_le = now();

CREATE OR REPLACE FUNCTION public.ordre_generique_executer(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; o record; d record; v_paie jsonb; v_roll integer; v_taux integer; v_res text; v_mult numeric;
  v_hp integer; v_moral integer; v_res_j jsonb; v_rembourse numeric := 0;
  e_hp numeric; e_moral numeric; e_pop numeric; e_inf numeric; e_dis numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO o FROM public.ordres_generiques WHERE fn = p_fn;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'ordre_indisponible'); END IF;
  SELECT current_building, poste ->> 'id' AS poste INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT (coalesce(d.current_building, '') = ANY (o.batiments)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF o.poste_requis = '*' AND d.poste IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  IF o.poste_requis IS NOT NULL AND o.poste_requis <> '*' AND d.poste IS DISTINCT FROM o.poste_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis', 'requis', o.poste_requis); END IF;

  v_paie := public.payer_ordre(v_moi, p_fn, p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  -- Le jet, tel que le faisait l'ecran.
  v_roll := floor(random() * 100)::integer + 1;
  v_taux := greatest(5, CASE WHEN o.taux_reussite >= 98 THEN 99 ELSE o.taux_reussite END);
  IF v_roll <= 100 - v_taux THEN v_res := 'crit-fail';
  ELSIF v_roll <= 100 - (v_taux * 0.7) THEN v_res := 'fail';
  ELSIF v_roll <= 100 - (v_taux * 0.4) THEN v_res := 'partial';
  ELSIF v_roll >= 95 THEN v_res := 'crit';
  ELSE v_res := 'success'; END IF;
  IF o.toujours_reussi THEN v_res := CASE WHEN v_roll >= 95 THEN 'crit' ELSE 'success' END; END IF;
  v_mult := CASE v_res WHEN 'crit' THEN 1.5 WHEN 'success' THEN 1 WHEN 'partial' THEN 0.5 WHEN 'fail' THEN 0 ELSE -0.5 END;

  e_hp := coalesce((o.effets ->> 'hp')::numeric, 0);
  e_moral := coalesce((o.effets ->> 'moral')::numeric, 0);
  e_pop := coalesce((o.effets ->> 'pop')::numeric, 0);
  e_inf := coalesce((o.effets ->> 'inf')::numeric, 0);
  e_dis := coalesce((o.effets ->> 'dis')::numeric, 0);

  SELECT coalesce(hp, 100), coalesce(moral, 75),
         CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_hp, v_moral, v_res_j FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;

  IF e_hp <> 0 THEN v_hp := least(100, greatest(0, v_hp + round(e_hp * v_mult)::integer)); END IF;
  IF e_moral <> 0 THEN v_moral := least(100, greatest(0, v_moral + round(e_moral * v_mult)::integer)); END IF;
  IF e_inf <> 0 THEN v_res_j := jsonb_set(v_res_j, '{inf}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'inf')::numeric, 0) + round(e_inf * v_mult))))); END IF;
  IF e_pop <> 0 THEN v_res_j := jsonb_set(v_res_j, '{pop}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'pop')::numeric, 50) + round(e_pop * CASE WHEN v_res = 'crit-fail' THEN -1 ELSE v_mult END))))); END IF;
  IF e_dis <> 0 THEN v_res_j := jsonb_set(v_res_j, '{dis}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'dis')::numeric, 85) + round(e_dis * CASE WHEN e_dis < 0 THEN 1 ELSE v_mult END))))); END IF;

  -- Echec simple : 30 % du cout rendu (regle inchangee).
  IF v_res = 'fail' AND coalesce(p_cost, 0) > 0 THEN v_rembourse := round(p_cost * 0.3); END IF;

  UPDATE public.personnages_donnees
     SET hp = v_hp, moral = v_moral, resources = v_res_j,
         liquide = coalesce(liquide, 0) + v_rembourse, arg = coalesce(arg, 0) + v_rembourse
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'resultat', v_res, 'jet', v_roll, 'hp', v_hp, 'moral', v_moral,
    'pop', v_res_j -> 'pop', 'inf', v_res_j -> 'inf', 'dis', v_res_j -> 'dis', 'rembourse', v_rembourse,
    'pa', (v_paie -> 'pa'),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'solde_national', v_paie -> 'solde_national');
END; $function$;
REVOKE ALL ON FUNCTION public.ordre_generique_executer(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ordre_generique_executer(text, integer, integer) TO authenticated;

-- « Racheter l'usine » (usine-principale) passait par l'ordre generique sans aucun effet : on
-- payait 8 000 FR pour rien, alors que le bouton promet 200 FR par jour. Constitution, article 15 :
-- l'ordre est retire du miroir des couts (plus aucun paiement possible) et le bouton passe en
-- « bientot » dans data.js, en attendant une decision de game design.
DELETE FROM public.ordres_couts WHERE fn = 'acheter_entreprise';
