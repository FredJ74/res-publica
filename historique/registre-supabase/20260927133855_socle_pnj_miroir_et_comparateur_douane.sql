-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927133855
-- Nom original      : socle_pnj_miroir_et_comparateur_douane
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 13:38:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2b90ea7add3c1967303183471dbd166e
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
-- LOT 2c — MIROIR ET COMPARATEUR DOUANE (27 septembre 2026)
--
-- Meme discipline que pour les soldats : le blob -- ici la sous-cle `effectifsDouane` de
-- `batiments_etat` -- reste l'autorite, un DECLENCHEUR propage chaque ecriture vers le socle dans
-- la MEME transaction, et un comparateur prouve l'equivalence avant toute bascule.
--
-- POURQUOI UN DECLENCHEUR, encore. Le recrutement, le licenciement et la paye ecrivent tous cette
-- sous-cle. Les retoucher un par un laisse le risque qu'un quatrieme chemin apparaisse. Un
-- declencheur est exhaustif par construction, et son echec annule l'ecriture metier.
--
-- LE PIEGE EVITE, ET IL AURAIT CASSE LA PAYE. Le miroir des soldats SUPPRIME les lignes absentes
-- du blob. Ici c'est impossible : `trg_pnj_garde_suppression` refuse de supprimer un PNJ `actif`,
-- et un douanier retire faute de budget n'est PAS mort -- il quitte le service. Le miroir aurait
-- donc fait echouer la tache de paye nocturne, chaque nuit ou la caisse est vide.
-- On ne supprime donc pas : on marque `disparu`. C'est aussi plus juste -- un depart n'est pas un
-- deces -- et cela garde une trace. Le comparateur ne regarde que les lignes `actif`.

-- ---------------------------------------------------------------------------------------
-- LES VALEURS DU METIER
-- ---------------------------------------------------------------------------------------
-- Arbitrage du concepteur : INT 10, CHA 8, VOL 12, PER 12, DUP 8, ENT 10. PER et VOL reprennent
-- exactement les valeurs historiques des fiches. La fiche reste la source quand elle porte la
-- cle -- meme doctrine que `arme` et `formation` chez les soldats -- et la constante metier ne
-- remplit que ce qu'elle ne dit pas.
CREATE OR REPLACE FUNCTION public.douane_caracteristiques_metier()
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('INT',10,'CHA',8,'VOL',12,'PER',12,'DUP',8,'ENT',10);
$$;

CREATE OR REPLACE FUNCTION public.douane_pnj_id(p_pays text, p_ville text, p_matricule text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT 'douane-' || p_pays || '-' || p_ville || '-' || p_matricule;
$$;

-- ---------------------------------------------------------------------------------------
-- LE MIROIR
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_miroir_douane(
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
  v_liste := v_etat->'effectifsDouane'->'douaniers';
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_def := public.douane_caracteristiques_metier();

  FOR d IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    CONTINUE WHEN COALESCE(d->>'matricule', '') = '';
    v_id := public.douane_pnj_id(p_pays, p_ville, d->>'matricule');
    v_vus := v_vus || v_id;
    v_st := CASE WHEN jsonb_typeof(d->'stats') = 'object' THEN d->'stats' ELSE '{}'::jsonb END;

    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        ville, building_id, room_id, pa, statut,
        car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_id, 'douanier', d->>'matricule', p_pays, 'douane', v_per,
        p_ville, COALESCE(d->>'buildingId', p_batiment), d->>'roomId', 12, 'actif',
        COALESCE((v_st->>'INT')::integer, (v_def->>'INT')::integer),
        COALESCE((v_st->>'CHA')::integer, (v_def->>'CHA')::integer),
        COALESCE((v_st->>'VOL')::integer, (v_def->>'VOL')::integer),
        COALESCE((v_st->>'PER')::integer, (v_def->>'PER')::integer),
        COALESCE((v_st->>'DUP')::integer, (v_def->>'DUP')::integer),
        COALESCE((v_st->>'ENT')::integer, (v_def->>'ENT')::integer))
    ON CONFLICT (id) DO UPDATE SET
        statut = 'actif',
        ville = EXCLUDED.ville, building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
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

  -- DEPART, PAS DECES. On ne supprime pas : la garde le refuserait sur un PNJ actif, et un agent
  -- retire faute de budget n'est pas mort. On le delie et on le marque disparu.
  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL, maj_le = now()
   WHERE famille = 'douanier' AND pays = p_pays AND proprietaire_perimetre = v_per
     AND statut = 'actif' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_partis = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'partis', v_partis);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_miroir_douane_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  -- Ne s'active que sur l'etat qui porte reellement des douaniers.
  IF NEW.building_id = 'port-sainte-marie'
     AND COALESCE(public.batiment_etat_lire(NEW.data), '{}'::jsonb) ? 'effectifsDouane' THEN
    PERFORM public.pnj_miroir_douane(NEW.country, NEW.city, NEW.building_id);
  END IF;
  RETURN NULL;
END; $$;
DROP TRIGGER IF EXISTS trg_pnj_miroir_douane ON public.batiments_etat;
CREATE TRIGGER trg_pnj_miroir_douane AFTER INSERT OR UPDATE ON public.batiments_etat
  FOR EACH ROW EXECUTE FUNCTION public.pnj_miroir_douane_declencheur();

