-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011111516 (UTC), nom `conference_de_presse_et_financement`.
-- Le registre passe de 645 a 646 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 9a55df25793fa507b356d5066991dbe0, 48071 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- DEUX ARBITRAGES, UNE SEULE TRANSACTION : QUI PAIE, ET QUI REPOND
--
-- QUI PAIE. Les PA restent au joueur qui passe l'ordre. Les francs sortent PAR DEFAUT du budget
-- du Ministere de l'Information. S'il ne couvre pas, RIEN n'est debite : la porte refuse en
-- NOMMANT la caisse de repli -- celle du poste de celui qui parle -- et son solde, et elle
-- attend un accord explicite. Jamais de financement mixte, jamais de debit partiel, aucun PA
-- perdu sur un refus. La caisse d'un poste n'est pas inventee ici : `salaires_caisses` la
-- declarait deja, enveloppe du Premier ministre comprise, et `salaire_caisse_de()` la resout.
-- Aucun montant n'a ete modifie.
-- QUI REPOND. Toute communication gouvernementale ouvre une CONFERENCE DE PRESSE, dans la meme
-- transaction que la publication. Une question a la fois, de une a cinq, et le nombre n'est
-- decide a l'avance par personne : apres chaque reponse, les journalistes decident s'il reste
-- un angle. Un REFUS DE REPONDRE ne termine jamais la conference. Fermer la pop-up la termine
-- IMMEDIATEMENT, et ce qui a eu lieu avant est conserve.
-- LA QUESTION EST ECRITE PAR LE SERVEUR, ET PAR LUI SEUL. `conference_question_poser` n'a
-- EXECUTE que pour service_role : si le navigateur pouvait poser la question, il choisirait ce
-- que les journalistes demandent -- donc la transcription elle-meme. Le joueur ne transmet que
-- sa reponse.
-- LES PAROLES DU MINISTRE SONT INTANGIBLES. Les deux tables sont sous RLS SANS AUCUNE POLICY,
-- et aucune porte ne modifie un echange deja renseigne : `conference_repondre` refuse un rang
-- qui a deja une suite. La transcription est donc immuable pour tout le monde, serveur compris.
-- La regle editoriale qui en decoule -- une redaction choisit, cite et commente, jamais ne
-- reecrit -- est propre a REPUBLIA et n'est pas posee en invariant pour les empires a venir.
-- CE QUI N'EST PAS LA, ET C'EST L'ARBITRAGE. Aucune publication automatique de la conference le
-- lendemain : elle devient une MATIERE que la redaction vient chercher par
-- `conference_matiere`, et dont elle publie tout, partie ou rien. Et aucun jugement : il
-- n'existe aucune colonne de veracite, de credibilite ou de qualite, et une preuve structurelle
-- le verifie.
-- UN DEFAUT DE LA VEILLE EST FERME AU PASSAGE. La memoire presidentielle avait ete branchee sur
-- `chronique_nationale` en affirmant qu'aucun navigateur n'y ecrivait. C'etait faux : policy
-- INSERT ouverte a authenticated, et une dizaine de hooks clients. N'importe quel joueur
-- pouvait fabriquer un fait national. Le declencheur est retire et la source reclassee parmi
-- les non raccordables -- fermer l'INSERT client aurait casse une dizaine de chemins de jeu
-- legitimes.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA CONFERENCE DE PRESSE, ET QUI PAIE LA COMMUNICATION (11 octobre 2026)
-- =================================================================================================
-- DEUX ARBITRAGES, UNE SEULE TRANSACTION. Une communication gouvernementale est desormais
-- indissociable de sa conference de presse : on ne peut pas avoir paye sans conference, ni une
-- conference sans communication.
--
-- 1. QUI PAIE. Les PA sont au PJ qui passe l'ordre. Les FR sont, PAR DEFAUT, sur le budget du
--    MINISTERE DE L'INFORMATION. S'il ne couvre pas, RIEN n'est debite : la porte refuse en
--    NOMMANT la caisse de repli -- celle du poste du PJ -- et son solde. Le joueur rappelle alors
--    la porte avec son accord explicite, et le cout est pris EN ENTIER sur sa caisse. Jamais de
--    financement mixte, jamais de debit partiel, et aucun PA preleve sur un refus.
--
--    LA CAISSE D'UN POSTE N'EST PAS INVENTEE ICI. `salaires_caisses` la declare deja pour chaque
--    poste -- `{pays}_gouvernement-pm` porte meme la note « enveloppe du PM » -- et
--    `salaire_caisse_de()` la resout. On reutilise ce resolveur plutot que d'ecrire une seconde
--    table de correspondance qui divergerait.
--
-- 2. LA CONFERENCE. Chaque communication ouvre une conference, et la matiere brute de l'echange
--    est conservee au serveur : question posee, reponse EXACTE, refus, ordre chronologique.
--
-- CE QUI N'EST PAS DANS CETTE MIGRATION, ET C'EST VOULU :
--   . aucun montant n'est modifie. Les couts restent ceux du miroir `ordres_couts`, et la porte
--     refuse un triplet (fn, pa, cost) que le miroir ne declare pas -- exactement comme
--     payer_ordre ;
--   . aucune publication automatique de la transcription. La trace publique est une PHRASE
--     factuelle dans la chronique nationale ; la transcription, elle, attend qu'une redaction
--     vienne la chercher ;
--   . aucun jugement. Il n'existe aucune colonne de veracite, de credibilite ou de qualite, et
--     aucune fonction n'en deduit.
--
-- LES PAROLES DU MINISTRE SONT INTANGIBLES. Il n'existe AUCUNE porte qui modifie une reponse
-- deja enregistree : `conference_repondre` refuse un echange deja renseigne. Techniquement la
-- transcription est donc immuable pour tout le monde. LA REGLE EDITORIALE qui en decoule -- une
-- redaction peut choisir, citer et commenter, jamais reecrire les paroles citees -- est propre a
-- REPUBLIA : elle est ecrite ici comme une regle de cet empire, et n'est pas posee en invariant
-- pour les empires a venir.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LA CONFERENCE
-- -------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conferences_presse (
  id              text PRIMARY KEY,
  pays            text        NOT NULL,
  building_id     text        NOT NULL,
  room_id         text        NOT NULL,
  auteur          text        NOT NULL,
  poste_id        text        NOT NULL,
  poste_libelle   text,
  ordre           text        NOT NULL,
  titre           text        NOT NULL,
  communication   text        NOT NULL,
  statut          text        NOT NULL DEFAULT 'ouverte',
  cout_fr         numeric     NOT NULL DEFAULT 0,
  caisse_payeuse  text,
  chronique_id    text,
  ouverte_le      timestamptz NOT NULL DEFAULT now(),
  close_le        timestamptz,
  CONSTRAINT conference_statut_connu
    CHECK (statut = ANY (ARRAY['ouverte','terminee','interrompue'])),
  CONSTRAINT conference_close_a_une_date
    CHECK ((statut = 'ouverte' AND close_le IS NULL) OR (statut <> 'ouverte' AND close_le IS NOT NULL))
);

