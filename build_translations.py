import os
import json
import subprocess
import xml.sax.saxutils as saxutils

with open("recovered_dict.json", "r", encoding="utf-8") as f:
    recovered = json.load(f)

en_dict = dict(recovered.get("en", {}))
de_dict = dict(recovered.get("de", {}))

new_keys = {
    # Categories
    "cat_all": ("All", "Alle"),
    "cat_grains": ("Grains & Cereals", "Getreide"),
    "cat_vegetables": ("Vegetables", "Gemüse"),
    "cat_fruits": ("Fruits", "Obst"),
    "cat_dairy": ("Dairy", "Milchprodukte"),
    "cat_herbs": ("Herbs & Spices", "Kräuter"),
    "cat_nuts": ("Nuts & Seeds", "Nüsse & Samen"),
    "cat_meat": ("Meat & Poultry", "Fleisch"),
    "cat_legumes": ("Legumes", "Hülsenfrüchte"),
    "cat_fish": ("Fish & Seafood", "Fisch"),
    "cat_sweeteners": ("Sweeteners", "Süßungsmittel"),
    "cat_oils": ("Oils & Fats", "Öle & Fette"),
    "cat_salads": ("Salads & Greens", "Salat"),
    "cat_beverages": ("Beverages", "Getränke"),
    "cat_eggs": ("Eggs", "Eier"),

    # Nutrients & Minerals
    "nutrient_energy": ("Energy", "Energie"),
    "nutrient_protein": ("Protein", "Eiweiß"),
    "nutrient_carbs": ("Carbohydrates", "Kohlenhydrate"),
    "nutrient_fat": ("Fat", "Fett"),
    "nutrient_fiber": ("Fiber", "Ballaststoffe"),
    "nutrient_gi": ("GI / Gastric Emptying", "GI / Magenentleerung"),
    "nutrient_macros_energy": ("Macronutrients & Energy", "Makronährstoffe & Energie"),
    "nutrient_minerals_vitamins": ("Minerals & Vitamins", "Mineralstoffe & Vitamine"),
    "nutrient_iron": ("Iron (Fe)", "Eisen (Fe)"),
    "nutrient_iron_heme": ("Heme (Animal)", "Häm (Tierisch)"),
    "nutrient_iron_non_heme": ("Non-Heme (Plant)", "Pflanzlich / Non-Häm"),
    "nutrient_vitamin_c": ("Vitamin C", "Vitamin C"),
    "nutrient_calcium": ("Calcium (Ca)", "Calcium (Ca)"),
    "nutrient_magnesium": ("Magnesium (Mg)", "Magnesium (Mg)"),
    "nutrient_potassium": ("Potassium (K)", "Kalium (K)"),
    "nutrient_sodium": ("Sodium (Na)", "Natrium (Na)"),
    "nutrient_zinc": ("Zinc (Zn)", "Zink (Zn)"),
    "nutrient_copper": ("Copper (Cu)", "Kupfer (Cu)"),
    "nutrient_omega3": ("Omega-3 Fatty Acids", "Omega-3 Fettsäuren"),
    "nutrient_leucine": ("L-Leucine (MPS)", "L-Leucin (MPS)"),
    "per_100g": ("(per 100g)", "(pro 100g)"),
    "portion_size_g": ("Portion Size (g):", "Portionsgröße (g):"),
    "target_meal": ("Target Meal:", "Ziel-Mahlzeit:"),
    "add_to_meal_btn": ("Add to Meal Plan", "In Plan einfügen"),
    "added_to_meal_feedback": ("Added %1g %2 to %3!", "%1g %2 zu %3 hinzugefügt!"),
    "no_foods_found": ("No ingredients found. Adjust your search or filters.", "Keine Zutaten gefunden. Suche anpassen."),
    "expand_details": ("Details", "Details"),
    "collapse_details": ("Hide Details", "Details ausblenden"),
    "gi_low": ("Low", "Niedrig"),
    "gi_medium": ("Medium", "Mittel"),
    "gi_high": ("High", "Hoch"),

    # Language & Restart
    "language_region": ("Language & Region", "Sprache & Region"),
    "restart_confirm_title": ("Restart Required", "Neustart erforderlich"),
    "restart_confirm_msg": ("Changing the language requires restarting the application. Do you want to proceed and restart now?",
                            "Ein Sprachwechsel erfordert einen Neustart der Anwendung. Möchten Sie die Anwendung jetzt neu starten?"),
    "restart_confirm_btn": ("Restart Now", "Jetzt neu starten"),
    "select_language": ("Select Language", "Sprache auswählen"),
    "lang_restart_hint": ("Applying language changes will restart QtSpeis.", "Die Übernahme der Sprache erfordert einen Neustart von QtSpeis.")
}

