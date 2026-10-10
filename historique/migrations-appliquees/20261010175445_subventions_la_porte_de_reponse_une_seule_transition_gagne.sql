-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010175445 (UTC), nom `subventions_la_porte_de_reponse_une_seule_transition_gagne`.
-- Le registre passe de 628 a 629 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4f4072bc6f943d5798ee0815df2066a4, 9223 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, §3 ET §4 -- LA PORTE DE REPONSE, UNE SEULE TRANSITION GAGNE
--
-- « La premiere decision valide est definitive » : c'est un compare-and-swap et rien d'autre --
-- l'UPDATE porte `WHERE statut = 'proposee'` dans sa propre clause, et non un « verifier puis
-- ecrire » par lequel deux acceptations passeraient. L'ordre des verrous (caisse PUIS proposition)
-- est le meme que dans la porte de proposition, exprès : l'inverse ferait tuer un des deux appels
-- par interblocage. Le client choisit un VERBE, jamais un statut, donc ne peut pas ecrire
-- 'expiree'. Une proposition echue est close au passage pour liberer la reserve si la passe de
-- minuit a manque -- cela s'est produit le 8 octobre. Le laissez-passer de caisse est ouvert puis
-- REFERME aussitot : `set_config(..., true)` vaut pour toute la transaction.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, §3 et §4 -- LA PORTE DE REPONSE (10 octobre 2026)
--
-- « La premiere decision valide est definitive : si plusieurs dirigeants habilites agissent en
-- meme temps, une seule reponse peut gagner. » C'est un compare-and-swap, et rien d'autre :
-- l'UPDATE porte `WHERE statut = 'proposee'` dans sa propre clause. Le second appel ne trouve
-- plus la condition, modifie zero ligne, et apprend qu'il a perdu la course. Il n'y a pas de
-- « verifier puis ecrire » -- ce serait precisement la fenetre par laquelle deux acceptations
-- passeraient.
--
-- L'ORDRE DES VERROUS EST LE MEME QUE DANS LA PORTE DE PROPOSITION, ET CE N'EST PAS UN DETAIL.
-- `subvention_proposer` verrouille la CAISSE puis ecrit la proposition. Si cette porte faisait
-- l'inverse -- proposition puis caisse -- deux appels simultanes s'attendraient mutuellement et
-- PostgreSQL tuerait l'un des deux par interblocage. La proposition est donc lue SANS verrou
-- d'abord, juste pour savoir quelle caisse verrouiller ; le verrou de la caisse vient ensuite ;
-- la proposition n'est relue sous verrou qu'apres. L'atomicite ne repose de toute facon pas sur
-- cette relecture mais sur le compare-and-swap final.
--
-- QUI PEUT REPONDRE, ET D'OU VIENT LA REGLE. Elle n'a pas ete inventee : pour un club du
-- championnat, l'autorite sur la caisse est deja le PRESIDENT partout dans le jeu. Le motif de
-- refus reutilise le nom que le jeu emploie deja -- `pas_gestionnaire_caisse`.
--
-- L'EXPIRATION SE CONSTATE PAR TOUS LES CHEMINS, et c'est volontaire. Si la passe de minuit
-- manque une nuit -- cela s'est produit le 8 octobre 2026 -- une proposition echue resterait
-- `proposee` et immobiliserait de l'argent indefiniment. Cette porte cloture donc elle-meme une
-- proposition dont l'echeance est passee, au lieu de se contenter de la refuser : la reserve est
-- liberee a la premiere occasion, par qui que ce soit. L'operation est idempotente.
--
-- LE DELAI, SANS AMBIGUITE : proposee au jour J, l'echeance est J+3. Elle est repondable les
-- jours J, J+1 et J+2 -- trois journees -- et expiree des que le jour de jeu atteint J+3.

