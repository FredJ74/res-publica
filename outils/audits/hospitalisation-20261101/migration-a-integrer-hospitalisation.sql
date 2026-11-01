-- Hospitalisation à 0 PA (Claude, 01/11/2026) — règles de Fred : GAME-DESIGN-HOSPITALISATION.md.
-- À PLACER APRÈS outils/audits/circuits-residuels-219-20261101/migration-a-integrer-circuits-residuels-positions.sql
-- (#318, elle-même après les 95 migrations de #219). Hors de migrations/ pour la même raison que #318 :
-- ne pas modifier le lot certifié de #219. Idempotente (rejouable).
--
-- Ce que fait ce correctif :
--   1. Déclenchement automatique : tout PJ dont les PA tombent à 0 (ordre payé, combat perdu, peu importe
--      la fonction qui écrit) est hospitalisé au dispensaire de la ville où il se trouve, à la fin de la
--      transaction (déclencheur différé : un PJ arrêté dans la même transaction reste en détention).
--   2. Régime « pa0 » dans personnages_donnees.hospitalisation :
--      {regime:'pa0', lieu, dateDebutParis (= J0), dateFinParis:'9999-12-31' (fin ouverte), repasLe?}
--      La fin ouverte garde TOUS les interdits existants de #219 (navigation, recrutement, police,
--      batailles lisent dateFinParis) jusqu'à la sortie : aucune de ces fonctions n'est retouchée.
--   3. Dormir (pa_repos_nocturne) : refusé à J0 ; J1 +2, J2 +6, J3 et après +12 ; ×3 en clinique ;
--      +2 si le repas de l'hôpital a été pris la veille.
--   4. Repas de l'hôpital : 1 PA, une fois par jour, au dispensaire ou à la clinique.
--   5. Transfert en clinique (dès J0) et SORTIE : par la porte hospitalisation_lieu_rejoindre de #318,
--      étendue (p_lieu = 'sortie'), jamais par une mécanique parallèle. Sortie : J2 au plus tôt et 20 PA.
--   6. Mails et forums refusés à J0 (écrits par le PJ lui-même, y compris au nom d'une organisation).
-- L'empoisonnement garde son propre fonctionnement (dates par palier posées par l'écran) : non touché.

-- 0. Coût de l'ordre « repas_hopital » au miroir (data.js : 1 PA, 0 FR).
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'repas_hopital', 1, 0
WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'repas_hopital' AND pa = 1 AND cost = 0);

