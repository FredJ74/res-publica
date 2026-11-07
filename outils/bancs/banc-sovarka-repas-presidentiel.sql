-- Banc annulé : repas présidentiel de Sovarka (07/11/2026). Après la migration 20261107124500,
-- dans la même transaction ; l'exception finale annule tout.
DO $banc$
DECLARE uj uuid; ua uuid; r0 jsonb; r1 jsonb; r2 jsonb; r3 jsonb; av record; ap record; avi record; api record;
BEGIN
  DELETE FROM sovarka_repas_presidentiels;
  UPDATE cycles_electoraux SET data = jsonb_set(data::jsonb,'{eluId}','"Jean Jaaj"')::text WHERE id='soviet_president';
  UPDATE personnages_donnees SET country='soviet', current_city='capitale', current_building='palais-presidentiel',
         current_room='appartements_president', hp=50, moral=50 WHERE name IN ('Jean Jaaj','Angie Porcelana','Arnie');
  SELECT hp, moral, resources->>'inf' inf, bonus_pa_differe b INTO av FROM personnages_donnees WHERE name='Jean Jaaj';
  SELECT hp, moral, resources->>'inf' inf, bonus_pa_differe b INTO avi FROM personnages_donnees WHERE name='Angie Porcelana';
  SELECT user_id INTO uj FROM personnages_donnees WHERE name='Jean Jaaj';
  SELECT user_id INTO ua FROM personnages_donnees WHERE name='Arnie';
  SET LOCAL ROLE authenticated;
  -- Sans ce chemin, personnages_fusionner_pop retient l'INF (appel client hors RPC).
  PERFORM set_config('request.path', '/rpc/sovarka_repas_presidentiel', true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub',ua,'role','authenticated')::text, true);
  r0 := sovarka_repas_presidentiel('banc-0', NULL);
  PERFORM set_config('request.jwt.claims', json_build_object('sub',uj,'role','authenticated')::text, true);
  r1 := sovarka_repas_presidentiel('banc-1', 'Angie Porcelana');
  r2 := sovarka_repas_presidentiel('banc-1', 'Angie Porcelana');
  r3 := sovarka_repas_presidentiel('banc-2', NULL);
  RESET ROLE;
  SELECT hp, moral, resources->>'inf' inf, bonus_pa_differe b INTO ap FROM personnages_donnees WHERE name='Jean Jaaj';
  SELECT hp, moral, resources->>'inf' inf, bonus_pa_differe b INTO api FROM personnages_donnees WHERE name='Angie Porcelana';
  RAISE EXCEPTION 'banc annule | non president=% | repas=% | rejeu=% | second repas=% | Jean hp % -> %, moral % -> %, inf % -> %, bonus % -> % | Angie hp % -> %, inf % -> %, bonus % -> %',
    r0->>'raison', r1->>'ok', r2->>'rejeu', r3->>'raison', av.hp, ap.hp, av.moral, ap.moral, av.inf, ap.inf, av.b, ap.b,
    avi.hp, api.hp, avi.inf, api.inf, avi.b, api.b;
END $banc$;
