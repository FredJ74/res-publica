-- Banc : chambres des hôpitaux de Sovarka (migration 20261113020000), 13/11/2026.
-- Coller la migration à l'endroit marqué ; finit TOUJOURS par une exception : rien ne reste.
-- Joué vert le 13/11 avant application (Starovka chambre, Novomirsk chambre, Républia salle d'attente).
-- >>> MIGRATION 20261113020000_hopitaux_sovarka_chambre.sql ICI <<<
DO $banc$
DECLARE v jsonb;
BEGIN
  UPDATE public.personnages_donnees SET country='soviet', current_city='ville_a', est_emprisonne=NULL,
    hospitalisation=jsonb_build_object('lieu','dispensaire','dateFinParis','2099-01-01') WHERE name='Arnie';
  v := public.hospitalisation_lieu_rejoindre_interne('Arnie','dispensaire',NULL,true,false);
  IF v->>'room' IS DISTINCT FROM 'chambre' THEN RAISE EXCEPTION 'ECHEC Starovka %', v; END IF;
  UPDATE public.personnages_donnees SET current_city='capitale' WHERE name='Arnie';
  v := public.hospitalisation_lieu_rejoindre_interne('Arnie','dispensaire',NULL,true,false);
  IF v->>'room' IS DISTINCT FROM 'chambre' THEN RAISE EXCEPTION 'ECHEC Novomirsk %', v; END IF;
  UPDATE public.personnages_donnees SET country='republic' WHERE name='Arnie';
  v := public.hospitalisation_lieu_rejoindre_interne('Arnie','dispensaire',NULL,true,false);
  IF v->>'room' IS DISTINCT FROM 'salle_attente' THEN RAISE EXCEPTION 'ECHEC Republia %', v; END IF;
  RAISE EXCEPTION 'BANC VERT (annulé) : Starovka chambre, Novomirsk chambre, Républia salle d''attente';
END $banc$;
