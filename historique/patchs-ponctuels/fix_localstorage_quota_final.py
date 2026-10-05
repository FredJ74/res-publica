#!/usr/bin/env python3

# --- creation.js (2 occurrences) ---
PATH_CREATION = "creation.js"
with open(PATH_CREATION, "r", encoding="utf-8") as f:
    creation = f.read()

old_a = """    localStorage.setItem('respublica_char_' + charData.name, JSON.stringify(charData));
    localStorage.setItem('respublica_char', JSON.stringify(charData));"""
new_a = """    try {
      localStorage.setItem('respublica_char_' + charData.name, JSON.stringify(charData));
      localStorage.setItem('respublica_char', JSON.stringify(charData));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }"""
assert creation.count(old_a) == 1, f"creation.js occ.1 : trouvé {creation.count(old_a)} fois (attendu 1)"
creation = creation.replace(old_a, new_a)

old_b = """    localStorage.setItem('respublica_char_' + char.name, JSON.stringify(char));
    // Clé générique = pointeur vers le dernier personnage actif
    localStorage.setItem('respublica_char', JSON.stringify(char));
    localStorage.setItem('respublica_last_char', char.name);"""
new_b = """    try {
      localStorage.setItem('respublica_char_' + char.name, JSON.stringify(char));
      // Clé générique = pointeur vers le dernier personnage actif
      localStorage.setItem('respublica_char', JSON.stringify(char));
      localStorage.setItem('respublica_last_char', char.name);
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }"""
assert creation.count(old_b) == 1, f"creation.js occ.2 : trouvé {creation.count(old_b)} fois (attendu 1)"
creation = creation.replace(old_b, new_b)

with open(PATH_CREATION, "w", encoding="utf-8") as f:
    f.write(creation)

# --- plateau-core.js (1 occurrence) ---
PATH_CORE = "plateau-core.js"
with open(PATH_CORE, "r", encoding="utf-8") as f:
    core = f.read()

old_c = """    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
  }
  buildCityTabs();"""
new_c = """    try {
      localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
  }
  buildCityTabs();"""
assert core.count(old_c) == 1, f"plateau-core.js : trouvé {core.count(old_c)} fois (attendu 1)"
core = core.replace(old_c, new_c)

with open(PATH_CORE, "w", encoding="utf-8") as f:
    f.write(core)

print("✅ Les 3 dernières occurrences sont maintenant protégées (creation.js x2, plateau-core.js x1).")