-- 1. Jour d'hospitalisation du régime pa0 (0 = jour du transfert). NULL hors de ce régime
--    (aucune hospitalisation, ou empoisonnement et anciens paliers).
CREATE OR REPLACE FUNCTION public.hospitalisation_jour_pa0(h jsonb)
RETURNS integer LANGUAGE plpgsql STABLE SET search_path TO 'public','pg_temp' AS $f$
BEGIN
 IF h IS NULL OR jsonb_typeof(h) <> 'object' OR h->>'regime' IS DISTINCT FROM 'pa0'
 OR coalesce(h->>'dateDebutParis','') !~ '^\d{4}-\d{2}-\d{2}$' THEN RETURN NULL; END IF;
 RETURN (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date - (h->>'dateDebutParis')::date;
END $f$;
REVOKE ALL ON FUNCTION public.hospitalisation_jour_pa0(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospitalisation_jour_pa0(jsonb) TO authenticated, service_role;

-- 2. La porte de #318, rendue utilisable par le serveur pour un PJ donné (déclenchement automatique)
--    et étendue à la sortie. Le corps dispensaire/clinique est celui de #318, paramétré par p_nom.
CREATE OR REPLACE FUNCTION public.hospitalisation_lieu_rejoindre_interne(
 p_nom text, p_lieu text, p_chambre text, p_verifier boolean, p_automatique boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $h$
DECLARE p public.personnages_donnees%ROWTYPE; dispo jsonb; v_ville text; v_bat text;
 v_piece text; paiement jsonb; aujourdhui text; v_pa integer; v_cost integer;
 v_jour integer; v_noeud text; v_rue jsonb;
BEGIN
 -- hospitalisation_porte_interne_v1
 IF p_lieu IS NULL OR p_lieu NOT IN ('dispensaire','clinique','sortie') THEN
  RETURN jsonb_build_object('ok',false,'raison','lieu_invalide'); END IF;
 IF p_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 -- Le transfert automatique survient à la fin d'une transaction qui tient déjà la fiche :
 -- verrou du graphe pris s'il est libre, jamais attendu (pas d'étreinte fatale avec un combat).
 IF p_automatique THEN PERFORM pg_try_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 ELSE PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0)); END IF;
 -- Mêmes interdits que la navigation commune, sauf l'hospitalisation elle-même. L'ambulance du
 -- transfert automatique emporte aussi un PJ intercepté ou sorti d'un combat (jamais un détenu).
 dispo := public.navigation_disponibilite_interne(p_nom);
 IF NOT coalesce((dispo->>'ok')::boolean,false) AND dispo->>'raison' IS DISTINCT FROM 'acteur_incapacite'
 AND NOT (p_automatique AND dispo->>'raison' IN ('interception_en_cours','combat_en_cours')) THEN
  RETURN dispo; END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name = p_nom;
 aujourdhui := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF p.hospitalisation IS NULL OR jsonb_typeof(p.hospitalisation) <> 'object'
 OR coalesce(p.hospitalisation->>'dateFinParis','') <= aujourdhui THEN
  RETURN jsonb_build_object('ok',false,'raison','non_hospitalise'); END IF;

 -- Sortie (règle de Fred, 01/11) : pas avant J2, et seulement à partir de 20 PA.
 IF p_lieu = 'sortie' THEN
  v_jour := public.hospitalisation_jour_pa0(p.hospitalisation);
  IF v_jour IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sortie_par_date'); END IF;
  IF v_jour < 2 THEN RETURN jsonb_build_object('ok',false,'raison','sortie_trop_tot','jour',v_jour); END IF;
  IF coalesce(p.pa,0) < 20 THEN
   RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants_sortie','pa',coalesce(p.pa,0),'seuil',20); END IF;
  SELECT s.noeud INTO v_noeud FROM public.rue_sorties_batiments s
   JOIN public.rue_noeuds_serveur n ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
   WHERE s.country=p.country AND s.city=p.current_city AND s.building=p.current_building
   ORDER BY s.noeud LIMIT 1;
  IF p_verifier THEN RETURN jsonb_build_object('ok',true,'verifie',true,'noeud',v_noeud); END IF;
  BEGIN
   UPDATE public.personnages_donnees SET hospitalisation = NULL, stats_affaiblies = '{}'::jsonb,
          regen_jour = NULL, updated_at = clock_timestamp() WHERE name = p_nom;
   -- Le patient sort par la porte du bâtiment, comme toute sortie à pied (même fonction de rue).
   IF v_noeud IS NOT NULL THEN
    v_rue := public.rue_position_personnage_interne(p_nom, v_noeud, false);
    IF NOT coalesce((v_rue->>'ok')::boolean,false) THEN RAISE EXCEPTION 'hg_sortie_hopital_refusee'; END IF;
   END IF;
  EXCEPTION WHEN raise_exception THEN
   IF SQLERRM <> 'hg_sortie_hopital_refusee' THEN RAISE; END IF;
   RETURN v_rue;            -- rien n'est écrit : hospitalisation et position restent
  END;
  -- La chambre de clinique est rendue à la sortie réelle, et seulement là.
  DELETE FROM public.locations_actives loc WHERE loc.data->>'buildingId' = 'clinique-privee'
     AND loc.data->>'chambreClinique' = 'true' AND loc.data->>'locataire' = p_nom;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = p_nom;
  RETURN jsonb_build_object('ok',true,'sortie',true,'country',p.country,'city',p.current_city,
    'building',p.current_building,'room',p.current_room,'street',p.current_street,'pa',p.pa);
 END IF;

 IF p_lieu = 'dispensaire' AND p.hospitalisation->>'lieu' IS DISTINCT FROM 'dispensaire' THEN
  RETURN jsonb_build_object('ok',false,'raison','lieu_non_prescrit'); END IF;
 IF p_lieu = 'clinique' THEN
  v_ville := 'capitale'; v_bat := 'clinique-privee';
  v_piece := coalesce(p_chambre, 'reception_clinique');
  IF p_chambre IS NOT NULL AND NOT (p_chambre ~ '^chambre_([1-9]|10)$' AND EXISTS(
     SELECT 1 FROM public.locations_actives loc WHERE loc.country = p.country
      AND loc.data->>'buildingId' = 'clinique-privee' AND loc.data->>'roomId' = p_chambre
      AND loc.data->>'city' = 'capitale' AND loc.data->>'locataire' = p_nom)) THEN
   RETURN jsonb_build_object('ok',false,'raison','chambre_non_attribuee'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays = p.country AND ville = v_ville
     AND batiment = v_bat AND pieces ? v_piece) THEN
   RETURN jsonb_build_object('ok',false,'raison','lieu_non_reference'); END IF;
 ELSE
  v_ville := p.current_city;
  SELECT batiment, pieces->>0 INTO v_bat, v_piece FROM public.navigation_lieux_regles
   WHERE pays = p.country AND ville = v_ville AND batiment LIKE 'dispensaire-public%'
   ORDER BY batiment LIMIT 1;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','lieu_non_reference'); END IF;
 END IF;
 IF p_verifier THEN
  RETURN jsonb_build_object('ok',true,'verifie',true,'country',p.country,'city',v_ville,'building',v_bat,'room',v_piece);
 END IF;
 -- Le transfert en clinique est payé dans la même transaction que le déplacement.
 IF p_lieu = 'clinique' AND p.hospitalisation->>'lieu' IS DISTINCT FROM 'clinique' THEN
  -- Tarif lu au miroir des coûts (data.js), jamais reçu du navigateur.
  SELECT pa, cost INTO v_pa, v_cost FROM public.ordres_couts WHERE fn = 'transfert_clinique_privee'
   ORDER BY cost DESC LIMIT 1;
  paiement := public.payer_ordre_interne(p_nom, 'transfert_clinique_privee', coalesce(v_pa,0), coalesce(v_cost,0));
  IF NOT coalesce((paiement->>'ok')::boolean,false) THEN RETURN paiement; END IF;
 END IF;
 -- Le patient quitte son groupe (même règle que groupe_pj_quitter) ; ses PNJ le suivent.
 DELETE FROM public.groupes_pj_adhesions WHERE membre = p_nom OR chef = p_nom;
 UPDATE public.personnages_donnees SET current_city = v_ville, current_building = v_bat,
        current_room = v_piece, current_street = NULL,
        hospitalisation = jsonb_set(hospitalisation, '{lieu}', to_jsonb(p_lieu)),
        updated_at = clock_timestamp()
  WHERE name = p_nom;
 RETURN jsonb_build_object('ok',true,'country',p.country,'city',v_ville,'building',v_bat,'room',v_piece,
   'paiement', paiement);
