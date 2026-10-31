-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030122905.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- UNE SEULE PRIMITIVE POUR TOUTES LES SANCTIONS FINANCIÈRES (30/10/2026, Claude). NON APPLIQUÉE.
-- Application par ChatGPT après prévol. Compatible avec l'écran en ligne (aucun contrat client
-- modifié). Suite de #255/#256 : ne recrée ni dette ni caisse, étend amendes_tresor.
--
-- 1. Contrat commun `sanction_financiere_imposer_interne(reference, origine, pays, debiteur,
--    montant, destinataire)` : une sanction est enregistrée UNE fois par référence. Prélèvement
--    immédiat de ce qui existe (espèces puis compte national, helvetia_debiter_fonds_ordinaires),
--    reste dû recouvré chaque nuit par minuit_amendes, au plus une fois par jour de Paris.
--    Destinataire : 'tresor' (budgets_nationaux.reserveJour du pays, défaut) ou
--    'caisse:<id>' (caisses_batiments, via caisse_institution_mouvement). Une reprise avec la même
--    référence ne sanctionne pas deux fois ; une même référence avec d'autres données est refusée.
--    amende_imposer_interne (fraude électorale) devient un simple appel à ce contrat.
--    Réservé au serveur : aucun droit pour anon/authenticated, le montant n'est jamais lu du client.
-- 2. minuit_decouverte_crimes retirait l'amende de `arg` sans la verser (et l'effaçait si le
--    joueur n'avait rien) : elle passe par le contrat, référence « decouverte-<nom>-<crime> ».
--    Les règles de détection (Codex) ne changent pas.
-- 3. crime_voler, vol raté : « Un agent vous verbalise sur-le-champ. -300 FR » (Républia) et
--    « -100 FR (amende symbolique) » (Union soviétique) disparaissaient ; ils vont au Trésor du pays
--    par le contrat. Le racket du cartel (narco) n'est pas une amende d'État : inchangé.
-- =====================================================================================
ALTER TABLE public.amendes_tresor ADD COLUMN IF NOT EXISTS origine text;
ALTER TABLE public.amendes_tresor ADD COLUMN IF NOT EXISTS destinataire text NOT NULL DEFAULT 'tresor';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'amendes_tresor_destinataire_valide') THEN
    ALTER TABLE public.amendes_tresor ADD CONSTRAINT amendes_tresor_destinataire_valide
      CHECK (destinataire = 'tresor' OR (destinataire LIKE 'caisse:%' AND length(destinataire) > 7));
  END IF;
END $$;

-- Prélève ce qui peut l'être, au plus une fois par jour de Paris, et le verse au destinataire.
CREATE OR REPLACE FUNCTION public.amende_prelever_interne(p_jugement text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.amendes_tresor; dispo numeric; pris integer; nat jsonb; r jsonb; ancien text;
  aujourdhui date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT * INTO a FROM public.amendes_tresor WHERE jugement_id = p_jugement FOR UPDATE;
  IF NOT FOUND OR a.statut <> 'due' OR a.dernier_prelevement IS NOT DISTINCT FROM aujourdhui THEN RETURN 0; END IF;
  -- Destinataire vérifié AVANT tout débit : jamais d'argent prélevé sans être versé.
  IF a.destinataire = 'tresor' THEN
    SELECT data INTO nat FROM public.budgets_nationaux WHERE id = a.pays FOR UPDATE;
    IF NOT FOUND THEN RETURN 0; END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = substr(a.destinataire, 8)) THEN
    RETURN 0;
  END IF;
  SELECT greatest(0, coalesce(d.liquide,0)) + greatest(0, coalesce((SELECT c.solde FROM public.comptes_bancaires c
           WHERE c.personnage = d.name AND c.banque = 'nationale' LIMIT 1),0))
    INTO dispo FROM public.personnages_donnees d WHERE d.name = a.condamne FOR UPDATE;
  pris := least(a.montant - a.paye, floor(coalesce(dispo,0)))::integer;
  IF pris > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(a.condamne, pris) THEN pris := 0; END IF;
  END IF;
  IF pris > 0 THEN
    IF a.destinataire = 'tresor' THEN
      UPDATE public.budgets_nationaux
         SET data = jsonb_set(coalesce(nat,'{}'::jsonb), '{reserveJour}', to_jsonb(coalesce((nat->>'reserveJour')::numeric,0) + pris)), updated_at = now()
       WHERE id = a.pays;
    ELSE
      ancien := current_setting('rp.caisse_interne', true);
      PERFORM set_config('rp.caisse_interne', 'on', true);
      r := public.caisse_institution_mouvement(substr(a.destinataire, 8), pris, true);
      PERFORM set_config('rp.caisse_interne', coalesce(ancien, ''), true);
      IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'sanction_versement_refuse'; END IF;
    END IF;
  END IF;
  UPDATE public.amendes_tresor
     SET paye = paye + pris, dernier_prelevement = aujourdhui, updated_at = now(),
         statut = CASE WHEN paye + pris >= montant THEN 'soldee' ELSE 'due' END,
         paiements = CASE WHEN pris > 0 THEN paiements || jsonb_build_array(jsonb_build_object('date', aujourdhui, 'montant', pris)) ELSE paiements END
   WHERE jugement_id = p_jugement;
  IF pris > 0 THEN
    PERFORM public.mail_systeme_poser_interne(CASE WHEN a.destinataire = 'tresor' THEN 'Trésor national' ELSE 'Service des amendes' END,
      a.condamne, 'Amende — prélèvement',
      pris || ' FR prélevés au titre de votre amende. ' ||
      CASE WHEN a.paye + pris >= a.montant THEN 'Votre amende est entièrement payée.'
           ELSE 'Reste dû : ' || (a.montant - a.paye - pris) || ' FR, prélevés au fur et à mesure de vos rentrées d''argent.' END, NULL);
  END IF;
  RETURN pris;
