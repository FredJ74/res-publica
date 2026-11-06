-- ACHAT A L'ENTREPOT : LA RECETTE VA A LA CAISSE CANONIQUE (Claude, 07/11/2026)
--
-- Constat : depuis le 8 octobre, la tresorerie des entrepots vit dans caisses_batiments
-- (<pays>_entrepot_<ville>), lue par la passe de minuit, le trading et l'ecran du directeur.
-- Mais acheter_a_entrepot(text,...) -- appelee par la porte client acheter_a_entrepot(uuid,...) --
-- creditait encore l'ancienne cle batiments_etat.data.entrepot.caisse, que plus rien ne lit et
-- que la passe de minuit ne reecrit pas. L'argent paye par un PJ a un entrepot disparaissait.
--
-- Patch en place : credit par caisse_institution_mouvement (porte interne, caisse exigee),
-- cle 'caisse' retiree du blob, solde canonique rendu dans 'caisse_entrepot'. Refus de
-- s'appliquer si la definition a change (empreinte du 07/11 en production).
-- Valable pour tous les pays (Republia et Sovarka passent par la meme fonction).

DO $migration$
DECLARE
  v_def text := pg_get_functiondef('public.acheter_a_entrepot(text,text,text,text,jsonb)'::regprocedure);
  v_avant text;
BEGIN
  IF md5(v_def) <> '1d05733c127130c2f17dda7bdbfaf444' THEN
    RAISE EXCEPTION 'acheter_a_entrepot a change depuis le releve du 07/11 : patch refuse';
  END IF;
  v_avant := v_def;

  v_def := replace(v_def,
    'v_idx int; v_ligne jsonb; v_existe boolean;',
    'v_idx int; v_ligne jsonb; v_existe boolean;
  v_caisse_id text; v_ancien_flag text; v_rep jsonb;');

  v_def := replace(v_def,
$a$  v_entrepot := v_entrepot || jsonb_build_object('stock', v_stock,
                  'caisse', coalesce((v_entrepot->>'caisse')::numeric, 0) + v_paye);$a$,
$b$  -- CAISSE CANONIQUE (07/11/2026) : caisses_batiments, plus la cle du blob.
  v_caisse_id := public.entrepot_caisse_id(v_id);
  IF v_caisse_id IS NULL THEN
    RAISE EXCEPTION 'caisse_entrepot_non_declaree: %', v_id;
  END IF;
  v_ancien_flag := current_setting('rp.caisse_interne', true);
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse_id, v_paye, true);
  PERFORM set_config('rp.caisse_interne', coalesce(v_ancien_flag, ''), true);
  IF (v_rep->>'ok')::boolean IS NOT TRUE THEN
    -- Tout est annule (debit du PJ compris) plutot que de perdre l'argent.
    RAISE EXCEPTION 'caisse_entrepot_refusee: %', v_rep;
  END IF;
  v_entrepot := (v_entrepot - 'caisse') || jsonb_build_object('stock', v_stock);$b$);

  v_def := replace(v_def,
    $c$'caisse_entrepot', (v_entrepot->>'caisse')::numeric);$c$,
    $d$'caisse_entrepot', (SELECT (c.data->>'solde')::numeric FROM public.caisses_batiments c WHERE c.id = v_caisse_id));$d$);

  IF v_def = v_avant
     OR position('caisse_institution_mouvement' IN v_def) = 0
     OR position($e$(v_entrepot->>'caisse')$e$ IN v_def) > 0 THEN
    RAISE EXCEPTION 'patch acheter_a_entrepot incomplet';
  END IF;

  EXECUTE v_def;
END
$migration$;
