-- BANC DES SUBVENTIONS MUNICIPALES -- 1 SUR 3 : LA PROPOSITION (10 octobre 2026)
--
-- CE BANC NE COMMITE RIEN, ET CE N'EST PAS UNE PRECAUTION DE STYLE. Il doit poser un decor que
-- la bete n'a pas : un maire elu, un president de club, une enveloppe dotee. Ce decor s'ecrit
-- dans des tables de JEU -- `cycles_electoraux`, `personnages_donnees`, `presidents_clubs`,
-- `caisses_batiments`. Un banc du 4 octobre 2026 a laisse dans `fraudes_electorales` une
-- accusation forgee au nom d'un joueur reel, restee six jours en production : il avait commite.
-- Celui-ci se termine par un RAISE EXCEPTION, que les epreuves soient vertes OU rouges, et le
-- ROLLBACK final est donc inconditionnel. Un banc qui ecrit dans une table de jeu doit s'annuler.
--
-- POURQUOI LE DECOR DOIT ETRE ECRIT, ET NON SIMULE. `poste_est_atteste` refuse un poste de maire
-- qui ne vient pas du depouillement : la verite d'un poste elu est `cycles_electoraux.data.eluId`,
-- et le trigger `personnages_attester_poste` la verifie a chaque ecriture de fiche. On ne peut
-- donc pas « se declarer maire » -- pas meme dans un banc, pas meme en postgres. Le decor passe
-- par le meme chemin que le jeu, ce qui est precisement ce qui rend l'epreuve credible.
--
-- MESURES DE DEPART : Ben a 10 PA, l'enveloppe de la capitale est dotee a 5 000 FR pour le banc,
-- l'Olympique de Luthecia est le seul eligible de la capitale, et sa caisse est a 0.

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

-- LES DEUX GRANT NE SONT PAS DECORATIFS. Depuis le registre 561, une fonction neuve n'est
-- appelable par personne par defaut : sans eux, le banc reprendrait son identite de serveur et
-- TOUTES les epreuves passeraient pour la mauvaise raison -- en postgres, rien n'est refuse.
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  BEN  text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5';
  MARS text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac';
  LEE  text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6';
  v jsonb; ko integer := 0; n integer := 0;
  v_solde numeric; v_pa integer; v_caisse_club numeric; v_reserve numeric;
  v_id1 text; v_id2 text;
