-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927011353
-- Nom original      : socle_pnj_raccordement_autorite_militaire
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 01:13:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3984f75aa294cb5c947263eec53df8f7
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
-- RACCORDEMENT DU METIER MILITAIRE A LA RESOLUTION D'AUTORITE (27 septembre 2026)
--
-- La migration precedente a pose le mecanisme ; celle-ci le branche et met a jour les douze
-- fonctions qui parlaient encore l'ancien langage (`proprietaire_poste`, `pnj_peut_commander`).

-- ---------------------------------------------------------------------------------------
-- 1. LES EVENEMENTS SUIVENT LE MEME MODELE DE PROPRIETE
-- ---------------------------------------------------------------------------------------
ALTER TABLE public.pnj_evenements
  ADD COLUMN IF NOT EXISTS proprietaire_institution text,
  ADD COLUMN IF NOT EXISTS proprietaire_perimetre   text;
ALTER TABLE public.pnj_evenements
  DROP COLUMN IF EXISTS proprietaire_poste,
  DROP COLUMN IF EXISTS proprietaire_poste_ville;

-- ---------------------------------------------------------------------------------------
-- 2. LA RESOLUTION, EN DEUX ETAGES
-- ---------------------------------------------------------------------------------------
-- Etage bas : resoudre un PERIMETRE. Utile aussi aux evenements, qui portent un perimetre
-- mais pas de PNJ vivant.
CREATE OR REPLACE FUNCTION public.pnj_autorite_de_perimetre(
  p_pays text, p_institution text, p_perimetre text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_res text; v_nom text;
BEGIN
  IF p_institution IS NULL OR p_perimetre IS NULL THEN RETURN NULL; END IF;
  SELECT resolveur INTO v_res FROM public.pnj_institutions WHERE institution = p_institution;
  IF v_res IS NULL THEN RETURN NULL; END IF;      -- institution non enregistree : personne.
  EXECUTE format('SELECT %I($1, $2)', v_res) INTO v_nom USING p_pays, p_perimetre;
  RETURN v_nom;                                    -- NULL legitime : aucune autorite humaine.
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_autorite_de(p_pnj_id text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN m.proprietaire_pj IS NOT NULL THEN m.proprietaire_pj
              ELSE public.pnj_autorite_de_perimetre(
                     m.pays, m.proprietaire_institution, m.proprietaire_perimetre) END
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$$;

-- ---------------------------------------------------------------------------------------
-- 3. LE RESOLVEUR MILITAIRE -- le seul endroit ou le mot « lieutenant » a le droit d'exister.
-- ---------------------------------------------------------------------------------------
-- Il REPRODUIT la porte historique militaire_section_de_moi, sans la durcir ni l'elargir :
--   autorite sur une section = `section.lieutenantNom`, dans la compagnie du bon pays.
-- Volontairement, PAS de controle du poste porte par le personnage : la porte historique ne le
-- fait pas non plus, et la demission/destitution vide `lieutenantNom`. Ajouter un controle ici
-- serait inventer une regle. Une chaine vide vaut vacance, comme dans
-- militaire_engagement_affecter_section qui teste coalesce(s->>'lieutenantNom','') = ''.
--
-- LA RESERVE N'A PAS D'AUTORITE. Aucun Lieutenant, aucun Capitaine ne l'administre en
-- permanence. Le Capitaine dispose bien d'UNE operation metier sur elle
-- (militaire_engagement_affecter_section, qui vide la reserve dans une section neuve) : c'est
-- une transition autorisee, PAS une autorite generique, et elle reste ou elle est.
CREATE OR REPLACE FUNCTION public.militaire_autorite_de_perimetre(p_pays text, p_perimetre text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text;
BEGIN
  IF p_perimetre LIKE '%:reserve' THEN RETURN NULL; END IF;
  SELECT s->>'lieutenantNom' INTO v_nom
    FROM public.compagnies_militaires c,
         jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) s
   WHERE c.data->>'pays' = p_pays AND s->>'id' = p_perimetre
   LIMIT 1;
  RETURN NULLIF(btrim(COALESCE(v_nom, '')), '');
END; $$;

INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES
  ('militaire', 'militaire_autorite_de_perimetre',
   'Perimetre = identifiant de section (autorite : son lieutenantNom) ou <compagnieId>:reserve '
   '(aucune autorite : la reserve n''est administree par personne).')
ON CONFLICT (institution) DO UPDATE SET resolveur = EXCLUDED.resolveur, note = EXCLUDED.note;

-- ---------------------------------------------------------------------------------------
-- 4. LA CO-PRESENCE PHYSIQUE, primitive generique
-- ---------------------------------------------------------------------------------------
-- Consulter, donner, retirer exigent que les deux corps soient au meme endroit. La comparaison
-- brute qui existait dans pnj_prendre ne voyait JAMAIS un PNJ en rue comme co-present : la
-- position de rue s'encode building='rue-centrale', room=<noeudId>, et pnj_position_effective
-- la rend sous la forme (building_id NULL, rue_noeud_id renseigne). On normalise donc les deux
-- cotes avant de comparer, exactement comme pnj_mourir le fait deja pour deposer au sol.
CREATE OR REPLACE FUNCTION public.pnj_co_present(p_moi text, p_pnj_id text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a record; pe record; v_b text; v_r text;
BEGIN
  IF p_moi IS NULL THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_moi;
  IF a.current_city IS NULL THEN RETURN false; END IF;
  SELECT * INTO pe FROM public.pnj_position_effective(p_pnj_id);
  IF pe.ville IS NULL THEN RETURN false; END IF;
  v_b := COALESCE(pe.building_id,
                  CASE WHEN pe.rue_noeud_id IS NOT NULL THEN 'rue-centrale' END);
  v_r := COALESCE(pe.room_id, pe.rue_noeud_id);
  RETURN pe.pays = a.country AND pe.ville = a.current_city
     AND v_b IS NOT DISTINCT FROM a.current_building
     AND v_r IS NOT DISTINCT FROM a.current_room;
END; $$;

-- ---------------------------------------------------------------------------------------
-- 5. LES VERBES PATRIMONIAUX : administrer + co-presence
-- ---------------------------------------------------------------------------------------
-- CONSULTER. On expose desormais `origine` et `cessible` : l'interface doit pouvoir montrer
-- qu'un objet miroir n'est pas reprenable tant que le blob fait autorite.
CREATE OR REPLACE FUNCTION public.pnj_possessions_lire(p_pnj text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT public.pnj_co_present(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;
  RETURN jsonb_build_object('ok', true,
    'liquide', (SELECT liquide FROM public.pnj_membres WHERE id = p_pnj),
    'possessions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('index', t.rang, 'objet', t.objet,
               'origine', t.origine, 'cessible', t.origine = 'socle') ORDER BY t.rang)
        FROM (SELECT (row_number() OVER (ORDER BY p.id)) - 1 AS rang, p.objet, p.origine
                FROM public.pnj_possessions p WHERE p.pnj_id = p_pnj) t
    ), '[]'::jsonb));
END; $$;

-- ARGENT.
CREATE OR REPLACE FUNCTION public.pnj_argent_transferer(p_pnj text, p_montant numeric, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pj numeric; v_pnj numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT public.pnj_co_present(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  SELECT liquide INTO v_pj FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT liquide INTO v_pnj FROM public.pnj_membres WHERE id = p_pnj FOR UPDATE;
  IF v_pj IS NULL OR v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  IF p_sens = 'donner' THEN
    IF v_pj < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE public.personnages_donnees SET liquide = v_pj - p_montant, arg = arg - p_montant
     WHERE name = v_moi;
    UPDATE public.pnj_membres SET liquide = v_pnj + p_montant WHERE id = p_pnj;
  ELSIF p_sens = 'retirer' THEN
    IF v_pnj < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE public.pnj_membres SET liquide = v_pnj - p_montant WHERE id = p_pnj;
    UPDATE public.personnages_donnees SET liquide = v_pj + p_montant, arg = arg + p_montant
     WHERE name = v_moi;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'montant', p_montant);
END; $$;

-- OBJETS. Correction de la DUPLICATION (defaut B1 de l'audit) : un objet dont `origine` n'est
-- pas 'socle' est le MIROIR d'un objet que le blob detient toujours. Le reprendre creait une
-- copie dans l'inventaire du joueur, puis le prochain passage du declencheur recreait la ligne
-- miroir -- deux objets pour un. Tant que le blob fait autorite, ces objets ne sont pas
-- cessibles par la couche generique.
CREATE OR REPLACE FUNCTION public.pnj_objet_transferer(p_pnj text, p_index integer, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_inv jsonb; v_objet jsonb; v_poss record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.pnj_peut_administrer(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF NOT public.pnj_co_present(v_moi, p_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  IF p_sens = 'donner' THEN
    SELECT COALESCE(inventory, '[]'::jsonb) INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    IF p_index IS NULL OR p_index < 0 OR p_index >= jsonb_array_length(v_inv) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'index_invalide'); END IF;
    v_objet := v_inv -> p_index;
    UPDATE public.personnages_donnees
       SET inventory = (v_inv - p_index) WHERE name = v_moi;
    INSERT INTO public.pnj_possessions (pnj_id, objet) VALUES (p_pnj, v_objet);
    RETURN jsonb_build_object('ok', true, 'sens', 'donner', 'objet', v_objet);

  ELSIF p_sens = 'retirer' THEN
    -- Meme ordonnancement que pnj_possessions_lire : l'index reste l'index affiche.
    SELECT * INTO v_poss FROM public.pnj_possessions
     WHERE pnj_id = p_pnj ORDER BY id OFFSET p_index LIMIT 1 FOR UPDATE;
    IF v_poss.id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'index_invalide'); END IF;
    IF v_poss.origine <> 'socle' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_cessible',
        'origine', v_poss.origine,
        'explication', 'Cet objet est le miroir d une possession que le metier detient encore. '
                    || 'Le reprendre le dupliquerait. Il faut passer par l action metier.'); END IF;
    SELECT COALESCE(inventory, '[]'::jsonb) INTO v_inv
      FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
    UPDATE public.personnages_donnees
       SET inventory = v_inv || jsonb_build_array(v_poss.objet) WHERE name = v_moi;
    DELETE FROM public.pnj_possessions WHERE id = v_poss.id;
    RETURN jsonb_build_object('ok', true, 'sens', 'retirer', 'objet', v_poss.objet);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
END; $$;

-- ---------------------------------------------------------------------------------------
-- 6. LES VERBES DE CONDUITE : conduire (administrateur OU leader courant)
-- ---------------------------------------------------------------------------------------
-- Aucun de ces trois verbes ne touche a `proprietaire_*` : un leader deplace, il n'acquiert pas.
CREATE OR REPLACE FUNCTION public.pnj_prendre(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; v_n integer := 0;
BEGIN
  IF public.pnj_axe_partage_verrouille(p_ids) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_axe_blob_autoritaire',
      'pnj', public.pnj_axe_partage_verrouille(p_ids),
      'explication', 'Pendant la phase miroir, les mouvements de soldats passent par les RPC militaires : le blob reste l autorite et le declencheur met le socle a jour.');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    IF NOT public.pnj_co_present(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    UPDATE public.pnj_membres SET leader_pj = v_moi, leader_pnj_id = NULL,
      ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'pris', v_n);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_quitter_groupe(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; pe record; v_n integer := 0;
BEGIN
  IF public.pnj_axe_partage_verrouille(p_ids) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_axe_blob_autoritaire',
      'pnj', public.pnj_axe_partage_verrouille(p_ids),
      'explication', 'Pendant la phase miroir, les mouvements de soldats passent par les RPC militaires : le blob reste l autorite et le declencheur met le socle a jour.');
  END IF;
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  FOR r IN SELECT id FROM public.pnj_membres WHERE id = ANY(p_ids) FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pe FROM public.pnj_position_effective(r.id);
    UPDATE public.pnj_membres
       SET leader_pj = NULL, leader_pnj_id = NULL,
           ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
     WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'detaches', v_n);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_transferer(
  p_ids text[], p_dest text, p_dest_est_pnj boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; r record; dv text; db text; dr text; pm record; v_n integer := 0;
BEGIN
  IF public.pnj_axe_partage_verrouille(p_ids) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_axe_blob_autoritaire',
      'pnj', public.pnj_axe_partage_verrouille(p_ids),
      'explication', 'Pendant la phase miroir, les mouvements de soldats passent par les RPC militaires : le blob reste l autorite et le declencheur met le socle a jour.');
  END IF;
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_dest_est_pnj THEN
    SELECT ville, building_id, room_id INTO dv, db, dr
      FROM public.pnj_position_effective(p_dest);
    IF NOT EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = p_dest AND statut = 'actif') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  ELSE
    SELECT current_city, current_building, current_room INTO dv, db, dr
      FROM public.personnages_donnees WHERE name = p_dest;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  END IF;

  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'pnj', r.id); END IF;
    SELECT * INTO pm FROM public.pnj_position_effective(r.id);
    IF pm.ville IS DISTINCT FROM dv OR pm.building_id IS DISTINCT FROM db
       OR pm.room_id IS DISTINCT FROM dr THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id); END IF;
    IF p_dest_est_pnj THEN
      UPDATE public.pnj_membres SET leader_pj = NULL, leader_pnj_id = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    ELSE
      UPDATE public.pnj_membres SET leader_pnj_id = NULL, leader_pj = p_dest,
        ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL WHERE id = r.id;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'transferes', v_n, 'nouveau_leader', p_dest);
