-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913232620
-- Nom original      : chantier_c_fermeture_comptes_bancaires
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 23:26:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5618d5e19353fc3e9458be93083e7b4d
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
-- CHANTIER C — FERMETURE DE `comptes_bancaires` (14 septembre 2026).
--
-- sbMajCompteBancaire ecrivait un SOLDE ABSOLU sur n'importe quelle ligne, sans le moindre
-- controle d'identite : le dernier endroit du jeu ou un navigateur pouvait s'attribuer la somme
-- de son choix. Ses deux appelants (depot/retrait et la primitive de debit) passent desormais
-- par des RPC verrouillees, et n'ecrivent plus rien.
--
-- La creation du compte initial etait elle aussi une ecriture cliente, avec un solde calcule
-- dans le navigateur. Elle devient une RPC qui relit la fortune reellement enregistree sur le
-- personnage : le solde bancaire de depart est ce qui n'est pas en liquide, rien d'autre.
CREATE OR REPLACE FUNCTION public.compte_bancaire_initial(p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_arg numeric; v_liquide numeric; v_pays text; v_id text; v_solde numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT COALESCE(arg,0), COALESCE(liquide,0), country
    INTO v_arg, v_liquide, v_pays
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_arg IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_id := 'nationale_' || p_acteur;
  IF EXISTS (SELECT 1 FROM public.comptes_bancaires WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_cree', true, 'compte', v_id);
  END IF;

  -- Le solde de depart est la part NON liquide de la fortune reellement enregistree. Il n'est
  -- pas transmis : il se deduit de la ligne du personnage, deja ecrite.
  v_solde := GREATEST(0, v_arg - v_liquide);
  INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde, updated_at)
  VALUES (v_id, p_acteur, COALESCE(v_pays,'republic'), 'nationale', v_solde, now())
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'compte', v_id, 'solde', v_solde);
END; $$;

REVOKE EXECUTE ON FUNCTION public.compte_bancaire_initial(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.compte_bancaire_initial(text) TO authenticated, service_role;

ALTER TABLE public.comptes_bancaires ENABLE ROW LEVEL SECURITY;
DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT polname FROM pg_policy JOIN pg_class c ON c.oid = polrelid
            WHERE c.relname = 'comptes_bancaires'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.comptes_bancaires', p.polname);
  END LOOP;
END $$;
-- La lecture reste ouverte : le masquage des donnees privees se joue sur la vue personnages,
-- et un solde bancaire n'est lu que par son titulaire dans l'interface.
CREATE POLICY "comptes_bancaires lecture" ON public.comptes_bancaires FOR SELECT USING (true);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.comptes_bancaires FROM anon, authenticated;
GRANT SELECT ON public.comptes_bancaires TO anon, authenticated;
