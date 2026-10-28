-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028204248 (+ correctif 20261028204519 inventaire_sels_caisse_creee).
-- Eprouvee au role authenticated en transaction annulee : achat de sels (rejeu sans double paiement) et objet trouvé une fois par jour.
-- (Preparee par Codex.) PREPAREE, NON APPLIQUEE. Suite des lots inventaire 1-3 de Claude.
-- Aucun verrou de sauvegarde ; aucun acte reel. Depot uniquement par inventaire_deposer_interne.
-- Requiert les migrations 20261027180000-180300 et les primitives de caisse existantes.
CREATE TABLE IF NOT EXISTS public.inventaire_actions_recus (
 acteur text NOT NULL, requete uuid NOT NULL, action text NOT NULL, parametres jsonb NOT NULL,
 resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(acteur,requete)
);
ALTER TABLE public.inventaire_actions_recus ENABLE ROW LEVEL SECURITY;
-- Aucune policy ni aucun GRANT navigateur sur ce registre interne.
CREATE TABLE IF NOT EXISTS public.objets_trouves_jours (
 acteur text NOT NULL, jour date NOT NULL, PRIMARY KEY(acteur,jour)
);
ALTER TABLE public.objets_trouves_jours ENABLE ROW LEVEL SECURITY;
-- IF NOT EXISTS ne doit pas reutiliser silencieusement un registre deja expose.
DO $securite$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_policy WHERE polrelid IN('public.inventaire_actions_recus'::regclass,'public.objets_trouves_jours'::regclass)) THEN
  RAISE EXCEPTION 'inventaire: politique preexistante du registre a examiner';
 END IF;
END; $securite$;
INSERT INTO public.objets_modeles(id,objet) VALUES
('sels_ammoniaque','{"name":"Sels d''ammoniaque","icon":"ti-flask","stackable":true,"stackKey":"sels_ammoniaque","qty":1,"legal":true,"desc":"Un flacon piquant. Réveille brutalement quelqu''un d''assoupi — un député, par exemple."}'::jsonb),
('objet_trouve:0','{"name": "Parapluie a tete de mort", "icon": "ti-umbrella", "desc": "Un parapluie noir orne de tetes de mort doreees, la pointe etrangement acereee. Rappelle furieusement certaines methodes d''un service secret de l''Est, jadis tres efficace pour faire taire les genants.", "imageUrl": "images/objet-parapluie.webp", "type": "kompromat", "origine": "objets_trouves", "cible": null, "legal": false}'::jsonb),
('objet_trouve:1','{"name": "Dossier de presse périmé", "icon": "ti-file-text", "desc": "Un dossier marque \"PRESS\", rempli de coupures de journaux sur \"l''Affaire du Sphinx\" et de cliches compromettants. Quelqu''un voulait visiblement etouffer cette histoire.", "imageUrl": "images/objet-dossier-presse.webp", "type": "kompromat", "origine": "objets_trouves", "cible": null, "legal": false}'::jsonb),
('objet_trouve:2','{"name": "Petite culotte en dentelle", "icon": "ti-shirt", "desc": "Une petite culotte en dentelle noire, avec une carte de visite d''escort glissée dedans.", "imageUrl": "images/objet-culotte-dentelle.webp", "type": "kompromat", "origine": "objets_trouves", "cible": null, "legal": false}'::jsonb),
('objet_trouve:3','{"name": "Enveloppe administrative suspecte", "icon": "ti-package", "desc": "Une enveloppe officielle mal refermée, laissant voir un sachet de poudre blanche.", "imageUrl": "images/objet-sachet-poudre.webp", "type": "kompromat", "origine": "objets_trouves", "cible": null, "legal": false}'::jsonb),
('objet_trouve:4','{"name": "Boîte de préservatifs entamée", "icon": "ti-heart", "desc": "Une boîte de préservatifs entamée, un numéro de téléphone griffonné au marqueur.", "imageUrl": "images/objet-preservatifs.webp", "type": "kompromat", "origine": "objets_trouves", "cible": null, "legal": false}'::jsonb),
('objet_trouve:5','{"name": "Agenda à codes ridicules", "icon": "ti-notebook", "desc": "Un petit carnet relié de cuir, ferme par un cadenas et un cachet de cire. A l''interieur, des rendez-vous notes sous des noms de code grotesques et des symboles que personne ne saurait expliquer.", "imageUrl": "images/objet-agenda.webp", "type": "kompromat", "origine": "objets_trouves", "cible": null, "legal": false}'::jsonb),
('objet_trouve:6','{"name": "Bouteille de whisky entamée", "icon": "ti-bottle", "desc": "Une bouteille de whisky bon marché, à moitié vide, planquée derrière un radiateur.", "imageUrl": "images/objet-whisky.webp", "type": "objet", "origine": "objets_trouves", "cible": null, "legal": true}'::jsonb) ON CONFLICT(id) DO UPDATE SET objet=excluded.objet;

-- Lecture des replays sur l'etat actuel, jamais adoption d'un ancien inventaire de recu.
CREATE OR REPLACE FUNCTION public.inventaire_action_rejouer_interne(p_acteur text,p_requete uuid,p_action text,p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE r public.inventaire_actions_recus; d record;
BEGIN
 SELECT * INTO r FROM public.inventaire_actions_recus WHERE acteur=p_acteur AND requete=p_requete;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF r.action IS DISTINCT FROM p_action OR r.parametres IS DISTINCT FROM p_parametres THEN
  RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
 SELECT inventory,inventory_revision,pa,liquide,arg INTO d FROM public.personnages_donnees WHERE name=p_acteur;
 RETURN r.resultat || jsonb_build_object('rejeu',true,'inventory',d.inventory,'revision',d.inventory_revision,
  'paie',jsonb_build_object('pa',d.pa,'liquide',d.liquide,'arg',d.arg,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=p_acteur AND banque='nationale'),0)));
