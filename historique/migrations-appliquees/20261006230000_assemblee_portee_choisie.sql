-- ============================================================================
-- CHANTIER 4D -- UNE CATEGORIE NE PORTE PLUS DE POLITIQUE
--
-- CE QUI ETAIT IMPLICITE. Une interdiction visait TOUT ce que sa categorie
-- recouvre, sans que le deposant puisse en decider. Interdire « les armes a
-- feu » tranchait d'office le sort de l'armement militaire ; interdire « les
-- medicaments » tranchait d'office celui des objets de soin. Ces choix sont
-- POLITIQUES : ils appartiennent aux deputes, pas a une ligne de catalogue.
--
-- CE QUE FAIT CETTE MIGRATION. Elle etend la portee -- deja presente, deja
-- fermee -- de UNE a QUATRE dimensions, et fait lire cette portee par la garde
-- de legalite. Rien n'est ajoute a cote : c'est le meme mecanisme, avec trois
-- cles de plus.
--
--   transformation_stock_interdite  (existante, inchangee)
--   volet_matieres   la loi vise-t-elle les MATIERES de la categorie ?
--   volet_objets     vise-t-elle les OBJETS de la categorie ?
--   sous_types       restreint-elle les sous-types vises ? (null = tous)
--
-- Ces quatre dimensions suffisent aux trois arbitrages, SANS cas particulier :
--   . medicaments : volet_matieres / volet_objets / les deux ;
--   . armes       : sous_types ['militaire'] ou les sous-types civils, ou null ;
--   . explosifs   : une CATEGORIE a part, donc independante des armes par
--                   construction -- elle ne partage avec elles aucun type d'objet.
--
-- LES DEFAUTS NE CHANGENT RIEN. Portee absente ou vide : les deux volets a
-- true, sous_types a null. C'est exactement le comportement d'avant. Et aucune
-- loi n'existe en base -- assemblee_propositions est vide -- donc il n'y a
-- aucun effet retroactif a redouter.
--
-- CE QUI N'EST PAS TOUCHE. assemblee_loi_en_vigueur exigeait DEJA appliquee_ts :
-- la regle « adoptee n'est pas appliquee » est serveur depuis toujours, c'est le
-- navigateur qui ne la respectait pas. Rien a corriger ici.
--
-- Idempotente : CREATE OR REPLACE partout, UPDATE/INSERT ON CONFLICT pour les
-- donnees, DROP FUNCTION IF EXISTS pour la seule signature qui change.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. LES SOUS-TYPES QUE LE JEU CONNAIT REELLEMENT
--
-- Pour qu'un depute puisse choisir « seulement le militaire » ou « seulement le
-- civil », Seb Lex doit savoir quels sous-types EXISTENT. On ne les ecrit pas a
-- la main : on les DEDUIT des deux catalogues canoniques que la base detient
-- deja -- le catalogue des objets illegaux (armes civiles, poisons) et le
-- miroir des recettes militaires (chantier 4D). Une liste ecrite a la main
-- serait une source de verite de plus, et elle derivrait.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_sous_types_connus(p_type text)
 RETURNS text[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(array_agg(s ORDER BY s), '{}'::text[])
    FROM (
      SELECT i.objet ->> 'sousType' AS s
        FROM public.assemblee_catalogue_illegal i
       WHERE i.objet ->> 'type' = p_type AND i.objet ->> 'sousType' IS NOT NULL
      UNION
      SELECT r.sous_type
        FROM public.recettes_militaires r
       WHERE r.type_objet = p_type AND r.sous_type IS NOT NULL
    ) z;
$function$;

COMMENT ON FUNCTION public.assemblee_sous_types_connus(text) IS
  'Les sous-types reellement presents dans le jeu pour un type d''objet, deduits du '
  'catalogue des objets illegaux et du miroir des recettes militaires. Sert a proposer '
  'au deposant un choix qui existe. Chantier 4D.';

-- ---------------------------------------------------------------------------
-- 2. LES EXPLOSIFS SONT UNE CIBLE LEGISLATIVE DISTINCTE
--
-- explosif_militaire porte typeObjet 'explosif', et AUCUNE categorie ne visait
-- ce type : interdire les armes laissait circuler les explosifs, sans que
-- personne l'ait decide. La categorie ci-dessous le rend votable -- et, parce
-- qu'elle ne partage aucun type d'objet avec les armes, l'independance des deux
-- interdictions est structurelle, pas une regle a maintenir.
-- ---------------------------------------------------------------------------
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types)
VALUES ('explosifs', 'Explosifs', '{}', '{explosif}', '{}')
ON CONFLICT (categorie) DO UPDATE SET
  label = EXCLUDED.label, matieres = EXCLUDED.matieres,
  types_objet = EXCLUDED.types_objet, sous_types = EXCLUDED.sous_types;

