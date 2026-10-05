-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917200844
-- Nom original      : redressement_fiscal_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 20:08:44 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a7cf3992d2d228356bc967969f9fdd0b
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
CREATE OR REPLACE FUNCTION public.redressement_fiscal_appliquer(
  p_type text, p_cible text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  -- Miroir EXACT du litteral client (const montantVise = 2000, plateau-politique.js).
  -- Aucun montant nouveau : c'est la valeur deja en vigueur, deplacee hors de portee du navigateur.
  c_montant constant numeric := 2000;
  v_acteur text; v_pays text;
  v_solde numeric; v_pris numeric;
  v_txt text; v_json jsonb; v_nat jsonb;
BEGIN
  -- Autorite : exactement le requiresPost declare sur l'ordre porteur (pilotage_fiscal_budgetaire,
  -- requiresPost:'min_fin'). Le client ne le verifiait qu'a l'OUVERTURE du panneau ; la fonction
  -- d'execution, appelable depuis un onclick, ne le revefifiait pas du tout.
  v_acteur := public.exiger_poste('min_fin');
  IF v_acteur IS NULL THEN v_acteur := public.mon_personnage(); END IF;
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  IF p_type = 'club_sportif' THEN
    SELECT coalesce((data->>'caisse')::numeric, 0) INTO v_solde
      FROM public.budgets_clubs WHERE id = p_cible FOR UPDATE;
    IF v_solde IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    v_pris := least(v_solde, c_montant);
    IF v_pris <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'solde', v_solde);
    END IF;
    UPDATE public.budgets_clubs
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{caisse}', to_jsonb(v_solde - v_pris))
     WHERE id = p_cible;

  ELSIF p_type = 'organisation' THEN
    -- organisations.data est une colonne TEXTE : on parse, on modifie la seule cle caisse, on
    -- reserialise -- le tout sous FOR UPDATE, ce qui supprime la course perdante du chemin client.
    SELECT data INTO v_txt FROM public.organisations WHERE id = p_cible FOR UPDATE;
    IF v_txt IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    BEGIN
      v_json := v_txt::jsonb;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'donnee_illisible');
    END;
    v_solde := coalesce((v_json->>'caisse')::numeric, 0);
    v_pris := least(v_solde, c_montant);
    IF v_pris <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'solde', v_solde);
    END IF;
    UPDATE public.organisations
       SET data = (jsonb_set(v_json, '{caisse}', to_jsonb(v_solde - v_pris)))::text
     WHERE id = p_cible;

  ELSE
    -- 'entreprise' possede deja sa primitive attestee (entreprise_mouvement_fiscal).
    -- 'citoyen' : le prelevement sur la fiche d'un tiers n'a jamais fonctionne (colonne arg
    -- masquee par la vue, ecriture refusee par le trigger). L'activer serait un choix de game
    -- design, pas un correctif : cette RPC ne le fait pas.
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert', 'type', p_type);
  END IF;

  -- Versement au Tresor : meme table, meme sous-cle que la fiscalite ordinaire
  -- (budgets_nationaux.data.reserveJour, celle qu'alimente deja appliquer_taxe_transaction),
  -- mais par jsonb_set sous verrou au lieu d'une reecriture du blob entier par le navigateur.
  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_nat IS NULL THEN
    RAISE EXCEPTION 'redressement_fiscal: budget national % absent', v_pays;
  END IF;
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(v_nat, '{reserveJour}',
           to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0) + v_pris)),
         updated_at = now()
   WHERE id = v_pays;

  RETURN jsonb_build_object('ok', true, 'montant', v_pris, 'solde_restant', v_solde - v_pris,
                            'pays', v_pays);
END;
$fn$;

REVOKE ALL ON FUNCTION public.redressement_fiscal_appliquer(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.redressement_fiscal_appliquer(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.redressement_fiscal_appliquer(text, text) TO authenticated, service_role;