-- Cliniques privées et service d'étage : relevé de Fred du 13/11/2026 (tour de Novomirsk).
--
-- 1. Escorts en clinique (décisions de Fred, 13/11/2026, GAME-DESIGN-ESCORTS-CLINIQUE.md) :
--    « Appel à un(e) escort » dans les chambres de TOUTES les cliniques privées (Républia et
--    Sovarka), pour l'occupant de la chambre (client d'une nuit ou patient hospitalisé), même
--    standard et mêmes barèmes que les résidences de Novomirsk. En clinique, le tirage ne propose
--    QUE les deux escorts des cliniques : Irina (infirmière) et Boris (infirmier).
--    Au passage : Ludmilla Bonaskova et Boris Kostof (catalogue « soviet », 12/11) n'étaient jamais
--    tirés aux résidences, le tirage ne lisant que le catalogue de Républia ; ils le sont en Sovarka.
--    escort_lieu_locataire_interne reste INCHANGÉE : elle ouvre aussi le service d'étage et le
--    piratage de nuit, que la décision ne concerne pas. Un nouveau lieu d'appel l'enveloppe.
-- 2. Nuitée de clinique créditée dans le sommeil lui-même (plus de second appel de l'écran, plus de
--    bouton « Vérifier les bonus de la nuit ») : le déclencheur qui constatait la nuit l'applique.
-- 3. Service d'étage des hôtels de Républia : santé, moral et bonus différé étaient écrits par
--    l'écran, après paiement, par un second appel. Une seule fonction serveur paie et applique.
--    pa_bonus_differe_crediter n'est plus ouverte aux joueurs (seul appelant écran : ce service).
-- Idempotente.

-- 1a. Les deux escorts des cliniques.
INSERT INTO public.escorts_agences (pays, nom)
VALUES ('clinique', 'Agence internationale Roxane Velours')
ON CONFLICT (pays) DO NOTHING;

INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif)
VALUES
  ('escort_clinique_irina', 'clinique', 'Irina', 'F',
   'images/personnages/Clinique_escort_Irina.webp', 'images/personnages/Clinique_escort_Irina_vignette.webp', '50% 12%', 1, true),
  ('escort_clinique_boris', 'clinique', 'Boris', 'H',
   'images/personnages/Clinique_escort_Boris.webp', 'images/personnages/Clinique_escort_Boris_vignette.webp', '50% 12%', 1, true)
ON CONFLICT (escort_id) DO NOTHING;

-- 1b. Lieu d'où l'on peut appeler : Pavillon, Résidence (inchangés) ou chambre de clinique occupée.
CREATE OR REPLACE FUNCTION public.escort_lieu_appel_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE d record; v jsonb;
BEGIN
  v := public.escort_lieu_locataire_interne(p_nom);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND OR d.country NOT IN ('republic', 'soviet') OR d.current_city IS DISTINCT FROM 'capitale'
     OR d.current_building IS DISTINCT FROM 'clinique-privee' OR coalesce(d.current_room, '') !~ '^chambre_([1-9]|10)$' THEN
    RETURN NULL;
  END IF;
  -- Même bail pour le client d'une nuit (reservationClinique) et le patient transféré.
  IF EXISTS (SELECT 1 FROM public.locations_actives l
              WHERE l.id = d.country || ':clinique-privee:' || d.current_room || ':capitale'
                AND l.country = d.country AND l.data->>'locataire' = p_nom) THEN
    RETURN jsonb_build_object('batiment', d.current_building, 'piece', d.current_room, 'lieu', 'clinique');
  END IF;
  RETURN NULL;
END $function$;
REVOKE ALL ON FUNCTION public.escort_lieu_appel_interne(text) FROM PUBLIC, anon, authenticated;

-- 1c. Escorts tirables selon le lieu.
CREATE OR REPLACE FUNCTION public.escort_disponibles_interne(p_nom text, p_genre text)
RETURNS SETOF public.escorts_catalogue LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT c.* FROM public.escorts_catalogue c
   WHERE c.actif AND c.genre = p_genre
     AND c.pays = ANY (CASE
       WHEN public.escort_lieu_appel_interne(p_nom)->>'lieu' = 'clinique' THEN ARRAY['clinique']
       WHEN (SELECT country FROM public.personnages_donnees WHERE name = p_nom) = 'soviet' THEN ARRAY['republic', 'soviet']
       ELSE ARRAY['republic'] END)
     AND NOT EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.id = public.employe_pnj_id(p_nom, 'escort', c.escort_id) AND m.statut = 'actif') $function$;
REVOKE ALL ON FUNCTION public.escort_disponibles_interne(text, text) FROM PUBLIC, anon, authenticated;

-- 1d. Devis et validation du standard : lieu d'appel élargi (patch en place, rien d'autre ne change).
DO $patch$
DECLARE f text; d text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.escort_standard_devis(text)', 'public.escort_standard_valider(uuid,integer,integer)'] LOOP
    d := pg_get_functiondef(f::regprocedure);
    IF position('escort_lieu_appel_interne(moi)' IN d) = 0 THEN
      IF position('escort_lieu_locataire_interne(moi)' IN d) = 0 THEN RAISE EXCEPTION 'motif introuvable dans %', f; END IF;
      EXECUTE replace(d, 'escort_lieu_locataire_interne(moi)', 'escort_lieu_appel_interne(moi)');
    END IF;
  END LOOP;
END $patch$;