END;
$function$;
REVOKE ALL ON FUNCTION public.amende_prelever_interne(text) FROM PUBLIC, anon, authenticated;

-- Contrat commun (tribunal hors déclencheur, fraude, police, combats…).
CREATE OR REPLACE FUNCTION public.sanction_financiere_imposer_interne(
  p_reference text, p_origine text, p_pays text, p_debiteur text, p_montant integer, p_destinataire text DEFAULT 'tresor')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.amendes_tresor; dest text := coalesce(nullif(btrim(p_destinataire), ''), 'tresor');
  cree boolean; pris integer := 0;
BEGIN
  IF coalesce(btrim(p_reference), '') = '' OR coalesce(btrim(p_origine), '') = '' OR coalesce(btrim(p_pays), '') = ''
     OR p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_debiteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debiteur_introuvable');
  END IF;
  IF dest = 'tresor' THEN
    IF NOT EXISTS (SELECT 1 FROM public.budgets_nationaux WHERE id = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'tresor_introuvable'); END IF;
  ELSIF dest LIKE 'caisse:_%' THEN
    IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = substr(dest, 8)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  INSERT INTO public.amendes_tresor(jugement_id, pays, condamne, montant, statut, origine, destinataire)
  VALUES (p_reference, p_pays, p_debiteur, p_montant, 'due', p_origine, dest)
  ON CONFLICT (jugement_id) DO NOTHING RETURNING true INTO cree;
  SELECT * INTO a FROM public.amendes_tresor WHERE jugement_id = p_reference;
  IF cree IS NOT TRUE AND (a.condamne, a.pays, a.montant, a.destinataire) IS DISTINCT FROM (p_debiteur, p_pays, p_montant, dest) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_deja_utilisee', 'reference', p_reference);
  END IF;
  IF cree THEN
    pris := public.amende_prelever_interne(p_reference);
    SELECT * INTO a FROM public.amendes_tresor WHERE jugement_id = p_reference;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reference', p_reference, 'deja_enregistree', cree IS NOT TRUE,
    'montant', a.montant, 'preleve', pris, 'paye', a.paye, 'reste', a.montant - a.paye, 'statut', a.statut,
    'destinataire', a.destinataire);
END;
$function$;
REVOKE ALL ON FUNCTION public.sanction_financiere_imposer_interne(text,text,text,text,integer,text) FROM PUBLIC, anon, authenticated;

-- Ancien point d'entrée (fraude électorale) : même contrat, destinataire Trésor.
CREATE OR REPLACE FUNCTION public.amende_imposer_interne(p_id text, p_pays text, p_condamne text, p_montant integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r jsonb;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN 0; END IF;
  r := public.sanction_financiere_imposer_interne(p_id, coalesce(nullif(split_part(p_id, '-', 1), ''), 'sanction'), p_pays, p_condamne, p_montant, 'tresor');
  RETURN coalesce((r->>'preleve')::integer, 0);
END;
$function$;
REVOKE ALL ON FUNCTION public.amende_imposer_interne(text,text,text,integer) FROM PUBLIC, anon, authenticated;

-- Raccordements en place : chaque fragment doit exister une seule fois.
DO $$
DECLARE d text; i int; frag text[];
BEGIN
  d := pg_get_functiondef('public.minuit_decouverte_crimes'::regproc);
  IF position('sanction_financiere_imposer_interne' IN d) = 0 THEN
    frag := ARRAY['        UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_amende) WHERE name = r.name;',
                  '        IF coalesce(v_amende, 0) > 0 THEN
          PERFORM public.sanction_financiere_imposer_interne(''decouverte-'' || r.name || ''-'' || coalesce(t ->> ''id'', md5(t::text)),
            ''decouverte_crime'', r.country, r.name, v_amende, ''tresor'');
        END IF;'];
    IF (length(d) - length(replace(d, frag[1], ''))) / length(frag[1]) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_decouverte'; END IF;
    EXECUTE replace(d, frag[1], frag[2]);
  END IF;

  d := pg_get_functiondef('public.crime_voler(text,text,boolean,integer,integer)'::regprocedure);
  IF position('sanction_financiere_imposer_interne' IN d) = 0 THEN
    frag := ARRAY[
      -- Union soviétique : l'amende symbolique sort du même UPDATE que la popularité.
      '         SET arg = greatest(0, coalesce(arg, 0) - 100),
             resources = jsonb_set(',
      '         SET resources = jsonb_set(',
      '       WHERE name = v_moi;
      v_msg := ''Le collectif vous denonce publiquement.',
      '       WHERE name = v_moi;
      PERFORM public.sanction_financiere_imposer_interne(''vol-echec-'' || v_moi || ''-'' || txid_current(), ''vol_echec'', m.country, v_moi, 100, ''tresor'');
      v_msg := ''Le collectif vous denonce publiquement.',
      -- Républia (et pays sans règle propre) : la contravention de 300 FR.
      '      UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - 300) WHERE name = v_moi;',
      '      PERFORM public.sanction_financiere_imposer_interne(''vol-echec-'' || v_moi || ''-'' || txid_current(), ''vol_echec'', m.country, v_moi, 300, ''tresor'');'];
    FOR i IN 1..array_length(frag, 1) / 2 LOOP
      IF (length(d) - length(replace(d, frag[2*i-1], ''))) / length(frag[2*i-1]) <> 1 THEN
        RAISE EXCEPTION 'fragment_introuvable_vol_%', i; END IF;
      d := replace(d, frag[2*i-1], frag[2*i]);
    END LOOP;
    EXECUTE d;
  END IF;
END $$;