-- ---------------------------------------------------------------------------------------
-- LE COMPARATEUR
-- ---------------------------------------------------------------------------------------
-- Il compare tout ce que le socle pretend porter. Un champ copie mais non compare est un champ
-- qui divergera sans temoin.
CREATE OR REPLACE FUNCTION public.pnj_comparer_douaniers(
  p_pays text, p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_div jsonb; v_nb_blob integer; v_nb_socle integer; v_def jsonb;
        v_per text := p_ville || ':' || p_batiment;
BEGIN
  v_def := public.douane_caracteristiques_metier();
  WITH etat AS (
    SELECT public.batiment_etat_lire(data) AS e FROM public.batiments_etat
     WHERE country = p_pays AND city = p_ville AND building_id = p_batiment
  ), blob AS (
    SELECT d->>'matricule' AS matricule,
           COALESCE(d->>'type', 'standard') AS type_unite,
           COALESCE(d->>'buildingId', p_batiment) AS bat,
           d->>'roomId' AS room,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'INT')::integer, (v_def->>'INT')::integer) AS c_int,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'CHA')::integer, (v_def->>'CHA')::integer) AS c_cha,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'VOL')::integer, (v_def->>'VOL')::integer) AS c_vol,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'PER')::integer, (v_def->>'PER')::integer) AS c_per,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'DUP')::integer, (v_def->>'DUP')::integer) AS c_dup,
           COALESCE((CASE WHEN jsonb_typeof(d->'stats')='object' THEN d->'stats'
                          ELSE '{}'::jsonb END ->>'ENT')::integer, (v_def->>'ENT')::integer) AS c_ent
      FROM etat, jsonb_array_elements(
             CASE WHEN jsonb_typeof(etat.e->'effectifsDouane'->'douaniers')='array'
                  THEN etat.e->'effectifsDouane'->'douaniers' ELSE '[]'::jsonb END) d
     WHERE COALESCE(d->>'matricule','') <> ''
  ), socle AS (
    SELECT fp.matricule, fp.type_unite, m.building_id AS bat, m.room_id AS room,
           m.car_int AS c_int, m.car_cha AS c_cha, m.car_vol AS c_vol,
           m.car_per AS c_per, m.car_dup AS c_dup, m.car_ent AS c_ent,
           m.ville, m.pa, m.proprietaire_pj, m.proprietaire_institution AS institution,
           m.proprietaire_perimetre AS perimetre, m.leader_pj, m.leader_pnj_id, m.liquide,
           public.pnj_classe_de(m.id) AS classe
      FROM public.pnj_membres m
      JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
     WHERE m.famille = 'douanier' AND m.pays = p_pays
       AND m.proprietaire_perimetre = v_per AND m.statut = 'actif'
  ), compare AS (
    SELECT COALESCE(b.matricule, s.matricule) AS matricule,
      CASE
        WHEN s.matricule IS NULL THEN 'absent_du_socle'
        WHEN b.matricule IS NULL THEN 'surnumeraire_dans_le_socle'
        WHEN b.type_unite IS DISTINCT FROM s.type_unite THEN 'type_unite'
        WHEN b.bat   IS DISTINCT FROM s.bat   THEN 'batiment'
        WHEN b.room  IS DISTINCT FROM s.room  THEN 'piece'
        WHEN s.ville IS DISTINCT FROM p_ville THEN 'ville'
        WHEN b.c_int IS DISTINCT FROM s.c_int THEN 'car_int'
        WHEN b.c_cha IS DISTINCT FROM s.c_cha THEN 'car_cha'
        WHEN b.c_vol IS DISTINCT FROM s.c_vol THEN 'car_vol'
        WHEN b.c_per IS DISTINCT FROM s.c_per THEN 'car_per'
        WHEN b.c_dup IS DISTINCT FROM s.c_dup THEN 'car_dup'
        WHEN b.c_ent IS DISTINCT FROM s.c_ent THEN 'car_ent'
        WHEN s.classe IS DISTINCT FROM 'beta'          THEN 'classe'
        WHEN s.pa IS DISTINCT FROM 12                  THEN 'pa'
        WHEN s.proprietaire_pj IS NOT NULL             THEN 'propriete_personnelle_inattendue'
        WHEN s.institution IS DISTINCT FROM 'douane'   THEN 'institution'
        WHEN s.perimetre IS DISTINCT FROM v_per        THEN 'perimetre'
        WHEN s.leader_pj IS NOT NULL OR s.leader_pnj_id IS NOT NULL THEN 'leader_inattendu'
        WHEN COALESCE(s.liquide, 0) <> 0               THEN 'liquide_inattendu'
        ELSE NULL END AS divergence
      FROM blob b FULL OUTER JOIN socle s ON s.matricule = b.matricule
  )
  SELECT (SELECT count(*) FROM blob), (SELECT count(*) FROM socle),
         COALESCE(jsonb_agg(jsonb_build_object('matricule', matricule, 'divergence', divergence)
                            ORDER BY matricule) FILTER (WHERE divergence IS NOT NULL), '[]'::jsonb)
    INTO v_nb_blob, v_nb_socle, v_div FROM compare;

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_div) = 0 AND v_nb_blob = v_nb_socle,
    'nb_blob', v_nb_blob, 'nb_socle', v_nb_socle,
    'correspondances', v_nb_blob - jsonb_array_length(v_div),
    'nb_divergences', jsonb_array_length(v_div), 'details', v_div,
    'observation_partis', (SELECT count(*) FROM public.pnj_membres
       WHERE famille='douanier' AND pays=p_pays AND proprietaire_perimetre=v_per
         AND statut='disparu'));
END; $$;

REVOKE ALL ON FUNCTION public.douane_caracteristiques_metier()            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.douane_pnj_id(text,text,text)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_miroir_douane(text,text,text)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_miroir_douane_declencheur()             FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_comparer_douaniers(text,text,text)      FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_miroir_douane(text,text,text)        TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_comparer_douaniers(text,text,text)   TO service_role;