-- ---------------------------------------------------------------------------
-- 3. LES MEDICAMENTS VISENT LES OBJETS QUI EXISTENT
--
-- La categorie visait le type d'objet 'medicament'. AUCUN objet de ce type
-- n'est cree nulle part dans le jeu, et aucun n'existe en base : les types
-- presents dans les inventaires sont equipement, soin, poison, arme. Les soins
-- produits sont 'soin'. Le volet « objets » de cette categorie ne pouvait donc
-- produire aucun effet.
--
-- L'arbitrage dit de NE PAS creer un type 'medicament' pour sauver une branche
-- morte, mais de laisser les deputes viser les objets de soin s'ils le veulent.
-- On corrige donc la cible, et le choix passe par volet_objets.
-- ---------------------------------------------------------------------------
UPDATE public.assemblee_categories_interdiction
   SET types_objet = '{soin}'
 WHERE categorie = 'medicaments';

-- ---------------------------------------------------------------------------
-- 4. LA PORTEE, DE UNE A QUATRE DIMENSIONS
--
-- La liste reste FERMEE, et c'est elle qui empeche Seb Lex de promettre un
-- effet que le moteur n'applique pas. Une cle inconnue est un refus, jamais un
-- silence.
--
-- sous_types = [] est REFUSE, pas interprete. Une liste vide voudrait dire
-- « restreindre a rien », ce qui annulerait silencieusement le volet objets :
-- exactement le genre de loi qui passe au vote et ne fait rien.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_portee_valider(p_portee jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_cle text; v_val jsonb; v_st jsonb;
BEGIN
  -- Absente ou vide : les defauts d'avant ce chantier. Le moins-disant sur la
  -- transformation, et aucune restriction sur ce que la categorie recouvre.
  IF p_portee IS NULL OR p_portee = 'null'::jsonb THEN
    RETURN jsonb_build_object('ok', true, 'portee',
             jsonb_build_object('transformation_stock_interdite', false,
                                'volet_matieres', true,
                                'volet_objets', true,
                                'sous_types', null));
  END IF;
  IF jsonb_typeof(p_portee) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_invalide');
  END IF;

  FOR v_cle IN SELECT jsonb_object_keys(p_portee) LOOP
    IF v_cle NOT IN ('transformation_stock_interdite', 'volet_matieres',
                     'volet_objets', 'sous_types') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'portee_cle_inconnue', 'cle', v_cle);
    END IF;
    v_val := p_portee -> v_cle;
    IF v_cle = 'sous_types' THEN
      IF jsonb_typeof(v_val) NOT IN ('array', 'null') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
      END IF;
      IF jsonb_typeof(v_val) = 'array' THEN
        IF jsonb_array_length(v_val) = 0 THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'portee_sous_types_vide');
        END IF;
        IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_val) e
                    WHERE jsonb_typeof(e) <> 'string') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
        END IF;
      END IF;
    ELSIF jsonb_typeof(v_val) <> 'boolean' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
    END IF;
  END LOOP;

  v_st := p_portee -> 'sous_types';
  RETURN jsonb_build_object('ok', true, 'portee', jsonb_build_object(
    'transformation_stock_interdite',
      coalesce((p_portee ->> 'transformation_stock_interdite')::boolean, false),
    'volet_matieres', coalesce((p_portee ->> 'volet_matieres')::boolean, true),
    'volet_objets',   coalesce((p_portee ->> 'volet_objets')::boolean, true),
    'sous_types',     CASE WHEN v_st IS NULL OR jsonb_typeof(v_st) = 'null'
                           THEN NULL ELSE v_st END));
END $function$;

-- ---------------------------------------------------------------------------
-- 5. LA GARDE DE LEGALITE LIT LA PORTEE
--
-- L'ancienne signature a DEUX parametres disparait : la garder en surcharge
-- aurait laisse vivre un appel qui ignore la portee, c'est-a-dire exactement le
-- comportement qu'on corrige. Son unique appelant, assemblee_loi_en_vigueur,
-- est mis a jour juste apres.
--
-- LA REGLE DES SOUS-TYPES, qui est la seule subtilite : la portee RESTREINT,
-- elle n'elargit jamais. Si la categorie borne deja ses sous-types et que la
-- portee en demande d'autres, c'est l'INTERSECTION qui vaut -- et si celle-ci
-- est vide, le volet objets ne vise rien. Une portee ne peut donc jamais faire
-- interdire plus que la categorie.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.assemblee_objet_vise(text, jsonb);

