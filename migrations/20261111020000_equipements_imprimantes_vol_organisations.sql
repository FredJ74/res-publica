-- MATERIELS PAR COMBINAISON, ETAPES 4 A 6 : IMPRIMANTES ET BANQUE DE PLANS 3D, VOL DE MATERIEL, MATERIEL DES ORGANISATIONS
-- (decisions de Fred du 31/10 et du 10/11/2026, GAME-DESIGN-EQUIPEMENTS.md, decisions 12 a 15, 17 et 18).
--  * Ordinateur + imprimante papier dans le bureau : faux document sans detection sur place, 45 + 25 = 70 % (moins le malus
--    ISN), une cartouche d'encre au lieu de 300 FR, trace ; le faux est range en dossier et reimprimable (1 cartouche, 1 PA,
--    sans jet).
--  * Ordinateur + imprimante 3D : 1 plastique (derives_petrochimiques) + 1 PA par objet ; couteau en plastique (bonus de
--    combat rapproche 3, moitie du couteau de poche, legal donc jamais saisi en douane) ; souvenir imprime depuis un plan.
--  * Banque de plans 3D (internet, aucun lieu) : avec ordinateur + box, achat legal du plan de tout souvenir du jeu
--    (2 x cout de revient, echelle du pays), ou piratage (3 PA, 45 %, trace, pas d'intranet) pour l'obtenir gratuitement.
--  * Voler du materiel installe : dans la piece, 3 PA, 20 % +/- (DUP - 10), une piece au choix ; detection commune du vol,
--    repere = flagrant delit au bareme du vol (et rien n'est pris) ; trace toujours. L'objet vole emporte ses dossiers.
--  * Organisations : le chef cede a l'organisation un materiel installe dans un local loue par elle ; il autorise nommement
--    les membres qui s'en servent (PA de l'utilisateur), rapports de camera au chef et aux membres autorises.
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note)
VALUES ('Couteau en plastique', 'cac', 3, 'Imprimante 3D (Fred, 10/11/2026) : moitie du couteau de poche, legal, jamais saisi.')
ON CONFLICT (cle) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.organisation_materiel_autorises (
  organisation text NOT NULL,
  membre       text NOT NULL,
  autorise_le  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organisation, membre)
);
ALTER TABLE public.organisation_materiel_autorises ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.organisation_materiel_autorises FROM anon, authenticated;

