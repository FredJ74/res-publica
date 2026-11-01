-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- restaurant_luthecia_pnj_chance(text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_pnj_chance(acteur text, invite text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p public.personnages_donnees; chance integer;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur;
 IF NOT FOUND THEN RETURN NULL; END IF;
 chance:=CASE invite WHEN 'Gaston Sauceblanche' THEN 60 WHEN 'Régis Gondasse' THEN 60 WHEN 'Yvette Gratinée' THEN 60 WHEN 'Jean Dupont' THEN 60 WHEN 'Marie Leblanc' THEN 20 ELSE NULL END;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes)='array' THEN p.employes ELSE '[]' END) e WHERE e->>'nom'=invite AND e->'inGroupe'='true'::jsonb)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.escort_active)='array' THEN p.escort_active ELSE '[]' END) e WHERE e->>'nom'=invite)
  OR EXISTS(SELECT 1 FROM public.pnj_membres WHERE nom=invite AND leader_pj IN(acteur,'pj:'||acteur) AND statut='actif') THEN chance:=95; END IF;
 -- Reutiliser la projection serveur des agents, jamais les vrais noms ni un cache de presence.
 IF acteur=public.mon_personnage() AND EXISTS(
  SELECT 1 FROM jsonb_array_elements(coalesce(public.agents_couverture_de_mon_groupe()->'agents','[]'::jsonb)) a WHERE a->>'nom'=invite
 ) THEN chance:=95; END IF;
 RETURN chance;
END $function$;

