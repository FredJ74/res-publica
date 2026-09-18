-- SIMULATEUR PARAMETRIQUE DE COMBAT (banc d'equilibrage uniquement).
-- Reproduit la LOGIQUE du moteur de production (5 degres, simultaneite, degats en PA, 0 PA = hors
-- combat, echec critique faisant sauter le round suivant, surprise sequentielle au round 1,
-- doctrine repli_50 avec passage de decrochage sans riposte) mais en MEMOIRE, sans aucune ecriture
-- canonique : le moteur reel reecrit le document jsonb de la compagnie a chaque soldat touche, ce
-- qui rend impossible d'explorer des milliers de batailles.
CREATE FUNCTION pg_temp.sim(
  p_na int, p_comp_a numeric, p_pa_a int, p_stat_a numeric,
  p_nb int, p_comp_b numeric, p_pa_b int, p_stat_b numeric,
  p_surprise boolean, p_doc_a text, p_doc_b text,
  p_base numeric, p_off numeric, p_def_comp numeric, p_def_stat numeric,
  p_min int, p_max int, p_dcrit int, p_dreus int, p_dpart int)
RETURNS TABLE(rounds int, morts_a int, morts_b int, pa_a int, pa_b int, issue text,
              repli_camp text, repli_round int, pertes_a_repli int, pertes_b_repli int,
              degats_surprise int, surv_a int, surv_b int)
LANGUAGE plpgsql AS $SIM$
DECLARE
  pa_a int[]; pa_b int[]; sa int[]; sb int[];
  t_ab int; t_ba int; r int := 0; i int; j int; d int; jet int; deg text;
  op_a int; op_b int; dec_a text; dec_b text; fini boolean := false;
  v_pa int := 0; v_pb int := 0; v_surp int := 0; v_issue text;
  v_repli_camp text := NULL; v_repli_round int := NULL;
  v_pra int := NULL; v_prb int := NULL;
  act_att int[]; act_cib int[]; act_deg int[]; act_camp int[]; n_act int;
  snap_a int[]; snap_b int[]; nsa int; nsb int;
BEGIN
  -- Taux fixes : tous les combattants d'un camp sont identiques dans ces scenarios.
  t_ab := greatest(p_min, least(p_max, round(p_base + p_comp_a*p_off - p_comp_b*p_def_comp - p_stat_b*p_def_stat)::int));
  t_ba := greatest(p_min, least(p_max, round(p_base + p_comp_b*p_off - p_comp_a*p_def_comp - p_stat_a*p_def_stat)::int));
  pa_a := array_fill(p_pa_a, ARRAY[p_na]); pa_b := array_fill(p_pa_b, ARRAY[p_nb]);
  sa := array_fill(0, ARRAY[p_na]); sb := array_fill(0, ARRAY[p_nb]);

  WHILE NOT fini AND r < 300 LOOP
    r := r + 1;
    op_a := 0; FOR i IN 1..p_na LOOP IF pa_a[i] > 0 THEN op_a := op_a + 1; END IF; END LOOP;
    op_b := 0; FOR i IN 1..p_nb LOOP IF pa_b[i] > 0 THEN op_b := op_b + 1; END IF; END LOOP;
    IF op_a = 0 OR op_b = 0 THEN EXIT; END IF;

    -- Doctrine : seuil sur l'effectif INITIAL, jamais recalcule.
    dec_a := CASE WHEN p_doc_a = 'repli_50' AND op_a*2 <= p_na THEN 'replier' ELSE 'continuer' END;
    dec_b := CASE WHEN p_doc_b = 'repli_50' AND op_b*2 <= p_nb THEN 'replier' ELSE 'continuer' END;

    IF dec_a = 'replier' OR dec_b = 'replier' THEN
      v_repli_round := r;
      v_repli_camp := CASE WHEN dec_a='replier' AND dec_b='replier' THEN 'les_deux'
                           WHEN dec_a='replier' THEN 'a' ELSE 'b' END;
      v_pra := p_na - op_a; v_prb := p_nb - op_b;
      -- Passage de decrochage : le camp qui reste frappe, celui qui decroche ne riposte pas.
      IF dec_a = 'replier' AND dec_b = 'continuer' THEN
        FOR i IN 1..p_nb LOOP
          CONTINUE WHEN pa_b[i] <= 0 OR sb[i] = r;
          jet := floor(random()*100)::int + 1;
          deg := CASE WHEN jet >= 96 THEN 'ec' WHEN jet <= t_ba/4.0 THEN 'c'
                      WHEN jet <= t_ba*3.0/4.0 THEN 'r' WHEN jet <= t_ba THEN 'p' ELSE 'e' END;
          d := CASE deg WHEN 'c' THEN p_dcrit WHEN 'r' THEN p_dreus WHEN 'p' THEN p_dpart ELSE 0 END;
          IF d > 0 THEN
            j := 1 + floor(random()*p_na)::int;
            WHILE pa_a[j] <= 0 LOOP j := 1 + floor(random()*p_na)::int; END LOOP;
            pa_a[j] := greatest(0, pa_a[j] - d); v_pa := v_pa + d;
          END IF;
        END LOOP;
      ELSIF dec_b = 'replier' AND dec_a = 'continuer' THEN
        FOR i IN 1..p_na LOOP
          CONTINUE WHEN pa_a[i] <= 0 OR sa[i] = r;
          jet := floor(random()*100)::int + 1;
          deg := CASE WHEN jet >= 96 THEN 'ec' WHEN jet <= t_ab/4.0 THEN 'c'
                      WHEN jet <= t_ab*3.0/4.0 THEN 'r' WHEN jet <= t_ab THEN 'p' ELSE 'e' END;
          d := CASE deg WHEN 'c' THEN p_dcrit WHEN 'r' THEN p_dreus WHEN 'p' THEN p_dpart ELSE 0 END;
          IF d > 0 THEN
            j := 1 + floor(random()*p_nb)::int;
            WHILE pa_b[j] <= 0 LOOP j := 1 + floor(random()*p_nb)::int; END LOOP;
            pa_b[j] := greatest(0, pa_b[j] - d); v_pb := v_pb + d;
          END IF;
        END LOOP;
      END IF;
      v_issue := 'repli_' || v_repli_camp;
      fini := true;
      EXIT;
    END IF;

    -- ---- ROUND NORMAL ----
    IF r = 1 AND p_surprise THEN
      -- Passe de A appliquee AVANT que B ne soit photographie.
      FOR i IN 1..p_na LOOP
        CONTINUE WHEN pa_a[i] <= 0;
        jet := floor(random()*100)::int + 1;
        deg := CASE WHEN jet >= 96 THEN 'ec' WHEN jet <= t_ab/4.0 THEN 'c'
                    WHEN jet <= t_ab*3.0/4.0 THEN 'r' WHEN jet <= t_ab THEN 'p' ELSE 'e' END;
        IF deg = 'ec' THEN sa[i] := r + 1; CONTINUE; END IF;
        d := CASE deg WHEN 'c' THEN p_dcrit WHEN 'r' THEN p_dreus WHEN 'p' THEN p_dpart ELSE 0 END;
        CONTINUE WHEN d = 0;
        op_b := 0; FOR j IN 1..p_nb LOOP IF pa_b[j] > 0 THEN op_b := op_b + 1; END IF; END LOOP;
        EXIT WHEN op_b = 0;
        j := 1 + floor(random()*p_nb)::int;
        WHILE pa_b[j] <= 0 LOOP j := 1 + floor(random()*p_nb)::int; END LOOP;
        pa_b[j] := greatest(0, pa_b[j] - d); v_pb := v_pb + d; v_surp := v_surp + d;
      END LOOP;
      -- Riposte : seuls les survivants de B tirent.
      FOR i IN 1..p_nb LOOP
        CONTINUE WHEN pa_b[i] <= 0;
        jet := floor(random()*100)::int + 1;
        deg := CASE WHEN jet >= 96 THEN 'ec' WHEN jet <= t_ba/4.0 THEN 'c'
                    WHEN jet <= t_ba*3.0/4.0 THEN 'r' WHEN jet <= t_ba THEN 'p' ELSE 'e' END;
        IF deg = 'ec' THEN sb[i] := r + 1; CONTINUE; END IF;
        d := CASE deg WHEN 'c' THEN p_dcrit WHEN 'r' THEN p_dreus WHEN 'p' THEN p_dpart ELSE 0 END;
        CONTINUE WHEN d = 0;
        op_a := 0; FOR j IN 1..p_na LOOP IF pa_a[j] > 0 THEN op_a := op_a + 1; END IF; END LOOP;
        EXIT WHEN op_a = 0;
        j := 1 + floor(random()*p_na)::int;
        WHILE pa_a[j] <= 0 LOOP j := 1 + floor(random()*p_na)::int; END LOOP;
        pa_a[j] := greatest(0, pa_a[j] - d); v_pa := v_pa + d;
      END LOOP;
    ELSE
      -- SIMULTANE : toutes les actions calculees sur la photo, puis appliquees.
      snap_a := ARRAY[]::int[]; snap_b := ARRAY[]::int[];
      FOR i IN 1..p_na LOOP IF pa_a[i] > 0 THEN snap_a := snap_a || i; END IF; END LOOP;
      FOR i IN 1..p_nb LOOP IF pa_b[i] > 0 THEN snap_b := snap_b || i; END IF; END LOOP;
      nsa := array_length(snap_a,1); nsb := array_length(snap_b,1);
      act_camp := ARRAY[]::int[]; act_cib := ARRAY[]::int[]; act_deg := ARRAY[]::int[];
      FOR i IN 1..nsa LOOP
        CONTINUE WHEN sa[snap_a[i]] = r;
        jet := floor(random()*100)::int + 1;
        deg := CASE WHEN jet >= 96 THEN 'ec' WHEN jet <= t_ab/4.0 THEN 'c'
                    WHEN jet <= t_ab*3.0/4.0 THEN 'r' WHEN jet <= t_ab THEN 'p' ELSE 'e' END;
        IF deg = 'ec' THEN sa[snap_a[i]] := r + 1; CONTINUE; END IF;
        d := CASE deg WHEN 'c' THEN p_dcrit WHEN 'r' THEN p_dreus WHEN 'p' THEN p_dpart ELSE 0 END;
        CONTINUE WHEN d = 0;
        act_camp := act_camp || 1; act_cib := act_cib || snap_b[1 + floor(random()*nsb)::int]; act_deg := act_deg || d;
      END LOOP;
      FOR i IN 1..nsb LOOP
        CONTINUE WHEN sb[snap_b[i]] = r;
        jet := floor(random()*100)::int + 1;
        deg := CASE WHEN jet >= 96 THEN 'ec' WHEN jet <= t_ba/4.0 THEN 'c'
                    WHEN jet <= t_ba*3.0/4.0 THEN 'r' WHEN jet <= t_ba THEN 'p' ELSE 'e' END;
        IF deg = 'ec' THEN sb[snap_b[i]] := r + 1; CONTINUE; END IF;
        d := CASE deg WHEN 'c' THEN p_dcrit WHEN 'r' THEN p_dreus WHEN 'p' THEN p_dpart ELSE 0 END;
        CONTINUE WHEN d = 0;
        act_camp := act_camp || 2; act_cib := act_cib || snap_a[1 + floor(random()*nsa)::int]; act_deg := act_deg || d;
      END LOOP;
      n_act := coalesce(array_length(act_camp,1),0);
      FOR i IN 1..n_act LOOP
        IF act_camp[i] = 1 THEN
          CONTINUE WHEN pa_b[act_cib[i]] <= 0;
          pa_b[act_cib[i]] := greatest(0, pa_b[act_cib[i]] - act_deg[i]); v_pb := v_pb + act_deg[i];
        ELSE
          CONTINUE WHEN pa_a[act_cib[i]] <= 0;
          pa_a[act_cib[i]] := greatest(0, pa_a[act_cib[i]] - act_deg[i]); v_pa := v_pa + act_deg[i];
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  op_a := 0; FOR i IN 1..p_na LOOP IF pa_a[i] > 0 THEN op_a := op_a + 1; END IF; END LOOP;
  op_b := 0; FOR i IN 1..p_nb LOOP IF pa_b[i] > 0 THEN op_b := op_b + 1; END IF; END LOOP;
  IF v_issue IS NULL THEN
    v_issue := CASE WHEN op_a = 0 AND op_b = 0 THEN 'mutuel'
                    WHEN op_b = 0 THEN 'victoire_a' WHEN op_a = 0 THEN 'victoire_b'
                    ELSE 'borne' END;
  END IF;
  RETURN QUERY SELECT r, p_na - op_a, p_nb - op_b, v_pa, v_pb, v_issue,
    v_repli_camp, v_repli_round, v_pra, v_prb, v_surp, op_a, op_b;
END;
$SIM$;
