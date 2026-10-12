-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012142450 (UTC), nom
-- `tribunal_signaler_un_recherche_a_la_police`.
-- Le registre passe de 686 a 687 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5a181ad364d11737eaaf17b0dc7f9b0c, 20683 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL, CHEMIN CRITIQUE (4/6) -- SIGNALER UN RECHERCHE, ET LES DIX SECONDES
--
-- EN REPUBLIA, UN CITOYEN N'ARRETE PERSONNE : il appelle, et la police vient A UN ENDROIT. La
-- piece exacte -- quatre coordonnees -- est enregistree, parce que c'est elle que le serveur
-- REVALIDE a l'echeance : si la cible est partie, l'intervention ECHOUE et ne la poursuit nulle
-- part. Elle reste recherchee.
--
-- LES DIX SECONDES SONT UNE FENETRE DE FUITE, PAS UNE ANIMATION. Le signale n'est jamais averti :
-- la table est fermee en lecture aux clients, et la porte ne touche ni sa fiche ni ses courriers.
-- Un compte a rebours trafique ne fait qu'arriver trop tot et se faire refuser.
--
-- TROIS PROTECTIONS DE CONCURRENCE : un INDEX UNIQUE PARTIEL sur les signalements vivants d'une
-- meme cible, un COMPARE-AND-SWAP sur la resolution, et le ramassage des signalements oublies --
-- un navigateur ferme avant l'echeance laisserait sinon sa cible protegee a vie par l'anti-doublon.
--
-- « RECHERCHE » A DESORMAIS UNE DEFINITION UNIQUE (`justice_est_recherche`) : deux portes en ont
-- besoin -- celle qui affiche le statut et celle qui permet de le signaler -- et deux copies
-- auraient diverge.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- SIGNALER UN RECHERCHE A LA POLICE, ET LES DIX SECONDES
-- 12 octobre 2026 -- §H du cahier des charges
--
-- EN REPUBLIA, UN CITOYEN N'ARRETE PERSONNE. Il n'y a pas d'agression citoyenne ici : il appelle
-- la police, et c'est la police qui vient. Cette porte est donc bornee a Republia -- la
-- possibilite d'arreter soi-meme appartient a un autre empire et a une autre tranche, et l'ouvrir
-- « au cas ou » serait l'etendre sans decision.
--
-- LES DIX SECONDES SONT UNE FENETRE DE FUITE, PAS UNE ANIMATION. Le signale n'est PAS averti :
-- seul le signaleur voit le compte a rebours. Ce que ces dix secondes donnent au recherche, c'est
-- une chance de sortir de la piece sans savoir qu'il est attendu -- et s'il sort, l'intervention
-- ECHOUE. Elle ne le poursuit jamais ailleurs : la police vient a UN ENDROIT, pas apres UNE
-- PERSONNE. Il reste recherche.
--
-- LE NAVIGATEUR NE FAIT QUE COMPTER. L'autorite est entierement serveur, en deux temps : la porte
-- de signalement enregistre la PIECE EXACTE et l'echeance, la porte de resolution refuse avant
-- l'echeance et RELIT la presence de la cible pour la comparer aux quatre coordonnees
-- enregistrees. Un compte a rebours trafique ne fait donc qu'arriver trop tot et se faire
-- refuser ; il ne peut ni avancer l'arrestation, ni la faire reussir sur une piece vide.
--
-- LES PROTECTIONS DE CONCURRENCE, et chacune a sa raison :
--   . un INDEX UNIQUE PARTIEL sur les signalements vivants d'une meme cible -- deux joueurs ne
--     declenchent pas deux interventions sur la meme personne, et un double clic non plus ;
--   . un COMPARE-AND-SWAP sur `resolu_le` a la resolution -- une seule arrestation, meme si deux
--     onglets arrivent a l'echeance en meme temps ;
--   . le RAMASSAGE des signalements oublies : un navigateur ferme avant l'echeance laisserait
--     sinon sa cible protegee a vie par l'anti-doublon.
--
-- AUCUN EFFET DE BORD N'EST AJOUTE. `arrestation_urgence` ajuste les indices de la ville quand une
-- AUTORITE arrete ; ici l'acte est l'appel d'un citoyen, et lui attribuer les memes effets serait
-- decider d'une consequence sociale que personne n'a arbitree. La detention d'un jour, elle, est
-- celle de la chaine existante -- meme acte, meme duree.
--
-- PREUVES STRUCTURELLES -- 10.

