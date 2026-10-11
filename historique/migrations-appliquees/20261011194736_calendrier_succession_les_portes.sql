-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011194736 (UTC), nom
-- `calendrier_succession_les_portes`.
-- Le registre passe de 663 a 664 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 db38863df79cbfed37368692220fc5ca, 17020 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LES PORTES DU CALENDRIER DE SUCCESSION (1/4)
--
-- L'ARBITRAGE : un mandat dure cinq semaines, six s'il faut un second tour, et il ne doit JAMAIS
-- exister de vacance institutionnelle du seul fait qu'une election est en cours. Le titulaire
-- sortant garde ses pouvoirs jusqu'a l'instant exact ou le resultat definitif designe son
-- successeur ; a cet instant la succession est immediate.
--
-- CE QUE L'AUDIT DU CALENDRIER AVAIT MESURE, SUR DONNEES REELLES. Au passage de `dateFinMandat`,
-- le cron remplacait le blob du cycle par un cycle de candidatures frais. Comme
-- `poste_est_atteste` ne lit que `eluId` / `elus`, cette seule ecriture faisait disparaitre le
-- titulaire -- et le successeur n'etait proclame que QUATORZE JOURS plus tard. Un mandat de cinq
-- semaines revenait donc toutes les sept, et le poste etait vide deux semaines sur sept.
--
-- CETTE MIGRATION OUVRE LES PORTES QUE LA PHASE DU MANDAT FERMAIT. `phase` ne decrit plus que le
-- SCRUTIN DE SUCCESSION ; le mandat en exercice coexiste avec lui dans le meme blob.
--   . `candidatures_cloture` : la seule borne est le GEL du lundi 00:01 de la derniere semaine.
--     Les candidatures sont donc ouvertes PENDANT les quatre premieres semaines du mandat, ce
--     qui etait exactement interdit avant. Et le declencheur ESTAMPILLE desormais la candidature
--     du scrutin vise, relu sur le cycle -- sans quoi les candidats d'un scrutin passe seraient
--     reinjectes dans le suivant, un cycle n'etant plus detruit entre deux.
--   . `election_voter` : le retour anticipe « un mandat est en cours, donc le vote est ferme »
--     est retire. Sous le nouveau calendrier un titulaire existe TOUJOURS : le garder aurait
--     rendu tout vote impossible. Et le bulletin porte son TOUR, ce qui ferme au passage un
--     defaut prealable -- la cle `pays_cle_votant` interdisait de voter au SECOND tour.
--   . `election_resultats_consigner` : la garde passe de `resultatsTraites` a `dateResultats`,
--     parce qu'une prise de fonctions rouvre immediatement le scrutin suivant et remet donc ce
--     drapeau a faux. `dateResultats` avance strictement a chaque proclamation.
--
-- AUCUNE REGLE DE MAJORITE, DE SECOND TOUR, DE VOTE BLANC NI DE FILET PNJ N'EST TOUCHEE.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CALENDRIER ELECTORAL COMMUN -- UNE SUCCESSION NE VACANCE PLUS LE POSTE (1/3 : LES PORTES)
-- 11 octobre 2026
--
-- LA REGLE ARBITREE. Un mandat dure cinq semaines, six s'il faut un second tour. Il ne doit
-- JAMAIS exister de vacance institutionnelle du seul fait qu'une election est en cours : le
-- titulaire sortant garde ses pouvoirs jusqu'a l'instant exact ou le resultat definitif designe
-- son successeur, et la succession est immediate a cet instant.
--
-- CE QUE L'AUDIT AVAIT MESURE. Au passage de `dateFinMandat`, le cron remplacait le blob du
-- cycle par un cycle de candidatures frais. Comme `poste_est_atteste` ne lit que `eluId` /
-- `elus`, cette seule ecriture faisait disparaitre le titulaire -- et le successeur n'etait
-- proclame que QUATORZE JOURS plus tard. Quatre postes electifs, a chaque alternance.
--
-- CE QUE CETTE MIGRATION CHANGE EN BASE. Le moteur de calendrier vit dans api/cron-minuit.js ;
-- ici ne sont touchees que les PORTES qui lisaient la phase du mandat comme « aucune election en
-- cours ». Cette phase n'existe plus : `phase` ne decrit desormais que le SCRUTIN DE SUCCESSION,
-- et le mandat en exercice coexiste avec lui dans le meme blob.
--
-- AUCUNE REGLE DE MAJORITE, DE SECOND TOUR, DE VOTE BLANC NI DE FILET PNJ N'EST TOUCHEE ICI.

