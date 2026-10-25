-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025193111.
-- Eprouvee avant application en transaction annulee (taux 40 refuse, 90 paye 2 h = 180 FR). Baseline NON reextrait.
-- ============================================================================
-- CHANTIERS : LE PROPRIETAIRE FIXE LE TAUX HORAIRE, AU MOINS LE SALAIRE MINIMUM
-- (GAME-DESIGN-BNE.md, decision de Fred du 25 octobre 2026)
-- ============================================================================
-- « Le proprietaire fixe le salaire mais ne peut pas descendre en dessous du salaire minimum de
-- 50 FR l'heure. » L'ordre « Travailler sur le chantier » reste cliquable comme aujourd'hui.
--
-- 1. entreprises_constantes : chantier_salaire_minimum = 50. Le taux de reference (70 FR) reste
--    celui des chantiers dont le proprietaire n'a rien fixe, et celui qui mesure le travail a
--    faire (capacite en heures) : le taux paye change ce que coute une heure, pas combien
--    d'heures le chantier demande.
-- 2. chantier_taux_definir (interne, comme chantier_prix_definir) : entier >= minimum, ecrit dans
--    chantier.tauxHoraire, sous l'autorite du titulaire (chantier_autorite_exiger_interne).
-- 3. chantier_commande : nouvelle action 'taux' (meme forme que 'prix'), refus nomme
--    'taux_invalide'.
-- 4. chantier_travailler : paie au taux du chantier (jamais sous le minimum), la tresorerie borne
--    les heures a ce taux. Patchs en place sur fragments exacts ; deja patche = laisse tel quel.
-- ============================================================================

INSERT INTO public.entreprises_constantes (cle, valeur)
SELECT 'chantier_salaire_minimum', 50
 WHERE NOT EXISTS (SELECT 1 FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum');

CREATE OR REPLACE FUNCTION public.chantier_taux_definir(p_terrain_id text, p_taux jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $function$
DECLARE v_id text; v_acteur text := public.mon_personnage(); v_pays text; v_etat jsonb; v_ch jsonb;
        v_n numeric; v_min numeric;
BEGIN
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;
  SELECT t.id, t.data::jsonb INTO v_id, v_etat FROM public.terrains_etat t
   WHERE t.country = v_pays AND (t.id = p_terrain_id OR t.building_id = p_terrain_id
         AND t.data::jsonb ->> 'city' = (SELECT current_city FROM public.personnages_donnees WHERE name = v_acteur))
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  PERFORM public.chantier_autorite_exiger_interne(v_etat ->> 'proprietaire', v_pays, v_etat ->> 'city');
  v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR (v_ch ->> 'progressionJours')::numeric >= (v_ch ->> 'dureeJours')::numeric
     OR nullif(v_etat ->> 'succession_gel', '') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_indisponible'); END IF;
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  IF jsonb_typeof(p_taux) NOT IN ('string', 'number') OR (p_taux #>> '{}') !~ '^[1-9][0-9]{0,5}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_invalide'); END IF;
  v_n := (p_taux #>> '{}')::numeric;
  IF v_n < coalesce(v_min, 50) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_invalide', 'minimum', coalesce(v_min, 50)); END IF;
  v_ch := v_ch || jsonb_build_object('tauxHoraire', v_n);
  v_etat := jsonb_set(v_etat, '{chantier}', v_ch);
  UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'taux', v_n, 'etat', v_etat);
END; $function$;
REVOKE ALL ON FUNCTION public.chantier_taux_definir(text, jsonb) FROM PUBLIC, anon, authenticated, service_role;

DO $p$ DECLARE s text; n text;
BEGIN
  s := pg_get_functiondef('public.chantier_commande(text,text,text,jsonb)'::regprocedure);
  IF position($x$p_action='taux'$x$ in s) > 0 THEN RETURN; END IF;
  n := replace(s, $a0$ ELSIF p_action='plan' THEN$a0$, $b0$ ELSIF p_action='taux' THEN
  IF p_parametres-ARRAY['taux']<>'{}' OR jsonb_typeof(p_parametres->'taux') NOT IN ('string','number') THEN RAISE EXCEPTION 'taux_invalide';END IF;
  r:=public.chantier_taux_definir(t.id,p_parametres->'taux');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'taux_invalide';END IF;
  SELECT data::jsonb INTO etat FROM public.terrains_etat WHERE id=t.id;
 ELSIF p_action='plan' THEN$b0$);
  n := replace(n, $a1$IF SQLERRM=ANY(ARRAY[$a1$, $b1$IF SQLERRM=ANY(ARRAY['taux_invalide',$b1$);
  IF position($x$p_action='taux'$x$ in n) = 0 OR position($x$ARRAY['taux_invalide',$x$ in n) = 0 THEN
    RAISE EXCEPTION 'patch non applique : fragments de chantier_commande introuvables';
  END IF;
  EXECUTE n;
END $p$;

DO $p$ DECLARE s text; n text;
BEGIN
  s := pg_get_functiondef('public.chantier_travailler(text,text,text,integer)'::regprocedure);
  IF position('v_taux_paye' in s) > 0 THEN RETURN; END IF;
  n := replace(s, E'  v_plafond numeric;\n', E'  v_plafond numeric; v_taux_paye numeric; v_min numeric;\n');
  n := replace(n, E'  v_payables   := floor(v_tresorerie / v_taux);\n',
    E'  -- Taux fixe par le proprietaire (Fred, 25/10/2026), jamais sous le salaire minimum.\n'
    || E'  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = ''chantier_salaire_minimum'';\n'
    || E'  v_taux_paye := GREATEST(COALESCE((v_ch->>''tauxHoraire'')::numeric, v_taux), COALESCE(v_min, 50));\n'
    || E'  v_payables   := floor(v_tresorerie / v_taux_paye);\n');
  n := replace(n, E'  v_montant := v_heures * v_taux;\n', E'  v_montant := v_heures * v_taux_paye;\n');
  n := replace(n, E'RETURN jsonb_build_object(''ok'', true, ''heures'', v_heures, ''montant'', v_montant,',
                  E'RETURN jsonb_build_object(''ok'', true, ''heures'', v_heures, ''montant'', v_montant, ''taux'', v_taux_paye,');
  IF position('v_taux_paye numeric' in n) = 0 OR position('floor(v_tresorerie / v_taux_paye)' in n) = 0
     OR position('v_heures * v_taux_paye' in n) = 0 OR position('''taux'', v_taux_paye' in n) = 0 THEN
    RAISE EXCEPTION 'patch non applique : fragments de chantier_travailler introuvables';
  END IF;
  EXECUTE n;
END $p$;
