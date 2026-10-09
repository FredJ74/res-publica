-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009154659 (UTC ; 17h46 a Paris), nom
-- `mails_routes_placement_helvetia_et_arete_assemblee`. Le registre passe de 581 a 582 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 ae2199a75a5f7d38eaf31e619673273a, 9 547 caracteres,
-- 1 instruction au registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- Elle route la ONZIEME fonction, que l'inventaire avait manquee : `resoudre_placement_helvetia`
-- ecrit `insert into public.mails` en MINUSCULES, et le motif `INSERT INTO` ne l'attrapait pas -- un
-- inventaire par motif textuel doit etre insensible a la casse, ou il ment. Elle ferme aussi l'arete
-- que le routage avait creee : le GRANT a `service_role` sur les deux intermediaires SECURITY INVOKER
-- de la chaine de detection de l'Assemblee est retire, car il ouvrait un chemin qui ne menait plus
-- nulle part.
--
-- AUCUNE MODIFICATION DU DEPOT NE L'ACCOMPAGNE : elle patche une fonction SQL en place et retire
-- deux droits.
-- =============================================================================

-- Chantier 5 -- LA ONZIEME FONCTION, ET L'ARETE QUE LE ROUTAGE A CREEE.
--
-- 1. UN INVENTAIRE FAUX PARCE QUE LE MOTIF ETAIT SENSIBLE A LA CASSE.
--
-- Le releve des ecritures directes dans `public.mails` disait DIX fonctions. Il en manquait une :
-- `resoudre_placement_helvetia` ecrit `insert into public.mails` **en minuscules**, et le motif
-- de recherche `INSERT INTO` ne l'attrapait pas. Elle est le pendant Helvetia exact de
-- `resoudre_placement_national`, routee quelques minutes plus tot, avec le meme defaut : la
-- notification appartient a la transaction qui recredite le capital, donc une contrainte violee
-- sur la table des courriers annulerait le credit.
--
-- La lecon vaut mieux que le correctif : **un inventaire par motif textuel doit etre insensible
-- a la casse, ou il ment.** Le balayage refait avec `~*` ne trouve plus rien d'autre.
--
-- 2. L'ARETE : DEUX FONCTIONS SECURITY INVOKER QUI APPELLENT UN MOTEUR RESERVE.
--
-- La chaine reelle de l'Assemblee est :
--
--   assemblee_achat_illegal            SECURITY DEFINER  (anon, authenticated, service_role)
--     -> assemblee_transaction_interdite_interne   SECURITY INVOKER  (service_role)
--          -> assemblee_detecter_partie            SECURITY INVOKER  (service_role)
--               -> mail_systeme_poser_interne      reserve a postgres
--
--   assemblee_tracer_vente_interdite   SECURITY DEFINER
--     -> assemblee_detecter_partie     (meme suite)
--
-- ELLE TRAVERSE, et ce n'est pas une deduction : c'est mesure dans cette base, en transaction
-- annulee, sous `role = authenticated`. Une porte SECURITY DEFINER possedee par postgres fait de
-- postgres l'utilisateur EFFECTIF de toute la chaine imbriquee, y compris a travers une fonction
-- SECURITY INVOKER -- qui s'execute avec les droits de l'utilisateur COURANT, et non de
-- l'appelant d'origine.
--
-- MAIS L'APPEL DIRECT DES DEUX INTERMEDIAIRES, LUI, EST DESORMAIS REFUSE : la meme epreuve l'a
-- constate (`insufficient_privilege`). Leur GRANT a `service_role` ouvrait donc un chemin qui ne
-- fonctionne plus. On RETIRE LE DROIT plutot que de laisser ce chemin mort : aucun appelant du
-- depot ne les invoque directement -- ni `api/`, ni les `plateau-*.js` -- et l'une des deux porte
-- deja « _interne » dans son nom.
--
-- L'alternative aurait ete de les passer en SECURITY DEFINER. On ne l'a PAS fait : cela change
-- leur SEMANTIQUE D'AUTORITE, et une fonction invoker s'executant avec les droits de son
-- appelant est precisement ce qui la rend inoffensive. On ne touche pas a cela pour une commodite
-- de droits.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.resoudre_placement_helvetia(text)'::regprocedure);
  v_new := replace(v_def,
$ancien$insert into public.mails (
    id,
    to_player,
    from_player,
    subject,
    body,
    time,
    read,
    archived
  )
  values (
    'mail-helvetia-' || extract(epoch from now())::bigint,
    v_placement.personnage,
    'Banque Privée Helvetia',
    'Placement Helvetia arrivé à échéance',
    'Montant placé : ' || v_placement.montant ||
      ' FR. Gain brut (8%) : ' || v_gain_brut ||
      ' FR. Frais Helvetia (30% du gain, prélevés) : -' || v_frais ||
      ' FR. ' ||
      case
        when v_placement.type = 'declare'
          then 'Impôt sur le revenu financier (50%, versé aux finances de Républia) : -' ||
               v_impot || ' FR. '
        else
          'Placement offshore : aucune imposition républienne. '
      end ||
      'Gain net : ' || v_gain_net ||
      ' FR. Montant crédité sur votre compte : ' ||
      v_montant_final || ' FR.',
    now()::text,
    false,
    false
  );$ancien$,
$nouveau$perform public.mail_systeme_poser_interne(
    'Banque Privée Helvetia',
    v_placement.personnage,
    'Placement Helvetia arrivé à échéance',
    'Montant placé : ' || v_placement.montant ||
      ' FR. Gain brut (8%) : ' || v_gain_brut ||
      ' FR. Frais Helvetia (30% du gain, prélevés) : -' || v_frais ||
      ' FR. ' ||
      case
        when v_placement.type = 'declare'
          then 'Impôt sur le revenu financier (50%, versé aux finances de Républia) : -' ||
               v_impot || ' FR. '
        else
          'Placement offshore : aucune imposition républienne. '
      end ||
      'Gain net : ' || v_gain_net ||
      ' FR. Montant crédité sur votre compte : ' ||
      v_montant_final || ' FR.',
    now()::text
  );$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique sur resoudre_placement_helvetia : le fragment ne correspond pas';
  END IF;
  IF v_new ~* 'insert into\s+(public\.)?mails\s*\(' THEN
    RAISE EXCEPTION 'resoudre_placement_helvetia ecrit encore mails en direct';
  END IF;
  EXECUTE v_new;
END $mig$;

REVOKE EXECUTE ON FUNCTION public.assemblee_detecter_partie(text,text,jsonb,text,integer,boolean) FROM service_role;
REVOKE EXECUTE ON FUNCTION public.assemblee_transaction_interdite_interne(text,text,text,jsonb,text,integer) FROM service_role;

DO $$
DECLARE v_def text; v_droits text; v_n int;
BEGIN
  -- P1 : la onzieme fonction ne touche plus la table, et son courrier est intact au caractere pres.
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='resoudre_placement_helvetia';
  IF v_def ~* 'insert into\s+(public\.)?mails\s*\(' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- elle ecrit encore mails en direct'; END IF;
  IF position('mail_systeme_poser_interne' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- elle ne passe pas par le poseur'; END IF;
  IF position('Placement Helvetia arrivé à échéance' in v_def) = 0
     OR position('Banque Privée Helvetia' in v_def) = 0
     OR position('Frais Helvetia (30% du gain, prélevés)' in v_def) = 0
     OR position('Placement offshore : aucune imposition républienne. ' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le contenu du courrier a change'; END IF;
  IF position('now()::text' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''heure affichee a change'; END IF;
  IF NOT (SELECT p.prosecdef FROM pg_proc p
            JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
           WHERE p.proname='resoudre_placement_helvetia') THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- elle a perdu SECURITY DEFINER, elle n''atteindrait plus le poseur'; END IF;
  SELECT string_agg(coalesce(r.rolname,'PUBLIC'), ',' ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname='resoudre_placement_helvetia';
  IF v_droits IS DISTINCT FROM 'postgres,service_role' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- ses droits ont change : %', v_droits; END IF;

  -- P2 : L'ARETE EST RETIREE SUR LES DEUX INTERMEDIAIRES, et aucun des deux n'a change de
  -- semantique d'autorite : ils restent SECURITY INVOKER.
  SELECT string_agg(p.proname || '=' || coalesce(r.rolname,'PUBLIC'), ', '
                    ORDER BY p.proname, coalesce(r.rolname,'PUBLIC'))
    INTO v_droits FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname IN ('assemblee_detecter_partie','assemblee_transaction_interdite_interne');
  IF v_droits IS DISTINCT FROM
     'assemblee_detecter_partie=postgres, assemblee_transaction_interdite_interne=postgres' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- droits des intermediaires : %', v_droits; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname IN ('assemblee_detecter_partie','assemblee_transaction_interdite_interne')
     AND p.prosecdef;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- % intermediaire(s) sont passes en SECURITY DEFINER', v_n; END IF;

  -- P3 : LES DEUX PORTES D'ENTREE DE LA CHAINE SONT BIEN SECURITY DEFINER, possedees par
  -- postgres -- c'est par la que la chaine atteint le moteur. Mesure, pas deduit.
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname IN ('assemblee_achat_illegal','assemblee_tracer_vente_interdite')
     AND p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres';
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- % porte(s) d''entree SECURITY DEFINER au lieu de 2', v_n; END IF;

  -- P4 : PLUS AUCUNE ECRITURE DIRECTE DE `mails`, CASSE INSENSIBLE. Le poseur est le seul.
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE pg_get_functiondef(p.oid) ~* 'insert into\s+(public\.)?mails\s*\('
     AND p.proname <> 'mail_systeme_poser_interne';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- % fonction(s) ecrivent encore mails en direct', v_n; END IF;

  -- P5 : AUCUN COURRIER CREE NI SUPPRIME, et aucun residu du banc des droits.
  SELECT count(*) INTO v_n FROM public.mails;
  IF v_n <> 28 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % courriers au lieu de 28', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public' WHERE p.proname LIKE 'zzb%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % fonction(s) de banc subsistent', v_n; END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;