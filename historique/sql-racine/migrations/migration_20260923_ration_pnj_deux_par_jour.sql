-- =============================================================================================
-- RATION DES SOLDATS PNJ : DEUX PAR JOUR, ET PLUS AUCUN GASPILLAGE (23 septembre 2026)
-- =============================================================================================
-- DEUX DEFAUTS FERMES ICI, releves a l'audit :
--
-- 1. LA RATION ETAIT LIMITEE A UNE PAR JOUR, structurellement : le marqueur 'dernier_ration'
--    stocke une DATE, pas un compteur, et la garde etait « marqueur <> aujourd'hui ». Impossible
--    d'aller au-dela de 1 sans compter. On ajoute donc 'nb_ration' a cote du marqueur, sans rien
--    reecrire en base.
--
--    COMPATIBILITE AVEC L'HISTORIQUE, c'est le point delicat : un soldat portant deja
--    'dernier_ration' = aujourd'hui SANS compteur est lu comme ayant consomme UNE ration
--    (coalesce(..., 1)). Sans ce 1, tous les soldats nourris aujourd'hui gagneraient une ration
--    gratuite le jour de la mise en service. Aucune migration de donnees n'est donc necessaire.
--
-- 2. UNE RATION ETAIT GASPILLEE AU PLAFOND. Le comptage ignorait les PA : un soldat deja a 12 PA
--    etait compte, consommait une ration et gagnait 0, le gain etant plafonne. Il est desormais
--    exclu des beneficiaires -- il ne consomme rien, n'incremente rien et ne perd rien.
--    La meme exclusion s'applique au bivouac.
--
-- CE QUI NE CHANGE PAS : la frequence du bivouac reste d'UNE fois par jour, sur son propre
-- marqueur. Le bivouac demeure une mecanique independante de la ration. L'autorite, la double
-- radio du commandement a distance, la verification des ressources avant toute ecriture et le
-- plafond de 12 PA sont inchanges.
--
-- LA VALEUR PAR DEFAUT DE p_leader EST CONSERVEE (DEFAULT NULL) : la retirer ferait echouer le
-- CREATE OR REPLACE, et surtout casserait les appelants qui omettent ce quatrieme argument.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.militaire_ordre_collectif(
  p_compagnie_id text, p_section_id text, p_action text, p_leader text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  c_capacite_tente   constant integer := 13;
  c_gain             constant integer := 1;
  c_pa_max_pnj       constant integer := 12;
  c_max_ration_jour  constant integer := 2;
  v_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb; v_leader text;
  v_jour text; v_n integer; v_tentes integer; v_requis integer;
  v_rations integer; v_inv jsonb; v_pos integer; i integer;
  v_a_distance boolean := false; v_radio_chef boolean; v_radio_leader boolean;
BEGIN
  IF p_action NOT IN ('ration', 'bivouac') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;

  -- Le groupe vise : celui mene par p_leader, ou par l'acteur lui-meme par defaut.
  v_leader := coalesce(nullif(btrim(coalesce(p_leader,'')), ''), v_moi);

  -- AUTORITE : le Lieutenant structurel, ou le leader operationnel pour SON propre groupe.
  IF v_sec->>'lieutenantNom' = v_moi THEN
    v_a_distance := (v_leader <> v_moi);
  ELSIF v_leader = v_moi THEN
    NULL;   -- un leader operationnel commande le groupe qu'il mene physiquement
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  -- DOUBLE RADIO obligatoire pour commander a distance. Relais de commandement, pas teleportation.
  IF v_a_distance THEN
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_moi AND i2->>'produitMilitaire' = 'radio') INTO v_radio_chef;
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i2
             WHERE pd.name = v_leader AND i2->>'produitMilitaire' = 'radio') INTO v_radio_leader;
    IF NOT coalesce(v_radio_chef,false) OR NOT coalesce(v_radio_leader,false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'radio_manquante',
        'radio_lieutenant', coalesce(v_radio_chef,false), 'radio_leader', coalesce(v_radio_leader,false));
    END IF;
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  -- BENEFICIAIRES. Le predicat est ecrit a l'identique ici et lors de l'application : un soldat
  -- compte est un soldat servi, et reciproquement.
  --   - soldat PNJ mene par ce leader ;
  --   - PAS DEJA AU PLAFOND : a 12 PA il ne gagnerait rien, on ne lui prend donc rien ;
  --   - ration : moins de deux rations consommees aujourd'hui (l'ancien marqueur seul vaut 1) ;
  --   - bivouac : pas encore bivouaque aujourd'hui -- frequence inchangee.
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean,false)
     AND sol->>'leaderCourant' = v_leader
     AND coalesce((sol->>'pa')::numeric, 0) < c_pa_max_pnj
     AND CASE WHEN p_action = 'ration'
              THEN (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                         THEN coalesce((sol->>'nb_ration')::integer, 1) ELSE 0 END) < c_max_ration_jour
              ELSE coalesce(sol->>'dernier_bivouac','') <> v_jour
         END;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_soldat_concerne');
  END IF;

  -- RESSOURCES, verifiees pour TOUT le groupe avant la moindre ecriture.
  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = v_leader FOR UPDATE;
  IF p_action = 'ration' THEN
    SELECT count(*) INTO v_rations FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'ration_combat';
    IF v_rations < v_n THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rations_insuffisantes',
        'requis', v_n, 'disponibles', v_rations);
    END IF;
  ELSE
    SELECT count(*) INTO v_tentes FROM jsonb_array_elements(v_inv) i2
     WHERE i2->>'produitMilitaire' = 'tente';
    v_requis := ceil(v_n::numeric / c_capacite_tente)::integer;
    IF coalesce(v_tentes,0) < v_requis THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'tentes_insuffisantes',
        'requis', v_requis, 'disponibles', coalesce(v_tentes,0), 'capacite_tente', c_capacite_tente);
    END IF;
  END IF;

  -- APPLICATION : +1 PA, plafond respecte, et le marqueur du jour mis a jour. Pour la ration, le
  -- compteur est incremente a partir de la meme lecture compatible que ci-dessus.
  SELECT coalesce(jsonb_agg(
           CASE WHEN NOT coalesce((sol->>'pj')::boolean,false)
                     AND sol->>'leaderCourant' = v_leader
                     AND coalesce((sol->>'pa')::numeric, 0) < c_pa_max_pnj
                     AND CASE WHEN p_action = 'ration'
                              THEN (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                                         THEN coalesce((sol->>'nb_ration')::integer, 1) ELSE 0 END) < c_max_ration_jour
                              ELSE coalesce(sol->>'dernier_bivouac','') <> v_jour
                         END
                THEN sol
                     || jsonb_build_object('pa', least(c_pa_max_pnj,
                          coalesce((sol->>'pa')::numeric, 0) + c_gain))
                     || CASE WHEN p_action = 'ration'
                             THEN jsonb_build_object('dernier_ration', v_jour,
                                    'nb_ration', (CASE WHEN coalesce(sol->>'dernier_ration','') = v_jour
                                                       THEN coalesce((sol->>'nb_ration')::integer, 1)
                                                       ELSE 0 END) + 1)
                             ELSE jsonb_build_object('dernier_bivouac', v_jour)
                        END
                ELSE sol END ORDER BY pos), '[]'::jsonb)
    INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La ration est consommee : une par soldat nourri. Le bivouac ne detruit PAS la tente.
  IF p_action = 'ration' THEN
    FOR i IN 1 .. v_n LOOP
      SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos)
       WHERE i2->>'produitMilitaire' = 'ration_combat' ORDER BY pos LIMIT 1;
      SELECT coalesce(jsonb_agg(i2 ORDER BY pos), '[]'::jsonb) INTO v_inv
        FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i2, pos) WHERE pos <> v_pos;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_leader;
  END IF;

  RETURN jsonb_build_object('ok', true, 'action', p_action, 'leader', v_leader,
    'soldats', v_n, 'a_distance', v_a_distance, 'gain_pa', c_gain,
    'tentes_requises', CASE WHEN p_action='bivouac' THEN v_requis END,
    'rations_consommees', CASE WHEN p_action='ration' THEN v_n END,
    'max_ration_jour', CASE WHEN p_action='ration' THEN c_max_ration_jour END);
END;
$function$;
