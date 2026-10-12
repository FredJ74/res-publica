-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012091457 (UTC), nom
-- `parquet_identites_et_poste_procureur`.
-- Le registre passe de 671 a 672 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5f8b0d28f9d6f689eb8af2f453e57241, 8364 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (1/7) -- IDENTITES INSTITUTIONNELLES ET POSTE DE PROCUREUR
--
-- UN SEUL PROCUREUR POUR TOUT REPUBLIA, et il entre par le systeme GENERIQUE des postes
-- nommes : une ligne dans `postes_nommes_regles` (nomme par min_just, scope pays) suffit a lui
-- donner la chaine RH complete -- candidature, nomination, revocation, priorite PJ. Aucune
-- fonction n'est ecrite pour cela, et c'est exactement ce que le cahier des charges demandait.
--
-- HONORE COZETOUJOURS PREND LE SIEGE DE LUTHECIA. Le registre declarait « Juge Fontaine » ; or
-- Honore etait declare dans la MEME salle d'audience depuis le 1er octobre, avec le meme
-- `job: 'juge'` -- il y avait DEUX juges PNJ dans la piece et un seul au registre.
--
-- ET UNE RECTIFICATION DU RAPPORT DU MATIN : il annoncait « 15 noms, 0 divergence » entre
-- `titulaires_pnj` et la copie surveillee de data.js. Le registre en portait DIX-SEPT -- le
-- releve avait ete tronque, et il manquait `Raoul Toufaud (PNJ)` et `Marcel Silo (PNJ)`.
-- Consequence reelle : ces deux PNJ gamma n'etaient pas reconnus comme tels, donc l'ordre
-- generique « Neutraliser » leur restait offert. Corrige dans le meme lot.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PARQUET DE REPUBLIA (1/2) -- IDENTITES INSTITUTIONNELLES ET POSTE DE PROCUREUR
-- 12 octobre 2026
--
-- CE QUE CETTE MIGRATION FAIT, ET POURQUOI ELLE NE CREE AUCUNE ARCHITECTURE RH.
--
-- Le systeme de nomination des postes nommes est entierement PILOTE PAR UNE TABLE :
-- `postes_nommes_regles` dit qui nomme quoi, avec quelle portee, et `poste_autorite_de`,
-- `poste_nommer`, `poste_revoquer`, `poste_postuler`, `poste_accepter_nomination` et
-- `poste_attribuer_candidature` lisent toutes cette seule ligne. Declarer le procureur, c'est
-- donc lui donner d'un coup la chaine RH complete : candidature d'un joueur, nomination par le
-- Ministre de la Justice, revocation, priorite PJ sur le titulaire PNJ. AUCUNE fonction nouvelle
-- n'est ecrite pour cela, et c'est exactement ce que le cahier des charges demande.
--
-- UN SEUL PROCUREUR POUR TOUT REPUBLIA : `scope = 'pays'`, donc une seule ligne dans
-- `postes_attribues` et `city IS NULL`. Il n'existe pas de procureur local par ville -- la
-- competence territoriale ne se partage pas, elle se DEPLACE, et c'est la migration 2/2 qui pose
-- l'exigence de presence physique dans le tribunal de la ville de l'affaire.
--
-- NOMME PAR LE MINISTRE DE LA JUSTICE (`nomme_par = 'min_just'`), portee d'autorite nationale --
-- meme regle que le juge, dont le siege est en ville mais que le ministre nomme pour les trois
-- tribunaux. C'est la seule prerogative judiciaire qui reste au Ministre : la migration 2/2 lui
-- retire la porte par laquelle il classait lui-meme une plainte.
--
-- ET HONORE COZETOUJOURS PREND LE SIEGE DE LUTHECIA. `titulaires_pnj` declarait « Juge Fontaine »
-- titulaire PNJ du tribunal de la capitale ; or Honore Cozetoujours est declare dans la MEME
-- piece depuis le 1er octobre 2026 (surcharge de Luthecia, data.js), avec le meme `job: 'juge'`.
-- Il y avait donc DEUX juges PNJ dans la salle d'audience de Luthecia, dont un seul inscrit au
-- registre. Honore devient le titulaire, Fontaine quitte le registre.
--
-- UNE RECTIFICATION DU RAPPORT DU 12 OCTOBRE AU MATIN, AU PASSAGE. Il annoncait « 15 noms, 0
-- divergence dans les deux sens » entre `titulaires_pnj` et la copie surveillee de data.js. Le
-- registre en portait DIX-SEPT : le releve qui avait servi a ecrire la liste etait tronque, et il
-- manquait `Raoul Toufaud (PNJ)` (commissaire de la capitale) et `Marcel Silo (PNJ)` (directeur
-- de l'entrepot de la capitale). Consequence reelle : ces deux PNJ de famille gamma n'etaient pas
-- reconnus comme tels par `pnjEstGamma`, donc l'ordre generique « Neutraliser » leur restait
-- offert. La liste de data.js est completee dans le meme lot, et la preuve P6 ci-dessous porte
-- desormais sur le compte REEL.

-- ============================================================================================
-- 1. LE POSTE DE PROCUREUR ENTRE AU REFERENTIEL DES POSTES NOMMES
-- ============================================================================================
-- CE N'EST PAS UNE REGENERATION DU MIROIR, et l'interdit du lot 4D est respecte : aucune des 17
-- lignes existantes n'est modifiee. Declarer un poste NEUF n'est pas reparer la derive d'une
-- sentinelle -- c'est le meme raisonnement que l'insertion de `subvention_proposer` dans
-- `ordres_couts` le 10 octobre 2026.
INSERT INTO public.postes_nommes_regles (poste_id, label, nomme_par, scope, autorite_scope)
VALUES ('procureur', 'Procureur de la Republique', 'min_just', 'pays', 'pays')
ON CONFLICT (poste_id) DO UPDATE SET label = EXCLUDED.label,
  nomme_par = EXCLUDED.nomme_par, scope = EXCLUDED.scope,
  autorite_scope = EXCLUDED.autorite_scope;

-- ============================================================================================
-- 2. LES TITULAIRES PNJ
-- ============================================================================================
-- SAAD EST TITULAIRE PAR DEFAUT DU PARQUET. `city = NULL` : le poste est national.
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj)
VALUES ('republic_procureur', 'republic', 'procureur', NULL, 'Procureur Saad')
ON CONFLICT (id) DO UPDATE SET nom_pnj = EXCLUDED.nom_pnj;

