-- Banc annulé de 20261108013000_sovarka_pouvoir_ministeres : jouer APRÈS la migration, dans la même
-- transaction ; le bloc final lève toujours une exception (rien ne reste). Acteur : Arnie (Sovarka).
CREATE TEMP TABLE banc_r (n serial, cas text, r jsonb) ON COMMIT DROP;
GRANT ALL ON banc_r TO authenticated; GRANT ALL ON SEQUENCE banc_r_n_seq TO authenticated;

INSERT INTO banc_r (cas, r) SELECT 'impot_mo_1000', to_jsonb(public.sovarka_impot_interne(1000, 'tauxMainOeuvre'));
INSERT INTO banc_r (cas, r) SELECT 'taxe_vente_1000', public.appliquer_taxe_transaction('soviet', 'capitale', 1000);
INSERT INTO banc_r (cas, r) SELECT 'taxe_vente_republia', public.appliquer_taxe_transaction('republic', 'capitale', 1000) - 'net';
INSERT INTO banc_r (cas, r) SELECT 'reserve_soviet', (SELECT data->'reserveJour' FROM public.budgets_nationaux WHERE id = 'soviet');

-- Mise en scène : un parti dont Arnie est chef, Arnie à la salle des partis de Novomirsk.
INSERT INTO public.organisations (id, country_origine, data) VALUES ('orga_banc_sov', 'soviet',
  jsonb_build_object('id','orga_banc_sov','type','politique','nom','Parti du Banc','chef','Arnie','country','soviet',
    'sovarkaParti',true,'pop',20,'membres',jsonb_build_array(jsonb_build_object('nom','Arnie','grade','Chef','gradeIdx',3)),
    'demandesAdhesion','[]'::jsonb,'caisse',0,'visible',true)::text);
UPDATE public.personnages_donnees SET current_city = 'capitale', current_building = 'mairie-capitale', current_room = 'salle_partis', pa = 30
 WHERE name = 'Arnie';
INSERT INTO banc_r (cas, r) SELECT 'parti_de_arnie', to_jsonb(public.sovarka_parti_de('Arnie'));

SELECT set_config('request.jwt.claims', '{"sub":"9abef1c4-75ab-4352-b5ca-a219fc37a35c","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
INSERT INTO banc_r (cas, r) SELECT 'lire', public.sovarka_pouvoir_lire() - 'lois' - 'ordre_du_jour';
INSERT INTO banc_r (cas, r) SELECT 'deposer', public.sovarka_pouvoir_commande(gen_random_uuid(), 'loi_deposer',
  '{"type":"rp","titre":"Loi du banc","texte":"Le Parti décrète la gaieté obligatoire."}');
INSERT INTO banc_r (cas, r) SELECT 'deposer_type_invalide', public.sovarka_pouvoir_commande(gen_random_uuid(), 'loi_deposer', '{"type":"x","titre":"a","texte":"b"}');
INSERT INTO banc_r (cas, r) SELECT 'trancher_pas_pm', public.sovarka_pouvoir_commande(gen_random_uuid(), 'loi_trancher', '{"loi":"x","accepter":true}');
INSERT INTO banc_r (cas, r) SELECT 'manif_hors_rue', public.sovarka_pouvoir_commande(gen_random_uuid(), 'manif_soutien', '{}');
INSERT INTO banc_r (cas, r) SELECT 'emarger_pas_depute', public.sovarka_pouvoir_commande(gen_random_uuid(), 'seance_emarger', '{}');
INSERT INTO banc_r (cas, r) SELECT 'sondage_pas_ministre', public.sovarka_pouvoir_commande(gen_random_uuid(), 'sondage_commander', '{"sujet":"Le Parti"}');
INSERT INTO banc_r (cas, r) SELECT 'conscription_pas_ministre', public.sovarka_pouvoir_commande(gen_random_uuid(), 'conscription_declencher', '{}');
INSERT INTO banc_r (cas, r) SELECT 'taux_mo_pas_ministre', public.taux_imposition_fixer('main_oeuvre', 12, 'pilotage_fiscal_budgetaire', 2, 0);
INSERT INTO banc_r (cas, r) SELECT 'sondage_ancien_circuit', public.jauges_ordre_executer('commanditer_sondage', gen_random_uuid(), '{"texte":"x"}');
RESET ROLE;

-- Arnie devient Président du Conseil du Peuple de Sovarka, dans son bureau.
INSERT INTO public.postes_attribues (id, country, poste_id, titulaire, source, updated_at)
VALUES ('banc_pm_sov', 'soviet', 'pm', 'Arnie', 'banc', now() + interval '1 day');
UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','pm','name','Président du Conseil du Peuple'),
       current_building = 'palais-gouvernement', current_room = 'bureaux' WHERE name = 'Arnie';
SELECT set_config('request.jwt.claims', '{"sub":"9abef1c4-75ab-4352-b5ca-a219fc37a35c","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
INSERT INTO banc_r (cas, r) SELECT 'trancher_accepte', public.sovarka_pouvoir_commande(gen_random_uuid(), 'loi_trancher',
  jsonb_build_object('loi', (SELECT id FROM public.assemblee_propositions WHERE titre = 'Loi du banc'), 'accepter', true));
INSERT INTO banc_r (cas, r) SELECT 'autocritique_sans_ministre', public.sovarka_pouvoir_commande(gen_random_uuid(), 'autocritique', '{"ministre":"Personne"}');
INSERT INTO banc_r (cas, r) SELECT 'lire_pm', jsonb_build_object('pm', (public.sovarka_pouvoir_lire())->'pm', 'ministres', (public.sovarka_pouvoir_lire())->'ministres');
RESET ROLE;
INSERT INTO banc_r (cas, r) SELECT 'loi_apres', (SELECT jsonb_build_object('statut', statut, 'appliquee', appliquee_ts IS NOT NULL, 'parti', data->>'parti_nom')
  FROM public.assemblee_propositions WHERE titre = 'Loi du banc');
INSERT INTO banc_r (cas, r) SELECT 'passe', public.sovarka_pouvoir_passe();
INSERT INTO banc_r (cas, r) SELECT 'pop_parti', public.sovarka_parti_pop_interne('orga_banc_sov', -5);

DO $fin$ BEGIN
  RAISE EXCEPTION 'BANC %', (SELECT jsonb_agg(jsonb_build_object(cas, r) ORDER BY n) FROM banc_r);
END $fin$;
