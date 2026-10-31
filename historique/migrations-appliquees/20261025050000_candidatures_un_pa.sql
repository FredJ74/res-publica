-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025182135.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025182135.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait.
-- ============================================================================
-- TOUTE CANDIDATURE A UN POSTE COUTE 1 PA (decision de Fred, 25 octobre 2026)
-- ============================================================================
-- Postes nommes (ordre « Postuler a un poste », Bureau de l'Emploi) et grades militaires
-- (« S'engager dans l'armee », Bureau de l'Emploi, choix d'une section). Avant : 2 PA affiches
-- pour le poste nomme mais JAMAIS preleves ; 2 PA preleves pour un grade militaire ; rien pour le
-- choix d'une section. Desormais : 1 PA, preleve par le serveur, et un refus ne coute rien.
--
-- 1. Miroir des couts : postuler et s_engager_armee passent a 1 PA (data.js aligne).
-- 2. poste_postuler (recruteur PNJ, nomination immediate) : 1 PA preleve dans la meme
--    transaction que la nomination ; si la nomination est refusee, le PA est rendu (sous-bloc).
-- 3. poste_candidature_transmettre (NOUVELLE) : recruteur JOUEUR. Verifie le poste et preleve
--    1 PA AVANT que l'ecran transmette le dossier (circuit du 25 aout, inchange).
-- 4. militaire_candidature_deposer : 2 -> 1 PA.
-- 5. militaire_candidater_soldat : 1 PA, preleve en dernier, apres toutes les verifications.
-- Patchs en place sur fragments exacts ; deja patche = laisse tel quel. Aucun acte de joueur.
-- ============================================================================

UPDATE public.ordres_couts SET pa = 1 WHERE fn IN ('postuler', 's_engager_armee');

-- 2. poste_postuler
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN public.poste_attribuer_interne(v_pays, p_poste, p_city, v_nom, ''candidature_autorite_pnj'');\n';
  v_ajout text := E'  -- 1 PA par candidature (Fred, 25/10/2026). Preleve avec la nomination ; une nomination\n  -- refusee annule le prelevement (sous-bloc = point de sauvegarde).\n  DECLARE v_paie jsonb; v_res jsonb;\n  BEGIN\n    v_paie := public.payer_ordre(v_nom, ''postuler'', 1, 0);\n    IF coalesce((v_paie ->> ''ok'')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;\n    v_res := public.poste_attribuer_interne(v_pays, p_poste, p_city, v_nom, ''candidature_autorite_pnj'');\n    IF coalesce((v_res ->> ''ok'')::boolean, false) IS NOT TRUE THEN\n      RAISE EXCEPTION USING ERRCODE = ''P0001'', MESSAGE = ''hg_candidature_refusee'', DETAIL = v_res::text;\n    END IF;\n    RETURN v_res || jsonb_build_object(''pa'', v_paie -> ''pa'');\n  EXCEPTION WHEN raise_exception THEN\n    IF SQLERRM = ''hg_candidature_refusee'' THEN RETURN v_res; END IF;\n    RAISE;\n  END;\n';
BEGIN
  v_def := pg_get_functiondef('public.poste_postuler(text,text)'::regprocedure);
  IF position('hg_candidature_refusee' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment de poste_postuler introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- 3. Candidature aupres d'un recruteur joueur : le serveur verifie et preleve 1 PA.
CREATE OR REPLACE FUNCTION public.poste_candidature_transmettre(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_regle record; v_paie jsonb;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_nom;
  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu'); END IF;
  IF EXISTS (SELECT 1 FROM public.postes_attribues a
              WHERE a.id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national')
                AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_occupe_par_un_joueur');
  END IF;
  v_paie := public.payer_ordre(v_nom, 'postuler', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  RETURN jsonb_build_object('ok', true, 'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.poste_candidature_transmettre(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_candidature_transmettre(text, text) TO authenticated;

-- 4. Grade militaire : 2 -> 1 PA.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.militaire_candidature_deposer(text)'::regprocedure);
  IF position('''s_engager_armee'', 1, 0)' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(replace(v_def, '''s_engager_armee'', 2, 0)', '''s_engager_armee'', 1, 0)'),
                   '''pa_preleves'', 2)', '''pa_preleves'', 1)');
  IF position('''s_engager_armee'', 1, 0)' in v_new) = 0 OR position('''pa_preleves'', 1)' in v_new) = 0 THEN
    RAISE EXCEPTION 'patch non applique : cout de militaire_candidature_deposer introuvable';
  END IF;
  EXECUTE v_new;
END $mig$;

-- 5. Choix d'une section comme soldat : 1 PA, preleve apres toutes les verifications.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  v_id := ''engsold-'' || replace(gen_random_uuid()::text, ''-'', '''');\n';
  v_ajout text := E'  -- 1 PA par candidature (Fred, 25/10/2026), preleve en dernier : un refus ne coute rien.\n  v_paie := public.payer_ordre(v_moi, ''s_engager_armee'', 1, 0);\n  IF coalesce((v_paie ->> ''ok'')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;\n';
BEGIN
  v_def := pg_get_functiondef('public.militaire_candidater_soldat(text,text)'::regprocedure);
  IF position('payer_ordre' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  v_new := replace(v_new, E'  v_data jsonb; v_sec jsonb; v_id text;\n', E'  v_data jsonb; v_sec jsonb; v_id text; v_paie jsonb;\n');
  IF position('v_paie jsonb' in v_new) = 0 OR position('payer_ordre' in v_new) = 0 THEN
    RAISE EXCEPTION 'patch non applique : fragments de militaire_candidater_soldat introuvables';
  END IF;
  v_new := replace(v_new, E'jsonb_build_object(''ok'', true, ''engagement'', v_id,', E'jsonb_build_object(''ok'', true, ''pa'', v_paie -> ''pa'', ''engagement'', v_id,');
  EXECUTE v_new;
END $mig$;
