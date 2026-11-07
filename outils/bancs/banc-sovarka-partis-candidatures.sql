-- Banc annulé : partis de Sovarka et candidatures (07/11/2026). Jouer après la migration, dans la même transaction ; rien ne reste.
DO $banc$
DECLARE u uuid; r1 jsonb; r2 jsonb; r3 jsonb; p0 text; p1 text;
BEGIN
  SELECT user_id INTO u FROM personnages_donnees WHERE name='Jean Jaaj';
  UPDATE personnages_donnees SET country='soviet', poste=NULL,
         domicile = coalesce(domicile,'{}'::jsonb) || '{"country":"soviet"}'::jsonb,
         resources = coalesce(resources,'{}'::jsonb) || '{"inf":99}'::jsonb
   WHERE name='Jean Jaaj';
  p0 := sovarka_parti_de('Jean Jaaj');
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true);
  r1 := candidature_deposer('president', NULL, NULL, '{"nom":"Jean Jaaj"}'::jsonb);
  r2 := candidature_deposer('depute', 'capitale', NULL, '{"nom":"Jean Jaaj"}'::jsonb);
  RESET ROLE;
  INSERT INTO organisations(id,country_origine,data,created_at)
  VALUES ('banc_parti','soviet', '{"id":"banc_parti","nom":"Parti du banc","type":"politique","country":"soviet","chef":"Personne","membres":[{"nom":"Jean Jaaj","grade":"Militant"}]}', now());
  p1 := sovarka_parti_de('Jean Jaaj');
  SET LOCAL ROLE authenticated;
  r3 := candidature_deposer('president', NULL, NULL, '{"nom":"Jean Jaaj"}'::jsonb);
  RAISE EXCEPTION 'banc annule | parti avant=% apres=% | sans parti=% | depute=% | avec parti=%',
    p0, p1, r1->>'raison', r2->>'raison', coalesce(r3->>'raison','ok');
END $banc$;
