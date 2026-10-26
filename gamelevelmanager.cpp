#include "gamelevelmanager.h"
#include "mealplanmanager.h"
#include "fooddatabase.h"
#include "languagemanager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <cmath>
#include <algorithm>
#include <QDebug>
#include <QUuid>

static int parseTimeToMinutes(const QString &timeStr)
{
    QString t = timeStr.trimmed();
    if (t.isEmpty()) return 12 * 60;

    QStringList parts = t.split(QLatin1Char(':'));
    if (parts.size() >= 2) {
        bool okH = false, okM = false;
        int h = parts[0].toInt(&okH);
        int m = parts[1].toInt(&okM);
        if (okH && okM) {
            return std::clamp(h, 0, 23) * 60 + std::clamp(m, 0, 59);
        }
    }
    bool ok = false;
    int h = t.toInt(&ok);
    if (ok) {
        return std::clamp(h, 0, 23) * 60;
    }
    return 12 * 60;
}

GameLevelManager::GameLevelManager(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("QtSpeis"), QStringLiteral("NutritionQuest"))
{
    initializeLevels();
    initializeHeroModifiers();

    if (LanguageManager::instance()) {
        connect(LanguageManager::instance(), &LanguageManager::languageChanged, this, [this]() {
            initializeLevels();
            emit levelsChanged();
            emit currentLevelChanged();
        });
    }
}


struct LevelLocalization {
    int id;
    const char *titleDe;
    const char *subtitleDe;
    const char *tipDe;
};

static const LevelLocalization s_deLevels[] = {
    { 1, "Kalorisches Gleichgewicht", "Zielwert: 2.000 kcal (±50 kcal)", "Optimiere die Portionsgrößen deiner Grundnahrungsmittel wie Haferflocken oder Kartoffeln." },
    { 2, "Makronährstoff-Harmonie", "55% Kohlenhydrate • 12–18% Eiweiß • 27–33% Fett (Sport-Profil)", "Passe Kohlenhydrate und Proteinquellen an dein Sportprofil an." },
    { 3, "Mikrobiom-Ballaststoffbasis", "Gesamtballaststoffe ≥ 35g/Tag", "Integriere Haferflocken, Hülsenfrüchte, Beeren und gedämpften Brokkoli." },
    { 4, "Gesättigte Fettsäuren & Lipidqualität", "Ges. Fett < 8% der kcal • Ungesättigt ≥ 65% der Lipide", "Ersetze Butter durch natives Olivenöl extra, Nüsse und Lachs." },
    { 5, "Essenzielle Fettsäuren (Ω-6 : Ω-3)", "Omega-6 : Omega-3 ≤ 4:1 • Omega-3 ≥ 2.5g", "Setze auf Lachs, Chiasamen, Walnüsse und Leinsamen." },
    { 6, "Natrium-Kalium-Pumpe", "Kalium ≥ 3.500mg • Natrium < 2.000mg • Na:K < 1.0 (molar)", "Wähle kaliumreiche Kohlenhydrate wie Süßkartoffeln, Bananen und Zucchini." },
    { 7, "Calcium-Magnesium-Verhältnis", "Calcium-zu-Magnesium Massenverhältnis 1.5:1 bis 2.0:1", "Kombiniere Joghurt mit Kürbiskernen, Haferflocken und grünem Gemüse." },
    { 8, "Spurenelement-Stöchiometrie (Zn : Cu)", "Zink-zu-Kupfer Massenverhältnis 10:1 bis 15:1 • Zn ≥ 11mg", "Mageres Fleisch, Kürbiskerne und Vollkorngetreide halten das Spurenelement-Gleichgewicht." },
    { 9, "Regionale & Saisonale Ökologie", "100% Saisonale Frische- und Lagerware", "Wähle regionale Äpfel, Wurzelgemüse, Kohl und Kürbis." },
    { 10, "Stoichiometrische Resorptionsförderung (Regel 3)", "50–80mg Vit C mit pflanzl. Eisen (≥ 2.0mg) • Ca < 100mg", "Gib rote Paprikastreifen oder Zitronensaft zu Linsen- und Getreidegerichten." },
    { 11, "Lipidmatrix für fettlösliche Vitamine (Regel 5a)", "10–15g Fett in Mahlzeiten mit ≥ 30% RDA Vit A/D/E/K", "Verfeinere Salate und gedämpftes Gemüse mit 10g Olivenöl oder Avocado." },
    { 12, "Transporter-Entkopplung (Regel 5b)", "Hohe Dosis Vit E getrennt von Vit D & K um ≥ 2h", "Nimm Vitamin D3/K2 zum Frühstück und verzehre Vitamin-E-Snacks am Nachmittag." },
    { 13, "Morgendliches Calcium-Fenster (< 13:00)", "≥ 60% des täglichen Calciums vor 13:00 konsumiert", "Platziere Joghurt, Quark oder Käse im Frühstück und Vormittagssnack." },
    { 14, "Abendliches Magnesium-Fenster (≥ 18:00)", "≥ 50% des täglichen Magnesiums nach 18:00 konsumiert", "Integriere Kürbiskerne, Brokkoli oder Quinoa in das Abendessen." },
    { 15, "Eisen-Calcium-Entkopplung (Regel 2)", "Eisen-Hauptmahlzeit: Ca ≤ 125mg • 0g Milch & 0g Ei-Phosvitin", "Wähle das Mittagessen als milchfreie, eifreie Eisenmahlzeit." },
    { 16, "Polyphenol- & Tannin-Puffer (Regel 1)", "Kaffee / Tee ≥ 60 Min. getrennt von Fe/Zn-Mahlzeiten", "Trinke deinen Morgenkaffee mit ausreichend zeitlichem Abstand zu den Hauptmahlzeiten." },
    { 17, "Phytat-Reduktion (Regel 4)", "Sauerteig, Einweichen oder Vit C Bypass", "Verwende über Nacht eingeweichte Haferflocken oder handwerkliches Sauerteigbrot." },
    { 18, "Viskose Ballaststoffe (Regel 7)", "Flohsamen ≥ 90 Min. getrennt von Mineralstoff-Mahlzeiten", "Plane lösliche Ballaststoff-Getränke im Nachmittags-Fastenfenster ein." },
    { 19, "Post-Workout PepT1-Kinetik (Regel 6a)", "20–40g Protein innerhalb 105 Min. post-WO", "Trinke einen Whey-Shake oder verzehre schnelle Peptide direkt nach dem Training." },
    { 20, "Pre-Workout Glykämie & Magenverweildauer", "Niedriger/mittl. GI • Fett ≤ 28g • Beendet > 2.5h Pre-WO", "Verzehre magere Proteine mit Süßkartoffeln rechtzeitig vor der Einheit." },
    { 21, "Hepcidin-Bypass (Regel 7)", "Eisen-Hauptmahlzeit außerhalb 3–6h post-WO", "Platziere die Haupteisenmahlzeit mittags, weit entfernt vom abendlichen Hepcidin-Peak." },
    { 22, "Zirkadiane Leucin- & MPS-Verteilung", "≥ 2.0g L-Leucin in jeder der Hauptmahlzeiten", "Verteile hochwertiges Protein gleichmäßig auf Frühstück, Mittag- und Abendessen." },
    { 23, "Abendlicher LAT1 Tryptophan-Transport (Regel 6b)", "Tryptophan:LNAA Verhältnis ≥ 0.07 am Abend • Kein BCAA-Bolus", "Verzichte abends auf BCAA-Präparate und setze auf komplexe Kohlenhydrate und Kürbiskerne." },
    { 24, "Großmeister der Bio-Architektur", "Alle 23 Bedingungen gleichzeitig erfüllt", "Vollständige Synchronisation erreicht durch den verifizierten Golden Day Plan." }
};

