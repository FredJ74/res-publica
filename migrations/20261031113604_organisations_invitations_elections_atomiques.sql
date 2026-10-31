-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019132431_organisations_invitations_elections_atomiques.sql ; aucun changement de règle.
-- PREPARE, non applique. Lacune : invitation/mail et paiement/election/forum
-- etaient des ecritures separees. Orchestration des contrats existants, sans moteur financier neuf.
BEGIN;
DO $garde$
BEGIN
 IF obj_description(to_regclass('public.organisation_commandes_recus'),'pg_class') IS DISTINCT FROM 'HG commandes administratives v1' THEN RAISE EXCEPTION 'registre_administratif_requis'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='organisation_commande_evenement' AND md5(p.prosrc)<>'ce4d518be2d0545b10a43757a6e48550') THEN RAISE EXCEPTION 'evenement_definition_a_reexaminer'; END IF;
END;
$garde$;
CREATE OR REPLACE FUNCTION public.organisation_commande_evenement(p_requete text,p_organisation text,p_action text,p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text; d jsonb; pays text; jour integer; cible text; motivation text;
 commande jsonb; rec public.organisation_commandes_recus; resultat jsonb; paiement jsonb;
 ordre text; titre text; contenu text; temps text; mail_id text; topic_id text; nom_html text;
BEGIN
 acteur:=public.mon_personnage();
 IF acteur IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 IF p_requete IS NULL OR p_requete !~ '^orgcmd-[A-Za-z0-9-]{6,80}$' OR p_parametres IS NULL OR jsonb_typeof(p_parametres)<>'object' THEN RAISE EXCEPTION 'commande_invalide'; END IF;
 SELECT data::jsonb INTO d FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('orgcmd:'||p_requete,0));
 commande:=jsonb_build_object('action',p_action,'parametres',p_parametres);
 SELECT * INTO rec FROM public.organisation_commandes_recus WHERE requete=p_requete;
 IF FOUND THEN
  IF rec.acteur<>acteur OR rec.organisation<>p_organisation OR rec.commande<>commande THEN RAISE EXCEPTION 'requete_reutilisee' USING ERRCODE='42501'; END IF;
  RETURN (rec.resultat-'organisation')||jsonb_build_object('rejeu',true);
 END IF;
 IF d IS NULL THEN RAISE EXCEPTION 'organisation_absente'; END IF;
 pays:=coalesce(d->>'country_origine',d->>'country');
 SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name=acteur;
 IF jour IS NULL THEN RAISE EXCEPTION 'personnage_absent'; END IF;
 temps:=to_char(now() AT TIME ZONE 'Europe/Paris','DD/MM/YYYY HH24:MI');
 nom_html:=replace(replace(replace(d->>'nom','&','&amp;'),'<','&lt;'),'>','&gt;');
 IF p_action='inviter' THEN
  IF d->>'chef' IS DISTINCT FROM acteur THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
  IF coalesce((d->>'visible')::boolean,true) THEN RAISE EXCEPTION 'invitation_reservee_organisation_secrete'; END IF;
  cible:=p_parametres->>'nom';
  IF p_parametres-ARRAY['nom']<>'{}' OR cible IS NULL OR cible=acteur THEN RAISE EXCEPTION 'destinataire_invalide'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=cible AND country=pays) THEN RAISE EXCEPTION 'destinataire_ineligible'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'deja_membre'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'invitationsEnvoyees','[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'invitation_en_cours'; END IF;
  contenu:='L''organisation <strong>'||nom_html||'</strong> vous invite à la rejoindre.<br><br><em>Cette invitation est privée : personne d''autre n''en a connaissance.</em><br><br>'||
   '[[act:orga_oui|'||regexp_replace(p_organisation,'[|\[\]]','','g')||'|'||regexp_replace(acteur,'[|\[\]]','','g')||']]'||
   '[[act:orga_non|'||regexp_replace(p_organisation,'[|\[\]]','','g')||'|'||regexp_replace(acteur,'[|\[\]]','','g')||']]';
  mail_id:='mail-'||p_requete;
  INSERT INTO public.mails(id,from_player,to_player,subject,body,time,from_real,from_org_id)
   VALUES(mail_id,d->>'nom',cible,'Invitation — '||(d->>'nom'),contenu,temps,acteur,p_organisation);
  IF NOT FOUND THEN RAISE EXCEPTION 'courrier_non_insere'; END IF;
  d:=jsonb_set(d,'{invitationsEnvoyees}',coalesce(d->'invitationsEnvoyees','[]')||jsonb_build_array(jsonb_build_object('nom',cible,'date',jour)));
 ELSIF p_action='declencher_election' THEN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)') AND md5(prosrc)='92234a6b14ff176d2c2c2236f705683e') THEN RAISE EXCEPTION 'paiement_definition_a_reexaminer'; END IF;

  IF p_parametres-ARRAY['motivation']<>'{}' OR jsonb_typeof(p_parametres->'motivation') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'motivation_requise'; END IF;
  motivation:=btrim(p_parametres->>'motivation');IF motivation='' THEN RAISE EXCEPTION 'motivation_requise'; END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=acteur) THEN RAISE EXCEPTION 'reserve_aux_membres' USING ERRCODE='42501'; END IF;
  IF coalesce((d->'election'->>'enCours')::boolean,false) THEN RAISE EXCEPTION 'election_en_cours'; END IF;
  IF d->'election'->>'derniereElection' IS NOT NULL AND jour-(d->'election'->>'derniereElection')::integer<7 THEN RAISE EXCEPTION 'election_trop_recente'; END IF;
  ordre:=CASE d->>'type' WHEN 'supporters' THEN 'declencher_election_club' WHEN 'syndicale' THEN 'declencher_election_syndicat' END;
  IF ordre IS NULL THEN RAISE EXCEPTION 'ordre_electoral_non_defini'; END IF;
  -- Triplets existants de data.js : 1 PA / 0 FR, confirmes dans ordres_couts avant paiement.
  IF NOT EXISTS(SELECT 1 FROM public.ordres_couts WHERE fn=ordre AND pa=1 AND cost=0) THEN RAISE EXCEPTION 'cout_electoral_a_reexaminer'; END IF;
  paiement:=public.payer_ordre(acteur,ordre,1,0);
  IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN
   -- Refus sans mutation organisation/forum ; payer_ordre est responsable du refus sans debit.
   RETURN paiement;
  END IF;
  d:=jsonb_set(d,'{election}',jsonb_build_object('enCours',true,'phase','candidatures','motivateur',acteur,'motivation',motivation,
   'dateDeclenchement',jour,'dateFinCandidatures',jour+3,'dateFinVote',jour+6,'candidats','[]'::jsonb,'votes','{}'::jsonb,
   'derniereElection',d->'election'->'derniereElection'));
  titre:='🗳 Élection déclenchée — '||(d->>'nom');topic_id:='topic-'||p_requete;
  contenu:=replace(replace(replace(acteur,'&','&amp;'),'<','&lt;'),'>','&gt;')||' déclenche une élection pour la présidence de "'||nom_html||'" :<br><br><em>'||
   replace(replace(replace(motivation,'&','&amp;'),'<','&lt;'),'>','&gt;')||'</em><br><br>Les candidatures sont ouvertes pendant 3 jours, suivies de 3 jours de vote.';
  INSERT INTO public.forum_topics(id,forum_id,title,author,country,time,views,replies,last_post_author,last_post_time)
   VALUES(topic_id,'sport',titre,acteur,pays,temps,1,0,acteur,temps);
  IF NOT FOUND THEN RAISE EXCEPTION 'forum_sujet_non_insere'; END IF;
  INSERT INTO public.forum_posts(id,topic_id,author,content,time) VALUES('post-'||p_requete,topic_id,acteur,contenu,temps);
  IF NOT FOUND THEN RAISE EXCEPTION 'forum_message_non_insere'; END IF;
 ELSE RAISE EXCEPTION 'action_non_migree'; END IF;
 UPDATE public.organisations SET data=d::text WHERE id=p_organisation;
 IF NOT FOUND THEN RAISE EXCEPTION 'organisation_non_enregistree'; END IF;
 resultat:=jsonb_build_object('ok',true,'organisation',d,'mail_id',mail_id,'topic_id',topic_id);
 INSERT INTO public.organisation_commandes_recus(requete,acteur,organisation,commande,resultat) VALUES(p_requete,acteur,p_organisation,commande,resultat);
 IF NOT FOUND THEN RAISE EXCEPTION 'recu_non_insere'; END IF;
 RETURN resultat;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_commande_evenement(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organisation_commande_evenement(text,text,text,jsonb) TO authenticated;
COMMIT;
