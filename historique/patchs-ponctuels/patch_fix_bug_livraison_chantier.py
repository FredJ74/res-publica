#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      } else if (ch.palierPaye >= 3 && maintenant >= ch.dateFinPrevue) {
        // Livraison
        const niveau = NIVEAUX_CONSTRUCTION_SERVEUR[ch.niveau];
        etat.niveau_construction = ch.niveau;
        etat.constructionAutorisee = true;
        delete etat.chantier;
        resultats.livraisons++;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Chantier livré !',
          corps: 'Le chantier est terminé : ' + (niveau ? niveau.label : ch.niveau) + ' livré. Les clés vous attendent sur place.',
          archived: false
        }).catch(() => {});
      } else if (Math.random() < 0.08) {"""
new = """      } else if (ch.palierPaye >= 3 && maintenant >= ch.dateFinPrevue) {
        // Livraison
        const niveau = NIVEAUX_CONSTRUCTION_SERVEUR[ch.niveau];
        etat.niveau_construction = ch.niveau;
        etat.constructionAutorisee = true;
        delete etat.chantier;
        resultats.livraisons++;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Chantier livré !',
          corps: 'Le chantier est terminé : ' + (niveau ? niveau.label : ch.niveau) + ' livré. Les clés vous attendent sur place.',
          archived: false
        }).catch(() => {});
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
        continue;
      } else if (Math.random() < 0.08) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """      if (modifie) {
        etat.chantier = ch.niveau ? ch : undefined; // si livre, chantier a deja ete supprime plus haut
        if (etat.chantier === undefined) delete etat.chantier;
        else etat.chantier = ch;
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      }"""
new_2 = """      if (modifie) {
        etat.chantier = ch;
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      }"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bug corrigé : la livraison sauvegarde et sort de la boucle immédiatement (continue), sans que le chantier soit remis par erreur.")
