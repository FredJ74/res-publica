-- Nominations municipales : transfert au maire, sans autre pouvoir municipal modifie.
-- EN ATTENTE D'APPLICATION. Ne pas mettre le baseline en avance sur la base.
-- Dependances : poste_autorite_de, batiment_etat_lire, jsonb_cles_hors_liste,
-- batiment_etat_sous_cle_ecrire et les tables existantes de nomination/couts.
-- A appliquer via le registre Supabase, puis reextraire le baseline (WORKFLOW-SUPABASE.md).
-- Aucun titulaire, candidature ou delai existant n'est reecrit par cette migration.

BEGIN;

UPDATE public.postes_nommes_regles
   SET nomme_par = 'maire'
 WHERE poste_id = 'directeur_entrepot' AND nomme_par IN ('maire_adjoint', 'maire');

-- Tarifs des actions existantes, declares dans ACTIONS_POSTE_NOMME et extraits
-- par generer_ordres_couts.py. Le menu gratuit n'est jamais facture a leur place.
-- Ajout cible, sans regenerer les autres tarifs ou leurs sentinelles perimees.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('gerer_candidature_directeur_entrepot', 1, 0),
  ('gerer_candidature_maire_adjoint', 1, 0),
  ('nommer_commissaire', 3, 0),
  ('nommer_directeur_entrepot', 3, 0),
  ('revoquer_commissaire', 1, 0),
  ('revoquer_directeur_entrepot', 1, 0),
  ('revoquer_maire_adjoint', 1, 0)
ON CONFLICT DO NOTHING;

-- Le blob national est partage entre les dossiers et les candidats.
-- Pour l'entrepot, un non-maire ne peut qu'AJOUTER SA candidature : pas modifier
-- le nominateur, l'echeance, les autres candidats ou le drapeau de traitement.
-- Les autres dossiers et les candidatures a d'autres postes restent inchanges.
CREATE OR REPLACE FUNCTION public.candidature_entrepot_modification_autorisee(
  p_pays text, p_ancien jsonb, p_nouveau jsonb
) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public, pg_temp
AS $fonction$
DECLARE
  v_cle text; v_ancien jsonb; v_nouveau jsonb; v_ville text;
  v_nom text; v_pays text; v_maire text; v_ajout jsonb; v_liste jsonb;
  v_maintenant numeric := extract(epoch FROM now()) * 1000;