END $h$;
REVOKE ALL ON FUNCTION public.hospitalisation_lieu_rejoindre_interne(text,text,text,boolean,boolean)
 FROM PUBLIC, anon, authenticated, service_role;

-- Porte réseau de #318 : même signature, mêmes droits ; le patient est toujours l'appelant.
CREATE OR REPLACE FUNCTION public.hospitalisation_lieu_rejoindre(
 p_lieu text, p_chambre text DEFAULT NULL, p_verifier boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $h$
BEGIN
 -- hospitalisation_porte_sortie_v1
 RETURN public.hospitalisation_lieu_rejoindre_interne(public.mon_personnage(), p_lieu, p_chambre,
   coalesce(p_verifier,false), false);
END $h$;
REVOKE ALL ON FUNCTION public.hospitalisation_lieu_rejoindre(text,text,boolean) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.hospitalisation_lieu_rejoindre(text,text,boolean) TO authenticated;

-- 3. Déclenchement automatique à 0 PA, quelle que soit la fonction qui a consommé les PA.
--    Différé à la fin de la transaction : on juge l'état final (PA rendus entre-temps, arrestation
--    posée après le combat). Ne fait jamais échouer l'ordre ou le combat qui l'a provoqué.
CREATE OR REPLACE FUNCTION public.hospitalisation_pa_epuises_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $t$
DECLARE p public.personnages_donnees%ROWTYPE; r jsonb; aujourdhui date;
BEGIN
 BEGIN
  SELECT * INTO p FROM public.personnages_donnees WHERE id = NEW.id FOR UPDATE;
  IF NOT FOUND OR coalesce(p.pa,0) <> 0 THEN RETURN NULL; END IF;
  -- La détention l'emporte : un PJ arrêté (même au terme du combat) reste sous écrou.
  IF (p.est_emprisonne IS NOT NULL AND p.est_emprisonne <> 'null'::jsonb)
  OR (jsonb_typeof(p.detention_qhs) = 'object' AND (p.detention_qhs->>'enQHS')::boolean IS TRUE) THEN
   RETURN NULL; END IF;
  aujourdhui := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
  -- Déjà hospitalisé (régime pa0, empoisonnement, ancien palier) : rien de plus.
  IF coalesce(p.hospitalisation->>'dateFinParis','') > aujourdhui::text
  OR (CASE WHEN coalesce(p.hospitalisation->>'jourFin','') ~ '^[0-9]+$'
      THEN (p.hospitalisation->>'jourFin')::numeric > coalesce(p.day,1) ELSE false END) THEN
   RETURN NULL; END IF;
  UPDATE public.personnages_donnees SET hospitalisation = jsonb_build_object(
     'regime','pa0','lieu','dispensaire','dateDebutParis',aujourdhui::text,'dateFinParis','9999-12-31'),
     updated_at = clock_timestamp()
   WHERE id = p.id;
  r := public.hospitalisation_lieu_rejoindre_interne(p.name, 'dispensaire', NULL, false, true);
  -- Pas de dispensaire référencé ici (ou autre refus) : hospitalisé sur place, immobilisé, motif noté.
  IF NOT coalesce((r->>'ok')::boolean,false) THEN
   UPDATE public.personnages_donnees
      SET hospitalisation = hospitalisation || jsonb_build_object('transfert', coalesce(r->>'raison','refus'))
    WHERE id = p.id;
  END IF;
 EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'hospitalisation_pa_epuises: % (%)', SQLERRM, NEW.name;
 END;
 RETURN NULL;
