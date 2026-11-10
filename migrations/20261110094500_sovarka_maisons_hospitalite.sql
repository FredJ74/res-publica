-- SOVARKA : MAISONS DE STAROVKA ET KRASNOV (decisions de Fred du 10/11/2026 ; GAME-DESIGN-NOVOMIRSK.md, « Reponses de
-- Fred », point 5 « Maisons »). Hommage a l'hospitalite russe.
-- - Un habitant PNJ tres accueillant offre spontanement l'hospitalite contre un service, tire au hasard chaque jour
--   (le meme pour tous ce jour-la) dans la liste des besoins locaux : Starovka = 3 bois, 2 poissons, 1 bidon de
--   carburant, 2 viandes de renne, 1 bouteille de vodka ; Krasnov = 3 bois, 5 fruits et legumes, 6 oeufs, 1 bouteille
--   de vodka. Un besoin dont l'objet n'existe pas encore dans le jeu (viande de renne, oeufs, vodka : fermes et
--   distillerie a venir) n'est pas tire tant qu'il n'existe pas.
-- - Service rendu : le PJ peut manger (repas ordinaire : +2 PA au prochain Dormir) et dormir chez l'habitant (une nuit
--   d'hotel de la ville, gratuite : +2 PA, +3 Moral au reveil, par le circuit existant des nuitees d'hotel).
--   Une hospitalite par jour et par PJ (toutes maisons confondues).
-- - Trinquer avec l'habitant : le PJ fournit la bouteille (n'importe quel alcool de son inventaire), 3 PA par
--   bouteille bue (pas de plafond ; tomber a 0 PA suit la regle d'hospitalisation). A chaque bouteille, « secret
--   contre secret » : le PJ livre malgre lui un renseignement reel tire au hasard par le serveur, que l'habitant
--   retient ; l'habitant livre un secret de la ville. Nid a ragots : il repete au buveur suivant ce qu'il a appris des
--   autres, et puise dans le circuit des rumeurs alimente par les traces des actes illegaux.
-- Habitants (noms proposes par Claude, a valider par Fred) : Dolgor Tsybikova (Starovka), Stepan Kouznetsov (Krasnov).
BEGIN;

-- 1. Batiments.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_a', 'maison-starovka', '["piece_maison"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'maison-krasnov', '["piece_maison"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
  ('soviet', 'ville_a', 'starovka-maisons-ferme', 'maison-starovka'),
  ('soviet', 'ville_b', 'krasnov-rue-maison', 'maison-krasnov')
ON CONFLICT DO NOTHING;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, 0 FROM (VALUES ('maison_habitant', 0), ('trinquer_habitant', 3)) x(fn, pa)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = x.pa AND o.cost = 0);
INSERT INTO public.pa_bonus_differes (source, montant) VALUES ('repas_habitant', 2) ON CONFLICT (source) DO NOTHING;

-- 2. Etat.
CREATE TABLE IF NOT EXISTS public.sovarka_maisons_hospitalite (
  jour date NOT NULL,
  personnage text NOT NULL,
  maison text NOT NULL,
  service jsonb NOT NULL,
  mange boolean NOT NULL DEFAULT false,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour, personnage)
);
CREATE TABLE IF NOT EXISTS public.sovarka_maisons_ragots (
  id bigserial PRIMARY KEY,
  maison text NOT NULL,
  sujet text NOT NULL,
  texte text NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sovarka_maisons_ragots_maison ON public.sovarka_maisons_ragots (maison, cree_le DESC);
CREATE TABLE IF NOT EXISTS public.sovarka_maisons_actes (
  acteur text NOT NULL,
  requete text NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete)
);
ALTER TABLE public.sovarka_maisons_hospitalite ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_maisons_ragots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_maisons_actes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_maisons_hospitalite, public.sovarka_maisons_ragots, public.sovarka_maisons_actes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.sovarka_maisons_ragots_id_seq FROM PUBLIC, anon, authenticated;

-- 3. Dormir chez l'habitant : la piece de la maison vaut une chambre d'hotel (patch en place, ancrage verifie).
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.hotel_nuitee_consommation_interne(text)'::regprocedure);
  IF position('maison-starovka' IN d) = 0 THEN
    avant := E' OR (p.current_building=''hotel-mineur'' AND p.current_room=''chambre_mineur'')) THEN';
    apres := E' OR (p.current_building=''hotel-mineur'' AND p.current_room=''chambre_mineur'')\n'
          || E' OR (p.current_building IN (''maison-starovka'',''maison-krasnov'') AND p.current_room=''piece_maison'')) THEN';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'hotel_nuitee_consommation_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $raccord$;