-- restaurant_luthecia_production_verifier(jsonb,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_production_verifier(d jsonb, acteur text, recette text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c numeric;
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica') OR NOT(public.restaurant_luthecia_carte(d,acteur) @> jsonb_build_array(recette)) THEN RETURN '{"ok":false,"raison":"hors_carte_piece"}'; END IF;
 IF coalesce(d->>'proprietaire','PNJ')='PNJ' AND recette IN('champagne_luthecia','cocktail_luthecia') THEN
  IF d->'coutMoyenMatieres'->>'fruits_legumes' IS NULL THEN RETURN '{"ok":false,"raison":"cout_matiere_inconnu"}'; END IF;
  c:=public.commerce_cout_revient_portion(d,recette);
  IF c IS NULL OR c*2>25 THEN RETURN jsonb_build_object('ok',false,'raison','marge_pnj_insuffisante','coutUnitaire',c); END IF;
 END IF;
 RETURN '{"ok":true}';
END $function$;

-- restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb, acteur text, produits jsonb, mode_vente text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 -- Compatibilite des appels historiques : aucune reservation deduite d'un panier vide.
 RETURN public.restaurant_luthecia_vente_verifier(d,acteur,produits,mode_vente,NULL);
END $function$;

-- restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb, acteur text, produits jsonb, mode_vente text, ordre text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica'
  AND CASE WHEN ordre='reserver_chambre_hotel' THEN current_room='accueil' ELSE current_room IN('bar','restaurant') END)
 THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF d->>'versionGastronomieLuthecia' IS DISTINCT FROM '1' THEN RETURN '{"ok":false,"raison":"carte_non_installee"}'; END IF;
 IF ordre='reserver_chambre_hotel' THEN
  -- Une prestation exacte, sans articles ni autre mode, a l'accueil uniquement.
  IF mode_vente IS DISTINCT FROM 'service' OR produits IS DISTINCT FROM '[]'::jsonb THEN
   RETURN '{"ok":false,"raison":"reservation_invalide"}';
  END IF;
 ELSE
  -- Le service des diners reste reserve a sa porte atomique existante.
  IF mode_vente='service' AND current_setting('rp.diner_luthecia',true) IS DISTINCT FROM 'on' THEN
   RETURN '{"ok":false,"raison":"service_par_invitation_requis"}';
  END IF;
 END IF;
 RETURN '{"ok":true}';
END $function$;

-- restituer_reliquats_chantier(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.restituer_reliquats_chantier(p_beneficiaire text, p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pj         personnages%ROWTYPE;
  v_terrain    terrains_etat%ROWTYPE;
  v_data       jsonb;
  v_acheve     jsonb;
  v_reliquats  jsonb;
  v_materiaux  jsonb;
  v_montant    numeric;
  v_matiere    text;
  v_qte        integer;
  v_jour       text;
  v_remis      jsonb := '{}'::jsonb;
  v_libelle    text;
  v_icone      text;
BEGIN
  IF COALESCE(p_beneficiaire, '') = '' OR COALESCE(p_terrain_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM personnages WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_absent'); END IF;

  SELECT * INTO v_terrain FROM terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- terrains_etat.data est une colonne TEXT contenant du JSON (meme convention qu'organisations).
  BEGIN
    v_data := v_terrain.data::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_illisible');
  END;

  v_acheve := v_data -> 'chantierAcheve';
  IF v_acheve IS NULL OR jsonb_typeof(v_acheve) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_chantier_livre');
  END IF;

  v_reliquats := v_acheve -> 'reliquats';
  IF v_reliquats IS NULL OR jsonb_typeof(v_reliquats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_reliquat');
  END IF;

  -- DEJA FAIT : reponse positive, aucune ecriture. C'est le cas normal d'un cron rejoue.
  IF COALESCE((v_reliquats ->> 'restitue')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'deja_restitue', true, 'montant', 0);
  END IF;

  -- LE BENEFICIAIRE EST LE PROPRIETAIRE DES MURS AU MOMENT DE LA LIVRAISON, pas celui qui a lance
  -- ni finance le chantier. On verifie que le nom fourni est bien celui inscrit sur le terrain :
  -- s'il ne l'est pas, on ne paie personne et le cron rejouera avec le bon nom.
  IF COALESCE(v_data ->> 'proprietaire', '') <> p_beneficiaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_incoherent');
  END IF;

  v_montant   := GREATEST(0, COALESCE((v_reliquats ->> 'tresorerie')::numeric, 0));
  v_materiaux := COALESCE(v_reliquats -> 'materiaux', '{}'::jsonb);
  v_jour      := COALESCE(v_acheve ->> 'jourLivraison', 'sansjour');

  -- 1. TRESORERIE. Rien n'est cree : cette somme a ete retiree du chantier par le meme traitement
  --    qui l'a inscrite ici, et elle n'y est plus disponible.
  IF v_montant > 0 THEN
    UPDATE public.personnages_donnees SET arg = COALESCE(arg, 0) + v_montant WHERE name = p_beneficiaire;
  END IF;

  -- 2. MATERIAUX, par le canal de reception AUTOMATIQUE (objets_recus). Ce canal est celui des
  --    objets qu'on n'a pas choisi de prendre : il ignore le plafond de 100 et fait passer son
  --    destinataire en Surcharge, exactement comme prevu au Lot 1.5.4. On n'ecrit surtout pas
  --    directement dans personnages.inventory : un client ouvert reecrit l'inventaire entier a sa
  --    prochaine sauvegarde et ecraserait l'ajout.
  --    L'identifiant est DETERMINISTE (terrain + jour de livraison + matiere) : un rejeu ne peut
  --    pas produire un second lot, meme si la transaction precedente avait echoue apres l'insert.
  FOR v_matiere IN SELECT unnest(ARRAY['bois', 'minerai', 'metal']) LOOP
    v_qte := GREATEST(0, floor(COALESCE((v_materiaux ->> v_matiere)::numeric, 0)))::integer;
    CONTINUE WHEN v_qte <= 0;
    -- Libelle et icone : simple habillage, repris de RESSOURCES_ECONOMIE (data.js). Aucune regle
    -- de jeu ne depend de ces deux chaines ; les quantites, elles, viennent du terrain verrouille.
    v_libelle := CASE v_matiere WHEN 'bois' THEN 'Bois' WHEN 'minerai' THEN 'Minerai' ELSE 'Métal' END;
    v_icone   := CASE v_matiere WHEN 'bois' THEN 'ti-trees' WHEN 'minerai' THEN 'ti-mountain' ELSE 'ti-bolt' END;
    -- Garde ecrite en SQL plutot qu'en ON CONFLICT : la definition d'objets_recus n'est pas
    -- versionnee dans le depot, on ne presume donc d'aucune contrainte d'unicite sur id. Le verrou
    -- deja pris sur terrains_etat serialise de toute facon deux appels concurrents.
    INSERT INTO objets_recus (id, destinataire, expediteur, data)
    SELECT 'reliquat-' || p_terrain_id || '-' || v_jour || '-' || v_matiere,
           p_beneficiaire,
           'Chef de Chantier',
           jsonb_build_object(
             'name', v_libelle, 'icon', v_icone,
             'stackable', true, 'stackKey', v_matiere, 'qty', v_qte,
             'desc', 'Matériaux restitués à la livraison du chantier.'
           )::text
    WHERE NOT EXISTS (
      SELECT 1 FROM objets_recus
      WHERE id = 'reliquat-' || p_terrain_id || '-' || v_jour || '-' || v_matiere
    );
    v_remis := jsonb_set(v_remis, ARRAY[v_matiere], to_jsonb(v_qte));
  END LOOP;

  -- 3. MARQUEUR, dans la MEME transaction que les deux paiements. C'est lui qui rend l'operation
  --    rejouable sans risque : tant qu'il n'est pas pose, rien n'a ete paye ; une fois pose, plus
  --    rien ne le sera.
  v_reliquats := jsonb_set(v_reliquats, '{restitue}', 'true'::jsonb);
  v_reliquats := jsonb_set(v_reliquats, '{dateRestitution}',
                   to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_acheve    := jsonb_set(v_acheve, '{reliquats}', v_reliquats);
  v_data      := jsonb_set(v_data, '{chantierAcheve}', v_acheve);

  UPDATE terrains_etat
    SET data = v_data::text,
        updated_at = now()
    WHERE id = p_terrain_id;

  RETURN jsonb_build_object('ok', true, 'deja_restitue', false,
                            'montant', v_montant, 'materiaux', v_remis,
                            'beneficiaire', p_beneficiaire);
END;
$function$;

-- sels_ammoniaque_acheter(uuid,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.sels_ammoniaque_acheter(p_requete uuid, p_quantite integer, p_pa integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

-- tournee_cloturer_boire(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tournee_cloturer_boire(p_tournee_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE t public.tournees; v_moi text:=public.mon_personnage(); v_n integer; v_qte integer; v_r jsonb; v_erreur text; v_participants text[];
BEGIN
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT * INTO t FROM public.tournees WHERE id=p_tournee_id FOR UPDATE;
 IF NOT FOUND OR t.contrat IS DISTINCT FROM 'boire_v1' OR t.offreur IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_offre'); END IF;
 IF t.resultat IS NOT NULL THEN RETURN t.resultat||jsonb_build_object('rejeu',true); END IF;
 IF t.statut NOT IN ('en_attente','en_resolution') THEN RETURN jsonb_build_object('ok',false,'raison','tournee_close'); END IF;
 IF t.expires_at>now() AND EXISTS(SELECT 1 FROM public.invitations_diner WHERE tournee_id=t.id AND statut='attente') THEN RETURN jsonb_build_object('ok',false,'raison','reponses_en_attente'); END IF;
 -- Meme ordre entreprise puis personnages que le moteur de vente et le lancement.
 PERFORM 1 FROM public.entreprises WHERE id=t.entreprise_id FOR UPDATE;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(t.invites_initiales||ARRAY[v_moi]) ORDER BY name FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_moi AND country=t.country AND current_city=t.ville AND current_building=t.building_id AND current_room=t.room_id) THEN
  v_r:=jsonb_build_object('ok',false,'raison','action_obsolete');
 ELSE
  SELECT coalesce(array_agg(DISTINCT d.name ORDER BY d.name),'{}'::text[]) INTO v_participants FROM public.invitations_diner i JOIN public.personnages_donnees d ON d.name=i.invite
   WHERE i.tournee_id=t.id AND i.statut='acceptee' AND d.country=t.country AND d.current_city=t.ville AND d.current_building=t.building_id AND d.current_room=t.room_id;
  v_n:=cardinality(v_participants); v_qte:=v_n+1;
  IF (SELECT valeur FROM public.entreprises_constantes WHERE cle='pa_tournee') IS DISTINCT FROM 1::numeric THEN
   RETURN jsonb_build_object('ok',false,'raison','contrat_pa_incompatible'); END IF;
  -- Sous-transaction : les moteurs historiques peuvent refuser apres un debit de PA.
  -- Le refus est leve puis capture : toutes ses ecritures sont annulees ensemble.
  BEGIN
   v_r:=public.commerce_vendre_produit_interne(v_moi,t.entreprise_id,jsonb_build_array(jsonb_build_object('produit',t.recette_id,'qte',v_qte)),'comptoir',NULL,0,0,'pa_tournee',25);
   IF v_r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'tournee_vente_refusee' USING DETAIL=v_r::text; END IF;
  EXCEPTION WHEN raise_exception THEN
   IF SQLERRM<>'tournee_vente_refusee' THEN RAISE; END IF;
   GET STACKED DIAGNOSTICS v_erreur=PG_EXCEPTION_DETAIL; v_r:=v_erreur::jsonb;
  END;
  IF v_r->>'ok'='true' THEN
   IF v_n=0 THEN
    UPDATE public.personnages_donnees SET moral=greatest(0,coalesce(moral,75)-5),updated_at=now() WHERE name=v_moi;
   ELSE
    UPDATE public.personnages_donnees SET hp=least(100,coalesce(hp,100)+5),
     resources=jsonb_set(coalesce(resources,'{}'),'{inf}',to_jsonb(least(100,coalesce((resources->>'inf')::numeric,0)+2)),true),
     stats=jsonb_set(coalesce(stats,'{}'),'{ENT}',to_jsonb(greatest(coalesce((stats->>'ENT')::numeric,0),least(20,coalesce((stats->>'ENT')::numeric,0)+2))),true),updated_at=now()
     WHERE name=ANY(v_participants||ARRAY[v_moi]);
   END IF;
   v_r:=jsonb_build_object('ok',true,'servie',true,'acceptants',v_n,'verres',v_qte,'total',25*v_qte,'pa',1,'seul',v_n=0);
  END IF;
 END IF;
 UPDATE public.invitations_diner SET statut='refusee' WHERE tournee_id=t.id AND statut='attente';
 UPDATE public.tournees SET statut=CASE WHEN v_r->>'ok'='true' THEN 'resolue' ELSE 'annulee' END,pa_debite=v_r->>'ok'='true',resultat=v_r WHERE id=t.id;
 RETURN v_r;
END $function$;

-- tournee_contrat_lire() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tournee_contrat_lire()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT jsonb_build_object('ok',public.mon_personnage() IS NOT NULL,'version',1);
$function$;

-- tournee_creer(text,text,text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tournee_creer(p_id text, p_entreprise text, p_recette text, p_invites text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text:=public.mon_personnage(); v_data jsonb; v_p public.personnages_donnees; t public.tournees; v_invite text; v_invites text[];
BEGIN
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_id IS NULL OR p_id !~ '^tournee-[A-Za-z0-9-]{10,80}$' OR coalesce(cardinality(p_invites),0) NOT BETWEEN 1 AND 50 OR v_moi=ANY(p_invites) OR array_position(p_invites,NULL) IS NOT NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
 SELECT array_agg(DISTINCT x ORDER BY x) INTO v_invites FROM unnest(p_invites) x;
 IF cardinality(v_invites)<>cardinality(p_invites) THEN RETURN jsonb_build_object('ok',false,'raison','invites_dupliques'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('tournee:'||p_id,0));
 SELECT * INTO t FROM public.tournees WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF t.offreur=v_moi AND t.entreprise_id=p_entreprise AND t.recette_id=p_recette AND t.invites_initiales=v_invites AND t.contrat='boire_v1' THEN
   RETURN jsonb_build_object('ok',true,'id',t.id,'rejeu',true); END IF;
  RETURN jsonb_build_object('ok',false,'raison','requete_incompatible'); END IF;
 SELECT data INTO v_data FROM public.entreprises WHERE id=p_entreprise FOR UPDATE;
 IF v_data IS NULL OR NOT(public.restaurant_luthecia_carte(v_data,v_moi) @> jsonb_build_array(p_recette)) OR NOT EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=p_recette AND categorie='boisson') THEN
  RETURN jsonb_build_object('ok',false,'raison','boisson_non_proposee'); END IF;
 -- Ordre de verrouillage commun a tous les participants, y compris deux organisateurs concurrents.
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(v_invites||ARRAY[v_moi]) ORDER BY name FOR UPDATE;
 SELECT * INTO v_p FROM public.personnages_donnees WHERE name=v_moi;
 IF NOT FOUND OR v_p.country IS DISTINCT FROM v_data->>'country' OR v_p.current_city IS DISTINCT FROM v_data->>'city' OR v_p.current_building IS DISTINCT FROM v_data->>'buildingId' OR v_p.current_room IS NULL OR
   (v_data->>'roomId' IS NOT NULL AND v_p.current_room IS DISTINCT FROM v_data->>'roomId') THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 IF public.restaurant_luthecia_est_commerce(v_data) AND v_p.current_room<>'bar' THEN RETURN '{"ok":false,"raison":"ordre_non_disponible"}'; END IF;
 FOREACH v_invite IN ARRAY v_invites LOOP
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_invite AND country=v_p.country AND current_city=v_p.current_city AND current_building=v_p.current_building AND current_room=v_p.current_room) THEN
   RETURN jsonb_build_object('ok',false,'raison','invite_absent'); END IF;
 END LOOP;
 INSERT INTO public.tournees(id,country,ville,offreur,building_id,room_id,commerce_type,recette_id,prix_unitaire_reference,pnj_resultats,expires_at,contrat,entreprise_id,invites_initiales)
 VALUES(p_id,v_p.country,v_p.current_city,v_moi,v_p.current_building,v_p.current_room,v_data->>'type',p_recette,25,'[]',now()+interval '5 minutes','boire_v1',p_entreprise,v_invites);
 INSERT INTO public.invitations_diner(inviteur,invite,country,city,building_id,room_id,cout,type,tournee_id)
 SELECT v_moi,x,v_p.country,v_p.current_city,v_p.current_building,v_p.current_room,25,'tournee_boisson',p_id FROM unnest(v_invites) x;
 RETURN jsonb_build_object('ok',true,'id',p_id);
END $function$;

-- tournee_proteger_contrat() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tournee_proteger_contrat()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nouveau boolean:=false; v_ancien boolean:=false;
BEGIN
 IF TG_TABLE_NAME='tournees' THEN
  IF TG_OP<>'DELETE' THEN v_nouveau:=NEW.contrat IS NOT NULL; END IF;
  IF TG_OP<>'INSERT' THEN v_ancien:=OLD.contrat IS NOT NULL; END IF;
 ELSE
  IF TG_OP<>'DELETE' THEN SELECT contrat IS NOT NULL INTO v_nouveau FROM public.tournees WHERE id=NEW.tournee_id; END IF;
  IF TG_OP<>'INSERT' THEN SELECT contrat IS NOT NULL INTO v_ancien FROM public.tournees WHERE id=OLD.tournee_id; END IF;
 END IF;
 IF TG_TABLE_NAME='tournees' AND TG_OP='INSERT' THEN v_nouveau:=true; END IF;
 IF (coalesce(v_nouveau,false) OR coalesce(v_ancien,false)) AND current_user NOT IN ('postgres','supabase_admin') THEN
  RAISE EXCEPTION 'tournee_ecriture_par_rpc_requise' USING ERRCODE='42501'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $function$;

-- tournee_repondre(bigint,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tournee_repondre(p_invitation bigint, p_accepte boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text:=public.mon_personnage(); i public.invitations_diner; t public.tournees; v_id text; v_statut text:=CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END;
BEGIN
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT tournee_id INTO v_id FROM public.invitations_diner WHERE id=p_invitation AND invite=v_moi;
 SELECT * INTO t FROM public.tournees WHERE id=v_id FOR UPDATE;
 IF NOT FOUND OR t.contrat IS DISTINCT FROM 'boire_v1' THEN RETURN jsonb_build_object('ok',false,'raison','invitation_absente'); END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation AND invite=v_moi FOR UPDATE;
 IF p_accepte IS NULL AND t.resultat IS NOT NULL THEN
  UPDATE public.invitations_diner SET statut='vue' WHERE id=i.id;
  RETURN jsonb_build_object('ok',true); END IF;
 IF p_accepte IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','invitation_non_resolue'); END IF;
 IF i.statut=v_statut THEN RETURN jsonb_build_object('ok',true,'rejeu',true); END IF;
 IF i.statut<>'attente' OR t.statut<>'en_attente' OR now()>=t.expires_at THEN RETURN jsonb_build_object('ok',false,'raison','invitation_close'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_moi AND country=t.country AND current_city=t.ville AND current_building=t.building_id AND current_room=t.room_id) THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 UPDATE public.invitations_diner SET statut=v_statut WHERE id=p_invitation;
 RETURN jsonb_build_object('ok',true);
END $function$;

-- vendre_fonds_commerce(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vendre_fonds_commerce(p_vendeur text, p_acheteur text, p_fonds_id text, p_prix integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb;
  v_bail_id text;
  v_bail jsonb;
  v_prix integer := GREATEST(0, COALESCE(p_prix, 0));
  v_caisse integer;
  v_premier text;
  v_second text;
BEGIN
  IF COALESCE(p_vendeur, '') = '' OR COALESCE(p_acheteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_vendeur = p_acheteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_identique'); END IF;
  IF left(p_acheteur, 6) = 'ville:' THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_invalide'); END IF;
  IF p_vendeur < p_acheteur THEN v_premier := p_vendeur; v_second := p_acheteur; ELSE v_premier := p_acheteur; v_second := p_vendeur; END IF;
  IF NOT mouvement_titulaire(v_premier, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  IF NOT mouvement_titulaire(v_second, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_vendeur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_prix > 0 THEN
    IF NOT mouvement_titulaire(p_acheteur, -v_prix) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_insolvable'); END IF;
    IF NOT mouvement_titulaire(p_vendeur, v_prix) THEN RAISE EXCEPTION 'vendeur_introuvable'; END IF;
  END IF;
  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_caisse > 0 THEN IF NOT mouvement_titulaire(p_vendeur, v_caisse) THEN RAISE EXCEPTION 'extraction_impossible'; END IF; END IF;
  v_data := jsonb_set(v_data, '{proprietaire}', to_jsonb(p_acheteur));
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(0));
  v_data := jsonb_set(v_data, '{historique}', COALESCE(v_data -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'evenement', 'vente', 'vendeur', p_vendeur, 'acheteur', p_acheteur, 'prix', v_prix, 'caisseExtraite', v_caisse,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
  UPDATE entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  v_bail_id := v_data -> 'implantation' ->> 'bailId';
  IF COALESCE(v_bail_id, '') <> '' THEN
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_bail_id FOR UPDATE;
    IF v_bail IS NOT NULL THEN
      UPDATE locations_actives
        SET data = v_bail || jsonb_build_object(
              'locataire', CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
              'locataireRef', p_acheteur,
              'transferts', COALESCE(v_bail -> 'transferts', '[]'::jsonb) || jsonb_build_array(
                jsonb_build_object('cause', 'vente_fonds', 'de', p_vendeur, 'vers', p_acheteur,
                  'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))))
        WHERE id = v_bail_id;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'prix', v_prix, 'caisseExtraite', v_caisse, 'acheteur', p_acheteur, 'bailTransfere', COALESCE(v_bail_id, ''));
END;
$function$;

-- vendre_materiaux_chantier(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vendre_materiaux_chantier(p_vendeur text, p_country text, p_building_id text, p_matiere text, p_quantite integer, p_prix integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_emplacement text;
  v_pj          personnages%ROWTYPE;
  v_terrain     terrains_etat%ROWTYPE;
  v_data        jsonb;
  v_chantier    jsonb;
  v_stock       jsonb;
  v_inv         jsonb;
  v_ligne       jsonb;
  v_idx         integer := -1;
  v_i           integer;
  v_possede     integer := 0;
  v_tresorerie  numeric;
  v_payables    integer;
  v_qte         integer;
  v_montant     numeric;
  v_duree       numeric;
  v_progression numeric;
  v_prix numeric;
  v_terrain_id  text := p_country || '_' || p_building_id;
BEGIN
  PERFORM public.exiger_acteur(p_vendeur);
  IF p_matiere NOT IN ('bois', 'minerai', 'metal') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_invalide');
  END IF;
  IF COALESCE(p_quantite, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_prix IS NULL OR p_prix < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide');
  END IF;

  -- VERROUS. Ordre fixe personnages -> terrains_etat, applique a toutes les ventes : deux ventes
  -- simultanees sur le meme chantier se serialisent au lieu de s'ecraser, et l'ordre etant
  -- toujours le meme, aucune de ces deux transactions ne peut en bloquer une autre en sens
  -- inverse.
  SELECT * INTO v_pj FROM personnages WHERE name = p_vendeur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_absent'); END IF;

  SELECT * INTO v_terrain FROM public.terrains_etat WHERE country=p_country AND (id=v_terrain_id OR building_id=p_building_id AND data::jsonb->>'city'=v_pj.current_city) ORDER BY (id=v_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  v_terrain_id:=v_terrain.id;
  IF coalesce(v_pj.hp,0)<=0 OR coalesce(v_pj.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text OR EXISTS(SELECT 1 FROM public.detention_active(p_vendeur)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  -- PRESENCE PHYSIQUE, verifiee sur la donnee faisant autorite cote serveur.
  IF COALESCE(v_pj.current_building, '') <> p_building_id OR v_pj.country IS DISTINCT FROM p_country THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- terrains_etat.data est une colonne TEXT contenant du JSON (meme convention que organisations).
  BEGIN
    v_data := v_terrain.data::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_illisible');
  END;

  v_emplacement:=CASE WHEN jsonb_typeof(v_data->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_chantier:=v_data->v_emplacement;
  IF v_chantier IS NULL OR jsonb_typeof(v_chantier) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  -- Un chantier arrive a son terme n'accepte plus de marchandise.
  v_duree       := COALESCE((v_chantier ->> 'dureeJours')::numeric, 0);
  v_progression := COALESCE((v_chantier ->> 'progressionJours')::numeric, 0);
  IF v_duree > 0 AND v_progression >= v_duree THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_termine');
  END IF;

  IF v_pj.current_city IS DISTINCT FROM (v_data->>'city') OR nullif(v_data->>'succession_gel','') IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_ville_ou_gele');
  END IF;
  IF p_prix=0 THEN v_prix:=0;
  ELSE
    v_prix:=coalesce((v_chantier->'prixAchatPJ'->>p_matiere)::numeric,
      (SELECT ceil(prix_base*1.10) FROM public.ressources_economie WHERE cle=p_matiere));
  END IF;
  IF v_prix IS NULL OR v_prix<0 OR v_prix<>trunc(v_prix) THEN
    RETURN jsonb_build_object('ok',false,'raison','prix_indisponible');
  END IF;

  IF p_prix>0 AND (v_chantier->'prixAchatPJ'->p_matiere) IS NULL THEN
    v_chantier:=jsonb_set(v_chantier,'{prixAchatPJ}',coalesce(v_chantier->'prixAchatPJ','{}'::jsonb)||jsonb_build_object(p_matiere,v_prix));
  END IF;

  -- STOCK REEL DU VENDEUR, relu sur son inventaire -- jamais celui annonce par le client.
  v_inv := COALESCE(v_pj.inventory, '[]'::jsonb);
  IF jsonb_typeof(v_inv) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_illisible');
  END IF;
  FOR v_i IN 0 .. jsonb_array_length(v_inv) - 1 LOOP
    v_ligne := v_inv -> v_i;
    IF (v_ligne ->> 'stackKey') = p_matiere AND COALESCE((v_ligne ->> 'stackable')::boolean, false) THEN
      v_idx := v_i;
      v_possede := GREATEST(0, floor(COALESCE((v_ligne ->> 'qty')::numeric, 0))::integer);
      EXIT;
    END IF;
  END LOOP;
  IF v_idx < 0 OR v_possede <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant');
  END IF;

  -- Tresorerie reelle ; le prix est celui du proprietaire, jamais celui du vendeur.
  v_tresorerie := GREATEST(0, COALESCE((v_chantier ->> 'tresorerie')::numeric, 0));
  v_payables   := CASE WHEN v_prix=0 THEN p_quantite ELSE least(2147483647,floor(v_tresorerie/v_prix))::integer END;

  -- RECALCUL SERVEUR de la quantite transferable.
  v_qte := LEAST(p_quantite, v_possede, v_payables);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante');
  END IF;
  v_montant := v_qte::numeric * v_prix;


  -- ---- A partir d'ici, tout est applique ou rien ne l'est.

  -- 1. Retrait chez le vendeur. La ligne d'inventaire disparait si elle tombe a zero.
  IF v_possede - v_qte <= 0 THEN
    v_inv := v_inv - v_idx;
  ELSE
    v_inv := jsonb_set(v_inv, ARRAY[v_idx::text, 'qty'], to_jsonb(v_possede - v_qte));
  END IF;

  -- 2. Credit du stock du chantier. Le stock est un VRAI stock : aucune limitation au besoin du
  --    jour, une reserve peut etre constituee pour les jours suivants.
  v_stock := COALESCE(v_chantier -> 'stockMateriaux', '{}'::jsonb);
  v_stock := jsonb_set(v_stock, ARRAY[p_matiere],
               to_jsonb(GREATEST(0, COALESCE((v_stock ->> p_matiere)::numeric, 0)) + v_qte));
  v_chantier := jsonb_set(v_chantier, '{stockMateriaux}', v_stock);

  -- 3. Debit de la tresorerie du chantier.
  v_chantier := jsonb_set(v_chantier, '{tresorerie}', to_jsonb(v_tresorerie - v_montant));

  -- 4. Journal NOMINATIF : contrairement au journal d'un vol, le vendeur est connu.
  v_chantier := jsonb_set(v_chantier, '{ventesMateriauxPJ}',
    COALESCE(v_chantier -> 'ventesMateriauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('vendeur', p_vendeur, 'matiere', p_matiere, 'quantite', v_qte,
                         'prixUnitaire',v_prix, 'montant', v_montant,
                         'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));

  UPDATE terrains_etat
    SET data = (v_data || jsonb_build_object(v_emplacement, v_chantier))::text,
        updated_at = now()
    WHERE id = v_terrain_id;

  -- 5. Paiement du vendeur et ecriture de son inventaire, dans la MEME transaction.
  UPDATE public.personnages_donnees
    SET arg = COALESCE(arg, 0) + v_montant,
        liquide = COALESCE(liquide,0) + v_montant,
        inventory = v_inv
    WHERE name = p_vendeur;

  IF (SELECT inventory FROM public.personnages_donnees WHERE name=p_vendeur) IS DISTINCT FROM v_inv THEN
    RAISE EXCEPTION 'inventaire_non_applique';
  END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', v_qte, 'montant', v_montant,
                            'prixUnitaire',v_prix, 'matiere', p_matiere);
END;
$function$;

-- vendre_materiaux_chantier(text,text,text,text,integer,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vendre_materiaux_chantier(p_vendeur text, p_country text, p_building_id text, p_matiere text, p_quantite integer, p_prix integer, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_charge jsonb; v_recu public.chantier_requetes%rowtype; v_resultat jsonb; v_inv jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_vendeur);
  IF p_requete IS NULL OR length(p_requete)<8 OR length(p_requete)>160 THEN
    RETURN jsonb_build_object('ok',false,'raison','requete_requise'); END IF;
  v_charge:=jsonb_build_object('pays',p_country,'terrain',p_building_id,'matiere',p_matiere,'quantite',p_quantite,'mode',p_prix);
  PERFORM pg_advisory_xact_lock(hashtextextended('chantier:'||p_requete,0));
  SELECT * INTO v_recu FROM public.chantier_requetes WHERE id=p_requete;
  IF FOUND THEN
    IF v_recu.acteur IS DISTINCT FROM p_vendeur OR v_recu.charge IS DISTINCT FROM v_charge THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    RETURN v_recu.resultat||jsonb_build_object('rejeu',true);
  END IF;
  v_resultat:=public.vendre_materiaux_chantier(p_vendeur,p_country,p_building_id,p_matiere,p_quantite,p_prix);
  IF (v_resultat->>'ok')::boolean THEN
    v_inv:=public.inventaire_reception_etat(p_vendeur);
    IF NOT coalesce((v_inv->>'ok')::boolean,false) THEN RAISE EXCEPTION 'inventaire_non_confirme'; END IF;
    v_resultat:=v_resultat||v_inv||jsonb_build_object('contratConstruction',57);
  END IF;
  INSERT INTO public.chantier_requetes(id,acteur,charge,resultat) VALUES(p_requete,p_vendeur,v_charge,v_resultat);
  RETURN v_resultat;
END;$function$;

-- vendre_matiere_a_usine(text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vendre_matiere_a_usine(p_acteur text, p_pays text, p_ville text, p_batiment text, p_matiere text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle text := p_pays || '|' || coalesce(p_ville,'') || '|' || p_batiment;
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_accepte boolean; v_detail boolean;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_cmm jsonb;
  v_plafond numeric; v_stock numeric; v_place numeric;
  v_prix numeric; v_total numeric; v_caisse numeric;
  v_inv jsonb; v_detenu numeric; v_arg numeric; v_liquide numeric;
  v_cout_moyen numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : vente de matiere a une usine.
  -- Une matiere interdite par l'Assemblee ne peut plus y entrer. Le don, lui,
  -- reste licite -- mais ce circuit-ci n'est pas un don. Garde posee avant toute
  -- lecture metier et toute ecriture ; la juridiction est resolue par le serveur.
  IF public.matiere_refus_circuit_legal(p_acteur, p_matiere, 'vente') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, p_matiere, 'vente');
  END IF;
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- Matiere acceptee ? Par une chaine de l'usine, ou par sa liste hors chaine.
  SELECT coalesce(prix_detail, false),
         EXISTS (SELECT 1 FROM public.chaines_production_usine c
                 WHERE c.building_id = p_batiment AND c.matiere = p_matiere)
         OR coalesce(matieres_hors_chaine, '[]'::jsonb) ? p_matiere
    INTO v_detail, v_accepte
  FROM public.usines_rachat_config WHERE cle = v_cle;
  IF v_accepte IS NULL THEN
    v_detail := false;
    SELECT EXISTS (SELECT 1 FROM public.chaines_production_usine c
                   WHERE c.building_id = p_batiment AND c.matiere = p_matiere) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee');
  END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_inv, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_matiere);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_cmm := coalesce(v_usine->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);

  SELECT plafond, CASE WHEN v_detail THEN prix_base ELSE prix_achat_fournisseur END
    INTO v_plafond, v_prix FROM public.ressources_economie WHERE cle = p_matiere;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;

  v_stock := coalesce((v_sm->>p_matiere)::numeric, 0);
  v_place := greatest(0, coalesce(v_plafond,0) - v_stock);
  IF v_place < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
  END IF;

  v_total := v_prix * p_qte;
  IF v_caisse < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  -- Cout moyen pondere, meme calcul que crediterStockMatiereCommerce.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>p_matiere)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, p_matiere, p_qte),
         arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = p_acteur;

  v_usine := v_usine || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_matiere], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_matiere], to_jsonb(v_cout_moyen)),
    'caisse', v_caisse - v_total);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
    'inventory', public.inventaire_retirer(v_inv, p_matiere, p_qte),
    'caisse_usine', v_caisse - v_total);
END; $function$;

-- vendre_ressource_medicale(text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vendre_ressource_medicale(p_acteur text, p_pays text, p_ville text, p_batiment text, p_ressource text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_ressources jsonb; v_financement text;
  v_etat jsonb; v_sante jsonb; v_sm jsonb; v_cmm jsonb;
  v_plafond numeric; v_stock numeric; v_place numeric; v_prix numeric; v_total numeric;
  v_caisse numeric; v_inv jsonb; v_detenu numeric; v_arg numeric; v_liquide numeric;
  v_cout_moyen numeric; v_caisse_id text; v_solde_inst numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : vente de ressource a une structure medicale.
  -- Une matiere interdite par l'Assemblee ne peut plus y entrer. Le don, lui,
  -- reste licite -- mais ce circuit-ci n'est pas un don. Garde posee avant toute
  -- lecture metier et toute ecriture ; la juridiction est resolue par le serveur.
  IF public.matiere_refus_circuit_legal(p_acteur, p_ressource, 'vente') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, p_ressource, 'vente');
  END IF;
  IF p_qte IS NULL OR p_qte <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT ressources, financement INTO v_ressources, v_financement
  FROM public.structures_medicales WHERE building_id = p_batiment;
  IF v_ressources IS NULL OR NOT (v_ressources ? p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_non_acceptee');
  END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_inv, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_ressource);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'structure_introuvable'); END IF;
  v_sante := coalesce(v_etat->'sante', '{}'::jsonb);
  v_sm := coalesce(v_sante->'stockMatieres', '{}'::jsonb);
  v_cmm := coalesce(v_sante->'coutMoyenMatieres', '{}'::jsonb);

  SELECT plafond, prix_achat_fournisseur INTO v_plafond, v_prix
  FROM public.ressources_economie WHERE cle = p_ressource;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_stock := coalesce((v_sm->>p_ressource)::numeric, 0);
  v_place := greatest(0, coalesce(v_plafond,0) - v_stock);
  IF v_place < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
  END IF;
  v_total := v_prix * p_qte;

  -- Deux financements, deux caisses -- exactement comme le client le faisait.
  IF v_financement = 'propre' THEN
    v_caisse := coalesce((v_sante->>'caisse')::numeric, 0);
    IF v_caisse < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
    END IF;
    v_sante := v_sante || jsonb_build_object('caisse', v_caisse - v_total);
  ELSE
    v_caisse_id := p_pays || '_dispensaire_' || p_ville;
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_inst
    FROM public.caisses_batiments WHERE id = v_caisse_id FOR UPDATE;
    IF v_solde_inst IS NULL OR v_solde_inst < v_total THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                                'caisse', coalesce(v_solde_inst, 0));
    END IF;
    UPDATE public.caisses_batiments
       SET data = jsonb_set(coalesce(data,'{}'::jsonb), '{solde}', to_jsonb(v_solde_inst - v_total)),
           updated_at = now()
     WHERE id = v_caisse_id;
  END IF;

  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>p_ressource)::numeric,0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;
  v_sante := v_sante || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_ressource], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_ressource], to_jsonb(v_cout_moyen)));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante))::text), updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, p_ressource, p_qte),
         arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
    'inventory', public.inventaire_retirer(v_inv, p_ressource, p_qte));
END; $function$;

-- ventes_snapshots_append_only() -> trigger | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.ventes_snapshots_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'preuve_immuable: une vente enregistree ne peut etre ni modifiee ni supprimee'
    USING ERRCODE = '42501';
END;
$function$;