COMMENT ON TABLE public.conferences_presse IS
  'En-tete d une conference de presse officielle : qui a parle, en quelle qualite, depuis quelle tribune, ce qu il a declare, et comment la conference s est terminee. La matiere de l echange est dans conferences_presse_echanges. Ne porte AUCUN jugement : ni veracite, ni credibilite, ni qualite (arbitrage du 11 octobre 2026).';

COMMENT ON COLUMN public.conferences_presse.poste_libelle IS
  'La fonction publique telle qu elle etait AU MOMENT de la communication. Figee ici expres : un ministre revoque le lendemain a bien parle comme ministre, et la presse doit pouvoir le citer ainsi.';

-- UNE SEULE CONFERENCE OUVERTE PAR AUTEUR, ET C'EST LA GARDE ANTI-DOUBLE-CLIC. Deux appels
-- simultanes ne peuvent pas creer deux conferences : le second viole l'index et sa transaction
-- entiere est annulee -- donc ni PA, ni FR, ni communication en double. Et c'est aussi une regle
-- de jeu juste : on ne tient pas deux conferences de presse a la fois.
-- AUCUN DELAI D'EXPIRATION N'EST INVENTE : une conference abandonnee se referme en fermant la
-- pop-up, ce qui est exactement ce que l'arbitrage demande.
CREATE UNIQUE INDEX IF NOT EXISTS conference_une_seule_ouverte_par_auteur
  ON public.conferences_presse (pays, auteur) WHERE statut = 'ouverte';

CREATE INDEX IF NOT EXISTS conference_par_pays_et_date
  ON public.conferences_presse (pays, ouverte_le DESC);

-- -------------------------------------------------------------------------------------------------
-- 2. LES ECHANGES
-- -------------------------------------------------------------------------------------------------
-- LE RANG PORTE L'ORDRE CHRONOLOGIQUE, et la cle primaire l'impose : il ne peut pas y avoir deux
-- questions numero 2. Le plafond de cinq est verifie par la porte, pas par un CHECK, parce que le
-- maximum est une regle de jeu et non une contrainte de forme -- et qu'un CHECK ne saurait pas
-- dire « l'IA a decide d'arreter avant ».
CREATE TABLE IF NOT EXISTS public.conferences_presse_echanges (
  conference_id text        NOT NULL REFERENCES public.conferences_presse(id) ON DELETE CASCADE,
  rang          integer     NOT NULL,
  question      text        NOT NULL,
  reponse       text,
  refus         boolean     NOT NULL DEFAULT false,
  pose_le       timestamptz NOT NULL DEFAULT now(),
  repondu_le    timestamptz,
  PRIMARY KEY (conference_id, rang),
  CONSTRAINT echange_rang_borne CHECK (rang >= 1 AND rang <= 5),
  -- UN REFUS N'EST PAS UNE REPONSE VIDE. Les deux etats sont distincts et exclusifs : « il a
  -- refuse de repondre » et « il n a pas encore repondu » ne se racontent pas pareil.
  CONSTRAINT echange_refus_sans_reponse CHECK (NOT (refus AND reponse IS NOT NULL)),
  CONSTRAINT echange_repondu_a_une_date
    CHECK ((reponse IS NULL AND NOT refus AND repondu_le IS NULL)
        OR ((reponse IS NOT NULL OR refus) AND repondu_le IS NOT NULL))
);

COMMENT ON TABLE public.conferences_presse_echanges IS
  'La matiere brute d une conference : la question posee, la reponse EXACTE du joueur, ou son refus. Aucune porte ne modifie un echange deja renseigne -- la transcription est immuable. Une redaction peut la citer et la commenter ; elle ne peut pas la reecrire (regle propre a Republia, arbitrage du 11 octobre 2026).';

-- LES DEUX TABLES SONT FERMEES AU CLIENT : RLS active, aucune policy. Un joueur ne peut donc ni
-- ecrire une question, ni retoucher une reponse, ni fabriquer une transcription -- tout passe par
-- les portes ci-dessous.
ALTER TABLE public.conferences_presse          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conferences_presse_echanges ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------------------------------
-- 2 bis. QUELS ORDRES UNE TRIBUNE ADMET
-- -------------------------------------------------------------------------------------------------
-- TROU TROUVE EN RELISANT LA PORTE : `p_fn` n'etait valide que contre le miroir des couts. Or le
-- miroir declare 381 ordres : un ministre pouvait donc « tenir une conference de presse » en
-- annoncant n'importe quel ordre declare -- `postuler` (2 PA, 0 FR), par exemple -- et obtenir une
-- vraie conference au nom de l'Etat. La tribune declare desormais ce qu'on peut y prononcer.
ALTER TABLE public.communications_salles
  ADD COLUMN IF NOT EXISTS ordres text[] NOT NULL DEFAULT ARRAY[]::text[];

