-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261028205154.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028205154.
-- Eprouvee au role authenticated en transaction annulee : acte citoyen (1 PA + 50), doublon refusé, fiche historique et fiche PJ, personne inconnue refusée.
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Suite obligatoire de 20261027214000 (catalogue et dates).
CREATE OR REPLACE FUNCTION public.etat_civil_document_recevoir(p_requete uuid,p_nom text,p_type text,p_reference text,p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET TimeZone TO 'UTC' AS $function$
DECLARE a public.personnages_donnees; v jsonb; o jsonb; params jsonb; paiement jsonb;
 dt timestamptz; ville text; titre text; texte text; cle text; ordre text; cout integer;
 m public.mariages; s public.successions; d jsonb; e record; evenements jsonb:='[]'; conjoint text; motif text; devise text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR nullif(p_nom,'') IS NULL OR p_type IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 params:=jsonb_build_object('nom',p_nom,'type',p_type,'reference',p_reference,'pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'etat_civil',params);IF v IS NOT NULL THEN RETURN v;END IF;
 IF (p_type IN('naissance','deces','fiche') AND nullif(p_reference,'') IS NOT NULL) OR (p_type IN('mariage','succession') AND nullif(p_reference,'') IS NULL) THEN RETURN jsonb_build_object('ok',false,'raison','reference_invalide');END IF;
 IF p_type='fiche' THEN
  IF (a.current_building IN('mairie','mairie-capitale') AND a.current_room='salle_archives') IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  IF p_pa IS DISTINCT FROM 0 OR p_cost IS DISTINCT FROM 0 THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
  SELECT objet INTO o FROM public.objets_modeles WHERE id='fiche_historique:'||a.country||':'||p_nom;
 ELSE
  IF a.current_building='office-notarial' AND a.current_room='bureau_contrats' THEN ordre:='acte_officiel_notaire';cout:=100;
  ELSIF a.current_building IN('mairie','mairie-capitale') AND a.current_room='bureau_maire_adjoint'
    AND a.poste->>'id'='maire_adjoint' AND a.poste->>'city'=a.current_city
    AND public.poste_est_atteste(a.name,a.poste,a.country) THEN ordre:='acte_officiel_mairie';cout:=0;
  ELSIF a.current_building IN('tribunal','tribunal-local') AND a.current_room='bureau_magistrats'
    AND a.poste->>'id'='juge' AND (a.poste->>'city' IS NULL OR a.poste->>'city'=a.current_city)
    AND public.poste_est_atteste(a.name,a.poste,a.country) THEN ordre:='acte_officiel_juge';cout:=0;
  ELSIF a.current_building IN('mairie','mairie-capitale') AND a.current_room IN('hall_mairie','accueil_mairie') AND p_nom=a.name THEN ordre:='acte_officiel';cout:=50; -- 28/10/2026 : tarif du jeu (1 PA + 50)
  ELSE RETURN jsonb_build_object('ok',false,'raison','lieu_ou_autorite_refuse');END IF;
  IF p_pa IS DISTINCT FROM 1 OR p_cost IS DISTINCT FROM cout THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
 END IF;
 IF p_type IN('naissance','fiche') AND o IS NULL THEN
  SELECT coalesce((SELECT created_at FROM public.personnages_donnees WHERE name=p_nom),created_at),public.etat_civil_ville_interne(a.country,city)
  INTO dt,ville FROM public.etat_civil_naissances WHERE nom=p_nom AND country=a.country LIMIT 1;
  IF dt IS NULL THEN SELECT created_at INTO dt FROM public.personnages_donnees WHERE name=p_nom;END IF;
  IF dt IS NOT NULL THEN
   titre:='Extrait d''acte de naissance';texte:=E'EXTRAIT D''ACTE DE NAISSANCE\n\n'||p_nom||', né(e) le '||public.etat_civil_date_interne(dt)||coalesce(' à '||ville,'')||'.';
   evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM dt),'texte',public.etat_civil_date_interne(dt)||' : naissance de '||p_nom||coalesce(', née à '||ville,'')||'.'));
  END IF;
 END IF;
 IF p_type IN('mariage','fiche') AND o IS NULL THEN
  FOR m IN SELECT * FROM public.mariages WHERE country=a.country AND (conjoint1=p_nom OR conjoint2=p_nom) AND (p_type='fiche' OR id=p_reference) ORDER BY created_at,id LOOP
   IF m.created_at IS NULL THEN CONTINUE;END IF;
   conjoint:=CASE WHEN m.conjoint1=p_nom THEN m.conjoint2 ELSE m.conjoint1 END;ville:=public.etat_civil_ville_interne(a.country,m.city);
   titre:='Extrait d''acte de mariage — '||conjoint;
   texte:=E'EXTRAIT D''ACTE DE MARIAGE\n\n'||p_nom||' et '||conjoint||', union célébrée le '||public.etat_civil_date_interne(m.created_at)||coalesce(' à '||ville,'')||'.';
   evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM m.created_at),'texte',public.etat_civil_date_interne(m.created_at)||' : mariage de '||p_nom||' avec '||conjoint||coalesce(', célébré à '||ville,'')||'.'));
   IF m.statut='dissous' THEN
    motif:=CASE WHEN to_jsonb(m)->>'raison_dissolution'='veuvage' THEN 'veuvage' ELSE 'divorce' END;
    texte:=texte||E'\n\nUnion dissoute ('||motif||').';
    evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM m.created_at),'texte','Union avec '||conjoint||' dissoute ('||motif||').'));
   END IF;
  END LOOP;
 END IF;
 IF p_type IN('deces','fiche') AND o IS NULL THEN
  FOR e IN SELECT created_at,city FROM public.etat_civil_deces WHERE nom=p_nom AND country=a.country ORDER BY created_at LIMIT 1 LOOP
   IF e.created_at IS NULL THEN CONTINUE;END IF;ville:=public.etat_civil_ville_interne(a.country,e.city);
   titre:='Extrait d''acte de décès';texte:=E'EXTRAIT D''ACTE DE DÉCÈS\n\n'||p_nom||', décédé(e) le '||public.etat_civil_date_interne(e.created_at)||coalesce(' à '||ville,'')||'.';
   evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM e.created_at),'texte',public.etat_civil_date_interne(e.created_at)||' : décès de '||p_nom||coalesce(' à '||ville,'')||'.'));
  END LOOP;
 END IF;
 IF p_type='succession' THEN
  SELECT * INTO s FROM public.successions WHERE id=p_reference AND country=a.country AND statut='resolue';
  IF FOUND THEN
   devise:=CASE a.country WHEN 'republic' THEN 'FR' WHEN 'narco' THEN 'PS' WHEN 'soviet' THEN 'RP' WHEN 'khalija' THEN 'DR' END;
   titre:='Acte de succession — '||s.defunt;
   FOR d IN SELECT value FROM jsonb_array_elements(s.dispositions) WHERE value->'resultat'->>'beneficiaire'=p_nom LOOP
    texte:=coalesce(texte,E'ACTE DE SUCCESSION\n\nSuccession de '||s.defunt||E', réglée.\nBénéficiaire : '||p_nom||E'\n\n')||
    CASE WHEN d->>'type'='argent' THEN '- Somme nette perçue : '||coalesce(d->>'part_nette','0')||' '||devise
    ELSE '- '||CASE WHEN d->>'type'='terrain' THEN 'Terrain' ELSE 'Entreprise' END||' : '||coalesce(d->>'libelle',d->>'id') END||E'\n';
   END LOOP;
  END IF;
 END IF;
 IF p_type='fiche' THEN
  IF o IS NULL AND (NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_nom) OR jsonb_array_length(evenements)=0) THEN RETURN jsonb_build_object('ok',false,'raison','personne_introuvable');END IF;
  IF o IS NULL THEN SELECT jsonb_build_object('name','Fiche d''état-civil — '||p_nom,'icon','ti-file-text','desc',string_agg(x.e->>'texte','<br><br>' ORDER BY (x.e->>'annee')::integer,x.n)) INTO o FROM jsonb_array_elements(evenements) WITH ORDINALITY x(e,n);END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(a.inventory) i WHERE i->>'name'=o->>'name') THEN RETURN jsonb_build_object('ok',false,'raison','deja_possede');END IF;
  o:=o||jsonb_build_object('id','fiche-etat-civil-'||gen_random_uuid());
 ELSE
  IF titre IS NULL OR texte IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acte_introuvable');END IF;
  cle:='acte-'||p_type||'-'||lower(regexp_replace(p_nom,'[[:space:]]+','-','g'))||CASE WHEN nullif(p_reference,'') IS NULL THEN '' ELSE '-'||lower(regexp_replace(p_reference,'[[:space:]]+','-','g')) END;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(a.inventory) i WHERE i->>'acteCle'=cle) THEN RETURN jsonb_build_object('ok',false,'raison','deja_possede');END IF;
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='acte:'||p_type;
  o:=o||jsonb_build_object('acteCle',cle,'name',titre,'concerne',p_nom,'desc',rtrim(texte,E'\n'));
 END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 IF p_type<>'fiche' THEN paiement:=public.payer_ordre(a.name,ordre,p_pa,p_cost);IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement;END IF;END IF;
 v:=public.inventaire_deposer_interne(a.name,o);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'etat civil: depot refuse';END IF;
 v:=v||jsonb_build_object('objet',o->>'name','paie',paiement);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'etat_civil',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.etat_civil_document_recevoir(uuid,text,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.etat_civil_document_recevoir(uuid,text,text,text,integer,integer) TO authenticated;