-- Materiel « a moi » : le mien, ou celui d'une organisation dont je suis chef ou membre autorise.
CREATE OR REPLACE FUNCTION public.equipement_a_moi_interne(p_proprietaire text, p_acteur text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT p_proprietaire = p_acteur
      OR (left(p_proprietaire, 5) = 'orga:'
          AND (EXISTS (SELECT 1 FROM public.organisations o
                        WHERE o.id = substr(p_proprietaire, 6) AND o.data::jsonb->>'chef' = p_acteur)
               OR EXISTS (SELECT 1 FROM public.organisation_materiel_autorises m
                           WHERE m.organisation = substr(p_proprietaire, 6) AND m.membre = p_acteur)));
$function$;

CREATE OR REPLACE FUNCTION public.equipements_destinataires_interne(p_proprietaire text)
RETURNS SETOF text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_proprietaire WHERE left(p_proprietaire, 5) <> 'orga:'
  UNION
  SELECT o.data::jsonb->>'chef' FROM public.organisations o WHERE left(p_proprietaire, 5) = 'orga:' AND o.id = substr(p_proprietaire, 6)
  UNION
  SELECT m.membre FROM public.organisation_materiel_autorises m WHERE left(p_proprietaire, 5) = 'orga:' AND m.organisation = substr(p_proprietaire, 6);
$$;

-- Retirer une unite d'un objet de l'inventaire (generique, cle de pile ou type). Faux si absent.
CREATE OR REPLACE FUNCTION public.inventaire_retirer_un_interne(p_acteur text, p_cle text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; v_pos integer; v_obj jsonb; v_qte integer;
BEGIN
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  SELECT (o.ord - 1)::integer, o.val INTO v_pos, v_obj FROM jsonb_array_elements(v_inv) WITH ORDINALITY o(val, ord)
   WHERE p_cle IN (o.val->>'generique_id', o.val->>'stackKey', o.val->>'type') ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN false; END IF;
  v_qte := CASE WHEN coalesce(v_obj->>'qty', '') ~ '^[0-9]+$' THEN (v_obj->>'qty')::integer ELSE 1 END;
  IF v_qte > 1 THEN
    v_inv := jsonb_set(v_inv, ARRAY[v_pos::text, 'qty'], to_jsonb(v_qte - 1));
  ELSE
    v_inv := v_inv - v_pos;
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_acteur;
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.equipements_bureau_a_interne(p_acteur text, p_generiques text[])
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (SELECT count(DISTINCT generique_id) FROM public.equipements_bureau_interne(p_acteur) WHERE generique_id = ANY (p_generiques))
         = cardinality(p_generiques);
$$;

CREATE OR REPLACE FUNCTION public.faux_document_objet_interne(p_doc text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_doc
    WHEN 'fausse_identite' THEN '{"name":"Fausse identite","icon":"ti-id-badge","desc":"Change votre nom affiche dans le jeu temporairement."}'
    WHEN 'faux_permis' THEN '{"name":"Faux permis de construire","icon":"ti-building","desc":"Permet de construire sans passer par la mairie."}'
    WHEN 'faux_contrat' THEN '{"name":"Faux contrat commercial","icon":"ti-file-text","desc":"Legitime une transaction illegale ou un transfert."}'
    WHEN 'fausse_convocation' THEN '{"name":"Fausse convocation officielle","icon":"ti-mail","desc":"Attire un PJ dans un lieu de votre choix."}'
  END::jsonb;
$$;

-- Faux document a l'imprimante (bureau equipe d'un ordinateur et d'une imprimante papier).
CREATE OR REPLACE FUNCTION public.faux_document_imprimer(p_doc text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); m record; v_doc jsonb; v_taux integer; v_jet integer; v_dossier uuid;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_doc := public.faux_document_objet_interne(p_doc);
  IF v_doc IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'document_inconnu'); END IF;
  SELECT pa, country, current_city, inventory INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT public.equipements_bureau_a_interne(a, ARRAY['ordinateur-complet', 'imprimante-papier']) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_imprimante'); END IF;
  IF coalesce(m.pa, 0) < 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF NOT public.inventaire_retirer_un_interne(a, 'cartouche-encre') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_cartouche'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 3 WHERE name = a;
  PERFORM public.crime_tracer_interne(a, 'falsifier_document', v_doc->>'name');
  v_taux := greatest(5, 70 - public.crime_malus_isn_interne(m.country, m.current_city));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet, 'pa', m.pa - 3)
        || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  END IF;
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
       || jsonb_build_array(v_doc || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
            'type', 'document_falsifie', 'docId', p_doc, 'legal', false))
   WHERE name = a;
  v_dossier := public.dossier_ranger_interne(a, 'faux_document', v_doc->>'name', 'Modèle : ' || (v_doc->>'name') || E'\n' || (v_doc->>'desc'),
                                             jsonb_build_object('doc', p_doc));
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet, 'pa', m.pa - 3, 'nom_document', v_doc->>'name', 'dossier', v_dossier)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;
REVOKE ALL ON FUNCTION public.faux_document_imprimer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.faux_document_imprimer(text) TO authenticated;

