-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030115956.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- LES AMENDES SONT PRÉLEVÉES ET VERSÉES AU TRÉSOR NATIONAL (30/10/2026, Claude). NON APPLIQUÉE.
-- Application par ChatGPT. Compatible avec l'écran en ligne ; à déployer avec api/cron-minuit.js
-- (tâche nocturne `minuit_amendes`).
--
-- Défaut confirmé par ChatGPT : justice_rendre_sentence, justice_appel_juger et plainte_defendre
-- fixent l'amende dans le jugement, mais personne ne la prélève (justice_peine_calcul le dit :
-- « l'amende n'est PRELEVEE nulle part »).
-- Décisions de Fred (30/10) :
--   - l'argent va au Trésor national : même canal que la taxe nationale sur les ventes
--     (budgets_nationaux.data.reserveJour, appliquer_taxe_transaction) ;
--   - ce qui ne peut pas être payé devient une dette envers le Trésor, prélevée au fur et à
--     mesure des rentrées d'argent : chaque nuit, ce que le condamné possède (espèces puis compte
--     national, moteur helvetia_debiter_fonds_ordinaires) jusqu'à extinction ;
--   - l'appel est suspensif : rien n'est prélevé tant que le délai d'appel court ou qu'un appel
--     est ouvert. La décision d'appel remplace l'amende de première instance.
-- Une ligne par jugement (clé = id du jugement) : jamais deux amendes pour le même jugement, et
-- jamais deux prélèvements la même nuit pour la même amende.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS public.amendes_tresor (
  jugement_id text PRIMARY KEY,
  pays text NOT NULL, condamne text NOT NULL, affaire_id text,
  montant integer NOT NULL CHECK (montant > 0),
  paye integer NOT NULL DEFAULT 0 CHECK (paye >= 0),
  statut text NOT NULL CHECK (statut IN ('suspendue','due','soldee','remplacee_appel')),
  appel_jusqu_au_jour_pays integer,
  dernier_prelevement date,
  paiements jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.amendes_tresor ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.amendes_tresor FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.amendes_tresor TO authenticated;
DROP POLICY IF EXISTS amendes_tresor_lecture_condamne ON public.amendes_tresor;
CREATE POLICY amendes_tresor_lecture_condamne ON public.amendes_tresor FOR SELECT TO authenticated
  USING (condamne = public.mon_personnage());

-- Prélève ce qui peut l'être, au plus une fois par jour de Paris, et le verse au Trésor.
CREATE OR REPLACE FUNCTION public.amende_prelever_interne(p_jugement text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.amendes_tresor; dispo numeric; pris integer; nat jsonb;
  aujourdhui date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT * INTO a FROM public.amendes_tresor WHERE jugement_id = p_jugement FOR UPDATE;
  IF NOT FOUND OR a.statut <> 'due' OR a.dernier_prelevement IS NOT DISTINCT FROM aujourdhui THEN RETURN 0; END IF;
  SELECT greatest(0, coalesce(d.liquide,0)) + greatest(0, coalesce((SELECT c.solde FROM public.comptes_bancaires c
           WHERE c.personnage = d.name AND c.banque = 'nationale' LIMIT 1),0))
    INTO dispo FROM public.personnages_donnees d WHERE d.name = a.condamne FOR UPDATE;
  pris := least(a.montant - a.paye, floor(coalesce(dispo,0)))::integer;
  IF pris > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(a.condamne, pris) THEN pris := 0; END IF;
  END IF;
  IF pris > 0 THEN
    SELECT data INTO nat FROM public.budgets_nationaux WHERE id = a.pays FOR UPDATE;
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(coalesce(nat,'{}'::jsonb), '{reserveJour}', to_jsonb(coalesce((nat->>'reserveJour')::numeric,0) + pris)), updated_at = now()
     WHERE id = a.pays;
  END IF;
  UPDATE public.amendes_tresor
     SET paye = paye + pris, dernier_prelevement = aujourdhui, updated_at = now(),
         statut = CASE WHEN paye + pris >= montant THEN 'soldee' ELSE 'due' END,
         paiements = CASE WHEN pris > 0 THEN paiements || jsonb_build_array(jsonb_build_object('date', aujourdhui, 'montant', pris)) ELSE paiements END
   WHERE jugement_id = p_jugement;
  IF pris > 0 THEN
    PERFORM public.mail_systeme_poser_interne('Trésor national', a.condamne, 'Amende — prélèvement',
      pris || ' FR prélevés au titre de votre amende. ' ||
      CASE WHEN a.paye + pris >= a.montant THEN 'Votre amende est entièrement payée.'
           ELSE 'Reste dû au Trésor : ' || (a.montant - a.paye - pris) || ' FR, prélevés au fur et à mesure de vos rentrées d''argent.' END, NULL);
  END IF;
  RETURN pris;
END;
$function$;
REVOKE ALL ON FUNCTION public.amende_prelever_interne(text) FROM PUBLIC, anon, authenticated;

-- Sanction hors tribunal (fraude électorale…) : amende due tout de suite, même dette et même canal.
CREATE OR REPLACE FUNCTION public.amende_imposer_interne(p_id text, p_pays text, p_condamne text, p_montant integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN 0; END IF;
  INSERT INTO public.amendes_tresor(jugement_id, pays, condamne, montant, statut)
  VALUES (p_id, p_pays, p_condamne, p_montant, 'due') ON CONFLICT (jugement_id) DO NOTHING;
  RETURN public.amende_prelever_interne(p_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.amende_imposer_interne(text,text,text,integer) FROM PUBLIC, anon, authenticated;

-- Chaque jugement portant une amende ouvre sa ligne au Trésor.
CREATE OR REPLACE FUNCTION public.amende_jugement_enregistrer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE montant integer := coalesce(nullif(NEW.data->>'amende','')::integer, 0);
  instance text := coalesce(NEW.data->>'instance', 'premiere'); affaire text;
BEGIN
  affaire := CASE WHEN left(NEW.id, 4) = 'jug-' THEN substr(NEW.id, 5) END;
  IF instance = 'appel' THEN
    -- La décision d'appel remplace l'amende de première instance (jamais prélevée : appel suspensif).
    UPDATE public.amendes_tresor SET statut = 'remplacee_appel', updated_at = now()
     WHERE jugement_id = NEW.data->>'jugement_premiere_instance' AND statut IN ('suspendue','due') AND paye = 0;
    affaire := coalesce(affaire, substr(NEW.data->>'jugement_premiere_instance', 5));
  END IF;
  IF montant <= 0 OR coalesce(NEW.data->>'verdict','condamnation') IN ('relaxe','acquittement','annulation') THEN RETURN NEW; END IF;
  INSERT INTO public.amendes_tresor(jugement_id, pays, condamne, affaire_id, montant, statut, appel_jusqu_au_jour_pays)
  VALUES (NEW.id, NEW.country, NEW.accuse, affaire, montant,
          CASE WHEN instance IN ('appel','simplifiee') THEN 'due' ELSE 'suspendue' END,
          nullif(NEW.data->>'appel_jusqu_au_jour_pays','')::integer)
  ON CONFLICT (jugement_id) DO NOTHING;
  IF instance IN ('appel','simplifiee') THEN PERFORM public.amende_prelever_interne(NEW.id); END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.amende_jugement_enregistrer() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS amende_jugement_enregistrer ON public.jugements;
CREATE TRIGGER amende_jugement_enregistrer AFTER INSERT ON public.jugements
  FOR EACH ROW EXECUTE FUNCTION public.amende_jugement_enregistrer();

-- Passage de minuit : fin du délai d'appel, puis prélèvement des amendes dues.
CREATE OR REPLACE FUNCTION public.minuit_amendes()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a record; limite integer; appel boolean; n_exigibles int := 0; n_preleves int := 0; total int := 0; pris int;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur'); END IF;
  FOR a IN SELECT * FROM public.amendes_tresor WHERE statut = 'suspendue' FOR UPDATE LOOP
    SELECT coalesce(a.appel_jusqu_au_jour_pays, nullif(j.data->>'appel_jusqu_au_jour_pays','')::integer) INTO limite
      FROM public.jugements j WHERE j.id = a.jugement_id;
    SELECT coalesce((p.data::jsonb ? 'appel_ouvert_le'), false) INTO appel FROM public.plaintes_en_cours p WHERE p.id = a.affaire_id;
    IF coalesce(appel, false) THEN CONTINUE; END IF;
    IF limite IS NOT NULL AND coalesce(public.jour_de_jeu_pays(a.pays), 1) > limite THEN
      UPDATE public.amendes_tresor SET statut = 'due', updated_at = now() WHERE jugement_id = a.jugement_id;
      n_exigibles := n_exigibles + 1;
    END IF;
  END LOOP;
  FOR a IN SELECT jugement_id FROM public.amendes_tresor WHERE statut = 'due' LOOP
    pris := public.amende_prelever_interne(a.jugement_id);
    IF pris > 0 THEN n_preleves := n_preleves + 1; total := total + pris; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'exigibles', n_exigibles, 'preleves', n_preleves, 'total', total);
END;
$function$;
REVOKE ALL ON FUNCTION public.minuit_amendes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.minuit_amendes() TO service_role;
