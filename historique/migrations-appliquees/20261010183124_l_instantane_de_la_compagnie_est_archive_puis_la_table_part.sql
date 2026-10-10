-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010183124 (UTC), nom `l_instantane_de_la_compagnie_est_archive_puis_la_table_part`.
-- Le registre passe de 632 a 633 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4712a747df5a4faa419a3bc9833da92a, 5217 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- RELIQUAT TECHNIQUE -- L'INSTANTANE DE LA COMPAGNIE EST ARCHIVE, PUIS LA TABLE PART
--
-- La dette du depot disait `zz_snap_cka_membres` « videe mais pas supprimee » : c'etait faux. La
-- purge du registre 623 n'avait retire qu'UNE ligne -- un policier de banc -- sur les CENT UNE
-- qu'elle contenait ; les cent restantes sont l'instantane des soldats PNJ de la compagnie de
-- Vince Lieutenant, photographies les 26 et 27 septembre 2026, dont 24 divergent encore de leur
-- etat courant. Comme un DROP est irreversible, les cent lignes partent d'abord dans
-- `purges_residus_bancs` DANS LA MEME TRANSACTION que la suppression : si l'archivage echoue, la
-- table reste.
--
-- NOTE D'ARCHIVE : une premiere tentative de cette migration a leve sur sa propre preuve, qui
-- comptait 101 archives au lieu de 100 parce que la ligne du registre 623 portait deja ce
-- `table_source` -- c'est ainsi que la ligne preexistante a ete decouverte, et rien n'avait alors
-- ete applique. Le corps enregistre ici est celui de la tentative CORRIGEE, dont la preuve P1
-- compte les archives DE CE JOUR.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- RELIQUAT TECHNIQUE -- zz_snap_cka_membres (10 octobre 2026)
--
-- CE QUE LE DEPOT CROYAIT, ET CE QUE LA BASE DIT. La dette consignee annoncait « artefact de banc,
-- VIDEE mais pas supprimee ». C'est FAUX, et la mesure a dit pourquoi : la purge du registre 623
-- avait retire de cette table UNE ligne -- un policier de banc, `police-republic-zztest-ville-POL-zz`
-- -- sur les CENT UNE qu'elle contenait. Avoir purge le residu avait fait croire que la table
-- entiere l'etait. Les cent lignes restantes sont les cent soldats PNJ de la compagnie
-- `compagnie-republic-1790116175239` -- celle de Vince Lieutenant -- photographies les 26 et
-- 27 septembre 2026. Un instantane de chantier, pas un residu vide.
--
-- LA PREMIERE TENTATIVE DE CETTE MIGRATION A ECHOUE SUR SA PROPRE PREUVE, et c'est ainsi qu'on l'a
-- su : elle comptait « 100 lignes archivees sous ce nom » et en a trouve 101, parce que la ligne du
-- registre 623 portait deja ce `table_source`. La preuve compte desormais les archives DE CE JOUR,
-- ce qui est la bonne question. Rien n'avait ete applique.
--
-- CE QUE LA MESURE A ETABLI AVANT DE DECIDER :
--   * les 100 identifiants de l'instantane existent TOUS dans `pnj_membres` : aucun PNJ n'a
--     disparu, et l'instantane ne protege donc aucune donnee perdue ;
--   * mais 24 d'entre eux DIVERGENT de leur etat actuel sur statut, ville, PA ou perimetre : la
--     table porte une information reelle, l'etat du 27 septembre, qu'aucune autre ne porte ;
--   * la compagnie compte aujourd'hui 96 membres, contre 100 dans la photo.
--
-- POURQUOI ON ARCHIVE AVANT DE SUPPRIMER. Un DROP est irreversible, et supprimer une information
-- qui n'existe nulle part ailleurs sur la seule foi d'une dette mal libellee serait exactement le
-- geste que la consigne interdit. Les cent lignes partent donc d'abord dans
-- `purges_residus_bancs` -- le mecanisme de reversibilite pose au registre 623 -- DANS LA MEME
-- TRANSACTION que la suppression. Si l'archivage echoue, la table reste.
--
-- CE N'EST PAS UNE DONNEE DE JEU, et c'est pour cela qu'elle part. Le prefixe `zz_` est la
-- convention de rebut du depot, `snap` dit l'instantane, et aucune fonction, aucune vue, aucune
-- cle etrangere, aucune policy ne la nomme : elle n'a ni ecrivain ni lecteur.

