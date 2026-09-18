-- =====================================================================
-- CHANTIER C — ENTONNOIR SERVEUR DE SORTIE D'INVENTAIRE (14 septembre 2026)
-- =====================================================================
-- L'inventaire personnel avait un entonnoir d'ENTREE cote client (addToInventory,
-- plateau-divers.js) et AUCUN entonnoir de sortie : 32 sites retiraient des objets par
-- splice/filter directs, puis -- parfois -- appelaient separement une ecriture serveur.
-- Ce decoupage produit trois defauts structurels :
--   1. le navigateur decide seul de la quantite finale de l'inventaire ;
--   2. un don/abandon peut faire disparaitre l'objet chez l'expediteur SANS jamais arriver
--      chez le destinataire (deux requetes, aucune transaction, .catch(() => {}) par-dessus) ;
--   3. la protection des objets de quete est evaluee par le client, donc contournable, et
--      elle a d'ailleurs deja trois angles morts (dropItem, don a un employe, caisse de fret).
--
-- On ne cree PAS une RPC generique capable de retirer n'importe quoi a n'importe qui : une
-- primitive INTERNE porte la mecanique commune (localisation, protection, quantite, retrait),
-- et CINQ GUICHETS nommes portent chacun leur regle metier et leur contrepartie. L'identite
-- vient toujours du compte connecte via exiger_acteur().
--
-- Aucune regle de jeu modifiee : protection du colis secret, familles consommables, perimetre
-- de saisie et semantique empilable/unique sont repris a l'identique du client.

-- =====================================================================
-- PARTIE 0 — PREREQUIS : PERSISTER L'ETAT DE QUETE DE CARRIERE
-- =====================================================================
-- Anomalie constatee pendant l'audit : state.char.queteCarriere, dont depend TOUTE la
-- protection du colis secret (colisSecretProtege, plateau-pnj.js:756), n'est ecrit dans
-- AUCUNE colonne. Il ne survit que par localStorage -- la meme dependance au cache local qui
-- a produit le bug du personnage fantome. Consequences : la quete de carriere est perdue au
-- changement de navigateur ou d'appareil, et le serveur est structurellement incapable
-- d'evaluer la protection.
--
-- On persiste donc l'etat tel quel, sans changer sa forme ni la regle qui le lit.
ALTER TABLE public.personnages_donnees
  ADD COLUMN IF NOT EXISTS quete_carriere jsonb;

-- =====================================================================
-- PARTIE 1 — JUMEAU SERVEUR DE colisSecretProtege
-- =====================================================================
-- Regle reprise mot pour mot : type 'colis_secret_pat', ambition 'criminel', etape non
-- terminee. Aucune generalisation -- le client ne protege que cet objet precis.
--
-- FAIL-CLOSED sur l'inconnu : si quete_carriere est absente (personnage anterieur a la
-- colonne ci-dessus, ou client pas encore mis a jour), un colis secret est traite comme
-- PROTEGE. Laisser passer detruirait un objet indispensable a une quete sur la foi d'une
-- donnee manquante ; refuser ne coute qu'un emplacement d'inventaire, et la situation se
-- resout d'elle-meme des la premiere sauvegarde du client a jour.
CREATE OR REPLACE FUNCTION public.inventaire_objet_protege(p_quete jsonb, p_item jsonb)
RETURNS boolean
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(p_item->>'type', '') = 'colis_secret_pat'
     AND (p_quete IS NULL
          OR (coalesce(p_quete->>'ambition', '') = 'criminel'
              AND coalesce(p_quete->>'etape', '') <> 'terminee'));
$$;

-- =====================================================================
-- PARTIE 2 — LOCALISATION D'UN OBJET DANS UN INVENTAIRE
-- =====================================================================
-- Le client designe ses objets par INDEX. Un index est inutilisable tel quel cote serveur :
-- il derive des qu'un autre onglet, un vol ou le cron modifie l'inventaire. On l'accepte donc
-- comme INDICE, jamais comme autorite : la position proposee n'est retenue que si l'element
-- qui s'y trouve correspond a la signature annoncee (name + type + stackKey) ; sinon on
-- cherche le premier element qui correspond vraiment. Si rien ne correspond : objet absent.
--
-- C'est ce qui rend l'appel sur et rejouable : une seconde soumission ne retire jamais
-- "l'objet voisin" qui aurait glisse a la place du premier.
CREATE OR REPLACE FUNCTION public.inventaire_localiser(p_inv jsonb, p_index integer, p_signature jsonb)
RETURNS integer
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH inv AS (
    SELECT e, (ord - 1)::int AS pos
      FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
  ), correspond AS (
    SELECT pos FROM inv
     WHERE coalesce(e->>'name', '')     = coalesce(p_signature->>'name', '')
       AND coalesce(e->>'type', '')     = coalesce(p_signature->>'type', '')
       AND coalesce(e->>'stackKey', '') = coalesce(p_signature->>'stackKey', '')
  )
  SELECT coalesce(
    (SELECT pos FROM correspond WHERE pos = p_index),
    (SELECT min(pos) FROM correspond),
    -1);
