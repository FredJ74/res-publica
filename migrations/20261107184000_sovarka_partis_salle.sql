-- PARTIS DE SOVARKA : SALLE DES PARTIS ET « POSTULER À UN POSTE » (décisions de Fred, 07/11/2026,
-- GAME-DESIGN-NOVOMIRSK.md, « Partis de Sovarka »).
--
-- Règles :
--  * création libre, dans la salle des partis d'une des trois mairies : 2 PA et 15 PSK de droits
--    d'enregistrement ; parti national, siège dans la ville de création ;
--  * un seul parti à la fois ; adhésion sur demande (2 PA) acceptée ou refusée par le chef ;
--    droit d'entrée fixé par le chef, payé à l'acceptation, versé à la caisse du parti ;
--    un refus coûte 2 POP au parti (popularité propre au parti, 50 au départ, bornée 0-100) ;
--  * quitter coûte 1 PA ; le chef désigne d'abord un successeur ; le dernier membre qui part
--    dissout le parti ;
--  * en Sovarka, aucun poste nommé sans parti (« parti_requis ») ; un ministre hors du parti du
--    Président du Conseil n'est permis que si aucun membre du parti n'est libre (tous occupent
--    déjà un poste du gouvernement).
-- Les portes génériques des organisations (fonder, demander, admettre, quitter, dissoudre) sont
-- fermées aux partis de Sovarka : un seul circuit, celui-ci.

-- 1. Coûts déclarés
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, x.cost FROM (VALUES ('sovarka_parti_fonder', 2, 15), ('sovarka_parti_adherer', 2, 0),
                                       ('sovarka_parti_quitter', 1, 0)) AS x(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn);

-- 2. Navigation serveur : la salle des partis des trois mairies
UPDATE public.navigation_lieux_regles
   SET pieces = CASE WHEN pieces @> '["salle_partis"]'::jsonb THEN pieces ELSE pieces || '["salle_partis"]'::jsonb END
 WHERE pays = 'soviet' AND ((ville = 'capitale' AND batiment = 'mairie-capitale')
                            OR (ville IN ('ville_a', 'ville_b') AND batiment = 'mairie'));

