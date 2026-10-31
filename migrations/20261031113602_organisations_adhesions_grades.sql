-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019130213_organisations_adhesions_grades.sql ; aucun changement de règle.
-- PREPARE : depend du registre administratif ; aucun droit historique ferme ici.
BEGIN;
DO $garde$
DECLARE r record;
BEGIN
 IF obj_description(to_regclass('public.organisation_commandes_recus'),'pg_class') IS DISTINCT FROM 'HG commandes administratives v1' THEN RAISE EXCEPTION 'registre_administratif_requis'; END IF;
 FOR r IN SELECT * FROM (VALUES ('organisation_regles_membres','df3b26e2b7db1d7d3d3b0241a70216c8'),('organisation_commande_membres','a0e36e3ff683225c12a38e6bb2e7df0b')) v(nom,empreinte) LOOP
  IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=r.nom AND md5(p.prosrc)<>r.empreinte) THEN RAISE EXCEPTION 'membres_definition_a_reexaminer: %',r.nom; END IF;
 END LOOP;
END;
$garde$;
-- DEBUT REGLES GENEREES
CREATE OR REPLACE FUNCTION public.organisation_regles_membres() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $regles$
 SELECT '{"politique":{"grades":{"republic":["Sympathisant","Militant","Cadre","Secrétaire Général"],"narco":["Seguidor","Activista","Líder Local","Jefe Supremo"],"soviet":["Camarade","Activiste","Commissaire","Secrétaire du Parti"],"khalija":["Partisan","Conseiller","Vizir","Grand Vizir"]},"maxAdhesion":1},"religieuse":{"grades":{"republic":["Novice","Diacre","Pretre","Grand Pontife"],"narco":["Croyant","Reverend","Archeveque","El Profeta"],"soviet":["Camarade Croyant","Lecteur du Parti","Prophete du Kolkhoze","Grand Oracle"],"khalija":["Etudiant","Imam","Grand Mufti","Ayatollah Supreme"]},"maxAdhesion":1},"syndicale":{"grades":{"republic":["Adherent","Delegue","Secretaire Adjoint","Secretaire General"],"narco":["Adherent","Delegue","Secretaire Adjoint","Secretaire General"],"soviet":["Camarade","Delegue Ouvrier","Commissaire Syndical","Secretaire General"],"khalija":["Adherent","Delegue","Secretaire Adjoint","Secretaire General"]},"maxAdhesion":1},"economique":{"grades":{"republic":["Actionnaire","Directeur","PDG","President du Conseil"],"narco":["Investisseur","Gerant","Patron","El Patron Economico"],"soviet":["Cooperateur","Directeur de Plan","Commissaire Economique","Ministre de l''Abondance"],"khalija":["Associe","Directeur","Cheikh des Affaires","Sultan Economique"]},"maxAdhesion":1},"criminelle":{"grades":{"republic":["Affilie","Soldat","Capo","Parrain"],"narco":["Sicario","Teniente","Comandante","El Jefe"],"soviet":["Homme de main","Brigadier","Vor","Pakhan"],"khalija":["Sbire","Lieutenant","Emir de l''ombre","Calife de l''obscurite"]},"maxAdhesion":1},"loge":{"grades":{"republic":["Apprenti","Compagnon","Maitre","Grand Maitre"],"narco":["Iniciado","Hermano","Maestro","Gran Maestro"],"soviet":["Apprenti du Parti","Frere Collectif","Maitre Sovietique","Grand Architecte"],"khalija":["Murid","Ikhwan","Sheikh","Grand Sheikh"]},"maxAdhesion":1},"mediatique":{"grades":{"republic":["Correspondant","Journaliste","Redacteur en chef","Directeur de Publication"],"narco":["Informateur","Reporter","Editeur","Patron des Medias"],"soviet":["Propagandiste","Redacteur","Chef de la Pravda","Commissaire a l''Information"],"khalija":["Conteur","Chroniqueur","Editorialiste","Grand Orateur du Sheikh"]},"maxAdhesion":1},"sportive":{"grades":{"republic":["Junior","Titulaire","Capitaine","Legende"],"narco":["Cadete","Titular","Capitan","Leyenda"],"soviet":["Espoir du Peuple","Titulaire","Capitaine du Kolkhoze","Legende Sportive"],"khalija":["Espoir","Titulaire","Capitaine","Legende du Sheikh"]},"maxAdhesion":1},"supporters":{"grades":{"republic":["Sympathisant","Membre","Ultra","Meneur"],"narco":["Simpatizante","Miembro","Ultra","Cabecilla"],"soviet":["Sympathisant","Membre du Kop","Ultra","Meneur de Foule"],"khalija":["Sympathisant","Membre","Ultra","Meneur"]},"maxAdhesion":1}}'::jsonb;