-- ============================================================================================
-- 1. « RECHERCHE » A UNE SEULE DEFINITION
-- ============================================================================================
-- Elle etait inline dans `justice_statuts_publics`. Deux portes en ont besoin desormais -- celle
-- qui affiche et celle qui signale -- et deux copies auraient divergé.
CREATE OR REPLACE FUNCTION public.justice_est_recherche(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d,
           jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array'
                                     THEN d.recherche ELSE '[]'::jsonb END) e
     WHERE d.name = p_nom
       AND NOT EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(p_nom) v
                        WHERE v.infraction IS NOT NULL AND v.infraction = (e ->> 'acte')));
$$;
COMMENT ON FUNCTION public.justice_est_recherche(text) IS
  'Cette personne est-elle RECHERCHEE ? Il reste au moins une entree de son tableau `recherche` dont l''acte n''est pas suspendu par une inculpation en cours. Definition UNIQUE : la porte qui affiche le statut et celle qui permet de le signaler lisent la meme.';
REVOKE ALL ON FUNCTION public.justice_est_recherche(text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.justice_statuts_publics()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_p record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_p
    FROM public.presences pr WHERE pr.name = v_moi;
  IF v_p IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'statuts', '[]'::jsonb);
  END IF;

  RETURN jsonb_build_object('ok', true, 'statuts', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'nom', x.nom, 'recherche', x.recherche, 'inculpe', x.inculpe) ORDER BY x.nom)
      FROM (
        SELECT pr.name AS nom,
               public.justice_est_recherche(pr.name) AS recherche,
               EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(pr.name)) AS inculpe
          FROM public.presences pr
         WHERE pr.country IS NOT DISTINCT FROM v_p.country
           AND pr.city IS NOT DISTINCT FROM v_p.city
           AND pr.building_id IS NOT DISTINCT FROM v_p.building_id
           AND pr.room_id IS NOT DISTINCT FROM v_p.room_id
      ) x
      WHERE x.recherche OR x.inculpe), '[]'::jsonb));
END;
$$;

-- ============================================================================================
-- 2. LE REGISTRE DES SIGNALEMENTS
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.signalements_police (
  id           text PRIMARY KEY,
  pays         text NOT NULL,
  ville        text NOT NULL,
  building_id  text NOT NULL,
  room_id      text NOT NULL,
  signaleur    text NOT NULL,
  cible        text NOT NULL,
  pose_le      timestamptz NOT NULL DEFAULT now(),
  echeance     timestamptz NOT NULL,
  resolu_le    timestamptz,
  issue        text,
  CONSTRAINT signalements_police_pas_soi CHECK (signaleur <> cible),
  CONSTRAINT signalements_police_issue_connue
    CHECK (issue IS NULL OR issue IN ('arrestation', 'cible_partie', 'abandonne')),
  -- L'ISSUE ET LA RESOLUTION VONT ENSEMBLE : un signalement resolu sans issue, ou une issue sans
  -- resolution, serait un etat que rien ne sait relire.
  CONSTRAINT signalements_police_resolution_coherente
    CHECK ((resolu_le IS NULL) = (issue IS NULL))
);
ALTER TABLE public.signalements_police ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.signalements_police FROM anon, authenticated;
-- UN SEUL SIGNALEMENT VIVANT PAR CIBLE : l'anti-doublon et l'anti-spam en une contrainte, et elle
-- tient contre la concurrence la ou un SELECT prealable ne tiendrait pas.
CREATE UNIQUE INDEX IF NOT EXISTS signalements_police_un_vivant_par_cible
  ON public.signalements_police (pays, cible) WHERE resolu_le IS NULL;
CREATE INDEX IF NOT EXISTS signalements_police_par_signaleur
  ON public.signalements_police (signaleur, pose_le DESC);

