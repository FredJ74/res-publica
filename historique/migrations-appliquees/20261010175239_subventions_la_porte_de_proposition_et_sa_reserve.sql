-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010175239 (UTC), nom `subventions_la_porte_de_proposition_et_sa_reserve`.
-- Le registre passe de 627 a 628 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5cad3be182bca282dbaed39ced44f34a, 9223 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, §3 -- LA PORTE DE PROPOSITION ET SA RESERVE
--
-- `subvention_proposer` ne recoit du navigateur qu'une famille, un beneficiaire et un montant :
-- ni poste, ni ville, ni eligibilite, ni solde, ni jour -- un parametre client qui BORNE une
-- autorisation est une faille, meme derriere un RPC. Le verrou de serialisation est la CAISSE
-- elle-meme : le `FOR UPDATE` sur l'enveloppe met les appels en file avant de calculer la reserve,
-- ce qui rend la sur-reservation impossible. L'INSERT precede le paiement pour qu'un double-clic ne
-- coute aucun PA, et un refus de paiement EFFACE la proposition avant d'etre rendu -- le patron de
-- `budget_repartition_fixer`. La porte est inerte tant que l'ordre n'est pas au miroir des couts,
-- et la preuve P3 le consigne au lieu de le masquer.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, §3 -- LA PORTE DE PROPOSITION (10 octobre 2026)
--
-- LE NAVIGATEUR N'APPORTE QUE TROIS CHOSES : une famille, un identifiant de beneficiaire, un
-- montant. Il n'apporte NI son poste, NI sa ville, NI l'eligibilite du beneficiaire, NI le solde
-- de l'enveloppe, NI le jour. Tout cela est relu au serveur, et c'est exactement la doctrine de
-- la purge : un parametre client qui BORNE une autorisation est une faille, meme derriere un RPC.
--
-- LE VERROU DE SERIALISATION EST LA CAISSE ELLE-MEME. Deux propositions simultanees sur la meme
-- commune pourraient chacune lire « 5 000 disponibles » et reserver 4 000 : 8 000 engages sur
-- 5 000. Le `FOR UPDATE` sur la ligne de l'enveloppe met donc les deux appels en file sur cette
-- ligne AVANT de calculer la reserve. La seconde lit la reserve que la premiere a creee, et se
-- voit refuser. Ce n'est pas un verrou ajoute a cote : c'est la ligne d'argent qui sert de verrou.
--
-- POURQUOI L'INSERT PRECEDE LE PAIEMENT, ET POURQUOI LE REFUS EFFACE. Une fonction appelee par
-- PostgREST qui RETOURNE normalement voit sa transaction COMMITER : un refus rendu apres une
-- ecriture laisserait l'ecriture en base. Deux consequences, et les deux sont traitees ici :
--   * l'INSERT passe en premier, pour que le rejeu (index unique partiel) soit refuse SANS avoir
--     facture 2 PA au maire -- un double-clic ne coute rien ;
--   * si le paiement echoue ensuite, la proposition est EFFACEE avant que le refus soit rendu.
--     C'est le patron de `budget_repartition_fixer`, qui restaure l'ancienne part avant de
--     refuser une somme au-dela de 100 %. Aucune branche de cette porte ne laisse de reliquat.
--
-- LE GESTIONNAIRE EST ANNONCE, PAS EXIGE. Si le beneficiaire n'a personne pour repondre
-- (`presidents_clubs` est vide aujourd'hui), la porte accepte quand meme et retourne
-- `gestionnaire_connu: false`. Refuser serait un arbitrage que personne n'a rendu -- et
-- l'expiration a trois jours EST une issue prevue. L'interface, elle, doit prevenir le maire
-- avant qu'il engage ses 2 PA.

CREATE OR REPLACE FUNCTION public.subvention_proposer(
  p_famille text, p_beneficiaire text, p_montant numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_moi text; v_poste text; v_ville text; v_pays text;
  v_caisse text; v_solde numeric; v_reserve numeric; v_dispo numeric;
  v_refus text; v_nom text; v_gest text; v_jour integer; v_id text;
  v_paie jsonb; v_n integer;
BEGIN
  -- 1. QUI PARLE, ET DE QUELLE COMMUNE. Lu au serveur, jamais recu du client.
  SELECT a.nom, a.poste_id, coalesce(a.poste_city, ''), a.pays
    INTO v_moi, v_poste, v_ville, v_pays
    FROM public.acteur_poste_courant() a LIMIT 1;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'maire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', 'maire', 'poste_reel', v_poste); END IF;
  IF v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_indeterminee'); END IF;

  -- 2. LE MONTANT. Brut, entier, strictement positif. `trunc` refuse les centimes : les recettes
  -- municipales et toutes les caisses du jeu sont en francs entiers.
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide', 'montant', p_montant); END IF;

  -- 3. LE BENEFICIAIRE. Eligible ET domicilie dans MA commune -- un seul verdict, celui que
  -- l'interface a deja vu, pour qu'aucune divergence ne soit possible.
  v_refus := public.subvention_beneficiaire_verdict(v_pays, v_ville, p_famille, p_beneficiaire);
  IF v_refus IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', v_refus, 'famille', p_famille,
                              'beneficiaire', p_beneficiaire, 'ma_commune', v_ville); END IF;

  SELECT e.nom INTO v_nom FROM public.subvention_entites(p_famille) e WHERE e.id = p_beneficiaire;
  v_gest := public.subvention_gestionnaire(p_famille, p_beneficiaire);

  -- 4. L'ENVELOPPE, SOUS VERROU. Le FOR UPDATE serialise les propositions de cette commune.
  v_caisse := v_pays || '_subventions_' || v_ville;
  SELECT coalesce((b.data->>'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments b WHERE b.id = v_caisse FOR UPDATE;
  IF v_solde IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enveloppe_absente', 'caisse', v_caisse); END IF;

  -- LA RESERVE EST CALCULEE, PAS STOCKEE : la somme des propositions encore en attente.
  SELECT coalesce(sum(s.montant), 0) INTO v_reserve FROM public.subventions_municipales s
   WHERE s.pays = v_pays AND s.ville = v_ville AND s.statut = 'proposee';
  v_dispo := v_solde - v_reserve;

  IF p_montant > v_dispo THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'solde', v_solde, 'reserve', v_reserve, 'disponible', v_dispo,
                              'demande', p_montant); END IF;

  -- 5. LA PROPOSITION. L'id est technique ; la cle LOGIQUE qui refuse le rejeu est portee par
  -- l'index unique partiel. ON CONFLICT DO NOTHING fait du rejeu un refus, pas une erreur.
  v_jour := public.jour_de_jeu_pays(v_pays);
  v_id := 'subv-' || gen_random_uuid()::text;

  INSERT INTO public.subventions_municipales
    (id, pays, ville, maire, famille, beneficiaire, beneficiaire_nom, montant, jour, jour_echeance)
  VALUES (v_id, v_pays, v_ville, v_moi, p_famille, p_beneficiaire,
          coalesce(v_nom, p_beneficiaire), p_montant, v_jour, v_jour + 3)
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_identique_en_attente',
                              'beneficiaire', p_beneficiaire, 'montant', p_montant); END IF;

  -- 6. LES 2 PA, EN DERNIER -- et le refus EFFACE la proposition avant d'etre rendu.
  v_paie := public.payer_ordre(v_moi, 'subvention_proposer', 2, 0);
  IF (v_paie->>'ok')::boolean IS NOT TRUE THEN
    DELETE FROM public.subventions_municipales WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'),
                              'paiement', v_paie); END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,
    'beneficiaire', p_beneficiaire, 'beneficiaire_nom', coalesce(v_nom, p_beneficiaire),
    'montant', p_montant, 'jour', v_jour, 'jour_echeance', v_jour + 3,
    'solde', v_solde, 'reserve', v_reserve + p_montant, 'disponible', v_dispo - p_montant,
    'gestionnaire_connu', v_gest IS NOT NULL, 'pa', v_paie->'pa');