for k, (en_val, de_val) in new_keys.items():
    en_dict[k] = en_val
    de_dict[k] = de_val

# Make sure all keys in en_dict exist in de_dict
for k in en_dict:
    if k not in de_dict:
        de_dict[k] = en_dict[k]

os.makedirs("translations", exist_ok=True)

ts_lines = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<!DOCTYPE TS>',
    '<TS version="2.1" language="de_DE">',
    '<context>',
    '    <name>QtSpeis</name>'
]

seen_sources = set()

for key in sorted(en_dict.keys()):
    en_val = en_dict[key]
    de_val = de_dict[key]
    escaped_key = saxutils.escape(key)
    escaped_en = saxutils.escape(en_val)
    escaped_de = saxutils.escape(de_val)
    
    # Key-based message with English text in extracomment for Linguist
    if key not in seen_sources:
        seen_sources.add(key)
        ts_lines.append('    <message>')
        ts_lines.append(f'        <source>{escaped_key}</source>')
        ts_lines.append(f'        <extracomment>English: {escaped_en}</extracomment>')
        ts_lines.append(f'        <translation>{escaped_de}</translation>')
        ts_lines.append('    </message>')
    
    # Also add English source string if different from key so qsTr(EnglishText) also works!
    if en_val != key and en_val not in seen_sources:
        seen_sources.add(en_val)
        ts_lines.append('    <message>')
        ts_lines.append(f'        <source>{escaped_en}</source>')
        ts_lines.append(f'        <translation>{escaped_de}</translation>')
        ts_lines.append('    </message>')

ts_lines.append('</context>')
ts_lines.append('</TS>')

ts_content = "\n".join(ts_lines) + "\n"

with open("translations/qtspeis_de.ts", "w", encoding="utf-8") as f:
    f.write(ts_content)

print(f"Generated translations/qtspeis_de.ts with {len(seen_sources)} unique messages.")

# Compile with lrelease
lrelease = "C:/Qt/6.8.3/mingw_64/bin/lrelease.exe"
if os.path.exists(lrelease):
    res = subprocess.run([lrelease, "translations/qtspeis_de.ts", "-qm", "translations/qtspeis_de.qm"], capture_output=True, text=True)
    print("lrelease STDOUT:", res.stdout)
    if res.stderr:
        print("lrelease STDERR:", res.stderr)
else:
    print("lrelease not found at", lrelease)

