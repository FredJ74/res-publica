-- Banc annulé de 20261108170000_sovarka_tresor_signalements (rien ne reste : exception finale).
BEGIN;
-- Fin des ministères de Sovarka (décisions de Fred du 08/11/2026, GAME-DESIGN-NOVOMIRSK.md) :
--  1. Redistribution nationale : chaque nuit, dotation fixe de 24 600 PSK + impôts du jour (reserveJour),
--     répartis par la cascade du socle (budget_cascade_quotidienne) depuis la caisse de l'Économie
--     collective. Socle de Républia adapté : Présidence 9 -> 3 % (aucun pouvoir), Sécurité du Peuple
--     9 -> 15 % (État policier), Soviet Suprême 19 % (couvre les indemnités des députés) ; reste à
--     l'identique ; Défense -> Caserne 65 % comme en Républia.
--  2. Registre des signalements de la cellule Balatov : lisible par le Président du Conseil et le
--     ministre de la Sécurité du Peuple, sans effet automatique ; une fuite aux Archives peut le publier.
--  3. Coûts en PA des ordres ministériels confirmés par Fred (inchangés).

INSERT INTO public.caisses_batiments (id, data, updated_at)
VALUES ('soviet_palais-gouvernement', '{"solde": 0}'::jsonb, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.repartitions_budgetaires
  (pays, source, beneficiaire, part_numerateur, part_denominateur, poste_autorite, rang, libelle, note) VALUES
  ('soviet','gouvernement-min_fin','palais-presidentiel',     3,100,'min_fin', 1,'Présidence de la République de Sovarka','Fred, 08/11/2026 : le président n''a aucun pouvoir'),
  ('soviet','gouvernement-min_fin','gouvernement-pm',         9,100,'min_fin', 2,'Président du Conseil du Peuple',NULL),
  ('soviet','gouvernement-min_fin','gouvernement-min_int',   15,100,'min_fin', 3,'Ministère de la Sécurité du Peuple','Fred, 08/11/2026 : État policier'),
  ('soviet','gouvernement-min_fin','gouvernement-min_fin',    9,100,'min_fin', 4,'Ministère de l''Économie collective','Part conservée par le répartiteur'),
  ('soviet','gouvernement-min_fin','gouvernement-min_just',   9,100,'min_fin', 5,'Ministère de la Justice prolétarienne',NULL),
  ('soviet','gouvernement-min_fin','gouvernement-min_def',    9,100,'min_fin', 6,'Ministère de la Défense de la Patrie',NULL),
  ('soviet','gouvernement-min_fin','gouvernement-min_info',   9,100,'min_fin', 7,'Ministère de la Vérité officielle',NULL),
  ('soviet','gouvernement-min_fin','gouvernement-min_ae',     9,100,'min_fin', 8,'Ministère de l''Amitié entre les Peuples',NULL),
  ('soviet','gouvernement-min_fin','palais-gouvernement',     9,100,'min_fin', 9,'Palais du Gouvernement',NULL),
  ('soviet','gouvernement-min_fin','assemblee',              19,100,'min_fin',10,'Soviet Suprême','Paie les indemnités des députés (250 PSK/jour)'),
  ('soviet','gouvernement-min_def','caserne-militaire',      65,100,'min_def', 1,'Caserne centrale de Novomirsk','Comme en Républia')
ON CONFLICT (pays, source, beneficiaire) DO NOTHING;

DO $patch$
DECLARE r record; v_def text; v_n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    -- Passe de nuit : redistribution nationale en tête de passe, donc avant les indemnités (ancre sur du code :
    -- la production ne garde pas les commentaires des corps de fonction).
    ('public.sovarka_pouvoir_passe()',
     $a$  v_conv int := 0; v_abs int := 0; v_pay int := 0; v_ref int := 0; c record;$a$,
     $b$  v_conv int := 0; v_abs int := 0; v_pay int := 0; v_ref int := 0; c record; v_reserve numeric; v_tresor jsonb;$b$),
    ('public.sovarka_pouvoir_passe()',
     $a$  v_dow := extract(isodow FROM v_jour)::int;$a$,
     $b$  v_dow := extract(isodow FROM v_jour)::int;

  -- Chaque nuit : redistribution nationale (Fred, 08/11) = dotation 24 600 PSK + impôts du jour, par la cascade
  -- du socle ; reserveJour remis à zéro dans la même transaction, seulement si la cascade a versé.
  IF NOT EXISTS (SELECT 1 FROM public.repartitions_versements
                  WHERE pays = 'soviet' AND source = 'gouvernement-min_fin' AND jour = v_jour) THEN
    SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO v_reserve FROM public.budgets_nationaux WHERE id = 'soviet' FOR UPDATE;
    v_tresor := public.budget_cascade_quotidienne('soviet', 24600 + greatest(0, coalesce(v_reserve, 0)));
    IF coalesce((v_tresor->>'ok')::boolean, false) AND v_tresor ? 'etapes' THEN
      UPDATE public.budgets_nationaux SET data = jsonb_set(data, '{reserveJour}', '0'::jsonb), updated_at = now() WHERE id = 'soviet';
    END IF;
  END IF;$b$),
    ('public.sovarka_pouvoir_passe()',
     $a$'indemnites', v_pay, 'refractaires', v_ref);$a$,
     $b$'indemnites', v_pay, 'refractaires', v_ref,
    'tresor', CASE WHEN v_tresor IS NULL THEN NULL ELSE jsonb_build_object('ok', v_tresor->'ok', 'recettes', v_tresor->'recettes', 'raison', v_tresor->'raison') END);$b$),
    -- Lecture : registre des signalements pour le Président du Conseil et la Sécurité du Peuple.
    ('public.sovarka_pouvoir_lire()',
     $a$  RETURN v_out;$a$,
     $b$  IF public.sovarka_est_titulaire_interne(a, 'pm') OR public.sovarka_est_titulaire_interne(a, 'min_int') THEN
    v_out := v_out || jsonb_build_object('signalements', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'ts', g.ts,
        'cible', g.cible, 'parti_nom', (SELECT o.data::jsonb->>'nom' FROM public.organisations o WHERE o.id = g.parti),
        'motif', g.motif, 'loi', (SELECT l.titre FROM public.assemblee_propositions l WHERE l.id::text = g.details->>'loi')) ORDER BY g.ts DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.sovarka_signalements ORDER BY ts DESC LIMIT 50) g));
  END IF;
  RETURN v_out;$b$),
    -- Fuite : objet « signalements » publie le registre des 30 derniers jours au forum national.
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)',
     $a$          SELECT * INTO s FROM public.sovarka_sondages WHERE statut = 'fausse' AND revele_ts IS NULL ORDER BY decide_ts DESC LIMIT 1 FOR UPDATE;
          IF s.id IS NULL THEN$a$,
     $b$          SELECT * INTO s FROM public.sovarka_sondages WHERE coalesce(p_params->>'objet', 'sondage') = 'sondage'
             AND statut = 'fausse' AND revele_ts IS NULL ORDER BY decide_ts DESC LIMIT 1 FOR UPDATE;
          IF s.id IS NULL AND coalesce(p_params->>'objet', 'sondage') = 'signalements' THEN
            SELECT string_agg('• ' || to_char(g.ts AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' — ' || g.cible
                     || coalesce(' (' || (SELECT o.data::jsonb->>'nom' FROM public.organisations o WHERE o.id = g.parti) || ')', '')
                     || ' : ' || CASE g.motif WHEN 'abstention' THEN 'abstention' ELSE g.motif END
                     || coalesce(' sur « ' || (SELECT l.titre FROM public.assemblee_propositions l WHERE l.id::text = g.details->>'loi') || ' »', ''),
                     E'\n' ORDER BY g.ts DESC)
              INTO v_contenu FROM (SELECT * FROM public.sovarka_signalements WHERE ts > now() - interval '30 days' ORDER BY ts DESC LIMIT 30) g;
            IF v_contenu IS NULL THEN
              v := jsonb_build_object('ok', true, 'action', p_action, 'objet', 'signalements', 'trouve', false,
                     'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
            ELSE
              v_vp := public.forum_publication_jauges_interne(a, p_requete, jsonb_build_object('forum', 'national',
                        'titre', 'Fuite — le registre secret de la cellule Balatov',
                        'contenu', 'Les députés signalés à la cellule de surveillance des partis, d''après les Archives du gouvernement :' || E'\n' || v_contenu));
              IF NOT coalesce((v_vp->>'ok')::boolean, false) THEN v := jsonb_build_object('ok', false, 'raison', 'publication_refusee');
              ELSE
                PERFORM public.crime_tracer_interne(a, 'fuite_info', 'Archives du gouvernement');
                PERFORM public.crime_detecter_interne(a, 'fuite_info', true, 'fuite_info');
                v := jsonb_build_object('ok', true, 'action', p_action, 'objet', 'signalements', 'trouve', true,
                       'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg',
                       'recherche', (SELECT recherche FROM public.personnages_donnees WHERE name = a));
              END IF;
            END IF;
          ELSIF s.id IS NULL THEN$b$)
  ) AS t(fn, avant, apres) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    v_n := (length(v_def) - length(replace(v_def, r.avant, ''))) / length(r.avant);
    IF v_n <> 1 THEN RAISE EXCEPTION 'fragment non unique dans % (%)', r.fn, v_n; END IF;
    EXECUTE replace(v_def, r.avant, r.apres);
  END LOOP;
