-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012094620 (UTC), nom
-- `parquet_referent_du_tribunal_honore_remplace_fontaine`.
-- Le registre passe de 677 a 678 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 076512d8ea1e8401340070e958646614, 3832 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (7/7) -- LE REFERENT DU TRIBUNAL
--
-- TROIS LISTES DOIVENT RESTER ALIGNEES, et le depot le dit lui-meme : PNJ_REFERENTS du
-- navigateur, REFERENTS de api/_pnj-referents.js, et la table `pnj_referents`. Les deux
-- premieres sont migrees dans le meme lot ; celle-ci suit.
--
-- FONTAINE ETAIT UN REFERENT SANS SIEGE : plus aucun poste au registre, plus aucune piece. Un
-- referent qu'on ne peut pas rencontrer n'est pas un referent.
--
-- ET DEUX AUTRES DOMAINES SONT REECRITS. Celui de Saad, parce que le parquet existe desormais
-- pour de vrai : avant ce lot il decrivait une fonction que le jeu n'implementait pas, les
-- plaintes allant au commissaire. Celui de Mathilde Garde, Ministre de la Justice, parce qu'elle
-- n'est plus la reference de la procedure du Tribunal -- elle nomme et revoque le Procureur, et
-- c'est la sa prerogative.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE REFERENT DU TRIBUNAL : HONORE REMPLACE FONTAINE
-- 12 octobre 2026
--
-- TROIS LISTES DOIVENT RESTER ALIGNEES, et le depot le dit lui-meme (plateau-pnj.js) : la
-- constante PNJ_REFERENTS du navigateur, le dictionnaire REFERENTS de api/_pnj-referents.js, et
-- cette table. Les deux premieres sont deja migrees dans le meme lot ; celle-ci suit.
--
-- FONTAINE ETAIT UN REFERENT SANS SIEGE. Elle n'avait aucun poste au registre apres la migration
-- des identites, et elle n'etait plus declaree dans aucune piece. Un referent qu'on ne peut pas
-- rencontrer n'est pas un referent.
--
-- ET LE DOMAINE D'HONORE EST CELUI QUE LE CAHIER DES CHARGES LUI DONNE : droit, procedure
-- judiciaire, fonctionnement du Tribunal. Mathilde Garde, Ministre de la Justice, garde le sien
-- -- le ministere -- mais elle n'est plus la reference de la procedure du Tribunal : son domaine
-- est reecrit pour ne plus l'annoncer.
--
-- LA TABLE PORTE 28 LIGNES, PAS 18 : le navigateur en declare 18 pour Republia, la base en
-- contient 28 parce qu'elle sert aussi les trois autres empires. La preuve P2 porte donc sur le
-- compte REEL -- c'est un REMPLACEMENT, et le compte ne doit pas bouger.
UPDATE public.pnj_referents
   SET referent_id = 'honore_cozetoujours',
       domaine = 'justice — droit, procedure judiciaire et fonctionnement du Tribunal'
 WHERE referent_id = 'juge_fontaine';

-- LE PARQUET EXISTE DESORMAIS POUR DE VRAI, et le domaine de Saad le dit.
UPDATE public.pnj_referents
   SET domaine = 'justice — le parquet : plaintes recues, enquetes diligentees, non-lieu, poursuites'
 WHERE referent_id = 'procureur_saad';

-- LE MINISTRE N'EST PLUS LA REFERENCE DE LA PROCEDURE JUDICIAIRE. Il nomme et revoque le
-- Procureur, et c'est la sa prerogative ; il ne classe plus aucune plainte.
UPDATE public.pnj_referents
   SET domaine = 'ministere de la Justice — nomination et revocation du Procureur, graces proposees, detention'
 WHERE referent_id = 'mathilde_garde';

DO $preuves$
DECLARE v_n integer;
BEGIN
  -- P1 : FONTAINE N'EST PLUS UN REFERENT, ET HONORE EN EST UN.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id = 'juge_fontaine';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- juge_fontaine est encore referent'; END IF;
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE referent_id = 'honore_cozetoujours' AND pays = 'republic';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % fiche(s) pour Honore au lieu d''une', v_n; END IF;

  -- P2 : LE NOMBRE DE REFERENTS N'A PAS BOUGE. C'est un REMPLACEMENT, pas un ajout : si le
  --      compte avait change, l'une des trois listes serait desormais plus longue que les autres.
  SELECT count(*) INTO v_n FROM public.pnj_referents;
  IF v_n <> 28 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % referent(s) en base au lieu de 28', v_n; END IF;

  -- P3 : LE MINISTRE N'ANNONCE PLUS LA PROCEDURE JUDICIAIRE comme son domaine.
  IF EXISTS (SELECT 1 FROM public.pnj_referents
              WHERE referent_id = 'mathilde_garde' AND domaine ILIKE '%plainte%') THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le ministre reste la reference des plaintes';
  END IF;

  -- P4 : ET AUCUN REFERENT N'A PERDU SON PAYS au passage.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE pays IS NULL;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % referent(s) sans pays', v_n; END IF;

  -- P5 : LE PARQUET ANNONCE SON VRAI DOMAINE. Avant ce lot, Saad decrivait une fonction que le
  --      jeu n'implementait pas : les plaintes allaient au commissaire.
  IF NOT EXISTS (SELECT 1 FROM public.pnj_referents
                  WHERE referent_id = 'procureur_saad' AND domaine ILIKE '%non-lieu%') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le domaine du parquet ne mentionne pas le non-lieu';
  END IF;

  RAISE NOTICE 'LES 5 PREUVES SONT VERTES.';
END
$preuves$;
