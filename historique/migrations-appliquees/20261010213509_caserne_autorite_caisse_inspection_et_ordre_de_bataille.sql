-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010213509 (UTC), nom `caserne_autorite_caisse_inspection_et_ordre_de_bataille`.
-- Le registre passe de 635 a 636 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5eb099b15b4a5a839d0d36e200e8f05e, 20061 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- CE QU'ELLE FERME, EN QUATRE POINTS -- CLOTURE DE LA CASERNE DE REPUBLIA
--
-- 1. LE MINISTRE DE LA DEFENSE NE PUISE PLUS DANS LA CAISSE DE LA CASERNE. `caisses_autorites`
--    accordait le debit a {commandant, min_def} ; l'arbitrage du 10 octobre 2026 tranche que le
--    ministre ALIMENTE et ne depense pas. Mesure prealable : le seul debit client de cette caisse
--    etait la recherche d'armement, deja reservee au Commandant -- retirer min_def ne fermait donc
--    aucun chemin legitime, il fermait la console.
-- 2. LE COMMANDANT PEUT REVERSER AU MINISTERE. Ce flux n'existait pas : la caserne pouvait
--    recevoir, jamais rendre. Debit et credit dans une seule transaction.
-- 3. L'ORDRE DE BATAILLE N'EST PLUS PUBLIC. La policy `compagnies_lecture_mon_pays` ouvrait
--    `compagnies_militaires` en SELECT a TOUT joueur authentifie du pays. Elle tombe, le SELECT
--    est revoque, et la lecture passe par une porte qui PROJETTE : blob entier pour la chaine,
--    presence seule pour les autres -- un civil doit continuer a voir qu'un detachement tient
--    une piece.
-- 4. L'INSPECTION DES TROUPES EST GARDEE AU SERVEUR. Elle ne l'etait qu'en JavaScript. Ouverte au
--    Lieutenant, au Capitaine, au Commandant et au ministre ; refusee au soldat et au civil ;
--    chacun dans son perimetre.
--
-- PREUVE COMPORTEMENTALE : outils/bancs/banc-caserne-autorites.sql, 24 epreuves en transaction
-- annulee, contre-epreuve de la fuite comprise.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- CASERNE DE REPUBLIA -- TROIS FERMETURES D'AUTORITE ET UN FLUX MANQUANT (10 octobre 2026)
-- =================================================================================================
-- Arbitrages de game design rendus le 10 octobre 2026, apres l'audit de consolidation de la
-- caserne. Cette migration ne cree aucun grade, aucun poste et aucun echelon : elle resserre des
-- autorites deja existantes et ajoute le seul flux financier que le game design reclamait.
--
-- 1. LE MINISTRE DE LA DEFENSE NE PUISE PLUS DANS LA CAISSE DE LA CASERNE.
--    `caisses_autorites` accordait le debit a {commandant, min_def}. La regle arbitree est :
--    le ministre ALIMENTE la caserne, il ne la depense pas. Une fois l'argent verse, il est
--    engage par le Commandant, a la caserne. La ligne passe donc a {commandant}.
--    Mesure prealable : le SEUL debit client de cette caisse est la recherche d'armement
--    (plateau-politique.js), deja reservee au Commandant par son ordre -- retirer min_def ne
--    ferme donc aucun chemin legitime, il ferme la console.
--    Le sens Ministere -> Caserne n'est pas touche : il passe par caisse_ministere_mouvement,
--    qui deduit le poste de l'identifiant de la caisse SOURCE et ne consulte pas cette table.
--
-- 2. LE COMMANDANT PEUT FAIRE REMONTER DE L'ARGENT AU MINISTERE.
--    Ce flux n'existait pas : il n'y avait aucun chemin de la caserne vers une caisse
--    ministerielle. caserne_reverser_au_ministere le pose, en une transaction, avec l'autorite
--    relue en base.
--
-- 3. L'ORDRE DE BATAILLE N'EST PLUS PUBLIC.
--    La policy compagnies_lecture_mon_pays ouvrait `compagnies_militaires` en SELECT a TOUT
--    joueur authentifie du pays : matricules, PA, armes, positions, missions, reserve. Elle est
--    supprimee et le SELECT est revoque. La lecture passe par militaire_compagnies_lisibles(),
--    qui PROJETTE selon la place de l'appelant dans la chaine militaire.
--    Ce n'est pas un filtre : un civil doit continuer a voir qu'un detachement tient une piece
--    (c'est ce qu'il observe dans le monde, et c'est ce qui declenche les missions d'entree).
--    Il recoit donc une projection de PRESENCE -- qui mene, ou sont les hommes, combien, quelle
--    consigne -- et rien de ce qui fait un ordre de bataille.
--
-- 4. L'INSPECTION DES TROUPES EST GARDEE AU SERVEUR.
--    Elle n'etait protegee que par `accesInspectionTroupes()`, en JavaScript. La regle arbitree
--    ouvre l'inspection a toute la chaine a partir du Lieutenant -- Lieutenant, Capitaine,
--    Commandant, ministre de la Defense -- et la refuse au soldat. militaire_inspection_perimetre
--    rend ce verdict, et le perimetre qui va avec : sa section, sa compagnie, ou l'armee.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS : elle ne touche ni aux grades, ni aux candidatures, ni au
-- combat, ni a la compagnie sans capitaine -- qui est un etat NORMAL du game design et non une
-- anomalie a reparer.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. L'AUTORITE DE DEBIT DE LA CAISSE DE LA CASERNE
-- -------------------------------------------------------------------------------------------------
UPDATE public.caisses_autorites
   SET postes_debit = ARRAY['commandant']::text[],
       note = 'caserne : le ministre ALIMENTE, le Commandant DEPENSE (arbitrage du 10 octobre 2026)'
 WHERE motif = 'caserne-militaire' AND NOT est_prefixe;

