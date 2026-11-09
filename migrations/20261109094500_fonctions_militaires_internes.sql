-- FONCTIONS MILITAIRES INTERNES : PLUS APPELABLES DEPUIS UN NAVIGATEUR (Claude, 09/11/2026)
--
-- Audit des 26 fonctions SECURITY DEFINER executables par anon (referentiel-game-design,
-- AUDIT-ACCUEIL-I18N-NUIT-DROITS.md, section D). 24 sont sures : gardees par exiger_acteur /
-- mon_personnage / acteur_poste_courant, neutralisees (calomnie_distribuer), ou lectures publiques
-- voulues (journal publie, sieges de l'assemblee, catalogue d'un commerce, empreintes de
-- configuration). Deux etaient des helpers internes sans aucune garde d'identite :
--  * militaire_terminal_liaison(p_moi, p_pnj_id) : n'importe qui pouvait sonder si un PJ nomme
--    porte une radio, ou se trouve avec un PNJ donne ;
--  * militaire_arme_operationnelle(p_pnj_id) : revelait la meilleure arme d'un PNJ.
-- Aucun appel navigateur ni API (verifie dans le depot) : seuls les appellent d'autres fonctions
-- SECURITY DEFINER, executees avec les droits de leur proprietaire, que ce retrait ne touche pas.
REVOKE EXECUTE ON FUNCTION public.militaire_terminal_liaison(text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.militaire_arme_operationnelle(text) FROM PUBLIC, anon, authenticated;

DO $verif$
BEGIN
  IF has_function_privilege('anon', 'public.militaire_terminal_liaison(text, text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.militaire_terminal_liaison(text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.militaire_arme_operationnelle(text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.militaire_arme_operationnelle(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'helpers militaires encore appelables par un client';
  END IF;
END
$verif$;
