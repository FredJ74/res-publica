-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024131720_acquisitions_depots_attestes.sql ; aucun changement de règle.
-- Prix et acompte des nouvelles reservations derives du recu prive, jamais d'un patch legacy.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.terrain_acquisition_commande(text,text,jsonb,uuid)');
IF h='c17c1bf98d1b64ba5fada309718b3999' THEN
d:=replace(d,$a$ IF montant IS NULL OR montant<0$a$,$b$ IF p_action IN('acte_direct','acte_compromis') AND e->>'acquisitionVersion'='2' THEN
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE terrain=t.id AND requete::text=e->>'acquisitionRequete' AND action=CASE p_action WHEN 'acte_direct' THEN 'depot' ELSE 'compromis' END;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','depot_non_atteste');END IF;
  prix:=(a.resultat->>'prix')::numeric;montant:=prix-(a.resultat->>'montant')::numeric;
 END IF;
 IF montant IS NULL OR montant<0$b$);d:=replace(d,$a$ INSERT INTO public.terrain_acquisitions_recus VALUES(moi,p_requete,t.id,p_action,params,r-'etat');$a$,$b$ IF p_action='depot' THEN
  r:=r||jsonb_build_object('courrier',public.mail_systeme_poser_interne('Office Notarial',moi,'Rendez-vous fixé — achat de terrain',
    'Votre dépôt de garantie de 1 000 FR est enregistré. Rendez-vous le '||to_char(to_timestamp((e->'achatDirect'->>'dateAchat')::numeric/1000) AT TIME ZONE 'Europe/Paris','DD/MM/YYYY HH24:MI')||' à l’Office Notarial. Tolérance de 24h ; passé ce délai, dépôt perdu et terrain remis en vente.',NULL));
 END IF;
 INSERT INTO public.terrain_acquisitions_recus VALUES(moi,p_requete,t.id,p_action,params,r-'etat');$b$);EXECUTE d;
ELSIF h IS DISTINCT FROM 'b2eacb6bff248ed3f0393f09cd44c4cc' THEN RAISE EXCEPTION 'definition_non_examinee: terrain_acquisition_commande depot';END IF;END;$g$;
COMMIT;
