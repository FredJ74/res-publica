-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927135448
-- Nom original      : socle_pnj_miroir_et_comparateur_police
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 13:54:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c9d6ddcf28f139a0fbde852ad70ec863
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LOT 3b — MIROIR ET COMPARATEUR POLICE, ET LA LISTE BLANCHE ELARGIE (27 septembre 2026)
--
-- Le lot 2 avait elargi la liste blanche des caracteristiques aux six POUR LA DOUANE SEULEMENT,
-- parce qu'il ne devait pas toucher la police. La police entrant maintenant dans le socle avec
-- les six, la distinction n'a plus de raison d'etre : les deux branches partagent le referentiel.
CREATE OR REPLACE FUNCTION public.batiment_etat_sous_cle_ecrire(
  p_pays text, p_ville text, p_batiment text, p_sous_cle text, p_valeur jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_id text; v_serveur boolean; v_poste jsonb; v_moi text;
  v_data jsonb; v_etat jsonb; v_mauvaise text; v_el jsonb; v_sous jsonb; v_n numeric;
BEGIN
  IF p_pays IS NULL OR p_ville IS NULL OR p_batiment IS NULL OR p_sous_cle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'arguments_manquants');
  END IF;
  v_id := p_pays || '_' || p_ville || '_' || p_batiment;
  v_serveur := public.est_appel_serveur();

  IF p_sous_cle NOT IN ('blocus','effectifsPolice','effectifsDouane','candidatures',
                        'parCaisse','controles','offres') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sous_cle_non_autorisee');
  END IF;

  v_mauvaise := public.jsonb_cle_economique_presente(p_valeur);
  IF v_mauvaise IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_economique_interdite', 'cle', v_mauvaise);
  END IF;

  IF NOT v_serveur THEN
    SELECT p.name, p.poste INTO v_moi, v_poste
    FROM public.personnages_donnees p WHERE p.user_id = auth.uid() LIMIT 1;
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;

    IF p_sous_cle = 'effectifsPolice' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'commissaire'
         OR (v_poste->>'city') IS DISTINCT FROM p_ville
         OR p_batiment NOT IN ('commissariat','commissariat-local') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'effectifsDouane' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'chef_douanes'
         OR p_ville <> 'ville_a' OR p_batiment <> 'port-sainte-marie' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'controles' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'chef_douanes'
         OR v_id <> 'global_national_dissimulation-fret' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'parCaisse' THEN
      IF v_id <> 'global_national_dissimulation-fret' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    ELSIF p_sous_cle = 'candidatures' THEN
      IF p_ville <> 'national' OR p_batiment <> 'candidatures_postes' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    ELSIF p_sous_cle = 'offres' THEN
      IF p_ville <> 'national' OR p_batiment <> 'bne' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    END IF;
  END IF;

  IF p_sous_cle IN ('effectifsPolice','effectifsDouane') THEN
    IF jsonb_typeof(p_valeur) <> 'object'
       OR public.jsonb_cles_hors_liste(p_valeur,
            ARRAY['policiers','douaniers','dernierPaiementJour']) IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    v_sous := COALESCE(p_valeur->'policiers', p_valeur->'douaniers');
    IF v_sous IS NOT NULL THEN
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 200 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['matricule','type','maitreNom','chienNom',
                'stats','buildingId','roomId','rueNoeudId','recruteLe']) IS NOT NULL
           OR COALESCE(v_el->>'type', 'standard') NOT IN ('standard','cynophile') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
        IF v_el ? 'stats' THEN
          -- LES SIX, pour la police comme pour la douane.
          IF jsonb_typeof(v_el->'stats') <> 'object'
             OR public.jsonb_cles_hors_liste(v_el->'stats',
                  public.pnj_caracteristiques_cles()) IS NOT NULL THEN
            RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
          END IF;
          FOR v_n IN SELECT (value#>>'{}')::numeric FROM jsonb_each(v_el->'stats') LOOP
            IF v_n < 0 OR v_n > 100 THEN
              RETURN jsonb_build_object('ok', false, 'raison', 'stat_hors_bornes');
            END IF;
          END LOOP;
        END IF;
      END LOOP;
    END IF;

  ELSIF p_sous_cle = 'blocus' THEN
    IF jsonb_typeof(p_valeur) NOT IN ('null','object') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    IF jsonb_typeof(p_valeur) = 'object' THEN
      IF public.jsonb_cles_hors_liste(p_valeur, ARRAY['syndicatId','syndicatNom','revendication',
           'nbMilitants','intensite','leaderActuel','lanceLe',
           'dernierRenouvellementTimestamp']) IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      IF COALESCE((p_valeur->>'intensite')::numeric, 0) < 0
         OR COALESCE((p_valeur->>'intensite')::numeric, 0) > 100
         OR COALESCE((p_valeur->>'nbMilitants')::numeric, 0) < 0
         OR COALESCE((p_valeur->>'nbMilitants')::numeric, 0) > 10000 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'valeur_hors_bornes');
      END IF;
      IF NOT v_serveur THEN
        p_valeur := jsonb_set(p_valeur, '{leaderActuel}', to_jsonb(v_moi));
      END IF;
    END IF;

  ELSIF p_sous_cle = 'parCaisse' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_el IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_el) <> 'number' OR (v_el#>>'{}')::numeric < 0
         OR (v_el#>>'{}')::numeric > 100 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'valeur_hors_bornes');
      END IF;
    END LOOP;

  ELSIF p_sous_cle = 'controles' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_el IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_el) <> 'object'
         OR public.jsonb_cles_hors_liste(v_el, ARRAY['resultat','controleeLe']) IS NOT NULL
         OR COALESCE(v_el->>'resultat', '') NOT IN ('positif','negatif') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
    END LOOP;

  ELSIF p_sous_cle = 'offres' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_sous IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 100 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['pjNom','statut']) IS NOT NULL
           OR COALESCE(v_el->>'statut', '') NOT IN ('actif','en_attente_arbitrage') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
      END LOOP;
    END LOOP;

  ELSIF p_sous_cle = 'candidatures' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_sous IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_sous) <> 'object'
         OR public.jsonb_cles_hors_liste(v_sous, ARRAY['posteId','city','candidats',
              'echeanceTs','autoriteNom','traitee']) IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      IF v_sous ? 'candidats' AND jsonb_typeof(v_sous->'candidats') <> 'array' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
    END LOOP;
  END IF;

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.batiments_etat (id, country, city, building_id, data)
    VALUES (v_id, p_pays, p_ville, p_batiment,
            to_jsonb(jsonb_build_object(p_sous_cle, p_valeur)::text));
    RETURN jsonb_build_object('ok', true, 'valeur', p_valeur);
  END IF;

  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_etat := jsonb_set(v_etat, ARRAY[p_sous_cle], p_valeur, true);

  UPDATE public.batiments_etat
     SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'valeur', p_valeur);