UPDATE public.communications_salles
   SET ordres = ARRAY['conference_presse','propagande_etat','dementi']
 WHERE ordres = ARRAY[]::text[];

DO $$
BEGIN
  -- IDEMPOTENT : une migration qui echoue plus bas et qu'on rejoue ne doit pas buter ici.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'communications_ordres_non_vides') THEN
    ALTER TABLE public.communications_salles
      ADD CONSTRAINT communications_ordres_non_vides CHECK (array_length(ordres, 1) >= 1);
  END IF;
END $$;

COMMENT ON COLUMN public.communications_salles.ordres IS
  'Les ordres qu on peut prononcer depuis cette tribune. Sans cette liste, la porte n aurait valide que le COUT de l ordre -- et le miroir en declare 381 : n importe lequel aurait servi de conference de presse.';

-- -------------------------------------------------------------------------------------------------
-- 3. QUI PAIE : LE RESOLVEUR DU FINANCEMENT
-- -------------------------------------------------------------------------------------------------
-- UNE FONCTION DE LECTURE SEULE, pour que la decision de financement soit lisible, testable et
-- identique des deux cotes de la porte. Elle ne debite rien.
--
-- `salaire_caisse_de` est le resolveur DECLARATIF deja en place : la caisse d'un poste vient de
-- `salaires_caisses`, pas d'une correspondance ecrite ici. C'est elle qui sait que l'enveloppe du
-- Premier ministre est `{pays}_gouvernement-pm`.
CREATE OR REPLACE FUNCTION public.communication_financement(
  p_pays text, p_poste_id text, p_cout numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_info text; v_sien text; v_solde_info numeric := 0; v_solde_sien numeric := 0;
BEGIN
  IF coalesce(p_cout, 0) <= 0 THEN
    -- UNE COMMUNICATION GRATUITE NE POSE AUCUNE QUESTION DE CAISSE. La conference de presse et le
    -- dementi sont dans ce cas : seuls des PA.
    RETURN jsonb_build_object('ok', true, 'gratuit', true, 'caisse', NULL, 'cout', 0);
  END IF;

  v_info := public.salaire_caisse_de('min_info', p_pays, NULL);
  v_sien := public.salaire_caisse_de(p_poste_id, p_pays, NULL);

  SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_info
    FROM public.caisses_batiments WHERE id = v_info;
  SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_sien
    FROM public.caisses_batiments WHERE id = v_sien;

  IF v_info IS NOT NULL AND coalesce(v_solde_info, 0) >= p_cout THEN
    RETURN jsonb_build_object('ok', true, 'gratuit', false, 'caisse', v_info,
                              'defaut', true, 'cout', p_cout, 'solde', v_solde_info);
  END IF;

  -- L'INFORMATION NE COUVRE PAS. On NOMME la caisse de repli et son solde, et on ne debite rien :
  -- c'est au joueur de dire s'il accepte de payer sur sa propre caisse institutionnelle.
  RETURN jsonb_build_object(
    'ok', false, 'gratuit', false, 'raison', 'budget_information_insuffisant',
    'cout', p_cout,
    'caisse_information', v_info, 'solde_information', coalesce(v_solde_info, 0),
    'caisse_proposee', v_sien, 'solde_proposee', coalesce(v_solde_sien, 0),
    -- SUFFISANTE OU PAS : le joueur a droit a l'information avant de repondre, sinon on lui
    -- demande d'accepter une depense impossible.
    'proposee_suffisante', (v_sien IS NOT NULL AND coalesce(v_solde_sien, 0) >= p_cout));
END;
$function$;

REVOKE ALL ON FUNCTION public.communication_financement(text, text, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.communication_financement(text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.communication_financement(text, text, numeric) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 4. LA PORTE DE PUBLICATION, REECRITE
-- -------------------------------------------------------------------------------------------------
-- CE QUI CHANGE PAR RAPPORT AU 11 OCTOBRE AU MATIN :
--   . les FR ne sortent plus de la poche du responsable mais d'une CAISSE, selon la regle ci-dessus ;
--   . les PA sont preleves ICI, sous verrou, apres le debit de la caisse -- de sorte qu'un echec
--     financier ne laisse jamais des PA amputes pour rien. C'est l'ordre que `deduireCoutOrdre`
--     applique deja pour le chemin institutionnel, et on le garde ;
--   . une CONFERENCE est ouverte, et une TRACE PUBLIQUE est deposee dans la chronique nationale ;
--   . le triplet (fn, pa, cost) est valide contre le miroir `ordres_couts` exactement comme le
--     fait payer_ordre -- un navigateur ne peut donc pas annoncer une propagande gratuite.
--
-- POURQUOI PAS payer_ordre POUR LES PA. payer_ordre valide le triplet puis preleve PA **ET** FR
-- sur le joueur ; l'appeler avec (pa, 0) ferait echouer la validation du miroir, qui ne declare
-- pas ce couple. Le prelevement des PA est donc fait ici, sous `FOR UPDATE`, et la validation du
-- miroir est faite ici aussi, sur le triplet REEL : aucune autorite n'est perdue au passage.
CREATE OR REPLACE FUNCTION public.communication_officielle_publier(
  p_building_id text, p_room_id text, p_fn text, p_pa integer, p_cost integer,
  p_titre text, p_contenu text, p_blocs jsonb,
  p_accepte_sa_caisse boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; sa record; fin jsonb;
  v_topic text; v_post text; v_titre text; v_contenu text; v_temps text;
  v_conf text; v_chron text; v_caisse text; v_data jsonb; v_solde numeric;
  v_pa integer; v_poste_libelle text; v_ouverte text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_titre   := nullif(btrim(coalesce(p_titre, '')), '');
  v_contenu := nullif(btrim(coalesce(p_contenu, '')), '');
  IF v_titre IS NULL OR v_contenu IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titre_ou_contenu_vide');
  END IF;

  SELECT * INTO sa FROM public.communications_salles
   WHERE building_id = p_building_id AND room_id = p_room_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_sans_tribune');
  END IF;

  SELECT * INTO a FROM public.acteur_poste_courant() LIMIT 1;
  IF NOT FOUND OR a.poste_id IS NULL OR NOT (a.poste_id = ANY (sa.postes)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_admis_dans_cette_tribune',
                              'tribune', sa.libelle, 'postes_admis', sa.postes);
  END IF;

  -- LA TRIBUNE DECLARE CE QU'ON PEUT Y PRONONCER. Sans ce controle, tout ordre declare au miroir
  -- aurait pu servir de conference de presse.
  IF NOT (p_fn = ANY (sa.ordres)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_etranger_a_la_tribune',
                              'ordre', p_fn, 'ordres_admis', sa.ordres);
  END IF;

  -- LE MIROIR DES COUTS FAIT AUTORITE SUR LE COUPLE ANNONCE.
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts o
                  WHERE o.fn = p_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', p_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  -- UNE SEULE CONFERENCE OUVERTE A LA FOIS. On le dit AVANT de debiter, et on rend l'identifiant
  -- de celle qui est deja ouverte : le navigateur rouvre sa pop-up au lieu d'en creer une seconde.
  SELECT id INTO v_ouverte FROM public.conferences_presse
   WHERE pays = a.pays AND auteur = v_moi AND statut = 'ouverte' LIMIT 1;
  IF v_ouverte IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_deja_ouverte',
                              'conference', v_ouverte);
  END IF;

  -- LE FINANCEMENT, DECIDE AVANT TOUT DEBIT.
  fin := public.communication_financement(a.pays, a.poste_id, coalesce(p_cost, 0));
  IF coalesce((fin->>'gratuit')::boolean, false) THEN
    v_caisse := NULL;
  ELSIF coalesce((fin->>'ok')::boolean, false) THEN
    v_caisse := fin->>'caisse';
  ELSE
    -- L'INFORMATION NE COUVRE PAS. Sans accord explicite, on rend la main SANS RIEN AVOIR DEBITE.
    IF p_accepte_sa_caisse IS NOT TRUE THEN
      RETURN fin || jsonb_build_object('ok', false, 'accord_requis', true);
    END IF;
    IF coalesce((fin->>'proposee_suffisante')::boolean, false) IS NOT TRUE THEN
      RETURN fin || jsonb_build_object('ok', false, 'accord_requis', false,
                                       'raison', 'les_deux_caisses_insuffisantes');
    END IF;
    v_caisse := fin->>'caisse_proposee';
  END IF;

  -- LES PA SONT VERROUILLES ET VERIFIES AVANT LE MOINDRE DEBIT. Le verrou est pris ici et tenu
  -- jusqu'au bout : entre la verification et le prelevement, personne ne peut depenser ces PA
  -- ailleurs. Et le refus est STRUCTURE -- un joueur a court de PA recoit une raison, pas une
  -- erreur de transport.
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'pa_reel', v_pa, 'requis', coalesce(p_pa, 0));
  END IF;

  -- LE DEBIT DE LA CAISSE, SOUS VERROU ET EN ENTIER. Tout ou rien : jamais de financement mixte,
  -- jamais de moitie.
  IF v_caisse IS NOT NULL THEN
    SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                    THEN (v_data ->> 'solde')::numeric ELSE 0 END;
    IF v_solde < p_cost THEN
      -- Le solde a bouge entre la lecture et le verrou : on refuse, et rien n'est ecrit.
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante_au_verrou',
                                'caisse', v_caisse, 'solde', v_solde, 'requis', p_cost);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_cost),
           updated_at = now()
     WHERE id = v_caisse;
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, v_caisse, -p_cost, 'communication_officielle:' || p_fn, true, NULL);
  END IF;

  -- LE PRELEVEMENT DES PA, APRES le debit financier : un echec de caisse ne doit jamais amputer
  -- les PA. La suffisance a deja ete verifiee sous le meme verrou, ce debit ne peut pas echouer.
  UPDATE public.personnages_donnees SET pa = v_pa - coalesce(p_pa, 0) WHERE name = v_moi;

  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
  v_topic := 'topic-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_post  := 'post-'  || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_conf  := 'conf-'  || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_chron := 'chronique-conference_presse-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;

  SELECT poste->>'name' INTO v_poste_libelle FROM public.personnages_donnees WHERE name = v_moi;

  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies,
     last_post_author, last_post_time, author_is_org, author_secret)
  VALUES (v_topic, sa.forum_id, v_titre, v_moi, a.pays, v_temps, 1, 0, v_moi, v_temps, false, false);

  INSERT INTO public.forum_posts
    (id, topic_id, author, content, time, author_is_org, author_secret, content_blocks, content_layout)
  VALUES (v_post, v_topic, v_moi, v_contenu, v_temps, false, false,
          CASE WHEN jsonb_typeof(p_blocs) = 'array' THEN p_blocs ELSE '[]'::jsonb END, NULL);

  -- LA CONFERENCE S'OUVRE. `communication` garde le texte DECLARE, verbatim.
  INSERT INTO public.conferences_presse
    (id, pays, building_id, room_id, auteur, poste_id, poste_libelle, ordre,
     titre, communication, statut, cout_fr, caisse_payeuse, chronique_id)
  VALUES (v_conf, a.pays, p_building_id, p_room_id, v_moi, a.poste_id, v_poste_libelle, p_fn,
          v_titre, v_contenu, 'ouverte', coalesce(p_cost, 0), v_caisse, v_chron);

  -- LA TRACE PUBLIQUE. Une PHRASE factuelle, dans la couche publique du jeu -- et ECRITE PAR LE
  -- SERVEUR, dans la meme transaction que la communication. Elle dit QU'UNE conference a eu lieu,
  -- et rien de son contenu : ni resume, ni jugement, ni transcription.
  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, a.pays, 'conference_presse', NULL,
          jsonb_build_array(v_moi),
          coalesce(v_poste_libelle, v_moi) || ' a tenu une conference de presse : « ' || v_titre || ' ».',
          jsonb_build_object('conference', v_conf, 'ordre', p_fn, 'tribune', sa.libelle,
                             'topic', v_topic),
          v_conf);

  RETURN jsonb_build_object('ok', true, 'topic', v_topic, 'post', v_post,
                            'conference', v_conf, 'chronique', v_chron,
                            'auteur', v_moi, 'poste', a.poste_id,
                            'poste_libelle', v_poste_libelle,
                            'tribune', sa.libelle, 'temps', v_temps,
                            'cout', coalesce(p_cost, 0), 'caisse_payeuse', v_caisse,
                            'pa_preleves', coalesce(p_pa, 0), 'pa', v_pa - coalesce(p_pa, 0));