-- 4. Outils.
CREATE OR REPLACE FUNCTION public.sovarka_ville_nom_interne(p_pays text, p_ville text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays || ':' || coalesce(p_ville, '')
    WHEN 'soviet:capitale' THEN 'Novomirsk' WHEN 'soviet:ville_a' THEN 'Starovka' WHEN 'soviet:ville_b' THEN 'Krasnov'
    WHEN 'republic:capitale' THEN 'Luthécia' WHEN 'republic:ville_a' THEN 'Port-Sainte-Marie' WHEN 'republic:ville_b' THEN 'Montrouge'
    ELSE CASE p_pays WHEN 'soviet' THEN 'Sovarka' WHEN 'republic' THEN 'Républia' WHEN 'narco' THEN 'El Estado'
                     WHEN 'khalija' THEN 'Al-Khalija' ELSE 'l''étranger' END END;
$$;

CREATE OR REPLACE FUNCTION public.sovarka_maison_interne(p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'ville_a' AND p_batiment = 'maison-starovka' THEN jsonb_build_object('id', 'maison-starovka', 'habitant', 'Dolgor Tsybikova',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"poisson","qte":2,"label":"2 poissons"},{"cle":"carburant","qte":1,"label":"1 bidon de carburant"},{"cle":"viande_renne","qte":2,"label":"2 viandes de renne"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov' THEN jsonb_build_object('id', 'maison-krasnov', 'habitant', 'Stepan Kouznetsov',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"fruits_legumes","qte":5,"label":"5 fruits et légumes"},{"cle":"oeufs","qte":6,"label":"6 œufs"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
  END;
$$;

-- Service du jour : tire parmi les besoins dont l'objet existe dans le jeu, le meme pour tous ce jour-la.
CREATE OR REPLACE FUNCTION public.sovarka_maison_service_interne(p_maison jsonb, p_jour date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH b AS (
    SELECT e, row_number() OVER () - 1 AS k
      FROM jsonb_array_elements(p_maison->'besoins') e
     WHERE EXISTS (SELECT 1 FROM public.ressources_economie r WHERE r.cle = e->>'cle')
  )
  SELECT e FROM b WHERE k = abs(hashtext((p_maison->>'id') || ':' || p_jour::text)) % greatest(1, (SELECT count(*) FROM b));
$$;

-- Ligne de pile d'une cle : [index, quantite] (-1, 0 si aucune).
CREATE OR REPLACE FUNCTION public.sovarka_inventaire_ligne_interne(p_inv jsonb, p_cles text[])
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE i integer;
BEGIN
  IF jsonb_typeof(p_inv) = 'array' THEN
    FOR i IN 0 .. jsonb_array_length(p_inv) - 1 LOOP
      IF (p_inv -> i ->> 'stackKey') = ANY (p_cles) AND coalesce((p_inv -> i ->> 'stackable')::boolean, false)
         AND coalesce((p_inv -> i ->> 'qty')::numeric, 0) >= 1 THEN
        RETURN jsonb_build_object('i', i, 'qte', floor((p_inv -> i ->> 'qty')::numeric)::integer, 'cle', p_inv -> i ->> 'stackKey');
      END IF;
    END LOOP;
  END IF;
  RETURN jsonb_build_object('i', -1, 'qte', 0);
END $$;

-- Retire p_qte unites d'une ligne de pile ; rend le nouvel inventaire.
CREATE OR REPLACE FUNCTION public.sovarka_inventaire_retirer_interne(p_nom text, p_ligne jsonb, p_qte integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; i integer := (p_ligne->>'i')::integer; q integer := (p_ligne->>'qte')::integer;
BEGIN
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF i < 0 OR q < p_qte OR (v_inv -> i ->> 'stackKey') IS DISTINCT FROM (p_ligne->>'cle') THEN RAISE EXCEPTION 'inventaire_ligne_invalide'; END IF;
  IF q = p_qte THEN v_inv := v_inv - i; ELSE v_inv := jsonb_set(v_inv, ARRAY[i::text, 'qty'], to_jsonb(q - p_qte)); END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now() WHERE name = p_nom;
  IF (SELECT inventory FROM public.personnages_donnees WHERE name = p_nom) IS DISTINCT FROM v_inv THEN
    RAISE EXCEPTION 'inventaire_non_applique'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_inventaire_retirer_interne(text, jsonb, integer) FROM PUBLIC, anon, authenticated;

-- Presence dans une maison ; verrouille la fiche.
CREATE OR REPLACE FUNCTION public.sovarka_maison_acteur_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; m jsonb;
BEGIN
  SELECT country, current_city, current_building, hp INTO p FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  m := CASE WHEN p.country = 'soviet' THEN public.sovarka_maison_interne(p.current_city, p.current_building) END;
  IF m IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active(p_nom)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  RETURN jsonb_build_object('ok', true, 'maison', m, 'ville', p.current_city);
END $$;

-- Un renseignement reel sur le PJ, tire au hasard (ce qu'il laisse echapper en buvant).
CREATE OR REPLACE FUNCTION public.sovarka_maison_secret_pj_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH d AS (SELECT * FROM public.personnages_donnees WHERE name = p_nom),
  c AS (
    SELECT p_nom || ' occupe le poste de ' || coalesce(nullif(d.poste->>'label', ''), replace(d.poste->>'id', '_', ' ')) || '.' AS t
      FROM d WHERE coalesce(d.poste->>'id', '') <> ''
    UNION ALL
    SELECT p_nom || ' se promène avec plus de ' || (floor(coalesce(d.liquide, 0) / 100) * 100)::bigint
           || CASE WHEN d.country = 'soviet' THEN ' PSK' ELSE ' FR' END || ' en poche.'
      FROM d WHERE coalesce(d.liquide, 0) >= 100
    UNION ALL
    SELECT p_nom || ' vit à ' || public.sovarka_ville_nom_interne(d.domicile->>'country', d.domicile->>'city') || '.'
      FROM d WHERE d.domicile ? 'country'
    UNION ALL
    SELECT p_nom || ' a avoué avoir fait quelque chose de louche (« ' || replace(a.type_action, '_', ' ') || ' »'
           || CASE WHEN coalesce(a.cible, '') <> '' THEN ', visant ' || a.cible ELSE '' END || ') à '
           || public.sovarka_ville_nom_interne(a.country, a.city) || '.'
      FROM (SELECT * FROM public.actions_tracables WHERE auteur = p_nom ORDER BY created_at DESC LIMIT 3) a
  )
  SELECT coalesce((SELECT t FROM c ORDER BY random() LIMIT 1), p_nom || ' n''a rien d''intéressant à cacher, paraît-il.');
$$;
REVOKE ALL ON FUNCTION public.sovarka_maison_secret_pj_interne(text) FROM PUBLIC, anon, authenticated;

-- Un secret de la ville : ragots appris des autres buveurs, ou rumeurs nees des traces des actes illegaux.
CREATE OR REPLACE FUNCTION public.sovarka_maison_secret_ville_interne(p_maison text, p_nom text)
RETURNS text LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH c AS (
    SELECT 'On m''a raconté ici même que ' || lower(left(r.texte, 1)) || substr(r.texte, 2) AS t
      FROM (SELECT * FROM public.sovarka_maisons_ragots WHERE maison = p_maison AND sujet <> p_nom ORDER BY cree_le DESC LIMIT 20) r
    UNION ALL
    SELECT 'Il paraîtrait que ' || a.auteur || ' a ' || CASE a.type_action
             WHEN 'voler_archives_ecoute' THEN 'volé un rapport d''espionnage'
             WHEN 'vol' THEN 'volé quelque chose'
             ELSE 'commis un acte louche (« ' || replace(a.type_action, '_', ' ') || ' »)' END
           || CASE WHEN coalesce(a.cible, '') <> '' THEN ' — ' || a.cible ELSE '' END
           || ', du côté de ' || public.sovarka_ville_nom_interne(a.country, a.city) || '…'
      FROM (SELECT * FROM public.actions_tracables WHERE country = 'soviet' AND auteur <> p_nom
             ORDER BY created_at DESC LIMIT 20) a
  )
  SELECT coalesce((SELECT t FROM c ORDER BY random() LIMIT 1),
    'Ici, il ne se passe jamais rien… sauf l''hiver, qui dure neuf mois. Mais reviens, je finirai bien par apprendre quelque chose.');
$$;
REVOKE ALL ON FUNCTION public.sovarka_maison_secret_ville_interne(text, text) FROM PUBLIC, anon, authenticated;

-- 5. Lecture.
CREATE OR REPLACE FUNCTION public.sovarka_maison_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb; h record; v_jour date := public.sovarka_jour_paris(); s jsonb; b jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.sovarka_maison_acteur_interne(a);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  s := public.sovarka_maison_service_interne(v->'maison', v_jour);
  SELECT * INTO h FROM public.sovarka_maisons_hospitalite WHERE jour = v_jour AND personnage = a;
  b := public.sovarka_inventaire_ligne_interne((SELECT inventory FROM public.personnages_donnees WHERE name = a),
         ARRAY['vodka', 'slivovitz', 'samogon', 'alcool']);
  RETURN jsonb_build_object('ok', true, 'habitant', v->'maison'->>'habitant', 'service', s,
    'heberge', h.maison IS NOT DISTINCT FROM v->'maison'->>'id', 'heberge_ailleurs', h.maison IS NOT NULL AND h.maison <> v->'maison'->>'id',
    'mange', coalesce(h.mange, false), 'bouteille', (b->>'i')::integer >= 0);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_maison_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_maison_lire() TO authenticated;

-- 6. Actes : rendre le service, manger, trinquer.
CREATE OR REPLACE FUNCTION public.sovarka_maison_agir(p_requete text, p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb; m jsonb; x record; h record; s jsonb; l jsonb; v_jour date := public.sovarka_jour_paris();
        v_paie jsonb; r jsonb; v_bonus integer; v_id bigint; v_pj text; v_ville text; v_reaction text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_action NOT IN ('service', 'manger', 'trinquer') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:maison:' || a, 0));
  SELECT * INTO x FROM public.sovarka_maisons_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  v := public.sovarka_maison_acteur_interne(a);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  m := v->'maison';
  SELECT * INTO h FROM public.sovarka_maisons_hospitalite WHERE jour = v_jour AND personnage = a FOR UPDATE;

  IF p_action = 'service' THEN
    IF FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN h.maison = m->>'id' THEN 'deja_heberge' ELSE 'heberge_ailleurs' END); END IF;
    s := public.sovarka_maison_service_interne(m, v_jour);
    IF s IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_service'); END IF;
    l := public.sovarka_inventaire_ligne_interne((SELECT inventory FROM public.personnages_donnees WHERE name = a), ARRAY[s->>'cle']);
    IF (l->>'qte')::integer < (s->>'qte')::integer THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'service_incomplet', 'service', s, 'possede', l->'qte'); END IF;
    v_paie := public.payer_ordre(a, 'maison_habitant', 0, 0);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    PERFORM public.sovarka_inventaire_retirer_interne(a, l, (s->>'qte')::integer);
    INSERT INTO public.sovarka_maisons_hospitalite (jour, personnage, maison, service) VALUES (v_jour, a, m->>'id', s);
    INSERT INTO public.hotel_nuitees (personnage_id, country, city, building_id, pa_bonus, moral_bonus)
    SELECT id, 'soviet', v->>'ville', m->>'id', 2, 3 FROM public.personnages_donnees WHERE name = a;
    r := jsonb_build_object('ok', true, 'action', 'service', 'service', s, 'habitant', m->>'habitant');

  ELSIF p_action = 'manger' THEN
    IF NOT FOUND OR h.maison <> m->>'id' THEN RETURN jsonb_build_object('ok', false, 'raison', 'service_non_rendu'); END IF;
    IF h.mange THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange'); END IF;
    SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'repas_habitant';
    v_paie := public.payer_ordre(a, 'maison_habitant', 0, 0);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    UPDATE public.sovarka_maisons_hospitalite SET mange = true WHERE jour = v_jour AND personnage = a;
    UPDATE public.personnages_donnees SET bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_bonus), updated_at = now()
     WHERE name = a;
    r := jsonb_build_object('ok', true, 'action', 'manger', 'bonus', v_bonus, 'habitant', m->>'habitant');

  ELSE
    l := public.sovarka_inventaire_ligne_interne((SELECT inventory FROM public.personnages_donnees WHERE name = a),
           ARRAY['vodka', 'slivovitz', 'samogon', 'alcool']);
    IF (l->>'i')::integer < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_bouteille'); END IF;
    v_paie := public.payer_ordre(a, 'trinquer_habitant', 3, 0);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    PERFORM public.sovarka_inventaire_retirer_interne(a, l, 1);
    v_ville := public.sovarka_maison_secret_ville_interne(m->>'id', a);
    v_pj := public.sovarka_maison_secret_pj_interne(a);
    INSERT INTO public.sovarka_maisons_ragots (maison, sujet, texte) VALUES (m->>'id', a, v_pj);
    v_reaction := CASE l->>'cle'
      WHEN 'vodka' THEN 'De la vodka ! Voilà un étranger qui sait vivre. Na zdorovie !'
      WHEN 'slivovitz' THEN 'De la slivovitz… ça sent la prune et le pays d''autrefois. Na zdorovie !'
      WHEN 'samogon' THEN 'Du samogon ! On ne demande pas d''où il vient. Na zdorovie !'
      ELSE 'De l''alcool de l''entrepôt d''État ? Ça brûle, mais ça réchauffe. Na zdorovie !' END;
    r := jsonb_build_object('ok', true, 'action', 'trinquer', 'habitant', m->>'habitant', 'reaction', v_reaction,
      'secret_livre', v_pj, 'secret_recu', v_ville);
  END IF;

  r := r || jsonb_build_object('pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg')
         || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  INSERT INTO public.sovarka_maisons_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory');
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_maison_agir(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_maison_agir(text, text) TO authenticated;

COMMIT;
