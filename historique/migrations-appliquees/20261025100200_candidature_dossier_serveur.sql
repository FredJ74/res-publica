-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025204601.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025204601.
-- Eprouvee apres application en transaction annulee (recruteur, doublon sans cout, mail, solde). Baseline NON reextrait.
-- ============================================================================
-- CANDIDATURE AUPRES D'UN RECRUTEUR JOUEUR : LE DOSSIER EST TENU PAR LE SERVEUR (25/10/2026)
-- ============================================================================
-- Circuit du 25 aout 2026, conserve en entier par Fred : le recruteur joueur a 48 heures pour
-- choisir, sinon tirage au sort et popularite divisee par deux (passe de nuit, deja serveur :
-- candidature_poste_tirage_appliquer). Seul le DOSSIER (qui est candidat, l'echeance, le
-- recruteur) etait encore ecrit par le navigateur dans batiments_etat. Desormais :
--   - poste_candidature_transmettre ecrit le dossier sous verrou, resout lui-meme le recruteur
--     joueur, refuse un doublon AVANT de prelever, preleve 1 PA, et envoie le mail au recruteur
--     (meme texte et meme bouton « Accepter la candidature » qu'avant) ;
--   - poste_attribuer_interne, porte unique de toute nomination, solde le dossier du poste
--     (traitee = true) : plus aucune ecriture du navigateur.
-- Meme forme de dossier qu'avant (lue par la passe de nuit et par la fenetre du recruteur) :
-- { candidatures: { "<poste>|<ville ou national>": { posteId, city, candidats:[{nom, depuisTs}],
--   echeanceTs, autoriteNom, traitee } } }.  Idempotente. Aucun acte de joueur.
-- ============================================================================

-- Le recruteur JOUEUR d'un poste, ou NULL (recruteur PNJ ou vacant).
CREATE OR REPLACE FUNCTION public.poste_recruteur_joueur(p_pays text, p_poste text, p_city text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_regle record; v_nom text; v_ville_autorite text;
BEGIN
  SELECT * INTO v_regle FROM public.postes_nommes_regles WHERE poste_id = p_poste;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_ville_autorite := CASE WHEN coalesce(v_regle.autorite_scope, v_regle.scope) = 'ville' THEN p_city END;
  SELECT a.titulaire INTO v_nom FROM public.postes_attribues a
   WHERE a.country = p_pays AND a.poste_id = v_regle.nomme_par
     AND (v_ville_autorite IS NULL OR a.city IS NOT DISTINCT FROM v_ville_autorite)
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire)
   LIMIT 1;
  IF v_nom IS NOT NULL THEN RETURN v_nom; END IF;
  SELECT c.data::jsonb ->> 'eluId' INTO v_nom FROM public.cycles_electoraux c
   WHERE c.country = p_pays AND c.poste_id = v_regle.nomme_par
     AND (v_ville_autorite IS NULL OR c.city IS NOT DISTINCT FROM v_ville_autorite)
     AND left(btrim(c.data), 1) = '{'
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = c.data::jsonb ->> 'eluId')
   LIMIT 1;
  RETURN v_nom;
END; $function$;
REVOKE ALL ON FUNCTION public.poste_recruteur_joueur(text, text, text) FROM PUBLIC, anon, authenticated;

-- Le dossier : ajout d'un candidat, sous verrou. Rend 'ajoute' ou 'deja_candidat'.
CREATE OR REPLACE FUNCTION public.poste_candidature_dossier_ajouter_interne(p_pays text, p_poste text, p_city text,
                                                                         p_candidat text, p_autorite text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_national_candidatures_postes'; v_etat jsonb; v_cands jsonb; v_cle text;
        v_dossier jsonb; v_maintenant bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
BEGIN
  INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
  VALUES (v_id, p_pays, 'national', 'candidatures_postes', to_jsonb('{"candidatures":{}}'::text), now())
  ON CONFLICT (id) DO NOTHING;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_cands := CASE WHEN jsonb_typeof(v_etat -> 'candidatures') = 'object' THEN v_etat -> 'candidatures' ELSE '{}'::jsonb END;
  v_cle := p_poste || '|' || coalesce(p_city, 'national');
  v_dossier := v_cands -> v_cle;
  IF v_dossier IS NULL OR coalesce((v_dossier ->> 'traitee')::boolean, false) THEN
    v_dossier := jsonb_build_object('posteId', p_poste, 'city', p_city,
      'candidats', jsonb_build_array(jsonb_build_object('nom', p_candidat, 'depuisTs', v_maintenant)),
      'echeanceTs', v_maintenant + 48 * 3600 * 1000, 'autoriteNom', p_autorite, 'traitee', false);
  ELSIF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_dossier -> 'candidats', '[]'::jsonb)) c
                 WHERE c ->> 'nom' = p_candidat AND NOT coalesce((c ->> 'retiree')::boolean, false)) THEN
    RETURN 'deja_candidat';
  ELSE
    v_dossier := jsonb_set(v_dossier, '{candidats}', coalesce(v_dossier -> 'candidats', '[]'::jsonb)
                   || jsonb_build_array(jsonb_build_object('nom', p_candidat, 'depuisTs', v_maintenant)));
    -- Le recruteur a change depuis l'ouverture du dossier : il recoit une fenetre complete.
    IF v_dossier ->> 'autoriteNom' IS DISTINCT FROM p_autorite THEN
      v_dossier := v_dossier || jsonb_build_object('autoriteNom', p_autorite, 'echeanceTs', v_maintenant + 48 * 3600 * 1000);
    END IF;
  END IF;
  v_etat := coalesce(v_etat, '{}'::jsonb) || jsonb_build_object('candidatures', v_cands || jsonb_build_object(v_cle, v_dossier));
  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now() WHERE id = v_id;
  RETURN 'ajoute';
