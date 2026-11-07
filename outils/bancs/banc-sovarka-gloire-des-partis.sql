-- Banc annulé : semaine à la gloire des partis (07/11/2026). À jouer après la migration
-- 20261107121500, dans la même transaction ; l'exception finale annule tout.
DO $banc$
DECLARE t bigint := 4242; r jsonb; c jsonb; g1 text; g2 text; g3 text; g4 text; i integer;
BEGIN
  INSERT INTO organisations(id,country_origine,data,created_at) VALUES
   ('banc_parti_a','soviet','{"id":"banc_parti_a","nom":"Parti A du banc","type":"politique","country":"soviet","chef":"Jean Jaaj","membres":[{"nom":"Jean Jaaj"},{"nom":"Angie Porcelana"}]}', now() - interval '2 days'),
   ('banc_parti_b','soviet','{"id":"banc_parti_b","nom":"Parti B du banc","type":"politique","country":"soviet","chef":"Igor Lebanc (PNJ)","membres":[]}', now() - interval '1 day');
  PERFORM sovarka_gloire_synchroniser();
  SELECT data::jsonb -> 'candidats' INTO c FROM cycles_electoraux WHERE id='soviet_gloire_partis';
  -- A : 2 adhérents PJ + 3 partisans ; B : 0 + 4 partisans -> A gagne 5 contre 4
  FOR i IN 1..3 LOOP INSERT INTO elections_tracts_pnj(cycle_id,tour,pnj_cle,pnj_nom,candidat,sens,effet,joueur)
    VALUES ('soviet_gloire_partis',t,'banc:a'||i,'pnj a'||i,'Parti A du banc',1,1,'Jean Jaaj'); END LOOP;
  FOR i IN 1..4 LOOP INSERT INTO elections_tracts_pnj(cycle_id,tour,pnj_cle,pnj_nom,candidat,sens,effet,joueur)
    VALUES ('soviet_gloire_partis',t,'banc:b'||i,'pnj b'||i,'Parti B du banc',1,1,'Jean Jaaj'); END LOOP;
  r := sovarka_gloire_proclamer(t);
  UPDATE cycles_electoraux SET data = jsonb_set(data::jsonb,'{gloire}', jsonb_build_object('vainqueur', r->>'vainqueur'))::text
   WHERE id='soviet_gloire_partis';
  g1 := coalesce(sovarka_nomination_refus('pm','Arnie',NULL),'permis');
  g2 := coalesce(sovarka_nomination_refus('min_fin','Arnie',NULL),'permis');
  g3 := coalesce(sovarka_nomination_refus('min_fin','Angie Porcelana',NULL),'permis');
  g4 := (SELECT titulaire FROM postes_attribues WHERE id='soviet_pm_national');
  RAISE EXCEPTION 'banc annule | candidats=% | vainqueur=% sieges=% pm=% | registre pm=% | pm par president=% | ministre hors parti=% | ministre du parti=%',
    (SELECT string_agg(e->>'nom', ', ') FROM jsonb_array_elements(c) e),
    r->>'vainqueurNom', r->'sieges', r->'pm', g4, g1, g2, g3;
END $banc$;
