-- Banc ANNULÉ (#295, 31/10/2026) : caisses des clubs et des organisations.
-- Joue, dans UNE transaction annulée à la fin, sous des identités authentifiées réelles :
--   A. contre-épreuve AVANT la fermeture (écritures abusives acceptées) ;
--   B. les portes serveur (20261031200000) et la fermeture (20261031201000) ;
--   C. les refus et les opérations légitimes.
-- Les sections {{ETAPE1}} / {{ETAPE2}} sont remplacées par le corps des migrations
-- (outils/bancs/banc-caisses-collectives-preparer.py). Aucune ligne ne reste.
BEGIN;
CREATE TEMP TABLE banc(n serial, quoi text, obtenu text, attendu text);
GRANT ALL ON banc TO authenticated; GRANT USAGE ON SEQUENCE banc_n_seq TO authenticated;

CREATE FUNCTION pg_temp.essai(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text;
BEGIN
  EXECUTE p_sql INTO r;
  RETURN coalesce(r, 'ok');
EXCEPTION WHEN OTHERS THEN RETURN 'ERR:' || SQLERRM;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.essai(text) TO authenticated;
CREATE FUNCTION pg_temp.qui(p_nom text) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', json_build_object('sub',
    (SELECT user_id FROM public.personnages_donnees WHERE name = p_nom), 'role', 'authenticated')::text, true);
$f$;
CREATE FUNCTION pg_temp.note(q text, o text, a text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO banc(quoi, obtenu, attendu) VALUES (q, o, a);
$f$;
GRANT EXECUTE ON FUNCTION pg_temp.note(text, text, text) TO authenticated;

-- Décor (serveur) : caisse du club et de l'organisation économique de Jean Jaaj ; Vince membre ordinaire.
UPDATE public.budgets_clubs SET data = jsonb_set(data, '{caisse}', '1000') WHERE id = 'olympique-luthecia';
UPDATE public.budgets_clubs SET data = jsonb_set(data, '{caisse}', '0') WHERE id = 'cheminote-montrouge';
UPDATE public.organisations SET data = jsonb_set(jsonb_set(data::jsonb, '{caisse}', '1000'), '{membres}',
  (data::jsonb->'membres') || '[{"nom":"Vince Kubrick","grade":"Associe","gradeIdx":0}]'::jsonb)::text
 WHERE id = 'orga_1792355539137';

-- ===================================================== A. CONTRE-ÉPREUVE (avant fermeture)
SELECT pg_temp.qui('Vince Kubrick');
SET LOCAL ROLE authenticated;
SELECT pg_temp.note('A1 Vince gonfle la caisse du club (avant)',
  pg_temp.essai($$UPDATE public.budgets_clubs SET data = jsonb_set(data,'{caisse}','999999') WHERE id='olympique-luthecia' RETURNING data->>'caisse'$$), '999999');
SELECT pg_temp.note('A2 Vince vide la caisse de l''organisation de Jean (avant)',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{caisse}','0')::text WHERE id='orga_1792355539137' RETURNING data::jsonb->>'caisse'$$), '0');
RESET ROLE;
-- Remise du décor après la contre-épreuve.
UPDATE public.budgets_clubs SET data = jsonb_set(data, '{caisse}', '1000') WHERE id = 'olympique-luthecia';
UPDATE public.organisations SET data = jsonb_set(data::jsonb, '{caisse}', '1000')::text WHERE id = 'orga_1792355539137';

-- ===================================================== B. MIGRATIONS
{{ETAPE1}}
{{ETAPE2}}

-- ===================================================== C. REFUS
SELECT pg_temp.qui('Vince Kubrick');
SET LOCAL ROLE authenticated;
SELECT pg_temp.note('C1 Vince gonfle sa caisse de club',
  pg_temp.essai($$UPDATE public.budgets_clubs SET data = jsonb_set(data,'{caisse}','999999') WHERE id='olympique-luthecia' RETURNING data->>'caisse'$$), 'ERR:permission denied');
SELECT pg_temp.note('C2 Vince crée une caisse de club',
  pg_temp.essai($$INSERT INTO public.budgets_clubs(id,data) VALUES ('olympique-luthecia-bis','{"caisse":5}') RETURNING id$$), 'ERR:permission denied');
SELECT pg_temp.note('C3 Vince vide la caisse de l''organisation de Jean (caisse conservée)',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{caisse}','0')::text WHERE id='orga_1792355539137' RETURNING data::jsonb->>'caisse'$$), '1000');
SELECT pg_temp.note('C4 Vince se proclame chef de l''organisation de Jean',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{chef}','"Vince Kubrick"')::text WHERE id='orga_1792355539137' RETURNING data::jsonb->>'chef'$$), 'ERR:organisation_direction_non_autorisee');
SELECT pg_temp.note('C5 Vince s''attribue le grade du chef (grade conservé)',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{membres}',
     (SELECT jsonb_agg(CASE WHEN e->>'nom'='Vince Kubrick' THEN e || '{"gradeIdx":4,"grade":"PDG"}' ELSE e END)
        FROM jsonb_array_elements(data::jsonb->'membres') e))::text
   WHERE id='orga_1792355539137'
   RETURNING (SELECT e->>'gradeIdx' FROM jsonb_array_elements(data::jsonb->'membres') e WHERE e->>'nom'='Vince Kubrick')$$), '0');
SELECT pg_temp.note('C6 Vince exclut Jean (membre conservé)',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{membres}',
     (SELECT coalesce(jsonb_agg(e),'[]') FROM jsonb_array_elements(data::jsonb->'membres') e WHERE e->>'nom'<>'Jean Jaaj'))::text
   WHERE id='orga_1792355539137'
   RETURNING (SELECT count(*)::text FROM jsonb_array_elements(data::jsonb->'membres') e WHERE e->>'nom'='Jean Jaaj')$$), '1');
