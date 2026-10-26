#include "languagemanager.h"
#include <QDebug>
#include <QCoreApplication>
#include <QProcess>

#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)
#include <emscripten.h>
#endif

LanguageManager *LanguageManager::s_instance = nullptr;

LanguageManager::LanguageManager(QObject *parent)
    : QObject(parent)
{
    s_instance = this;
    initEnglishDictionary();
    initGermanDictionary();

    QSettings settings;
    m_currentLanguage = settings.value(QStringLiteral("appLanguage"), QStringLiteral("en")).toString().trimmed().toLower();

#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)
    char *savedLang = (char*)EM_ASM_PTR({
        try {
            var l = localStorage.getItem('appLanguage');
            if (!l) return 0;
            var len = lengthBytesUTF8(l) + 1;
            var p = _malloc(len);
            stringToUTF8(l, p, len);
            return p;
        } catch(e) { return 0; }
    });
    if (savedLang) {
        QString s = QString::fromUtf8(savedLang).trimmed().toLower();
        free(savedLang);
        if (s == QStringLiteral("de") || s == QStringLiteral("en")) {
            m_currentLanguage = s;
        }
    }
#endif

    if (m_currentLanguage != QStringLiteral("de") && m_currentLanguage != QStringLiteral("en")) {
        m_currentLanguage = QStringLiteral("en");
    }

    if (m_currentLanguage == QStringLiteral("de")) {
        if (m_translator.load(QStringLiteral(":/translations/qtspeis_de.qm")) ||
            m_translator.load(QStringLiteral("translations/qtspeis_de.qm"))) {
            QCoreApplication::installTranslator(&m_translator);
            qInfo() << "LanguageManager installed German QTranslator from qtspeis_de.qm";
        } else {
            qWarning() << "LanguageManager could not load qtspeis_de.qm";
        }
    }
}

void LanguageManager::setCurrentLanguage(const QString &langCode)
{
    QString code = langCode.trimmed().toLower();
    if (code.isEmpty()) code = QStringLiteral("en");
    if (code != QStringLiteral("de") && code != QStringLiteral("en")) code = QStringLiteral("en");
    m_currentLanguage = code;

    QSettings settings;
    settings.setValue(QStringLiteral("appLanguage"), m_currentLanguage);
    settings.sync();

#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)
    QString script = QString("try { localStorage.setItem('appLanguage', '%1'); } catch(e){}").arg(m_currentLanguage);
    emscripten_run_script(script.toUtf8().constData());
#endif

    if (m_currentLanguage == QStringLiteral("de")) {
        if (m_translator.load(QStringLiteral(":/translations/qtspeis_de.qm")) ||
            m_translator.load(QStringLiteral("translations/qtspeis_de.qm"))) {
            QCoreApplication::installTranslator(&m_translator);
            qInfo() << "LanguageManager installed German QTranslator on language change";
        }
    } else {
        QCoreApplication::removeTranslator(&m_translator);
    }

    emit languageChanged(m_currentLanguage);
}

void LanguageManager::restartApplication()
{
#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)
    emscripten_run_script("window.location.reload();");
#else
    QString program = QCoreApplication::applicationFilePath();
    QStringList args = QCoreApplication::arguments();
    if (!args.isEmpty()) {
        args.removeFirst();
    }
    QProcess::startDetached(program, args);
    QCoreApplication::quit();
#endif
}

QString LanguageManager::currentLanguageName() const
{
    if (m_currentLanguage == QStringLiteral("de")) return QStringLiteral("Deutsch");
    if (m_currentLanguage == QStringLiteral("fr")) return QStringLiteral("Français");
    if (m_currentLanguage == QStringLiteral("es")) return QStringLiteral("Español");
    if (m_currentLanguage == QStringLiteral("it")) return QStringLiteral("Italiano");
    return QStringLiteral("English");
}

QString LanguageManager::currentLanguageFlag() const
{
    if (m_currentLanguage == QStringLiteral("de")) return QStringLiteral("🇩🇪");
    if (m_currentLanguage == QStringLiteral("fr")) return QStringLiteral("🇫🇷");
    if (m_currentLanguage == QStringLiteral("es")) return QStringLiteral("🇪🇸");
    if (m_currentLanguage == QStringLiteral("it")) return QStringLiteral("🇮🇹");
    return QStringLiteral("🇬🇧");
}

void LanguageManager::setShowAllLanguages(bool show)
{
    if (m_showAllLanguages != show) {
        m_showAllLanguages = show;
        emit showAllLanguagesChanged();
    }
}

QVariantList LanguageManager::availableLanguages() const
{
    QVariantList list;

    auto add = [&list](const QString &code, const QString &name, const QString &flag) {
        QVariantMap map;
        map[QStringLiteral("code")] = code;
        map[QStringLiteral("name")] = name;
        map[QStringLiteral("flag")] = flag;
        list.append(map);
    };

    add(QStringLiteral("en"), QStringLiteral("English"), QStringLiteral("🇬🇧"));
    add(QStringLiteral("de"), QStringLiteral("Deutsch"), QStringLiteral("🇩🇪"));

    if (m_showAllLanguages) {
        add(QStringLiteral("fr"), QStringLiteral("Français"), QStringLiteral("🇫🇷"));
        add(QStringLiteral("es"), QStringLiteral("Español"), QStringLiteral("🇪🇸"));
        add(QStringLiteral("it"), QStringLiteral("Italiano"), QStringLiteral("🇮🇹"));
    }

    return list;
}

QString LanguageManager::t(const QString &key, const QVariantList &args) const
{
    QString res;
    if (m_currentLanguage == QStringLiteral("de")) {
        res = QCoreApplication::translate("QtSpeis", key.toUtf8().constData());
        if (res.isEmpty() || res == key) {
            if (m_deDict.contains(key)) {
                res = m_deDict.value(key);
            } else if (m_enDict.contains(key)) {
                QString enVal = m_enDict.value(key);
                QString trFromEn = QCoreApplication::translate("QtSpeis", enVal.toUtf8().constData());
                if (!trFromEn.isEmpty() && trFromEn != enVal) {
                    res = trFromEn;
                } else if (m_deDict.contains(enVal)) {
                    res = m_deDict.value(enVal);
                } else {
                    res = enVal;
                }
            } else {
                res = key;
            }
        }
    } else {
        res = QCoreApplication::translate("QtSpeis", key.toUtf8().constData());
        if (res.isEmpty() || res == key) {
            if (m_enDict.contains(key)) {
                res = m_enDict.value(key);
            } else {
                res = key;
            }
        }
    }

    for (int i = 0; i < args.size(); ++i) {
        res = res.arg(args[i].toString());
    }

    return res;
}

