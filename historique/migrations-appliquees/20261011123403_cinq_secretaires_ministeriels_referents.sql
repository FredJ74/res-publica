-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011123403 (UTC), nom `cinq_secretaires_ministeriels_referents`.
-- Le registre passe de 646 a 647 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 811a0c045626273d58b577beecce0f61, 5753 caracteres, 1 instruction
-- au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- CINQ REFERENTS QUI N'AVAIENT AUCUN SOUVENIR
--
-- Les cinq ministres PNJ du Palais du Gouvernement sont les referents permanents de leur
-- ministere depuis la premiere passe -- corpus, role, titre de secretaire. Mais
-- `pnj_referents`, la LISTE FERMEE qui autorise la memoire pedagogique, ne les connaissait pas
-- : `referent_pedagogie_noter` rend `referent: false` et n'ecrit RIEN pour un identifiant
-- absent.
-- CONSEQUENCE REELLE : ils recommencaient a zero a chaque conversation, la ou Martial Bouterin,
-- Tom Hawak et Huguette Papier se souviennent de ce qu'ils ont deja explique. Ce n'etait pas un
-- arbitrage, c'etait un oubli de la premiere passe.
-- ILS SONT INCARNES PAR LA MEME OCCASION -- Yvan Danltat, Alain Theret, Mathilde Garde,
-- Marie-Eve Beaulieu, Jean-Jacques Carlin -- et leurs identifiants changent donc. Les anciennes
-- cles generiques n'ont jamais figure dans cette table : il n'y avait rien a renommer,
-- seulement cinq lignes a creer.
-- LE DOMAINE DECLARE EST CELUI DU MINISTERE, jamais le dehors personnel. Un bateau au port de
-- plaisance, un gout pour l'investissement locatif, le marche, le football de Montrouge,
-- l'EHPAD : ce sont des traits de personnage portes par le prompt. Les declarer ici aurait fait
-- de ces cinq les referents officiels de rayons qui appartiennent a Alain Bordage, Laurent
-- Barre, Marc Hantile et Lucas Tenaire -- et une preuve structurelle l'interdit desormais.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LES CINQ SECRETAIRES MINISTERIELS DEVIENNENT DES REFERENTS DECLARES (11 octobre 2026)
-- =================================================================================================
-- CE QUE LA PASSE PNJ A FAIT VOIR. Les cinq ministres PNJ du Palais du Gouvernement sont, depuis la
-- premiere passe, les referents permanents de leur ministere -- c'est le meme principe que Martial
-- Bouterin a la Defense. Mais `pnj_referents`, la LISTE FERMEE qui autorise la memoire pedagogique,
-- ne les connaissait pas : `referent_pedagogie_noter` rend `referent: false` et n'ecrit RIEN pour un
-- identifiant absent.
--
-- CONSEQUENCE REELLE : les cinq n'avaient AUCUN souvenir de ce qu'ils avaient deja explique. Un
-- joueur pouvait leur demander dix fois la meme chose, ils recommencaient a zero -- la ou Martial,
-- Tom Hawak ou Huguette se souviennent. Ce n'etait pas un arbitrage, c'etait un oubli : la premiere
-- passe leur a donne un corpus et un role de referent sans les inscrire.
--
-- ILS SONT AUSSI INCARNES PAR LA MEME OCCASION, et leurs identifiants changent donc : les anciennes
-- cles generiques (`le_ministre_de_l_interieur` et les quatre autres) n'ont jamais figure dans cette
-- table, il n'y a donc rien a renommer ici -- seulement cinq lignes a creer sous les vrais noms.
--
-- LE DOMAINE DECLARE EST CELUI DU MINISTERE, pas celui du dehors personnel. Yvan Danltat a un bateau
-- et Alain Theret un gout pour l'investissement locatif : ce sont des traits de personnage portes par
-- leur prompt, pas des domaines de reference. Les inscrire ici en ferait les referents officiels du
-- port de plaisance et de l'immobilier, ce qui doublerait Alain Bordage et Laurent Barre.
-- =================================================================================================

INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES
  ('yvan_danltat',        'ministere de l''Interieur — ordre public, manifestations, naturalisations, douanes', 'republic'),
  ('alain_theret',        'ministere des Finances — fiscalite, budget national, subventions, preemption',       'republic'),
  ('mathilde_garde',      'ministere de la Justice — plaintes, enquetes, juges, graces proposees, detention',    'republic'),
  ('marie_eve_beaulieu',  'ministere de l''Information — propagande, censure, sondages, communication',          'republic'),
  ('jean_jacques_carlin', 'ministere des Affaires etrangeres — treves, relations bilaterales, ambassades',       'republic')
ON CONFLICT (referent_id) DO UPDATE SET domaine = EXCLUDED.domaine, pays = EXCLUDED.pays;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_id text;
BEGIN
  -- P1 : les cinq sont declares, et dans le bon pays.
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE pays = 'republic' AND referent_id IN
     ('yvan_danltat','alain_theret','mathilde_garde','marie_eve_beaulieu','jean_jacques_carlin');
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'P1 : % des cinq secretaires ministeriels sont declares au lieu de 5', v_n;
  END IF;

  -- P2 : CHACUN A SON DOMAINE, ET AUCUN NE PARTAGE LE SIEN. Deux referents sous un meme libelle de
  -- domaine rendraient l'un des deux decoratif -- c'est la regle de decoupage du Palais.
  SELECT count(*) INTO v_n FROM (
    SELECT domaine FROM public.pnj_referents WHERE pays = 'republic'
     GROUP BY domaine HAVING count(*) > 1) q;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P2 : % domaine(s) de reference partage(s) par deux referents', v_n;
  END IF;

  -- P3 : AUCUN DEHORS PERSONNEL N'EST DEVENU UN DOMAINE DE REFERENCE. Le port de plaisance, le
  -- locatif, le marche, le football et l'EHPAD colorent cinq personnages ; ils ne font d'eux les
  -- referents de rien. Alain Bordage, Laurent Barre, Marc Hantile, Lucas Tenaire restent seuls
  -- sur leurs rayons.
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE referent_id IN ('yvan_danltat','alain_theret','mathilde_garde','marie_eve_beaulieu','jean_jacques_carlin')
     AND (domaine ILIKE '%plaisance%' OR domaine ILIKE '%locatif%' OR domaine ILIKE '%football%'
       OR domaine ILIKE '%marche%' OR domaine ILIKE '%ehpad%' OR domaine ILIKE '%universite%'
       OR domaine ILIKE '%alimentation%');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P3 : % dehors personnel(s) declare(s) comme domaine de reference', v_n;
  END IF;

  -- P4 : LES ANCIENNES CLES GENERIQUES N'ONT PAS ETE CREEES AU PASSAGE. Si elles existaient, deux
  -- identifiants pointeraient le meme personnage, et l'un des deux garderait un savoir vide.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id LIKE 'le_ministre_%';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P4 : % ancienne(s) cle(s) generique(s) de ministre dans le registre', v_n;
  END IF;

  -- P5 : le registre garde la ligne de Martial Bouterin, qui est le modele de cette mecanique. Si
  -- la Defense disparaissait du registre, le principe meme serait casse.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id = 'martial_bouterin';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P5 : le referent de la Defense a disparu du registre';
  END IF;

  -- P6 : et le registre compte desormais exactement 27 referents -- 22 plus les cinq.
  SELECT count(*) INTO v_n FROM public.pnj_referents;
  IF v_n <> 27 THEN
    RAISE EXCEPTION 'P6 : % referents au registre au lieu de 27', v_n;
  END IF;

  RAISE NOTICE 'Cinq secretaires ministeriels : les 6 preuves structurelles passent.';
END $$;
