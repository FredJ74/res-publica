-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917223518
-- Nom original      : militaire_accessoires_et_dotation
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 22:35:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5fab38d48c26198275825b75b3dbda5c
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ==========================================================================================
-- ACCESSOIRES MILITAIRES : retrait d'armurerie et DOTATION INITIALE des casernes
--
-- caserne_stock_mouvement est deja ENTIEREMENT GENERIQUE (aucune liste blanche de produit) :
-- rien a y changer. Seul militaire_retrait filtrait les produits -- la liste s'etend aux cinq
-- accessoires, avec leur forme d'objet, miroir de RECETTES_MILITAIRES (plateau-effort-guerre.js).
--
-- imageUrl reste NULL : une planche d'accessoires a ete produite mais son nom de fichier
-- canonique n'est pas connu du depot. Aucun nom n'est invente -- voir le rapport.
-- ==========================================================================================
CREATE OR REPLACE FUNCTION public.militaire_retrait(
  p_pays text, p_produit text, p_quantite integer, p_lieutenant text, p_section text, p_jour integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_plafond constant integer := 100;
  v_pj public.personnages%ROWTYPE;
  v_mvt jsonb; v_lot jsonb; v_inv jsonb; v_occupe numeric; v_poses integer := 0;
  v_label text; v_type text; v_soustype text; v_icon text; v_img text; v_desc text; v_trouve boolean;
BEGIN
  PERFORM public.exiger_acteur(p_lieutenant);
  IF COALESCE(p_quantite, 0) <= 0 OR p_quantite > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- Forme de l'objet, miroir de RECETTES_MILITAIRES. La liste EST la liste blanche : un produit
  -- absent d'ici est refuse, donc il n'existe pas deux listes a tenir a jour.
  SELECT true, r.label, r.t, r.st, r.ic, r.im, r.de
    INTO v_trouve, v_label, v_type, v_soustype, v_icon, v_img, v_desc
    FROM (VALUES
      ('arme_de_poing', 'Pistolet militaire', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png',
       'Arme de poing réglementaire de l''armée de Républia.'),
      ('mitraillette', 'Mitraillette', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png',
       'Arme automatique réglementaire de l''armée de Républia.'),
      ('explosif_militaire', 'Explosifs militaires', 'explosif', 'militaire', 'ti-bomb',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-militaires.png',
       'Explosifs réglementaires de l''armée de Républia.'),
      ('gilet_pare_balles', 'Gilet pare-balles', 'equipement', 'militaire', 'ti-shield-check', NULL,
       'Gilet pare-balles réglementaire. Protège contre les attaques pertinentes, notamment les tirs.'),
      ('radio', 'Radio de campagne', 'equipement', 'militaire', 'ti-radio', NULL,
       'Poste radio de campagne. Relais de commandement : permet de transmettre des ordres à distance.'),
      ('tente', 'Tente de campagne', 'equipement', 'militaire', 'ti-tent', NULL,
       'Tente de campagne. Abrite 13 personnes en bivouac. Aucun montage à ordonner.'),
      ('jumelles', 'Jumelles', 'equipement', 'militaire', 'ti-binoculars', NULL,
       'Jumelles d''observation. Renseignement toujours approximatif.'),
      ('tenue_camouflage', 'Tenue de camouflage', 'equipement', 'militaire', 'ti-eye-off', NULL,
       'Tenue de camouflage. Protège CELUI QUI LA PORTE.')
    ) AS r(p, label, t, st, ic, im, de) WHERE r.p = p_produit;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide', 'produit', p_produit);
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_lieutenant FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF COALESCE(v_pj.poste ->> 'id', '') <> 'lieutenant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_section');
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_pj.inventory) = 'array' THEN v_pj.inventory ELSE '[]'::jsonb END;
  SELECT coalesce(sum(greatest(1,
           coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
    INTO v_occupe FROM jsonb_array_elements(v_inv) i;
  IF v_occupe + p_quantite > c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein',
                              'occupe', v_occupe, 'plafond', c_plafond, 'demande', p_quantite);
  END IF;

  v_mvt := public.caserne_stock_mouvement(p_pays, p_produit, -p_quantite, NULL);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;

  FOR v_lot IN SELECT value FROM jsonb_array_elements(COALESCE(v_mvt -> 'lots', '[]'::jsonb)) LOOP
    INSERT INTO public.retraits_materiel_militaire
      (pays, materiel, lot, quantite, lieutenant, section, jour)
    VALUES (p_pays, p_produit, v_lot ->> 'lot', (v_lot ->> 'qte')::integer, p_lieutenant, p_section, p_jour);

    FOR i IN 1 .. greatest(0, coalesce((v_lot ->> 'qte')::integer, 0)) LOOP
      v_inv := v_inv || jsonb_build_array(jsonb_build_object(
        'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
        'type', v_type, 'sousType', v_soustype,
        'origineMilitaire', true, 'lot', coalesce(v_lot ->> 'lot', 'legacy'),
        'produitMilitaire', p_produit,
        'name', v_label, 'icon', v_icon, 'legal', true, 'imageUrl', v_img,
        'desc', v_desc || ' Lot ' || coalesce(v_lot ->> 'lot', 'legacy') || '.'));
      v_poses := v_poses + 1;
    END LOOP;
  END LOOP;

  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_lieutenant;
  RETURN v_mvt || jsonb_build_object('registre', true, 'objets_poses', v_poses,
                                     'inventaire_serveur', true);
END;
$fn$;
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) TO authenticated, service_role;

-- ---- DOTATION INITIALE DES CASERNES, une seule fois, sans regeneration ----
-- 2 radios, 1 tente, 3 gilets, 1 paire de jumelles, 1 tenue de camouflage par caserne.
-- GARDE D'IDEMPOTENCE : la dotation n'est posee que si la cle du produit est ABSENTE du stock.
-- Un rejeu de cette migration ne double donc rien, et aucune regeneration automatique n'existe.
DO $$
DECLARE v_pays text; v_prod text; v_qte integer; v_stock jsonb;
BEGIN
  FOREACH v_pays IN ARRAY ARRAY['republic','narco','soviet','khalija'] LOOP
    SELECT CASE WHEN jsonb_typeof(data -> 'stockArmurerieMilitaire') = 'object'
                THEN data -> 'stockArmurerieMilitaire' ELSE '{}'::jsonb END
      INTO v_stock FROM public.budgets_nationaux WHERE id = v_pays;
    CONTINUE WHEN v_stock IS NULL;
    FOR v_prod, v_qte IN SELECT * FROM (VALUES
        ('radio', 2), ('tente', 1), ('gilet_pare_balles', 3),
        ('jumelles', 1), ('tenue_camouflage', 1)) AS d(p, q) LOOP
      IF NOT (v_stock ? v_prod) THEN
        PERFORM public.caserne_stock_mouvement(v_pays, v_prod, v_qte, 'dotation-initiale');
      END IF;
    END LOOP;
  END LOOP;
END $$;