-- CRIMINALITÉ — LOT 1 : équipement et dissimulation (GAME-DESIGN-CRIMINALITE.md §§ 1 et 5, décisions de Fred des 18-19/11/2026).
-- • Revêtir / Retirer (0 PA) : l'objet porté est marqué dans l'inventaire (`porte_par` = nom du porteur). Un objet donné,
--   volé ou déposé garde la clé mais ne compte plus (le nom ne correspond plus) ; un objet retiré n'a plus d'effet.
-- • Gilet pare-balles : ne compte en combat que revêtu (militaire_gilet_absorber) ; le gilet civil compte désormais aussi.
--   Les gilets déjà détenus sont marqués revêtus (un par personnage) pour ne rien retirer à personne.
-- • Nouveaux objets : tenue ninja, masque de carnaval, kit de crochetage (5 usages réussis), pied-de-biche ; boutique
--   « Équipement discret » (armureries et marchés) ; prix Républia / Sovarka ; gilet à 60 PSK en Sovarka.
--   Achat d'un kit ou d'un pied-de-biche : trace dans crim_traces_achat (lue par l'enquête, lot 6).
-- • Se cacher : 70 % + 5 par tranche de 20 de DIS + 15 tenue ninja revêtue, plafond 98 ; échec critique (jet 99-100) −15 moral.
--   La cachette dure jusqu'à la sortie de la pièce (déclencheur) et n'est plus consommée par l'empoisonnement.
-- • Fouiller les cachettes (1 PA) : 40 + 2×PER − DIS du caché/10 − 15 ninja + 20 force de l'ordre, borné 10-90.
-- • Présents : crim_presents() (caché absent, masqué = « Individu masqué n°X » sans portrait) ; la table presences ne
--   montre plus aux autres les PJ cachés ou masqués (RLS).
-- • Hôpital et détention : tous les vêtements portés reviennent dans l'inventaire ; à l'arrestation, le masque tombe et
--   l'écran reçoit l'événement « demasque » (animation « Bas les masques ! »).
-- Helpers réutilisables (lots suivants) : crim_objet_categorie_interne, crim_porte_ligne_interne, crim_objet_porte_interne,
-- crim_cache_interne, crim_masque_interne, crim_mode_action_interne, crim_force_ordre_interne, crim_debusquer_interne,
-- crim_vetements_retirer_interne, crim_jeton_resoudre_interne, crim_evenement_interne, crim_param_interne, crim_stat_interne.
BEGIN;

-- ── Paramètres (valeurs de Républia ; Sovarka a ses prix ; les autres empires reprennent Républia) ────────────────────
CREATE TABLE IF NOT EXISTS public.crim_parametres (cle text PRIMARY KEY, valeur numeric NOT NULL);
ALTER TABLE public.crim_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_parametres FROM anon, authenticated;
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('prix_tenue_ninja_republic', 240), ('prix_tenue_ninja_soviet', 30),
  ('prix_masque_carnaval_republic', 50), ('prix_masque_carnaval_soviet', 8),
  ('prix_kit_crochetage_republic', 80), ('prix_kit_crochetage_soviet', 15),
  ('prix_pied_de_biche_republic', 40), ('prix_pied_de_biche_soviet', 8),
  ('prix_gilet_republic', 380), ('prix_gilet_soviet', 60),
  ('kit_usages', 5),
  ('cacher_base', 70), ('cacher_par_20_dis', 5), ('cacher_ninja', 15), ('cacher_plafond', 98), ('cacher_critique_points', 2),
  ('echec_critique_moral', 15),
  ('fouiller_base', 40), ('fouiller_par_per', 2), ('fouiller_ninja', 15), ('fouiller_force_ordre', 20),
  ('fouiller_min', 10), ('fouiller_max', 90), ('fouiller_pa', 1)
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.crim_param_interne(p_cle text, p_defaut numeric DEFAULT 0)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT valeur FROM public.crim_parametres WHERE cle = p_cle), p_defaut);
$$;

-- Caractéristique numérique d'un personnage (stats.PER, resources.dis…), avec valeur par défaut.
CREATE OR REPLACE FUNCTION public.crim_stat_interne(p_nom text, p_cle text, p_defaut numeric)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT CASE
      WHEN p_cle = 'dis' AND jsonb_typeof(d.resources -> 'dis') = 'number' THEN (d.resources ->> 'dis')::numeric
      WHEN p_cle <> 'dis' AND coalesce(d.stats ->> p_cle, '') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN (d.stats ->> p_cle)::numeric END
    FROM public.personnages_donnees d WHERE d.name = p_nom), p_defaut);
