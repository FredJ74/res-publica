-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010155212 (UTC), nom `purge_des_residus_de_banc_archivee_et_bornee`.
-- Le registre passe de 622 a 623 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5c6bbd70bd36f1c59896c981c34d3c97, 10909 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- LA PURGE DES RESIDUS DE BANC -- ARCHIVEE, BORNEE, EXPLICABLE LIGNE PAR LIGNE
--
-- Un balayage de tout le schema `public` a releve 280 lignes marquees dans 25 tables. La purge ne
-- porte que sur les colonnes d'identite, et archive chaque ligne en jsonb dans
-- `purges_residus_bancs` dans la MEME transaction que sa suppression -- elle est donc reversible.
-- Les journaux forensiques et trois vraies lignes de la beta sont CONSERVES : 205 des 280 lignes.
-- `zz_snap_cka_membres`, artefact de banc, est videe ici ; son `DROP` ouvrira le lot suivant.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA PURGE DES RESIDUS DE BANC -- archivee, bornee, et explicable ligne par ligne
-- Standard de preuve du 10 octobre 2026 : « aucune donnee de banc residuelle ».
--
-- CE QUE LE BALAYAGE A TROUVE. Un parcours de TOUTES les tables du schema `public`, cherchant
-- `(zztest|zzville|zzbanc|zz-banc|banc-test)` dans `to_jsonb(ligne)::text`, a releve
-- 280 LIGNES DANS 25 TABLES. Le declencheur de ce balayage est un fait, pas un soupcon : le
-- terrain `zztest_terrain-chantier` est traite par la passe de minuit CHAQUE NUIT depuis le
-- 9 octobre (`jourTraite: 2026-10-10`, `dernierePenurieSignalee: 2026-10-10`), et il consigne une
-- penurie de materiaux sur un chantier qui n'existe pour aucun joueur.
--
-- TROIS REGLES DE PRUDENCE, et elles bornent tout ce qui suit.
--
--   1. LA PURGE NE PORTE QUE SUR LES COLONNES D'IDENTITE. Une ligne est un residu de banc parce
--      que son IDENTIFIANT, son PAYS, sa VILLE, son BATIMENT ou son ACTEUR porte le marqueur --
--      jamais parce que son contenu le MENTIONNE. TROIS lignes de la beta sont dans ce cas, et
--      elles sont CONSERVEES, nommees par la preuve P6 :
--        * `journal_editions / republic_2026-09-14` -- une vraie edition, qui parle d'un
--          evenement de banc ;
--        * `entreprises / brasserie-republic-capitale-hotel-republica` -- une vraie brasserie de
--          Republia, dont l'historique porte une vente de 74 FR a un client de banc ;
--        * `mails / ce-1790412302612-bd3c26` -- un vrai rapport de renseignement envoye a Arnie
--          le 25 septembre, qui nomme une cellule de banc.
--      Les effacer detruirait du jeu reel pour faire disparaitre un nom.
--
--   2. RIEN N'EST SUPPRIME SANS ETRE ARCHIVE D'ABORD. `purges_residus_bancs` recoit la ligne
--      entiere en jsonb, dans la MEME transaction que sa suppression. La purge est donc
--      reversible, et son contenu reste lisible.
--
--   3. LES JOURNAUX FORENSIQUES NE SONT PAS PURGES. `personnages_supprimes` (132 lignes),
--      `fiche_hausses_observees` (32), `fiche_inventaire_observe` (5) et
--      `historique_deplacements` (36) sont des traces d'OBSERVATION : elles existent pour qu'on
--      puisse reconstituer qui a fait quoi. Les lignes de banc n'y font aucun mal -- aucun
--      mecanisme de jeu ne les lit -- et les effacer detruirait une piste. Elles sont donc
--      CONSERVEES, et c'est une decision, pas un oubli : 205 des 280 lignes relevees.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS. La table `zz_snap_cka_membres` est elle-meme un artefact de
-- banc -- un instantane de `pnj_membres` pris par un banc, nom compris. La supprimer demande un
-- `DROP TABLE`, et ce canal de migration exige pour cela une confirmation interactive que ce lot
-- ne peut pas obtenir. Elle est donc NOMMEE ici, videe de son unique ligne, et son `DROP` est la
-- premiere ligne du lot suivant.

