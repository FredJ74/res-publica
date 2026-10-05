-- =====================================================================================
-- OUTILLAGE DE MIGRATION DES SOLDATS -- copie, comparateur, rollback
-- CE FICHIER N'EST PAS APPLIQUE. AUCUNE LIGNE N'A ETE EXECUTEE SUR public.
-- Les trois fonctions ont ete ecrites et EPROUVEES dans le schema jetable banc_pnj, contre
-- les 96 soldats REELS lus en lecture seule. Elles sont ici transposees vers public,
-- telles qu'elles seront appliquees au feu vert de bascule.
-- 26 septembre 2026
--
-- RESULTATS DE L'EPREUVE SUR LES DONNEES REELLES (schema banc_pnj, blob jamais ecrit) :
--   copie          -> 96 copies : 24 en section, 72 en reserve, 4 sections. Compte rendu exact.
--   comparateur    -> nb_blob 96, nb_socle 96, correspondances 96, divergences 0.
--   detection      -> 3 divergences injectees a la main dans le socle de banc, toutes vues :
--                     202609-001 'pa', 202609-025 'entrainement', 202609-096 'absent_du_socle'
--                     (nb_socle 95, manquants 1, correspondances 93).
--   seconde copie  -> refusee proprement : {ok:false, raison:'deja_copie', deja:95}
--   rollback       -> lignes de la compagnie supprimees, AUCUNE autre famille touchee,
--                     aucun metier orphelin.
--   recopie apres rollback -> 96/96, 0 divergence. Le cycle est donc repetable et reversible.
--   blob apres tout cela -> 96 soldats, updated_at TOUJOURS 2026-09-22 22:29:35.
--                           Preuve qu'il n'a jamais ete ecrit.
--
-- POINT DE NON-RETOUR : il n'y en a AUCUN pendant toute la phase miroir. Le blob reste
-- autoritaire et n'est jamais modifie par cet outillage ; le socle n'est qu'une copie qu'un
-- DELETE cible efface. Le point de non-retour n'apparaitra qu'au moment ou les 14 fonctions
-- d'ecriture basculeront leur autorite -- et il sera precede d'un snapshot date du blob.

-- -------------------------------------------------------------------------------------
-- 0. SNAPSHOT PREALABLE -- a executer AVANT la copie reelle, jamais apres.
-- -------------------------------------------------------------------------------------
-- CREATE TABLE public.compagnies_militaires_snapshot_avant_socle AS
--   SELECT *, now() AS snapshot_le FROM public.compagnies_militaires;
-- REVOKE ALL ON public.compagnies_militaires_snapshot_avant_socle FROM anon, authenticated, PUBLIC;

-- -------------------------------------------------------------------------------------
-- 1. COPIE blob -> socle. LIT compagnies_militaires, N'Y ECRIT JAMAIS.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_copier_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE
  c record; s jsonb; sol jsonb; v_id text; v_pays text;
  v_sections integer := 0; v_sect integer := 0; v_res integer := 0; v_deja integer := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';

  -- Refus propre d'une seconde copie : on constate, on n'ecrase pas.
  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'soldat' AND m.id LIKE p_compagnie || '-%';
  IF v_deja > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_copie', 'deja', v_deja);
  END IF;

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sections := v_sections + 1;
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;  -- un soldat PJ n'est pas un PNJ
      v_id := p_compagnie || '-' || (sol->>'matricule');
      INSERT INTO public.pnj_membres (id, famille, nom, pays,
          proprietaire_poste, proprietaire_poste_ville,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays,
          'lieutenant', NULL,
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif');
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
      VALUES (v_id, sol->>'matricule', s->>'id', false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb));
      v_sect := v_sect + 1;
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_poste, leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays,
        'lieutenant', sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif');
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
    VALUES (v_id, sol->>'matricule', NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb));
    v_res := v_res + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'compagnie', p_compagnie, 'pays', v_pays,
    'sections', v_sections, 'copies_section', v_sect, 'copies_reserve', v_res,
    'total', v_sect + v_res);
END; $fn$;

