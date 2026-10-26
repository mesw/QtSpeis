# QtSpeis — Future Roadmap & Backlog (TODO_LATER)

This document collects architectural enhancements, biological edge cases, and user experience expansions identified during the development of QtSpeis. These items are reserved for future development cycles.

---

## 1. Chrono-Nutrition & Workout Dynamics

### 1.1 Multiple Workouts in a Single Day
* **Current Behavior:** In `GameLevelManager::checkAllLevelConstraints`, the engine anchors the chrono-nutrition timing rules—Level 19 (Post-Workout `PepT1` rapid recovery window), Level 20 (Pre-Workout glycemic clearance), and Level 21 (Hepcidin window bypass)—to the **first workout** found in the daily plan.
* **Problem / Edge Case:** Athletic populations frequently train twice a day (e.g., morning endurance session at 07:00 and evening hypertrophy session at 17:30). The second workout is currently ignored in timing calculations.
* **Proposed Solution:**
  * Allow users to designate a "Primary Focus Session" via a star toggle on the workout card, or
  * Evaluate multiple discrete pre/post feeding windows and verify that both training sessions have valid nutrient timing buffers.

### 1.2 Rest Day Mode (Zero Workouts Logged)
* **Current Behavior:** If no workout is present in the plan (`workoutCount == 0`), the engine defaults to an internal reference time of 16:30. Levels 19, 20, and 21 evaluate against this phantom workout, requiring post-workout protein shakes even on complete rest days.
* **Proposed Solution:**
  * Add automatic detection for `workoutCount == 0`.
  * Award an automatic pass with the status badge `🛌 Rest Day — Recovery Mode` for Levels 19, 20, and 21.
  * Adjust calorie targets strictly to base metabolic needs (BMR $\times$ PAL) without exercise expenditure bonuses.

---

## 2. Nutritional & Biological Calculations

### 2.1 Absolute g/kg Protein and Fat Floors (Caloric Extremes)
* **Current Behavior:** Level 2 evaluates relative macronutrient percentages (e.g., 55% C / 12–18% P / 27–33% F for the default sport profile).
* **Problem / Edge Case:**
  * **Low-Calorie Diets:** On a 1,500 kcal plan, a 12% protein target yields only 45 g ($0.6\text{ g/kg}$ for a 75 kg individual), which is below the threshold for lean mass preservation and satiety.
  * **Extreme Expenditure (>4,000 kcal):** As documented in the Level Guide, when daily caloric needs surge in stage racing or arctic expeditions, fat intake must scale to 1.0–3.0+ g/kg of body weight to prevent gastrointestinal volume overload from excessive starches.
* **Proposed Solution:**
  * Introduce dual constraints for Level 2: maintain target percentage ranges while validating absolute biological floors (e.g., Protein $\ge 1.2\text{ g/kg}$, Fat $\ge 0.8\text{ g/kg}$).

### 2.2 Fractional Bioavailability Modeling vs. Analytical Mass Ratios
* **Current Behavior:** Stoichiometric ratios (Ca:Mg in Level 7, Zn:Cu in Level 8, Na:K in Level 6) are calculated from analytical chemical masses stored in `speis.db`.
* **Nuance:** Real-world intestinal absorption is fractional and modulated by co-ingested ligands:
  * Non-heme iron absorption increases from ~5% to ~15% in the presence of $\ge 50\text{ mg}$ Vitamin C (Level 10).
  * High calcium ($\ge 125\text{ mg}$) competitively inhibits iron absorption at the DMT1 transporter (Level 15).
  * Phytate chelates zinc and iron unless degraded by sourdough fermentation or phytases (Level 17).
* **Proposed Solution:**
  * Retain analytical ratios as the default baseline.
  * Introduce an optional "True Bioavailability" toggle that applies mathematical absorption algorithms to display estimated net absorbed microminerals.

---

## 3. Feature Completeness & User Experience

