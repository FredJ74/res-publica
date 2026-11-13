-- SOVARKA : HÉROS DU TRAVAIL ET BOÎTE AUX LETTRES DU PARTI (décisions de Fred, 13/11/2026 après-midi,
-- consignées dans GAME-DESIGN-NOVOMIRSK.md « Héros du Travail » et « Boîte aux lettres du Parti »).
--
-- HÉROS DU TRAVAIL
--  * Points : les PA dépensés en ordres de production en Sovarka, par tout personnage qui s'y trouve
--    (étrangers compris). Comptés par le serveur, sans toucher aux ordres :
--      - déclencheur sur la baisse des PA quand la requête en cours est une porte de production
--        (`request.path`, comme payer_ordre) : commerce_produire (commerces, armes), produire_en_usine,
--        recolte_effectuer, sovarka_ferme_travailler, sovarka_foret_couper, fonds_reference_produire(_lots) ;
--      - garage : déclencheur sur garage_fabrications (pa_pj qui augmente, PJ du journal) ;
--      - chantiers : déclencheur sur terrains_etat (nouvelles lignes travauxPJ : 1 heure = 1 PA).
--  * Semaine de jeu : du lundi 0 h au dimanche 24 h, heure de Paris (horloge commune).
--  * Clôture (tâche de minuit, heros_travail_cloturer) : chaque score hebdomadaire devient un RECORD ;
--    le ministre de l'Économie collective (à défaut le Président du Conseil du Peuple) reçoit le
--    classement par courrier. Aucune attribution automatique.
--  * Décoration : le décideur ne peut décorer que le meilleur record en attente (égalité admise), toutes
--    semaines confondues (record en attente, décision de Fred) ; une décoration par semaine.
--  * Médaille : objet d'inventaire gravé au nom du décoré, installable dans un logement (équipement),
--    +3 Moral à quiconque y dort, sans cumul ; donnable, vendable, volable, transmise par succession.
--  * Publicité : liste des décorés (accueil des mairies), décorations dans la fenêtre d'un personnage,
--    annonce au journal (evenements_globaux). Aucun bonus de POP.
--
-- BOÎTE AUX LETTRES DU PARTI
--  * Une boîte par parti, dans la salle des partis des trois mairies. Dénonciation : texte libre, aucune
--    vérification, 1 PA, auteur jamais enregistré. Registre : tout est consigné ; lecture par le chef et
--    les personnes qu'il désigne ; seul le chef supprime une dénonciation. Information pure.

BEGIN;

-- ============================================================================ HÉROS DU TRAVAIL
CREATE TABLE IF NOT EXISTS public.heros_travail_points (
  pays text NOT NULL, semaine date NOT NULL, personnage text NOT NULL,
  points integer NOT NULL DEFAULT 0 CHECK (points >= 0), maj_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, semaine, personnage));
CREATE TABLE IF NOT EXISTS public.heros_travail_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pays text NOT NULL, semaine date NOT NULL, personnage text NOT NULL, points integer NOT NULL CHECK (points > 0),
  decore boolean NOT NULL DEFAULT false, decore_le timestamptz, decore_par text,
  UNIQUE (pays, semaine, personnage));
CREATE INDEX IF NOT EXISTS heros_travail_records_attente ON public.heros_travail_records (pays, points DESC) WHERE NOT decore;
CREATE TABLE IF NOT EXISTS public.heros_travail_clotures (
  pays text NOT NULL, semaine date NOT NULL, cloture_le timestamptz NOT NULL DEFAULT now(), destinataire text,
  PRIMARY KEY (pays, semaine));
