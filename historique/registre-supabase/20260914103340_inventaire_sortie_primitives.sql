-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914103340
-- Nom original      : inventaire_sortie_primitives
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 10:33:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7fb98ab5e640ddd7e9cf419494f9daed
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
-- Jumeau serveur de colisSecretProtege (plateau-pnj.js:756). Regle reprise mot pour mot :
-- type 'colis_secret_pat', ambition 'criminel', etape non terminee. Aucune generalisation.
--
-- FAIL-CLOSED sur l'inconnu : si quete_carriere est absente (personnage anterieur a la colonne,
-- ou client pas encore a jour), un colis secret est traite comme PROTEGE. Laisser passer
-- detruirait un objet indispensable a une quete sur la foi d'une donnee manquante ; refuser ne
-- coute qu'un emplacement d'inventaire, et se resout des la premiere sauvegarde du client.
CREATE OR REPLACE FUNCTION public.inventaire_objet_protege(p_quete jsonb, p_item jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(p_item->>'type', '') = 'colis_secret_pat'
     AND (p_quete IS NULL
          OR (coalesce(p_quete->>'ambition', '') = 'criminel'
              AND coalesce(p_quete->>'etape', '') <> 'terminee'));
$$;

-- Le client designe ses objets par INDEX. Un index est inutilisable tel quel cote serveur : il
-- derive des qu'un autre onglet, un vol ou le cron modifie l'inventaire. On l'accepte comme
-- INDICE, jamais comme autorite : la position proposee n'est retenue que si l'element qui s'y
-- trouve correspond a la signature annoncee (name + type + stackKey) ; sinon on cherche le
-- premier element qui correspond vraiment. Si rien ne correspond : objet absent.
-- C'est ce qui rend l'appel sur et rejouable -- une seconde soumission ne retire jamais
-- "l'objet voisin" qui aurait glisse a la place du premier.
CREATE OR REPLACE FUNCTION public.inventaire_localiser(p_inv jsonb, p_index integer, p_signature jsonb)
RETURNS integer LANGUAGE sql IMMUTABLE
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
  SELECT coalesce((SELECT pos FROM correspond WHERE pos = p_index),
                  (SELECT min(pos) FROM correspond), -1);
$$;

-- inventaire_retirer() ne sait traiter que les objets empilables (par stackKey) ; les objets
-- uniques n'ont ni stackKey ni identifiant stable. Il faut donc pouvoir en retirer un
-- exemplaire par sa position -- etablie par le serveur, jamais annoncee par le client.
CREATE OR REPLACE FUNCTION public.inventaire_retirer_position(p_inv jsonb, p_pos integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
    FROM jsonb_array_elements(coalesce(p_inv, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
   WHERE (ord - 1) <> p_pos;
$$;

-- PRIMITIVE INTERNE COMMUNE. Aucun grant, aucun controle d'identite ici : elle suppose que
-- l'appelant a DEJA verifie l'acteur et pose le verrou -- meme doctrine que
-- helvetia_debiter_fonds_ordinaires, dont l'exposition accidentelle au navigateur a ete le
-- defaut trouve par le banc de parcours joueur de la passe precedente.
-- Ordre : quantite -> localisation -> protection -> retrait. N'ecrit RIEN : elle renvoie le
-- nouvel inventaire et l'objet sorti, a charge du guichet appelant de les ecrire dans la meme
-- transaction que sa contrepartie.
CREATE OR REPLACE FUNCTION public.helvetia_inventaire_sortie(
  p_inv jsonb, p_quete jsonb, p_index integer, p_signature jsonb, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE
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
    -- stock en supprimant la ligne devenue negative -- un retrait silencieusement partiel,
    -- que l'appelant croirait complet.
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

REVOKE ALL ON FUNCTION public.inventaire_objet_protege(jsonb, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_localiser(jsonb, integer, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.inventaire_retirer_position(jsonb, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.helvetia_inventaire_sortie(jsonb, jsonb, integer, jsonb, integer)
  FROM PUBLIC, anon, authenticated;