### 3.1 Aggregated Grocery / Shopping List Mode (Einkaufszettel)
* **Current Behavior:** `CozyShoppingList.qml` organizes ingredients within meal cards (Breakfast, Lunch, Dinner, Snacks).
* **Proposed Feature:**
  * Add an aggregated "Shopping Mode" drawer or tab.
  * Consolidate duplicate ingredients across the entire day into a single grocery list (e.g., combining 85 g oats from breakfast and 40 g oats from a shake into **"125 g Haferflocken"**).
  * Include tap-to-check checkboxes with strike-through styling for in-store supermarket shopping.
  * Categorize items by grocery department (Produce, Bakery, Dairy & Alternatives, Grains & Legumes, Meat & Seafood, Oils & Condiments).

### 3.2 Manual Raw Ingredient Creator UI
* **Current Behavior:** Users can save composed meals as reusable templates (`💾` in meal header) and fetch items via OpenFoodFacts barcodes. Creating brand-new raw ingredients from scratch requires direct SQLite editing in `speis.db`.
* **Proposed Feature:**
  * Provide a "+ Add Custom Food" modal in the food search drawer.
  * Allow users to enter food name (multilingual), serving size, calories, macronutrients, and key micronutrients (Fe, Ca, Mg, Zn, Vit C, Omega-3).
  * Persist custom ingredients in a separate `user_custom_foods` table in `speis.db` or via user settings to survive app updates.

### 3.3 Hardware Viewfinder Barcode Scanner on Mobile
* **Current Behavior:** OpenFoodFacts lookup operates via numeric barcode input, paste from clipboard, or direct name search.
* **Proposed Feature:**
  * On native Android and iOS devices, integrate live camera viewfinder scanning using Qt Multimedia (`QMediaCaptureSession`, `QVideoSink`) or a lightweight WASM/native barcode decoder library (such as ZXing-C++).

### 3.4 Additional Language Localizations (Français, Español, Italiano) & Statutory Legal Texts
* **Current Behavior:** German (`de`) and English (`en`) are 100% localized with 12,900+ entries across all 17 QML views, 32 recipes, and biochem coaching tips. `LanguageManager::availableLanguages()` supports toggling French, Spanish, and Italian via `showAllLanguages`, but those languages currently fall back to English.
* **Proposed Feature:**
  * Add `qtspeis_fr.ts`, `qtspeis_es.ts`, and `qtspeis_it.ts` translation catalogs.
  * Translate the UI, nutrients, and common ingredients into French, Spanish, and Italian.
  * Keep the verbatim statutory legal texts in `AboutLegalDialog.qml` (GNU GPLv3, USDA public domain, ANSES Licence Ouverte, FSVO Swiss OGD) in their statutory original languages, while providing optional localized plain-language summaries.

---

## 4. Scope & Architecture

### 4.1 Multi-Day / 7-Day Weekly Calendar Planner
* **Current Behavior:** QtSpeis focuses on a single 24-hour diurnal bio-optimization cycle.
* **Proposed Feature:**
  * Expand the data model from a single day plan to a 7-day weekly schedule (Monday through Sunday).
  * Allow different sport targets and workout timings on training days versus active recovery or rest days.
  * Support weekly grocery list aggregation covering all 7 days of meals.

### 4.2 Printable PDF & Export Formatting
* **Current Behavior:** The app supports JSON savegame slots, JSON import/export, and YAML text clipboard export.
* **Proposed Feature:**
  * Add a clean, printable HTML/PDF export with vector nutritional charts for sharing meal plans with dietitians, coaches, or family members.

### 4.3 Offline PWA Service Worker for WebAssembly Deployment
* **Current Behavior:** The WebAssembly build bundles all assets (including `speis.db`) into `.wasm` and `.js` files.
* **Proposed Feature:**
  * Add a `manifest.json` and a lightweight Service Worker script (`sw.js`) to provide full Progressive Web App (PWA) offline installation, home screen icons, and instant cache loading.