CREATE TABLE IF NOT EXISTS public.heros_travail_requetes (
  requete uuid PRIMARY KEY, acteur text NOT NULL, resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.heros_travail_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heros_travail_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heros_travail_clotures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heros_travail_requetes ENABLE ROW LEVEL SECURITY;

-- Lundi de la semaine de jeu (heure de Paris) contenant l'instant donné.
CREATE OR REPLACE FUNCTION public.heros_travail_semaine_interne(p_t timestamptz DEFAULT now())
RETURNS date LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $$ SELECT date_trunc('week', (p_t AT TIME ZONE 'Europe/Paris'))::date $$;

-- Compte des PA de production : seulement pour un personnage qui se trouve en Sovarka.
CREATE OR REPLACE FUNCTION public.heros_travail_noter_interne(p_acteur text, p_pa integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_pays text;
BEGIN
  IF p_acteur IS NULL OR coalesce(p_pa, 0) <= 0 THEN RETURN; END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_pays IS DISTINCT FROM 'soviet' THEN RETURN; END IF;
  INSERT INTO public.heros_travail_points (pays, semaine, personnage, points)
  VALUES ('soviet', public.heros_travail_semaine_interne(), p_acteur, p_pa)
  ON CONFLICT (pays, semaine, personnage) DO UPDATE SET points = public.heros_travail_points.points + EXCLUDED.points, maj_le = now();
END $$;

-- Portes de production appelées directement par l'écran (PostgREST pose request.path).
CREATE OR REPLACE FUNCTION public.heros_travail_pa_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Jamais bloquant : un compte de points ne doit pas pouvoir faire échouer un ordre.
  BEGIN
    IF NEW.pa < OLD.pa AND coalesce(current_setting('request.path', true), '') IN (
         '/rpc/commerce_produire', '/rpc/produire_en_usine', '/rpc/recolte_effectuer',
         '/rpc/sovarka_ferme_travailler', '/rpc/sovarka_foret_couper',
         '/rpc/fonds_reference_produire', '/rpc/fonds_reference_produire_lots') THEN
      PERFORM public.heros_travail_noter_interne(NEW.name, OLD.pa - NEW.pa);
    END IF;
  EXCEPTION WHEN others THEN NULL;
  END;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS heros_travail_pa ON public.personnages_donnees;
CREATE TRIGGER heros_travail_pa AFTER UPDATE OF pa ON public.personnages_donnees
  FOR EACH ROW WHEN (NEW.pa < OLD.pa) EXECUTE FUNCTION public.heros_travail_pa_declencheur();

-- Garage : main-d'œuvre d'un PJ (vehicule_travailler_interne écrit pa_pj et le journal).
CREATE OR REPLACE FUNCTION public.heros_travail_garage_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  BEGIN
    IF NEW.pa_pj > OLD.pa_pj AND jsonb_typeof(NEW.journal) = 'array' THEN
      PERFORM public.heros_travail_noter_interne(NEW.journal->-1->>'pj', NEW.pa_pj - OLD.pa_pj);
    END IF;
  EXCEPTION WHEN others THEN NULL;
  END;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS heros_travail_garage ON public.garage_fabrications;
CREATE TRIGGER heros_travail_garage AFTER UPDATE OF pa_pj ON public.garage_fabrications
  FOR EACH ROW WHEN (NEW.pa_pj > OLD.pa_pj) EXECUTE FUNCTION public.heros_travail_garage_declencheur();

-- Chantiers : chantier_travailler ajoute une ligne {nom, heures} à travauxPJ (1 heure = 1 PA).
CREATE OR REPLACE FUNCTION public.heros_travail_chantier_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_old jsonb; v_new jsonb; e text; v_avant jsonb; v_apres jsonb; i integer;
BEGIN
  IF NEW.data IS NOT DISTINCT FROM OLD.data OR position('travauxPJ' in coalesce(NEW.data, '')) = 0 THEN RETURN NULL; END IF;
  BEGIN
  v_old := OLD.data::jsonb; v_new := NEW.data::jsonb;
  FOREACH e IN ARRAY ARRAY['chantier', 'chantierReamenagement'] LOOP
    v_avant := CASE WHEN jsonb_typeof(v_old->e->'travauxPJ') = 'array' THEN v_old->e->'travauxPJ' ELSE '[]'::jsonb END;
    v_apres := CASE WHEN jsonb_typeof(v_new->e->'travauxPJ') = 'array' THEN v_new->e->'travauxPJ' ELSE '[]'::jsonb END;
    IF jsonb_array_length(v_apres) > jsonb_array_length(v_avant) THEN
      FOR i IN jsonb_array_length(v_avant) .. jsonb_array_length(v_apres) - 1 LOOP
        PERFORM public.heros_travail_noter_interne(v_apres->i->>'nom', floor(coalesce((v_apres->i->>'heures')::numeric, 0))::integer);
      END LOOP;
    END IF;
  END LOOP;
  EXCEPTION WHEN others THEN NULL;
  END;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS heros_travail_chantier ON public.terrains_etat;
CREATE TRIGGER heros_travail_chantier AFTER UPDATE OF data ON public.terrains_etat
  FOR EACH ROW EXECUTE FUNCTION public.heros_travail_chantier_declencheur();

-- Décideur : le ministre de l'Économie collective ; à défaut, le Président du Conseil du Peuple.
CREATE OR REPLACE FUNCTION public.heros_travail_decideur_interne()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT coalesce(public.sovarka_titulaire_interne('min_fin'), public.sovarka_titulaire_interne('pm')) $$;

-- Clôture des semaines révolues (tâche de minuit, idempotente, rattrape une semaine manquée).
CREATE OR REPLACE FUNCTION public.heros_travail_cloturer(p_jour date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_courante date := date_trunc('week', coalesce(p_jour, (now() AT TIME ZONE 'Europe/Paris')::date))::date;
  s date; v_dest text; v_corps text; v_n integer := 0; r record; v_rang integer;
BEGIN
  FOR s IN SELECT DISTINCT p.semaine FROM public.heros_travail_points p
            WHERE p.pays = 'soviet' AND p.semaine < v_courante
              AND NOT EXISTS (SELECT 1 FROM public.heros_travail_clotures c WHERE c.pays = 'soviet' AND c.semaine = p.semaine)
            ORDER BY 1 LOOP
    INSERT INTO public.heros_travail_records (pays, semaine, personnage, points)
    SELECT 'soviet', p.semaine, p.personnage, p.points FROM public.heros_travail_points p
     WHERE p.pays = 'soviet' AND p.semaine = s AND p.points > 0
    ON CONFLICT (pays, semaine, personnage) DO NOTHING;
    v_dest := public.heros_travail_decideur_interne();
    INSERT INTO public.heros_travail_clotures (pays, semaine, destinataire) VALUES ('soviet', s, v_dest);
    v_n := v_n + 1;
    IF v_dest IS NOT NULL THEN
      v_corps := 'Camarade ministre,' || E'\n\n' || 'Voici le classement du travail de la semaine du '
        || to_char(s, 'DD/MM/YYYY') || ' au ' || to_char(s + 6, 'DD/MM/YYYY') || ' (PA dépensés en production en Sovarka) :' || E'\n';
      v_rang := 0;
      FOR r IN SELECT personnage, points FROM public.heros_travail_records WHERE pays = 'soviet' AND semaine = s
                ORDER BY points DESC, personnage LIMIT 10 LOOP
        v_rang := v_rang + 1;
        v_corps := v_corps || E'\n' || v_rang || '. ' || r.personnage || ' — ' || r.points || ' points';
      END LOOP;
      SELECT personnage, points INTO r FROM public.heros_travail_records WHERE pays = 'soviet' AND NOT decore
       ORDER BY points DESC, semaine, personnage LIMIT 1;
      IF FOUND THEN
        v_corps := v_corps || E'\n\n' || 'Record en attente de décoration : ' || r.personnage || ' (' || r.points || ' points). '
          || 'Nul ne peut être décoré avec moins de points tant que ce record ne l''a pas été.';
      END IF;
      v_corps := v_corps || E'\n\n' || 'La décision vous appartient : « Héros du Travail », dans votre bureau du Palais du Gouvernement.';
      PERFORM public.mail_systeme_poser_interne('Ministère de l''Économie collective', v_dest,
        'Héros du Travail — classement de la semaine', v_corps, NULL);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'semaines_cloturees', v_n);
END $$;

-- Lecture pour le bureau du ministre : classement, records en attente, éligibles.
CREATE OR REPLACE FUNCTION public.heros_travail_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE a text := public.mon_personnage(); v_decideur text := public.heros_travail_decideur_interne();
  v_der date; v_max integer; v_deja boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT max(semaine) INTO v_der FROM public.heros_travail_clotures WHERE pays = 'soviet';
  SELECT max(points) INTO v_max FROM public.heros_travail_records WHERE pays = 'soviet' AND NOT decore;
  v_deja := EXISTS (SELECT 1 FROM public.heros_travail_records WHERE pays = 'soviet' AND decore
                     AND decore_le >= (public.heros_travail_semaine_interne()::timestamp AT TIME ZONE 'Europe/Paris'));
  RETURN jsonb_build_object('ok', true, 'decideur', a = v_decideur, 'deja_decore_cette_semaine', v_deja,
    'derniere_semaine', v_der,
    'classement', coalesce((SELECT jsonb_agg(jsonb_build_object('personnage', personnage, 'points', points) ORDER BY points DESC, personnage)
                             FROM public.heros_travail_records WHERE pays = 'soviet' AND semaine = v_der), '[]'::jsonb),
    'attente', coalesce((SELECT jsonb_agg(x ORDER BY (x->>'points')::integer DESC, x->>'semaine', x->>'personnage') FROM (
        SELECT jsonb_build_object('id', id, 'personnage', personnage, 'semaine', semaine, 'points', points,
                                  'eligible', points = v_max) AS x
          FROM public.heros_travail_records WHERE pays = 'soviet' AND NOT decore ORDER BY points DESC, semaine LIMIT 20) t), '[]'::jsonb),
    'mes_points_semaine', coalesce((SELECT points FROM public.heros_travail_points WHERE pays = 'soviet'
                                      AND semaine = public.heros_travail_semaine_interne() AND personnage = a), 0));
END $$;

-- Décorer : décideur seulement, meilleur record en attente seulement, une décoration par semaine.
CREATE OR REPLACE FUNCTION public.heros_travail_decorer(p_requete uuid, p_record uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE a text := public.mon_personnage(); r public.heros_travail_records; v_max integer; v_obj jsonb; v_res jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  SELECT resultat INTO v_res FROM public.heros_travail_requetes WHERE requete = p_requete AND acteur = a;
  IF FOUND THEN RETURN v_res || jsonb_build_object('rejeu', true); END IF;
  IF a IS DISTINCT FROM public.heros_travail_decideur_interne() THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_decideur'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('heros_travail_soviet'));
  SELECT * INTO r FROM public.heros_travail_records WHERE id = p_record AND pays = 'soviet' FOR UPDATE;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'record_introuvable'); END IF;
  IF r.decore THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_decore'); END IF;
  IF EXISTS (SELECT 1 FROM public.heros_travail_records WHERE pays = 'soviet' AND decore
              AND decore_le >= (public.heros_travail_semaine_interne()::timestamp AT TIME ZONE 'Europe/Paris')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_decore_cette_semaine'); END IF;
  SELECT max(points) INTO v_max FROM public.heros_travail_records WHERE pays = 'soviet' AND NOT decore;
  IF r.points < v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'record_superieur_en_attente', 'record', v_max); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = r.personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  UPDATE public.heros_travail_records SET decore = true, decore_le = now(), decore_par = a WHERE id = r.id;
  v_obj := jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', ''), 'qty', 1,
    'name', 'Médaille de Héros du Travail',
    'desc', 'Décernée à ' || r.personnage || ' par le ministère de l''Économie collective de Sovarka, semaine du '
            || to_char(r.semaine, 'DD/MM/YYYY') || ' (' || r.points || ' points). Installée dans un logement : +3 Moral à chaque sommeil.',
    'icon', 'ti-medal', 'type', 'medaille_heros_travail', 'generique_id', 'medaille_heros_travail', 'legal', true,
    'decore', r.personnage, 'semaine', r.semaine, 'points', r.points, 'image', 'images/medaille-heros-du-travail-sovarka-vignette.webp');
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END) || jsonb_build_array(v_obj)
   WHERE name = r.personnage;
  PERFORM public.annonce_publique_interne('soviet', 'Le camarade ' || r.personnage || ' est décoré Héros du Travail pour la semaine du '
    || to_char(r.semaine, 'DD/MM/YYYY') || ' (' || r.points || ' points).');
  PERFORM public.mail_systeme_poser_interne('Ministère de l''Économie collective', r.personnage, 'Vous êtes Héros du Travail',
    'Camarade,' || E'\n\n' || 'Le ministère de l''Économie collective vous décore Héros du Travail pour la semaine du '
    || to_char(r.semaine, 'DD/MM/YYYY') || ' (' || r.points || ' points). La médaille est dans votre inventaire ; installée dans un logement, elle donne +3 Moral à chaque sommeil.', NULL);
  v_res := jsonb_build_object('ok', true, 'personnage', r.personnage, 'semaine', r.semaine, 'points', r.points);
  INSERT INTO public.heros_travail_requetes (requete, acteur, resultat) VALUES (p_requete, a, v_res);
  RETURN v_res;
