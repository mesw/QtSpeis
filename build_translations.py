# -*- coding: utf-8 -*-
import sys
import os
import re
import subprocess
import xml.etree.ElementTree as ET
import xml.sax.saxutils as saxutils

sys.stdout.reconfigure(encoding='utf-8')

# 1. Parse existing translations/qtspeis_de.ts
tree = ET.parse('translations/qtspeis_de.ts')
master_dict = {} # key -> {'en': ..., 'de': ...}

for m in tree.findall('.//message'):
    src = m.find('source')
    trn = m.find('translation')
    ext = m.find('extracomment')
    s = src.text.strip() if src is not None and src.text else ''
    t = trn.text.strip() if trn is not None and trn.text else ''
    e = ext.text.strip() if ext is not None and ext.text else ''
    
    if not s:
        continue
        
    en_val = ''
    if e.startswith('English: '):
        en_val = e[9:].strip()
    
    if not en_val and s != t:
        en_val = s
        
    if s not in master_dict:
        master_dict[s] = {'en': en_val, 'de': t}
    else:
        if t and not master_dict[s]['de']:
            master_dict[s]['de'] = t
        if en_val and not master_dict[s]['en']:
            master_dict[s]['en'] = en_val

# 2. Parse languagemanager.cpp
with open('languagemanager.cpp', 'r', encoding='utf-8') as f:
    lm = f.read()

en_dict = dict(re.findall(r'm_enDict\[QStringLiteral\("([^"]+)"\)\]\s*=\s*QStringLiteral\("([^"]*)"\);', lm))
de_dict = dict(re.findall(r'm_deDict\[QStringLiteral\("([^"]+)"\)\]\s*=\s*QStringLiteral\("([^"]*)"\);', lm))

for k, v in en_dict.items():
    if k not in master_dict:
        master_dict[k] = {'en': v, 'de': ''}
    else:
        if v and not master_dict[k]['en']:
            master_dict[k]['en'] = v

for k, v in de_dict.items():
    if k not in master_dict:
        master_dict[k] = {'en': '', 'de': v}
    else:
        if v and not master_dict[k]['de']:
            master_dict[k]['de'] = v