INSERT INTO public.purges_residus_bancs (table_source, cle, contenu, motif)
SELECT 'zz_snap_cka_membres', s.id, to_jsonb(s),
       'INSTANTANE DE CHANTIER archive le 10 octobre 2026 avant le DROP de la table : les 100 '
       'soldats PNJ de compagnie-republic-1790116175239, pris les 26-27 septembre 2026. Les 100 '
       'identifiants existaient tous dans pnj_membres au moment de l''archivage ; 24 divergeaient '
       'de leur etat courant (statut, ville, pa ou perimetre), ce qui est la seule information que '
       'cette table portait encore.'
  FROM public.zz_snap_cka_membres s;

DROP TABLE public.zz_snap_cka_membres;

DO $p$
DECLARE v integer;
BEGIN
  -- P1 : les cent lignes de CE JOUR sont archivees. Le compte porte sur le motif de cette
  -- migration, et non sur le `table_source` -- la ligne du registre 623 le porte deja.
  SELECT count(*) INTO v FROM public.purges_residus_bancs
   WHERE table_source = 'zz_snap_cka_membres' AND motif LIKE 'INSTANTANE DE CHANTIER%';
  IF v <> 100 THEN RAISE EXCEPTION 'P1 : % ligne(s) archivee(s) au lieu de 100', v; END IF;

  -- P2 : et la ligne du registre 623 est TOUJOURS LA. On archive, on n'ecrase pas.
  SELECT count(*) INTO v FROM public.purges_residus_bancs
   WHERE table_source = 'zz_snap_cka_membres' AND cle = 'police-republic-zztest-ville-POL-zz';
  IF v <> 1 THEN RAISE EXCEPTION 'P2 : l''archive du registre 623 a ete perdue (%)', v; END IF;

  -- P3 : chaque archive est complete -- une archive tronquee ne permettrait pas de restituer.
  SELECT count(*) INTO v FROM public.purges_residus_bancs
   WHERE table_source = 'zz_snap_cka_membres' AND motif LIKE 'INSTANTANE DE CHANTIER%'
     AND cle IS NOT NULL AND contenu ? 'id' AND contenu ? 'famille'
     AND contenu ? 'proprietaire_perimetre' AND contenu ? 'statut';
  IF v <> 100 THEN RAISE EXCEPTION 'P3 : % archive(s) completes au lieu de 100', v; END IF;

  -- P4 : LA TABLE N'EXISTE PLUS. Le DROP a bien eu lieu, et pas seulement l'archivage.
  IF to_regclass('public.zz_snap_cka_membres') IS NOT NULL THEN
    RAISE EXCEPTION 'P4 : la table existe encore'; END IF;

  -- P5 : ET AUCUN PNJ VIVANT N'A ETE TOUCHE. C'est la seule chose qui compte vraiment : les
  -- soldats de la compagnie vivent dans `pnj_membres`, pas dans l'instantane.
  SELECT count(*) INTO v FROM public.pnj_membres
   WHERE proprietaire_perimetre LIKE 'compagnie-republic-1790116175239%';
  IF v <> 96 THEN
    RAISE EXCEPTION 'P5 : la compagnie compte % membres au lieu de 96 -- la suppression a '
      'deborde sur le vivant', v;
  END IF;

  -- P6 : les archives restent inaccessibles aux clients.
  IF has_table_privilege('authenticated', 'public.purges_residus_bancs', 'SELECT')
     OR has_table_privilege('anon', 'public.purges_residus_bancs', 'SELECT') THEN
    RAISE EXCEPTION 'P6 : un client peut lire les archives de purge'; END IF;

  RAISE NOTICE 'Instantane archive puis table supprimee : 6 preuves vertes.';
END $p$;
