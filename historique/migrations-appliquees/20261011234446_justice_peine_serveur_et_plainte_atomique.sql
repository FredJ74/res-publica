-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261011234446 (UTC), nom
-- `justice_peine_serveur_et_plainte_atomique`.
-- Le registre passe de 670 a 671 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 f0617f616b737ea97e1ce6acc68f2ea9, 30683 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE CODE PENAL DEVIENT LA LOI (2/2)
--
-- DEUX DEFAUTS FERMES, TOUS DEUX MESURES SUR LE CODE EN PRODUCTION.
--
-- UN -- LA PEINE ETAIT CE QUE LE NAVIGATEUR EN DISAIT. L'ancienne
-- `justice_rendre_sentence(p_affaire jsonb, p_peine text)` acceptait une CHAINE LIBRE comme
-- peine, et le BLOB ENTIER de l'affaire, qu'elle fusionnait sur la ligne existante : l'accuse, le
-- motif, la ville et le pays d'une affaire deja enregistree etaient reecrivables a l'instant du
-- jugement. La duree reellement infligee ne venait meme pas de la -- c'etait un 3 EN DUR cote
-- navigateur. L'ancienne surcharge est SUPPRIMEE, pas remplacee (preuve P1) : `CREATE OR REPLACE`
-- avec d'autres parametres aurait CREE une seconde fonction, et le vieux chemin serait reste
-- appelable par son nom -- piege deja rencontre le 11 octobre sur election_resultats_consigner.
--
-- DEUX -- LA PLAINTE EXISTAIT AVANT D'ETRE PAYEE. `soumettrePlaynte` appelait `plainte_deposer`
-- (qui CREE le dossier) PUIS `deduireCoutOrdre`, et en cas de refus se contentait de le signaler
-- sans `return` : le dossier restait ouvert, parfois deja instruit et suivi d'une garde a vue,
-- sans qu'un seul PA ait ete preleve. Le paiement descend dans la porte, AVANT l'insertion et
-- dans la meme transaction (preuve P7, qui verifie l'ORDRE des deux instructions). Le cout n'est
-- pas ecrit dans la fonction : il est lu au miroir `ordres_couts`, fail closed (preuve P8).
--
-- UNE SEULE FORMULE DE PEINE, DEUX APPELANTS. `justice_peine_calcul` est appelee par la porte qui
-- PROPOSE au juge et par celle qui ENREGISTRE (preuve P5) : ce que l'ecran annonce est ce que le
-- greffe validera. La plage est RECALCULEE a l'enregistrement, jamais relue d'un parametre.
--
-- CE QU'ELLE NE FAIT PAS, DELIBEREMENT : ni procureur, ni parquet, ni chronologie procedurale, ni
-- relaxe, ni requalification formelle. Et elle ne change AUCUNE regle de game design : le QHS
-- vaut toujours 30 jours, la torture toujours 3 x (n+1) -- deux valeurs RECOPIEES des regles
-- validees, pas derivees du catalogue, et desormais IMPOSEES par le serveur au lieu d'etre
-- recues du navigateur.
--
-- LES 12 PREUVES STRUCTURELLES sont passees a l'application. Le COMPORTEMENT est eprouve par
-- outils/bancs/banc-justice-peine-serveur.sql (22 epreuves, transaction annulee).
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA PEINE N'EST PLUS UNE CHAINE DU NAVIGATEUR, ET LA PLAINTE SE PAIE AVANT D'EXISTER
-- 12 octobre 2026
--
-- DEUX DEFAUTS, TOUS DEUX MESURES SUR LE CODE EN PRODUCTION.
--
-- UN -- LA PEINE ETAIT CE QUE LE NAVIGATEUR EN DISAIT.
-- `justice_rendre_sentence(p_affaire jsonb, p_peine text)` recevait :
--   . `p_peine` : une CHAINE LIBRE, archivee telle quelle dans `jugements.peine`. Le serveur ne
--     la confrontait a AUCUN bareme -- il n'en connaissait aucun ;
--   . `p_affaire` : le BLOB ENTIER de l'affaire, fusionne sur la ligne existante
--     (`v_existante || p_affaire`). L'accuse, le motif, la ville et le pays d'une affaire deja
--     enregistree pouvaient donc etre REECRITS par l'appelant a l'instant du jugement. Seul
--     `status` etait impose.
-- Et la duree reellement infligee ne venait meme pas de la : `appliquerSentence` posait
-- `let duree = 3` EN DUR, modulee par `affaire.circonstanceAttenuante` et `affaire.aggravation`,
-- deux drapeaux portes par le meme blob client. Le QHS valait 30 jours en dur, la torture
-- 3 x (n+1) comptes par le navigateur.
--
-- DEUX -- LA PLAINTE EXISTAIT AVANT D'ETRE PAYEE.
-- `soumettrePlaynte` appelait `plainte_deposer` (qui CREE le dossier), PUIS `deduireCoutOrdre`.
-- En cas de refus de paiement elle appelait `signalerRefusCout(rCout)` et CONTINUAIT : le
-- dossier restait ouvert, instruit, parfois deja suivi d'une garde a vue, sans qu'un seul PA ait
-- ete preleve. Le `return` manquait, et meme avec lui les deux actes n'auraient pas ete atomiques.
--
-- CE QUE CETTE MIGRATION FAIT.
--   . Le calcul de la peine devient une fonction SERVEUR UNIQUE, `justice_peine_calcul`, et les
--     deux portes -- celle qui PROPOSE au juge et celle qui ENREGISTRE -- l'appellent toutes les
--     deux. Elles ne peuvent donc pas diverger : ce que l'ecran annonce est ce que le greffe
--     validera.
--   . `justice_rendre_sentence` change de signature. Elle ne recoit plus d'affaire, seulement son
--     IDENTIFIANT, et relit la ligne elle-meme. L'ancienne surcharge (jsonb, text) est
--     explicitement SUPPRIMEE -- `CREATE OR REPLACE` avec d'autres parametres CREERAIT une
--     seconde fonction, et le vieux chemin resterait appelable par son nom.
--   . `plainte_deposer` preleve le cout AVANT d'inserer, dans la meme transaction. Un refus de
--     paiement ne laisse rien.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS, ET C'EST DELIBERE.
--   . Elle ne cree NI procureur, NI parquet, NI chronologie procedurale, NI relaxe, NI
--     requalification formelle : ce sont les tranches suivantes du chantier judiciaire, et les
--     livrer a moitie creerait deux autorites concurrentes sur la meme procedure.
--   . Elle ne change AUCUN bareme, AUCUN cout, AUCUNE regle de game design. Le QHS vaut toujours
--     30 jours et la torture toujours 3 x (n+1) : ces deux valeurs sont RECOPIEES de la regle
--     validee existante, pas derivees du catalogue -- le QHS et la torture ne sont pas des peines
--     du code penal, ce sont des mecaniques a part. Elles passent desormais par le serveur, qui
--     les IMPOSE au lieu de les recevoir.

-- ============================================================================================
-- 1. LE CALCUL DE LA PEINE -- UNE SEULE FORMULE, DEUX APPELANTS
-- ============================================================================================
-- Rend TOUJOURS la valeur autoritaire, jamais celle qu'on lui propose : l'appelant passe un genre
-- et une infraction, il recoit ce que le serveur accepte. Les genres `qhs` et `torture` rendent
-- une plage reduite a un POINT (min = max = la valeur imposee), ce qui suffit a les rendre
-- invalidables : toute autre valeur sera refusee par la porte d'enregistrement.
CREATE OR REPLACE FUNCTION public.justice_peine_calcul(
  p_infraction text, p_genre text, p_cible text, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_b jsonb; v_n integer; v_jmin integer; v_jmax integer;
        v_amin integer; v_amax integer; v_impose boolean := false;
BEGIN
  IF p_genre NOT IN ('prison', 'amende', 'amenagement', 'qhs', 'torture') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'genre_inconnu', 'genre', p_genre);
  END IF;

  v_b := public.infraction_peine_bornes(p_infraction);
  IF coalesce((v_b ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_b;   -- infraction_inconnue : le refus porte deja sa raison
  END IF;

  v_jmin := (v_b ->> 'jours_min')::integer;  v_jmax := (v_b ->> 'jours_max')::integer;
  v_amin := (v_b ->> 'amende_min')::integer; v_amax := (v_b ->> 'amende_max')::integer;

  IF p_genre = 'prison' THEN
    -- La modulation du juge porte sur les JOURS, dans la plage du catalogue. Aucune amende : le
    -- jeu n'en preleve aucune aujourd'hui (voir le genre `amende` ci-dessous).
    v_amin := 0; v_amax := 0;

  ELSIF p_genre = 'amende' THEN
    -- La modulation porte sur le MONTANT. Aucun jour de detention.
    -- DETTE NOMMEE, NON TRAITEE ICI : l'amende n'est PRELEVEE nulle part. `appliquerSentence`
    -- composait « Amende de 500 FR » -- un 500 en dur, sans rapport avec le bareme -- et
    -- n'appelait aucune porte de debit. Le montant devient au moins REEL (celui du catalogue,
    -- modulable) et verifie ; le prelevement reste a construire.
    v_jmin := 0; v_jmax := 0;

  ELSIF p_genre = 'amenagement' THEN
    -- Mention au registre, sans consequence mecanique -- c'etait deja le cas.
    v_jmin := 0; v_jmax := 0; v_amin := 0; v_amax := 0; v_impose := true;

  ELSIF p_genre = 'qhs' THEN
    -- TRENTE JOURS, RECOPIES DE LA REGLE VALIDEE, pas derives du catalogue : le QHS n'est pas une
    -- peine du code penal, c'est une mecanique a part, arbitree le 26 aout 2026 et inchangee ici.
    -- Le serveur l'IMPOSE desormais, au lieu de recevoir du navigateur une duree qu'il n'a jamais
    -- verifiee.
    v_jmin := 30; v_jmax := 30; v_amin := 0; v_amax := 0; v_impose := true;

  ELSE   -- torture
    -- TROIS JOURS PAR CONDAMNATION, CUMULES, RECOPIES DE LA REGLE VALIDEE. Le cumul se comptait
    -- cote navigateur (`sbGetActionsTracablesParAuteur`) : il se compte ici, sur la meme trace
    -- `condamnation_torture`, qui est ecrite avec une expiration a +36500 jours et ne s'eteint
    -- donc jamais. C'est la meme formule, deplacee la ou elle ne peut plus etre reecrite.
    SELECT count(*) INTO v_n FROM public.actions_tracables a
     WHERE a.auteur = p_cible AND a.type_action = 'condamnation_torture'
       AND a.country IS NOT DISTINCT FROM p_pays;
    v_jmin := 3 * (v_n + 1); v_jmax := v_jmin; v_amin := 0; v_amax := 0; v_impose := true;
  END IF;

  RETURN v_b || jsonb_build_object(
    'genre', p_genre,
    'jours_min', v_jmin, 'jours_max', v_jmax,
    'amende_min', v_amin, 'amende_max', v_amax,
    -- `impose` dit a l'ecran qu'il n'y a RIEN a moduler : la valeur est celle-la et pas une autre.
    'impose', v_impose,
    -- La valeur par defaut proposee au juge : la reference du catalogue pour les genres
    -- modulables, la valeur imposee sinon. Toujours dans la plage, par construction.
    'jours_defaut', CASE WHEN v_impose THEN v_jmin
                         WHEN p_genre = 'prison' THEN (v_b ->> 'jours_reference')::integer
                         ELSE 0 END,
    'amende_defaut', CASE WHEN p_genre = 'amende' THEN (v_b ->> 'amende_reference')::integer
                          ELSE 0 END);
END;
$$;
COMMENT ON FUNCTION public.justice_peine_calcul(text, text, text, text) IS
  'LA formule de peine du serveur, unique : la plage autorisee pour une infraction canonique et un genre de sanction. Les deux portes du jugement -- celle qui propose au juge et celle qui enregistre -- l''appellent toutes les deux, donc elles ne peuvent pas diverger. Les genres qhs et torture rendent une plage reduite a un POINT : leur valeur est IMPOSEE par le serveur (30 jours, et 3 x (n+1) pour la torture), recopiee des regles validees et non derivee du catalogue.';

-- ============================================================================================
-- 2. CE QUE LE JUGE PEUT PRONONCER -- LECTURE
-- ============================================================================================
-- L'ecran du juge a besoin de la plage REELLE avant de proposer un curseur. Sans elle il
-- afficherait une plage inventee, et le greffe refuserait ensuite -- ce qui est la pire des
-- interfaces : un bouton qui ment.
CREATE OR REPLACE FUNCTION public.justice_peine_proposer(
  p_affaire_id text, p_infraction text, p_genre text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- MEME REGLE D'AUTORITE QUE LA PORTE D'ENREGISTREMENT, lue en base : juge ou commissaire DE LA
  -- VILLE de l'affaire. Un ecran qui s'ouvrirait sans elle promettrait une competence absente.
  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') = 'jugee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_deja_jugee'); END IF;

  RETURN public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays)
         || jsonb_build_object('affaire', p_affaire_id,
                               'accuse', v_a ->> 'cible',
                               'motif_allegue', v_a ->> 'motif');
END;
$$;
COMMENT ON FUNCTION public.justice_peine_proposer(text, text, text) IS
  'Ce que le juge PEUT prononcer sur une affaire, pour son ecran : la plage reelle calculee par justice_peine_calcul, apres verification de la competence et de l''etat de l''affaire. Lecture seule. Elle rend aussi le motif ALLEGUE de la plainte, que la qualification du juge peut contredire sans l''effacer.';

-- ============================================================================================
-- 3. LA SENTENCE -- NOUVELLE PORTE, ET L'ANCIENNE DISPARAIT
-- ============================================================================================
-- L'ANCIENNE SURCHARGE EST SUPPRIMEE AVANT, ET C'EST INDISPENSABLE. `CREATE OR REPLACE` avec une
-- autre liste de parametres ne remplace pas : il CREE une seconde fonction. Les deux auraient
-- coexiste, et le vieux chemin -- celui qui accepte une chaine libre -- serait reste appelable
-- par son nom depuis n'importe quel navigateur. Le piege a deja ete rencontre le 11 octobre 2026
-- sur `election_resultats_consigner`.
DROP FUNCTION IF EXISTS public.justice_rendre_sentence(jsonb, text);

CREATE OR REPLACE FUNCTION public.justice_rendre_sentence(
  p_affaire_id text, p_infraction text, p_genre text,
  p_jours integer DEFAULT 0, p_amende integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_juge text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer;
  v_calc jsonb; v_jours integer; v_amende integer; v_libelle text; v_peine text;
  v_jug text; v_n integer; v_motifs jsonb;
BEGIN
  v_juge := public.mon_personnage();
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_affaire_id, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_invalide'); END IF;

  -- LE VERROU SUR L'AFFAIRE EST LA REVENDICATION : deux juges simultanes se serialisent ici, et
  -- le second lit « jugee ».
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') = 'jugee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_deja_jugee'); END IF;

  -- LA MEME FORMULE QUE CELLE QUI A ETE PROPOSEE AU JUGE. Elle est RECALCULEE, jamais relue d'un
  -- parametre : entre l'ouverture de l'ecran et le clic, le navigateur a eu tout le temps de
  -- changer d'avis sur ce qu'il annonce.
  v_calc := public.justice_peine_calcul(p_infraction, p_genre, v_a ->> 'cible', v_pays);
  IF coalesce((v_calc ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_calc; END IF;

  v_jours  := coalesce(p_jours, 0);
  v_amende := coalesce(p_amende, 0);

  -- LES BORNES SONT LA LOI. Hors plage, rien n'est ecrit -- et le refus NOMME la plage, pour que
  -- l'ecart soit lisible au lieu d'etre devine.
  IF v_jours < (v_calc ->> 'jours_min')::integer
     OR v_jours > (v_calc ->> 'jours_max')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'peine_hors_bornes',
      'demande_jours', v_jours,
      'jours_min', (v_calc ->> 'jours_min')::integer,
      'jours_max', (v_calc ->> 'jours_max')::integer,
      'jours_reference', (v_calc ->> 'jours_reference')::integer);
  END IF;
  IF v_amende < (v_calc ->> 'amende_min')::integer
     OR v_amende > (v_calc ->> 'amende_max')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'amende_hors_bornes',
      'demande_amende', v_amende,
      'amende_min', (v_calc ->> 'amende_min')::integer,
      'amende_max', (v_calc ->> 'amende_max')::integer,
      'amende_reference', (v_calc ->> 'amende_reference')::integer);
  END IF;

  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_juge;
  v_jour := coalesce(v_jour, 1);
  v_libelle := v_calc ->> 'libelle';

  -- LE LIBELLE DE LA PEINE EST COMPOSE PAR LE SERVEUR. C'etait la chaine libre du navigateur ;
  -- c'est desormais une phrase derivee des valeurs qu'il vient de valider.
  v_peine := CASE p_genre
    WHEN 'prison'      THEN 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
    WHEN 'amende'      THEN 'Amende de ' || v_amende || ' FR'
    WHEN 'amenagement' THEN 'Amenagement : pointage quotidien au commissariat'
    WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'
    ELSE                    'Prison ' || v_jours || ' jours + popularite a zero'
  END;

  -- LES MOTIFS PORTENT LA DUREE VALIDEE. `justice_executer_condamnation` les somme pour ouvrir la
  -- detention et retombe sur 3 jours quand elle n'en trouve aucun : une ligne de jugement sans
  -- motifs faisait donc executer trois jours quelle que soit la sentence.
  v_motifs := CASE WHEN v_jours > 0 THEN jsonb_build_array(jsonb_build_object(
      'type', v_libelle, 'infraction', v_calc ->> 'infraction', 'jours', v_jours,
      'city', v_ville, 'source', 'jugement',
      'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
    ELSE '[]'::jsonb END;

  -- L'IDENTIFIANT DU JUGEMENT EST DERIVE DE L'AFFAIRE, pas d'une horloge : un rejeu ne peut pas
  -- produire une seconde ligne, meme si la garde de statut etait un jour contournee.
  v_jug := 'jug-' || p_affaire_id;
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_jug, v_pays, coalesce(v_ville, 'capitale'), v_a ->> 'cible',
          v_libelle, v_peine, v_juge, v_jour, false,
          jsonb_build_object(
            'infraction', v_calc ->> 'infraction',
            'infraction_libelle', v_libelle,
            'genre', p_genre,
            'jours', v_jours, 'amende', v_amende,
            'jours_reference', (v_calc ->> 'jours_reference')::integer,
            'jours_min', (v_calc ->> 'jours_min')::integer,
            'jours_max', (v_calc ->> 'jours_max')::integer,
            'amende_reference', (v_calc ->> 'amende_reference')::integer,
            -- L'HISTORIQUE DE LA QUALIFICATION COMMENCE ICI, et il n'efface rien. Le motif
            -- ALLEGUE par le plaignant ou par la police est conserve a cote de la qualification
            -- retenue par le juge, qui peut le contredire. Quand le parquet existera, sa propre
            -- qualification s'intercalera entre les deux sans rien reecrire.
            'motif_allegue', v_a ->> 'motif',
            'motifs', v_motifs,
            'issue_judiciaire', v_peine))
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- L'AFFAIRE N'EST PLUS FUSIONNEE AVEC UN BLOB D'APPELANT. La base de la fusion est `v_a`, la
  -- ligne RELUE en base sous verrou ; seuls les champs que le serveur vient d'etablir s'y
  -- ajoutent. Tout le reste de la ligne est celui qui y etait deja.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'status', 'jugee',
           'juge', v_juge,
           'juge_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'qualification_finale', v_calc ->> 'infraction',
           'qualification_libelle', v_libelle,
           'peine_genre', p_genre,
           'peine_jours', v_jours,
           'peine_amende', v_amende,
           'peine_libelle', v_peine))::text
   WHERE id = p_affaire_id;

  RETURN jsonb_build_object('ok', true, 'jugement_id', v_jug, 'affaire', p_affaire_id,
    'juge', v_juge, 'jour', v_jour, 'jugement_cree', v_n = 1,
    'infraction', v_calc ->> 'infraction', 'infraction_libelle', v_libelle,
    'genre', p_genre, 'jours', v_jours, 'amende', v_amende, 'peine', v_peine,
    'motifs', v_motifs);
END;
$$;
COMMENT ON FUNCTION public.justice_rendre_sentence(text, text, text, integer, integer) IS
  'La sentence, calculee et bornee AU SERVEUR. Elle ne recoit plus l''affaire mais son identifiant, et relit la ligne elle-meme : le blob client ne peut plus reecrire l''accuse, le motif ni la ville au moment du jugement. La peine est validee contre la plage du catalogue (-50 % / +50 %) par justice_peine_calcul, la meme formule que celle proposee a l''ecran. Le libelle de la peine est COMPOSE par le serveur, jamais recu. L''ancienne surcharge (jsonb, text) est supprimee, pas remplacee.';

-- ============================================================================================
-- 4. LA PLAINTE SE PAIE AVANT D'EXISTER
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_commissaire text; v_est_pj boolean := false;
  v_id text; v_res jsonb; v_statut text; v_data jsonb; v_cible text;
  v_pa integer; v_cost integer; v_n integer; v_paye jsonb;
BEGIN
  SELECT d.name, d.country, coalesce(d.current_city, 'capitale'), coalesce(d.day, 1)
    INTO v_nom, v_pays, v_ville, v_jour
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;
  v_cible := coalesce(nullif(btrim(p_cible), ''), 'X');

  -- ANTI-SPAM : une seule plainte en cours par plaignant et par cible. Le dossier doit etre
  -- instruit avant qu'un second soit ouvert sur le meme sujet. VERIFIE AVANT LE PAIEMENT : une
  -- plainte refusee pour doublon ne doit rien couter.
  IF EXISTS (SELECT 1 FROM public.plaintes_en_cours p
              WHERE p.country = v_pays
                AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
                AND (p.data::jsonb) ->> 'auteur' = v_nom
                AND (p.data::jsonb) ->> 'cible'  = v_cible
                AND (p.data::jsonb) ->> 'status' = 'deposee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plainte_deja_en_cours');
  END IF;

  -- LE COUT N'EST PAS ECRIT ICI, IL EST LU AU MIROIR. `ordres_couts` est la declaration serveur
  -- du canon de data.js ; recopier « 1 PA » dans cette fonction en ferait une seconde source de
  -- verite, qui divergerait au premier arbitrage. FAIL CLOSED : si le miroir ne declare pas
  -- exactement une ligne pour cet ordre, on refuse plutot que de deviner un montant.
  SELECT count(*) INTO v_n FROM public.ordres_couts o WHERE o.fn = 'plainte_police';
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_indetermine',
                              'fn', 'plainte_police', 'declarations', v_n);
  END IF;
  SELECT o.pa, o.cost INTO v_pa, v_cost FROM public.ordres_couts o WHERE o.fn = 'plainte_police';

  -- LE PAIEMENT PRECEDE LA CREATION, DANS LA MEME TRANSACTION. C'est le correctif : le navigateur
  -- creait le dossier PUIS tentait de payer, et un refus de paiement laissait derriere lui un
  -- dossier ouvert, parfois deja instruit et suivi d'une garde a vue, sans un PA preleve.
  v_paye := public.payer_ordre(v_nom, 'plainte_police', v_pa, v_cost);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paye ->> 'raison', 'paiement_refuse'),
                              'paiement', v_paye);
  END IF;

  SELECT d.name INTO v_commissaire
    FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.poste ->> 'id' = 'commissaire' AND d.poste ->> 'city' = v_ville
   LIMIT 1;
  IF v_commissaire IS NOT NULL THEN
    v_est_pj := true;
  ELSE
    SELECT t.nom_pnj INTO v_commissaire FROM public.titulaires_pnj t
     WHERE t.country = v_pays AND t.poste_id = 'commissaire' AND t.city = v_ville LIMIT 1;
  END IF;

  v_id := 'plainte-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);

  IF v_est_pj THEN
    v_statut := 'deposee';
    v_res := jsonb_build_object('ok', true, 'decision', 'transmise_commissaire');
  ELSE
    v_res := public.plainte_instruire_interne(v_pays, v_ville, v_cible, p_motif,
                                              coalesce(v_commissaire, 'Commissariat'));
    v_statut := v_res ->> 'decision';
  END IF;

  v_data := jsonb_build_object(
    'id', v_id, 'auteur', v_nom, 'cible', v_cible, 'motif', p_motif,
    'jour', v_jour, 'city', v_ville, 'country', v_pays, 'status', v_statut,
    'commissaire', v_commissaire, 'commissaire_pj', v_est_pj,
    'decide_le', CASE WHEN v_est_pj THEN NULL
                      ELSE to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END,
    'motif_decision', v_res ->> 'motif_decision');

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text);

  -- Le verdict du paiement remonte avec le dossier : le navigateur n'a plus a payer de son cote,
  -- et il a besoin des soldes pour rafraichir l'affichage.
  RETURN v_res || jsonb_build_object('id', v_id, 'commissaire', v_commissaire,
                                     'commissaire_pj', v_est_pj, 'ville', v_ville,
                                     'paiement', v_paye);
