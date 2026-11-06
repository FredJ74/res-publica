-- Courrier d'arrivée des caisses terrestres (décision de Fred, 04/11/2026, suite de 20261104181000).
-- fret_arrivees_constater prévient désormais chaque destinataire quand sa caisse arrive. L'écran
-- de chaque joueur connecté l'appelle avec sa lecture du courrier (toutes les minutes) : le
-- courrier part dans la minute qui suit l'échéance, ou à la première connexion suivante. Une caisse
-- n'est constatée qu'une fois (statut en_transit -> arrivee), donc un seul courrier.
CREATE OR REPLACE FUNCTION public.fret_arrivees_constater()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE n integer := 0; c record; v_nom text;
BEGIN
  FOR c IN
    UPDATE public.caisses_fret k
       SET statut = 'arrivee', date_arrivee_reelle = now(),
           quantite_arrivee = (SELECT coalesce(sum(l.quantite), 0) FROM public.contenu_caisses_fret l WHERE l.caisse_id = k.id)
     WHERE k.statut = 'en_transit' AND k.building_destination LIKE 'entrepot-logistique-%'
       AND k.date_arrivee_prevue <= now()
    RETURNING k.destinataire, k.ville_destination, k.declaration_douaniere
  LOOP
    n := n + 1;
    v_nom := CASE c.ville_destination WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                                      WHEN 'ville_b' THEN 'Montrouge' ELSE c.ville_destination END;
    PERFORM public.mail_systeme_poser_interne('Entrepôt Logistique', c.destinataire,
      'Votre caisse est arrivée à l''entrepôt de ' || v_nom,
      coalesce(c.declaration_douaniere || '. ', '') || 'Votre caisse est arrivée à l''Entrepôt Logistique de ' || v_nom ||
      '. Retirez-la à la Salle des ventes, ordre « Réceptionner une caisse ». Sans retrait sous 15 jours, elle sera mise en vente.');
  END LOOP;
  RETURN n;
END $f$;
REVOKE ALL ON FUNCTION public.fret_arrivees_constater() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fret_arrivees_constater() TO authenticated, service_role;
