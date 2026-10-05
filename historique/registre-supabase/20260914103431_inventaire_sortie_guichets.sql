-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914103431
-- Nom original      : inventaire_sortie_guichets
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:34:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : dbece5de914bb424935995c92ab54a84
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
-- GUICHET 1 : DESTRUCTION DEFINITIVE. Aucune contrepartie, aucune trace : c'est exactement ce
-- que fait deja le bouton "Supprimer (destruction definitive)". Le seul apport du serveur est
-- que la protection de quete et la quantite ne sont plus evaluees par le navigateur.
CREATE OR REPLACE FUNCTION public.inventaire_detruire(
  p_acteur text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $$;

-- GUICHET 2 : ABANDON DANS LA PIECE. Retrait ET depot dans objets_abandonnes DANS LA MEME
-- TRANSACTION. Avant ce lot, le client faisait un splice local puis un INSERT separe avec
-- .catch(() => {}) : un reseau qui lache entre les deux detruisait l'objet sans que personne
-- ne puisse jamais le ramasser.
CREATE OR REPLACE FUNCTION public.inventaire_abandonner(
  p_acteur text, p_index integer, p_signature jsonb,
  p_country text, p_city text, p_building text, p_room text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_objet jsonb; v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_building, '') = '' OR coalesce(p_room, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  -- Identifiant attribue par le SERVEUR : la plupart des objets uniques du jeu n'ont aucun
  -- champ id (seuls les objets de quete en ont un), et l'ancien chemin client reprenait
  -- objet.id tel quel -- donc NULL le plus souvent, pour une colonne qui est la cle primaire.
  v_id := 'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '');
  v_objet := (v_r->'objet') || jsonb_build_object('id', v_id);

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
  VALUES (v_id, p_country, p_city, p_building, p_room, v_objet::text);

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $$;

-- GUICHET 3 : DON A UN AUTRE JOUEUR. Meme atomicite. Le destinataire doit exister reellement :
-- donner a un nom invente faisait jusqu'ici disparaitre l'objet dans le vide.
CREATE OR REPLACE FUNCTION public.inventaire_donner(
  p_acteur text, p_destinataire text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_destinataire, '') = '' OR p_destinataire = p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, p_qte);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  -- objets_recus est le SAS obligatoire : le serveur n'ecrit JAMAIS directement dans
  -- l'inventaire du destinataire, dont le client ouvert reecrirait le tableau entier et
  -- ecraserait l'ajout (doctrine posee par migration_moteur_commerce.sql).
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, p_acteur, v_r->'objet');

  RETURN v_r || jsonb_build_object('objet_id', v_id);
END; $$;

-- GUICHET 4 : USAGE UNIQUE. Famille reelle du jeu, pas une invention : aliment consomme,
-- medicament pris, explosif utilise, poison administre -- tous ont la meme sortie, un
-- exemplaire disparait a l'usage. Les EFFETS (faim, soins, degats, peremption) restent au
-- client : ce sont des regles de jeu, pas des quantites d'inventaire, et les deplacer ici
-- serait modifier le game design. Le serveur garantit uniquement qu'un exemplaire reellement
-- detenu a ete retire, une seule fois.
CREATE OR REPLACE FUNCTION public.inventaire_consommer(
  p_acteur text, p_index integer, p_signature jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inv jsonb; v_quete jsonb; v_trouve boolean; v_r jsonb; v_pos integer; v_item jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere
    INTO v_trouve, v_inv, v_quete
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;

  IF NOT (coalesce(v_item->>'familleProduitMarche', '') = 'aliment'
          OR coalesce(v_item->>'type', '') IN ('medicament', 'explosif', 'poison')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_consommable');
  END IF;

  v_r := public.helvetia_inventaire_sortie(v_inv, v_quete, p_index, p_signature, 1);
  IF NOT (v_r->>'ok')::boolean THEN RETURN v_r; END IF;

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  RETURN v_r;
END; $$;

-- GUICHET 5 : CONFISCATION. Sortie EN MASSE, dont le perimetre n'est pas choisi par le joueur
-- mais calcule par la regle. Reprend exactement objetsSaisissables()
-- (plateau-justice-economie.js:9754) : saisissable = legal === false OU vise par une loi
-- mecanique en vigueur (§39), moins les objets de quete proteges. Le jumeau serveur de la
-- seconde condition existait deja -- assemblee_loi_en_vigueur(), qui lit les propositions
-- reellement adoptees. Le navigateur ne choisit donc plus ce qu'il rend.
-- Le guichet ne porte AUCUNE peine : convocations, detentions et amendes restent chez leurs
-- appelants respectifs, qui ont chacun les leurs.
CREATE OR REPLACE FUNCTION public.inventaire_confisquer(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_inv jsonb; v_quete jsonb; v_pays text; v_trouve boolean; v_saisis jsonb; v_restant jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere, coalesce(country, 'republic')
    INTO v_trouve, v_inv, v_quete, v_pays
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  WITH elements AS (
    SELECT e, (coalesce((e->>'legal')::boolean, true) = false
               OR public.assemblee_loi_en_vigueur(v_pays, e, now()) IS NOT NULL)
              AND NOT public.inventaire_objet_protege(v_quete, e) AS saisi
      FROM jsonb_array_elements(v_inv) e
  )
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE saisi), '[]'::jsonb),
         coalesce(jsonb_agg(e) FILTER (WHERE NOT saisi), '[]'::jsonb)
    INTO v_saisis, v_restant FROM elements;

  IF jsonb_array_length(v_saisis) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'saisis', '[]'::jsonb, 'inventory', v_inv, 'noms', '');
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_restant WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'saisis', v_saisis, 'inventory', v_restant,
    'noms', (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(v_saisis) e));
END; $$;

-- Piege deja rencontre cinq fois sur ce chantier : ALTER DEFAULT PRIVILEGES accorde EXECUTE a
-- anon sur toute fonction nouvellement creee. REVOKE explicite avant tout GRANT.
REVOKE ALL ON FUNCTION public.inventaire_detruire(text, integer, jsonb, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_abandonner(text, integer, jsonb, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_donner(text, text, integer, jsonb, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_consommer(text, integer, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_confisquer(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.inventaire_detruire(text, integer, jsonb, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_abandonner(text, integer, jsonb, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_donner(text, text, integer, jsonb, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_consommer(text, integer, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_confisquer(text) TO authenticated;