$$;

-- ── Objets portables ────────────────────────────────────────────────────────────────────────────────────────────
-- Catégorie de port d'une ligne d'inventaire : 'gilet', 'masque', 'tenue_ninja' (ou la clé « revetable » d'un futur objet).
CREATE OR REPLACE FUNCTION public.crim_objet_categorie_interne(p_item jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN jsonb_typeof(p_item) <> 'object' THEN NULL
    WHEN nullif(p_item ->> 'revetable', '') IS NOT NULL THEN p_item ->> 'revetable'
    WHEN p_item ->> 'produitMilitaire' = 'gilet_pare_balles' THEN 'gilet'
    WHEN p_item ->> 'type' = 'protection' AND p_item ->> 'name' ILIKE 'gilet%' THEN 'gilet'
  END;
$$;
-- La ligne est-elle revêtue par ce personnage ?
CREATE OR REPLACE FUNCTION public.crim_porte_ligne_interne(p_item jsonb, p_nom text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_item ->> 'porte_par' = p_nom, false) AND public.crim_objet_categorie_interne(p_item) IS NOT NULL;
$$;
-- Le personnage porte-t-il un objet de cette catégorie ? (helper commun : gilet, masque, tenue_ninja…)
CREATE OR REPLACE FUNCTION public.crim_objet_porte_interne(p_nom text, p_categorie text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d,
                   jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) e
                  WHERE d.name = p_nom AND public.crim_porte_ligne_interne(e, p_nom)
                    AND public.crim_objet_categorie_interne(e) = p_categorie);
$$;

CREATE OR REPLACE FUNCTION public.crim_objet_interne(p_cle text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE p_cle
    WHEN 'tenue_ninja' THEN jsonb_build_object('name', 'Tenue ninja', 'icon', 'ti-shirt', 'type', 'vetement', 'revetable', 'tenue_ninja',
      'generique_id', 'tenue_ninja', 'famille', 'habillement', 'sousTypes', jsonb_build_array('civil', 'militaire'), 'legal', true, 'stackable', false,
      'desc', 'Noire de la tête aux pieds. Revêtue : +15 % pour se cacher, −15 % aux fouilles qui vous visent.')
    WHEN 'masque_carnaval' THEN jsonb_build_object('name', 'Masque de carnaval', 'icon', 'ti-mask', 'type', 'vetement', 'revetable', 'masque',
      'generique_id', 'masque_carnaval', 'famille', 'habillement', 'sousTypes', jsonb_build_array('civil'), 'legal', true, 'stackable', false,
      'desc', 'Revêtu, vous n''êtes plus qu''un « individu masqué » pour ceux qui vous croisent. Il tombe à l''arrestation.')
    WHEN 'kit_crochetage' THEN jsonb_build_object('name', 'Kit de crochetage', 'icon', 'ti-tool', 'type', 'outil', 'generique_id', 'kit_crochetage',
      'famille', 'bazar', 'sousTypes', jsonb_build_array('outil'), 'legal', true, 'stackable', false,
      'usages_restants', public.crim_param_interne('kit_usages', 5)::integer,
      'desc', 'Crochets et tensionneurs. S''use après cinq serrures ouvertes. Chaque achat est noté par le vendeur.')
    WHEN 'pied_de_biche' THEN jsonb_build_object('name', 'Pied-de-biche', 'icon', 'ti-hammer', 'type', 'outil', 'generique_id', 'pied_de_biche',
      'famille', 'bazar', 'sousTypes', jsonb_build_array('outil'), 'legal', true, 'stackable', false,
      'desc', 'Pour forcer une porte. Chaque achat est noté par le vendeur.')
    WHEN 'gilet' THEN (SELECT objet FROM public.objets_modeles WHERE id = 'gilet')
  END;
$$;

-- Le gilet civil se revêt ; il entre dans la famille Armement, protection individuelle.
UPDATE public.objets_modeles SET objet = objet || jsonb_build_object('revetable', 'gilet', 'famille', 'armement',
    'sousTypes', jsonb_build_array('protection_individuelle'))
 WHERE id = 'gilet' AND NOT (objet ? 'revetable');
INSERT INTO public.objets_modeles (id, objet)
SELECT c, public.crim_objet_interne(c) FROM unnest(ARRAY['tenue_ninja', 'masque_carnaval', 'kit_crochetage', 'pied_de_biche']) c
ON CONFLICT (id) DO NOTHING;

-- ── Boutique « Équipement discret » ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crim_boutiques (
  id text PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL, cles text[] NOT NULL
);
ALTER TABLE public.crim_boutiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_boutiques FROM anon, authenticated;
INSERT INTO public.crim_boutiques (id, pays, ville, batiment, piece, cles) VALUES
  ('armurerie-luthecia',   'republic', 'capitale', 'armurerie',        'magasin',    ARRAY['gilet', 'kit_crochetage', 'pied_de_biche', 'tenue_ninja']),
  ('armurerie-montrouge',  'republic', 'ville_b',  'armurerie',        'magasin',    ARRAY['gilet', 'kit_crochetage', 'pied_de_biche', 'tenue_ninja']),
  ('chasse-peche-psm',     'republic', 'ville_a',  'chasse-peche-psm', 'boutique',   ARRAY['gilet', 'kit_crochetage', 'pied_de_biche', 'tenue_ninja']),
  ('armurerie-novomirsk',  'soviet',   'capitale', 'armurerie',        'magasin',    ARRAY['gilet', 'kit_crochetage', 'pied_de_biche', 'tenue_ninja']),
  ('chasse-peche-starovka','soviet',   'ville_a',  'armurerie',        'magasin',    ARRAY['gilet', 'kit_crochetage', 'pied_de_biche', 'tenue_ninja']),
  ('marche-luthecia',      'republic', 'capitale', 'marche',           'marche_ext', ARRAY['masque_carnaval', 'tenue_ninja']),
  ('marche-montrouge',     'republic', 'ville_b',  'marche',           'marche_ext', ARRAY['masque_carnaval', 'tenue_ninja']),
  ('marche-psm',           'republic', 'ville_a',  'marche-psm',       'etals',      ARRAY['masque_carnaval', 'tenue_ninja']),
  ('marche-novomirsk',     'soviet',   'capitale', 'marche',           'marche_ext', ARRAY['masque_carnaval', 'tenue_ninja']),
  ('marche-starovka',      'soviet',   'ville_a',  'marche',           'marche_ext', ARRAY['masque_carnaval', 'tenue_ninja']),
  ('marche-krasnov',       'soviet',   'ville_b',  'marche',           'marche_ext', ARRAY['masque_carnaval', 'tenue_ninja'])
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.crim_traces_achat (
  id bigserial PRIMARY KEY, acheteur text NOT NULL, objet text NOT NULL, boutique text NOT NULL,
  pays text, ville text, jour integer, le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS crim_traces_achat_ville ON public.crim_traces_achat (pays, ville, le);
ALTER TABLE public.crim_traces_achat ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_traces_achat FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_traces_achat_id_seq FROM anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'boutique_discretion', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'boutique_discretion' AND pa = 0 AND cost = 0);

CREATE OR REPLACE FUNCTION public.crim_boutique_interne(p_nom text)
RETURNS public.crim_boutiques LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT b.* FROM public.crim_boutiques b JOIN public.personnages_donnees d ON d.name = p_nom
   WHERE d.country = b.pays AND d.current_city = b.ville AND d.current_building = b.batiment AND d.current_room = b.piece;
$$;
-- Prix d'un objet dans un pays : Sovarka a ses prix ; les autres empires reprennent ceux de Républia.
CREATE OR REPLACE FUNCTION public.crim_prix_interne(p_cle text, p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT valeur FROM public.crim_parametres WHERE cle = 'prix_' || p_cle || '_' || coalesce(p_pays, 'republic')),
                  public.crim_param_interne('prix_' || p_cle || '_republic', 0));
$$;

CREATE OR REPLACE FUNCTION public.boutique_discretion_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); b public.crim_boutiques; v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  b := public.crim_boutique_interne(a);
  IF b.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_boutique'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'offre', (SELECT jsonb_agg(jsonb_build_object('cle', c, 'prix', public.crim_prix_interne(c, v_pays),
           'nom', public.crim_objet_interne(c) ->> 'name', 'trace', c IN ('kit_crochetage', 'pied_de_biche')) ORDER BY o)
         FROM unnest(b.cles) WITH ORDINALITY u(c, o)));
