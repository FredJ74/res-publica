-- Banc annulé : désignation des députés du Soviet Suprême (07/11/2026). Après la migration
-- 20261107123000, dans la même transaction ; l'exception finale annule tout.
DO $banc$
DECLARE u uuid; r1 jsonb; r2 jsonb; r3 jsonb; r4 jsonb; r5 jsonb; e jsonb; dep1 jsonb; dep2 jsonb;
BEGIN
  INSERT INTO organisations(id,country_origine,data,created_at) VALUES
   ('banc_parti_a','soviet','{"id":"banc_parti_a","nom":"Parti A du banc","type":"politique","country":"soviet","chef":"Jean Jaaj","membres":[{"nom":"Jean Jaaj"},{"nom":"Angie Porcelana"}]}', now());
  UPDATE cycles_electoraux SET data = jsonb_set(data::jsonb,'{gloire}','{"sieges":{"banc_parti_a":1}}')::text WHERE id='soviet_gloire_partis';
  UPDATE personnages_donnees SET country='soviet', current_building='assemblee' WHERE name='Jean Jaaj';
  UPDATE personnages_donnees SET poste_depute=NULL WHERE name IN ('Angie Porcelana','Jean Jaaj');
  SELECT user_id INTO u FROM personnages_donnees WHERE name='Jean Jaaj';
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true);
  r1 := sovarka_depute_designer('Arnie');
  r2 := sovarka_depute_designer('Angie Porcelana');
  r3 := sovarka_depute_designer('Jean Jaaj');
  e := sovarka_soviet_etat();
  RESET ROLE;
  SELECT poste_depute INTO dep1 FROM personnages_donnees WHERE name='Angie Porcelana';
  r5 := sovarka_gloire_proclamer(1);
  SELECT poste_depute INTO dep2 FROM personnages_donnees WHERE name='Angie Porcelana';
  RAISE EXCEPTION 'banc annule | hors parti=% | Angie=% | siege en trop=% | etat chef=% deputes=% | fiche apres=% | apres proclamation=%',
    r1->>'raison', coalesce(r2->>'raison','ok'), r3->>'raison', e->>'chef', e->'deputes', dep1->>'name', coalesce(dep2::text,'aucun siege');
END $banc$;