END; $function$;
REVOKE ALL ON FUNCTION public.inventaire_action_rejouer_interne(text,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sels_ammoniaque_acheter(p_requete uuid,p_quantite integer,p_pa integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; v jsonb; o jsonb; paiement jsonb; depot jsonb; q integer; params jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR p_quantite IS NULL OR p_quantite NOT BETWEEN 1 AND 20 THEN
  RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
 params:=jsonb_build_object('quantite',p_quantite,'pa',p_pa);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'sels',params); IF v IS NOT NULL THEN RETURN v; END IF;
 IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM
 ('republic','capitale','usine-pharmaceutique-luthecia','salle_ventes') THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='sels_ammoniaque';
 v:=public.assemblee_verifier_vente(jsonb_build_array(o),a.country);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RETURN v; END IF;
 q:=least(p_quantite,public.inventaire_place_restante(a.inventory));
 IF q<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale' FOR UPDATE;
 IF coalesce(a.liquide,0)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)<q*30 THEN
 RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
 paiement:=public.payer_ordre(a.name,'acheter_sels_ammoniaque',p_pa,0);
 IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement; END IF;
 IF NOT public.helvetia_debiter_fonds_ordinaires(a.name,q*30) THEN
  RAISE EXCEPTION 'fonds_insuffisants' USING ERRCODE='P0001'; END IF;
 -- 28/10/2026 : la caisse de l'usine est creee au premier achat, comme le faisait l'ecran.
 PERFORM set_config('rp.caisse_interne','on',true);
 v:=public.caisse_institution_mouvement(a.country||'_usine-pharmaceutique-luthecia',q*30,false);
 PERFORM set_config('rp.caisse_interne','',true);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'sels: caisse refusee'; END IF;
 depot:=public.inventaire_deposer_interne(a.name,o||jsonb_build_object('qty',q));
 IF (depot->>'ok')::boolean IS DISTINCT FROM true OR (depot->>'qte')::integer<>q THEN RAISE EXCEPTION 'sels: depot incomplet'; END IF;
 SELECT jsonb_build_object('pa',pa,'liquide',liquide,'arg',arg,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)) INTO paiement FROM public.personnages_donnees WHERE name=a.name;
 v:=depot||jsonb_build_object('paie',paiement,'total',q*30);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'sels',params,v,now()); RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.sels_ammoniaque_acheter(uuid,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sels_ammoniaque_acheter(uuid,integer,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.objet_trouve_reclamer(p_requete uuid,p_pa integer,p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; v jsonb; o jsonb; paiement jsonb; depot jsonb;
 v_index integer; v_jour date:=(now() AT TIME ZONE 'Europe/Paris')::date; params jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 params:=jsonb_build_object('pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'objet_trouve',params); IF v IS NOT NULL THEN RETURN v; END IF;
 -- Lieux exposes par data.js ; accueil de l'Assemblee conserve pour le service historique.
 IF ((a.current_building='mairie-capitale' AND a.current_room='hall_mairie' AND a.current_city='capitale')
 OR (a.current_building='mairie' AND a.current_room='accueil_mairie' AND a.current_city IN('ville_a','ville_b'))
 OR (a.current_building='assemblee' AND a.current_room='accueil_assemblee' AND a.current_city='capitale')) IS NOT TRUE THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 IF EXISTS(SELECT 1 FROM public.objets_trouves_jours WHERE acteur=a.name AND jour=v_jour)
 OR a.dernier_objet_trouve_jour=public.jour_de_jeu_pays(a.country) THEN
 RETURN jsonb_build_object('ok',false,'raison','deja_fait_aujourdhui'); END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
 paiement:=public.payer_ordre(a.name,'objet_trouve',p_pa,p_cost);
 IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement; END IF;
 INSERT INTO public.objets_trouves_jours VALUES(a.name,v_jour);
 UPDATE public.personnages_donnees SET dernier_objet_trouve_jour=public.jour_de_jeu_pays(a.country) WHERE name=a.name;
 IF random()<0.5 THEN
  v_index:=floor(random()*7)::integer;
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='objet_trouve:'||v_index;
  depot:=public.inventaire_deposer_interne(a.name,o);
  IF (depot->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'objet trouve: depot refuse'; END IF;
  INSERT INTO public.souvenirs_accueil(id,pj_nom,objet_nom,jour_creation,jour_expiration,revele)
  VALUES('souv-'||gen_random_uuid(),a.name,o->>'name',public.jour_de_jeu_pays(a.country),public.jour_de_jeu_pays(a.country)+12,false);
 ELSE SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision) INTO depot FROM public.personnages_donnees WHERE name=a.name;
 END IF;
 v:=depot||jsonb_build_object('paie',paiement,'trouve',o IS NOT NULL,'objet',o->>'name');
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'objet_trouve',params,v,now()); RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.objet_trouve_reclamer(uuid,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.objet_trouve_reclamer(uuid,integer,integer) TO authenticated;