END $t$;
REVOKE ALL ON FUNCTION public.hospitalisation_pa_epuises_declencheur() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_hospitalisation_pa_epuises ON public.personnages_donnees;
CREATE CONSTRAINT TRIGGER trg_hospitalisation_pa_epuises
 AFTER UPDATE OF pa ON public.personnages_donnees
 DEFERRABLE INITIALLY DEFERRED
 FOR EACH ROW WHEN (NEW.pa = 0 AND coalesce(OLD.pa,0) > 0)
 EXECUTE FUNCTION public.hospitalisation_pa_epuises_declencheur();

-- 4. Dormir à l'hôpital (patch en place de pa_repos_nocturne, fragments exacts, idempotent).
DO $repos$
DECLARE s text; a text; b text;
BEGIN
 s := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
 IF position('-- hospitalisation_pa0_repos_v1' IN s) > 0 THEN RETURN; END IF;
 a := '  v_caserne boolean; v_tente boolean; v_grade text; v_gain integer;';
 b := a || chr(10) || '  v_hosp jsonb; v_j integer; v_repas integer;';
 IF position(a IN s) = 0 THEN RAISE EXCEPTION 'pa_repos_nocturne: fragment DECLARE introuvable'; END IF;
 s := replace(s, a, b);
 a := '  IF v_qhs IS NOT NULL AND jsonb_typeof(v_qhs) = ''object'' AND (v_qhs ->> ''enQHS'')::boolean IS TRUE THEN';
 IF position(a IN s) = 0 THEN RAISE EXCEPTION 'pa_repos_nocturne: fragment QHS introuvable'; END IF;
 b := '  -- hospitalisation_pa0_repos_v1 (GAME-DESIGN-HOSPITALISATION.md, Fred 01/11/2026)' || chr(10)
   || '  SELECT hospitalisation INTO v_hosp FROM public.personnages_donnees WHERE name = p_acteur;' || chr(10)
   || '  v_j := public.hospitalisation_jour_pa0(v_hosp);' || chr(10)
   || '  IF v_j IS NOT NULL THEN' || chr(10)
   || '    IF v_j <= 0 THEN' || chr(10)
   || '      RETURN jsonb_build_object(''ok'', false, ''raison'', ''hospitalise_j0'', ''pa'', v_pa);' || chr(10)
   || '    END IF;' || chr(10)
   || '    v_gain := (CASE v_j WHEN 1 THEN 2 WHEN 2 THEN 6 ELSE 12 END)' || chr(10)
   || '            * (CASE WHEN v_hosp ->> ''lieu'' = ''clinique'' THEN 3 ELSE 1 END);' || chr(10)
   || '    v_repas := CASE WHEN v_hosp ->> ''repasLe'' = (v_jour - 1)::text THEN 2 ELSE 0 END;' || chr(10)
   || '    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_repas + v_bonus));' || chr(10)
   || '    UPDATE public.personnages_donnees' || chr(10)
   || '       SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour' || chr(10)
   || '     WHERE name = p_acteur;' || chr(10)
   || '    RETURN jsonb_build_object(''ok'', true, ''pa'', v_nouveau, ''bonus_consomme'', v_bonus,' || chr(10)
   || '      ''qhs'', false, ''hospitalisation'', true, ''jour_hospitalisation'', v_j,' || chr(10)
   || '      ''lieu'', v_hosp ->> ''lieu'', ''gain'', v_gain, ''repas'', v_repas,' || chr(10)
   || '      ''sortie_possible'', v_j >= 2 AND v_nouveau >= 20);' || chr(10)
   || '  END IF;' || chr(10) || chr(10) || a;
 s := replace(s, a, b);
 EXECUTE s;
