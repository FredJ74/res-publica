-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- acteur_poste_courant() -> TABLE(nom text, poste_id text, poste_city text, pays text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.acteur_poste_courant()
 RETURNS TABLE(nom text, poste_id text, poste_city text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name, p.poste->>'id', p.poste->>'city', p.country
    FROM public.personnages_donnees p
   WHERE p.user_id = auth.uid()
   LIMIT 1;
$function$;

-- acteur_present_sur_site(text,text,text,text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.acteur_present_sur_site(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE a record;
BEGIN
  -- FERME PAR DEFAUT. Un site dont on ignore le pays, la ville ou le batiment ne
  -- permet pas d'etablir une presence : on refuse, on ne devine pas.
  IF p_acteur IS NULL OR coalesce(p_pays, '') = ''
     OR coalesce(p_ville, '') = '' OR coalesce(p_batiment, '') = '' THEN
    RETURN false;
  END IF;

  -- LA POSITION FAISANT AUTORITE, et elle seule. Le navigateur ne transmet ici
  -- aucune localisation : il ne pourrait pas mentir meme s'il essayait.
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR a.current_city IS NULL OR a.current_building IS NULL THEN
    RETURN false;
  END IF;

  IF a.country          IS DISTINCT FROM p_pays     THEN RETURN false; END IF;
  IF a.current_city     IS DISTINCT FROM p_ville    THEN RETURN false; END IF;
  IF a.current_building IS DISTINCT FROM p_batiment THEN RETURN false; END IF;

  -- La piece ne compte que si le site en designe une. Sept commerces du jeu
  -- occupent leur batiment entier (voir commerces_types) : y etre, c'est y etre.
  IF coalesce(p_piece, '') <> '' AND a.current_room IS DISTINCT FROM p_piece THEN
    RETURN false;
  END IF;

  RETURN true;
END $function$;

-- deplacement_enregistrer(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.deplacement_enregistrer(p_city text, p_building text, p_room text, p_heure text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_jour integer; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_building IS NULL OR p_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_incomplete'); END IF;

  SELECT coalesce(country, 'republic'), coalesce(day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- Dedoublonnage : un battement au meme endroit n'ecrit RIEN.
  SELECT h.city, h.building_id, h.room_id INTO d
    FROM public.historique_deplacements h
   WHERE h.name = v_moi ORDER BY h.created_at DESC LIMIT 1;
  IF FOUND AND d.city IS NOT DISTINCT FROM p_city
           AND d.building_id IS NOT DISTINCT FROM p_building
           AND d.room_id IS NOT DISTINCT FROM p_room THEN
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'position_inchangee');
  END IF;

  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure)
  VALUES (v_moi, v_pays, p_city, p_building, p_room, v_jour, p_heure);
  RETURN jsonb_build_object('ok', true, 'enregistre', true);
END;
$function$;

-- eg_etat_id(text,jsonb) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.eg_etat_id(p_pays text, p_entrepot jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_pays || '_' || (p_entrepot ->> 'city') || '_' || (p_entrepot ->> 'building');
$function$;

-- eg_etat_lire(jsonb) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.eg_etat_lire(p_brut jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_brut IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof(p_brut) = 'string' THEN (p_brut #>> '{}')::jsonb
    WHEN jsonb_typeof(p_brut) = 'object' THEN p_brut
    ELSE '{}'::jsonb END;
$function$;

-- embargo_actif(text,text) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.embargo_actif(p_pays_soi text, p_pays_cible text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((
    SELECT (data -> 'sanctions' -> p_pays_cible -> 'mesures') ? 'embargo'
      FROM public.budgets_nationaux
     WHERE id = p_pays_soi
       AND jsonb_typeof(data -> 'sanctions' -> p_pays_cible -> 'mesures') = 'array'
  ), false);
$function$;

-- est_appel_serveur() -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.est_appel_serveur()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN coalesce(nullif(current_setting('role', true), 'none'), session_user)
         IN ('anon', 'authenticated')
      THEN false
    WHEN coalesce(nullif(current_setting('role', true), 'none'), session_user)
         IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin')
      THEN true
    ELSE coalesce(
           nullif(current_setting('request.jwt.claim.role', true), ''),
           (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
           'anon'
         ) = 'service_role'
  END;
$function$;

-- est_mon_personnage(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.est_mon_personnage(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.est_appel_serveur()
      OR (p_nom IS NOT NULL AND auth.uid() IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.personnages p
                      WHERE p.name = p_nom AND p.user_id = auth.uid()));
$function$;

-- exiger_acteur(text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.exiger_acteur(p_nom text)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_mon_personnage(p_nom) THEN
    RAISE EXCEPTION 'acteur_non_authentifie: % n''appartient pas au compte connecte', coalesce(p_nom, '(null)')
      USING ERRCODE = '42501';
  END IF;
END;
$function$;

-- exiger_poste(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.exiger_poste(p_poste text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text;
BEGIN
  -- Le serveur (cron, endpoints /api/*) traverse : il n'a pas de personnage.
  IF public.est_appel_serveur() THEN RETURN NULL; END IF;

  SELECT p.name, p.poste->>'id' INTO v_nom, v_poste
  FROM public.personnages_donnees p
  WHERE p.user_id = auth.uid()
  LIMIT 1;

  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'acteur_non_authentifie: aucun personnage rattache a ce compte'
      USING ERRCODE = '42501';
  END IF;
  IF v_poste IS DISTINCT FROM p_poste THEN
    RAISE EXCEPTION 'autorite_insuffisante: poste % requis, poste reel %',
      p_poste, coalesce(v_poste, '(aucun)') USING ERRCODE = '42501';
  END IF;
  RETURN v_nom;
END;
$function$;

-- generique_de_objet(jsonb) -> TABLE(generique_id text, variante_id text, effets_effectifs jsonb, motif text, valeur text, priorite integer) | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.generique_de_objet(p_objet jsonb)
 RETURNS TABLE(generique_id text, variante_id text, effets_effectifs jsonb, motif text, valeur text, priorite integer)
 LANGUAGE sql
 STABLE
AS $function$
  with direct as (
    -- Designation DIRECTE par le referentiel. Priorite maximale : quand le serveur
    -- a lui-meme pose l'identite mecanique, aucune cle legacy n'a a la deviner.
    select g.id                                  as generique_id,
           (select v.id from public.catalogue_variantes v
             where v.id = p_objet->>'variante_id' and v.generique_id = g.id) as variante_id,
           null::jsonb                           as effets_effectifs,
           'generique_id'::text                  as motif,
           g.id                                  as valeur,
           1000                                  as priorite,
           0::bigint                             as ordre
      from public.catalogue_generiques g
     where g.id = p_objet->>'generique_id'
  ),
  cand(motif, valeur) as (
    select 'type_originequete', (p_objet->>'type') || '|' || (p_objet->>'origineQuete')
      where p_objet->>'type' is not null and p_objet->>'origineQuete' is not null
    union all
    select 'type_produit_militaire', (p_objet->>'type') || '|' || (p_objet->>'produitMilitaire')
      where p_objet->>'type' is not null and p_objet->>'produitMilitaire' is not null
    union all
    select 'produit_militaire', p_objet->>'produitMilitaire'
      where p_objet->>'produitMilitaire' is not null
    union all
    select 'type_tracttype', (p_objet->>'type') || '|' || (p_objet->>'tractType')
      where p_objet->>'type' is not null and p_objet->>'tractType' is not null
    union all
    select 'famille_produit_marche', p_objet->>'familleProduitMarche'
      where p_objet->>'familleProduitMarche' is not null
    union all
    select 'type_soustype', (p_objet->>'type') || '|' || (p_objet->>'sousType')
      where p_objet->>'type' is not null and p_objet->>'sousType' is not null
    union all
    select 'recette_id', p_objet->>'type'
      where p_objet->>'type' is not null
    union all
    select 'stack_key', p_objet->>'stackKey'
      where p_objet->>'stackKey' is not null
    union all
    select 'type', p_objet->>'type'
      where p_objet->>'type' is not null
  ),
  legacy as (
    select c.generique_id, c.variante_id, c.effets_effectifs, c.motif, c.valeur,
           c.priorite, c.id as ordre
      from cand
      join public.catalogue_correspondance_legacy c
        on c.motif = cand.motif and c.valeur = cand.valeur
  ),
  tout as (select * from direct union all select * from legacy)
  select t.generique_id, t.variante_id, t.effets_effectifs, t.motif, t.valeur, t.priorite
    from tout t
   order by t.priorite desc, t.ordre asc
   limit 1;
$function$;

-- generique_recettes_systeme(text) -> TABLE(recette_id text, label text, pa integer, portions integer, materiaux jsonb) | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.generique_recettes_systeme(p_generique_id text)
 RETURNS TABLE(recette_id text, label text, pa integer, portions integer, materiaux jsonb)
 LANGUAGE sql
 STABLE
AS $function$
  with toutes as (
    select r.id, r.label, r.label_forme, r.pa, r.portions,
           coalesce(r.materiaux, '{}'::jsonb) as materiaux
      from public.recettes_commerce r
     where r.generique_id = p_generique_id
  ), arbitre as (
    select exists (select 1 from toutes where nullif(btrim(label_forme), '') is not null) as oui
  )
  select t.id, coalesce(nullif(btrim(t.label_forme), ''), t.label),
         t.pa, t.portions, t.materiaux
    from toutes t, arbitre a
   where NOT a.oui OR nullif(btrim(t.label_forme), '') is not null
   order by t.id;
$function$;

-- inventaire_abandonner(text,integer,jsonb,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_abandonner(p_acteur text, p_index integer, p_signature jsonb, p_country text, p_city text, p_building text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_objet jsonb; v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_building, '') = '' OR coalesce(p_room, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  -- Identifiant attribue par le SERVEUR : la plupart des objets uniques du jeu n'ont aucun
  -- champ id (seuls les objets de quete en ont un), et l'ancien chemin client reprenait
  -- objet.id tel quel -- donc NULL le plus souvent, pour une colonne qui est la cle primaire.
  v_id := 'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '');
  v_objet := (v_r->'objet') || jsonb_build_object('id', v_id);

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
  VALUES (v_id, p_country, p_city, p_building, p_room, v_objet::text);

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $function$;

-- inventaire_ajouter(jsonb,text,integer,text) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_ajouter(p_inv jsonb, p_cle text, p_qte integer, p_desc text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb := coalesce(p_inv, '[]'::jsonb);
BEGIN
  IF p_qte <= 0 THEN RETURN v_inv; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE e->>'stackKey' = p_cle) THEN
    SELECT jsonb_agg(CASE WHEN e->>'stackKey' = p_cle
             THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) + p_qte))
             ELSE e END) INTO v_inv FROM jsonb_array_elements(v_inv) e;
    RETURN v_inv;
  END IF;
  RETURN v_inv || jsonb_build_array(jsonb_build_object(
    'name', p_cle, 'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'desc', p_desc));
END; $function$;

-- inventaire_confisquer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_confisquer(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inv jsonb; v_quete jsonb; v_pays text; v_trouve boolean;
  v_saisis jsonb; v_restant jsonb;
  v_ville text; v_bat text; v_room text; v_ref text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere, coalesce(country, 'republic'),
         current_city, current_building, current_room
    INTO v_trouve, v_inv, v_quete, v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  WITH elements AS (
    SELECT e, (coalesce((e->>'legal')::boolean, true) = false
               OR public.assemblee_loi_en_vigueur(v_pays, e, now()) IS NOT NULL)
              AND NOT public.inventaire_objet_protege(v_quete, e) AS saisi
      FROM jsonb_array_elements(v_inv) e
  )
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE saisi), '[]'::jsonb),
         coalesce(jsonb_agg(e) FILTER (WHERE NOT saisi), '[]'::jsonb)
    INTO v_saisis, v_restant FROM elements;

  IF jsonb_array_length(v_saisis) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'saisis', '[]'::jsonb, 'inventory', v_inv, 'noms', '');
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_restant WHERE name = p_acteur;

  -- EVENEMENT MONDE, une ligne par objet reellement confisque, dans la meme
  -- transaction que le retrait.
  v_ref := 'conf-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
           substr(md5(p_acteur || random()::text), 1, 8);
  INSERT INTO public.confiscations_douanieres
    (id, personne, objet_nom, objet_type, quantite, pays, ville, building_id, room_id, reference)
  SELECT v_ref || '-' || o.ord, p_acteur,
         coalesce(o.e ->> 'name', o.e ->> 'nom', '?'),
         o.e ->> 'type',
         nullif(coalesce(o.e ->> 'qty', o.e ->> 'quantite'), '')::integer,
         v_pays, v_ville, v_bat, v_room, v_ref
    FROM jsonb_array_elements(v_saisis) WITH ORDINALITY AS o(e, ord);

  RETURN jsonb_build_object('ok', true, 'saisis', v_saisis, 'inventory', v_restant,
    'noms', (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(v_saisis) e));
END; $function$;

-- inventaire_consommer(text,integer,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_consommer(p_acteur text, p_index integer, p_signature jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_pos integer; v_item jsonb;
  v_date numeric; v_frais boolean; v_pa integer; v_delta integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;

  IF NOT (coalesce(v_item->>'familleProduitMarche', '') = 'aliment'
          OR coalesce(v_item->>'type', '') IN ('medicament', 'explosif', 'poison')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_consommable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;

  -- EFFET EN PA DES ALIMENTS, dans la meme transaction que le retrait.
  IF coalesce(v_item->>'familleProduitMarche', '') = 'aliment' THEN
    BEGIN v_date := (v_item->>'dateAchat')::numeric; EXCEPTION WHEN others THEN v_date := NULL; END;
    IF v_date IS NOT NULL AND v_date > 0 THEN
      -- dateAchat est un horodatage en millisecondes, comme du cote du navigateur.
      v_frais := (extract(epoch FROM now()) * 1000 - v_date) <= 7 * 24 * 60 * 60 * 1000;
      v_delta := CASE WHEN v_frais THEN 1 ELSE -1 END;
      UPDATE public.personnages_donnees
         SET pa = least(30, greatest(0, coalesce(pa, 0) + v_delta))
       WHERE name = p_acteur
       RETURNING pa INTO v_pa;
      v_r := v_r || jsonb_build_object('pa', v_pa, 'aliment_frais', v_frais);
    END IF;
  END IF;

  RETURN v_r;
END; $function$;

-- inventaire_detruire(text,integer,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_detruire(p_acteur text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $function$;

-- inventaire_donner(text,text,integer,jsonb,integer,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_donner(p_acteur text, p_destinataire text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1, p_mutations jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_id text;
        v_mut jsonb; v_objet jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' OR p_destinataire = p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  -- Mutations de PRESENTATION seulement (carte postale ecrite). Liste NOIRE plutot que blanche :
  -- un champ de jeu nouvellement invente reste transmissible, mais aucun champ economique ne
  -- peut l'etre par oubli.
  v_objet := v_r->'objet';
  IF p_mutations IS NOT NULL AND jsonb_typeof(p_mutations) = 'object' THEN
    v_mut := p_mutations - 'qty' - 'quantite' - 'stackable' - 'stackKey'
                         - 'encombrement' - 'type' - 'legal' - 'id';
    v_objet := v_objet || v_mut;
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  -- objets_recus est le SAS obligatoire : le serveur n'ecrit JAMAIS directement dans
  -- l'inventaire du destinataire, dont le client ouvert reecrirait le tableau entier et
  -- ecraserait l'ajout (doctrine posee par migration_moteur_commerce.sql).
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, p_acteur, to_jsonb(v_objet::text));

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $function$;

-- inventaire_localiser(jsonb,integer,jsonb) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_localiser(p_inv jsonb, p_index integer, p_signature jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH inv AS (
    SELECT e, (ord - 1)::int AS pos
      FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
  ), correspond AS (
    SELECT pos FROM inv
     WHERE coalesce(e->>'name', '')     = coalesce(p_signature->>'name', '')
       AND coalesce(e->>'type', '')     = coalesce(p_signature->>'type', '')
       AND coalesce(e->>'stackKey', '') = coalesce(p_signature->>'stackKey', '')
  )
  SELECT coalesce((SELECT pos FROM correspond WHERE pos = p_index),
                  (SELECT min(pos) FROM correspond), -1);
$function$;

-- inventaire_objet_protege(jsonb,jsonb) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_objet_protege(p_quete jsonb, p_item jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_item->>'type', '') = 'colis_secret_pat'
     AND (p_quete IS NULL
          OR (coalesce(p_quete->>'ambition', '') = 'criminel'
              AND coalesce(p_quete->>'etape', '') <> 'terminee'));
$function$;

-- inventaire_place_restante(jsonb) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_place_restante(p_inv jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0, 100 - coalesce((SELECT sum(coalesce((e->>'qty')::numeric,
           (e->>'encombrement')::numeric, 1)) FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e), 0))::int;
$function$;

-- inventaire_quantite(jsonb,text) -> numeric | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_quantite(p_inv jsonb, p_cle text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT sum(coalesce((e->>'qty')::numeric,1))
                   FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e
                   WHERE e->>'stackKey' = p_cle), 0);
$function$;

-- inventaire_remettre(text,integer,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_remettre(p_acteur text, p_index integer, p_signature jsonb, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_pos integer; v_item jsonb; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;

  -- Objet protege : sortie autorisee UNIQUEMENT vers son destinataire designe.
  IF public.inventaire_objet_protege(v_quete, v_item) THEN
    IF coalesce(v_item->>'type', '') = 'colis_secret_pat' AND p_destinataire = 'Brigitte Menottes' THEN
      v_inv := public.inventaire_retirer_position(v_inv, v_pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_acteur;
      RETURN jsonb_build_object('ok', true, 'inventory', v_inv, 'objet', v_item,
                                'position', v_pos, 'remise_quete', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_non_designe');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $function$;

-- inventaire_retirer(jsonb,text,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_retirer(p_inv jsonb, p_cle text, p_qte integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE coalesce((e->>'qty')::numeric, 1) > 0), '[]'::jsonb)
  FROM (SELECT CASE WHEN e->>'stackKey' = p_cle
                    THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) - p_qte))
                    ELSE e END AS e
        FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e) x;
$function$;

-- inventaire_retirer_position(jsonb,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.inventaire_retirer_position(p_inv jsonb, p_pos integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
    FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
   WHERE (ord - 1) <> p_pos;
$function$;

-- is_national(text) -> numeric | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.is_national(p_pays text)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN count(*) = 3 THEN round(avg((v.data ->> 'isn')::numeric), 2)
    ELSE 50
  END
  FROM public.indices_villes v
  WHERE v.id = ANY (ARRAY[p_pays || '_capitale',
                          p_pays || '_ville_a',
                          p_pays || '_ville_b'])
    AND jsonb_typeof(v.data -> 'isn') = 'number';
$function$;

-- jour_de_jeu_pays(text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jour_de_jeu_pays(p_pays text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1,
    ((now() AT TIME ZONE 'Europe/Paris')::date
      - coalesce((SELECT e.jour_un FROM public.rp_epoques e WHERE e.pays = p_pays),
                 DATE '2026-09-13')
    )::int + 1);
$function$;

-- jour_de_jeu_reel() -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jour_de_jeu_reel()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.jour_de_jeu_pays('republic');
$function$;

-- jsonb_cle_economique_presente(jsonb) -> text | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.jsonb_cle_economique_presente(p_val jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_cle text; v_sous jsonb; v_res text;
BEGIN
  IF p_val IS NULL THEN RETURN NULL; END IF;

  IF jsonb_typeof(p_val) = 'object' THEN
    FOR v_cle, v_sous IN SELECT key, value FROM jsonb_each(p_val) LOOP
      IF lower(v_cle) = ANY (ARRAY[
            'caisse','caisses','stock','stocks','stockmatieres','stockproduits','stockbois',
            'stockmedical','reserve','reserves','prix','prixmanuel','prixachat','prixvente',
            'prixunitaire','repartition','arg','liquide','banque','inventory','inventaire',
            'solde','production','chaines','montant','salaire','tresorerie','budget','fonds',
            'loyer','imprimerie','entrepot','entrepots','usine','usines','sante','terrain',
            'commerce','journal','pret','prets','dette','dettes','taxe','impot']) THEN
        RETURN v_cle;
      END IF;
      v_res := public.jsonb_cle_economique_presente(v_sous);
      IF v_res IS NOT NULL THEN RETURN v_res; END IF;
    END LOOP;

  ELSIF jsonb_typeof(p_val) = 'array' THEN
    FOR v_sous IN SELECT value FROM jsonb_array_elements(p_val) LOOP
      v_res := public.jsonb_cle_economique_presente(v_sous);
      IF v_res IS NOT NULL THEN RETURN v_res; END IF;
    END LOOP;
  END IF;

  RETURN NULL;
END; $function$;

-- jsonb_cles_hors_liste(jsonb,text[]) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.jsonb_cles_hors_liste(p_obj jsonb, p_autorisees text[])
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT key FROM jsonb_each(p_obj)
  WHERE jsonb_typeof(p_obj) = 'object' AND NOT (key = ANY (p_autorisees))
  LIMIT 1;
$function$;

-- jsonb_ou_null(text) -> jsonb | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.jsonb_ou_null(p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN p_texte::jsonb;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$function$;

-- mon_personnage() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mon_personnage()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name FROM public.personnages p
  WHERE p.user_id IS NOT NULL AND p.user_id = auth.uid()
  LIMIT 1;
$function$;

-- mon_poste_est(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mon_poste_est(p_poste text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
  );
$function$;

-- mon_poste_est_dans(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mon_poste_est_dans(p_poste text, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
       AND (p_pays IS NULL OR d.country = p_pays)
  );
$function$;

-- mouvement_titulaire(text,numeric) -> boolean | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.mouvement_titulaire(p_ref text, p_delta numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_type text; v_id text; v_solde numeric; v_data text; v_json jsonb;
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;

  IF left(p_ref, 5) = 'orga:' THEN
    v_type := 'orga'; v_id := substr(p_ref, 6);
  ELSIF left(p_ref, 3) = 'pj:' THEN
    v_type := 'pj'; v_id := substr(p_ref, 4);
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  ELSE
    v_type := 'pj'; v_id := p_ref;
  END IF;
  IF COALESCE(v_id, '') = '' THEN RETURN false; END IF;

  IF v_type = 'pj' THEN
    -- TABLE REELLE, pas la vue : ni masquage de colonne, ni controle de propriete a traverser.
    SELECT arg INTO v_solde FROM public.personnages_donnees WHERE name = v_id FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    IF COALESCE(v_solde, 0) + p_delta < 0 THEN RETURN false; END IF;
    UPDATE public.personnages_donnees
       SET arg = COALESCE(arg, 0) + p_delta, updated_at = now()
     WHERE name = v_id;
    RETURN true;
  END IF;

  SELECT data INTO v_data FROM public.organisations WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  BEGIN
    v_json := v_data::jsonb;
  EXCEPTION WHEN others THEN RETURN false;
  END;
  IF v_json IS NULL OR jsonb_typeof(v_json) <> 'object' THEN RETURN false; END IF;
  v_solde := GREATEST(0, COALESCE((v_json ->> 'caisse')::numeric, 0));
  IF v_solde + p_delta < 0 THEN RETURN false; END IF;
  UPDATE public.organisations
     SET data = jsonb_set(v_json, '{caisse}', to_jsonb(v_solde + p_delta))::text
   WHERE id = v_id;
  RETURN true;
END; $function$;

-- objet_fiche_officielle(jsonb) -> jsonb | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.objet_fiche_officielle(p_objet jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  with r as (
    select * from public.generique_de_objet(p_objet) limit 1
  ),
  g as (
    select gen.*, fam.libelle as famille_libelle
      from r
      join public.catalogue_generiques gen on gen.id = r.generique_id
      join public.catalogue_familles    fam on fam.id = gen.famille_id
  ),
  v as (
    select va.libelle, va.capacites
      from r
      join public.catalogue_variantes va on va.id = r.variante_id
  ),
  t as (
    select coalesce(jsonb_agg(ty.libelle order by ty.ordre), '[]'::jsonb) as types
      from g
      join public.catalogue_generique_type gt on gt.generique_id = g.id
      join public.catalogue_types ty on ty.id = gt.type_id
  )
  select case
    when not exists (select 1 from r) then
      jsonb_build_object('resolu', false)
    else
      (select jsonb_strip_nulls(jsonb_build_object(
        'resolu',        true,
        'generique_id',  g.id,
        'generique',     g.libelle,
        'famille',       g.famille_libelle,
        'types',         (select types from t),
        'variante',      (select libelle from v),
        'regime',        g.regime,
        'est_service',   g.est_service,
        'effets',        coalesce((select effets_effectifs from r), g.effets),
        'capacites',     coalesce((select capacites from v), g.capacites),
        'consommable',   g.consommable,
        'equipable',     g.equipable,
        'encombrement',  g.encombrement,
        'durabilite',    g.durabilite,
        'conditions',    g.conditions,
        'contraintes',   g.contraintes
      )) || jsonb_build_object(
        'aucun_effet',
        (coalesce((select effets_effectifs from r), g.effets) is null
         and coalesce((select capacites from v), g.capacites) is null)
      )
      from g)
  end;
$function$;

-- objet_sas_deposer(text,text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.objet_sas_deposer(p_motif text, p_destinataire text, p_objet jsonb, p_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_vol record;
  v_nouveau_type text;
  v_demandeur text;
  v_expediteur text;
  v_id text;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_destinataire, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  IF p_motif = 'butin_vol' THEN
    -- La victime depose le butin pour le voleur. La ligne de vol est la piece justificative :
    -- elle doit exister, designer l'acteur comme victime et le destinataire comme voleur.
    SELECT * INTO v_vol FROM public.vols_en_attente
     WHERE id = p_reference FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vol_introuvable', 'reference', p_reference);
    END IF;
    IF v_vol.victime IS DISTINCT FROM v_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_la_victime');
    END IF;
    IF v_vol.voleur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_voleur');
    END IF;
    -- Anti-rejeu : un butin deja confirme ne se depose pas deux fois.
    IF v_vol.type_butin IN ('matiere_confirmee', 'objet_confirme') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'butin_deja_confirme');
    END IF;
    v_nouveau_type := CASE v_vol.type_butin
      WHEN 'matiere' THEN 'matiere_confirmee'
      WHEN 'objet'   THEN 'objet_confirme'
      ELSE NULL END;
    IF v_nouveau_type IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_butin_non_transferable',
                                'type_butin', v_vol.type_butin);
    END IF;
    v_expediteur := 'Butin de vol';

  ELSIF p_motif = 'document_urbanisme' THEN
    -- L'archive municipale COMMANDE : le joueur ne doit jamais detenir un recepisse d'un acte que
    -- la mairie n'a pas enregistre. La ligne d'archive est donc la piece justificative, et c'est
    -- elle qui nomme le demandeur legitime.
    SELECT demandeur INTO v_demandeur FROM public.dossiers_urbanisme WHERE id = p_reference;
    IF v_demandeur IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable',
                                'reference', p_reference);
    END IF;
    IF v_demandeur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_demandeur');
    END IF;
    v_expediteur := 'Services d''urbanisme';

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_non_declare', 'motif', p_motif);
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, v_expediteur, to_jsonb(p_objet::text));

  -- Meme transaction que le depot : le marquage du butin ne peut plus rester en arriere.
  IF p_motif = 'butin_vol' THEN
    UPDATE public.vols_en_attente SET type_butin = v_nouveau_type WHERE id = p_reference;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire,
                            'motif', p_motif, 'type_butin', v_nouveau_type);
END;
$function$;

-- personnage_fantome_declarer(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.personnage_fantome_declarer(p_nom text, p_empreinte jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid; v_nom text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  v_nom := btrim(coalesce(p_nom, ''));
  IF v_nom = '' OR length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide');
  END IF;

  -- Ce compte a deja un personnage : ce n'est pas un fantome, rien a reconcilier.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu');
  END IF;
  -- Le nom reclame appartient a un personnage VIVANT : on n'enregistre pas une revendication
  -- sur l'identite de quelqu'un d'autre.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
  END IF;

  INSERT INTO public.reconciliation_fantomes (user_id, nom_local, empreinte, vu_le)
  VALUES (v_uid, v_nom, coalesce(p_empreinte, '{}'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE
    SET nom_local = EXCLUDED.nom_local, empreinte = EXCLUDED.empreinte, vu_le = now();

  RETURN jsonb_build_object('ok', true, 'enregistre', v_nom);
END;
$function$;

-- rattacher_personnage(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rattacher_personnage(p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid       uuid := auth.uid();
  v_proprio   uuid;
  v_mien      text;
  c_sans_maitre CONSTANT uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  -- Jamais d'action sous la cle anon partagee : il faut une identite nominative.
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_session');
  END IF;
  IF p_nom IS NULL OR btrim(p_nom) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent');
  END IF;

  SELECT d.user_id INTO v_proprio
    FROM public.personnages_donnees d
   WHERE d.name = p_nom
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- Cas nominal : il est deja a moi. Rien a ecrire, l'acces est legitime.
  IF v_proprio = v_uid THEN
    RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'deja_rattache', true);
  END IF;

  -- Ce compte porte-t-il deja un AUTRE personnage ?
  SELECT d.name INTO v_mien
    FROM public.personnages_donnees d
   WHERE d.user_id = v_uid
   LIMIT 1;
  IF v_mien IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu', 'personnage', v_mien);
  END IF;

  -- Il appartient a un autre compte : refus sec, aucune ecriture.
  IF v_proprio IS DISTINCT FROM c_sans_maitre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_deja_possede');
  END IF;

  -- Seul cas de rattachement : personnage explicitement sans maitre.
  UPDATE public.personnages_donnees
     SET user_id = v_uid
   WHERE name = p_nom AND user_id = c_sans_maitre;

  RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'deja_rattache', false);
END;
$function$;

-- ref_patrimoine_existe(text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.ref_patrimoine_existe(p_ref text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;
  IF left(p_ref, 5) = 'orga:' THEN
    RETURN EXISTS (SELECT 1 FROM organisations WHERE id = substr(p_ref, 6));
  ELSIF left(p_ref, 3) = 'pj:' THEN
    RETURN EXISTS (SELECT 1 FROM personnages WHERE name = substr(p_ref, 4));
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM personnages WHERE name = p_ref);
END;
$function$;

-- restaurer_personnage_sauvegarde(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.restaurer_personnage_sauvegarde(p_nom text, p_poste text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid; v_emp jsonb; v_sauv record; v_cols text; v_sql text; v_res jsonb;
  v_champs text[] := ARRAY['archetype','career','origin','school'];
  v_c text; v_stat text;
BEGIN
  -- --- 1. Le compte a-t-il declare ce personnage ? ---
  SELECT user_id, empreinte INTO v_uid, v_emp
    FROM public.reconciliation_fantomes
   WHERE nom_local = p_nom AND traite IS FALSE
   ORDER BY vu_le DESC LIMIT 1;
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_declaration',
      'detail', 'Ce personnage n''a ete declare par aucun compte : le joueur doit recharger le jeu.');
  END IF;

  SELECT * INTO v_sauv FROM sauvegarde_beta_20260913.personnages WHERE name = p_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'absent_de_la_sauvegarde'); END IF;

  -- --- 2. L'empreinte corrobore-t-elle la sauvegarde ? ---
  FOREACH v_c IN ARRAY v_champs LOOP
    IF coalesce(v_emp ->> v_c, '') IS DISTINCT FROM coalesce(
         CASE v_c WHEN 'archetype' THEN v_sauv.archetype WHEN 'career' THEN v_sauv.career
                  WHEN 'origin' THEN v_sauv.origin ELSE v_sauv.school END, '') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'empreinte_incompatible', 'champ', v_c,
        'declare', v_emp ->> v_c, 'sauvegarde',
        CASE v_c WHEN 'archetype' THEN v_sauv.archetype WHEN 'career' THEN v_sauv.career
                 WHEN 'origin' THEN v_sauv.origin ELSE v_sauv.school END);
    END IF;
  END LOOP;
  FOREACH v_stat IN ARRAY ARRAY['CHA','DUP','ENT','INT','PER','VOL'] LOOP
    IF (v_emp -> 'stats' ->> v_stat) IS DISTINCT FROM (v_sauv.stats ->> v_stat) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'empreinte_incompatible', 'champ', 'stats.'||v_stat,
        'declare', v_emp -> 'stats' ->> v_stat, 'sauvegarde', v_sauv.stats ->> v_stat);
    END IF;
  END LOOP;

  -- --- 3. Ni doublon de compte, ni doublon de nom ---
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu');
  END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
  END IF;

  -- --- 4. Copie, colonnes communes uniquement, poste exclu ---
  SELECT string_agg(quote_ident(s.column_name), ', ' ORDER BY s.column_name) INTO v_cols
    FROM information_schema.columns s
   WHERE s.table_schema='sauvegarde_beta_20260913' AND s.table_name='personnages'
     AND s.column_name NOT IN ('poste','user_id','id')
     AND EXISTS (SELECT 1 FROM information_schema.columns a
                  WHERE a.table_schema='public' AND a.table_name='personnages_donnees'
                    AND a.column_name = s.column_name);

  -- Le trigger personnages_lier_proprietaire ecrase user_id par auth.uid() : on pose donc les
  -- claims de CE compte, localement a la transaction, pour que la ligne lui soit rattachee.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  v_sql := format('INSERT INTO public.personnages_donnees (%s, user_id) SELECT %s, %L FROM sauvegarde_beta_20260913.personnages WHERE name = %L',
                  v_cols, v_cols, v_uid, p_nom);
  EXECUTE v_sql;

  -- --- 5. Poste historique, via la primitive qui tient registre + PNJ + miroir ---
  IF p_poste IS NOT NULL THEN
    v_res := public.poste_attribuer_interne(v_sauv.country, p_poste, NULL, p_nom, 'restauration_sauvegarde');
    IF coalesce((v_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_restaure', 'detail', v_res);
    END IF;
  END IF;

  UPDATE public.reconciliation_fantomes SET traite = true WHERE user_id = v_uid;

  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'user_id', v_uid,
    'poste', p_poste, 'poste_resultat', v_res);
END;
$function$;

-- rp_transition_active(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rp_transition_active(p_cle text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT t.actif FROM public.rp_transitions t WHERE t.cle = p_cle), false);
$function$;