-- Reimprimer un faux deja range (1 cartouche, 1 PA, sans jet) ou imprimer en 3D un plan de souvenir.
CREATE OR REPLACE FUNCTION public.dossier_imprimer(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); x public.dossiers_informatiques; m record; v_doc jsonb; r public.recettes_commerce; v_obj jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.dossier_accessible_interne(a, p_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossier_inaccessible'); END IF;
  SELECT * INTO x FROM public.dossiers_informatiques WHERE id = p_id;
  SELECT pa, inventory INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(m.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF public.inventaire_place_restante(m.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  IF x.donnees ? 'doc' THEN
    IF NOT public.equipements_bureau_a_interne(a, ARRAY['ordinateur-complet', 'imprimante-papier']) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_imprimante'); END IF;
    v_doc := public.faux_document_objet_interne(x.donnees->>'doc');
    IF NOT public.inventaire_retirer_un_interne(a, 'cartouche-encre') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_cartouche'); END IF;
    v_obj := v_doc || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''), 'type', 'document_falsifie',
                                         'docId', x.donnees->>'doc', 'legal', false);
    PERFORM public.crime_tracer_interne(a, 'falsifier_document', v_doc->>'name');
  ELSIF x.donnees ? 'recette' THEN
    IF NOT public.equipements_bureau_a_interne(a, ARRAY['ordinateur-complet', 'imprimante-3d']) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_imprimante_3d'); END IF;
    SELECT * INTO r FROM public.recettes_commerce WHERE id = x.donnees->>'recette';
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'plan_invalide'); END IF;
    IF NOT public.inventaire_retirer_un_interne(a, 'derives_petrochimiques') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_plastique'); END IF;
    v_obj := jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', ''), 'type', r.id, 'recette_id', r.id,
               'generique_id', r.generique_id, 'name', r.label, 'icon', coalesce(r.icone, 'ti-package'), 'imageUrl', r.image,
               'familleProduitMarche', r.famille_produit_marche, 'bonusIntegrationVille', r.bonus_integration_ville,
               'legal', true, 'imprime3d', true);
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_non_imprimable');
  END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1,
         inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END) || jsonb_build_array(v_obj)
   WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'objet', v_obj->>'name', 'pa', m.pa - 1)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;
REVOKE ALL ON FUNCTION public.dossier_imprimer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dossier_imprimer(uuid) TO authenticated;

-- Couteau en plastique (imprimante 3D).
CREATE OR REPLACE FUNCTION public.imprimer_couteau_plastique()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); m record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT pa, inventory INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT public.equipements_bureau_a_interne(a, ARRAY['ordinateur-complet', 'imprimante-3d']) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_imprimante_3d'); END IF;
  IF coalesce(m.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF public.inventaire_place_restante(m.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  IF NOT public.inventaire_retirer_un_interne(a, 'derives_petrochimiques') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_plastique'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1,
         inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
           || jsonb_build_array(jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', ''), 'type', 'couteau_plastique',
                'name', 'Couteau en plastique', 'icon', 'ti-knife', 'legal', true, 'categorie', 'arme', 'arme', 'Couteau en plastique',
                'desc', 'Imprimé en 3D : moins tranchant qu''un vrai couteau, mais invisible aux douaniers.'))
   WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'objet', 'Couteau en plastique', 'pa', m.pa - 1)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;
REVOKE ALL ON FUNCTION public.imprimer_couteau_plastique() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.imprimer_couteau_plastique() TO authenticated;