BEGIN
  FOR v_cle IN
    SELECT key FROM jsonb_each(coalesce(p_ancien, '{}'::jsonb))
    UNION SELECT key FROM jsonb_each(coalesce(p_nouveau, '{}'::jsonb))
  LOOP
    v_ancien := p_ancien -> v_cle;
    v_nouveau := p_nouveau -> v_cle;
    IF v_ancien IS NOT DISTINCT FROM v_nouveau THEN CONTINUE; END IF;
    IF split_part(v_cle, '|', 1) <> 'directeur_entrepot'
       AND coalesce(v_ancien ->> 'posteId', '') <> 'directeur_entrepot'
       AND coalesce(v_nouveau ->> 'posteId', '') <> 'directeur_entrepot' THEN
      CONTINUE;
    END IF;

    v_ville := split_part(v_cle, '|', 2);
    IF v_ville = '' OR v_ville = 'national'
       OR v_cle <> 'directeur_entrepot|' || v_ville THEN RETURN false; END IF;
    IF EXISTS (SELECT 1 FROM public.poste_autorite_de('directeur_entrepot', v_ville) a
                WHERE a.pays = p_pays) THEN CONTINUE; END IF;

    SELECT d.name, d.country INTO v_nom, v_pays
      FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
    IF v_nom IS NULL OR v_pays IS DISTINCT FROM p_pays THEN RETURN false; END IF;
    IF jsonb_typeof(v_nouveau) IS DISTINCT FROM 'object'
       OR v_nouveau ->> 'posteId' IS DISTINCT FROM 'directeur_entrepot'
       OR v_nouveau ->> 'city' IS DISTINCT FROM v_ville
       OR jsonb_typeof(v_nouveau -> 'candidats') IS DISTINCT FROM 'array' THEN
      RETURN false;
    END IF;

    IF v_ancien IS NULL OR v_ancien -> 'traitee' = 'true'::jsonb THEN
      -- Nouveau dossier : meme fenetre de 48h et meme maire PJ que le client.
      SELECT d.name INTO v_maire FROM public.personnages_donnees d
       WHERE d.country = p_pays AND d.poste ->> 'id' = 'maire'
         AND d.poste ->> 'city' = v_ville LIMIT 1;
      IF v_maire IS NULL
         OR public.jsonb_cles_hors_liste(v_nouveau,
              ARRAY['posteId','city','candidats','echeanceTs','autoriteNom','traitee']) IS NOT NULL
         OR v_nouveau -> 'traitee' IS DISTINCT FROM 'false'::jsonb
         OR v_nouveau ->> 'autoriteNom' IS DISTINCT FROM v_maire
         OR jsonb_typeof(v_nouveau -> 'echeanceTs') IS DISTINCT FROM 'number' THEN
        RETURN false;
      END IF;
      IF abs((v_nouveau ->> 'echeanceTs')::numeric - v_maintenant - 172800000) > 60000 THEN
        RETURN false;
      END IF;
      v_liste := '[]'::jsonb;
    ELSE
      IF (v_nouveau - 'candidats') IS DISTINCT FROM (v_ancien - 'candidats') THEN RETURN false; END IF;
      v_liste := coalesce(v_ancien -> 'candidats', '[]'::jsonb);
      IF jsonb_typeof(v_liste) IS DISTINCT FROM 'array' THEN RETURN false; END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_liste) c
                WHERE c ->> 'nom' = v_nom AND coalesce(c ->> 'retiree', 'false') <> 'true') THEN
      RETURN false;
    END IF;
    v_ajout := v_nouveau -> 'candidats' -> -1;
    IF jsonb_typeof(v_ajout) IS DISTINCT FROM 'object'
       OR v_ajout ->> 'nom' IS DISTINCT FROM v_nom
       OR public.jsonb_cles_hors_liste(v_ajout, ARRAY['nom','depuisTs']) IS NOT NULL
       OR jsonb_typeof(v_ajout -> 'depuisTs') IS DISTINCT FROM 'number'
       OR (v_nouveau -> 'candidats') IS DISTINCT FROM (v_liste || jsonb_build_array(v_ajout)) THEN
      RETURN false;
    END IF;
    IF abs((v_ajout ->> 'depuisTs')::numeric - v_maintenant) > 60000 THEN RETURN false; END IF;
  END LOOP;
  RETURN true;
END;
$fonction$;
REVOKE ALL ON FUNCTION public.candidature_entrepot_modification_autorisee(text,jsonb,jsonb) FROM PUBLIC, anon, authenticated;

-- Patch de la porte existante, sans recopier son corps ni ses autres permissions.
DO $patch$
DECLARE
  v_definition text;
  v_ancre text := '  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;';
  v_garde text := $garde$
  -- nominations_municipales_entrepot : garde apres verrou, avant toute ecriture.
  IF NOT v_serveur AND p_sous_cle = 'candidatures'
     AND NOT public.candidature_entrepot_modification_autorisee(p_pays,
       coalesce(public.batiment_etat_lire(v_data) -> 'candidatures', '{}'::jsonb), p_valeur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
$garde$;
BEGIN
  SELECT pg_get_functiondef('public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)'::regprocedure)
    INTO v_definition;
  IF strpos(v_definition, '-- nominations_municipales_entrepot :') = 0 THEN
    IF (length(v_definition) - length(replace(v_definition, v_ancre, ''))) <> length(v_ancre) THEN
      RAISE EXCEPTION 'nominations municipales : ancre absente ou ambigue, relire la porte';
    END IF;
    EXECUTE replace(v_definition, v_ancre, v_ancre || E'\n' || v_garde);
  END IF;
END;
$patch$;

-- Preuves structurelles uniquement : aucune nomination ou revocation n'est jouee ici.
DO $verification$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles
                  WHERE poste_id = 'directeur_entrepot' AND nomme_par = 'maire'
                    AND scope = 'ville' AND coalesce(autorite_scope, scope) = 'ville') THEN
    RAISE EXCEPTION 'nominations municipales : miroir de nomination non transfere';
  END IF;
  IF has_function_privilege('anon', 'public.candidature_entrepot_modification_autorisee(text,jsonb,jsonb)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.candidature_entrepot_modification_autorisee(text,jsonb,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'nominations municipales : helper interne ouvert aux clients';
  END IF;
  IF strpos(pg_get_functiondef('public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)'::regprocedure),
            '-- nominations_municipales_entrepot :') = 0 THEN
    RAISE EXCEPTION 'nominations municipales : garde du blob non installee';
  END IF;
END;
$verification$;

COMMIT;
