-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913232051
-- Nom original      : chantier_c_imprimerie_produire_tracts
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 23:20:51 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 841caced25752f9005b479cb94c1b959
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
-- CHANTIER C — PRODUCTION DE LOTS DE TRACTS (14 septembre 2026).
--
-- Ordre REFUSE en production depuis la phase 1 des qu'on commande plus d'UN lot : l'ordre
-- imprimer_tracts_* declare (1 PA, 150 FR), le client envoie (N PA, 150N FR). Verifie
-- empiriquement : 3 lots -> 'cout_non_declare'. Un seul lot passait.
--
-- Le bois et la caisse de l'imprimerie etaient deja atomiques (batiment_caisse_mouvement) ; le
-- debit du client, lui, passait par payer_ordre avec un montant multiplie, et le salaire du
-- producteur etait credite par le navigateur. Tout est reuni ici, dans une seule transaction.
--
-- Regles recopiees telles quelles : 1 lot = 10 tracts, 150 FR payes par le commanditaire,
-- 1 bois pris au stock de l'atelier, 1 PA de travail, 50 FR de salaire verses au producteur.
-- La caisse de l'imprimerie encaisse la recette nette du salaire.
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES
  ('prix_lot_tracts', 150), ('bois_par_lot_tracts', 1), ('salaire_lot_tracts', 50),
  ('pa_par_lot_tracts', 1)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

CREATE OR REPLACE FUNCTION public.imprimerie_produire_tracts(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_lots integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id text; v_data jsonb; v_imp jsonb; v_bois numeric; v_caisse numeric;
  v_prix numeric; v_boisLot numeric; v_salaireLot numeric; v_paLot numeric;
  v_cout numeric; v_salaire numeric; v_boisTotal numeric; v_paRequis integer;
  v_pa integer; v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_lots, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lots_invalides');
  END IF;

  SELECT valeur INTO v_prix       FROM public.entreprises_constantes WHERE cle = 'prix_lot_tracts';
  SELECT valeur INTO v_boisLot    FROM public.entreprises_constantes WHERE cle = 'bois_par_lot_tracts';
  SELECT valeur INTO v_salaireLot FROM public.entreprises_constantes WHERE cle = 'salaire_lot_tracts';
  SELECT valeur INTO v_paLot      FROM public.entreprises_constantes WHERE cle = 'pa_par_lot_tracts';
  IF v_prix IS NULL OR v_boisLot IS NULL OR v_salaireLot IS NULL OR v_paLot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tarif_indisponible');
  END IF;

  v_cout      := p_lots * v_prix;
  v_salaire   := p_lots * v_salaireLot;
  v_boisTotal := p_lots * v_boisLot;
  v_paRequis  := (p_lots * v_paLot)::integer;

  v_id := p_pays || '_' || p_ville || '_' || p_batiment;
  SELECT public.batiment_etat_lire(data) INTO v_data
    FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_absent'); END IF;
  v_imp := COALESCE(v_data->'imprimerie', '{}'::jsonb);

  v_bois := GREATEST(0, COALESCE((v_imp->>'stockBois')::numeric, 0));
  IF v_bois < v_boisTotal THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bois_insuffisant',
                              'stock', v_bois, 'requis', v_boisTotal);
  END IF;

  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0)
    INTO v_pa, v_arg, v_liquide
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < v_paRequis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_paRequis, 'pa_reel', v_pa);
  END IF;

  -- Le commanditaire paie. helvetia_debiter_fonds_ordinaires applique la regle existante :
  -- liquide d'abord, complete par la Banque nationale, jamais de debit partiel.
  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_cout) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'cout', v_cout);
  END IF;

  -- Atelier : le bois sort, la caisse encaisse la recette NETTE du salaire. Une seule ecriture.
  v_caisse := GREATEST(0, COALESCE((v_imp->>'caisse')::numeric, 0));
  v_imp := v_imp || jsonb_build_object('stockBois', v_bois - v_boisTotal,
                                       'caisse', v_caisse + (v_cout - v_salaire));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_data || jsonb_build_object('imprimerie', v_imp))::text),
         updated_at = now()
   WHERE id = v_id;

  -- PA du producteur et salaire, dans la meme transaction que tout le reste.
  UPDATE public.personnages_donnees
     SET pa = pa - v_paRequis, arg = arg + v_salaire, liquide = liquide + v_salaire,
         updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'lots', p_lots, 'cout', v_cout, 'salaire', v_salaire,
    'bois', v_boisTotal, 'paConsommes', v_paRequis,
    'stockBois', v_bois - v_boisTotal, 'caisseAtelier', v_caisse + (v_cout - v_salaire),
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $$;

REVOKE EXECUTE ON FUNCTION public.imprimerie_produire_tracts(text,text,text,text,integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.imprimerie_produire_tracts(text,text,text,text,integer)
  TO authenticated, service_role;