END;
$function$;

REVOKE ALL ON FUNCTION public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb, boolean) TO service_role;

-- L'ANCIENNE SIGNATURE A HUIT PARAMETRES EST RETIREE : deux fonctions de meme nom, l'une sans la
-- regle de financement, seraient deux chemins pour un seul acte -- et le navigateur pourrait
-- choisir le mauvais.
DROP FUNCTION IF EXISTS public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb);

-- -------------------------------------------------------------------------------------------------
-- 5. LA QUESTION : ECRITE PAR LE SERVEUR, JAMAIS PAR LE NAVIGATEUR
-- -------------------------------------------------------------------------------------------------
-- POURQUOI service_role SEUL. Si le navigateur pouvait poser la question, il pourrait l'ecrire
-- lui-meme -- donc choisir ce que les journalistes demandent, et fabriquer une transcription
-- flatteuse. La question est donc redigee par l'endpoint serveur (api/conference.js), qui appelle
-- le modele et ecrit sous identite de service. Le joueur ne transmet que sa REPONSE.
--
-- LA PORTE COMPTE ELLE-MEME LES QUESTIONS. Le plafond de cinq et l'etat de la conference sont
-- verifies ici : un endpoint qui boucle par erreur ne peut pas depasser.
CREATE OR REPLACE FUNCTION public.conference_question_poser(p_conference_id text, p_question text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_q text; v_rang integer; v_reste integer;
BEGIN
  v_q := nullif(btrim(coalesce(p_question, '')), '');
  IF v_q IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'question_vide');
  END IF;

  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;
  IF c.statut <> 'ouverte' THEN
    -- LA POP-UP A ETE FERMEE : plus aucune question ne s'ajoute, et c'est exactement l'arbitrage.
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_close', 'statut', c.statut);
  END IF;

  -- ON NE POSE PAS UNE QUESTION TANT QUE LA PRECEDENTE N'A PAS DE SUITE. Sans cela, un appel
  -- repete empilerait des questions sans reponse, et la transcription perdrait son sens.
  SELECT count(*) INTO v_reste FROM public.conferences_presse_echanges
   WHERE conference_id = p_conference_id AND reponse IS NULL AND NOT refus;
  IF v_reste > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'question_en_attente_de_reponse');
  END IF;

  SELECT coalesce(max(rang), 0) + 1 INTO v_rang
    FROM public.conferences_presse_echanges WHERE conference_id = p_conference_id;
  IF v_rang > 5 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_de_questions_atteint', 'maximum', 5);
  END IF;

  INSERT INTO public.conferences_presse_echanges (conference_id, rang, question)
  VALUES (p_conference_id, v_rang, left(v_q, 600));

  RETURN jsonb_build_object('ok', true, 'rang', v_rang, 'question', left(v_q, 600),
                            'reste_possible', 5 - v_rang);
