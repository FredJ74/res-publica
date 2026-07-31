#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    state.char.currentCity = cityKey;
    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
  }"""
new = """    state.char.currentCity = cityKey;
    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    try {
      localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Dernière occurrence protégée dans plateau-justice-economie.js")
