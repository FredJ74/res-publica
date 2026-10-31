-- PRÉPARÉE — NE PAS APPLIQUER AVANT : (1) installation des contrats #219 en production,
-- (2) recette des parcours légitimes, (3) feu vert explicite. La migration se refuse elle-même
-- sans ces conditions (voir les gardes ci-dessous). Inventaire : outils/audits/ORGANISATIONS-ECRITURES-20261031.md
--
-- FIN DE LA DOUBLE AUTORITÉ SUR LES ORGANISATIONS, ÉTAPE A (#295 / #219, 31/10/2026).
-- Une fois les commandes de #219 installées, l'écran n'écrit plus par la sauvegarde générale les
-- champs qu'elles tiennent : nom, devise, avatar, visibilité, demandes d'adhésion, invitations,
-- élection. Une sauvegarde générale encore utilisée par un autre chemin (grève, blocus,
-- militants…) peut porter une copie périmée de ces champs : la garde la remplace par la valeur
-- enregistrée (même principe que la caisse dans organisations_finances_garder), sans refuser
-- l'écriture légitime du reste.
--
-- Hors étape A (chemins sans commande serveur à ce jour, voir l'inventaire) : création, membres
-- PNJ (militants), adhésion supporters, grèves, blocus, mobilisation de police, influence (rumeur),
-- ordres génériques. Les droits INSERT/UPDATE sur `organisations` restent donc accordés ; la
-- fermeture totale (étape B) suivra le portage de ces chemins.

BEGIN;

DO $g$ BEGIN
  IF to_regprocedure('public.organisation_commande_membres(text,text,text,jsonb)') IS NULL
     OR to_regprocedure('public.organisation_commande_administrative(text,text,text,jsonb)') IS NULL
     OR to_regprocedure('public.organisation_commande_evenement(text,text,text,jsonb)') IS NULL THEN
    RAISE EXCEPTION 'contrats_219_absents : installer #219 avant cette migration';
  END IF;
  IF to_regprocedure('public.organisations_finances_garder()') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_organisations_finances_garder' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'garde_finances_absente : 20261031201000 requise';
  END IF;
  IF coalesce(current_setting('hg.feu_vert_organisations', true), '') <> 'parcours_valides' THEN
    RAISE EXCEPTION 'feu_vert_requis : SET LOCAL hg.feu_vert_organisations = ''parcours_valides'' après recette authentifiée';
  END IF;
END $g$;

-- Pas SECURITY DEFINER : la garde s'appuie sur current_user (anon / authenticated = l'écran).
CREATE OR REPLACE FUNCTION public.organisations_champs_commandes_garder() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE v_av jsonb; v_ap jsonb; v_cle text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  IF NEW.data IS NULL OR NOT (NEW.data IS JSON OBJECT) THEN
    RAISE EXCEPTION 'organisation_donnees_illisibles' USING ERRCODE = '42501';
  END IF;
  v_av := CASE WHEN OLD.data IS JSON OBJECT THEN OLD.data::jsonb ELSE '{}'::jsonb END;
  v_ap := NEW.data::jsonb;
  FOREACH v_cle IN ARRAY ARRAY['nom', 'devise', 'avatar', 'visible', 'demandesAdhesion', 'invitationsEnvoyees', 'election'] LOOP
    IF v_av ? v_cle THEN v_ap := jsonb_set(v_ap, ARRAY[v_cle], v_av->v_cle); ELSE v_ap := v_ap - v_cle; END IF;
  END LOOP;
  NEW.data := v_ap::text;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_organisations_champs_commandes_garder ON public.organisations;
CREATE TRIGGER trg_organisations_champs_commandes_garder BEFORE UPDATE ON public.organisations
  FOR EACH ROW EXECUTE FUNCTION public.organisations_champs_commandes_garder();

DO $$ BEGIN
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.organisations_champs_commandes_garder()'::regprocedure) THEN
    RAISE EXCEPTION 'la garde ne doit pas être SECURITY DEFINER';
  END IF;
END $$;

COMMIT;