-- -------------------------------------------------------------------------------------------------
-- 2. CASERNE -> MINISTERE : LE REVERSEMENT, DECIDE PAR LE COMMANDANT
-- -------------------------------------------------------------------------------------------------
-- POURQUOI UNE FONCTION DEDIEE ET NON caisse_client_mouvement. Celle-la debite SANS crediter :
-- l'argent quitterait la caserne sans arriver au ministere si le second appel echouait. Les deux
-- mouvements sont ici dans la meme transaction, comme caisse_ministere_mouvement le fait dans
-- l'autre sens.
--
-- L'ORDRE DES VERROUS EST CANONIQUE (identifiant croissant) et non « source puis destination » :
-- deux reversements simultanes se serialisent donc au lieu de s'interbloquer. Le cas croise avec
-- caisse_ministere_mouvement, qui verrouille dans son propre sens, reste theoriquement possible ;
-- PostgreSQL l'arbitre en annulant une transaction ENTIERE, donc sans ecriture partielle ni
-- argent perdu. C'est le seul compromis de cette fonction, et il est nomme.
--
-- AUCUN PLAFONNEMENT : un reversement partiel serait une surprise sur une decision volontaire.
-- Solde insuffisant = refus, rien n'est ecrit.
CREATE OR REPLACE FUNCTION public.caserne_reverser_au_ministere(p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text;
  v_source text; v_dest text;
  v_src_data jsonb; v_dst_data jsonb;
  v_src_solde numeric; v_dst_solde numeric;
  v_existe_dest boolean;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- AUTORITE : leve si le compte connecte n'est pas le Commandant.
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;

  v_source := v_pays || '_caserne-militaire';
  v_dest   := v_pays || '_gouvernement-min_def';

  -- Verrous dans l'ordre de l'identifiant, independamment du sens du flux.
  PERFORM 1 FROM public.caisses_batiments
   WHERE id IN (v_source, v_dest) ORDER BY id FOR UPDATE;

  SELECT data INTO v_src_data FROM public.caisses_batiments WHERE id = v_source;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_caserne_absente');
  END IF;
  v_src_solde := CASE WHEN jsonb_typeof(v_src_data->'solde') = 'number'
                      THEN (v_src_data->>'solde')::numeric ELSE 0 END;
  IF v_src_solde < p_montant THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, v_source, -p_montant, 'reversement_ministere', false, 'solde_insuffisant');
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', v_src_solde);
  END IF;

  SELECT data INTO v_dst_data FROM public.caisses_batiments WHERE id = v_dest;
  v_existe_dest := FOUND;
  v_dst_solde := CASE WHEN v_existe_dest AND jsonb_typeof(v_dst_data->'solde') = 'number'
                      THEN (v_dst_data->>'solde')::numeric ELSE 0 END;

  UPDATE public.caisses_batiments
     SET data = coalesce(v_src_data,'{}'::jsonb) || jsonb_build_object('solde', v_src_solde - p_montant),
         updated_at = now()
   WHERE id = v_source;

  IF v_existe_dest THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_dst_data,'{}'::jsonb) || jsonb_build_object('solde', v_dst_solde + p_montant),
           updated_at = now()
     WHERE id = v_dest;
  ELSE
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (v_dest, jsonb_build_object('solde', p_montant), now());
  END IF;

  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, v_source, -p_montant, 'reversement_ministere', true, NULL);

  RETURN jsonb_build_object('ok', true, 'verse', p_montant,
                            'solde_caserne', v_src_solde - p_montant,
                            'solde_ministere', v_dst_solde + p_montant);
END;
$function$;

COMMENT ON FUNCTION public.caserne_reverser_au_ministere(numeric) IS
  'Reversement Caserne -> Ministere de la Defense, decide par le Commandant. Debit et credit dans une seule transaction, verrous en ordre d identifiant, aucun plafonnement (arbitrage du 10 octobre 2026).';

