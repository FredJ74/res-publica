-- Même moteur judiciaire : reliquat existant et confirmation, aucun nouveau barème.
-- Prévol vivant impératif : cette définition ne figurait pas parmi les 22 corps fournis.
BEGIN;
DO $g$ DECLARE h text;BEGIN
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.justice_executer_condamnation(text,text)');
 IF h IS NULL OR h NOT IN('a7c59553d969fc20077b2059c2c8e9c6','cb4eeecfc22f4a0ec8aa27f19a78e1f6') THEN RAISE EXCEPTION 'definition_non_examinee: justice_executer_condamnation';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation(p_jugement_id text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_j record; v_jours integer; v_motif text; v_res jsonb; v_det record;v_reliquat numeric;
BEGIN
  v_acteur := public.exiger_poste('commissaire');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- Verrou : deux executions simultanees de la meme condamnation ne peuvent pas coexister.
  SELECT * INTO v_j FROM public.jugements WHERE id = p_jugement_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_introuvable');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', true, 'deja_executee', true, 'accuse', v_j.accuse);
  END IF;

  -- Deja detenu : la peine s'ajoute a la detention en cours plutot que d'en ouvrir une seconde.
  SELECT * INTO v_det FROM public.detention_active(v_j.accuse);
  IF v_det.id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  IF v_j.data->>'reliquat_jours' IS NOT NULL THEN
    v_reliquat:=(v_j.data->>'reliquat_jours')::numeric;
    IF v_reliquat<0 OR v_reliquat<>trunc(v_reliquat) OR v_reliquat::text IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','reliquat_invalide');END IF;
    v_jours:=v_reliquat::integer+coalesce((SELECT (x.value->>'jours')::integer FROM jsonb_array_elements(coalesce(v_j.data->'motifs','[]')) WITH ORDINALITY x(value,numero) WHERE x.value->>'source'='evasion' ORDER BY x.numero LIMIT 1),0);
  ELSE
  v_jours := coalesce((SELECT sum((m->>'jours')::int)
                         FROM jsonb_array_elements(coalesce(v_j.data->'motifs', '[]'::jsonb)) m), 0);
  END IF;
  IF v_jours <= 0 THEN v_jours := 3; END IF;   -- meme repli que le flagrant delit du client
  v_motif := coalesce(v_j.motif, 'Avis de recherche');

  v_res := public.detention_ouvrir_interne(
             v_j.accuse, v_motif, v_jours, coalesce(p_ville, v_j.city), v_j.country,
             coalesce(v_j.data->'motifs', '[]'::jsonb), v_acteur,
             coalesce(v_j.data->>'issue_judiciaire', 'condamnation_executee'),
             jsonb_build_object('ville_condamnation',v_j.city,'jour_affaire',v_j.data->'jour_affaire',
               'detention_precedente_id',v_j.data->'detention_precedente_id','reliquat_jours',v_j.data->'reliquat_jours'));
  IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN v_res;
  END IF;

  UPDATE public.jugements SET executee = true WHERE id = p_jugement_id;
  IF nullif(v_res->>'detention_id','') IS NULL
     OR NOT EXISTS(SELECT 1 FROM public.jugements WHERE id=p_jugement_id AND executee IS TRUE)
     OR NOT EXISTS(SELECT 1 FROM public.detentions d WHERE d.id=v_res->>'detention_id' AND d.nom=v_j.accuse AND d.city=coalesce(p_ville,v_j.city) AND d.country IS NOT DISTINCT FROM v_j.country AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL AND d.date_fin_effective IS NULL)
     OR (EXISTS(SELECT 1 FROM public.personnages_donnees p WHERE p.name=v_j.accuse) AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees p WHERE p.name=v_j.accuse AND p.est_emprisonne->>'detentionId'=v_res->>'detention_id')) THEN
    RAISE EXCEPTION 'execution_condamnation_non_confirmee';
  END IF;


  RETURN jsonb_build_object('ok', true, 'accuse', v_j.accuse, 'jours', v_jours,
                            'detention_id', v_res->>'detention_id', 'motif', v_motif);
END; $function$;
COMMIT;
