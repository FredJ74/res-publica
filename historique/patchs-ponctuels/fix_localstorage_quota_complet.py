#!/usr/bin/env python3
PATH_NAV = "plateau-navigation.js"
with open(PATH_NAV, "r", encoding="utf-8") as f:
    nav = f.read()

# --- Occurrence 1 : enterRoom (lignes ~385-394) ---
old_a = """    localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
    // Pousser aussi vers Supabase pour que la position survive a un rafraichissement avant la prochaine sauvegarde periodique
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }
  }"""
new_a = """    try {
      localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    // Pousser aussi vers Supabase pour que la position survive a un rafraichissement avant la prochaine sauvegarde periodique
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }
  }"""
assert nav.count(old_a) == 1, f"occurrence 1 : trouvé {nav.count(old_a)} fois (attendu 1)"
nav = nav.replace(old_a, new_a)

# --- Occurrence 2 : sortie de batiment (lignes ~580-587) ---
old_b = """    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }"""
new_b = """    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    try {
      localStorage.setItem('respublica_char_' + (state.char.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    if (typeof sbSavePersonnage === 'function') {
      sbSavePersonnage(state).catch(() => {});
    }"""
assert nav.count(old_b) == 1, f"occurrence 2 : trouvé {nav.count(old_b)} fois (attendu 1)"
nav = nav.replace(old_b, new_b)

# --- Occurrence 3 : changement de ville (lignes ~1166-1170) ---
old_c = """    state.char.currentCity = villeId;
    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
  }"""
new_c = """    state.char.currentCity = villeId;
    state.char.currentBuilding = null;
    state.char.currentRoom = null;
    try {
      localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
  }"""
assert nav.count(old_c) == 1, f"occurrence 3 : trouvé {nav.count(old_c)} fois (attendu 1)"
nav = nav.replace(old_c, new_c)

with open(PATH_NAV, "w", encoding="utf-8") as f:
    f.write(nav)

print("✅ Les 3 occurrences dans plateau-navigation.js sont maintenant protégées contre le quota localStorage.")