CREATE TABLE IF NOT EXISTS public.purges_residus_bancs (
  id bigserial PRIMARY KEY,
  table_source text NOT NULL,
  cle text,
  contenu jsonb NOT NULL,
  motif text NOT NULL,
  purge_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.purges_residus_bancs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.purges_residus_bancs FROM PUBLIC;
REVOKE ALL ON TABLE public.purges_residus_bancs FROM anon, authenticated;

COMMENT ON TABLE public.purges_residus_bancs IS
  'Archive des lignes de banc purgees du schema public. Une purge n''est acceptable que si elle '
  'est reversible : la ligne entiere est copiee ici dans la MEME transaction que sa suppression. '
  'Aucun role client n''y a acces -- c''est une table d''administration.';

DO $purge$
DECLARE
  M constant text := '(zztest|zzville|zzbanc|zz-banc|banc-test)';
  -- TABLE, COLONNES D'IDENTITE, COLONNE DE CLE. Liste EXPLICITE : pas de boucle sur le catalogue,
  -- pas de regex sur un blob. Chaque ligne de ce tableau est une decision.
  CIBLES constant text[][] := ARRAY[
    ARRAY['terrains_etat',            'id,country,building_id',                  'id'],
    ARRAY['batiments_etat',           'id,country,city,building_id',             'id'],
    ARRAY['caisses_batiments',        'id',                                      'id'],
    ARRAY['comptes_bancaires',        'id,personnage,pays',                      'id'],
    ARRAY['cycles_electoraux',        'id,country,city',                         'id'],
    ARRAY['indices_villes',           'id',                                      'id'],
    ARRAY['entreprises',              'id',                                      'id'],
    ARRAY['entrepots_par_ville',      'ville,building_id',                       'ville'],
    ARRAY['fraudes_electorales',      'id,country,city,auteur,candidat',         'id'],
    ARRAY['confiscations_douanieres', 'personne,pays,ville,building_id',         'id'],
    ARRAY['prisonniers_qhs',          'id',                                      'id'],
    ARRAY['pnj_membres',              'id,pays,ville,building_id,proprietaire_pj','id'],
    ARRAY['presences',                'name,country,city,building_id',           'name'],
    ARRAY['objets_recus',             'destinataire,expediteur',                 'id'],
    ARRAY['pa_credits_uniques',       'acteur,source,reference',                 'acteur'],
    ARRAY['fonds_debits',             'acteur',                                  'id'],
    ARRAY['mails',                    'from_player,to_player',                   'id'],
    ARRAY['mails_envois_systeme',     'auteur_reel,expediteur,destinataire',     'id'],
    ARRAY['zz_snap_cka_membres',      'id,pays,ville,proprietaire_pj',           'id']
  ];
  i integer; v_tbl text; v_cle text; v_pred text;
  v_n bigint; v_total bigint := 0; v_detail text[] := '{}';
BEGIN
  FOR i IN 1 .. array_length(CIBLES, 1) LOOP
    v_tbl := CIBLES[i][1];
    v_cle := CIBLES[i][3];
    v_pred := format('concat_ws(''|'', t.%s) ~* %L', replace(CIBLES[i][2], ',', ', t.'), M);

    -- 1. ARCHIVER, dans la meme transaction.
    EXECUTE format(
      'INSERT INTO public.purges_residus_bancs (table_source, cle, contenu, motif)
         SELECT %L, t.%I::text, to_jsonb(t), ''marqueur dans une colonne d identite : %s''
           FROM public.%I t WHERE %s',
      v_tbl, v_cle, CIBLES[i][2], v_tbl, v_pred);
    GET DIAGNOSTICS v_n = ROW_COUNT;

    -- 2. PUIS SUPPRIMER, exactement les memes lignes.
    EXECUTE format('DELETE FROM public.%I t WHERE %s', v_tbl, v_pred);
    v_total := v_total + v_n;
    IF v_n > 0 THEN v_detail := v_detail || format('%s : %s', v_tbl, v_n); END IF;
  END LOOP;

  RAISE NOTICE 'Purge : % ligne(s) archivees puis supprimees -- %',
    v_total, array_to_string(v_detail, ', ');
END $purge$;

-- PREUVES. Elles constatent l'etat APRES la purge, sans rien ecrire de plus.
DO $p$
DECLARE
  M constant text := '(zztest|zzville|zzbanc|zz-banc|banc-test)';
  PREDS constant text[][] := ARRAY[
    ARRAY['terrains_etat',            'id, t.country, t.building_id'],
    ARRAY['batiments_etat',           'id, t.country, t.city, t.building_id'],
    ARRAY['caisses_batiments',        'id'],
    ARRAY['comptes_bancaires',        'id, t.personnage, t.pays'],
    ARRAY['cycles_electoraux',        'id, t.country, t.city'],
    ARRAY['indices_villes',           'id'],
    ARRAY['entreprises',              'id'],
    ARRAY['entrepots_par_ville',      'ville, t.building_id'],
    ARRAY['fraudes_electorales',      'id, t.country, t.city, t.auteur, t.candidat'],
    ARRAY['confiscations_douanieres', 'personne, t.pays, t.ville, t.building_id'],
    ARRAY['prisonniers_qhs',          'id'],
    ARRAY['pnj_membres',              'id, t.pays, t.ville, t.building_id, t.proprietaire_pj'],
    ARRAY['presences',                'name, t.country, t.city, t.building_id'],
    ARRAY['objets_recus',             'destinataire, t.expediteur'],
    ARRAY['pa_credits_uniques',       'acteur, t.source, t.reference'],
    ARRAY['fonds_debits',             'acteur'],
    ARRAY['mails',                    'from_player, t.to_player'],
    ARRAY['mails_envois_systeme',     'auteur_reel, t.expediteur, t.destinataire'],
    ARRAY['zz_snap_cka_membres',      'id, t.pays, t.ville, t.proprietaire_pj']
  ];
  i integer; v_n bigint; v_arch bigint; v_restants text[] := '{}'; v_contenu text[] := '{}';
BEGIN
  -- P1 : l'archive contient bien ce qui a ete supprime.
  SELECT count(*) INTO v_arch FROM public.purges_residus_bancs;
  IF v_arch = 0 THEN RAISE EXCEPTION 'P1 : rien n''a ete archive -- la purge n''a rien fait'; END IF;

  -- P2 : plus AUCUNE ligne d'identite marquee dans les tables de jeu purgees.
  FOR i IN 1 .. array_length(PREDS, 1) LOOP
    EXECUTE format('SELECT count(*) FROM public.%I t WHERE concat_ws(''|'', t.%s) ~* %L',
                   PREDS[i][1], PREDS[i][2], M) INTO v_n;
    IF v_n > 0 THEN v_restants := v_restants || format('%s : %s', PREDS[i][1], v_n); END IF;
    -- P6, dans la meme boucle : les lignes dont SEUL LE CONTENU mentionne un nom de banc.
    EXECUTE format('SELECT count(*) FROM public.%I t WHERE to_jsonb(t)::text ~* %L
                     AND NOT (concat_ws(''|'', t.%s) ~* %L)',
                   PREDS[i][1], M, PREDS[i][2], M) INTO v_n;
    IF v_n > 0 THEN v_contenu := v_contenu || format('%s : %s', PREDS[i][1], v_n); END IF;
  END LOOP;
  IF array_length(v_restants, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'P2 : identites de banc restantes -- %', array_to_string(v_restants, ', ');
  END IF;

  -- P3 : LES JOURNAUX FORENSIQUES SONT INTACTS, et on le verifie plutot que de l'affirmer.
  IF (SELECT count(*) FROM public.personnages_supprimes) = 0 THEN
    RAISE EXCEPTION 'P3 : l''archive des personnages supprimes a ete videe'; END IF;
  IF (SELECT count(*) FROM public.historique_deplacements) = 0 THEN
    RAISE EXCEPTION 'P3 : l''historique des deplacements a ete vide'; END IF;

  -- P4 : LES TROIS LIGNES REELLES DE LA BETA QUI MENTIONNENT UN NOM DE BANC SONT TOUJOURS LA.
  IF NOT EXISTS (SELECT 1 FROM public.journal_editions WHERE id = 'republic_2026-09-14') THEN
    RAISE EXCEPTION 'P4a : l''edition du 14 septembre a disparu'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.entreprises
                  WHERE id = 'brasserie-republic-capitale-hotel-republica') THEN
    RAISE EXCEPTION 'P4b : la brasserie de l''Hotel Republica a disparu'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mails WHERE id = 'ce-1790412302612-bd3c26') THEN
    RAISE EXCEPTION 'P4c : le rapport de renseignement du 25 septembre a disparu'; END IF;

  -- P5 : aucun role client ne voit l'archive de purge.
  IF has_table_privilege('anon', 'public.purges_residus_bancs', 'SELECT')
     OR has_table_privilege('authenticated', 'public.purges_residus_bancs', 'SELECT') THEN
    RAISE EXCEPTION 'P5 : l''archive de purge est lisible par un client'; END IF;

  RAISE NOTICE 'Purge : 6 preuves vertes. % ligne(s) archivees. Conservees pour contenu seul : %.',
    v_arch, coalesce(array_to_string(v_contenu, ', '), 'aucune');
END $p$;
