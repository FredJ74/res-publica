-- CRIMINALITÉ — LOT 6 : JUSTICE (GAME-DESIGN-CRIMINALITE.md §§ 3 et 14 ; Fred, 18-19/11/2026).
-- • Plainte contre X et enquête : une plainte contre X déposée par la victime (ou par l'employeur d'un PNJ, déjà créée par la
--   résolution commune) est rattachée à son affaire crim_affaires. Le commissaire de la ville où l'acte a eu lieu « Enquête »
--   (2 PA, une tentative par jour et par plainte) : départ à la moitié du plafond d'identification (5 % après réussite, 15 %
--   après une tentative ratée), bonus jusqu'au plafond (trace, rumeurs vraies visant le coupable, informateur du commissaire,
--   traces d'achat pour le cambriolage). Réussite : coupable démasqué, peine d'office DOUBLÉE, avis de recherche ; la plainte
--   vise désormais le coupable (dommages et intérêts au procès). Première enquête ratée (une seule fois par plainte) :
--   « Le commissaire X est sur vos traces… », −20 DIS, −15 moral. Tous les actes des lots 2 à 5 sont enquêtables.
-- • Plus aucune enquête automatique : minuit_decouverte_crimes est neutralisée.
-- • Peines : nomenclature unique (alias), fin des catégories 4 / 8 / 30 j (délit 1 j, crime 2 j), baremes de Républia repris
--   par les autres empires (paramètres peine_jours_<acte>_<empire> pour les différencier), durées en dur retirées (garde à vue,
--   évasion, rébellion, résistance, convocation). Peine d'office = jugement d'office exécutable par la police (simple sur le
--   moment, doublée si démasqué plus tard). Seuil du procès 4 jours : au-delà, 4 jours d'office puis un procès décide d'un
--   complément. Juge : ±50 % autour de la référence (de la somme pour un procès de seuil), liberté totale sous l'état d'urgence.
-- • État d'urgence : 7 jours, renouvelable par le Président (3 PA et la perte de POP habituelle), levé seul à échéance.
-- • Cellule : rébellion réussie = +1 j (barème) et grilles abîmées (4-10) ; matée = PV −25, DIS −15, +4 j d'office, plus de
--   QHS automatique, aucun dégât. Grilles abîmées = bonus d'évasion pour la cellule (dégâts cumulés, plafond +25 %), réparées
--   d'un tiers par nuit pour 100 FR pris sur la caisse du commissariat (pas d'argent, pas de réparation).
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia) ──────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('seuil_proces_jours', 4), ('juge_modulation_pct', 50), ('juge_urgence_max_jours', 365), ('etat_urgence_jours', 7),
  ('enquete_pa', 2), ('enquete_echec_dis', 20), ('enquete_echec_moral', 15),
  ('grilles_bonus_max', 25), ('grilles_reparation_cout', 100), ('grilles_reparation_tiers', 3),
  ('peine_jours_garde_a_vue_republic', 2), ('peine_jours_evasion_echouee_republic', 1),
  ('peine_jours_rebellion_matee_republic', 4), ('peine_jours_resistance_arrestation_republic', 2)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('enqueter_plainte', 2, 0) ON CONFLICT DO NOTHING;

INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note) VALUES ('crim_grilles_reparation', false,
  'Réparation nocturne des grilles d''une cellule de commissariat (criminalité lot 6) : 100 FR débités de la caisse du commissariat '
  || 'et un tiers des dégâts réparé. Un rejeu débiterait une seconde fois et réparerait deux tiers. Un sujet par cellule (niveaux_prison.id).')
ON CONFLICT (mecanisme) DO NOTHING;

-- ── Barème unique (miroir de plateau-core.js, régénéré par outils/generateurs/generer_infractions.py) ─────────────
INSERT INTO public.infractions_categories (id, libelle, jours_reference, amende_reference) VALUES
  ('crime', 'Crime', 2, 5000),
  ('crime_etat', 'Crime d''Etat', 2, 0),
  ('delit', 'Delit', 1, 500),
  ('delit_grave', 'Delit grave', 1, 1500),
  ('delit_mineur', 'Delit mineur', 1, 500)
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle, jours_reference = EXCLUDED.jours_reference, amende_reference = EXCLUDED.amende_reference;

INSERT INTO public.infractions (id, libelle, categorie, jours_reference, amende_reference, detect_rate, bareme_propre, detectable) VALUES
  ('achat_arme_illegal', 'Achat d''arme non enregistree', 'delit', 1, 500, NULL, true, true),
  ('acheter_arme_illegale', 'Achat d''arme non enregistree', 'delit', 1, 500, 20, true, true),
  ('acheter_bombe_illegale', 'Achat d''explosifs non enregistres', 'crime', 2, 2000, 55, true, true),
  ('arreter', 'Delit grave', 'delit_grave', 1, 1500, 40, false, true),
  ('assassinat', 'Assassinat', 'crime', 2, 1500, NULL, true, true),
  ('assassiner_arme', 'Assassinat', 'crime', 2, 1500, 40, true, true),
  ('assassiner_feu', 'Assassinat', 'crime', 2, 1500, 60, true, true),
  ('assassiner_mains', 'Assassinat', 'crime', 2, 1500, 30, true, true),
  ('blanchiment', 'Delit grave', 'delit_grave', 1, 1500, 35, false, true),
  ('contrebande_port', 'Delit mineur', 'delit_mineur', 1, 500, 20, false, true),
  ('corrompre_douanier', 'Delit mineur', 'delit_mineur', 1, 500, 35, false, true),
  ('corrompre_fonct', 'Corruption de fonctionnaire', 'delit', 1, 1000, 30, true, true),
  ('corrompre_gardien', 'Delit mineur', 'delit_mineur', 1, 500, 35, false, true),
  ('corrompre_journaliste', 'Delit mineur', 'delit_mineur', 1, 500, 25, false, true),
  ('corrompre_juge', 'Delit grave', 'delit_grave', 1, 1500, 40, false, true),
  ('corrompre_police', 'Delit mineur', 'delit_mineur', 1, 500, 35, false, true),
  ('corruption_fonctionnaire', 'Corruption de fonctionnaire', 'delit', 1, 1000, NULL, true, true),
  ('diffamation', 'Diffamation', 'delit', 1, 500, NULL, true, true),
  ('effraction', 'Effraction', 'delit', 1, 500, NULL, true, true),
  ('empoisonnement', 'Empoisonnement', 'crime', 2, 2000, 25, true, true),
  ('fabriquer_bombe', 'Crime', 'crime', 2, 5000, 60, false, true),
  ('fabriquer_scandale', 'Delit grave', 'delit_grave', 1, 1500, 45, false, true),
  ('falsifier_document', 'Delit grave', 'delit_grave', 1, 1500, 40, false, true),
  ('fausse_rumeur', 'Delit mineur', 'delit_mineur', 1, 500, 35, false, true),
  ('fuite_info', 'Delit grave', 'delit_grave', 1, 1500, 40, false, true),
  ('hooliganisme', 'Trouble a l''ordre public (hooliganisme)', 'delit', 1, 500, NULL, true, true),
  ('imprimer_tracts_calomnieux', 'Delit mineur', 'delit_mineur', 1, 500, 30, false, true),
  ('incendier', 'Incendie volontaire', 'crime', 2, 2000, 70, true, true),
  ('justification_rejetee', 'Justification rejetée (marchandise interdite)', NULL, 1, 0, NULL, true, true),
  ('non_presentation_convocation', 'Non-présentation à convocation', 'delit', 2, 0, NULL, true, true),
  ('possession_illegale_douane', 'Possession d''objets prohibes au controle douanier', 'delit', 1, 500, NULL, true, true),
  ('se_rebeller', 'Delit mineur', 'delit_mineur', 1, 500, 60, false, true),
  ('societe_ecran', 'Delit mineur', 'delit_mineur', 1, 500, 25, false, true),
  ('tentative_assassinat', 'Tentative d''assassinat', 'crime', 2, 1500, NULL, true, true),
  ('tentative_empoisonnement', 'Tentative d''empoisonnement', 'crime', 2, 2000, NULL, true, true),
  ('tentative_evasion', 'Crime', 'crime', 2, 5000, 90, false, true),
  ('utiliser_explosifs', 'Usage d''explosifs', 'crime', 2, 2000, 65, true, true),
  ('violation_couvre_feu', 'Violation du couvre-feu', 'delit', 1, 200, NULL, true, true),
  ('vol', 'Vol', 'delit_mineur', 1, 500, 30, true, true),
  ('vol_materiel_chantier', 'Delit mineur', 'delit_mineur', 1, 500, 30, false, true)
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle, categorie = EXCLUDED.categorie, jours_reference = EXCLUDED.jours_reference,
  amende_reference = EXCLUDED.amende_reference, detect_rate = EXCLUDED.detect_rate, bareme_propre = EXCLUDED.bareme_propre, detectable = EXCLUDED.detectable;