-- 3. Est-ce un parti de Sovarka ?
CREATE OR REPLACE FUNCTION public.sovarka_est_parti_interne(d jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(d->>'type' = 'politique' AND coalesce(d->>'country', d->>'country_origine') = 'soviet', false);
$$;
REVOKE ALL ON FUNCTION public.sovarka_est_parti_interne(jsonb) FROM PUBLIC, anon, authenticated;

-- 4. Lecture : partis, mon parti, et pour le chef ses demandes et ses membres
CREATE OR REPLACE FUNCTION public.sovarka_partis_liste()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_mien text; d jsonb; v_partis jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_mien := public.sovarka_parti_de(a);
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id, 'nom', o.data::jsonb->>'nom', 'desc', o.data::jsonb->>'desc', 'chef', o.data::jsonb->>'chef',
           'siege', o.data::jsonb->>'city', 'prix', coalesce((o.data::jsonb->>'prixAdhesion')::numeric, 0),
           'pop', coalesce((o.data::jsonb->>'pop')::numeric, 50),
           'membres', jsonb_array_length(coalesce(o.data::jsonb->'membres', '[]')),
           'demande_en_cours', EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(o.data::jsonb->'demandesAdhesion', '[]')) m
                                        WHERE m->>'nom' = a))
           ORDER BY o.created_at), '[]')
    INTO v_partis
    FROM public.organisations o
   WHERE o.data IS JSON OBJECT AND public.sovarka_est_parti_interne(o.data::jsonb);
  IF v_mien IS NOT NULL THEN
    SELECT data::jsonb INTO d FROM public.organisations WHERE id = v_mien;
  END IF;
  RETURN jsonb_build_object('ok', true, 'partis', v_partis,
    'mon_parti', CASE WHEN d IS NULL THEN NULL ELSE jsonb_build_object(
       'id', v_mien, 'nom', d->>'nom', 'chef', d->>'chef', 'est_chef', d->>'chef' = a, 'siege', d->>'city',
       'prix', coalesce((d->>'prixAdhesion')::numeric, 0), 'pop', coalesce((d->>'pop')::numeric, 50),
       'caisse', CASE WHEN d->>'chef' = a THEN coalesce((d->>'caisse')::numeric, 0) END,
       'membres', coalesce(d->'membres', '[]'),
       'demandes', CASE WHEN d->>'chef' = a THEN coalesce(d->'demandesAdhesion', '[]') ELSE '[]'::jsonb END) END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_partis_liste() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_partis_liste() TO authenticated;

-- 5. Commandes : fonder, demander, accepter, refuser, fixer_prix, successeur, quitter
CREATE OR REPLACE FUNCTION public.sovarka_parti_commande(p_requete uuid, p_action text, p_parti text, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  a text := public.mon_personnage(); act text := 'sovarka:parti'; par jsonb;
  v jsonb; dt text; p record; d jsonb; v_paie jsonb; v_id text; v_nom text; v_cible text; v_prix numeric;
  v_pris numeric; v_grades jsonb; v_jour integer; v_ville text; v_autres int;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  p_params := coalesce(p_params, '{}'::jsonb);
  par := jsonb_build_object('action', p_action, 'parti', p_parti, 'params', p_params);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:parti:membre:' || a, 0));
    SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = a;
    v_grades := public.organisation_regles_membres() -> 'politique' -> 'grades' -> 'soviet';
    v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
    IF p.country IS DISTINCT FROM 'soviet' THEN
      v := jsonb_build_object('ok', false, 'raison', 'reserve_a_sovarka');
    ELSIF p_action = 'fonder' THEN
      v_nom := btrim(coalesce(p_params->>'nom', ''));
      v_ville := p.current_city;
      IF p_params - ARRAY['nom', 'desc'] <> '{}'::jsonb THEN v := jsonb_build_object('ok', false, 'raison', 'champs_interdits');
      ELSIF NOT (p.current_room = 'salle_partis' AND ((v_ville = 'capitale' AND p.current_building = 'mairie-capitale')
                 OR (v_ville IN ('ville_a', 'ville_b') AND p.current_building = 'mairie'))) THEN
        v := jsonb_build_object('ok', false, 'raison', 'salle_des_partis_requise');
      ELSIF public.sovarka_parti_de(a) IS NOT NULL THEN v := jsonb_build_object('ok', false, 'raison', 'deja_dans_un_parti');
      ELSIF length(v_nom) < 2 THEN v := jsonb_build_object('ok', false, 'raison', 'nom_requis');
      ELSIF length(v_nom) > 40 OR length(coalesce(p_params->>'desc', '')) > 200 THEN v := jsonb_build_object('ok', false, 'raison', 'texte_trop_long');
      ELSE
        PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:parti:nom', 0));
        IF EXISTS (SELECT 1 FROM public.organisations o WHERE o.data IS JSON OBJECT AND public.sovarka_est_parti_interne(o.data::jsonb)
                     AND lower(btrim(o.data::jsonb->>'nom')) = lower(v_nom)) THEN
          v := jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
        ELSE
          v_paie := public.payer_ordre_interne(a, 'sovarka_parti_fonder', 2, 15);
          IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
          ELSE
            v_id := 'orga_' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
            d := jsonb_build_object('id', v_id, 'type', 'politique', 'nom', v_nom, 'desc', btrim(coalesce(p_params->>'desc', '')),
              'fondateur', a, 'chef', a, 'country', 'soviet', 'country_origine', 'soviet', 'city', v_ville, 'creeLe', v_jour,
              'sovarkaParti', true, 'prixAdhesion', 0, 'pop', 50,
              'membres', jsonb_build_array(jsonb_build_object('nom', a, 'grade', v_grades->>3, 'gradeIdx', 3, 'rejointLe', v_jour)),
              'demandesAdhesion', '[]'::jsonb, 'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0),
              'caisse', 0, 'influence', 50, 'visible', true);
            INSERT INTO public.organisations (id, country_origine, data) VALUES (v_id, 'soviet', d::text);
            v := jsonb_build_object('ok', true, 'action', 'fonder', 'parti', v_id, 'nom', v_nom,
                   'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
          END IF;
        END IF;
      END IF;
    ELSE
      SELECT data::jsonb INTO d FROM public.organisations WHERE id = p_parti FOR UPDATE;
      v_cible := btrim(coalesce(p_params->>'nom', ''));
      IF d IS NULL OR NOT public.sovarka_est_parti_interne(d) THEN
        v := jsonb_build_object('ok', false, 'raison', 'parti_introuvable');
      ELSIF p_action = 'demander' THEN
        IF p_params <> '{}'::jsonb THEN v := jsonb_build_object('ok', false, 'raison', 'champs_interdits');
        ELSIF public.sovarka_parti_de(a) IS NOT NULL THEN v := jsonb_build_object('ok', false, 'raison', 'deja_dans_un_parti');
        ELSIF EXISTS (SELECT 1 FROM public.organisations o, jsonb_array_elements(coalesce(o.data::jsonb->'demandesAdhesion', '[]')) m
                       WHERE o.data IS JSON OBJECT AND public.sovarka_est_parti_interne(o.data::jsonb) AND m->>'nom' = a) THEN
          v := jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
        ELSE
          v_paie := public.payer_ordre_interne(a, 'sovarka_parti_adherer', 2, 0);
          IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
          ELSE
            d := jsonb_set(d, '{demandesAdhesion}', coalesce(d->'demandesAdhesion', '[]') || jsonb_build_array(jsonb_build_object('nom', a, 'date', v_jour)));
            UPDATE public.organisations SET data = d::text WHERE id = p_parti;
            PERFORM public.mail_systeme_poser_interne(d->>'nom', d->>'chef', 'Demande d''adhésion : ' || a,
              a || ' demande à adhérer à votre parti. Droit d''entrée actuel : ' || coalesce(d->>'prixAdhesion', '0')
              || ' PSK, payé à l''acceptation. Un refus coûte 2 POP au parti. Répondez depuis la salle des partis d''une mairie (« Mon parti »).', NULL);
            v := jsonb_build_object('ok', true, 'action', 'demander', 'parti', p_parti, 'nom', d->>'nom', 'pa', v_paie->'pa');
          END IF;
        END IF;
      ELSIF p_action IN ('accepter', 'refuser', 'fixer_prix', 'successeur') THEN
        IF d->>'chef' IS DISTINCT FROM a THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_au_chef');
        ELSIF p_action = 'fixer_prix' THEN
          IF p_params - ARRAY['prix'] <> '{}'::jsonb OR jsonb_typeof(p_params->'prix') IS DISTINCT FROM 'number'
             OR (p_params->>'prix')::numeric < 0 OR (p_params->>'prix')::numeric > 100000
             OR (p_params->>'prix')::numeric <> round((p_params->>'prix')::numeric) THEN
            v := jsonb_build_object('ok', false, 'raison', 'prix_invalide');
          ELSE
            d := d || jsonb_build_object('prixAdhesion', (p_params->>'prix')::numeric);
            UPDATE public.organisations SET data = d::text WHERE id = p_parti;
            v := jsonb_build_object('ok', true, 'action', 'fixer_prix', 'prix', (p_params->>'prix')::numeric);
          END IF;
        ELSIF p_params - ARRAY['nom'] <> '{}'::jsonb OR v_cible = '' THEN
          v := jsonb_build_object('ok', false, 'raison', 'cible_requise');
        ELSIF p_action = 'successeur' THEN
          IF v_cible = a OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres', '[]')) m WHERE m->>'nom' = v_cible) THEN
            v := jsonb_build_object('ok', false, 'raison', 'membre_absent');
          ELSE
            d := d || jsonb_build_object('chef', v_cible);
            d := jsonb_set(d, '{membres}', (SELECT jsonb_agg(CASE WHEN m->>'nom' = v_cible THEN m || jsonb_build_object('gradeIdx', 3, 'grade', v_grades->>3)
                                                              WHEN m->>'nom' = a THEN m || jsonb_build_object('gradeIdx', 2, 'grade', v_grades->>2)
                                                              ELSE m END ORDER BY o) FROM jsonb_array_elements(d->'membres') WITH ORDINALITY e(m, o)));
            UPDATE public.organisations SET data = d::text WHERE id = p_parti;
            PERFORM public.mail_systeme_poser_interne(d->>'nom', v_cible, 'Vous dirigez désormais ' || (d->>'nom'),
              a || ' vous a désigné comme son successeur à la tête du parti.', NULL);
            v := jsonb_build_object('ok', true, 'action', 'successeur', 'chef', v_cible);
          END IF;
        ELSIF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(d->'demandesAdhesion', '[]')) m WHERE m->>'nom' = v_cible) THEN
          v := jsonb_build_object('ok', false, 'raison', 'demande_absente');
        ELSIF p_action = 'refuser' THEN
          d := jsonb_set(d, '{demandesAdhesion}', coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(d->'demandesAdhesion') m WHERE m->>'nom' IS DISTINCT FROM v_cible), '[]'));
          d := d || jsonb_build_object('pop', greatest(0, coalesce((d->>'pop')::numeric, 50) - 2));
          UPDATE public.organisations SET data = d::text WHERE id = p_parti;
          PERFORM public.mail_systeme_poser_interne(d->>'nom', v_cible, 'Adhésion refusée',
            'Votre demande d''adhésion au parti ' || (d->>'nom') || ' a été refusée.', NULL);
          v := jsonb_build_object('ok', true, 'action', 'refuser', 'nom', v_cible, 'pop', d->'pop');
        ELSE
          -- accepter : le candidat n'a pas rejoint un autre parti entre-temps, et paie le droit d'entrée
          PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:parti:membre:' || v_cible, 0));
          v_prix := coalesce((d->>'prixAdhesion')::numeric, 0);
          IF public.sovarka_parti_de(v_cible) IS NOT NULL THEN
            v := jsonb_build_object('ok', false, 'raison', 'candidat_deja_dans_un_parti');
          ELSE
            IF v_prix > 0 THEN
              IF (SELECT coalesce(liquide, 0) FROM public.personnages_donnees WHERE name = v_cible)
                 + coalesce((SELECT sum(greatest(solde, 0)) FROM public.comptes_bancaires WHERE personnage = v_cible AND banque = 'nationale'), 0) < v_prix THEN
                v := jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants_candidat');
              ELSE
                v_pris := public.argent_debiter_interne(v_cible, v_prix, 'liquide_puis_nationale');
                IF v_pris <> v_prix THEN RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = '{"ok":false,"raison":"fonds_insuffisants_candidat"}'; END IF;
                d := d || jsonb_build_object('caisse', coalesce((d->>'caisse')::numeric, 0) + v_prix);
              END IF;
            END IF;
            IF v IS NULL THEN
              d := jsonb_set(d, '{demandesAdhesion}', coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(d->'demandesAdhesion') m WHERE m->>'nom' IS DISTINCT FROM v_cible), '[]'));
              d := jsonb_set(d, '{membres}', coalesce(d->'membres', '[]') || jsonb_build_array(
                     jsonb_build_object('nom', v_cible, 'grade', v_grades->>0, 'gradeIdx', 0, 'rejointLe', v_jour)));
              UPDATE public.organisations SET data = d::text WHERE id = p_parti;
              PERFORM public.mail_systeme_poser_interne(d->>'nom', v_cible, 'Adhésion acceptée',
                'Bienvenue au parti ' || (d->>'nom') || '.' || CASE WHEN v_prix > 0 THEN ' Droit d''entrée payé : ' || v_prix || ' PSK.' ELSE '' END, NULL);
              v := jsonb_build_object('ok', true, 'action', 'accepter', 'nom', v_cible, 'prix', v_prix);
            END IF;
          END IF;
        END IF;
      ELSIF p_action = 'quitter' THEN
        IF p_params <> '{}'::jsonb THEN v := jsonb_build_object('ok', false, 'raison', 'champs_interdits');
        ELSIF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres', '[]')) m WHERE m->>'nom' = a) AND d->>'chef' IS DISTINCT FROM a THEN
          v := jsonb_build_object('ok', false, 'raison', 'membre_absent');
        ELSE
          SELECT count(*) INTO v_autres FROM jsonb_array_elements(coalesce(d->'membres', '[]')) m WHERE m->>'nom' IS DISTINCT FROM a;
          IF d->>'chef' = a AND v_autres > 0 THEN
            v := jsonb_build_object('ok', false, 'raison', 'successeur_requis');
          ELSE
            v_paie := public.payer_ordre_interne(a, 'sovarka_parti_quitter', 1, 0);
            IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
            ELSIF v_autres = 0 THEN
              DELETE FROM public.organisations WHERE id = p_parti;
              v := jsonb_build_object('ok', true, 'action', 'quitter', 'dissous', true, 'nom', d->>'nom', 'pa', v_paie->'pa');
            ELSE
              d := jsonb_set(d, '{membres}', coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(d->'membres') m WHERE m->>'nom' IS DISTINCT FROM a), '[]'));
              UPDATE public.organisations SET data = d::text WHERE id = p_parti;
              v := jsonb_build_object('ok', true, 'action', 'quitter', 'dissous', false, 'nom', d->>'nom', 'pa', v_paie->'pa');
            END IF;
          END IF;
        END IF;
      ELSE
        v := jsonb_build_object('ok', false, 'raison', 'action_inconnue');
      END IF;
    END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_parti_commande(uuid, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_parti_commande(uuid, text, text, jsonb) TO authenticated;

-- 6. Nominations de Sovarka : parti requis, ministres hors parti si aucun membre libre
CREATE OR REPLACE FUNCTION public.sovarka_nomination_refus(p_poste text, p_titulaire text, p_source text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_pm text; v_parti_pm text; d jsonb;
BEGIN
  IF coalesce(p_source, '') IN ('sovarka_gloire') OR coalesce(p_source, '') ILIKE 'restaur%' THEN
    RETURN NULL;
  END IF;
  IF p_poste = 'pm' AND public.sovarka_gloire_vainqueur() IS NOT NULL THEN
    RETURN 'pm_impose_par_le_parti';
  END IF;
  -- Aucun poste nommé sans parti (Fred, 07/11/2026) ; les PNJ ne sont pas concernés.
  IF EXISTS (SELECT 1 FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste)
     AND EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name = p_titulaire)
     AND public.sovarka_parti_de(p_titulaire) IS NULL THEN
    RETURN 'parti_requis';
  END IF;
  IF p_poste IN ('min_int','min_fin','min_just','min_def','min_info','min_ae') THEN
    SELECT titulaire INTO v_pm FROM public.postes_attribues WHERE id = 'soviet_pm_national';
    IF v_pm IS NULL THEN
      SELECT nom_pnj INTO v_pm FROM public.titulaires_pnj WHERE id = 'soviet_pm_national';
    END IF;
    v_parti_pm := CASE WHEN v_pm IS NULL THEN NULL ELSE public.sovarka_parti_de(v_pm) END;
    IF v_parti_pm IS NOT NULL AND public.sovarka_parti_de(p_titulaire) IS DISTINCT FROM v_parti_pm THEN
      -- Hors du parti seulement si aucun membre du parti n'est libre (Fred, 07/11/2026) :
      -- libre = joueur du parti qui n'occupe aucun poste du gouvernement.
      SELECT data::jsonb INTO d FROM public.organisations WHERE id = v_parti_pm;
      IF EXISTS (SELECT 1 FROM (SELECT d->>'chef' AS nom UNION SELECT m->>'nom' FROM jsonb_array_elements(coalesce(d->'membres', '[]')) m) x
                  WHERE x.nom IS NOT NULL
                    AND EXISTS (SELECT 1 FROM public.personnages_donnees pd WHERE pd.name = x.nom)
                    AND NOT EXISTS (SELECT 1 FROM public.postes_attribues a
                                     WHERE a.country = 'soviet' AND a.titulaire = x.nom
                                       AND a.poste_id IN ('pm','min_int','min_fin','min_just','min_def','min_info','min_ae'))) THEN
        RETURN 'ministre_hors_parti';
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_nomination_refus(text, text, text) FROM PUBLIC, anon, authenticated;

-- 7. Patchs en place, sous empreinte : portes génériques fermées aux partis, parti requis pour postuler
DO $patch$
DECLARE r record; v_def text; v_new text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.organisation_vie_commande(text,text,text,jsonb)', '6b0a9e82ee19505c2bface5cdec14e8c', 'parti_sovarka_salle_des_partis',
     E'    v_def := public.organisation_vie_referentiel() -> v_type;\n',
     E'    v_def := public.organisation_vie_referentiel() -> v_type;\n    IF v_type = ''politique'' AND v_perso.country = ''soviet'' THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''parti_sovarka_salle_des_partis''); END IF;\n'),
    ('public.organisation_commande_membres(text,text,text,jsonb)', 'db23d83700e94190d21229d251eb5402', 'parti_sovarka_salle_des_partis',
     E' IF p_action IN (''demander'',''admettre'',''accepter_invitation'') THEN\n',
     E' IF public.sovarka_est_parti_interne(d) AND p_action IN (''demander'',''admettre'',''refuser_demande'',''accepter_invitation'',''refuser_invitation'') THEN\n  RAISE EXCEPTION ''parti_sovarka_salle_des_partis''; END IF;\n IF p_action IN (''demander'',''admettre'',''accepter_invitation'') THEN\n'),
    ('public.organisation_commande_administrative(text,text,text,jsonb)', 'fcefcb173da45196adc7cff96d631541', 'parti_sovarka_salle_des_partis',
     E' avant:=d; chef:=coalesce(d->>''chef''=acteur,false); cible:=p_parametres->>''nom'';\n',
     E' avant:=d; chef:=coalesce(d->>''chef''=acteur,false); cible:=p_parametres->>''nom'';\n IF public.sovarka_est_parti_interne(d) AND p_action IN (''dissoudre'',''quitter'') THEN\n  RAISE EXCEPTION ''parti_sovarka_salle_des_partis''; END IF;\n'),
    ('public.poste_postuler(text,text)', '907a39ce173fc117599a3a2de5e3fb67', 'parti_requis',
     E'  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''poste_inconnu''); END IF;\n',
     E'  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''poste_inconnu''); END IF;\n  IF v_pays = ''soviet'' AND public.sovarka_parti_de(v_nom) IS NULL THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''parti_requis''); END IF;\n'),
    ('public.poste_candidature_transmettre(text,text)', '49902a3ebae3665a27dd2aa9b55e97e4', 'parti_requis',
     E'  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''poste_inconnu''); END IF;\n',
     E'  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''poste_inconnu''); END IF;\n  IF v_pays = ''soviet'' AND public.sovarka_parti_de(v_nom) IS NULL THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''parti_requis''); END IF;\n')
  ) AS t(fn, empreinte, marque, ancre, remplace) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    CONTINUE WHEN strpos(v_def, r.marque) > 0;
    IF md5(v_def) <> r.empreinte THEN RAISE EXCEPTION 'empreinte_inattendue: %', r.fn; END IF;
    IF (length(v_def) - length(replace(v_def, r.ancre, ''))) / length(r.ancre) <> 1 THEN
      RAISE EXCEPTION 'ancre_non_unique: %', r.fn; END IF;
    v_new := replace(v_def, r.ancre, r.remplace);
    EXECUTE v_new;
  END LOOP;
