-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030162931.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- FICHE PJ : UNE COPIE ANCIENNE DU NAVIGATEUR N'ÉCRASE PLUS UNE VALEUR PLUS RÉCENTE DU SERVEUR
-- (30/10/2026, Claude, clôture Luthécia). NON APPLIQUÉE. Application par ChatGPT après prévol,
-- AVANT le déploiement du client qui envoie `fiche_base` (sinon le PATCH refuse la colonne).
-- Compatible avec l'écran en ligne : sans `fiche_base`, comportement inchangé.
--
-- Défaut : la sauvegarde générique renvoie la fiche entière. L'inventaire, les francs, la banque,
-- les caractéristiques, le poste, le jour, les convocations et le casier sont déjà tenus par le
-- serveur ; mais PA (baisse acceptée), santé, moral, position, prison, hospitalisation, poison,
-- caractéristiques affaiblies, réquisition, domicile, employés, escorte, locations, dernier
-- sommeil, réservation d'hôtel et excommunication étaient pris tels quels. Un onglet qui n'a pas
-- vu un changement du serveur (recharge nocturne des PA, arrestation, hospitalisation, bail
-- résilié, autre session…) le défaisait à sa prochaine sauvegarde.
--
-- Remède : fusion à trois voies. Le navigateur joint à sa sauvegarde `fiche_base`, la valeur de
-- chacun de ces champs telle qu'il l'a reçue du serveur. Pour chaque champ :
--   - le navigateur ne l'a pas changé (nouvelle = base)   → la valeur du serveur est conservée ;
--   - le serveur ne l'a pas changé (serveur = base)        → le changement du navigateur passe ;
--   - les deux l'ont changé                                  → le serveur l'emporte, PA et santé
--     compris. (Une règle « serveur + variation de l'écran » a été écartée : l'écran recopie les PA
--     renvoyés par plus de cinquante actions serveur sans avancer sa base, la dépense serait
--     comptée deux fois. Pire cas retenu : une dépense locale non enregistrée, jamais une perte de
--     ce que le serveur a écrit.)
--   - champ absent de `fiche_base`                          → la valeur du serveur est conservée.
-- Les gardes existantes s'appliquent ensuite (PA jamais au-dessus du serveur, hausses de santé
-- journalisées, etc.). La ligne renvoyée porte le résultat réel : le navigateur s'y recale.
-- `fiche_base` n'est jamais stockée : c'est une colonne de saisie de la vue (NULL en lecture).
-- =====================================================================================

-- 1. Comparaison tolérante aux représentations : null, {}, [] et '' valent « vide ».
CREATE OR REPLACE FUNCTION public.fiche_valeur_normalisee(v jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN v IS NULL OR v = 'null'::jsonb OR v = '{}'::jsonb OR v = '[]'::jsonb OR v = '""'::jsonb THEN NULL ELSE v END;
$function$;

-- 2. Fusion d'une sauvegarde de l'écran avec la fiche canonique.
CREATE OR REPLACE FUNCTION public.fiche_fusionner_ecran(p_nouvelle jsonb, p_base jsonb, p_canon jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  champs constant text[] := ARRAY['pa','hp','moral','current_city','current_building','current_room',
    'est_emprisonne','hospitalisation','poison_actif','stats_affaiblies','regen_jour','requisition',
    'domicile','employes','escort_active','locations_actives','dernier_dormir','reservation_hotel','excommunie'];
  f text; n jsonb; b jsonb; c jsonb; r jsonb := '{}'::jsonb;
BEGIN
  FOREACH f IN ARRAY champs LOOP
    c := p_canon -> f;
    IF NOT (p_base ? f) OR NOT (p_nouvelle ? f) THEN
      r := r || jsonb_build_object(f, c);                     -- inconnu : le serveur fait foi
      CONTINUE;
    END IF;
    n := p_nouvelle -> f; b := p_base -> f;
    IF public.fiche_valeur_normalisee(n) IS NOT DISTINCT FROM public.fiche_valeur_normalisee(b) THEN
      r := r || jsonb_build_object(f, c);                     -- pas changé à l'écran
    ELSIF public.fiche_valeur_normalisee(c) IS NOT DISTINCT FROM public.fiche_valeur_normalisee(b) THEN
      r := r || jsonb_build_object(f, n);                     -- changé à l'écran seulement
    ELSE
      r := r || jsonb_build_object(f, c);                     -- conflit : le serveur l'emporte
    END IF;
  END LOOP;
  RETURN r;
END;
$function$;
REVOKE ALL ON FUNCTION public.fiche_fusionner_ecran(jsonb,jsonb,jsonb) FROM PUBLIC, anon, authenticated;

-- 3. La vue accepte `fiche_base` en saisie (toujours NULL en lecture). Options et droits conservés.
DO $$
DECLARE d text; o text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.personnages'::regclass AND attname = 'fiche_base' AND NOT attisdropped) THEN RETURN; END IF;
  d := rtrim(pg_get_viewdef('public.personnages'::regclass), E'; \n');
  IF (length(d) - length(replace(d, 'FROM personnages_donnees d', ''))) / length('FROM personnages_donnees d') <> 1 THEN
    RAISE EXCEPTION 'vue_personnages_inattendue'; END IF;
  d := replace(d, 'FROM personnages_donnees d', ', NULL::jsonb AS fiche_base FROM personnages_donnees d');
  SELECT CASE WHEN reloptions IS NULL THEN '' ELSE ' WITH (' || array_to_string(reloptions, ', ') || ')' END INTO o
    FROM pg_class WHERE oid = 'public.personnages'::regclass;
  EXECUTE 'CREATE OR REPLACE VIEW public.personnages' || o || ' AS ' || d;
END $$;

-- 4. La porte d'écriture de la vue applique la fusion aux écritures de l'écran qui la demandent.
DO $$
DECLARE d text;
  f text := '    NEW.user_id := v_canon.user_id;';
BEGIN
  d := pg_get_functiondef('public.personnages_vue_modifier'::regproc);
  IF position('fiche_fusionner_ecran' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, f, ''))) / length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_vue_modifier'; END IF;
  d := replace(d, f, f || '

    -- Fusion à trois voies (30/10/2026) : une copie ancienne ne défait plus le serveur.
    IF NEW.fiche_base IS NOT NULL AND jsonb_typeof(NEW.fiche_base) = ''object'' THEN
      NEW := jsonb_populate_record(NEW, public.fiche_fusionner_ecran(to_jsonb(NEW), NEW.fiche_base, to_jsonb(v_canon)));
    END IF;
    NEW.fiche_base := NULL;');
  EXECUTE d;
END $$;
