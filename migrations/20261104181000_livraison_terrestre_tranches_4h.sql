-- Livraison terrestre par tranches de 4 h (décision de Fred, 04/11/2026, suite de 20261104173000).
-- Six livraisons par jour à l'entrepôt (heure de Paris : 0 h, 4 h, 8 h, 12 h, 16 h, 20 h). Une
-- commande passée dans une tranche est livrée à la FIN de la tranche suivante : commander à 7 h
-- (tranche 4 h-8 h) donne une livraison à 12 h. La tâche de minuit ne passant qu'une fois par jour,
-- l'arrivée est constatée par le serveur au moment où l'on regarde (fret_arrivees_constater),
-- seulement pour les caisses terrestres arrivées à échéance ; le fret maritime reste à minuit.

-- 1. Échéance : fin de la tranche suivante, en heure de Paris.
CREATE OR REPLACE FUNCTION public.livraison_terrestre_echeance(p_commande timestamptz)
RETURNS timestamptz LANGUAGE sql STABLE SET search_path = public AS $f$
  SELECT ((date_trunc('day', p_commande AT TIME ZONE 'Europe/Paris')
           + make_interval(hours => (floor(extract(hour FROM p_commande AT TIME ZONE 'Europe/Paris') / 4) * 4)::int)
           + interval '8 hours') AT TIME ZONE 'Europe/Paris');
$f$;
REVOKE ALL ON FUNCTION public.livraison_terrestre_echeance(timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.livraison_terrestre_echeance(timestamptz) TO authenticated, service_role;

-- 2. Courrier : l'heure annoncée est l'échéance elle-même (plus la passe de minuit).
CREATE OR REPLACE FUNCTION public.trading_livraison_courrier_interne(p_dest text, p_ville text, p_prevue timestamptz, p_objet text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_nom text;
BEGIN
  v_nom := CASE p_ville WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                        WHEN 'ville_b' THEN 'Montrouge' ELSE p_ville END;
  PERFORM public.mail_systeme_poser_interne('Entrepôt Logistique', p_dest,
    'Livraison en route vers l''entrepôt de ' || v_nom,
    p_objet || ' Une caisse vous est livrée par voie terrestre à l''Entrepôt Logistique de ' || v_nom ||
    '. Elle sera disponible à partir du ' || to_char(p_prevue AT TIME ZONE 'Europe/Paris', 'DD/MM à HH24') ||
    ' h : rendez-vous à la Salle des ventes de l''entrepôt, ordre « Réceptionner une caisse ».');
EXCEPTION WHEN others THEN
  RAISE WARNING 'courrier_livraison_indisponible: %', SQLSTATE;
END $f$;
REVOKE ALL ON FUNCTION public.trading_livraison_courrier_interne(text, text, timestamptz, text) FROM PUBLIC, anon, authenticated;

-- 3. Achat de trading et offre servie : échéance par tranche au lieu de 24 h.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.trading_acheter(text,text,text,integer,text)'::regprocedure);
  v_new := replace(v_def, $a$  v_prevue := now() + interval '1 day';$a$,
                          $n$  v_prevue := public.livraison_terrestre_echeance(now());$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch trading_acheter non applique'; END IF;
  EXECUTE v_new;

  v_def := pg_get_functiondef('public.offre_achat_servir(uuid,integer,text,text,text)'::regprocedure);
  v_new := replace(v_def,
$a$        true, now(), now(), now(), now() + interval '1 day'
      FROM public.personnages_donnees pd,
           public.trading_livraison_entrepot_interne(o.pays, NULL, o.auteur) d$a$,
$n$        true, now(), now(), now(), public.livraison_terrestre_echeance(now())
      FROM public.personnages_donnees pd,
           public.trading_livraison_entrepot_interne(o.pays, NULL, o.auteur) d$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch offre_achat_servir non applique'; END IF;
  EXECUTE v_new;
END $mig$;

-- 4. Constat des arrivées terrestres échues (même écriture que la tâche de minuit pour le fret).
CREATE OR REPLACE FUNCTION public.fret_arrivees_constater()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE n integer;
BEGIN
  UPDATE public.caisses_fret c
     SET statut = 'arrivee', date_arrivee_reelle = now(),
         quantite_arrivee = (SELECT coalesce(sum(l.quantite), 0) FROM public.contenu_caisses_fret l WHERE l.caisse_id = c.id)
   WHERE c.statut = 'en_transit' AND c.building_destination LIKE 'entrepot-logistique-%'
     AND c.date_arrivee_prevue <= now();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $f$;
REVOKE ALL ON FUNCTION public.fret_arrivees_constater() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fret_arrivees_constater() TO authenticated, service_role;

-- 5. Caisses terrestres déjà en route : échéance recalculée depuis leur heure de commande.
UPDATE public.caisses_fret
   SET date_arrivee_prevue = public.livraison_terrestre_echeance(date_depart)
 WHERE statut = 'en_transit' AND building_destination LIKE 'entrepot-logistique-%' AND date_depart IS NOT NULL;