END $$;

CREATE OR REPLACE FUNCTION public.boutique_discretion_acheter(p_requete uuid, p_cle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle); v jsonb; b public.crim_boutiques;
        d record; v_prix numeric; v_fonds numeric; v_debit numeric; v_dep jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'boutique_discretion_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  b := public.crim_boutique_interne(a);
  IF b.id IS NULL OR NOT (p_cle = ANY (b.cles)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_boutique'); END IF;
  SELECT name, country, current_city, day, liquide INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  v_prix := public.crim_prix_interne(p_cle, d.country);
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires c WHERE c.personnage = a AND c.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds;
  IF v_fonds < v_prix THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_prix); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(a, 'boutique_discretion', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  IF v_prix > 0 THEN
    v_debit := public.argent_debiter_interne(a, v_prix, 'liquide_puis_nationale');
    IF v_debit IS DISTINCT FROM v_prix THEN RAISE EXCEPTION 'boutique_discretion: debit incomplet'; END IF;
  END IF;
  v_dep := public.inventaire_deposer_interne(a, public.crim_objet_interne(p_cle));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'boutique_discretion: depot refuse %', v_dep; END IF;
  IF p_cle IN ('kit_crochetage', 'pied_de_biche') THEN
    INSERT INTO public.crim_traces_achat (acheteur, objet, boutique, pays, ville, jour) VALUES (a, p_cle, b.id, d.country, d.current_city, d.day);
  END IF;
  v := jsonb_build_object('ok', true, 'cle', p_cle, 'paye', v_prix)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide, 'arg', arg)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'boutique_discretion_acheter', prm, v);
