-- ============================================================================
-- CHANTIER 4E -- LE JUGE EST UN POSTE TERRITORIAL DE VILLE
--
-- ARBITRAGE DU 7 OCTOBRE 2026. Chaque ville a son juge, rattache au tribunal de
-- cette ville. Le rattachement territorial N'EST PAS un rattachement municipal :
-- le juge n'est pas sous l'autorite du maire, il releve du Ministre de la
-- Justice, et il est paye par le circuit de la Justice -- le tribunal de sa
-- ville, jamais la mairie.
--
-- CE QUE LA BASE SAVAIT DEJA, ET QU'IL NE FAUT PAS TOUCHER. Les trois relations
-- generiques expriment deja exactement cet arbitrage, chacune separement :
--   . TERRITOIRE  postes_nommes_regles.scope = 'ville'
--   . AUTORITE    postes_nommes_regles.autorite_scope = 'pays'  (min_just)
--   . PAYEUR      salaires_caisses.motif = '{pays}_tribunal_{ville}'
--                 caisses_autorites : tribunal -> {juge, min_just}
-- Aucun cas special n'est donc cree ici : les trois axes etaient deja
-- representables separement, et ils l'etaient correctement. La divergence ne
-- vivait que dans une copie JavaScript du cron, fermee par generation.
--
-- CE QUE CETTE MIGRATION CORRIGE : deux restes du temps ou le juge etait
-- national.
--
-- 1. UN QUATRIEME JUGE SANS VILLE. La ligne republic_juge_national portait
--    « Juge Fontaine » -- le MEME PNJ que le juge de la capitale, qui siegeait
--    donc deux fois. Elle datait de l'epoque ou le juge figurait dans la cascade
--    nationale du cron. L'arbitrage dit qu'elle n'est pas canonique et ne doit
--    pas servir de repli : on la supprime. Le cron ne peut plus la recreer --
--    l'entree juge de PNJ_PAR_DEFAUT_POSTE a ete retiree le meme jour.
--
--    Verifie avant suppression : aucun PJ ne tient de siege de juge, et aucune
--    autre table ne reference cet identifiant.
--
-- 2. UNE DECLARATION QUI SE CONTREDISAIT. salaires_caisses.juge portait
--    par_ville = false et la note « poste de portee nationale : tribunal de la
--    capitale », alors que son propre motif contient {ville} et que la paie
--    fonctionne par ville depuis toujours. Ni par_ville ni note ne sont lues par
--    une fonction : cette correction ne change aucun comportement. Elle fait
--    seulement cesser une declaration de mentir -- et c'est elle qui avait
--    induit l'audit en erreur.
--
-- CE QUI N'EST PAS TOUCHE, VOLONTAIREMENT. ville_defaut reste NULL pour le juge.
-- Lui donner 'capitale' recreerait exactement le repli que l'arbitrage interdit :
-- un juge sans ville serait silencieusement paye par le tribunal de la capitale.
-- Sans ville, la paie refuse par 'caisse_payeuse_non_declaree', et c'est le bon
-- comportement.
--
-- Idempotente : DELETE ... WHERE, UPDATE ... WHERE.
-- ============================================================================

DELETE FROM public.titulaires_pnj
 WHERE id = 'republic_juge_national'
   AND poste_id = 'juge'
   AND city IS NULL;

UPDATE public.salaires_caisses
   SET par_ville = true,
       note = 'tribunal de sa ville -- poste territorial, autorite nationale (min_just)'
 WHERE poste_id = 'juge';
