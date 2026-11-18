-- PNJ DE STAROVKA (décisions de Fred, 18/11/2026, nuit ; GAME-DESIGN-NOVOMIRSK.md « PNJ de Starovka :
-- personnalités et référents ») :
--  1. référents (liste fermée pnj_referents, alignée sur PNJ_REFERENTS de plateau-pnj.js) : PNJ en poste
--     et référents désignés ;
--  2. titulaires PNJ renommés : Commandant du Port (Tömör Ochirov → Gleb Ledokolov), commissaire de
--     Starovka (Bato Dashiev → Zhargal Dashiev).
-- Aucune donnée de joueur touchée. Idempotente.
BEGIN;
INSERT INTO public.pnj_referents (referent_id, domaine, pays)
SELECT x.id, x.domaine, 'soviet' FROM (VALUES
  ('sayana_tsydypova', 'démarches municipales — mairie de Starovka'),
  ('tsyren_dorji_bazarov', 'mairie — maire de Starovka (conseiller si un PJ est maire)'),
  ('munko_tsybenov', 'production — adjoint au maire de Starovka, régulation (conseiller si un PJ est adjoint)'),
  ('dugar_tsyrempilov', 'élections de Sovarka — commission électorale de Starovka'),
  ('lieutenant_tsyden_zhalsaraev', 'partis de Sovarka — salle des partis de Starovka'),
  ('erdem_gombozhapov', 'registres des partis — salle des partis de Starovka'),
  ('gleb_ledokolov', 'commerce extérieur — Commandant du Port (conseiller si un PJ est Commandant)'),
  ('stepan_vetrov', 'douanes — expédition, retrait, déclaration au port de Starovka'),
  ('batzorig_dorjiev', 'entrepôt et trading — entrepôt logistique de Starovka (conseiller si un PJ dirige)'),
  ('damdin_mazoutov', 'raffinerie et carburant — raffinerie d''État de Starovka (conseiller si un PJ dirige)'),
  ('dashi_burilov', 'récolte du pétrole — Compagnie nationale, Starovka'),
  ('tuyana_sambueva', 'kolkhoze — magasin du kolkhoze de Starovka'),
  ('saran_batbayar', 'presse — Presse Metel, Starovka'),
  ('saryuna_dorjieva', 'location des locaux — centre artisanal de Starovka'),
  ('arkadi_prigovorov', 'justice — tribunal de Starovka'),
  ('zhargal_dashiev', 'police — commissariat de Starovka'),
  ('darima_zhambalova', 'enseignement — lycée de Starovka'),
  ('gombo_zhigzhitov', 'transport — gare de Starovka'),
  ('viktor_morozko', 'football — Partizan de Starovka')) AS x(id, domaine)
 WHERE NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = x.id);
UPDATE public.titulaires_pnj SET nom_pnj = 'Commandant Gleb Ledokolov (PNJ)'
 WHERE id = 'soviet_capitaine_port_national' AND nom_pnj IS DISTINCT FROM 'Commandant Gleb Ledokolov (PNJ)';
UPDATE public.titulaires_pnj SET nom_pnj = 'Zhargal Dashiev (PNJ)'
 WHERE id = 'soviet_commissaire_ville_a' AND nom_pnj IS DISTINCT FROM 'Zhargal Dashiev (PNJ)';
DO $$ BEGIN
  IF (SELECT count(*) FROM public.pnj_referents WHERE pays = 'soviet' AND referent_id IN (
        'sayana_tsydypova','tsyren_dorji_bazarov','munko_tsybenov','dugar_tsyrempilov','lieutenant_tsyden_zhalsaraev',
        'erdem_gombozhapov','gleb_ledokolov','stepan_vetrov','batzorig_dorjiev','damdin_mazoutov','dashi_burilov',
        'tuyana_sambueva','saran_batbayar','saryuna_dorjieva','arkadi_prigovorov','zhargal_dashiev','darima_zhambalova',
        'gombo_zhigzhitov','viktor_morozko')) <> 19
     OR (SELECT nom_pnj FROM public.titulaires_pnj WHERE id = 'soviet_capitaine_port_national') IS DISTINCT FROM 'Commandant Gleb Ledokolov (PNJ)'
     OR (SELECT nom_pnj FROM public.titulaires_pnj WHERE id = 'soviet_commissaire_ville_a') IS DISTINCT FROM 'Zhargal Dashiev (PNJ)'
  THEN RAISE EXCEPTION 'starovka_pnj_referents : controle structurel en echec'; END IF;
END $$;
COMMIT;
