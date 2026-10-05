-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913232445
-- Nom original      : chantier_c_banque_nationale_mouvement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:24:45 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e467006462b392467423900f6d2c5a9f
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
-- CHANTIER C — BANQUE NATIONALE : DEPOT ET RETRAIT (14 septembre 2026).
--
-- C'etait le dernier compte du jeu encore pilote par une ecriture cliente. Le navigateur
-- deplacait l'argent entre liquide et compte national dans son propre etat, puis persistait les
-- deux cotes SEPAREMENT : sauvegarderPersonnageImmediat pour le liquide, sbMajCompteBancaire en
-- fire-and-forget pour le solde -- deux tables, aucune transaction croisee. Un echec du second
-- appel creait ou detruisait de l'argent, et personne n'en etait informe.
-- Pire, sbMajCompteBancaire ecrit un SOLDE ABSOLU sans aucun controle d'identite : n'importe
-- quel compte pouvait s'y attribuer la somme de son choix.
--
-- Helvetia avait deja ses RPC atomiques ; la Banque nationale n'avait rien. La voici.
-- Un depot/retrait ne cree ni ne detruit de valeur : 'arg' (fortune totale) ne bouge pas, seule
-- la repartition entre les poches change. C'est la regle existante, conservee telle quelle.
CREATE OR REPLACE FUNCTION public.banque_nationale_mouvement(
  p_acteur text, p_sens text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_liquide numeric; v_arg numeric; v_compte_id text; v_solde numeric; v_pays text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_sens NOT IN ('depot', 'retrait') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant)
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  -- Ordre de verrou fixe : personnage puis compte. Deux operations simultanees se serialisent.
  SELECT COALESCE(liquide,0), COALESCE(arg,0), country
    INTO v_liquide, v_arg, v_pays
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_liquide IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, COALESCE(solde,0) INTO v_compte_id, v_solde
    FROM public.comptes_bancaires
   WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;

  IF p_sens = 'depot' THEN
    IF v_liquide < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'liquide_insuffisant', 'liquide', v_liquide);
    END IF;
    IF v_compte_id IS NULL THEN
      -- Premier depot d'un personnage sans compte : la ligne est creee ici, sous verrou,
      -- plutot que par une ecriture cliente separee.
      v_compte_id := 'nationale_' || p_acteur;
      INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde, updated_at)
      VALUES (v_compte_id, p_acteur, COALESCE(v_pays,'republic'), 'nationale', 0, now())
      ON CONFLICT (id) DO NOTHING;
      SELECT COALESCE(solde,0) INTO v_solde FROM public.comptes_bancaires WHERE id = v_compte_id;
    END IF;
    UPDATE public.personnages_donnees SET liquide = v_liquide - p_montant, updated_at = now()
     WHERE name = p_acteur;
    UPDATE public.comptes_bancaires SET solde = v_solde + p_montant, updated_at = now()
     WHERE id = v_compte_id;
    v_liquide := v_liquide - p_montant; v_solde := v_solde + p_montant;

  ELSE
    IF v_compte_id IS NULL OR v_solde < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant',
                                'solde', COALESCE(v_solde, 0));
    END IF;
    UPDATE public.comptes_bancaires SET solde = v_solde - p_montant, updated_at = now()
     WHERE id = v_compte_id;
    UPDATE public.personnages_donnees SET liquide = v_liquide + p_montant, updated_at = now()
     WHERE name = p_acteur;
    v_liquide := v_liquide + p_montant; v_solde := v_solde - p_montant;
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'montant', p_montant,
    'liquide', v_liquide, 'solde', v_solde, 'arg', v_arg, 'compte', v_compte_id);
END; $$;

REVOKE EXECUTE ON FUNCTION public.banque_nationale_mouvement(text,text,numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.banque_nationale_mouvement(text,text,numeric)
  TO authenticated, service_role;