END;
$$;
COMMENT ON FUNCTION public.plainte_deposer(text, text) IS
  'Depot d''une plainte, PAIEMENT COMPRIS et dans la meme transaction. Le cout est lu au miroir ordres_couts (fail closed : zero ou plusieurs declarations pour `plainte_police` et le depot est refuse), preleve par payer_ordre AVANT l''insertion. Un paiement refuse ne laisse aucun dossier -- c''etait le defaut : le navigateur creait le dossier puis tentait de payer, et continuait meme en cas de refus.';

-- ============================================================================================
-- 5. DROITS
-- ============================================================================================
REVOKE ALL ON FUNCTION public.justice_peine_calcul(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.justice_peine_proposer(text, text, text)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.justice_rendre_sentence(text, text, text, integer, integer) FROM PUBLIC, anon, authenticated;

-- La formule brute reste INTERNE : elle ne verifie aucune competence, c'est le role de ses deux
-- appelants. L'accorder a un client lui donnerait un calculateur de peine sans juge.
GRANT EXECUTE ON FUNCTION public.justice_peine_calcul(text, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_peine_proposer(text, text, text)     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(text, text, text, integer, integer)
  TO authenticated, service_role;

-- ============================================================================================
-- 6. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text; v_args text;
BEGIN
  -- P1 : L'ANCIENNE PORTE N'EXISTE PLUS, et il n'en reste qu'UNE. Deux surcharges auraient laisse
  --      le vieux chemin -- celui qui accepte une chaine libre -- appelable par son nom.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'justice_rendre_sentence';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- % version(s) de justice_rendre_sentence au lieu d''une', v_n;
  END IF;

  SELECT pg_get_functiondef(p.oid), pg_get_function_identity_arguments(p.oid)
    INTO v_txt, v_args FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'justice_rendre_sentence';

  -- P2 : LA PORTE NE RECOIT PLUS DE BLOB D'AFFAIRE -- aucun parametre jsonb dans sa signature.
  --      Et la base de la fusion est la ligne RELUE (`v_a`), pas un parametre : c'est une
  --      assertion POSITIVE, parce que chercher l'absence de « || p_affaire » attrapait par
  --      sous-chaine le legitime « 'jug-' || p_affaire_id ».
  IF position('jsonb' IN v_args) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte accepte encore un jsonb : %', v_args;
  END IF;
  IF position('SET data = (v_a || jsonb_build_object(' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la fusion ne part pas de la ligne relue en base';
  END IF;

  -- P3 : LA PEINE EST BORNEE, ET LE REFUS EST NOMME.
  IF position('peine_hors_bornes' IN v_txt) = 0
     OR position('amende_hors_bornes' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la porte n''a pas de refus hors bornes';
  END IF;

  -- P4 : LA PLAGE EST RECALCULEE DANS LA PORTE, jamais relue d'un parametre.
  IF position('justice_peine_calcul(p_infraction, p_genre' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la porte ne recalcule pas la plage';
  END IF;

  -- P5 : LES DEUX PORTES APPELLENT LA MEME FORMULE. Si elles divergeaient, l'ecran promettrait
  --      une plage que le greffe refuserait.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('justice_peine_proposer', 'justice_rendre_sentence')
     AND position('public.justice_peine_calcul(' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- % porte(s) sur 2 appellent la formule unique', v_n;
  END IF;

  -- P6 : PLUS AUCUN PARAMETRE DE PEINE LIBRE dans la signature.
  IF position('p_peine' IN v_args) > 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- un parametre de peine libre subsiste : %', v_args;
  END IF;

  -- P7 : LA PLAINTE PAIE AVANT D'INSERER. L'ORDRE DES DEUX INSTRUCTIONS EST LA PREUVE : payer
  --      apres l'insertion laisserait exactement le dossier impaye qu'on ferme ici.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'plainte_deposer';
  IF position('payer_ordre' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le depot de plainte ne paie pas';
  END IF;
  IF position('v_paye := public.payer_ordre' IN v_txt)
     > position('INSERT INTO public.plaintes_en_cours' IN v_txt) THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le paiement vient APRES l''insertion du dossier';
  END IF;

  -- P8 : LE COUT N'EST PAS ECRIT DANS LA PORTE, il est lu au miroir -- sinon deux sources de
  --      verite pour un meme montant.
  IF position('FROM public.ordres_couts o WHERE o.fn = ''plainte_police''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- le cout du depot n''est pas lu au miroir';
  END IF;

  -- P9 : LE DOUBLON EST REFUSE AVANT LE PAIEMENT -- une plainte refusee ne coute rien.
  IF position('plainte_deja_en_cours' IN v_txt)
     > position('v_paye := public.payer_ordre' IN v_txt) THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le doublon est verifie apres le paiement';
  END IF;

  -- P10 : AUCUNE DES TROIS PORTES NEUVES N'EST OUVERTE A anon NI A PUBLIC.
  SELECT count(*) INTO v_n FROM pg_proc p, aclexplode(p.proacl) ae
   LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('justice_peine_calcul','justice_peine_proposer','justice_rendre_sentence')
     AND coalesce(r.rolname, 'PUBLIC') IN ('anon', 'PUBLIC');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10 ECHOUEE -- % droit(s) anon/PUBLIC', v_n; END IF;

  -- P11 : LA FORMULE BRUTE RESTE INTERNE. Elle ne verifie aucune competence : accordee a un
  --       client, elle serait un calculateur de peine sans juge.
  SELECT count(*) INTO v_n FROM pg_proc p, aclexplode(p.proacl) ae
   LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'justice_peine_calcul'
     AND coalesce(r.rolname, 'PUBLIC') = 'authenticated';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P11 ECHOUEE -- la formule brute est accordee au client'; END IF;

  -- P12 : LES DEUX PORTES DE JUGEMENT VERIFIENT LA COMPETENCE ET L'ETAT DE L'AFFAIRE.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('justice_peine_proposer', 'justice_rendre_sentence')
     AND position('affaire_autorite_de' IN pg_get_functiondef(p.oid)) > 0
     AND position('affaire_deja_jugee' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- % porte(s) sur 2 verifient competence et etat', v_n;
  END IF;

  RAISE NOTICE 'LES 12 PREUVES SONT VERTES.';
END
$preuves$;