END $repos$;

-- 5. Repas de l'hôpital : 1 PA (miroir), une fois par jour, au dispensaire ou à la clinique ;
--    +2 PA au Dormir du lendemain (lu par pa_repos_nocturne).
CREATE OR REPLACE FUNCTION public.hospitalisation_repas_prendre()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $r$
DECLARE moi text; p public.personnages_donnees%ROWTYPE; v_j integer; aujourdhui text;
 v_pa integer; v_cost integer; paiement jsonb;
BEGIN
 moi := public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
 v_j := public.hospitalisation_jour_pa0(p.hospitalisation);
 IF v_j IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_hospitalise'); END IF;
 IF coalesce(p.current_building,'') NOT LIKE 'dispensaire-public%' AND p.current_building IS DISTINCT FROM 'clinique-privee' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_a_l_hopital'); END IF;
 aujourdhui := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF p.hospitalisation->>'repasLe' = aujourdhui THEN
  RETURN jsonb_build_object('ok',false,'raison','repas_deja_pris'); END IF;
 SELECT pa, cost INTO v_pa, v_cost FROM public.ordres_couts WHERE fn = 'repas_hopital' ORDER BY pa DESC LIMIT 1;
 paiement := public.payer_ordre_interne(moi, 'repas_hopital', coalesce(v_pa,1), coalesce(v_cost,0));
 IF NOT coalesce((paiement->>'ok')::boolean,false) THEN RETURN paiement; END IF;
 UPDATE public.personnages_donnees
    SET hospitalisation = hospitalisation || jsonb_build_object('repasLe', aujourdhui)
  WHERE name = moi RETURNING pa INTO v_pa;
 RETURN jsonb_build_object('ok',true,'pa',v_pa,'bonus_lendemain',2,'jour',v_j);
