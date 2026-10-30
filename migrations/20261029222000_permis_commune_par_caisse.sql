-- =====================================================================================
-- PERMIS D'UN TERRAIN DE LA COMMUNE : PAYÉ PAR LA CAISSE DE LA MAIRIE (29/10/2026, Claude).
-- NON APPLIQUÉE — application par ChatGPT, APRÈS 20261029220000. Compatible avec l'écran en ligne.
--
-- Décision de Fred : « c'est évident : par la mairie ». Quand le maire dépose le permis d'un
-- terrain de la commune, les 100 FR sont pris dans la caisse de la mairie
-- (`salaire_caisse_de('maire', …)`) ; le maire ne dépense que son point d'action. Si la caisse
-- ne couvre pas les 100 FR, rien n'est prélevé.
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.permis_commune_payer_interne(p_acteur text, p_pays text, p_ville text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE caisse text := public.salaire_caisse_de('maire', p_pays, p_ville); solde numeric; ancien text; r jsonb;
BEGIN
  IF caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','caisse_mairie_introuvable'); END IF;
  SELECT (data->>'solde')::numeric INTO solde FROM public.caisses_batiments WHERE id = caisse FOR UPDATE;
  IF coalesce(solde,0) < 100 THEN RETURN jsonb_build_object('ok',false,'raison','caisse_communale_insuffisante'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1, updated_at = now() WHERE name = p_acteur AND coalesce(pa,0) >= 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
  ancien := current_setting('rp.caisse_interne', true);
  PERFORM set_config('rp.caisse_interne', 'on', true);
  r := public.caisse_institution_mouvement(caisse, -100, true);
  PERFORM set_config('rp.caisse_interne', coalesce(ancien,''), true);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'caisse_communale_insuffisante'; END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'pa',d.pa,'arg',d.arg,'liquide',d.liquide,'payeParCommune',true)
            FROM public.personnages_donnees d WHERE d.name = p_acteur);
END;
$function$;
REVOKE ALL ON FUNCTION public.permis_commune_payer_interne(text,text,text) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE d text; f text := ' ELSE paiement:=public.payer_ordre(acteur,''deposer_demande_permis'',1,100);END IF;';
BEGIN
  d := pg_get_functiondef('public.terrain_permis_deposer(text,text,uuid)'::regprocedure);
  IF position('permis_commune_payer_interne' IN d) = 0 THEN
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_paiement_permis'; END IF;
    EXECUTE replace(d, f, ' ELSIF etat->>''proprietaire''=''ville:''||pays||'':''||ville THEN paiement:=public.permis_commune_payer_interne(acteur,pays,ville);
 ELSE paiement:=public.payer_ordre(acteur,''deposer_demande_permis'',1,100);END IF;');
  END IF;
END $$;