SELECT pg_temp.note('C7 Vince se nomme trésorier (trésorier conservé)',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{tresorier}','"Vince Kubrick"')::text WHERE id='orga_1792355539137' RETURNING coalesce(data::jsonb->>'tresorier','aucun')$$), 'aucun');
SELECT pg_temp.note('C8 Vince supprime l''organisation de Jean',
  pg_temp.essai($$DELETE FROM public.organisations WHERE id='orga_1792355539137' RETURNING id$$), 'ERR:permission denied');
SELECT pg_temp.note('C9 Vince fonde une organisation avec 5000 FR en caisse',
  pg_temp.essai($$INSERT INTO public.organisations(id,country_origine,data) VALUES ('orga_banc','republic','{"type":"economique","chef":"Vince Kubrick","fondateur":"Vince Kubrick","caisse":5000,"membres":[]}') RETURNING id$$), 'ERR:organisation_caisse_initiale_interdite');
SELECT pg_temp.note('C10 Vince verse les dividendes de l''organisation de Jean',
  pg_temp.essai($$SELECT public.organisation_ordre_financier('banc-c10-0000000001','orga_1792355539137','orga_dividendes')->>'raison'$$), 'pas_gestionnaire_caisse');
SELECT pg_temp.note('C11 Vince verse une subvention ministérielle sans être ministre',
  pg_temp.essai($$SELECT public.subvention_collective_verser('banc-c11-0000000001','club_sportif','olympique-luthecia',5000)->>'ok'$$), 'ERR:…');
SELECT pg_temp.note('C12 Vince fixe les salaires d''un club qu''il ne préside pas',
  pg_temp.essai($$SELECT public.club_salaires_fixer('olympique-luthecia',99999,99999,99999)->>'raison'$$), 'reserve_au_president');
SELECT pg_temp.note('C13 Vince forge une offre de transfert',
  pg_temp.essai($$INSERT INTO public.transferts_clubs(id,statut,data) VALUES ('transfert-banc-forge','attente_joueur','{"statut":"attente_joueur","joueur":"Vince Kubrick","clubDepartId":"olympique-luthecia","clubArriveeId":"cheminote-montrouge","prixClub":100}') RETURNING id$$), 'ERR:transfert_offre_non_autorisee');
SELECT pg_temp.note('C14 Sponsoring sans les fonds : refus, rien crédité',
  pg_temp.essai($$SELECT public.club_sponsoriser('banc-c14-0000000001','olympique-luthecia',3000)->>'raison' || ' / caisse=' || (SELECT data->>'caisse' FROM public.budgets_clubs WHERE id='olympique-luthecia')$$), 'fonds_insuffisants / caisse=1000');
RESET ROLE;

-- ===================================================== C'. OPÉRATIONS LÉGITIMES
SELECT pg_temp.qui('Jean Jaaj');
SET LOCAL ROLE authenticated;
SELECT pg_temp.note('L1 Jean (chef) verse les dividendes',
  pg_temp.essai($$SELECT (r->>'ok') || ' montant=' || (r->>'montant') || ' caisse=' || (r->>'caisse')
     FROM (SELECT public.organisation_ordre_financier('banc-l1-00000000001','orga_1792355539137','orga_dividendes') r) x$$), 'true montant=300 caisse=700');
SELECT pg_temp.note('L2 Rejeu de la même requête : rien n''est versé deux fois',
  pg_temp.essai($$SELECT (r->>'rejeu') || ' caisse=' || (SELECT data::jsonb->>'caisse' FROM public.organisations WHERE id='orga_1792355539137')
     FROM (SELECT public.organisation_ordre_financier('banc-l1-00000000001','orga_1792355539137','orga_dividendes') r) x$$), 'true caisse=700');
SELECT pg_temp.note('L3 Jean (chef) promeut Vince',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{membres}',
     (SELECT jsonb_agg(CASE WHEN e->>'nom'='Vince Kubrick' THEN e || '{"gradeIdx":1}' ELSE e END)
        FROM jsonb_array_elements(data::jsonb->'membres') e))::text
   WHERE id='orga_1792355539137'
   RETURNING (SELECT e->>'gradeIdx' FROM jsonb_array_elements(data::jsonb->'membres') e WHERE e->>'nom'='Vince Kubrick')$$), '1');