$$;

-- Retrait d'un element UNIQUE par position. inventaire_retirer() ne sait traiter que les
-- objets empilables (par stackKey) ; les objets uniques n'ont ni stackKey ni identifiant
-- stable, il faut donc pouvoir en retirer un exemplaire par sa position -- une fois celle-ci
-- etablie par le serveur lui-meme, jamais annoncee par le client.
CREATE OR REPLACE FUNCTION public.inventaire_retirer_position(p_inv jsonb, p_pos integer)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
    FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
   WHERE (ord - 1) <> p_pos;
$$;

-- =====================================================================
-- PARTIE 3 — PRIMITIVE INTERNE COMMUNE
-- =====================================================================
-- INTERNE : aucun grant, aucun controle d'identite ici. Elle suppose que l'appelant a DEJA
-- verifie l'acteur et pose le verrou -- meme doctrine que helvetia_debiter_fonds_ordinaires,
-- dont l'exposition accidentelle au navigateur a ete le defaut trouve par le banc de parcours
-- joueur de la passe precedente.
--
-- Applique dans l'ordre : quantite -> localisation -> protection -> retrait.
-- Ne fait AUCUNE ecriture : elle renvoie le nouvel inventaire et l'objet sorti, a charge du
-- guichet appelant de les ecrire dans la meme transaction que sa contrepartie.
CREATE OR REPLACE FUNCTION public.helvetia_inventaire_sortie(
  p_inv jsonb, p_quete jsonb, p_index integer, p_signature jsonb, p_qte integer)
RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_pos integer; v_item jsonb; v_cle text; v_detenu numeric; v_nouveau jsonb; v_sorti jsonb;
BEGIN
  IF p_qte IS NULL OR p_qte <= 0 OR p_qte > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  v_pos := public.inventaire_localiser(p_inv, p_index, p_signature);
  IF v_pos < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent');
  END IF;
  v_item := p_inv -> v_pos;

  IF public.inventaire_objet_protege(p_quete, v_item) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_protege');
  END IF;

  v_cle := v_item->>'stackKey';
  IF coalesce((v_item->>'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    -- Objet empilable : la quantite totale detenue fait foi, jamais la ligne. Verifiee AVANT
    -- le retrait : inventaire_retirer() seule laisserait passer une demande superieure au
    -- stock en supprimant simplement la ligne devenue negative -- un retrait silencieusement
    -- partiel, que l'appelant croirait complet.
    v_detenu := public.inventaire_quantite(p_inv, v_cle);
    IF v_detenu < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante', 'detenu', v_detenu);
    END IF;
    v_nouveau := public.inventaire_retirer(p_inv, v_cle, p_qte);
    v_sorti := v_item || jsonb_build_object('qty', p_qte);
  ELSE
    -- Objet unique : un exemplaire, jamais plus. Demander 2 exemplaires d'un objet qui n'en a
    -- qu'un est un refus, pas un retrait de ce qui existe.
    IF p_qte <> 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante', 'detenu', 1);
    END IF;
    v_nouveau := public.inventaire_retirer_position(p_inv, v_pos);
    v_sorti := v_item;
  END IF;

  RETURN jsonb_build_object('ok', true, 'inventory', v_nouveau, 'objet', v_sorti, 'position', v_pos);
END; $$;

REVOKE ALL ON FUNCTION public.helvetia_inventaire_sortie(jsonb, jsonb, integer, jsonb, integer)
  FROM PUBLIC, anon, authenticated;

-- =====================================================================
-- PARTIE 4 — GUICHET : DESTRUCTION DEFINITIVE
-- =====================================================================
-- Aucune contrepartie, aucune trace : c'est exactement ce que fait deja le bouton "Supprimer
-- (destruction definitive)". Le seul apport du serveur est que la protection de quete et la
-- quantite ne sont plus evaluees par le navigateur.
CREATE OR REPLACE FUNCTION public.inventaire_detruire(
  p_acteur text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
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

-- =====================================================================
-- PARTIE 5 — GUICHET : ABANDON DANS LA PIECE COURANTE
-- =====================================================================
-- Retrait ET depot dans objets_abandonnes DANS LA MEME TRANSACTION. Avant ce lot, le client
-- faisait un splice local puis un INSERT separe avec .catch(() => {}) : un reseau qui lache
-- entre les deux detruisait l'objet sans que personne ne puisse jamais le ramasser.
CREATE OR REPLACE FUNCTION public.inventaire_abandonner(
  p_acteur text, p_index integer, p_signature jsonb,
  p_country text, p_city text, p_building text, p_room text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
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
  -- objet.id tel quel -- donc NULL le plus souvent, pour une colonne qui sert de cle primaire.
  v_id := 'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '');
  v_objet := (v_r->'objet') || jsonb_build_object('id', v_id);

  UPDATE public.personnages_donnees SET inventory = v_r->'inventory' WHERE name = p_acteur;
  INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
  VALUES (v_id, p_country, p_city, p_building, p_room, v_objet::text);

  RETURN v_r || jsonb_build_object('objet', v_objet, 'objet_id', v_id);
END; $$;

-- =====================================================================
-- PARTIE 6 — GUICHET : DON A UN AUTRE JOUEUR
-- =====================================================================
-- Meme atomicite. Le destinataire doit exister reellement : donner a un nom invente faisait
-- jusqu'ici disparaitre l'objet dans le vide.
CREATE OR REPLACE FUNCTION public.inventaire_donner(
  p_acteur text, p_destinataire text, p_index integer, p_signature jsonb, p_qte integer DEFAULT 1)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
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

-- =====================================================================
-- PARTIE 7 — GUICHET : USAGE UNIQUE (CONSOMMATION / DESTRUCTION PAR L'USAGE)
-- =====================================================================
-- Famille reelle du jeu, pas une invention : aliment consomme, medicament pris, explosif
-- utilise, poison administre. Tous ont la meme sortie -- un exemplaire disparait a l'usage.
-- Les EFFETS (faim, soins, degats, peremption) restent au client : ce sont des regles de jeu,
-- pas des quantites d'inventaire, et les deplacer ici serait modifier le game design. Le
-- serveur garantit uniquement qu'un exemplaire reellement detenu a ete retire, une seule fois.
CREATE OR REPLACE FUNCTION public.inventaire_consommer(
  p_acteur text, p_index integer, p_signature jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
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

-- =====================================================================
-- PARTIE 8 — GUICHET : CONFISCATION
-- =====================================================================
-- Sortie EN MASSE, dont le perimetre n'est pas choisi par le joueur mais calcule par la regle.
-- Reprend exactement objetsSaisissables() (plateau-justice-economie.js:9754) :
--   saisissable = legal === false  OU  vise par une loi mecanique en vigueur (§39)
--   moins les objets de quete proteges.
-- Le jumeau serveur de la seconde condition existait deja : assemblee_loi_en_vigueur(), qui
-- lit les propositions reellement adoptees. Le navigateur ne choisit donc plus ce qu'il rend.
--
-- Le guichet ne porte AUCUNE peine : convocations, detentions et amendes restent ou elles
-- sont, chaque appelant ayant les siennes. Ce guichet ne fait que la saisie elle-meme.
CREATE OR REPLACE FUNCTION public.inventaire_confisquer(p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_inv jsonb; v_quete jsonb; v_pays text; v_trouve boolean;
  v_saisis jsonb; v_restant jsonb;
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

-- =====================================================================
-- PARTIE 9 — DROITS
-- =====================================================================
-- Piege deja rencontre cinq fois sur ce chantier : ALTER DEFAULT PRIVILEGES accorde EXECUTE a
-- anon sur toute fonction nouvellement creee. Il faut REVOKE ... FROM PUBLIC, anon avant de
-- donner explicitement le droit a authenticated.
REVOKE ALL ON FUNCTION public.inventaire_objet_protege(jsonb, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_localiser(jsonb, integer, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_retirer_position(jsonb, integer) FROM PUBLIC, anon;

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
