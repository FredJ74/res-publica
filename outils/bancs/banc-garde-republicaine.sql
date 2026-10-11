-- BANC DE LA GARDE REPUBLICAINE (11 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il tue des gardes, vide une caisse ministerielle et forge un jugement
-- contre une joueuse reelle ; il se termine par un RAISE EXCEPTION INCONDITIONNEL. Un banc du
-- 4 octobre 2026 a laisse une accusation forgee au nom d'un joueur reel pendant six jours parce
-- qu'il avait commite.
--
-- CE QU'IL PROUVE -- et c'est la question que l'arbitrage posait : LES GARDES SONT-ILS REELS OU
-- DECORATIFS ? Chaque epreuve a donc sa contre-epreuve.
--   . un garde mis hors de combat LAISSE SON ARME AU SOL, et son ministre en est averti ;
--   . une piece gardee par personne ne pese PLUS RIEN -- le malus suit les hommes, pas le panneau ;
--   . le permanent NE REVIENT PAS avant quatre heures, et il revient apres ;
--   . un RENFORT TOMBE N'EST JAMAIS REMPLACE, et sa chute n'ouvre aucune vacance ;
--   . un poste DECIME est regarni, mais a l'horloge NATIONALE : tuer la Garde ne la prolonge pas ;
--   . le renfort est TOUT OU RIEN : caisse insuffisante, et il n'y a ni garde ni debit ;
--   . un civil ne commande pas la Garde, et la Garde ne controle que si elle est VIVANTE.
--
-- MESURES DE DEPART (11 octobre 2026) : 3 postes, 3 gardes permanents armes, aucun renfort,
-- Arnie ministre de la Defense.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc garde : LES 35 EPREUVES SONT VERTES. -- rien ne doit rester

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

DO $banc$
DECLARE
  ARNIE text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c';   -- ministre de la Defense (reel)
  LEE   text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6';   -- civile (reelle)
  PAL   text := 'palais-presidentiel';
  HALL  text := 'accueil_elysee';
  GPERM text := 'garde-republic-palais-presidentiel-permanent';
  V_CAISSE text := 'republic_gouvernement-min_def';   -- nomme V_ : `caisse` est aussi une COLONNE de caisses_mouvements_clients, et PL/pgSQL ne tranche pas l ambiguite
  v jsonb; n integer := 0; ko integer := 0; v_echecs text := '';
  v_av numeric; v_ap numeric; v_n integer; v_exp timestamptz; v_exp2 timestamptz;
  v_mouv integer; v_sol numeric; g record;
BEGIN
  -- ===========================================================================================
  -- D. LA NEUTRALISATION EST REELLE
  -- ===========================================================================================
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.caisses_batiments
     SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', 100000)
   WHERE id = V_CAISSE;

  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_piece('republic', PAL, HALL);
  n := n + 1;
  IF coalesce((v->>'gardee')::boolean,false) IS NOT TRUE
     OR (v->>'gardes')::integer <> 1 OR (v->>'malus')::integer <> 11 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE1 le hall n est pas garde au depart : ' || v::text;
  END IF;

  -- LA CHUTE. pnj_mourir est la porte generique du socle : la Garde n a pas eu besoin de la
  -- modifier pour etre neutralisable.
  PERFORM pg_temp.je_suis_le_serveur();
  v := public.pnj_mourir(GPERM, 'banc');
  n := n + 1;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'deposes')::integer <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE2 la neutralisation n a rien depose : ' || v::text;
  END IF;

  n := n + 1;   -- L ARME EST AU SOL, DANS LA PIECE, DONC RECUPERABLE
  SELECT count(*) INTO v_n FROM public.objets_abandonnes
   WHERE building_id = PAL AND room_id = HALL AND data LIKE '%arme_de_poing%';
  IF v_n < 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE3 l arme de service n est pas tombee au sol';
  END IF;

  n := n + 1;   -- LE MINISTRE EST AVERTI, par la propriete institutionnelle
  SELECT count(*) INTO v_n FROM public.pnj_evenements
   WHERE pnj_id = GPERM AND type = 'mort'
     AND proprietaire_institution = 'garde_republicaine' AND proprietaire_perimetre = 'republic';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE4 le proprietaire institutionnel n est pas averti';
  END IF;

  n := n + 1;   -- CONTRE-EPREUVE : une piece gardee par PERSONNE ne pese plus rien
  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_piece('republic', PAL, HALL);
  IF (v->>'gardes')::integer <> 0 OR (v->>'malus')::integer <> 0
     OR coalesce((v->>'gardee')::boolean,false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE5 un hall sans garde pese encore : ' || v::text;
  END IF;

  n := n + 1;   -- LA VACANCE EST HORODATEE PAR LE DECLENCHEUR, sans que personne l appelle
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.garde_republicaine_postes
   WHERE pays = 'republic' AND building_id = PAL AND vacant_depuis IS NOT NULL;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE6 la vacance n a pas ete horodatee';
  END IF;

  n := n + 1;   -- IL NE REVIENT PAS TOUT DE SUITE : les quatre heures ne sont pas ecoulees
  v := public.garde_republicaine_synchroniser('republic');
  SELECT count(*) INTO v_n FROM public.pnj_membres WHERE id = GPERM AND statut = 'actif';
  IF v_n <> 0 OR (v->>'revenus')::integer <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE7 le permanent est revenu avant 4 h : ' || v::text;
  END IF;

  n := n + 1;   -- ET IL REVIENT APRES, arme
  UPDATE public.garde_republicaine_postes SET vacant_depuis = now() - interval '4 hours 1 minute'
   WHERE pays = 'republic' AND building_id = PAL;
  v := public.garde_republicaine_synchroniser('republic');
  IF (v->>'revenus')::integer <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE8 le permanent n est pas revenu apres 4 h : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_membres
   WHERE id = GPERM AND statut = 'actif'
     AND public.militaire_arme_operationnelle(id) = 'arme_de_poing';
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE9 le garde revenu n est pas arme';
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.garde_republicaine_postes
   WHERE pays = 'republic' AND building_id = PAL AND vacant_depuis IS NULL;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE10 la vacance n a pas ete refermee';
  END IF;

  n := n + 1;   -- ON NE SUPPRIME PAS UN GARDE VIVANT : le garde-fou du socle vaut pour la Garde
  BEGIN
    DELETE FROM public.pnj_membres WHERE id = GPERM;
    ko := ko + 1; v_echecs := v_echecs || E'\nE11 un garde vivant a pu etre supprime';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  -- ===========================================================================================
  -- E. LE RENFORT NATIONAL
  -- ===========================================================================================
  n := n + 1;   -- UN CIVIL NE COMMANDE PAS LA GARDE
  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_renfort_national(3);
  IF coalesce((v->>'ok')::boolean,true) IS NOT FALSE
     OR v->>'raison' <> 'reserve_au_ministre_de_la_defense' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE12 un civil a pu renforcer la Garde : ' || v::text;
  END IF;

  PERFORM pg_temp.je_suis(ARNIE);
  n := n + 1;   -- LES BORNES SONT GARDEES AUX DEUX BOUTS
  v := public.garde_renfort_national(1);
  IF v->>'raison' <> 'facteur_hors_bornes' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13a facteur 1 accepte : ' || v::text;
  END IF;
  v := public.garde_renfort_national(6);
  IF v->>'raison' <> 'facteur_hors_bornes' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE13b facteur 6 accepte : ' || v::text;
  END IF;

  -- LE RENFORT x3 : 2 gardes de plus sur chacun des 3 postes = 6, a 50 FR = 300 FR.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (data->>'solde')::numeric INTO v_av FROM public.caisses_batiments WHERE id = V_CAISSE;
  SELECT count(*) INTO v_mouv FROM public.caisses_mouvements_clients;
  PERFORM pg_temp.je_suis(ARNIE);
  v := public.garde_renfort_national(3);

  n := n + 1;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE
     OR (v->>'gardes_supplementaires')::integer <> 6 OR (v->>'cout')::numeric <> 300 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE14 le renfort x3 n est pas chiffre juste : ' || v::text;
  END IF;
  v_exp := (v->>'expire_le')::timestamptz;

  n := n + 1;   -- LA CAISSE DE LA DEFENSE A PAYE, EXACTEMENT
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (data->>'solde')::numeric INTO v_ap FROM public.caisses_batiments WHERE id = V_CAISSE;
  IF v_av - v_ap <> 300 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE15 debit incorrect : ' || v_av::text || ' -> ' || v_ap::text;
  END IF;

  n := n + 1;   -- ET LE MOUVEMENT EST JOURNALISE
  SELECT count(*) INTO v_n FROM public.caisses_mouvements_clients
   WHERE caisse = V_CAISSE AND motif = 'garde_republicaine_renfort' AND delta = -300 AND accepte;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE16 le mouvement de caisse n est pas journalise';
  END IF;

  n := n + 1;   -- LES TROIS POSTES SONT A TROIS GARDES
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic';
  IF v_n <> 9 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE17 ' || v_n::text || ' gardes en service au lieu de 9';
  END IF;

  n := n + 1;   -- LE MALUS DE GROUPE SUIT LE NOMBRE REEL : min(40, 10 + 3)
  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_piece('republic', PAL, HALL);
  IF (v->>'gardes')::integer <> 3 OR (v->>'malus')::integer <> 13
     OR coalesce((v->>'renfort_actif')::boolean,false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE18 le malus de groupe est faux : ' || v::text;
  END IF;

  n := n + 1;   -- L ECHEANCE EST A 24 H
  IF v_exp < now() + interval '23 hours 50 minutes' OR v_exp > now() + interval '24 hours 10 minutes' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE19 l echeance n est pas a 24 h : ' || v_exp::text;
  END IF;

  -- UN RENFORT TOMBE N'EST PAS REMPLACE, et il n ouvre aucune vacance.
  PERFORM pg_temp.je_suis_le_serveur();
  PERFORM public.pnj_mourir('garde-republic-palais-presidentiel-renfort-1', 'banc');
  v := public.garde_republicaine_synchroniser('republic');
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic' AND e.building_id = PAL;
  IF v_n <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE20 un renfort tombe a ete remplace (' || v_n::text || ' gardes)';
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.garde_republicaine_postes
   WHERE pays = 'republic' AND building_id = PAL AND vacant_depuis IS NOT NULL;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE21 la chute d un renfort a ouvert une vacance';
  END IF;
  n := n + 1;   -- et le malus a baisse en consequence
  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_piece('republic', PAL, HALL);
  IF (v->>'malus')::integer <> 12 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE22 le malus n a pas suivi la perte : ' || v::text;
  END IF;

  -- LE POSTE DECIME : on abat les deux survivants du Palais.
  PERFORM pg_temp.je_suis_le_serveur();
  FOR g IN SELECT m.id FROM public.pnj_membres m
            JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
           WHERE m.statut = 'actif' AND e.pays = 'republic' AND e.building_id = PAL
  LOOP
    PERFORM public.pnj_mourir(g.id, 'banc');
  END LOOP;
  v := public.garde_republicaine_synchroniser('republic');

  n := n + 1;   -- IL EST REGARNI jusqu au facteur en cours
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic' AND e.building_id = PAL AND NOT e.permanent;
  IF v_n <> 2 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23a le poste decime n est pas regarni de ses renforts (' || v_n::text || ')';
  END IF;
  -- DEUX HOMMES, PAS TROIS, et c'est juste : le permanent vient de tomber et purge ses quatre
  -- heures. La regle du permanent et l'exception du poste decime sont deux regles distinctes qui
  -- se composent sans s'annuler ; attendre 3 ici serait demander a la decimation d'effacer le
  -- delai de retour du permanent.
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.garde_republicaine_postes
   WHERE pays = 'republic' AND building_id = PAL AND vacant_depuis IS NOT NULL;
  IF v_n <> 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE23b le permanent decime ne purge pas ses 4 h';
  END IF;

  n := n + 1;   -- MAIS L HORLOGE N A PAS BOUGE : tuer la Garde ne la prolonge pas
  SELECT expire_le INTO v_exp2 FROM public.garde_republicaine_renfort WHERE pays = 'republic';
  IF v_exp2 IS DISTINCT FROM v_exp THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE24 l echeance a ete repoussee : '
      || v_exp::text || ' -> ' || v_exp2::text;
  END IF;

  -- L EXPIRATION : on recule l horloge, les renforts rentrent, le permanent reste.
  UPDATE public.garde_republicaine_renfort SET expire_le = now() - interval '1 minute'
   WHERE pays = 'republic';
  v := public.garde_republicaine_synchroniser('republic');
  n := n + 1;
  IF (v->>'facteur')::integer <> 1 OR (v->>'partis')::integer < 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE25 les renforts ne sont pas rentres : ' || v::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic' AND NOT e.permanent;
  IF v_n <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE26 ' || v_n::text || ' renforts sont restes apres expiration';
  END IF;
  n := n + 1;   -- UN RENFORT QUI RENTRE N EST PAS UN MORT : il ne laisse pas son arme au sol
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'disparu' AND e.pays = 'republic' AND NOT e.permanent;
  IF v_n < 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE27 les renforts expires ne sont pas en disparu';
  END IF;

  -- TOUT OU RIEN : caisse vide, aucun garde, aucun debit.
  UPDATE public.caisses_batiments
     SET data = coalesce(data,'{}'::jsonb) || jsonb_build_object('solde', 10) WHERE id = V_CAISSE;
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic';
  PERFORM pg_temp.je_suis(ARNIE);
  v := public.garde_renfort_national(5);
  n := n + 1;
  IF coalesce((v->>'ok')::boolean,true) IS NOT FALSE
     OR v->>'raison' <> 'caisse_defense_insuffisante' THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE28 une caisse vide a finance un renfort : ' || v::text;
  END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  SELECT (data->>'solde')::numeric INTO v_sol FROM public.caisses_batiments WHERE id = V_CAISSE;
  IF v_sol <> 10 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE29 le refus a quand meme debite : ' || v_sol::text;
  END IF;
  n := n + 1;
  SELECT count(*) INTO v_ap FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic';
  IF v_ap <> v_n THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE30 le refus a quand meme cree des gardes';
  END IF;

  -- ===========================================================================================
  -- F. LE CONTROLE A L'ENTREE
  -- ===========================================================================================
  -- ON REMET UN GARDE EN FACTION AVANT DE TESTER LE CONTROLE, ET ON LE VERIFIE. Sans cette
  -- precaution les deux epreuves suivantes passeraient pour la mauvaise raison : un hall desert
  -- n'intercepte personne, et « aucune interception » ressemble alors a une reussite. Les
  -- epreuves qui se valident toutes seules sont les plus dangereuses d'un banc -- c'est ce que
  -- la premiere execution de ce banc a montre.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.garde_republicaine_postes SET vacant_depuis = now() - interval '5 hours'
   WHERE pays = 'republic' AND building_id = PAL;
  PERFORM public.garde_republicaine_synchroniser('republic');
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = 'republic' AND e.building_id = PAL;
  IF v_n < 1 THEN
    ko := ko + 1; v_echecs := v_echecs
      || E'\nE30b le hall n a pas de garde : les epreuves du controle seraient vides';
  END IF;

  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_controle(PAL, HALL);
  n := n + 1;
  IF coalesce((v->>'intervention')::boolean,true) IS NOT FALSE
     OR (v->>'gardes')::integer < 1 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE31 un citoyen ordinaire est intercepte : ' || v::text;
  END IF;

  -- ON FORGE UN JUGEMENT NON EXECUTE CONTRE LEE. Il disparait avec le ROLLBACK.
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES ('banc-jugement-garde', 'republic', 'capitale', 'Lee Capene', 'banc', 'banc', 'banc',
          0, false, '{"motifs":[{"jours":2}]}'::jsonb);

  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_controle(PAL, HALL);
  n := n + 1;
  IF coalesce((v->>'intervention')::boolean,false) IS NOT TRUE THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE32 une personne recherchee passe devant la Garde : ' || v::text;
  END IF;

  -- CONTRE-EPREUVE DECISIVE : la MEME personne recherchee, dans le MEME hall, mais sans garde
  -- vivant. Si l intervention avait lieu quand meme, la Garde serait un panneau et non des hommes.
  PERFORM pg_temp.je_suis_le_serveur();
  FOR g IN SELECT m.id FROM public.pnj_membres m
            JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
           WHERE m.statut = 'actif' AND e.pays = 'republic' AND e.building_id = PAL
  LOOP
    PERFORM public.pnj_mourir(g.id, 'banc');
  END LOOP;
  PERFORM pg_temp.je_suis(LEE);
  v := public.garde_republicaine_controle(PAL, HALL);
  n := n + 1;
  IF coalesce((v->>'intervention')::boolean,true) IS NOT FALSE
     OR (v->>'gardes')::integer <> 0 THEN
    ko := ko + 1; v_echecs := v_echecs || E'\nE33 un hall vide intercepte encore : ' || v::text;
  END IF;

  PERFORM pg_temp.je_suis_le_serveur();

  IF ko = 0 THEN
    RAISE EXCEPTION 'banc garde : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE
    RAISE EXCEPTION 'banc garde : % EPREUVES ROUGES sur %. %', ko, n, v_echecs;
  END IF;
END $banc$;

ROLLBACK;