END $$;

COMMENT ON FUNCTION public.subvention_proposer(text, text, numeric) IS
  'Etage 2 : le maire propose un montant BRUT a une organisation eligible de sa commune. 2 PA. '
  'Le client n''apporte ni poste, ni ville, ni eligibilite, ni solde, ni jour. Le FOR UPDATE sur '
  'la caisse de l''enveloppe serialise les propositions, ce qui rend la sur-reservation '
  'impossible. L''INSERT precede le paiement pour qu''un rejeu ne coute pas de PA, et un refus de '
  'paiement efface la proposition avant d''etre rendu.';

GRANT EXECUTE ON FUNCTION public.subvention_proposer(text, text, numeric) TO authenticated;

DO $p$
DECLARE v integer;
BEGIN
  -- P1 : la porte existe, en SECURITY DEFINER, avec un search_path fixe.
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'subvention_proposer'
     AND p.prosecdef AND p.proconfig::text LIKE '%search_path%';
  IF v <> 1 THEN RAISE EXCEPTION 'P1 : la porte n''est pas un SECURITY DEFINER borne (%)', v; END IF;

  -- P2 : elle est appelable par un client authentifie, et PAS par anon.
  IF NOT has_function_privilege('authenticated',
       'public.subvention_proposer(text,text,numeric)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P2a : un maire authentifie ne peut pas appeler la porte'; END IF;
  IF has_function_privilege('anon', 'public.subvention_proposer(text,text,numeric)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P2b : anon peut proposer une subvention'; END IF;

  -- P3 : L'ORDRE N'EST PAS ENCORE AU MIROIR DES COUTS, et c'est consigne ici sans etre masque.
  -- `payer_ordre` refuse un ordre non declare (`ordre_inconnu`) : la porte est donc INERTE
  -- jusqu'a ce que data.js declare l'ordre a 2 PA et que le miroir soit regenere. L'ordre des
  -- gestes est voulu -- la base n'est pas en avance sur le code, elle est en attente de lui.
  SELECT count(*) INTO v FROM public.ordres_couts WHERE fn = 'subvention_proposer';
  IF v = 0 THEN
    RAISE NOTICE 'P3 : subvention_proposer n''est pas encore au miroir des couts -- la porte '
                 'refusera ordre_inconnu jusqu''a la regeneration. Attendu a cet instant.';
  ELSIF NOT EXISTS (SELECT 1 FROM public.ordres_couts
                     WHERE fn = 'subvention_proposer' AND pa = 2 AND cost = 0) THEN
    RAISE EXCEPTION 'P3 : l''ordre est au miroir mais pas a 2 PA et 0 FR';
  END IF;

  RAISE NOTICE 'Porte de proposition : 3 preuves structurelles vertes.';
END $p$;
