-- BANC DES DIX PARCOURS JUDICIAIRES COMPLETS (13 octobre 2026) -- 65 epreuves
--
-- CE BANC NE COMMITE RIEN. Il depose dix plaintes, nomme des magistrats, fait enqueter la police,
-- juger, plaider, temoigner, appeler, et se termine par un RAISE EXCEPTION INCONDITIONNEL qui
-- annule tout -- y compris l'avance d'horloge qu'il s'autorise.
--
-- POURQUOI IL EXISTE, ALORS QUE SEPT BANCS COUVRENT DEJA LA JUSTICE. Les autres mesurent des
-- PORTES, une par une : la garde du parquet, le minimum de trois jours, le verbatim d'une
-- deposition. Aucun ne suit une affaire DU DEPOT A SON ARCHIVAGE, et c'est la que vivent les
-- defauts de couture -- un statut qu'une porte pose et qu'une autre n'attend pas, un delai qui
-- court depuis le mauvais jour, une autorite competente dans une ville et muette dans l'autre.
--
-- LES DIX PARCOURS SONT REPARTIS SUR LES TROIS VILLES, deliberement : Luthecia a un `tribunal`
-- et un `commissariat`, Port-Sainte-Marie et Montrouge un `tribunal-local` et un
-- `commissariat-local`, et les resolveurs de site ne rendent pas les memes pieces. Un parcours
-- qui ne se joue qu'a la capitale ne prouve rien pour les deux autres.
--
--   P1  capitale  plainte -> non-lieu du parquet
--   P2  capitale  plainte -> enquete -> acte de police -> poursuites -> saisine -> PV ->
--                 audience fixee -> audience ouverte -> condamnation
--   P3  ville_a   plainte -> poursuites -> saisine -> relaxe
--   P4  ville_b   delit -> procedure simplifiee plaidee -> definitive, aucun appel
--   P5  capitale  CRIME -> procedure simplifiee refusee -> le tribunal juge
--   P6  ville_a   condamnation -> appel du condamne -> jugement d'appel -> indemnite
--   P7  ville_b   saisine -> le parquet abandonne -> le juge poursuit malgre tout
--   P8  capitale  temoins cites au depot -> deposition verbatim -> refus de temoigner
--   P9  ville_a   defense demandee, acceptee, dossier lu, rompue ; puis l'audience verrouille
--   P10 ville_b   delai de jugement expire -> charges abandonnees par la passe de minuit
--
-- UN DEPOT REFUSE ARRETE LE BANC SUR LE CHAMP, et ce n'est pas de la prudence decorative : un
-- identifiant d'affaire NULL rend VERTES toutes les epreuves du parcours qui suit, puisqu'elles
-- comptent alors zero ligne la ou elles en attendaient zero. Les dix depots levent donc, en
-- nommant le refus du serveur.
--
-- CHAQUE PARCOURS SE CLOT AVANT QUE LE SUIVANT NE NAISSE, et ce n'est pas une commodite de
-- banc : `plainte_deposer` refuse `plainte_deja_en_cours` tant qu'une affaire VIVANTE oppose le
-- meme plaignant a la meme personne, dans le meme pays. C'est la regle du jeu, et elle impose au
-- banc de conduire chaque affaire jusqu'a un verdict, un non-lieu ou une peremption -- ce qui est
-- exactement ce qu'un parcours complet doit faire. Les deux parcours qui ne se closaient pas
-- d'eux-memes (l'abandon du parquet, l'affaire des temoins) ont donc gagne leur acte final.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc parcours : LES 75 EPREUVES SONT VERTES. -- rien ne doit rester
--
-- LE DECOR NOMME CE QU'IL EXIGE. Cinq joueurs, et chacun a UN role : Phileas est le juge (il est
-- deplace de ville en ville, un siege a la fois), Lee est le Procureur de la Republique (un seul
-- pour tout Republia), May est la commissaire, Marsault est le plaignant, Ben est le prevenu.
-- Les carrieres sont posees explicitement : les trois postes judiciaires exigent la carriere
-- JUSTICE, et un officier s'y verrait refuser l'acces.

BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

-- LE JUGE CHANGE DE SIEGE ENTRE DEUX PARCOURS, et c'est le seul moyen de jouer trois villes avec
-- cinq fiches. La fonction fait les DEUX moities que le jeu exige : la ligne au registre des
-- postes, et le `poste` sur la fiche -- sans quoi `juge_moi()` ne le reconnait pas.
CREATE OR REPLACE FUNCTION pg_temp.siege_juge(p_qui text, p_ville text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  DELETE FROM public.postes_attribues WHERE poste_id = 'juge';
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-pj-juge', 'republic', 'juge', p_ville, p_qui, 'banc');
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'juge', 'city', p_ville) WHERE name = p_qui;
  UPDATE public.personnages_donnees SET current_city = p_ville,
         current_building = CASE WHEN p_ville = 'capitale' THEN 'tribunal' ELSE 'tribunal-local' END,
         current_room = CASE WHEN p_ville = 'capitale' THEN 'salle_audience' ELSE 'salle_audience_locale' END
   WHERE name = p_qui;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.siege_commissaire(p_qui text, p_ville text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  DELETE FROM public.postes_attribues WHERE poste_id = 'commissaire';
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-pj-comm', 'republic', 'commissaire', p_ville, p_qui, 'banc');
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'commissaire', 'city', p_ville) WHERE name = p_qui;
END $f$;