END; $$;

-- ---------------------------------------------------------------------------------------
-- 7. LES FONCTIONS QUI PARLAIENT ENCORE LE LANGAGE DES POSTES
-- ---------------------------------------------------------------------------------------
-- Les evenements institutionnels se lisent par RESOLUTION, pas par comparaison de poste : est
-- destinataire celui qui detient AUJOURD'HUI l'autorite sur le perimetre concerne. Si personne
-- ne la detient, l'evenement n'a pas de lecteur institutionnel -- il n'est pas perdu, il attend.
CREATE OR REPLACE FUNCTION public.pnj_evenements_lire(p_limite integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'evenements', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('id', e.id, 'type', e.type, 'pnj', e.pnj_nom,
             'famille', e.famille, 'ville', e.ville, 'building_id', e.building_id,
             'room_id', e.room_id, 'cree_le', e.cree_le, 'lu', e.lu_le IS NOT NULL)
             ORDER BY e.cree_le DESC)
      FROM (SELECT * FROM public.pnj_evenements e2
             WHERE e2.proprietaire_pj = v_moi
                OR (e2.proprietaire_institution IS NOT NULL
                    AND v_moi = public.pnj_autorite_de_perimetre(
                          e2.pays, e2.proprietaire_institution, e2.proprietaire_perimetre))
             ORDER BY e2.cree_le DESC LIMIT greatest(1, least(coalesce(p_limite,30), 100))) e
  ), '[]'::jsonb));
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_mourir(p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record; pe record; v_n integer := 0; o record;
BEGIN
  SELECT * INTO m FROM public.pnj_membres WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF m.statut = 'mort' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_mort', 'deposes', 0); END IF;

  SELECT * INTO pe FROM public.pnj_position_effective(p_id);

  UPDATE public.pnj_membres
     SET statut = 'mort', leader_pj = NULL, leader_pnj_id = NULL,
         ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
   WHERE id = p_id;

  FOR o IN SELECT * FROM public.pnj_possessions WHERE pnj_id = p_id LOOP
    INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
    VALUES ('objet-abandonne-' || replace(gen_random_uuid()::text, '-', ''),
            pe.pays, COALESCE(pe.ville, 'inconnue'),
            COALESCE(pe.building_id, 'rue-centrale'),
            COALESCE(pe.room_id, COALESCE(pe.rue_noeud_id, 'inconnu')),
            (o.objet || jsonb_build_object('id',
               'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '')))::text);
    v_n := v_n + 1;
  END LOOP;
  DELETE FROM public.pnj_possessions WHERE pnj_id = p_id;

  INSERT INTO public.pnj_evenements (pnj_id, pnj_nom, famille, type, pays, proprietaire_pj,
      proprietaire_institution, proprietaire_perimetre, ville, building_id, room_id)
  VALUES (m.id, m.nom, m.famille, 'mort', m.pays, m.proprietaire_pj,
      m.proprietaire_institution, m.proprietaire_perimetre, pe.ville, pe.building_id, pe.room_id);

  RETURN jsonb_build_object('ok', true, 'deposes', v_n, 'ville', pe.ville,
                            'building_id', pe.building_id, 'room_id', pe.room_id);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_autorite_de_perimetre(text,text,text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_autorite_de_perimetre(text,text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_co_present(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_mourir(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_autorite_de_perimetre(text,text,text)  TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_autorite_de_perimetre(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_co_present(text,text)                  TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_mourir(text)                           TO service_role;