-- Banque de plans 3D : souvenirs du jeu (cartes postales, objets d'integration locale) et leur prix.
CREATE OR REPLACE FUNCTION public.plans3d_prix_interne(r public.recettes_commerce, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(1, round(2 * ((coalesce((SELECT sum((m.value)::numeric * coalesce(re.prix_base, 3))
                                            FROM jsonb_each_text(coalesce(r.materiaux, '{}'::jsonb)) m
                                            LEFT JOIN public.ressources_economie re ON re.cle = m.key), 0)
                                 + coalesce(r.pa, 1) * 50) / greatest(coalesce(r.portions, 1), 1))
                          / CASE WHEN p_pays = 'soviet' THEN 3 ELSE 1 END))::integer;
$$;

CREATE OR REPLACE FUNCTION public.plans3d_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.equipements_connecte_interne(a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'plans', coalesce((SELECT jsonb_agg(jsonb_build_object('id', r.id, 'label', r.label,
      'prix', public.plans3d_prix_interne(r, v_pays)) ORDER BY r.label)
    FROM public.recettes_commerce r WHERE r.famille_produit_marche IN ('carte_postale', 'integration_locale')), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.plans3d_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plans3d_lire() TO authenticated;

-- Obtenir un plan : achat legal ou piratage (3 PA, 45 % +/- INT, trace).
CREATE OR REPLACE FUNCTION public.plan3d_obtenir(p_recette text, p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); r public.recettes_commerce; m record; v_prix integer; v_paie jsonb; v_taux integer; v_jet integer; v_dossier uuid;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_mode NOT IN ('acheter', 'pirater') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide'); END IF;
  SELECT * INTO r FROM public.recettes_commerce WHERE id = p_recette AND famille_produit_marche IN ('carte_postale', 'integration_locale');
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'plan_invalide'); END IF;
  SELECT pa, stats, country INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT public.equipements_connecte_interne(a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  IF p_mode = 'acheter' THEN
    v_prix := public.plans3d_prix_interne(r, m.country);
    v_paie := public.debiter_fonds_ordinaires(a, v_prix);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  ELSE
    IF coalesce(m.pa, 0) < 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
    UPDATE public.personnages_donnees SET pa = pa - 3 WHERE name = a;
    PERFORM public.crime_tracer_interne(a, 'pirater', 'banque de plans 3D');
    v_taux := greatest(5, least(95, 45 + coalesce(CASE WHEN coalesce(m.stats->>'INT', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
                                                       THEN floor((m.stats->>'INT')::numeric)::integer END, 10) - 10));
    v_jet := floor(random() * 100)::integer + 1;
    IF v_jet > v_taux THEN RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet, 'pa', m.pa - 3); END IF;
  END IF;
  v_dossier := public.dossier_ranger_interne(a, 'plan_3d', 'Plan 3D — ' || r.label, 'Plan d''impression 3D : ' || r.label,
                                             jsonb_build_object('recette', r.id));
  IF v_dossier IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossiers_pleins'); END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'mode', p_mode, 'prix', v_prix, 'taux', v_taux, 'jet', v_jet,
                            'pa', CASE WHEN p_mode = 'pirater' THEN m.pa - 3 ELSE m.pa END, 'dossier', v_dossier, 'label', r.label);
END $$;
REVOKE ALL ON FUNCTION public.plan3d_obtenir(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plan3d_obtenir(text, text) TO authenticated;

-- Materiel installe ici et qui n'est pas a moi (cible d'un vol).
CREATE OR REPLACE FUNCTION public.equipements_voler_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  RETURN jsonb_build_object('ok', true, 'materiel', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'generique', e.generique_id) ORDER BY e.installe_le)
    FROM public.equipements_installes e WHERE e.pays = l.pays AND e.ville = l.ville AND e.batiment = l.batiment AND e.piece = l.piece
      AND e.generique_id <> 'armoire_souvenirs' AND NOT public.equipement_a_moi_interne(e.proprietaire, a)), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.equipements_voler_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipements_voler_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.voler_materiel(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); m record; l record; e public.equipements_installes; v_taux integer; v_jet integer;
        v_repere boolean; v_arr jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT pa, stats, inventory INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR e.generique_id = 'armoire_souvenirs' THEN RETURN jsonb_build_object('ok', false, 'raison', 'equipement_introuvable'); END IF;
  IF public.equipement_a_moi_interne(e.proprietaire, a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_vous'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  IF (l.pays, l.ville, l.batiment, l.piece) IS DISTINCT FROM (e.pays, e.ville, e.batiment, e.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce(m.pa, 0) < 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF public.inventaire_place_restante(m.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 3 WHERE name = a;
  PERFORM public.crime_tracer_interne(a, 'vol', 'matériel informatique');
  v_repere := public.crime_detecter_interne(a, 'vol', true);
  IF v_repere THEN
    v_arr := public.arrestation_flagrant_interne(a, 'vol', false, 'voler_materiel', 'Surpris en train de voler du matériel informatique');
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'repere', true, 'arrestation', v_arr, 'pa', m.pa - 3) || public.crime_etat_acteur_interne(a);
  END IF;
  v_taux := greatest(1, least(95, 20 + coalesce(CASE WHEN coalesce(m.stats->>'DUP', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
                                                     THEN floor((m.stats->>'DUP')::numeric)::integer END, 10) - 10));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'repere', false, 'taux', v_taux, 'jet', v_jet, 'pa', m.pa - 3) || public.crime_etat_acteur_interne(a);
  END IF;
  DELETE FROM public.equipements_installes WHERE id = e.id;
  UPDATE public.personnages_donnees
     SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END) || jsonb_build_array(e.objet)
   WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet, 'pa', m.pa - 3, 'generique', e.generique_id)
      || public.crime_etat_acteur_interne(a)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;