END $$;

-- ── Événements d'écran (animation de démasquage, débusqué…) ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crim_evenements (
  id bigserial PRIMARY KEY, personnage text NOT NULL, type text NOT NULL, donnees jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(), lu_le timestamptz
);
CREATE INDEX IF NOT EXISTS crim_evenements_non_lus ON public.crim_evenements (personnage) WHERE lu_le IS NULL;
ALTER TABLE public.crim_evenements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_evenements FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_evenements_id_seq FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.crim_evenement_interne(p_nom text, p_type text, p_donnees jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.crim_evenements (personnage, type, donnees) VALUES (p_nom, p_type, coalesce(p_donnees, '{}'::jsonb));
$$;
CREATE OR REPLACE FUNCTION public.crim_evenements_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  WITH lus AS (UPDATE public.crim_evenements SET lu_le = now()
                WHERE personnage = a AND lu_le IS NULL AND cree_le > now() - interval '3 days'
                RETURNING id, type, donnees, cree_le)
  SELECT coalesce(jsonb_agg(jsonb_build_object('type', type, 'donnees', donnees, 'le', cree_le) ORDER BY id), '[]'::jsonb) INTO v FROM lus;
  RETURN jsonb_build_object('ok', true, 'evenements', v);
END $$;

-- ── Cachette, masque, mode d'action ─────────────────────────────────────────────────────────────────────────────
-- Caché dans la pièce où il se trouve en ce moment.
CREATE OR REPLACE FUNCTION public.crim_cache_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.caches_pj k JOIN public.personnages_donnees d ON d.name = k.personnage
                  WHERE k.personnage = p_nom AND k.pays IS NOT DISTINCT FROM d.country AND k.ville IS NOT DISTINCT FROM d.current_city
                    AND k.batiment IS NOT DISTINCT FROM d.current_building AND k.piece IS NOT DISTINCT FROM d.current_room
                    AND coalesce(d.current_building, '') <> '');
$$;
CREATE OR REPLACE FUNCTION public.crim_masque_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_objet_porte_interne(p_nom, 'masque');
$$;
-- Mode d'action d'un PJ : 'decouvert' (visage découvert), 'cache', 'masque' ou 'cache_masque' (cumul, § 1).
CREATE OR REPLACE FUNCTION public.crim_mode_action_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN c AND m THEN 'cache_masque' WHEN c THEN 'cache' WHEN m THEN 'masque' ELSE 'decouvert' END
    FROM (SELECT public.crim_cache_interne(p_nom) c, public.crim_masque_interne(p_nom) m) x;
$$;
-- Policier, commissaire ou agent de sécurité privée (bonus de fouille).
CREATE OR REPLACE FUNCTION public.crim_force_ordre_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT poste ->> 'id' ~ '^(commissaire|policier|agent_securite|maitre_chien)' FROM public.personnages_donnees WHERE name = p_nom), false);
$$;
CREATE OR REPLACE FUNCTION public.crim_debusquer_interne(p_nom text, p_motif text DEFAULT 'debusque')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  DELETE FROM public.caches_pj WHERE personnage = p_nom;
  RETURN FOUND;
END $$;