COMMENT ON TABLE public.signalements_police IS
  'LES APPELS A LA POLICE. Un citoyen de Republia signale un RECHERCHE present dans sa piece ; dix secondes plus tard, la police vient A CET ENDROIT. La piece exacte est enregistree ici -- quatre coordonnees -- parce que c''est elle que le serveur revalide a l''echeance : si la cible est partie, l''intervention echoue et ne la poursuit nulle part. Le signale n''est jamais averti.';
COMMENT ON COLUMN public.signalements_police.echeance IS
  'L''instant a partir duquel l''intervention peut etre resolue. Dix secondes de temps REEL : c''est la fenetre de fuite du recherche, qui ignore qu''il est attendu.';

CREATE OR REPLACE FUNCTION public.police_delai_intervention_secondes()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 10 $$;
COMMENT ON FUNCTION public.police_delai_intervention_secondes() IS
  'Le delai d''intervention de la police apres un signalement, en secondes de temps reel. Dix. Declare une seule fois : la porte qui pose le signalement est la seule a le lire, et celle qui resout compare a l''echeance enregistree.';
REVOKE ALL ON FUNCTION public.police_delai_intervention_secondes() FROM PUBLIC;

-- ============================================================================================
-- 3. SIGNALER
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.police_signaler(p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; v_m record; v_c record; v_id text; v_ech timestamptz; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF p_cible = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur'); END IF;

  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi;
  -- BORNE A REPUBLIA, et c'est explicite : ailleurs, la question de l'arrestation citoyenne n'est
  -- pas tranchee, et une porte ouverte « au cas ou » serait une decision prise en passant.
  IF v_pays IS DISTINCT FROM 'republic' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'signalement_reserve_a_republia',
                              'pays', v_pays); END IF;

  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_m
    FROM public.presences pr WHERE pr.name = v_moi;
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_inconnue'); END IF;

  -- LA CIBLE DOIT ETRE DANS LA MEME PIECE AU DECLENCHEMENT. Quatre coordonnees, pas trois : un
  -- filtre sans `room_id` aurait permis de signaler quelqu'un a l'autre bout du batiment.
  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_c
    FROM public.presences pr WHERE pr.name = p_cible;
  IF v_c IS NULL
     OR v_c.country IS DISTINCT FROM v_m.country OR v_c.city IS DISTINCT FROM v_m.city
     OR v_c.building_id IS DISTINCT FROM v_m.building_id
     OR v_c.room_id IS DISTINCT FROM v_m.room_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_la_piece'); END IF;

  IF NOT public.justice_est_recherche(p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_recherchee'); END IF;

  -- RAMASSAGE DES SIGNALEMENTS OUBLIES. Un navigateur ferme avant l'echeance laisserait sa cible
  -- protegee a vie par l'index unique partiel : on clot ceux dont l'echeance est passee d'une
  -- minute, et eux seuls -- jamais un signalement encore en cours.
  UPDATE public.signalements_police
     SET resolu_le = now(), issue = 'abandonne'
   WHERE resolu_le IS NULL AND echeance < now() - interval '1 minute';

  v_ech := now() + make_interval(secs => public.police_delai_intervention_secondes());
  v_id := 'sig-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
          || substr(md5(v_moi || '|' || p_cible), 1, 6);

  BEGIN
    INSERT INTO public.signalements_police
      (id, pays, ville, building_id, room_id, signaleur, cible, echeance)
    VALUES (v_id, v_m.country, v_m.city, v_m.building_id, v_m.room_id, v_moi, p_cible, v_ech);
  EXCEPTION WHEN unique_violation THEN
    -- L'INDEX UNIQUE PARTIEL A MORDU : une intervention est deja en route sur cette personne.
    RETURN jsonb_build_object('ok', false, 'raison', 'intervention_deja_en_route');
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'cible', p_cible,
    'delai_secondes', public.police_delai_intervention_secondes(),
    'echeance', to_char(v_ech AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
END;
$$;
COMMENT ON FUNCTION public.police_signaler(text) IS
  'Un citoyen de Republia signale a la police un RECHERCHE present dans sa piece. Enregistre la PIECE EXACTE -- pays, ville, batiment, salle -- et l''echeance a dix secondes. La cible n''est jamais avertie : aucun courrier, aucun evenement, rien sur sa fiche. Un seul signalement vivant par cible, garanti par un index unique partiel et non par une relecture.';
REVOKE ALL ON FUNCTION public.police_signaler(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.police_signaler(text) TO authenticated;

-- ============================================================================================
-- 4. RESOUDRE L'INTERVENTION
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.police_signalement_resoudre(p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; v_s record; v_c record; v_n integer; v_res jsonb;
  v_issue text; v_motifs jsonb; v_jour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_s FROM public.signalements_police WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'signalement_absent'); END IF;
  -- SEUL LE SIGNALEUR RESOUT SON APPEL. Personne d'autre n'en connait l'identifiant, mais la
  -- garde ne repose pas sur ce secret.
  IF v_s.signaleur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_signalement'); END IF;
  IF v_s.resolu_le IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolu', true, 'issue', v_s.issue); END IF;
  -- LE DELAI EST UNE CONDITION SERVEUR. Un compte a rebours trafique arrive trop tot et se fait
  -- refuser : il ne peut pas avancer l'intervention.
  IF now() < v_s.echeance THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
      'echeance', to_char(v_s.echeance AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')); END IF;

  -- LA REVALIDATION : LA CIBLE EST-ELLE ENCORE DANS EXACTEMENT CETTE PIECE ?
  SELECT pr.country, pr.city, pr.building_id, pr.room_id INTO v_c
    FROM public.presences pr WHERE pr.name = v_s.cible;
  v_issue := CASE
    WHEN v_c IS NOT NULL
     AND v_c.country     IS NOT DISTINCT FROM v_s.pays
     AND v_c.city        IS NOT DISTINCT FROM v_s.ville
     AND v_c.building_id IS NOT DISTINCT FROM v_s.building_id
     AND v_c.room_id     IS NOT DISTINCT FROM v_s.room_id
    THEN 'arrestation' ELSE 'cible_partie' END;

  -- COMPARE-AND-SWAP : deux onglets arrivant ensemble a l'echeance n'arretent qu'une fois.
  UPDATE public.signalements_police
     SET resolu_le = now(), issue = v_issue
   WHERE id = p_id AND resolu_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolu', true); END IF;

  IF v_issue = 'cible_partie' THEN
    -- AUCUNE POURSUITE AILLEURS, ET LE STATUT EST CONSERVE : la police s'est deplacee pour rien.
    RETURN jsonb_build_object('ok', true, 'issue', 'cible_partie', 'cible', v_s.cible,
      'arrestation', false); END IF;

  -- L'ARRESTATION PASSE PAR LA CHAINE EXISTANTE, et pour la meme duree qu'une arrestation
  -- d'urgence : un jour. Le PV d'audition est ce qui l'ouvrira ensuite.
  v_jour := coalesce(public.jour_de_jeu_pays(v_s.pays), 1);
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Interpellation sur signalement', 'jour_fait', v_jour,
    'city', v_s.ville, 'jours', 1, 'source', 'signalement_police',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
             v_s.cible, 'Interpellation sur signalement', 1, v_s.ville, v_s.pays,
             v_motifs, 'Police de ' || v_s.ville, 'arrestation_sur_signalement');
  IF coalesce((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
    -- La detention n'a pas pu s'ouvrir -- deja detenu, par exemple. Le signalement reste resolu :
    -- la police est venue, et on ne raconte pas une arrestation qui n'a pas eu lieu.
    RETURN jsonb_build_object('ok', true, 'issue', 'arrestation', 'arrestation', false,
      'cible', v_s.cible, 'raison_detention', v_res ->> 'raison'); END IF;

  RETURN jsonb_build_object('ok', true, 'issue', 'arrestation', 'arrestation', true,
    'cible', v_s.cible, 'detention_id', v_res ->> 'detention_id', 'ville', v_s.ville);
END;
$$;
COMMENT ON FUNCTION public.police_signalement_resoudre(text) IS
  'Resout une intervention a l''echeance des dix secondes. Le SERVEUR relit la presence de la cible et la compare aux quatre coordonnees enregistrees : encore la, elle est interpellee par la chaine existante (un jour, comme une arrestation d''urgence) ; partie, l''intervention ECHOUE et ne la poursuit nulle part -- elle reste recherchee. Refuse avant l''echeance, et en compare-and-swap : deux onglets n''arretent qu''une fois.';
REVOKE ALL ON FUNCTION public.police_signalement_resoudre(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.police_signalement_resoudre(text) TO authenticated;

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LA TABLE EST FERMEE AUX CLIENTS, SOUS RLS, SANS POLICY.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'signalements_police' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- table absente ou sans RLS'; END IF;
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid = 'public.signalements_police'::regclass
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client', v_n; END IF;

  -- P2 : UN SEUL SIGNALEMENT VIVANT PAR CIBLE, PAR INDEX UNIQUE PARTIEL -- et non par relecture.
  SELECT count(*) INTO v_n FROM pg_index x JOIN pg_class ic ON ic.oid = x.indexrelid
   WHERE x.indrelid = 'public.signalements_police'::regclass
     AND ic.relname = 'signalements_police_un_vivant_par_cible'
     AND x.indisunique AND x.indpred IS NOT NULL;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE -- l''unicite partielle des signalements vivants manque'; END IF;

  -- P3 : LE DELAI EST DECLARE UNE FOIS, ET IL VAUT DIX SECONDES.
  IF public.police_delai_intervention_secondes() <> 10 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le delai d''intervention ne vaut pas 10 s'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'police_signaler';

  -- P4 : BORNE A REPUBLIA.
  IF position('signalement_reserve_a_republia' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le signalement n''est pas borne a Republia'; END IF;

  -- P5 : LA PIECE EST COMPAREE SUR QUATRE COORDONNEES AU DECLENCHEMENT.
  IF position('v_c.room_id IS DISTINCT FROM v_m.room_id' IN v_txt) = 0
     OR position('v_c.building_id IS DISTINCT FROM v_m.building_id' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la piece n''est pas comparee entierement'; END IF;

  -- P6 : LA CIBLE DOIT ETRE RECHERCHEE, par la definition UNIQUE.
  IF position('public.justice_est_recherche(p_cible)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- on peut signaler quelqu''un qui n''est pas recherche'; END IF;

  -- P7 : LA CIBLE N'EST JAMAIS AVERTIE. Aucun courrier, aucun evenement, aucune ecriture sur sa
  -- fiche dans la porte de signalement.
  IF position('sbSendMail' IN v_txt) > 0 OR position('mails' IN v_txt) > 0
     OR position('UPDATE public.personnages_donnees' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le signalement touche la cible ou la previent'; END IF;

  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'police_signalement_resoudre';

  -- P8 : LE DELAI EST UNE CONDITION SERVEUR, et la resolution est en compare-and-swap.
  IF position('IF now() < v_s.echeance THEN' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''echeance n''est pas opposee au serveur'; END IF;
  IF position('WHERE id = p_id AND resolu_le IS NULL' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la resolution n''est pas en compare-and-swap'; END IF;

  -- P9 : LA REVALIDATION PORTE SUR LES QUATRE COORDONNEES ENREGISTREES.
  IF position('v_c.room_id     IS NOT DISTINCT FROM v_s.room_id' IN v_txt) = 0
     OR position('v_c.building_id IS NOT DISTINCT FROM v_s.building_id' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- la revalidation ne compare pas la piece exacte'; END IF;

  -- P10 : UNE CIBLE PARTIE N'EST NI ARRETEE NI POURSUIVIE, ET RESTE RECHERCHEE -- aucun retrait
  -- de `recherche` dans cette porte.
  IF position('''cible_partie''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la fuite n''a pas d''issue nommee'; END IF;
  IF position('recherche_retirer' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- la resolution touche l''avis de recherche'; END IF;

  RAISE NOTICE 'LES 10 PREUVES SONT VERTES.';
END $preuves$;