-- Une seule nomenclature : les alias se résolvent vers l'infraction canonique (infraction_canonique, crim_peine_jours_interne).
INSERT INTO public.infractions_alias (alias, canonique, note) VALUES
  ('acheter_arme_illegale', 'achat_arme_illegal', 'Criminalite lot 6 : une seule nomenclature (19/11/2026)'),
  ('assassiner_arme', 'assassinat', 'Criminalite lot 6 : une seule nomenclature (19/11/2026)'),
  ('assassiner_feu', 'assassinat', 'Criminalite lot 6 : une seule nomenclature (19/11/2026)'),
  ('assassiner_mains', 'assassinat', 'Criminalite lot 6 : une seule nomenclature (19/11/2026)'),
  ('corrompre_fonct', 'corruption_fonctionnaire', 'Criminalite lot 6 : une seule nomenclature (19/11/2026)'),
  ('meurtre', 'assassinat', 'Criminalite lot 6 : une seule nomenclature (19/11/2026)')
ON CONFLICT (alias) DO UPDATE SET canonique = EXCLUDED.canonique, note = EXCLUDED.note;

-- Sentinelle du miroir (les trois empreintes doivent concorder : générateur, sentinelle, infractions_empreinte_reelle()).
UPDATE public.infractions_empreinte SET empreinte = 'ac8ead42d4f8134e', pose_le = now() WHERE seul;

