-- A jouer APRES le corps de la migration 20261104181000, dans la meme transaction annulee.
-- Echeances par tranches de 4 h (heure de Paris) et constat des arrivees terrestres echues.
DO $$
DECLARE e text; n integer; c uuid;
BEGIN
  SELECT string_agg(to_char(public.livraison_terrestre_echeance(t::timestamptz) AT TIME ZONE 'Europe/Paris', 'DD HH24:MI'), ' ' ORDER BY t)
    INTO e FROM unnest(ARRAY['2026-11-04 07:00 Europe/Paris', '2026-11-04 08:00 Europe/Paris',
                             '2026-11-04 17:10 Europe/Paris', '2026-11-04 23:30 Europe/Paris']) t;
  IF e <> '04 12:00 04 16:00 05 00:00 05 04:00' THEN RAISE EXCEPTION 'echeances: %', e; END IF;
  INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
      ville_destination, building_destination, statut, dedouanee, date_depart, date_arrivee_prevue)
  VALUES ('Jean Jaaj', 'republic', 'ville_b', 'entrepot-logistique-montrouge', 'Jean Jaaj', 'republic',
      'capitale', 'entrepot-logistique-luthecia', 'en_transit', true, now() - interval '9 hours', now() - interval '1 minute')
  RETURNING id INTO c;
  INSERT INTO public.contenu_caisses_fret (caisse_id, deposant, objet, quantite)
  VALUES (c, 'Jean Jaaj', '{"name":"bois","stackable":true,"stackKey":"bois"}', 3);
  n := public.fret_arrivees_constater();
  IF (SELECT statut || '/' || quantite_arrivee FROM public.caisses_fret WHERE id = c) <> 'arrivee/3' THEN
    RAISE EXCEPTION 'constat: %', (SELECT statut FROM public.caisses_fret WHERE id = c); END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (echeances %, % caisse(s) constatee(s))', e, n;
END $$;
