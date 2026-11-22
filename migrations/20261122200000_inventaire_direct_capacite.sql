-- Inventaire en direct, déposer et ramasser avec quantité, capacité propre à chaque personnage
-- (Fred, 22/11/2026, fin de nuit, GAME-DESIGN-FORET-TEST-20261122.md, points 2, 3 et 4).
--
-- Écrite à partir des définitions de PRODUCTION (pg_get_functiondef, 22/11/2026) et non du dépôt.
-- Éprouvée sur PGlite : outils/bancs/banc-inventaire-direct-pglite-20261122.cjs.
--
-- 1. Capacité par personnage : colonne personnages_donnees.capacite_inventaire (100 par défaut, de 1 à 10 000),
--    réglable par un MJ (admin_inventaire_capacite_fixer). inventaire_place_restante(inventaire, capacité) fait foi ;
--    l'ancienne forme à un argument (55 appelants : achats, récoltes, fabrications…) prend désormais la capacité du
--    personnage connecté (100 sans session, comme avant). Le navigateur lit la même capacité dans
--    inventaire_reception_etat (champ « capacite ») et applique la même règle de comptage.
-- 2. Déposer avec quantité : inventaire_abandonner(…, p_qte). Le lieu est celui du SERVEUR (un écran en retard est
--    refusé « pas_sur_place ») ; une pile du même objet déjà au sol de la pièce grossit au lieu d'en créer une seconde.
-- 3. Ramasser avec quantité : objet_abandonne_ramasser(p_id, p_qte), plafonné à la pile et à la place libre ; le reste
--    de la pile reste au sol. Refus nommé « place_insuffisante » avec la place restante (message du joueur :
--    « Votre inventaire ne peut accueillir que 12 unités de plus. »). L'ancienne forme ramasse toute la pile, ou refuse
--    si elle ne tient pas (aujourd'hui elle laissait dépasser 100).
-- 4. Donner : refus « destinataire_plein » (avec la place) si le don ne tient pas dans l'inventaire du destinataire,
--    dons encore en route compris.
-- 5. Direct : un objet reçu (objets_recus) prévient aussitôt son destinataire ; un changement d'inventaire ou de capacité
--    prévient son propriétaire (personnages_signaux) ; un objet posé ou retiré du sol prévient la pièce (salles_signaux).
BEGIN;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Capacité
-- ---------------------------------------------------------------------------------------------------------------
ALTER TABLE public.personnages_donnees ADD COLUMN IF NOT EXISTS capacite_inventaire integer NOT NULL DEFAULT 100;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'personnages_capacite_inventaire_bornes') THEN
    ALTER TABLE public.personnages_donnees ADD CONSTRAINT personnages_capacite_inventaire_bornes CHECK (capacite_inventaire BETWEEN 1 AND 10000);
  END IF;
END $$;

-- Même règle de comptage que l'ancienne inventaire_place_restante (quantite, puis qty, puis encombrement, sinon 1).
CREATE OR REPLACE FUNCTION public.inventaire_unites_interne(p_inv jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT coalesce((
 SELECT sum(CASE
   WHEN coalesce(e->>'quantite','') ~ '^[0-9]+$' THEN (e->>'quantite')::numeric
   WHEN coalesce(e->>'qty','') ~ '^[0-9]+$' THEN (e->>'qty')::numeric
   WHEN coalesce(e->>'encombrement','') ~ '^[0-9]+$' THEN (e->>'encombrement')::numeric
   ELSE 1 END)
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) e), 0)::integer; /* inventaire_capacite_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.inventaire_capacite(p_nom text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT capacite_inventaire FROM public.personnages_donnees WHERE name = p_nom), 100); /* inventaire_capacite_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.inventaire_place_restante(p_inv jsonb, p_capacite integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0, coalesce(p_capacite, 100) - public.inventaire_unites_interne(p_inv)); /* inventaire_capacite_v1 */
$function$;

-- Forme historique : capacité du personnage connecté (tous ses appelants agissent pour lui), 100 sans session.
CREATE OR REPLACE FUNCTION public.inventaire_place_restante(p_inv jsonb)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.inventaire_place_restante(p_inv, public.inventaire_capacite(public.mon_personnage())); /* inventaire_capacite_v1 */
$function$;

