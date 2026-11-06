-- Chantier naval PSM : commandes, approvisionnements quotidiens et livraison.
-- Règles 04/11/2026 : acompte 35 %, puis 65 % sur 7 ou 10 journées EFFECTIVES.
-- Si une matière manque, aucune journée n'avance, aucune échéance n'est débitée.
-- Aucune récupération des journées bloquées : une seule avancée par date Paris.
-- Prix contractuel fixe : les matériaux sont payés au prix réel de l'entrepôt
-- depuis l'enveloppe du contrat, sans double facturation au joueur.
-- Les bateaux sont des biens physiques au port, non navigables avant raccordement
-- du moteur privé (transport commun et douanes).

ALTER TABLE public.chantier_naval_modeles
 ADD COLUMN IF NOT EXISTS jours integer NOT NULL DEFAULT 7 CHECK (jours IN (7,10));
UPDATE public.chantier_naval_modeles SET jours=CASE code WHEN 'bateau_3' THEN 7 ELSE 10 END;

CREATE TABLE IF NOT EXISTS public.chantier_naval_commandes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 requete uuid NOT NULL,
 proprietaire_user_id uuid NOT NULL,
 proprietaire_nom text NOT NULL,
 modele text NOT NULL REFERENCES public.chantier_naval_modeles(code),
 pays text NOT NULL DEFAULT 'republic' CHECK(pays='republic'),
 ville text NOT NULL DEFAULT 'ville_a' CHECK(ville='ville_a'),
 prix_total integer NOT NULL CHECK(prix_total>0),
 acompte integer NOT NULL CHECK(acompte>0),
 jours_total integer NOT NULL CHECK(jours_total>0),
 jours_faits integer NOT NULL DEFAULT 0 CHECK(jours_faits>=0),
 somme_versee numeric NOT NULL DEFAULT 0 CHECK(somme_versee>=0),
 depense_matieres numeric NOT NULL DEFAULT 0 CHECK(depense_matieres>=0),
 matieres_consommees jsonb NOT NULL DEFAULT '{"bois":0,"metal":0,"derives_petrochimiques":0}'::jsonb,
 etat text NOT NULL DEFAULT 'en_construction'
   CHECK(etat IN ('en_construction','bloque_matieres','bloque_finances','acheve')),
 dernier_jour date,
 cree_le timestamptz NOT NULL DEFAULT now(),
 termine_le timestamptz,
 UNIQUE(proprietaire_user_id,requete),
 CHECK(jours_faits<=jours_total),
 CHECK(somme_versee<=prix_total),
 CHECK(depense_matieres<=somme_versee)
);
CREATE TABLE IF NOT EXISTS public.chantier_naval_bateaux (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 commande_id uuid NOT NULL UNIQUE REFERENCES public.chantier_naval_commandes(id),
 proprietaire_user_id uuid NOT NULL,
 proprietaire_nom text NOT NULL,
 modele text NOT NULL REFERENCES public.chantier_naval_modeles(code),
 pays text NOT NULL DEFAULT 'republic',
 ville text NOT NULL DEFAULT 'ville_a',
 port text NOT NULL DEFAULT 'port-sainte-marie',
 passagers integer NOT NULL CHECK(passagers>0),
 capacite_fret integer NOT NULL CHECK(capacite_fret>0),
 cargaison jsonb NOT NULL DEFAULT '{}'::jsonb,
 etat text NOT NULL DEFAULT 'au_port' CHECK(etat='au_port'),
 navigation_active boolean NOT NULL DEFAULT false,
 livre_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.chantier_naval_commandes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chantier_naval_bateaux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chantier_naval_commandes FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.chantier_naval_bateaux FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.chantier_naval_commander(p_modele text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $naval$
DECLARE p public.personnages_donnees%ROWTYPE;
        m public.chantier_naval_modeles%ROWTYPE;
        c public.chantier_naval_commandes%ROWTYPE;
        a integer; v_commande uuid:=gen_random_uuid(); v_rep jsonb;
        v_escrow text;
BEGIN
 IF auth.uid() IS NULL OR p_requete IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','non_authentifie');
 END IF;
 SELECT * INTO p FROM public.personnages_donnees
  WHERE user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
 SELECT * INTO c FROM public.chantier_naval_commandes
  WHERE proprietaire_user_id=p.user_id AND requete=p_requete;
 IF FOUND THEN
  IF c.modele<>p_modele THEN RETURN jsonb_build_object('ok',false,'raison','requete_deja_utilisee'); END IF;
  RETURN jsonb_build_object('ok',true,'rejeu',true,'commande',c.id,'acompte',c.acompte);
 END IF;
 IF p.country<>'republic' OR p.current_city<>'ville_a'
    OR p.current_building<>'chantier-naval' THEN
  RETURN jsonb_build_object('ok',false,'raison','lieu_incorrect');
 END IF;
 SELECT * INTO m FROM public.chantier_naval_modeles WHERE code=p_modele;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','modele_inconnu'); END IF;
 a := (m.prix_total_fr*35)/100;
 v_escrow:='republic_ville_a_chantier-naval-commande-' || v_commande::text;
 IF NOT public.helvetia_debiter_fonds_ordinaires(p.name,a) THEN
  RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants','acompte',a);
 END IF;
 -- L'acompte sort de la poche du PJ et entre dans une caisse séquestre.
 -- Si la caisse ou la commande échoue, toute la transaction (débit compris) est annulée.
 PERFORM set_config('rp.caisse_interne','on',true);
 v_rep:=public.caisse_institution_mouvement(v_escrow,a,false);
 IF (v_rep->>'ok')::boolean IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'naval_sequestre_acompte: %',v_rep;
 END IF;
 PERFORM set_config('rp.caisse_interne','',true);
 INSERT INTO public.chantier_naval_commandes
 (id,requete,proprietaire_user_id,proprietaire_nom,modele,prix_total,acompte,
  jours_total,somme_versee)
 VALUES(v_commande,p_requete,p.user_id,p.name,m.code,m.prix_total_fr,a,m.jours,a)
 RETURNING * INTO c;
 RETURN jsonb_build_object('ok',true,'commande',c.id,'acompte',a,
   'prix_total',c.prix_total,'jours',c.jours_total,'etat',c.etat);
END;$naval$;

-- Routine interne de progression : verrouillage ordre commande / entrepôt /
-- personnage, transactionnelle. Une journée ne peut avancer qu'une fois.
CREATE OR REPLACE FUNCTION public.chantier_naval_avancer_interne(p_commande uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $naval$
DECLARE c public.chantier_naval_commandes%ROWTYPE;
        m public.chantier_naval_modeles%ROWTYPE;
        e jsonb; v_ent jsonb; v_stock jsonb; v_nouveau jsonb; v_prices jsonb;
        jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
        k text; cible int; deja int; besoin int; disponible numeric; prix numeric;
        cout numeric :=0; tranche numeric; base numeric; rep jsonb;
        p public.personnages_donnees%ROWTYPE;
        navire uuid;
        e_id text := 'republic_ville_a_entrepot-logistique-psm';
        escrow_id text;
BEGIN
 -- AUCUN GRANT client : seul service_role pourra appeler cette primitive.
 SELECT * INTO c FROM public.chantier_naval_commandes WHERE id=p_commande FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','commande_absente'); END IF;
 IF c.etat='acheve' OR c.jours_faits>=c.jours_total THEN
  RETURN jsonb_build_object('ok',true,'etat','acheve','jours',c.jours_faits);
 END IF;
 IF c.dernier_jour=jour THEN
  RETURN jsonb_build_object('ok',true,'rejeu',true,'jours',c.jours_faits);
 END IF;
 SELECT * INTO m FROM public.chantier_naval_modeles WHERE code=c.modele;
 escrow_id:='republic_ville_a_chantier-naval-commande-' || c.id::text;
 SELECT public.batiment_etat_lire(data) INTO e FROM public.batiments_etat
  WHERE id=e_id FOR UPDATE;
 IF e IS NULL THEN
  UPDATE public.chantier_naval_commandes SET etat='bloque_matieres' WHERE id=c.id;
  RETURN jsonb_build_object('ok',false,'raison','entrepot_absent');
 END IF;
 v_ent:=coalesce(e->'entrepot','{}'::jsonb);
 v_stock:=coalesce(v_ent->'stock','{}'::jsonb);
 v_prices:=coalesce(v_ent->'prixManuel','{}'::jsonb);
 v_nouveau:=v_stock;
 -- La fraction quotidienne est ceil(total*jour/nbjours) - ceil(total*(jour-1)/nbjours)
 -- afin que la somme exacte des jours soit l'intégralité de chaque matière.
 FOREACH k IN ARRAY ARRAY['bois','metal','derives_petrochimiques'] LOOP
  cible:=CASE k WHEN 'bois' THEN m.bois WHEN 'metal' THEN m.metal
              ELSE m.derives_petrochimiques END;
  besoin:=ceil(cible::numeric*(c.jours_faits+1)/c.jours_total)::int
         -ceil(cible::numeric*c.jours_faits/c.jours_total)::int;
  disponible:=coalesce((v_stock->>k)::numeric,0);
  IF disponible<besoin THEN
   UPDATE public.chantier_naval_commandes SET etat='bloque_matieres' WHERE id=c.id;
   RETURN jsonb_build_object('ok',false,'raison','matieres_insuffisantes',
      'matiere',k,'requis',besoin,'disponible',disponible);
  END IF;
  prix:=coalesce((v_prices->>k)::numeric,
          (SELECT prix_base FROM public.ressources_economie WHERE cle=k));
  IF prix IS NULL OR prix<0 THEN
   RAISE EXCEPTION 'naval_prix_invalide: %',k;
  END IF;
  cout:=cout+besoin*prix;
  v_nouveau:=jsonb_set(v_nouveau,ARRAY[k],to_jsonb(disponible-besoin),true);
 END LOOP;
 -- 65 % restants en échéances exactes. Ne jamais prélever si la journée est bloquée.
 -- A la dernière journée, corriger le reliquat de division.
 tranche:=CASE WHEN c.jours_faits+1=c.jours_total THEN
   c.prix_total-c.somme_versee
  ELSE floor((c.prix_total-c.acompte)::numeric/c.jours_total) END;
 SELECT * INTO p FROM public.personnages_donnees
  WHERE user_id=c.proprietaire_user_id FOR UPDATE;
 IF NOT FOUND THEN
  UPDATE public.chantier_naval_commandes SET etat='bloque_finances' WHERE id=c.id;
  RETURN jsonb_build_object('ok',false,'raison','proprietaire_indisponible');
 END IF;
 IF c.somme_versee + tranche < c.depense_matieres + cout THEN
  UPDATE public.chantier_naval_commandes SET etat='bloque_finances' WHERE id=c.id;
  RETURN jsonb_build_object('ok',false,'raison','prix_matiere_superieur_budget',
    'cout_jour',cout,'caisse_disponible',c.somme_versee-c.depense_matieres+tranche);
 END IF;
 IF NOT public.helvetia_debiter_fonds_ordinaires(p.name,tranche) THEN
  UPDATE public.chantier_naval_commandes SET etat='bloque_finances' WHERE id=c.id;
  RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants',
    'echeance',tranche);
 END IF;
 -- Après le débit, tout incident est une EXCEPTION : annulation totale.
 -- Crédit de l'échéance au séquestre, règlement des matières depuis ce séquestre.
 PERFORM set_config('rp.caisse_interne','on',true);
 rep:=public.caisse_institution_mouvement(escrow_id,tranche,true);
 IF (rep->>'ok')::boolean IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'naval_sequestre_echeance: %',rep;
 END IF;
 IF cout>0 THEN
  rep:=public.caisse_institution_mouvement(escrow_id,-cout,true);
  IF (rep->>'ok')::boolean IS DISTINCT FROM true THEN
   RAISE EXCEPTION 'naval_sequestre_fournisseur: %',rep;
  END IF;
  rep:=public.entrepot_caisse_mouvement(e_id,cout);
  IF (rep->>'ok')::boolean IS DISTINCT FROM true THEN
   RAISE EXCEPTION 'naval_caisse_entrepot: %',rep;
  END IF;
 END IF;
 UPDATE public.batiments_etat SET
  data=to_jsonb((e || jsonb_build_object('entrepot',
       v_ent || jsonb_build_object('stock',v_nouveau)))::text),
  updated_at=now() WHERE id=e_id;
 -- Journal de sortie de stock, basé sur les prix réellement affichés.
 FOREACH k IN ARRAY ARRAY['bois','metal','derives_petrochimiques'] LOOP
  cible:=CASE k WHEN 'bois' THEN m.bois WHEN 'metal' THEN m.metal
              ELSE m.derives_petrochimiques END;
  besoin:=ceil(cible::numeric*(c.jours_faits+1)/c.jours_total)::int
         -ceil(cible::numeric*c.jours_faits/c.jours_total)::int;
  prix:=coalesce((v_prices->>k)::numeric,
        (SELECT prix_base FROM public.ressources_economie WHERE cle=k));
  INSERT INTO public.entrepot_journal
   (entrepot_id,operation,sens,ressource,quantite,prix_unitaire,montant,acteur,jour)
  VALUES (e_id,'chantier_naval','sortie',k,besoin,prix,besoin*prix,c.proprietaire_nom,jour);
 END LOOP;
 UPDATE public.chantier_naval_commandes
   SET jours_faits=c.jours_faits+1, dernier_jour=jour,
       somme_versee=c.somme_versee+tranche, depense_matieres=c.depense_matieres+cout,
       matieres_consommees=jsonb_build_object(
        'bois',ceil(m.bois::numeric*(c.jours_faits+1)/c.jours_total)::int,
        'metal',ceil(m.metal::numeric*(c.jours_faits+1)/c.jours_total)::int,
        'derives_petrochimiques',ceil(m.derives_petrochimiques::numeric*(c.jours_faits+1)/c.jours_total)::int),
       etat=CASE WHEN c.jours_faits+1=c.jours_total THEN 'acheve'
                 ELSE 'en_construction' END,
       termine_le=CASE WHEN c.jours_faits+1=c.jours_total THEN now()
                       ELSE NULL END
 WHERE id=c.id;
 IF c.jours_faits+1=c.jours_total THEN
  -- Paiement du constructeur = prix total - matières effectivement achetées.
  -- La marge globale n'est pas payée deux fois.
  base:=c.prix_total-(c.depense_matieres+cout);
  IF base<0 THEN RAISE EXCEPTION 'naval_budget_negatif'; END IF;
  IF base>0 THEN
   rep:=public.caisse_institution_mouvement(escrow_id,-base,true);
   IF (rep->>'ok')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'naval_sequestre_constructeur: %',rep;
   END IF;
   rep:=public.caisse_institution_mouvement('republic_ville_a_chantier-naval',base,false);
   IF (rep->>'ok')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'naval_caisse_constructeur: %',rep;
   END IF;
  END IF;
  INSERT INTO public.chantier_naval_bateaux
   (commande_id,proprietaire_user_id,proprietaire_nom,modele,
    passagers,capacite_fret)
  VALUES(c.id,c.proprietaire_user_id,c.proprietaire_nom,c.modele,
         m.passagers,m.capacite_fret)
  RETURNING id INTO navire;
 END IF;
 PERFORM set_config('rp.caisse_interne','',true);
 RETURN jsonb_build_object('ok',true,'jours',c.jours_faits+1,
    'total',c.jours_total,'prix_matiere',cout,'echeance',tranche,
    'etat',CASE WHEN navire IS NOT NULL THEN 'acheve' ELSE 'en_construction' END,
    'bateau',navire);
END;$naval$;

CREATE OR REPLACE FUNCTION public.chantier_naval_avancer_jour()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $naval$
DECLARE c record; r jsonb; ok_n integer:=0; bloque_n integer:=0;
BEGIN
 IF NOT public.est_appel_serveur() THEN
  RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur');
 END IF;
 FOR c IN SELECT id FROM public.chantier_naval_commandes
   WHERE etat<>'acheve' ORDER BY cree_le,id
 LOOP
  -- Ne pas masquer les erreurs techniques : tout le batch est atomique et rejouable.
  r:=public.chantier_naval_avancer_interne(c.id);
  IF (r->>'ok')::boolean IS TRUE AND (r->>'rejeu') IS DISTINCT FROM 'true'
   THEN ok_n:=ok_n+1;
  ELSIF (r->>'ok')::boolean IS FALSE THEN bloque_n:=bloque_n+1;
  END IF;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'avances',ok_n,'bloquees',bloque_n);
END;$naval$;

CREATE OR REPLACE FUNCTION public.chantier_naval_mes_commandes()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public,pg_temp
AS $naval$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'id',c.id,'modele',c.modele,'jours',c.jours_faits,'total',c.jours_total,
   'etat',c.etat,'prix_total',c.prix_total,'verse',c.somme_versee,
   'matieres_utilisees',c.matieres_consommees,
   'bateau_id',b.id,'au_port',b.port,'navigable',coalesce(b.navigation_active,false))
  ORDER BY c.cree_le DESC),'[]'::jsonb)
 FROM public.chantier_naval_commandes c
 LEFT JOIN public.chantier_naval_bateaux b ON b.commande_id=c.id
 WHERE auth.uid() IS NOT NULL AND c.proprietaire_user_id=auth.uid();
$naval$;

REVOKE ALL ON FUNCTION public.chantier_naval_commander(text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.chantier_naval_avancer_interne(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.chantier_naval_avancer_jour() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.chantier_naval_mes_commandes() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.chantier_naval_commander(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chantier_naval_mes_commandes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.chantier_naval_avancer_jour() TO service_role;
GRANT EXECUTE ON FUNCTION public.chantier_naval_avancer_interne(uuid) TO service_role;