-- ── Résolution unique d'une peine : alias, paramètre de l'empire, paramètre de Républia, barème, catégorie ─────────
CREATE OR REPLACE FUNCTION public.crim_peine_jours_interne(p_acte text, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH c AS (SELECT coalesce((SELECT a.canonique FROM public.infractions_alias a WHERE a.alias = p_acte), p_acte) AS id)
  SELECT coalesce(
    (SELECT valeur FROM public.crim_parametres, c WHERE cle = 'peine_jours_' || c.id || '_' || coalesce(p_pays, 'republic')),
    (SELECT valeur FROM public.crim_parametres, c WHERE cle = 'peine_jours_' || c.id || '_republic'),
    (SELECT i.jours_reference FROM public.infractions i, c WHERE i.id = c.id),
    (SELECT a.peine_jours FROM public.actes_illegaux a, c WHERE a.fn = c.id),
    (SELECT k.jours_reference FROM public.actes_illegaux a JOIN public.infractions_categories k ON k.id = a.type, c WHERE a.fn = c.id),
    (SELECT k.jours_reference FROM public.infractions_categories k, c WHERE k.id = c.id))::integer;
$$;

-- Barème des arrestations : la même résolution, pour tous les empires (Républia par défaut).
CREATE OR REPLACE FUNCTION public.peine_acte_interne(p_acte text, p_pays text)
RETURNS TABLE(libelle text, jours integer) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id text := coalesce((SELECT a.canonique FROM public.infractions_alias a WHERE a.alias = p_acte), p_acte); /* crim_peine_unique_v1 */
BEGIN
  jours := public.crim_peine_jours_interne(p_acte, p_pays);
  libelle := coalesce((SELECT i.libelle FROM public.infractions i WHERE i.id = v_id),
                      (SELECT k.libelle FROM public.actes_illegaux a JOIN public.infractions_categories k ON k.id = a.type WHERE a.fn = v_id),
                      (SELECT k.libelle FROM public.infractions_categories k WHERE k.id = v_id));
  IF jours IS NULL THEN
    SELECT k.libelle, k.jours_reference INTO libelle, jours FROM public.infractions_categories k WHERE k.id = 'delit_mineur';
  END IF;
  libelle := coalesce(libelle, replace(p_acte, '_', ' '));
  RETURN NEXT;
END $$;

-- Ancienne résolution (découverte nocturne) alignée : même barème, doublement si démasqué pour toute peine.
CREATE OR REPLACE FUNCTION public.crime_peine_interne(p_acte text, p_demasque boolean)
RETURNS TABLE(jours integer, amende integer) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH c AS (SELECT coalesce((SELECT a.canonique FROM public.infractions_alias a WHERE a.alias = p_acte), p_acte) AS id)
  SELECT (coalesce(public.crim_peine_jours_interne(p_acte, NULL), 1) * CASE WHEN p_demasque THEN 2 ELSE 1 END)::integer,
         (coalesce((SELECT i.amende_reference FROM public.infractions i, c WHERE i.id = c.id),
                   (SELECT a.amende FROM public.actes_illegaux a, c WHERE a.fn = c.id), 500) * CASE WHEN p_demasque THEN 2 ELSE 1 END)::integer;
$$;

-- § 3 : plus aucune enquête automatique. La tâche de minuit ne découvre plus rien (le cron l'appelle encore, sans effet).
CREATE OR REPLACE FUNCTION public.minuit_decouverte_crimes()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  RETURN jsonb_build_object('ok', true, 'decouvertes', 0, 'desactivee', 'criminalite_lot6_pas_d_enquete_automatique');
END $$;

-- ── Peine d'office : un jugement d'office, exécutable par la police (chasse, patrouille), simple ou doublé ────────
CREATE OR REPLACE FUNCTION public.crim_peine_office_interne(p_auteur text, p_acte text, p_demasque boolean, p_affaire bigint, p_ville text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pays text; v_ville text; v_jours integer; v_inf text; v_lib text; v_id text; v_jour integer;
BEGIN
  SELECT country, coalesce(p_ville, current_city, 'capitale') INTO v_pays, v_ville FROM public.personnages_donnees WHERE name = p_auteur;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_jours := coalesce(public.crim_peine_jours_interne(p_acte, v_pays), 1) * CASE WHEN p_demasque THEN 2 ELSE 1 END;
  v_inf := coalesce(public.infraction_canonique(p_acte), p_acte);
  v_lib := coalesce((SELECT libelle FROM public.infractions WHERE id = v_inf), replace(p_acte, '_', ' '))
           || CASE WHEN p_demasque THEN ' (démasqué par enquête)' ELSE '' END;
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_id := 'office-' || coalesce(p_affaire::text, md5(p_auteur || p_acte || clock_timestamp()::text))
          || CASE WHEN p_demasque THEN '-demasque' ELSE '' END;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_id, v_pays, v_ville, p_auteur, v_lib, v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END, 'Peine d''office', v_jour, false,
    jsonb_build_object('id', v_id, 'verdict', 'condamnation', 'instance', 'office', 'source', 'peine_office', 'infraction', v_inf,
      'acte', p_acte, 'jours', v_jours, 'demasque', p_demasque, 'affaire', p_affaire, 'ville_condamnation', v_ville,
      'issue_judiciaire', 'Peine d''office : ' || v_jours || ' jour(s)',
      'motifs', jsonb_build_array(jsonb_build_object('type', v_lib, 'infraction', v_inf, 'acte', p_acte, 'jours', v_jours,
        'city', v_ville, 'source', 'peine_office', 'demasque', p_demasque,
        'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))))
  ON CONFLICT (id) DO NOTHING;
  RETURN v_jours;
END $$;

-- Identification sur le moment (lots 2 à 5) : avis de recherche ET jugement d'office simple.
CREATE OR REPLACE FUNCTION public.crim_identifier_interne(p_auteur text, p_acte_peine text, p_type text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.crime_rechercher_interne(p_auteur, p_acte_peine, coalesce(p_type, 'crime'));
  RETURN public.crim_peine_office_interne(p_auteur, p_acte_peine, false, NULL, NULL); /* crim_office_v1 */
END $$;

-- Une peine d'office exécutée efface l'avis de recherche correspondant (plus « recherché » après avoir purgé).
CREATE OR REPLACE FUNCTION public.crim_office_executee_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NEW.executee AND NOT coalesce(OLD.executee, false) AND NEW.data ->> 'source' = 'peine_office' THEN
    PERFORM set_config('rp.recherche_interne', 'on', true);
    UPDATE public.personnages_donnees d
       SET recherche = coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(d.recherche) WITH ORDINALITY x(e, o)
                                  WHERE (e ->> 'acte') IS DISTINCT FROM (NEW.data ->> 'acte')), '[]'::jsonb)
     WHERE d.name = NEW.accuse AND jsonb_typeof(d.recherche) = 'array';
    PERFORM set_config('rp.recherche_interne', '', true);
  END IF;
  RETURN NEW;
END $$;
CREATE OR REPLACE TRIGGER crim_office_executee AFTER UPDATE OF executee ON public.jugements
  FOR EACH ROW EXECUTE FUNCTION public.crim_office_executee_trg();

-- ── Seuil du procès (4 jours) : au-delà, 4 jours d'office et un procès pour un éventuel complément ───────────────
-- p_auto_deja : jours automatiques déjà portés par la détention en cours. Les motifs « jugement » ne comptent pas.
CREATE OR REPLACE FUNCTION public.crim_seuil_proces_interne(p_nom text, p_motifs jsonb, p_auto_deja integer, p_pays text, p_ville text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_seuil integer := public.crim_param_interne('seuil_proces_jours', 4)::integer; v_auto integer; v_reste integer; v_reporte integer := 0;
  v_out jsonb := '[]'::jsonb; m jsonb; v_j integer; v_garde integer; v_id text; v_old jsonb; v_inf text; v_jour integer;
  v_ville text := coalesce(p_ville, 'capitale'); v_pays text := coalesce(p_pays, 'republic');
BEGIN
  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' THEN RETURN jsonb_build_object('motifs', p_motifs, 'reporte', 0); END IF;
  SELECT coalesce(sum(CASE WHEN jsonb_typeof(e -> 'jours') = 'number' THEN (e ->> 'jours')::integer ELSE 0 END), 0) INTO v_auto
    FROM jsonb_array_elements(p_motifs) e WHERE coalesce(e ->> 'source', '') <> 'jugement';
  IF coalesce(p_auto_deja, 0) + v_auto <= v_seuil THEN RETURN jsonb_build_object('motifs', p_motifs, 'reporte', 0); END IF;
  v_reste := greatest(0, v_seuil - coalesce(p_auto_deja, 0));
  FOR m IN SELECT e FROM jsonb_array_elements(p_motifs) e LOOP
    IF coalesce(m ->> 'source', '') <> 'jugement' AND jsonb_typeof(m -> 'jours') = 'number' THEN
      v_j := (m ->> 'jours')::integer; v_garde := least(v_j, v_reste); v_reste := v_reste - v_garde; v_reporte := v_reporte + v_j - v_garde;
      IF v_garde < v_j THEN
        m := m || jsonb_build_object('jours', v_garde, 'jours_bareme', v_j, 'reporte_au_proces', v_j - v_garde);
        v_inf := coalesce(v_inf, public.infraction_canonique(coalesce(m ->> 'infraction', m ->> 'acte')));
      END IF;
    END IF;
    v_out := v_out || jsonb_build_array(m);
  END LOOP;
  IF v_reporte = 0 THEN RETURN jsonb_build_object('motifs', p_motifs, 'reporte', 0); END IF;
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  -- Un seul procès de seuil ouvert par personne : les reports suivants s'y ajoutent.
  SELECT id, data::jsonb INTO v_id, v_old FROM public.plaintes_en_cours
   WHERE country = v_pays AND data IS NOT NULL AND left(btrim(data), 1) = '{'
     AND data::jsonb ->> 'origine' = 'seuil_proces' AND data::jsonb ->> 'cible' = p_nom AND data::jsonb ->> 'status' = 'saisie'
   ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF v_id IS NOT NULL THEN
    UPDATE public.plaintes_en_cours SET data = (v_old || jsonb_build_object(
        'jours_reference_total', coalesce((v_old ->> 'jours_reference_total')::integer, v_seuil) + v_reporte,
        'jours_reportes', coalesce((v_old ->> 'jours_reportes')::integer, 0) + v_reporte))::text
     WHERE id = v_id;
  ELSE
    v_id := 'proces-' || (extract(epoch from clock_timestamp()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 6);
    INSERT INTO public.plaintes_en_cours (id, country, city, data)
    VALUES (v_id, v_pays, v_ville, jsonb_build_object('id', v_id, 'auteur', 'Ministère public', 'cible', p_nom,
      'motif', 'Cumul de peines automatiques au-delà de ' || v_seuil || ' jours : ' || v_seuil || ' jours d''office, procès pour un éventuel complément',
      'categorie_alleguee', NULL, 'jour', v_jour, 'city', v_ville, 'country', v_pays, 'status', 'saisie', 'origine', 'seuil_proces',
      'qualification_parquet', v_inf, 'jours_reference_total', coalesce(p_auto_deja, 0) + v_auto, 'jours_office', v_seuil,
      'jours_reportes', v_reporte, 'depose_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))::text);
    PERFORM public.dossier_acte_consigner(v_id, v_pays, v_ville, 'juge_saisi', 'Ministère public', NULL, NULL, v_inf,
      jsonb_build_object('seuil', v_seuil, 'jours_reference_total', coalesce(p_auto_deja, 0) + v_auto));
    PERFORM public.mail_systeme_poser_interne('Ministère public', p_nom, 'Procès',
      'Vos peines automatiques dépassent ' || v_seuil || ' jours : vous en purgez ' || v_seuil || ' d''office. Un juge décidera '
      || 'lors d''un procès d''un éventuel complément.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
  END IF;
  RETURN jsonb_build_object('motifs', v_out, 'reporte', v_reporte, 'proces', v_id);
END $$;

-- ── Raccords (texte de production) ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Seuil appliqué à l'ouverture d'une détention (sauf reprise après évasion) et à chaque prolongation.
SELECT pg_temp.rp_raccorder('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure,
  $a$v_ville_cond text; v_jour_aff integer; v_prec text; v_reliquat integer; v_retour text;$a$,
  $b$v_ville_cond text; v_jour_aff integer; v_prec text; v_reliquat integer; v_retour text; v_seuil jsonb; /* crim_seuil_decl_v1 */$b$,
  'crim_seuil_decl_v1');
SELECT pg_temp.rp_raccorder('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure,
  $a$  INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
           autorite,issue_judiciaire,ville_condamnation,jour_affaire,detention_precedente_id,reliquat_jours)$a$,
  $b$  IF v_reliquat IS NULL THEN /* crim_seuil_ouvrir_v1 */
    v_seuil := public.crim_seuil_proces_interne(p_nom, p_motifs, 0, p_country, p_city);
    IF coalesce((v_seuil ->> 'reporte')::integer, 0) > 0 THEN
      p_motifs := v_seuil -> 'motifs'; p_jours := greatest(1, p_jours - (v_seuil ->> 'reporte')::integer);
    END IF;
  END IF;
  INSERT INTO public.detentions (id,country,city,nom,raison,jour_debut,jour_fin,qhs,motifs,
           autorite,issue_judiciaire,ville_condamnation,jour_affaire,detention_precedente_id,reliquat_jours)$b$,
  'crim_seuil_ouvrir_v1');
SELECT pg_temp.rp_raccorder('public.detention_prolonger_interne(text,jsonb,boolean)'::regprocedure,
  $a$DECLARE v_peine jsonb; v_det record; v_jours_supp int; v_nouveau int; v_motifs jsonb;$a$,
  $b$DECLARE v_peine jsonb; v_det record; v_jours_supp int; v_nouveau int; v_motifs jsonb; v_seuil jsonb; /* crim_seuil_decl_v1 */$b$,
  'crim_seuil_decl_v1');
SELECT pg_temp.rp_raccorder('public.detention_prolonger_interne(text,jsonb,boolean)'::regprocedure,
  $a$    FROM public.detentions WHERE id = v_det.id FOR UPDATE;$a$,
  $b$    FROM public.detentions WHERE id = v_det.id FOR UPDATE;
  v_seuil := public.crim_seuil_proces_interne(p_nom, p_motifs, /* crim_seuil_prolonger_v1 */
    (SELECT coalesce(sum(CASE WHEN jsonb_typeof(e -> 'jours') = 'number' THEN (e ->> 'jours')::integer ELSE 0 END), 0)
       FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_motifs) = 'array' THEN v_motifs ELSE '[]'::jsonb END) e
      WHERE coalesce(e ->> 'source', '') <> 'jugement')::integer, v_det.country, v_det.city); /* crim_seuil_prolonger_v2 */
  IF coalesce((v_seuil ->> 'reporte')::integer, 0) > 0 THEN
    p_motifs := v_seuil -> 'motifs';
    SELECT coalesce(sum((m ->> 'jours')::int), 0) INTO v_jours_supp FROM jsonb_array_elements(p_motifs) m;
    v_nouveau := coalesce(v_det.jour_fin, 0) + v_jours_supp;
  END IF;$b$,
  'crim_seuil_prolonger_v1');
-- Correctif (appliqué en production par la migration complémentaire « crim_lot6_justice_correctif_prolonger ») : sum() rend un bigint.
SELECT pg_temp.rp_raccorder('public.detention_prolonger_interne(text,jsonb,boolean)'::regprocedure,
  $a$WHERE coalesce(e ->> 'source', '') <> 'jugement'), v_det.country, v_det.city);$a$,
  $b$WHERE coalesce(e ->> 'source', '') <> 'jugement')::integer, v_det.country, v_det.city); /* crim_seuil_prolonger_v2 */$b$,
  'crim_seuil_prolonger_v2');
SELECT pg_temp.rp_raccorder('public.detention_prolonger_interne(text,jsonb,boolean)'::regprocedure,
  $a$                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau);$a$,
  $b$                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau,
                            'proces', v_seuil -> 'proces', 'jours_reportes', coalesce((v_seuil ->> 'reporte')::integer, 0)); /* crim_seuil_retour_v1 */$b$,
  'crim_seuil_retour_v1');

-- Flagrant délit : résistance au barème ; la peine d'office du même acte est réputée exécutée par l'arrestation.
SELECT pg_temp.rp_raccorder('public.arrestation_flagrant_interne(text,text,boolean,text,text,integer,boolean,text)'::regprocedure,
  $a$'acte', 'resistance_arrestation', 'jour_fait', p.jour, 'city', p.current_city, 'jours', 2,$a$,
  $b$'acte', 'resistance_arrestation', 'jour_fait', p.jour, 'city', p.current_city, 'jours', public.crim_peine_jours_interne('resistance_arrestation', p.country) /* crim_bareme_resistance_v1 */,$b$,
  'crim_bareme_resistance_v1');
SELECT pg_temp.rp_raccorder('public.arrestation_flagrant_interne(text,text,boolean,text,text,integer,boolean,text)'::regprocedure,
  $a$ v_total := v_total + 2;$a$,
  $b$ v_total := v_total + public.crim_peine_jours_interne('resistance_arrestation', p.country); /* crim_bareme_resistance_total_v1 */$b$,
  'crim_bareme_resistance_total_v1');
SELECT pg_temp.rp_raccorder('public.arrestation_flagrant_interne(text,text,boolean,text,text,integer,boolean,text)'::regprocedure,
  $a$RETURN v_r || jsonb_build_object('ok', true, 'acte', p_acte, 'raison_peine', v_libelle, 'jours', v_total, 'qhs', p_qhs);$a$,
  $b$UPDATE public.jugements SET executee = true /* crim_office_flagrant_v1 */
 WHERE accuse = p_nom AND NOT coalesce(executee, false) AND data ->> 'source' = 'peine_office'
   AND (data ->> 'acte' = p_acte OR data ->> 'infraction' = coalesce(public.infraction_canonique(p_acte), p_acte));
RETURN v_r || jsonb_build_object('ok', true, 'acte', p_acte, 'raison_peine', v_libelle, 'jours', v_total, 'qhs', p_qhs);$b$,
  'crim_office_flagrant_v1');

-- Garde à vue : barème (2 j de Républia) au lieu des 2 jours en dur.
SELECT pg_temp.rp_raccorder('public.plainte_instruire_interne(text,text,text,text,text)'::regprocedure,
  $a$    'jours', 2,$a$,
  $b$    'jours', public.crim_peine_jours_interne('garde_a_vue', p_pays) /* crim_bareme_gav_v1 */,$b$,
  'crim_bareme_gav_v1');
SELECT pg_temp.rp_raccorder('public.plainte_instruire_interne(text,text,text,text,text)'::regprocedure,
  $a$    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), 2,$a$,
  $b$    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), public.crim_peine_jours_interne('garde_a_vue', p_pays) /* crim_bareme_gav2_v1 */,$b$,
  'crim_bareme_gav2_v1');