-- 1e. Projet d'article du scandale : le lieu « clinique » est nommé.
DO $patch$
DECLARE d text := pg_get_functiondef('public.escort_scandale_presse_interne(text,text)'::regprocedure);
BEGIN
  IF position('WHEN ''clinique''' IN d) = 0 THEN
    IF position('dans son appartement ''' IN d) = 0 THEN RAISE EXCEPTION 'motif presse introuvable'; END IF;
    d := replace(d, 'dans son appartement ''' || E'\n' || '    || CASE s.lieu WHEN ''residence'' THEN ''de la Résidence impériale''',
                    '''' || E'\n' || '    || CASE s.lieu WHEN ''residence'' THEN ''dans son appartement de la Résidence impériale'' WHEN ''clinique'' THEN ''dans sa chambre de clinique privée''');
    d := replace(d, 'ELSE ''du Pavillon des Ambassadeurs'' END', 'ELSE ''dans son appartement du Pavillon des Ambassadeurs'' END');
    IF position('WHEN ''clinique''' IN d) = 0 THEN RAISE EXCEPTION 'patch presse non appliqué'; END IF;
    EXECUTE d;
  END IF;
END $patch$;

-- 2. La nuit constatée en chambre réservée est créditée aussitôt (une seule fois).
CREATE OR REPLACE FUNCTION public.clinique_nuitee_marquer_repos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $trigger$
DECLARE v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date; v_id bigint;
BEGIN
 IF NEW.pa_repos_le IS DISTINCT FROM OLD.pa_repos_le
    AND NEW.pa_repos_le=v_jour
    AND NEW.country IN ('republic','soviet') AND NEW.current_city='capitale'
    AND NEW.current_building='clinique-privee'
    AND NEW.current_room ~ '^chambre_([1-9]|10)$'
    AND NOT (NEW.hospitalisation IS NOT NULL AND jsonb_typeof(NEW.hospitalisation)='object'
      AND COALESCE(NULLIF(NEW.hospitalisation->>'dateFinParis','')::date,v_jour)>=v_jour)
 THEN
  UPDATE public.clinique_nuitees n SET dormie_le=v_jour, consommee_le=v_jour
   WHERE n.personnage=NEW.name AND n.country=NEW.country AND n.room_id=NEW.current_room
     AND n.consommee_le IS NULL AND n.annulee_le IS NULL
     AND EXISTS (SELECT 1 FROM public.locations_actives l
       WHERE l.id=NEW.country||':clinique-privee:'||NEW.current_room||':capitale'
       AND l.country=NEW.country AND l.data->>'locataire'=NEW.name
       AND l.data->>'reservationClinique'='true')
   RETURNING n.id INTO v_id;
  IF v_id IS NOT NULL THEN
   -- Mêmes bonus et plafonds que clinique_nuitee_consommer ; la mise à jour ne touche pas
   -- pa_repos_le, le déclencheur ne se relance donc pas.
   UPDATE public.personnages_donnees SET
      pa=LEAST(30,GREATEST(0,COALESCE(pa,0)+2)),
      hp=LEAST(100,GREATEST(0,COALESCE(hp,0)+10)),
      moral=LEAST(100,GREATEST(0,COALESCE(moral,0)+3)),
      updated_at=now()
    WHERE name=NEW.name;
   DELETE FROM public.locations_actives
    WHERE id=NEW.country||':clinique-privee:'||NEW.current_room||':capitale'
      AND country=NEW.country AND data->>'reservationClinique'='true' AND data->>'locataire'=NEW.name;
  END IF;
 END IF;
 RETURN NEW;
END;$trigger$;

-- 3. Service d'étage des hôtels de Républia, en une seule opération serveur.
CREATE OR REPLACE FUNCTION public.hotel_service_etage_commander()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE moi text := public.mon_personnage(); p record; v_prix integer; v_pay jsonb; v_bonus jsonb; r record;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT id, country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  -- Tarifs de data.js et d'ordres_couts : 150 à La Republica, 50 à l'Hôtel du Port et des Mineurs.
  v_prix := CASE p.current_building WHEN 'hotel-republica' THEN 150 WHEN 'hotel-port' THEN 50 WHEN 'hotel-mineur' THEN 50 END;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'service_indisponible'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.hotel_nuitees n WHERE n.personnage_id = p.id AND n.consommee_le IS NULL
                   AND n.building_id = p.current_building AND n.country = p.country AND n.city = p.current_city) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chambre_non_reservee');
  END IF;
  v_pay := public.payer_ordre_interne(moi, 'service_etage', 0, v_prix);
  IF coalesce((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_pay->>'raison', 'paiement_refuse'));
  END IF;
  UPDATE public.personnages_donnees SET hp = LEAST(100, coalesce(hp, 0) + 10), moral = LEAST(100, coalesce(moral, 0) + 1), updated_at = now()
   WHERE name = moi;
  v_bonus := public.pa_bonus_differe_crediter(moi, 'service_etage_hotel');
  SELECT pa, hp, moral, liquide, arg, bonus_pa_differe INTO r FROM public.personnages_donnees WHERE name = moi;
  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'pa', r.pa, 'hp', r.hp, 'moral', r.moral,
    'liquide', r.liquide, 'arg', r.arg, 'bonus_differe', r.bonus_pa_differe, 'bonus_pa', coalesce((v_bonus->>'montant')::integer, 0));
END $function$;
REVOKE ALL ON FUNCTION public.hotel_service_etage_commander() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hotel_service_etage_commander() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.pa_bonus_differe_crediter(text, text) FROM PUBLIC, anon, authenticated;
