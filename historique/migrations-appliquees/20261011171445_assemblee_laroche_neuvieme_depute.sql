-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011171445 (UTC), nom
-- `assemblee_laroche_neuvieme_depute`.
-- Le registre passe de 659 a 660 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 269c50ee41279408a73b16ecba1cdb27, 5703 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LAROCHE EST L UN DES NEUF, ET IL N Y A PLUS DE DIXIEME PARLEMENTAIRE
--
-- L'arbitrage du 11 octobre tranche le point laisse ouvert par la troisieme passe : la presidence
-- est une FONCTION portee par l'un des neuf deputes, et le President Laroche -- qui existait comme
-- DIXIEME carte de l'hemicycle, presidant sans siege -- devient depute de Luthecia.
-- C'est BENOIT DELORME qui lui cede le siege, au rang 3. Le choix n'a aucune incidence de jeu --
-- les neuf PNJ sont volontairement identiques -- mais l'existant en avait une : Sophie Marechal et
-- Etienne Vauclerc sont nommes dans trois bancs, Benoit Delorme nulle part ailleurs que dans la
-- definition de son siege. Le rang 3, lui, est deliberement choisi : un depute joueur elu a
-- Luthecia prend le rang 1, puis 2, puis 3 -- le President en exercice reste donc assis aussi
-- longtemps qu'il reste un siege PNJ dans sa ville.
-- LE NOM RESTE « President Laroche », et ce n'est pas un oubli : son profil de dialogue serveur est
-- la cle `president_laroche`, derivee de son nom affiche. Le renommer le rendrait muet. Que son NOM
-- affirme une fonction qu'il peut perdre est un defaut d'identite reel, consigne au rapport, et il
-- appartient a la passe Laroche que l'arbitrage reserve.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ASSEMBLEE NATIONALE -- QUATRIEME PASSE, §1 : LAROCHE EST L'UN DES NEUF
-- 11 octobre 2026
--
-- LA TROISIEME PASSE A RENDU LE FAIT ET LAISSE L'ARBITRAGE OUVERT. Le President Laroche existait
-- comme DIXIEME carte de l'hemicycle : un figurant institutionnel qui presidait sans siege. Les
-- neuf sieges, eux, etaient tenus par neuf autres PNJ. L'arbitrage du 11 octobre tranche : la
-- presidence est une FONCTION portee par l'un des neuf, Laroche est depute de Luthecia, et il ne
-- doit plus exister de dixieme parlementaire.
--
-- QUI A ETE REMPLACE, ET POURQUOI CELUI-LA. Les trois sieges de Luthecia etaient tenus par
-- Etienne Vauclerc (rang 1), Sophie Marechal (rang 2) et Benoit Delorme (rang 3). L'arbitrage dit
-- que le choix individuel n'a pas d'importance ; l'existant, lui, en avait un :
--
--   . Sophie Marechal est nommee dans trois bancs (banc-presidence-election.sql l'interroge comme
--     eligible, banc-assemblee-regards.sql et banc-assemblee-hall.js la citent dans un scrutin
--     forge). La retirer aurait demande de reecrire des epreuves qui ne parlent pas d'elle.
--   . Etienne Vauclerc est nomme dans banc-assemblee-hall.js (etat de seance forge).
--   . Benoit Delorme n'est nomme NULLE PART ailleurs que dans la definition du siege et dans sa
--     ligne de statistiques. C'est donc lui qui cede le siege -- le remplacement le moins
--     bruyant, pas un jugement sur le personnage.
--
-- LE RANG 3 N'EST PAS NEUTRE, ET C'EST VOULU. Un depute PJ elu a Luthecia prend le siege de rang
-- 1, puis 2, puis 3 (assemblee_occupation_sieges classe les PJ par nom et les apparie aux rangs).
-- Placer Laroche au rang 3 fait de lui le DERNIER PNJ de Luthecia a ceder sa place : le President
-- en exercice reste assis aussi longtemps que possible.
--
-- UNE MISE A JOUR, PAS UNE SUPPRESSION-RECREATION. La ligne porte une cle etrangere entrante ;
-- surtout, l'identifiant du siege (`republic:capitale:3`) est une reference stable citee par les
-- intentions et les scrutins. On change son OCCUPANT PNJ, jamais le siege.
--
-- LE NOM RESTE « President Laroche ». Il n'est pas touche ici, et ce n'est pas un oubli : le
-- profil de dialogue serveur du personnage est la cle `president_laroche`, derivee de son nom
-- affiche par slugPnj(). Le renommer le rendrait muet. Le fait que son NOM affirme une fonction
-- qu'il peut perdre est un defaut d'identite reel, consigne au rapport ; il appartient a la passe
-- Laroche, que l'arbitrage reserve explicitement.

