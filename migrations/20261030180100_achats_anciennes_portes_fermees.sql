-- =============================================================================
-- ACHATS : FERMETURE DES ANCIENNES PORTES SANS CLE (Claude, 30/10/2026)
-- =============================================================================
-- A APPLIQUER SEULEMENT APRES le deploiement de l'ecran qui envoie p_requete
-- (branche claude/achats-cle-unicite-20261030), et apres 20261030180000.
-- Avant ce deploiement, l'ecran en ligne appelle encore ces signatures : les fermer
-- plus tot rendrait ces achats impossibles.
--
-- Les anciennes signatures restent appelables par le serveur : les nouvelles portes
-- (proprietaire postgres) les appellent pour faire l'achat. Seul le joueur perd le
-- droit de les appeler directement, donc d'acheter sans cle.
-- commerce_acheter_matiere : relais historique sans aucun appelant, qui fabriquait une
-- cle aleatoire devant commerce_apporter_matiere (la porte a cle, inchangee).
-- =============================================================================
DO $$
DECLARE s text;
BEGIN
  FOREACH s IN ARRAY ARRAY[
    'public.acheter_a_entrepot(text, text, text, text, jsonb)',
    'public.acheter_a_la_criee(text, text, text, text, jsonb)',
    'public.acheter_vente_directe_usine(text, text, text, text, jsonb)',
    'public.acheter_produit_manufacture(text, text, text)',
    'public.objet_acheter(text, text, integer, integer)',
    'public.arme_acheter(text, text)',
    'public.crime_acheter_arme_noire(text, text, boolean)',
    'public.crime_acheter_explosifs(integer, integer)',
    'public.imprimerie_acheter_bois(integer)',
    'public.commerce_acheter_matiere(text, text, text, integer)'] LOOP
    EXECUTE 'REVOKE ALL ON FUNCTION ' || s || ' FROM PUBLIC, anon, authenticated';
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