END $$;

-- Liste publique des décorés (accueil des mairies).
CREATE OR REPLACE FUNCTION public.heros_travail_tableau()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'decores', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'personnage', personnage, 'semaine', semaine, 'points', points, 'decore_le', decore_le) ORDER BY decore_le DESC)
    FROM (SELECT * FROM public.heros_travail_records WHERE pays = 'soviet' AND decore ORDER BY decore_le DESC LIMIT 200) t), '[]'::jsonb));
END $$;

-- Décorations d'un personnage (fenêtre d'interaction) : générique, pour d'autres distinctions plus tard.
CREATE OR REPLACE FUNCTION public.decorations_lire(p_personnage text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.mon_personnage() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'decorations', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'type', 'heros_travail', 'pays', pays, 'semaine', semaine, 'points', points, 'decore_le', decore_le) ORDER BY decore_le)
    FROM public.heros_travail_records WHERE personnage = p_personnage AND decore), '[]'::jsonb));
END $$;

-- Médaille installée dans le logement : +3 Moral au sommeil (sans cumul), pour qui y dort légitimement.
CREATE OR REPLACE FUNCTION public.logement_sommeil_interne(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; i jsonb; r text; v_medaille boolean;
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_acteur;
  i := public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF i IS NULL THEN RETURN NULL; END IF;
  r := public.logement_role_interne(p_acteur, i);
  IF r IS NULL OR r = 'reprise' THEN RETURN NULL; END IF;
  IF (i->>'premium')::boolean THEN
    IF (i->>'chambre')::integer = 0 THEN RETURN NULL; END IF;
  ELSIF (i->>'chambre')::integer <> 0 THEN RETURN NULL; END IF;
  -- heros_travail_medaille_v1 (13/11/2026) : médaille installée dans le logement (salon ou chambre).
  v_medaille := EXISTS (SELECT 1 FROM public.equipements_installes e
    WHERE e.generique_id = 'medaille_heros_travail' AND e.pays = d.country AND e.ville = d.current_city
      AND e.batiment = d.current_building AND (e.piece = i->>'base' OR e.piece LIKE (i->>'base') || '\_chambre\_%'));
  RETURN jsonb_build_object('pa', 1, 'moral', (i->>'moral')::integer + CASE WHEN v_medaille THEN 3 ELSE 0 END,
    'sante', (i->>'sante')::integer, 'role', r, 'premium', (i->>'premium')::boolean, 'label', i->>'label',
    'medaille', v_medaille);
END $function$;

-- Médaille installable comme équipement, seulement dans un logement.
DO $$
DECLARE f regprocedure; d text; n text; c_liste text := '''armoire_souvenirs'', ''imprimante-papier''';
BEGIN
  FOREACH f IN ARRAY ARRAY['public.equipement_installer(text)'::regprocedure, 'public.equipements_local_lire()'::regprocedure] LOOP
    d := pg_get_functiondef(f);
    IF position('medaille_heros_travail' in d) > 0 THEN CONTINUE; END IF;
    n := replace(d, c_liste, '''armoire_souvenirs'', ''medaille_heros_travail'', ''imprimante-papier''');
    IF n = d THEN RAISE EXCEPTION 'heros_travail : liste des équipements introuvable dans %', f; END IF;
    IF f = 'public.equipement_installer(text)'::regprocedure THEN
      d := n;
      n := replace(d, '  PERFORM 1 FROM public.equipements_installes',
        '  IF p_generique = ''medaille_heros_travail'' AND public.logement_info_interne(d.country, d.current_city, d.current_building, d.current_room) IS NULL THEN' || chr(10) ||
        '    RETURN jsonb_build_object(''ok'', false, ''raison'', ''medaille_logement_seulement''); END IF;' || chr(10) ||
        '  PERFORM 1 FROM public.equipements_installes');
      IF n = d THEN RAISE EXCEPTION 'heros_travail : ancre de equipement_installer introuvable'; END IF;
    END IF;
    EXECUTE n;
  END LOOP;
END $$;

-- ============================================================================ BOÎTE AUX LETTRES DU PARTI
CREATE TABLE IF NOT EXISTS public.parti_boite_acces (
  parti_id text NOT NULL, personnage text NOT NULL, designe_par text NOT NULL, designe_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (parti_id, personnage));
-- Aucun auteur enregistré : l'anonymat est total dans le registre.
CREATE TABLE IF NOT EXISTS public.parti_denonciations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), parti_id text NOT NULL, texte text NOT NULL,
  depose_le timestamptz NOT NULL DEFAULT now(), ville text);