-- Jeton opaque d'un individu masqué (cible d'un ordre sans révéler le nom ; lu par les lots suivants).
CREATE TABLE IF NOT EXISTS public.crim_jetons_masque (personnage text PRIMARY KEY, jeton uuid NOT NULL DEFAULT gen_random_uuid(), le timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS crim_jetons_masque_jeton ON public.crim_jetons_masque (jeton);
ALTER TABLE public.crim_jetons_masque ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_jetons_masque FROM anon, authenticated;
CREATE OR REPLACE FUNCTION public.crim_jeton_resoudre_interne(p_jeton text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT personnage FROM public.crim_jetons_masque
   WHERE p_jeton ~ '^[0-9a-f-]{36}$' AND jeton = p_jeton::uuid AND public.crim_masque_interne(personnage);
$$;

-- Tous les vêtements portés reviennent dans l'inventaire (hôpital, détention). Rend le nouvel inventaire et les catégories retirées.
CREATE OR REPLACE FUNCTION public.crim_inventaire_devetir_interne(p_inv jsonb, p_nom text, p_categorie text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(jsonb_agg(CASE WHEN public.crim_porte_ligne_interne(e, p_nom)
                                   AND (p_categorie IS NULL OR public.crim_objet_categorie_interne(e) = p_categorie)
                                 THEN e - 'porte_par' ELSE e END ORDER BY o), '[]'::jsonb)
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) WITH ORDINALITY x(e, o);
$$;
CREATE OR REPLACE FUNCTION public.crim_vetements_retirer_interne(p_nom text, p_categorie text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; n integer;
BEGIN
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT count(*) INTO n FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_inv) = 'array' THEN v_inv ELSE '[]'::jsonb END) e
   WHERE public.crim_porte_ligne_interne(e, p_nom) AND (p_categorie IS NULL OR public.crim_objet_categorie_interne(e) = p_categorie);
  IF n > 0 THEN
    UPDATE public.personnages_donnees SET inventory = public.crim_inventaire_devetir_interne(v_inv, p_nom, p_categorie) WHERE name = p_nom;
  END IF;
  RETURN n;
END $$;

-- Déclencheur : sortie de pièce = fin de la cachette ; hôpital ou détention = vêtements retirés ; arrestation = démasquage.
CREATE OR REPLACE FUNCTION public.crim_personnage_etat_declencheur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_detenu_old boolean; v_detenu_new boolean; v_hosp_new boolean; v_qhs_new boolean; v_masque boolean;
BEGIN
  IF (NEW.country, NEW.current_city, NEW.current_building, NEW.current_room)
     IS DISTINCT FROM (OLD.country, OLD.current_city, OLD.current_building, OLD.current_room) THEN
    DELETE FROM public.caches_pj WHERE personnage = NEW.name;
  END IF;
  v_detenu_old := coalesce(jsonb_typeof(OLD.est_emprisonne), 'null') <> 'null' AND OLD.est_emprisonne <> 'false'::jsonb;
  v_detenu_new := coalesce(jsonb_typeof(NEW.est_emprisonne), 'null') <> 'null' AND NEW.est_emprisonne <> 'false'::jsonb;
  v_hosp_new := jsonb_typeof(NEW.hospitalisation) = 'object' AND NEW.hospitalisation IS DISTINCT FROM OLD.hospitalisation;
  v_qhs_new := jsonb_typeof(NEW.detention_qhs) = 'object' AND (NEW.detention_qhs ->> 'enQHS')::boolean IS TRUE
               AND NEW.detention_qhs IS DISTINCT FROM OLD.detention_qhs;
  IF (v_detenu_new AND NOT v_detenu_old) OR v_hosp_new OR v_qhs_new THEN
    v_masque := EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(NEW.inventory) = 'array' THEN NEW.inventory ELSE '[]'::jsonb END) e
                         WHERE public.crim_porte_ligne_interne(e, NEW.name) AND public.crim_objet_categorie_interne(e) = 'masque');
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(NEW.inventory) = 'array' THEN NEW.inventory ELSE '[]'::jsonb END) e
                WHERE public.crim_porte_ligne_interne(e, NEW.name)) THEN
      NEW.inventory := public.crim_inventaire_devetir_interne(NEW.inventory, NEW.name, NULL);
    END IF;
    DELETE FROM public.caches_pj WHERE personnage = NEW.name;
    IF v_masque AND v_detenu_new AND NOT v_detenu_old THEN
      PERFORM public.crim_evenement_interne(NEW.name, 'demasque', jsonb_build_object('ville', NEW.current_city));
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS crim_personnage_etat ON public.personnages_donnees;
CREATE TRIGGER crim_personnage_etat BEFORE UPDATE OF country, current_city, current_building, current_room, est_emprisonne, hospitalisation, detention_qhs
  ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.crim_personnage_etat_declencheur();