SELECT pg_temp.rp_raccorder('public.enquete_garde_a_vue(text,text,text)'::regprocedure,
  $a$v_e jsonb; v_res jsonb; v_jours integer := 2;$a$,
  $b$v_e jsonb; v_res jsonb; v_jours integer := public.crim_peine_jours_interne('garde_a_vue', NULL); /* crim_bareme_gav3_v1 */$b$,
  'crim_bareme_gav3_v1');

-- Convocations : les deux barèmes propres (non-présentation 2 j, justification rejetée 1 j) enfin rattachés.
SELECT pg_temp.rp_raccorder('public.convocation_se_justifier(integer,integer)'::regprocedure,
  $a$v_det := public.convocation_detention_interne(v_moi, 'Non-présentation à une convocation', 2);$a$,
  $b$v_det := public.convocation_detention_interne(v_moi, 'Non-présentation à une convocation', public.crim_peine_jours_interne('non_presentation_convocation', NULL)); /* crim_bareme_conv1_v1 */$b$,
  'crim_bareme_conv1_v1');
SELECT pg_temp.rp_raccorder('public.convocation_se_justifier(integer,integer)'::regprocedure,
  $a$RETURN jsonb_build_object('ok', true, 'issue', 'non_presentation', 'jours', 2,$a$,
  $b$RETURN jsonb_build_object('ok', true, 'issue', 'non_presentation', 'jours', public.crim_peine_jours_interne('non_presentation_convocation', NULL) /* crim_bareme_conv2_v1 */,$b$,
  'crim_bareme_conv2_v1');
SELECT pg_temp.rp_raccorder('public.convocation_se_justifier(integer,integer)'::regprocedure,
  $a$v_det := public.convocation_detention_interne(v_moi, 'Justification rejetée au commissariat', 1);$a$,
  $b$v_det := public.convocation_detention_interne(v_moi, 'Justification rejetée au commissariat', public.crim_peine_jours_interne('justification_rejetee', NULL)); /* crim_bareme_conv3_v1 */$b$,
  'crim_bareme_conv3_v1');
SELECT pg_temp.rp_raccorder('public.convocation_se_justifier(integer,integer)'::regprocedure,
  $a$RETURN jsonb_build_object('ok', true, 'issue', 'rejetee', 'jours', 1,$a$,
  $b$RETURN jsonb_build_object('ok', true, 'issue', 'rejetee', 'jours', public.crim_peine_jours_interne('justification_rejetee', NULL) /* crim_bareme_conv4_v1 */,$b$,
  'crim_bareme_conv4_v1');

-- ── Juge : ±50 % autour de la référence (somme d'un procès de seuil, complément = au-delà des jours d'office) ──────
-- État d'urgence limité à 7 jours (§ 14) : échéance enregistrée.
ALTER TABLE public.etats_urgence ADD COLUMN IF NOT EXISTS expire_le timestamptz;
ALTER TABLE public.etats_urgence ADD COLUMN IF NOT EXISTS renouvellements integer NOT NULL DEFAULT 0;
-- Un état d'urgence déclaré avant ce lot expire 7 jours après aujourd'hui.
UPDATE public.etats_urgence SET expire_le = now() + interval '7 days' WHERE actif AND expire_le IS NULL;

CREATE OR REPLACE FUNCTION public.crim_etat_urgence_actif_interne(p_pays text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.etats_urgence WHERE country = p_pays AND actif AND expire_le IS NOT NULL AND expire_le > now());
$$;

CREATE OR REPLACE FUNCTION public.crim_peine_bornes_juge_interne(p_calc jsonb, p_affaire jsonb, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_mod numeric := public.crim_param_interne('juge_modulation_pct', 50) / 100.0; v_ref integer; v_office integer := 0;
  v_min integer; v_max integer; v_urg boolean := public.crim_etat_urgence_actif_interne(p_pays); v_seuil boolean;
BEGIN
  IF coalesce((p_calc ->> 'ok')::boolean, false) IS NOT TRUE OR p_calc ->> 'genre' IS DISTINCT FROM 'prison' THEN
    RETURN p_calc || CASE WHEN p_calc ? 'ok' THEN jsonb_build_object('etat_urgence', v_urg) ELSE '{}'::jsonb END;
  END IF;
  v_seuil := coalesce(p_affaire ->> 'origine', '') = 'seuil_proces' AND (p_affaire ->> 'jours_reference_total') IS NOT NULL;
  IF v_seuil THEN
    v_ref := (p_affaire ->> 'jours_reference_total')::integer; v_office := coalesce((p_affaire ->> 'jours_office')::integer, 0);
    v_min := greatest(0, round(v_ref * (1 - v_mod))::integer - v_office);
    v_max := greatest(0, round(v_ref * (1 + v_mod))::integer - v_office);
  ELSE
    v_ref := coalesce(public.crim_peine_jours_interne(p_calc ->> 'infraction', p_pays), (p_calc ->> 'jours_reference')::integer);
    v_min := greatest(1, round(v_ref * (1 - v_mod))::integer);
    v_max := round(v_ref * (1 + v_mod))::integer;
  END IF;
  IF v_urg THEN   -- état d'urgence : liberté totale du juge (borne technique)
    v_min := CASE WHEN v_seuil THEN 0 ELSE 1 END;
    v_max := public.crim_param_interne('juge_urgence_max_jours', 365)::integer;
  END IF;
  RETURN p_calc || jsonb_build_object('jours_reference', v_ref, 'jours_min', v_min, 'jours_max', v_max,
    'jours_defaut', least(v_max, greatest(v_min, v_ref - v_office)), 'jours_office', v_office, 'proces_seuil', v_seuil,
    'etat_urgence', v_urg);
END $$;

SELECT pg_temp.rp_raccorder('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure,
  $a$v_calc := public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays);$a$,
  $b$v_calc := public.crim_peine_bornes_juge_interne(public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays), v_a, v_pays); /* crim_juge_bornes_v1 */$b$,
  'crim_juge_bornes_v1');
SELECT pg_temp.rp_raccorder('public.justice_appel_juger(text,text,text,text,integer,integer)'::regprocedure,
  $a$v_calc := public.justice_peine_calcul(v_inf, p_genre, v_a ->> 'cible', v_pays);$a$,
  $b$v_calc := public.crim_peine_bornes_juge_interne(public.justice_peine_calcul(v_inf, p_genre, v_a ->> 'cible', v_pays), v_a, v_pays); /* crim_juge_bornes_v1 */$b$,
  'crim_juge_bornes_v1');
SELECT pg_temp.rp_raccorder('public.justice_peine_proposer(text,text,text)'::regprocedure,
  $a$RETURN public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays)$a$,
  $b$RETURN public.crim_peine_bornes_juge_interne(public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays), v_a, v_pays) /* crim_juge_bornes_v1 */$b$,
  'crim_juge_bornes_v1');

-- ── État d'urgence : 7 jours, renouvelable (3 PA + perte de POP habituelle), levé seul à échéance ─────────────────

CREATE OR REPLACE FUNCTION public.etat_urgence_decider(p_activer boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pays text; v_jour integer; v_actif boolean; v_paie jsonb; v_pop integer := 0; v_inf integer := 0;
        v_res jsonb; v_expire timestamptz; v_renouv boolean := false; v_jours integer := public.crim_param_interne('etat_urgence_jours', 7)::integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(day, 1) INTO v_pays, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('president', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  SELECT actif AND expire_le IS NOT NULL AND expire_le > now(), expire_le INTO v_actif, v_expire
    FROM public.etats_urgence WHERE country = v_pays FOR UPDATE;
  v_actif := coalesce(v_actif, false);
  IF NOT coalesce(p_activer, false) AND NOT v_actif THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_vigueur');
  END IF;
  v_renouv := coalesce(p_activer, false) AND v_actif;
  v_paie := public.payer_ordre(v_moi, 'etat_urgence', 3, 0);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;
  IF coalesce(p_activer, false) THEN
    v_expire := CASE WHEN v_renouv THEN v_expire ELSE now() END + make_interval(days => v_jours);
    INSERT INTO public.etats_urgence (country, actif, active_par, jour_debut, expire_le, renouvellements)
    VALUES (v_pays, true, v_moi, v_jour, v_expire, 0)
    ON CONFLICT (country) DO UPDATE SET actif = true, active_par = EXCLUDED.active_par,
      jour_debut = CASE WHEN v_renouv THEN public.etats_urgence.jour_debut ELSE EXCLUDED.jour_debut END,
      expire_le = EXCLUDED.expire_le,
      renouvellements = CASE WHEN v_renouv THEN public.etats_urgence.renouvellements + 1 ELSE 0 END;
    v_pop := -(floor(random() * 15)::integer + 5);
    v_inf := floor(random() * 10)::integer + 5;
    UPDATE public.personnages_donnees
       SET resources = jsonb_set(jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
             '{pop}', to_jsonb(greatest(0, least(100, coalesce(CASE WHEN jsonb_typeof(resources->'pop') = 'number' THEN (resources->>'pop')::numeric END, 50) + v_pop)))),
             '{inf}', to_jsonb(greatest(0, least(100, coalesce(CASE WHEN jsonb_typeof(resources->'inf') = 'number' THEN (resources->>'inf')::numeric END, 0) + v_inf)))),
           updated_at = clock_timestamp()
     WHERE name = v_moi
    RETURNING resources INTO v_res;
  ELSE
    UPDATE public.etats_urgence SET actif = false, active_par = v_moi WHERE country = v_pays;
    v_expire := NULL;
  END IF;
  RETURN jsonb_build_object('ok', true, 'actif', coalesce(p_activer, false), 'renouvele', v_renouv, 'expire_le', v_expire,
                            'jours', v_jours, 'paiement', v_paie, 'delta_pop', v_pop, 'delta_inf', v_inf,
                            'pop', v_res->'pop', 'inf', v_res->'inf');
END $$;

-- ── Cellule : grilles, rébellion, évasion ────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.prison_grilles_endommager_interne(p_pays text, p_ville text, p_degats integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id text := p_pays || '_' || coalesce(p_ville, 'capitale'); v_avant integer; v_apres integer; v_final integer;
BEGIN
  INSERT INTO public.niveaux_prison (id, data, updated_at) VALUES (v_id, jsonb_build_object('niveau', 100), now()) ON CONFLICT (id) DO NOTHING;
  SELECT coalesce(CASE WHEN jsonb_typeof(data -> 'niveau') = 'number' THEN (data ->> 'niveau')::numeric END, 100)::integer
    INTO v_avant FROM public.niveaux_prison WHERE id = v_id FOR UPDATE;
  v_apres := greatest(0, v_avant - greatest(0, coalesce(p_degats, 0)));
  -- Insurrection : les grilles cèdent, puis sont remises à neuf (comportement d'origine).
  v_final := CASE WHEN v_apres <= 0 THEN 100 ELSE v_apres END;
  -- Réparation : un tiers des dégâts cumulés par nuit (crim_justice_nuit).
  UPDATE public.niveaux_prison
     SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('niveau', v_final,
           'tranche_reparation', ceil((100 - v_final) / public.crim_param_interne('grilles_reparation_tiers', 3))::integer),
         updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('niveau', v_apres, 'degats', v_avant - v_apres, 'insurrection', v_apres <= 0,
                            'bonus_evasion', public.crim_grilles_bonus_interne(p_pays, p_ville));
END $$;

CREATE OR REPLACE FUNCTION public.crim_grilles_bonus_interne(p_pays text, p_ville text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(public.crim_param_interne('grilles_bonus_max', 25)::integer,
               greatest(0, 100 - coalesce((SELECT CASE WHEN jsonb_typeof(data -> 'niveau') = 'number' THEN (data ->> 'niveau')::numeric END
                                             FROM public.niveaux_prison WHERE id = p_pays || '_' || coalesce(p_ville, 'capitale')), 100)::integer));
$$;

CREATE OR REPLACE FUNCTION public.detention_se_rebeller(p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_moi text; p public.personnages_donnees%ROWTYPE; v_det record; v_paie jsonb;
  v_ville text; v_pays text; v_vol numeric; v_for numeric; v_taux integer; v_jet integer; v_degats integer;
  v_grilles jsonb; v_dis numeric; v_hp integer; v_res jsonb; v_r jsonb; v_fiche record; v_jours integer; j jsonb;
  v_ts text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO v_det FROM public.detention_active(v_moi);
  IF v_det.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_detenu'); END IF;

  v_paie := public.payer_ordre_interne(v_moi, 'se_rebeller', p_pa, p_cost);
  IF NOT coalesce((v_paie ->> 'ok')::boolean, false) THEN RETURN v_paie; END IF;

  v_pays := coalesce(v_det.country, p.country, 'republic');
  v_ville := coalesce(v_det.city, p.current_city, 'capitale');
  -- Réussite inchangée : min(60, 3 VOL + FOR du codétenu / 2).
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'VOL') = 'number' THEN (p.stats ->> 'VOL')::numeric END, 8);
  SELECT greatest(0, least(20, coalesce(CASE WHEN jsonb_typeof(e -> 'stats' -> 'FOR') = 'number'
                                             THEN (e -> 'stats' ->> 'FOR')::numeric END, 0)))
    INTO v_for
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes) = 'array' THEN p.employes ELSE '[]'::jsonb END) e
   WHERE e ->> 'job' = 'codetenu' LIMIT 1;
  v_taux := least(60, floor(v_vol * 3 + floor(coalesce(v_for, 0) / 2)))::integer;
  j := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END;
  v_jet := coalesce((j ->> 'rebellion')::integer, floor(random() * 100)::integer + 1);
  v_res := CASE WHEN jsonb_typeof(p.resources) = 'object' THEN p.resources ELSE '{}'::jsonb END;
  v_dis := coalesce(CASE WHEN jsonb_typeof(v_res -> 'dis') = 'number' THEN (v_res ->> 'dis')::numeric END, 50);

  IF v_jet <= v_taux THEN
    -- Rébellion réussie : effets actuels (DIS +6, PV −10, +1 jour au barème) et les grilles sont abîmées (4 à 10 points).
    v_degats := coalesce((j ->> 'degats')::integer, floor(random() * 7)::integer + 4);
    v_grilles := public.prison_grilles_endommager_interne(v_pays, v_ville, v_degats);
    v_jours := public.crim_peine_jours_interne('se_rebeller', v_pays);
    v_hp := greatest(1, coalesce(p.hp, 100) - 10);
    UPDATE public.personnages_donnees
       SET hp = v_hp, resources = v_res || jsonb_build_object('dis', least(100, v_dis + 6))
     WHERE name = v_moi;
    v_r := public.detention_prolonger_interne(v_moi, jsonb_build_array(jsonb_build_object(
        'type', 'Rébellion en cellule', 'acte', 'se_rebeller', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', v_jours,
        'source', 'evenement_detention', 'date_evenement', v_ts)), false);
    SELECT est_emprisonne INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet,
      'grilles', v_grilles, 'hp', v_hp, 'dis', least(100, v_dis + 6),
      'jour_fin', v_r -> 'jour_fin', 'jours_ajoutes', v_r -> 'jours_ajoutes', 'proces', v_r -> 'proces',
      'est_emprisonne', v_fiche.est_emprisonne, 'paiement', v_paie);
  END IF;

  -- Rébellion matée : les gardiens interviennent avant, aucun dégât aux grilles ; PV −25, DIS −15, +4 jours d'office.
  -- Plus de QHS automatique : le placement au QHS reste une décision de l'autorité supérieure (§ 16, lot 10).
  v_jours := public.crim_peine_jours_interne('rebellion_matee', v_pays);
  v_hp := greatest(1, coalesce(p.hp, 100) - 25);
  UPDATE public.personnages_donnees
     SET hp = v_hp, resources = v_res || jsonb_build_object('dis', greatest(0, v_dis - 15))
   WHERE name = v_moi;
  v_r := public.detention_prolonger_interne(v_moi, jsonb_build_array(jsonb_build_object(
      'type', 'Rébellion en cellule matée', 'acte', 'rebellion_matee', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', v_jours,
      'source', 'evenement_detention', 'date_evenement', v_ts)), false);
  SELECT est_emprisonne INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet,
    'grilles', NULL, 'hp', v_hp, 'dis', greatest(0, v_dis - 15), 'qhs', false,
    'jour_fin', v_r -> 'jour_fin', 'jours_ajoutes', v_r -> 'jours_ajoutes', 'proces', v_r -> 'proces',
    'est_emprisonne', v_fiche.est_emprisonne, 'paiement', v_paie);
