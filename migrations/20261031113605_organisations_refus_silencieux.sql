-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019132908_organisations_refus_silencieux.sql ; aucun changement de règle.
-- PREPARE : un trigger BEFORE ... RETURN NULL est un refus, jamais un succes.
-- Lacune reproduite localement ; adaptations gardees des commandes existantes.
-- Apres administratif + membres + progression electorale ; aucun droit historique ferme.
BEGIN;
DO $garde$
DECLARE r record; source text; nouveau text; definition text; signature regprocedure;
BEGIN
 FOR r IN SELECT * FROM (VALUES ('organisation_commande_administrative','7b1e697f28ea882fde5809d152d774ca','28e6b0f633552251a70b1893cb5df55a'),('organisation_commande_membres','28286d902e7a89f9f3c47b98664ce885','51bf628916b6d22d4bc04360c2fa1fde')) v(nom,avant,apres) LOOP
  signature:=to_regprocedure('public.'||r.nom||'(text,text,text,jsonb)');
  SELECT prosrc INTO source FROM pg_proc WHERE oid=signature;
  IF source IS NULL THEN RAISE EXCEPTION 'commande_absente: %',r.nom; END IF;
  IF md5(source)=r.apres THEN CONTINUE; END IF;
  IF md5(source)<>r.avant THEN RAISE EXCEPTION 'commande_definition_a_reexaminer: %',r.nom; END IF;
  nouveau:=replace(source,'UPDATE public.organisations SET data=d::text WHERE id=p_organisation;',
   E'UPDATE public.organisations SET data=d::text WHERE id=p_organisation;\n IF NOT FOUND THEN RAISE EXCEPTION ''organisation_non_enregistree''; END IF;');
  nouveau:=replace(nouveau,'DELETE FROM public.organisations WHERE id=p_organisation;',
   E'DELETE FROM public.organisations WHERE id=p_organisation;\n IF NOT FOUND THEN RAISE EXCEPTION ''dissolution_non_enregistree''; END IF;');
  nouveau:=replace(nouveau,'VALUES(p_requete,acteur,p_organisation,commande,resultat);',
   E'VALUES(p_requete,acteur,p_organisation,commande,resultat);\n IF NOT FOUND THEN RAISE EXCEPTION ''recu_non_insere''; END IF;');
  IF md5(nouveau)<>r.apres THEN RAISE EXCEPTION 'transformation_commande_inattendue: %',r.nom; END IF;
  definition:=pg_get_functiondef(signature);
  EXECUTE replace(definition,source,nouveau);
 END LOOP;
END;
$garde$;
COMMIT;