-- ── Revêtir / Retirer (0 PA) ────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_revetir(p_index integer, p_signature jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_pos integer; v_item jsonb; v_cat text; v_inv jsonb;
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
  -- Un seul objet porté par catégorie : l'ancien revient dans l'inventaire.
  v_inv := public.crim_inventaire_devetir_interne(d.inventory, a, v_cat);
  v_inv := jsonb_set(v_inv, ARRAY[v_pos::text], (v_inv -> v_pos) || jsonb_build_object('porte_par', a));
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = a;
  IF v_cat = 'masque' THEN
    INSERT INTO public.crim_jetons_masque (personnage) VALUES (a)
    ON CONFLICT (personnage) DO UPDATE SET jeton = gen_random_uuid(), le = now();
  END IF;
  RETURN jsonb_build_object('ok', true, 'categorie', v_cat, 'objet', v_item ->> 'name', 'mode', public.crim_mode_action_interne(a))
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;

CREATE OR REPLACE FUNCTION public.crim_retirer(p_index integer, p_signature jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_inv jsonb; v_pos integer; v_item jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF jsonb_typeof(v_inv) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_format_a_examiner'); END IF;
  -- On cherche d'abord une ligne PORTÉE correspondant à la signature (deux gilets : on retire celui qui est porté).
  SELECT (o - 1)::int INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
   WHERE public.crim_porte_ligne_interne(e, a)
     AND coalesce(e->>'name', '') = coalesce(p_signature->>'name', '') AND coalesce(e->>'type', '') = coalesce(p_signature->>'type', '')
   ORDER BY ((o - 1) = p_index) DESC, o LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_revetu'); END IF;
  v_item := v_inv -> v_pos;
  v_inv := jsonb_set(v_inv, ARRAY[v_pos::text], v_item - 'porte_par');
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'categorie', public.crim_objet_categorie_interne(v_item), 'objet', v_item ->> 'name',
                            'mode', public.crim_mode_action_interne(a))
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;

-- ── Se cacher (§ 1) ─────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_cacher_taux_interne(p_dis numeric, p_ninja boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(public.crim_param_interne('cacher_plafond', 98),
               public.crim_param_interne('cacher_base', 70)
               + public.crim_param_interne('cacher_par_20_dis', 5) * floor(greatest(0, coalesce(p_dis, 50)) / 20)
               + CASE WHEN p_ninja THEN public.crim_param_interne('cacher_ninja', 15) ELSE 0 END)::integer;
$$;

CREATE OR REPLACE FUNCTION public.se_cacher()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_taux integer; v_roll integer; v_ok boolean; v_critique boolean := false;
        v_ninja boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, resources INTO m
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  IF public.crim_cache_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_cache'); END IF;
  v_paie := public.payer_ordre(v_moi, 'se_cacher', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_ninja := public.crim_objet_porte_interne(v_moi, 'tenue_ninja');
  v_taux := public.crim_cacher_taux_interne(public.crim_stat_interne(v_moi, 'dis', 50), v_ninja);
  v_roll := floor(random() * 100)::integer + 1;
  -- Échec critique : les 2 derniers points du jet, quel que soit le taux.
  v_critique := v_roll > 100 - public.crim_param_interne('cacher_critique_points', 2)::integer;
  v_ok := v_roll <= v_taux AND NOT v_critique;
  IF v_ok THEN
    INSERT INTO public.caches_pj (personnage, pays, ville, batiment, piece, le)
    VALUES (v_moi, m.country, m.current_city, m.current_building, m.current_room, now())
    ON CONFLICT (personnage) DO UPDATE SET pays = EXCLUDED.pays, ville = EXCLUDED.ville,
      batiment = EXCLUDED.batiment, piece = EXCLUDED.piece, le = now();
  ELSIF v_critique THEN
    UPDATE public.personnages_donnees SET moral = greatest(0, coalesce(moral, 50) - public.crim_param_interne('echec_critique_moral', 15)::integer)
     WHERE name = v_moi;
  END IF;
  RETURN (SELECT jsonb_build_object('ok', true, 'cache', v_ok, 'critique', v_critique, 'taux', v_taux, 'jet', v_roll, 'ninja', v_ninja,
                 'moral', moral, 'pa', pa, 'liquide', liquide, 'arg', arg) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;
REVOKE ALL ON FUNCTION public.se_cacher() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.se_cacher() TO authenticated;

-- ── Fouiller les cachettes (§ 1) ────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_fouiller_taux_interne(p_per_fouilleur numeric, p_dis_cache numeric, p_ninja boolean, p_force boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(public.crim_param_interne('fouiller_min', 10), least(public.crim_param_interne('fouiller_max', 90),
           public.crim_param_interne('fouiller_base', 40)
           + public.crim_param_interne('fouiller_par_per', 2) * coalesce(p_per_fouilleur, 10)
           - floor(greatest(0, coalesce(p_dis_cache, 50)) / 10)
           - CASE WHEN p_ninja THEN public.crim_param_interne('fouiller_ninja', 15) ELSE 0 END
           + CASE WHEN p_force THEN public.crim_param_interne('fouiller_force_ordre', 20) ELSE 0 END))::integer;
$$;

CREATE OR REPLACE FUNCTION public.crim_fouiller_cachettes()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; c record; v_pa integer := public.crim_param_interne('fouiller_pa', 1)::integer;
        v_per numeric; v_force boolean; v_taux integer; v_trouves jsonb := '[]'::jsonb; v_n integer := 0; v_masque boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT name, pa, country, current_city, current_building, current_room, est_emprisonne INTO d
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(d.est_emprisonne), 'null') <> 'null' AND d.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF coalesce(d.current_building, '') = '' OR coalesce(d.current_room, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  IF coalesce(d.pa, 0) < v_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - v_pa WHERE name = a;
  v_per := public.crim_stat_interne(a, 'PER', 10);
  v_force := public.crim_force_ordre_interne(a);
  FOR c IN SELECT k.personnage FROM public.caches_pj k JOIN public.personnages_donnees p ON p.name = k.personnage
            WHERE k.personnage <> a AND p.country = d.country AND p.current_city = d.current_city
              AND p.current_building = d.current_building AND p.current_room = d.current_room
              AND k.pays = p.country AND k.ville = p.current_city AND k.batiment = p.current_building AND k.piece = p.current_room
            ORDER BY k.le FOR UPDATE OF k LOOP
    v_n := v_n + 1;
    v_taux := public.crim_fouiller_taux_interne(v_per, public.crim_stat_interne(c.personnage, 'dis', 50),
                                                public.crim_objet_porte_interne(c.personnage, 'tenue_ninja'), v_force);
    IF floor(random() * 100)::integer + 1 <= v_taux THEN
      PERFORM public.crim_debusquer_interne(c.personnage, 'fouille');
      v_masque := public.crim_masque_interne(c.personnage);
      -- Débusqué : il perd sa cachette mais garde son masque (le fouilleur ne voit qu'un individu masqué).
      v_trouves := v_trouves || jsonb_build_array(CASE WHEN v_masque THEN jsonb_build_object('masque', true)
                                                       ELSE jsonb_build_object('masque', false, 'nom', c.personnage) END);
      PERFORM public.crim_evenement_interne(c.personnage, 'debusque',
        CASE WHEN public.crim_masque_interne(a) THEN jsonb_build_object('par_masque', true) ELSE jsonb_build_object('par', a) END);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'trouves', v_trouves, 'nb', jsonb_array_length(v_trouves), 'pa', d.pa - v_pa,
                            'force_ordre', v_force);
END $$;

-- ── Présents (§ 1) ──────────────────────────────────────────────────────────────────────────────────────────────
-- Une ligne de presences est-elle publique ? Non si le PJ est caché dans sa pièce ou masqué.
CREATE OR REPLACE FUNCTION public.crim_presence_publique_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT NOT public.crim_cache_interne(p_nom) AND NOT public.crim_masque_interne(p_nom);
$$;
DROP POLICY IF EXISTS presences_lecture_publique ON public.presences;
CREATE POLICY presences_lecture_publique ON public.presences FOR SELECT
  USING (name = public.mon_personnage() OR public.crim_presence_publique_interne(name));

-- Liste des présents de MA pièce, telle que je la vois : cachés absents, masqués numérotés, sans nom ni portrait.
CREATE OR REPLACE FUNCTION public.crim_presents()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a;
  IF coalesce(d.current_building, '') = '' OR coalesce(d.current_room, '') = '' THEN RETURN jsonb_build_object('ok', true, 'presents', '[]'::jsonb); END IF;
  WITH pr AS (
    SELECT p.name, p.updated_at, p.groupe_pnj,
           (p.name <> a AND public.crim_cache_interne(p.name)) AS cache,
           (p.name <> a AND public.crim_masque_interne(p.name)) AS masque
      FROM public.presences p
     WHERE p.country = d.country AND p.city = d.current_city AND p.building_id = d.current_building AND p.room_id = d.current_room
       AND p.updated_at > now() - interval '5 minutes'
  ), vis AS (
    SELECT pr.*, CASE WHEN masque THEN row_number() OVER (PARTITION BY masque ORDER BY md5(name || d.current_building || d.current_room)) END AS numero
      FROM pr WHERE NOT cache
  )
  SELECT coalesce(jsonb_agg(CASE WHEN masque THEN
           jsonb_build_object('name', 'Individu masqué n°' || numero, 'masque', true, 'numero', numero, 'updated_at', updated_at,
                              'jeton', (SELECT jeton FROM public.crim_jetons_masque j WHERE j.personnage = vis.name),
                              'groupe_pnj', (SELECT coalesce(jsonb_agg(g - 'photoUrl'), '[]'::jsonb)
                                               FROM jsonb_array_elements(CASE WHEN jsonb_typeof(groupe_pnj) = 'array' THEN groupe_pnj ELSE '[]'::jsonb END) g))
         ELSE jsonb_build_object('name', name, 'masque', false, 'updated_at', updated_at, 'groupe_pnj', groupe_pnj) END
         ORDER BY masque, numero, name), '[]'::jsonb)
    INTO v FROM vis;
  RETURN jsonb_build_object('ok', true, 'presents', v, 'mode', public.crim_mode_action_interne(a));
END $$;

-- ── Gilet : ne compte que revêtu (militaire_gilet_absorber, branche PJ ; le moteur de combat ne change pas) ───────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

SELECT pg_temp.rp_raccorder('public.militaire_gilet_absorber(boolean,text,text,text,text)'::regprocedure,
  $a$WHERE i->>'produitMilitaire' = 'gilet_pare_balles'$a$,
  $b$WHERE public.crim_objet_categorie_interne(i) = 'gilet' AND public.crim_porte_ligne_interne(i, p_nom) /* crim_gilet_revetu_v1 */$b$,
  'crim_gilet_revetu_v1');

-- Empoisonnement : la cachette n'est plus consommée par la tentative (§ 1 ; le reste du § 9 viendra avec son lot).
SELECT pg_temp.rp_raccorder('public.crime_empoisonner(text)'::regprocedure,
  $a$  DELETE FROM public.caches_pj WHERE personnage = v_moi;$a$,
  $b$  NULL; /* crim_cachette_conservee_v1 */$b$,
  'crim_cachette_conservee_v1');

-- Gilets déjà détenus : le premier de chaque personnage est revêtu (rien n'est retiré à personne).
UPDATE public.personnages_donnees pd SET inventory = (
    SELECT jsonb_agg(CASE WHEN o = (SELECT min(o2) FROM jsonb_array_elements(pd.inventory) WITH ORDINALITY y(e2, o2)
                                     WHERE public.crim_objet_categorie_interne(e2) = 'gilet')
                          THEN e || jsonb_build_object('porte_par', pd.name) ELSE e END ORDER BY o)
      FROM jsonb_array_elements(pd.inventory) WITH ORDINALITY x(e, o))
 WHERE jsonb_typeof(pd.inventory) = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(pd.inventory) e WHERE public.crim_objet_categorie_interne(e) = 'gilet')
   AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(pd.inventory) e WHERE e ? 'porte_par');

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_param_interne(text,numeric)', 'crim_stat_interne(text,text,numeric)', 'crim_objet_porte_interne(text,text)',
    'crim_objet_interne(text)', 'crim_boutique_interne(text)', 'crim_prix_interne(text,text)', 'crim_evenement_interne(text,text,jsonb)',
    'crim_cache_interne(text)', 'crim_masque_interne(text)', 'crim_mode_action_interne(text)', 'crim_force_ordre_interne(text)',
    'crim_debusquer_interne(text,text)', 'crim_jeton_resoudre_interne(text)', 'crim_vetements_retirer_interne(text,text)',
    'crim_personnage_etat_declencheur()', 'crim_cacher_taux_interne(numeric,boolean)',
    'crim_fouiller_taux_interne(numeric,numeric,boolean,boolean)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['boutique_discretion_etat()', 'boutique_discretion_acheter(uuid,text)', 'crim_evenements_lire()',
    'crim_revetir(integer,jsonb)', 'crim_retirer(integer,jsonb)', 'crim_fouiller_cachettes()', 'crim_presents()'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;
-- La politique de lecture de presences appelle ce prédicat pour tous les rôles.
GRANT EXECUTE ON FUNCTION public.crim_presence_publique_interne(text) TO anon, authenticated;

COMMIT;
