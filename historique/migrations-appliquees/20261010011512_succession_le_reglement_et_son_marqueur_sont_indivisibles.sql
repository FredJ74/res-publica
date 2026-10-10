-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010011512 (UTC), nom `succession_le_reglement_et_son_marqueur_sont_indivisibles`.
-- Le registre passe de 592 a 593 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 12023770ef0494ba3bd8af5c3cc26803, 12 373 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- SUCCESSION : LE REGLEMENT ET SON MARQUEUR SONT INDIVISIBLES
--
-- L'audit du 7 octobre disait « huit ecritures non atomiques, toutes avalees » : c'etait FAUX, et
l'audit canonique l'avait deja corrige. Le defaut residuel etait UNE FENETRE -- entre le credit
reel et la pose du marqueur, deux requetes HTTP. Un depassement du maxDuration laissait un
heritier credite sans `regle`, donc RECREDITE la nuit suivante : un heritage entier.
`succession_regler(succession)` met chaque mutation et son marqueur dans la meme transaction, et
preserve l'INDEPENDANCE des dispositions -- la valeur de l'architecture v4 -- en enfermant chaque
etape dans sa propre SOUS-TRANSACTION : un terrain introuvable annule sa seule etape. Le credit
de la caisse du notaire reutilise `caisse_institution_mouvement`.
--
-- ELLE VA PAR PAIRE AVEC : `api/cron-minuit.js` (`reglerSuccession`, qui ne garde que la lecture du verdict).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ===========================================================================
-- CHANTIER 6, FAMILLE D (2/2) -- LE REGLEMENT D'UNE SUCCESSION ET SON MARQUEUR
-- 10 octobre 2026
-- ===========================================================================
--
-- CE QUI ETAIT FAUX, EXACTEMENT. L'audit du 7 octobre disait « huit ecritures non atomiques,
-- toutes en .catch(() => null) » : c'etait FAUX, et l'audit canonique l'a corrige. reglerSuccession
-- est bien construite -- garde par disposition (`if (d.regle) continue`), chaque ecriture verifiee,
-- marqueur pose par disposition immediatement apres sa mutation, deux marqueurs fiscaux
-- independants, cloture en tout dernier.
--
-- Le defaut residuel est UNE FENETRE, PAS UNE PASSOIRE : entre le credit reel et la pose du
-- marqueur il reste DEUX requetes HTTP. Un depassement du maxDuration: 120 ou un plantage dans cet
-- intervalle laisse un beneficiaire credite sans `regle` -- donc recredite la nuit suivante.
-- Probabilite faible, montant eleve : un heritage entier, ou la part de l'Etat.
--
-- CE QUE CETTE PORTE FAIT, ET POURQUOI PAS actes_nocturnes. Le verrou juste existe deja et il est
-- METIER : dispositions[].regle, part_etat_reglee, part_notaire_reglee. Une cle de journee serait
-- un second verrou pour le meme travail -- et elle serait FAUSSE, car une succession dont une
-- etape a echoue doit pouvoir etre reprise des le lendemain. On ne force donc pas la brique : on
-- met la mutation et son marqueur DANS LA MEME TRANSACTION.
--
-- UNE SOUS-TRANSACTION PAR ETAPE, ET C'EST LE POINT D'ARCHITECTURE. L'architecture v4 des
-- successions tient a l'INDEPENDANCE des dispositions (« sur des dispositions independantes les
-- unes des autres », « deux marqueurs fiscaux independants l'un de l'autre : un des deux peut
-- reussir et l'autre echouer sans se confondre »). Une transaction unique tout-ou-rien
-- detruirait cette independance : un terrain introuvable bloquerait indefiniment le reglement de
-- l'argent. Chaque etape est donc enfermee dans un bloc BEGIN ... EXCEPTION, c'est-a-dire une
-- SOUS-TRANSACTION : son echec annule sa propre mutation ET son propre marqueur -- jamais l'un
-- sans l'autre -- et laisse les etapes deja reussies acquises. Un seul aller-retour HTTP la ou il
-- en fallait deux par etape.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. Memes mutations, meme repli de devolution a l'Etat quand le
-- beneficiaire a disparu entre l'acceptation et le reglement, meme 'PNJ' pour une entreprise sans
-- heritier, memes marqueurs, meme ordre, meme cloture en dernier. La phase de DECISION (chaine de
-- convocations, renonciation tacite, cascade) reste cote JS : elle est persistee AVANT, et aucune
-- mutation n'a lieu sur un etat non confirme en base.
--
-- BRIQUES REUTILISEES. Le credit de la caisse du notaire passe par caisse_institution_mouvement,
-- la primitive generique de mouvement de caisse de batiment (elle cree la caisse absente cote
-- serveur, exactement comme le sbInsert de repli qu'elle remplace). Le credit de reserveJour
-- reprend l'idiome etabli par appliquer_taxe_transaction, faute de brique dediee -- fait mesure :
-- aucune fonction generique de credit de budget national n'existe, onze fonctions ecrivent cette
-- table directement.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.succession_regler(p_succession_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  s public.successions; v_disp jsonb; v_nouv jsonb; v_d jsonb; v_i integer;
  v_benef text; v_reglees integer := 0; v_echecs text[] := '{}'; v_fisc text[] := '{}';
  v_cloturee boolean := false; v_n integer; v_tid text; v_etat jsonb; v_nat jsonb;
  v_ok boolean; v_r jsonb;
BEGIN
  SELECT * INTO s FROM public.successions WHERE id = p_succession_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_introuvable');
  END IF;
  IF s.statut <> 'en_attente' THEN
    -- Pas une erreur : la cloture a deja eu lieu. Le rejeu ne doit rien faire et le dire.
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_resolue', 'cloturee', false);
  END IF;

  v_disp := coalesce(s.dispositions, '[]'::jsonb);

  FOR v_i IN 0 .. greatest(0, jsonb_array_length(v_disp) - 1) LOOP
    v_d := v_disp -> v_i;
    CONTINUE WHEN v_d IS NULL;
    CONTINUE WHEN coalesce((v_d ->> 'regle')::boolean, false);
    -- Une disposition sans decision tranchee n'est pas reglable. L'appelant ne presente la
    -- succession que lorsque toutes le sont ; on refuse plutot que de lever.
    IF v_d -> 'resultat' IS NULL OR jsonb_typeof(v_d -> 'resultat') = 'null' THEN
      v_echecs := array_append(v_echecs, v_i::text || ':decision_absente');
      CONTINUE;
    END IF;
    v_benef := nullif(v_d -> 'resultat' ->> 'beneficiaire', '');

    BEGIN
      IF (v_d ->> 'type') = 'terrain' THEN
        SELECT t.id, t.data::jsonb INTO v_tid, v_etat FROM public.terrains_etat t
         WHERE t.country = s.country AND t.building_id = (v_d ->> 'id') FOR UPDATE;
        IF v_tid IS NULL THEN RAISE EXCEPTION 'terrain_introuvable'; END IF;
        v_etat := jsonb_set(coalesce(v_etat,'{}'::jsonb), '{proprietaire}',
                            coalesce(to_jsonb(v_benef), 'null'::jsonb), true);
        v_etat := jsonb_set(v_etat, '{coproprietaire}', 'null'::jsonb, true);
        v_etat := jsonb_set(v_etat, '{succession_gel}', 'null'::jsonb, true);
        UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = v_tid;

      ELSIF (v_d ->> 'type') = 'entreprise' THEN
        SELECT e.data INTO v_etat FROM public.entreprises e
         WHERE e.id = (v_d ->> 'id') FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'entreprise_introuvable'; END IF;
        v_etat := jsonb_set(coalesce(v_etat,'{}'::jsonb), '{proprietaire}',
                            to_jsonb(coalesce(v_benef, 'PNJ')), true);
        v_etat := jsonb_set(v_etat, '{succession_gel}', 'null'::jsonb, true);
        UPDATE public.entreprises SET data = v_etat, updated_at = now() WHERE id = (v_d ->> 'id');

      ELSIF (v_d ->> 'type') = 'argent' AND coalesce((v_d ->> 'part_nette')::numeric, 0) > 0 THEN
        v_n := 0;
        IF v_benef IS NOT NULL THEN
          UPDATE public.personnages
             SET arg = coalesce(arg, 0) + (v_d ->> 'part_nette')::numeric
           WHERE name = v_benef;
          GET DIAGNOSTICS v_n = ROW_COUNT;
        END IF;
        -- Devolution a l'Etat : d'emblee (chaine epuisee) ou en repli si le beneficiaire a
        -- disparu entre l'acceptation et le reglement, plutot que de laisser la somme disparaitre.
        IF v_n <> 1 THEN
          SELECT b.data INTO v_nat FROM public.budgets_nationaux b
           WHERE b.id = s.country FOR UPDATE;
          IF NOT FOUND THEN RAISE EXCEPTION 'budget_national_introuvable'; END IF;
          UPDATE public.budgets_nationaux
             SET data = jsonb_set(coalesce(v_nat,'{}'::jsonb), '{reserveJour}',
                   to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0)
                            + (v_d ->> 'part_nette')::numeric), true),
                 updated_at = now()
           WHERE id = s.country;
        END IF;
      END IF;

      -- LE MARQUEUR, DANS LA MEME SOUS-TRANSACTION QUE LA MUTATION. C'est tout l'objet de ce lot.
      v_nouv := jsonb_set(v_disp, ARRAY[v_i::text, 'regle'], 'true'::jsonb, true);
      UPDATE public.successions SET dispositions = v_nouv WHERE id = p_succession_id;
      v_disp := v_nouv;
      v_reglees := v_reglees + 1;
    EXCEPTION WHEN others THEN
      -- La sous-transaction a annule la mutation ET le marqueur. v_disp n'a pas ete reaffecte.
      v_echecs := array_append(v_echecs, v_i::text || ':' || sqlerrm);
    END;
  END LOOP;

  IF coalesce(s.droits_total, 0) > 0 THEN
    IF NOT coalesce(s.part_etat_reglee, false) THEN
      BEGIN
        SELECT b.data INTO v_nat FROM public.budgets_nationaux b
         WHERE b.id = s.country FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'budget_national_introuvable'; END IF;
        UPDATE public.budgets_nationaux
           SET data = jsonb_set(coalesce(v_nat,'{}'::jsonb), '{reserveJour}',
                 to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0)
                          + coalesce(s.part_etat, 0)), true),
               updated_at = now()
         WHERE id = s.country;
        UPDATE public.successions SET part_etat_reglee = true WHERE id = p_succession_id;
        v_fisc := array_append(v_fisc, 'etat');
      EXCEPTION WHEN others THEN
        v_echecs := array_append(v_echecs, 'etat:' || sqlerrm);
      END;
    END IF;
    IF NOT coalesce(s.part_notaire_reglee, false) THEN
      BEGIN
        PERFORM set_config('rp.caisse_interne', 'on', true);
        v_r := public.caisse_institution_mouvement(s.country || '_office-notarial',
                                                   coalesce(s.part_notaire, 0));
        v_ok := coalesce((v_r ->> 'ok')::boolean, false);
        IF NOT v_ok THEN RAISE EXCEPTION 'caisse_notaire:%', coalesce(v_r ->> 'raison','?'); END IF;
        UPDATE public.successions SET part_notaire_reglee = true WHERE id = p_succession_id;
        v_fisc := array_append(v_fisc, 'notaire');
      EXCEPTION WHEN others THEN
        v_echecs := array_append(v_echecs, 'notaire:' || sqlerrm);
      END;
    END IF;
  END IF;

  -- CLOTURE EN TOUT DERNIER, sur l'etat RELU : statut='resolue' n'est pas une protection contre le
  -- rejeu, seulement un marqueur de fermeture. Le compare-and-swap sur statut la rend unique.
  SELECT * INTO s FROM public.successions WHERE id = p_succession_id;
  IF (SELECT bool_and(coalesce((e ->> 'regle')::boolean, false))
        FROM jsonb_array_elements(coalesce(s.dispositions, '[]'::jsonb)) e) IS NOT FALSE
     AND (coalesce(s.droits_total, 0) = 0
          OR (coalesce(s.part_etat_reglee,false) AND coalesce(s.part_notaire_reglee,false))) THEN
    UPDATE public.successions SET statut = 'resolue', resolved_at = now()
     WHERE id = p_succession_id AND statut = 'en_attente';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_cloturee := (v_n = 1);
  END IF;

  RETURN jsonb_build_object('ok', true, 'dispositions_reglees', v_reglees,
    'fiscalite', to_jsonb(v_fisc), 'cloturee', v_cloturee, 'echecs', to_jsonb(v_echecs));
