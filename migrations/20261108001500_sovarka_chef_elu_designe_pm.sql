-- Sovarka : chef du parti vainqueur déjà président ou maire (décision de Fred, 08/11/2026).
-- « Il choisit qui il veut dans son parti » : le chef désigne le Président du Conseil du Peuple
-- parmi les membres de son parti (depuis « Mon parti », salle des partis). Le président ne nomme
-- toujours pas le pm tant qu'un parti a gagné (pm_impose_par_le_parti, inchangé).
-- 1. sovarka_parti_commande : action « designer_pm » (chef, parti vainqueur, chef président ou maire).
-- 2. sovarka_partis_liste : drapeau « peut_designer_pm » dans « Mon parti ».
-- 3. sovarka_gloire_proclamer : courrier au chef pour l'inviter à désigner le pm.
-- Patchs en place, sous empreinte : refus si un fragment attendu n'est pas présent une fois.
DO $m$
DECLARE d text; a1 text; a2 text; a3 text; n1 int; n2 int;
BEGIN
  -- 1. Commande
  d := pg_get_functiondef('public.sovarka_parti_commande(uuid,text,text,jsonb)'::regprocedure);
  IF position('designer_pm' in d) > 0 THEN
    RAISE NOTICE 'commande déjà appliquée';
  ELSE
    a1 := 'p_action IN (''accepter'', ''refuser'', ''fixer_prix'', ''successeur'')';
    a2 := 'ELSIF p_action = ''successeur'' THEN';
    n1 := (length(d) - length(replace(d, a1, ''))) / length(a1);
    n2 := (length(d) - length(replace(d, a2, ''))) / length(a2);
    IF n1 <> 1 OR n2 <> 1 THEN RAISE EXCEPTION 'empreinte_inattendue_sovarka_parti_commande (%, %)', n1, n2; END IF;
    d := replace(d, a1, 'p_action IN (''accepter'', ''refuser'', ''fixer_prix'', ''successeur'', ''designer_pm'')');
    d := replace(d, a2, $b$ELSIF p_action = 'designer_pm' THEN
          IF public.sovarka_gloire_vainqueur() IS DISTINCT FROM p_parti THEN
            v := jsonb_build_object('ok', false, 'raison', 'parti_non_vainqueur');
          ELSIF coalesce((SELECT x.poste->>'id' FROM public.personnages_donnees x WHERE x.name = a), '') NOT IN ('president', 'maire') THEN
            v := jsonb_build_object('ok', false, 'raison', 'chef_pm_d_office');
          ELSIF v_cible = a OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres', '[]')) m WHERE m->>'nom' = v_cible)
                OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name = v_cible) THEN
            v := jsonb_build_object('ok', false, 'raison', 'membre_absent');
          ELSIF coalesce((SELECT x.poste->>'id' FROM public.personnages_donnees x WHERE x.name = v_cible), '') IN ('president', 'maire') THEN
            v := jsonb_build_object('ok', false, 'raison', 'cible_deja_elue');
          ELSE
            SELECT titulaire INTO v_id FROM public.postes_attribues WHERE id = 'soviet_pm_national';
            v_paie := public.poste_attribuer_interne('soviet', 'pm', NULL, v_cible, 'sovarka_gloire');
            IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
              v := jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'nomination_refusee'));
            ELSE
              PERFORM public.mail_systeme_poser_interne(d->>'nom', v_cible, 'Président du Conseil du Peuple',
                a || ', chef du parti ' || (d->>'nom') || ', vous a désigné Président du Conseil du Peuple de Sovarka. '
                || 'Il vous revient de nommer les ministres, uniquement parmi les membres du parti.', NULL);
              IF v_id IS NOT NULL AND v_id IS DISTINCT FROM v_cible THEN
                PERFORM public.mail_systeme_poser_interne(d->>'nom', v_id, 'Fin de vos fonctions',
                  v_cible || ' devient Président du Conseil du Peuple, désigné par le chef du parti ' || (d->>'nom') || '.', NULL);
              END IF;
              v := jsonb_build_object('ok', true, 'action', 'designer_pm', 'nom', v_cible, 'predecesseur', v_id);
            END IF;
          END IF;
        ELSIF p_action = 'successeur' THEN$b$);
    EXECUTE d;
  END IF;

  -- 2. Liste
  d := pg_get_functiondef('public.sovarka_partis_liste()'::regprocedure);
  IF position('peut_designer_pm' in d) > 0 THEN
    RAISE NOTICE 'liste déjà appliquée';
  ELSE
    a1 := '''est_chef'', d->>''chef'' = a,';
    IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 THEN RAISE EXCEPTION 'empreinte_inattendue_sovarka_partis_liste'; END IF;
    EXECUTE replace(d, a1, a1 || ' ''peut_designer_pm'', (d->>''chef'' = a AND public.sovarka_gloire_vainqueur() IS NOT DISTINCT FROM v_mien'
      || ' AND coalesce((SELECT x.poste->>''id'' FROM public.personnages_donnees x WHERE x.name = a), '''') IN (''president'', ''maire'')),');
  END IF;

  -- 3. Proclamation
  d := pg_get_functiondef('public.sovarka_gloire_proclamer(bigint)'::regprocedure);
  a3 := 'v_pm := jsonb_build_object(''attribue'', false, ''raison'', ''chef_deja_elu'', ''chef'', v_chef, ''poste'', v_poste_chef);';
  IF position('Désigner le Président du Conseil' in d) > 0 THEN
    RAISE NOTICE 'proclamation déjà appliquée';
  ELSE
    IF (length(d) - length(replace(d, a3, ''))) / length(a3) <> 1 THEN RAISE EXCEPTION 'empreinte_inattendue_sovarka_gloire_proclamer'; END IF;
    EXECUTE replace(d, a3, a3 || $b$
      PERFORM public.mail_systeme_envoyer('Système', v_chef, 'Désigner le Président du Conseil',
        'Votre parti, ' || (v_scores -> 0 ->> 'nom') || ', a remporté la semaine à la gloire des partis. '
        || 'Comme vous êtes déjà ' || CASE WHEN v_poste_chef = 'president' THEN 'président' ELSE 'maire' END
        || ', il vous revient de désigner le Président du Conseil du Peuple parmi les membres du parti, '
        || 'depuis « Mon parti » dans la salle des partis d''une mairie.');$b$);
  END IF;
END $m$;