UPDATE public.assemblee_sieges
   SET pnj_id  = 'dep_laroche',
       pnj_nom = 'President Laroche'
 WHERE id = 'republic:capitale:3';

DO $$
DECLARE v_n integer; v_txt text;
BEGIN
  -- 1. NEUF SIEGES, exactement.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges WHERE country = 'republic';
  IF v_n <> 9 THEN RAISE EXCEPTION 'PREUVE 1 : % sieges au lieu de 9', v_n; END IF;

  -- 2. TROIS PAR VILLE, exactement, sur trois villes.
  SELECT count(*) INTO v_n FROM (
    SELECT city FROM public.assemblee_sieges WHERE country = 'republic'
     GROUP BY city HAVING count(*) = 3) x;
  IF v_n <> 3 THEN RAISE EXCEPTION 'PREUVE 2 : % villes a 3 sieges au lieu de 3', v_n; END IF;

  -- 3. LAROCHE EST L'UN DES TROIS DE LUTHECIA.
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_sieges
                  WHERE country = 'republic' AND city = 'capitale'
                    AND pnj_id = 'dep_laroche' AND pnj_nom = 'President Laroche') THEN
    RAISE EXCEPTION 'PREUVE 3 : Laroche n''est pas depute de Luthecia';
  END IF;

  -- 4. UNE SEULE FOIS. Ni doublon de nom, ni doublon d'identifiant PNJ.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges WHERE pnj_id = 'dep_laroche';
  IF v_n <> 1 THEN RAISE EXCEPTION 'PREUVE 4 : % sieges tenus par dep_laroche', v_n; END IF;
  SELECT count(*) INTO v_n FROM (
    SELECT pnj_nom FROM public.assemblee_sieges WHERE country = 'republic'
     GROUP BY pnj_nom HAVING count(*) > 1) x;
  IF v_n <> 0 THEN RAISE EXCEPTION 'PREUVE 4 bis : % noms de PNJ en double', v_n; END IF;

  -- 5. LE PNJ REMPLACE A DISPARU DES SIEGES.
  IF EXISTS (SELECT 1 FROM public.assemblee_sieges WHERE pnj_id = 'dep_delorme') THEN
    RAISE EXCEPTION 'PREUVE 5 : dep_delorme tient encore un siege';
  END IF;

  -- 6. LAROCHE EST ELIGIBLE A LA PRESIDENCE PARCE QU'IL EST DEPUTE, et par aucune autre voie.
  --    assemblee_presidence_eligibles derive les NEUF SIEGES et rien d'autre : si Laroche y
  --    figure, c'est en tant que titulaire d'un siege.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic');
  IF v_n <> 9 THEN RAISE EXCEPTION 'PREUVE 6 : % eligibles au lieu de 9', v_n; END IF;
  -- Le nom cote serveur est le nom NU : assemblee_occupation_sieges renvoie `pnj_nom` tel quel,
  -- sans le suffixe « (PNJ) » que l'ecran ajoute a l'affichage. C'est ce nom nu qui est inscrit
  -- dans postes_attribues par le depouillement, et donc celui que renvoie assemblee_president().
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_eligibles('republic') e
                  WHERE e.depute = 'President Laroche') THEN
    SELECT string_agg(e.depute, ' | ' ORDER BY e.depute) INTO v_txt
      FROM public.assemblee_presidence_eligibles('republic') e;
    RAISE EXCEPTION 'PREUVE 6 bis : Laroche absent des eligibles. Liste : %', v_txt;
  END IF;

  -- 7. LE SIEGE N'A PAS BOUGE. On a change l'occupant, pas la geometrie de l'hemicycle.
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_sieges
                  WHERE id = 'republic:capitale:3' AND city = 'capitale' AND rang = 3) THEN
    RAISE EXCEPTION 'PREUVE 7 : le siege republic:capitale:3 n''est plus le rang 3 de Luthecia';
  END IF;

  RAISE NOTICE 'LES 7 PREUVES DE §1 SONT VERTES.';
END $$;