-- LE PROCUREUR DOIT ETRE DANS LE TRIBUNAL DE LA VILLE DE L'AFFAIRE : sa competence ne se partage
-- pas, elle se DEPLACE. Cette fonction le pose au bon endroit avant chaque acte du parquet.
CREATE OR REPLACE FUNCTION pg_temp.parquet_au_tribunal(p_qui text, p_ville text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.personnages_donnees SET current_city = p_ville,
         current_building = CASE WHEN p_ville = 'capitale' THEN 'tribunal' ELSE 'tribunal-local' END,
         current_room = CASE WHEN p_ville = 'capitale' THEN 'greffe' ELSE 'greffe' END
   WHERE name = p_qui;
END $f$;

-- LE PLAIGNANT DEPOSE AU COMMISSARIAT DE SA VILLE, et c'est la ville de SA fiche qui fait la
-- juridiction de l'affaire -- pas un parametre.
CREATE OR REPLACE FUNCTION pg_temp.au_commissariat(p_qui text, p_ville text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.personnages_donnees SET current_city = p_ville,
         current_building = CASE WHEN p_ville = 'capitale' THEN 'commissariat' ELSE 'commissariat-local' END,
         current_room = CASE WHEN p_ville = 'capitale' THEN 'accueil_police' ELSE 'accueil_loc' END,
         pa = 20
   WHERE name = p_qui;
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.libere(p_qui text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM public.detention_clore_interne(p_qui, 'purgee');
  UPDATE public.personnages_donnees SET est_emprisonne = NULL, recherche = '[]'::jsonb
   WHERE name = p_qui;
  DELETE FROM public.detentions WHERE nom = p_qui;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.siege_juge(text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.siege_commissaire(text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.parquet_au_tribunal(text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.au_commissariat(text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.libere(text) TO PUBLIC;

DO $banc$
DECLARE
  JUGE_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; JUGE text := 'Phileas Frogg';
  PROC_U text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; PROC text := 'Lee Capene';
  COMM_U text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a'; COMM text := 'May';
  PLAI_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; PLAI text := 'Marsault';
  PREV_U text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; PREV text := 'Ben';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_s text; v_jour integer; v_rang bigint; v_av text;
  -- LE JOUR COURANT, A PART. `v_jour` sert aussi de compteur de jours indus en P6 : le
  -- verrou d'audience ne doit pas l'ecraser au passage.
  v_auj integer;
  a1 text; a2 text; a3 text; a4 text; a5 text; a6 text; a7 text; a8 text; a9 text; a10 text;
  a11 text;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- ============================================================ LE DECOR
  DELETE FROM public.postes_attribues WHERE poste_id IN ('juge','procureur','commissaire','commandant');
  DELETE FROM public.carrieres_acquises WHERE personnage IN (JUGE, PROC, COMM, PLAI, PREV);
  UPDATE public.personnages_donnees SET poste = NULL, est_emprisonne = NULL,
         recherche = '[]'::jsonb, hp = 100, pa = 20, arg = 50000, country = 'republic'
   WHERE name IN (JUGE, PROC, COMM, PLAI, PREV);
  DELETE FROM public.detentions WHERE nom IN (JUGE, PROC, COMM, PLAI, PREV);
  DELETE FROM public.justice_indemnites WHERE beneficiaire IN (JUGE, PROC, COMM, PLAI, PREV);
  -- Les trois magistrats ont la carriere JUSTICE ; le plaignant est officier et le prevenu est
  -- du crime organise. Aucun des deux derniers ne pourrait sieger, et c'est voulu.
  UPDATE public.personnages_donnees SET career = 'magistrat'  WHERE name IN (JUGE, PROC, COMM);
  UPDATE public.personnages_donnees SET career = 'officer'    WHERE name = PLAI;
  UPDATE public.personnages_donnees SET career = 'criminal_c' WHERE name = PREV;

  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-pj-proc', 'republic', 'procureur', NULL, PROC, 'banc');
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','procureur') WHERE name = PROC;

  v_jour := public.jour_de_jeu_pays('republic');

  n := n + 1;   -- D1 : LE DECOR LUI-MEME EST VERIFIE. Un banc dont le decor ment prouve n'importe quoi.
  IF public.parquet_moi() IS NULL THEN
    ko := ko + 1; e := e || E'\nD1 : le Procureur du decor n''est pas reconnu'; END IF;
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  IF public.justice_juge_titulaire('republic','capitale') IS DISTINCT FROM JUGE THEN
    ko := ko + 1; e := e || E'\nD1 : le juge de Luthecia n''est pas celui du decor ('
                         || coalesce(public.justice_juge_titulaire('republic','capitale'),'-') || ')'; END IF;

  -- ============================================================ P1 : LE NON-LIEU (capitale)
  PERFORM pg_temp.au_commissariat(PLAI, 'capitale');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Il a tenu des propos mensongers sur mon compte', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a1 := v ->> 'id';
  IF a1 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 1 est refuse : %', v::text; END IF;

  n := n + 1;   -- P1.1 : LE DEPOT OUVRE UN DOSSIER AU PARQUET, DANS LA VILLE DU PLAIGNANT.
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR a1 IS NULL THEN
    ko := ko + 1; e := e || E'\nP1.1 : le depot a echoue -- ' || v::text;
  ELSE
    SELECT (p.data::jsonb) ->> 'status' INTO v_s
      FROM public.plaintes_en_cours p WHERE p.id = a1;
    IF v_s IS DISTINCT FROM 'au_parquet' THEN
      ko := ko + 1; e := e || E'\nP1.1 : statut au depot = ' || coalesce(v_s,'(nul)'); END IF;
    SELECT count(*) INTO v_n FROM public.plaintes_en_cours p
     WHERE p.id = a1 AND p.city = 'capitale' AND p.country = 'republic';
    IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP1.1 : la juridiction du dossier n''est pas Luthecia'; END IF;
  END IF;

  n := n + 1;   -- P1.2 : LA CATEGORIE ALLEGUEE EST CONSERVEE COMME ALLEGATION, et `delit` est acceptee.
  SELECT (p.data::jsonb) ->> 'categorie_alleguee' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a1;
  IF v_s IS DISTINCT FROM 'delit' THEN
    ko := ko + 1; e := e || E'\nP1.2 : la categorie alleguee = ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P1.3 : LE PARQUET DOIT ETRE AU TRIBUNAL DE LA VILLE. A distance, il est refuse.
  UPDATE public.personnages_donnees SET current_building = 'hotel-republica', current_room = 'bar'
   WHERE name = PROC;
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_non_lieu(a1, 'Aucun element');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_requise' THEN
    ko := ko + 1; e := e || E'\nP1.3 : le parquet decide depuis un bar -- ' || v::text; END IF;

  n := n + 1;   -- P1.4 : AU TRIBUNAL, LE NON-LIEU EST PRONONCE, ET L'AFFAIRE EST CLOSE.
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_non_lieu(a1, 'Aucun element');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a1;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'non_lieu' THEN
    ko := ko + 1; e := e || E'\nP1.4 : non-lieu refuse ou statut = ' || coalesce(v_s,'(nul)')
                         || ' -- ' || v::text; END IF;

  n := n + 1;   -- P1.5 : L'ACTE EST A LA CHRONOLOGIE, ET IL PORTE SON AUTEUR.
  -- LE POSTE INSCRIT EST `procureur`, le nom du POSTE -- pas `parquet`, qui est le nom de la
  -- QUALITE au registre des types d'actes. Les deux vocabulaires coexistent, et c'est le poste
  -- qui est ecrit sur l'acte.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a1 AND type = 'non_lieu' AND acteur = PROC AND acteur_poste = 'procureur';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP1.5 : ' || v_n || ' acte(s) de non-lieu'; END IF;

  n := n + 1;   -- P1.6 : ET LE JOURNAL L'APPREND, PAR LE DECLENCHEUR, SANS CROCHET DANS LA PORTE.
  SELECT count(*) INTO v_n FROM public.chronique_nationale
   WHERE type = 'justice_non_lieu' AND libelle LIKE '%' || PREV || '%';
  IF v_n < 1 THEN ko := ko + 1; e := e || E'\nP1.6 : le non-lieu n''entre pas au journal'; END IF;

  -- ============================================================ P2 : LA CHAINE COMPLETE (capitale)
  PERFORM pg_temp.siege_commissaire(COMM, 'capitale');
  PERFORM pg_temp.au_commissariat(PLAI, 'capitale');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Il m''a vole mon manteau devant temoins', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a2 := v ->> 'id';
  IF a2 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 2 est refuse : %', v::text; END IF;

  n := n + 1;   -- P2.1 : LE PARQUET DILIGENTE UNE ENQUETE, LA POLICE NE SE L'ORDONNE PAS.
  PERFORM pg_temp.je_suis(COMM_U);
  v := public.plainte_traiter(a2, 'enqueter');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'enquete_non_diligentee' THEN
    ko := ko + 1; e := e || E'\nP2.1 : la police enquete sans ordre du parquet -- ' || v::text; END IF;

  n := n + 1;   -- P2.2 : LE PARQUET ORDONNE ; LE DOSSIER PASSE A `enquete`.
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_enqueter(a2);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a2;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'enquete' THEN
    ko := ko + 1; e := e || E'\nP2.2 : enquete non diligentee -- ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P2.3 : LA POLICE ACCOMPLIT L'ACTE, ET LE STATUT NE BOUGE PAS -- elle rapporte.
  PERFORM pg_temp.je_suis(COMM_U);
  v := public.plainte_traiter(a2, 'enqueter');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a2;
  IF v_s IS DISTINCT FROM 'enquete' THEN
    ko := ko + 1; e := e || E'\nP2.3 : l''acte de police a change le statut en ' || coalesce(v_s,'(nul)'); END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a2 AND type = 'enquete_acte_police' AND acteur_poste = 'commissaire';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP2.3 : l''acte de police n''est pas consigne'; END IF;

  n := n + 1;   -- P2.4 : LA POLICE NE PEUT PLUS CLASSER -- l'opportunite est au parquet.
  PERFORM pg_temp.je_suis(COMM_U);
  v := public.plainte_traiter(a2, 'classer');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'classement_reserve_au_parquet' THEN
    ko := ko + 1; e := e || E'\nP2.4 : la police classe encore -- ' || v::text; END IF;

  n := n + 1;   -- P2.5 : LES POURSUITES PORTENT UNE QUALIFICATION CANONIQUE, et une seule.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_poursuivre(a2, 'infraction_qui_n_existe_pas');
  IF (v ->> 'raison') IS DISTINCT FROM 'infraction_inconnue' THEN
    ko := ko + 1; e := e || E'\nP2.5 : une qualification inventee est acceptee -- ' || v::text; END IF;
  v := public.parquet_poursuivre(a2, 'vol');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'qualification_parquet' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a2;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'vol' THEN
    ko := ko + 1; e := e || E'\nP2.5 : la qualification du parquet = ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P2.6 : LE PV D'AUDITION APPARTIENT AU PREVENU, ET A LUI SEUL.
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.pv_audition_realiser(a2, 'Je dis ce que je veux', false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_mon_affaire' THEN
    ko := ko + 1; e := e || E'\nP2.6 : le plaignant fait le PV du prevenu -- ' || v::text; END IF;

  n := n + 1;   -- P2.7 : LE PV DU PREVENU EST VERBATIM, ET IL OUVRE LE DELAI DE JUGEMENT.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.pv_audition_realiser(a2, E'Ce manteau est a moi.\nJ ai la facture.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP2.7 : le PV du prevenu est refuse -- ' || v::text;
  ELSE
    -- LE VERBATIM NE VIT PAS DANS LE DOSSIER, ET C'EST UNE BONNE NOUVELLE. `plaintes_en_cours`
    -- ne retient du PV que son EXISTENCE -- `pv_le`, `pv_jour`, `pv_refus` -- et le delai qu'il
    -- ouvre. La declaration elle-meme est dans `dossiers_auditions`, table sans aucun droit
    -- client. Les deux epreuves mesurent les deux moities : le texte est conserve mot pour mot
    -- la-bas, et il n'est PAS recopie ici.
    SELECT declaration INTO v_s FROM public.dossiers_auditions
     WHERE affaire = a2 AND personne = PREV ORDER BY fait_le DESC LIMIT 1;
    IF v_s IS DISTINCT FROM E'Ce manteau est a moi.\nJ ai la facture.' THEN
      ko := ko + 1; e := e || E'\nP2.7 : le PV n''est pas verbatim -- ' || coalesce(v_s,'(nul)'); END IF;
    SELECT (p.data::jsonb)::text INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a2;
    IF v_s LIKE '%J ai la facture%' THEN
      ko := ko + 1; e := e || E'\nP2.7 : le dossier recopie la declaration du prevenu'; END IF;
    IF (SELECT (p.data::jsonb) ->> 'pv_le' FROM public.plaintes_en_cours p WHERE p.id = a2) IS NULL THEN
      ko := ko + 1; e := e || E'\nP2.7 : le dossier ne garde pas trace que le PV a eu lieu'; END IF;
    SELECT ((p.data::jsonb) ->> 'delai_jugement_jour')::integer INTO v_n
      FROM public.plaintes_en_cours p WHERE p.id = a2;
    IF v_n IS DISTINCT FROM v_jour + public.justice_delai_jugement_jours() THEN
      ko := ko + 1; e := e || E'\nP2.7 : le delai de jugement = ' || coalesce(v_n::text,'(nul)')
                           || ', ' || (v_jour + public.justice_delai_jugement_jours()) || ' attendu'; END IF;
  END IF;

  n := n + 1;   -- P2.8 : LA SAISINE DU JUGE EST UN ACTE DU PARQUET.
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_transmettre_juge(a2);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a2;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'saisie' THEN
    ko := ko + 1; e := e || E'\nP2.8 : la saisine a echoue -- ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P2.9 : LE JUGE D'UNE AUTRE VILLE NE FIXE PAS CETTE AUDIENCE.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_fixer(a2, v_jour + 3);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_juge_de_cette_ville' THEN
    ko := ko + 1; e := e || E'\nP2.9 : le juge de Montrouge fixe une audience a Luthecia -- ' || v::text; END IF;

  n := n + 1;   -- P2.10 : LE JUGE COMPETENT FIXE LE JOUR, AU MINIMUM TROIS JOURS APRES.
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_fixer(a2, v_jour + 3);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP2.10 : le jour d''audience est refuse -- ' || v::text; END IF;

  -- ============================================================ P2 (suite) : LE JOUR VIENT
  UPDATE public.rp_epoques SET jour_un = jour_un - 3 WHERE pays = 'republic';
  v_jour := public.jour_de_jeu_pays('republic');

  n := n + 1;   -- P2.11 : LE JOUR VENU, LE JUGE OUVRE L'AUDIENCE DANS SA SALLE.
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_ouvrir(a2);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP2.11 : l''audience ne s''ouvre pas -- ' || v::text; END IF;

  n := n + 1;   -- P2.12 : L'OUVERTURE CONSTATE LES PRESENCES, ET N'EN TIRE AUCUNE CONSEQUENCE.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a2 AND type = 'audience_ouverte';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP2.12 : l''ouverture n''est pas consignee'; END IF;
  SELECT count(*) INTO v_n FROM public.detentions WHERE nom IN (PLAI, PROC);
  IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nP2.12 : une absence a produit une detention'; END IF;

  n := n + 1;   -- P2.13 : LE JUGE CONDAMNE, ET LA PEINE EST CELLE DU BAREME.
  --
  -- UNE PEINE DE PRISON NE PORTE AUCUNE AMENDE, et c'est le serveur qui l'impose : pour le genre
  -- `prison`, `justice_peine_calcul` ramene la plage d'amende a [0, 0]. Les deux genres ne se
  -- cumulent pas -- le juge choisit la prison OU l'amende. L'epreuve mesure les deux cotes : un
  -- montant joint a une peine de prison est REFUSE, et la meme peine sans montant passe.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(a2, 'vol', 'prison', 1, 500);
  IF (v ->> 'raison') IS DISTINCT FROM 'amende_hors_bornes' THEN
    ko := ko + 1; e := e || E'\nP2.13 : une prison avec amende est acceptee -- ' || v::text; END IF;
  v := public.justice_rendre_sentence(a2, 'vol', 'prison', 1, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP2.13 : la condamnation a echoue -- ' || v::text; END IF;
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a2;
  IF v_s IS DISTINCT FROM 'jugee' THEN
    ko := ko + 1; e := e || E'\nP2.13 : statut apres jugement = ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P2.14 : ET LE DOSSIER JUGE N'EST PLUS LISIBLE PAR UN TIERS. C'est la fuite fermee
                --         le 13 octobre : `status = 'jugee'` ouvrait la table a tout le monde.
  PERFORM pg_temp.siege_commissaire(COMM, 'ville_b');
  PERFORM pg_temp.je_suis(COMM_U);
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours WHERE id = a2;
  PERFORM pg_temp.je_suis_le_serveur();
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nP2.14 : un tiers lit le dossier d''une affaire jugee'; END IF;


  -- ============================================================ P3 : LA RELAXE (ville_a)
  --
  -- BEN SORT D'ABORD DE LA PRISON DU PARCOURS 2. La peine prononcee en P2.13 est une peine de
  -- PRISON, et `justice_rendre_sentence` ouvre vraiment la detention : la ligne de `detentions`
  -- survit au parcours. Sans cette remise a zero, P3.4 compterait la detention du VOL et
  -- accuserait la relaxe de la FAUSSE RUMEUR -- exactement le genre de mensonge qu'un banc doit
  -- s'interdire. Les parcours 4 a 11 font deja cette remise a zero ; le parcours 3 l'oubliait.
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.au_commissariat(PLAI, 'ville_a');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Il a diffuse une rumeur a mon sujet au port', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a3 := v ->> 'id';
  IF a3 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 3 est refuse : %', v::text; END IF;

  n := n + 1;   -- P3.1 : LE DOSSIER EST OUVERT A PORT-SAINTE-MARIE, et le parquet doit y aller.
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours WHERE id = a3 AND city = 'ville_a';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP3.1 : le dossier n''est pas a Port-Sainte-Marie'; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_poursuivre(a3, 'fausse_rumeur');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_requise' THEN
    ko := ko + 1; e := e || E'\nP3.1 : le parquet agit a Luthecia sur un dossier de PSM -- ' || v::text; END IF;

  n := n + 1;   -- P3.2 : SUR PLACE, LES POURSUITES ET LA SAISINE PASSENT.
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'ville_a');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a3, 'fausse_rumeur');
  v := public.parquet_transmettre_juge(a3);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a3;
  IF v_s IS DISTINCT FROM 'saisie' THEN
    ko := ko + 1; e := e || E'\nP3.2 : la saisine a PSM a echoue -- ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P3.2b : AUCUN VERDICT AVANT QUE LE PROCES AIT EU LIEU (ville_a).
  --
  -- LE VERROU D'AUDIENCE DU 13 OCTOBRE 2026, MESURE DES DEUX COTES. D'abord le REFUS : l'affaire
  -- est regulierement saisie, le juge est bien celui de sa ville, et le jugement est pourtant
  -- refuse -- l'audience n'a pas ete ouverte. Ensuite l'ACCEPTATION, apres la chaine reelle :
  -- le prevenu CONSENT a etre juge aujourd'hui, le juge fixe ce jour-la, puis il ouvre
  -- l'audience depuis sa salle. Rien n'est pose a la main dans le dossier.
  v_auj := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_relaxer(a3, 'fausse_rumeur');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_non_ouverte' THEN
    ko := ko + 1; e := e || E'\nP3.2b : un verdict est rendu sans audience ouverte -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_audience_consentir(a3, v_auj);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP3.2b : le prevenu ne peut pas consentir -- ' || v::text; END IF;
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_fixer(a3, v_auj);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP3.2b : le jour consenti est refuse -- ' || v::text; END IF;
  v := public.justice_audience_ouvrir(a3);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP3.2b : l''audience ne s''ouvre pas -- ' || v::text; END IF;

  n := n + 1;   -- P3.3 : LE JUGE DE PSM RELAXE, ET LA RELAXE EST UN VERDICT.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_relaxer(a3, 'fausse_rumeur');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a3;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'relaxe' THEN
    ko := ko + 1; e := e || E'\nP3.3 : la relaxe a echoue -- ' || coalesce(v_s,'(nul)') || ' ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes WHERE affaire = a3 AND type = 'relaxe';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP3.3 : la relaxe n''est pas a la chronologie'; END IF;

  n := n + 1;   -- P3.4 : UNE RELAXE N'OUVRE AUCUNE DETENTION.
  --
  -- LE COMPTE EST GLOBAL, ET C'EST VOLONTAIRE : le prevenu est sorti de prison a l'entree du
  -- parcours, donc toute ligne de `detentions` a son nom ne peut venir que de la relaxe qui
  -- vient d'etre prononcee. Mesurer `affaire = a3` aurait laisse passer une detention ouverte
  -- sans affaire.
  SELECT count(*) INTO v_n FROM public.detentions WHERE nom = PREV;
  IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nP3.4 : une relaxe a incarcere (' || v_n || ')'; END IF;

  -- ============================================================ P4 : LA PROCEDURE SIMPLIFIEE (ville_b)
  PERFORM pg_temp.au_commissariat(PLAI, 'ville_b');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Diffamation publique a Montrouge', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a4 := v ->> 'id';
  IF a4 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 4 est refuse : %', v::text; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'ville_b');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a4, 'diffamation');
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || jsonb_build_object('status','au_parquet'))::text WHERE id = a4;

  n := n + 1;   -- P4.1 : UN DELIT CLASSE PAR L'ARBITRAGE SE PLAIDE EN PROCEDURE SIMPLIFIEE.
  -- LE JUGE PJ PREND LE SIEGE DE MONTROUGE AVANT LA PLAIDOIRIE. Sans cela, c'est le juge PNJ de
  -- la ville qui signe -- comportement correct du jeu, mais P4.2 veut mesurer qu'un JOUEUR
  -- titulaire signe bien le jugement de SA ville.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.plainte_defendre(a4);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP4.1 : la diffamation est refusee en procedure simplifiee -- ' || v::text; END IF;

  n := n + 1;   -- P4.2 : LE JUGEMENT EST SIGNE PAR LE JUGE DE MONTROUGE, PAS PAR CELUI DE PSM.
  SELECT j.juge INTO v_s FROM public.jugements j WHERE j.id = 'jug-' || a4;
  IF v_s IS DISTINCT FROM public.justice_juge_titulaire('republic','ville_b') THEN
    ko := ko + 1; e := e || E'\nP4.2 : le jugement est signe ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P4.3 : ELLE EST DEFINITIVE : ni seconde plaidoirie, ni appel.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.plainte_defendre(a4);
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nP4.3 : on plaide deux fois -- ' || v::text; END IF;
  v := public.justice_appel_ouvrir(a4);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'appel_exclu_procedure_simplifiee' THEN
    ko := ko + 1; e := e || E'\nP4.3 : un appel est possible -- ' || v::text; END IF;

  -- ============================================================ P5 : LE CRIME (capitale)
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.au_commissariat(PLAI, 'capitale');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Il a tente de me tuer', 'crime');
  PERFORM pg_temp.je_suis_le_serveur();
  a5 := v ->> 'id';
  IF a5 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 5 est refuse : %', v::text; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a5, 'tentative_assassinat');
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || jsonb_build_object('status','au_parquet'))::text WHERE id = a5;

  n := n + 1;   -- P5.1 : UNE TENTATIVE D'ASSASSINAT NE SE PLAIDE PAS EN DIX SECONDES.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.plainte_defendre(a5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'procedure_simplifiee_exclut_les_crimes'
     OR (v ->> 'categorie') IS DISTINCT FROM 'crime' THEN
    ko := ko + 1; e := e || E'\nP5.1 : un crime passe en procedure simplifiee -- ' || v::text; END IF;

  n := n + 1;   -- P5.2 : IL EST JUGE PAR LE TRIBUNAL, DANS LES BORNES DU BAREME.
  -- LE DOSSIER A ETE RAMENE A `au_parquet` POUR EPROUVER LA PROCEDURE SIMPLIFIEE : il faut donc
  -- rengager les poursuites avant de saisir le juge. `parquet_transmettre_juge` n'accepte que
  -- `poursuites`, et c'est tres bien ainsi -- on ne saisit pas un juge sans poursuites.
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a5, 'tentative_assassinat');
  PERFORM public.parquet_transmettre_juge(a5);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;   -- P5.1b : AUCUN VERDICT AVANT QUE LE PROCES AIT EU LIEU (capitale).
  --
  -- LE VERROU D'AUDIENCE DU 13 OCTOBRE 2026, MESURE DES DEUX COTES. D'abord le REFUS : l'affaire
  -- est regulierement saisie, le juge est bien celui de sa ville, et le jugement est pourtant
  -- refuse -- l'audience n'a pas ete ouverte. Ensuite l'ACCEPTATION, apres la chaine reelle :
  -- le prevenu CONSENT a etre juge aujourd'hui, le juge fixe ce jour-la, puis il ouvre
  -- l'audience depuis sa salle. Rien n'est pose a la main dans le dossier.
  v_auj := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(a5, 'tentative_assassinat', 'prison', 3, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_non_ouverte' THEN
    ko := ko + 1; e := e || E'\nP5.1b : un verdict est rendu sans audience ouverte -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_audience_consentir(a5, v_auj);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP5.1b : le prevenu ne peut pas consentir -- ' || v::text; END IF;
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_fixer(a5, v_auj);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP5.1b : le jour consenti est refuse -- ' || v::text; END IF;
  v := public.justice_audience_ouvrir(a5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP5.1b : l''audience ne s''ouvre pas -- ' || v::text; END IF;

  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(a5, 'tentative_assassinat', 'prison', 99, 0);
  IF (v ->> 'raison') IS DISTINCT FROM 'peine_hors_bornes' THEN
    ko := ko + 1; e := e || E'\nP5.2 : 99 jours passent pour 2 de reference -- ' || v::text; END IF;
  -- DEUX JOURS DE REFERENCE : la plage est [1, 3]. Trois jours est le haut de la fourchette, et
  -- l'amende reste a zero -- une peine de prison n'en porte pas (voir P2.13).
  v := public.justice_rendre_sentence(a5, 'tentative_assassinat', 'prison', 3, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP5.2 : la condamnation a echoue -- ' || v::text; END IF;

  n := n + 1;   -- P5.3 : LE GREFFE PUBLIC DIT LA CATEGORIE, ET RIEN DU DOSSIER.
  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'tribunal',
         current_room = 'greffe' WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.justice_archives_greffe(a5);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP5.3 : les archives ne s''ouvrent pas -- ' || v::text;
  ELSE
    IF v::text LIKE '%tente de me tuer%' THEN
      ko := ko + 1; e := e || E'\nP5.3 : les archives disent le texte de la plainte'; END IF;
    IF v::text NOT LIKE '%crime%' THEN
      ko := ko + 1; e := e || E'\nP5.3 : les archives ne disent pas la categorie'; END IF;
  END IF;

  -- ============================================================ P6 : L'APPEL (ville_a)
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.au_commissariat(PLAI, 'ville_a');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Corruption de fonctionnaire au port', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a6 := v ->> 'id';
  IF a6 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 6 est refuse : %', v::text; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'ville_a');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a6, 'corruption_fonctionnaire');
  PERFORM public.parquet_transmettre_juge(a6);
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;   -- P6.0b : AUCUN VERDICT AVANT QUE LE PROCES AIT EU LIEU (ville_a).
  --
  -- LE VERROU D'AUDIENCE DU 13 OCTOBRE 2026, MESURE DES DEUX COTES. D'abord le REFUS : l'affaire
  -- est regulierement saisie, le juge est bien celui de sa ville, et le jugement est pourtant
  -- refuse -- l'audience n'a pas ete ouverte. Ensuite l'ACCEPTATION, apres la chaine reelle :
  -- le prevenu CONSENT a etre juge aujourd'hui, le juge fixe ce jour-la, puis il ouvre
  -- l'audience depuis sa salle. Rien n'est pose a la main dans le dossier.
  v_auj := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(a6, 'corruption_fonctionnaire', 'prison', 1, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_non_ouverte' THEN
    ko := ko + 1; e := e || E'\nP6.0b : un verdict est rendu sans audience ouverte -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_audience_consentir(a6, v_auj);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP6.0b : le prevenu ne peut pas consentir -- ' || v::text; END IF;
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_fixer(a6, v_auj);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP6.0b : le jour consenti est refuse -- ' || v::text; END IF;
  v := public.justice_audience_ouvrir(a6);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP6.0b : l''audience ne s''ouvre pas -- ' || v::text; END IF;

  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(a6, 'corruption_fonctionnaire', 'prison', 1, 0);
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- P6.1 : LA CONDAMNATION EST RENDUE, ET ELLE EST EXECUTOIRE.
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP6.1 : la condamnation de PSM a echoue -- ' || v::text; END IF;

  n := n + 1;   -- P6.2 : UN TIERS N'INTERJETTE PAS APPEL. L'appel appartient au condamne et au parquet.
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.justice_appel_ouvrir(a6);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nP6.2 : le plaignant interjette appel -- ' || v::text; END IF;

  n := n + 1;   -- P6.3 : LE CONDAMNE INTERJETTE APPEL DANS SA FENETRE DE DEUX JOURS.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_appel_ouvrir(a6);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a6;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'appel' THEN
    ko := ko + 1; e := e || E'\nP6.3 : l''appel n''est pas ouvert -- ' || coalesce(v_s,'(nul)')
                         || ' ' || v::text; END IF;

  n := n + 1;   -- P6.4 : UN SEUL APPEL PAR AFFAIRE, ET LE REFUS DIT POURQUOI.
  --
  -- LA DETTE DU 12 OCTOBRE EST PAYEE. La porte controlait le STATUT avant l'unicite : une
  -- affaire en appel n'etant ni `jugee` ni `relaxe`, elle repondait
  -- `pas_de_jugement_de_premiere_instance` -- un refus juste sous un motif mensonger. L'ordre
  -- des gardes est desormais definitif / unicite / statut, et l'epreuve exige LE motif exact :
  -- un banc qui accepte deux motifs ne mesure plus lequel la porte rend.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_appel_ouvrir(a6);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE
     OR (v ->> 'raison') IS DISTINCT FROM 'appel_deja_interjete' THEN
    ko := ko + 1; e := e || E'\nP6.4 : un second appel est possible -- ' || v::text; END IF;

  n := n + 1;   -- P6.5 : LE MEME JUGE REEXAMINE, ET SA DECISION EST DEFINITIVE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_appel_juger(a6, 'relaxe');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a6;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP6.5 : le jugement d''appel a echoue -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a6 AND type IN ('condamnation','appel_ouvert','jugement_appel');
  IF v_n < 3 THEN
    ko := ko + 1; e := e || E'\nP6.5 : la chronologie ne porte pas les trois actes (' || v_n || ')'; END IF;

  n := n + 1;   -- P6.6 : LA RELAXE EN APPEL FAIT NAITRE L'INDEMNITE DES JOURS PURGES A TORT,
                --        et PAS UN FRANC DE PLUS QUE MILLE PAR JOUR ENTIER.
  SELECT count(*), coalesce(max(montant_du), 0), coalesce(max(jours_indus), 0)
    INTO v_n, v_rang, v_jour FROM public.justice_indemnites WHERE affaire = a6;
  IF v_n > 0 AND v_rang <> v_jour * public.justice_indemnite_par_jour() THEN
    ko := ko + 1; e := e || E'\nP6.6 : ' || v_rang || ' FR pour ' || v_jour || ' jour(s) indus'; END IF;
  v_jour := public.jour_de_jeu_pays('republic');

  -- ============================================================ P7 : L'ABANDON (ville_b)
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.au_commissariat(PLAI, 'ville_b');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Hooliganisme au stade de Montrouge', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a7 := v ->> 'id';
  IF a7 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 7 est refuse : %', v::text; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'ville_b');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a7, 'hooliganisme');
  PERFORM public.parquet_transmettre_juge(a7);
  v := public.parquet_abandonner(a7, 'Priorites du parquet');
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- P7.1 : LE PARQUET PEUT SE RETIRER APRES LA SAISINE, et le dossier l'annonce.
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a7;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'abandon_demande' THEN
    ko := ko + 1; e := e || E'\nP7.1 : l''abandon a echoue -- ' || coalesce(v_s,'(nul)') || ' ' || v::text; END IF;

  n := n + 1;   -- P7.2 : LE JUGE DECIDE SEUL DE LA SUITE, ET POURSUIVRE EST UN FAIT DISTINCT.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_suite_apres_abandon(a7, 'poursuivre');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a7;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'saisie' THEN
    ko := ko + 1; e := e || E'\nP7.2 : le juge ne peut pas poursuivre -- ' || coalesce(v_s,'(nul)')
                         || ' ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a7 AND type IN ('abandon_poursuites','juge_poursuite_maintenue');
  IF v_n < 2 THEN
    ko := ko + 1; e := e || E'\nP7.2 : les deux faits ne coexistent pas (' || v_n || ')'; END IF;

  n := n + 1;   -- P7.2b : AUCUN VERDICT AVANT QUE LE PROCES AIT EU LIEU (ville_b).
  --
  -- LE VERROU D'AUDIENCE DU 13 OCTOBRE 2026, MESURE DES DEUX COTES. D'abord le REFUS : l'affaire
  -- est regulierement saisie, le juge est bien celui de sa ville, et le jugement est pourtant
  -- refuse -- l'audience n'a pas ete ouverte. Ensuite l'ACCEPTATION, apres la chaine reelle :
  -- le prevenu CONSENT a etre juge aujourd'hui, le juge fixe ce jour-la, puis il ouvre
  -- l'audience depuis sa salle. Rien n'est pose a la main dans le dossier.
  v_auj := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_relaxer(a7, 'hooliganisme');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_non_ouverte' THEN
    ko := ko + 1; e := e || E'\nP7.2b : un verdict est rendu sans audience ouverte -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_audience_consentir(a7, v_auj);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP7.2b : le prevenu ne peut pas consentir -- ' || v::text; END IF;
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_audience_fixer(a7, v_auj);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP7.2b : le jour consenti est refuse -- ' || v::text; END IF;
  v := public.justice_audience_ouvrir(a7);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP7.2b : l''audience ne s''ouvre pas -- ' || v::text; END IF;

  n := n + 1;   -- P7.3 : ET LE JUGE QUI A CHOISI DE POURSUIVRE VA JUSQU'AU VERDICT.
  -- CE N'EST PAS DU CONFORT DE BANC : un plaignant ne peut pas avoir DEUX affaires vivantes
  -- contre la meme personne (`plainte_deja_en_cours`). Chaque parcours doit donc se CLORE pour
  -- que le suivant puisse naitre -- ce qui est aussi la verite du jeu : une affaire finit.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_relaxer(a7, 'hooliganisme');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a7;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'relaxe' THEN
    ko := ko + 1; e := e || E'\nP7.3 : le verdict apres abandon a echoue -- ' || coalesce(v_s,'(nul)')
                         || ' ' || v::text; END IF;
  PERFORM pg_temp.libere(PREV);

  -- ============================================================ P8 : LES TEMOINS (capitale)
  PERFORM pg_temp.au_commissariat(PLAI, 'capitale');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Achat d arme non enregistree, deux personnes ont vu',
                              'delit', ARRAY[COMM, JUGE]);
  PERFORM pg_temp.je_suis_le_serveur();
  a8 := v ->> 'id';
  IF a8 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 8 est refuse : %', v::text; END IF;

  n := n + 1;   -- P8.1 : LES DEUX TEMOINS SONT CITES AU DEPOT, ET CONVOQUES.
  IF jsonb_array_length(v -> 'temoins_cites') <> 2 THEN
    ko := ko + 1; e := e || E'\nP8.1 : les temoins du depot ne sont pas cites -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.temoins_citations
   WHERE affaire = a8 AND cite_par_qualite = 'plaignant';
  IF v_n <> 2 THEN ko := ko + 1; e := e || E'\nP8.1 : ' || v_n || ' citation(s) au lieu de 2'; END IF;

  n := n + 1;   -- P8.2 : APRES SON DEPOT, LE PLAIGNANT NE CITE PLUS -- JAMAIS.
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.temoin_citer(a8, PROC);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nP8.2 : le plaignant cite apres son depot -- ' || v::text; END IF;

  n := n + 1;   -- P8.3 : LA DEPOSITION EST VERBATIM, ET PERSONNE NE LA JUGE.
  UPDATE public.personnages_donnees SET current_city = 'capitale',
         current_building = 'commissariat', current_room = 'accueil_police' WHERE name = COMM;
  PERFORM pg_temp.je_suis(COMM_U);
  v := public.temoin_deposer(a8, E'J ai tout vu.\nIl portait un manteau rouge.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP8.3 : la deposition est refusee -- ' || v::text; END IF;
  SELECT declaration INTO v_s FROM public.dossiers_auditions
   WHERE affaire = a8 AND personne = COMM ORDER BY fait_le DESC LIMIT 1;
  IF v_s IS DISTINCT FROM E'J ai tout vu.\nIl portait un manteau rouge.' THEN
    ko := ko + 1; e := e || E'\nP8.3 : la deposition n''est pas verbatim -- ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P8.4 : LE REFUS DE TEMOIGNER EST UNE REPONSE, ET IL N'EMPORTE AUCUN MALUS.
  UPDATE public.personnages_donnees SET current_city = 'capitale',
         current_building = 'commissariat', current_room = 'accueil_police' WHERE name = JUGE;
  -- LA POPULARITE VIT DANS `resources`, PAS DANS UNE COLONNE. On releve le blob ENTIER avant et
  -- apres : l'epreuve ne porte donc pas seulement sur la popularite mais sur TOUTE ressource --
  -- aucune ne doit bouger. Un refus de temoigner n'est pas une faute.
  SELECT resources::text INTO v_av FROM public.personnages_donnees WHERE name = JUGE;
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.temoin_deposer(a8, NULL, true);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP8.4 : le refus de temoigner est refuse -- ' || v::text; END IF;
  IF (SELECT resources::text FROM public.personnages_donnees WHERE name = JUGE) IS DISTINCT FROM v_av THEN
    ko := ko + 1; e := e || E'\nP8.4 : le refus a change une ressource du temoin'; END IF;
  SELECT count(*) INTO v_n FROM public.detentions WHERE nom = JUGE;
  IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nP8.4 : le refus a incarcere le temoin'; END IF;

  n := n + 1;   -- P8.5 : LE GREFFE PUBLIC DIT QUI A ETE CITE, ET RIEN DE CE QUI A ETE DIT.
  UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'tribunal',
         current_room = 'greffe' WHERE name = PREV;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.justice_affaires_publiques();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP8.5 : le registre public ne s''ouvre pas -- ' || v::text;
  ELSE
    IF v::text NOT LIKE '%' || COMM || '%' THEN
      ko := ko + 1; e := e || E'\nP8.5 : le registre ne nomme pas le temoin cite'; END IF;
    IF v::text LIKE '%manteau rouge%' OR v::text LIKE '%deux personnes ont vu%' THEN
      ko := ko + 1; e := e || E'\nP8.5 : le registre dit le contenu du dossier'; END IF;
    IF v::text LIKE '%' || PLAI || '%' THEN
      ko := ko + 1; e := e || E'\nP8.5 : le registre nomme le plaignant'; END IF;
  END IF;

  n := n + 1;   -- P8.6 : LE PARQUET CLOT L'AFFAIRE DES TEMOINS, ET LES CITATIONS S'ETEIGNENT.
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_non_lieu(a8, 'Les depositions ne convergent pas');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP8.6 : le non-lieu sur l''affaire des temoins a echoue -- ' || v::text; END IF;
  -- LES TROIS ETATS D'UNE CITATION SONT `convoquee`, `recherche` et `close`. A la cloture de
  -- l'affaire, aucune ne doit rester dans les deux premiers -- un temoin convoque pour une
  -- affaire qui n'existe plus serait recherche pour rien.
  SELECT count(*) INTO v_n FROM public.temoins_citations
   WHERE affaire = a8 AND etat <> 'close';
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nP8.6 : ' || v_n || ' citation(s) survivent a la cloture'; END IF;

  -- ============================================================ P9 : LA DEFENSE (ville_a)
  PERFORM pg_temp.au_commissariat(PLAI, 'ville_a');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Possession d objets prohibes au controle douanier', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a9 := v ->> 'id';
  IF a9 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 9 est refuse : %', v::text; END IF;
  -- LE PROCUREUR EST AUSSI AVOCAT PAR SA CARRIERE JUSTICE : c'est voulu, et c'est l'occasion de
  -- verifier que le barreau ne depend d'aucun poste. Il publie sa tarification pour etre visible.
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.avocat_publier_tarification('1 200 FR');
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- P9.1 : ON NE DEMANDE PAS D'AVOCAT AVANT QUE LES POURSUITES SOIENT ENGAGEES.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.defense_demander(a9, ARRAY[PROC]);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'poursuites_non_engagees' THEN
    ko := ko + 1; e := e || E'\nP9.1 : une defense se constitue au parquet -- ' || v::text; END IF;

  n := n + 1;   -- P9.2 : POURSUITES ENGAGEES, LA DEMANDE PASSE ET L'AVOCAT ACCEPTE.
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'ville_a');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a9, 'possession_illegale_douane');
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.defense_demander(a9, ARRAY[PROC]);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP9.2 : la demande de defense a echoue -- ' || v::text; END IF;
  SELECT rang INTO v_rang FROM public.defenses_demandes WHERE affaire = a9 AND avocat = PROC;
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.defense_repondre(v_rang, true);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP9.2 : l''acceptation a echoue -- ' || v::text; END IF;

  n := n + 1;   -- P9.3 : UN SEUL AVOCAT RETENU PAR AFFAIRE, ET C'EST STRUCTUREL.
  BEGIN
    INSERT INTO public.defenses_demandes (affaire, pays, avocat, prevenu, etat)
    VALUES (a9, 'republic', COMM, PREV, 'acceptee');
    ko := ko + 1; e := e || E'\nP9.3 : un second avocat retenu a pu s''ecrire';
  EXCEPTION WHEN unique_violation THEN NULL; END;

  n := n + 1;   -- P9.4 : L'AVOCAT LIT SON DOSSIER AU GREFFE DE SA VILLE, ET PAS AILLEURS.
  UPDATE public.personnages_donnees SET current_city = 'ville_a',
         current_building = 'commissariat-local', current_room = 'accueil_loc' WHERE name = PROC;
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.avocat_dossier(a9);
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nP9.4 : le dossier se lit au commissariat -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.personnages_donnees SET current_city = 'ville_a',
         current_building = 'tribunal-local', current_room = 'greffe' WHERE name = PROC;
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.avocat_dossier(a9);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP9.4 : le dossier ne s''ouvre pas au greffe -- ' || v::text; END IF;

  n := n + 1;   -- P9.5 : LE DOSSIER NE PORTE NI CASIER NI AFFAIRE ETRANGERE.
  SELECT count(*) INTO v_n FROM jsonb_object_keys(v) k
   WHERE k IN ('casier','jugements','historique_crimes','antecedents','autres_affaires');
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nP9.5 : le dossier porte ' || v_n || ' cle(s) interdite(s)'; END IF;

  n := n + 1;   -- P9.6 : LE PREVENU REVOQUE SON AVOCAT, ET L'ACTE PORTE SON AUTEUR REEL.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.defense_rompre(a9);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP9.6 : la revocation a echoue -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a9 AND type = 'defense_rompue' AND acteur = PREV;
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nP9.6 : la rupture ne porte pas son auteur reel'; END IF;

  n := n + 1;   -- P9.7 : L'AUDIENCE OUVERTE VERROUILLE LA DEFENSE.
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_transmettre_juge(a9);
  PERFORM pg_temp.je_suis_le_serveur();
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  -- LE JOUR SE LIT AVANT DE CHANGER D'IDENTITE : `jour_de_jeu_pays` est une porte SERVEUR, et
  -- l'appeler sous l'identite du juge leve « permission denied ». Le banc doit respecter les
  -- memes frontieres que le jeu.
  v_jour := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.je_suis(JUGE_U);
  PERFORM public.justice_audience_fixer(a9, v_jour + 3);
  PERFORM pg_temp.je_suis_le_serveur();
  -- LA CLE QUI FAIT FOI EST `audience_ouverte_le`, et c'est sa PRESENCE qui compte : c'est ce que
  -- lit `affaire_audience_ouverte`. Un decor qui poserait `audience_ouverte` ne verrouillerait
  -- rien, et l'epreuve serait verte pour la mauvaise raison.
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || jsonb_build_object(
           'audience_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'audience_ouverte_jour', v_jour))::text
   WHERE id = a9;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.defense_demander(a9, ARRAY[COMM]);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_ouverte' THEN
    ko := ko + 1; e := e || E'\nP9.7 : on change d''avocat apres l''ouverture -- ' || v::text; END IF;

  n := n + 1;   -- P9.8 : ET L'AFFAIRE DE LA DEFENSE SE CLOT, ELLE AUSSI, PAR UN VERDICT.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_relaxer(a9, 'possession_illegale_douane');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a9;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'relaxe' THEN
    ko := ko + 1; e := e || E'\nP9.8 : la relaxe de PSM a echoue -- ' || coalesce(v_s,'(nul)')
                         || ' ' || v::text; END IF;

  -- ============================================================ P10 : LE DELAI (ville_b)
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.au_commissariat(PLAI, 'ville_b');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Violation du couvre-feu a Montrouge', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a10 := v ->> 'id';
  IF a10 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 10 est refuse : %', v::text; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'ville_b');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a10, 'violation_couvre_feu');
  PERFORM public.parquet_transmettre_juge(a10);
  PERFORM pg_temp.je_suis_le_serveur();
  PERFORM pg_temp.je_suis(PREV_U);
  PERFORM public.pv_audition_realiser(a10, NULL, true);
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- P10.1 : LE REFUS DE REPONDRE OUVRE LE DELAI COMME UNE DECLARATION.
  SELECT ((p.data::jsonb) ->> 'delai_jugement_jour')::integer INTO v_n
    FROM public.plaintes_en_cours p WHERE p.id = a10;
  IF v_n IS NULL THEN
    ko := ko + 1; e := e || E'\nP10.1 : un refus de repondre n''ouvre pas le delai'; END IF;

  n := n + 1;   -- P10.2 : AVANT L'ECHEANCE, LA PASSE DE MINUIT NE TOUCHE A RIEN.
  v := public.justice_delais_echus();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nP10.2 : la passe des delais echoue -- ' || v::text; END IF;
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a10;
  IF v_s IS DISTINCT FROM 'saisie' THEN
    ko := ko + 1; e := e || E'\nP10.2 : le dossier a bouge avant l''echeance -- ' || coalesce(v_s,'(nul)'); END IF;

  n := n + 1;   -- P10.3 : L'ECHEANCE PASSEE, LES CHARGES SONT ABANDONNEES -- ni relaxe, ni non-lieu.
  UPDATE public.rp_epoques SET jour_un = jour_un - (public.justice_delai_jugement_jours() + 1)
   WHERE pays = 'republic';
  v := public.justice_delais_echus();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a10;
  IF v_s IS DISTINCT FROM 'delai_expire' THEN
    ko := ko + 1; e := e || E'\nP10.3 : statut apres echeance = ' || coalesce(v_s,'(nul)')
                         || ' -- ' || v::text; END IF;
  -- L'ACTE EST POSE SANS AUTEUR NI POSTE, et c'est juste : personne ne l'a decide. La passe de
  -- minuit CONSTATE une echeance. Le registre des types dit `pose_par = 'serveur'` ; l'acte, lui,
  -- laisse `acteur` et `acteur_poste` a NULL -- il n'y a pas d'acteur.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a10 AND type = 'charges_abandonnees_delai'
     AND acteur IS NULL AND acteur_poste IS NULL;
  IF v_n <> 1 THEN
    ko := ko + 1; e := e || E'\nP10.3 : l''abandon pour delai n''est pas consigne (' || v_n || ')'; END IF;

  n := n + 1;   -- P10.4 : ET LE JUGE NE PEUT PLUS JUGER UN DOSSIER PERIME.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  -- LA PEINE DEMANDEE EST VALIDE -- un jour, aucune amende -- pour que le refus ne puisse venir
  -- QUE de la peremption. Un banc dont le refus attendu arrive pour une autre raison est vert
  -- sans rien prouver, et c'est le piege le plus courant.
  v := public.justice_rendre_sentence(a10, 'violation_couvre_feu', 'prison', 1, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  -- DEUX GARDES SE PRESENTENT DANS CET ORDRE, et la premiere suffit : la passe de minuit a deja
  -- fait passer le dossier a `delai_expire`, donc `affaire_non_saisie` repond avant que le
  -- controle de l'echeance ne soit atteint. Les deux motifs sont acceptes -- ce que l'epreuve
  -- exige, c'est qu'un dossier perime ne se juge PAS.
  IF coalesce((v ->> 'ok')::boolean, true) IS NOT FALSE
     OR (v ->> 'raison') NOT IN ('delai_de_jugement_expire', 'affaire_non_saisie') THEN
    ko := ko + 1; e := e || E'\nP10.4 : un dossier perime est encore jugeable -- ' || v::text; END IF;

  n := n + 1;   -- P10.5 : LA PASSE EST IDEMPOTENTE : rejouee, elle ne reclot rien.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a10 AND type = 'charges_abandonnees_delai';
  PERFORM public.justice_delais_echus();
  IF (SELECT count(*) FROM public.dossiers_judiciaires_actes
       WHERE affaire = a10 AND type = 'charges_abandonnees_delai') <> v_n THEN
    ko := ko + 1; e := e || E'\nP10.5 : la passe des delais n''est pas idempotente'; END IF;

  -- ============================================================ CE QUE LES DIX LAISSENT
  n := n + 1;   -- F1 : AUCUN DOSSIER N'EST RESTE SANS CHRONOLOGIE. Un acte jete en silence est le
                --      defaut que `dossier_acte_consigner` a ete ecrite pour rendre impossible.
  SELECT count(*) INTO v_n FROM unnest(ARRAY[a1,a2,a3,a4,a5,a6,a7,a8,a9,a10]) x(id)
   WHERE NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes a WHERE a.affaire = x.id);
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nF1 : ' || v_n || ' dossier(s) sans aucun acte'; END IF;

  n := n + 1;   -- F2 : LES DIX DOSSIERS PORTENT TOUS L'ACTE DE DEPOT, EN PREMIER.
  SELECT count(*) INTO v_n FROM unnest(ARRAY[a1,a2,a3,a4,a5,a6,a7,a8,a9,a10]) x(id)
   WHERE (SELECT a.type FROM public.dossiers_judiciaires_actes a
           WHERE a.affaire = x.id ORDER BY a.rang LIMIT 1) IS DISTINCT FROM 'plainte_deposee';
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nF2 : ' || v_n || ' dossier(s) dont le premier acte n''est pas le depot'; END IF;

  n := n + 1;   -- F3 : LES TROIS VILLES ONT REELLEMENT ETE JOUEES.
  SELECT count(DISTINCT city) INTO v_n FROM public.plaintes_en_cours
   WHERE id IN (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10);
  IF v_n <> 3 THEN
    ko := ko + 1; e := e || E'\nF3 : ' || v_n || ' ville(s) jouee(s) au lieu de 3'; END IF;

  n := n + 1;   -- F4 : AUCUN ACTE N'A ETE POSE PAR UN TYPE ABSENT DU REGISTRE.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes a
   WHERE a.affaire IN (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
     AND NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types t WHERE t.type = a.type);
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nF4 : ' || v_n || ' acte(s) hors registre'; END IF;

  n := n + 1;   -- F5 : LE JOURNAL N'A PUBLIE QUE DES FAITS DECLARES AU REGISTRE. Le silence est
                --      le defaut : un acte non declare ne publie rien.
  SELECT count(*) INTO v_n FROM public.chronique_nationale c
   WHERE c.type LIKE 'justice_%'
     AND NOT EXISTS (SELECT 1 FROM public.justice_faits_publics f WHERE f.chronique_type = c.type);
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nF5 : ' || v_n || ' publication(s) judiciaire(s) hors registre'; END IF;

  n := n + 1;   -- F6 : ET UN JOUEUR NE FORGE PAS UN FAIT JUDICIAIRE AU JOURNAL.
  --
  -- La porte d'insertion de `chronique_nationale` est ouverte a tout acteur identifie -- il faut
  -- bien que le navigateur puisse deposer une nomination ou une fin de greve. Rien n'empechait
  -- d'y poser un `justice_condamnation` nommant n'importe qui. La policy refuse desormais tout
  -- type DECLARE au registre `justice_faits_publics` ; les faits judiciaires n'ont qu'une source,
  -- le declencheur serveur. Les deux cotes sont mesures : le faux est refuse, le vrai passe.
  PERFORM pg_temp.je_suis(PREV_U);
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, type, libelle)
    VALUES ('banc-faux-' || a10, 'republic', 'justice_condamnation',
            PLAI || ' a ete condamne(e)');
    ko := ko + 1; e := e || E'\nF6 : un joueur a forge une condamnation au journal';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, type, libelle)
    VALUES ('banc-vrai-' || a10, 'republic', 'nomination', 'Un fait ordinaire');
  EXCEPTION WHEN insufficient_privilege THEN
    ko := ko + 1; e := e || E'\nF6 : un fait ordinaire est refuse au navigateur';
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  -- ============================================================ LA PORTE DEROBEE DU VERDICT
  --
  -- `justice_condamner(cible, entree)` n'exigeait que le POSTE de juge : ni affaire, ni statut,
  -- ni audience, ni bareme -- et son entree est un jsonb LIBRE dont la peine est la SOMME de ce
  -- que le navigateur ecrit dans `motifs`. C'est elle que le chemin judiciaire appelle EN
  -- PREMIER : la sanction tombe par cette porte, `justice_rendre_sentence` ne fait qu'archiver.
  -- Verrouiller l'archivage sans verrouiller la sanction n'aurait verrouille rien du tout.

  n := n + 1;   -- F7 : UNE CONDAMNATION QUI NE NOMME AUCUNE AFFAIRE EST REFUSEE.
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_condamner(PREV, jsonb_build_object(
         'type', 'condamnation', 'country', 'republic',
         'motifs', jsonb_build_array(jsonb_build_object('type', 'Invente', 'jours', 30))));
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'condamnation_sans_affaire' THEN
    ko := ko + 1; e := e || E'\nF7 : une condamnation hors affaire est acceptee -- ' || v::text; END IF;
  IF EXISTS (SELECT 1 FROM public.jugements j WHERE j.accuse = PREV AND j.motif = 'Invente') THEN
    ko := ko + 1; e := e || E'\nF7 : la condamnation inventee a laisse une ligne au registre'; END IF;

  n := n + 1;   -- F8 : UNE CONDAMNATION SUR UNE AFFAIRE CLOSE EST REFUSEE.
  --
  -- LE JUGE SIEGE A PORT-SAINTE-MARIE, parce que l'affaire a3 y a ete jugee. L'ORDRE DES GARDES
  -- EST CELUI DE LA PORTE : affaire nommee, affaire existante, COMPETENCE du juge, identite de
  -- la cible, puis STATUT. Juger a3 depuis Luthecia aurait rendu `pas_juge_de_cette_ville` -- un
  -- refus juste, mais qui ne mesure pas le verrou que cette epreuve-ci nomme. Le statut est
  -- mesure par F8, la competence par F12 : chacune sur son propre decor.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_a');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_condamner(PREV, jsonb_build_object(
         'type', 'condamnation', 'affaire_id', a3, 'country', 'republic',
         'motifs', jsonb_build_array(jsonb_build_object('type', 'Invente', 'jours', 30))));
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'affaire_non_saisie' THEN
    ko := ko + 1; e := e || E'\nF8 : une affaire relaxee se recondamne -- ' || v::text; END IF;

  n := n + 1;   -- F9 : LE MANDAT DU DESERTEUR RESTE OUVERT. Il porte `type` 'militaire', il ne juge
                --      rien et n'attache aucune peine : le verrou ne le concerne pas.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_condamner(PREV, jsonb_build_object(
         'acte', 'desertion', 'type', 'militaire', 'country', 'republic',
         'origine', 'banc_parcours'));
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nF9 : le mandat du deserteur est refuse -- ' || v::text; END IF;

  -- UNE ONZIEME AFFAIRE, POUR MESURER LE COTE QUI PASSE. Toutes les precedentes sont closes : un
  -- depot est donc possible (`plainte_deja_en_cours` ne s'oppose qu'aux affaires vivantes).
  PERFORM pg_temp.libere(PREV);
  PERFORM pg_temp.au_commissariat(PLAI, 'capitale');
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Vol d''un manteau au marche de Luthecia', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a11 := v ->> 'id';
  IF a11 IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours 11 est refuse : %', v::text; END IF;
  PERFORM pg_temp.parquet_au_tribunal(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  PERFORM public.parquet_poursuivre(a11, 'vol');
  PERFORM public.parquet_transmettre_juge(a11);
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- F10 : SAISIE MAIS SANS AUDIENCE OUVERTE, LA PORTE DEROBEE REFUSE AUSSI.
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_condamner(PREV, jsonb_build_object(
         'type', 'condamnation', 'affaire_id', a11, 'country', 'republic',
         'motifs', jsonb_build_array(jsonb_build_object('type', 'Vol', 'jours', 1))));
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'audience_non_ouverte' THEN
    ko := ko + 1; e := e || E'\nF10 : la sanction tombe sans audience -- ' || v::text; END IF;

  n := n + 1;   -- F11 : L'AUDIENCE OUVERTE, LA MEME DEMANDE PASSE -- ET LA CIBLE DOIT ETRE CELLE
                --       DU DOSSIER. Les trois cotes du verrou sont mesures sur la meme affaire.
  v_auj := public.jour_de_jeu_pays('republic');
  PERFORM pg_temp.je_suis(PREV_U);
  PERFORM public.justice_audience_consentir(a11, v_auj);
  PERFORM pg_temp.je_suis_le_serveur();
  PERFORM pg_temp.siege_juge(JUGE, 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  PERFORM public.justice_audience_fixer(a11, v_auj);
  v := public.justice_audience_ouvrir(a11);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nF11 : l''audience de la onzieme affaire ne s''ouvre pas -- ' || v::text; END IF;
  v := public.justice_condamner(PLAI, jsonb_build_object(
         'type', 'condamnation', 'affaire_id', a11, 'country', 'republic',
         'motifs', jsonb_build_array(jsonb_build_object('type', 'Vol', 'jours', 1))));
  IF (v ->> 'raison') IS DISTINCT FROM 'cible_etrangere_a_l_affaire' THEN
    ko := ko + 1; e := e || E'\nF11 : le juge condamne une personne etrangere au dossier -- ' || v::text; END IF;
  v := public.justice_condamner(PREV, jsonb_build_object(
         'type', 'condamnation', 'affaire_id', a11, 'country', 'republic',
         'motifs', jsonb_build_array(jsonb_build_object('type', 'Vol', 'jours', 1))));
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nF11 : l''audience ouverte, la sanction est refusee -- ' || v::text; END IF;

  n := n + 1;   -- F12 : ET LE JUGE D'UNE AUTRE VILLE N'EMPRUNTE PAS LA PORTE DEROBEE. C'est la
                --       regle d'autorite des trois autres portes, qui manquait a celle-ci.
  PERFORM pg_temp.siege_juge(JUGE, 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_condamner(PREV, jsonb_build_object(
         'type', 'condamnation', 'affaire_id', a11, 'country', 'republic',
         'motifs', jsonb_build_array(jsonb_build_object('type', 'Vol', 'jours', 1))));
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_juge_de_cette_ville' THEN
    ko := ko + 1; e := e || E'\nF12 : le juge de Montrouge condamne a Luthecia -- ' || v::text; END IF;

  IF ko > 0 THEN RAISE EXCEPTION 'banc parcours : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc parcours : LES % EPREUVES SONT VERTES.', n;
END $banc$;
ROLLBACK;
