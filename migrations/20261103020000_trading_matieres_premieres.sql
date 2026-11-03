-- APPLIQUEE le 03/11/2026 par Claude (registre trading_matieres_premieres_20261103020000), apres le banc
-- annule outils/bancs/banc-trading-matieres.sql joue en production (tous les cas conformes).
-- 3 novembre 2026 -- TRADING DE MATIERES PREMIERES, etape 1 : equipements installes, cours, achat a distance.
--
-- Decisions de Fred (GAME-DESIGN-TRADING.md) :
--   31/10 : ordinateur + box internet installes dans son bureau (tout local dont on a la jouissance
--           legale) = connexion internet ; elle permet de consulter les cours des matieres dans les
--           entrepots et d'acheter a distance ; a distance on ne fait qu'ACHETER ; les entrepots n'ont
--           pas un stock illimite ; la marchandise part en caisses de fret par le port industriel ; le
--           stockage ensuite, c'est l'affaire du PJ ; le trading passe par une ORGANISATION
--           economique, dont la caisse paie ; le chef autorise les membres a trader.
--   03/11 : le trader doit etre DANS son bureau ; consulter = 0 PA, acheter = 1 PA par commande ;
--           depart le jour meme vers le port industriel de PSM, arrivee au cron de minuit, sans droits
--           de douane (la marchandise ne quitte pas la Republia).
--
-- REUTILISE : prix et disponibilite d'acheter_a_entrepot (prix manuel sinon prix de reference, stock
-- moins la reserve militaire), caisses d'entrepot (caisse_institution_mouvement), caisse
-- d'organisation (mouvement_titulaire), caisses de fret et leur cycle (arrivee au cron, retrait par
-- fret_objet_agir, mise en vente a J15), bail (locations_actives), 2 emplacements par bureau (ecran
-- « Installer des equipements », version gratuite).
-- NOUVEAU : la table equipements_installes et les RPC ci-dessous. Etape 2 a venir : offres d'achat.
-- Idempotente. Aucun acte de joueur.

CREATE TABLE IF NOT EXISTS public.equipements_installes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proprietaire  text NOT NULL,
  pays          text NOT NULL,
  ville         text NOT NULL,
  batiment      text NOT NULL,
  piece         text NOT NULL,
  generique_id  text NOT NULL,
  objet         jsonb NOT NULL,
  installe_le   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS equipements_installes_local ON public.equipements_installes (pays, ville, batiment, piece);
ALTER TABLE public.equipements_installes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.equipements_installes FROM anon, authenticated;

-- Jouissance legale d'un local : bail actif au nom du PJ, ou d'une organisation dont il est membre.
CREATE OR REPLACE FUNCTION public.local_jouissance_interne(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.locations_actives l
     WHERE l.id = p_pays || ':' || p_batiment || ':' || p_piece || ':' || p_ville
       AND ( replace(coalesce(l.data->>'locataire', ''), 'pj:', '') = p_acteur
          OR EXISTS (SELECT 1 FROM public.organisations o
                      WHERE o.id = l.data->>'orgaId'
                        AND ( o.data::jsonb->>'chef' = p_acteur
                           OR EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array'
                                                                         THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) mb
                                       WHERE mb->>'nom' = p_acteur)))));
$function$;

-- Le PJ est-il dans un bureau ou SON ordinateur et SA box sont installes, avec jouissance valide ?
CREATE OR REPLACE FUNCTION public.trading_connexion_interne(p_acteur text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees pd
     WHERE pd.name = p_acteur AND pd.current_building IS NOT NULL AND pd.current_room IS NOT NULL
       AND public.local_jouissance_interne(p_acteur, pd.country, pd.current_city, pd.current_building, pd.current_room)
       AND (SELECT count(DISTINCT e.generique_id) FROM public.equipements_installes e
             WHERE e.proprietaire = p_acteur AND e.pays = pd.country AND e.ville = pd.current_city
               AND e.batiment = pd.current_building AND e.piece = pd.current_room
               AND e.generique_id IN ('ordinateur-complet', 'box-internet')) = 2);
$function$;

