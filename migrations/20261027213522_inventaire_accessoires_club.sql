-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028205033.
-- Eprouvee au role authenticated en transaction annulee : accessoire de club : achat, crédit du budget du club, accessoire inconnu refusé.
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Meme catalogue/depot/recus, meme budget de club.
-- Requiert les lots inventaire precedents. Ne modifie ni les tarifs ni les salaires.
-- Prevol vivant obligatoire : catalogue des clubs et anciens ecrivains de budgets_clubs.
INSERT INTO public.objets_modeles(id,objet) VALUES
 ('accessoire:echarpe','{"type":"accessoire_sport","name":"Écharpe","icon":"ti-shirt","legal":true}'::jsonb),
 ('accessoire:casquette','{"type":"accessoire_sport","name":"Casquette","icon":"ti-shirt","legal":true}'::jsonb),
 ('accessoire:maillot','{"type":"accessoire_sport","name":"Maillot","icon":"ti-shirt","legal":true}'::jsonb)
 ON CONFLICT(id) DO UPDATE SET objet=excluded.objet;
CREATE OR REPLACE FUNCTION public.club_accessoire_acheter(p_requete uuid,p_accessoire text,p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; c public.clubs_sportifs_regles; o jsonb; prix integer; v jsonb; d jsonb; paiement jsonb; params jsonb; budget jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 params:=jsonb_build_object('accessoire',p_accessoire,'pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'club_accessoire',params);IF v IS NOT NULL THEN RETURN v;END IF;
 IF a.current_building IS DISTINCT FROM 'stade' OR a.current_room IS DISTINCT FROM 'buvette' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country=a.country AND city=a.current_city;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','club_local_introuvable');END IF;
 -- Prix historiques : l'ecran ne transmet ni nom de club, ni libelle, ni tarif.
 prix:=CASE p_accessoire WHEN 'echarpe' THEN 80 WHEN 'casquette' THEN 60 WHEN 'maillot' THEN 150 END;
 IF prix IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','accessoire_inconnu');END IF;
 SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='accessoire:'||p_accessoire;
 o:=o||jsonb_build_object('name',(o->>'name')||' — '||c.nom);
 v:=public.assemblee_verifier_vente(jsonb_build_array(o),a.country);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RETURN v;END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale' FOR UPDATE;
 IF coalesce(a.liquide,0)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)<prix THEN
 RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');END IF;
 paiement:=public.payer_ordre(a.name,'choisir_accessoire_club',p_pa,p_cost);
 IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement;END IF;
 IF NOT public.helvetia_debiter_fonds_ordinaires(a.name,prix) THEN RAISE EXCEPTION 'club: debit non confirme';END IF;
 -- credit atomique dans le budget existant ; jamais de solde absolu fourni par le navigateur.
 INSERT INTO public.budgets_clubs(id,data) VALUES(c.club_id,jsonb_build_object('clubId',c.club_id,'caisse',0,'historique','[]'::jsonb,
  'salaires',jsonb_build_object('titulaire',100,'remplacant',50,'primeVictoire',150))) ON CONFLICT(id) DO NOTHING;
 SELECT data INTO STRICT budget FROM public.budgets_clubs WHERE id=c.club_id FOR UPDATE;
 IF jsonb_typeof(budget) IS DISTINCT FROM 'object' OR (budget?'historique' AND jsonb_typeof(budget->'historique') IS DISTINCT FROM 'array') THEN RAISE EXCEPTION 'club: budget historique invalide';END IF;
 budget:=budget||jsonb_build_object('caisse',coalesce((budget->>'caisse')::numeric,0)+prix,
  'historique',coalesce(budget->'historique','[]')||jsonb_build_array(jsonb_build_object('jour',public.jour_de_jeu_pays(a.country),'montant',prix,'motif','Vente boutique : '||split_part(o->>'name',' — ',1))));
 SELECT jsonb_set(budget,'{historique}',coalesce(jsonb_agg(e ORDER BY n),'[]')) INTO budget
 FROM jsonb_array_elements(budget->'historique') WITH ORDINALITY x(e,n) WHERE n>jsonb_array_length(budget->'historique')-50;
 UPDATE public.budgets_clubs SET data=budget,updated_at=now() WHERE id=c.club_id;
 d:=public.inventaire_deposer_interne(a.name,o);
 IF (d->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'club: depot refuse';END IF;
 SELECT jsonb_build_object('pa',pa,'liquide',liquide,'arg',arg,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)) INTO paiement FROM public.personnages_donnees WHERE name=a.name;
 v:=d||jsonb_build_object('paie',paiement,'prix',prix,'objet',o->>'name');
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'club_accessoire',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.club_accessoire_acheter(uuid,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.club_accessoire_acheter(uuid,text,integer,integer) TO authenticated;