-- Lecture sûre d'un objet stocké en texte (objets_abandonnes.data) ou en chaîne JSON (objets_recus.data).
CREATE OR REPLACE FUNCTION public.inventaire_objet_lire_interne(p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v jsonb;
BEGIN
  BEGIN v := p_texte::jsonb; EXCEPTION WHEN others THEN RETURN NULL; END;
  IF jsonb_typeof(v) = 'string' THEN
    BEGIN v := (v #>> '{}')::jsonb; EXCEPTION WHEN others THEN RETURN NULL; END;
  END IF;
  RETURN CASE WHEN jsonb_typeof(v) = 'object' THEN v ELSE NULL END; /* inventaire_capacite_v1 */
END $function$;

-- Place réelle d'un destinataire : capacité − ce qu'il porte − ce qui est déjà en route vers lui.
CREATE OR REPLACE FUNCTION public.inventaire_place_destinataire_interne(p_nom text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0, public.inventaire_place_restante(d.inventory, d.capacite_inventaire)
    - coalesce((SELECT sum(public.inventaire_unites_interne(jsonb_build_array(o)))
                  FROM (SELECT public.inventaire_objet_lire_interne(r.data::text) o FROM public.objets_recus r WHERE r.destinataire = p_nom) x
                 WHERE o IS NOT NULL), 0))::integer
    FROM public.personnages_donnees d WHERE d.name = p_nom; /* inventaire_capacite_v1 */
$function$;

-- Le dépôt serveur commun (achats, récoltes, coupes, butin du chef…) prend la capacité du personnage servi.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;
SELECT pg_temp.rp_remplacer('public.inventaire_deposer_interne(text,jsonb,boolean)'::regprocedure,
  $a$ELSE public.inventaire_place_restante(v_inv) END;$a$,
  $b$ELSE public.inventaire_place_restante(v_inv, public.inventaire_capacite(p_nom)) END; /* inventaire_capacite_v1 */$b$, 1, 'inventaire_capacite_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Déposer au sol, avec quantité
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inventaire_abandonner(p_acteur text, p_index integer, p_signature jsonb, p_country text, p_city text, p_building text, p_room text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; v_r jsonb; v_objet jsonb; v_id text; v_cle text; s record; v_sol jsonb; v_qte_sol numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT coalesce(inventory, '[]'::jsonb) AS inv, quete_carriere AS quete, country, current_city, current_building, current_room
    INTO d FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- Le sol est celui où le SERVEUR place le personnage : jamais dans la rue, jamais ailleurs que là où il est.
  IF coalesce(d.current_building, '') = '' OR coalesce(d.current_room, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide');
  END IF;
  IF p_building IS DISTINCT FROM d.current_building OR p_room IS DISTINCT FROM d.current_room
     OR (p_city IS NOT NULL AND p_city IS DISTINCT FROM d.current_city) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_r := public.helvetia_inventaire_sortie(d.inv, d.quete, p_index, p_signature, coalesce(p_qte, 1));
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;
  v_objet := v_r->'objet';
  v_cle := nullif(v_objet->>'stackKey', '');

  -- Une pile du même objet est déjà au sol de cette pièce : elle grossit (une seule pile par objet).
  IF coalesce((v_objet->>'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    FOR s IN SELECT id, data FROM public.objets_abandonnes
              WHERE country IS NOT DISTINCT FROM d.country AND city IS NOT DISTINCT FROM d.current_city
                AND building_id = d.current_building AND room_id = d.current_room
              ORDER BY created_at, id FOR UPDATE LOOP
      v_sol := public.inventaire_objet_lire_interne(s.data);
      IF v_sol IS NOT NULL AND coalesce((v_sol->>'stackable')::boolean, false) AND v_sol->>'stackKey' = v_cle
         AND public.inventaire_pile_fusionnable(v_sol, v_objet) THEN
        v_id := s.id;
        v_qte_sol := coalesce((v_sol->>'qty')::numeric, 1) + coalesce((v_objet->>'qty')::numeric, 1);
        v_sol := v_sol || jsonb_build_object('qty', v_qte_sol, 'id', v_id);
        UPDATE public.objets_abandonnes SET data = v_sol::text WHERE id = v_id;
        EXIT;
      END IF;
    END LOOP;
  END IF;
  IF v_id IS NULL THEN
    v_id := 'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '');
    v_sol := v_objet || jsonb_build_object('id', v_id);
    INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
    VALUES (v_id, d.country, d.current_city, d.current_building, d.current_room, v_sol::text);
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id, 'qte', coalesce(p_qte, 1),
      'sol_qte', coalesce((v_sol->>'qty')::numeric, 1), 'capacite', public.inventaire_capacite(p_acteur))
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur)
    /* inventaire_sol_quantite_v1 */;
END; $function$;

-- Forme historique (navigateurs pas encore rechargés) : une unité, comme avant.
CREATE OR REPLACE FUNCTION public.inventaire_abandonner(p_acteur text, p_index integer, p_signature jsonb, p_country text, p_city text, p_building text, p_room text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.inventaire_abandonner(p_acteur, p_index, p_signature, p_country, p_city, p_building, p_room, 1); /* inventaire_sol_quantite_v1 */
$function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Ramasser au sol, avec quantité, plafonné à la place libre
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.objet_abandonne_ramasser(p_id text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; o record; v_objet jsonb; v_inv jsonb; v_place integer; v_dispo integer; v_q integer;
        v_pile bigint; v_pris jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb) AS inv, capacite_inventaire AS capacite
    INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO o FROM public.objets_abandonnes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_disparu'); END IF;
  IF o.building_id IS DISTINCT FROM d.current_building OR o.room_id IS DISTINCT FROM d.current_room
     OR (o.city IS NOT NULL AND o.city IS DISTINCT FROM d.current_city) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_objet := public.inventaire_objet_lire_interne(o.data);
  IF v_objet IS NULL THEN
    DELETE FROM public.objets_abandonnes WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_illisible'); END IF;
  v_objet := v_objet - 'id';
  v_place := public.inventaire_place_restante(d.inv, d.capacite);

  IF coalesce((v_objet ->> 'stackable')::boolean, false) AND nullif(v_objet ->> 'stackKey', '') IS NOT NULL THEN
    v_dispo := greatest(1, coalesce((v_objet ->> 'qty')::numeric, 1)::integer);
    v_q := coalesce(p_qte, v_dispo);
    IF v_q <= 0 OR v_q > v_dispo THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide', 'dispo', v_dispo, 'place', v_place); END IF;
    IF v_q > v_place THEN
      RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN v_place = 0 THEN 'inventaire_plein' ELSE 'place_insuffisante' END,
        'place', v_place, 'dispo', v_dispo, 'capacite', d.capacite); END IF;
    v_pris := v_objet || jsonb_build_object('qty', v_q);
    SELECT o2 INTO v_pile FROM jsonb_array_elements(d.inv) WITH ORDINALITY x(e, o2)
     WHERE coalesce((e->>'stackable')::boolean, false) AND e->>'stackKey' = v_objet->>'stackKey'
       AND public.inventaire_pile_fusionnable(e, v_objet) ORDER BY o2 LIMIT 1;
    IF v_pile IS NOT NULL THEN
      v_inv := jsonb_set(d.inv, ARRAY[(v_pile - 1)::text, 'qty'], to_jsonb(coalesce((d.inv -> (v_pile - 1)::integer ->> 'qty')::numeric, 1) + v_q));
    ELSE
      v_inv := d.inv || jsonb_build_array(public.aliment_dater_interne(v_pris));
    END IF;
    IF v_q < v_dispo THEN
      UPDATE public.objets_abandonnes SET data = (v_objet || jsonb_build_object('qty', v_dispo - v_q, 'id', p_id))::text WHERE id = p_id;
    ELSE
      DELETE FROM public.objets_abandonnes WHERE id = p_id;
    END IF;
  ELSE
    v_dispo := 1; v_q := 1;
    IF coalesce(p_qte, 1) <> 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide', 'dispo', 1, 'place', v_place); END IF;
    IF greatest(1, public.inventaire_unites_interne(jsonb_build_array(v_objet))) > v_place THEN
      RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN v_place = 0 THEN 'inventaire_plein' ELSE 'place_insuffisante' END,
        'place', v_place, 'dispo', 1, 'capacite', d.capacite, 'encombrement', public.inventaire_unites_interne(jsonb_build_array(v_objet))); END IF;
    v_pris := v_objet;
    v_inv := d.inv || jsonb_build_array(v_objet);
    DELETE FROM public.objets_abandonnes WHERE id = p_id;
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  PERFORM public.crim_ramasser_constater_interne(v_moi, v_pris); /* crim_ramasser_v1 */
  RETURN jsonb_build_object('ok', true, 'objet', v_pris, 'qte', v_q, 'reste', v_dispo - v_q, 'capacite', d.capacite,
      'place', public.inventaire_place_restante(v_inv, d.capacite))
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = v_moi)
    /* inventaire_sol_quantite_v1 */;
END; $function$;

-- Forme historique : toute la pile, ou un refus nommé si elle ne tient pas (plus jamais au-delà de la capacité).
CREATE OR REPLACE FUNCTION public.objet_abandonne_ramasser(p_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.objet_abandonne_ramasser(p_id, NULL::integer); /* inventaire_sol_quantite_v1 */
$function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Donner : jamais au-delà de la place du destinataire
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inventaire_donner(p_acteur text, p_destinataire text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1, p_mutations jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_id text;
        v_mut jsonb; v_objet jsonb; v_place integer; v_unites integer;
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

  -- Capacité du destinataire (Fred, 22/11/2026) : un don ne la dépasse jamais, dons encore en route compris.
  v_place := public.inventaire_place_destinataire_interne(p_destinataire);
  v_unites := greatest(1, public.inventaire_unites_interne(jsonb_build_array(v_objet)));
  IF v_unites > coalesce(v_place, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_plein', 'place', coalesce(v_place, 0),
                              'destinataire', p_destinataire, 'demande', v_unites); /* inventaire_capacite_v1 */
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  -- objets_recus est le SAS obligatoire : le serveur n'ecrit JAMAIS directement dans
  -- l'inventaire du destinataire, dont le client ouvert reecrirait le tableau entier et
  -- ecraserait l'ajout (doctrine posee par migration_moteur_commerce.sql).
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, p_acteur, to_jsonb(v_objet::text));

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END; $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Le navigateur lit sa capacité avec son inventaire
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inventaire_reception_etat(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v public.personnages_donnees%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
  PERFORM public.exiger_acteur(p_acteur);
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
  IF NOT FOUND OR v.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';
  END IF;
  IF jsonb_typeof(v.inventory) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'inventaire_format_a_reexaminer';
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'inventory',v.inventory,'revision',v.inventory_revision,
    'capacite', v.capacite_inventaire, 'place', public.inventaire_place_restante(v.inventory, v.capacite_inventaire)); /* inventaire_capacite_v1 */
END;
$function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 6. MJ : régler la capacité d'un personnage
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_inventaire_capacite_fixer(p_nom text, p_capacite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant integer; v_inv jsonb;
BEGIN
  PERFORM public.admin_exiger();
  IF p_capacite IS NULL OR p_capacite < 1 OR p_capacite > 10000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_invalide');
  END IF;
  SELECT capacite_inventaire, inventory INTO v_avant, v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  UPDATE public.personnages_donnees SET capacite_inventaire = p_capacite WHERE name = p_nom;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'inventaire_capacite_fixer', jsonb_build_object('nom', p_nom, 'capacite', p_capacite),
          jsonb_build_object('avant', v_avant), true);
  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'avant', v_avant, 'capacite', p_capacite,
    'porte', public.inventaire_unites_interne(v_inv)); /* inventaire_capacite_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.admin_inventaire_capacite_lire(p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record;
BEGIN
  PERFORM public.admin_exiger();
  SELECT capacite_inventaire, inventory INTO r FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'capacite', r.capacite_inventaire,
    'porte', public.inventaire_unites_interne(r.inventory)); /* inventaire_capacite_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 7. Direct : prévenir le propriétaire, le destinataire et la pièce
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.personnages_signaux_trg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pos boolean; v_etat boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(OLD.country, OLD.current_city, OLD.current_building, OLD.current_room, OLD.current_street));
    RETURN OLD;
  END IF;
  v_pos := TG_OP = 'INSERT' OR NEW.country IS DISTINCT FROM OLD.country OR NEW.current_city IS DISTINCT FROM OLD.current_city
        OR NEW.current_building IS DISTINCT FROM OLD.current_building OR NEW.current_room IS DISTINCT FROM OLD.current_room
        OR NEW.current_street IS DISTINCT FROM OLD.current_street;
  v_etat := v_pos OR NEW.est_emprisonne IS DISTINCT FROM OLD.est_emprisonne OR NEW.detention_qhs IS DISTINCT FROM OLD.detention_qhs
        OR NEW.hospitalisation IS DISTINCT FROM OLD.hospitalisation OR NEW.pa IS DISTINCT FROM OLD.pa OR NEW.hp IS DISTINCT FROM OLD.hp
        -- Inventaire et capacité (Fred, 22/11/2026) : butin, correction du MJ, objet porté… le propriétaire relit aussitôt.
        OR NEW.inventory IS DISTINCT FROM OLD.inventory OR NEW.capacite_inventaire IS DISTINCT FROM OLD.capacite_inventaire; /* inventaire_direct_v1 */
  IF v_pos THEN
    IF TG_OP = 'UPDATE' THEN
      PERFORM public.salle_signaler_interne(public.salle_cle_interne(OLD.country, OLD.current_city, OLD.current_building, OLD.current_room, OLD.current_street));
    END IF;
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(NEW.country, NEW.current_city, NEW.current_building, NEW.current_room, NEW.current_street));
    INSERT INTO public.presences (name, country, city, building_id, room_id, updated_at)
    VALUES (NEW.name, NEW.country, NEW.current_city, coalesce(NEW.current_building, 'rue-centrale'),
            CASE WHEN NEW.current_building IS NULL THEN NEW.current_street ELSE NEW.current_room END, NULL)
    ON CONFLICT (name) DO UPDATE SET country = excluded.country, city = excluded.city,
      building_id = excluded.building_id, room_id = excluded.room_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.inventory IS DISTINCT FROM OLD.inventory THEN
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(NEW.country, NEW.current_city, NEW.current_building, NEW.current_room, NEW.current_street));
  END IF;
  IF v_etat THEN PERFORM public.personnage_signaler_interne(NEW.name); END IF;
  RETURN NEW;
END $function$;

-- Un objet donné entre dans le sas : son destinataire est prévenu aussitôt (il le reçoit sans attendre deux minutes).
CREATE OR REPLACE FUNCTION public.objets_recus_signaux_trg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.destinataire IS NOT NULL THEN PERFORM public.personnage_signaler_interne(NEW.destinataire); END IF;
  RETURN NEW; /* inventaire_direct_v1 */
END $function$;
DROP TRIGGER IF EXISTS zz_objets_recus_signaux ON public.objets_recus;
CREATE TRIGGER zz_objets_recus_signaux AFTER INSERT ON public.objets_recus FOR EACH ROW EXECUTE FUNCTION public.objets_recus_signaux_trg();

-- Un objet posé, entamé ou retiré du sol : toute la pièce relit le sol.
CREATE OR REPLACE FUNCTION public.objets_abandonnes_signaux_trg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(OLD.country, OLD.city, OLD.building_id, OLD.room_id, NULL));
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') AND (TG_OP = 'INSERT' OR NEW.building_id IS DISTINCT FROM OLD.building_id OR NEW.room_id IS DISTINCT FROM OLD.room_id
                                         OR NEW.city IS DISTINCT FROM OLD.city OR NEW.country IS DISTINCT FROM OLD.country) THEN
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(NEW.country, NEW.city, NEW.building_id, NEW.room_id, NULL));
  END IF;
  RETURN coalesce(NEW, OLD); /* inventaire_direct_v1 */
END $function$;
DROP TRIGGER IF EXISTS zz_objets_abandonnes_signaux ON public.objets_abandonnes;
CREATE TRIGGER zz_objets_abandonnes_signaux AFTER INSERT OR UPDATE OR DELETE ON public.objets_abandonnes FOR EACH ROW EXECUTE FUNCTION public.objets_abandonnes_signaux_trg();

-- ---------------------------------------------------------------------------------------------------------------
-- Droits
-- ---------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.inventaire_unites_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.inventaire_capacite(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.inventaire_objet_lire_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.inventaire_place_destinataire_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.objets_recus_signaux_trg() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.objets_abandonnes_signaux_trg() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.inventaire_place_restante(jsonb, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inventaire_place_restante(jsonb, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.inventaire_abandonner(text, integer, jsonb, text, text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inventaire_abandonner(text, integer, jsonb, text, text, text, text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.objet_abandonne_ramasser(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.objet_abandonne_ramasser(text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_inventaire_capacite_fixer(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_inventaire_capacite_fixer(text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_inventaire_capacite_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_inventaire_capacite_lire(text) TO authenticated, service_role;
COMMIT;