END; $fn$;

REVOKE ALL ON FUNCTION public.succession_regler(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.succession_regler(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.succession_regler(text) TO service_role;

DO $$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef('public.succession_regler(text)'::regprocedure) INTO v_def;
  IF v_def NOT LIKE '%SECURITY DEFINER%' THEN RAISE EXCEPTION 'P1 : pas SECURITY DEFINER'; END IF;
  IF coalesce(array_to_string((SELECT proacl::text[] FROM pg_proc p JOIN pg_namespace n
       ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='succession_regler'),
       ' | '), '(defaut)') <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P2 : la porte n''est pas reservee au serveur'; END IF;
  -- P3 : TROIS sous-transactions, une par famille d'etape (disposition, part Etat, part notaire).
  IF (length(v_def) - length(replace(v_def, 'EXCEPTION WHEN others THEN', ''))) / 26 <> 3 THEN
    RAISE EXCEPTION 'P3 : % sous-transaction(s) au lieu de 3',
      (length(v_def) - length(replace(v_def, 'EXCEPTION WHEN others THEN', ''))) / 26; END IF;
  -- P4 : la brique de caisse est reutilisee, pas reecrite.
  IF v_def NOT LIKE '%caisse_institution_mouvement%' THEN
    RAISE EXCEPTION 'P4 : la primitive de caisse n''est pas reutilisee'; END IF;
  IF v_def LIKE '%INSERT INTO public.caisses_batiments%' THEN
    RAISE EXCEPTION 'P4 : une seconde maniere de crediter une caisse a ete ecrite'; END IF;
  -- P5 : la cloture est un compare-and-swap, jamais une ecriture seche.
  IF v_def NOT LIKE '%WHERE id = p_succession_id AND statut = ''en_attente''%' THEN
    RAISE EXCEPTION 'P5 : la cloture n''est pas un compare-and-swap'; END IF;
  -- P6 : aucune succession n'est en cours en base -- la bancarisation ne touche donc personne.
  RAISE NOTICE 'succession_regler : 5 preuves structurelles conformes ; % succession(s) en attente.',
    (SELECT count(*) FROM public.successions WHERE statut = 'en_attente');
END $$;