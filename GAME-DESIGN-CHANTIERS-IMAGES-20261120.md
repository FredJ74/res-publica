# Chantier de construction : images par étape et par ville — consigne intégrale

Décisions de Fred du 20/11/2026, consignées mot pour mot avant tout code. À prendre après la distillerie et le lot de Krasnov.

---

1. BUG À CORRIGER : après le lancement d'un chantier (test réel d'Arnie, terrain 3 de Luthécia, 20/11), l'image et l'état du terrain ne se sont mis à jour qu'après un clic sur un bouton. Règle de Fred : jamais besoin de recharger la page. Le lancement, la progression de nuit et la réception doivent se refléter immédiatement à l'écran.

2. IMAGES PAR ÉTAPE, PAR VILLE ET PAR GABARIT
- Une série par ville (style propre à la ville, sans coller à la géographie exacte du terrain) : Luthécia, Montrouge, Port-Sainte-Marie ; prévoir la même structure pour les villes des autres empires.
- Étape selon la progression du chantier : fondations (moins d'un tiers), gros œuvre (du tiers aux deux tiers), façade et finitions (au-delà des deux tiers), puis achevé (après réception).
- Fondations : une image par ville, commune à tous les types de bâtiment.
- Gros œuvre et façade : deux gabarits par ville. Bas = hangar, commerce standard, commerce premium, logements sociaux petit. Haut = building, logements moyen, barre d'immeuble.
- Achevé : une image finale par ville et par type de bâtiment, sans encarts.
- Les fiches actuelles avec encarts (building-construction-terrain.webp, etc.) restent l'illustration du choix du bâtiment à construire, avant le lancement.
- Convention de fichiers, pour que Fred puisse déposer les images sans nouveau code : images/chantiers/<ville>/fondations.webp, gros-oeuvre-bas.webp, gros-oeuvre-haut.webp, facade-bas.webp, facade-haut.webp, final-<palier>.webp (ville = luthecia, montrouge, psm…). Si un fichier manque, repli sur l'image actuelle.
- L'image actuelle du chantier en cours (incrustations « 47 % », « élévation R+2 », « fin prévisionnelle 12/01/2027 ») affiche de fausses informations : elle ne doit plus servir que de repli provisoire, et l'état réel du chantier doit rester lisible dans l'interface du jeu.

3. Fred fournira les images au fur et à mesure (fondations de Luthécia déjà faite, transmise depuis claude.ai). Chantier d'image seule ensuite : fusion sans attendre le contrôle long.