END $patch$;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'sovarka_signalements', 0, 0 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'sovarka_signalements');
DO $banc$
DECLARE s0 jsonb; s1 jsonb; v1 jsonb; v2 jsonb; r0 numeric;
BEGIN
  SELECT coalesce((data->>'reserveJour')::numeric, 0) INTO r0 FROM public.budgets_nationaux WHERE id = 'soviet';
  SELECT jsonb_object_agg(id, (data->>'solde')::numeric) INTO s0 FROM public.caisses_batiments WHERE id LIKE 'soviet_%';
  v1 := public.sovarka_pouvoir_passe();
  v2 := public.sovarka_pouvoir_passe();
  SELECT jsonb_object_agg(id, (data->>'solde')::numeric) INTO s1 FROM public.caisses_batiments WHERE id LIKE 'soviet_%';
  IF (v1->'tresor'->>'ok') IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'banc KO : cascade %', v1; END IF;
  IF (SELECT (data->>'reserveJour')::numeric FROM public.budgets_nationaux WHERE id = 'soviet') <> 0 THEN RAISE EXCEPTION 'banc KO : reserve non remise a zero'; END IF;
  IF v2->'tresor' IS NOT NULL AND v2->'tresor' <> 'null'::jsonb THEN RAISE EXCEPTION 'banc KO : second passage %', v2; END IF;
  IF position('signalements' in pg_get_functiondef('public.sovarka_pouvoir_lire()'::regprocedure)) = 0 THEN RAISE EXCEPTION 'banc KO : lecture'; END IF;
  RAISE EXCEPTION 'banc OK : reserve %, total %, assemblee +%, min_int +%, president +%, caserne +%, min_fin +%, palais-gouv %',
    r0, 24600 + r0,
    (s1->>'soviet_assemblee')::numeric - (s0->>'soviet_assemblee')::numeric,
    (s1->>'soviet_gouvernement-min_int')::numeric - (s0->>'soviet_gouvernement-min_int')::numeric,
    (s1->>'soviet_palais-presidentiel')::numeric - (s0->>'soviet_palais-presidentiel')::numeric,
    (s1->>'soviet_caserne-militaire')::numeric - (s0->>'soviet_caserne-militaire')::numeric,
    (s1->>'soviet_gouvernement-min_fin')::numeric - (s0->>'soviet_gouvernement-min_fin')::numeric,
    s1->>'soviet_palais-gouvernement';
END $banc$;
ROLLBACK;
