-- ============================================================================
-- CHANTIER 4D -- LA COMMANDE MILITAIRE PASSE PAR UNE PORTE, ET LA PORTE A UNE SERRURE
--
-- CE QUI ETAIT OUVERT. commandes_militaires etait ecrite par un INSERT PostgREST
-- direct, sous une policy `acteur_identifie()`. N'importe quel joueur authentifie
-- pouvait donc creer une commande militaire pour n'importe quel PAYS, avec un
-- PRODUIT arbitraire -- aucune contrainte, aucune cle etrangere, aucun trigger ne
-- bornait ce champ -- et en n'importe quelle QUANTITE ; et la policy UPDATE, de
-- la meme forme, laissait modifier la commande d'autrui. Le poste `min_def`
-- n'etait verifie QUE dans le navigateur, a trois endroits. Un controle
-- navigateur n'est pas une autorite.
--
-- CE QUE FAIT CETTE MIGRATION, EN TROIS TEMPS.
--
-- 1. Le serveur apprend ce qu'est une recette militaire. Il ne le savait pas :
--    le catalogue n'existait qu'en JavaScript, deux fois (navigateur et cron).
--    La table ci-dessous est un MIROIR GENERE depuis la source canonique
--    (plateau-effort-guerre.js, RECETTES_MILITAIRES) par
--    outils/generateurs/generer_recettes_militaires.py, surveille par une
--    empreinte comme les quatre autres miroirs du depot. On ne recopie pas, on
--    regenere -- sans quoi cette migration aurait cree une TROISIEME copie.
--
-- 2. Deux portes serveur remplacent l'ecriture directe : effort_commande_creer
--    et effort_commande_annuler. Elles portent les cinq regles que le navigateur
--    appliquait seul -- poste min_def, produit au catalogue, quantite bornee,
--    Effort de guerre actif, et le pays DU MINISTRE et non celui qu'il demande.
--
-- 3. La surface directe se ferme : les deux policies d'ecriture tombent, et
--    INSERT/UPDATE sont revoques a authenticated. La lecture reste ouverte --
--    le tableau de l'Effort doit continuer d'afficher les commandes.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS. Elle ne touche a aucune commande
-- existante, a aucun stock, a aucune caisse. Elle ne change pas le comportement
-- d'une commande deja passee. effort_produire_lot n'est pas modifiee.
--
-- Idempotente : CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE, DROP POLICY IF
-- EXISTS, et un seed en INSERT ... ON CONFLICT DO UPDATE.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. LE MIROIR DES RECETTES, ET SA SENTINELLE
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recettes_militaires (
  produit         text PRIMARY KEY,
  label           text NOT NULL,
  materiaux       jsonb NOT NULL,
  pa              integer,
  produit_par_lot integer NOT NULL,
  type_objet      text,
  sous_type       text,
  prix_pnj        integer,
  capacite        integer
);

COMMENT ON TABLE public.recettes_militaires IS
  'MIROIR GENERE de RECETTES_MILITAIRES (plateau-effort-guerre.js). Ne jamais editer '
  'a la main : regenerer par outils/generateurs/generer_recettes_militaires.py. '
  'Sert au serveur a valider qu''un produit commande appartient au catalogue. Chantier 4D.';

CREATE TABLE IF NOT EXISTS public.recettes_militaires_empreinte (
  empreinte text NOT NULL,
  pose_le   timestamptz NOT NULL DEFAULT now()
);

-- Le seed, GENERE. Un produit retire du canon disparait aussi d'ici : sans le
-- DELETE, une recette supprimee du jeu resterait commandable indefiniment.
INSERT INTO public.recettes_militaires
  (produit, label, materiaux, pa, produit_par_lot, type_objet, sous_type, prix_pnj, capacite)