END $r$;
REVOKE ALL ON FUNCTION public.hospitalisation_repas_prendre() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.hospitalisation_repas_prendre() TO authenticated;

-- 6. Mails et forums interdits à J0 : refus nommé à l'écriture, pour tout ce que le PJ écrit
--    lui-même (à son nom ou au nom d'une organisation). Les avis institutionnels qu'il reçoit passent.
CREATE OR REPLACE FUNCTION public.hospitalisation_ecriture_j0_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; v_auteur boolean; v_hosp jsonb;
BEGIN
 IF public.est_appel_serveur() THEN RETURN NEW; END IF;
 moi := public.mon_personnage();
 IF moi IS NULL THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME = 'mails' THEN
  v_auteur := NEW.from_player = moi OR NEW.from_real = moi;
 ELSE
  v_auteur := NEW.author = moi OR NEW.author_real = moi;
 END IF;
 IF NOT coalesce(v_auteur,false) THEN RETURN NEW; END IF;
 SELECT hospitalisation INTO v_hosp FROM public.personnages_donnees WHERE name = moi;
 IF public.hospitalisation_jour_pa0(v_hosp) = 0 THEN
  RAISE EXCEPTION 'hospitalise_j0: pas de mail ni de forum le jour de l''hospitalisation'
   USING ERRCODE = '42501';
 END IF;
 RETURN NEW;
END $g$;
REVOKE ALL ON FUNCTION public.hospitalisation_ecriture_j0_garder() FROM PUBLIC, anon, authenticated, service_role;
DROP TRIGGER IF EXISTS trg_hospitalisation_ecriture_j0 ON public.mails;
CREATE TRIGGER trg_hospitalisation_ecriture_j0 BEFORE INSERT ON public.mails
 FOR EACH ROW EXECUTE FUNCTION public.hospitalisation_ecriture_j0_garder();
DROP TRIGGER IF EXISTS trg_hospitalisation_ecriture_j0 ON public.forum_topics;
CREATE TRIGGER trg_hospitalisation_ecriture_j0 BEFORE INSERT ON public.forum_topics
 FOR EACH ROW EXECUTE FUNCTION public.hospitalisation_ecriture_j0_garder();
DROP TRIGGER IF EXISTS trg_hospitalisation_ecriture_j0 ON public.forum_posts;
CREATE TRIGGER trg_hospitalisation_ecriture_j0 BEFORE INSERT ON public.forum_posts
 FOR EACH ROW EXECUTE FUNCTION public.hospitalisation_ecriture_j0_garder();

DO $verification$
BEGIN
 IF position('-- hospitalisation_pa0_repos_v1' IN pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) = 0
 OR position('-- hospitalisation_porte_sortie_v1' IN pg_get_functiondef('public.hospitalisation_lieu_rejoindre(text,text,boolean)'::regprocedure)) = 0
 OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_hospitalisation_pa_epuises'
                AND tgrelid = 'public.personnages_donnees'::regclass)
 OR (SELECT count(*) FROM pg_trigger WHERE tgname = 'trg_hospitalisation_ecriture_j0') <> 3 THEN
  RAISE EXCEPTION 'hospitalisation_incomplete';
 END IF;
END $verification$;
