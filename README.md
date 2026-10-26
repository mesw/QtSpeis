# Speis: Cozy Meal Planner & Nutrition Quest (Qt Quick / WebAssembly)

> **License:** GNU General Public License v3.0 (GPL-3.0)  
> **Source Code:** [github.com/mesw/QtSpeis](https://github.com/mesw/QtSpeis)  
> **Live WebAssembly Deployment:** [mesw.github.io/QtSpeis](https://mesw.github.io/QtSpeis)  
> **Status:** Modern C++, Qt Quick (Qt 6.8+), WebAssembly (single-thread) & Desktop Native  
> 
> **Core Concept:** An educational meal-planning game with a cozy shopping list UI where players plan daily meals to meet specific nutritional goals (calories & macro distributions). Features an embedded SQLite food catalog with autocomplete, live Open Food Facts barcode scanning, interactive 24-hour tabular schedule visualization, and background WebAssembly Worker offloading.

---

### Key Features

1. **Cozy Shopping List & Meal Plan Editor (`CozyShoppingList.qml`)**
   - **Tactile, warm aesthetic:** Designed like a cozy kitchen notebook/shopping list with warm paper tones, food icons, and clean typography.
   - **Full Meal Organization:** Group foods into meals (Breakfast, Lunch, Dinner, Snacks, or custom).
   - **Ingredient Autocomplete:** Live dropdown suggestions from the built-in SQLite database as you type, displaying calories and macros per 100g.
   - **Portion Adjustment:** Easy `[ - ] [ + ]` steppers or direct gram/ml input that recalculates meal subtotals in real time.
   - **Meal Time & Reordering:** Adjust meal scheduled times with seamless synchronization to the tabular schedule view.

2. **Open Food Facts Barcode Scanner (`BarcodeLookupDialog.qml`, `OpenFoodFactsFetcher`)**
   - Scan or enter product barcodes (e.g., `4008400404127`, `5201051001078`, `7610400070776`).
   - Fetches official nutrition data (calories, carbohydrates, proteins, fats, fiber, ingredients) directly from the Open Food Facts API via `QNetworkAccessManager`.
   - Includes quick one-click test presets and auto-caches discovered items into the local SQLite database.

3. **Reused 24-Hour Tabular Schedule View (`TemporalTableChart.qml`)**
   - Visualizes the day's meals and constituent food items mapped along a non-linear 24-hour straight time axis with diurnal circadian blended lighting.
   - Automatically synchronizes with the shopping list via YAML export (`mealPlanManager.syncToDayPlanModel(dayPlanModel)`).

4. **Educational Game Progression & Level Evaluation (`GameLevelManager`, `EvaluationResultDialog.qml`)**
   - **Level 1: Calorie Balance**
     - Target: Exactly 2,000 kcal total daily energy (±50 kcal for 3 stars, ±150 kcal for 2 stars, ±300 kcal for 1 star). Flexible macronutrient distribution.
   - **Level 2: Balanced Macros**
     - Target: 2,000 kcal with the classic balanced distribution: **50% Carbs, 25% Protein, 25% Fat**.
   - **20+ Locked Campaign Levels:**
     - Level selection grid displaying 22 deactivated, "?" captioned challenge tiles with lock badges (e.g. Ketogenic Shift, High-Protein Athlete, Plant Power, Longevity).
   - **Grading & Feedback Modal:**
     - 0 to 3 gold star rating, accuracy percentages, constraint validation breakdown, and personalized educational coaching advice.

5. **Display Language Selection & Multilingual Prioritized Search (`LanguageManager`)**
   - In-app display language selector in the header bar supporting 🇬🇧 English, 🇩🇪 Deutsch, 🇫🇷 Français, 🇪🇸 Español, and 🇮🇹 Italiano.
   - **Cross-language search ranking:** The user can search in any language (e.g. typing `"oats"` in English while German display language is active). Results from other languages appear at the **bottom of the list** with a matched-language indicator, while the ingredient is **always displayed in the selected app language** (e.g. `"Haferflocken"`).
   - Dynamic language switching updates the shopping list, day plan, and UI labels reactively.

---

### Project Structure

```
QtSpeis/
├── CMakeLists.txt                 # Build configuration (Desktop MinGW & WASM)
├── languagemanager.h / .cpp       # Display language manager & multi-language dictionaries
├── fooddatabase.h / .cpp          # Multilingual SQLite food catalog with prioritized search
├── openfoodfactsfetcher.h / .cpp  # Open Food Facts API network fetcher
├── mealplanmanager.h / .cpp       # Daily meals data model & multilingual sync
├── gamelevelmanager.h / .cpp      # Game level rules, progression & scoring
├── Main.qml                       # Main application window, language menu & tab switcher
├── CozyShoppingList.qml           # Cozy shopping list meal creation UI & autocomplete
├── GoalSummaryCard.qml            # Live calorie gauge & macro ratio bar
├── BarcodeLookupDialog.qml        # Barcode scanner & Open Food Facts lookup modal
├── LevelSelectView.qml            # Level selection screen (Levels 1, 2 + 22 locked "?")
├── EvaluationResultDialog.qml     # 0-3 star scorecard & constraints breakdown
├── AboutLegalDialog.qml           # In-app legal notices, copyright, AI disclaimer & privacy policy
├── TemporalTableChart.qml         # Reused 24-hour tabular schedule chart
├── TemporalPieChart.qml           # Circular 24h dial (preserved)
└── TemporalSpiralChart.qml        # Multi-day coiled spiral (preserved)
```

---

### Building & Running

#### Desktop (Qt 6.8+ MinGW / Clang / MSVC)
```bash
cmake -B build/Desktop_Qt_6_8_3_MinGW_64_bit-Debug -S . -GNinja
cmake --build build/Desktop_Qt_6_8_3_MinGW_64_bit-Debug
./build/Desktop_Qt_6_8_3_MinGW_64_bit-Debug/appQtSpeis.exe
```

#### WebAssembly (Qt 6.8+ WASM Single-Threaded & Emscripten)
```bash
call <path-to-emsdk>/emsdk_env.bat
cmake -B build/WebAssembly_Qt_6_8_3_single_threaded-Release -S . -GNinja
cmake --build build/WebAssembly_Qt_6_8_3_single_threaded-Release
# Run local HTTP server to launch in browser
python -m http.server 8080 --directory build/WebAssembly_Qt_6_8_3_single_threaded-Release
```

Live online deployment: [mesw.github.io/QtSpeis](https://mesw.github.io/QtSpeis)

---

### Data Sources & Copyright Notices

Speis compiles, normalizes, and imputes nutrient values from official national and international food composition databases. All data remains the intellectual property of their respective publishing agencies and research institutions.

- 🇺🇸 **USDA FoodData Central (FDC)** [fdc.nal.usda.gov ↗](https://fdc.nal.usda.gov/)  
  U.S. Department of Agriculture, Agricultural Research Service. Comprehensive Foundation Foods, SR Legacy, and FNDDS nutrient profiles.  
  *Copyright & License:* Public Domain (U.S. Government Work).

- 🇨🇭 **Swiss Food Composition Database** [naehrwertdaten.ch ↗](https://naehrwertdaten.ch/)  
  Federal Food Safety and Veterinary Office (FSVO / BLV) & ETH Zurich. Standard Swiss nutritional values (Version 6.0+).  
  *Copyright & License:* © Federal Food Safety and Veterinary Office (FSVO), Switzerland / Open Government Data (OGD).

- 🇫🇷 **French Ciqual Database** [ciqual.anses.fr ↗](https://ciqual.anses.fr/)  
  French Agency for Food, Environmental and Occupational Health & Safety (ANSES). Nutritional composition of over 3,000 foods.  
  *Copyright & License:* © ANSES / Open Licence (Licence Ouverte / Etalab).

- 🇩🇪 **Bundeslebensmittelschlüssel (BLS)** [mri.bund.de/bls ↗](https://www.mri.bund.de/de/institute/ernaehrung-und-verhalten/forschungsprojekte/bls/)  
  Max Rubner-Institut (MRI), Federal Research Institute of Nutrition and Food, Germany. Standard German reference nutrient database.  
  *Copyright & License:* © Max Rubner-Institut (MRI), Federal Ministry of Food and Agriculture (BMEL).

- 🔬 **FlavorDB & Aroma Networks** [cosylab.iiitd.edu.in/flavordb ↗](https://cosylab.iiitd.edu.in/flavordb/)  
  Computational biology resource of 25,000+ flavor molecule pairings and chemical odor profile graphs (Garg et al., IIIT-Delhi).  
  *Copyright & License:* Open Academic Resource / CC BY-NC 4.0.

---

### AI-Generated Database & Accuracy Notice

The database `speis.db` was compiled, cross-matched, normalized, and imputed from the aforementioned sources using **Artificial Intelligence (AI)** and automated algorithmic data pipelines.

**Notice of Potential Errors:**
Due to differences in analytical laboratory methods across countries, translation subtleties, and automated unit conversions and imputation, the database may contain inaccuracies or errors. Nutritional values are provided for **educational simulation and gaming purposes only** and should not be used for medical, clinical, or diagnostic dietary management.

---

### License & Qt WebAssembly Static Linking Obligations

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for the full license text.

#### Qt Static Linking Compliance
QtSpeis is built using the Qt framework (Qt 6.8+). In the WebAssembly build, the application links **statically** against Qt libraries (including Qt Quick, Qt Quick Controls 2, Qt Network, and Qt Sql). Under the terms of the GNU General Public License v3 (GPLv3) governing static linking with Qt, the entire application is distributed as a unified work under GPLv3.

In compliance with GPLv3 Section 6, the complete corresponding source code, build scripts, and resource definitions are publicly and freely available in the repository at [github.com/mesw/QtSpeis](https://github.com/mesw/QtSpeis).

---

### Privacy Policy

QtSpeis is designed from the ground up with a **strict client-side privacy architecture**:

1. **100% Local Execution:**
   All user data, personalized profile metrics (age, weight, height, athletic goals), daily meal plans, custom recipes, custom workouts, and campaign star ratings remain exclusively on your device.

2. **Save Game Storage Location:**
   - **WebAssembly (Browser):** Save data is stored locally in your browser's persistent HTML5 `window.localStorage` under the keys:
     - `speis_savegame_v1` (active autosave)
     - `speis_savegame_slots_v1` (custom named save slots)
   - **Desktop (Native):** Stored locally on your machine via `QSettings` (`SpeisApp / SaveGame`) in your standard operating system user configuration path.
   - **Local File Backups:** Users can manually export or import save games as `.json` files. File parsing occurs entirely in local memory with no network activity.

3. **Zero Server Tracking & Telemetry:**
   **No personal data, meal plan data, or save games are ever transmitted to any remote server.** There are no tracking cookies, analytics SDKs, external telemetry scripts, or remote database synchronizations.

4. **Optional Outgoing Barcode Queries:**
   If and only if the user explicitly triggers the barcode scanner, the application sends a direct HTTPS request from the client to the public Open Food Facts API (`world.openfoodfacts.org`) to look up public product nutrition information. No personal identifiers or user plan details are transmitted.