-- Ce qui est installe dans le local ou se tient le PJ.
CREATE OR REPLACE FUNCTION public.equipements_local_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, inventory INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_local'); END IF;
  RETURN jsonb_build_object('ok', true, 'emplacements', 2,
    'jouissance', public.local_jouissance_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room),
    'connexion', public.trading_connexion_interne(v_moi),
    'installes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'generique_id', e.generique_id,
                              'nom', coalesce(e.objet->>'name', e.generique_id), 'proprietaire', e.proprietaire,
                              'a_moi', e.proprietaire = v_moi) ORDER BY e.installe_le)
                            FROM public.equipements_installes e
                           WHERE e.pays = d.country AND e.ville = d.current_city AND e.batiment = d.current_building
                             AND e.piece = d.current_room), '[]'::jsonb),
    'installables', coalesce((SELECT jsonb_agg(DISTINCT o->>'generique_id')
                                FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
                               WHERE o->>'generique_id' IN ('ordinateur-complet', 'box-internet')), '[]'::jsonb));
END; $function$;

CREATE OR REPLACE FUNCTION public.equipement_installer(p_generique text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_pos integer; v_obj jsonb; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_generique IS NULL OR p_generique NOT IN ('ordinateur-complet', 'box-internet') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'equipement_inconnu'); END IF;
  SELECT country, current_city, current_building, current_room, inventory INTO d
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_local'); END IF;
  IF NOT public.local_jouissance_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jouissance'); END IF;
  PERFORM 1 FROM public.equipements_installes
   WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building AND piece = d.current_room FOR UPDATE;
  SELECT count(*) INTO v_n FROM public.equipements_installes
   WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building AND piece = d.current_room;
  IF v_n >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'emplacements_pleins', 'emplacements', 2); END IF;
  IF EXISTS (SELECT 1 FROM public.equipements_installes WHERE proprietaire = v_moi AND generique_id = p_generique
               AND pays = d.country AND ville = d.current_city AND batiment = d.current_building AND piece = d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_installe'); END IF;
  SELECT (o.ord - 1)::integer, o.val INTO v_pos, v_obj
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END)
         WITH ORDINALITY AS o(val, ord)
   WHERE o.val->>'generique_id' = p_generique ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = v_moi;
  INSERT INTO public.equipements_installes (proprietaire, pays, ville, batiment, piece, generique_id, objet)
  VALUES (v_moi, d.country, d.current_city, d.current_building, d.current_room, p_generique, v_obj);
  RETURN jsonb_build_object('ok', true, 'generique_id', p_generique)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