# Regenerate languagemanager.cpp with English dictionary
cpp_lines = [
    '#include "languagemanager.h"',
    '#include <QDebug>',
    '#include <QCoreApplication>',
    '#include <QProcess>',
    '',
    '#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)',
    '#include <emscripten.h>',
    '#endif',
    '',
    'LanguageManager *LanguageManager::s_instance = nullptr;',
    '',
    'LanguageManager::LanguageManager(QObject *parent)',
    '    : QObject(parent)',
    '{',
    '    s_instance = this;',
    '    initEnglishDictionary();',
    '',
    '    QSettings settings;',
    '    m_currentLanguage = settings.value(QStringLiteral("appLanguage"), QStringLiteral("en")).toString().trimmed().toLower();',
    '    if (m_currentLanguage != QStringLiteral("de") && m_currentLanguage != QStringLiteral("en")) {',
    '        m_currentLanguage = QStringLiteral("en");',
    '    }',
    '',
    '    if (m_currentLanguage == QStringLiteral("de")) {',
    '        if (m_translator.load(QStringLiteral(":/translations/qtspeis_de.qm")) ||',
    '            m_translator.load(QStringLiteral("translations/qtspeis_de.qm"))) {',
    '            QCoreApplication::installTranslator(&m_translator);',
    '            qInfo() << "LanguageManager installed German QTranslator from qtspeis_de.qm";',
    '        } else {',
    '            qWarning() << "LanguageManager could not load qtspeis_de.qm";',
    '        }',
    '    }',
    '}',
    '',
    'void LanguageManager::setCurrentLanguage(const QString &langCode)',
    '{',
    '    QString code = langCode.trimmed().toLower();',
    '    if (code.isEmpty()) code = QStringLiteral("en");',
    '    m_currentLanguage = code;',
    '',
    '    QSettings settings;',
    '    settings.setValue(QStringLiteral("appLanguage"), m_currentLanguage);',
    '',
    '    emit languageChanged(m_currentLanguage);',
    '}',
    '',
    'void LanguageManager::restartApplication()',
    '{',
    '#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)',
    '    emscripten_run_script("window.location.reload();");',
    '#else',
    '    QString program = QCoreApplication::applicationFilePath();',
    '    QStringList args = QCoreApplication::arguments();',
    '    if (!args.isEmpty()) {',
    '        args.removeFirst();',
    '    }',
    '    QProcess::startDetached(program, args);',
    '    QCoreApplication::quit();',
    '#endif',
    '}',
    '',
    'QString LanguageManager::currentLanguageName() const',
    '{',
    '    if (m_currentLanguage == QStringLiteral("de")) return QStringLiteral("Deutsch");',
    '    if (m_currentLanguage == QStringLiteral("fr")) return QStringLiteral("Français");',
    '    if (m_currentLanguage == QStringLiteral("es")) return QStringLiteral("Español");',
    '    if (m_currentLanguage == QStringLiteral("it")) return QStringLiteral("Italiano");',
    '    return QStringLiteral("English");',
    '}',
    '',
    'QString LanguageManager::currentLanguageFlag() const',
    '{',
    '    if (m_currentLanguage == QStringLiteral("de")) return QStringLiteral("🇩🇪");',
    '    if (m_currentLanguage == QStringLiteral("fr")) return QStringLiteral("🇫🇷");',
    '    if (m_currentLanguage == QStringLiteral("es")) return QStringLiteral("🇪🇸");',
    '    if (m_currentLanguage == QStringLiteral("it")) return QStringLiteral("🇮🇹");',
    '    return QStringLiteral("🇬🇧");',
    '}',
    '',
    'void LanguageManager::setShowAllLanguages(bool show)',
    '{',
    '    if (m_showAllLanguages != show) {',
    '        m_showAllLanguages = show;',
    '        emit showAllLanguagesChanged();',
    '    }',
    '}',
    '',
    'QVariantList LanguageManager::availableLanguages() const',
    '{',
    '    QVariantList list;',
    '',
    '    auto add = [&list](const QString &code, const QString &name, const QString &flag) {',
    '        QVariantMap map;',
    '        map[QStringLiteral("code")] = code;',
    '        map[QStringLiteral("name")] = name;',
    '        map[QStringLiteral("flag")] = flag;',
    '        list.append(map);',
    '    };',
    '',
    '    add(QStringLiteral("en"), QStringLiteral("English"), QStringLiteral("🇬🇧"));',
    '    add(QStringLiteral("de"), QStringLiteral("Deutsch"), QStringLiteral("🇩🇪"));',
    '',
    '    if (m_showAllLanguages) {',
    '        add(QStringLiteral("fr"), QStringLiteral("Français"), QStringLiteral("🇫🇷"));',
    '        add(QStringLiteral("es"), QStringLiteral("Español"), QStringLiteral("🇪🇸"));',
    '        add(QStringLiteral("it"), QStringLiteral("Italiano"), QStringLiteral("🇮🇹"));',
    '    }',
    '',
    '    return list;',
    '}',
    '',
    'QString LanguageManager::t(const QString &key, const QVariantList &args) const',
    '{',
    '    QString res = QCoreApplication::translate("QtSpeis", key.toUtf8().constData());',
    '    if ((res == key || res.isEmpty()) && m_enDict.contains(key)) {',
    '        res = m_enDict.value(key);',
    '    } else if (res.isEmpty()) {',
    '        res = key;',
    '    }',
    '',
    '    for (int i = 0; i < args.size(); ++i) {',
    '        res = res.arg(args[i].toString());',
    '    }',
    '',
    '    return res;',
    '}',
    '',
    'void LanguageManager::initEnglishDictionary()',
    '{'
]

for k in sorted(en_dict.keys()):
    v = en_dict[k].replace('\\', '\\\\').replace('"', '\\"')
    cpp_lines.append(f'    m_enDict[QStringLiteral("{k}")] = QStringLiteral("{v}");')

cpp_lines.append('}')
cpp_lines.append('')

with open("languagemanager.cpp", "w", encoding="utf-8") as f:
    f.write("\n".join(cpp_lines))

print("Regenerated languagemanager.cpp with full English master dictionary.")