CREATE INDEX IF NOT EXISTS parti_denonciations_parti ON public.parti_denonciations (parti_id, depose_le DESC);
-- Reçus de requête sans lien vers la dénonciation (double clic sans second dépôt, sans trahir l'auteur).
CREATE TABLE IF NOT EXISTS public.parti_denonciations_requetes (
  requete uuid PRIMARY KEY, acteur text NOT NULL, cree_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.parti_boite_acces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parti_denonciations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parti_denonciations_requetes ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.parti_boite_dans_salle_interne(p_acteur text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT CASE WHEN country = 'soviet' AND current_room = 'salle_partis' THEN jsonb_build_object('ville', current_city) END
        FROM public.personnages_donnees WHERE name = p_acteur $$;

CREATE OR REPLACE FUNCTION public.parti_boite_poster(p_requete uuid, p_parti text, p_texte text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE a text := public.mon_personnage(); v_lieu jsonb; v_texte text := btrim(coalesce(p_texte, '')); v_pay jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF EXISTS (SELECT 1 FROM public.parti_denonciations_requetes WHERE requete = p_requete AND acteur = a) THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  v_lieu := public.parti_boite_dans_salle_interne(a);
  IF v_lieu IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_la_salle'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = p_parti AND o.data IS JSON OBJECT
                  AND public.sovarka_est_parti_interne(o.data::jsonb)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parti_introuvable'); END IF;
  IF v_texte = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_vide'); END IF;
  IF length(v_texte) > 2000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_trop_long', 'max', 2000); END IF;
  v_pay := public.payer_ordre_interne(a, 'parti_denoncer', 1, 0);
  IF coalesce((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_pay; END IF;
  INSERT INTO public.parti_denonciations (parti_id, texte, ville) VALUES (p_parti, v_texte, v_lieu->>'ville');
  INSERT INTO public.parti_denonciations_requetes (requete, acteur) VALUES (p_requete, a);
  RETURN jsonb_build_object('ok', true, 'pa', v_pay->'pa');
END $$;

CREATE OR REPLACE FUNCTION public.parti_boite_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'dans_la_salle', public.parti_boite_dans_salle_interne(a) IS NOT NULL,
    'partis', coalesce((SELECT jsonb_agg(jsonb_build_object('id', o.id, 'nom', o.data::jsonb->>'nom') ORDER BY o.data::jsonb->>'nom')
      FROM public.organisations o WHERE o.data IS JSON OBJECT AND public.sovarka_est_parti_interne(o.data::jsonb)), '[]'::jsonb),
    'boites', CASE WHEN public.parti_boite_dans_salle_interne(a) IS NULL THEN '[]'::jsonb ELSE coalesce((SELECT jsonb_agg(jsonb_build_object(
        'parti', o.id, 'nom', o.data::jsonb->>'nom', 'est_chef', o.data::jsonb->>'chef' = a,
        'denonciations', coalesce((SELECT jsonb_agg(jsonb_build_object('id', x.id, 'texte', x.texte, 'depose_le', x.depose_le, 'ville', x.ville)
                                    ORDER BY x.depose_le DESC) FROM public.parti_denonciations x WHERE x.parti_id = o.id), '[]'::jsonb),
        'acces', CASE WHEN o.data::jsonb->>'chef' = a THEN coalesce((SELECT jsonb_agg(b.personnage ORDER BY b.personnage)
                   FROM public.parti_boite_acces b WHERE b.parti_id = o.id), '[]'::jsonb) END)
        ORDER BY o.data::jsonb->>'nom')
      FROM public.organisations o
     WHERE o.data IS JSON OBJECT AND public.sovarka_est_parti_interne(o.data::jsonb)
       AND (o.data::jsonb->>'chef' = a OR EXISTS (SELECT 1 FROM public.parti_boite_acces b WHERE b.parti_id = o.id AND b.personnage = a))), '[]'::jsonb) END);
END $$;

CREATE OR REPLACE FUNCTION public.parti_boite_acces_fixer(p_parti text, p_personnage text, p_acces boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE a text := public.mon_personnage(); v_nom text := btrim(coalesce(p_personnage, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = p_parti AND o.data IS JSON OBJECT
                  AND public.sovarka_est_parti_interne(o.data::jsonb) AND o.data::jsonb->>'chef' = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef'); END IF;
  IF coalesce(p_acces, false) THEN
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
    IF v_nom = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'chef_deja_acces'); END IF;
    INSERT INTO public.parti_boite_acces (parti_id, personnage, designe_par) VALUES (p_parti, v_nom, a) ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.parti_boite_acces WHERE parti_id = p_parti AND personnage = v_nom;
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.parti_boite_supprimer(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE a text := public.mon_personnage(); v_parti text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT parti_id INTO v_parti FROM public.parti_denonciations WHERE id = p_id;
  IF v_parti IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'denonciation_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = v_parti AND o.data IS JSON OBJECT
                  AND o.data::jsonb->>'chef' = a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef'); END IF;
  DELETE FROM public.parti_denonciations WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;

-- Coûts déclarés (miroir de data.js, régénéré dans baseline/seeds).
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('parti_denoncer', 1, 0), ('parti_boite_registre', 0, 0), ('heros_travail_tableau', 0, 0), ('heros_travail_classement', 0, 0)
ON CONFLICT DO NOTHING;

-- Droits : lectures et actes pour les joueurs, clôture pour la tâche de minuit, internes fermés.
REVOKE ALL ON FUNCTION public.heros_travail_noter_interne(text, integer), public.heros_travail_decideur_interne(),
  public.heros_travail_cloturer(date), public.parti_boite_dans_salle_interne(text),
  public.heros_travail_lire(), public.heros_travail_decorer(uuid, uuid), public.heros_travail_tableau(), public.decorations_lire(text),
  public.parti_boite_poster(uuid, text, text), public.parti_boite_lire(), public.parti_boite_acces_fixer(text, text, boolean),
  public.parti_boite_supprimer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.heros_travail_lire(), public.heros_travail_decorer(uuid, uuid), public.heros_travail_tableau(),
  public.decorations_lire(text), public.parti_boite_poster(uuid, text, text), public.parti_boite_lire(),
  public.parti_boite_acces_fixer(text, text, boolean), public.parti_boite_supprimer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.heros_travail_cloturer(date) TO service_role;
REVOKE ALL ON FUNCTION public.heros_travail_noter_interne(text, integer), public.heros_travail_decideur_interne(),
  public.parti_boite_dans_salle_interne(text) FROM authenticated;

COMMIT;