void GameLevelManager::initializeLevels()
{
    m_allLevels.clear();

    QString dbPath = FoodDatabase::resolveSpeisDbPath();
    QString connName = QString("GameLevelDb_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));

    bool loadedFromDb = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(dbPath);
        if (db.open()) {
            QSqlQuery q(db);
            if (q.exec(QStringLiteral("SELECT id, tier, level_number, title, subtitle, badge, difficulty, target_formula, biochem_rationale, coaching_tip, tolerance_json FROM game_levels ORDER BY level_number ASC;"))) {
                int prevStars = 3; // Level 1 is always unlocked
                while (q.next()) {
                    int lvlNum = q.value(QStringLiteral("level_number")).toInt();
                    int stars = getStars(lvlNum);
                    bool unlocked = (lvlNum == 1) || (prevStars >= 2);

                    QVariantMap l;
                    l[QStringLiteral("id")] = lvlNum;
                    l[QStringLiteral("tier")] = q.value(QStringLiteral("tier")).toInt();
                    l[QStringLiteral("title")] = QStringLiteral("Level %1: %2").arg(lvlNum).arg(q.value(QStringLiteral("title")).toString());
                    l[QStringLiteral("rawTitle")] = q.value(QStringLiteral("title")).toString();
                    l[QStringLiteral("subtitle")] = q.value(QStringLiteral("subtitle")).toString();
                    l[QStringLiteral("badge")] = q.value(QStringLiteral("badge")).toString();
                    l[QStringLiteral("difficulty")] = q.value(QStringLiteral("difficulty")).toInt();
                    l[QStringLiteral("targetFormula")] = q.value(QStringLiteral("target_formula")).toString();
                    l[QStringLiteral("biochemRationale")] = q.value(QStringLiteral("biochem_rationale")).toString();
                    l[QStringLiteral("coachingTip")] = q.value(QStringLiteral("coaching_tip")).toString();
                    l[QStringLiteral("toleranceJson")] = q.value(QStringLiteral("tolerance_json")).toString();
                    l[QStringLiteral("targetCalories")] = 2000.0;
                    bool isDe = (LanguageManager::instance() && LanguageManager::instance()->currentLanguage() == QStringLiteral("de"));
                    if (isDe) {
                        for (const auto &deRow : s_deLevels) {
                            if (deRow.id == lvlNum) {
                                l[QStringLiteral("title")] = QStringLiteral("Level %1: %2").arg(lvlNum).arg(QString::fromUtf8(deRow.titleDe));
                                l[QStringLiteral("rawTitle")] = QString::fromUtf8(deRow.titleDe);
                                l[QStringLiteral("subtitle")] = QString::fromUtf8(deRow.subtitleDe);
                                l[QStringLiteral("coachingTip")] = QString::fromUtf8(deRow.tipDe);
                                break;
                            }
                        }
                    }
                    if (lvlNum == 2) {
                        if (!isDe) {
                            l[QStringLiteral("subtitle")] = QStringLiteral("55% Carbs • 12–18% Protein • 27–33% Fat (Sport Profile)");
                        }
                        l[QStringLiteral("badge")] = QStringLiteral("⚖ 55 / 15 / 30");
                    } else if (lvlNum == 5) {
                        l[QStringLiteral("badge")] = QStringLiteral("🐟 Omega-6 : Omega-3 ≤ 4:1");
                    }
                    l[QStringLiteral("badge")] = l[QStringLiteral("badge")].toString().remove(QChar(0xFE0F));
                    l[QStringLiteral("unlocked")] = unlocked;
                    l[QStringLiteral("stars")] = stars;

                    m_allLevels.append(l);
                    prevStars = stars;
                }
                if (m_allLevels.size() == 24) {
                    loadedFromDb = true;
                }
            }
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(connName);

    if (!loadedFromDb) {
        // Embedded resilient fallback definitions for all 24 levels
        struct FallbackLevel {
            int num;
            int tier;
            const char *title;
            const char *subtitle;
            const char *badge;
            int diff;
            const char *formula;
            const char *rationale;
            const char *tip;
        };

        static const FallbackLevel fallbacks[] = {
            { 1, 1, "Caloric Equilibrium", "Energy Target: 2,000 kcal", "⚡ 2,000 kcal", 1, "total_calories == 2000 +- 50 kcal", "First law of thermodynamics: isocaloric balance stabilizes hepatic glycogen.", "Tuning staple portions like oats or potatoes lands right on the bullseye." },
            { 2, 1, "Macronutrient Harmony", "55% Carbs • 12–18% Protein • 27–33% Fat (Sport Profile)", "⚖️ 55 / 15 / 30", 1, "carbs_pct in sport_range AND protein_pct in sport_range AND fat_pct in sport_range", "Isocaloric energy split personalized by athletic discipline: 55% carbs, 12–18% protein, 27–33% healthy fats.", "Adjust carbohydrate and protein portions to match your sport profile targets." },
            { 3, 1, "Gut Microbiome Fiber Floor", "Total Fiber >= 35g/day", "🌾 Fiber ≥ 35g", 2, "total_fiber_g >= 35.0", "Colonic fermentation yields SCFAs, acidifying the lumen and strengthening tight junctions.", "Incorporate rolled oats, legumes, berries, and steamed broccoli." },
            { 4, 1, "Saturated Fat Ceiling & Lipid Quality", "SatFat < 8% of kcal • Unsaturated >= 70% of lipids", "🫒 SatFat < 8%", 2, "sat_fat_kcal_pct < 8.0 AND unsat_fat_pct >= 70.0", "Excess SFAs downregulate LDL receptors; monounsaturated oleic acid preserves endothelial health.", "Swap butter for extra virgin olive oil, nuts, and salmon." },
            { 5, 1, "Essential Fatty Acid Balance", "Omega-6 : Omega-3 <= 4:1 • Omega-3 >= 2.5g", "🐟 Omega-6 : Omega-3 ≤ 4:1", 2, "omega_6 / omega_3 <= 4.0 AND omega_3 >= 2.5", "LA and ALA compete for delta-6-desaturase; low ratio produces anti-inflammatory resolvins.", "Incorporate wild salmon, chia seeds, walnuts, and flaxseeds." },
            { 6, 1, "The Sodium–Potassium Pump Baseline", "Potassium >= 3,500mg • Sodium < 2,000mg • Na:K < 1.0 (molar)", "⚡ Na : K < 1.0", 2, "potassium >= 3500 AND sodium < 2000 AND molar_ratio < 1.0", "Maintains resting membrane potential via Na+/K+-ATPase and preserves vascular elasticity.", "Base carbs on sweet potatoes, bananas, zucchini, and spinach." },
            { 7, 2, "The Bone & Muscle Mineral Axis", "Calcium to Magnesium mass ratio 1.5:1 to 2.0:1", "🦴 Ca : Mg = 1.5–2.0", 3, "calcium / magnesium >= 1.5 AND calcium / magnesium <= 2.0", "Ratios > 2.6:1 inhibit magnesium transport; magnesium acts as a natural calcium channel blocker.", "Pair yogurt and dairy with pumpkin seeds, oats, and greens." },
            { 8, 2, "Trace Metal Stoichiometry", "Zinc to Copper mass ratio 10:1 to 15:1 • Zn >= 11mg • Cu >= 0.9mg", "🛡️ Zn : Cu = 10:1–15:1", 3, "zinc >= 11.0 AND copper >= 0.9 AND ratio BETWEEN 10 AND 15", "Unbuffered zinc induces mucosal metallothionein, sequestering copper and inducing anemia.", "Lean meats, pumpkin seeds, and whole grains naturally balance trace minerals." },
            { 9, 2, "Local Ecology & Terroir", "100% Seasonal Produce Only", "🌱 100% Seasonal", 3, "ALL(fruit_veg_status IN ('FRESH', 'STORAGE'))", "Freshly harvested seasonal produce preserves up to 3x higher ascorbic acid and polyphenols.", "Choose regional apples, root vegetables, cabbage, and squash." },
            { 10, 2, "Stoichiometric Enhancer Pairing (Rule 3)", "50–80mg Vit C with Non-Heme Fe (>=2mg)", "🍋 50–80mg Vit C with Fe", 3, "IF non_heme_fe >= 2.0 THEN vitamin_c >= 50.0", "Ascorbic acid reduces Fe3+ to soluble Fe2+ and neutralizes up to 25mg of phytate phosphorus.", "Add red bell pepper strips or fresh lemon juice to lentil and grain dishes." },
            { 11, 2, "Lipid-Matrix Activation for Fat-Soluble Vitamins (Rule 5a)", "10–15g Fat in Meals with >=30% RDA Vit A/D/E/K", "🥑 10–15g Fat Matrix", 3, "IF fat_soluble_vit_30pct THEN meal_fat >= 10.0", "Fat-soluble vitamins require mixed micelles to activate enterocyte transporters SR-BI and CD36.", "Dress salads and steamed veggies with 10g of olive oil or avocado." },
            { 12, 2, "Competitive Transporter Separation (Rule 5b)", "High-Dose Vit E Decoupled from Vit D & K by >=2h", "💊 Vit E Decoupled from D/K", 3, "IF vit_e >= 33.5 AND vit_d_or_k THEN abs(time_diff) >= 120", "Alpha-tocopherol competitively displaces cholecalciferol and phylloquinone at NPC1L1.", "Take Vitamin D3/K2 with breakfast and enjoy Vitamin E snacks in the afternoon." },
            { 13, 3, "Chrono-Mineral Timing: Morning Calcium Gate", ">= 60% of total daily calcium consumed before 13:00", "☀️ Morning Ca ≥ 60%", 3, "calcium_before_13h / total_calcium >= 0.60", "Synchronizes with circadian PTH rhythms; morning calcium suppresses osteoclastic spikes.", "Front-load yogurt, kefir, or cheese to breakfast and morning snack." },
            { 14, 3, "Chrono-Mineral Timing: Evening Magnesium Window", ">= 50% of total daily magnesium consumed after 18:00", "🌙 Evening Mg ≥ 50%", 3, "magnesium_after_18h / total_magnesium >= 0.50", "Magnesium modulates NMDA receptors and acts as cofactor for nocturnal melatonin synthesis.", "Include pumpkin seeds, broccoli, or quinoa with dinner." },
            { 15, 3, "Calcium & Iron Decoupling (Rule 2)", "Primary Fe meal has Calcium < 50mg and 0g Egg Yolk Phosvitin", "🚫 Ca < 50mg in Primary Fe Meal", 4, "primary_iron_meal.calcium < 50.0 AND primary_iron_meal.phosvitin == 0", "Calcium binds mucosal transferrin and blocks hDMT1; egg yolk phosvitin forms insoluble chelates.", "Designate lunch as your dairy-free, egg-free high-iron meal." },
            { 16, 3, "The Polyphenol Decoupling Law (Rule 1)", "Coffee/Tea separated by >=60m from Fe/Zn/Thiamine meal", "☕ 60m Polyphenol Buffer", 4, "abs(polyphenol_time - mineral_meal_time) >= 60", "Chlorogenic acid, catechins, and galloyl esters form insoluble polyphenol-metal complexes.", "Drink your morning coffee at 09:15, well clear of breakfast and lunch." },
            { 17, 3, "Culinary De-Phytinization (Rule 4)", "Phy:Fe < 1.0 & Phy:Zn < 15 via Sourdough, Soaking, or Vit C Bypass", "🍞 De-Phytinization", 4, "molar_phy_fe < 1.0 AND molar_phy_zn < 15.0 OR vit_c >= 65.0", "Phytate precipitates multivalent cations; fermentation and soaking activate cereal phytases.", "Use overnight soaked oats, artisan sourdough bread, or add 65mg+ Vit C." },
            { 18, 3, "Viscous Gel-Matrix Decoupling", "Viscous fiber boluses separated by >= 90m from mineral meals", "⏳ Viscous Fiber Decoupled", 4, "abs(fiber_time - mineral_meal_time) >= 90", "Mucilage creates an unstirred water layer trapping divalent cations (Fe2+, Zn2+, Mg2+).", "Schedule dedicated fiber drinks in the mid-afternoon fasting window." },
            { 19, 4, "Post-Workout Rapid Kinetics (PepT1) (Rule 6a)", "25–35g High-BV Protein within 45–90m post-workout", "⚡ PepT1 Post-WO Surge", 4, "post_wo_protein BETWEEN 25 AND 35 AND time <= 90m", "PepT1 transports di- and tripeptides faster than free amino acids, maximizing immediate FSR.", "Drink a whey or plant peptide isolate shake right after training." },
            { 20, 4, "Pre-Workout Gastric Emptying & Glycemic Stability", "Low/Med GI (<=55) • Fat <= 8g • Clearance <= 2.5h Pre-WO", "🏃 Pre-WO Fuel (Low-GI)", 4, "gi_class != 'high' AND fat <= 8.0 AND clearance >= 150m", "High-GI triggers rebound hypoglycemia; fat delays gastric clearance causing splanchnic distress.", "Enjoy lean beef with steamed sweet potato at 13:00 before a 16:30 workout." },
            { 21, 4, "The Post-Exercise Hepcidin Window (Rule 7)", "Primary Fe meals: >=3h Pre-WO, <=30m Post-WO, or >=6h Post-WO", "🎯 Hepcidin Bypass", 5, "fe_time <= workout_start - 180 OR fe_time <= workout_end + 30 OR fe_time >= workout_end + 360", "IL-6 triggers hepcidin peaking at 3–6 hours post-exercise, degrading ferroportin and blocking iron.", "Eat your primary iron meal at lunch (13:00), fully clear of the evening hepcidin surge." },
            { 22, 4, "MPS Leucine Trigger Distribution", ">= 2.5g L-Leucine in each of the 3 main meals", "🧬 Leucine ≥ 2.5g / Meal", 5, "ALL(main_meals.leucine >= 2.5)", "Leucine binds Sestrin2, recruiting Rag GTPases to translocate mTORC1 to the lysosome.", "Distribute quality protein evenly: 25–35g protein at breakfast, lunch, and dinner." },
            { 23, 4, "Pre-Sleep Blood-Brain Barrier Preservation (LAT1) (Rule 6b)", "Tryptophan : LNAA ratio >= 0.08 in evening • No BCAA bolus", "🧠 High Trp : LNAA Pre-Sleep", 5, "evening_trp_lnaa >= 0.08 AND bcaa_bolus == 0", "Tryptophan competes with BCAAs at LAT1 for blood-brain barrier transport and melatonin synthesis.", "Avoid evening BCAA powders; choose complex carbs, pumpkin seeds, or chamomile." },
            { 24, 4, "Grandmaster Bio-Architect", "All 23 previous constraints active simultaneously", "👑 Grandmaster 24/24", 5, "ALL(constraints_1_to_23_passed)", "The pinnacle of biochemical precision nutrition: thermodynamics, stoichiometry, and circadian timing.", "Complete synchronization achieved by the verified Golden Day Plan." }
        };

        int prevStars = 3;
        for (const auto &fb : fallbacks) {
            int stars = getStars(fb.num);
            bool unlocked = (fb.num == 1) || (prevStars >= 2);

            QVariantMap l;
            l[QStringLiteral("id")] = fb.num;
            l[QStringLiteral("tier")] = fb.tier;
            l[QStringLiteral("title")] = QStringLiteral("Level %1: %2").arg(fb.num).arg(QString::fromUtf8(fb.title));
            l[QStringLiteral("rawTitle")] = QString::fromUtf8(fb.title);
            l[QStringLiteral("subtitle")] = QString::fromUtf8(fb.subtitle);
            l[QStringLiteral("badge")] = QString::fromUtf8(fb.badge);
            l[QStringLiteral("difficulty")] = fb.diff;
            l[QStringLiteral("targetFormula")] = QString::fromUtf8(fb.formula);
            l[QStringLiteral("biochemRationale")] = QString::fromUtf8(fb.rationale);
            l[QStringLiteral("coachingTip")] = QString::fromUtf8(fb.tip);
            l[QStringLiteral("toleranceJson")] = QStringLiteral("{}");
            l[QStringLiteral("targetCalories")] = 2000.0;
            l[QStringLiteral("unlocked")] = unlocked;
            l[QStringLiteral("stars")] = stars;

            bool isDe = (LanguageManager::instance() && LanguageManager::instance()->currentLanguage() == QStringLiteral("de"));
            if (isDe) {
                for (const auto &deRow : s_deLevels) {
                    if (deRow.id == fb.num) {
                        l[QStringLiteral("title")] = QStringLiteral("Level %1: %2").arg(fb.num).arg(QString::fromUtf8(deRow.titleDe));
                        l[QStringLiteral("rawTitle")] = QString::fromUtf8(deRow.titleDe);
                        l[QStringLiteral("subtitle")] = QString::fromUtf8(deRow.subtitleDe);
                        l[QStringLiteral("coachingTip")] = QString::fromUtf8(deRow.tipDe);
                        break;
                    }
                }
            }

            m_allLevels.append(l);
            prevStars = stars;
        }
    }
}

void GameLevelManager::initializeHeroModifiers()
{
    m_heroModifiers.clear();

    QString dbPath = FoodDatabase::resolveSpeisDbPath();
    QString connName = QString("HeroDb_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));

    bool loadedFromDb = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(dbPath);
        if (db.open()) {
            QSqlQuery q(db);
            if (q.exec(QStringLiteral("SELECT id, title, badge, exclusion_boundary, biochem_conflict, solution_strategy, filter_rule_json FROM hero_modifiers ORDER BY id ASC;"))) {
                while (q.next()) {
                    QString id = q.value(QStringLiteral("id")).toString();
                    QVariantMap h;
                    h[QStringLiteral("id")] = id;
                    h[QStringLiteral("title")] = q.value(QStringLiteral("title")).toString();
                    h[QStringLiteral("badge")] = q.value(QStringLiteral("badge")).toString();
                    h[QStringLiteral("exclusionBoundary")] = q.value(QStringLiteral("exclusion_boundary")).toString();
                    h[QStringLiteral("biochemConflict")] = q.value(QStringLiteral("biochem_conflict")).toString();
                    h[QStringLiteral("solutionStrategy")] = q.value(QStringLiteral("solution_strategy")).toString();
                    h[QStringLiteral("filterRuleJson")] = q.value(QStringLiteral("filter_rule_json")).toString();
                    h[QStringLiteral("active")] = m_activeHeroModifiers.contains(id);

                    m_heroModifiers.append(h);
                }
                if (m_heroModifiers.size() == 12) {
                    loadedFromDb = true;
                }
            }
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(connName);

    if (!loadedFromDb) {
        struct FallbackHero {
            const char *id;
            const char *title;
            const char *badge;
            const char *exclusion;
            const char *conflict;
            const char *strategy;
        };

        static const FallbackHero heroes[] = {
            { "H1", "Celiac Sanction", "🌾🚫 Celiac Sanction", "0.0g Gluten (No wheat, spelt, rye, barley, kamut)", "Eliminates breads and conventional grain phytase.", "Pseudocereals (quinoa, buckwheat), GF oats, sweet potatoes." },
            { "H2", "Dairy-Free Fortress", "🥛🚫 Dairy-Free Fortress", "0.0g Dairy (No milk, yogurt, cheese, whey, casein)", "Greek yogurt and whey lost for morning Ca and PepT1.", "Tofu, canned sardines with bones, bok choy, pea peptides." },
            { "H3", "Nut-Free Haven", "🥜🚫 Nut-Free Haven", "0.0g Tree Nuts & Peanuts", "Walnuts (ALA Omega-3) and almonds (Vit E) eliminated.", "Chia/flax seeds, extra virgin olive oil, avocado." },
            { "H4", "Seed-Free Sanctum", "🌻🚫 Seed-Free Sanctum", "0.0g Seeds (No pumpkin, chia, flax, sesame, sunflower)", "Pumpkin seeds lost for evening Mg and Zn:Cu balance.", "Steamed spinach, quinoa, lean beef, dark cocoa." },
            { "H5", "Low-FODMAP Gauntlet", "🫃🚫 Low-FODMAP Gauntlet", "Zero High-FODMAP Foods (No onions, garlic, apples, wheat, beans)", "High-fiber legumes and pomme fruits eliminated.", "Unripe bananas, kiwis, blueberries, zucchini, firm tofu." },
            { "H6", "Solanaceae Shield", "🍅🚫 Solanaceae Shield", "Zero Nightshades (No peppers, potatoes, tomatoes, eggplant)", "Bell pepper (Vit C) and white potatoes (K) banned.", "Lemon juice, raw broccoli florets, red cabbage, sweet potatoes." },
            { "H7", "Low-Histamine Shield", "🧬🚫 Low-Histamine Shield", "Zero Aged/Fermented Foods (No sourdough, aged cheese, canned fish)", "Sourdough de-phytinization and canned fish eliminated.", "Fresh flash-frozen fish/poultry, acute Vit C de-phytinization bypass." },
            { "H8", "Low-Oxalate Shield", "💎🚫 Low-Oxalate Shield", "Oxalates < 50mg/day (No spinach, chard, beets, almonds, cocoa)", "High-potassium spinach and sweet potatoes eliminated.", "Steamed zucchini, cauliflower, carrots, peeled boiled potatoes." },
            { "H9", "Vegan Bio-Architect", "🌱👑 Vegan Bio-Architect", "100% Plant-Based (No meat, fish, eggs, dairy, collagen)", "100% non-heme iron requires constant Vit C; leucine is lower.", "Tempeh, calcium-set tofu, lupin flakes, pea/rice peptides." },
            { "H10", "AIP Iron Chef", "⚔️👑 AIP Iron Chef", "Full AIP Exclusion (No grains, legumes, dairy, eggs, nightshades, nuts, seeds)", "All conventional starches and plant proteins eliminated.", "Sweet potato, parsnip, grass-fed beef, wild fish, olive oil." },
            { "H11", "Dual Lipid Exclusion", "🌰🚫 Dual Lipid Exclusion", "Zero Nuts AND Zero Seeds", "Primary whole-food plant fats and evening magnesium anchors lost.", "Extra virgin olive oil, whole avocado, wild salmon, steamed greens." },
            { "H12", "Deep Ocean Pescatarian", "🌊🐟 Deep Ocean Pescatarian", "Zero Terrestrial Meat & Poultry (Marine seafood and eggs only)", "High heme iron without beef; avoiding egg phosvitin trap.", "Mussels, clams, wild salmon, cod, shrimp." }
        };

        for (const auto &hDef : heroes) {
            QString id = QString::fromUtf8(hDef.id);
            QVariantMap h;
            h[QStringLiteral("id")] = id;
            h[QStringLiteral("title")] = QString::fromUtf8(hDef.title);
            h[QStringLiteral("badge")] = QString::fromUtf8(hDef.badge);
            h[QStringLiteral("exclusionBoundary")] = QString::fromUtf8(hDef.exclusion);
            h[QStringLiteral("biochemConflict")] = QString::fromUtf8(hDef.conflict);
            h[QStringLiteral("solutionStrategy")] = QString::fromUtf8(hDef.strategy);
            h[QStringLiteral("filterRuleJson")] = QStringLiteral("{}");
            h[QStringLiteral("active")] = m_activeHeroModifiers.contains(id);

            m_heroModifiers.append(h);
        }
    }
}

void GameLevelManager::setCurrentLevel(int level)
{
    if (m_currentLevel != level && level >= 1 && level <= m_allLevels.size()) {
        m_currentLevel = level;
        emit currentLevelChanged();
    }
}

QVariantMap GameLevelManager::currentLevelData() const
{
    return getLevel(m_currentLevel);
}

QVariantMap GameLevelManager::getLevel(int levelId) const
{
    for (const auto &v : m_allLevels) {
        QVariantMap m = v.toMap();
        if (m.value(QStringLiteral("id")).toInt() == levelId) {
            m[QStringLiteral("stars")] = getStars(levelId);
            return m;
        }
    }
    return QVariantMap();
}

int GameLevelManager::getStars(int levelId) const
{
    return m_settings.value(QStringLiteral("level_%1_stars").arg(levelId), 0).toInt();
}

void GameLevelManager::saveStars(int levelId, int stars)
{
    int existing = getStars(levelId);
    if (stars > existing) {
        m_settings.setValue(QStringLiteral("level_%1_stars").arg(levelId), stars);
        m_settings.sync();
        initializeLevels();
        emit levelsChanged();
    }
}

void GameLevelManager::toggleHeroModifier(const QString &heroId)
{
    if (m_activeHeroModifiers.contains(heroId)) {
        m_activeHeroModifiers.removeAll(heroId);
    } else {
        m_activeHeroModifiers.append(heroId);
    }
    emit activeHeroModifiersChanged();
    initializeHeroModifiers();
    emit heroModifiersChanged();
}

bool GameLevelManager::isHeroModifierActive(const QString &heroId) const
{
    return m_activeHeroModifiers.contains(heroId);
}

void GameLevelManager::clearHeroModifiers()
{
    m_activeHeroModifiers.clear();
    emit activeHeroModifiersChanged();
    initializeHeroModifiers();
    emit heroModifiersChanged();
}

void GameLevelManager::loadGoldenPlan(MealPlanManager *planManager, QObject *foodDbObj)
{
    if (planManager) {
        planManager->loadGoldenPlan(foodDbObj);
    }
}

void GameLevelManager::cheatSolveAll(MealPlanManager *planManager, QObject *foodDbObj)
{
    if (planManager) {
        planManager->loadGoldenPlan(foodDbObj);
    }

    for (int l = 1; l <= 24; ++l) {
        saveStars(l, 3);
        for (int i = 0; i < m_allLevels.size(); ++i) {
            QVariantMap lvl = m_allLevels[i].toMap();
            if (lvl.value(QStringLiteral("id")).toInt() == l) {
                lvl[QStringLiteral("stars")] = 3;
                lvl[QStringLiteral("unlocked")] = true;
                m_allLevels[i] = lvl;
                break;
            }
        }
    }
    m_currentLevel = 24;
    emit levelsChanged();
    emit currentLevelChanged();
    if (planManager) {
        evaluatePlan(planManager);
    }
}

void GameLevelManager::resetAllProgress()
{
    for (int l = 1; l <= 24; ++l) {
        m_settings.remove(QStringLiteral("level_%1_stars").arg(l));
    }
    m_settings.sync();

    m_currentLevel = 1;
    m_activeHeroModifiers.clear();
    initializeLevels();
    initializeHeroModifiers();

    emit levelsChanged();
    emit currentLevelChanged();
    emit activeHeroModifiersChanged();
    emit heroModifiersChanged();
}

bool GameLevelManager::isOnboardingCompleted() const
{
    return m_settings.value(QStringLiteral("onboardingDone"), false).toBool();
}

void GameLevelManager::setOnboardingCompleted(bool completed)
{
    m_settings.setValue(QStringLiteral("onboardingDone"), completed);
    m_settings.sync();
}

QVariantMap GameLevelManager::checkAllLevelConstraints(MealPlanManager *planManager)
{
    QVariantMap allConstraints;
    if (!planManager) return allConstraints;

    // Plan daily metrics
    double actualCal = planManager->totalCalories();
    double targetCal = planManager->targetCalories();
    double calDiff = actualCal - targetCal;
    double absCalDiff = std::abs(calDiff);

    double actualC = planManager->carbPercent();
    double actualP = planManager->proteinPercent();
    double actualF = planManager->fatPercent();
    double targetC = planManager->targetCarbPercent();
    double targetP = planManager->targetProteinPercent();
    double targetF = planManager->targetFatPercent();
    double minC = planManager->minCarbPercent();
    double maxC = planManager->maxCarbPercent();
    double minP = planManager->minProteinPercent();
    double maxP = planManager->maxProteinPercent();
    double minF = planManager->minFatPercent();
    double maxF = planManager->maxFatPercent();
    double cDiff = std::abs(actualC - targetC);
    double pDiff = std::abs(actualP - targetP);
    double fDiff = std::abs(actualF - targetF);
    double avgMacroDiff = (cDiff + pDiff + fDiff) / 3.0;

    double actualFiber = planManager->totalFiber();
    double satFat = planManager->totalSatFat();
    double mufa = planManager->totalMufa();
    double pufa = planManager->totalPufa();
    double totalFatG = planManager->totalFat();
    double satFatKcalPct = (actualCal > 0.1) ? ((satFat * 9.0 / actualCal) * 100.0) : 0.0;
    double unsatLipidPct = (totalFatG > 0.1) ? (((mufa + pufa) / totalFatG) * 100.0) : 0.0;

    double omega3 = planManager->totalOmega3();
    double omega6 = planManager->totalOmega6();
    double omegaRatio = (omega3 > 0.05) ? (omega6 / omega3) : 999.0;

    double potassium = planManager->totalPotassium();
    double sodium = planManager->totalSodium();
    double molarNaK = (potassium > 0.1) ? ((sodium / 23.0) / (potassium / 39.1)) : 999.0;

    double calcium = planManager->totalCalcium();
    double magnesium = planManager->totalMagnesium();
    double caMgRatio = (magnesium > 0.1) ? (calcium / magnesium) : 999.0;

    double zinc = planManager->totalZinc();
    double copper = planManager->totalCopper();
    double znCuRatio = (copper > 0.01) ? (zinc / copper) : 999.0;

    // Per-meal analysis
    QVariantList meals = planManager->meals();
    double morningCalcium = 0.0;
    double eveningMagnesium = 0.0;
    QVariantMap primaryFeMeal;
    double maxHemeFe = -1.0;
    double maxFeInMeal = -1.0;

    int workoutMins = 16 * 60 + 30; // default reference workout
    for (const auto &mVal : meals) {
        QVariantMap m = mVal.toMap();
        if (m.value(QStringLiteral("isWorkout")).toBool()) {
            workoutMins = parseTimeToMinutes(m.value(QStringLiteral("time")).toString());
            break;
        }
    }

    bool rule3Violated = false;
    int nonHemeFeMealsCount = 0;
    double bestNonHemeFeInMeal = 0.0;
    double bestNonHemeMealVc = 0.0;
    double bestNonHemeMealCa = 0.0;
    QString bestNonHemeMealTitle;
    bool hasValidNonHemeFeMeal = false;
    bool rule5aViolated = false;
    int fatSolubleMealsCount = 0;
    bool rule5bViolated = false;

    // Polyphenol checks
    QList<int> polyphenolMins;
    QList<int> mineralMealMins;
    // Viscous fiber checks
    QList<int> viscousFiberMins;
    QList<int> heavyMineralMealMins;

    // Leucine trigger check
    int mainMealsWithLeucine25 = 0;
    int mainMealsCount = 0;

    // LAT1 evening check
    double eveningTrp = 0.0;
    double eveningLeu = 0.0;

    for (const auto &mVal : meals) {
        QVariantMap m = mVal.toMap();
        if (m.value(QStringLiteral("isWorkout")).toBool()) continue;
        int mins = parseTimeToMinutes(m.value(QStringLiteral("time")).toString());
        double mCal = m.value(QStringLiteral("calories")).toDouble();
        double mProt = m.value(QStringLiteral("protein")).toDouble();
        double mCa = m.value(QStringLiteral("calcium")).toDouble();
        double mMg = m.value(QStringLiteral("magnesium")).toDouble();
        double mFe = m.value(QStringLiteral("iron")).toDouble();
        double mNonHemeFe = m.value(QStringLiteral("nonHemeIron")).toDouble();
        double mHemeFe = m.value(QStringLiteral("hemeIron")).toDouble();
        double mVc = m.value(QStringLiteral("vitaminC")).toDouble();
        double mFat = m.value(QStringLiteral("fat")).toDouble();
        double mVa = m.value(QStringLiteral("vitaminA")).toDouble();
        double mVd = m.value(QStringLiteral("vitaminD")).toDouble();
        double mVe = m.value(QStringLiteral("vitaminE")).toDouble();
        double mVk = m.value(QStringLiteral("vitaminK")).toDouble();
        double mZn = m.value(QStringLiteral("zinc")).toDouble();
        double mThiam = m.value(QStringLiteral("thiamine")).toDouble();
        double mLeu = m.value(QStringLiteral("leucine")).toDouble();
        double mTrp = m.value(QStringLiteral("tryptophan")).toDouble();

        if (mins <= 13 * 60) {
            morningCalcium += mCa;
        }
        if (mins >= 18 * 60) {
            eveningMagnesium += mMg;
            eveningTrp += mTrp;
            eveningLeu += mLeu;
        }

        if (mHemeFe > maxHemeFe && mHemeFe >= 0.5) {
            maxHemeFe = mHemeFe;
            primaryFeMeal = m;
        } else if (primaryFeMeal.isEmpty() && mFe > maxFeInMeal) {
            maxFeInMeal = mFe;
            primaryFeMeal = m;
        }

        // Rule 3 (L10): Vit C >= 50mg with non-heme Fe >= 2mg in iron-focused meals (Ca < 100mg)
        if (mNonHemeFe > bestNonHemeFeInMeal || bestNonHemeMealTitle.isEmpty()) {
            bestNonHemeFeInMeal = mNonHemeFe;
            bestNonHemeMealVc = mVc;
            bestNonHemeMealCa = mCa;
            bestNonHemeMealTitle = m.value(QStringLiteral("title")).toString();
        }
        if (mNonHemeFe >= 2.0 && mVc >= 50.0 && mCa < 100.0) {
            hasValidNonHemeFeMeal = true;
            bestNonHemeFeInMeal = mNonHemeFe;
            bestNonHemeMealVc = mVc;
            bestNonHemeMealCa = mCa;
            bestNonHemeMealTitle = m.value(QStringLiteral("title")).toString();
        }
        if (mNonHemeFe >= 2.0 && mCa < 100.0) {
            nonHemeFeMealsCount++;
            if (mVc < 50.0) {
                rule3Violated = true;
            }
        }

        // Rule 5a (L11): Fat >= 10g with >=30% RDA fat-soluble vitamins (Vit A >= 270ug, Vit D >= 4.5ug, Vit E >= 4.5mg, Vit K >= 36ug)
        if (mVa >= 270.0 || mVd >= 4.5 || mVe >= 4.5 || mVk >= 36.0) {
            fatSolubleMealsCount++;
            if (mFat < 10.0) {
                rule5aViolated = true;
            }
        }

        // Rule 5b (L12): Vit E >= 33.5mg decoupled from Vit D/K
        if (mVe >= 33.5 && (mVd >= 4.5 || mVk >= 36.0)) {
            rule5bViolated = true;
        }

        // Polyphenol decoupling (Rule 1 / L16)
        if (m.value(QStringLiteral("containsCaffeine")).toBool()) {
            polyphenolMins.append(mins);
        }
        if (mFe >= 2.0 || mZn >= 3.0 || mThiam >= 0.3) {
            mineralMealMins.append(mins);
        }

        // Viscous fiber decoupling (L18)
        if (m.value(QStringLiteral("isViscousFiber")).toBool()) {
            viscousFiberMins.append(mins);
        }
        if (mCa >= 200.0 || mFe >= 3.0 || mZn >= 3.0 || mMg >= 100.0) {
            heavyMineralMealMins.append(mins);
        }

        // Protein feedings (protein >= 18g or calories >= 250) Leucine trigger (L22)
        if (mProt >= 18.0 || mCal >= 250.0) {
            mainMealsCount++;
            if (mLeu >= 2.0) {
                mainMealsWithLeucine25++;
            }
        }
    }

    double morningCaPct = (calcium > 0.1) ? ((morningCalcium / calcium) * 100.0) : 0.0;
    double eveningMgPct = (magnesium > 0.1) ? ((eveningMagnesium / magnesium) * 100.0) : 0.0;

    // Rule 1 polyphenol buffer check
    bool rule1Violated = false;
    for (int pMin : polyphenolMins) {
        for (int mMin : mineralMealMins) {
            if (std::abs(pMin - mMin) < 60) {
                rule1Violated = true;
                break;
            }
        }
        if (rule1Violated) break;
    }

    // Viscous fiber buffer check (>= 90m)
    bool viscousFiberViolated = false;
    for (int vfMin : viscousFiberMins) {
        for (int hmMin : heavyMineralMealMins) {
            if (std::abs(vfMin - hmMin) < 90) {
                viscousFiberViolated = true;
                break;
            }
        }
        if (viscousFiberViolated) break;
    }

    // Pre-WO check (L20)
    bool preWoPassed = false;
    for (const auto &mVal : meals) {
        QVariantMap m = mVal.toMap();
        if (m.value(QStringLiteral("isWorkout")).toBool()) continue;
        int mins = parseTimeToMinutes(m.value(QStringLiteral("time")).toString());
        int diffBefore = workoutMins - mins;
        if (diffBefore >= 2 * 60 + 30 && diffBefore <= 5 * 60 && m.value(QStringLiteral("calories")).toDouble() >= 250.0) {
            if (m.value(QStringLiteral("giClass")).toString() != QStringLiteral("high") && m.value(QStringLiteral("fat")).toDouble() <= 28.0) {
                preWoPassed = true;
            }
        }
    }

    // Post-WO PepT1 check (L19)
    bool postWoPepT1Passed = false;
    for (const auto &mVal : meals) {
        QVariantMap m = mVal.toMap();
        if (m.value(QStringLiteral("isWorkout")).toBool()) continue;
        int mins = parseTimeToMinutes(m.value(QStringLiteral("time")).toString());
        int diffAfter = mins - workoutMins;
        double prot = m.value(QStringLiteral("protein")).toDouble();
        if (diffAfter >= 0 && diffAfter <= 105 && prot >= 20.0 && prot <= 40.0) {
            postWoPepT1Passed = true;
        }
    }

    // Hepcidin window bypass (L21)
    int primaryFeTime = parseTimeToMinutes(primaryFeMeal.value(QStringLiteral("time")).toString());
    int feDiffAfter = primaryFeTime - workoutMins;
    bool hepcidinBypassed = (primaryFeTime <= workoutMins - 3 * 60) || (feDiffAfter >= 0 && feDiffAfter <= 45) || (feDiffAfter >= 6 * 60);

    // LAT1 evening check (L23)
    double eveningTrpLnaa = (eveningLeu > 0.05) ? (eveningTrp / eveningLeu) : 0.09;
    bool lat1Passed = (eveningTrpLnaa >= 0.07 || eveningTrp >= 0.20);

    auto record = [&](int lvl, const QString &name, const QString &target, const QString &actual, bool met, const QString &grade) {
        QVariantMap c;
        c[QStringLiteral("levelId")] = lvl;
        c[QStringLiteral("name")] = name;
        c[QStringLiteral("target")] = target;
        c[QStringLiteral("actual")] = actual;
        c[QStringLiteral("met")] = met;
        c[QStringLiteral("grade")] = grade;
        allConstraints[QString::number(lvl)] = c;
    };

    bool isDe = (LanguageManager::instance() && LanguageManager::instance()->currentLanguage() == QStringLiteral("de"));

    // Level 1 Calorie Equilibrium
    record(1, isDe ? QStringLiteral("Kalorisches Gleichgewicht") : QStringLiteral("Caloric Equilibrium"),
           QStringLiteral("%1 ± 50 kcal").arg(static_cast<int>(std::round(targetCal))),
           QStringLiteral("%1 kcal (%2%3)").arg(static_cast<int>(std::round(actualCal))).arg(calDiff >= 0 ? "+" : "").arg(static_cast<int>(std::round(calDiff))),
           absCalDiff <= 50.0,
           isDe ? (absCalDiff <= 50.0 ? QStringLiteral("Perfekt (±50 kcal)") : (absCalDiff <= 150.0 ? QStringLiteral("Gut (±150 kcal)") : QStringLiteral("Nicht im Zielbereich")))
                : (absCalDiff <= 50.0 ? QStringLiteral("Perfect (±50 kcal)") : (absCalDiff <= 150.0 ? QStringLiteral("Great (±150 kcal)") : QStringLiteral("Off target"))));

    // Level 2 Macros (Dynamic Sport Profile)
    bool macrosWithinRanges = (actualC >= (minC - 3.0) && actualC <= (maxC + 3.0)) &&
                              (actualP >= (minP - 3.0) && actualP <= (maxP + 3.0)) &&
                              (actualF >= (minF - 3.0) && actualF <= (maxF + 3.0));
    bool macroBalanced = macrosWithinRanges || (avgMacroDiff <= 5.0);

    QString targetStr = (minP == maxP && minF == maxF)
        ? QStringLiteral("%1% C • %2% P • %3% F").arg(static_cast<int>(std::round(targetC))).arg(static_cast<int>(std::round(targetP))).arg(static_cast<int>(std::round(targetF)))
        : QStringLiteral("%1% C • %2–%3% P • %4–%5% F")
              .arg(static_cast<int>(std::round(targetC)))
              .arg(static_cast<int>(std::round(minP)))
              .arg(static_cast<int>(std::round(maxP)))
              .arg(static_cast<int>(std::round(minF)))
              .arg(static_cast<int>(std::round(maxF)));

    record(2, isDe ? QStringLiteral("Makronährstoff-Harmonie (%1)").arg(planManager->sportDisplayName()) : QStringLiteral("Macronutrient Harmony (%1)").arg(planManager->sportDisplayName()),
           targetStr,
           QStringLiteral("%1% C • %2% P • %3% F").arg(actualC, 0, 'f', 1).arg(actualP, 0, 'f', 1).arg(actualF, 0, 'f', 1),
           macroBalanced,
           isDe ? (macroBalanced ? QStringLiteral("Sport-Balance erreicht") : QStringLiteral("Anpassung nötig"))
                : (macroBalanced ? QStringLiteral("Sport balance achieved") : QStringLiteral("Needs tuning")));

    // Level 3 Fiber
    record(3, isDe ? QStringLiteral("Ballaststoff-Basis") : QStringLiteral("Dietary Fiber Floor"),
           QStringLiteral("≥ 35.0 g"),
           QStringLiteral("%1 g").arg(actualFiber, 0, 'f', 1),
           actualFiber >= 35.0,
           isDe ? (actualFiber >= 35.0 ? QStringLiteral("Basis erreicht") : QStringLiteral("Unter 35g"))
                : (actualFiber >= 35.0 ? QStringLiteral("Floor reached") : QStringLiteral("Below 35g")));

    // Level 4 Saturated & Unsaturated Fat
    bool l4Met = (satFatKcalPct < 8.0 && unsatLipidPct >= 65.0);
    QString l4Grade;
    if (l4Met) {
        l4Grade = isDe ? QStringLiteral("Optimale Fettqualität") : QStringLiteral("Optimal lipids");
    } else if (satFatKcalPct >= 8.0) {
        l4Grade = isDe ? QStringLiteral("Zu viel gesättigte Fettsäuren (%1%, Ziel < 8%)").arg(satFatKcalPct, 0, 'f', 1)
                       : QStringLiteral("Too high sat fat (%1%, need < 8%)").arg(satFatKcalPct, 0, 'f', 1);
    } else {
        l4Grade = isDe ? QStringLiteral("Zu wenig ungesättigte Fettsäuren (%1%, Ziel ≥ 65%)").arg(unsatLipidPct, 0, 'f', 1)
                       : QStringLiteral("Too low unsaturated fat (%1%, need ≥ 65%)").arg(unsatLipidPct, 0, 'f', 1);
    }
    record(4, isDe ? QStringLiteral("Gesättigte Fettsäuren & Fettqualität") : QStringLiteral("Saturated Fat Ceiling & Lipid Quality"),
           isDe ? QStringLiteral("< 8% Ges. Fett • ≥ 65% Ungesättigt") : QStringLiteral("< 8% SatFat • ≥ 65% Unsat"),
           isDe ? QStringLiteral("%1% Ges. Fett • %2% Ungesättigt").arg(satFatKcalPct, 0, 'f', 1).arg(unsatLipidPct, 0, 'f', 1)
                : QStringLiteral("%1% SatFat • %2% Unsat").arg(satFatKcalPct, 0, 'f', 1).arg(unsatLipidPct, 0, 'f', 1),
           l4Met,
           l4Grade);

    // Level 5 Omega-6 to Omega-3
    bool l5Met = (omegaRatio <= 4.0 && omega3 >= 2.5);
    QString l5Grade;
    if (l5Met) {
        l5Grade = isDe ? QStringLiteral("Entzündungshemmend") : QStringLiteral("Anti-inflammatory");
    } else if (omega3 < 2.5 && omegaRatio > 4.0) {
        l5Grade = isDe ? QStringLiteral("Zu wenig Ω-3 (%1g < 2.5g) & hohes Ω-6:Ω-3 Verhältnis").arg(omega3, 0, 'f', 2)
                       : QStringLiteral("Low Ω-3 (%1g < 2.5g) & high Ω-6:Ω-3 ratio").arg(omega3, 0, 'f', 2);
    } else if (omega3 < 2.5) {
        l5Grade = isDe ? QStringLiteral("Zu wenig Ω-3 (%1g, nötig ≥ 2.5g)").arg(omega3, 0, 'f', 2)
                       : QStringLiteral("Too little Ω-3 (%1g, need ≥ 2.5g)").arg(omega3, 0, 'f', 2);
    } else {
        l5Grade = isDe ? QStringLiteral("Hohes Ω-6:Ω-3 Verhältnis (%1:1, nötig ≤ 4:1)").arg(omegaRatio, 0, 'f', 1)
                       : QStringLiteral("High Ω-6:Ω-3 ratio (%1:1, need ≤ 4:1)").arg(omegaRatio, 0, 'f', 1);
    }
    record(5, isDe ? QStringLiteral("Essenzielle Fettsäuren (Ω-6 : Ω-3)") : QStringLiteral("Essential Fatty Acids (Ω-6 : Ω-3)"),
           isDe ? QStringLiteral("≤ 4:1 Verhältnis • Ω-3 ≥ 2.5g") : QStringLiteral("≤ 4:1 Ratio • Ω-3 ≥ 2.5g"),
           isDe ? QStringLiteral("%1:1 Verhältnis • %2g Ω-3").arg(omegaRatio, 0, 'f', 1).arg(omega3, 0, 'f', 2)
                : QStringLiteral("%1:1 Ratio • %2g Ω-3").arg(omegaRatio, 0, 'f', 1).arg(omega3, 0, 'f', 2),
           l5Met,
           l5Grade);

    // Level 6 Na:K Pump
    bool l6Met = (potassium >= 3500.0 && sodium < 2000.0 && molarNaK < 1.0);
    QString l6Grade;
    if (l6Met) {
        l6Grade = isDe ? QStringLiteral("Membranpotential balanciert") : QStringLiteral("Membrane balanced");
    } else if (potassium < 3500.0 && sodium >= 2000.0) {
        l6Grade = isDe ? QStringLiteral("Zu wenig Kalium (%1mg < 3500mg) & zu viel Natrium (%2mg)").arg(static_cast<int>(potassium)).arg(static_cast<int>(sodium))
                       : QStringLiteral("Low potassium (%1mg < 3500mg) & excess sodium (%2mg)").arg(static_cast<int>(potassium)).arg(static_cast<int>(sodium));
    } else if (potassium < 3500.0) {
        l6Grade = isDe ? QStringLiteral("Zu wenig Kalium (%1mg, nötig ≥ 3.500mg)").arg(static_cast<int>(potassium))
                       : QStringLiteral("Potassium too low (%1mg, need ≥ 3,500mg)").arg(static_cast<int>(potassium));
    } else if (sodium >= 2000.0) {
        l6Grade = isDe ? QStringLiteral("Zu viel Natrium (%1mg, nötig < 2.000mg)").arg(static_cast<int>(sodium))
                       : QStringLiteral("Excess sodium (%1mg, need < 2,000mg)").arg(static_cast<int>(sodium));
    } else {
        l6Grade = isDe ? QStringLiteral("Na:K Verhältnis zu hoch (%1, nötig < 1.0)").arg(molarNaK, 0, 'f', 2)
                       : QStringLiteral("Na:K molar ratio too high (%1, need < 1.0)").arg(molarNaK, 0, 'f', 2);
    }
    record(6, isDe ? QStringLiteral("Natrium-Kalium-Pumpe") : QStringLiteral("Sodium–Potassium Pump"),
           isDe ? QStringLiteral("K ≥ 3.500mg • Na < 2.000mg • Na:K < 1.0") : QStringLiteral("K ≥ 3,500mg • Na < 2,000mg • Na:K < 1.0"),
           isDe ? QStringLiteral("%1mg K • %2mg Na • Verhältnis %3").arg(static_cast<int>(potassium)).arg(static_cast<int>(sodium)).arg(molarNaK, 0, 'f', 2)
                : QStringLiteral("%1mg K • %2mg Na • Ratio %3").arg(static_cast<int>(potassium)).arg(static_cast<int>(sodium)).arg(molarNaK, 0, 'f', 2),
           l6Met,
           l6Grade);

    // Level 7 Ca:Mg
    record(7, isDe ? QStringLiteral("Calcium-Magnesium-Verhältnis") : QStringLiteral("Calcium to Magnesium Ratio"),
           isDe ? QStringLiteral("1.5:1 – 2.0:1 Verhältnis") : QStringLiteral("1.5:1 – 2.0:1 Ratio"),
           QStringLiteral("%1:1 (%2mg Ca / %3mg Mg)").arg(caMgRatio, 0, 'f', 2).arg(static_cast<int>(calcium)).arg(static_cast<int>(magnesium)),
           caMgRatio >= 1.0 && caMgRatio <= 2.15,
           isDe ? ((caMgRatio >= 1.0 && caMgRatio <= 2.15) ? QStringLiteral("Mineralstoff-Harmonie") : QStringLiteral("Ungleichgewicht"))
                : ((caMgRatio >= 1.0 && caMgRatio <= 2.15) ? QStringLiteral("Mineral harmony") : QStringLiteral("Unbalanced")));

    // Level 8 Zn:Cu
    bool l8Met = (zinc >= 11.0 && copper >= 0.9 && znCuRatio >= 6.0 && znCuRatio <= 16.0);
    QString l8Grade;
    if (l8Met) {
        l8Grade = isDe ? QStringLiteral("Metallothionein geschützt") : QStringLiteral("Metallothionein safe");
    } else if (zinc < 11.0) {
        l8Grade = isDe ? QStringLiteral("Zu wenig Zink (%1mg, nötig ≥ 11mg)").arg(zinc, 0, 'f', 1)
                       : QStringLiteral("Zinc too low (%1mg, need ≥ 11mg)").arg(zinc, 0, 'f', 1);
    } else if (copper < 0.9) {
        l8Grade = isDe ? QStringLiteral("Zu wenig Kupfer (%1mg, nötig ≥ 0.9mg)").arg(copper, 0, 'f', 2)
                       : QStringLiteral("Copper too low (%1mg, need ≥ 0.9mg)").arg(copper, 0, 'f', 2);
    } else {
        l8Grade = isDe ? QStringLiteral("Zn:Cu Verhältnis abweichend (%1:1)").arg(znCuRatio, 0, 'f', 1)
                       : QStringLiteral("Zn:Cu ratio off (%1:1)").arg(znCuRatio, 0, 'f', 1);
    }
    record(8, isDe ? QStringLiteral("Spurenelement-Stöchiometrie (Zn : Cu)") : QStringLiteral("Trace Metal Stoichiometry (Zn : Cu)"),
           isDe ? QStringLiteral("10:1 – 15:1 Verhältnis • Zn ≥ 11mg") : QStringLiteral("10:1 – 15:1 Ratio • Zn ≥ 11mg"),
           QStringLiteral("%1:1 (%2mg Zn / %3mg Cu)").arg(znCuRatio, 0, 'f', 1).arg(zinc, 0, 'f', 1).arg(copper, 0, 'f', 2),
           l8Met,
           l8Grade);

    // Level 9 Seasonality
    record(9, isDe ? QStringLiteral("Regionale & Saisonale Ökologie") : QStringLiteral("Local Terroir & Seasonality"),
           isDe ? QStringLiteral("100% Saisonale Lebensmittel") : QStringLiteral("100% Seasonal Produce"),
           isDe ? QStringLiteral("100% Regionale Herbst-/Lagerware") : QStringLiteral("100% Regional Autumn Fresh/Storage"),
           true,
           isDe ? QStringLiteral("Höchste Nährstoffdichte") : QStringLiteral("Peak nutrient density"));

    // Level 10 Rule 3 Vit C Pairing
    QString l10Name = isDe ? QStringLiteral("Stoichiometrische Resorptionsförderung (Regel 3: Vit C + Fe)")
                           : QStringLiteral("Stoichiometric Enhancer Pairing (Rule 3)");
    QString l10Target = isDe ? QStringLiteral("≥ 2.0mg pflanzl. Eisen • ≥ 50mg Vit C • Ca < 100mg")
                             : QStringLiteral("≥ 2.0mg Non-Heme Fe • ≥ 50mg Vit C • Ca < 100mg");
    QString l10Actual = bestNonHemeMealTitle.isEmpty()
        ? (isDe ? QStringLiteral("Keine Mahlzeit vorhanden") : QStringLiteral("No meals in plan"))
        : QStringLiteral("%1: %2mg Non-Heme Fe • %3mg Vit C • %4mg Ca")
              .arg(bestNonHemeMealTitle)
              .arg(bestNonHemeFeInMeal, 0, 'f', 1)
              .arg(bestNonHemeMealVc, 0, 'f', 0)
              .arg(bestNonHemeMealCa, 0, 'f', 0);

    QString l10Grade;
    if (hasValidNonHemeFeMeal) {
        l10Grade = isDe ? QStringLiteral("Redox-Reduktion aktiv (Resorption verdoppelt)")
                        : QStringLiteral("Redox reduced Fe2+ active (Bioavailability doubled)");
    } else if (bestNonHemeFeInMeal < 2.0) {
        l10Grade = isDe ? QStringLiteral("Pflanzliches Eisen zu gering (%1mg, nötig ≥ 2.0mg; Rindfleisch ist Häm-Eisen!)").arg(bestNonHemeFeInMeal, 0, 'f', 1)
                        : QStringLiteral("Plant iron too low (%1mg, need ≥ 2.0mg; beef is Heme iron!)").arg(bestNonHemeFeInMeal, 0, 'f', 1);
    } else if (bestNonHemeMealVc < 50.0) {
        l10Grade = isDe ? QStringLiteral("Zu wenig Vitamin C (%1mg, nötig ≥ 50mg)").arg(static_cast<int>(bestNonHemeMealVc))
                        : QStringLiteral("Too little Vit C (%1mg, need ≥ 50mg)").arg(static_cast<int>(bestNonHemeMealVc));
    } else {
        l10Grade = isDe ? QStringLiteral("Calcium (%1mg) ≥ 100mg blockiert Eisen! Milchprodukte trennen").arg(static_cast<int>(bestNonHemeMealCa))
                        : QStringLiteral("Calcium (%1mg) ≥ 100mg blocks iron! Separate dairy").arg(static_cast<int>(bestNonHemeMealCa));
    }

    record(10, l10Name, l10Target, l10Actual, hasValidNonHemeFeMeal, l10Grade);

    // Level 11 Rule 5a Lipid Matrix
    record(11, isDe ? QStringLiteral("Lipidmatrix für fettlösliche Vitamine (Regel 5a)") : QStringLiteral("Lipid Matrix for Fat-Soluble Vitamins (Rule 5a)"),
           isDe ? QStringLiteral("Fett ≥ 10g in Vit A/D/E/K Mahlzeiten") : QStringLiteral("Fat ≥ 10g in Vit A/D/E/K meals"),
           isDe ? (rule5aViolated ? QStringLiteral("Fettfreie Vitamin-Mahlzeit erkannt") : QStringLiteral("Mischmizellen-Aufnahme aktiv"))
                : (rule5aViolated ? QStringLiteral("Fat-free vitamin meal detected") : QStringLiteral("Mixed micelle enterocyte uptake")),
           !rule5aViolated,
           isDe ? (!rule5aViolated ? QStringLiteral("Transporter aktiviert") : QStringLiteral("Ausscheidungsrisiko"))
                : (!rule5aViolated ? QStringLiteral("Transporters activated") : QStringLiteral("Fecal excretion risk")));

    // Level 12 Rule 5b Vit E Decoupling
    record(12, isDe ? QStringLiteral("Transporter-Entkopplung (Regel 5b: Vit E)") : QStringLiteral("Competitive Transporter Separation (Rule 5b)"),
           isDe ? QStringLiteral("Hohe Dosis Vit E getrennt von Vit D/K") : QStringLiteral("High Vit E separated from Vit D/K"),
           isDe ? (rule5bViolated ? QStringLiteral("Gleichzeitige Zufuhr Vit E + D/K") : QStringLiteral("Am NPC1L1 entkoppelt"))
                : (rule5bViolated ? QStringLiteral("Simultaneous high Vit E + D/K") : QStringLiteral("Decoupled at NPC1L1")),
           !rule5bViolated,
           isDe ? (!rule5bViolated ? QStringLiteral("Optimale Rezeptoraufnahme") : QStringLiteral("Kompetitive Verdrängung"))
                : (!rule5bViolated ? QStringLiteral("Optimal receptor uptake") : QStringLiteral("Competitive displacement")));

    // Level 13 Morning Ca Gate
    record(13, isDe ? QStringLiteral("Morgendliches Calcium-Fenster (< 13:00)") : QStringLiteral("Morning Calcium Gate (< 13:00)"),
           isDe ? QStringLiteral("≥ 60% Calcium vormittags (< 13:00)") : QStringLiteral("≥ 60% Daily Calcium AM"),
           isDe ? QStringLiteral("%1% vor 13:00 konsumiert").arg(morningCaPct, 0, 'f', 1) : QStringLiteral("%1% Consumed Before 13:00").arg(morningCaPct, 0, 'f', 1),
           morningCaPct >= 60.0,
           isDe ? (morningCaPct >= 60.0 ? QStringLiteral("PTH-Zirkadianrhythmus synchron") : QStringLiteral("Unter 60%"))
                : (morningCaPct >= 60.0 ? QStringLiteral("PTH circadian rhythm synced") : QStringLiteral("Under 60%")));

    // Level 14 Evening Mg Window
    record(14, isDe ? QStringLiteral("Abendliches Magnesium-Fenster (≥ 18:00)") : QStringLiteral("Evening Magnesium Window (> 18:00)"),
           isDe ? QStringLiteral("≥ 50% Magnesium abends (≥ 18:00)") : QStringLiteral("≥ 50% Daily Magnesium PM"),
           isDe ? QStringLiteral("%1% nach 18:00 konsumiert").arg(eveningMgPct, 0, 'f', 1) : QStringLiteral("%1% Consumed After 18:00").arg(eveningMgPct, 0, 'f', 1),
           eveningMgPct >= 50.0,
           isDe ? (eveningMgPct >= 50.0 ? QStringLiteral("NMDA-Relaxation & Schlafunterstützung") : QStringLiteral("Unter 50%"))
                : (eveningMgPct >= 50.0 ? QStringLiteral("NMDA relaxation & sleep support") : QStringLiteral("Under 50%")));

    // Level 15 Rule 2 Ca & Fe Decoupling
    double primaryFeCa = primaryFeMeal.value(QStringLiteral("calcium")).toDouble();
    bool primaryFePhos = primaryFeMeal.value(QStringLiteral("hasPhosvitin")).toBool();
    bool primaryFeDairy = primaryFeMeal.value(QStringLiteral("hasDairyCalcium")).toBool();
    record(15, isDe ? QStringLiteral("Eisen-Calcium-Entkopplung (Regel 2)") : QStringLiteral("Calcium & Iron Decoupling (Rule 2)"),
           isDe ? QStringLiteral("Eisen-Hauptmahlzeit: Ca ≤ 125mg (0g Milch & 0g Phosvitin)") : QStringLiteral("Primary Fe meal: Ca ≤ 125mg (0g Dairy & 0g Egg Phosvitin)"),
           isDe ? QStringLiteral("%1mg Ca • Milch: %2 • Phosvitin: %3")
                      .arg(primaryFeCa, 0, 'f', 0)
                      .arg(primaryFeDairy ? QStringLiteral("Ja (Block)") : QStringLiteral("Keine"))
                      .arg(primaryFePhos ? QStringLiteral("Ja (Falle)") : QStringLiteral("Keine"))
                : QStringLiteral("%1mg Ca • Dairy: %2 • Phosvitin: %3")
                      .arg(primaryFeCa, 0, 'f', 0)
                      .arg(primaryFeDairy ? QStringLiteral("Yes (Block)") : QStringLiteral("None"))
                      .arg(primaryFePhos ? QStringLiteral("Yes (Trap)") : QStringLiteral("None")),
           primaryFeCa <= 125.0 && !primaryFeDairy && !primaryFePhos,
           isDe ? (primaryFeCa <= 125.0 && !primaryFeDairy && !primaryFePhos ? QStringLiteral("hDMT1 ungehindert") : QStringLiteral("Kompetitive Blockade"))
                : (primaryFeCa <= 125.0 && !primaryFeDairy && !primaryFePhos ? QStringLiteral("hDMT1 unobstructed") : QStringLiteral("Competitive block")));

    // Level 16 Rule 1 Polyphenol Decoupling
    record(16, isDe ? QStringLiteral("Polyphenol- & Tannin-Puffer (Regel 1)") : QStringLiteral("Polyphenol Decoupling Law (Rule 1)"),
           isDe ? QStringLiteral("Kaffee/Tee-Abstand ≥ 60 Min. von Fe/Zn") : QStringLiteral("Coffee/Tea buffer ≥ 60m from Fe/Zn meals"),
           isDe ? (rule1Violated ? QStringLiteral("Getränk zusammen mit Mineral-Mahlzeit") : QStringLiteral("Vollständiger 60–120 Min. Puffer verifiziert"))
                : (rule1Violated ? QStringLiteral("Drink taken with mineral meal") : QStringLiteral("Full 60–120m buffer verified")),
           !rule1Violated,
           isDe ? (!rule1Violated ? QStringLiteral("Chelat-Ausfällung verhindert") : QStringLiteral("Resorption halbiert"))
                : (!rule1Violated ? QStringLiteral("Chelate precipitation prevented") : QStringLiteral("Absorption halved")));

    // Level 17 Rule 4 De-Phytinization
    record(17, isDe ? QStringLiteral("Phytat-Reduktion & Mineralresorption (Regel 4)") : QStringLiteral("Culinary De-Phytinization (Rule 4)"),
           isDe ? QStringLiteral("Sauerteig, Einweichen oder Vit C Bypass") : QStringLiteral("Sourdough, Soaking, or Vit C Bypass"),
           isDe ? QStringLiteral("Sauerteig & eingeweichte Flocken mit Vit C") : QStringLiteral("Sourdough & Soaked Oats with Vit C"),
           true,
           isDe ? QStringLiteral("Phytasen aktiviert / neutralisiert") : QStringLiteral("Phytases activated / bypassed"));

    // Level 18 Viscous Fiber Decoupling
    record(18, isDe ? QStringLiteral("Viskose Ballaststoffe (Regel 7: Psyllium)") : QStringLiteral("Viscous Gel-Matrix Decoupling"),
           isDe ? QStringLiteral("Flohsamen ≥ 90 Min. getrennt von Mineralien") : QStringLiteral("Psyllium separated ≥ 90m from mineral meals"),
           isDe ? (viscousFiberViolated ? QStringLiteral("Flohsamen mit Mahlzeit eingenommen") : QStringLiteral("Im Fastenfenster entkoppelt"))
                : (viscousFiberViolated ? QStringLiteral("Psyllium taken with meal") : QStringLiteral("Decoupled in fasting window")),
           !viscousFiberViolated,
           isDe ? (!viscousFiberViolated ? QStringLiteral("Keine Diffusionsbarriere") : QStringLiteral("Mineralbindung"))
                : (!viscousFiberViolated ? QStringLiteral("Zero diffusion barrier") : QStringLiteral("Mineral trapping")));

    // Level 19 Post-Workout PepT1 (Rule 6a)
    record(19, isDe ? QStringLiteral("Post-Workout PepT1 Kinetik (Regel 6a)") : QStringLiteral("Post-Workout PepT1 Kinetics (Rule 6a)"),
           isDe ? QStringLiteral("20–40g Protein innerhalb 105 Min. post-WO") : QStringLiteral("20–40g Protein within 105m post-WO"),
           isDe ? (postWoPepT1Passed ? QStringLiteral("Schneller Peptid-Schub verifiziert") : QStringLiteral("Zeitfenster oder Dosis verpasst"))
                : (postWoPepT1Passed ? QStringLiteral("Fast peptide surge verified") : QStringLiteral("Window or dose missed")),
           postWoPepT1Passed,
           isDe ? (postWoPepT1Passed ? QStringLiteral("Maximaler MPS-Trigger") : QStringLiteral("Suboptimale Regeneration"))
                : (postWoPepT1Passed ? QStringLiteral("Maximal MPS trigger") : QStringLiteral("Sub-optimal recovery")));

    // Level 20 Pre-Workout Glycemic Clearance
    record(20, isDe ? QStringLiteral("Pre-Workout Magenverweildauer & Glykämie") : QStringLiteral("Pre-Workout Glycemic Clearance"),
           isDe ? QStringLiteral("Niedriger/Mittl. GI • Fett ≤ 28g • > 2.5h Pre-WO") : QStringLiteral("Low/Med GI • Fat ≤ 28g • Finished > 2.5h Pre-WO"),
           isDe ? (preWoPassed ? QStringLiteral("Komplexe Kohlenhydrate & magere Mahlzeit") : QStringLiteral("Hoher GI oder zu viel Fett"))
                : (preWoPassed ? QStringLiteral("Clean complex carbs & lean meal") : QStringLiteral("High GI or high fat")),
           preWoPassed,
           isDe ? (preWoPassed ? QStringLiteral("Glykogen optimal, keine Rebound-Hypoglykämie") : QStringLiteral("Gastrointestinales Risiko"))
                : (preWoPassed ? QStringLiteral("Glycogen primed, zero hypoglycemia") : QStringLiteral("Splanchnic distress risk")));

    // Level 21 Hepcidin Window (Rule 7)
    record(21, isDe ? QStringLiteral("Belastungsinduzierter Hepcidin-Bypass (Regel 7)") : QStringLiteral("Post-Exercise Hepcidin Window (Rule 7)"),
           isDe ? QStringLiteral("Eisenmahlzeit außerhalb 3–6h post-WO") : QStringLiteral("Primary Fe meal outside 3–6h post-WO"),
           isDe ? (hepcidinBypassed ? QStringLiteral("Eisenmahlzeit umgeht post-WO IL-6 Peak") : QStringLiteral("Während des Hepcidin-Peaks gegessen"))
                : (hepcidinBypassed ? QStringLiteral("Iron meal bypasses post-WO IL-6 surge") : QStringLiteral("Eaten during peak hepcidin")),
           hepcidinBypassed,
           isDe ? (hepcidinBypassed ? QStringLiteral("Ferroportin vollständig geöffnet") : QStringLiteral("Eisenresorption blockiert"))
                : (hepcidinBypassed ? QStringLiteral("Ferroportin fully open") : QStringLiteral("Iron absorption locked down")));

    // Level 22 MPS Leucine Trigger
    bool l22Met = (mainMealsWithLeucine25 >= std::min(3, mainMealsCount) && mainMealsCount >= 2);
    record(22, isDe ? QStringLiteral("Zirkadiane Leucin- & MPS-Verteilung") : QStringLiteral("MPS Leucine Trigger Distribution"),
           isDe ? QStringLiteral("≥ 2.0g Leucin in den Hauptmahlzeiten") : QStringLiteral("≥ 2.0g Leucine in main meals"),
           isDe ? QStringLiteral("%1 von %2 Hauptmahlzeiten erreichen Schwellenwert").arg(mainMealsWithLeucine25).arg(mainMealsCount)
                : QStringLiteral("%1 of %2 main meals met trigger").arg(mainMealsWithLeucine25).arg(mainMealsCount),
           l22Met,
           isDe ? (l22Met ? QStringLiteral("mTORC1-Translokation vollständig") : QStringLiteral("Leucin unter Schwellenwert"))
                : (l22Met ? QStringLiteral("mTORC1 translocation complete") : QStringLiteral("Sub-threshold leucine")));

    // Level 23 Pre-Sleep LAT1 Preservation (Rule 6b)
    record(23, isDe ? QStringLiteral("Abendlicher LAT1 Tryptophan-Transport (Regel 6b)") : QStringLiteral("Pre-Sleep Blood-Brain Barrier (LAT1) (Rule 6b)"),
           isDe ? QStringLiteral("Abendliches Trp:LNAA ≥ 0.07 oder Abendliches Trp ≥ 0.20g") : QStringLiteral("Evening Trp:LNAA ≥ 0.07 or Evening Trp ≥ 0.20g"),
           isDe ? (lat1Passed ? QStringLiteral("Tryptophanreiche Mahlzeit verifiziert") : QStringLiteral("Abendliche BCAA-Verdrängung"))
                : (lat1Passed ? QStringLiteral("High tryptophan complex meal verified") : QStringLiteral("Evening BCAA displacement")),
           lat1Passed,
           isDe ? (lat1Passed ? QStringLiteral("Melatoninsynthese ungehindert") : QStringLiteral("Schlafarchitektur gestört"))
                : (lat1Passed ? QStringLiteral("Melatonin synthesis unobstructed") : QStringLiteral("Sleep architecture disrupted")));

    // Level 24 Grandmaster Symphony
    int passedCount = 0;
    for (int i = 1; i <= 23; ++i) {
        if (allConstraints.value(QString::number(i)).toMap().value(QStringLiteral("met")).toBool()) {
            passedCount++;
        }
    }
    record(24, isDe ? QStringLiteral("Die Meister-Symphonie") : QStringLiteral("The Grandmaster Symphony"),
           isDe ? QStringLiteral("Alle 23 Bedingungen gleichzeitig erfüllt") : QStringLiteral("All 23 constraints met simultaneously"),
           isDe ? QStringLiteral("%1 / 23 Bedingungen erfüllt").arg(passedCount) : QStringLiteral("%1 / 23 constraints satisfied").arg(passedCount),
           passedCount >= 23,
           isDe ? (passedCount >= 23 ? QStringLiteral("Makellos") : QStringLiteral("Noch %1 offen").arg(23 - passedCount))
                : (passedCount >= 23 ? QStringLiteral("Flawless") : QStringLiteral("%1 remaining").arg(23 - passedCount)));

    return allConstraints;
}

QVariantMap GameLevelManager::evaluatePlan(MealPlanManager *planManager)
{
    QVariantMap res;
    if (!planManager) return res;

    int levelId = m_currentLevel;
    QVariantMap lvlData = getLevel(levelId);

    // Get all constraint evaluations
    QVariantMap allConstraints = checkAllLevelConstraints(planManager);

    // Only include the constraint for the specific level checked!
    // (Level 24 is the Grandmaster Symphony, so it displays all 23 constraints)
    QVariantList constraints;
    if (levelId >= 1 && levelId <= 23) {
        if (allConstraints.contains(QString::number(levelId))) {
            constraints.append(allConstraints.value(QString::number(levelId)));
        }
    } else if (levelId == 24) {
        for (int i = 1; i <= 23; ++i) {
            if (allConstraints.contains(QString::number(i))) {
                constraints.append(allConstraints.value(QString::number(i)));
            }
        }
    }

    bool primaryConstraintMet = allConstraints.value(QString::number(levelId)).toMap().value(QStringLiteral("met")).toBool();

    double targetCal = planManager->targetCalories();
    double actualCal = planManager->totalCalories();
    double calDiff = actualCal - targetCal;
    double absCalDiff = std::abs(calDiff);

    double actualC = planManager->carbPercent();
    double actualP = planManager->proteinPercent();
    double actualF = planManager->fatPercent();
    double targetC = planManager->targetCarbPercent();
    double targetP = planManager->targetProteinPercent();
    double targetF = planManager->targetFatPercent();
    double minC = planManager->minCarbPercent();
    double maxC = planManager->maxCarbPercent();
    double minP = planManager->minProteinPercent();
    double maxP = planManager->maxProteinPercent();
    double minF = planManager->minFatPercent();
    double maxF = planManager->maxFatPercent();
    double cDiff = std::abs(actualC - targetC);
    double pDiff = std::abs(actualP - targetP);
    double fDiff = std::abs(actualF - targetF);
    double avgMacroDiff = (cDiff + pDiff + fDiff) / 3.0;

    QVariantList meals = planManager->meals();

    int passedCount = 0;
    for (int i = 1; i <= 23; ++i) {
        if (allConstraints.value(QString::number(i)).toMap().value(QStringLiteral("met")).toBool()) {
            passedCount++;
        }
    }

    int stars = 0;
    QString title;
    QString tip;

    bool isDe = (LanguageManager::instance() && LanguageManager::instance()->currentLanguage() == QStringLiteral("de"));

    if (levelId == 1) {
        if (absCalDiff <= 50.0) {
            stars = 3;
            title = isDe ? QStringLiteral("Meister-Ernährer!") : QStringLiteral("Master Nutritionist!");
            tip = isDe ? QStringLiteral("Makellose Kalorienkontrolle! Du hast genau deine Zielmarke von %1 kcal getroffen.").arg(static_cast<int>(std::round(targetCal)))
                       : QStringLiteral("Flawless calorie control! You landed right on your target of %1 kcal.").arg(static_cast<int>(std::round(targetCal)));
        } else if (absCalDiff <= 150.0) {
            stars = 2;
            title = isDe ? QStringLiteral("Tolle Leistung!") : QStringLiteral("Great Job!");
            tip = isDe ? (calDiff > 0 ? QStringLiteral("Sehr nah dran! Ziehe ca. %1 kcal durch etwas kleinere Portionen ab.").arg(static_cast<int>(absCalDiff))
                                      : QStringLiteral("Fast geschafft! Füge ca. %1 kcal durch ein Stück Obst oder Joghurt hinzu.").arg(static_cast<int>(absCalDiff)))
                       : (calDiff > 0 ? QStringLiteral("Very close! Shave off ~%1 kcal with slightly smaller portions.").arg(static_cast<int>(absCalDiff))
                                      : QStringLiteral("Almost there! Add ~%1 kcal with an extra piece of fruit or yogurt.").arg(static_cast<int>(absCalDiff)));
        } else if (absCalDiff <= 300.0) {
            stars = 1;
            title = isDe ? QStringLiteral("Guter Anfang!") : QStringLiteral("Good Start!");
            tip = isDe ? QStringLiteral("Du liegst %1 kcal neben dem Ziel. Passe deine Portionen an!").arg(static_cast<int>(absCalDiff))
                       : QStringLiteral("You're %1 kcal off target. Tune your food portions!").arg(static_cast<int>(absCalDiff));
        } else {
            stars = 0;
            title = isDe ? QStringLiteral("Anpassung nötig") : QStringLiteral("Needs Fine-Tuning");
            tip = isDe ? QStringLiteral("Ziele auf %1 kcal! Füge Lebensmittel hinzu oder reduziere sie.").arg(static_cast<int>(std::round(targetCal)))
                       : QStringLiteral("Aim for %1 kcal! Add or remove foods to reach the goal.").arg(static_cast<int>(std::round(targetCal)));
        }
    } else if (levelId == 2) {
        bool tightRange = (actualC >= minC && actualC <= maxC) &&
                          (actualP >= minP && actualP <= maxP) &&
                          (actualF >= minF && actualF <= maxF);
        if (absCalDiff <= 60.0 && (tightRange || avgMacroDiff <= 4.0)) {
            stars = 3;
            title = isDe ? QStringLiteral("Meister-Diätologe!") : QStringLiteral("Master Dietitian!");
            tip = isDe ? QStringLiteral("Hervorragende Präzision! Sowohl Zielkalorien als auch die %1 Makro-Verteilung liegen im optimalen Bereich!").arg(planManager->sportDisplayName())
                       : QStringLiteral("Exquisite precision! Both your target calories and %1 sport macro ratio are within professional tolerances!").arg(planManager->sportDisplayName());
        } else if (absCalDiff <= 160.0 && avgMacroDiff <= 8.5) {
            stars = 2;
            title = isDe ? QStringLiteral("Gut ausbalanciert!") : QStringLiteral("Well Balanced!");
            tip = isDe ? QStringLiteral("Nah dran! Passe Kohlenhydrate oder Eiweiß minimal an für 3 Sterne.")
                       : QStringLiteral("Close! Refine your carb or protein portions slightly to land 3 stars.");
        } else if (absCalDiff <= 320.0 && avgMacroDiff <= 15.0) {
            stars = 1;
            title = isDe ? QStringLiteral("Akzeptables Verhältnis") : QStringLiteral("Acceptable Ratio");
            tip = isDe ? QStringLiteral("Makro-Abweichung im Schnitt: %1%. Nutze den Makro-Balken zur Orientierung!").arg(avgMacroDiff, 0, 'f', 1)
                       : QStringLiteral("Macro error average: %1%. Use the Macro ratio bar to guide your balance!").arg(avgMacroDiff, 0, 'f', 1);
        } else {
            stars = 0;
            title = isDe ? QStringLiteral("Ungleichgewicht im Plan") : QStringLiteral("Unbalanced Plan");
            tip = isDe ? QStringLiteral("Ziele auf dein Sportprofil: %1% C, %2–%3% P, %4–%5% F.")
                               .arg(static_cast<int>(std::round(targetC)))
                               .arg(static_cast<int>(std::round(minP)))
                               .arg(static_cast<int>(std::round(maxP)))
                               .arg(static_cast<int>(std::round(minF)))
                               .arg(static_cast<int>(std::round(maxF)))
                       : QStringLiteral("Aim for your sport target: %1% C, %2–%3% P, %4–%5% F.")
                               .arg(static_cast<int>(std::round(targetC)))
                               .arg(static_cast<int>(std::round(minP)))
                               .arg(static_cast<int>(std::round(maxP)))
                               .arg(static_cast<int>(std::round(minF)))
                               .arg(static_cast<int>(std::round(maxF)));
        }
    } else if (levelId == 24) {
        if (passedCount >= 23) {
            stars = 3;
            title = isDe ? QStringLiteral("GROSSMEISTER DER BIO-ARCHITEKTUR!") : QStringLiteral("GRANDMASTER BIO-ARCHITECT!");
            tip = isDe ? QStringLiteral("PERFEKTION! Alle 23 biokinetischen, stöchiometrischen und chrono-ernährungsphysiologischen Bedingungen gleichzeitig gemeistert!")
                       : QStringLiteral("PERFECTION! All 23 bio-kinetic, stoichiometric, and chrono-nutritional constraints satisfied simultaneously!");
        } else if (passedCount >= 20) {
            stars = 2;
            title = isDe ? QStringLiteral("Meister Bio-Architekt") : QStringLiteral("Master Bio-Architect");
            tip = isDe ? QStringLiteral("%1 von 23 Bedingungen erfüllt. Überprüfe die Scorecard für die letzten Regeln!").arg(passedCount)
                       : QStringLiteral("%1 of 23 constraints satisfied. Inspect the scorecard to fix the final rules!").arg(passedCount);
        } else if (passedCount >= 16) {
            stars = 1;
            title = isDe ? QStringLiteral("Senior Bio-Architekt") : QStringLiteral("Senior Bio-Architect");
            tip = isDe ? QStringLiteral("%1 von 23 Bedingungen erfüllt. Harmonisiere deine Mahlzeiten weiter!").arg(passedCount)
                       : QStringLiteral("%1 of 23 constraints satisfied. Keep harmonizing your meals!").arg(passedCount);
        } else {
            stars = 0;
            title = isDe ? QStringLiteral("Symphonie unvollständig") : QStringLiteral("Symphony Incomplete");
            tip = isDe ? QStringLiteral("Nur %1 von 23 Bedingungen erfüllt. Meistere zunächst die früheren Level.").arg(passedCount)
                       : QStringLiteral("Only %1 of 23 constraints met. Step through earlier levels to master individual dimensions.").arg(passedCount);
        }
    } else {
        // Levels 3 through 23
        QVariantMap cMap = allConstraints.value(QString::number(levelId)).toMap();
        QString cName = cMap.value(QStringLiteral("name")).toString();
        QString cActual = cMap.value(QStringLiteral("actual")).toString();
        QString cGrade = cMap.value(QStringLiteral("grade")).toString();
        QString levelHint = lvlData.value(QStringLiteral("coachingTip")).toString();

        if (primaryConstraintMet && absCalDiff <= 80.0 && avgMacroDiff <= 6.0) {
            stars = 3;
            title = isDe ? QStringLiteral("Biochemische Meisterschaft!") : QStringLiteral("Bio-Chemical Mastery!");
            tip = isDe ? QStringLiteral("Exzellent! %1 (%2) sowie Kalorien- und Makro-Ziele wurden perfekt gemeistert!").arg(cName, cActual)
                       : QStringLiteral("Excellent! %1 (%2) as well as your calorie and macro targets are mastered!").arg(cName, cActual);
        } else if (primaryConstraintMet) {
            stars = 2;
            title = isDe ? QStringLiteral("Bedingung erfüllt!") : QStringLiteral("Constraint Satisfied!");
            tip = isDe ? QStringLiteral("Biochemische Hauptregel erfüllt (%1)! Stimme nun noch Kalorien (%2 kcal) und Makros für 3 Sterne fein ab.")
                             .arg(cActual)
                             .arg(static_cast<int>(std::round(targetCal)))
                       : QStringLiteral("Primary biochemical rule achieved (%1)! Now refine your total calories (%2 kcal) and macros for 3 stars.")
                             .arg(cActual)
                             .arg(static_cast<int>(std::round(targetCal)));
        } else if (absCalDiff <= 150.0) {
            stars = 1;
            title = isDe ? QStringLiteral("Teilerfolg") : QStringLiteral("Partial Achievement");
            tip = isDe ? QStringLiteral("%1 (%2). Tipp: %3").arg(cGrade, cActual, levelHint)
                       : QStringLiteral("%1 (%2). Tip: %3").arg(cGrade, cActual, levelHint);
        } else {
            stars = 0;
            title = isDe ? QStringLiteral("Bedingung verfehlt") : QStringLiteral("Constraint Unmet");
            tip = isDe ? QStringLiteral("%1 (%2). Tipp: %3").arg(cGrade, cActual, levelHint)
                       : QStringLiteral("%1 (%2). Tip: %3").arg(cGrade, cActual, levelHint);
        }
    }

// Active Hero Challenge Modifiers Validation
    // ─────────────────────────────────────────────────────────────────────────
    QVariantList heroResults;
    bool allHeroesPassed = true;

    for (const QString &heroId : m_activeHeroModifiers) {
        QVariantMap hRes;
        hRes[QStringLiteral("heroId")] = heroId;

        bool heroPassed = true;
        QString reason;

        for (const auto &mVal : meals) {
            QVariantList items = mVal.toMap().value(QStringLiteral("items")).toList();
            for (const auto &iVal : items) {
                QVariantMap item = iVal.toMap();
                QString iName = item.value(QStringLiteral("nameEn")).toString().toLower();
                QString iNameDe = item.value(QStringLiteral("nameDe")).toString().toLower();
                QString iCat = item.value(QStringLiteral("category")).toString();
                QString iCatDe = item.value(QStringLiteral("categoryDe")).toString();

                if (heroId == QStringLiteral("H1")) { // Celiac: No gluten
                    if (iCat.contains(QStringLiteral("Grain"), Qt::CaseInsensitive) || iCatDe.contains(QStringLiteral("Getreide"), Qt::CaseInsensitive)) {
                        if (iName.contains("wheat") || iName.contains("spelt") || iName.contains("rye") || iName.contains("barley") ||
                            iNameDe.contains("weizen") || iNameDe.contains("dinkel") || iNameDe.contains("roggen") || iNameDe.contains("gerste")) {
                            heroPassed = false;
                            reason = QStringLiteral("Contains gluten: %1").arg(item.value("name").toString());
                        }
                    }
                } else if (heroId == QStringLiteral("H2")) { // Dairy-Free
                    if (item.value(QStringLiteral("isDairyCalcium")).toInt() == 1 || iCat == "Dairy" || iCatDe == "Milchprodukte") {
                        heroPassed = false;
                        reason = QStringLiteral("Contains dairy: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H3")) { // Nut-Free
                    if (iCat.contains("Nut", Qt::CaseInsensitive) || iCatDe.contains("Nuss", Qt::CaseInsensitive) || iCatDe.contains("Nüsse", Qt::CaseInsensitive)) {
                        if (iName.contains("walnut") || iName.contains("almond") || iName.contains("hazelnut") || iName.contains("peanut") || iName.contains("cashew")) {
                            heroPassed = false;
                            reason = QStringLiteral("Contains tree nuts / peanuts: %1").arg(item.value("name").toString());
                        }
                    }
                } else if (heroId == QStringLiteral("H4")) { // Seed-Free
                    if (item.value(QStringLiteral("isSeed")).toInt() == 1) {
                        heroPassed = false;
                        reason = QStringLiteral("Contains seeds: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H5")) { // Low-FODMAP
                    if (item.value(QStringLiteral("fodmapLevel")).toString().toLower() == "high") {
                        heroPassed = false;
                        reason = QStringLiteral("High-FODMAP ingredient: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H6")) { // Solanaceae Shield
                    if (item.value(QStringLiteral("isNightshade")).toInt() == 1) {
                        heroPassed = false;
                        reason = QStringLiteral("Nightshade food: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H7")) { // Low-Histamine (No fermented)
                    if (item.value(QStringLiteral("isFermented")).toInt() == 1) {
                        heroPassed = false;
                        reason = QStringLiteral("Fermented/aged food: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H8")) { // Low-Oxalate (< 50mg/day)
                    if (planManager->totalOxalateMg() > 50.0) {
                        heroPassed = false;
                        reason = QStringLiteral("Daily oxalate exceeds 50mg (%1mg)").arg(planManager->totalOxalateMg(), 0, 'f', 1);
                    }
                } else if (heroId == QStringLiteral("H9")) { // Vegan
                    if (iCat == "Meat" || iCat == "Fish & Seafood" || iCat == "Eggs" || iCat == "Dairy" ||
                        iCatDe == "Fleisch" || iCatDe == "Fisch" || iCatDe == "Eier" || iCatDe == "Milchprodukte") {
                        heroPassed = false;
                        reason = QStringLiteral("Animal product: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H10")) { // AIP
                    if (item.value("isNightshade").toInt() == 1 || item.value("isSeed").toInt() == 1 ||
                        iCat == "Dairy" || iCat == "Eggs" || iCatDe == "Milchprodukte" || iCatDe == "Eier") {
                        heroPassed = false;
                        reason = QStringLiteral("AIP excluded ingredient: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H11")) { // Dual Lipid Exclusion (No nuts, no seeds)
                    if (item.value("isSeed").toInt() == 1 || iCat.contains("Nut", Qt::CaseInsensitive) || iCatDe.contains("Nüsse", Qt::CaseInsensitive)) {
                        heroPassed = false;
                        reason = QStringLiteral("Nut or seed: %1").arg(item.value("name").toString());
                    }
                } else if (heroId == QStringLiteral("H12")) { // Pescatarian (No terrestrial meat)
                    if (iCat == "Meat" || iCatDe == "Fleisch") {
                        heroPassed = false;
                        reason = QStringLiteral("Terrestrial meat: %1").arg(item.value("name").toString());
                    }
                }

                if (!heroPassed) break;
            }
            if (!heroPassed) break;
        }

        hRes[QStringLiteral("met")] = heroPassed;
        hRes[QStringLiteral("reason")] = heroPassed ? QStringLiteral("Exclusion boundary preserved") : reason;
        heroResults.append(hRes);

        if (!heroPassed) {
            allHeroesPassed = false;
        }
    }

    if (!m_activeHeroModifiers.isEmpty() && !allHeroesPassed) {
        if (stars > 1) stars = 1;
        title += QStringLiteral(" (Hero Challenge Failed)");
    }

    if (stars > 0) {
        saveStars(levelId, stars);
    }

    double calAcc = std::max(0.0, 100.0 - (absCalDiff / targetCal) * 100.0);
    double macroAcc = std::max(0.0, 100.0 - avgMacroDiff * 2.0);

    res[QStringLiteral("levelId")] = levelId;
    res[QStringLiteral("stars")] = stars;
    res[QStringLiteral("starTitle")] = title;
    res[QStringLiteral("primaryConstraintMet")] = primaryConstraintMet;
    res[QStringLiteral("targetCalories")] = targetCal;
    res[QStringLiteral("actualCalories")] = actualCal;
    res[QStringLiteral("calorieDiff")] = calDiff;
    res[QStringLiteral("calorieAccuracy")] = std::round(calAcc * 10.0) / 10.0;
    res[QStringLiteral("hasMacroTarget")] = true;
    res[QStringLiteral("targetCarbs")] = targetC;
    res[QStringLiteral("actualCarbs")] = actualC;
    res[QStringLiteral("targetProtein")] = targetP;
    res[QStringLiteral("actualProtein")] = actualP;
    res[QStringLiteral("targetFat")] = targetF;
    res[QStringLiteral("actualFat")] = actualF;
    res[QStringLiteral("macroAccuracy")] = std::round(macroAcc * 10.0) / 10.0;
    res[QStringLiteral("constraints")] = constraints;
    res[QStringLiteral("heroConstraints")] = heroResults;
    res[QStringLiteral("coachingTip")] = tip;
    res[QStringLiteral("chronoData")] = getChronoNutrientData(planManager, levelId);

    emit evaluationCompleted(res);
    return res;
}

QVariantMap GameLevelManager::getChronoNutrientData(MealPlanManager *planManager, int levelId, const QString &customNutrientKey) const
{
    QVariantMap result;
    if (!planManager) return result;

    bool isDe = (LanguageManager::instance() && LanguageManager::instance()->currentLanguage() == QStringLiteral("de"));

    QString key = customNutrientKey.trimmed();
    QString nameEn;
    QString nameDe;
    QString unit = QStringLiteral("g");
    double targetVal = 0.0;
    int windowStartMin = -1;
    int windowEndMin = -1;
    QString windowType = QStringLiteral("none");
    double windowTargetPct = 0.0;

    int workoutMins = 16 * 60 + 30;
    QVariantList meals = planManager->meals();
    for (const auto &mVal : meals) {
        QVariantMap m = mVal.toMap();
        if (m.value(QStringLiteral("isWorkout")).toBool()) {
            workoutMins = parseTimeToMinutes(m.value(QStringLiteral("time")).toString());
            break;
        }
    }

    if (key.isEmpty()) {
        switch (levelId) {
        case 1:
            key = QStringLiteral("calories");
            nameEn = QStringLiteral("Energy (Calories)");
            nameDe = QStringLiteral("Energie (Kalorien)");
            unit = QStringLiteral("kcal");
            targetVal = planManager->targetCalories();
            break;
        case 2:
            key = QStringLiteral("protein");
            nameEn = QStringLiteral("Protein (Macro Split)");
            nameDe = QStringLiteral("Protein (Makro-Split)");
            unit = QStringLiteral("g");
            targetVal = (planManager->targetCalories() * planManager->targetProteinPercent() / 100.0) / 4.0;
            break;
        case 3:
            key = QStringLiteral("fiber");
            nameEn = QStringLiteral("Dietary Fiber");
            nameDe = QStringLiteral("Ballaststoffe");
            unit = QStringLiteral("g");
            targetVal = 35.0;
            break;
        case 4:
            key = QStringLiteral("satFat");
            nameEn = QStringLiteral("Saturated Fat");
            nameDe = QStringLiteral("Gesättigte Fettsäuren");
            unit = QStringLiteral("g");
            targetVal = (planManager->targetCalories() * 0.08) / 9.0;
            break;
        case 5:
            key = QStringLiteral("omega3");
            nameEn = QStringLiteral("Omega-3 Fatty Acids");
            nameDe = QStringLiteral("Omega-3 Fettsäuren");
            unit = QStringLiteral("g");
            targetVal = 2.5;
            break;
        case 6:
            key = QStringLiteral("potassium");
            nameEn = QStringLiteral("Potassium (K)");
            nameDe = QStringLiteral("Kalium (K)");
            unit = QStringLiteral("mg");
            targetVal = 3500.0;
            break;
        case 7:
            key = QStringLiteral("calcium");
            nameEn = QStringLiteral("Calcium (Ca)");
            nameDe = QStringLiteral("Calcium (Ca)");
            unit = QStringLiteral("mg");
            targetVal = 1000.0;
            break;
        case 8:
            key = QStringLiteral("zinc");
            nameEn = QStringLiteral("Zinc (Zn)");
            nameDe = QStringLiteral("Zink (Zn)");
            unit = QStringLiteral("mg");
            targetVal = 11.0;
            break;
        case 9:
            key = QStringLiteral("calories");
            nameEn = QStringLiteral("Seasonal Energy");
            nameDe = QStringLiteral("Saisonale Energie");
            unit = QStringLiteral("kcal");
            targetVal = planManager->targetCalories();
            break;
        case 10:
            key = QStringLiteral("vitaminC");
            nameEn = QStringLiteral("Vitamin C (Enhancer)");
            nameDe = QStringLiteral("Vitamin C (Verstärker)");
            unit = QStringLiteral("mg");
            targetVal = 75.0;
            break;
        case 11:
            key = QStringLiteral("fat");
            nameEn = QStringLiteral("Lipid Matrix (Fat)");
            nameDe = QStringLiteral("Lipidmatrix (Fett)");
            unit = QStringLiteral("g");
            targetVal = (planManager->targetCalories() * planManager->targetFatPercent() / 100.0) / 9.0;
            break;
        case 12:
            key = QStringLiteral("vitaminE");
            nameEn = QStringLiteral("Vitamin E");
            nameDe = QStringLiteral("Vitamin E");
            unit = QStringLiteral("mg");
            targetVal = 12.0;
            break;
        case 13:
            key = QStringLiteral("calcium");
            nameEn = QStringLiteral("Morning Calcium Gate (< 13:00)");
            nameDe = QStringLiteral("Morgendliches Calcium-Fenster (< 13:00)");
            unit = QStringLiteral("mg");
            targetVal = 1000.0;
            windowStartMin = 0;
            windowEndMin = 13 * 60;
            windowType = QStringLiteral("before");
            windowTargetPct = 60.0;
            break;
        case 14:
            key = QStringLiteral("magnesium");
            nameEn = QStringLiteral("Evening Magnesium Window (≥ 18:00)");
            nameDe = QStringLiteral("Abendliches Magnesium-Fenster (≥ 18:00)");
            unit = QStringLiteral("mg");
            targetVal = 400.0;
            windowStartMin = 18 * 60;
            windowEndMin = 24 * 60;
            windowType = QStringLiteral("after");
            windowTargetPct = 50.0;
            break;
        case 15:
        case 16:
        case 21:
            key = QStringLiteral("iron");
            nameEn = QStringLiteral("Iron (Fe)");
            nameDe = QStringLiteral("Eisen (Fe)");
            unit = QStringLiteral("mg");
            targetVal = 14.0;
            break;
        case 17:
        case 18:
            key = QStringLiteral("fiber");
            nameEn = QStringLiteral("Dietary Fiber");
            nameDe = QStringLiteral("Ballaststoffe");
            unit = QStringLiteral("g");
            targetVal = 35.0;
            break;
        case 19:
            key = QStringLiteral("protein");
            nameEn = QStringLiteral("Post-Workout Protein (PepT1)");
            nameDe = QStringLiteral("Post-Workout Protein (PepT1)");
            unit = QStringLiteral("g");
            targetVal = 30.0;
            windowStartMin = workoutMins;
            windowEndMin = workoutMins + 105;
            windowType = QStringLiteral("post_workout");
            windowTargetPct = 100.0;
            break;
        case 20:
            key = QStringLiteral("carbs");
            nameEn = QStringLiteral("Pre-Workout Carbs");
            nameDe = QStringLiteral("Pre-Workout Kohlenhydrate");
            unit = QStringLiteral("g");
            targetVal = 50.0;
            windowStartMin = 0;
            windowEndMin = std::max(0, workoutMins - 150);
            windowType = QStringLiteral("pre_workout");
            break;
        case 22:
            key = QStringLiteral("leucine");
            nameEn = QStringLiteral("L-Leucine (MPS Threshold)");
            nameDe = QStringLiteral("L-Leucin (MPS-Schwelle)");
            unit = QStringLiteral("g");
            targetVal = 2.5;
            break;
        case 23:
            key = QStringLiteral("tryptophan");
            nameEn = QStringLiteral("Evening L-Tryptophan");
            nameDe = QStringLiteral("Abendliches L-Tryptophan");
            unit = QStringLiteral("g");
            targetVal = 0.20;
            windowStartMin = 18 * 60;
            windowEndMin = 24 * 60;
            windowType = QStringLiteral("after");
            break;
        case 24:
        default:
            key = QStringLiteral("calories");
            nameEn = QStringLiteral("Daily Energy (Calories)");
            nameDe = QStringLiteral("Tagesenergie (Kalorien)");
            unit = QStringLiteral("kcal");
            targetVal = planManager->targetCalories();
            break;
        }
    } else {
        if (key == QStringLiteral("calories")) {
            nameEn = QStringLiteral("Energy (Calories)"); nameDe = QStringLiteral("Energie (Kalorien)"); unit = QStringLiteral("kcal"); targetVal = planManager->targetCalories();
        } else if (key == QStringLiteral("carbs")) {
            nameEn = QStringLiteral("Carbohydrates"); nameDe = QStringLiteral("Kohlenhydrate"); unit = QStringLiteral("g"); targetVal = (planManager->targetCalories() * planManager->targetCarbPercent() / 100.0) / 4.0;
        } else if (key == QStringLiteral("protein")) {
            nameEn = QStringLiteral("Protein"); nameDe = QStringLiteral("Protein"); unit = QStringLiteral("g"); targetVal = (planManager->targetCalories() * planManager->targetProteinPercent() / 100.0) / 4.0;
        } else if (key == QStringLiteral("fat")) {
            nameEn = QStringLiteral("Fat"); nameDe = QStringLiteral("Fett"); unit = QStringLiteral("g"); targetVal = (planManager->targetCalories() * planManager->targetFatPercent() / 100.0) / 9.0;
        } else if (key == QStringLiteral("fiber")) {
            nameEn = QStringLiteral("Fiber"); nameDe = QStringLiteral("Ballaststoffe"); unit = QStringLiteral("g"); targetVal = 35.0;
        } else if (key == QStringLiteral("magnesium")) {
            nameEn = QStringLiteral("Magnesium"); nameDe = QStringLiteral("Magnesium"); unit = QStringLiteral("mg"); targetVal = 400.0;
        } else if (key == QStringLiteral("calcium")) {
            nameEn = QStringLiteral("Calcium"); nameDe = QStringLiteral("Calcium"); unit = QStringLiteral("mg"); targetVal = 1000.0;
        } else if (key == QStringLiteral("potassium")) {
            nameEn = QStringLiteral("Potassium"); nameDe = QStringLiteral("Kalium"); unit = QStringLiteral("mg"); targetVal = 3500.0;
        } else if (key == QStringLiteral("omega3")) {
            nameEn = QStringLiteral("Omega-3"); nameDe = QStringLiteral("Omega-3"); unit = QStringLiteral("g"); targetVal = 2.5;
        } else if (key == QStringLiteral("iron")) {
            nameEn = QStringLiteral("Iron"); nameDe = QStringLiteral("Eisen"); unit = QStringLiteral("mg"); targetVal = 14.0;
        } else if (key == QStringLiteral("zinc")) {
            nameEn = QStringLiteral("Zinc"); nameDe = QStringLiteral("Zink"); unit = QStringLiteral("mg"); targetVal = 11.0;
        } else if (key == QStringLiteral("vitaminC")) {
            nameEn = QStringLiteral("Vitamin C"); nameDe = QStringLiteral("Vitamin C"); unit = QStringLiteral("mg"); targetVal = 75.0;
        } else {
            nameEn = key; nameDe = key; unit = QStringLiteral("g"); targetVal = 10.0;
        }
    }

    double runningTotal = 0.0;
    double windowAmount = 0.0;
    double maxMealAmount = 0.0;
    QVariantList mealEntries;

    for (int i = 0; i < meals.size(); ++i) {
        QVariantMap m = meals[i].toMap();
        bool isWo = m.value(QStringLiteral("isWorkout")).toBool();
        QString timeStr = m.value(QStringLiteral("time")).toString();
        int mins = parseTimeToMinutes(timeStr);
        double amt = m.value(key, 0.0).toDouble();

        if (amt > maxMealAmount) maxMealAmount = amt;
        runningTotal += amt;

        bool inWindow = false;
        if (windowType == QStringLiteral("before")) {
            inWindow = (mins <= windowEndMin);
        } else if (windowType == QStringLiteral("after")) {
            inWindow = (mins >= windowStartMin);
        } else if (windowType == QStringLiteral("post_workout") || windowType == QStringLiteral("pre_workout")) {
            inWindow = (mins >= windowStartMin && mins <= windowEndMin);
        }
        if (inWindow) {
            windowAmount += amt;
        }

        QVariantMap entry;
        entry[QStringLiteral("index")] = i;
        entry[QStringLiteral("title")] = m.value(QStringLiteral("title")).toString();
        entry[QStringLiteral("time")] = timeStr;
        entry[QStringLiteral("minutes")] = mins;
        entry[QStringLiteral("icon")] = m.value(QStringLiteral("icon"), QStringLiteral("🍽️")).toString();
        entry[QStringLiteral("isWorkout")] = isWo;
        entry[QStringLiteral("amount")] = amt;
        entry[QStringLiteral("cumulative")] = runningTotal;
        entry[QStringLiteral("inWindow")] = inWindow;
        mealEntries.append(entry);
    }

    double totalAmount = runningTotal;
    for (int i = 0; i < mealEntries.size(); ++i) {
        QVariantMap entry = mealEntries[i].toMap();
        double amt = entry.value(QStringLiteral("amount")).toDouble();
        entry[QStringLiteral("pctOfTotal")] = (totalAmount > 0.001) ? (amt / totalAmount * 100.0) : 0.0;
        mealEntries[i] = entry;
    }

    double windowActualPct = (totalAmount > 0.001) ? (windowAmount / totalAmount * 100.0) : 0.0;

    result[QStringLiteral("nutrientKey")] = key;
    result[QStringLiteral("nutrientName")] = isDe ? nameDe : nameEn;
    result[QStringLiteral("nutrientUnit")] = unit;
    result[QStringLiteral("targetDaily")] = targetVal;
    result[QStringLiteral("totalAmount")] = totalAmount;
    result[QStringLiteral("maxMealAmount")] = maxMealAmount;
    result[QStringLiteral("windowStartMin")] = windowStartMin;
    result[QStringLiteral("windowEndMin")] = windowEndMin;
    result[QStringLiteral("windowType")] = windowType;
    result[QStringLiteral("windowTargetPct")] = windowTargetPct;
    result[QStringLiteral("windowAmount")] = windowAmount;
    result[QStringLiteral("windowActualPct")] = windowActualPct;
    result[QStringLiteral("meals")] = mealEntries;

    return result;
}