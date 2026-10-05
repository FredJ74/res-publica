-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225714
-- Nom original      : militaire_presentation_affectation_et_desertions
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:57:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 359e18304d50c62b4f7f8bb1c74a4cad
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
-- =====================================================================================
-- PRESENTATION A L'AFFECTATION ET PASSE DE DESERTION : ECRITURES BASCULEES AU SERVEUR
-- (21 septembre 2026)
-- =====================================================================================
-- CE QUI ETAIT CASSE. Le civil requisitionne qui se presentait a la caserne payait 1 PA,
-- puis le NAVIGATEUR posait statut='affecte' dans compagnies_militaires. La policy
-- « compagnies maj par la chaine de commandement » n'autorise que le Commandant du pays ou
-- le Capitaine de la compagnie : l'ecriture du civil etait refusee, sbUpdate avalait l'erreur
-- et le toast annoncait « Affectation confirmée ». Le statut restait donc 'convoque' -- et la
-- passe quotidienne declarait DESERTEUR un joueur qui s'etait presente et avait paye.
--
-- DOCTRINE APPLIQUEE. Le candidat agit POUR LUI-MEME, mais il n'a aucune autorite sur le blob
-- de la compagnie : c'est donc le serveur qui ecrit, sous SECURITY DEFINER, apres avoir verifie
-- lui-meme la convocation, la presence physique a la caserne et le delai. Le navigateur ne
-- touche plus jamais compagnies_militaires pour cette action, et n'affiche un succes que si le
-- serveur l'a confirme. Un autre chantier va durcir l'ecriture de compagnies_militaires : ces
-- deux RPC continueront de fonctionner, elles ecrivent cote serveur.

