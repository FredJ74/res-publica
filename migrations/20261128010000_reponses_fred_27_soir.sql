-- Mission du 28/11/2026 (nuit, Claude), étape 2 — réponses de Fred aux questions du compte rendu du 27/11 (soir).
--   1. Prêt « travaux » : exige un permis de construire, vrai (arrêté d'accord de la mairie, document_urbanisme_acceptation
--      enregistré dans dossiers_urbanisme) ou faux (« Falsifier un document » → faux permis, identique au vrai). Un permis
--      ne sert qu'à un prêt ; un faux est retiré de l'inventaire à l'usage (un faux réussi vaut un vrai pour un seul usage ;
--      la détection reste celle du faux, à la fabrication). Le prêt « consommation » ne change pas. Pas de faux compromis.
--   3. « Produire une fuite » : 2 PA.
--   4. Renseignement : le détenu reste en salle d'interrogatoire ; on l'interroge tant qu'il a plus de 1 PA.
--   5. Trace « mauvais traitement » : 30 jours (les autres traces restent à 8 jours).
--   6. Transfert d'un détenu : tous les détenus sont transférables (QHS, goulag, salle d'interrogatoire compris) ; prison
--      d'arrivée : capitale du pays d'origine.
--   7. Cartons d'invitation : seul l'ambassadeur du pays qui a réservé la Grande Salle les envoie ; 40 au plus par envoi.
--   8. Accessoire personnalisé : le joueur ne perd que la popularité réellement gagnée (gain effectif stocké sur l'objet).
--
-- Contrôles en lecture après application :
--   SELECT position('pret_travaux_permis_v1' in pg_get_functiondef('public.pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)'::regprocedure)) > 0;
--   SELECT pa FROM public.ordres_couts WHERE fn = 'fuite_info';                                            -- 2
--   SELECT position('renseignement_interrogatoires_repetes_v1' in pg_get_functiondef('public.renseignement_interroger(text)'::regprocedure)) > 0;
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $$;

-- ===================================================================== 1. Prêt « travaux » et permis de construire
CREATE TABLE IF NOT EXISTS public.faux_permis_emis (id text PRIMARY KEY, auteur text NOT NULL, cree_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.prets_permis_utilises (permis_id text PRIMARY KEY, emprunteur text NOT NULL, pret_reference text NOT NULL,
  faux boolean NOT NULL DEFAULT false, utilise_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.faux_permis_emis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prets_permis_utilises ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.faux_permis_emis, public.prets_permis_utilises FROM PUBLIC, anon, authenticated;

-- Choisit le permis présenté à la banque : d'abord un vrai permis non encore utilisé, sinon un faux (retiré de l'inventaire).
CREATE OR REPLACE FUNCTION public.pret_travaux_permis_consommer_interne(p_nom text, p_reference text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; v_id text; v_pos integer;
BEGIN
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT e ->> 'id' INTO v_id FROM jsonb_array_elements(v_inv) e
   WHERE e ->> 'type' = 'document_urbanisme_acceptation'
     AND EXISTS (SELECT 1 FROM public.dossiers_urbanisme u WHERE u.id = e ->> 'id' AND u.type_evenement = 'acceptation')
     AND NOT EXISTS (SELECT 1 FROM public.prets_permis_utilises x WHERE x.permis_id = e ->> 'id')
   LIMIT 1;
  IF v_id IS NOT NULL THEN
    INSERT INTO public.prets_permis_utilises (permis_id, emprunteur, pret_reference) VALUES (v_id, p_nom, p_reference);
    RETURN jsonb_build_object('permis', v_id, 'faux', false);
  END IF;
  SELECT (o - 1)::integer, e ->> 'id' INTO v_pos, v_id FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
   WHERE e ->> 'type' = 'document_urbanisme_acceptation'
     AND EXISTS (SELECT 1 FROM public.faux_permis_emis f WHERE f.id = e ->> 'id')
     AND NOT EXISTS (SELECT 1 FROM public.prets_permis_utilises x WHERE x.permis_id = e ->> 'id')
   ORDER BY o LIMIT 1;
  IF v_id IS NULL THEN RAISE EXCEPTION 'permis_construire_requis'; END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer_position(v_inv, v_pos) WHERE name = p_nom;
  INSERT INTO public.prets_permis_utilises (permis_id, emprunteur, pret_reference, faux) VALUES (v_id, p_nom, p_reference, true);
  RETURN jsonb_build_object('permis', v_id, 'faux', true);
END $$;
REVOKE ALL ON FUNCTION public.pret_travaux_permis_consommer_interne(text, text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)'::regprocedure,
  ' IF EXISTS(SELECT 1 FROM public.prets WHERE emprunteur=p_nom AND type_pret=p_type_pret AND statut=''en_cours'')',
  ' IF p_type_pret=''travaux'' THEN PERFORM public.pret_travaux_permis_consommer_interne(p_nom,p_reference); END IF; /* pret_travaux_permis_v1 (Fred, 28/11/2026) */
 IF EXISTS(SELECT 1 FROM public.prets WHERE emprunteur=p_nom AND type_pret=p_type_pret AND statut=''en_cours'')',
  'pret_travaux_permis_v1');

-- Faux permis de construire : retour dans la liste des documents falsifiables, identique à un vrai arrêté d'accord.
CREATE OR REPLACE FUNCTION public.faux_document_objet_interne(p_doc text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c jsonb; d date;
BEGIN
  -- faux_documents_effectifs_v1 (Fred, 27/11/2026) ; faux permis de construire rétabli le 28/11/2026 (prêt « travaux »).
  IF split_part(p_doc, '|', 1) = 'faux_laissez_passer' THEN
    RETURN CASE WHEN public.faux_lp_parametres_interne(p_doc) IS NOT NULL THEN jsonb_build_object(
      'name', 'Laissez-passer — ' || public.crim_lp_libelle_interne(public.faux_lp_parametres_interne(p_doc) ->> 'lieu'),
      'icon', 'ti-id-badge', 'desc', 'Laissez-passer') END;
  END IF;
  IF p_doc = 'faux_permis' THEN
    RETURN jsonb_build_object('name', 'Arrêté d’accord de permis', 'icon', 'ti-file-certificate', 'legal', true,
      'type', 'document_urbanisme_acceptation', 'desc', 'Votre permis de construire est accordé.',
      'documentUrbanisme', jsonb_build_object('nature', 'acceptation'));
  END IF;
  c := public.faux_carton_parametres_interne(p_doc);
  IF c IS NOT NULL THEN
    BEGIN d := (c ->> 'jour')::date; EXCEPTION WHEN others THEN RETURN NULL; END;
    RETURN public.pavillon_carton_objet_interne(d, c ->> 'nom', NULL);
  END IF;
  RETURN NULL; /* crim_faux_lp_v2 */
END $function$;

DROP FUNCTION IF EXISTS public.faux_document_final_interne(jsonb, text, text);
CREATE FUNCTION public.faux_document_final_interne(p_doc_objet jsonb, p_doc text, p_auteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text;
BEGIN
  IF public.faux_lp_parametres_interne(p_doc) IS NOT NULL THEN
    RETURN public.crim_lp_emettre_interne(public.faux_lp_parametres_interne(p_doc) ->> 'lieu', public.faux_lp_parametres_interne(p_doc) ->> 'pays',
      coalesce(public.faux_lp_parametres_interne(p_doc) ->> 'nom', p_auteur), p_auteur, true);
  END IF;
  -- Faux carton d'invitation : identique à un vrai (même type, même forme), seul l'identifiant interne diffère.
  IF public.faux_carton_parametres_interne(p_doc) IS NOT NULL THEN
    RETURN jsonb_set(p_doc_objet, '{carton,id}', to_jsonb('faux-' || replace(gen_random_uuid()::text, '-', '')));
  END IF;
  -- Faux permis : même forme qu'un vrai arrêté ; la banque le reconnaît par le registre faux_permis_emis (jamais visible).
  IF p_doc = 'faux_permis' THEN
    v_id := 'urb-acceptation-' || replace(gen_random_uuid()::text, '-', '');
    INSERT INTO public.faux_permis_emis (id, auteur) VALUES (v_id, p_auteur);
    RETURN p_doc_objet || jsonb_build_object('id', v_id);
  END IF;
  RETURN p_doc_objet || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
         'type', 'document_falsifie', 'docId', p_doc, 'legal', false);
END $function$;
REVOKE ALL ON FUNCTION public.faux_document_final_interne(jsonb, text, text) FROM PUBLIC, anon, authenticated;

-- ===================================================================== 3. Fuite à 2 PA
UPDATE public.ordres_couts SET pa = 2, cost = 0 WHERE fn = 'fuite_info';
SELECT pg_temp.rp_remplacer('public.archives_gouv_fuite(text)'::regprocedure,
  'public.payer_ordre(a, ''fuite_info'', 3, 0)', 'public.payer_ordre(a, ''fuite_info'', 2, 0) /* fuite_deux_pa_v1 */', 'fuite_deux_pa_v1');

-- ===================================================================== 4. Interrogatoires répétés au Renseignement
SELECT pg_temp.rp_remplacer('public.renseignement_interroger(text)'::regprocedure,
  'SET pa = v_pa, est_emprisonne = est_emprisonne - ''interrogatoire'',
         current_building = CASE WHEN current_city = ''capitale'' THEN ''commissariat'' ELSE ''commissariat-local'' END,
         current_room = CASE WHEN current_city = ''capitale'' THEN ''prison'' ELSE ''geoles'' END,
         current_street = NULL, updated_at = clock_timestamp()',
  'SET pa = v_pa, updated_at = clock_timestamp() /* renseignement_interrogatoires_repetes_v1 (Fred, 28/11/2026) : il reste en salle */',
  'renseignement_interrogatoires_repetes_v1');
SELECT pg_temp.rp_remplacer('public.renseignement_interroger(text)'::regprocedure,
  '  PERFORM public.mail_systeme_poser_interne(''Direction du Renseignement'', d.name, ''Fin de l''''interrogatoire'',
    ''Vous avez été conduit en cellule pour la suite de votre peine.'');
', '', 'Fin de l''''interrogatoire_retire');

-- ===================================================================== 5. Mauvais traitement : 30 jours
CREATE OR REPLACE FUNCTION public.interrogatoire_mauvais_traitement_interne(p_lieu text, p_interrogateur text,
  p_detenu text, p_pays text, p_ville text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour integer := coalesce(public.jour_de_jeu_pays(p_pays), 1);
BEGIN
  -- mauvais_traitement_trente_jours_v1 (Fred, 28/11/2026) : cette trace seule dure 30 jours.
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES ('trace-mauvais-traitement-' || replace(gen_random_uuid()::text, '-', ''), p_interrogateur, p_detenu,
          'mauvais_traitement', p_pays, coalesce(p_ville, 'capitale'), v_jour, v_jour + 30, false);
  UPDATE public.personnages_donnees
     SET historique_crimes = (CASE WHEN jsonb_typeof(historique_crimes) = 'array' THEN historique_crimes ELSE '[]'::jsonb END)
       || jsonb_build_array(jsonb_build_object('id', 'crime-' || replace(gen_random_uuid()::text, '-', ''),
            'acte', 'mauvais_traitement', 'cible', p_detenu, 'jour', coalesce(day, 1), 'expireJour', coalesce(day, 1) + 30,
            'origine', 'serveur',
            'expireTs', to_char((now() + interval '30 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
   WHERE name = p_interrogateur;
  PERFORM public.mail_systeme_poser_interne(CASE p_lieu WHEN 'goulag' THEN 'Camp de rééducation de Sovarka'
      WHEN 'qhs' THEN 'Quartier Haute Sécurité' ELSE 'Direction du Renseignement' END, p_detenu,
    'Vous avez été interrogé', 'Vous avez été interrogé par ' || p_interrogateur || CASE p_lieu
      WHEN 'goulag' THEN ' au camp de rééducation.' WHEN 'qhs' THEN ' en salle d''interrogatoire du Quartier Haute Sécurité.'
      ELSE ' en salle d''interrogatoire de la Direction du Renseignement.' END);
END $$;
REVOKE ALL ON FUNCTION public.interrogatoire_mauvais_traitement_interne(text, text, text, text, text) FROM PUBLIC, anon, authenticated;

-- ===================================================================== 6. Transfert : tous les détenus
CREATE OR REPLACE FUNCTION public.transfert_detenu_refus_interne(p_detenu text, p_empire text, p_hote text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_det record;
BEGIN
  -- transfert_tous_detenus_v1 (Fred, 28/11/2026) : QHS, goulag et salle d'interrogatoire compris.
  IF public.personnage_nationalite(p_detenu) IS DISTINCT FROM p_empire THEN RETURN 'pas_compatriote'; END IF;
  SELECT * INTO v_det FROM public.detention_active(p_detenu);
  IF v_det.id IS NULL OR v_det.country IS DISTINCT FROM p_hote THEN RETURN 'pas_detenu_ici'; END IF;
  RETURN NULL;
END $$;

-- Lève les régimes particuliers avant le transfert vers une prison ordinaire de la capitale du pays d'origine.
CREATE OR REPLACE FUNCTION public.transfert_detenu_regimes_lever_interne(p_detenu text, p_detention text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record; v_jour integer;
BEGIN
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = p_detenu;
  -- QHS
  UPDATE public.detentions SET qhs = false WHERE id = p_detention AND qhs;
  UPDATE public.prisonniers_qhs SET statut = 'transfere' WHERE data ->> 'nom' = p_detenu AND coalesce(statut, '') <> 'transfere';
  UPDATE public.personnages_donnees SET detention_qhs = jsonb_build_object('enQHS', false)
   WHERE name = p_detenu AND jsonb_typeof(detention_qhs) = 'object' AND coalesce((detention_qhs ->> 'enQHS')::boolean, false);
  -- Goulag : la peine restante (compteur de sommeils) devient une fin de peine au calendrier du personnage.
  SELECT * INTO g FROM public.sovarka_goulag_registre WHERE detention_id = p_detention AND liberation_le IS NULL FOR UPDATE;
  IF FOUND THEN
    UPDATE public.detentions SET jour_fin = v_jour + greatest(0, coalesce(g.jours_restants, 0)) WHERE id = p_detention;
    UPDATE public.sovarka_goulag_registre SET liberation_le = now() WHERE detention_id = p_detention;
  END IF;
  -- Salle d'interrogatoire
  UPDATE public.personnages_donnees SET est_emprisonne = est_emprisonne - 'interrogatoire'
   WHERE name = p_detenu AND jsonb_typeof(est_emprisonne) = 'object' AND est_emprisonne ? 'interrogatoire';
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_regimes_lever_interne(text, text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.transfert_detenu_decider(bigint,text)'::regprocedure,
  'RETURN jsonb_build_object(''ok'', false, ''raison'', ''prison_non_referencee''); END IF;',
  'RETURN jsonb_build_object(''ok'', false, ''raison'', ''prison_non_referencee''); END IF;
  PERFORM public.transfert_detenu_regimes_lever_interne(t.detenu, v_det.id); /* transfert_tous_detenus_v1 */',
  'transfert_tous_detenus_v1');

-- ===================================================================== 7. Cartons : l'ambassadeur seulement
CREATE OR REPLACE FUNCTION public.pavillon_cartons_ambassadeur_interne(p_nom text, p_empire text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                  WHERE a.pays_hote = 'soviet' AND a.empire = p_empire AND a.data ->> 'ambassadeur' = p_nom)
$$;
REVOKE ALL ON FUNCTION public.pavillon_cartons_ambassadeur_interne(text, text) FROM PUBLIC, anon, authenticated;
SELECT pg_temp.rp_remplacer('public.pavillon_cartons_etat()'::regprocedure,
  '  IF NOT FOUND OR r.acteur IS DISTINCT FROM moi THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''reception_non_reservee''); END IF;',
  '  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''reception_non_reservee''); END IF;
  -- cartons_ambassadeur_v1 (Fred, 28/11/2026) : seul l''ambassadeur du pays qui a réservé envoie les cartons.
  IF NOT public.pavillon_cartons_ambassadeur_interne(moi, r.pays_payeur) THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''reserve_ambassadeur''); END IF;',
  'cartons_ambassadeur_v1');
SELECT pg_temp.rp_remplacer('public.pavillon_cartons_envoyer(text[])'::regprocedure,
  '  IF NOT FOUND OR r.acteur IS DISTINCT FROM moi THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''reception_non_reservee''); END IF;',
  '  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''reception_non_reservee''); END IF;
  -- cartons_ambassadeur_v1 (Fred, 28/11/2026) : seul l''ambassadeur du pays qui a réservé envoie les cartons.
  IF NOT public.pavillon_cartons_ambassadeur_interne(moi, r.pays_payeur) THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''reserve_ambassadeur''); END IF;',
  'cartons_ambassadeur_v1');

-- ===================================================================== 8. Accessoire : perte égale au gain réel
CREATE OR REPLACE FUNCTION public.accessoires_revetus_popularite_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_res jsonb; v_pop numeric; v_inv jsonb; v_old jsonb; i integer; e jsonb; v_id text; v_gain integer; o jsonb;
BEGIN
  -- accessoire_gain_effectif_v1 (Fred, 28/11/2026) : le gain réellement obtenu (plafond 100) est stocké sur l'objet
  -- (bonus_pop_applique) et seul ce gain est repris quand l'objet n'est plus revêtu ou quitte l'inventaire.
  v_res := CASE WHEN jsonb_typeof(NEW.resources) = 'object' THEN NEW.resources ELSE '{}'::jsonb END;
  v_pop := coalesce((v_res ->> 'pop')::numeric, 0);
  v_inv := CASE WHEN jsonb_typeof(NEW.inventory) = 'array' THEN NEW.inventory ELSE '[]'::jsonb END;
  v_old := CASE WHEN jsonb_typeof(OLD.inventory) = 'array' THEN OLD.inventory ELSE '[]'::jsonb END;
  -- Reprises : objets revêtus avec un gain dans l'ancien inventaire, qui ne le sont plus (ou ont disparu).
  FOR o IN SELECT x FROM jsonb_array_elements(v_old) x
            WHERE x ->> 'type' = 'accessoire_club_perso' AND public.crim_porte_ligne_interne(x, OLD.name) AND x ? 'bonus_pop_applique' LOOP
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) y WHERE y ->> 'accessoire_id' = o ->> 'accessoire_id'
                    AND public.crim_porte_ligne_interne(y, NEW.name)) THEN
      v_pop := v_pop - coalesce((o ->> 'bonus_pop_applique')::numeric, 0);
    END IF;
  END LOOP;
  -- Nouvel inventaire : un objet non revêtu perd sa marque ; un objet revêtu sans marque reçoit son gain réel.
  FOR i IN 0 .. jsonb_array_length(v_inv) - 1 LOOP
    e := v_inv -> i;
    CONTINUE WHEN e ->> 'type' IS DISTINCT FROM 'accessoire_club_perso';
    IF public.crim_porte_ligne_interne(e, NEW.name) THEN
      IF NOT (e ? 'bonus_pop_applique') OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_old) y
             WHERE y ->> 'accessoire_id' = e ->> 'accessoire_id' AND public.crim_porte_ligne_interne(y, OLD.name)) THEN
        v_gain := greatest(0, least(coalesce((e ->> 'bonus_pop_revetu')::integer, 0), (100 - greatest(0, least(100, v_pop)))::integer));
        v_pop := v_pop + v_gain;
        v_inv := jsonb_set(v_inv, ARRAY[i::text], e || jsonb_build_object('bonus_pop_applique', v_gain));
      END IF;
    ELSIF e ? 'bonus_pop_applique' THEN
      v_inv := jsonb_set(v_inv, ARRAY[i::text], e - 'bonus_pop_applique');
    END IF;
  END LOOP;
  IF v_inv IS DISTINCT FROM NEW.inventory THEN NEW.inventory := v_inv; END IF;
  IF v_pop IS DISTINCT FROM coalesce((v_res ->> 'pop')::numeric, 0) THEN
    NEW.resources := v_res || jsonb_build_object('pop', greatest(0, least(100, v_pop)));
  END IF;
  RETURN NEW;
END $$;

COMMIT;