-- ============================================================================================
-- 0. DEUX COLONNES, PARCE QU'UN CYCLE N'EST PLUS DETRUIT ENTRE DEUX SCRUTINS
-- ============================================================================================
-- C'EST LA CONSEQUENCE LA PLUS SILENCIEUSE DU CORRECTIF, ET ELLE AURAIT FAUSSE DES RESULTATS.
-- `candidatures` et `votes_electoraux` ne portaient que (pays, poste, ville) : elles
-- identifiaient un POSTE, jamais un SCRUTIN. Tant que le cron detruisait le blob a chaque
-- renouvellement, le rapprochement restait approximativement juste. Maintenant qu'un cycle
-- traverse les scrutins, `syncCyclesDepuisSupabase` reinjecterait dans le scrutin EN COURS les
-- candidats et les bulletins des scrutins precedents -- et le depouillement les compterait.
--
-- ET ELLES FERMENT UN DEFAUT QUI EXISTAIT DEJA. L'identifiant d'un bulletin valait
-- `pays_cle_votant`, sans aucune composante de tour. Un electeur ayant vote au premier tour
-- obtenait donc `deja_vote` au SECOND : personne n'a jamais pu voter a un second tour. Le tour
-- entre dans la cle, et le defaut tombe avec.
ALTER TABLE public.candidatures      ADD COLUMN IF NOT EXISTS cle_scrutin bigint;
ALTER TABLE public.votes_electoraux  ADD COLUMN IF NOT EXISTS tour bigint;

COMMENT ON COLUMN public.candidatures.cle_scrutin IS
  'Scrutin vise : cycles_electoraux.data->>dateDebutCandidatures en ms. Pose par le declencheur candidatures_cloture, jamais par le client. NULL sur les lignes anterieures au 11 octobre 2026.';
COMMENT ON COLUMN public.votes_electoraux.tour IS
  'Tour vise : cycles_electoraux.data->>dateVote en ms, meme cle que elections_tracts_pnj.tour. Pose par election_voter. NULL sur les lignes anterieures au 11 octobre 2026.';

CREATE INDEX IF NOT EXISTS candidatures_par_scrutin
  ON public.candidatures (country, poste_id, city, cle_scrutin);
CREATE INDEX IF NOT EXISTS votes_electoraux_par_tour
  ON public.votes_electoraux (country, poste_id, city, tour);

-- ============================================================================================
-- 1. LES CANDIDATURES NE SONT PLUS FERMEES PAR LE MANDAT
-- ============================================================================================
-- LA SEULE BORNE EST LE GEL. `dateDebutCampagne` est le lundi 00:01 de la derniere semaine du
-- mandat : avant lui on se porte candidat a la succession du titulaire en exercice, apres lui
-- la liste est figee. Les deux conditions retirees portaient sur la phase :
--   . celle du mandat interdisait toute candidature pendant les cinq semaines -- c'est
--     precisement l'ancienne regle que l'arbitrage supprime ;
--   . celle de la vacance interdisait de se porter candidat a un poste SANS titulaire, ce qui est
--     l'inverse du but. Ni l'une ni l'autre n'est plus jamais ecrite par le moteur.
-- `resultatsTraites` reste : un scrutin deja depouille n'accepte plus de candidat.
CREATE OR REPLACE FUNCTION public.candidatures_cloture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data text;
  v_d    jsonb;
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  SELECT data INTO v_data FROM public.cycles_electoraux
   WHERE id = NEW.country || '_' || NEW.poste_id || CASE WHEN NEW.city IS NOT NULL THEN '_' || NEW.city ELSE '' END;
  IF NOT FOUND THEN RETURN NEW; END IF;          -- cycle cree par le client juste avant la candidature
  BEGIN v_d := v_data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number' AND v_ms >= (v_d ->> 'dateDebutCampagne')::numeric) THEN
    RAISE EXCEPTION 'candidatures_closes' USING HINT = 'Les candidatures a ce scrutin sont closes (gel du lundi 00:01 de la derniere semaine du mandat).';
  END IF;
  -- ET LA CANDIDATURE EST ESTAMPILLEE DU SCRUTIN VISE, PAR LE SERVEUR (11 octobre 2026).
  -- Un cycle n'etant plus detruit entre deux scrutins, la table `candidatures` n'est plus
  -- distinguable par (pays, poste, ville) : sans cette colonne, les candidats d'un scrutin passe
  -- seraient reinjectes dans le suivant par syncCyclesDepuisSupabase. La valeur n'est pas celle
  -- que le client annonce : elle est RELUE sur le cycle, ici meme, dans la transaction.
  IF jsonb_typeof(v_d -> 'dateDebutCandidatures') = 'number' THEN
    NEW.cle_scrutin := (v_d ->> 'dateDebutCandidatures')::numeric::bigint;
  END IF;
  RETURN NEW;