# 3. Explicit definitions with improved correctness, style, and biochemical domain accuracy
curated_updates = {
    # ── Level Biochemical Rules (User preferences) ──
    "Stoichiometric Enhancer Pairing (Rule 3)": ("Iron-Booster (Rule 3)", "Eisen-Booster (Regel 3)"),
    "Iron-Booster (Rule 3)": ("Iron-Booster (Rule 3)", "Eisen-Booster (Regel 3)"),
    "Eisen-Booster (Regel 3)": ("Iron-Booster (Rule 3)", "Eisen-Booster (Regel 3)"),
    "Culinary De-Phytinization (Rule 4)": ("Phytate Reduction (Rule 4)", "Phytat-Reduktion (Regel 4)"),
    "Phytate Reduction (Rule 4)": ("Phytate Reduction (Rule 4)", "Phytat-Reduktion (Regel 4)"),
    "Phytat-Reduktion (Rule 4)": ("Phytate Reduction (Rule 4)", "Phytat-Reduktion (Regel 4)"),
    "Pre-Workout Gastric Emptying & Glycemic Stability": ("Pre-Workout Gastric Emptying & Glycemic Stability", "Pre-Workout Glykämie & Magenverweildauer"),
    "The Post-Exercise Hepcidin Window (Rule 7)": ("Hepcidin Window (Rule 7)", "Hepcidin-Fenster (Regel 7)"),
    "Hepcidin Window (Rule 7)": ("Hepcidin Window (Rule 7)", "Hepcidin-Fenster (Regel 7)"),
    "Hepcidin-Fenster (Regel 7)": ("Hepcidin Window (Rule 7)", "Hepcidin-Fenster (Regel 7)"),

    # ── Athletic Profiles & Energy Formulation ──
    "Endurance with High Power": ("Endurance with high strength demand", "Ausdauersport mit hohem Krafteinsatz"),
    "Ausdauersport mit hohem Krafteinsatz": ("Endurance with high strength demand", "Ausdauersport mit hohem Krafteinsatz"),
    "Base Calorie Need (BMR)": ("Basal Metabolic Rate", "Grundumsatz"),
    "base_calories": ("Basal Metabolic Rate", "Grundumsatz"),
    "Personalize your resting energy needs (Grundumsatz)": ("Personalize your resting energy expenditure", "Passe deinen täglichen Ruheenergiebedarf (Grundumsatz) an"),

    # ── 32 Authentic Chef Recipes ──
    "Milchreis mit Pfirsich und Honig": ("Rice Pudding with Peach & Honey", "Milchreis mit Pfirsich und Honig"),
    "Hirsebrei": ("Millet Porridge", "Hirsebrei"),
    "Apfelmüsli": ("Apple Muesli", "Apfelmüsli"),
    "Himbeer-Apfel-Müsli": ("Raspberry Apple Muesli", "Himbeer-Apfel-Müsli"),
    "Klassisches Frühstück": ("Classic Breakfast", "Klassisches Frühstück"),
    "Bananen-Himbeer Shake": ("Banana Raspberry Shake", "Bananen-Himbeer Shake"),
    "Bananen-Shake": ("Banana Shake", "Bananen-Shake"),
    "Schoko Shake": ("Chocolate Shake", "Schoko Shake"),
    "Birnen-Jogurt Shake": ("Pear Yogurt Shake", "Birnen-Jogurt Shake"),
    "Tunfischaufstrich": ("Tuna Spread", "Tunfischaufstrich"),
    "Schinkenaufstrich": ("Ham Spread", "Schinkenaufstrich"),
    "Dilltopfen": ("Dill Curd Spread", "Dilltopfen"),
    "Kartoffelkäse": ("Potato Spread (Kartoffelkäse)", "Kartoffelkäse"),
    "Tunfischsalat": ("Tuna Salad", "Tunfischsalat"),
    "Hering-Apfel-Salat": ("Herring & Apple Salad", "Hering-Apfel-Salat"),
    "Karottencremesuppe": ("Cream of Carrot Soup", "Karottencremesuppe"),
    "Zucchinicremesuppe": ("Cream of Zucchini Soup", "Zucchinicremesuppe"),
    "Gemüseauflauf mit Penne": ("Vegetable Penne Bake", "Gemüseauflauf mit Penne"),
    "Spaghetti mit Tomatensoße": ("Spaghetti with Tomato Sauce", "Spaghetti mit Tomatensoße"),
    "Makkaroni mit Ricottasoße": ("Macaroni with Ricotta Sauce", "Makkaroni mit Ricottasoße"),
    "Gemüse-Lasagne": ("Vegetable Lasagna", "Gemüse-Lasagne"),
    "Tortilla Wrap mit Putenfleisch und Käse": ("Turkey & Cheese Tortilla Wrap", "Tortilla Wrap mit Putenfleisch und Käse"),
    "Asiatische Hühnerbrust": ("Asian Style Chicken Breast", "Asiatische Hühnerbrust"),
    "Couscous mit Gemüse": ("Couscous with Vegetables", "Couscous mit Gemüse"),
    "Vegetarisches Chili": ("Vegetarian Chili", "Vegetarisches Chili"),
    "Reis mit Pilzen": ("Mushroom Rice", "Reis mit Pilzen"),
    "Erdäpfelpfanne": ("Potato Hash Pan", "Erdäpfelpfanne"),
    "Überbackenes Fischfilet": ("Baked Fish Fillet au Gratin", "Überbackenes Fischfilet"),
    "Dorsch mit Brokkoli": ("Cod with Steamed Broccoli", "Dorsch mit Brokkoli"),
    "Pfirsich-Topfencreme": ("Peach Quark Cream", "Pfirsich-Topfencreme"),
    "Apfelnockerln mit Nüssen": ("Apple Dumplings with Nuts", "Apfelnockerln mit Nüssen"),
    "Kaiserschmarrn": ("Kaiserschmarrn (Austrian Shredded Pancake)", "Kaiserschmarrn"),

    # ── Recipe Categories ──
    "Frühstück & Breie": ("Breakfast & Porridge", "Frühstück & Breie"),
    "Aufstriche & Salate": ("Spreads & Salads", "Aufstriche & Salate"),
    "Suppen & Nudelgerichte": ("Soups & Pasta", "Suppen & Nudelgerichte"),
    "Hauptgerichte": ("Main Dishes", "Hauptgerichte"),
    "Süßspeisen": ("Desserts & Sweet Dishes", "Süßspeisen"),
    "Custom": ("Custom", "Eigene"),

    # ── Nutrients & Units ──
    "Calories": ("Calories", "Kalorien"),
    "Carbohydrates": ("Carbohydrates", "Kohlenhydrate"),
    "Protein": ("Protein", "Eiweiß"),
    "Fat": ("Fat", "Fett"),
    "Carbs": ("Carbs", "Kohlenhydrate"),
    "Amount:": ("Amount:", "Menge:"),
    "grams": ("grams", "Gramm"),
    "Target Meal:": ("Target Meal:", "Ziel-Mahlzeit:"),
    "Cancel": ("Cancel", "Abbrechen"),
    "Save": ("Save", "Speichern"),
    "Close": ("Close", "Schließen"),
    "Burn (kcal)": ("Burn (kcal)", "Verbrauch (kcal)"),
    "Carbs (g)": ("Carbs (g)", "Kohlenhydrate (g)"),
    "Protein (g)": ("Protein (g)", "Eiweiß (g)"),
    "Fat (g)": ("Fat (g)", "Fett (g)"),
    "Auto": ("Auto", "Auto"),
    "Target Split (Calorie-%):": ("Target Split (Calorie-%):", "Ziel-Verteilung (Kalorien-%):"),
    "Gram budget at": ("Gram budget at", "Grammbudget bei"),

    # ── Food & Sample Names ──
    "Chicken Breast (Grilled)": ("Grilled Chicken Breast", "Gegrillte Hähnchenbrust"),
    "name": ("Grilled Chicken Breast", "Gegrillte Hähnchenbrust"),
    "Grandmaster Cheat": ("Grandmaster Unlock (Cheat)", "Großmeister-Freischaltung (Cheat)"),
    "cheat_button_title": ("Grandmaster Unlock (Cheat)", "Großmeister-Freischaltung (Cheat)"),

    # ── Placeholders ──
    "search_food_placeholder": ("Search ingredients (e.g. Oats, Salmon, Banana)...", "Zutaten suchen (z.B. Haferflocken, Lachs, Banane)..."),
    "search_recipes_placeholder": ("Search recipes or ingredients...", "Rezepte oder Zutaten suchen..."),
    "search_recipes": ("Search recipes...", "Rezepte durchsuchen..."),
    "search_workouts": ("Search workouts...", "Trainingsformen suchen..."),
    "name_placeholder": ("e.g. Alex, Runner99", "z.B. Alex, Läufer99"),
    "meal_name_placeholder": ("Meal Name (e.g. Post-Workout Snack)...", "Mahlzeitenname (z.B. Post-Workout Snack)..."),
    "template_name_placeholder": ("Meal name (e.g. My Power Breakfast)...", "Mahlzeitenname (z.B. Power-Frühstück)..."),
    "new_slot_placeholder": ("Slot name (e.g. Level 2 - Balanced)...", "Name (z.B. Level 2 - Sport-Balance)..."),
    "barcode_placeholder": ("Enter EAN/UPC Barcode (e.g. 5201051001078)...", "EAN/UPC Barcode eingeben (z.B. 5201051001078)..."),
    "paste_json_placeholder": ("Paste {\"app\":\"Speis\", ...} JSON here...", "Hier {\"app\":\"Speis\", ...} JSON einfügen..."),
    "add_ingredient_placeholder": ("Type ingredient (e.g. Oats, Egg, Avocado)...", "Zutat eingeben (z.B. Haferflocken, Ei, Avocado)..."),
    "meal_time_placeholder": ("Time (HH:MM)", "Uhrzeit (HH:MM)"),
    "meal_title_placeholder": ("Meal Title (e.g. Breakfast)", "Mahlzeitentitel (z.B. Frühstück)"),

    # ── Educational & User Profile ──
    "why_cal_pct_not_gram_pct": ("💡 Why Calorie-% and Gram-% Differ", "💡 Warum Kalorien-% nicht gleich Gramm-% sind"),
    "fuel_values_explanation": (
        "Macronutrients provide different amounts of energy per gram (physiological fuel value):\n• 1 g Carbohydrates = 4 kcal (17 kJ)\n• 1 g Protein = 4 kcal (17 kJ)\n• 1 g Fat = 9 kcal (37 kJ)\nFat delivers more than double the energy of carbs or protein. To convert calorie percentages into grams, divide carbohydrate and protein calories by 4 and fat calories by 9.",
        "Die Makronährstoffe liefern pro Gramm unterschiedlich viel Energie (physiologischer Brennwert):\n• 1 g Kohlenhydrate = 4 kcal (17 kJ)\n• 1 g Eiweiß = 4 kcal (17 kJ)\n• 1 g Fett = 9 kcal (37 kJ)\nFett liefert mehr als doppelt so viele Kalorien wie Kohlenhydrate oder Eiweiß. Wenn du deine Kalorien-% in Gramm umrechnest, teilst du die jeweiligen Kalorien bei Kohlenhydraten und Eiweiß durch 4 und bei Fett durch 9."
    ),
    "daily_energy_calculation_title": ("📊 Daily Energy Target Calculation", "📊 Berechnung des täglichen Energiebedarfs"),
    "cancel_btn": ("Cancel", "Abbrechen"),
    "btn_close": ("Close", "Schließen"),

    # ── Workouts & Expenditure ──
    "workout_desc": ("Burns energy & macronutrients, increasing daily caloric need", "Verbraucht Energie & Makronährstoffe und erhöht den täglichen Kalorienbedarf"),
    "custom_expenditure_overrides": ("⚙️ Custom Expenditure Overrides", "⚙️ Manuelle Verbrauchswerte"),
    "delete_workout_btn": ("🗑️ Delete Workout", "🗑️ Training löschen"),
    "no_workouts_in_category": ("No workouts in this category.", "Keine Trainingsformen in dieser Kategorie."),
    "total_burned_energy": ("Total Burned Energy", "Gesamter Trainingsverbrauch"),
    "substrates_burned": ("Substrates Burned", "Verbrannte Substrate"),
    "carbs": ("Carbs", "Kohlenhydrate"),
    "protein": ("Protein", "Eiweiß"),
    "fat": ("Fat", "Fett"),
    "add_workout_to_plan": ("Add Workout to Plan", "Training zum Plan hinzufügen"),
    "custom_workout_details": ("Custom Workout Details", "Details zum Training"),

    # ── Savegame Management ──
    "savegame_dialog_subtitle": ("Export, import, and backup your day plan and progress locally", "Speichere, exportiere und sichere deinen Tagesplan lokal"),
    "load_pasted_plan": ("Load Pasted Plan", "Eingefügten Plan laden"),
    "clear_btn": ("Clear", "Leeren"),
    "savegame_restored_success": ("Savegame successfully restored!", "Spielstand erfolgreich wiederhergestellt!"),
    "savegame_json_invalid": ("Invalid JSON savegame data. Please check syntax.", "Ungültige JSON-Spieldaten. Bitte überprüfe das Format."),
    "save_slot_title": ("💾 Save Current Plan to Named Slot:", "💾 Aktuellen Plan unter Namen speichern:"),
    "save_slot_desc": ("Saves meals, workouts, stars, and athlete profile locally.", "Speichert Mahlzeiten, Trainings, Sterne und Athletenprofil lokal auf deinem Gerät."),
    "saved_slots_header": ("📁 Saved Slots", "📁 Gespeicherte Spielstände"),
    "last_autosaved": ("Last autosaved:", "Zuletzt automatisch gespeichert:"),
    "export_file_json": ("📤 Export File (.json)", "📤 Datei exportieren (.json)"),
    "import_file_json": ("📥 Import File (.json)", "📥 Datei importieren (.json)"),
    "copy_json_btn": ("📋 Copy JSON", "📋 JSON kopieren"),
    "reset_sample_plan_btn": ("🔄 Reset Sample Plan", "🔄 Musterplan zurücksetzen"),
    "paste_json_savegame": ("Paste JSON Savegame Directly:", "JSON-Spielstand direkt einfügen:"),

    # ── Barcode Scanner ──
    "barcode_dialog_title": ("Scan Barcode / Open Food Facts", "Barcode scannen / Open Food Facts"),
    "barcode_dialog_subtitle": ("Fetch real nutritional data directly via Open Food Facts API", "Echte Nährwertdaten direkt über die Open Food Facts API abrufen"),
    "barcode_presets_title": ("Quick Test Presets (Click to test):", "Schnelltest-Vorlagen (Klicken zum Testen):"),
    "camera_viewfinder_hint": ("Point EAN-13 / UPC barcode at camera viewfinder", "Halte den EAN-13 / UPC Barcode in das Kamerasichtfeld"),
    "barcode_nutrition_per_100g": ("Nutritional Values (per 100g):", "Nährwerte (pro 100g):"),
    "amount_label": ("Amount:", "Menge:"),
    "grams_unit": ("grams", "Gramm"),
    "target_meal_label": ("Target Meal:", "Ziel-Mahlzeit:"),
    "add_to_meal_plan": ("➕ Add to Meal Plan", "➕ Zum Tagesplan hinzufügen"),

    # ── Action Bar & Navigation ──
    "expand_all": ("Expand All", "Alles ausklappen"),
    "collapse_all": ("Collapse All", "Alles einklappen"),
    "clear_plan_title": ("Clear Plan", "Plan leeren"),
    "browse_recipes_tooltip": ("Browse 32 real balanced chef recipes", "Entdecke 32 ausgewogene Kochrezepte"),
    "load_custom_meals_tooltip": ("Load your saved custom meals", "Lade deine gespeicherten Mahlzeiten"),
    "browse_workouts_tooltip": ("Browse athletic workout presets", "Trainingsformen für deine Sportart"),
    "custom_meal": ("Custom Meal", "Eigene Mahlzeit"),
    "remove_meal": ("Remove Meal", "Mahlzeit entfernen"),
    "no_ingredients_hint": ("No ingredients added yet. Type below to search or scan a barcode!", "Noch keine Zutaten hinzugefügt. Suche unten nach Zutaten oder scanne einen Barcode!"),
    "time_label": ("Time:", "Uhrzeit:"),
    "save_custom_meal_desc": ("Save this meal with all its ingredients and portion sizes into your personal recipe library:", "Speichere diese Mahlzeit mit allen Zutaten und Portionsgrößen in deiner Rezeptsammlung:"),

    # ── Recipe Library ──
    "recipe_tab_all": ("All (32)", "Alle (32)"),
    "no_recipes_matched": ("No recipes matched your search filter.", "Keine Rezepte für diesen Suchfilter gefunden."),
    "per_serving": ("per serving", "pro Portion"),
    "scaled_total": ("scaled total", "skalierte Gesamtmenge"),
    "ingredients_breakdown": ("Ingredients Breakdown", "Zutaten-Aufschlüsselung"),

    # ── Golden Plan & Level Select ──
    "golden_plan_btn": ("Golden Plan", "Golden Plan"),
    "golden_plan_tooltip": ("Load mathematically verified Golden Day Plan (satisfies all 24 levels simultaneously)", "Mathematisch verifizierten Golden Day Plan laden (erfüllt alle 24 Level gleichzeitig)"),
    "cheat_solve_all_btn": ("Cheat (Solve All 24★)", "Großmeister-Cheat (Alle 24★)"),
    "cheat_solve_all_tooltip": ("Cheat: Load ideal plan and unlock/solve all 24 levels with 3 stars!", "Cheat: Idealplan laden und alle 24 Level mit 3 Sternen lösen!"),
}

