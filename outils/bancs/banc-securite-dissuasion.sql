-- Banc annule de 20261103003000_securite_dissuasion_hommes_armes (#135, dissuasion).
-- A jouer APRES la migration, dans la meme transaction ; tout est annule par l'exception finale.
-- PNJ fictifs « banc-dissuasion-* » ; aucun PJ reel modifie (lecture de leur position seulement).
DO $$
DECLARE r text := ''; a0 int; a1 int; a2 int; a3 int; j0 int; j1 int; n int;
BEGIN
  a0 := public.securite_malus_lieu_interne('Angie Porcelana');
  INSERT INTO public.pnj_membres (id, famille, nom, pays, position_pays, proprietaire_pj, ville, rue_noeud_id, pa, statut, car_per, car_vol)
  VALUES ('banc-dissuasion-1','employe','Agent banc 1','republic','republic','Jean Jaaj','ville_a','psm-tribunal-banque',5,'actif',10,10);
  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle) VALUES ('banc-dissuasion-1','agent_securite','Agent de sécurité');
  a1 := public.securite_malus_lieu_interne('Angie Porcelana');
  INSERT INTO public.pnj_membres (id, famille, nom, pays, position_pays, proprietaire_pj, ville, rue_noeud_id, pa, statut, car_per, car_vol)
  VALUES ('banc-dissuasion-2','employe','Agent banc 2','republic','republic','Jean Jaaj','ville_a','psm-tribunal-banque',5,'actif',10,10);
  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle) VALUES ('banc-dissuasion-2','maitre_chien','Maître-chien');
  a2 := public.securite_malus_lieu_interne('Angie Porcelana');
  -- L'agent de l'auteur lui-meme ne le gene pas.
  INSERT INTO public.pnj_membres (id, famille, nom, pays, position_pays, proprietaire_pj, ville, rue_noeud_id, pa, statut, car_per, car_vol)
  VALUES ('banc-dissuasion-3','employe','Agent banc 3','republic','republic','Angie Porcelana','ville_a','psm-tribunal-banque',5,'actif',10,10);
  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle) VALUES ('banc-dissuasion-3','agent_securite','Agent de sécurité');
  a3 := public.securite_malus_lieu_interne('Angie Porcelana');
  -- En interieur : Jean Jaaj dans l'arriere-boutique, agent d'Angie present.
  j0 := public.securite_malus_lieu_interne('Jean Jaaj');
  UPDATE public.pnj_membres SET ville='capitale', rue_noeud_id=NULL, building_id='centre-commercial', room_id='arriere_boutique'
   WHERE id='banc-dissuasion-3';
  j1 := public.securite_malus_lieu_interne('Jean Jaaj');
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
   WHERE s.nspname='public' AND position('securite_dissuasion' IN pg_get_functiondef(p.oid))>0 AND p.proname<>'securite_malus_lieu_interne';
  r := format('angie rue: vide=%s, 1 agent=%s (attendu 11), 2 agents=%s (12), + le sien=%s (12) | jean piece: avant=%s, agent d''Angie=%s (avant+1 ou 11) | fonctions raccordees=%s (12)',
              a0, a1, a2, a3, j0, j1, n);
  RAISE EXCEPTION 'BANC (annule) : %', r;
END $$;