END;
$function$;

-- ============================================================================================
-- 2. LE MANDAT NE FERME PLUS LA FENETRE DE VOTE
-- ============================================================================================
-- Le retour anticipe « vote_ferme, un mandat est en cours » etait la transcription exacte du
-- court-circuit client : tant qu'un titulaire etait en fonction, aucun vote n'etait possible.
-- C'est devenu l'inverse de la regle -- on vote TOUJOURS pendant le mandat du sortant, le
-- dernier dimanche. La fenetre est desormais la seule borne, et elle n'a pas change :
-- [dateVote, dateResultats), dimanche 00:01 -> lundi 00:00 de Paris.
CREATE OR REPLACE FUNCTION public.election_voter(p_pays text, p_poste_id text, p_ville text, p_candidat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi      text;
  v_pays     text := lower(btrim(coalesce(p_pays, '')));
  v_poste    text := btrim(coalesce(p_poste_id, ''));
  v_cand     text := btrim(coalesce(p_candidat, ''));
  v_local    boolean;
  v_ville    text;
  v_cle      text;
  v_id_cycle text;
  v_brut     text;
  v_cycle    jsonb;
  v_ms       numeric := floor(extract(epoch from now()) * 1000);
  v_domicile text;
  v_n        integer;
BEGIN
  -- L'IDENTITE N'EST PAS UN PARAMETRE. L'appelant ne dit pas qui vote : le serveur le lit.
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_pays = '' OR v_poste = '' OR v_cand = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- LA LOCALITE DU POSTE VIENT DU REFERENTIEL, pas du navigateur :
  -- postes_electifs_regles.niveau = 'ville' est exactement la regle de posteEstLocal(). La cle
  -- du scrutin et l'identifiant du bulletin s'en deduisent, comme getCleCycle() cote client.
  SELECT (niveau = 'ville') INTO v_local FROM public.postes_electifs_regles WHERE poste_id = v_poste;
  IF v_local IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;
  v_ville    := CASE WHEN v_local AND coalesce(btrim(p_ville), '') <> '' THEN btrim(p_ville) END;
  v_cle      := CASE WHEN v_ville IS NOT NULL THEN v_poste || '_' || v_ville ELSE v_poste END;
  v_id_cycle := v_pays || '_' || v_cle;

  -- DOMICILE : meme regle que le client -- domicile.country, a defaut le pays du personnage.
  SELECT coalesce(nullif(d.domicile ->> 'country', ''), d.country) INTO v_domicile
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_domicile IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;

  -- VERROU DU CYCLE. C'est lui qui serialise deux electeurs simultanes : le blob etant
  -- relu-modifie-reecrit, le second ecrasait sinon le bulletin du premier.
  SELECT data INTO v_brut FROM public.cycles_electoraux WHERE id = v_id_cycle FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_absent');
  END IF;
  BEGIN
    v_cycle := v_brut::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_illisible');
  END;
  IF jsonb_typeof(v_cycle) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_illisible');
  END IF;

  -- LA FENETRE DE VOTE, ET ELLE SEULE (11 octobre 2026). Le retour anticipe « un mandat est en
  -- cours, donc le vote est ferme » est RETIRE : depuis l'arbitrage du calendrier commun, on vote
  -- toujours pendant le mandat du sortant -- le dernier dimanche de ce mandat. Un titulaire en
  -- fonction n'est plus un motif de refus, c'est l'etat normal d'un scrutin de succession.
  -- Les bornes n'ont pas change : dimanche 00:01 -> lundi 00:00, heure de Paris, en millisecondes
  -- JavaScript. `resultatsTraites` ferme un scrutin deja depouille.
  IF COALESCE((v_cycle ->> 'resultatsTraites')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme', 'phase', 'depouille');
  END IF;
  IF jsonb_typeof(v_cycle -> 'dateVote') <> 'number'
     OR jsonb_typeof(v_cycle -> 'dateResultats') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_sans_calendrier');
  END IF;
  IF v_ms < (v_cycle ->> 'dateVote')::numeric
     OR v_ms >= (v_cycle ->> 'dateResultats')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme');
  END IF;

  -- LE CANDIDAT DOIT EXISTER, ou etre le vote blanc -- qui n'est jamais un candidat fictif
  -- ajoute a la liste, mais un choix reel compte a part par le depouillement.
  IF v_cand <> 'BLANC' AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(
         CASE WHEN jsonb_typeof(v_cycle -> 'candidats') = 'array' THEN v_cycle -> 'candidats' ELSE '[]'::jsonb END
       ) c WHERE c ->> 'nom' = v_cand) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_inconnu');
  END IF;

  -- LE BULLETIN EST LA REVENDICATION. Sa cle primaire porte (pays, cle du scrutin, votant) :
  -- un second bulletin du meme electeur pour le meme scrutin obtient un conflit et ne produit
  -- rien. Ce n'est pas un marqueur qu'une ecriture avalee peut perdre.
  --
  -- ET ELLE PORTE DESORMAIS LE TOUR, PAS SEULEMENT LE POSTE (11 octobre 2026). Un cycle n'etant
  -- plus detruit entre deux scrutins, la cle `pays_cle_votant` aurait interdit a un electeur de
  -- voter une seconde fois au scrutin SUIVANT du meme poste. Elle le lui interdisait deja au
  -- SECOND TOUR du meme scrutin, ou le blob remet `votes` a zero mais ou cette ligne survivait :
  -- personne n'a jamais pu voter a un second tour. `dateVote` identifie le tour en cours, et
  -- c'est la meme cle que `elections_tracts_pnj.tour` emploie deja.
  INSERT INTO public.votes_electoraux (id, country, poste_id, city, votant, candidat, tour, created_at)
  VALUES (v_pays || '_' || v_cle || '_' || v_moi || '_' || trim(to_char((v_cycle ->> 'dateVote')::numeric, 'FM999999999999999')),
          v_pays, v_poste, v_ville, v_moi, v_cand,
          (v_cycle ->> 'dateVote')::numeric::bigint, now())
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote');
  END IF;

  -- LE BLOB EST CE QUE LE DEPOUILLEMENT COMPTE, et il est ecrit DANS LA MEME TRANSACTION que le
  -- bulletin.
  UPDATE public.cycles_electoraux
     SET data = (v_cycle || jsonb_build_object('votes',
                   coalesce(CASE WHEN jsonb_typeof(v_cycle -> 'votes') = 'object'
                                 THEN v_cycle -> 'votes' END, '{}'::jsonb)
                   || jsonb_build_object(v_moi, v_cand)))::text,
         updated_at = now()
   WHERE id = v_id_cycle;

  RETURN jsonb_build_object('ok', true, 'votant', v_moi, 'candidat', v_cand, 'cle', v_cle);
END; $function$;

-- ============================================================================================
-- 3. LA CONSIGNATION GARDE SUR `dateResultats`, PLUS SUR `resultatsTraites`
-- ============================================================================================
-- POURQUOI LA GARDE DEVAIT CHANGER DE CHAMP. Elle exigeait `resultatsTraites = false` sur la
-- ligne lue. Or une prise de fonctions rouvre immediatement le scrutin suivant, donc le blob
-- ECRIT repose ce drapeau a `false` : un rejeu de la passe l'aurait retrouve a `false` et aurait
-- proclame une seconde fois. `dateResultats` AVANCE STRICTEMENT a chaque proclamation -- cinq
-- semaines pour une prise de fonctions, une pour un second tour, deux pour une prolongation --
-- donc un rejeu ne retrouve jamais la valeur qu'il a lue.
--
-- LE PARAMETRE EST OPTIONNEL, et son absence conserve l'ancienne garde a la lettre : aucun
-- appelant existant ne change de comportement sans l'avoir demande.
CREATE OR REPLACE FUNCTION public.election_resultats_consigner(
  p_cycle_id text, p_data jsonb,
  p_evenement jsonb DEFAULT NULL::jsonb, p_chronique jsonb DEFAULT NULL::jsonb,
  p_si_date_resultats numeric DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_n integer; v_ev integer := 0; v_ch integer := 0;
BEGIN
  IF coalesce(btrim(p_cycle_id),'') = '' OR p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'election_resultats_consigner : cycle et blob sont obligatoires';
  END IF;
  -- COMPARE-AND-SWAP DANS LE FILTRE, PAS DANS LE CORPS : deux passes simultanees ne peuvent pas
  -- proclamer le meme scrutin, et un rejeu lit zero ligne. Un cycle inconnu donne aussi zero
  -- ligne : aucune annonce ne peut partir sans son cycle.
  IF p_si_date_resultats IS NULL THEN
    UPDATE public.cycles_electoraux
       SET data = p_data::text, updated_at = now()
     WHERE id = p_cycle_id
       AND coalesce((data::jsonb ->> 'resultatsTraites')::boolean, false) = false;
  ELSE
    UPDATE public.cycles_electoraux
       SET data = p_data::text, updated_at = now()
     WHERE id = p_cycle_id
       AND jsonb_typeof(data::jsonb -> 'dateResultats') = 'number'
       AND (data::jsonb ->> 'dateResultats')::numeric = p_si_date_resultats;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traite');
  END IF;

  IF jsonb_typeof(p_evenement) = 'object' THEN
    INSERT INTO public.evenements_globaux (country, city, texte, jour)
    VALUES (p_evenement ->> 'country', p_evenement ->> 'city', p_evenement ->> 'texte', NULL);
    v_ev := 1;
  END IF;
  -- L'identifiant de la chronique vient de l'appelant et est DEJA deterministe
  -- (election-<cycle>-<dateResultats>) : le ON CONFLICT est une seconde barriere, pas la premiere.
  IF jsonb_typeof(p_chronique) = 'object' THEN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (p_chronique ->> 'id', p_chronique ->> 'country', p_chronique ->> 'city',
            p_chronique ->> 'type',
            CASE WHEN jsonb_typeof(p_chronique -> 'personnages') = 'array'
                 THEN p_chronique -> 'personnages' ELSE '[]'::jsonb END,
            p_chronique ->> 'libelle', p_chronique -> 'data', p_chronique ->> 'source_ref')
    ON CONFLICT (id) DO NOTHING;
    GET DIAGNOSTICS v_ch = ROW_COUNT;
  END IF;
  RETURN jsonb_build_object('ok', true, 'cycle', p_cycle_id,
                            'evenement_pose', v_ev = 1, 'chronique_posee', v_ch = 1);
END; $function$;

-- Le defaut des privileges (chantier du 9 octobre 2026) : une fonction recreee reprend les
-- droits par defaut. La signature de `election_resultats_consigner` a CHANGE (cinquieme
-- parametre), donc une nouvelle entree existe et doit etre refermee explicitement.
REVOKE ALL ON FUNCTION public.election_resultats_consigner(text, jsonb, jsonb, jsonb, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.election_resultats_consigner(text, jsonb, jsonb, jsonb, numeric) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.election_resultats_consigner(text, jsonb, jsonb, jsonb, numeric) TO service_role;