END $$;

-- Évasion : bonus des grilles abîmées (plafond +25) après le plafond ordinaire, maximum absolu 90 % ; durées au barème.
SELECT pg_temp.rp_raccorder('public.detention_tenter_evasion(integer,integer,boolean)'::regprocedure,
  $a$  v_jet := floor(random() * 100)::integer + 1;$a$,
  $b$  v_bonus := public.crim_grilles_bonus_interne(v_pays, v_ville); /* crim_grilles_evasion_v1 */
  IF v_bonus > 0 THEN v_taux := least(90, v_taux + v_bonus); END IF;
  v_jet := floor(random() * 100)::integer + 1;$b$,
  'crim_grilles_evasion_v1');
SELECT pg_temp.rp_raccorder('public.detention_tenter_evasion(integer,integer,boolean)'::regprocedure,
  $a$'type', 'Évasion', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', 2,$a$,
  $b$'type', 'Évasion', 'acte', 'tentative_evasion', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', public.crim_peine_jours_interne('tentative_evasion', v_pays) /* crim_bareme_evasion_v1 */,$b$,
  'crim_bareme_evasion_v1');
SELECT pg_temp.rp_raccorder('public.detention_tenter_evasion(integer,integer,boolean)'::regprocedure,
  $a$'type', 'Tentative d''évasion échouée', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', 1,$a$,
  $b$'type', 'Tentative d''évasion échouée', 'acte', 'evasion_echouee', 'jour_fait', coalesce(p.day, 1), 'city', v_ville, 'jours', public.crim_peine_jours_interne('evasion_echouee', v_pays) /* crim_bareme_evasion2_v1 */,$b$,
  'crim_bareme_evasion2_v1');

