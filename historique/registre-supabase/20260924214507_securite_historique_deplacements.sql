-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924214507
-- Nom original      : securite_historique_deplacements
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 21:45:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a4d21d0a6e9433933676209973d02cdf
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =============================================================================================
-- CHANTIER SECURITE — LOT 4 : L'HISTORIQUE DES DEPLACEMENTS CESSE D'ETRE PUBLIC (24 sept. 2026)
-- =============================================================================================
-- 9 911 lignes nominatives -- ou se trouve chaque personnage, jour et heure -- etaient lisibles
-- par n'importe qui, SANS JETON (policy « deplacements lecture » USING(true) pour anon).
--
-- IL EXISTE POURTANT UNE VRAIE MECANIQUE : l'ordre `organiser_filature` (data.js:2824), reserve
-- au commissaire, 2 PA et 150 FR, decrit comme « obtenir un rapport des deplacements d'un PJ sur
-- les dernieres 24h », avec un jet de reussite. Le probleme n'est donc pas la filature : c'est
-- que le client lisait la TABLE en direct, ce qui rendait le poste, le cout, le jet et la fenetre
-- de 24 h purement decoratifs -- n'importe qui obtenait l'historique integral de n'importe qui,
-- gratuitement et sans jet.
--
-- ON NE TOUCHE PAS AU GAME DESIGN. Les deux regles appliquees ici sont ECRITES DANS L'ORDRE
-- LUI-MEME : reserve au commissaire, et fenetre de 24 heures. Le jet de reussite et le paiement
-- restent ou ils sont, cote client, exactement comme aujourd'hui -- les deplacer serait changer
-- la mecanique, ce qui n'est pas demande.
--
-- La fenetre suit la notion de jour du jeu, `personnages_donnees.day` du COMMISSAIRE, comme le
-- fait deja le client (jourMin = state.day - 1). Pas de 24 heures glissantes inventees.

CREATE OR REPLACE FUNCTION public.filature_deplacements(p_cible text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_jour integer; v_lignes jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  -- Autorite : le poste est relu EN BASE, jamais accepte du client.
  PERFORM public.exiger_poste('commissaire');

  IF coalesce(btrim(coalesce(p_cible,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LES DERNIERES 24 HEURES, ET RIEN DE PLUS : le libelle de l'ordre fait foi.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'jour', h.jour, 'heure', h.heure,
           'building_id', h.building_id, 'room_id', h.room_id, 'city', h.city)
           ORDER BY h.jour, h.heure), '[]'::jsonb)
    INTO v_lignes
    FROM public.historique_deplacements h
   WHERE h.name = p_cible AND h.jour >= greatest(1, v_jour - 1);

  RETURN jsonb_build_object('ok', true, 'cible', p_cible, 'deplacements', v_lignes);
END;
$function$;

REVOKE ALL ON FUNCTION public.filature_deplacements(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.filature_deplacements(text) TO authenticated, service_role;

-- La table n'est plus lisible du navigateur. L'ecriture passait deja par la RPC
-- `deplacement_enregistrer` (SECURITY DEFINER, qui derive le personnage de mon_personnage()) :
-- elle n'est donc pas touchee, et aucune ecriture legitime n'est cassee.
DROP POLICY IF EXISTS "deplacements lecture" ON public.historique_deplacements;
DROP POLICY IF EXISTS deplacements_lecture ON public.historique_deplacements;
REVOKE SELECT ON public.historique_deplacements FROM anon, authenticated;