VALUES
  ('arme_de_poing', 'Pistolet militaire', '{"bois":1,"metal":2}'::jsonb, NULL, 1, 'arme', 'militaire', NULL, NULL),
  ('explosif_militaire', 'Explosifs militaires', '{"metal":2,"minerai":3}'::jsonb, 1, 3, 'explosif', 'militaire', NULL, NULL),
  ('gilet_pare_balles', 'Gilet pare-balles', '{"metal":2,"textile":2}'::jsonb, 3, 1, 'equipement', 'militaire', 380, NULL),
  ('jumelles', 'Jumelles', '{"metal":1,"minerai":1,"textile":1}'::jsonb, 2, 1, 'equipement', 'militaire', 260, NULL),
  ('mitraillette', 'Mitraillette', '{"bois":2,"metal":2}'::jsonb, NULL, 1, 'arme', 'militaire', NULL, NULL),
  ('radio', 'Radio de campagne', '{"metal":1,"minerai":1,"textile":1}'::jsonb, 3, 1, 'equipement', 'militaire', 360, NULL),
  ('tente', 'Tente de campagne', '{"metal":1,"textile":1}'::jsonb, 2, 1, 'equipement', 'militaire', 240, 13),
  ('tenue_camouflage', 'Tenue de camouflage', '{"charbon":1,"fruits_legumes":1,"textile":1}'::jsonb, 2, 1, 'equipement', 'militaire', 230, NULL)
ON CONFLICT (produit) DO UPDATE SET
  label = EXCLUDED.label, materiaux = EXCLUDED.materiaux, pa = EXCLUDED.pa,
  produit_par_lot = EXCLUDED.produit_par_lot, type_objet = EXCLUDED.type_objet,
  sous_type = EXCLUDED.sous_type, prix_pnj = EXCLUDED.prix_pnj, capacite = EXCLUDED.capacite;

DELETE FROM public.recettes_militaires WHERE produit NOT IN (
  'arme_de_poing','explosif_militaire','gilet_pare_balles','jumelles',
  'mitraillette','radio','tente','tenue_camouflage');

DELETE FROM public.recettes_militaires_empreinte;
INSERT INTO public.recettes_militaires_empreinte (empreinte) VALUES ('6162d0e5d809630e');

-- Meme formule que generer_recettes_militaires.py, empreinte().
--
-- DEUX PIEGES, TOUS DEUX PAYES D'AVANCE.
-- COLLATE "C" sur le tri : Python trie par point de code, la collation de la
-- base ignore la ponctuation au premier niveau, et deux tris differents sur le
-- meme contenu rendent deux hachages differents.
-- Et surtout, les matieres sont hachees sous une forme PLATE construite ici,
-- jamais par materiaux::text. PostgreSQL ordonne les cles d'un jsonb par
-- LONGUEUR puis par octets et intercale des espaces : la tenue de camouflage
-- sort « charbon, textile, fruits_legumes » cote base contre
-- « charbon, fruits_legumes, textile » cote Python. Les deux empreintes
-- auraient diverge sur un contenu rigoureusement identique.
CREATE OR REPLACE FUNCTION public.recettes_militaires_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      produit || '|' || coalesce(label, '')
              || '|' || (SELECT coalesce(string_agg(k || ':' || (r.materiaux ->> k),
                                                    ',' ORDER BY k COLLATE "C"), '')
                           FROM jsonb_object_keys(r.materiaux) AS k)
              || '|' || coalesce(pa::text, '')
              || '|' || coalesce(produit_par_lot::text, '')
              || '|' || coalesce(type_objet, '')
              || '|' || coalesce(sous_type, '')
              || '|' || coalesce(prix_pnj::text, '')
              || '|' || coalesce(capacite::text, ''),
      E'\n' ORDER BY produit COLLATE "C")), 16)
  FROM public.recettes_militaires AS r;
$function$;

COMMENT ON FUNCTION public.recettes_militaires_empreinte_reelle() IS
  'Empreinte reelle du miroir des recettes militaires. Pendant SQL de '
  'outils/generateurs/generer_recettes_militaires.py. Chantier 4D.';

ALTER TABLE public.recettes_militaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recettes_militaires_empreinte ENABLE ROW LEVEL SECURITY;

-- Le catalogue est public : l'interface doit pouvoir nommer un produit. Il n'est
-- ecrit par personne d'autre que la regeneration.
DROP POLICY IF EXISTS recettes_militaires_lecture ON public.recettes_militaires;
CREATE POLICY recettes_militaires_lecture ON public.recettes_militaires
  FOR SELECT TO PUBLIC USING (true);