-- -------------------------------------------------------------------------------------
-- 2. COMPARATEUR. STRICTEMENT LECTURE SEULE : il ne corrige JAMAIS rien.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_comparer_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer;
BEGIN
  WITH blob AS (
    SELECT sol->>'matricule' AS matricule, sol->>'leaderCourant' AS leader,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS room,
           (sol->>'pa')::integer AS pa, sol->>'arme' AS arme,
           COALESCE(sol->'formation','{}'::jsonb) AS formation,
           false AS en_reserve, s->>'id' AS section_id
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) sol
     WHERE c.id = p_compagnie AND COALESCE((sol->>'pj')::boolean, false) = false
    UNION ALL
    SELECT r->>'matricule', r->>'leaderCourant', r->>'ville', r->>'buildingId', r->>'roomId',
           (r->>'pa')::integer, r->>'arme', COALESCE(r->'formation','{}'::jsonb), true, NULL
      FROM public.compagnies_militaires c,
           jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) r
     WHERE c.id = p_compagnie
  ), socle AS (
    SELECT sm.matricule, m.leader_pj AS leader, m.ville, m.building_id AS bat,
           m.room_id AS room, m.pa, sm.arme, sm.formation, sm.en_reserve, sm.section_id,
           m.proprietaire_poste, m.statut
      FROM public.pnj_membres m JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE m.id LIKE p_compagnie || '-%'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.leader      IS DISTINCT FROM s.leader      THEN 'leader'
        WHEN b.ville       IS DISTINCT FROM s.ville       THEN 'ville'
        WHEN b.bat         IS DISTINCT FROM s.bat         THEN 'batiment'
        WHEN b.room        IS DISTINCT FROM s.room        THEN 'piece'
        WHEN b.pa          IS DISTINCT FROM s.pa          THEN 'pa'
        WHEN b.arme        IS DISTINCT FROM s.arme        THEN 'arme'
        WHEN b.formation   IS DISTINCT FROM s.formation   THEN 'entrainement'
        WHEN b.en_reserve  IS DISTINCT FROM s.en_reserve  THEN 'reserve'
        WHEN b.section_id  IS DISTINCT FROM s.section_id  THEN 'section'
        WHEN s.proprietaire_poste IS DISTINCT FROM 'lieutenant' THEN 'proprietaire'
        WHEN s.statut IS DISTINCT FROM 'actif' THEN 'statut'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div
    FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div),
    'manquants', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'absent_du_socle'),
    'surnumeraires', (SELECT count(*) FROM jsonb_array_elements(v_div) d
                   WHERE d->>'divergence' = 'surnumeraire_dans_le_socle'),
    'details', v_div);
END; $fn$;

-- -------------------------------------------------------------------------------------
-- 3. ROLLBACK. Supprime UNIQUEMENT les lignes issues de cette copie.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_rollback_soldats(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_avant integer; v_apres integer; v_autres_avant integer; v_autres_apres integer;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  SELECT count(*) INTO v_avant FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_autres_avant FROM public.pnj_membres WHERE id NOT LIKE p_compagnie || '-%';
  DELETE FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_apres FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  SELECT count(*) INTO v_autres_apres FROM public.pnj_membres WHERE id NOT LIKE p_compagnie || '-%';
  RETURN jsonb_build_object('ok', v_apres = 0 AND v_autres_avant = v_autres_apres,
    'supprimes', v_avant - v_apres, 'restants_compagnie', v_apres,
    'autres_familles_avant', v_autres_avant, 'autres_familles_apres', v_autres_apres,
    'metier_orphelin', (SELECT count(*) FROM public.pnj_soldats_metier sm
                         WHERE NOT EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.id = sm.pnj_id)));
END; $fn$;