END; $$;

-- ---------------------------------------------------------------------------------------
-- LE MIROIR POLICE
-- ---------------------------------------------------------------------------------------
-- Difference avec la douane : la position d'un policier a TROIS formes -- une piece
-- (buildingId + roomId), un noeud de rue (rueNoeudId), ou rien du tout (disponible au
-- commissariat). On recopie les trois telles quelles, sans les interpreter : le socle porte ce
-- que la fiche dit, et le comparateur verifie les quatre champs.
-- Comme pour la douane, un agent retire faute de budget est marque `disparu`, jamais supprime :
-- la garde refuserait la suppression d'un PNJ actif et ferait echouer la paye.
CREATE OR REPLACE FUNCTION public.pnj_miroir_police(
  p_pays text, p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_etat jsonb; v_liste jsonb; d jsonb; v_id text; v_vus text[] := '{}';
  v_maj integer := 0; v_partis integer := 0; v_st jsonb; v_def jsonb;
  v_per text := p_ville || ':' || p_batiment;
BEGIN
  SELECT public.batiment_etat_lire(data) INTO v_etat
    FROM public.batiments_etat
   WHERE country = p_pays AND city = p_ville AND building_id = p_batiment;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etat_introuvable'); END IF;
  v_liste := v_etat->'effectifsPolice'->'policiers';
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_def := public.police_caracteristiques_metier();

  FOR d IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    CONTINUE WHEN COALESCE(d->>'matricule', '') = '';
    v_id := public.police_pnj_id(p_pays, p_ville, d->>'matricule');
    v_vus := v_vus || v_id;
    v_st := CASE WHEN jsonb_typeof(d->'stats') = 'object' THEN d->'stats' ELSE '{}'::jsonb END;

    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        ville, building_id, room_id, rue_noeud_id, pa, statut,
        car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_id, 'policier', d->>'matricule', p_pays, 'police', v_per,
        p_ville, d->>'buildingId', d->>'roomId', d->>'rueNoeudId', 12, 'actif',
        COALESCE((v_st->>'INT')::integer, (v_def->>'INT')::integer),
        COALESCE((v_st->>'CHA')::integer, (v_def->>'CHA')::integer),
        COALESCE((v_st->>'VOL')::integer, (v_def->>'VOL')::integer),
        COALESCE((v_st->>'PER')::integer, (v_def->>'PER')::integer),
        COALESCE((v_st->>'DUP')::integer, (v_def->>'DUP')::integer),
        COALESCE((v_st->>'ENT')::integer, (v_def->>'ENT')::integer))
    ON CONFLICT (id) DO UPDATE SET
        statut = 'actif',
        ville = EXCLUDED.ville, building_id = EXCLUDED.building_id,
        room_id = EXCLUDED.room_id, rue_noeud_id = EXCLUDED.rue_noeud_id,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
        car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
        maj_le = now();

    INSERT INTO public.pnj_force_publique_metier
        (pnj_id, matricule, type_unite, maitre_nom, chien_nom, recrute_le)
    VALUES (v_id, d->>'matricule', COALESCE(d->>'type', 'standard'),
            d->>'maitreNom', d->>'chienNom',
            COALESCE(to_timestamp(NULLIF(d->>'recruteLe','')::numeric / 1000.0), now()))
    ON CONFLICT (pnj_id) DO UPDATE SET
        matricule = EXCLUDED.matricule, type_unite = EXCLUDED.type_unite,
        maitre_nom = EXCLUDED.maitre_nom, chien_nom = EXCLUDED.chien_nom;
    v_maj := v_maj + 1;
  END LOOP;

  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL, maj_le = now()
   WHERE famille = 'policier' AND pays = p_pays AND proprietaire_perimetre = v_per
     AND statut = 'actif' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_partis = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'partis', v_partis);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_miroir_police_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NEW.building_id IN ('commissariat','commissariat-local')
     AND COALESCE(public.batiment_etat_lire(NEW.data), '{}'::jsonb) ? 'effectifsPolice' THEN
    PERFORM public.pnj_miroir_police(NEW.country, NEW.city, NEW.building_id);
  END IF;
  RETURN NULL;
