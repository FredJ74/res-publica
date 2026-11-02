-- ORGANISATIONS, FIN DE LA DOUBLE AUTORITÉ, ÉTAPE B — PORTAGE 3/3 (Claude, 02/11/2026). Additive.
-- À APPLIQUER APRÈS le déploiement READY de l'écran : sinon l'ancien écran retirerait l'influence
-- une seconde fois après une rumeur réussie.
-- Deux patchs en place (WORKFLOW-SUPABASE.md, « patcher en place, jamais retaper ») :
-- 1) militant_recruter : le militant PNJ entre dans la liste des membres de SON syndicat dans la
--    même transaction que son recrutement (l'écran l'ajoutait ensuite par la sauvegarde générale).
--    Le syndicat transmis doit être un syndicat dont le recruteur est membre : avant, n'importe
--    quel identifiant passait dès lors qu'on était membre d'un syndicat quelconque.
-- 2) rumeur_lancer : la perte d'influence d'une organisation visée, déjà tirée ici, est appliquée
--    ici (bornée 0-100, 50 par défaut), au lieu d'être écrite par l'écran du lanceur.
-- 3) organisations_politique_autorite : une création d'organisation non politique n'est plus
--    prise pour un parti (voir le détail au patch). Débloque supporters et dockers.
-- Banc annulé : outils/bancs/banc-organisations-etape-b.sql (joué le 02/11 contre la production).
BEGIN;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.militant_recruter(text,text,text,text,text,text,integer,integer)'::regprocedure);
  IF position('pnj_militants_metier (pnj_id' IN substr(v_def, position('pnj_militants_metier (pnj_id' IN v_def) + 1)) > 0
     OR position('etape B des organisations' IN v_def) > 0 THEN
    RAISE EXCEPTION 'patch militant_recruter : fragment multiple ou deja patche'; END IF;
  v_new := replace(v_def, $a$  IF NOT coalesce(v_syndicat, false) THEN$a$,
$n$  -- LE SYNDICAT DESIGNE, PAS UN SYNDICAT QUELCONQUE (02/11/2026, etape B des organisations).
  v_syndicat := coalesce(v_syndicat, false) AND EXISTS (
    SELECT 1 FROM public.organisations o
     WHERE o.id = p_organisation_id AND left(btrim(coalesce(o.data, '')), 1) = '{'
       AND (o.data::jsonb ->> 'type') = 'syndicale'
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                          THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END) m
                    WHERE m ->> 'nom' = v_moi));
  IF NOT coalesce(v_syndicat, false) THEN$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch militant_recruter : fragment 1 introuvable'; END IF;
  v_def := v_new;
  v_new := replace(v_def, $a$  INSERT INTO public.pnj_militants_metier (pnj_id, organisation_id, grade, rejoint_le)$a$,
$n$  -- LE MILITANT EST COMPTE DANS SON SYNDICAT, DANS LA MEME TRANSACTION (02/11/2026).
  UPDATE public.organisations o
     SET data = jsonb_set(o.data::jsonb, '{membres}',
                  CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array' THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END
                  || jsonb_build_array(jsonb_build_object('nom', v_nom, 'grade', 'Militant (PNJ)', 'rejointLe', v_jour,
                                                          'estPnj', true, 'recruteur', v_moi)))::text
   WHERE o.id = p_organisation_id
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(
                       CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                            THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END) m
                      WHERE m ->> 'nom' = v_nom);

  INSERT INTO public.pnj_militants_metier (pnj_id, organisation_id, grade, rejoint_le)$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch militant_recruter : fragment 2 introuvable'; END IF;
  EXECUTE v_new;

  v_def := pg_get_functiondef('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure);
  v_new := replace(v_def, $a$    ELSIF p_type = 'organisation' THEN
      v_perte := floor(random() * 10)::integer + 1;
$a$, $n$    ELSIF p_type = 'organisation' THEN
      v_perte := floor(random() * 10)::integer + 1;
      -- L'INFLUENCE DE L'ORGANISATION VISEE, ECRITE ICI (02/11/2026, etape B des organisations).
      UPDATE public.organisations o
         SET data = jsonb_set(o.data::jsonb, '{influence}', to_jsonb(greatest(0, least(100,
               coalesce(CASE WHEN jsonb_typeof(o.data::jsonb -> 'influence') = 'number'
                             THEN (o.data::jsonb ->> 'influence')::numeric END, 50) - v_perte))))::text
       WHERE o.id = p_cible AND o.data IS JSON OBJECT;
$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch rumeur_lancer : fragment introuvable'; END IF;
  EXECUTE v_new;

  -- 3) organisations_politique_autorite : à la création, OLD n'existe pas et le test « parti avant
  --    OU parti après » valait NULL, donc toute organisation créée par un joueur était traitée comme
  --    un parti. Effet : un club de supporters ou le syndicat des dockers (fondateur PNJ) ne
  --    pouvaient pas naître (aucun n'existe en base au 02/11/2026). Le garde-fou ne vise que les partis.
  v_def := pg_get_functiondef('public.organisations_politique_autorite()'::regprocedure);
  v_new := replace(v_def, $a$  v_politique := (v_av ->> 'type') = 'politique' OR (v_ap ->> 'type') = 'politique';$a$,
    $n$  v_politique := coalesce(v_av ->> 'type', '') = 'politique' OR coalesce(v_ap ->> 'type', '') = 'politique'; -- etape B des organisations$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch organisations_politique_autorite : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

COMMIT;