for k, (en_val, de_val) in curated_updates.items():
    if k not in master_dict:
        master_dict[k] = {'en': en_val, 'de': de_val}
    else:
        master_dict[k]['en'] = en_val
        master_dict[k]['de'] = de_val

# Fill any missing en values with key or default
for k in master_dict:
    if not master_dict[k]['en']:
        master_dict[k]['en'] = k
    if not master_dict[k]['de']:
        master_dict[k]['de'] = master_dict[k]['en']

print(f"Master dictionary reconciled with {len(master_dict)} unique terms.")

# 4. Generate TS files
qml_contexts = [
    "AboutLegalDialog", "BarcodeLookupDialog", "CozyShoppingList", "EvaluationResultDialog",
    "GoalSummaryCard", "IngredientExplorerDialog", "LevelSelectView", "Main", "OnboardingDialog",
    "RecipeLibraryDialog", "SavegameDialog", "TemporalPieChart", "TemporalSpiralChart",
    "TemporalTableChart", "UserProfileDialog", "WorkoutDialog", "WorkoutLibraryDialog"
]

def write_ts_file(filepath, lang_code):
    lines = []
    lines.append('<?xml version="1.0" encoding="utf-8"?>')
    lines.append('<!DOCTYPE TS>')
    lines.append(f'<TS version="2.1" language="{lang_code}">')
    
    # Context 1: QtSpeis (for QCoreApplication::translate and C++ calls)
    lines.append('    <context>')
    lines.append('        <name>QtSpeis</name>')
    for key in sorted(master_dict.keys()):
        en_val = master_dict[key]['en']
        de_val = master_dict[key]['de']
        tr_val = de_val if lang_code.startswith('de') else en_val
        
        esc_src = saxutils.escape(key)
        esc_tr = saxutils.escape(tr_val)
        esc_en = saxutils.escape(en_val)
        
        lines.append('        <message>')
        lines.append(f'            <source>{esc_src}</source>')
        lines.append(f'            <extracomment>English: {esc_en}</extracomment>')
        lines.append(f'            <translation>{esc_tr}</translation>')
        lines.append('        </message>')
    lines.append('    </context>')

    # Contexts 2..N: Each QML file context so qsTr("English text") and qsTr(key) resolve natively!
    seen_sources = {}
    for key in sorted(master_dict.keys()):
        en_val = master_dict[key]['en']
        de_val = master_dict[key]['de']
        tr_val = de_val if lang_code.startswith('de') else en_val
        if en_val:
            seen_sources[en_val] = tr_val
        seen_sources[key] = tr_val

    for ctx in qml_contexts:
        lines.append('    <context>')
        lines.append(f'        <name>{ctx}</name>')
        for src, tr in sorted(seen_sources.items()):
            esc_src = saxutils.escape(src)
            esc_tr = saxutils.escape(tr)
            lines.append('        <message>')
            lines.append(f'            <source>{esc_src}</source>')
            lines.append(f'            <translation>{esc_tr}</translation>')
            lines.append('        </message>')
        lines.append('    </context>')

    lines.append('</TS>')
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"Wrote entries to {filepath}")

