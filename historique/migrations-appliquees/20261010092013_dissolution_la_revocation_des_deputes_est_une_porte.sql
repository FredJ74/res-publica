-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010092013 (UTC), nom `dissolution_la_revocation_des_deputes_est_une_porte`.
-- Le registre passe de 607 a 608 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6fd8b6aac043d8e5dad0ce0089d87578, 5109 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 18 : LA DISSOLUTION DE L'ASSEMBLEE
--
-- La revocation des deputes etait un UPDATE client sur la fiche d'autrui, qui leve
-- `personnage_non_possede` (42501) depuis le declencheur de la vue et dont l'echec etait avale :
-- la dissolution n'a jamais revoque personne. `assemblee_dissoudre_revoquer_deputes` revoque tous
-- les deputes du pays en une seule instruction sur la table, autorite presidentielle relue au
-- serveur, sans modifier aucune regle de jeu.
--
-- SUPERSEDEE une heure plus tard par la version 20261010093056 (registre 611), qui SUPPRIME cette
-- fonction au profit de `assemblee_dissoudre`, couvrant aussi le drapeau `dissolutionUtilisee`.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 18 -- LA DISSOLUTION DE L'ASSEMBLEE (10 octobre 2026)
--
-- CE QUI SE PASSAIT, ET LA MESURE EST SANS APPEL. `doDissoudreAssemblee` lisait tous les
-- personnages du pays, puis, pour chaque depute, faisait un
-- `sbUpdate('personnages', ..., { poste_depute: null }).catch(() => {})`. C'est une ecriture
-- CLIENTE SUR LA FICHE D'AUTRUI : mesure faite le 10 octobre 2026, un tel UPDATE ne rend pas
-- « 0 ligne », il LEVE `personnage_non_possede` (ERRCODE 42501) depuis le declencheur de la vue.
-- Le catch l'avalait.
--
-- AUTREMENT DIT : LA DISSOLUTION N'A JAMAIS REVOQUE PERSONNE. Le President payait son ordre, le
-- drapeau `dissolutionUtilisee` etait pose -- une dissolution par mandat, consommee -- les cycles
-- electoraux etaient relances, et les deputes en place GARDAIENT leur mandat. Une Assemblee
-- dissoute se retrouvait avec deux generations de deputes : les anciens, jamais revoques, et les
-- nouveaux elus par les scrutins relances.
--
-- CE QUE LA PORTE FAIT. Une transaction : la revocation de TOUS les deputes du pays en une seule
-- instruction, et le compte rendu. L'autorite est relue au serveur -- seul le President dissout.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. Meme perimetre (les deputes de CE pays), meme lecture
-- fiable (`poste_depute->>'id' = 'depute'`, jamais le filtre errone de
-- notifierDeputesPourVoteConfiance que l'inventaire signalait deja comme dette separee), meme
-- compte rendu. Ce qui change, c'est que la revocation a lieu.

CREATE OR REPLACE FUNCTION public.assemblee_dissoudre_revoquer_deputes(p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_pays text; v_n integer;
BEGIN
  -- SEUL LE PRESIDENT DISSOUT. exiger_poste leve pour un client sans le poste, et rend NULL pour
  -- un appel serveur -- le cron n'a pas de personnage et traverse, comme partout ailleurs.
  v_moi := public.exiger_poste('president');

  IF v_moi IS NULL THEN
    -- Appel serveur : le pays doit etre nomme.
    IF coalesce(btrim(coalesce(p_pays, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_manquant');
    END IF;
    v_pays := p_pays;
  ELSE
    -- Appel client : le pays est celui du President, jamais celui qu'il annonce.
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
    END IF;
    IF p_pays IS NOT NULL AND p_pays <> v_pays THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite');
    END IF;
  END IF;

  -- UNE SEULE INSTRUCTION POUR TOUS LES DEPUTES : aucune boucle, aucune fenetre entre deux
  -- revocations. La lecture du mandat est celle du client, a la lettre.
  UPDATE public.personnages_donnees
     SET poste_depute = NULL
   WHERE country = v_pays
     AND poste_depute IS NOT NULL
     AND (poste_depute ->> 'id') = 'depute';
  GET DIAGNOSTICS v_n = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'revoques', v_n);
END; $fn$;

REVOKE ALL ON FUNCTION public.assemblee_dissoudre_revoquer_deputes(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_dissoudre_revoquer_deputes(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_dissoudre_revoquer_deputes(text)
  TO authenticated, service_role;

DO $$
DECLARE v_def text; v_acl text; v_n integer;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='assemblee_dissoudre_revoquer_deputes';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_acl LIKE '%anon=%' THEN RAISE EXCEPTION 'P2 : anon peut dissoudre l''Assemblee'; END IF;
  IF v_def NOT LIKE '%exiger_poste(''president'')%' THEN
    RAISE EXCEPTION 'P3 : l''autorite presidentielle n''est pas exigee'; END IF;
  -- P4 : UNE SEULE instruction de revocation, et elle vise la TABLE (la vue refuserait la fiche
  -- d'autrui -- c'est precisement le defaut ferme).
  IF (length(v_def) - length(replace(v_def, 'SET poste_depute = NULL', ''))) / 23 <> 1 THEN
    RAISE EXCEPTION 'P4 : % instruction(s) de revocation au lieu de 1',
      (length(v_def) - length(replace(v_def, 'SET poste_depute = NULL', ''))) / 23; END IF;
  IF v_def LIKE '%UPDATE public.personnages %' THEN
    RAISE EXCEPTION 'P4 : la revocation passe par la vue, elle sera refusee'; END IF;
  -- P5 : le pays n'est jamais celui que le client annonce.
  IF v_def NOT LIKE '%pays_hors_autorite%' THEN
    RAISE EXCEPTION 'P5 : un President pourrait dissoudre l''Assemblee d''un autre empire'; END IF;
  -- P6 : combien de deputes en place aujourd'hui ? Cette migration n'en revoque aucun.
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE poste_depute IS NOT NULL AND (poste_depute ->> 'id') = 'depute';
  RAISE NOTICE 'assemblee_dissoudre_revoquer_deputes : 5 preuves conformes ; % depute(s) en place.', v_n;
END $$;
