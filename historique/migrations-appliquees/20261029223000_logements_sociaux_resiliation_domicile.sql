-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030115944.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- LOGEMENTS SOCIAUX : RÉSERVÉS AUX DOMICILIÉS DE LA VILLE (29/10/2026, Claude). NON APPLIQUÉE.
-- Application par ChatGPT, APRÈS 20261029220000. Compatible avec l'écran en ligne.
--
-- Décision de Fred : « c'est un mécanisme du socle, commun à tous les logements sociaux : n'y ont
-- droit que ceux qui sont domiciliés dans la ville ».
-- Le domicile est modifié par l'écran (vue personnages) : la règle est donc posée au serveur, sur
-- la ligne du personnage. Dès que son domicile officiel change de ville, chacun de ses baux
-- sociaux situé hors de sa nouvelle ville est résilié. Cela vaut pour les logements de la commune
-- et pour les appartements historiques de Montrouge. Pour un logement de la commune, l'appartement
-- est libéré et la résiliation inscrite dans l'historique du bâtiment. Le locataire est prévenu
-- par courrier. L'ancienne résiliation côté écran (Montrouge) devient sans effet, sans danger.
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.logements_sociaux_domicile_resilier()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE b record; t record; e jsonb; x jsonb; sortie jsonb;
BEGIN
  IF (OLD.domicile->>'country', OLD.domicile->>'city') IS NOT DISTINCT FROM (NEW.domicile->>'country', NEW.domicile->>'city') THEN
    RETURN NEW; END IF;
  FOR b IN DELETE FROM public.locations_actives
            WHERE data->>'locataire' = NEW.name AND data->>'logementSocial' = 'true'
              AND (country IS DISTINCT FROM NEW.domicile->>'country' OR data->>'city' IS DISTINCT FROM NEW.domicile->>'city')
           RETURNING id, country, data LOOP
    IF nullif(b.data->>'lotId','') IS NOT NULL THEN
      SELECT * INTO t FROM public.terrains_etat WHERE country = b.country AND building_id = b.data->>'buildingId' FOR UPDATE;
      IF FOUND THEN
        e := t.data::jsonb; sortie := '[]';
        FOR x IN SELECT value FROM jsonb_array_elements(coalesce(e->'subdivisions','[]')) LOOP
          sortie := sortie || jsonb_build_array(CASE WHEN x->>'id' = b.data->>'lotId' AND x->>'locataire' = NEW.name
                                                     THEN x || jsonb_build_object('locataire', NULL) ELSE x END);
        END LOOP;
        PERFORM public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('subdivisions', sortie, 'lotsHistorique',
          coalesce(e->'lotsHistorique','[]') || jsonb_build_array(jsonb_build_object('acte','resiliation_depart','lot',b.data->>'lotId',
            'ancienLocataire',NEW.name,'date',statement_timestamp()))), t.country);
      END IF;
    END IF;
    PERFORM public.mail_systeme_poser_interne('Mairie', NEW.name, 'Logement social résilié',
      'Votre domicile officiel a quitté la ville : votre bail social (' || coalesce(b.data->>'localLabel', 'logement') || ') est résilié.', NULL);
  END LOOP;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.logements_sociaux_domicile_resilier() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS logements_sociaux_domicile_resilier ON public.personnages_donnees;
CREATE TRIGGER logements_sociaux_domicile_resilier AFTER UPDATE OF domicile ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.logements_sociaux_domicile_resilier();

-- L'adjoint n'attribue qu'à un demandeur encore domicilié dans la ville.
DO $$
DECLARE d text; f text := '  idb := t.country||'':''||t.building_id||'':lot_dyn_''||regexp_replace(p_lot,''[^A-Za-z0-9_-]'',''_'',''g'')||'':''||ville;
  SELECT coalesce(day,1) INTO jour';
BEGIN
  d := pg_get_functiondef('public.logement_social_attribuer(text,text,text)'::regprocedure);
  IF position('demandeur_non_resident' IN d) = 0 THEN
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_attribuer'; END IF;
    EXECUTE replace(d, f, '  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees r WHERE r.name = dm.demandeur AND r.domicile->>''country'' = t.country AND r.domicile->>''city'' = ville) THEN
    RETURN jsonb_build_object(''ok'',false,''raison'',''demandeur_non_resident''); END IF;
'||f);
  END IF;
END $$;