-- HONORE REMPLACE FONTAINE AU TRIBUNAL DE LUTHECIA. L'identifiant de la ligne n'est pas touche :
-- c'est le MEME poste (juge / republic / capitale), seul son titulaire PNJ change.
UPDATE public.titulaires_pnj
   SET nom_pnj = 'Honoré Cozetoujours (PNJ)', updated_at = now()
 WHERE country = 'republic' AND poste_id = 'juge' AND city = 'capitale';

-- ============================================================================================
-- 3. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_r record;
BEGIN
  -- P1 : LE POSTE EXISTE, NATIONAL, NOMME PAR LE MINISTRE DE LA JUSTICE.
  SELECT * INTO v_r FROM public.postes_nommes_regles WHERE poste_id = 'procureur';
  IF NOT FOUND THEN RAISE EXCEPTION 'P1 ECHOUEE -- le poste de procureur n''est pas declare'; END IF;
  IF v_r.nomme_par <> 'min_just' OR v_r.scope <> 'pays' OR v_r.autorite_scope <> 'pays' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- regle inattendue : % / % / %',
      v_r.nomme_par, v_r.scope, v_r.autorite_scope;
  END IF;

  -- P2 : LES 17 AUTRES REGLES SONT INTACTES. Declarer un poste neuf ne doit rien deplacer.
  SELECT count(*) INTO v_n FROM public.postes_nommes_regles;
  IF v_n <> 18 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % regle(s) au lieu de 18', v_n; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles
                  WHERE poste_id = 'juge' AND nomme_par = 'min_just'
                    AND scope = 'ville' AND autorite_scope = 'pays') THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la regle du juge a bouge';
  END IF;

  -- P3 : UN SEUL PROCUREUR POUR TOUT REPUBLIA, et il est national (city NULL).
  SELECT count(*) INTO v_n FROM public.titulaires_pnj WHERE poste_id = 'procureur';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % titulaire(s) de procureur', v_n; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj
                  WHERE poste_id = 'procureur' AND country = 'republic'
                    AND city IS NULL AND nom_pnj = 'Procureur Saad') THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le titulaire PNJ du parquet n''est pas Saad, ou il est local';
  END IF;

  -- P4 : HONORE TIENT LE TRIBUNAL DE LUTHECIA, ET FONTAINE N'EST PLUS AU REGISTRE.
  IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj
                  WHERE country = 'republic' AND poste_id = 'juge' AND city = 'capitale'
                    AND nom_pnj = 'Honoré Cozetoujours (PNJ)') THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- Honore n''est pas titulaire du tribunal de la capitale';
  END IF;
  SELECT count(*) INTO v_n FROM public.titulaires_pnj WHERE nom_pnj = 'Juge Fontaine';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- Juge Fontaine est encore titulaire de % poste(s)', v_n; END IF;

  -- P5 : LES DEUX AUTRES JUGES N'ONT PAS BOUGE. Le cahier des charges ne parle que de Luthecia.
  IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj
                  WHERE poste_id = 'juge' AND city = 'ville_a' AND nom_pnj = 'Mireille Sedlex (PNJ)')
     OR NOT EXISTS (SELECT 1 FROM public.titulaires_pnj
                  WHERE poste_id = 'juge' AND city = 'ville_b' AND nom_pnj = 'Gérard Bretellewood (PNJ)') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- un juge de ville a ete touche';
  END IF;

  -- P6 : LE REGISTRE DES TITULAIRES COMPTE DIX-HUIT NOMS -- 17 avant, Fontaine REMPLACEE par
  --      Honore (donc toujours 17), plus Saad. La copie surveillee de data.js
  --      (PNJ_TITULAIRES_DE_POSTE_NOMS) doit porter ces 18 noms, et c'est le banc client qui le
  --      verifie : elle n'en portait que 15, parce qu'elle avait ete ecrite sur un releve tronque.
  SELECT count(*) INTO v_n FROM public.titulaires_pnj;
  IF v_n <> 18 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % titulaire(s) PNJ au lieu de 18', v_n; END IF;

  -- P7 : AUCUN POSTE N'EST ATTRIBUE AU PARQUET. Le poste nait vacant cote joueurs : c'est la
  --      cascade PNJ du cron, ou une candidature, qui le pourvoira.
  SELECT count(*) INTO v_n FROM public.postes_attribues WHERE poste_id = 'procureur';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7 ECHOUEE -- le parquet est deja attribue a quelqu''un'; END IF;

  RAISE NOTICE 'LES 7 PREUVES SONT VERTES.';
END
$preuves$;
