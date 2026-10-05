-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916141135
-- Nom original      : subvention_ministerielle_transaction_atomique
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 14:11:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3b1fea0678176495aee838b44b0b7a16
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
-- LA SUBVENTION DU MINISTRE DES FINANCES DEVIENT UNE SEULE TRANSACTION (16 septembre 2026).
--
-- LE DEFAUT. La subvention se faisait en deux temps, cote navigateur :
--   1. debiterCaisseBatimentPlafonne() retire l'argent de la caisse du gouvernement -- et ca,
--      ca marche, c'est une RPC serveur ;
--   2. le beneficiaire est credite par une ecriture directe sur SA fiche.
-- Depuis le chantier B, la vue personnages refuse d'ecrire la fiche d'autrui
-- (personnage_non_possede). L'argent quittait donc la caisse publique sans jamais arriver.
--
-- Un second defaut, plus discret, se cachait dans le meme chemin : le montant credite etait
-- calcule comme « solde relu + montant ». Or la fortune d'autrui n'est pas lisible non plus
-- depuis le chantier B -- la lecture renvoyait 0. Si l'ecriture etait passee, elle aurait REMIS
-- LA FORTUNE DU BENEFICIAIRE A 500 FR au lieu de l'augmenter. Le refus nous a protege d'une
-- destruction de donnees. Ici, on incremente : on ne relit plus pour reecrire.
--
-- LA REGLE, retrouvee dans le code et NON MODIFIEE : montant libre choisi par le ministre,
-- plafond 5000, preleve sur la caisse <pays>_gouvernement-min_fin, versement PARTIEL tolere si
-- la caisse ne suit pas (comportement volontaire et ancien), 2 PA a la charge du ministre --
-- debites par le client avant l'appel, comme aujourd'hui. Aucun cooldown n'existe, et ce lot
-- n'en invente pas.
--
-- CE QUE LE SERVEUR ATTESTE LUI-MEME : l'identite de l'acteur et son poste min_fin reel (via
-- exiger_poste, qui lit le poste ATTESTE de la fiche), le pays, la caisse competente,
-- l'existence du beneficiaire, et le montant. L'appelant ne designe qu'un beneficiaire et un
-- montant demande -- il ne choisit ni la caisse, ni ce qui est reellement verse.
--
-- ATOMICITE : debit et credit vivent dans la meme fonction, donc la meme transaction. Soit les
-- deux, soit aucun -- une exception a n'importe quelle etape annule l'ensemble.
--
-- PERIMETRE : uniquement le beneficiaire de type CITOYEN, le seul casse. Les subventions a un
-- club, une entreprise ou une organisation passent par d'autres chemins qui fonctionnent, et ne
-- sont pas touchees. caisse_institution_mouvement n'est pas refondue : elle est reutilisee.

CREATE OR REPLACE FUNCTION public.subvention_citoyen_verser(p_beneficiaire text, p_montant integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_acteur text; v_pays text; v_caisse text; v_data jsonb;
  v_solde numeric; v_verse numeric; v_arg numeric;
BEGIN
  -- 1. AUTORITE. exiger_poste leve si le compte n'a pas de personnage ou n'est pas min_fin.
  v_acteur := public.exiger_poste('min_fin');
  IF v_acteur IS NULL THEN            -- appel serveur (cron) : pas de subvention automatique
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;
  IF coalesce(v_pays, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_indetermine');
  END IF;

  -- 2. MONTANT. Memes bornes que le formulaire : au moins 1, au plus 5000.
  IF p_montant IS NULL OR p_montant < 1 OR p_montant > 5000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  -- 3. BENEFICIAIRE. Il doit exister. La ligne est verrouillee avant tout mouvement.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable');
  END IF;

  -- 4. CAISSE. Verrouillee elle aussi : le solde lu est celui qu'on debite.
  v_caisse := v_pays || '_gouvernement-min_fin';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number'
                  THEN (v_data->>'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);   -- versement partiel tolere, comme avant
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;

  -- 5. LES DEUX MOUVEMENTS, ENSEMBLE.
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = v_caisse;

  -- INCREMENT, jamais « solde relu + montant » : c'est ce calcul qui aurait ecrase la fortune.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_verse
   WHERE name = p_beneficiaire;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'beneficiaire', p_beneficiaire,
                            'acteur', v_acteur, 'caisse', v_caisse);
END; $$;

REVOKE ALL ON FUNCTION public.subvention_citoyen_verser(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.subvention_citoyen_verser(text, integer) TO authenticated;