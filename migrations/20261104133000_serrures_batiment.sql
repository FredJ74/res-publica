-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_batiment_20261104133000), structure eprouvee en transaction annulee,
-- banc annule outils/bancs/banc-serrures-batiment.sql vert.
-- 4 novembre 2026 -- SERRURES, etape 7 : le batiment entier, et l'etat ouvert / ferme vu de dehors (issue #434).
--
-- Decisions de Fred (04/11, 14 h 07 et 14 h 27) :
--   * « Seule une personne qui a l'integralite de la jouissance d'un batiment peut fermer un
--     batiment entier. » Integralite : proprietaire (ou coproprietaire) du batiment construit, ou
--     membre de l'organisation proprietaire, et aucun lot du batiment loue a quelqu'un d'autre.
--     La serrure du batiment se pose sur son entree ; elle est detruite des que cette integralite
--     se perd (vente, lot loue a un tiers), comme celle d'un local au depart du locataire.
--   * Batiment ferme a cle : l'infobulle le dit, seul un detenteur de cle peut entrer ; dedans, il
--     l'ouvre au public ou le referme. Meme principe pour un local.
--   * Vu de dehors, un cadenas ouvert ou ferme selon l'etat : serrures_portes_lire rend desormais
--     toutes les serrures posees du batiment (ouvertes comprises) ; serrures_batiments_lire rend
--     celles des batiments de la ville.

ALTER TABLE public.serrures DROP CONSTRAINT IF EXISTS serrures_cible_check;
ALTER TABLE public.serrures ADD CONSTRAINT serrures_cible_check CHECK (cible IN ('lieu', 'armoire', 'batiment'));
CREATE UNIQUE INDEX IF NOT EXISTS serrures_batiment_unique ON public.serrures (pays, ville, batiment)
  WHERE statut = 'posee' AND cible = 'batiment';

CREATE OR REPLACE FUNCTION public.batiment_jouissance_integrale_interne(p_acteur text, p_pays text, p_ville text, p_batiment text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH t AS (
    SELECT coalesce(nullif(te.proprietaire, ''), te.data::jsonb->>'proprietaire') AS prop, te.coproprietaire AS copro,
           coalesce(nullif(te.niveau_construction, ''), te.data::jsonb->>'niveau_construction') AS niveau, te.data::jsonb AS d
      FROM public.terrains_etat te
     WHERE te.country = p_pays AND te.building_id = p_batiment AND coalesce(te.data::jsonb->>'city', p_ville) = p_ville
     LIMIT 1),
  moi AS (
    SELECT t.*, (replace(coalesce(t.prop, ''), 'pj:', '') = p_acteur OR replace(coalesce(t.copro, ''), 'pj:', '') = p_acteur
             OR (left(coalesce(t.prop, ''), 5) = 'orga:' AND EXISTS (SELECT 1 FROM public.organisations o
                  WHERE o.id = substr(t.prop, 6) AND (o.data::jsonb->>'chef' = p_acteur OR EXISTS (
                    SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array'
                                                       THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) mb
                     WHERE mb->>'nom' = p_acteur))))) AS a_moi
      FROM t)
  SELECT coalesce((SELECT moi.a_moi AND moi.niveau IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(moi.d->'subdivisions') = 'array'
                                                          THEN moi.d->'subdivisions' ELSE '[]'::jsonb END) x
                       WHERE coalesce(x->>'locataire', '') <> '' AND replace(x->>'locataire', 'pj:', '') <> p_acteur
                         AND x->>'locataire' IS DISTINCT FROM moi.prop)
      AND NOT EXISTS (SELECT 1 FROM public.locations_actives l
                       WHERE l.id LIKE p_pays || ':' || p_batiment || ':%:' || p_ville
                         AND replace(coalesce(l.data->>'locataire', ''), 'pj:', '') NOT IN ('', p_acteur)
                         AND coalesce('orga:' || nullif(l.data->>'orgaId', ''), '') IS DISTINCT FROM moi.prop)
    FROM moi), false);
$$;

CREATE OR REPLACE FUNCTION public.serrure_valide_interne(s public.serrures)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT s.statut = 'posee' AND (s.cible = 'armoire'
    OR (s.cible = 'batiment' AND public.batiment_jouissance_integrale_interne(s.poseur, s.pays, s.ville, s.batiment))
    OR (s.cible = 'lieu' AND EXISTS (
      SELECT 1 FROM public.locations_actives l
       WHERE l.id = s.bail_ref
         AND coalesce(nullif(l.data->>'orgaId', ''), replace(coalesce(l.data->>'locataire', ''), 'pj:', '')) = s.bail_titulaire)));
$$;

-- Fin de jouissance : avec un filtre de piece, la serrure du local ET celle du batiment qui le
-- contient sont examinees ; sans filtre, toutes (passe de nuit).
CREATE OR REPLACE FUNCTION public.serrures_fin_bail_interne(p_pays text DEFAULT NULL, p_ville text DEFAULT NULL,
  p_batiment text DEFAULT NULL, p_piece text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.serrures; n integer := 0;
BEGIN
  FOR s IN SELECT * FROM public.serrures x
            WHERE x.statut = 'posee' AND x.cible IN ('lieu', 'batiment')
              AND (p_batiment IS NULL OR (x.pays, x.ville, x.batiment) = (p_pays, p_ville, p_batiment))
              AND (p_piece IS NULL OR x.cible = 'batiment' OR x.piece = p_piece)
            FOR UPDATE LOOP
    CONTINUE WHEN public.serrure_valide_interne(s);
    UPDATE public.serrures SET statut = 'detruite', fermee = false, detruite_le = now(),
           motif_destruction = 'fin_de_bail' WHERE id = s.id;
    PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', s.poseur, 'Serrure détruite',
      CASE WHEN s.cible = 'batiment'
           THEN 'Vous n''avez plus l''intégralité de la jouissance du bâtiment où vous aviez posé la serrure n° '
                || public.serrure_numero_interne(s.id) || '. La serrure est détruite : plus aucune de ses clés n''ouvre quoi que ce soit.'
           ELSE 'Le bail du local où vous aviez posé la serrure n° ' || public.serrure_numero_interne(s.id) || ' (' || s.piece
                || ') a pris fin. La serrure est détruite : plus aucune de ses clés n''ouvre quoi que ce soit.' END);
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

CREATE OR REPLACE FUNCTION public.serrure_batiment_ferme_interne(p_nom text, p_pays text, p_ville text, p_batiment text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id uuid;
BEGIN
  IF p_batiment IS NULL OR NOT EXISTS (SELECT 1 FROM public.serrures WHERE statut = 'posee' AND cible = 'batiment' AND fermee
       AND (pays, ville, batiment) = (p_pays, p_ville, p_batiment)) THEN RETURN false; END IF;
  PERFORM public.serrures_fin_bail_interne(p_pays, p_ville, p_batiment, NULL);
  SELECT id INTO v_id FROM public.serrures WHERE statut = 'posee' AND cible = 'batiment' AND fermee
     AND (pays, ville, batiment) = (p_pays, p_ville, p_batiment);
  RETURN v_id IS NOT NULL AND NOT public.serrure_cle_detenue_interne(p_nom, v_id);
END $$;

REVOKE ALL ON FUNCTION public.batiment_jouissance_integrale_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_batiment_ferme_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;