SELECT pg_temp.note('L4 Jean (chef) nomme un trésorier',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{tresorier}','"Vince Kubrick"')::text WHERE id='orga_1792355539137' RETURNING data::jsonb->>'tresorier'$$), 'Vince Kubrick');
SELECT pg_temp.note('L5 Jean n''est plus gestionnaire une fois le trésorier nommé',
  pg_temp.essai($$SELECT public.organisation_ordre_financier('banc-l5-00000000001','orga_1792355539137','orga_dividendes')->>'raison'$$), 'pas_gestionnaire_caisse');
RESET ROLE;

SELECT pg_temp.qui('Vince Kubrick');
SET LOCAL ROLE authenticated;
SELECT pg_temp.note('L6 Vince cotise au club de supporters (+50 caisse)',
  pg_temp.essai($$SELECT (r->>'ok') || ' caisse=' || (r->>'caisse') FROM (SELECT public.club_supporters_cotiser('banc-l6-00000000001','olympique-luthecia') r) x$$), 'true caisse=1050');
SELECT pg_temp.note('L7 Rejeu de la cotisation : un seul encaissement',
  pg_temp.essai($$SELECT (r->>'rejeu') || ' caisse=' || (SELECT data->>'caisse' FROM public.budgets_clubs WHERE id='olympique-luthecia') FROM (SELECT public.club_supporters_cotiser('banc-l6-00000000001','olympique-luthecia') r) x$$), 'true caisse=1050');
SELECT pg_temp.note('L8 Vince, devenu trésorier, dispose de la caisse',
  pg_temp.essai($$SELECT (r->>'ok') || ' montant=' || (r->>'montant') FROM (SELECT public.organisation_ordre_financier('banc-l8-00000000001','orga_1792355539137','orga_dividendes') r) x$$), 'true montant=210');
SELECT pg_temp.note('L9 Vince rejoint une organisation au grade 0 (adhésion ordinaire conservée)',
  pg_temp.essai($$UPDATE public.organisations SET data = jsonb_set(data::jsonb,'{membres}',
     (data::jsonb->'membres') || '[{"nom":"Vince Kubrick","grade":"Membre","gradeIdx":0}]')::text
   WHERE id='orga_1792166277858'
   RETURNING (SELECT count(*)::text FROM jsonb_array_elements(data::jsonb->'membres') e WHERE e->>'nom'='Vince Kubrick')$$), '1');
RESET ROLE;

-- Transfert : décor serveur (offre acceptée par les clubs), le joueur conclut.
INSERT INTO public.transferts_clubs(id, statut, data) VALUES ('transfert-banc-1', 'attente_joueur',
  '{"statut":"attente_joueur","joueur":"Vince Kubrick","clubDepartId":"olympique-luthecia","clubArriveeId":"cheminote-montrouge","prixClub":400,"proposePar":"X"}');
SELECT pg_temp.qui('Vince Kubrick');
SET LOCAL ROLE authenticated;
SELECT pg_temp.note('L10 Transfert refusé : le club d''arrivée n''a pas les fonds (aucun crédit)',
  pg_temp.essai($$SELECT (public.club_transfert_conclure('transfert-banc-1')->>'raison') || ' depart=' || (SELECT data->>'caisse' FROM public.budgets_clubs WHERE id='olympique-luthecia')$$), 'caisse_club_insuffisante depart=1050');
RESET ROLE;
UPDATE public.budgets_clubs SET data = jsonb_set(data, '{caisse}', '500') WHERE id = 'cheminote-montrouge';
SELECT pg_temp.qui('Vince Kubrick');
SET LOCAL ROLE authenticated;
SELECT pg_temp.note('L11 Transfert conclu : 400 passent de l''arrivée au départ',
  pg_temp.essai($$SELECT (r->>'ok') || ' arrivee=' || (r->>'caisseArrivee') || ' depart=' || (r->>'caisseDepart') FROM (SELECT public.club_transfert_conclure('transfert-banc-1') r) x$$), 'true arrivee=100 depart=1450');
SELECT pg_temp.note('L12 Transfert rejoué : rien ne bouge',
  pg_temp.essai($$SELECT (public.club_transfert_conclure('transfert-banc-1')->>'rejeu') || ' depart=' || (SELECT data->>'caisse' FROM public.budgets_clubs WHERE id='olympique-luthecia')$$), 'true depart=1450');
SELECT pg_temp.note('L13 Le joueur ne peut pas marquer lui-même le transfert « conclu »',
  pg_temp.essai($$UPDATE public.transferts_clubs SET data = data || '{"concluPar":"Vince Kubrick"}' WHERE id='transfert-banc-1' RETURNING id$$), 'ERR:transfert_termes_immuables ou etape');
RESET ROLE;

DO $$ BEGIN RAISE EXCEPTION 'BANC %', (SELECT string_agg(n || ' ' || quoi || ' => ' || obtenu || '   [attendu ' || attendu || ']', E'\n' ORDER BY n) FROM banc); END $$;
