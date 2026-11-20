-- Banc lecture seule : rues initiales des six villes + refus de saut à Krasnov.
DO $test$
DECLARE pays text; ville text; depart text; ok jsonb;
BEGIN
 FOR pays, ville, depart IN
   SELECT * FROM (VALUES
    ('republic','capitale','luthecia-palais-presidentiel'),
    ('republic','ville_a','psm-centre-multimodal'),
    ('republic','ville_b','montrouge-vue-3'),
    ('soviet','capitale','novomirsk-vue-1'),
    ('soviet','ville_a','starovka-rue-gare'),
    ('soviet','ville_b','krasnov-rue-gare')
   ) AS t(pays, ville, depart)
 LOOP
   ok:=public.navigation_rue_trajet_interne(pays, ville, NULL, NULL, depart);
   IF ok->>'ok' IS DISTINCT FROM 'true' THEN
     RAISE EXCEPTION 'Départ initial refusé %/%/% : %', pays, ville, depart, ok;
   END IF;
 END LOOP;
 ok:=public.navigation_rue_trajet_interne('soviet','ville_b',NULL,NULL,'krasnov-rue-entrepot');
 IF ok->>'raison' IS DISTINCT FROM 'position_initiale_invalide' THEN
   RAISE EXCEPTION 'Le saut de la gare vers l’entrepôt est autorisé : %',ok;
 END IF;
 ok:=public.navigation_rue_trajet_interne('soviet','ville_b',NULL,NULL,'montrouge-vue-3');
 IF ok->>'raison' IS DISTINCT FROM 'noeud_inconnu' THEN
   RAISE EXCEPTION 'Un noeud de Républia est autorisé à Krasnov : %',ok;
 END IF;
END $test$;