-- ── Passe de nuit : états d'urgence échus, réparation des grilles (1/3 par nuit, 100 FR de la caisse du commissariat) ─
CREATE OR REPLACE FUNCTION public.crim_justice_nuit()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; g record; v_pays text; v_ville text; v_niv integer; v_tr integer; v_c jsonb; v_u integer := 0; v_g integer := 0;
  v_cout integer := public.crim_param_interne('grilles_reparation_cout', 100)::integer;
BEGIN
  FOR r IN SELECT country FROM public.etats_urgence WHERE actif AND expire_le IS NOT NULL AND expire_le <= now() FOR UPDATE LOOP
    UPDATE public.etats_urgence SET actif = false WHERE country = r.country;
    PERFORM public.annonce_publique_interne(r.country, 'Fin de l''état d''urgence : les 7 jours sont écoulés sans renouvellement.');
    v_u := v_u + 1;
  END LOOP;
  FOR g IN SELECT id, data FROM public.niveaux_prison
            WHERE coalesce(CASE WHEN jsonb_typeof(data -> 'niveau') = 'number' THEN (data ->> 'niveau')::numeric END, 100) < 100
            ORDER BY id FOR UPDATE LOOP
    v_pays := split_part(g.id, '_', 1); v_ville := substr(g.id, length(v_pays) + 2);
    CONTINUE WHEN NOT public.acte_nocturne_revendiquer(v_pays, 'crim_grilles_reparation', g.id, NULL);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_c := public.caisse_institution_mouvement(v_pays || '_commissariat_' || v_ville, -v_cout, true);
    PERFORM set_config('rp.caisse_interne', '', true);
    CONTINUE WHEN coalesce((v_c ->> 'ok')::boolean, false) IS NOT TRUE;   -- pas d'argent, pas de réparation
    v_niv := (g.data ->> 'niveau')::numeric::integer;
    v_tr := greatest(1, coalesce((g.data ->> 'tranche_reparation')::integer,
                                 ceil((100 - v_niv) / public.crim_param_interne('grilles_reparation_tiers', 3))::integer));
    v_niv := least(100, v_niv + v_tr);
    UPDATE public.niveaux_prison SET data = g.data || jsonb_build_object('niveau', v_niv,
             'tranche_reparation', CASE WHEN v_niv >= 100 THEN 0 ELSE v_tr END), updated_at = now() WHERE id = g.id;
    v_g := v_g + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'urgences_levees', v_u, 'grilles_reparees', v_g);