END $patch$;

-- 8. Contrôles structurels
DO $v$ BEGIN
  IF (SELECT count(*) FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND pieces @> '["salle_partis"]'::jsonb) <> 3 THEN
    RAISE EXCEPTION 'salle_partis_non_referencee'; END IF;
  IF strpos(pg_get_functiondef('public.poste_postuler(text,text)'::regprocedure), 'parti_requis') = 0
     OR strpos(pg_get_functiondef('public.poste_candidature_transmettre(text,text)'::regprocedure), 'parti_requis') = 0
     OR strpos(pg_get_functiondef('public.organisation_vie_commande(text,text,text,jsonb)'::regprocedure), 'parti_sovarka_salle_des_partis') = 0
     OR strpos(pg_get_functiondef('public.organisation_commande_membres(text,text,text,jsonb)'::regprocedure), 'parti_sovarka_salle_des_partis') = 0
     OR strpos(pg_get_functiondef('public.organisation_commande_administrative(text,text,text,jsonb)'::regprocedure), 'parti_sovarka_salle_des_partis') = 0 THEN
    RAISE EXCEPTION 'patch_incomplet'; END IF;
  IF (SELECT count(*) FROM public.ordres_couts WHERE fn IN ('sovarka_parti_fonder','sovarka_parti_adherer','sovarka_parti_quitter')) <> 3 THEN
    RAISE EXCEPTION 'couts_non_declares'; END IF;
END $v$;
