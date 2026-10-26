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

    QSettings settings;
    m_currentLanguage = settings.value(QStringLiteral("appLanguage"), QStringLiteral("en")).toString().trimmed().toLower();
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
    m_currentLanguage = code;

    QSettings settings;
    settings.setValue(QStringLiteral("appLanguage"), m_currentLanguage);

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
    QString res = QCoreApplication::translate("QtSpeis", key.toUtf8().constData());
    if ((res == key || res.isEmpty()) && m_enDict.contains(key)) {
        res = m_enDict.value(key);
    } else if (res.isEmpty()) {
        res = key;
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
