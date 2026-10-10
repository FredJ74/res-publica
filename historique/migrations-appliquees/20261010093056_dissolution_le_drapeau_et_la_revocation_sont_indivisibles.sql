-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010093056 (UTC), nom `dissolution_le_drapeau_et_la_revocation_sont_indivisibles`.
-- Le registre passe de 610 a 611 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 d859b4888e409224be81c8d9be21775e, 6393 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 18 : LA DISSOLUTION, LES TROIS VAGUES
--
-- La porte posee une heure plus tot ne couvrait que la deuxieme vague : elle est remplacee, et
-- SUPPRIMEE, par `assemblee_dissoudre`, qui met le drapeau `dissolutionUtilisee` et la revocation
-- des deputes dans une seule transaction, le drapeau en compare-and-swap AVANT toute revocation.
-- La troisieme vague -- la relance d'un cycle frais par circonscription -- reste au client,
-- consignee et non masquee, parce que sa formule vit dans data.js. Aucune regle de jeu modifiee.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 18 -- LA DISSOLUTION, LES TROIS VAGUES (10 octobre 2026)
--
-- L'inventaire decrivait la chaine 18 comme « cycle electoral, puis poste_depute = null en
-- boucle, puis relance par circonscription. TROIS VAGUES, AUCUNE PREUVE. » La porte posee une
-- heure plus tot ne couvrait que la deuxieme. Elle est remplacee -- et SUPPRIMEE, pour ne pas
-- laisser deux portes pour le meme acte -- par une porte qui couvre la premiere ET la deuxieme
-- dans une seule transaction.
--
-- POURQUOI LES DEUX PREMIERES VAGUES NE PEUVENT PAS ETRE SEPAREES. Le drapeau
-- `dissolutionUtilisee` est le verrou qui limite le President a UNE dissolution par mandat. Il
-- etait pose par un `sbSaveCycleElectoral(...).catch(() => {})` AVANT la revocation : si cette
-- ecriture se perdait et que la revocation aboutissait, le President pouvait DISSOUDRE A
-- NOUVEAU -- et si l'inverse se produisait, le drapeau etait consomme sans qu'aucun depute ne
-- perde son mandat. Les deux dans un seul BEGIN, avec un COMPARE-AND-SWAP sur le drapeau : un
-- rejeu est refuse, et il est refuse AVANT de revoquer quoi que ce soit.
--
-- LA TROISIEME VAGUE -- la relance d'un cycle frais par circonscription -- RESTE AU CLIENT, et
-- c'est consigne, pas masque : elle cree un cycle par ville a partir de
-- `construireNouveauCycleElectoral`, une formule qui vit dans data.js et que le serveur ne
-- connait pas. L'absorber demanderait un miroir du calendrier electoral, qui n'existe pas. Son
-- echec n'est plus avale pour autant : le client le lit et le dit.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE : une dissolution par mandat, tous les deputes du pays, meme
-- lecture du mandat (`poste_depute->>'id' = 'depute'`).

DROP FUNCTION IF EXISTS public.assemblee_dissoudre_revoquer_deputes(text);

CREATE OR REPLACE FUNCTION public.assemblee_dissoudre(p_pays text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_moi text; v_pays text; v_id text; v_data jsonb; v_n integer; v_revoques integer;
BEGIN
  -- SEUL LE PRESIDENT DISSOUT. exiger_poste leve pour un client sans le poste, et rend NULL pour
  -- un appel serveur -- le cron n'a pas de personnage et traverse, comme partout ailleurs.
  v_moi := public.exiger_poste('president');

  IF v_moi IS NULL THEN
    IF coalesce(btrim(coalesce(p_pays, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_manquant');
    END IF;
    v_pays := p_pays;
  ELSE
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu'); END IF;
    IF p_pays IS NOT NULL AND p_pays <> v_pays THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite');
    END IF;
  END IF;

  -- PREMIERE VAGUE : le drapeau, par COMPARE-AND-SWAP, et AVANT toute revocation.
  v_id := v_pays || '_president';
  SELECT c.data::jsonb INTO v_data FROM public.cycles_electoraux c WHERE c.id = v_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_presidentiel_introuvable');
  END IF;
  IF coalesce((v_data ->> 'dissolutionUtilisee')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dissolution_deja_utilisee');
  END IF;

  UPDATE public.cycles_electoraux
     SET data = jsonb_set(v_data, '{dissolutionUtilisee}', 'true'::jsonb, true)::text,
         updated_at = now()
   WHERE id = v_id
     AND coalesce((data::jsonb ->> 'dissolutionUtilisee')::boolean, false) = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dissolution_deja_utilisee');
  END IF;

  -- DEUXIEME VAGUE : tous les deputes du pays, en UNE instruction, sur la TABLE. La vue
  -- refuserait la fiche d'autrui -- c'est precisement le defaut ferme.
  UPDATE public.personnages_donnees
     SET poste_depute = NULL
   WHERE country = v_pays
     AND poste_depute IS NOT NULL
     AND (poste_depute ->> 'id') = 'depute';
  GET DIAGNOSTICS v_revoques = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'revoques', v_revoques,
    'cycle_president', jsonb_set(v_data, '{dissolutionUtilisee}', 'true'::jsonb, true));
END; $fn$;

REVOKE ALL ON FUNCTION public.assemblee_dissoudre(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_dissoudre(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_dissoudre(text) TO authenticated, service_role;

DO $$
DECLARE v_def text; v_acl text; v_n integer;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='assemblee_dissoudre';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  -- P2 : l'ancienne porte partielle a bien DISPARU -- pas deux portes pour un acte.
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
              WHERE n.nspname='public' AND p.proname='assemblee_dissoudre_revoquer_deputes') THEN
    RAISE EXCEPTION 'P2 : l''ancienne porte partielle subsiste'; END IF;
  IF v_acl LIKE '%anon=%' THEN RAISE EXCEPTION 'P3 : anon peut dissoudre'; END IF;
  IF v_def NOT LIKE '%exiger_poste(''president'')%' THEN
    RAISE EXCEPTION 'P4 : l''autorite presidentielle n''est pas exigee'; END IF;
  -- P5 : le drapeau est un compare-and-swap DANS LE FILTRE, et il precede la revocation.
  IF v_def NOT LIKE '%AND coalesce((data::jsonb ->> ''dissolutionUtilisee'')::boolean, false) = false%' THEN
    RAISE EXCEPTION 'P5a : le drapeau n''est pas un compare-and-swap'; END IF;
  IF position('dissolutionUtilisee}'', ''true''::jsonb, true)::text' in v_def) = 0
     OR position('SET poste_depute = NULL' in v_def) < position('dissolutionUtilisee}'', ''true''::jsonb, true)::text' in v_def) THEN
    RAISE EXCEPTION 'P5b : la revocation precede le drapeau'; END IF;
  IF v_def LIKE '%UPDATE public.personnages %' THEN
    RAISE EXCEPTION 'P6 : la revocation passe par la vue, elle sera refusee'; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees
   WHERE poste_depute IS NOT NULL AND (poste_depute ->> 'id') = 'depute';
  RAISE NOTICE 'assemblee_dissoudre : 6 preuves conformes ; % depute(s) en place.', v_n;
END $$;
