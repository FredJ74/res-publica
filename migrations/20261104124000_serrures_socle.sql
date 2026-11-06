-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_socle_20261104124000), structure eprouvee en transaction annulee
-- avant application, puis banc annule outils/bancs/banc-serrures.sql joue en production : vert.
-- 4 novembre 2026 -- SERRURES, etape 1 : le socle (issue #434, GAME-DESIGN-SERRURES.md).
--
-- Decisions de Fred (01/11 et 04/11) : la serrure est un article de quincaillerie, PAS une arme ;
-- 2 metal + 1 PA = 2 serrures, 60 FR la serrure en commerce PNJ ; 1 metal + 1 PA = 10 cles
-- vierges ; chaque serrure est vendue avec UNE cle ; doubles illimites ; la cle est transmissible
-- et ouvre pour qui la detient ; au depart du locataire, la serrure posee sur le lieu est detruite
-- pour tout le monde, irreversiblement. Prix : la regle existante (04/11) -- PNJ : 60 FR decide
-- pour la serrure, 2 x le cout de revient pour la cle vierge (14 FR) ; un PJ fixe ses prix.
--
-- Ce fichier pose :
--   * la table serrures : une ligne par serrure vendue (neuve -> posee -> detruite), son etat
--     fermee/ouverte, sa cible (lieu ou armoire) et le bail qui l'a vue poser ;
--   * les deux recettes de quincaillerie dans le miroir recettes_commerce (source 'quincaillerie',
--     regenere depuis QUINCAILLERIE_PRODUITS par generer_miroirs_entreprises.py) ;
--   * les prix et plafonds par defaut des armureries de Republia (dotation + armureries PNJ
--     existantes, sans ecraser une valeur deja posee) ;
--   * les moteurs sans autorite : recette de quincaillerie, objets d'inventaire, validite d'une
--     serrure, cle detenue, fin de bail.
-- Idempotente. Aucun acte de joueur.

CREATE TABLE IF NOT EXISTS public.serrures (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  statut            text NOT NULL DEFAULT 'neuve' CHECK (statut IN ('neuve', 'posee', 'detruite')),
  fermee            boolean NOT NULL DEFAULT false,
  cible             text CHECK (cible IN ('lieu', 'armoire')),
  pays text, ville text, batiment text, piece text,
  armoire_objet     text,
  bail_ref          text,
  bail_titulaire    text,
  poseur            text,
  posee_le          timestamptz,
  detruite_le       timestamptz,
  motif_destruction text,
  achetee_par       text,
  entreprise        text,
  cree_le           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT serrures_posee_cible CHECK (statut <> 'posee' OR cible IS NOT NULL),
  CONSTRAINT serrures_lieu_bail CHECK (cible IS DISTINCT FROM 'lieu' OR (bail_ref IS NOT NULL AND bail_titulaire IS NOT NULL)),
  CONSTRAINT serrures_armoire_objet CHECK (cible IS DISTINCT FROM 'armoire' OR armoire_objet IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS serrures_lieu_unique ON public.serrures (pays, ville, batiment, piece)
  WHERE statut = 'posee' AND cible = 'lieu';
CREATE UNIQUE INDEX IF NOT EXISTS serrures_armoire_unique ON public.serrures (armoire_objet)
  WHERE statut = 'posee' AND cible = 'armoire';
ALTER TABLE public.serrures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.serrures FROM anon, authenticated;

-- Miroir regenere (lignes de la source 'quincaillerie', identiques a la sortie du generateur).
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie,
  effets, stack_key, sous_type, icone, image, description, famille_produit_marche, bonus_integration_ville,
  types_autorises, pays_autorises, villes_autorisees, buildings_autorises) VALUES
  ('cle_vierge', 'quincaillerie', 'Clé vierge', 1, 10, '{"metal": 1}'::jsonb, NULL, 'quincaillerie',
   NULL, NULL, NULL, 'ti-key', NULL, 'Une clé brute. Taillée sur une clé que vous détenez, elle devient un double.',
   NULL, NULL, '["armurerie"]'::jsonb, '["republic"]'::jsonb, NULL, NULL),
  ('serrure_cle', 'quincaillerie', 'Serrure à clé', 1, 2, '{"metal": 2}'::jsonb, NULL, 'quincaillerie',
   NULL, NULL, NULL, 'ti-lock', NULL, 'Un bloc serrure vendu avec sa clé. Se pose sur une armoire à souvenirs installée, ou sur un local ou un appartement dont vous avez la jouissance.',
   NULL, NULL, '["armurerie"]'::jsonb, '["republic"]'::jsonb, NULL, NULL)
ON CONFLICT (id) DO UPDATE SET source = EXCLUDED.source, label = EXCLUDED.label, pa = EXCLUDED.pa,
  portions = EXCLUDED.portions, materiaux = EXCLUDED.materiaux, prix_fixe = EXCLUDED.prix_fixe,
  categorie = EXCLUDED.categorie, icone = EXCLUDED.icone, description = EXCLUDED.description,
  types_autorises = EXCLUDED.types_autorises, pays_autorises = EXCLUDED.pays_autorises;

UPDATE public.armureries_dotations
   SET parametres = '{"prixAchatMatiere": {"bois": 10, "metal": 20}, "prixVente": {"carabine_chasse": 1200, "cle_vierge": 14, "couteau": 300, "revolver": 800, "serrure_cle": 60}, "stockMax": {"carabine_chasse": 5, "cle_vierge": 50, "couteau": 10, "revolver": 5, "serrure_cle": 10}}'::jsonb
 WHERE pays = 'republic';

-- Armureries existantes de Republia : prix et plafonds par defaut, sans ecraser une valeur posee.
UPDATE public.entreprises
   SET data = jsonb_set(jsonb_set(data, '{parametres,prixVente}',
                '{"serrure_cle": 60, "cle_vierge": 14}'::jsonb || coalesce(data->'parametres'->'prixVente', '{}'::jsonb), true),
                '{parametres,stockMax}',
                '{"serrure_cle": 10, "cle_vierge": 50}'::jsonb || coalesce(data->'parametres'->'stockMax', '{}'::jsonb), true),
       updated_at = now()
 WHERE data->>'type' = 'armurerie' AND coalesce(data->>'country', 'republic') = 'republic'
   AND jsonb_typeof(data->'parametres') = 'object'
   AND NOT (coalesce(data->'parametres'->'prixVente', '{}'::jsonb) ? 'serrure_cle'
        AND coalesce(data->'parametres'->'prixVente', '{}'::jsonb) ? 'cle_vierge'
        AND coalesce(data->'parametres'->'stockMax', '{}'::jsonb) ? 'serrure_cle'
        AND coalesce(data->'parametres'->'stockMax', '{}'::jsonb) ? 'cle_vierge');

-- Recette de quincaillerie d'une armurerie de ce pays (ligne vide si inconnue).
CREATE OR REPLACE FUNCTION public.quincaillerie_recette_interne(p_id text, p_pays text)
RETURNS public.recettes_commerce LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT r.* FROM public.recettes_commerce r
   WHERE r.id = p_id AND r.source = 'quincaillerie'
     AND coalesce(r.types_autorises, '["armurerie"]'::jsonb) @> '["armurerie"]'::jsonb
     AND (r.pays_autorises IS NULL OR r.pays_autorises @> jsonb_build_array(p_pays));
$$;

CREATE OR REPLACE FUNCTION public.serrure_numero_interne(p_id uuid)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT upper(left(replace(p_id::text, '-', ''), 6));
$$;

-- Objets d'inventaire : le bloc (non empilable) et la cle (empilable par serrure).
CREATE OR REPLACE FUNCTION public.serrure_objet_interne(p_id uuid)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('type', 'serrure_cle', 'name', 'Serrure à clé n° ' || public.serrure_numero_interne(p_id),
    'icon', 'ti-lock', 'serrureId', p_id::text, 'numero', public.serrure_numero_interne(p_id), 'stackable', false,
    'desc', 'Bloc serrure. Se pose sur une armoire à souvenirs installée, ou sur un local ou un appartement dont vous avez la jouissance.');
$$;
CREATE OR REPLACE FUNCTION public.serrure_cle_objet_interne(p_id uuid, p_qte integer DEFAULT 1)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('type', 'cle_serrure', 'name', 'Clé n° ' || public.serrure_numero_interne(p_id),
    'icon', 'ti-key', 'serrureId', p_id::text, 'numero', public.serrure_numero_interne(p_id),
    'stackable', true, 'stackKey', 'cle_serrure:' || p_id::text, 'qty', greatest(1, p_qte),
    'desc', 'Clé de la serrure n° ' || public.serrure_numero_interne(p_id) || '. Elle ouvre et ferme cette serrure, pour qui la détient.');
$$;
CREATE OR REPLACE FUNCTION public.cle_vierge_objet_interne(p_qte integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('type', 'cle_vierge', 'name', 'Clé vierge', 'icon', 'ti-key',
    'stackable', true, 'stackKey', 'cle_vierge', 'qty', greatest(1, p_qte),
    'desc', 'Une clé brute. Taillée sur une clé que vous détenez, elle devient un double.');
$$;

-- Une serrure ne vaut que posee ; sur un lieu, tant que dure le bail qui l'a vue poser.
CREATE OR REPLACE FUNCTION public.serrure_valide_interne(s public.serrures)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT s.statut = 'posee' AND (s.cible = 'armoire' OR EXISTS (
    SELECT 1 FROM public.locations_actives l
     WHERE l.id = s.bail_ref
       AND coalesce(nullif(l.data->>'orgaId', ''), replace(coalesce(l.data->>'locataire', ''), 'pj:', '')) = s.bail_titulaire));
$$;

CREATE OR REPLACE FUNCTION public.serrure_cle_detenue_interne(p_acteur text, p_serrure uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d,
      jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) e
     WHERE d.name = p_acteur AND e->>'type' = 'cle_serrure' AND e->>'serrureId' = p_serrure::text);
$$;

-- Fin de bail : la serrure du lieu est detruite pour tout le monde (decision du 01/11), avec
-- toutes ses cles. Sans filtre : toutes les serrures de lieu (passe de nuit) ; avec : ce lieu.
CREATE OR REPLACE FUNCTION public.serrures_fin_bail_interne(p_pays text DEFAULT NULL, p_ville text DEFAULT NULL,
  p_batiment text DEFAULT NULL, p_piece text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.serrures; n integer := 0;
BEGIN
  FOR s IN SELECT * FROM public.serrures x
            WHERE x.statut = 'posee' AND x.cible = 'lieu'
              AND (p_piece IS NULL OR (x.pays, x.ville, x.batiment, x.piece) = (p_pays, p_ville, p_batiment, p_piece))
            FOR UPDATE LOOP
    CONTINUE WHEN public.serrure_valide_interne(s);
    UPDATE public.serrures SET statut = 'detruite', fermee = false, detruite_le = now(),
           motif_destruction = 'fin_de_bail' WHERE id = s.id;
    PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', s.poseur, 'Serrure détruite',
      'Le bail du local où vous aviez posé la serrure n° ' || public.serrure_numero_interne(s.id) || ' (' || s.piece
      || ') a pris fin. La serrure est détruite : plus aucune de ses clés n''ouvre quoi que ce soit.');
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

REVOKE ALL ON FUNCTION public.quincaillerie_recette_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_numero_interne(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_objet_interne(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_cle_objet_interne(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cle_vierge_objet_interne(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_valide_interne(public.serrures) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_cle_detenue_interne(text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrures_fin_bail_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;