END;
$function$;

REVOKE ALL ON FUNCTION public.conference_question_poser(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conference_question_poser(text, text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 6. LA REPONSE : VERBATIM, ET UNE SEULE FOIS
-- -------------------------------------------------------------------------------------------------
-- LA REPONSE EST CONSERVEE TELLE QUELLE. Aucun nettoyage, aucune reformulation, aucune analyse :
-- ce sont les paroles du ministre, et c'est tout l'interet de les garder.
-- AUCUN JUGEMENT N'EST PORTE : la porte ne verifie pas si la reponse repond, et rien dans le
-- schema ne permettrait de l'ecrire.
-- UN ECHANGE DEJA RENSEIGNE EST REFUSE : c'est ce qui rend la transcription immuable.
CREATE OR REPLACE FUNCTION public.conference_repondre(
  p_conference_id text, p_rang integer, p_reponse text, p_refus boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; e record; v_r text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;
  -- SEUL CELUI QUI A PARLE REPOND. Un autre joueur ne met pas de mots dans sa bouche.
  IF c.auteur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_conference');
  END IF;
  IF c.statut <> 'ouverte' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_close', 'statut', c.statut);
  END IF;

  SELECT * INTO e FROM public.conferences_presse_echanges
   WHERE conference_id = p_conference_id AND rang = p_rang FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'question_inconnue');
  END IF;
  IF e.reponse IS NOT NULL OR e.refus THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_repondu');
  END IF;

  IF p_refus IS TRUE THEN
    -- UN REFUS NE TERMINE PAS LA CONFERENCE. La porte ne touche pas au statut : les journalistes
    -- peuvent enchainer, et c'est exactement l'arbitrage.
    UPDATE public.conferences_presse_echanges
       SET refus = true, repondu_le = now()
     WHERE conference_id = p_conference_id AND rang = p_rang;
    RETURN jsonb_build_object('ok', true, 'rang', p_rang, 'refus', true);
  END IF;

  v_r := nullif(btrim(coalesce(p_reponse, '')), '');
  IF v_r IS NULL THEN
    -- NI REPONSE NI REFUS N'EST PAS UN ETAT : il faut choisir. Un champ vide envoye par megarde
    -- ne doit pas devenir un refus implicite.
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_vide_sans_refus');
  END IF;

  UPDATE public.conferences_presse_echanges
     SET reponse = left(v_r, 4000), repondu_le = now()
   WHERE conference_id = p_conference_id AND rang = p_rang;

  RETURN jsonb_build_object('ok', true, 'rang', p_rang, 'refus', false);
END;
$function$;

REVOKE ALL ON FUNCTION public.conference_repondre(text, integer, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conference_repondre(text, integer, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.conference_repondre(text, integer, text, boolean) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 7. LA FIN : NORMALE OU PAR FERMETURE
-- -------------------------------------------------------------------------------------------------
-- DEUX FINS, ET ELLES NE SE RACONTENT PAS PAREIL. `terminee` : les journalistes n'avaient plus de
-- question. `interrompue` : le responsable a ferme la pop-up. La seconde est une information, et
-- une redaction a le droit de la connaitre.
-- CE QUI A EU LIEU AVANT LA FERMETURE EST CONSERVE : la porte ne supprime aucun echange.
CREATE OR REPLACE FUNCTION public.conference_clore(p_conference_id text, p_interrompue boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;
  IF NOT public.est_appel_serveur() AND c.auteur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_conference');
  END IF;
  IF c.statut <> 'ouverte' THEN
    -- IDEMPOTENT : refermer une conference close n'est pas une erreur, et un double clic sur la
    -- croix de la pop-up ne doit pas lever.
    RETURN jsonb_build_object('ok', true, 'deja_close', true, 'statut', c.statut);
  END IF;

  v_statut := CASE WHEN p_interrompue IS TRUE THEN 'interrompue' ELSE 'terminee' END;
  UPDATE public.conferences_presse
     SET statut = v_statut, close_le = now() WHERE id = p_conference_id;

  RETURN jsonb_build_object('ok', true, 'statut', v_statut,
    'echanges', (SELECT count(*) FROM public.conferences_presse_echanges
                  WHERE conference_id = p_conference_id));
END;
$function$;

REVOKE ALL ON FUNCTION public.conference_clore(text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conference_clore(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.conference_clore(text, boolean) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 8. LA LECTURE : CELUI QUI PARLE, ET LA REDACTION
-- -------------------------------------------------------------------------------------------------
-- DEUX LECTEURS LEGITIMES, ET PAS UN DE PLUS :
--   . L'AUTEUR, pour que sa pop-up puisse se rouvrir apres un rechargement sans rien perdre ;
--   . LA REDACTION, parce que c'est elle qui exploitera la matiere. Le droit n'est pas invente :
--     c'est l'appartenance a un groupe de presse du pays, dans `presse_membres` -- les quatre
--     grades existants, du correspondant au directeur.
-- LE SERVEUR aussi, pour l'endpoint qui redige les questions.
CREATE OR REPLACE FUNCTION public.conference_lire(p_conference_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; v_est_presse boolean := false;
BEGIN
  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;

  v_moi := public.mon_personnage();
  IF NOT public.est_appel_serveur() THEN
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT EXISTS (SELECT 1 FROM public.presse_membres m
                     JOIN public.groupes_presse g ON g.id = m.groupe_id
                    WHERE m.personnage = v_moi AND g.pays = c.pays) INTO v_est_presse;
    IF c.auteur IS DISTINCT FROM v_moi AND NOT v_est_presse THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'lecture_reservee_a_l_auteur_et_a_la_presse');
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true,
    'conference', jsonb_build_object(
      'id', c.id, 'pays', c.pays, 'auteur', c.auteur,
      'poste', c.poste_id, 'fonction', c.poste_libelle,
      'ordre', c.ordre, 'titre', c.titre, 'communication', c.communication,
      'statut', c.statut, 'ouverte_le', c.ouverte_le, 'close_le', c.close_le),
    'echanges', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'rang', e.rang, 'question', e.question, 'reponse', e.reponse,
          'refus', e.refus, 'pose_le', e.pose_le, 'repondu_le', e.repondu_le) ORDER BY e.rang), '[]'::jsonb)
       FROM public.conferences_presse_echanges e WHERE e.conference_id = c.id));
END;
$function$;

REVOKE ALL ON FUNCTION public.conference_lire(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conference_lire(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.conference_lire(text) TO service_role;

-- LA MATIERE DE LA REDACTION. C'est le raccordement de l'arbitrage J+1 : la conference ne se
-- publie PAS toute seule, elle attend qu'un journaliste vienne la lire. La porte rend les
-- conferences CLOSES -- on ne cite pas une conference en cours -- avec leur transcription
-- complete, et rien d'autre : ni angle, ni titre, ni commentaire. Ce travail appartient au PJ.
CREATE OR REPLACE FUNCTION public.conference_matiere(p_limite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_lim integer := least(greatest(coalesce(p_limite, 10), 1), 30);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LE DROIT EXISTANT, REUTILISE : etre membre d'un groupe de presse. Un ministre n'a pas acces a
  -- la matiere des conferences des autres, et un citoyen non plus.
  SELECT g.pays INTO v_pays FROM public.presse_membres m
    JOIN public.groupes_presse g ON g.id = m.groupe_id
   WHERE m.personnage = v_moi LIMIT 1;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_a_la_redaction');
  END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'conferences', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'ouverte_le') DESC), '[]'::jsonb) FROM (
      SELECT jsonb_build_object(
               'id', c.id, 'auteur', c.auteur, 'fonction', c.poste_libelle, 'poste', c.poste_id,
               'ordre', c.ordre, 'titre', c.titre, 'communication', c.communication,
               'statut', c.statut, 'ouverte_le', c.ouverte_le, 'close_le', c.close_le,
               'echanges', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                     'rang', e.rang, 'question', e.question,
                     'reponse', e.reponse, 'refus', e.refus) ORDER BY e.rang), '[]'::jsonb)
                  FROM public.conferences_presse_echanges e WHERE e.conference_id = c.id)) AS x
        FROM public.conferences_presse c
       WHERE c.pays = v_pays AND c.statut <> 'ouverte'
       ORDER BY c.ouverte_le DESC LIMIT v_lim) z));
