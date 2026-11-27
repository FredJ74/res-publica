-- Mission du 27/11/2026 (soir, Claude), étape 6 — « Falsifier un document » : seuls les documents qui ont un effet en jeu.
-- Décision de Fred du 27/11/2026 : liste au choix du joueur, limitée aux documents qui ont un effet ; règles des faux
-- inchangées (imprimante : 3 PA + cartouche, 70 % ; greffe : 3 PA + 300, 45 % ; un faux réussi vaut un vrai pour un seul
-- usage). Relevé du code le 27/11/2026 :
--   • laissez-passer (archives d'écoute de Sovarka, QHS) : effet réel (crim_laissez_passer, faux = vrai) → gardé ;
--   • carton d'invitation de la Grande Salle du Pavillon (étape 5) : effet réel (pavillon_carton_remettre) → AJOUTÉ, le
--     faussaire choisit la date de la réception (et le nom inscrit, facultatif) ; l'objet est identique à un vrai carton ;
--   • permis de construire, compromis de vente : la banque (pret_national_creer_interne : « travaux », « consommation »)
--     n'exige aucun de ces documents → pas d'effet, NON ajoutés (question notée pour Fred) ;
--   • fausse identité, faux permis de construire, faux contrat commercial, fausse convocation : objets
--     « document_falsifie » qu'aucune fonction ne lit → retirés de la liste (refus « document_inconnu »).
--
-- Contrôles en lecture après application :
--   SELECT public.faux_document_objet_interne('faux_carton|2026-12-01|') ->> 'type';     -- carton_invitation
--   SELECT public.faux_document_objet_interne('fausse_identite') IS NULL;                 -- vrai
BEGIN;

CREATE OR REPLACE FUNCTION public.faux_carton_parametres_interne(p_doc text)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN split_part(p_doc, '|', 1) <> 'faux_carton' OR split_part(p_doc, '|', 2) !~ '^\d{4}-\d{2}-\d{2}$'
               OR length(split_part(p_doc, '|', 3)) > 60 THEN NULL
    ELSE jsonb_build_object('jour', split_part(p_doc, '|', 2), 'nom', nullif(btrim(split_part(p_doc, '|', 3)), '')) END
$$;
REVOKE ALL ON FUNCTION public.faux_carton_parametres_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.faux_document_objet_interne(p_doc text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c jsonb; d date;
BEGIN
  -- faux_documents_effectifs_v1 (Fred, 27/11/2026) : seuls les documents qui ont un effet en jeu.
  IF split_part(p_doc, '|', 1) = 'faux_laissez_passer' THEN
    RETURN CASE WHEN public.faux_lp_parametres_interne(p_doc) IS NOT NULL THEN jsonb_build_object(
      'name', 'Laissez-passer — ' || public.crim_lp_libelle_interne(public.faux_lp_parametres_interne(p_doc) ->> 'lieu'),
      'icon', 'ti-id-badge', 'desc', 'Laissez-passer') END;
  END IF;
  c := public.faux_carton_parametres_interne(p_doc);
  IF c IS NOT NULL THEN
    BEGIN d := (c ->> 'jour')::date; EXCEPTION WHEN others THEN RETURN NULL; END;
    RETURN public.pavillon_carton_objet_interne(d, c ->> 'nom', NULL);
  END IF;
  RETURN NULL; /* crim_faux_lp_v2 */
END $function$;

CREATE OR REPLACE FUNCTION public.faux_document_final_interne(p_doc_objet jsonb, p_doc text, p_auteur text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.faux_lp_parametres_interne(p_doc) IS NOT NULL THEN
      public.crim_lp_emettre_interne(public.faux_lp_parametres_interne(p_doc) ->> 'lieu', public.faux_lp_parametres_interne(p_doc) ->> 'pays',
        coalesce(public.faux_lp_parametres_interne(p_doc) ->> 'nom', p_auteur), p_auteur, true)
    -- Faux carton d'invitation : identique à un vrai (même type, même forme), seul l'identifiant interne diffère.
    WHEN public.faux_carton_parametres_interne(p_doc) IS NOT NULL THEN
      jsonb_set(p_doc_objet, '{carton,id}', to_jsonb('faux-' || replace(gen_random_uuid()::text, '-', '')))
    ELSE p_doc_objet || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
           'type', 'document_falsifie', 'docId', p_doc, 'legal', false) END;
$function$;

COMMIT;