REVOKE ALL ON FUNCTION public.voler_materiel(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.voler_materiel(uuid) TO authenticated;

-- Organisations : le chef cede un materiel installe dans un local loue par l'organisation, et autorise des membres.
CREATE OR REPLACE FUNCTION public.equipement_ceder_organisation(p_id uuid, p_organisation text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.equipements_installes;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = p_organisation AND o.data::jsonb->>'chef' = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef'); END IF;
  SELECT * INTO e FROM public.equipements_installes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR e.proprietaire <> a THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.locations_actives l WHERE l.id = e.pays || ':' || e.batiment || ':' || e.piece || ':' || e.ville
                    AND l.data->>'orgaId' = p_organisation) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'local_pas_a_organisation'); END IF;
  UPDATE public.equipements_installes SET proprietaire = 'orga:' || p_organisation WHERE id = e.id;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE ALL ON FUNCTION public.equipement_ceder_organisation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipement_ceder_organisation(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.organisation_materiel_autoriser(p_organisation text, p_membre text, p_autorise boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); o jsonb; v_membre boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT data::jsonb INTO o FROM public.organisations WHERE id = p_organisation;
  IF o IS NULL OR o->>'chef' IS DISTINCT FROM a THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef'); END IF;
  v_membre := EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o->'membres') = 'array' THEN o->'membres' ELSE '[]'::jsonb END) mb
                       WHERE mb->>'nom' = p_membre);
  IF p_autorise AND NOT v_membre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre'); END IF;
  IF p_autorise THEN
    INSERT INTO public.organisation_materiel_autorises (organisation, membre) VALUES (p_organisation, p_membre) ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.organisation_materiel_autorises WHERE organisation = p_organisation AND membre = p_membre;
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE ALL ON FUNCTION public.organisation_materiel_autoriser(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.organisation_materiel_autoriser(text, text, boolean) TO authenticated;

-- Organisations dont je suis chef, leurs membres et les autorises (ecran du bureau).
CREATE OR REPLACE FUNCTION public.organisation_materiel_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'organisations', coalesce((SELECT jsonb_agg(jsonb_build_object('id', o.id, 'nom', o.data::jsonb->>'nom',
      'membres', coalesce((SELECT jsonb_agg(jsonb_build_object('nom', mb->>'nom',
                  'autorise', EXISTS (SELECT 1 FROM public.organisation_materiel_autorises x WHERE x.organisation = o.id AND x.membre = mb->>'nom')))
                 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array' THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) mb
                WHERE mb->>'nom' IS DISTINCT FROM a), '[]'::jsonb)))
    FROM public.organisations o WHERE o.data::jsonb->>'chef' = a), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.organisation_materiel_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.organisation_materiel_lire() TO authenticated;

COMMIT;
