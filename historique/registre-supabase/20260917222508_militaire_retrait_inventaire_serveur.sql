-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917222508
-- Nom original      : militaire_retrait_inventaire_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 22:25:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f21bd4be17b32aaa60162e0abe046000
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
-- militaire_retrait : LES OBJETS ENTRENT DANS L'INVENTAIRE COTE SERVEUR
--
-- CE QUI SE PASSAIT. La RPC debitait le stock de l'armurerie et inscrivait le registre, mais ne
-- creditait aucun inventaire. C'est le CLIENT qui fabriquait ensuite les objets
-- (poserObjetMilitaire -> addToInventory -> sbSavePersonnage) et republiait tout le blob
-- inventory. L'objet arrivait donc bien dans l'inventaire du Lieutenant -- mais son EXISTENCE
-- etait decidee par le navigateur : un client modifie pouvait retirer une unite et s'en ajouter
-- cent, ou s'ajouter des objets sans aucun retrait.
--
-- DESORMAIS la RPC ecrit elle-meme les objets dans personnages_donnees.inventory, dans la MEME
-- transaction que le debit du stock et l'inscription au registre. La regle du GD -- « l'objet
-- entre dans son inventaire personnel », « ne jamais simplement supprimer l'objet » -- est donc
-- tenue par le serveur et non plus par la bonne volonte du client.
--
-- C'est le motif deja employe par les RPC d'achat du jeu (acheter_a_entrepot,
-- acheter_produit_manufacture, acheter_vente_directe_usine...) : elles ecrivent inventory cote
-- serveur. Aucun systeme parallele.
--
-- LA FORME DE L'OBJET est recopiee de RECETTES_MILITAIRES (plateau-effort-guerre.js), sans rien
-- inventer : type / sousType / label / icon / imageUrl / desc identiques, et les cles
-- origineMilitaire, lot et produitMilitaire qui voyagent avec l'objet -- donc survivent au don,
-- au depot, au ramassage et au vol.
--
-- LE PLAFOND D'INVENTAIRE (100) est applique : un retrait qui ne tient pas est refuse AVANT tout
-- debit de stock, plutot que de faire disparaitre du materiel.
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
  v_label text; v_type text; v_soustype text; v_icon text; v_img text; v_desc text;
BEGIN
  PERFORM public.exiger_acteur(p_lieutenant);
  IF COALESCE(p_quantite, 0) <= 0 OR p_quantite > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette', 'explosif_militaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_lieutenant FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF COALESCE(v_pj.poste ->> 'id', '') <> 'lieutenant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_section');
  END IF;

  -- Miroir de RECETTES_MILITAIRES : aucune valeur nouvelle.
  SELECT r.label, r.t, r.st, r.ic, r.im, r.de INTO v_label, v_type, v_soustype, v_icon, v_img, v_desc
    FROM (VALUES
      ('arme_de_poing', 'Pistolet militaire', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png',
       'Arme de poing réglementaire de l''armée de Républia.'),
      ('mitraillette', 'Mitraillette', 'arme', 'militaire', 'ti-crosshair',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png',
       'Arme automatique réglementaire de l''armée de Républia.'),
      ('explosif_militaire', 'Explosifs militaires', 'explosif', 'militaire', 'ti-bomb',
       'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-militaires.png',
       'Explosifs réglementaires de l''armée de Républia.')
    ) AS r(p, label, t, st, ic, im, de) WHERE r.p = p_produit;

  -- PLAFOND VERIFIE AVANT TOUT DEBIT : un materiel qui ne tiendrait pas dans l'inventaire ne doit
  -- pas quitter l'armurerie pour se volatiliser.
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

    -- Un objet REEL par unite retiree, cote serveur. Le lot voyage avec l'objet.
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