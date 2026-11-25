-- Mission de jour du 25/11/2026 (Claude), bloc 3 (H.9) — APPLIQUÉE en production le 25/11/2026 au soir (feu vert de Fred, contrôlée en lecture).
-- ARMOIRE À SOUVENIRS : DÉPÔT ET COLLECTION, partie serveur, fidèle aux règles déjà écrites (guide du jeu, rubrique « ARMOIRE À
-- SOUVENIRS » de plateau-personnage.js ; GAME-DESIGN-SERRURES.md ; GAME-DESIGN-CRIMINALITE.md § 8 ; GAME-DESIGN-APPARTEMENTS.md).
-- • Listes en base (elles n'étaient qu'en code navigateur, LISTES_SOUVENIRS) : souvenirs_listes, souvenirs_emplacements (douze
--   emplacements, un par grande ville). Liste 1 recopiée mot pour mot. Une armoire garde la liste de son objet (listeId) ; à
--   défaut, le serveur lui en attribue une (stable, selon son numéro). Un emplacement se remplit par le souvenir EXACT : son nom
--   exact, ou la clé d'objet indiquée, ou — si la liste demande la carte postale d'une ville — une carte postale de ce modèle.
-- • Contenu tenu par le serveur (armoires_contenus, par numéro d'armoire = objet.id, comme les serrures). Les objets hors liste
--   n'y entrent pas, sauf les cartes postales, rangées sans compter pour la collection.
-- • Déposer (armoire_deposer) : le propriétaire, c.-à-d. qui a la jouissance du lieu où l'armoire est installée (vérifiée au
--   moment de l'acte), sur place. Reprendre (armoire_reprendre) : le propriétaire, ou un visiteur présent si l'armoire n'est pas
--   fermée à clé — ce n'est pas un vol, mais une affaire « ramasser » est enregistrée au nom du propriétaire et un constat lui dit
--   qu'il peut porter plainte pour vol (même chemin que les objets déposés, crim_ramasser). Fermée à clé : seulement avec une de
--   ses clés (déposer comme reprendre).
-- • Collection complète : +1 PA au personnage qui dort dans la même pièce que SON armoire complète (décision de Fred, 13/11/2026,
--   GAME-DESIGN-APPARTEMENTS.md), sans cumul entre armoires, cumulable avec le +1 PA de l'appartement. Réglage MJ
--   aliments_parametres.armoire_confort_pa (1). Raccord : pa_repos_nocturne (remplacement contrôlé, marque armoire_confort_v1).
-- • L'armoire doit être entièrement vidée avant tout déplacement ou désinstallation : refus « armoire_non_vide » dans
--   desinstaller_materiel et equipement_desinstaller (remplacements contrôlés, marque armoire_vide_v1).
-- Sans cette migration, l'écran garde l'ancienne fenêtre (lecture de l'objet) et n'affiche pas le bouton « Ouvrir l'armoire ».
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.souvenirs_emplacements WHERE liste_id = 1;                                        -- 12
--   SELECT valeur FROM public.aliments_parametres WHERE cle = 'armoire_confort_pa';                               -- 1
--   SELECT position('armoire_confort_v1' in pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) > 0;  -- vrai
--   SELECT position('armoire_vide_v1' in pg_get_functiondef('public.desinstaller_materiel(uuid,uuid)'::regprocedure)) > 0
--      AND position('armoire_vide_v1' in pg_get_functiondef('public.equipement_desinstaller(uuid)'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.armoire_deposer(uuid,uuid,text)', 'EXECUTE');              -- vrai
--   SELECT has_function_privilege('anon', 'public.armoire_lire(uuid)', 'EXECUTE');                                   -- faux
BEGIN;

-- 1. Listes de collection.
CREATE TABLE IF NOT EXISTS public.souvenirs_listes (id integer PRIMARY KEY, nom text NOT NULL);
CREATE TABLE IF NOT EXISTS public.souvenirs_emplacements (
  liste_id integer NOT NULL REFERENCES public.souvenirs_listes(id),
  rang integer NOT NULL CHECK (rang BETWEEN 1 AND 12),
  ville text NOT NULL,
  nom text NOT NULL,
  cle_objet text,          -- clé d'objet du souvenir (type, recetteId, stackKey), si elle existe
  carte_modele text,       -- modèle de carte postale demandé (la carte remplit alors l'emplacement)
  PRIMARY KEY (liste_id, rang)
);
ALTER TABLE public.souvenirs_listes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.souvenirs_emplacements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.souvenirs_listes, public.souvenirs_emplacements FROM PUBLIC, anon, authenticated;
INSERT INTO public.souvenirs_listes (id, nom) VALUES (1, 'Collection n°1') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.souvenirs_emplacements (liste_id, rang, ville, nom) VALUES
  (1, 1, 'Luthécia', 'Reproduction miniature du Palais présidentiel'),
  (1, 2, 'Montrouge', 'Ticket du cinéma de Montrouge'),
  (1, 3, 'Port Sainte-Marie', 'Mug « Port Sainte-Marie »'),
  (1, 4, 'Novomirsk', 'Poupée traditionnelle de Novomirsk'),
  (1, 5, 'Starovka', 'Flasque métallique gravée « Starovka »'),
  (1, 6, 'Krasnov', 'Insigne émaillé des hauts-fourneaux de Krasnov'),
  (1, 7, 'Ciudad Roja', 'Petit masque rouge du carnaval de Ciudad Roja'),
  (1, 8, 'Puerto Negro', 'Jeton du casino de Puerto Negro'),
  (1, 9, 'Villa Sangre', 'Crâne décoratif peint de Villa Sangre'),
  (1, 10, 'Al Madina', 'Petite lampe ouvragée d''Al Madina'),
  (1, 11, 'Oasis City', 'Boule à neige « Oasis City »'),
  (1, 12, 'Al-Petrol', 'Miniature de baril de pétrole doré')
ON CONFLICT (liste_id, rang) DO NOTHING;

-- 2. Contenu des armoires (par numéro d'armoire : objet.id de l'armoire).
CREATE TABLE IF NOT EXISTS public.armoires_contenus (
  id bigserial PRIMARY KEY,
  armoire_objet text NOT NULL,
  rang integer,            -- emplacement rempli ; NULL = carte postale rangée hors liste
  objet jsonb NOT NULL,
  depose_par text,
  depose_le timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS armoires_contenus_emplacement_idx ON public.armoires_contenus (armoire_objet, rang) WHERE rang IS NOT NULL;
CREATE INDEX IF NOT EXISTS armoires_contenus_armoire_idx ON public.armoires_contenus (armoire_objet);
ALTER TABLE public.armoires_contenus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.armoires_contenus FROM PUBLIC, anon, authenticated;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('armoire_confort_pa', 1) ON CONFLICT (cle) DO NOTHING;

-- 3. Fonctions internes.
CREATE OR REPLACE FUNCTION public.armoire_liste_interne(p_objet jsonb)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT l.id FROM public.souvenirs_listes l WHERE l.id::text = p_objet ->> 'listeId'),
    (SELECT l.id FROM public.souvenirs_listes l ORDER BY l.id
      OFFSET (abs(hashtext(coalesce(p_objet ->> 'id', ''))) % greatest(1, (SELECT count(*) FROM public.souvenirs_listes))) LIMIT 1)) /* armoire_souvenirs_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.armoire_est_carte_interne(p_item jsonb)
 RETURNS boolean LANGUAGE sql IMMUTABLE AS $function$
  SELECT coalesce(p_item ->> 'familleProduitMarche', '') = 'carte_postale' OR coalesce(p_item ->> 'type', '') = 'carte_postale'
$function$;

-- L'objet remplit-il cet emplacement ? (souvenir exact)
CREATE OR REPLACE FUNCTION public.armoire_correspond_interne(e public.souvenirs_emplacements, p_item jsonb)
 RETURNS boolean LANGUAGE sql IMMUTABLE AS $function$
  SELECT CASE
    WHEN e.carte_modele IS NOT NULL THEN public.armoire_est_carte_interne(p_item) AND coalesce(p_item ->> 'modele', p_item ->> 'type') = e.carte_modele
    WHEN e.cle_objet IS NOT NULL THEN e.cle_objet IN (p_item ->> 'recetteId', p_item ->> 'type', p_item ->> 'stackKey', p_item ->> 'produitId')
    ELSE btrim(coalesce(p_item ->> 'name', '')) = e.nom END
$function$;

-- Accès d'un personnage à une armoire installée.
CREATE OR REPLACE FUNCTION public.armoire_acces_interne(p_nom text, e public.equipements_installes)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; s public.serrures; v_present boolean; v_proprio boolean; v_cle boolean := false;
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_nom;
  v_present := (e.pays, e.ville, e.batiment, e.piece) IS NOT DISTINCT FROM (d.country, d.current_city, d.current_building, d.current_room);
  v_proprio := v_present AND public.local_jouissance_interne(p_nom, e.pays, e.ville, e.batiment, e.piece);
  SELECT * INTO s FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'armoire' AND x.armoire_objet = e.objet ->> 'id' LIMIT 1;
  IF s.id IS NOT NULL THEN v_cle := public.serrure_cle_detenue_interne(p_nom, s.id); END IF;
  RETURN jsonb_build_object('present', v_present, 'proprietaire', v_proprio, 'verrouillee', coalesce(s.fermee, false), 'cle', v_cle,
    'ouvrable', v_present AND (NOT coalesce(s.fermee, false) OR v_cle)); /* armoire_souvenirs_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.armoire_complete_interne(p_armoire text, p_liste integer)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (SELECT count(*) FROM public.souvenirs_emplacements WHERE liste_id = p_liste) > 0
     AND (SELECT count(*) FROM public.souvenirs_emplacements WHERE liste_id = p_liste)
       = (SELECT count(*) FROM public.armoires_contenus WHERE armoire_objet = p_armoire AND rang IS NOT NULL)
$function$;

-- Ce que voit le personnage (contenu, progression, droits, ce qu'il peut déposer depuis son inventaire).
CREATE OR REPLACE FUNCTION public.armoire_etat_interne(p_nom text, e public.equipements_installes)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_acc jsonb := public.armoire_acces_interne(p_nom, e); v_liste integer := public.armoire_liste_interne(e.objet);
        v_arm text := e.objet ->> 'id'; v_total integer; v_n integer; v_inv jsonb;
BEGIN
  SELECT count(*) INTO v_total FROM public.souvenirs_emplacements WHERE liste_id = v_liste;
  IF NOT (v_acc ->> 'ouvrable')::boolean THEN
    RETURN jsonb_build_object('ok', true, 'id', e.id, 'acces', v_acc, 'liste', (SELECT nom FROM public.souvenirs_listes WHERE id = v_liste), 'total', v_total);
  END IF;
  SELECT count(*) INTO v_n FROM public.armoires_contenus WHERE armoire_objet = v_arm AND rang IS NOT NULL;
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv FROM public.personnages_donnees WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true, 'id', e.id, 'acces', v_acc, 'liste', (SELECT nom FROM public.souvenirs_listes WHERE id = v_liste),
    'total', v_total, 'remplis', v_n, 'complete', v_total > 0 AND v_n = v_total,
    'emplacements', (SELECT coalesce(jsonb_agg(jsonb_build_object('rang', s.rang, 'ville', s.ville, 'nom', s.nom,
                       'contenu', c.id, 'objet', c.objet ->> 'name') ORDER BY s.rang), '[]'::jsonb)
                       FROM public.souvenirs_emplacements s
                       LEFT JOIN public.armoires_contenus c ON c.armoire_objet = v_arm AND c.rang = s.rang
                      WHERE s.liste_id = v_liste),
    'cartes', (SELECT coalesce(jsonb_agg(jsonb_build_object('contenu', c.id, 'objet', c.objet ->> 'name') ORDER BY c.id), '[]'::jsonb)
                 FROM public.armoires_contenus c WHERE c.armoire_objet = v_arm AND c.rang IS NULL),
    -- Le propriétaire voit ce qu'il peut déposer : un souvenir exact d'un emplacement vide, ou une carte postale.
    'deposables', CASE WHEN (v_acc ->> 'proprietaire')::boolean THEN (
        SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('ref', coalesce(nullif(o ->> 'id', ''), nullif(o ->> 'stackKey', ''), o ->> 'type'),
                 'nom', o ->> 'name', 'carte', public.armoire_est_carte_interne(o))), '[]'::jsonb)
          FROM jsonb_array_elements(v_inv) o
         WHERE public.armoire_est_carte_interne(o)
            OR EXISTS (SELECT 1 FROM public.souvenirs_emplacements s WHERE s.liste_id = v_liste AND public.armoire_correspond_interne(s, o)
                        AND NOT EXISTS (SELECT 1 FROM public.armoires_contenus c WHERE c.armoire_objet = v_arm AND c.rang = s.rang)))
      ELSE '[]'::jsonb END); /* armoire_souvenirs_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.armoire_installee_interne(p_equipement uuid)
 RETURNS public.equipements_installes LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT * FROM public.equipements_installes WHERE id = p_equipement AND generique_id = 'armoire_souvenirs' $function$;

-- 4. RPC.
CREATE OR REPLACE FUNCTION public.armoire_lire(p_equipement uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); e public.equipements_installes;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  e := public.armoire_installee_interne(p_equipement);
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_introuvable'); END IF;
  IF NOT (public.armoire_acces_interne(a, e) ->> 'present')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN public.armoire_etat_interne(a, e); /* armoire_souvenirs_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.armoire_deposer(p_requete uuid, p_equipement uuid, p_ref text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('equipement', p_equipement, 'ref', p_ref); v jsonb;
        e public.equipements_installes; v_acc jsonb; v_inv jsonb; v_pos integer; v_obj jsonb; v_liste integer; v_rang integer; v_arm text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_equipement IS NULL OR coalesce(p_ref, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'armoire_deposer', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_equipement AND generique_id = 'armoire_souvenirs' FOR UPDATE;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_introuvable'); END IF;
  v_acc := public.armoire_acces_interne(a, e);
  IF NOT (v_acc ->> 'present')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF NOT (v_acc ->> 'proprietaire')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF NOT (v_acc ->> 'ouvrable')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_fermee_a_cle'); END IF;
  SELECT (o.ord - 1)::integer, o.val INTO v_pos, v_obj FROM jsonb_array_elements(v_inv) WITH ORDINALITY o(val, ord)
   WHERE o.val ->> 'id' = p_ref OR o.val ->> 'stackKey' = p_ref OR o.val ->> 'type' = p_ref
   ORDER BY (o.val ->> 'id' = p_ref) DESC NULLS LAST, o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_liste := public.armoire_liste_interne(e.objet); v_arm := e.objet ->> 'id';
  SELECT s.rang INTO v_rang FROM public.souvenirs_emplacements s
   WHERE s.liste_id = v_liste AND public.armoire_correspond_interne(s, v_obj)
     AND NOT EXISTS (SELECT 1 FROM public.armoires_contenus c WHERE c.armoire_objet = v_arm AND c.rang = s.rang)
   ORDER BY s.rang LIMIT 1;
  IF v_rang IS NULL AND NOT public.armoire_est_carte_interne(v_obj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN EXISTS (SELECT 1 FROM public.souvenirs_emplacements s
      WHERE s.liste_id = v_liste AND public.armoire_correspond_interne(s, v_obj)) THEN 'emplacement_deja_rempli' ELSE 'hors_liste' END);
  END IF;
  -- Une seule unité quitte l'inventaire.
  IF coalesce((v_obj ->> 'stackable')::boolean, false) AND coalesce((v_obj ->> 'qty')::numeric, 1) > 1 THEN
    v_inv := jsonb_set(v_inv, ARRAY[v_pos::text, 'qty'], to_jsonb(coalesce((v_obj ->> 'qty')::numeric, 1) - 1));
    v_obj := jsonb_set(v_obj, '{qty}', '1'::jsonb);
  ELSE
    v_inv := v_inv - v_pos;
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = a;
  INSERT INTO public.armoires_contenus (armoire_objet, rang, objet, depose_par) VALUES (v_arm, v_rang, v_obj, a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'armoire_deposer', prm,
    public.armoire_etat_interne(a, e) || jsonb_build_object('depose', v_obj ->> 'name', 'rang', v_rang)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a)); /* armoire_souvenirs_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.armoire_reprendre(p_requete uuid, p_equipement uuid, p_contenu bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('equipement', p_equipement, 'contenu', p_contenu); v jsonb;
        e public.equipements_installes; v_acc jsonb; c public.armoires_contenus; v_dep jsonb; r jsonb; v_pj text; v_nom text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_equipement IS NULL OR p_contenu IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'armoire_reprendre', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_equipement AND generique_id = 'armoire_souvenirs' FOR UPDATE;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_introuvable'); END IF;
  v_acc := public.armoire_acces_interne(a, e);
  IF NOT (v_acc ->> 'present')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF NOT (v_acc ->> 'ouvrable')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_fermee_a_cle'); END IF;
  SELECT * INTO c FROM public.armoires_contenus WHERE id = p_contenu AND armoire_objet = e.objet ->> 'id' FOR UPDATE;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_repris'); END IF;
  v_dep := public.inventaire_deposer_interne(a, c.objet);
  IF (v_dep ->> 'ok')::boolean IS DISTINCT FROM true THEN RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_dep ->> 'raison', 'inventaire_plein')); END IF;
  DELETE FROM public.armoires_contenus WHERE id = c.id;
  -- Un visiteur vide une armoire ouverte : ce n'est pas un vol, mais le propriétaire peut porter plainte pour vol.
  IF NOT (v_acc ->> 'proprietaire')::boolean AND NOT public.equipement_a_moi_interne(e.proprietaire, a) THEN
    v_nom := coalesce(c.objet ->> 'name', 'un souvenir');
    r := public.crim_resoudre_interne('ramasser', a, NULL, jsonb_build_object('reussite_auto', true, 'detection', false,
           'indices', jsonb_build_object('objet', v_nom), 'objet', v_nom, 'armoire', e.objet ->> 'id'));
    UPDATE public.crim_affaires SET cible = e.proprietaire, maj_le = now() WHERE id = (r ->> 'affaire')::bigint;
    v_pj := public.crim_proprietaire_pj_interne(e.proprietaire);
    IF v_pj IS NOT NULL THEN
      INSERT INTO public.crim_constats (destinataire, pays, ville, batiment, piece, titre, corps, affaire)
      VALUES (v_pj, e.pays, e.ville, e.batiment, e.piece, 'Souvenir disparu',
              'En ouvrant votre armoire à souvenirs, vous constatez que « ' || replace(replace(v_nom, '{', '('), '}', ')')
              || ' » a disparu. Vous pouvez porter plainte pour vol.', (r ->> 'affaire')::bigint);
    END IF;
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'armoire_reprendre', prm,
    public.armoire_etat_interne(a, e) || jsonb_build_object('repris', c.objet ->> 'name')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a)); /* armoire_souvenirs_v1 */
END $function$;

-- Confort du sommeil : +1 PA (réglage MJ) dans la même pièce que SON armoire complète ; jamais plus d'une fois.
CREATE OR REPLACE FUNCTION public.armoire_confort_pa_interne(p_nom text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN EXISTS (
      SELECT 1 FROM public.equipements_installes e JOIN public.personnages_donnees d ON d.name = p_nom
       WHERE e.generique_id = 'armoire_souvenirs' AND (e.pays, e.ville, e.batiment, e.piece) = (d.country, d.current_city, d.current_building, d.current_room)
         AND public.equipement_a_moi_interne(e.proprietaire, p_nom)
         AND public.armoire_complete_interne(e.objet ->> 'id', public.armoire_liste_interne(e.objet)))
    THEN greatest(0, public.aliments_param_interne('armoire_confort_pa', 1))::integer ELSE 0 END /* armoire_confort_v1 */
$function$;

-- 5. Raccords contrôlés dans des fonctions existantes.
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

SELECT pg_temp.rp_remplacer('public.pa_repos_nocturne(text)'::regprocedure,
  $a$    IF v_logement IS NOT NULL THEN v_gain := v_gain + coalesce((v_logement->>'pa')::integer, 0); END IF;$a$,
  $b$    IF v_logement IS NOT NULL THEN v_gain := v_gain + coalesce((v_logement->>'pa')::integer, 0); END IF;
    v_gain := v_gain + public.armoire_confort_pa_interne(p_acteur); /* armoire_confort_v1 : armoire à souvenirs complète, cumulable avec le logement */$b$,
  1, 'armoire_confort_v1');

SELECT pg_temp.rp_remplacer('public.desinstaller_materiel(uuid,uuid)'::regprocedure,
  $a$  v_legal := public.local_jouissance_interne(a, m.country, m.current_city, m.current_building, m.current_room)$a$,
  $b$  IF e.generique_id = 'armoire_souvenirs' AND EXISTS (SELECT 1 FROM public.armoires_contenus x WHERE x.armoire_objet = e.objet ->> 'id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'armoire_non_vide'); END IF; /* armoire_vide_v1 */
  v_legal := public.local_jouissance_interne(a, m.country, m.current_city, m.current_building, m.current_room)$b$,
  1, 'armoire_vide_v1');

SELECT pg_temp.rp_remplacer('public.equipement_desinstaller(uuid)'::regprocedure,
  $a$  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))$a$,
  $b$  IF e.generique_id = 'armoire_souvenirs' AND EXISTS (SELECT 1 FROM public.armoires_contenus x WHERE x.armoire_objet = e.objet ->> 'id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'armoire_non_vide'); END IF; /* armoire_vide_v1 */
  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))$b$,
  1, 'armoire_vide_v1');

REVOKE ALL ON FUNCTION public.armoire_liste_interne(jsonb), public.armoire_acces_interne(text, public.equipements_installes),
  public.armoire_complete_interne(text, integer), public.armoire_etat_interne(text, public.equipements_installes),
  public.armoire_installee_interne(uuid), public.armoire_confort_pa_interne(text),
  public.armoire_correspond_interne(public.souvenirs_emplacements, jsonb), public.armoire_est_carte_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.armoire_lire(uuid), public.armoire_deposer(uuid, uuid, text), public.armoire_reprendre(uuid, uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.armoire_lire(uuid), public.armoire_deposer(uuid, uuid, text), public.armoire_reprendre(uuid, uuid, bigint) TO authenticated;

COMMIT;