REVOKE ALL ON FUNCTION public.caserne_reverser_au_ministere(numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.caserne_reverser_au_ministere(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.caserne_reverser_au_ministere(numeric) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 3. L'ORDRE DE BATAILLE, PROJETE SELON LA PLACE DANS LA CHAINE
-- -------------------------------------------------------------------------------------------------
-- PERIMETRE PLEIN (le blob entier, comme avant) :
--   . ministre de la Defense et Commandant : toutes les compagnies de leur pays ;
--   . Capitaine : la compagnie dont il est le capitaine ;
--   . Lieutenant : la compagnie qui porte sa section ;
--   . soldat joueur : la compagnie ou il sert.
-- PROJECTION DE PRESENCE (tout le reste, meme pays) : qui mene, ou, combien, quelle consigne.
-- Ni matricule, ni PA, ni arme, ni reserve, ni contingent, ni tresorerie, ni stock d'armes.
--
-- MEME FORME DE SORTIE QUE LE SELECT QU'ELLE REMPLACE -- (id, data) -- pour que les trente-trois
-- sites d'appel du navigateur ne bougent pas d'une ligne. C'est la couche d'acces qui change de
-- chemin, pas les ecrans.
CREATE OR REPLACE FUNCTION public.militaire_compagnies_lisibles()
 RETURNS TABLE(id text, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_sommet boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;
  SELECT pd.country, pd.poste->>'id' INTO v_pays, v_poste
    FROM public.personnages_donnees pd WHERE pd.name = v_moi;
  IF v_pays IS NULL THEN RETURN; END IF;
  v_sommet := coalesce(v_poste,'') IN ('min_def', 'commandant');

  RETURN QUERY
  SELECT c.id,
         CASE WHEN v_sommet
                OR c.data->>'capitaineNom' = v_moi
                OR EXISTS (SELECT 1
                             FROM jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
                            WHERE s->>'lieutenantNom' = v_moi)
                OR EXISTS (SELECT 1
                             FROM jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
                                  jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
                            WHERE coalesce((sol->>'pj')::boolean, false)
                              AND sol->>'nom' = v_moi)
              THEN c.data
              ELSE jsonb_build_object(
                     'pays',         c.data->>'pays',
                     'capitaineNom', c.data->>'capitaineNom',
                     'sections',     coalesce((
                        SELECT jsonb_agg(jsonb_build_object(
                                 'id',            s->>'id',
                                 'lieutenantNom', s->>'lieutenantNom',
                                 'mission',       s->>'mission',
                                 'soldats',       coalesce((
                                    SELECT jsonb_agg(jsonb_build_object(
                                             'ville',         sol->>'ville',
                                             'buildingId',    sol->>'buildingId',
                                             'roomId',        sol->>'roomId',
                                             'leaderCourant', sol->>'leaderCourant'))
                                      FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
                                 ), '[]'::jsonb)
                               ) ORDER BY ord)
                          FROM jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb))
                               WITH ORDINALITY AS t(s, ord)
                     ), '[]'::jsonb))
         END
    FROM public.compagnies_militaires c
   WHERE c.data->>'pays' = v_pays
   ORDER BY c.id;
END;
$function$;

COMMENT ON FUNCTION public.militaire_compagnies_lisibles() IS
  'Compagnies du pays de l appelant, PROJETEES selon sa place dans la chaine militaire : blob entier pour min_def/Commandant/son Capitaine/son Lieutenant/son soldat, projection de presence seule pour tout le reste. Remplace le SELECT direct sur compagnies_militaires (10 octobre 2026).';

REVOKE ALL ON FUNCTION public.militaire_compagnies_lisibles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_compagnies_lisibles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_compagnies_lisibles() TO service_role;

-- LA POLICY TOMBE, ET LE DROIT AVEC. Les deux : une policy supprimee sans revoquer le GRANT
-- laisserait la table lisible le jour ou quelqu'un reactiverait une policy permissive.
DROP POLICY IF EXISTS compagnies_lecture_mon_pays ON public.compagnies_militaires;
REVOKE SELECT ON TABLE public.compagnies_militaires FROM authenticated;

-- -------------------------------------------------------------------------------------------------
-- 4. L'INSPECTION DES TROUPES : LE VERDICT ET LE PERIMETRE, RENDUS PAR LE SERVEUR
-- -------------------------------------------------------------------------------------------------
-- La chaine a partir du Lieutenant inspecte ; le soldat non ; un civil non. Le perimetre suit le
-- grade -- sa section, sa compagnie, l'armee -- parce que « inspecter les troupes » n'a pas le
-- meme sens pour un chef de section et pour un ministre.
CREATE OR REPLACE FUNCTION public.militaire_inspection_perimetre()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text;
  v_compagnies text[]; v_sections text[]; v_portee text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT pd.country, pd.poste->>'id' INTO v_pays, v_poste
    FROM public.personnages_donnees pd WHERE pd.name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;

  IF coalesce(v_poste,'') IN ('min_def', 'commandant') THEN
    v_portee := 'armee';
    SELECT array_agg(c.id ORDER BY c.id) INTO v_compagnies
      FROM public.compagnies_militaires c WHERE c.data->>'pays' = v_pays;

  ELSIF coalesce(v_poste,'') = 'capitaine' THEN
    v_portee := 'compagnie';
    SELECT array_agg(c.id ORDER BY c.id) INTO v_compagnies
      FROM public.compagnies_militaires c
     WHERE c.data->>'pays' = v_pays AND c.data->>'capitaineNom' = v_moi;

  ELSIF coalesce(v_poste,'') = 'lieutenant' THEN
    v_portee := 'section';
    SELECT array_agg(DISTINCT c.id), array_agg(DISTINCT s->>'id') INTO v_compagnies, v_sections
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
     WHERE c.data->>'pays' = v_pays AND s->>'lieutenantNom' = v_moi;

  ELSE
    -- Le soldat est dans la chaine de commandement, pas dans celle de l inspection.
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_chaine_d_inspection',
                              'poste', coalesce(v_poste, '(aucun)'));
  END IF;

  IF v_compagnies IS NULL OR array_length(v_compagnies, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'portee', v_portee, 'pays', v_pays,
                              'poste', v_poste, 'compagnies', '[]'::jsonb,
                              'sections', '[]'::jsonb, 'vide', true);
  END IF;

  RETURN jsonb_build_object('ok', true, 'portee', v_portee, 'pays', v_pays,
                            'poste', v_poste,
                            'compagnies', to_jsonb(v_compagnies),
                            'sections', coalesce(to_jsonb(v_sections), '[]'::jsonb),
                            'vide', false);
