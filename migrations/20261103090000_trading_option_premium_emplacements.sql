-- APPLIQUEE le 03/11/2026 par Claude (registre trading_option_premium_emplacements_20261103090000), apres le banc
-- annule outils/bancs/banc-trading-option-premium.sql joue en production (9 cas conformes).
-- 3 novembre 2026 -- TRADING : option premium « 6 emplacements » d'un bureau (3 en gratuit).
--
-- Decisions de Fred du 03/11 (GAME-DESIGN-TRADING.md, points 17 a 19) : pas de compte premium mais des
-- options premium payantes ; un bureau offre 3 emplacements d'equipement en gratuit, 6 avec l'option ;
-- l'option s'achete pour UN bureau, definitive tant que l'acheteur garde ce bureau (perdue avec la
-- jouissance) ; gratuite pendant la beta (comme la publicite premium), le paiement viendra plus tard.
--
-- NOUVEAU : table bureaux_option_premium, equipements_emplacements_interne (3 ou 6, seul endroit qui
-- decide), equipement_option_premium_activer. Patch : equipement_installer et equipements_local_lire
-- lisent le nombre d'emplacements ; la passe de nuit equipements_jouissance_nuit efface l'option d'un
-- acheteur qui n'a plus la jouissance du bureau. Idempotente. Aucun acte de joueur.

CREATE TABLE IF NOT EXISTS public.bureaux_option_premium (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acheteur   text NOT NULL,
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  achetee_le timestamptz NOT NULL DEFAULT now(),
  paiement   text NOT NULL DEFAULT 'gratuit_beta',
  UNIQUE (acheteur, pays, ville, batiment, piece)
);
ALTER TABLE public.bureaux_option_premium ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bureaux_option_premium FROM anon, authenticated;

-- Nombre d'emplacements d'un bureau : 6 si un occupant legal y a active l'option, sinon 3.
CREATE OR REPLACE FUNCTION public.equipements_emplacements_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM public.bureaux_option_premium b
                            WHERE b.pays = p_pays AND b.ville = p_ville AND b.batiment = p_batiment AND b.piece = p_piece
                              AND public.local_jouissance_interne(b.acheteur, p_pays, p_ville, p_batiment, p_piece))
              THEN 6 ELSE 3 END;
$function$;

CREATE OR REPLACE FUNCTION public.equipement_option_premium_activer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_local'); END IF;
  IF NOT public.local_jouissance_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jouissance'); END IF;
  IF EXISTS (SELECT 1 FROM public.bureaux_option_premium WHERE acheteur = v_moi AND pays = d.country AND ville = d.current_city
               AND batiment = d.current_building AND piece = d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'option_deja_active'); END IF;
  -- Beta : gratuite. Le paiement de l'option premium sera branche ici.
  INSERT INTO public.bureaux_option_premium (acheteur, pays, ville, batiment, piece)
  VALUES (v_moi, d.country, d.current_city, d.current_building, d.current_room);
  RETURN jsonb_build_object('ok', true, 'emplacements',
    public.equipements_emplacements_interne(d.country, d.current_city, d.current_building, d.current_room));
END; $function$;

CREATE OR REPLACE FUNCTION public.equipement_installer(p_generique text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; v_pos integer; v_obj jsonb; v_n integer; v_max integer;
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
  v_max := public.equipements_emplacements_interne(d.country, d.current_city, d.current_building, d.current_room);
  IF v_n >= v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'emplacements_pleins', 'emplacements', v_max); END IF;
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
  RETURN jsonb_build_object('ok', true,
    'emplacements', public.equipements_emplacements_interne(d.country, d.current_city, d.current_building, d.current_room),
    'emplacements_gratuits', 3, 'emplacements_premium', 6,
    'option_premium', EXISTS (SELECT 1 FROM public.bureaux_option_premium b
                               WHERE b.acheteur = v_moi AND b.pays = d.country AND b.ville = d.current_city
                                 AND b.batiment = d.current_building AND b.piece = d.current_room),
    'option_premium_bureau', public.equipements_emplacements_interne(d.country, d.current_city, d.current_building, d.current_room) = 6,
    'jouissance', public.local_jouissance_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room),
    'connexion', public.trading_connexion_interne(v_moi),
    'installes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'generique_id', e.generique_id,
                              'nom', coalesce(e.objet->>'name', e.generique_id),
                              'proprietaire', CASE WHEN left(e.proprietaire, 5) = 'orga:'
                                                   THEN coalesce((SELECT o.data::jsonb->>'nom' FROM public.organisations o
                                                                   WHERE o.id = substr(e.proprietaire, 6)), 'une organisation')
                                                   ELSE e.proprietaire END,
                              'a_moi', public.equipement_a_moi_interne(e.proprietaire, v_moi),
                              'delai_jusqu_au', CASE WHEN e.jouissance_perdue_le IS NOT NULL
                                                     THEN e.jouissance_perdue_le + interval '48 hours' END) ORDER BY e.installe_le)
                            FROM public.equipements_installes e
                           WHERE e.pays = d.country AND e.ville = d.current_city AND e.batiment = d.current_building
                             AND e.piece = d.current_room), '[]'::jsonb),
    'installables', coalesce((SELECT jsonb_agg(DISTINCT o->>'generique_id')
                                FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
                               WHERE o->>'generique_id' IN ('ordinateur-complet', 'box-internet')), '[]'::jsonb));
END; $function$;

-- Passe de nuit : l'option d'un acheteur qui n'a plus la jouissance du bureau est perdue.
DO $$
DECLARE f text;
BEGIN
  f := pg_get_functiondef('public.equipements_jouissance_nuit()'::regprocedure);
  IF position('bureaux_option_premium' IN f) > 0 THEN RETURN; END IF;
  IF position('  RETURN jsonb_build_object(''ok'', jsonb_array_length(v_err) = 0' IN f) = 0 THEN
    RAISE EXCEPTION 'equipements_jouissance_nuit_definition_non_examinee'; END IF;
  f := replace(f, '  RETURN jsonb_build_object(''ok'', jsonb_array_length(v_err) = 0',
    '  DELETE FROM public.bureaux_option_premium b
   WHERE NOT public.local_jouissance_interne(b.acheteur, b.pays, b.ville, b.batiment, b.piece);
  RETURN jsonb_build_object(''ok'', jsonb_array_length(v_err) = 0');
  EXECUTE f;
END $$;

REVOKE ALL ON FUNCTION public.equipements_emplacements_interne(text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.equipement_option_premium_activer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipement_option_premium_activer() TO authenticated;
REVOKE ALL ON FUNCTION public.equipement_installer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipement_installer(text) TO authenticated;
REVOKE ALL ON FUNCTION public.equipements_local_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipements_local_lire() TO authenticated;
