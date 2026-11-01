-- SEED -- scandales_predefinis
-- ============================================================================
-- Table      : public.scandales_predefinis
-- Domaine    : presse
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 10
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Contenu authored du monde : lieux, caractéristiques territoriales,
-- personnages ou récits propres aux empires. La mécanique reste commune ; ne
-- pas partager ni uniformiser ce contenu pour créer un autre empire.
--
-- ARBITRAGE DE GAME DESIGN
-- Structure constatée dans les exports canoniques du 31/10/2026. Aucun
-- compte de lignes déduit du schéma. Compte SQL relevé en lecture seule par
-- ChatGPT, commit 2a71eaf77dac83370a02c4f12cd71b502a20d772, 31/10/2026 ; ne
-- prouve pas la possession des lignes ni leur actualité au prochain point de
-- coupe.
-- ============================================================================

INSERT INTO public.scandales_predefinis (id, texte) VALUES ('1', 'Le Ministre des Finances a été surpris à frauder sa propre déclaration d''impôts. Il invoque ''une erreur de formulaire en triple exemplaire''.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('2', 'Le Premier Ministre a été aperçu au Laboratoire de Prière d''El Estado. Il parle d''un ''voyage diplomatique culturel intensif''.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('3', 'Le Président refuse de signer un décret car il manque le tampon numéro 7. Le pays est paralysé depuis 48 heures.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('4', 'Le Grand Prêtre du Papyrusisme a été surpris sans ses formulaires. Le Tabernacle est en état de choc.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('5', 'Un député s''est endormi pendant le vote d''une loi et a voté Pour et Contre simultanément. La loi est en suspens.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('6', 'Le Commissaire Raoul Toufaud a perdu ses menottes. Il s''est menotté lui-même par erreur en cherchant à les retrouver.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('7', 'Le Ministre de l''Information a censuré son propre communiqué de presse par inadvertance.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('8', 'Un loukoum contaminé sème la panique à Al-Khalija. Le Grand Confiseur Abdul Loukoum est introuvable.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('9', 'Le Camarade Pontife Tractorenko a béni un tracteur privé par erreur. L''hérésie est totale.');
INSERT INTO public.scandales_predefinis (id, texte) VALUES ('10', 'Le Juge Honoré Cozetoujours a condamné son propre greffier avant d''entendre l''affaire. Il ''assume pleinement''.');