CREATE OR REPLACE FUNCTION public.equipement_desinstaller(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; e public.equipements_installes; d record; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id FOR UPDATE;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  IF e.proprietaire <> v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF d.country IS DISTINCT FROM e.pays OR d.current_city IS DISTINCT FROM e.ville
     OR d.current_building IS DISTINCT FROM e.batiment OR d.current_room IS DISTINCT FROM e.piece THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi)) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_dep := public.inventaire_deposer_interne(v_moi, e.objet);
  IF (v_dep->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'equipement: depot refuse'; END IF;
  DELETE FROM public.equipements_installes WHERE id = e.id;
  RETURN jsonb_build_object('ok', true, 'generique_id', e.generique_id)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- Organisations economiques ou le PJ peut trader : chef, ou membre autorise par le chef (data.traders).
CREATE OR REPLACE FUNCTION public.trading_organisations_interne(p_acteur text)
 RETURNS TABLE(id text, nom text, chef boolean, caisse numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT o.id, o.data::jsonb->>'nom', (o.data::jsonb->>'chef') = p_acteur,
         coalesce(CASE WHEN jsonb_typeof(o.data::jsonb->'caisse') = 'number' THEN (o.data::jsonb->>'caisse')::numeric END, 0)
    FROM public.organisations o
   WHERE o.data::jsonb->>'type' = 'economique'
     AND ( (o.data::jsonb->>'chef') = p_acteur
        OR (jsonb_typeof(o.data::jsonb->'traders') = 'array' AND (o.data::jsonb->'traders') ? p_acteur));
$function$;

CREATE OR REPLACE FUNCTION public.trading_cours()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.trading_connexion_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true,
    'organisations', coalesce((SELECT jsonb_agg(jsonb_build_object('id', t.id, 'nom', t.nom, 'chef', t.chef, 'caisse', t.caisse))
                                 FROM public.trading_organisations_interne(v_moi) t), '[]'::jsonb),
    'entrepots', coalesce((
      SELECT jsonb_agg(jsonb_build_object('id', v_pays || '_' || ep.ville || '_' || ep.building_id, 'ville', ep.ville,
               'batiment', ep.building_id,
               'cours', (SELECT coalesce(jsonb_agg(jsonb_build_object('ressource', r.cle,
                           'prix', coalesce((ent->'prixManuel'->>r.cle)::numeric, r.prix_base),
                           'disponible', greatest(0, floor(coalesce((ent->'stock'->>r.cle)::numeric, 0)
                                                  - coalesce((ent->'reserveMilitaire'->>r.cle)::numeric, 0))))
                           ORDER BY r.cle), '[]'::jsonb) FROM public.ressources_economie r))
             ORDER BY ep.ville)
        FROM public.entrepots_par_ville ep
        CROSS JOIN LATERAL (SELECT coalesce(public.batiment_etat_lire(b.data)->'entrepot', '{}'::jsonb) AS ent
                              FROM public.batiments_etat b WHERE b.id = v_pays || '_' || ep.ville || '_' || ep.building_id) x), '[]'::jsonb));
END; $function$;

CREATE OR REPLACE FUNCTION public.trading_acheter(p_organisation text, p_entrepot text, p_ressource text, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_org record; v_ville text; v_bat text; v_etat jsonb; v_ent jsonb; v_prix numeric;
  v_dispo numeric; v_total numeric; v_caisse_ent text; v_rep jsonb; v_caisse uuid; v_objet jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.trading_connexion_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  IF p_quantite IS NULL OR p_quantite <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  SELECT * INTO v_org FROM public.trading_organisations_interne(v_moi) t WHERE t.id = p_organisation;
  IF v_org.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_trader'); END IF;
  SELECT name, country, pa INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  SELECT ep.ville, ep.building_id INTO v_ville, v_bat FROM public.entrepots_par_ville ep
   WHERE m.country || '_' || ep.ville || '_' || ep.building_id = p_entrepot;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_inconnu'); END IF;
  v_caisse_ent := public.entrepot_caisse_id(p_entrepot);
  IF v_caisse_ent IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree'); END IF;
  PERFORM 1 FROM public.batiments_etat WHERE id = p_entrepot FOR UPDATE;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = p_entrepot;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_dispo := floor(coalesce((v_ent->'stock'->>p_ressource)::numeric, 0) - coalesce((v_ent->'reserveMilitaire'->>p_ressource)::numeric, 0));
  IF v_dispo < p_quantite THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'disponible', greatest(0, v_dispo)); END IF;
  v_prix := coalesce((v_ent->'prixManuel'->>p_ressource)::numeric, (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource));
  v_total := round(p_quantite * v_prix, 2);
  -- La caisse de l'organisation paie ; elle ne descend jamais sous zero.
  IF NOT public.mouvement_titulaire('orga:' || p_organisation, -v_total) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_organisation_insuffisante', 'montant', v_total, 'caisse', v_org.caisse); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1 WHERE name = v_moi;
  v_ent := v_ent || jsonb_build_object('stock', jsonb_set(coalesce(v_ent->'stock', '{}'::jsonb), ARRAY[p_ressource],
                    to_jsonb(coalesce((v_ent->'stock'->>p_ressource)::numeric, 0) - p_quantite)));
  UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', v_ent))::text), updated_at = now()
   WHERE id = p_entrepot;
  v_rep := public.caisse_institution_mouvement(v_caisse_ent, v_total, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'trading: credit entrepot refuse'; END IF;
  INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
  VALUES (p_entrepot, 'commande_directe', 'sortie', v_org.nom || ' (trading)', p_ressource, p_quantite, v_prix, 0, v_total, 'comptant', v_moi);
  -- Caisse de fret vers le port industriel de PSM, deja dedouanee (achat interieur).
  INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
      ville_destination, building_destination, statut, declaration_douaniere, valeur_declaree, receptionnaires_autorises,
      dedouanee, date_dedouanement, date_fermeture, date_depart, date_arrivee_prevue)
  VALUES (v_moi, m.country, v_ville, v_bat, v_moi, m.country, 'ville_a', 'port-sainte-marie', 'en_transit',
      'Matières premières — achat de trading (' || v_org.nom || ')', v_total, ARRAY[v_moi],
      true, now(), now(), now(), now() + interval '1 day')
  RETURNING id INTO v_caisse;
  v_objet := jsonb_build_object('name', p_ressource, 'stackable', true, 'stackKey', p_ressource,
                                'desc', 'Matière première achetée par trading.');
  INSERT INTO public.contenu_caisses_fret (caisse_id, deposant, objet, quantite) VALUES (v_caisse, v_moi, v_objet, p_quantite);
  RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite, 'prix_unitaire', v_prix,
    'montant', v_total, 'caisse_fret', v_caisse, 'organisation', v_org.nom, 'pa', m.pa - 1,
    'arrivee', 'port-sainte-marie');