GRANT SELECT ON public.recettes_militaires TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. LES DEUX PORTES SERVEUR
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.effort_commande_creer(p_produit text, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text;
  v_rec public.recettes_militaires%ROWTYPE;
  v_effort jsonb; v_expire numeric; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LE PAYS VIENT DU MINISTRE, JAMAIS DU PARAMETRE. C'est ce qui empeche de
  -- commander pour un empire sur lequel on n'a aucune autorite : il n'y a tout
  -- simplement pas de parametre `pays` a cette fonction.
  SELECT coalesce(country, 'republic'), poste ->> 'id'
    INTO v_pays, v_poste
    FROM public.personnages_donnees WHERE name = v_moi;

  IF coalesce(v_poste, '') <> 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis',
                              'attendu', 'min_def', 'obtenu', v_poste);
  END IF;

  SELECT * INTO v_rec FROM public.recettes_militaires WHERE produit = p_produit;
  IF v_rec.produit IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_hors_catalogue',
                              'produit', p_produit);
  END IF;

  IF p_quantite IS NULL OR p_quantite <= 0 OR p_quantite > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide',
                              'quantite', p_quantite);
  END IF;

  -- L'Effort de guerre doit etre actif ET non expire. Le navigateur le verifiait
  -- deja ; il le verifie toujours, mais ce n'est plus lui qui decide.
  SELECT data -> 'effortGuerre' INTO v_effort
    FROM public.budgets_nationaux WHERE id = v_pays;
  IF v_effort IS NULL OR coalesce((v_effort ->> 'actif')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effort_inactif');
  END IF;
  v_expire := (v_effort ->> 'expireA')::numeric;
  IF v_expire IS NOT NULL
     AND v_expire <= extract(epoch FROM now()) * 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effort_expire');
  END IF;

  -- L'identifiant est fabrique ICI. Le laisser au client, c'etait lui laisser
  -- choisir la cle primaire d'une ligne qu'il ne possede pas.
  v_id := 'cmd-' || to_char(now(), 'YYYYMMDDHH24MISS') || '-' ||
          substr(md5(random()::text || v_moi), 1, 8);

  INSERT INTO public.commandes_militaires
    (id, pays, produit, quantite_demandee, quantite_produite, statut, ministre)
  VALUES (v_id, v_pays, p_produit, p_quantite, 0, 'en_cours', v_moi);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'pays', v_pays,
                            'produit', p_produit, 'label', v_rec.label,
                            'quantite_demandee', p_quantite, 'ministre', v_moi);
END;
$function$;

COMMENT ON FUNCTION public.effort_commande_creer(text, integer) IS
  'Seule porte de creation d''une commande militaire. Exige le poste min_def, un produit '
  'du catalogue canonique (recettes_militaires), une quantite bornee et un Effort de guerre '
  'actif. Le pays est celui du ministre, jamais un parametre. Chantier 4D.';

CREATE OR REPLACE FUNCTION public.effort_commande_annuler(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text;
  v_cmd public.commandes_militaires%ROWTYPE;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country, 'republic'), poste ->> 'id'
    INTO v_pays, v_poste
    FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(v_poste, '') <> 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis',
                              'attendu', 'min_def', 'obtenu', v_poste);
  END IF;

  SELECT * INTO v_cmd FROM public.commandes_militaires WHERE id = p_id FOR UPDATE;
  IF v_cmd.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_inconnue');
  END IF;
  -- Un ministre n'annule que les commandes de SON empire.
  IF v_cmd.pays <> v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_hors_pays');
  END IF;
  IF v_cmd.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_close',
                              'statut', v_cmd.statut);
  END IF;

  -- quantite_produite n'est JAMAIS touchee : ce qui a ete produit, paye et livre
  -- reste definitif. C'est la regle d'avant, conservee telle quelle.
  UPDATE public.commandes_militaires
     SET statut = 'annulee', updated_at = now()
   WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'id', p_id,
                            'quantite_produite', v_cmd.quantite_produite);
END;
$function$;

COMMENT ON FUNCTION public.effort_commande_annuler(text) IS
  'Seule porte d''annulation du reliquat d''une commande militaire. Exige min_def et '
  'le meme pays que la commande. quantite_produite n''est jamais modifiee. Chantier 4D.';

GRANT EXECUTE ON FUNCTION public.effort_commande_creer(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.effort_commande_annuler(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. FERMETURE DE LA SURFACE DIRECTE
--
-- La lecture reste ouverte : le tableau de l'Effort affiche les commandes en
-- cours, et c'est voulu. Seule l'ECRITURE change de porte.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS commandes_militaires_ecriture_acteur ON public.commandes_militaires;
DROP POLICY IF EXISTS commandes_militaires_maj_acteur ON public.commandes_militaires;

REVOKE INSERT, UPDATE ON public.commandes_militaires FROM anon, authenticated, PUBLIC;
