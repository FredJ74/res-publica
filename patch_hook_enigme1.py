#!/usr/bin/env python3
PATH = "plateau-core.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """            applyCharToState(state.char);
            updateUI();
            restaurerPositionApresChargement(state.char);
            console.log('Personnage synchronisé depuis Supabase:', char.name);"""
new = """            applyCharToState(state.char);
            updateUI();
            restaurerPositionApresChargement(state.char);
            if (typeof enigme1VerifierDeclenchement === 'function') enigme1VerifierDeclenchement();
            console.log('Personnage synchronisé depuis Supabase:', char.name);"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook ajouté dans plateau-core.js.")
