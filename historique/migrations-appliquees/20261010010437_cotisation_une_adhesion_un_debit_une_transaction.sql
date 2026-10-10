-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010010437 (UTC), nom `cotisation_une_adhesion_un_debit_une_transaction`.
-- Le registre passe de 589 a 590 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 942a41323777e493f58f60c499667e3f, 10 962 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- COTISATION D'ORGANISATION : UNE ADHESION, UN DEBIT, UNE TRANSACTION
--
-- `cotisation_renouveler(orga, membre, saison)` verrouille l'organisation et la fiche du membre,
puis debite 50 FR, marque l'adhesion et credite la contrepartie ENSEMBLE -- ou rien. La dette
que le code consignait lui-meme le 7 octobre (« deux ecritures sur deux tables ») est payee.
Pas d'acte nocturne : le marqueur metier (`derniereCotisationSaison` /
`derniereCotisationDate`) est deja le verrou d'idempotence.
--
-- ELLE VA PAR PAIRE AVEC : `api/cron-minuit.js` (`renouvellerCotisationsOrganisations` ; suppression de
-- `crediterBudgetClubServeur`, partie avec son unique appelant).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ===========================================================================
-- CHANTIER 6, FAMILLE D (1/2) -- LA COTISATION D'ORGANISATION EST UN SEUL ACTE
-- 10 octobre 2026
-- ===========================================================================
--
-- CE QUI ETAIT FAUX. renouvellerCotisationsOrganisations (api/cron-minuit.js) debitait le
-- personnage par un sbUpdate('personnages'), PUIS creditait la contrepartie -- la caisse du club
-- de supporters par crediterBudgetClubServeur (lecture-modification-ecriture de budgets_clubs avec
-- catch avale), ou la caisse du syndicat dans le blob de l'organisation -- PUIS ecrivait le blob.
-- Trois requetes HTTP pour un seul acte economique. Le code le reconnaissait lui-meme : « Debiter
-- un personnage et marquer son adhesion sont deux ecritures sur deux tables : les rendre atomiques
-- demande une RPC. Dette consignee. »
--
-- Consequences reelles d'une panne au milieu : 50 FR quittaient un personnage sans arriver nulle
-- part, ou l'adhesion restait non marquee -- donc redebitee a la passe suivante.
--
-- POURQUOI PAS actes_nocturnes ICI. La brique protege ce qu'une JOURNEE ne doit produire qu'une
-- fois. Le marqueur d'idempotence existe deja et il est METIER : derniereCotisationSaison pour les
-- supporters, derniereCotisationDate pour les autres. C'est l'appelant qui decide qui est du ;
-- cette porte, elle, rend chaque acte ATOMIQUE. Ajouter un acte nocturne par (orga, membre)
-- dupliquerait un verrou qui existe.
--
-- CE QUE LA PORTE GARANTIT. En une transaction : l'organisation est verrouillee FOR UPDATE, le
-- membre est localise dans data->'membres', sa fiche est verrouillee FOR UPDATE, puis
--   -- soit RESILIATION (personnage absent ou arg < 50) : le membre quitte la liste, AUCUN debit,
--      AUCUNE dette creee, et un courrier le dit -- par mail_systeme_poser_interne, l'unique
--      ecrivain de public.mails, donc la notification ne porte pas l'autorite de l'acte ;
--   -- soit RENOUVELLEMENT : debit de 50 FR, marquage de l'adhesion, et credit de la contrepartie
--      (caisse du club resolu par clubs_sportifs_regles pour les supporters, caisse de
--      l'organisation sinon). Les quatre ecritures tombent ou tiennent ensemble.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. 50 FR, les deux branches, les deux marqueurs, le plafond de
-- 50 lignes d'historique du budget de club et le correctif « la cotisation d'un syndicat alimente
-- SA caisse » sont repris tels quels. Une organisation de supporters dont la ville n'a pas de club
-- continue de ne crediter personne -- c'est le comportement existant, pas une invention.
--
-- EPROUVEE EN TRANSACTION ANNULEE : 16 epreuves vertes (refus d'organisation inconnue et de membre
-- inconnu sans ecriture, syndicat debite+credite, insolvable resilie sans debit avec son courrier,
-- saison exigee pour les supporters, caisse du club creditee, saison marquee).
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.cotisation_renouveler(
  p_orga_id text, p_membre text, p_saison integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_data jsonb; v_membres jsonb; v_i integer; v_trouve integer := -1;
  v_type text; v_pays text; v_ville text; v_nom_orga text;
  v_arg numeric; v_existe boolean; v_club text; v_bc jsonb; v_hist jsonb;
  v_montant numeric := 50;
BEGIN
  SELECT o.data::jsonb INTO v_data FROM public.organisations o
   WHERE o.id = p_orga_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok',false,'action','organisation_introuvable'); END IF;
  v_membres := CASE WHEN jsonb_typeof(v_data->'membres')='array' THEN v_data->'membres' ELSE '[]'::jsonb END;
  FOR v_i IN 0 .. greatest(0, jsonb_array_length(v_membres) - 1) LOOP
    IF (v_membres -> v_i ->> 'nom') = p_membre THEN v_trouve := v_i; EXIT; END IF;
  END LOOP;
  IF v_trouve < 0 THEN RETURN jsonb_build_object('ok',false,'action','membre_introuvable'); END IF;
  v_type := v_data ->> 'type'; v_pays := v_data ->> 'country'; v_ville := v_data ->> 'city';
  v_nom_orga := coalesce(v_data ->> 'nom', p_orga_id);

  SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
   WHERE name = p_membre FOR UPDATE;

  IF NOT coalesce(v_existe,false) OR v_arg < v_montant THEN
    -- RESILIATION : le membre quitte la liste, aucune dette n'est creee. Le courrier passe par
    -- l'unique ecrivain de public.mails ; il notifie, il ne decide pas.
    v_data := jsonb_set(v_data, '{membres}', v_membres - v_trouve);
    UPDATE public.organisations SET data = v_data::text WHERE id = p_orga_id;
    PERFORM public.mail_systeme_poser_interne(v_nom_orga, p_membre,
      'Fin d''adhésion — cotisation non renouvelée',
      'Votre adhésion à "' || v_nom_orga || '" a pris fin automatiquement : la cotisation de '
      || v_montant::text || ' FR n''a pas pu être prélevée. Aucune dette n''est créée.',
      to_char(now() AT TIME ZONE 'Europe/Paris','YYYY-MM-DD"T"HH24:MI:SS'));
    RETURN jsonb_build_object('ok',true,'action','resiliation','membre',p_membre);
  END IF;

  UPDATE public.personnages SET arg = v_arg - v_montant WHERE name = p_membre;

  IF v_type = 'supporters' THEN
    IF p_saison IS NULL THEN
      RAISE EXCEPTION 'cotisation_renouveler : une organisation de supporters exige la saison';
    END IF;
    v_membres := jsonb_set(v_membres, ARRAY[v_trouve::text,'derniereCotisationSaison'], to_jsonb(p_saison));
    SELECT c.club_id INTO v_club FROM public.clubs_sportifs_regles c
     WHERE c.country = v_pays AND c.city = v_ville;
    IF v_club IS NOT NULL THEN
      SELECT b.data INTO v_bc FROM public.budgets_clubs b WHERE b.id = v_club FOR UPDATE;
      IF v_bc IS NULL THEN
        v_bc := jsonb_build_object('clubId', v_club, 'caisse', 0, 'historique', '[]'::jsonb,
                 'derniereSubventionJour', NULL,
                 'salaires', jsonb_build_object('titulaire',100,'remplacant',50,'primeVictoire',150));
      END IF;
      v_hist := CASE WHEN jsonb_typeof(v_bc->'historique')='array' THEN v_bc->'historique' ELSE '[]'::jsonb END;
      v_hist := v_hist || jsonb_build_array(jsonb_build_object('jour', NULL, 'montant', v_montant,
                  'motif', 'Cotisation supporter (renouvellement)'));
      IF jsonb_array_length(v_hist) > 50 THEN
        v_hist := (SELECT jsonb_agg(e) FROM (
          SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
           ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) z);
      END IF;
      v_bc := v_bc || jsonb_build_object(
                'caisse', greatest(0, coalesce(nullif(v_bc->>'caisse','')::numeric,0) + v_montant),
                'historique', v_hist);
      INSERT INTO public.budgets_clubs (id, data, updated_at) VALUES (v_club, v_bc, now())
      ON CONFLICT (id) DO UPDATE SET data = excluded.data, updated_at = now();
    END IF;
  ELSE
    v_membres := jsonb_set(v_membres, ARRAY[v_trouve::text,'derniereCotisationDate'],
                   to_jsonb(to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
    -- Correctif anterieur conserve : la cotisation d'un syndicat alimente SA caisse, sinon les
    -- 50 FR quittaient le personnage sans arriver nulle part.
    v_data := jsonb_set(v_data, '{caisse}',
                to_jsonb(coalesce(nullif(v_data->>'caisse','')::numeric,0) + v_montant), true);
  END IF;

  v_data := jsonb_set(v_data, '{membres}', v_membres);
  UPDATE public.organisations SET data = v_data::text WHERE id = p_orga_id;
  RETURN jsonb_build_object('ok',true,'action','renouvellement','membre',p_membre,
                            'montant',v_montant,'club',v_club);
END; $fn$;

REVOKE ALL ON FUNCTION public.cotisation_renouveler(text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cotisation_renouveler(text, text, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cotisation_renouveler(text, text, integer) TO service_role;

-- --- PREUVES STRUCTURELLES (une migration commite les effets de bord de ses preuves : rien ici
-- --- n'execute la porte) --------------------------------------------------------------------
DO $$
DECLARE v_acl text; v_def text; v_prop text; v_ident text;
BEGIN
  -- pg_get_function_identity_arguments rend les NOMS des parametres, pas seulement les types :
  -- mesure faite en base, l'hypothese inverse etait fausse.
  SELECT coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)'), pg_get_functiondef(p.oid),
         pg_get_userbyid(p.proowner), pg_get_function_identity_arguments(p.oid)
    INTO v_acl, v_def, v_prop, v_ident
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'cotisation_renouveler';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_ident <> 'p_orga_id text, p_membre text, p_saison integer' THEN
    RAISE EXCEPTION 'P1b : signature inattendue -- %', v_ident; END IF;
  IF v_acl <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P2 : la porte n''est pas reservee au serveur -- %', v_acl; END IF;
  IF v_def NOT LIKE '%SECURITY DEFINER%' THEN RAISE EXCEPTION 'P3 : pas SECURITY DEFINER'; END IF;
  IF v_prop <> 'postgres' THEN RAISE EXCEPTION 'P4 : proprietaire %', v_prop; END IF;

  -- P5 : les trois verrous et l'unique ecrivain des courriers sont bien dans le corps.
  IF v_def NOT LIKE '%FROM public.organisations o%FOR UPDATE%' THEN
    RAISE EXCEPTION 'P5a : l''organisation n''est pas verrouillee'; END IF;
  IF v_def NOT LIKE '%FROM public.personnages%FOR UPDATE%' THEN
    RAISE EXCEPTION 'P5b : la fiche du membre n''est pas verrouillee'; END IF;
  IF v_def NOT LIKE '%FROM public.budgets_clubs b WHERE b.id = v_club FOR UPDATE%' THEN
    RAISE EXCEPTION 'P5c : le budget du club n''est pas verrouille'; END IF;
  IF v_def NOT LIKE '%mail_systeme_poser_interne%' THEN
    RAISE EXCEPTION 'P5d : le courrier ne passe pas par l''unique ecrivain'; END IF;

  -- P6 : le referentiel qui resout le club existe toujours, avec ses colonnes.
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='clubs_sportifs_regles'
                    AND column_name IN ('club_id','country','city')
                 GROUP BY table_name HAVING count(*) = 3) THEN
    RAISE EXCEPTION 'P6 : clubs_sportifs_regles ne resout plus (country, city) -> club_id'; END IF;

  -- P7 : aucune donnee de banc n'a survecu (le banc tournait en transaction annulee).
  IF EXISTS (SELECT 1 FROM public.organisations WHERE id LIKE 'zzo-%') THEN
    RAISE EXCEPTION 'P7 : une organisation de banc a survecu'; END IF;
  IF EXISTS (SELECT 1 FROM public.mails WHERE subject = 'Fin d''adhésion — cotisation non renouvelée') THEN
    RAISE EXCEPTION 'P7 : un courrier de banc a survecu'; END IF;

  RAISE NOTICE 'cotisation_renouveler : 8 preuves structurelles conformes.';
END $$;