$regles$;
REVOKE ALL ON FUNCTION public.organisation_regles_membres() FROM PUBLIC,anon,authenticated;
-- FIN REGLES GENEREES
CREATE OR REPLACE FUNCTION public.organisation_commande_membres(p_requete text,p_organisation text,p_action text,p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text; d jsonb; avant jsonb; cible text; jour integer; pays text;
 regles jsonb; grades jsonb; idx integer; membre jsonb; liste text; decision jsonb;
 commande jsonb; rec public.organisation_commandes_recus; resultat jsonb;
BEGIN
 acteur:=public.mon_personnage();
 IF acteur IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 IF p_requete IS NULL OR p_requete !~ '^orgcmd-[A-Za-z0-9-]{6,80}$' OR p_organisation IS NULL OR
 p_parametres IS NULL OR jsonb_typeof(p_parametres)<>'object' THEN RAISE EXCEPTION 'commande_invalide'; END IF;
 SELECT data::jsonb INTO d FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('orgcmd:'||p_requete,0));
 commande:=jsonb_build_object('action',p_action,'parametres',p_parametres);
 SELECT * INTO rec FROM public.organisation_commandes_recus WHERE requete=p_requete;
 IF FOUND THEN
  IF rec.acteur<>acteur OR rec.organisation<>p_organisation OR rec.commande<>commande THEN RAISE EXCEPTION 'requete_reutilisee' USING ERRCODE='42501'; END IF;
  RETURN (rec.resultat-'organisation')||jsonb_build_object('rejeu',true);
 END IF;
 IF d IS NULL THEN RAISE EXCEPTION 'organisation_absente'; END IF;
 avant:=d;pays:=coalesce(d->>'country_origine',d->>'country');
 regles:=public.organisation_regles_membres()->(d->>'type');
 IF regles IS NULL THEN RAISE EXCEPTION 'type_non_reconnu'; END IF;
 grades:=regles->'grades'->pays;
 IF grades IS NULL THEN RAISE EXCEPTION 'grades_non_definis'; END IF;
 SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name=acteur;
 IF jour IS NULL THEN RAISE EXCEPTION 'personnage_absent'; END IF;
 cible:=p_parametres->>'nom';
 IF p_action IN ('demander','accepter_invitation','refuser_invitation') THEN
  IF p_parametres<>'{}' THEN RAISE EXCEPTION 'champs_interdits'; END IF;cible:=acteur;
 ELSE
  IF p_parametres-ARRAY['nom']<>'{}' OR cible IS NULL THEN RAISE EXCEPTION 'cible_requise'; END IF;
  IF d->>'chef' IS DISTINCT FROM acteur THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
 END IF;
 IF p_action IN ('demander','admettre','accepter_invitation') THEN
  -- Serialiser les admissions concurrentes du meme personnage, meme entre organisations.
  PERFORM pg_advisory_xact_lock(hashtextextended('orgmembre:'||cible,0));
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'deja_membre'; END IF;
  IF (SELECT count(*) FROM public.organisations o WHERE coalesce(o.data::jsonb->>'country_origine',o.data::jsonb->>'country')=pays
    AND o.data::jsonb->>'type'=d->>'type' AND EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(o.data::jsonb->'membres','[]')) m WHERE m->>'nom'=cible)) >= (regles->>'maxAdhesion')::integer THEN
   RAISE EXCEPTION 'limite_adhesion'; END IF;
 END IF;
 IF p_action='demander' THEN
  IF coalesce((d->>'visible')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'invitation_requise'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'demandesAdhesion','[]')) m WHERE m->>'nom'=acteur) THEN RAISE EXCEPTION 'demande_en_cours'; END IF;
  d:=jsonb_set(d,'{demandesAdhesion}',coalesce(d->'demandesAdhesion','[]')||jsonb_build_array(jsonb_build_object('nom',acteur,'date',jour)));
 ELSIF p_action IN ('admettre','refuser_demande','accepter_invitation','refuser_invitation') THEN
  liste:=CASE WHEN p_action IN ('admettre','refuser_demande') THEN 'demandesAdhesion' ELSE 'invitationsEnvoyees' END;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->liste,'[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'demande_ou_invitation_absente'; END IF;
  d:=jsonb_set(d,ARRAY[liste],coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(d->liste) m WHERE m->>'nom' IS DISTINCT FROM cible),'[]'));
  IF p_action IN ('admettre','accepter_invitation') THEN
   membre:=jsonb_build_object('nom',cible,'grade',grades->>0,'gradeIdx',0,'rejointLe',jour);
   d:=jsonb_set(d,'{membres}',coalesce(d->'membres','[]')||jsonb_build_array(membre));
  END IF;
 ELSIF p_action IN ('promouvoir','retrograder') THEN
  SELECT m INTO membre FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible;
  IF membre IS NULL THEN RAISE EXCEPTION 'membre_absent'; END IF;
  idx:=(membre->>'gradeIdx')::integer+CASE WHEN p_action='promouvoir' THEN 1 ELSE -1 END;
  IF idx IS NULL OR idx<0 OR idx>=jsonb_array_length(grades) THEN RAISE EXCEPTION 'grade_limite'; END IF;
  membre:=membre||jsonb_build_object('gradeIdx',idx,'grade',grades->>idx);
  d:=jsonb_set(d,'{membres}',(SELECT jsonb_agg(CASE WHEN m->>'nom'=cible THEN membre ELSE m END ORDER BY ord)
    FROM jsonb_array_elements(d->'membres') WITH ORDINALITY e(m,ord)));
 ELSE RAISE EXCEPTION 'action_non_migree'; END IF;
 IF d-ARRAY['membres','demandesAdhesion','invitationsEnvoyees'] IS DISTINCT FROM avant-ARRAY['membres','demandesAdhesion','invitationsEnvoyees'] THEN RAISE EXCEPTION 'etat_hors_commande'; END IF;
 UPDATE public.organisations SET data=d::text WHERE id=p_organisation;
 resultat:=jsonb_build_object('ok',true,'organisation',d);
 INSERT INTO public.organisation_commandes_recus(requete,acteur,organisation,commande,resultat) VALUES(p_requete,acteur,p_organisation,commande,resultat);
 RETURN resultat;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_commande_membres(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organisation_commande_membres(text,text,text,jsonb) TO authenticated;
COMMIT;