-- -------------------------------------------------------------------------------------
-- 4. TABLE METIER MILITAIRE -- l'entrainement ne monte JAMAIS dans le socle.
-- -------------------------------------------------------------------------------------
-- CREATE TABLE public.pnj_soldats_metier (
--   pnj_id     text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
--   matricule  text NOT NULL,
--   section_id text NULL,          -- NULL = en reserve
--   en_reserve boolean NOT NULL,
--   arme       text NULL,
--   formation  jsonb NOT NULL DEFAULT '{}'::jsonb,  -- 4 axes militaires, metier pur
--   CONSTRAINT soldat_reserve_coherente CHECK (en_reserve = (section_id IS NULL)));
-- CREATE UNIQUE INDEX idx_pnj_soldats_matricule ON public.pnj_soldats_metier(matricule);

-- =====================================================================================
-- 5. DOUBLE ECRITURE -- INVENTAIRE DES 22 FONCTIONS TOUCHANT UN AXE GENERIQUE
--
-- 44 fonctions serveur lisent compagnies_militaires. 22 seulement touchent un axe
-- generique (chef, position, PA) ; les 22 autres (candidatures, grades, armurerie de
-- compagnie, equipement, desertions, services) ne sont PAS concernees.
-- Sur ces 22 : 8 sont en LECTURE SEULE, 14 ECRIVENT.
--
-- >>> LES 8 LECTURES : rien a doubler. Elles basculeront leur SOURCE au moment du cutover,
--     et c'est la que la logique se SIMPLIFIE : la duplication OR/EXISTS disparait au profit
--     de pnj_position_effective(). A basculer EN PREMIER, aucun risque d'ecriture.
--   agent_garde_observer ............... position          (serveur seul)
--   militaire_bataille_combattants ..... pa                (serveur seul)
--   militaire_bataille_engager ......... chef + position    (client)
--   militaire_bataille_recruter ........ chef + pos + pa    (serveur seul)
--   militaire_detachement_ici .......... chef + position    (client)   <- la plus visible
--   militaire_entree_zone .............. chef + position    (client)
--   militaire_observer ................. position           (client)
--   mutinerie_camps_presents ........... chef + pos + pa    (client)
--
-- >>> LES 14 ECRITURES : chacune doit, pendant la phase miroir, reussir d'abord sur le blob
--     selon la regle actuelle, PUIS ecrire l'equivalent dans le socle, dans LA MEME
--     transaction -- ce qui est possible ici, les deux cibles etant dans la meme base : un
--     echec du miroir provoque donc le rollback global, et il n'y a pas de fail-closed a
--     inventer. La verification de coherence est le comparateur, appele en fin de transaction
--     sur la compagnie touchee.
--   militaire_affecter_leader .......... chef              -> miroir leader_pj
--   militaire_deposer_soldats .......... chef + position   -> miroir leader NULL + triade
--   militaire_recuperer_soldats ........ chef + position   -> miroir leader + triade NULL
--   militaire_lien_operationnel_rompre . chef + position   -> miroir (serveur seul, trigger)
--   militaire_bataille_decrocher_groupe  chef + position   -> miroir (serveur seul)
--   militaire_reposer_section .......... chef + pos + pa   -> miroir pa (recuperation metier)
--   militaire_ordre_collectif .......... chef + pa         -> miroir pa (ration/bivouac)
--   militaire_entrainer_section ........ pa                -> miroir pa (-6 par soldat)
--   militaire_soldat_pa_fixer .......... pa                -> miroir pa (combat, serveur seul)
--   militaire_mutinerie_declencher ..... pa                -> miroir pa
--   militaire_requisition_civile ....... pa                -> miroir pa
--   militaire_presentation_affectation . pa                -> miroir pa
--   militaire_armurerie_transfert ...... pa                -> miroir pa
--   militaire_compagnie_creer .......... chef + pos + pa   -> ecrit directement les DEUX
--                                                            (une compagnie neuve n'a pas
--                                                             de blob prealable a mirroiter)
--
-- AUCUNE ECRITURE MILITAIRE OUBLIEE : la liste ci-dessus est l'intersection exacte, calculee
-- en base, entre « fonction citant compagnies_militaires » et « fonction citant leaderCourant,
-- buildingId, roomId ou 'pa' ». Toute nouvelle fonction militaire devra etre confrontee a la
-- meme requete avant activation du miroir.
-- =====================================================================================
