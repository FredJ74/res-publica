-- =====================================================================================
-- LOT DU 21 SEPTEMBRE 2026 : ORDRES MILITAIRES REPARES
-- =====================================================================================
-- OBJET DU LOT. Quatre ordres militaires etaient annonces au joueur mais restaient sans
-- effet. Ce lot les remet en etat :
--   * les couts d'inspection des troupes et de mobilisation nationale sont remis au miroir
--     public.ordres_couts (payer_ordre exige le triplet EXACT, sinon l'ordre est refuse) ;
--   * l'ordre abandonne recruter_section est supprime du miroir ;
--   * la presentation a l'affectation et la passe quotidienne de desertion passent cote
--     serveur (le navigateur n'avait aucune autorite pour ecrire ces lignes) ;
--   * la requisition civile passe cote serveur (poste min_def atteste, tirage au sort,
--     convocation des 24 fiches, paiement au miroir) ;
--   * la dotation en armement preleve REELLEMENT le 1 PA qu'elle affiche.
--
-- MIGRATIONS ABSORBEES, dans l'ordre chronologique de leur version :
--   20260920225514  ordres_couts_inspection_mobilisation_recrutement
--   20260920225714  militaire_presentation_affectation_et_desertions
--   20260920225742  militaire_requisition_civile_serveur
--   20260920225809  militaire_armurerie_transfert_cout_pa
--
-- AVERTISSEMENT. Ce fichier est un VERSIONNEMENT a posteriori : les quatre migrations
-- ci-dessus ont deja ete appliquees en production le 21 septembre 2026. Le fichier
-- reproduit l'enchainement REELLEMENT applique, chaque bloc recopie caractere pour
-- caractere depuis supabase_migrations.schema_migrations. Ne pas le reordonner, ne pas
-- le corriger : il doit rester le reflet fidele de ce qui tourne.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- MIGRATION 20260920225514  ordres_couts_inspection_mobilisation_recrutement
-- -------------------------------------------------------------------------------------
-- MIROIR DES COUTS : trois ordres militaires remis en coherence (21 septembre 2026).
--
-- public.ordres_couts est le miroir declare des couts d'ordre : payer_ordre exige le triplet
-- EXACT (fn, pa, cost), sinon 'cout_non_declare'. Trois ordres militaires etaient donc morts.
--
-- 1. inspecter_troupes : declare (0,0) dans data.js, mais facture REELLEMENT 1 PA (revue) ou
--    2 PA (detaillee) -- les deux niveaux etaient refuses. data.js declare desormais le cout
--    d'entree (1 PA) et NIVEAUX_INSPECTION_TROUPES (plateau-politique.js) le second niveau.
-- 2. mobilisation_nationale : facade gratuite (0,0) conservee -- ouvrir le tableau ne coute
--    rien -- mais ses TROIS sous-actions facturent sous ce meme fn : mobiliser 4 PA,
--    requisition civile 3 PA, demobiliser 2 PA. Aucune des trois n'etait executable.
-- 3. recruter_section : ordre supprime (modele de recompletement a la piece abandonne par le
--    GD le 17 septembre 2026). Plus aucun appelant : declaration, route et handler retires.
--
-- Les cinq couples ajoutes et les deux retires sont EXACTEMENT le delta calcule par
-- .scratch/generer_ordres_couts.py entre le depot avant et apres ce lot : aucun chiffre saisi
-- a la main. Aucune autre ligne du miroir n'est touchee.
DELETE FROM public.ordres_couts WHERE fn = 'inspecter_troupes' AND pa = 0 AND cost = 0;
DELETE FROM public.ordres_couts WHERE fn = 'recruter_section'  AND pa = 2 AND cost = 0;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('inspecter_troupes', 1, 0),
  ('inspecter_troupes', 2, 0),
  ('mobilisation_nationale', 4, 0),
  ('mobilisation_nationale', 3, 0),
  ('mobilisation_nationale', 2, 0)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- Les ecarts deja enregistres pour ces trois ordres portaient precisement sur ces couples :
-- une fois declares, la trace de diagnostic n'a plus de sens.
DELETE FROM public.ordres_couts_ecarts e
 WHERE EXISTS (SELECT 1 FROM public.ordres_couts o
                WHERE o.fn = e.fn AND o.pa = e.pa AND o.cost = e.cost);

-- -------------------------------------------------------------------------------------
-- MIGRATION 20260920225714  militaire_presentation_affectation_et_desertions
-- -------------------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------------------
-- MIGRATION 20260920225742  militaire_requisition_civile_serveur
-- -------------------------------------------------------------------------------------
-- =====================================================================================
-- REQUISITION CIVILE : LA DECISION DU MINISTRE PRODUIT ENFIN UN EFFET (21 septembre 2026)
-- =====================================================================================
-- CE QUI ETAIT CASSE. confirmerRequisitionCivile ecrivait section.civilsRequisitionnes par
-- sbSaveCompagnie (refuse par la policy de compagnies_militaires : ni Commandant ni Capitaine),
-- puis bouclait 24 sbUpdate sur la fiche des AUTRES joueurs (refuses par le trigger
-- personnages_vue_modifier, motif personnage_non_possede), le tout avale par un .catch(() => {}).
-- Seuls les 24 mails partaient : les convoques n'etaient convoques nulle part, aucun delai
-- n'existait, et « Se presenter a mon affectation » ne trouvait donc jamais de convocation.
--
-- DOCTRINE APPLIQUEE. On n'ecrit JAMAIS sur la fiche d'un autre joueur depuis le navigateur :
-- une RPC SECURITY DEFINER verifie le poste min_def ATTESTE (exiger_poste, qui lit le poste
-- reel en base, pas celui que le client pretend), verifie la mobilisation nationale, tire au
-- sort les civils, ecrit le blob de la compagnie ET les 24 fiches, et paie les 3 PA au miroir.
-- Le client ne garde que ce qu'il est legitime a faire : envoyer les mails de convocation.
--
-- Bareme et perimetre inchanges : 24 civils, 48 h de delai, memes postes exclus du tirage
-- (officiers, ministres, maire), une seule requisition par section.
CREATE OR REPLACE FUNCTION public.militaire_requisition_civile(p_compagnie_id text, p_section_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa       constant integer := 3;
  c_heures   constant integer := 48;
  c_effectif constant integer := 24;
  v_moi text; v_pays text; v_pa integer; v_mobilisee boolean;
  v_data jsonb; v_sec jsonb; v_liste jsonb; v_noms text[];
  v_deadline numeric; v_paye jsonb;
BEGIN
  -- Poste ATTESTE : exiger_poste leve 42501 si l'appelant n'est pas reellement min_def.
  v_moi := public.exiger_poste('min_def');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT coalesce((b.data->>'mobilisationNationaleActive')::boolean, false) INTO v_mobilisee
    FROM public.budgets_nationaux b WHERE b.id = v_pays;
  IF NOT coalesce(v_mobilisee, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mobilisation_inactive');
  END IF;

  SELECT c.data INTO v_data FROM public.compagnies_militaires c
   WHERE c.id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable');
  END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable');
  END IF;
  IF coalesce(v_sec->>'lieutenantNom', '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant');
  END IF;
  IF jsonb_array_length(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_requisitionnee');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- TIRAGE AU SORT, cote serveur : le client ne choisit plus qui est requisitionne. Memes
  -- exclusions que la liste d'origine (officiers, ministres, maire) + le ministre lui-meme.
  SELECT array_agg(q.name) INTO v_noms FROM (
    SELECT p.name FROM public.personnages_donnees p
     WHERE coalesce(p.domicile->>'country', p.country, 'republic') = v_pays
       AND coalesce(p.poste->>'id', '') NOT IN ('lieutenant','capitaine','commandant','min_def',
             'president','pm','min_int','min_fin','min_just','min_info','min_ae','maire')
       AND p.name <> v_moi
     ORDER BY random() LIMIT c_effectif) q;
  IF v_noms IS NULL OR array_length(v_noms, 1) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_civil_eligible');
  END IF;

  v_deadline := floor(extract(epoch FROM now()) * 1000) + c_heures * 3600000;
  SELECT jsonb_agg(jsonb_build_object('nom', n, 'statut', 'convoque', 'deadline', v_deadline))
    INTO v_liste FROM unnest(v_noms) n;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('civilsRequisitionnes', v_liste))
   WHERE id = p_compagnie_id;

  UPDATE public.personnages_donnees p
     SET requisition = jsonb_build_object('compagnieId', p_compagnie_id, 'sectionId', p_section_id,
                                          'deadline', v_deadline, 'statut', 'convoque')
   WHERE p.name = ANY(v_noms);

  v_paye := public.payer_ordre(v_moi, 'mobilisation_nationale', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_requisition_civile: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'convoques', to_jsonb(v_noms),
    'nombre', array_length(v_noms, 1), 'deadline', v_deadline, 'delai_heures', c_heures,
    'section', v_sec->>'numero', 'lieutenant', v_sec->>'lieutenantNom', 'pa', v_paye->'pa');
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_requisition_civile(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_requisition_civile(text, text) TO authenticated, service_role;

-- -------------------------------------------------------------------------------------
-- MIGRATION 20260920225809  militaire_armurerie_transfert_cout_pa
-- -------------------------------------------------------------------------------------
-- =====================================================================================
-- « Doter ma section en armement » : 1 PA AFFICHE, 1 PA REELLEMENT PRELEVE (21 sept. 2026)
-- =====================================================================================
-- data.js declare repartir_armement a 1 PA et le miroir porte deja le couple
-- ('repartir_armement',1,0) -- mais ni ouvrirRepartirArmement ni confirmerTransfertArmement
-- n'appelaient deduireCoutOrdre : le triplet n'etait JAMAIS consulte et l'ordre etait gratuit.
-- Le prelevement est pose ICI plutot que dans le navigateur : le transfert est deja une
-- transaction serveur atomique (stock national + stock de section), le cout en fait partie et
-- ne depend donc plus du client. UN mouvement = UN PA, dans les deux sens : sortir des armes du
-- magasin comme les y rendre est un acte de commandement, et le client ne peut plus obtenir
-- l'effet sans la contrepartie.
--
-- Le corps d'origine est conserve a l'identique (autorite : le Lieutenant de CETTE section,
-- memes produits, memes quantites, meme primitive caserne_stock_mouvement). Deux ajouts :
-- une verification prealable des PA (pour rendre un refus lisible plutot qu'une exception)
-- et l'appel a payer_ordre a la fin, sous la meme transaction -- un paiement refuse annule
-- l'ensemble du transfert.
CREATE OR REPLACE FUNCTION public.militaire_armurerie_transfert(p_compagnie_id text, p_section_id text, p_produit text, p_qte integer, p_sens text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa constant integer := 1;
  g record; v_pays text; v_sec jsonb; v_stock jsonb; v_dispo int; v_mvt jsonb;
  v_pa int; v_paye jsonb;
BEGIN
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;
  IF COALESCE(p_qte, 0) <= 0 OR p_qte > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_sens NOT IN ('vers_section', 'vers_armurerie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;

  -- AUTORITE : le lieutenant de CETTE section. Refuse le capitaine, le commandant et tout autre.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT country, COALESCE(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  -- COUT DE L'ORDRE, verifie AVANT tout mouvement de stock : un refus doit etre lisible.
  IF COALESCE(v_pa, 0) < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'pa_reel', COALESCE(v_pa, 0));
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;

  IF p_sens = 'vers_section' THEN
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, -p_qte, NULL);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
    v_stock := v_stock || jsonb_build_object(p_produit,
                 GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0)) + p_qte);
  ELSE
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_produit)::int, 0));
    IF v_dispo < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'disponible', v_dispo);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_produit, v_dispo - p_qte);
    v_mvt := public.caserne_stock_mouvement(v_pays, p_produit, p_qte, 'retour-' || p_section_id);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;

  -- PAIEMENT ATTESTE (miroir ordres_couts). En cas de refus, l'exception annule aussi le
  -- mouvement de stock : jamais d'armes transferees sans PA preleves.
  v_paye := public.payer_ordre(g.o_moi, 'repartir_armement', c_pa, 0);
  IF NOT COALESCE((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_armurerie_transfert: paiement refuse (%)',
      COALESCE(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'produit', p_produit, 'quantite', p_qte,
    'stock_armurerie', v_mvt->'stock', 'stock_section', v_stock->p_produit,
    'pa', v_paye->'pa', 'pa_preleves', c_pa);
END; $function$;

REVOKE ALL ON FUNCTION public.militaire_armurerie_transfert(text, text, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_armurerie_transfert(text, text, text, integer, text) TO authenticated, service_role;