BEGIN
  -- ============================ LE DECOR ============================
  PERFORM pg_temp.je_suis_le_serveur();

  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId', 'Ben', 'phase', 'mandat'))::text
   WHERE id = 'republic_maire_capitale';
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId', 'Marsault'))::text
   WHERE id = 'republic_maire_ville_a';

  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'maire', 'name', 'Maire', 'city', 'capitale')
   WHERE name = 'Ben';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'maire', 'name', 'Maire', 'city', 'ville_a')
   WHERE name = 'Marsault';

  INSERT INTO public.presidents_clubs (id, data, updated_at)
  VALUES ('olympique-luthecia', jsonb_build_object('president', 'May'), now())
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;

  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 5000)
   WHERE id = 'republic_subventions_capitale';

  -- Le decor a bien pris : si l'attestation avait refuse, le poste serait reste NULL et toutes
  -- les epreuves suivantes auraient menti en refusant pour la mauvaise raison.
  IF (SELECT poste->>'city' FROM public.personnages_donnees WHERE name = 'Ben') IS DISTINCT FROM 'capitale' THEN
    RAISE EXCEPTION 'DECOR : Ben n''est pas maire de la capitale -- l''attestation a refuse';
  END IF;

  -- ============ EPREUVE 0 : LE BANC PORTE VRAIMENT L'IDENTITE QU'IL CROIT ============
  -- Sans cette epreuve, un banc reste en postgres verdit tout : en serveur, aucune porte ne
  -- refuse rien. Elle doit venir AVANT les autres, parce qu'elle conditionne leur sens.
  PERFORM pg_temp.je_suis(LEE);
  n := n + 1;
  IF current_user <> 'authenticated' OR public.mon_personnage() IS DISTINCT FROM 'Lee Capene' THEN
    RAISE EXCEPTION 'E0 l''identite de banc n''est pas prise : role=%, personnage=%',
      current_user, coalesce(public.mon_personnage(), 'NULL');
  END IF;

  -- ===================== EPREUVE 1 : UN NON-MAIRE EST REFUSE =====================
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'autorite_insuffisante' THEN
    ko := ko + 1; RAISE WARNING 'E1 un non-maire a obtenu : %', v; END IF;

  -- ============ EPREUVE 2 : UN MAIRE D'UNE AUTRE COMMUNE EST REFUSE ============
  -- La territorialite n'est pas une politesse : Marsault est un VRAI maire, elu, atteste. Son
  -- refus ne peut donc venir que de la commune du beneficiaire.
  PERFORM pg_temp.je_suis(MARS);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'beneficiaire_hors_commune' THEN
    ko := ko + 1; RAISE WARNING 'E2 le maire de ville_a a obtenu : %', v; END IF;

  -- ============ EPREUVES 3 ET 4 : L'ELIGIBILITE N'EST PAS NEGOCIABLE ============
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('criminelle', 'olympique-luthecia', 1000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'famille_non_eligible' THEN
    ko := ko + 1; RAISE WARNING 'E3 une criminelle a obtenu : %', v; END IF;

  v := public.subvention_proposer('confrerie_forgee', 'olympique-luthecia', 1000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'famille_inconnue' THEN
    ko := ko + 1; RAISE WARNING 'E4 une famille forgee a obtenu : %', v; END IF;

  -- ============ EPREUVES 5 A 7 : LES MONTANTS IMPOSSIBLES ============
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 0);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'montant_invalide' THEN
    ko := ko + 1; RAISE WARNING 'E5 un montant nul a obtenu : %', v; END IF;

  v := public.subvention_proposer('club_football', 'olympique-luthecia', -500);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'montant_invalide' THEN
    ko := ko + 1; RAISE WARNING 'E6 un montant negatif a obtenu : %', v; END IF;

  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1500.5);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'montant_invalide' THEN
    ko := ko + 1; RAISE WARNING 'E7 un montant a centimes a obtenu : %', v; END IF;

  -- ============ EPREUVE 8 : AU-DELA DE L'ENVELOPPE ============
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 6000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'fonds_insuffisants' THEN
    ko := ko + 1; RAISE WARNING 'E8 6000 sur 5000 a obtenu : %', v; END IF;

  -- ============ EPREUVE 9 : LA PROPOSITION LEGITIME PASSE, ET RESERVE ============
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1500);
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE THEN
    ko := ko + 1; RAISE WARNING 'E9 la proposition legitime a ete refusee : %', v;
  ELSE
    v_id1 := v->>'id';
    IF (v->>'reserve')::numeric <> 1500 OR (v->>'disponible')::numeric <> 3500 THEN
      ko := ko + 1; RAISE WARNING 'E9 reserve/disponible faux : %', v; END IF;
  END IF;

  -- ============ EPREUVE 10 : LE REJEU NE COUTE NI ARGENT NI PA ============
  -- Le meme montant, le meme jour, au meme beneficiaire : c'est un double-clic, pas une
  -- intention. Il doit etre refuse AVANT la facturation.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = 'Ben';
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1500);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'proposition_identique_en_attente' THEN
    ko := ko + 1; RAISE WARNING 'E10 le rejeu a obtenu : %', v; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = 'Ben') <> v_pa THEN
    ko := ko + 1;
    RAISE WARNING 'E11 le rejeu a coute des PA : % avant, % apres',
      v_pa, (SELECT pa FROM public.personnages_donnees WHERE name = 'Ben'); END IF;

  -- ============ EPREUVES 12 ET 13 : PAS DE SUR-RESERVATION ============
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 3000);
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'disponible')::numeric <> 500 THEN
    ko := ko + 1; RAISE WARNING 'E12 la seconde proposition : %', v;
  ELSE v_id2 := v->>'id'; END IF;

  -- 1500 + 3000 = 4500 sur 5000 : il reste 500. Une troisieme de 1000 doit tomber.
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'fonds_insuffisants' THEN
    ko := ko + 1; RAISE WARNING 'E13 la sur-reservation est passee : %', v; END IF;

  -- ============ EPREUVE 14 : AUCUNE PROPOSITION NE DEPLACE UN FRANC ============
  -- C'est le coeur du modele : proposer RESERVE, cela ne PAIE pas. L'enveloppe est intacte et le
  -- club n'a rien touche, alors que 4 500 FR sont engages.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (data->>'solde')::numeric INTO v_solde FROM public.caisses_batiments
   WHERE id = 'republic_subventions_capitale';
  n := n + 1;
  IF v_solde <> 5000 THEN
    ko := ko + 1; RAISE WARNING 'E14 l''enveloppe a bouge sans acceptation : %', v_solde; END IF;

  SELECT coalesce((data->>'caisse')::numeric, -1) INTO v_caisse_club
    FROM public.budgets_clubs WHERE id = 'olympique-luthecia';
  n := n + 1;
  IF v_caisse_club <> 0 THEN
    ko := ko + 1; RAISE WARNING 'E15 le club a ete credite sans acceptation : %', v_caisse_club; END IF;

  -- ============ EPREUVE 16 : LES PA ONT ETE PRELEVES UNE FOIS PAR PROPOSITION ============
  -- Deux propositions acceptees par la porte = 4 PA. Ni 2 (une seule facturee), ni 6 (un rejeu
  -- facture), ni 8 (double facturation).
  n := n + 1;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = 'Ben') <> 6 THEN
    ko := ko + 1;
    RAISE WARNING 'E16 PA de Ben = % au lieu de 6 (10 - 2 - 2)',
      (SELECT pa FROM public.personnages_donnees WHERE name = 'Ben'); END IF;

  -- ============ EPREUVE 17 : LA RESERVE EST UNE SOMME, PAS UNE COLONNE ============
  SELECT coalesce(sum(montant), 0) INTO v_reserve FROM public.subventions_municipales
   WHERE pays = 'republic' AND ville = 'capitale' AND statut = 'proposee';
  n := n + 1;
  IF v_reserve <> 4500 THEN
    ko := ko + 1; RAISE WARNING 'E17 la reserve calculee vaut % au lieu de 4500', v_reserve; END IF;

  -- ============ EPREUVE 18 : UN CLIENT NE DEBITE PAS L'ENVELOPPE A LA MAIN ============
  -- La primitive heritee existe toujours et reste appelable. Elle doit refuser cette caisse.
  PERFORM pg_temp.je_suis(BEN);
  v := public.caisse_institution_mouvement('republic_subventions_capitale', -1000);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'caisse_reservee_au_serveur' THEN
    ko := ko + 1; RAISE WARNING 'E18 un maire a pu debiter l''enveloppe : %', v; END IF;

  -- ============ EPREUVE 19 : LES PROPOSITIONS EN ATTENTE NE SONT PAS PUBLIQUES ============
  -- La policy ne laisse voir que les propositions CLOSES. Sous l'identite d'un joueur, donc sous
  -- la RLS, les deux propositions en attente doivent etre invisibles.
  n := n + 1;
  IF (SELECT count(*) FROM public.subventions_municipales WHERE statut = 'proposee') <> 0 THEN
    ko := ko + 1;
    RAISE WARNING 'E19 % proposition(s) en attente visible(s) sous la RLS',
      (SELECT count(*) FROM public.subventions_municipales WHERE statut = 'proposee'); END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  IF ko = 0 THEN RAISE EXCEPTION 'LES % EPREUVES SONT VERTES.', n;
  ELSE RAISE EXCEPTION 'ECHEC : % epreuve(s) sur % en defaut.', ko, n; END IF;
END $banc$;

ROLLBACK;