CREATE OR REPLACE FUNCTION public.subvention_repondre(p_id text, p_reponse text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_moi text; r record; v_caisse text; v_jour integer; v_gest text;
  v_statut text; v_mvt jsonb; v_solde_orga numeric; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- LISTE CLOSE. Le client ne nomme pas le statut qu'il veut ecrire : il choisit un verbe parmi
  -- deux, et le serveur en deduit le statut. Un client modifie ne peut donc pas ecrire 'expiree'
  -- ni inventer une issue.
  IF p_reponse NOT IN ('accepter', 'refuser') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_invalide',
                              'attendu', jsonb_build_array('accepter', 'refuser')); END IF;
  v_statut := CASE p_reponse WHEN 'accepter' THEN 'acceptee' ELSE 'refusee' END;

  SELECT * INTO r FROM public.subventions_municipales WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_introuvable'); END IF;

  -- VERROU 1 : LA CAISSE, dans le meme ordre que la porte de proposition.
  v_caisse := r.pays || '_subventions_' || r.ville;
  PERFORM 1 FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;

  -- VERROU 2 : LA PROPOSITION.
  SELECT * INTO r FROM public.subventions_municipales WHERE id = p_id FOR UPDATE;
  IF r.statut <> 'proposee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_close', 'statut', r.statut,
                              'clos_par', r.clos_par, 'clos_le', r.clos_le); END IF;

  -- L'ECHEANCE, CONSTATEE ET APPLIQUEE. On ne refuse pas en laissant l'argent immobilise.
  v_jour := public.jour_de_jeu_pays(r.pays);
  IF v_jour >= r.jour_echeance THEN
    UPDATE public.subventions_municipales
       SET statut = 'expiree', clos_le = now()
     WHERE id = p_id AND statut = 'proposee';
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_echue',
                              'jour', v_jour, 'jour_echeance', r.jour_echeance,
                              'montant_libere', r.montant); END IF;

  -- QUI REPOND POUR L'ORGANISATION.
  v_gest := public.subvention_gestionnaire(r.famille, r.beneficiaire);
  IF v_gest IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_gestionnaire',
                              'beneficiaire', r.beneficiaire); END IF;
  IF v_gest IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_gestionnaire_caisse',
                              'beneficiaire', r.beneficiaire); END IF;

  -- LE COMPARE-AND-SWAP. Une seule transition peut gagner.
  UPDATE public.subventions_municipales
     SET statut = v_statut, clos_par = v_moi, clos_le = now()
   WHERE id = p_id AND statut = 'proposee';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'course_perdue'); END IF;

  -- UN REFUS NE DEPLACE RIEN. La reserve est liberee par le seul changement de statut : il n'y a
  -- aucune ecriture financiere a faire, donc aucune a rater.
  IF v_statut = 'refusee' THEN
    RETURN jsonb_build_object('ok', true, 'statut', 'refusee', 'id', p_id,
      'montant_libere', r.montant, 'beneficiaire', r.beneficiaire,
      'commune', r.ville, 'maire', r.maire); END IF;

  -- L'ACCEPTATION DEPLACE L'ARGENT, DANS LA MEME TRANSACTION QUE LA TRANSITION.
  --
  -- LE LAISSEZ-PASSER EST REFERME IMMEDIATEMENT. `set_config(..., true)` vaut pour toute la
  -- transaction, pas pour l'instruction : laisse ouvert, il autoriserait n'importe quel debit
  -- ulterieur de la meme transaction. Il est donc ferme des que l'ecriture est faite.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_mvt := public.caisse_institution_mouvement(v_caisse, -r.montant, true);
  PERFORM set_config('rp.caisse_interne', '', true);

  -- UN DEBIT REFUSE ICI N'EST PAS UN REFUS METIER, C'EST UNE INCOHERENCE : la reserve garantit
  -- que l'enveloppe couvre le montant. On leve donc, pour que TOUTE la transaction soit annulee
  -- -- rendre un refus laisserait la proposition acceptee sans transfert, ce qui est pire.
  IF (v_mvt->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'enveloppe_incoherente : le debit de % sur % a ete refuse (%) alors que la '
      'reserve le garantissait -- transaction annulee',
      r.montant, v_caisse, coalesce(v_mvt->>'raison', '?');
  END IF;

  v_solde_orga := public.subvention_caisse_crediter(
    r.famille, r.beneficiaire, r.montant, 'Subvention municipale', v_jour);

  RETURN jsonb_build_object('ok', true, 'statut', 'acceptee', 'id', p_id,
    'montant', r.montant, 'beneficiaire', r.beneficiaire,
    'beneficiaire_nom', r.beneficiaire_nom, 'commune', r.ville, 'maire', r.maire,
    'caisse_organisation', v_solde_orga);
END $$;

COMMENT ON FUNCTION public.subvention_repondre(text, text) IS
  'L''organisation accepte ou refuse. Compare-and-swap sur statut = ''proposee'' : une seule '
  'transition gagne, et il n''y a pas de seconde reponse ni d''annulation ulterieure. Le client '
  'choisit un verbe (accepter/refuser), jamais un statut. Une proposition echue est close en '
  '''expiree'' au passage, pour ne pas immobiliser la reserve si la passe de minuit a manque.';

GRANT EXECUTE ON FUNCTION public.subvention_repondre(text, text) TO authenticated;

DO $p$
DECLARE v integer; v_def text;
BEGIN
  -- P1 : SECURITY DEFINER borne, et appelable par un client authentifie seulement.
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'subvention_repondre'
     AND p.prosecdef AND p.proconfig::text LIKE '%search_path%';
  IF v <> 1 THEN RAISE EXCEPTION 'P1 : la porte n''est pas un SECURITY DEFINER borne'; END IF;
  IF has_function_privilege('anon', 'public.subvention_repondre(text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P1b : anon peut repondre a une proposition'; END IF;

  -- P2 : LE COMPARE-AND-SWAP EST DANS LE CORPS -- l'UPDATE porte sa condition, il n'y a pas de
  -- verification separee suivie d'une ecriture.
  v_def := pg_get_functiondef('public.subvention_repondre(text,text)'::regprocedure);
  IF v_def NOT LIKE '%WHERE id = p_id AND statut = ''proposee''%' THEN
    RAISE EXCEPTION 'P2 : l''UPDATE de cloture ne porte pas sa condition de course'; END IF;

  -- P3 : LE LAISSEZ-PASSER EST REFERME. Deux appels a set_config, et le second remet a vide.
  IF v_def NOT LIKE '%set_config(''rp.caisse_interne'', ''on'', true)%'
     OR v_def NOT LIKE '%set_config(''rp.caisse_interne'', '''', true)%' THEN
    RAISE EXCEPTION 'P3 : le laissez-passer de caisse n''est pas ouvert PUIS referme';
  END IF;

  -- P4 : le client ne peut pas nommer un statut -- la liste close est dans le corps.
  IF v_def NOT LIKE '%p_reponse NOT IN (''accepter'', ''refuser'')%' THEN
    RAISE EXCEPTION 'P4 : la liste close des reponses est absente'; END IF;

  RAISE NOTICE 'Porte de reponse : 4 preuves structurelles vertes.';
END $p$;
