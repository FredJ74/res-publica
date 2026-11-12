\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('banc.clinique_acteur','A',false);
DO $$
DECLARE v jsonb; v2 jsonb; v3 jsonb; v4 jsonb; n integer;
BEGIN
 v:=public.clinique_nuitee_reserver();
 IF v->>'ok'<>'true' OR v->>'chambre'<>'chambre_1' THEN RAISE EXCEPTION 'Réservation A : %',v; END IF;
 v2:=public.clinique_nuitee_reserver();
 IF v2->>'deja_reservee'<>'true' THEN RAISE EXCEPTION 'Double réservation A : %',v2; END IF;
 SELECT liquide INTO n FROM public.personnages_donnees WHERE name='A';
 IF n<>350 THEN RAISE EXCEPTION 'Double prélèvement A : %',n; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.locations_actives
   WHERE id='republic:clinique-privee:chambre_1:capitale'
   AND data->>'locataire'='A' AND data->>'reservationClinique'='true')
 THEN RAISE EXCEPTION 'Chambre A absente'; END IF;
 PERFORM set_config('banc.clinique_acteur','B',false);
 v:=public.clinique_nuitee_reserver();
 IF v->>'chambre'<>'chambre_2' THEN RAISE EXCEPTION 'Chambre B : %',v; END IF;
 -- Le repos effectué à l'accueil ne peut pas être transformé après coup en nuitée.
 UPDATE public.personnages_donnees SET pa_repos_le=(now() AT TIME ZONE 'Europe/Paris')::date WHERE name='B';
 UPDATE public.personnages_donnees SET current_room='chambre_2' WHERE name='B';
 v:=public.clinique_nuitee_consommer();
 IF v->>'raison'<>'repos_non_valide' THEN RAISE EXCEPTION 'Dormir ailleurs puis venir à la clinique : %',v; END IF;
 PERFORM set_config('banc.clinique_acteur','C',false);
 v:=public.clinique_nuitee_reserver();
 IF v->>'chambre'<>'chambre_1' THEN RAISE EXCEPTION 'Isolation Sovarka : %',v; END IF;
 PERFORM set_config('banc.clinique_acteur','D',false);
 v:=public.clinique_nuitee_reserver();
 IF v->>'raison'<>'deja_hospitalise' THEN RAISE EXCEPTION 'Hospitalisé accepté : %',v; END IF;
 PERFORM set_config('banc.clinique_acteur','E',false);
 v:=public.clinique_nuitee_reserver();
 IF v->>'raison'<>'fonds_insuffisants' THEN RAISE EXCEPTION 'Insuffisance : %',v; END IF;
 IF EXISTS(SELECT 1 FROM public.locations_actives WHERE data->>'locataire'='E')
 THEN RAISE EXCEPTION 'Occupation sans paiement'; END IF;
 PERFORM set_config('banc.clinique_acteur','F',false);
 UPDATE public.personnages_donnees SET pa_repos_le=(now() AT TIME ZONE 'Europe/Paris')::date WHERE name='F';
 v:=public.clinique_nuitee_reserver();
 IF v->>'raison'<>'deja_dormi' THEN RAISE EXCEPTION 'Réservation après sommeil : %',v; END IF;

 PERFORM set_config('banc.clinique_acteur','A',false);
 v:=public.clinique_nuitee_consommer();
 IF v->>'raison'<>'repos_non_valide' THEN RAISE EXCEPTION 'Bonus avant sommeil : %',v; END IF;
 UPDATE public.personnages_donnees SET current_room='chambre_1',
   pa_repos_le=(now() AT TIME ZONE 'Europe/Paris')::date WHERE name='A';
 v:=public.clinique_nuitee_consommer();
 IF v->>'ok'<>'true' OR (v->>'pa')::int<>12 OR (v->>'hp')::int<>50
   OR (v->>'moral')::int<>33 OR v->>'rejeu'<>'false'
 THEN RAISE EXCEPTION 'Bonus A : %',v; END IF;
 v2:=public.clinique_nuitee_consommer();
 IF v2->>'rejeu'<>'true' THEN RAISE EXCEPTION 'Anti-rejeu A : %',v2; END IF;
 SELECT pa INTO n FROM public.personnages_donnees WHERE name='A';
 IF n<>12 THEN RAISE EXCEPTION 'Double bonus A : %',n; END IF;
 IF EXISTS(SELECT 1 FROM public.locations_actives WHERE data->>'locataire'='A')
 THEN RAISE EXCEPTION 'Chambre A non libérée'; END IF;
END $$;
ROLLBACK;
-- Les fonctions ne sont pas exposées à anon ; seuls les joueurs authentifiés les appellent.
SELECT
 has_function_privilege('anon','public.clinique_nuitee_reserver()','EXECUTE') AS anon_reserver,
 has_function_privilege('authenticated','public.clinique_nuitee_reserver()','EXECUTE') AS joueur_reserver,
 has_function_privilege('anon','public.clinique_nuitee_consommer()','EXECUTE') AS anon_consommer;