END;
$function$;

REVOKE ALL ON FUNCTION public.conference_matiere(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.conference_matiere(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.conference_matiere(integer) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 9. CORRECTION D'UN DEFAUT INTRODUIT HIER : LA CHRONIQUE N'EST PAS UNE SOURCE ATTESTEE
-- -------------------------------------------------------------------------------------------------
-- CE QUI A ETE TROUVE EN INSPECTANT CE BATIMENT. `chronique_nationale` porte une policy
-- `chronique_nationale_ecriture_acteur` : INSERT ouvert a `authenticated` avec pour seule
-- condition `acteur_identifie()`. Elle est en outre massivement ecrite DEPUIS LE NAVIGATEUR, par
-- `sbEnregistrerEvenementPublic` (un sbInsert direct) : une dizaine de hooks legitimes en
-- dependent -- organisations, elections, lobbying, immobilier, Tribune.
--
-- OR LA MIGRATION DE LA MEMOIRE DES MANDATS Y AVAIT BRANCHE UN DECLENCHEUR, en affirmant
-- « elle est ATTESTEE : aucun navigateur n'y ecrit ». C'ETAIT FAUX : j'avais verifie quelles
-- FONCTIONS citent la table, pas si un client pouvait y inserer. Consequence reelle : n'importe
-- quel joueur pouvait fabriquer un « fait national public » et le faire entrer dans la memoire
-- presidentielle -- ce qui defait la seule regle de cette memoire.
--
-- LA CORRECTION PORTE SUR LA MEMOIRE, PAS SUR LA CHRONIQUE. Fermer l'INSERT client casserait une
-- dizaine de chemins de jeu legitimes : ce serait une regression hors perimetre. C'est donc la
-- memoire qui cesse de faire confiance a une table que le client ecrit. La source rejoint la liste
-- des sources non raccordables, avec son vrai obstacle.
DROP TRIGGER IF EXISTS presidence_memoire_chronique_trg ON public.chronique_nationale;
DROP FUNCTION IF EXISTS public.presidence_memoire_chronique();

-- `election_presidentielle` part aussi de la liste ACTIVE : elle n'etait alimentee que par ce
-- declencheur. Une source declaree que rien n'ecrit est un mensonge de registre.
-- L'ALIAS EST INDISPENSABLE : sans lui, `source` dans la sous-requete se resout sur la colonne
-- de `presidence_memoire` et la condition devient `m.source = m.source` -- toujours vraie des
-- qu'une ligne existe. Le garde n'aurait rien garde.
DELETE FROM public.presidence_memoire_sources s
 WHERE s.source IN ('chronique_nationale', 'election_presidentielle')
   AND NOT EXISTS (SELECT 1 FROM public.presidence_memoire m WHERE m.source = s.source);

INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES
  ('chronique nationale', 'contexte',
   'ECARTEE LE 11 OCTOBRE 2026 APRES AVOIR ETE BRANCHEE LE MATIN MEME. La table porte une policy INSERT ouverte a authenticated (WITH CHECK acteur_identifie()) et elle est ecrite depuis le navigateur par sbEnregistrerEvenementPublic : un joueur pouvait donc fabriquer un fait national et le faire entrer dans la memoire presidentielle. La fermer au client casserait une dizaine de hooks legitimes -- organisations, elections, lobbying, immobilier, Tribune -- donc c est la memoire qui cesse de la croire. A raccorder le jour ou les ecritures publiques de la chronique passeront par des portes serveur.'),
  ('election presidentielle', 'contexte',
   'N etait alimentee que par le declencheur de chronique, retire le 11 octobre 2026. Le probleme de fond reste celui deja consigne : au moment ou election_resultats_consigner s execute, postes_attribues ne porte pas encore le nouveau President.')
ON CONFLICT (sujet) DO UPDATE SET genre = EXCLUDED.genre, obstacle = EXCLUDED.obstacle;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_ordres text[];
BEGIN
  -- P1 : les deux tables de conference existent, sous RLS et SANS AUCUNE POLICY. C'est ce qui
  -- rend la transcription inforgeable : aucun client n'y ecrit directement.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relrowsecurity
     AND c.relname IN ('conferences_presse', 'conferences_presse_echanges');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P1a : % tables de conference sous RLS au lieu de 2', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename LIKE 'conferences_presse%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1b : % policy sur les tables de conference', v_n; END IF;

  -- P2 : UNE SEULE CONFERENCE OUVERTE PAR AUTEUR -- la garde anti-double-clic.
  SELECT count(*) INTO v_n FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'conference_une_seule_ouverte_par_auteur'
     AND indexdef LIKE '%UNIQUE%' AND indexdef LIKE '%ouverte%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 : l index d unicite de conference ouverte manque'; END IF;

  -- P3 : LE PLAFOND DE CINQ EST DANS LE SCHEMA, pas seulement dans la porte.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'conferences_presse_echanges'
     AND c.conname = 'echange_rang_borne' AND pg_get_constraintdef(c.oid) LIKE '%5%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 : le plafond de 5 questions n est pas dans le schema'; END IF;

  -- P4 : UN REFUS N'EST PAS UNE REPONSE VIDE -- les deux etats sont exclusifs par contrainte.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'conferences_presse_echanges'
     AND c.conname = 'echange_refus_sans_reponse';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 : refus et reponse ne sont pas exclusifs'; END IF;

  -- P5 : AUCUNE COLONNE DE JUGEMENT nulle part dans la conference. Ni veracite, ni credibilite,
  -- ni qualite, ni score. Si quelqu'un en ajoute une, cette preuve tombe.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name LIKE 'conferences_presse%'
     AND (column_name LIKE '%score%' OR column_name LIKE '%veracite%'
          OR column_name LIKE '%credibilite%' OR column_name LIKE '%qualite%'
          OR column_name LIKE '%mensonge%' OR column_name LIKE '%jugement%');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 : une colonne de jugement est apparue dans la conference'; END IF;

  -- P6 : LA QUESTION EST RESERVEE AU SERVEUR, la reponse est ouverte au joueur. L'inverse serait
  -- exactement la faille : un navigateur qui ecrit les questions ecrit la transcription.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'conference_question_poser'
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6a : la porte des questions n est pas reservee au serveur'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'conference_repondre'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6b : la porte des reponses est mal posee'; END IF;

  -- P7 : AUCUNE PORTE NE MODIFIE UNE REPONSE DEJA DONNEE. La seule qui ecrit `reponse` refuse un
  -- echange deja renseigne -- c'est ce qui rend les paroles intangibles.
  -- LE MOTIF CIBLE L'ECRITURE, PAS LA MENTION. Une premiere version cherchait
  -- « conferences_presse_echanges » ET « UPDATE » n'importe ou dans le corps : elle accusait
  -- `conference_clore`, qui LIT les echanges et met a jour l'EN-TETE. On cherche donc l'ordre
  -- d'ecriture exact.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosrc LIKE '%UPDATE public.conferences_presse_echanges%'
     AND p.proname <> 'conference_repondre';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7a : % autre(s) fonction(s) ecrivent un echange', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'conference_repondre'
     AND p.prosrc LIKE '%deja_repondu%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7b : conference_repondre accepte de reecrire une reponse'; END IF;

  -- P8 : LES ORDRES ADMIS SONT DECLARES PAR TRIBUNE, et la porte les consulte.
  SELECT ordres INTO v_ordres FROM public.communications_salles
   WHERE building_id = 'palais-gouvernement';
  IF v_ordres IS NULL OR array_length(v_ordres, 1) <> 3
     OR NOT ('conference_presse' = ANY (v_ordres)) THEN
    RAISE EXCEPTION 'P8a : les ordres de la tribune du Gouvernement sont mal declares';
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'communication_officielle_publier'
     AND p.prosrc LIKE '%ordre_etranger_a_la_tribune%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P8b : la porte n interroge pas les ordres de la tribune'; END IF;

  -- P9 : LA CAISSE D'UN POSTE VIENT DU RESOLVEUR DECLARATIF, pas d'une correspondance ecrite ici.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'communication_financement'
     AND p.prosrc LIKE '%salaire_caisse_de%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P9a : le financement n utilise pas le resolveur declaratif'; END IF;
  -- Et les sept postes de la tribune ont tous une caisse REELLE. Une caisse introuvable serait un
  -- financement impossible, donc une tribune morte pour ce poste.
  SELECT count(*) INTO v_n FROM (
    SELECT unnest(postes) AS poste FROM public.communications_salles
     WHERE building_id = 'palais-gouvernement') q
   WHERE public.salaire_caisse_de(q.poste, 'republic', NULL) IS NULL;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9b : % poste(s) de tribune sans caisse institutionnelle', v_n; END IF;

  -- P10 : LE DEFAUT D'HIER EST FERME. Le declencheur de chronique a disparu, et la chronique
  -- n'est plus une source active de la memoire presidentielle.
  SELECT count(*) INTO v_n FROM pg_trigger
   WHERE tgname = 'presidence_memoire_chronique_trg' AND NOT tgisinternal;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10a : le declencheur de chronique est toujours pose'; END IF;
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources
   WHERE source IN ('chronique_nationale', 'election_presidentielle');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10b : la chronique est encore une source active'; END IF;
  -- Et les sources qui RESTENT sont exactement les trois reellement attestees.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources;
  IF v_n <> 3 THEN RAISE EXCEPTION 'P10c : % sources actives au lieu de 3', v_n; END IF;
  -- Les deux ecartees sont NOMMEES, avec leur obstacle.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources_absentes
   WHERE sujet IN ('chronique nationale', 'election presidentielle');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P10d : les sources ecartees ne sont pas documentees'; END IF;

  -- P11 : LA MATIERE EST RESERVEE A LA REDACTION, par le droit EXISTANT (presse_membres).
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'conference_matiere'
     AND p.prosrc LIKE '%presse_membres%'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P11 : la porte de la matiere est mal posee'; END IF;

  -- P12 : AUCUNE CONFERENCE N'EXISTE ENCORE. La mecanique nait vide.
  SELECT count(*) INTO v_n FROM public.conferences_presse;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12 : % conference(s) a la naissance', v_n; END IF;

  RAISE NOTICE 'Conference de presse : les 12 preuves structurelles passent.';
END $$;