CREATE OR REPLACE FUNCTION public.assemblee_objet_vise(p_categorie text, p_objet jsonb, p_portee jsonb DEFAULT NULL)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH c AS (
    SELECT * FROM public.assemblee_categories_interdiction WHERE categorie = p_categorie
  ), p AS (
    SELECT coalesce((p_portee ->> 'volet_matieres')::boolean, true) AS vm,
           coalesce((p_portee ->> 'volet_objets')::boolean, true)   AS vo,
           CASE WHEN p_portee ? 'sous_types'
                 AND jsonb_typeof(p_portee -> 'sous_types') = 'array'
                THEN ARRAY(SELECT jsonb_array_elements_text(p_portee -> 'sous_types'))
           END AS st
  )
  SELECT EXISTS (
    SELECT 1 FROM c, p
     WHERE ( p.vm
             AND p_objet ->> 'stackKey' IS NOT NULL
             AND (p_objet ->> 'stackKey') = ANY (c.matieres) )
        OR ( p.vo
             AND p_objet ->> 'type' IS NOT NULL
             AND (p_objet ->> 'type') = ANY (c.types_objet)
             AND ( CASE
                     WHEN p.st IS NULL AND cardinality(c.sous_types) = 0 THEN true
                     ELSE (p_objet ->> 'sousType') = ANY (
                            CASE WHEN p.st IS NULL THEN c.sous_types
                                 WHEN cardinality(c.sous_types) = 0 THEN p.st
                                 ELSE ARRAY(SELECT unnest(c.sous_types)
                                            INTERSECT SELECT unnest(p.st))
                            END)
                   END ) )
  );
$function$;

COMMENT ON FUNCTION public.assemblee_objet_vise(text, jsonb, jsonb) IS
  'Un objet est-il vise par une categorie, COMPTE TENU de la portee votee ? La portee '
  'restreint, elle n''elargit jamais : volet_matieres, volet_objets et sous_types ne font '
  'que retrancher a ce que la categorie recouvre. Chantier 4D.';

CREATE OR REPLACE FUNCTION public.assemblee_loi_en_vigueur(p_country text, p_objet jsonb, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
           'id', p.id, 'titre', p.titre, 'categorie', p.categorie,
           'adoptee_ts', p.adoptee_ts, 'appliquee_ts', p.appliquee_ts,
           'portee', coalesce(p.data -> 'portee', '{}'::jsonb))
    FROM public.assemblee_propositions p
   WHERE p.country = p_country
     AND p.type = 'mecanique'
     AND p.statut = 'adoptee'
     AND p.adoptee_ts IS NOT NULL
     AND p.adoptee_ts <= p_instant
     AND p.appliquee_ts IS NOT NULL
     AND p.appliquee_ts <= p_instant
     AND public.assemblee_objet_vise(p.categorie, p_objet,
                                     coalesce(p.data -> 'portee', '{}'::jsonb))
   ORDER BY p.appliquee_ts, p.adoptee_ts, p.id
   LIMIT 1;
$function$;

-- ---------------------------------------------------------------------------
-- 6. LE CATALOGUE DIT CE QUI EST CHOISISSABLE
--
-- Seb Lex ne peut proposer un choix que s'il sait qu'il existe. Deux champs
-- nouveaux par categorie : choix_volets (la categorie vise-t-elle A LA FOIS des
-- matieres et des objets ? sinon la question n'a pas de sens) et
-- sous_types_disponibles (ce parmi quoi le deposant peut restreindre).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_catalogue_legislatif()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
    'categories', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'categorie', c.categorie,
               'label', c.label,
               'matieres', coalesce(to_jsonb(c.matieres), '[]'::jsonb),
               'types_objet', coalesce(to_jsonb(c.types_objet), '[]'::jsonb),
               'sous_types', coalesce(to_jsonb(c.sous_types), '[]'::jsonb),
               'choix_volets', (cardinality(c.matieres) > 0 AND cardinality(c.types_objet) > 0),
               'sous_types_disponibles', coalesce((
                  SELECT to_jsonb(array_agg(DISTINCT s ORDER BY s))
                    FROM unnest(c.types_objet) t,
                         unnest(public.assemblee_sous_types_connus(t)) s
                    WHERE cardinality(c.sous_types) = 0 OR s = ANY (c.sous_types)
                 ), '[]'::jsonb),
               'transformation_pertinente', EXISTS (
                 SELECT 1 FROM unnest(c.matieres) m
                  WHERE (public.matiere_circuits_disponibles(m) ->> 'transformation')::boolean),
               'production_pertinente', EXISTS (
                 SELECT 1 FROM unnest(c.matieres) m
                  WHERE (public.matiere_circuits_disponibles(m) ->> 'production_usine')::boolean
                     OR (public.matiere_circuits_disponibles(m) ->> 'recolte')::boolean)
             ) ORDER BY c.label)
        FROM public.assemblee_categories_interdiction c), '[]'::jsonb),
    'matieres', coalesce((
      SELECT jsonb_agg(public.matiere_circuits_disponibles(r.cle) ORDER BY r.cle)
        FROM public.ressources_economie r), '[]'::jsonb),
    'portee_dimensions', jsonb_build_array('transformation_stock_interdite',
                                           'volet_matieres', 'volet_objets', 'sous_types')
  );
$function$;