write_ts_file('translations/qtspeis_de.ts', 'de_DE')
write_ts_file('translations/qtspeis_en.ts', 'en_US')

# 5. Compile TS to QM with lrelease
lrelease_bin = r"C:\Qt\6.8.3\mingw_64\bin\lrelease.exe"
if os.path.exists(lrelease_bin):
    subprocess.run([lrelease_bin, "translations/qtspeis_de.ts", "-qm", "translations/qtspeis_de.qm"], check=True)
    subprocess.run([lrelease_bin, "translations/qtspeis_en.ts", "-qm", "translations/qtspeis_en.qm"], check=True)
    print("Compiled both translations to .qm via lrelease.")
else:
    print(f"Warning: {lrelease_bin} not found.")

# 6. Synchronize languagemanager.cpp
with open('languagemanager.cpp', 'r', encoding='utf-8') as f:
    orig_cpp = f.read()

en_lines = []
for k in sorted(master_dict.keys()):
    v = master_dict[k]['en'].replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '')
    k_esc = k.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '')
    en_lines.append(f'    m_enDict[QStringLiteral("{k_esc}")] = QStringLiteral("{v}");')

de_lines = []
for k in sorted(master_dict.keys()):
    v = master_dict[k]['de'].replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '')
    k_esc = k.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '')
    de_lines.append(f'    m_deDict[QStringLiteral("{k_esc}")] = QStringLiteral("{v}");')

marker_en = "void LanguageManager::initEnglishDictionary()\n{\n"
marker_de = "void LanguageManager::initGermanDictionary()\n{\n"

idx_en = orig_cpp.find(marker_en)
idx_de = orig_cpp.find(marker_de)

if idx_en != -1 and idx_de != -1:
    prefix = orig_cpp[:idx_en + len(marker_en)]
    en_code = "\n".join(en_lines)
    de_code = "\n".join(de_lines)
    
    new_cpp = prefix + en_code + "\n}\n\n" + marker_de + de_code + "\n}\n"
    with open('languagemanager.cpp', 'w', encoding='utf-8') as f:
        f.write(new_cpp)
    print("Successfully updated languagemanager.cpp dictionaries.")
else:
    print("Warning: Could not find dictionary markers in languagemanager.cpp")