END $$;

DO $$ BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'crim_justice_nuit';
  PERFORM cron.schedule('crim_justice_nuit', '20 23 * * *', 'SELECT public.crim_justice_nuit()');
END $$;

-- ── Plainte contre X : rattachée à l'affaire dont la plaignante ou le plaignant est la victime ───────────────────
SELECT pg_temp.rp_raccorder('public.plainte_deposer(text,text,text,text[])'::regprocedure,
  $a$  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,$a$,
  $b$  IF v_cible = 'X' THEN /* crim_plainte_x_v1 */
    UPDATE public.crim_affaires f SET plainte_id = v_id, maj_le = now()
     WHERE f.id = (SELECT f2.id FROM public.crim_affaires f2
                    WHERE f2.plainte_id IS NULL AND NOT f2.identifie AND f2.pays = v_pays AND f2.auteur <> v_nom
                      AND f2.issue <> 'combat' AND (f2.cible = v_nom OR f2.employeur = v_nom)
                    ORDER BY f2.id DESC LIMIT 1);
    IF FOUND THEN
      UPDATE public.plaintes_en_cours SET data = (data::jsonb || jsonb_build_object('affaire',
               (SELECT f.id FROM public.crim_affaires f WHERE f.plainte_id = v_id), 'origine_affaire', 'crim_affaire'))::text
       WHERE id = v_id;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,$b$,
  'crim_plainte_x_v1');

-- ── Enquête du commissaire (§ 3) ────────────────────────────────────────────────────────────────────────────────
-- Plafond de l'affaire (5 / 15) ; départ à la moitié ; chaque piste présente ajoute une part égale de l'autre moitié.
CREATE OR REPLACE FUNCTION public.crim_enquete_taux_interne(p_affaire bigint, p_commissaire text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f public.crim_affaires%ROWTYPE; v_plafond numeric; v_base numeric; v_trace boolean; v_rum boolean; v_inf boolean; v_ach boolean;
  v_effr boolean; v_n integer; v_k integer; v_jour integer;
BEGIN
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_plafond := coalesce(f.plafond_enquete, public.crim_param_interne('plafond_enquete_echec', 15));
  v_base := v_plafond / 2;
  v_trace := f.trace OR f.detecte;
  SELECT coalesce(day, 1) INTO v_jour FROM public.personnages_donnees WHERE name = f.auteur;
  v_rum := EXISTS (SELECT 1 FROM public.actions_tracables a WHERE a.auteur = f.auteur AND a.country = f.pays
                     AND a.city IS NOT DISTINCT FROM coalesce(f.ville, a.city) AND a.decouvert IS NOT TRUE
                     AND (a.jour_expiration IS NULL OR a.jour_expiration >= coalesce(v_jour, 1)));
  v_inf := EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_commissaire
                     AND jsonb_typeof(d.informateurs) = 'array' AND jsonb_array_length(d.informateurs) > 0);
  v_effr := f.acte IN ('crocheter', 'forcer_porte', 'cambrioler', 'ramasser');
  v_ach := v_effr AND EXISTS (SELECT 1 FROM public.crim_traces_achat t WHERE t.acheteur = f.auteur AND t.pays = f.pays);
  v_n := CASE WHEN v_effr THEN 4 ELSE 3 END;
  v_k := (v_trace)::integer + (v_rum)::integer + (v_inf)::integer + (coalesce(v_ach, false))::integer;
  RETURN jsonb_build_object('plafond', v_plafond, 'base', v_base,
    'taux', round(least(v_plafond, v_base + (v_plafond - v_base) * v_k / v_n), 2),
    'pistes', jsonb_strip_nulls(jsonb_build_object('trace', v_trace, 'rumeurs', v_rum, 'informateur', v_inf,
                                                   'achats', CASE WHEN v_effr THEN coalesce(v_ach, false) END)));
END $$;

-- Ce que le commissaire lit : les plaintes contre X de sa ville rattachées à une affaire non résolue (jamais le nom).
CREATE OR REPLACE FUNCTION public.crim_enquetes_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text; v_poste text; v_ville text; v_pays text; v_auj text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays INTO v_nom, v_poste, v_ville, v_pays FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_commissaire'); END IF;
  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'pa', public.crim_param_interne('enquete_pa', 2)::integer,
    'affaires', coalesce((SELECT jsonb_agg(jsonb_build_object(
        'affaire', f.id, 'acte', f.acte, 'jour', f.jour, 'plainte', f.plainte_id, 'plaignant', p.data::jsonb ->> 'auteur',
        'victime', coalesce(f.cible, f.employeur), 'masque', f.mode IN ('masque', 'cache_masque'),
        'issue', CASE WHEN f.issue IN ('reussite', 'combat_gagne') THEN 'reussite' ELSE 'echec' END,
        'indices', f.indices - 'genre' - 'mode_arme',
        'deja_aujourdhui', (f.details -> 'enquete' ->> 'dernier_jour') = v_auj,
        'tentatives', coalesce((f.details -> 'enquete' ->> 'tentatives')::integer, 0)) ||
        jsonb_build_object('chances', public.crim_enquete_taux_interne(f.id, v_nom) -> 'taux',
                           'pistes', public.crim_enquete_taux_interne(f.id, v_nom) -> 'pistes')
        ORDER BY f.id DESC)
      FROM public.crim_affaires f JOIN public.plaintes_en_cours p ON p.id = f.plainte_id
     WHERE f.pays = v_pays AND coalesce(f.ville, 'capitale') = v_ville AND NOT f.identifie AND f.issue <> 'combat'
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{' AND p.data::jsonb ->> 'cible' = 'X'
       AND coalesce(p.data::jsonb ->> 'status', '') NOT IN ('jugee', 'classee', 'classee_sans_suite', 'non_lieu')), '[]'::jsonb));