CREATE OR REPLACE FUNCTION public.militaire_presentation_affectation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  v_moi text; v_pays text; v_bat text; v_pa integer;
  v_req jsonb; v_recherche jsonb; v_recherche2 jsonb;
  v_statut text; v_deserteur boolean; v_maintenant numeric; v_deadline numeric;
  v_cid text; v_sid text; v_data jsonb; v_sec jsonb; v_liste jsonb;
  v_inscrit boolean := false; v_numero text; v_paye jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.current_building, ''), coalesce(p.pa, 0),
         p.requisition, coalesce(p.recherche, '[]'::jsonb)
    INTO v_pays, v_bat, v_pa, v_req, v_recherche
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- La colonne est jsonb, mais le client y ecrivait un JSON.stringify : la valeur peut donc
  -- etre soit un objet, soit une CHAINE json contenant l'objet. Les deux sont acceptees.
  IF jsonb_typeof(v_req) = 'string' THEN
    BEGIN v_req := (v_req #>> '{}')::jsonb; EXCEPTION WHEN others THEN v_req := NULL; END;
  END IF;
  IF v_req IS NULL OR jsonb_typeof(v_req) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation');
  END IF;

  v_statut := coalesce(v_req->>'statut', '');
  v_deserteur := (v_statut = 'deserteur');
  IF v_statut NOT IN ('convoque', 'deserteur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_convocation', 'statut', v_statut);
  END IF;
  -- Presence reelle exigee, comme militaire_retrait et militaire_candidater_soldat.
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_maintenant := floor(extract(epoch FROM now()) * 1000);
  v_deadline := CASE WHEN (v_req->>'deadline') ~ '^[0-9]+(\.[0-9]+)?$'
                     THEN (v_req->>'deadline')::numeric ELSE NULL END;
  -- Un DESERTEUR se rend a tout moment, sans delai : c'est ce qui fait de la reddition une
  -- option de jeu. Un convoque, lui, reste tenu par son delai.
  IF NOT v_deserteur AND v_deadline IS NOT NULL AND v_deadline < v_maintenant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- 1. LE BLOB DE LA COMPAGNIE, ecrit par le serveur (le civil n'a aucune autorite dessus).
  v_cid := v_req->>'compagnieId';
  v_sid := v_req->>'sectionId';
  IF v_cid IS NOT NULL THEN
    SELECT c.data INTO v_data FROM public.compagnies_militaires c WHERE c.id = v_cid FOR UPDATE;
  END IF;
  IF v_data IS NOT NULL THEN
    SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
     WHERE s->>'id' = v_sid;
    IF v_sec IS NOT NULL THEN
      v_numero := v_sec->>'numero';
      SELECT coalesce(jsonb_agg(CASE WHEN e->>'nom' = v_moi
                                     THEN e || jsonb_build_object('statut', 'affecte') ELSE e END), '[]'::jsonb),
             coalesce(bool_or(e->>'nom' = v_moi), false)
        INTO v_liste, v_inscrit
        FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e;
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, v_sid,
                      v_sec || jsonb_build_object('civilsRequisitionnes', coalesce(v_liste, '[]'::jsonb)))
       WHERE id = v_cid;
    END IF;
  END IF;

  -- 2. LA FICHE DU JOUEUR. La presentation ETEINT les poursuites pour desertion -- et elles
  -- seules : on FILTRE le tableau `recherche`, on ne le remplace jamais (tout autre motif,
  -- crime, condamnation en attente, motif d'un autre empire, survit intact).
  v_req := v_req || jsonb_build_object('statut', 'affecte');
  v_recherche2 := v_recherche;
  IF v_deserteur THEN
    SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_recherche2
      FROM jsonb_array_elements(v_recherche) e
     WHERE NOT (coalesce(e->>'acte', '') = 'desertion'
                AND coalesce(e->>'country', v_pays) = v_pays);
  END IF;
  UPDATE public.personnages_donnees
     SET requisition = v_req, recherche = v_recherche2
   WHERE name = v_moi;

  -- 3. LE PAIEMENT, en dernier et sous le meme verrou : payer_ordre relit le cout dans le
  -- miroir declare. Un refus a ce stade annule TOUT (exception = rollback), jamais un effet
  -- accorde sans contrepartie.
  v_paye := public.payer_ordre(v_moi, 'se_presenter_affectation', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_presentation_affectation: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'deserteur', v_deserteur, 'section', v_numero,
    'compagnie', v_cid, 'inscrit', v_inscrit, 'requisition', v_req,
    'recherche', v_recherche2, 'pa', v_paye->'pa');
END;
$function$;

-- ---------------------------------------------------------------------------------------
-- PASSE QUOTIDIENNE DE DESERTION. Elle vivait entierement dans le navigateur : sbSaveCompagnie
-- (refuse par la policy) et sbUpdate sur la fiche des AUTRES joueurs (refuse par le trigger
-- personnages_vue_modifier). Le statut ne basculait donc jamais en base -- et la passe
-- recommencait chaque jour, pour chaque joueur connecte, en re-condamnant le meme absent.
-- Elle bascule ici : deterministe, idempotente, declenchable par n'importe quel joueur (elle
-- n'applique que des echeances deja depassees, aucun arbitrage). Elle RETOURNE les nouveaux
-- deserteurs, a charge pour le client d'emettre l'avis de recherche par la voie existante
-- (justice_condamner) et l'evenement public.
CREATE OR REPLACE FUNCTION public.militaire_desertions_verifier(p_pays text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pays text := coalesce(nullif(btrim(coalesce(p_pays, '')), ''), 'republic');
  v_maintenant numeric := floor(extract(epoch FROM now()) * 1000);
  c record; v_data jsonb; v_sec jsonb; v_liste jsonb;
  v_noms text[]; v_nouveaux jsonb := '[]'::jsonb;
BEGIN
  IF public.mon_personnage() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  FOR c IN SELECT id, data FROM public.compagnies_militaires
            WHERE data->>'pays' = v_pays FOR UPDATE LOOP
    v_data := c.data;
    FOR v_sec IN SELECT s FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s LOOP
      SELECT array_agg(e->>'nom') INTO v_noms
        FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e
       WHERE coalesce(e->>'statut', '') = 'convoque'
         AND (CASE WHEN (e->>'deadline') ~ '^[0-9]+(\.[0-9]+)?$'
                   THEN (e->>'deadline')::numeric ELSE NULL END) < v_maintenant;

      IF v_noms IS NOT NULL AND array_length(v_noms, 1) > 0 THEN
        SELECT coalesce(jsonb_agg(CASE WHEN e->>'nom' = ANY(v_noms)
                                       THEN e || jsonb_build_object('statut', 'deserteur') ELSE e END), '[]'::jsonb)
          INTO v_liste
          FROM jsonb_array_elements(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) e;
        v_data := public.militaire_sections_remplacer(v_data, v_sec->>'id',
                    v_sec || jsonb_build_object('civilsRequisitionnes', v_liste));

        UPDATE public.personnages_donnees p
           SET requisition = jsonb_build_object('compagnieId', c.id, 'sectionId', v_sec->>'id',
                                                'statut', 'deserteur')
         WHERE p.name = ANY(v_noms);

        SELECT v_nouveaux || coalesce(jsonb_agg(jsonb_build_object(
                 'nom', n, 'compagnieId', c.id, 'sectionId', v_sec->>'id',
                 'section', v_sec->>'numero')), '[]'::jsonb)
          INTO v_nouveaux FROM unnest(v_noms) n;
      END IF;
    END LOOP;
    IF v_data IS DISTINCT FROM c.data THEN
      UPDATE public.compagnies_militaires SET data = v_data WHERE id = c.id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'deserteurs', v_nouveaux);
END;
$function$;

-- Les DEFAULT PRIVILEGES du schema public reaccordent EXECUTE a anon : on referme.
REVOKE ALL ON FUNCTION public.militaire_presentation_affectation() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_desertions_verifier(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_presentation_affectation() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_desertions_verifier(text) TO authenticated, service_role;