END;
$function$;

COMMENT ON FUNCTION public.militaire_inspection_perimetre() IS
  'Verdict serveur de l inspection des troupes : ouverte au Lieutenant, au Capitaine, au Commandant et au ministre de la Defense, refusee au soldat et au civil. Rend aussi le perimetre -- section, compagnie ou armee (arbitrage du 10 octobre 2026).';

REVOKE ALL ON FUNCTION public.militaire_inspection_perimetre() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_inspection_perimetre() TO authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_inspection_perimetre() TO service_role;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES. Une migration commite : elle ne prouve que du structurel, jamais du
-- comportemental (regle du depot, apprise au registre 562).
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : min_def n a plus le debit de la caserne, et le commandant l a toujours.
  SELECT count(*) INTO v_n FROM public.caisses_autorites
   WHERE motif = 'caserne-militaire' AND NOT est_prefixe
     AND postes_debit = ARRAY['commandant']::text[];
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 : autorite de la caisse de caserne non resserree'; END IF;

  -- P2 : la policy de lecture publique de l ordre de bataille n existe plus.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'compagnies_militaires'
     AND policyname = 'compagnies_lecture_mon_pays';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 : la policy de lecture est encore la'; END IF;

  -- P3 : plus aucun SELECT accorde a authenticated sur la table.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'compagnies_militaires'
     AND grantee = 'authenticated' AND privilege_type = 'SELECT';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3 : authenticated garde un SELECT sur compagnies_militaires'; END IF;

  -- P4 : les trois fonctions existent, sont SECURITY DEFINER, et ont leur search_path fige.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('caserne_reverser_au_ministere', 'militaire_compagnies_lisibles',
                       'militaire_inspection_perimetre')
     AND p.prosecdef
     AND array_to_string(coalesce(p.proconfig, '{}'), ',') LIKE '%search_path%';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P4 : les trois fonctions ne sont pas toutes SECURITY DEFINER a search_path fige (%)', v_n; END IF;

  -- P5 : elles sont appelables par le navigateur, et fermees a anon et a PUBLIC.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('caserne_reverser_au_ministere', 'militaire_compagnies_lisibles',
                       'militaire_inspection_perimetre')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P5 : droits d execution incorrects sur les trois fonctions (%)', v_n; END IF;

  -- P6 : le reversement exige bien le poste de Commandant, dans son CORPS.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'caserne_reverser_au_ministere'
     AND p.prosrc LIKE '%exiger_poste(''commandant'')%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 : le reversement ne verifie pas le poste de Commandant'; END IF;

  -- P7 : l inspection refuse explicitement hors chaine.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'militaire_inspection_perimetre'
     AND p.prosrc LIKE '%hors_chaine_d_inspection%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 : l inspection n a pas de refus nomme'; END IF;

  RAISE NOTICE 'Caserne : les 7 preuves structurelles passent.';
END $$;