void LanguageManager::initEnglishDictionary()
{
    m_enDict[QStringLiteral("about_legal_btn")] = QStringLiteral("Legal & Privacy");
    m_enDict[QStringLiteral("about_legal_title")] = QStringLiteral("About, Licenses & Privacy");
    m_enDict[QStringLiteral("add_ingredient")] = QStringLiteral("Add ingredient...");
    m_enDict[QStringLiteral("add_meal")] = QStringLiteral("➕ Add Meal");
    m_enDict[QStringLiteral("add_to_meal_btn")] = QStringLiteral("Add to Meal Plan");
    m_enDict[QStringLiteral("add_to_plan_btn")] = QStringLiteral("Add to Plan");
    m_enDict[QStringLiteral("add_workout")] = QStringLiteral("Workout");
    m_enDict[QStringLiteral("added_to_meal_feedback")] = QStringLiteral("Added %1g %2 to %3!");
    m_enDict[QStringLiteral("age")] = QStringLiteral("Age (years)");
    m_enDict[QStringLiteral("app_title")] = QStringLiteral("QtSpeis Nutrition Quest");
    m_enDict[QStringLiteral("apply_estimate")] = QStringLiteral("Apply Estimate (%1 kcal)");
    m_enDict[QStringLiteral("base_calories")] = QStringLiteral("Base Calorie Need (BMR)");
    m_enDict[QStringLiteral("base_calories_hint")] = QStringLiteral("Daily resting energy expenditure without exercise");
    m_enDict[QStringLiteral("bmr_estimator")] = QStringLiteral("Estimate BMR (Mifflin-St Jeor)");
    m_enDict[QStringLiteral("btn_close")] = QStringLiteral("Close");
    m_enDict[QStringLiteral("btn_evaluate")] = QStringLiteral("Finish & Grade Meal Plan");
    m_enDict[QStringLiteral("bullseye")] = QStringLiteral("🎯 Perfect bullseye (±50 kcal)!");
    m_enDict[QStringLiteral("burned_energy")] = QStringLiteral("Energy Burned");
    m_enDict[QStringLiteral("burned_kcal_tag")] = QStringLiteral("-%1 kcal burned");
    m_enDict[QStringLiteral("burned_macros")] = QStringLiteral("Substrate Oxidation (Burned)");
    m_enDict[QStringLiteral("calorie_accuracy")] = QStringLiteral("Calorie Accuracy");
    m_enDict[QStringLiteral("cancel_btn")] = QStringLiteral("Cancel");
    m_enDict[QStringLiteral("carbs")] = QStringLiteral("Carbs");
    m_enDict[QStringLiteral("cat_all")] = QStringLiteral("All");
    m_enDict[QStringLiteral("cat_beverages")] = QStringLiteral("Beverages");
    m_enDict[QStringLiteral("cat_dairy")] = QStringLiteral("Dairy");
    m_enDict[QStringLiteral("cat_eggs")] = QStringLiteral("Eggs");
    m_enDict[QStringLiteral("cat_fish")] = QStringLiteral("Fish & Seafood");
    m_enDict[QStringLiteral("cat_fruits")] = QStringLiteral("Fruits");
    m_enDict[QStringLiteral("cat_grains")] = QStringLiteral("Grains & Cereals");
    m_enDict[QStringLiteral("cat_herbs")] = QStringLiteral("Herbs & Spices");
    m_enDict[QStringLiteral("cat_legumes")] = QStringLiteral("Legumes");
    m_enDict[QStringLiteral("cat_meat")] = QStringLiteral("Meat & Poultry");
    m_enDict[QStringLiteral("cat_nuts")] = QStringLiteral("Nuts & Seeds");
    m_enDict[QStringLiteral("cat_oils")] = QStringLiteral("Oils & Fats");
    m_enDict[QStringLiteral("cat_salads")] = QStringLiteral("Salads & Greens");
    m_enDict[QStringLiteral("cat_sweeteners")] = QStringLiteral("Sweeteners");
    m_enDict[QStringLiteral("cat_vegetables")] = QStringLiteral("Vegetables");
    m_enDict[QStringLiteral("cheat_btn_action")] = QStringLiteral("Load & Solve All");
    m_enDict[QStringLiteral("cheat_button_confirm")] = QStringLiteral("Load the mathematically verified ideal day plan and unlock/solve all 24 levels with 3 stars?");
    m_enDict[QStringLiteral("cheat_button_desc")] = QStringLiteral("Cheat: Load Ideal Plan & Solve All 24 Levels");
    m_enDict[QStringLiteral("cheat_button_title")] = QStringLiteral("Grandmaster Cheat");
    m_enDict[QStringLiteral("clear_plan_btn")] = QStringLiteral("Clear Plan");
    m_enDict[QStringLiteral("clear_plan_confirm")] = QStringLiteral("Are you sure you want to clear all meals and ingredients? Your current meal plan will be removed. This cannot be undone.");
    m_enDict[QStringLiteral("clear_plan_title")] = QStringLiteral("Clear Meal Plan?");
    m_enDict[QStringLiteral("coach_feedback")] = QStringLiteral("Nutrition Coach's Feedback:");
    m_enDict[QStringLiteral("collapse_details")] = QStringLiteral("Hide Details");
    m_enDict[QStringLiteral("confirm_delete_slot_msg")] = QStringLiteral("Are you sure you want to delete '%1'?");
    m_enDict[QStringLiteral("confirm_delete_slot_title")] = QStringLiteral("Delete Save Slot?");
    m_enDict[QStringLiteral("confirm_delete_template_msg")] = QStringLiteral("Are you sure you want to delete '%1'?");
    m_enDict[QStringLiteral("confirm_delete_template_title")] = QStringLiteral("Delete Saved Meal?");
    m_enDict[QStringLiteral("confirm_load_slot_msg")] = QStringLiteral("Load '%1'? Any unsaved changes in your current plan will be replaced.");
    m_enDict[QStringLiteral("confirm_load_slot_title")] = QStringLiteral("Load Save Slot?");
    m_enDict[QStringLiteral("confirm_overwrite_slot_msg")] = QStringLiteral("Overwrite '%1' with your current meal plan and progress?");
    m_enDict[QStringLiteral("confirm_overwrite_slot_title")] = QStringLiteral("Overwrite Save Slot?");
    m_enDict[QStringLiteral("constraint_broken_desc")] = QStringLiteral("Your current meal plan violates rules from previously unlocked levels:");
    m_enDict[QStringLiteral("constraint_broken_title")] = QStringLiteral("Violated Earlier Level Rules");
    m_enDict[QStringLiteral("constraints_breakdown")] = QStringLiteral("Constraints Breakdown:");
    m_enDict[QStringLiteral("custom_meals_tab")] = QStringLiteral("Saved Meals");
    m_enDict[QStringLiteral("daily_calories")] = QStringLiteral("Daily Energy (Calories)");
    m_enDict[QStringLiteral("deep_audit_btn")] = QStringLiteral("🔬 Deep Nutritional Audit (Worker)");
    m_enDict[QStringLiteral("delete_slot_btn")] = QStringLiteral("Delete");
    m_enDict[QStringLiteral("diff_kcal")] = QStringLiteral("%1 kcal diff");
    m_enDict[QStringLiteral("diversity")] = QStringLiteral("Diversity");
    m_enDict[QStringLiteral("duration")] = QStringLiteral("Duration (minutes)");
    m_enDict[QStringLiteral("edit_workout")] = QStringLiteral("Edit Workout");
    m_enDict[QStringLiteral("evaluating")] = QStringLiteral("Evaluating...");
    m_enDict[QStringLiteral("expand_details")] = QStringLiteral("Details");
    m_enDict[QStringLiteral("export_file")] = QStringLiteral("📥 Export Savegame (.json)");
    m_enDict[QStringLiteral("fat")] = QStringLiteral("Fat");
    m_enDict[QStringLiteral("female")] = QStringLiteral("Female");
    m_enDict[QStringLiteral("fiber")] = QStringLiteral("Fiber");
    m_enDict[QStringLiteral("gi_high")] = QStringLiteral("High");
    m_enDict[QStringLiteral("gi_low")] = QStringLiteral("Low");
    m_enDict[QStringLiteral("gi_medium")] = QStringLiteral("Medium");
    m_enDict[QStringLiteral("height")] = QStringLiteral("Height (cm)");
    m_enDict[QStringLiteral("hero_challenges_title")] = QStringLiteral("Hero Challenges");
    m_enDict[QStringLiteral("icon")] = QStringLiteral("🍗");
    m_enDict[QStringLiteral("import_file")] = QStringLiteral("📤 Import Savegame (.json)");
    m_enDict[QStringLiteral("ingredient_explorer")] = QStringLiteral("Ingredient Explorer");
    m_enDict[QStringLiteral("ingredient_explorer_sub")] = QStringLiteral("Explore, sort and filter all ingredients, macro profiles and micronutrients");
    m_enDict[QStringLiteral("kcal_over")] = QStringLiteral("▲ %1 kcal over target");
    m_enDict[QStringLiteral("kcal_remaining")] = QStringLiteral("▼ %1 kcal remaining");
    m_enDict[QStringLiteral("keep_editing")] = QStringLiteral("✏️ Keep Editing");
    m_enDict[QStringLiteral("lang_restart_hint")] = QStringLiteral("Applying language changes will restart QtSpeis.");
    m_enDict[QStringLiteral("language")] = QStringLiteral("Language");
    m_enDict[QStringLiteral("language_region")] = QStringLiteral("Language & Region");
    m_enDict[QStringLiteral("levels_menu")] = QStringLiteral("🏆 Levels Menu");
    m_enDict[QStringLiteral("load_slot_btn")] = QStringLiteral("Load");
    m_enDict[QStringLiteral("macro_accuracy")] = QStringLiteral("Macro Balance Accuracy");
    m_enDict[QStringLiteral("macro_split")] = QStringLiteral("Macronutrient Split (% of energy)");
    m_enDict[QStringLiteral("male")] = QStringLiteral("Male");
    m_enDict[QStringLiteral("meal_breakfast")] = QStringLiteral("Breakfast");
    m_enDict[QStringLiteral("meal_dinner")] = QStringLiteral("Dinner");
    m_enDict[QStringLiteral("meal_lunch")] = QStringLiteral("Lunch");
    m_enDict[QStringLiteral("meal_snack")] = QStringLiteral("Snack");
    m_enDict[QStringLiteral("meal_time_placeholder")] = QStringLiteral("Time (HH:MM)");
    m_enDict[QStringLiteral("meal_title_placeholder")] = QStringLiteral("Meal Title (e.g. Breakfast)");
    m_enDict[QStringLiteral("mobile_goal_tab")] = QStringLiteral("Target & Grade");
    m_enDict[QStringLiteral("mobile_plan_tab")] = QStringLiteral("Meal Plan");
    m_enDict[QStringLiteral("name")] = QStringLiteral("Chicken Breast (Grilled)");
    m_enDict[QStringLiteral("nav_back")] = QStringLiteral("Back");
    m_enDict[QStringLiteral("new_slot_placeholder")] = QStringLiteral("Slot name (e.g. Level 2 - Balanced)...");
    m_enDict[QStringLiteral("next_level")] = QStringLiteral("Next Level →");
    m_enDict[QStringLiteral("no_foods_found")] = QStringLiteral("No ingredients found. Adjust your search or filters.");
    m_enDict[QStringLiteral("no_items_in_meal")] = QStringLiteral("No ingredients yet. Type an ingredient name above!");
    m_enDict[QStringLiteral("no_saved_meals_hint")] = QStringLiteral("No saved custom meals yet. Build a meal in your plan and click '💾 Save as Custom Meal'!");
    m_enDict[QStringLiteral("no_slots_hint")] = QStringLiteral("No custom save slots yet. Enter a name above to save your current plan!");
    m_enDict[QStringLiteral("nutrient_calcium")] = QStringLiteral("Calcium (Ca)");
    m_enDict[QStringLiteral("nutrient_carbs")] = QStringLiteral("Carbohydrates");
    m_enDict[QStringLiteral("nutrient_copper")] = QStringLiteral("Copper (Cu)");
    m_enDict[QStringLiteral("nutrient_energy")] = QStringLiteral("Energy");
    m_enDict[QStringLiteral("nutrient_fat")] = QStringLiteral("Fat");
    m_enDict[QStringLiteral("nutrient_fiber")] = QStringLiteral("Fiber");
    m_enDict[QStringLiteral("nutrient_gi")] = QStringLiteral("GI / Gastric Emptying");
    m_enDict[QStringLiteral("nutrient_iron")] = QStringLiteral("Iron (Fe)");
    m_enDict[QStringLiteral("nutrient_iron_heme")] = QStringLiteral("Heme (Animal)");
    m_enDict[QStringLiteral("nutrient_iron_non_heme")] = QStringLiteral("Non-Heme (Plant)");
    m_enDict[QStringLiteral("nutrient_leucine")] = QStringLiteral("L-Leucine (MPS)");
    m_enDict[QStringLiteral("nutrient_macros_energy")] = QStringLiteral("Macronutrients & Energy");
    m_enDict[QStringLiteral("nutrient_magnesium")] = QStringLiteral("Magnesium (Mg)");
    m_enDict[QStringLiteral("nutrient_minerals_vitamins")] = QStringLiteral("Minerals & Vitamins");
    m_enDict[QStringLiteral("nutrient_omega3")] = QStringLiteral("Omega-3 Fatty Acids");
    m_enDict[QStringLiteral("nutrient_potassium")] = QStringLiteral("Potassium (K)");
    m_enDict[QStringLiteral("nutrient_protein")] = QStringLiteral("Protein");
    m_enDict[QStringLiteral("nutrient_sodium")] = QStringLiteral("Sodium (Na)");
    m_enDict[QStringLiteral("nutrient_vitamin_c")] = QStringLiteral("Vitamin C");
    m_enDict[QStringLiteral("nutrient_zinc")] = QStringLiteral("Zinc (Zn)");
    m_enDict[QStringLiteral("nutrition_quest_title")] = QStringLiteral("Nutrition Quest");
    m_enDict[QStringLiteral("overwrite_slot_btn")] = QStringLiteral("Overwrite");
    m_enDict[QStringLiteral("per_100g")] = QStringLiteral("(per 100g)");
    m_enDict[QStringLiteral("portion_size_g")] = QStringLiteral("Portion Size (g):");
    m_enDict[QStringLiteral("profile_btn")] = QStringLiteral("Profile");
    m_enDict[QStringLiteral("protein")] = QStringLiteral("Protein");
    m_enDict[QStringLiteral("quick_add")] = QStringLiteral("Quick Add:");
    m_enDict[QStringLiteral("recipes_btn")] = QStringLiteral("📖 Recipes (32)");
    m_enDict[QStringLiteral("recipes_subtitle")] = QStringLiteral("32 authentic balanced recipes & saved custom meals");
    m_enDict[QStringLiteral("recipes_title")] = QStringLiteral("Recipe & Meal Library");
    m_enDict[QStringLiteral("reset_progress")] = QStringLiteral("Reset All Game Progress");
    m_enDict[QStringLiteral("reset_progress_confirm_msg")] = QStringLiteral("This will reset all unlocked levels back to Level 1 and clear all earned stars (0/72 ★). Your current meal plan will remain intact. Are you sure?");
    m_enDict[QStringLiteral("reset_progress_confirm_title")] = QStringLiteral("Reset Game Progress?");
    m_enDict[QStringLiteral("reset_sample_btn")] = QStringLiteral("Reset Plan");
    m_enDict[QStringLiteral("reset_sample_confirm")] = QStringLiteral("Are you sure you want to replace your current meal plan with the default sample meals?");
    m_enDict[QStringLiteral("reset_sample_title")] = QStringLiteral("Reset to Sample Plan?");
    m_enDict[QStringLiteral("restart_confirm_btn")] = QStringLiteral("Restart Now");
    m_enDict[QStringLiteral("restart_confirm_msg")] = QStringLiteral("Changing the language requires restarting the application. Do you want to proceed and restart now?");
    m_enDict[QStringLiteral("restart_confirm_title")] = QStringLiteral("Restart Required");
    m_enDict[QStringLiteral("satiety")] = QStringLiteral("Satiety");
    m_enDict[QStringLiteral("save_as_template_btn")] = QStringLiteral("💾 Save as Custom Meal");
    m_enDict[QStringLiteral("save_game")] = QStringLiteral("Save / Export");
    m_enDict[QStringLiteral("save_profile")] = QStringLiteral("Save Profile");
    m_enDict[QStringLiteral("save_to_slot_btn")] = QStringLiteral("💾 Save Slot");
    m_enDict[QStringLiteral("saved_in_browser")] = QStringLiteral("Autosaved in Browser");
    m_enDict[QStringLiteral("scan_barcode")] = QStringLiteral("Scan Barcode");
    m_enDict[QStringLiteral("select_language")] = QStringLiteral("Select Language");
    m_enDict[QStringLiteral("servings_label")] = QStringLiteral("Servings");
    m_enDict[QStringLiteral("sex")] = QStringLiteral("Biological Sex");
    m_enDict[QStringLiteral("sport_discipline")] = QStringLiteral("Athletic Discipline & Macro Ratio");
    m_enDict[QStringLiteral("start_time")] = QStringLiteral("Start Time");
    m_enDict[QStringLiteral("tab_about_license")] = QStringLiteral("License & Code");
    m_enDict[QStringLiteral("tab_ai_notice")] = QStringLiteral("AI Database");
    m_enDict[QStringLiteral("tab_data_sources")] = QStringLiteral("Data Sources");
    m_enDict[QStringLiteral("tab_files")] = QStringLiteral("💾 Files & Backup");
    m_enDict[QStringLiteral("tab_levels")] = QStringLiteral("Level Select (%1)");
    m_enDict[QStringLiteral("tab_planner")] = QStringLiteral("Shopping List Planner");
    m_enDict[QStringLiteral("tab_privacy_policy")] = QStringLiteral("Privacy Policy");
    m_enDict[QStringLiteral("tab_schedule")] = QStringLiteral("Daily Schedule Table");
    m_enDict[QStringLiteral("tab_slots")] = QStringLiteral("📁 Save Slots");
    m_enDict[QStringLiteral("target_calc_hint")] = QStringLiteral("Base: %1 + Workouts: %2 = Target: %3 kcal");
    m_enDict[QStringLiteral("target_meal")] = QStringLiteral("Target Meal:");
    m_enDict[QStringLiteral("target_split")] = QStringLiteral("Target: 50C / 25P / 25F");
    m_enDict[QStringLiteral("template_name_placeholder")] = QStringLiteral("Meal name (e.g. My Power Breakfast)...");
    m_enDict[QStringLiteral("tier_1_title")] = QStringLiteral("Tier I: Energetics & Fuel Balance");
    m_enDict[QStringLiteral("tier_2_title")] = QStringLiteral("Tier II: Mineral & Electrolyte Stoichiometry");
    m_enDict[QStringLiteral("tier_3_title")] = QStringLiteral("Tier III: Chrono-Nutrition & Diurnal Gates");
    m_enDict[QStringLiteral("tier_4_title")] = QStringLiteral("Tier IV: Grandmaster Synthesis");
    m_enDict[QStringLiteral("user_name")] = QStringLiteral("Name / Nickname");
    m_enDict[QStringLiteral("user_profile_title")] = QStringLiteral("User Profile & Metabolism");
    m_enDict[QStringLiteral("weight")] = QStringLiteral("Weight (kg)");
    m_enDict[QStringLiteral("workout_custom")] = QStringLiteral("Custom Workout");
    m_enDict[QStringLiteral("workout_endurance")] = QStringLiteral("Endurance Cardio");
    m_enDict[QStringLiteral("workout_hiit")] = QStringLiteral("HIIT & Intervals");
    m_enDict[QStringLiteral("workout_library_btn")] = QStringLiteral("🏋️ Workout Library");
    m_enDict[QStringLiteral("workout_library_subtitle")] = QStringLiteral("Standard athletic disciplines with metabolic energy burn");
    m_enDict[QStringLiteral("workout_library_title")] = QStringLiteral("Athletic Workout Library");
    m_enDict[QStringLiteral("workout_strength")] = QStringLiteral("Strength Training");
    m_enDict[QStringLiteral("workout_stretch")] = QStringLiteral("Stretching & Yoga");
    m_enDict[QStringLiteral("workout_type")] = QStringLiteral("Workout Type");
}