END; $function$;
REVOKE ALL ON FUNCTION public.poste_candidature_dossier_ajouter_interne(text, text, text, text, text) FROM PUBLIC, anon, authenticated;

-- Le dossier d'un poste pourvu est solde.
CREATE OR REPLACE FUNCTION public.poste_candidature_dossier_solder_interne(p_pays text, p_poste text, p_city text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_national_candidatures_postes'; v_etat jsonb; v_cle text := p_poste || '|' || coalesce(p_city, 'national');
BEGIN
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL OR jsonb_typeof(v_etat #> ARRAY['candidatures', v_cle]) IS DISTINCT FROM 'object'
     OR coalesce((v_etat #>> ARRAY['candidatures', v_cle, 'traitee'])::boolean, false) THEN RETURN; END IF;
  v_etat := jsonb_set(v_etat, ARRAY['candidatures', v_cle, 'traitee'], 'true'::jsonb);
  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now() WHERE id = v_id;
END; $function$;
REVOKE ALL ON FUNCTION public.poste_candidature_dossier_solder_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- La candidature aupres d'un recruteur joueur, de bout en bout.
CREATE OR REPLACE FUNCTION public.poste_candidature_transmettre(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_regle record; v_paie jsonb; v_autorite text; v_city text; v_res text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_nom;
  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu'); END IF;
  v_city := CASE WHEN v_regle.scope = 'ville' THEN p_city END;
  IF EXISTS (SELECT 1 FROM public.postes_attribues a
              WHERE a.id = v_pays || '_' || p_poste || '_' || coalesce(v_city, 'national')
                AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_occupe_par_un_joueur');
  END IF;
  v_autorite := public.poste_recruteur_joueur(v_pays, p_poste, v_city);
  IF v_autorite IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'recruteur_pnj'); END IF;
  IF v_autorite = v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'recruteur_soi_meme'); END IF;
  -- Le doublon est refuse AVANT le prelevement : un refus ne coute rien.
  IF EXISTS (SELECT 1 FROM public.batiments_etat b,
                    jsonb_array_elements(coalesce(public.batiment_etat_lire(b.data)
                       #> ARRAY['candidatures', p_poste || '|' || coalesce(v_city, 'national'), 'candidats'], '[]'::jsonb)) c
              WHERE b.id = v_pays || '_national_candidatures_postes'
                AND NOT coalesce((public.batiment_etat_lire(b.data)
                       #>> ARRAY['candidatures', p_poste || '|' || coalesce(v_city, 'national'), 'traitee'])::boolean, false)
                AND c ->> 'nom' = v_nom AND NOT coalesce((c ->> 'retiree')::boolean, false)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;
  v_paie := public.payer_ordre(v_nom, 'postuler', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_res := public.poste_candidature_dossier_ajouter_interne(v_pays, p_poste, v_city, v_nom, v_autorite);
  PERFORM public.mail_systeme_poser_interne(v_nom, v_autorite, 'Candidature au poste de ' || v_regle.label,
    v_nom || ' postule au poste de <strong>' || v_regle.label || '</strong>. Vous disposez de 48h pour choisir un candidat depuis la fenêtre de gestion des candidatures, sans quoi le système tranchera automatiquement.<br><br>'
    || '[[act:candidature|' || p_poste || '|' || replace(replace(replace(v_regle.label, '|', ''), '[', ''), ']', '')
    || '|' || replace(replace(replace(v_nom, '|', ''), '[', ''), ']', '') || ']]');
  RETURN jsonb_build_object('ok', true, 'pa', v_paie -> 'pa', 'recruteur', v_autorite, 'dossier', v_res);
END; $function$;
REVOKE ALL ON FUNCTION public.poste_candidature_transmettre(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_candidature_transmettre(text, text) TO authenticated;

-- Toute nomination solde le dossier du poste.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  DELETE FROM public.titulaires_pnj\n   WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;\n';
  v_ajout text := E'  -- Le dossier de candidature du poste est solde (25/10/2026) : le poste est pourvu.\n  PERFORM public.poste_candidature_dossier_solder_interne(p_pays, p_poste, p_city);\n';
BEGIN
  v_def := pg_get_functiondef('public.poste_attribuer_interne(text,text,text,text,text)'::regprocedure);
  IF position('poste_candidature_dossier_solder_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_frag || v_ajout);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment de poste_attribuer_interne introuvable'; END IF;
  EXECUTE v_new;
END $mig$;
