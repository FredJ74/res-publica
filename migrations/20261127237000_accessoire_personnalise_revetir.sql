-- Mission du 27/11/2026 (soir, Claude), étape 7 — Accessoire personnalisé et règle des objets revêtus (décision de Fred).
--   • À la buvette des stades, « Acheter un accessoire personnalisé » fabrique un maillot, une casquette ou une écharpe du club
--     local, personnalisé par l'acheteur, dont l'image est générée par IA à partir de sa demande (chaîne existante : fonction
--     Edge sur le modèle de publicite-premium, gpt-image et sa modération). L'objet rejoint l'inventaire.
--   • +10 popularité tant qu'il est revêtu (ordre « Revêtir », comme le masque ou la tenue de ninja) ; les points disparaissent
--     s'il est retiré, vendu, donné ou volé ; un accessoire par type porté, cumulable.
--   • Règle générale : jamais plus de DEUX objets revêtus à la fois, quels qu'ils soient ; le serveur refuse le troisième.
--   • Achat ouvert à tous, payé à l'unité en argent réel, prix réglé dans la page MJ (premium_produits). Le prestataire de
--     paiement n'est pas choisi : tout est codé sauf le paiement ; l'écran affiche « Paiement bientôt disponible » sans rien
--     débiter ni créer. La livraison (accessoire_personnalise_livrer_service) n'est appelable que par le serveur, après un
--     paiement confirmé.
--
-- Contrôles en lecture après application :
--   SELECT nature FROM public.premium_produits WHERE produit = 'accessoire_personnalise';                         -- unite
--   SELECT position('revetus_deux_max_v1' in pg_get_functiondef('public.crim_revetir(integer,jsonb)'::regprocedure)) > 0; -- vrai
--   SELECT tgname FROM pg_trigger WHERE tgname = 'accessoires_revetus_popularite';                               -- 1 ligne
BEGIN;

INSERT INTO public.premium_produits (produit, nature, libelle, prix_centimes)
VALUES ('accessoire_personnalise', 'unite', 'Accessoire de club personnalisé (maillot, casquette ou écharpe)', NULL)
ON CONFLICT (produit) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.accessoires_personnalises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acheteur_user_id uuid NOT NULL,
  acheteur_nom text NOT NULL,
  pays text NOT NULL,
  ville text NOT NULL,
  club text NOT NULL,
  type_accessoire text NOT NULL CHECK (type_accessoire IN ('maillot', 'casquette', 'echarpe')),
  demande text NOT NULL CHECK (char_length(demande) BETWEEN 3 AND 300),
  etat text NOT NULL DEFAULT 'commande' CHECK (etat IN ('commande', 'apercu', 'livre', 'annule')),
  paiement_confirme_le timestamptz,
  achat_id text,
  apercu_path text,
  image_path text,
  retouches integer NOT NULL DEFAULT 0,
  cree_le timestamptz NOT NULL DEFAULT now(),
  livre_le timestamptz
);
ALTER TABLE public.accessoires_personnalises ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accessoires_personnalises FROM PUBLIC, anon, authenticated;