void LanguageManager::initGermanDictionary()
{
    m_deDict[QStringLiteral("about_legal_btn")] = QStringLiteral("Rechtliches & Datenschutz");
    m_deDict[QStringLiteral("about_legal_title")] = QStringLiteral("Über Speis, Lizenzen & Datenschutz");
    m_deDict[QStringLiteral("add_ingredient")] = QStringLiteral("Zutat hinzufügen...");
    m_deDict[QStringLiteral("add_meal")] = QStringLiteral("➕ Mahlzeit hinzufügen");
    m_deDict[QStringLiteral("add_to_meal_btn")] = QStringLiteral("In Plan einfügen");
    m_deDict[QStringLiteral("add_to_plan_btn")] = QStringLiteral("Zum Plan hinzufügen");
    m_deDict[QStringLiteral("add_workout")] = QStringLiteral("Training");
    m_deDict[QStringLiteral("added_to_meal_feedback")] = QStringLiteral("%1g %2 zu %3 hinzugefügt!");
    m_deDict[QStringLiteral("age")] = QStringLiteral("Alter (Jahre)");
    m_deDict[QStringLiteral("app_title")] = QStringLiteral("QtSpeis Nutrition Quest");
    m_deDict[QStringLiteral("apply_estimate")] = QStringLiteral("Schätzwert übernehmen (%1 kcal)");
    m_deDict[QStringLiteral("base_calories")] = QStringLiteral("Grundumsatz (BMR)");
    m_deDict[QStringLiteral("base_calories_hint")] = QStringLiteral("Täglicher Ruheenergiebedarf ohne Sport");
    m_deDict[QStringLiteral("bmr_estimator")] = QStringLiteral("Grundumsatz berechnen (Mifflin-St Jeor)");
    m_deDict[QStringLiteral("btn_close")] = QStringLiteral("Schließen");
    m_deDict[QStringLiteral("btn_evaluate")] = QStringLiteral("Tagesplan auswerten");
    m_deDict[QStringLiteral("bullseye")] = QStringLiteral("🎯 Perfekte Punktlandung (±50 kcal)!");
    m_deDict[QStringLiteral("burned_energy")] = QStringLiteral("Verbrannte Energie");
    m_deDict[QStringLiteral("burned_kcal_tag")] = QStringLiteral("-%1 kcal verbrannt");
    m_deDict[QStringLiteral("burned_macros")] = QStringLiteral("Substratoxidation (Verbrannt)");
    m_deDict[QStringLiteral("calorie_accuracy")] = QStringLiteral("Kalorien-Genauigkeit");
    m_deDict[QStringLiteral("cancel_btn")] = QStringLiteral("Abbrechen");
    m_deDict[QStringLiteral("carbs")] = QStringLiteral("Kohlenhydrate");
    m_deDict[QStringLiteral("cat_all")] = QStringLiteral("Alle");
    m_deDict[QStringLiteral("cat_beverages")] = QStringLiteral("Getränke");
    m_deDict[QStringLiteral("cat_dairy")] = QStringLiteral("Milchprodukte");
    m_deDict[QStringLiteral("cat_eggs")] = QStringLiteral("Eier");
    m_deDict[QStringLiteral("cat_fish")] = QStringLiteral("Fisch & Meeresfrüchte");
    m_deDict[QStringLiteral("cat_fruits")] = QStringLiteral("Obst & Beeren");
    m_deDict[QStringLiteral("cat_grains")] = QStringLiteral("Getreide & Zerealien");
    m_deDict[QStringLiteral("cat_herbs")] = QStringLiteral("Kräuter & Gewürze");
    m_deDict[QStringLiteral("cat_legumes")] = QStringLiteral("Hülsenfrüchte");
    m_deDict[QStringLiteral("cat_meat")] = QStringLiteral("Fleisch & Geflügel");
    m_deDict[QStringLiteral("cat_nuts")] = QStringLiteral("Nüsse & Samen");
    m_deDict[QStringLiteral("cat_oils")] = QStringLiteral("Öle & Fette");
    m_deDict[QStringLiteral("cat_salads")] = QStringLiteral("Salate & Grünzeug");
    m_deDict[QStringLiteral("cat_sweeteners")] = QStringLiteral("Süßungsmittel");
    m_deDict[QStringLiteral("cat_vegetables")] = QStringLiteral("Gemüse");
    m_deDict[QStringLiteral("cheat_btn_action")] = QStringLiteral("Laden & Alles lösen");
    m_deDict[QStringLiteral("cheat_button_confirm")] = QStringLiteral("Möchtest du den verifizierten Idealtag laden und alle 24 Level mit 3 Sternen freischalten?");
    m_deDict[QStringLiteral("cheat_button_desc")] = QStringLiteral("Großmeister-Cheat: Idealtag laden und alle 24 Level meistern");
    m_deDict[QStringLiteral("cheat_button_title")] = QStringLiteral("Großmeister-Cheat");
    m_deDict[QStringLiteral("clear_plan_btn")] = QStringLiteral("Plan leeren");
    m_deDict[QStringLiteral("clear_plan_confirm")] = QStringLiteral("Möchtest du wirklich alle Mahlzeiten und Zutaten löschen? Dein aktueller Tagesplan wird zurückgesetzt. Dies kann nicht rückgängig gemacht werden.");
    m_deDict[QStringLiteral("clear_plan_title")] = QStringLiteral("Tagesplan leeren?");
    m_deDict[QStringLiteral("coach_feedback")] = QStringLiteral("Ernährungs-Coach Feedback:");
    m_deDict[QStringLiteral("collapse_details")] = QStringLiteral("Details verbergen");
    m_deDict[QStringLiteral("collapse_all")] = QStringLiteral("Alle einklappen");
    m_deDict[QStringLiteral("expand_all")] = QStringLiteral("Alle ausklappen");
    m_deDict[QStringLiteral("confirm_delete_slot_msg")] = QStringLiteral("Möchtest du '%1' wirklich löschen?");
    m_deDict[QStringLiteral("confirm_delete_slot_title")] = QStringLiteral("Speicherstand löschen?");
    m_deDict[QStringLiteral("confirm_delete_template_msg")] = QStringLiteral("Möchtest du '%1' wirklich löschen?");
    m_deDict[QStringLiteral("confirm_delete_template_title")] = QStringLiteral("Gespeicherte Mahlzeit löschen?");
    m_deDict[QStringLiteral("confirm_load_slot_msg")] = QStringLiteral("'%1' laden? Nicht gespeicherte Änderungen im aktuellen Plan werden ersetzt.");
    m_deDict[QStringLiteral("confirm_load_slot_title")] = QStringLiteral("Speicherstand laden?");
    m_deDict[QStringLiteral("confirm_overwrite_slot_msg")] = QStringLiteral("'%1' mit deinem aktuellen Tagesplan und Spielfortschritt überschreiben?");
    m_deDict[QStringLiteral("confirm_overwrite_slot_title")] = QStringLiteral("Speicherstand überschreiben?");
    m_deDict[QStringLiteral("constraint_broken_desc")] = QStringLiteral("Dein aktueller Plan verletzt Regeln aus zuvor gemeisterten Leveln:");
    m_deDict[QStringLiteral("constraint_broken_title")] = QStringLiteral("Regelverletzung früherer Level");
    m_deDict[QStringLiteral("constraints_breakdown")] = QStringLiteral("Level-Bedingungen:");
    m_deDict[QStringLiteral("custom_meals_tab")] = QStringLiteral("Gespeicherte Mahlzeiten");
    m_deDict[QStringLiteral("daily_calories")] = QStringLiteral("Tagesenergie (Kalorien)");
    m_deDict[QStringLiteral("deep_audit_btn")] = QStringLiteral("🔬 Biochemisches Ernährungs-Audit");
    m_deDict[QStringLiteral("delete_slot_btn")] = QStringLiteral("Löschen");
    m_deDict[QStringLiteral("diff_kcal")] = QStringLiteral("%1 kcal Abweichung");
    m_deDict[QStringLiteral("diversity")] = QStringLiteral("Diversität");
    m_deDict[QStringLiteral("duration")] = QStringLiteral("Dauer (Minuten)");
    m_deDict[QStringLiteral("edit_workout")] = QStringLiteral("Training bearbeiten");
    m_deDict[QStringLiteral("evaluating")] = QStringLiteral("Wird ausgewertet...");
    m_deDict[QStringLiteral("expand_details")] = QStringLiteral("Details");
    m_deDict[QStringLiteral("export_file")] = QStringLiteral("📤 Exportieren (.json)");
    m_deDict[QStringLiteral("import_file")] = QStringLiteral("📥 Importieren (.json)");
    m_deDict[QStringLiteral("fat")] = QStringLiteral("Fett");
    m_deDict[QStringLiteral("female")] = QStringLiteral("Weiblich");
    m_deDict[QStringLiteral("male")] = QStringLiteral("Männlich");
    m_deDict[QStringLiteral("fiber")] = QStringLiteral("Ballaststoffe");
    m_deDict[QStringLiteral("files_backup_tab")] = QStringLiteral("Dateien & Backup");
    m_deDict[QStringLiteral("food_explorer_btn")] = QStringLiteral("🔬 Zutaten-Explorer");
    m_deDict[QStringLiteral("height")] = QStringLiteral("Körpergröße (cm)");
    m_deDict[QStringLiteral("keep_editing")] = QStringLiteral("✏️ Weiter bearbeiten");
    m_deDict[QStringLiteral("levels_menu")] = QStringLiteral("🏆 Level-Übersicht");
    m_deDict[QStringLiteral("load_slot_btn")] = QStringLiteral("Laden");
    m_deDict[QStringLiteral("macro_accuracy")] = QStringLiteral("Makronährstoff-Genauigkeit");
    m_deDict[QStringLiteral("macro_split")] = QStringLiteral("Makronährstoff-Verteilung (% der Energie)");
    m_deDict[QStringLiteral("matched_in")] = QStringLiteral("Gefunden in %1: \"%2\"");
    m_deDict[QStringLiteral("meal_label")] = QStringLiteral("Mahlzeit");
    m_deDict[QStringLiteral("name_placeholder")] = QStringLiteral("z.B. Alex, Läufer99");
    m_deDict[QStringLiteral("new_save_slot")] = QStringLiteral("+ Neuer Speicherstand");
    m_deDict[QStringLiteral("new_slot_placeholder")] = QStringLiteral("z.B. Level 5 Vorbereitung, Marathon-Tag");
    m_deDict[QStringLiteral("next_level")] = QStringLiteral("Nächstes Level →");
    m_deDict[QStringLiteral("no_saved_meals")] = QStringLiteral("Keine gespeicherten Mahlzeiten vorhanden.");
    m_deDict[QStringLiteral("no_slots_found")] = QStringLiteral("Noch keine Speicherstände gesichert.");
    m_deDict[QStringLiteral("nutrient_calcium")] = QStringLiteral("Calcium");
    m_deDict[QStringLiteral("nutrient_carbs")] = QStringLiteral("Kohlenhydrate");
    m_deDict[QStringLiteral("nutrient_copper")] = QStringLiteral("Kupfer");
    m_deDict[QStringLiteral("nutrient_energy")] = QStringLiteral("Energie");
    m_deDict[QStringLiteral("nutrient_fat")] = QStringLiteral("Fett");
    m_deDict[QStringLiteral("nutrient_fiber")] = QStringLiteral("Ballaststoffe");
    m_deDict[QStringLiteral("nutrient_iron")] = QStringLiteral("Eisen");
    m_deDict[QStringLiteral("nutrient_iron_heme")] = QStringLiteral("Häm-Eisen (tierisch)");
    m_deDict[QStringLiteral("nutrient_iron_non_heme")] = QStringLiteral("Nicht-Häm-Eisen (pflanzlich)");
    m_deDict[QStringLiteral("nutrient_leucine")] = QStringLiteral("L-Leucin (MPS)");
    m_deDict[QStringLiteral("nutrient_macros_energy")] = QStringLiteral("Makronährstoffe & Energie");
    m_deDict[QStringLiteral("nutrient_magnesium")] = QStringLiteral("Magnesium");
    m_deDict[QStringLiteral("nutrient_minerals_vitamins")] = QStringLiteral("Mineralstoffe & Vitamine");
    m_deDict[QStringLiteral("nutrient_mufa")] = QStringLiteral("Einfach ungesättigt");
    m_deDict[QStringLiteral("nutrient_omega3")] = QStringLiteral("Omega-3");
    m_deDict[QStringLiteral("nutrient_omega6")] = QStringLiteral("Omega-6");
    m_deDict[QStringLiteral("nutrient_potassium")] = QStringLiteral("Kalium");
    m_deDict[QStringLiteral("nutrient_protein")] = QStringLiteral("Protein");
    m_deDict[QStringLiteral("nutrient_pufa")] = QStringLiteral("Mehrfach ungesättigt");
    m_deDict[QStringLiteral("nutrient_sat_fat")] = QStringLiteral("Gesättigte Fettsäuren");
    m_deDict[QStringLiteral("nutrient_sodium")] = QStringLiteral("Natrium");
    m_deDict[QStringLiteral("nutrient_thiamine")] = QStringLiteral("Thiamin (B1)");
    m_deDict[QStringLiteral("nutrient_tryptophan")] = QStringLiteral("L-Tryptophan");
    m_deDict[QStringLiteral("nutrient_vitamin_a")] = QStringLiteral("Vitamin A");
    m_deDict[QStringLiteral("nutrient_vitamin_c")] = QStringLiteral("Vitamin C");
    m_deDict[QStringLiteral("nutrient_vitamin_d")] = QStringLiteral("Vitamin D");
    m_deDict[QStringLiteral("nutrient_vitamin_e")] = QStringLiteral("Vitamin E");
    m_deDict[QStringLiteral("nutrient_vitamin_k")] = QStringLiteral("Vitamin K");
    m_deDict[QStringLiteral("nutrient_zinc")] = QStringLiteral("Zink");
    m_deDict[QStringLiteral("nutrition_facts")] = QStringLiteral("Nährwerte & Mikronährstoffe");
    m_deDict[QStringLiteral("overwrite_slot_btn")] = QStringLiteral("Überschreiben");
    m_deDict[QStringLiteral("per_100g")] = QStringLiteral("(pro 100g)");
    m_deDict[QStringLiteral("portion_size_g")] = QStringLiteral("Portionsgröße (g)");
    m_deDict[QStringLiteral("protein")] = QStringLiteral("Protein");
    m_deDict[QStringLiteral("quick_add")] = QStringLiteral("Schnellauswahl:");
    m_deDict[QStringLiteral("recipes_title")] = QStringLiteral("Rezepte (%1)");
    m_deDict[QStringLiteral("reset_progress_btn")] = QStringLiteral("Fortschritt zurücksetzen");
    m_deDict[QStringLiteral("reset_progress_confirm_msg")] = QStringLiteral("Möchtest du wirklich alle Sterne zurücksetzen und zu Level 1 zurückkehren? Dein aktueller Tagesplan bleibt erhalten.");
    m_deDict[QStringLiteral("reset_progress_confirm_title")] = QStringLiteral("Spielfortschritt zurücksetzen?");
    m_deDict[QStringLiteral("reset_sample_title")] = QStringLiteral("Beispielplan laden");
    m_deDict[QStringLiteral("restart_confirm_msg")] = QStringLiteral("Das Ändern der Sprache erfordert ein Neuladen der Anwendung. Jetzt fortfahren?");
    m_deDict[QStringLiteral("restart_confirm_title")] = QStringLiteral("Neuladen erforderlich");
    m_deDict[QStringLiteral("save_plan_btn")] = QStringLiteral("Plan sichern");
    m_deDict[QStringLiteral("save_profile")] = QStringLiteral("Profil speichern");
    m_deDict[QStringLiteral("save_profile_btn")] = QStringLiteral("💾 Profil speichern");
    m_deDict[QStringLiteral("save_slots_tab")] = QStringLiteral("📁 Speicherstände");
    m_deDict[QStringLiteral("save_to_slot_btn")] = QStringLiteral("💾 Speichern");
    m_deDict[QStringLiteral("saved_in_browser")] = QStringLiteral("Im Browser automatisch gesichert");
    m_deDict[QStringLiteral("scan_barcode")] = QStringLiteral("Barcode scannen");
    m_deDict[QStringLiteral("search_food_placeholder")] = QStringLiteral("Zutaten suchen (z.B. Haferflocken, Lachs, Banane)...");
    m_deDict[QStringLiteral("search_recipes")] = QStringLiteral("Rezepte durchsuchen...");
    m_deDict[QStringLiteral("search_workouts")] = QStringLiteral("Trainingsformen suchen...");
    m_deDict[QStringLiteral("select_language")] = QStringLiteral("Sprache auswählen");
    m_deDict[QStringLiteral("select_sport_discipline")] = QStringLiteral("Sportdisziplin & Makroverhältnis");
    m_deDict[QStringLiteral("serving_g")] = QStringLiteral("Portion (%1g)");
    m_deDict[QStringLiteral("servings_label")] = QStringLiteral("Portionen");
    m_deDict[QStringLiteral("sex")] = QStringLiteral("Biologisches Geschlecht");
    m_deDict[QStringLiteral("shopping_planner_btn")] = QStringLiteral("Tagesplaner");
    m_deDict[QStringLiteral("sport_discipline")] = QStringLiteral("Sportdisziplin & Makroverhältnis");
    m_deDict[QStringLiteral("start_time")] = QStringLiteral("Startzeit");
    m_deDict[QStringLiteral("tab_about_license")] = QStringLiteral("Lizenz & Quellcode");
    m_deDict[QStringLiteral("tab_ai_notice")] = QStringLiteral("KI-Ernährungsdatenbank");
    m_deDict[QStringLiteral("tab_data_sources")] = QStringLiteral("Datenquellen");
    m_deDict[QStringLiteral("tab_files")] = QStringLiteral("💾 Dateien & Backup");
    m_deDict[QStringLiteral("tab_levels")] = QStringLiteral("Level-Auswahl (%1)");
    m_deDict[QStringLiteral("tab_planner")] = QStringLiteral("Tagesplaner");
    m_deDict[QStringLiteral("tab_privacy_policy")] = QStringLiteral("Datenschutzerklärung");
    m_deDict[QStringLiteral("tab_schedule")] = QStringLiteral("Tageszeitlicher Zeitplan");
    m_deDict[QStringLiteral("tab_slots")] = QStringLiteral("📁 Speicherstände");
    m_deDict[QStringLiteral("target_calc_hint")] = QStringLiteral("Grundumsatz: %1 + Training: %2 = Zielwert: %3 kcal");
    m_deDict[QStringLiteral("target_meal")] = QStringLiteral("Ziel-Mahlzeit:");
    m_deDict[QStringLiteral("target_split")] = QStringLiteral("Ziel: 50C / 25P / 25F");
    m_deDict[QStringLiteral("template_name_placeholder")] = QStringLiteral("Mahlzeitenname (z.B. Power-Frühstück)...");
    m_deDict[QStringLiteral("tier_1_title")] = QStringLiteral("Tier I: Energetik & Brennstoff-Balance");
    m_deDict[QStringLiteral("tier_2_title")] = QStringLiteral("Tier II: Mineralstoff- & Elektrolyt-Stöchiometrie");
    m_deDict[QStringLiteral("tier_3_title")] = QStringLiteral("Tier III: Chrono-Nutrition & Zirkadiane Tore");
    m_deDict[QStringLiteral("tier_4_title")] = QStringLiteral("Tier IV: Großmeister-Synthese");
    m_deDict[QStringLiteral("total_calories")] = QStringLiteral("Gesamtkalorien");
    m_deDict[QStringLiteral("unit_g")] = QStringLiteral("g");
    m_deDict[QStringLiteral("unit_kcal")] = QStringLiteral("kcal");
    m_deDict[QStringLiteral("unit_mg")] = QStringLiteral("mg");
    m_deDict[QStringLiteral("user_name")] = QStringLiteral("Name / Spitzname");
    m_deDict[QStringLiteral("user_profile_title")] = QStringLiteral("Athletenprofil & Grundumsatz");
    m_deDict[QStringLiteral("weight")] = QStringLiteral("Gewicht (kg)");
    m_deDict[QStringLiteral("workout_custom")] = QStringLiteral("Individuelles Training");
    m_deDict[QStringLiteral("workout_endurance")] = QStringLiteral("Ausdauertraining (Cardio)");
    m_deDict[QStringLiteral("workout_hiit")] = QStringLiteral("HIIT & Intervalle");
    m_deDict[QStringLiteral("workout_library_btn")] = QStringLiteral("🏋️ Trainings-Bibliothek");
    m_deDict[QStringLiteral("workout_library_subtitle")] = QStringLiteral("Typische Sportarten mit metabolischem Kalorienverbrauch");
    m_deDict[QStringLiteral("workout_library_title")] = QStringLiteral("Trainings- & Sportarten-Bibliothek");
    m_deDict[QStringLiteral("workout_strength")] = QStringLiteral("Krafttraining & Hypertrophie");
    m_deDict[QStringLiteral("workout_stretch")] = QStringLiteral("Dehnen & Yoga");
    m_deDict[QStringLiteral("workout_type")] = QStringLiteral("Trainingsform");
    m_deDict[QStringLiteral("browse_explorer_btn")] = QStringLiteral("Zutaten-Explorer");
    m_deDict[QStringLiteral("open_explorer_for_meal")] = QStringLiteral("Zutaten-Explorer für diese Mahlzeit öffnen");
    m_deDict[QStringLiteral("chrono_timing_chart_title")] = QStringLiteral("Tageszeitlicher Nährstoffverlauf & Kumulative Aufnahme");
    m_deDict[QStringLiteral("chrono_bar_legend")] = QStringLiteral("Mahlzeit");
    m_deDict[QStringLiteral("chrono_line_legend")] = QStringLiteral("Kumulativ");
    m_deDict[QStringLiteral("chrono_target_legend")] = QStringLiteral("Zielwert / Zeitfenster");
    m_deDict[QStringLiteral("welcome_onboarding_title")] = QStringLiteral("Willkommen bei Nutrition Quest!");
    m_deDict[QStringLiteral("welcome_onboarding_subtitle")] = QStringLiteral("Dein evidenzbasiertes Sporternährungs- & Biochemie-Puzzle.");
    m_deDict[QStringLiteral("onboarding_step1_title")] = QStringLiteral("1. Athletenprofil einrichten");
    m_deDict[QStringLiteral("onboarding_step1_desc")] = QStringLiteral("Passe Grundumsatz (BMR) und Makro-Verteilung an deine Sportart an.");
    m_deDict[QStringLiteral("onboarding_step2_title")] = QStringLiteral("2. Mahlzeiten zusammenstellen");
    m_deDict[QStringLiteral("onboarding_step2_desc")] = QStringLiteral("Kombiniere Zutaten und Rezepte, um deine Zielwerte genau zu treffen.");
    m_deDict[QStringLiteral("onboarding_step3_title")] = QStringLiteral("3. Plan auswerten & Aufsteigen");
    m_deDict[QStringLiteral("onboarding_step3_desc")] = QStringLiteral("Meistere die Regeln von Level 1 bis 24 und werde zum Großmeister!");
    m_deDict[QStringLiteral("start_quest_btn")] = QStringLiteral("🚀 Los geht's!");
    m_deDict[QStringLiteral("quick_start_btn")] = QStringLiteral("⚡ Schnellstart");
    m_deDict[QStringLiteral("customize_profile_btn")] = QStringLiteral("⚙️ Profil anpassen");
    m_deDict[QStringLiteral("autosaved_status")] = QStringLiteral("Im Browser automatisch gesichert");
    m_deDict[QStringLiteral("last_saved")] = QStringLiteral("Zuletzt gesichert:");
    m_deDict[QStringLiteral("breakfast")] = QStringLiteral("Frühstück");
    m_deDict[QStringLiteral("lunch")] = QStringLiteral("Mittagessen");
    m_deDict[QStringLiteral("snack")] = QStringLiteral("Snack");
    m_deDict[QStringLiteral("dinner")] = QStringLiteral("Abendessen");
    m_deDict[QStringLiteral("post_wo_meal")] = QStringLiteral("Post-Workout Shake");
    m_deDict[QStringLiteral("next_level_locked_msg")] = QStringLiteral("⚠️ Level-Bedingung noch nicht erfüllt. Erreiche mindestens 2 Sterne, um das nächste Level freizuschalten!");
}