END; $function$;

-- Le chef autorise ou retire un membre comme trader.
CREATE OR REPLACE FUNCTION public.organisation_trader_autoriser(p_organisation text, p_membre text, p_autorise boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_d jsonb; v_t jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data::jsonb INTO v_d FROM public.organisations WHERE id = p_organisation FOR UPDATE;
  IF v_d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable'); END IF;
  IF v_d->>'type' <> 'economique' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_economique'); END IF;
  IF v_d->>'chef' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef'); END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_d->'membres') = 'array' THEN v_d->'membres' ELSE '[]'::jsonb END) mb
                  WHERE mb->>'nom' = p_membre) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre'); END IF;
  v_t := CASE WHEN jsonb_typeof(v_d->'traders') = 'array' THEN v_d->'traders' ELSE '[]'::jsonb END;
  v_t := coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements_text(v_t) x WHERE x <> p_membre), '[]'::jsonb);
  IF p_autorise THEN v_t := v_t || to_jsonb(p_membre); END IF;
  UPDATE public.organisations SET data = (v_d || jsonb_build_object('traders', v_t))::text WHERE id = p_organisation;
  RETURN jsonb_build_object('ok', true, 'traders', v_t);
END; $function$;

-- Lecture pour le chef : membres et traders autorises de ses organisations economiques.
CREATE OR REPLACE FUNCTION public.trading_traders_lire()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true, 'organisations', coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id, 'nom', o.data::jsonb->>'nom',
           'membres', (SELECT coalesce(jsonb_agg(mb->>'nom'), '[]'::jsonb) FROM jsonb_array_elements(
                         CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array' THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) mb
                        WHERE mb->>'nom' <> public.mon_personnage()),
           'traders', CASE WHEN jsonb_typeof(o.data::jsonb->'traders') = 'array' THEN o.data::jsonb->'traders' ELSE '[]'::jsonb END)), '[]'::jsonb))
    FROM public.organisations o
   WHERE o.data::jsonb->>'type' = 'economique' AND o.data::jsonb->>'chef' = public.mon_personnage();
$function$;

-- Le contenu d'une caisse de fret ne se depose que par le serveur : trading_acheter rejoint fret_objet_agir.
DO $$
DECLARE f text;
BEGIN
  f := pg_get_functiondef('public.fret_contenu_source_garder()'::regprocedure);
  IF position('trading_acheter' IN f) > 0 THEN RETURN; END IF;
  IF position('<>''/rpc/fret_objet_agir''' IN f) = 0 THEN RAISE EXCEPTION 'fret_contenu_source_garder_definition_non_examinee'; END IF;
  f := replace(f, '<>''/rpc/fret_objet_agir''', ' NOT IN (''/rpc/fret_objet_agir'', ''/rpc/trading_acheter'')');
  EXECUTE f;
END $$;

REVOKE ALL ON FUNCTION public.local_jouissance_interne(text,text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trading_connexion_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trading_organisations_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.equipements_local_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equipement_installer(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equipement_desinstaller(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trading_cours() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trading_acheter(text,text,text,integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.organisation_trader_autoriser(text,text,boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trading_traders_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipements_local_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.equipement_installer(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.equipement_desinstaller(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trading_cours() TO authenticated;
GRANT EXECUTE ON FUNCTION public.trading_acheter(text,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.organisation_trader_autoriser(text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trading_traders_lire() TO authenticated;