END $$;

-- « Enquêter » : 2 PA, une tentative par jour et par plainte.
CREATE OR REPLACE FUNCTION public.crim_enqueter(p_affaire bigint, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('affaire', p_affaire); v jsonb; v_poste text; v_ville text; v_pays text;
  f public.crim_affaires%ROWTYPE; pl jsonb; v_auj text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD'); v_pa integer;
  v_paie jsonb; t jsonb; j jsonb; v_jet numeric; v_reussi boolean; v_enq jsonb; v_acte text; v_jours integer; v_averti boolean := false;
  v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'); v_out jsonb; v_dis numeric;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'enqueter_plainte', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT x.poste_id, x.poste_city, x.pays INTO v_poste, v_ville, v_pays FROM public.acteur_poste_courant() x;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_commissaire'); END IF;
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  IF NOT FOUND OR f.plainte_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_plainte'); END IF;
  IF f.pays IS DISTINCT FROM v_pays OR coalesce(f.ville, 'capitale') <> v_ville THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  IF f.identifie THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_identifie'); END IF;
  SELECT data::jsonb INTO pl FROM public.plaintes_en_cours WHERE id = f.plainte_id FOR UPDATE;
  IF pl IS NULL OR pl ->> 'cible' IS DISTINCT FROM 'X' THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_plainte'); END IF;
  v_enq := coalesce(f.details -> 'enquete', '{}'::jsonb);
  IF v_enq ->> 'dernier_jour' = v_auj THEN RETURN jsonb_build_object('ok', false, 'raison', 'une_tentative_par_jour'); END IF;
  v_pa := public.crim_param_interne('enquete_pa', 2)::integer;
  v_paie := public.payer_ordre(a, 'enqueter_plainte', v_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  t := public.crim_enquete_taux_interne(f.id, a);
  j := CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END;
  v_jet := coalesce((j ->> 'enquete')::numeric, random() * 100);
  v_reussi := v_jet < (t ->> 'taux')::numeric;
  v_enq := v_enq || jsonb_build_object('dernier_jour', v_auj, 'tentatives', coalesce((v_enq ->> 'tentatives')::integer, 0) + 1,
                                       'commissaire', a, 'dernier_taux', t -> 'taux', 'dernier_jet', round(v_jet, 2));

  IF v_reussi THEN
    -- Démasqué par l'enquête : peine d'office doublée (§ 14), avis de recherche ; la plainte vise désormais le coupable.
    v_acte := coalesce(f.details -> 'params' ->> CASE WHEN f.issue IN ('reussite', 'combat_gagne') THEN 'acte_peine_reussite' ELSE 'acte_peine_echec' END,
                       CASE f.acte WHEN 'ramasser' THEN 'vol' WHEN 'cambrioler' THEN 'vol' WHEN 'voler' THEN 'vol'
                                   WHEN 'crocheter' THEN 'effraction' WHEN 'forcer_porte' THEN 'effraction' ELSE f.acte END);
    PERFORM public.crime_rechercher_interne(f.auteur, v_acte, coalesce(f.details -> 'params' ->> 'type_recherche', 'crime'));
    v_jours := public.crim_peine_office_interne(f.auteur, v_acte, true, f.id, f.ville);
    v_enq := v_enq || jsonb_build_object('resolue', true, 'jours', v_jours);
    UPDATE public.crim_affaires SET identifie = true, peine_jours = v_jours, details = details || jsonb_build_object('enquete', v_enq), maj_le = now()
     WHERE id = f.id;
    UPDATE public.plaintes_en_cours SET data = (pl || jsonb_build_object('cible', f.auteur, 'identifie_par_enquete', true,
             'identifie_par', a, 'identifie_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
     WHERE id = f.plainte_id;
    PERFORM public.dossier_acte_consigner(f.plainte_id, f.pays, coalesce(f.ville, 'capitale'), 'enquete_acte_police', a, 'commissaire', NULL, v_acte,
      jsonb_build_object('affaire', f.id, 'identifie', f.auteur, 'jours', v_jours));
    PERFORM public.mail_systeme_poser_interne('Commissariat', pl ->> 'auteur', 'Votre plainte contre X',
      'L''enquête du commissaire ' || a || ' a identifié l''auteur des faits : ' || f.auteur || '. Il est recherché par la police. '
      || 'Vous pouvez poursuivre la procédure pour obtenir des dommages et intérêts.', v_date);
    PERFORM public.mail_systeme_poser_interne('Commissariat', f.auteur, 'Démasqué(e)',
      'L''enquête du commissaire ' || a || ' vous a identifié(e). Vous êtes recherché(e) : ' || v_jours || ' jour(s) de prison d''office.', v_date);
  ELSE
    UPDATE public.crim_affaires SET details = details || jsonb_build_object('enquete', v_enq), maj_le = now() WHERE id = f.id;
    -- Première enquête ratée (une seule fois par plainte) : le criminel est prévenu, −20 DIS, −15 moral.
    IF NOT coalesce((v_enq ->> 'averti')::boolean, false) AND NOT coalesce((pl ->> 'auteur_averti')::boolean, false) THEN
      v_averti := true;
      UPDATE public.crim_affaires SET details = jsonb_set(details, '{enquete,averti}', 'true'::jsonb) WHERE id = f.id;
      UPDATE public.plaintes_en_cours SET data = (pl || jsonb_build_object('auteur_averti', true))::text WHERE id = f.plainte_id;
      v_dis := public.crim_stat_interne(f.auteur, 'dis', 50);
      UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}',
               to_jsonb(greatest(0, v_dis - public.crim_param_interne('enquete_echec_dis', 20)))),
             moral = greatest(0, coalesce(moral, 50) - public.crim_param_interne('enquete_echec_moral', 15)::integer)
       WHERE name = f.auteur;
      PERFORM public.mail_systeme_poser_interne('Événement', f.auteur, 'Sur vos traces',
        'Le commissaire ' || a || ' est sur vos traces. Vous n''êtes pas identifié pour l''instant, mais vous n''avez plus droit à l''erreur.', v_date);
    END IF;
  END IF;

  v_out := jsonb_build_object('ok', true, 'affaire', f.id, 'reussi', v_reussi, 'taux', t -> 'taux', 'jet', round(v_jet, 2),
    'pistes', t -> 'pistes', 'coupable', CASE WHEN v_reussi THEN f.auteur END, 'jours', v_jours, 'averti', v_averti, 'paiement', v_paie);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'enqueter_plainte', prm, v_out);
END $$;

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  -- Fonctions nouvelles seulement : les fonctions remplacées gardent leurs droits.
  FOREACH f IN ARRAY ARRAY['crim_peine_office_interne(text,text,boolean,bigint,text)', 'crim_office_executee_trg()',
    'crim_seuil_proces_interne(text,jsonb,integer,text,text)', 'crim_etat_urgence_actif_interne(text)',
    'crim_peine_bornes_juge_interne(jsonb,jsonb,text)', 'crim_grilles_bonus_interne(text,text)', 'crim_justice_nuit()',
    'crim_enquete_taux_interne(bigint,text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crim_enquetes_lire()', 'crim_enqueter(bigint,uuid)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