-- Offre affichée au joueur (aucune écriture) : club local, prix fixé par le MJ, paiement ouvert ou non.
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_offre()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; c record; v_prix integer;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = moi;
  -- Même lieu que les accessoires de club (club_accessoire_acheter) : buvette, ou boutique des stades de Sovarka.
  IF p.current_building IS DISTINCT FROM 'stade' OR (p.current_room IS DISTINCT FROM 'buvette'
     AND NOT (p.country = 'soviet' AND p.current_city IN ('capitale', 'ville_b', 'ville_a') AND p.current_room = 'boutique')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country = p.country AND city = p.current_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_local_introuvable'); END IF;
  SELECT prix_centimes INTO v_prix FROM public.premium_produits WHERE produit = 'accessoire_personnalise';
  -- Prestataire de paiement non choisi (Fred, 27/11/2026) : le paiement reste fermé.
  RETURN jsonb_build_object('ok', true, 'club', c.nom, 'prix_centimes', v_prix, 'paiement_ouvert', false);
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_offre() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_offre() TO authenticated;

-- Livraison, appelée par le serveur seulement (fonction Edge, après paiement confirmé et image validée).
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_livrer_service(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a public.accessoires_personnalises%ROWTYPE; v_obj jsonb; v_dep jsonb;
BEGIN
  SELECT * INTO a FROM public.accessoires_personnalises WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_introuvable'); END IF;
  IF a.etat = 'livre' THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF a.paiement_confirme_le IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'paiement_requis'); END IF;
  IF a.etat <> 'apercu' OR a.apercu_path IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'image_requise'); END IF;
  v_obj := jsonb_build_object(
    'name', CASE a.type_accessoire WHEN 'maillot' THEN 'Maillot personnalisé' WHEN 'casquette' THEN 'Casquette personnalisée'
              ELSE 'Écharpe personnalisée' END || ' — ' || a.club,
    'type', 'accessoire_club_perso', 'revetable', 'accessoire_' || a.type_accessoire, 'bonus_pop_revetu', 10,
    'icon', CASE a.type_accessoire WHEN 'maillot' THEN 'ti-shirt-sport' WHEN 'casquette' THEN 'ti-baseball' ELSE 'ti-ribbon-health' END,
    'image', a.apercu_path, 'personnalisation', a.demande, 'accessoire_id', a.id::text, 'encombrement', 1,
    'desc', 'Accessoire du club ' || a.club || ', personnalisé : « ' || a.demande || ' ». +10 popularité tant qu''il est revêtu.');
  v_dep := public.inventaire_deposer_interne(a.acheteur_nom, v_obj, true);
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_dep; END IF;
  UPDATE public.accessoires_personnalises SET etat = 'livre', image_path = a.apercu_path, livre_le = now() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'objet', v_obj ->> 'name');
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_livrer_service(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_livrer_service(uuid) TO service_role;

-- Revêtir : un objet par catégorie (inchangé) et jamais plus de deux objets revêtus à la fois.
CREATE OR REPLACE FUNCTION public.crim_revetir(p_index integer, p_signature jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); d record; v_pos integer; v_item jsonb; v_cat text; v_inv jsonb; v_portes integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT inventory, est_emprisonne, hospitalisation INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF jsonb_typeof(d.inventory) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_format_a_examiner'); END IF;
  IF coalesce(jsonb_typeof(d.est_emprisonne), 'null') <> 'null' AND d.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF coalesce(d.hospitalisation ->> 'dateFinParis', '') > ((statement_timestamp() AT TIME ZONE 'Europe/Paris')::date)::text THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hospitalise'); END IF;
  v_pos := public.inventaire_localiser(d.inventory, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_introuvable'); END IF;
  v_item := d.inventory -> v_pos;
  v_cat := public.crim_objet_categorie_interne(v_item);
  IF v_cat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_revetable'); END IF;
  IF public.crim_porte_ligne_interne(v_item, a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_revetu'); END IF;
  -- revetus_deux_max_v1 (Fred, 27/11/2026) : l'objet de même catégorie est retiré d'office ; les autres comptent.
  SELECT count(*) INTO v_portes FROM jsonb_array_elements(d.inventory) e
   WHERE public.crim_porte_ligne_interne(e, a) AND public.crim_objet_categorie_interne(e) IS DISTINCT FROM v_cat;
  IF v_portes >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deux_objets_revetus_max'); END IF;
  v_inv := public.crim_inventaire_devetir_interne(d.inventory, a, v_cat);
  v_inv := jsonb_set(v_inv, ARRAY[v_pos::text], (v_inv -> v_pos) || jsonb_build_object('porte_par', a));
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = a;
  IF v_cat = 'masque' THEN
    INSERT INTO public.crim_jetons_masque (personnage) VALUES (a)
    ON CONFLICT (personnage) DO UPDATE SET jeton = gen_random_uuid(), le = now();
  END IF;
  RETURN jsonb_build_object('ok', true, 'categorie', v_cat, 'objet', v_item ->> 'name', 'mode', public.crim_mode_action_interne(a))
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $function$;

-- +10 popularité par accessoire personnalisé revêtu : le bonus suit l'inventaire, quel que soit le chemin (revêtir,
-- retirer, vendre, donner, voler, abandonner). Un objet arrivé d'un autre inventaire n'est jamais compté comme revêtu.
CREATE OR REPLACE FUNCTION public.accessoires_revetus_bonus_interne(p_inv jsonb, p_nom text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(sum(coalesce((e ->> 'bonus_pop_revetu')::integer, 0)), 0)::integer
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) e
   WHERE e ->> 'type' = 'accessoire_club_perso' AND public.crim_porte_ligne_interne(e, p_nom)
$$;

CREATE OR REPLACE FUNCTION public.accessoires_revetus_popularite_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_delta integer; v_res jsonb;
BEGIN
  v_delta := public.accessoires_revetus_bonus_interne(NEW.inventory, NEW.name) - public.accessoires_revetus_bonus_interne(OLD.inventory, OLD.name);
  IF v_delta <> 0 THEN
    v_res := CASE WHEN jsonb_typeof(NEW.resources) = 'object' THEN NEW.resources ELSE '{}'::jsonb END;
    NEW.resources := v_res || jsonb_build_object('pop', greatest(0, least(100, coalesce((v_res ->> 'pop')::numeric, 0) + v_delta)));
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS accessoires_revetus_popularite ON public.personnages_donnees;
CREATE TRIGGER accessoires_revetus_popularite BEFORE UPDATE OF inventory ON public.personnages_donnees
  FOR EACH ROW WHEN (OLD.inventory IS DISTINCT FROM NEW.inventory) EXECUTE FUNCTION public.accessoires_revetus_popularite_trg();

COMMIT;