END; $$;
DROP TRIGGER IF EXISTS trg_pnj_miroir_police ON public.batiments_etat;
CREATE TRIGGER trg_pnj_miroir_police AFTER INSERT OR UPDATE ON public.batiments_etat
  FOR EACH ROW EXECUTE FUNCTION public.pnj_miroir_police_declencheur();

-- ---------------------------------------------------------------------------------------
-- LE COMPARATEUR
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_comparer_policiers(
  p_pays text, p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer; v_def jsonb;
        v_per text := p_ville || ':' || p_batiment;
BEGIN
  v_def := public.police_caracteristiques_metier();
  WITH etat AS (
    SELECT public.batiment_etat_lire(data) AS e FROM public.batiments_etat
     WHERE country = p_pays AND city = p_ville AND building_id = p_batiment
  ), st AS (
    SELECT d->>'matricule' AS matricule,
           COALESCE(d->>'type','standard') AS type_unite,
           d->>'buildingId' AS bat, d->>'roomId' AS room, d->>'rueNoeudId' AS rue,
           CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats' ELSE '{}'::jsonb END AS s
      FROM etat, jsonb_array_elements(
             CASE WHEN jsonb_typeof(etat.e->'effectifsPolice'->'policiers')='array'
                  THEN etat.e->'effectifsPolice'->'policiers' ELSE '[]'::jsonb END) d
     WHERE COALESCE(d->>'matricule','') <> ''
  ), blob AS (
    SELECT matricule, type_unite, bat, room, rue,
           COALESCE((s->>'INT')::integer, (v_def->>'INT')::integer) AS c_int,
           COALESCE((s->>'CHA')::integer, (v_def->>'CHA')::integer) AS c_cha,
           COALESCE((s->>'VOL')::integer, (v_def->>'VOL')::integer) AS c_vol,
           COALESCE((s->>'PER')::integer, (v_def->>'PER')::integer) AS c_per,
           COALESCE((s->>'DUP')::integer, (v_def->>'DUP')::integer) AS c_dup,
           COALESCE((s->>'ENT')::integer, (v_def->>'ENT')::integer) AS c_ent
      FROM st
  ), socle AS (
    SELECT fp.matricule, fp.type_unite, m.building_id AS bat, m.room_id AS room,
           m.rue_noeud_id AS rue,
           m.car_int AS c_int, m.car_cha AS c_cha, m.car_vol AS c_vol,
           m.car_per AS c_per, m.car_dup AS c_dup, m.car_ent AS c_ent,
           m.ville, m.pa, m.proprietaire_pj, m.proprietaire_institution AS institution,
           m.proprietaire_perimetre AS perimetre, m.leader_pj, m.leader_pnj_id, m.liquide,
           public.pnj_classe_de(m.id) AS classe
      FROM public.pnj_membres m
      JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
     WHERE m.famille = 'policier' AND m.pays = p_pays
       AND m.proprietaire_perimetre = v_per AND m.statut = 'actif'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.type_unite IS DISTINCT FROM s.type_unite THEN 'type_unite'
        WHEN b.bat  IS DISTINCT FROM s.bat  THEN 'batiment'
        WHEN b.room IS DISTINCT FROM s.room THEN 'piece'
        WHEN b.rue  IS DISTINCT FROM s.rue  THEN 'noeud_de_rue'
        WHEN s.ville IS DISTINCT FROM p_ville THEN 'ville'
        WHEN b.c_int IS DISTINCT FROM s.c_int THEN 'car_int'
        WHEN b.c_cha IS DISTINCT FROM s.c_cha THEN 'car_cha'
        WHEN b.c_vol IS DISTINCT FROM s.c_vol THEN 'car_vol'
        WHEN b.c_per IS DISTINCT FROM s.c_per THEN 'car_per'
        WHEN b.c_dup IS DISTINCT FROM s.c_dup THEN 'car_dup'
        WHEN b.c_ent IS DISTINCT FROM s.c_ent THEN 'car_ent'
        WHEN s.classe IS DISTINCT FROM 'beta'         THEN 'classe'
        WHEN s.pa IS DISTINCT FROM 12                 THEN 'pa'
        WHEN s.proprietaire_pj IS NOT NULL            THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'police'  THEN 'institution'
        WHEN s.perimetre IS DISTINCT FROM v_per       THEN 'perimetre'
        WHEN s.leader_pj IS NOT NULL OR s.leader_pnj_id IS NOT NULL THEN 'leader_inattendu'
        WHEN COALESCE(s.liquide, 0) <> 0              THEN 'liquide_inattendu'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'ville', p_ville, 'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div), 'details', v_div,
    'observation_partis', (SELECT count(*) FROM public.pnj_membres
       WHERE famille='policier' AND pays=p_pays AND proprietaire_perimetre=v_per
         AND statut='disparu'));
END; $$;

REVOKE ALL ON FUNCTION public.pnj_miroir_police(text,text,text)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_miroir_police_declencheur()           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_comparer_policiers(text,text,text)    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_miroir_police(text,text,text)      TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_comparer_policiers(text,text,text) TO service_role;