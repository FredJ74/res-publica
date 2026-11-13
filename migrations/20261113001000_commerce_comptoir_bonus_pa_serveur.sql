-- Bonus de PA au prochain sommeil des plats achetés au comptoir (« Consulter la carte »), 13/11/2026.
-- Jusqu'ici l'écran appelait pa_bonus_differe_crediter APRÈS la vente, sans attendre la réponse :
-- un échec laissait le joueur payé sans bonus, en silence. Le bonus est désormais crédité dans la
-- même transaction que la vente, par la porte publique commerce_vendre_produit, en mode comptoir
-- seulement. Le moteur interne n'est pas touché : les dîners (restaurant_diner_servir,
-- diner_commerce_servir_interne) et le service d'étage (service_etage_commander) créditent déjà leur
-- propre bonus et l'appellent directement — aucun double crédit.
-- Montant : celui de pa_bonus_differes (source = identifiant du produit), par unité achetée ;
-- seulement pour un plat consommé (pas un produit de marché déposé en inventaire) qui porte paDiffere.
CREATE OR REPLACE FUNCTION public.commerce_vendre_produit(p_acteur text, p_entreprise text, p_produits jsonb, p_mode text DEFAULT 'comptoir'::text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_regle_pa text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v jsonb; l jsonb; n integer; c jsonb; total integer;
BEGIN
  -- 27/10/2026 : le marche noir passe par crime_acheter_arme_noire (jet, denonciation, trace).
  IF p_mode = 'marche_noir' THEN RETURN jsonb_build_object('ok', false, 'raison', 'marche_noir_par_le_serveur'); END IF;
  -- 27/10/2026 : une arme achetee au comptoir est deposee par arme_acheter.
  IF p_ordre = 'choisir_arme' THEN RETURN jsonb_build_object('ok', false, 'raison', 'achat_arme_par_le_serveur'); END IF;
  v := public.commerce_vendre_produit_interne(p_acteur, p_entreprise, p_produits, p_mode, p_ordre, p_pa, p_cost, p_regle_pa, NULL);
  -- comptoir_bonus_pa_v1 (13/11/2026) : bonus de sommeil du plat crédité dans la vente.
  IF p_mode = 'comptoir' AND (v->>'ok')::boolean IS TRUE AND jsonb_typeof(v->'livraison') = 'array' THEN
    FOR l IN SELECT value FROM jsonb_array_elements(v->'livraison') LOOP
      IF l->'familleProduitMarche' IS NULL OR jsonb_typeof(l->'familleProduitMarche') = 'null' THEN
        IF coalesce((l->'effets'->>'paDiffere')::numeric, 0) > 0 THEN
          FOR n IN 1 .. greatest(1, coalesce((l->>'qte')::integer, 1)) LOOP
            c := public.pa_bonus_differe_crediter(p_acteur, l->>'produit');
            IF (c->>'ok')::boolean IS TRUE THEN total := (c->>'bonus_differe')::integer; END IF;
          END LOOP;
        END IF;
      END IF;
    END LOOP;
    IF total IS NOT NULL THEN v := v || jsonb_build_object('bonus_pa_differe', total); END IF;
  END IF;
  RETURN v;
END; $function$;
