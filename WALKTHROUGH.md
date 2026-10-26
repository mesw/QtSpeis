# Usability & UX Playtest Walkthrough (Desktop — WebAssembly Build)

**Date:** 2026-10-25
**Target:** Desktop (WebAssembly Single-Threaded Release)
**Starting State:** Clean athlete profile (all progress and storage cleared)

---

## Playtest Log & Findings

**Environment:** 1920x1080 Desktop Browser (with Windows taskbar & browser chrome).

### Session 1: Zero-State Onboarding & Initial Screen (`Level 1: Caloric Equilibrium`)

1. **Missing First-Time Onboarding / Welcome Flow (Cognitive Overload):**
   - **Observation:** Launching with a clean profile drops the player directly into the full workspace (top bar, Quick Add bar with 9 buttons, an empty "Food" card, and the right-hand constraint sidebar).
   - **UX Impact:** While clear to the developer, a new player has no narrative context, no prompt to configure their Athlete Profile first (it silently defaults to `2,000 kcal`), and no guided first step explaining what "Nutrition Quest" is or how to win Level 1.
   - **Improvement Idea:** Trigger a welcome modal or a 3-step interactive onboarding coach-mark on first launch (Step 1: Set up your Athlete Profile / BMR; Step 2: Add meals or recipes to match your daily energy target; Step 3: Grade your Meal Plan to unlock Level 2).

2. **Mnemonic Typos in Primary CTA (`Finish _Grade Meal Plan`):**
   - **Observation:** Both the top-right header button and the right-hand sidebar CTA display `⭐ Finish _Grade Meal Plan` (an underscore `_` instead of `&` or `/` where a mnemonic or separator was likely intended).
   - **UX Impact:** Looks like a rendering bug on the most prominent button on the screen, and having two identical orange primary CTAs in close proximity (top-right header + right sidebar) competes for visual attention.

3. **Redundant / Competing Controls Across Regions:**
   - **Observation:**
     - `🔬 Ingredient Explorer` appears in both the top navigation bar and the `Quick Add:` toolbar.
     - `+ Custom Meal` + `+ Workout` in the `Quick Add:` bar duplicate the huge `+ Add Meal` and `🏃 Workout` buttons directly below the meal card.
     - `👤 Athlete (2000 kcal)` in the top bar vs. `👤 Athlete • 2000 (Base) + 0 (0 WO) = 20...` dropdown/pill inside the right sidebar.
   - **UX Impact:** Increases visual noise for a Level 1 player who only needs to understand "Add food to hit 2,000 kcal".

4. **Progressive Disclosure in Level 1:**
   - **Observation:** Level 1 only tests **Caloric Equilibrium** (`2,000 kcal`), yet the right sidebar already displays `Macronutrient Split (% of energy)` (Carbs/Protein/Fat) and workout energy formulas (`2000 (Base) + 0 (0 WO)`), and the Quick Add bar exposes workouts and advanced tools immediately.
   - **UX Impact:** Dilutes focus on the single core mechanic of Level 1.

5. **Default Empty Card Naming (`Food` at `12:00`):**
   - **Observation:** The initial card is generically titled `Food` at `12:00` rather than a recognizable meal like `Breakfast (08:00)`.
   - **UX Impact:** Feels slightly robotic compared to the `🍳 Breakfast`, `🥗 Lunch`, `🍎 Snack`, `🍲 Dinner` pills right above it.

---

### Session 2: Athlete Profile Modal & Language Switch to German (`de`)

6. **Severe Incomplete Localization ("Denglish" UI after switching to German):**
   - **Observation:** After switching language to German (which triggers an app restart), only backend/C++ strings and a single Quick Add button (`🔬 Zutaten-Explorer`) are in German (`Level 1: Kalorisches Gleichgewicht`, `Zielwert: 2,000 kcal (±50 kcal)`, `Ausdauersport mit hohem Krafteinsatz`), while almost all QML UI labels remain hardcoded in English:
     - Top bar: `🔬 Ingredient Explorer`, `💾 Save / Export`, `⚖️ Legal & Privacy`, `⭐ Finish _Grade Meal Plan`
     - Quick Add bar: `Quick Add:`, `📖 Recipes (32)`, `Saved Meals`, `🏋️ Workout Library`, `🍳 Breakfast`, `🥗 Lunch`, `🍎 Snack`, `🍲 Dinner`, `+ Custom Meal`, `🏃 Workout`
     - Main area & Sidebar: `Collapse All`, `Clear`, `Daily Energy (Calories)`, `2000 kcal remaining`, `Macronutrient Split (% of energy)`, `Carbs`, `Protein`, `Fat`
     - Inside the **User Profile & Metabolism** modal: Every label (`Name / Nickname`, `Base Calorie Need (BMR)`, `Estimate BMR (Mifflin-St Jeor)`, `Biological Sex`, `Male`/`Female`, `Age (years)`, `Weight (kg)`, `Height (cm)`, `Apply Estimate (1718 kcal)`, `Athletic Discipline & Macro Ratio`, `Cancel`, `💾 Save Profile`) is still in English!
   - **UX Impact:** Switching language requires a disruptive full app restart, yet leaves ~85% of the interface in English.

7. **Top Header Button Overlap with Longer Athlete Names:**
   - **Observation:** Changing the athlete name from `Athlete` to `Test Athlete` caused the `👤 Test Athlete (2000 kcal)` pill in the top header to expand and visually collide/overlap with the adjacent `🔬 Ingredient Explorer` button (`👤 Test Athlete (2000 kcal` is cut off and touches the next button).
   - **UX Impact:** Layout bug in the top navigation bar when the user enters a realistic name (>7 characters).

8. **Clipped Content & Missing Scroll Indicator in Athlete Profile Modal:**
   - **Observation:** At the bottom of the `User Profile & Metabolism` dialog, the blue info box under `Athletic Discipline & Macro Ratio` is vertically cut off mid-line (`⚖️ Grammatura-Anteil (2000 kcal)...`) right above the `Cancel` / `💾 Save Profile` footer bar.
   - **UX Impact:** The dialog height is slightly too small for its contents (or lacks obvious scrollbar padding), cutting off the gram-target breakdown.

9. **Confusion Between Manual `2000 kcal` BMR and `⚡ Apply Estimate (1718 kcal)`:**
   - **Observation:** The dialog shows `2000 kcal` at the top, and right below it shows pre-filled default stats (`Male`, `30` yrs, `75` kg, `178` cm) with a button `⚡ Apply Estimate (1718 kcal)`.
   - **UX Impact:** A user who leaves the default body stats unchanged might think their profile is using those stats, not realizing `2000 kcal` is a manual override unless they explicitly click `⚡ Apply Estimate (1718 kcal)`.

---

### Session 3: Ingredient Explorer & Barcode Scanner

10. **SpinBox Text Field Clipped in Ingredient Explorer (`Portion Size (g)`):**
    - **Observation:** In the `Ingredient Explorer` modal (`Ananas` expanded), the `Portion Size (g)` SpinBox between the `-` and `+` buttons has a white center text box that is far too narrow (~10–12px wide), so a value like `200` is clipped to only show the last digit `0`. The user had to rely on the preset buttons (`50g`, `100g`, `150g`, `200g`, `250g`) instead.
    - **UX Impact:** Critical layout bug on the SpinBox `contentItem` width inside `IngredientExplorerModal.qml`.

11. **Inverted Meal Context When Adding Ingredients (Global Explorer vs. Meal-Scoped Selection):**
    - **Observation:** Opening the global `Ingredient Explorer` requires choosing a `Target Meal: [Food (12:00) ⌄]` inside the modal before clicking `+ Add to Meal Plan`.
    - **User / UX Preference:** Instead of selecting the target meal and time *after* picking an ingredient in a global dialog, adding an ingredient should originate from the **Meal Card context** itself—e.g., replacing or augmenting the `Add ingredient...` text box inside each Meal Card with a rich combobox/dropdown or button that opens the Ingredient Picker already scoped to that specific meal.

12. **Nutrition Values in Ingredient Explorer Do Not Dynamically Preview Selected Portion Size:**
    - **Observation:** Even when `200g` is selected at the bottom of the `Ananas` card, the header still displays `60 kcal` and `Macronutrients & Energy (per 100g)`.
    - **UX Impact:** Players have to do mental math (`200g = 2 × 60 kcal = 120 kcal`) before adding the item to see how much it will contribute to their daily target.

13. **Barcode Scanner Lacks Camera Viewfinder & Sample Barcode Fails (`Network error: Not Found`):**
    - **Observation:**
      - Clicking `Scan Barcode` opens a manual text-entry modal (`Scan Barcode / Open Food Facts`) with a camera icon `📷`, but no actual camera viewfinder widget opens to scan a physical barcode via webcam/phone camera.
      - Clicking one of the `Quick Test Presets` (`4008400404127`) resulted in `Network error: Not Found` (either OpenFoodFacts API endpoint/CORS failure in WebAssembly or an outdated/404 barcode in the preset list).
    - **UX Impact:** Both the expectation promised by the label/icon ("Scan Barcode" with a camera icon) and the built-in test preset fail in the WebAssembly build.

---

### Session 4: Populated Meal Card & Level 1 Grading Modal

14. **Truncated Step Increment Buttons in Ingredient Rows (`-1...` / `+1...`):**
    - **Observation:** In the populated `Food` card, two-digit step buttons like `-80`/`+80`, `-50`/`+50`, `-20`/`+20` fit inside the circular yellow pills, but three-digit or two-digit `10`/`100` step buttons on `Birnen`, `Ananas`, `Butter`, and `Apfel` are truncated with an ellipsis: `(-1...)` and `(+1...)`!
    - **UX Impact:** The user cannot tell whether clicking `(+1...)` on `Birnen` (200g) or `Butter` (10g) adds `+10g` or `+100g` without clicking it.

15. **Missing Ingredient Icons on Most Rows:**
    - **Observation:** `Haferflocken` (`🥣`) and `Hühnerei` (`🍳`) have icons on the left of their row, whereas `Birnen`, `Ananas`, `Butter`, `Apfel`, and `Walnüsse` have no icon at all—leaving their text unaligned or inconsistently styled compared to rows with icons (notice that in the `Ingredient Explorer`, `Ananas` and `Apfel` *did* have fruit icons `🍍`/`🍎`, so the Meal Card row isn't using the same icon mapping!).
    - **UX Impact:** Visual inconsistency between the Ingredient Explorer and the Meal Card list items.

16. **Hardcoded / Mismatched `50% C • 25% P • 25% F` Subtitle in Grading Modal:**
    - **Observation:** In the Level 1 completion modal (`★★★ Meister-Ernährer!`), the `Macro Balance Accuracy` box shows `95.5%` with the subtitle `50% C • 25% P • 25% F`. However:
      1. The athlete's actual sport profile target is **55% C • 12–18% P • 27–33% F** (`Ausdauersport mit hohem Krafteinsatz`).
      2. The athlete's actual meal plan macro split is **54.2% C • 12.4% P • 33.3% F** (which is why accuracy is 95.5% against the sport profile!).
      3. Furthermore, in Level 1, Macro Balance isn't even a level constraint yet.
    - **UX Impact:** Displaying a hardcoded `50% C • 25% P • 25% F` label in the grading card contradicts both the user's selected sport profile and their actual meal plan macros.

17. **Duplicate Stars & Mixed Language in Grading Modal:**
    - **Observation:**
      - The header displays three large gold stars `⭐⭐⭐` and immediately below them three black stars in the title string `★★★ Meister-Ernährer!`.
      - Mixed English/German labels inside the same modal: `Calorie Accuracy`, `Macro Balance Accuracy`, `Level 1 Constraint:`, `Target: 2000 ± 50 kcal`, `Nutrition Coach's Feedback:`, `Keep Editing`, `Levels Menu`, `Next Level →` (English) vs. `Meister-Ernährer!`, `Kalorisches Gleichgewicht`, `Perfekt (±50 kcal)`, `Makellose Kalorienkontrolle!...` (German).

---

### Session 5: Level 2 (`Makronährstoff-Harmonie`) — Unclear Objective & Live Pass/Fail State

18. **Unclear Level Objective & Missing Live Pass/Fail Indicator on the Main Screen:**
    - **Observation:** Upon advancing to Level 2, the player did not clearly understand what the new objective was or whether their current meal plan already satisfied the Level 2 criteria before clicking `Finish _Grade Meal Plan`.
    - **Root Causes in UI:**
      1. **No Level Briefing / New Rule Intro:** Clicking `Next Level →` silently swaps the level header without a brief introduction explaining *what changed* (e.g., "New Rule Unlocked: Now your Carbs, Protein, and Fat percentages must match your Sport Profile!").
      2. **No Target Ranges or Pass/Fail Checkmarks in the Sidebar Macro Boxes:** On the main screen's right sidebar, `Macronutrient Split (% of energy)` shows `Carbs 54.2% (284g)`, `Protein 12.4% (65g)`, `Fat 33.3% (76g)` in static yellow/green/blue boxes, **without showing the target ranges (`55% C`, `12–18% P`, `27–33% F`) or whether each macro is currently passing (`✓`) or failing (`✗`)**!
      3. **Only Single-Level Constraint Shown in Grading Modal:** Notice the grading modal header says `Level 2 Constraint:` (singular) and only lists `Makronährstoff-Harmonie`, hiding the Level 1 Calorie constraint row even though both are evaluated.
    - **UX Impact:** The player is flying blind on the main workspace—they only see the explicit `✓ Makronährstoff-Harmonie (Target: 55% C • 12–18% P • 27–33% F)` checklist item *after* clicking `Finish _Grade Meal Plan`.

---

### Session 6: Level 3 (`Ballaststoff-Basis`) — Auto-Pass & Prescriptive Feedback on Already-Passed Level

19. **Trivial Auto-Pass Across Consecutive Levels Without Player Action:**
    - **Observation:** Because the player added `240g Haferflocken` + fruits + walnuts in Level 1 (`42.1 g` fiber total), advancing to Level 2 and then Level 3 allowed immediately clicking `Finish _Grade Meal Plan` and winning 3 stars (`★★★ Biochemische Meisterschaft!`) without making a single change or understanding the new constraint first.
    - **UX Impact:** When a meal plan already satisfies the next level's constraint, clicking `Next Level →` followed immediately by `Grade` feels like clicking through empty dialogs rather than solving a puzzle.

20. **Coach Feedback Gives a "How-To Fix" Hint Even When the Player Scored 3 Stars:**
    - **Observation:** In the Level 3 grading dialog (`42.1 g / Target: ≥ 35.0 g`, `★★★ Biochemische Meisterschaft!`), the `💡 Nutrition Coach's Feedback:` box says:
      > *"Integriere Haferflocken, Hülsenfrüchte, Beeren und gedämpften Brokkoli."*
      Even though the player *already* has `240g Haferflocken` in their plan and passed with `42.1 g`!
    - **UX Impact:** For Levels 3+, the grading modal displays the static level hint ("Include oats, legumes...") as "Coach's Feedback" instead of actual praise/feedback on passing the constraint.

---

### Session 7: Level 4 (`Gesättigte Fettsäuren & Lipidqualität`) — Unhelpful Failure Feedback & Missing Culprit Attribution

21. **Inverted Coach Feedback Logic (Helpful Hint Shown Only When You WIN, Useless Generic Text Shown When You FAIL!):**
    - **Observation:** When the player *failed* Level 4 (`9.1% Ges. Fett` vs. `< 8% Ges. Fett`, receiving `★☆☆ Teilerfolg`), the `💡 Nutrition Coach's Feedback:` box displayed a completely generic, unhelpful sentence:
      > *"Kalorien passen, aber die biochemische Hauptbedingung dieses Levels ist noch nicht erfüllt."*
      Whereas in Level 3 (when the player *passed*), it displayed the actionable food tip!
    - **UX Impact:** The conditional logic for Coach Feedback is backwards! When a player fails a level and asks *"What do I have to do?"*, they get a generic boilerplate string instead of the level's actionable nutrition advice (e.g., *"Reduce butter/saturated animal fats and swap for olive oil, walnuts, or avocado"*).

22. **No Attribution of Which Ingredients Are Causing the Constraint Failure:**
    - **Observation:** The error says `9.1% Ges. Fett • 66.6% Ungesättigt — Zu viel gesättigte Fettsäuren` (Target: `< 8% Ges. Fett`), while the meal card lists 7 ingredients (`Birnen`, `Ananas`, `Haferflocken`, `Hühnerei`, `Butter`, `Apfel`, `Walnüsse`), each showing only `kcal` (`72 kcal`, `322 kcal`, etc.).
    - **UX Impact:** Neither the Meal Card rows nor the Ingredient Explorer (which didn't even show Saturated Fat in its main macro grid!) tells the player *which* ingredients in their plan are contributing the most saturated fat (`Butter` and `Hühnerei`). The player has no visual clue which item to reduce or swap.

23. **1 Star (`Teilerfolg`) Unlocks `Next Level →` Even When the Level's Core Constraint Failed:**
    - **Observation:** Even though the Level 4 constraint failed (`✗ Gesättigte Fettsäuren & Fettqualität`), the player still earned `★☆☆ Teilerfolg` (because Calories were within target) and the green `Next Level →` button is active and enabled!
    - **UX Impact:** A player can click `Next Level →` through every single level in the game just by having `2,000 kcal` (1 star), bypassing the actual biochemical constraint of every level.

24. **Right Sidebar Horizontal Clipping / Overflow on Level 4:**
    - **Observation:** Look at the right-hand sidebar in the Level 4 screenshot:
      - Header title is cut off: `Level 4: Gesättigte Fettsäuren & Lipi`
      - Header subtitle is cut off: `Ges. Fett < 8% der kcal • Ungesättigt ≥ 65% der`
      - Daily Energy value is cut off: `2015 / ` (the `2000 kcal` part overflows off the right edge!)
      - Fat macro box is cut off: `Fat 33.3%` (the `(76g)` is cut off!)
    - **UX Impact:** Because the Level 4 title string (`Level 4: Gesättigte Fettsäuren & Lipidqualität`) has no `elide` or `wrapMode` constraint inside the sidebar layout, it forces the internal column wider than the sidebar card, clipping the right edge of every single widget inside the right sidebar!

---

### Session 8: Level 4 Victory — Stale Live Sidebar State & Confirmation of Inverted Coach Hint

25. **Confirmed Inverted Coach Hint (`Ersetze Butter durch natives Olivenöl extra, Nüsse und Lachs` Shown Only *After* Removing Butter!):**
    - **Observation:** Once the player removed `Butter`, reduced `Hühnerei`, increased `Walnüsse`, and passed Level 4 (`5.2% Ges. Fett • 75.4% Ungesättigt`, 3 stars), the `💡 Nutrition Coach's Feedback:` finally revealed:
      > *"Ersetze Butter durch natives Olivenöl extra, Nüsse und Lachs."*
    - **UX Impact:** Complete confirmation of #21—the exact hint the player needed while failing (`Replace butter with extra virgin olive oil, nuts, and salmon`) is hidden during failure and displayed only after the player has already removed the butter and won 3 stars!

26. **Right Sidebar Live Constraint Box Does Not Update Reactively Until Grading (Stale `9.1% Ges. Fett` in Sidebar):**
    - **Observation:** Look at the right-hand sidebar behind the Level 4 victory modal:
      - `Daily Energy` updated to `2049 /` and `Macronutrient Split` updated to `59.0% C / 12.1% P / 28.9% F`.
      - And inside the modal, the Level 4 constraint shows `✓ 5.2% Ges. Fett • 75.4% Ungesättigt`.
      - **However**, the orange box in the right-hand sidebar *still* displays the old stale failure state: `⚠️ Gesättigte Fettsäuren & Fettqualität — Aktuell: 9.1% Ges. Fett • 66.6% Ungesättigt (Zu viel gesättigte Fettsäuren)`!
    - **UX Impact:** The live constraint widget in the right sidebar is not bound reactively to ingredient portion changes (or isn't refreshing when ingredients are edited/deleted), which also explains why it feels impossible to tell on the main screen whether your edits have fixed the level constraint!

---

### Session 9: Levels Overview Menu & Level 5 (`Essenzielle Fettsäuren (Ω-6 : Ω-3)`)

27. **Confusing `← Shopping List Planner` Button Caption in Top Bar (plus Duplicate `← Back` Button):**
    - **Observation:** When viewing the `Nutrition Quest` Levels screen, the top navigation bar button says `← Shopping List Planner` (and right below it in the main area is a second `← Back` button).
    - **User / UX Impact:** The user isn't building a "Shopping List"—they are building a **Meal Plan / Daily Nutrition Plan** (`Meal Planner` or `Tagesplan`). Furthermore, having both `← Shopping List Planner` and `← Back` stacked right on top of each other is redundant.

28. **Cryptic, Mathematical & Unexplained Presentation of Level 5 Objective (`Ω-6 : Ω-3 ≤ 4:1 • Omega-3 ≥ 2.5g`):**
    - **Observation:** Even for a player who understands the biology of the Omega-6 : Omega-3 ratio and inflammation, the UI presents the goal purely as compressed mathematical symbols:
      - Main banner: `🎯 Omega-6 : Omega-3 ≤ 4:1 • Omega-3 ≥ 2.5g`
      - Right sidebar card: `Ziel: ≤ 4:1 Verhältnis • Ω-3 ≥ 2.5g` / `Aktuell: 16.7:1 Verhältnis • 0.53g Ω-3` / `Hohes Ω-6 Verhältnis`
      - Levels screen card: `🐟 Ω-6 : Ω-3 ≤ 4:1 • Omega-6 : Omega-3 ≤ 4:1 • Omega-3 ≥ 2.5g` (notice it prints the ratio rule **twice** in a row on the Level card, and the `🐟` emoji renders as a broken `[]` tofu box on the Levels card!).
    - **Why It Is Hard to Understand & Act On:**
      1. **No Plain-Language Explanation or Biological Context:** There is no short briefing card or expandable "Why this matters & how to solve it" panel explaining the physiological goal and which foods are high in Omega-3 (e.g., salmon, flaxseeds/Leinsamen, chia seeds) vs. high in Omega-6 (e.g., walnuts/sunflower oil—ironically `100g Walnüsse` from Level 4 is high in LA/Omega-6 in this database, driving the `16.7:1` ratio!).
      2. **Missing Absolute Omega-6 Grams:** The status says `16.7:1 Verhältnis • 0.53g Ω-3`, but never shows how many grams of **Omega-6** are currently in the plan (roughly `8.85g Ω-6` vs `0.53g Ω-3`). Without seeing both numbers (`8.9g Ω-6 vs. 0.53g Ω-3`), a ratio like `16.7:1` feels abstract and hard to debug.
      3. **Two Separate Sub-Goals Mashed Into One String:** Level 5 actually has **two** distinct requirements (`1. Get at least 2.5g of Omega-3` AND `2. Keep Omega-6 at most 4× your Omega-3`), which should be displayed as two clear progress bars or two separate checklist lines rather than `≤ 4:1 Verhältnis • Ω-3 ≥ 2.5g`.

---

### Session 10: Ingredient Explorer Category Row & Icon Regressions

29. **Category Filter Row in Ingredient Explorer Cannot Be Scrolled / Flicked on Desktop (and Clips Overflowing Pills):**
    - **Observation:** The category filter row (`🌐 All`, `🌾 Grains & Cereals`, `🥦 Vegetables`, `🍎 Fruits`, `🫘 Legumes`, `🥜 Nuts & Seeds`, `🥩 Meat & Poultry`, `🐟 Fish & Seafood`, `🥛 Dairy`, and a half-clipped 10th pill on the right edge) overflows horizontally, and trying to mouse-drag/flick or wheel-scroll it does not work!
    - **UX Impact:** Categories beyond `🥛 Dairy` (like `Oils & Fats` / `Herbs` / etc.) are completely unreachable on Desktop! Instead of a non-scrollable single-line horizontal strip, category pills should use a wrapping `Flow` layout (or include horizontal scroll/arrow controls and wheel handler).

30. **Blank Gray Squares Instead of Icons for Most Items in Ingredient Explorer:**
    - **Observation:** In this screenshot of `Ingredient Explorer` (`Biskotten`, `Brokkoli`, `Brombeeren`, `Buchweizen`, `Bulgur`, `Butter`, `Buttermilch`, `Bärlauch`, `Camembert`, `Cashewkerne`), **every single item has a blank empty gray square** on the left instead of an emoji/icon!
    - **UX Impact:** If an ingredient doesn't have a specific icon mapped, rendering a large empty gray placeholder box looks like a broken image asset. Either every category should provide a fallback category icon (`🥦` for `Gemüse`, `🍎` for `Obst`, `🌾` for `Getreide`, `🥛` for `Milchprodukte`, `🫒` for `Öle & Fette`), or the empty box should be omitted.

---

### Session 11: Nutrient Sorting in Ingredient Explorer (`Sortierung: Omega-3`)

31. **Low Discoverability of the Nutrient Sort Control (`Sortierung: Name ⌄`):**
    - **Observation:** The player wished for a way to sort by nutrient (Omega-3) and didn't notice the `Sortierung: [Name ⌄]` control tucked into the top-right corner next to the wide search bar until prompted.
    - **UX Improvement Idea:**
      - Make the Sort dropdown much more visually prominent, or even better: **auto-suggest or pre-select the current level's target nutrient** (e.g., a quick button `"⚡ Sort by Level 5 Goal: Omega-3"` or opening the Explorer Directly from the Level 5 constraint box already sorted by `Omega-3` descending!).

32. **Sorting by a Nutrient (`Omega-3`) Doesn't Display That Nutrient's Value on the Ingredient Rows!**
    - **Observation:** Look at the list when sorted by `Omega-3` (`▼` descending) under `🥜 Nuts & Seeds`:
      - The rows show `Chiasamen` (`486 kcal | C:42 P:17 F:31`), `Kürbiskerne` (`534 kcal | C:29 P:18 F:42`), `Leinsamen` (`534 kcal | C:29 P:18 F:42`), `Mohn`, `Sonnenblumenkerne`...
      - **None of the rows display their `Omega-3` value!** They still only show `kcal` and `C / P / F` on the right!
      - Worse, you cannot tell where the high-Omega-3 seeds (`Chiasamen`, `Leinsamen`) end and the zero-Omega-3 / high-Omega-6 seeds (`Sonnenblumenkerne`, `Erdnussbutter`) begin without clicking and expanding every single item AND expanding `Minerals & Vitamins (per 100g)` inside it!
    - **UX Impact:** Whenever the user sorts by a specific nutrient (`Omega-3`, `Fiber`, `Iron`, `Calcium`, `Zinc`, `Vitamin C`, etc.), each row in the list **must dynamically display a badge with that sorted nutrient's value** (e.g. `🐟 Omega-3: 17.8 g / 100g` alongside `Omega-6: 5.8 g`).
    - **Database Suspicion (`Kürbiskerne` Ranked #2 for Omega-3 Above `Leinsamen`?):** Notice `Kürbiskerne` is ranked #2 in `Omega-3` above `Leinsamen` (flaxseeds) and shares identical macro numbers (`534 kcal, C:29 P:18 F:42`) with `Leinsamen`! That strongly suggests a database entry error in `speis.db` where `Kürbiskerne` copied `Leinsamen`'s nutritional profile!

---

### Session 12: Level 5 Completion — Confirmed Non-Reactive Sidebar Constraint & Biological Data Errors

33. **Confirmed Critical Bug: Right Sidebar Level Constraint Widget Never Updates Live When Editing Meal Plan (Ref #26):**
    - **Observation:** The player added `50g Chiasamen` and rebalanced `Haferflocken` to `200g`. The calories (`2020 / 2000 kcal`) and macros (`54.8% C / 11.5% P / 33.7% F`) updated immediately in the right sidebar, **but the Level 5 constraint box in the right sidebar stayed frozen at `⚠️ Aktuell: 16.7:1 Verhältnis • 0.53g Ω-3 (Hohes Ω-6 Verhältnis)`**!
    - The player thought they were still failing the fat goal and only discovered they had actually passed (`0.5:1 Verhältnis • 18.25g Ω-3`) after clicking `Finish _Grade Meal Plan`!
    - **Root Cause:** The QML binding for the sidebar level constraint status calls `gameLevelManager.checkLevelConstraint(...)` without a reactive property dependency on `shoppingListModel`'s data changes (unlike `totalCalories` which is a `Q_PROPERTY` with a `NOTIFY` signal).

34. **Biochemical Data Errors in `speis.db` & Level 5 Coach Hint (`Kürbiskerne` & `Chiasamen` / `Walnüsse`):**
    - **Observation:**
      1. Look at the Level 5 Coach Feedback: *"Setze auf Lachs, Kürbiskerne, Walnüsse und Leinsamen."* — **Pumpkin seeds (`Kürbiskerne`) are NOT an Omega-3 source** in real life (they have ~20g Omega-6 and ~0.1g Omega-3, a ~170:1 Omega-6:Omega-3 ratio!).
      2. Even worse, adding just `50g Chiasamen` jumped total Omega-3 from `0.53g` to **`18.25g Ω-3`** (`35.4g Ω-3 per 100g` of Chia seeds, which is higher than the total fat content `31g` of Chia seeds!).
      3. Meanwhile, `100g Walnüsse` before adding Chia only gave `0.53g Ω-3` total for the whole meal plan (whereas real walnuts have ~`9.0g ALA Omega-3 per 100g`!).
    - **UX / Scientific Impact:** Both the database values for Omega-3/Omega-6 in `speis.db` (`Walnüsse`, `Chiasamen`, `Kürbiskerne`) and the Level 5 German hint recommending `Kürbiskerne` are biochemically inaccurate.

---

### Session 13: Level 6 (`Natrium-Kalium-Pumpe`) — Contradictory Failure Status (`✗` + `"Membranpotential balanciert"`)

35. **Contradictory Failure Status Message on Level 6 (`✗` Red Error Box Says `"Membranpotential balanciert"`!):**
    - **Observation:** Look closely at the red `✗ Natrium-Kalium-Pumpe` constraint row (and the orange sidebar box):
      - Target: `K ≥ 3.500mg • Na < 2.000mg • Na:K < 1.0`
      - Current: `2130mg K • 488mg Na • Verhältnis 0.39`
      - Status subtitle in bright red text: **`Membranpotential balanciert`** ("Membrane potential balanced"!)
    - **Root Cause:** In `GameLevelManager::checkLevelConstraint` for Level 6, the status message only checks `if (naKRatio >= 1.0)` or `if (na >= 2000)`, and falls through to `"Membranpotential balanciert"` without checking `if (k < 3500)` (`Zu wenig Kalium (< 3.500mg)`)!
    - **UX Impact:** The player sees a red `✗` failure box whose explanation text literally says `"Membranpotential balanciert"` (everything is balanced!), leaving them to manually compare `2130mg K` vs `K ≥ 3.500mg` to figure out why it failed!
    - Meanwhile, `💡 Nutrition Coach's Feedback` again shows the useless generic boilerplate (`"Kalorien passen, aber die biochemische Hauptbedingung dieses Levels ist noch nicht erfüllt."`).

---

### Session 14: Recipe & Meal Library (`Karottencremesuppe`) — Critical Bug Where Recipe Ingredients Go Into the Wrong Meal Card!

36. **Critical Functional Bug: Adding a Recipe Creates an EMPTY Meal Card (`0 kcal`) and Dumps Its 7 Ingredients Into the First (`Food`) Card!**
    - **Observation:** Look at the first screenshot after adding `Karottencremesuppe` (`89 kcal`, 7 ingredients) at `13:00` from the `Recipe & Meal Library`:
      - A new meal card `🥗 Karottencremesuppe` (`13:00`) was created at the bottom, **but it is completely EMPTY (`0 kcal • C:0g P:0g F:0g`, *"No ingredients added yet..."*)**!
      - Meanwhile, the collapsed `Food` (`12:00`) card at the top jumped from `2020 kcal` (7 items) to **`2109 kcal` (`13 items`)**!
      - That means `addRecipeToPlan` created the `Karottencremesuppe` meal header at `13:00`, **but inserted all of `Karottencremesuppe`'s ingredients into the `Food (12:00)` meal card instead of the newly created `Karottencremesuppe (13:00)` meal card!**
    - **UX Impact:** Severe bug! Adding any recipe leaves its newly created card empty (`0 kcal`) while secretly merging all of its ingredients into whatever meal card was first/active!

37. **Recipe & Meal Library UI Flaws:**
    - **Duplicate Ingredients in Recipe Definition:** In `Karottencremesuppe` (`Ingredients Breakdown (7 items)`), **`Wasser 200 g`** is listed **twice** in a row (`Wasser 200 g`, `Wasser 200 g`).
    - **Wrong Search Placeholder Text:** The search box inside `Recipe & Meal Library` says `🔍 Add ingredient...` instead of `🔍 Search recipes...` (`Rezept suchen...`).
    - **Clipped Category Strip on Right Edge:** Just like in the Ingredient Explorer (#29), the recipe category filter row clips the 6th category pill (`🍽️ Hau...` for `Hauptgerichte`) on the right edge without wrapping or scrolling!
    - **No Micronutrient / Level-Constraint Preview on Recipes:** When playing Level 6 (`Kalium ≥ 3500mg, Natrium < 2000mg`), the recipe preview only shows `Carbs: 13g`, `Protein: 4g`, `Fat: 2g`, `Fiber: 3g`—it doesn't show Potassium (`K`) or Sodium (`Na`) (or the active level's target metric), so the player can't tell before adding a soup whether it's high in Potassium or loaded with Sodium (`Salz`).

---

### Session 15: Save / Export Dialog (`Save Slots` & `Files _Backup`)

38. **Ambiguous Relationship Between `Autosaved in Browser` and `📤 Export File (.json)` in `Files _Backup` Tab:**
    - **Observation:** The file download *did* work, but the user was unsure whether `📤 Export File (.json)` downloaded their full current savegame or only an older "autosave" state because the `Files _Backup` tab prominently features a card at the top reading `🟢 Autosaved in Browser (Last autosaved: 2026-10-25T07:02:54)` right above `📤 Export File (.json)`.
    - **UX Impact:** Placing `📤 Export File (.json)` directly beneath the `Autosaved in Browser` status box makes it look like you are exporting the *autosave snapshot* (which had an older timestamp `07:02:54` than the slot saved at `07:04`!) rather than exporting the live, full current state of the game. Visually separating "Browser Autosave Status" from "Manual File Export / Import (.json)" (and updating the autosave timestamp whenever a manual save/export happens) will remove this doubt.

39. **Another Mnemonic Underscore Typo (`💾 Files _Backup`) & 100% Untranslated Dialog:**
    - **Observation:**
      - Just like `⭐ Finish _Grade Meal Plan` (#2), the second tab in `Save / Export` says **`💾 Files _Backup`** (an underscore `_` where `&` or `/` was intended: `Files & Backup`).
      - Both `📤 Export File (.json)` and `📥 Import File (.json)` use the **exact same outbox icon** (`📤` orange tray with arrow) instead of distinct Export (`📤` / `⬇️`) vs. Import (`📥` / `📂`) icons.
      - The entire `Save / Export` modal is 100% in English despite German language selection.
      - In the `Autosaved in Browser` box, the timestamp uses raw ISO format (`2026-10-25T07:02:54` with a `T`) whereas the Saved Slot uses a cleaner space-separated format (`2026-10-25 07:04`).

---

### Session 16: Deep Inspection of Exported Savegame JSON (3 Smoking-Gun Data/Model Bugs!)

40. **Smoking Gun #1 — Duplicate Meal ID (`"id": "meal_102"`) Causes Recipe Ingredients to Land in the First Meal (Confirmed in UI):**
    - **Observation:** In the exported JSON (and confirmed by expanding the `Food` meal card in the UI):
      - Meal 0 (`"title": "Food"`, `"time": "12:00"`) has **`"id": "meal_102"`**.
      - Meal 1 (`"title": "Karottencremesuppe"`, `"time": "13:00"`) ALSO has **`"id": "meal_102"`**!
      - Expanding `Food` confirms that all of `Karottencremesuppe`'s ingredients were dumped directly into `Food`!
    - **Root Cause:** Because both meals were assigned the exact same `"id": "meal_102"`, when `addRecipeToPlan` adds ingredients by `mealId` (`"meal_102"`), the lookup matches the **first** meal with `"id": "meal_102"` (`Food`) and dumps all 7 soup ingredients into `Food`, leaving `Karottencremesuppe` with `"items": []`!

41. **Smoking Gun #2 — Recipe Ingredients Have `0` for ALL Micronutrients (`id: 0`, `potassium: 0`, `sodium: 0`, `calcium: 0`):**
    - **Observation:** Look at the recipe items added from `Karottencremesuppe` (`Karotte`, `Wasser`, `Milch`, `Joghurt`, `Petersilie`, `Salz`):
      - Every single one has `"id": 0` and **`0` for every single micronutrient** (`"potassium": 0`, `"sodium": 0`, `"calcium": 0`, `"magnesium": 0`, `"iron": 0`, `"vitaminA": 0`, `"vitaminC": 0`)!
      - Even `"Salz"` (`0.25g`) has `"sodium": 0`! Even `"Karotte"` (`100g`) has `"vitaminA": 0` and `"potassium": 0`! Even `"Milch"` (`60g`) has `"calcium": 0`!
    - **Root Cause & UX Impact:** Recipes in the Recipe Library are only storing macro estimates (`calories`, `carbs`, `protein`, `fat`, `fiber`) without resolving their ingredients against `speis.db` for micronutrients! That means **adding any recipe from the Recipe Library contributes `0` micronutrients to Levels 4–24**, making recipes completely useless (and actively harmful by taking up calories without providing minerals/vitamins) in every micronutrient level!

42. **Smoking Gun #3 — Corrupt Database Row for `Walnüsse` (`id: 88`):**
    - **Observation:** Look at `Walnüsse` (`id: 88`) in the exported JSON:
      - `"carbsPer100g": 47.6` (real walnuts have ~7–14g carbs, not 47.6g!)
      - `"sodiumPer100g": 446` (real walnuts have `2 mg` sodium, not `446 mg`!)
      - `"omega3Per100g": 0`, `"omega6Per100g": 0`, `"magnesiumPer100g": 0`, `"zincPer100g": 0`, `"copperPer100g": 0`, `"vitaminEPer100g": 0`!
    - **Root Cause:** Several foods in `speis.db` (like `Walnüsse` `id: 88`) have completely missing or scrambled nutrient columns.

---

### Session 17: Adding a Workout (`Endurance Cardio`) — Two Huge Desync Bugs!

43. **Workout Modal Desync: `Duration (minutes)` Shows `15` While `45m` Pill Is Highlighted and Preview Shows `-420 kcal` (45m), Then Adds `15 min` (`-140 kcal`)!**
    - **Observation:** Look at the `Workout` modal screenshot:
      - The **`Duration (minutes)`** text field says **`15`**.
      - Directly below it, the **`45m`** preset button is highlighted in bright blue (`15m` is unselected!).
      - The **`🔥 Energy Burned`** preview box shows **`-420 kcal`** (`-63g Carbs`, `-5g Protein`, `-16g Fat`), which is the calculation for **45 minutes** (`560 kcal/h × 0.75h = 420 kcal`)!
      - Yet when the user clicked **`+ Workout`**, the workout actually added to the plan (first screenshot) is **`15 min`** and **`-140 kcal`** (`-21g carbs`, `-2g protein`, `-5g fat`)!
    - **Root Cause:** Typing `15` into the `Duration (minutes)` text field updated the text field's `text`, which `+ Workout` reads on submit (`15 min`), **but did NOT update the internal `durationMinutes` property** (`45`) that drives the highlighted preset pill (`45m`) and the `-420 kcal` preview box (or vice versa)!

44. **Right Sidebar `Daily Energy (Calories)` Bar Does Not Reactively Update When Adding a Workout (`109 kcal over target` vs `2140 kcal` / `2280 kcal` target!):**
    - **Observation:** Look at the right-hand sidebar after adding a first `-140 kcal` workout and then a second `-140 kcal` workout:
      - The athlete pill inside the sidebar updated to: `👤 Test Athlete • 2000 (Base) + 280 (2 WO) = 2280 kcal`.
      - **However**, the `Daily Energy (Calories)` bar right above it is STILL frozen at **`2109 / 2000 kcal` (`▲ 109 kcal over target`)** instead of **`2109 / 2280 kcal` (`171 kcal remaining`)**!
      - And in the top navigation bar, the pill still says `👤 Test Athlete (2000 kcal` instead of `2280 kcal`.
    - **Root Cause:** Either `targetCalories` in `GameLevelManager` is NOT bound to `shoppingListModel.totalWorkoutCalories` (or `shoppingListModel` is not updating `gameLevelManager.targetCalories = baseCalories + totalWorkoutCalories` when workouts are added/edited/removed), OR the `Daily Energy` progress bar is hardcoded to bind to `baseCalories` (`2000`) instead of `baseCalories + totalWorkoutCalories` (`2280`)!
    - **UX Impact:** Adding workouts claims to increase your daily caloric need (`2000 (Base) + 280 (2 WO) = 2280 kcal`), but the actual energy progress bar and level grading target completely ignore the workout burn!

---

### Session 18: Levels Overview Screen After Adding Workouts — Contradictory Calorie Math & Overlapping Header Badges

45. **Contradiction Between Main Sidebar (`+109 kcal over 2000`) and Levels Screen (`-171 kcal under 2280`, While Still Printing `Zielwert: 2,000 kcal`!):**
    - **Observation:** Look at the `Level 1: Kalorisches Gleichgewicht` card on the Levels screen after adding the two `-140 kcal` workouts (`280 kcal` total burn):
      - The red failure badge inside the Level 1 card says: **`⚠️ 2109 kcal (-171)`** — which means `GameLevelManager::checkAllLevelConstraints` **DID** compare `2109 kcal` against `2280 kcal` (`2109 - 2280 = -171 kcal`)!
      - **Yet** right above that red badge on the exact same Level 1 card, the subtitle still says **`⚡ 2,000 kcal • Zielwert: 2,000 kcal (±50 kcal)`**!
      - And back on the main workspace right sidebar (#44), the `Daily Energy` progress bar compared `2109 kcal` against **`2,000 kcal` (`▲ 109 kcal over target`)**!
    - **Root Cause:** The C++ constraint evaluator (`checkAllLevelConstraints`) uses `baseCalories + workoutCalories` (`2280 kcal`), **whereas** the main sidebar `Daily Energy` bar and the static level descriptions (`Zielwert: 2,000 kcal`) only display `baseCalories` (`2000 kcal`)! So one screen tells the player they are `+109 kcal TOO HIGH`, while the Levels screen tells them they are `-171 kcal TOO LOW`!

46. **Overlapping Badges in `Nutrition Quest` Header (`⭐ 16 / 72 Stars` Collides With `⚠️ 2 Regel-Verletzungen`):**
    - **Observation:** Look at the top-left header of the Levels screen (`⚔️ Nutrition Quest`):
      - The gold **`⭐ 16 / 72 Stars`** pill and the red **`⚠️ 2 Regel-Verletzungen`** badge are drawn right on top of each other, making both unreadable!
    - **Root Cause:** Missing layout spacing or overlapping anchoring (`anchors.left` / fixed `x` offset) in the Levels view header row.

47. **Confirmed Calorie Desync in Grading Modal vs. Sidebar (`-171 kcal diff` in Modal vs. `▲ 109 kcal over target` in Sidebar):**
    - **Observation:** In the Level 6 grading modal after adding the two `-140 kcal` workouts, `Calorie Accuracy` shows **`92.5% (-171 kcal diff)`** (evaluating against `2280 kcal`), while the right sidebar directly behind the modal simultaneously says **`▲ 109 kcal over target`** (evaluating against `2000 kcal`)!

---

### Session 19: Level 6 Victory — Sub-1g Decrement Bug (`0.25g` → `10g`) & Unrealistic `per 100g` Spice Ranking (`50g Kurkuma`)

48. **Clicking `-` on a Sub-10g Ingredient (`Salz: 0.25g`) Jumps UP to `10g` Instead of Decrementing or Removing:**
    - **Observation:** `Salz` had an amount of `0.25g` (from the soup recipe). When the user clicked the **`-`** button to reduce it, the amount **jumped UP from `0.25g` to `10g`**!
    - **Root Cause:** The `-` button logic in `CozyShoppingList.qml` likely uses a minimum floor or step clamp such as `Math.max(10, amount - step)` (or `amount > 10 ? amount - 10 : 10`), so clicking `-` on any value `< 10g` (`0.25g`, `3g`, `4g`) forces the value *up* to `10g`!

49. **Sorting by Nutrient (`per 100g`) Ranks Spices/Powders (`Kurkuma`) #1 and Proposes Unrealistic `50g` Portions:**
    - **Observation:** When sorting the `Ingredient Explorer` by `Kalium` (Potassium), **`Kurkuma`** (turmeric powder, ~`2,525 mg K / 100g`) ranks at the top because sorting is strictly `per 100g` rather than `per realistic serving`. Worse, the Ingredient Explorer's preset portion buttons (`50g`, `100g`, `150g`, `200g`, `250g`) and default portion size proposed **`50g` of Kurkuma** (nobody eats 50g of dry turmeric powder in a meal!). And inside the meal card, `Kurkuma` (`3g`) still shows `-100`/`+100` (`-1...`/`+1...`) step buttons!
    - **UX / Domain Improvement:**
      1. Spices, herbs, and condiments (`Kräuter`, `Gewürze`, `Salz`) should have realistic serving sizes (`1g–5g`) and small step buttons (`-1g` / `+1g`, and preset buttons like `1g, 2g, 5g, 10g` in the Explorer).
      2. Nutrient sorting in the Ingredient Explorer should either sort by **nutrient per typical serving** (or offer a toggle `"Per 100g" vs "Per Serving"`) so spices don't dominate the top of every mineral ranking.

50. **Sidebar Constraint Card Remains Frozen Even Across Multiple Grading Cycles (`2130mg K` in Sidebar vs `4299mg K` in Victory Modal):**
    - **Observation:** Even after adding `Banane (300g)`, `Spinat (300g)`, and `Kurkuma (3g)` and passing Level 6 with **`4299mg K • 904mg Na • Verhältnis 0.36`** (`★★★ Biochemische Meisterschaft!`), the right-hand sidebar behind the modal *still* shows the frozen state from 15 minutes ago: **`Aktuell: 2130mg K • 488mg Na • Verhältnis 0.39`**!

---

## Summary & Prioritized Action Plan (50 Findings Across Tier I)

### Priority 1: Critical Functional & Reactivity Bugs (Broken Core Mechanics)
1. **Duplicate Meal ID (`"id": "meal_102"`) on Recipe Addition (#36, #40):** Adding a recipe creates an empty meal card (`0 kcal`) and dumps all ingredients into the first meal card because both meals receive the same `meal_102` ID.
2. **Recipe Ingredients Have `0` Micronutrients (#41):** Pre-packaged recipes in `Recipe & Meal Library` insert items with `id: 0` and `0` for all minerals/vitamins/fatty acids, making recipes useless in Levels 4–24.
3. **Frozen Right-Sidebar Level Constraint Card (#26, #33, #50):** The sidebar constraint status box never updates reactively when ingredients are added, edited, or deleted.
4. **Workout Calorie Target Desync (#44, #45, #47):** Adding workouts updates `totalWorkoutCalories` (and fails Level 1 on the Levels screen against `2280 kcal`), but the main sidebar `Daily Energy` progress bar and level subtitles remain stuck at `baseCalories` (`2000 kcal`).
5. **Workout Modal Duration Desync (#43):** Typing `15` in the duration input leaves `45m` highlighted and `-420 kcal` displayed in the preview, while submitting `15 min` (`-140 kcal`).
6. **Sub-10g `-` Button Jump Bug (#48):** Clicking `-` on `0.25g Salz` jumps the amount UP to `10g` due to a `Math.max(10, ...)` floor.
7. **Inverted Coach Feedback Logic (#20, #21, #25):** Actionable food hints are only displayed when the player *passes* a level (`3 stars`), while failing a level displays a useless generic boilerplate string.
8. **Level 6 Contradictory Failure Status (#35):** Failing Level 6 due to low Potassium (`< 3500mg K`) displays a red `✗` box with the success text `"Membranpotential balanciert"`.
9. **Corrupt Database Entries in `speis.db` (#32b, #34, #42):**
   - `Walnüsse` (`id: 88`) has `0g` Omega-3, `47.6g` Carbs, and `446mg` Sodium.
   - `Chiasamen` (`id: 107`) has `35.6g` Omega-3 per 100g (exceeding its `30.7g` total fat!).
   - `Kürbiskerne` copied `Leinsamen`'s macros/Omega-3 and is falsely recommended in the Level 5 Coach Hint.
10. **Barcode Scanner Preset Failure (`Network error: Not Found`) & Missing Camera Viewfinder (#13):** Built-in barcode presets fail in WebAssembly, and there is no camera scanner widget.

### Priority 2: Layout, Clipping & Visual Bugs
11. **Right Sidebar Horizontal Overflow (#24):** Long German level titles (`Level 4: Gesättigte Fettsäuren & Lipidqualität`) stretch the sidebar column and clip the right edge of `Daily Energy` and `Fat` macro boxes.
12. **Top Header Athlete Button Overlap (#7):** Names longer than ~7 chars (`Test Athlete`) overflow the pill and collide with `🔬 Ingredient Explorer`.
13. **Overlapping Header Badges on Levels Screen (#46):** `⭐ 16 / 72 Stars` and `⚠️ 2 Regel-Verletzungen` render directly on top of each other.
14. **SpinBox Width Clipping in Ingredient Explorer (#10):** `Portion Size (g)` text box only shows the last digit (`0`).
15. **Truncated Step Increment Pills (`-1...` / `+1...`) in Meal Card (#14):** `±10` and `±100` step buttons are cut off with ellipses.
16. **Unreachable Clipped Category Pills in Ingredient Explorer & Recipe Library (#29, #37):** Horizontal category rows clip overflowing categories (`Oils & Fats`, `Hauptgerichte`) and cannot be scrolled or flicked on Desktop.
17. **Clipped Bottom Text in Athlete Profile Modal (#8):** The gram-breakdown box at the bottom of the Profile modal is vertically cut off.
18. **Blank Gray Icon Placeholders & Inconsistent Icons (#15, #30):** Most ingredients show empty gray squares in the Explorer or no icon in the Meal Card, and `🐟` renders as `[]` on the Level 5 card (#28).
19. **Mnemonic Underscore Typos (`⭐ Finish _Grade Meal Plan`, `💾 Files _Backup`) & Duplicate Stars (`⭐⭐⭐` + `★★★`) (#2, #17, #39).**
20. **Hardcoded `50% C • 25% P • 25% F` Subtitle in Grading Modal (#16):** Contradicts both the athlete's sport profile and actual meal macros.

### Priority 3: Localization, Onboarding & Core UX Architecture (COMPLETED ✅)
21. **Incomplete German Localization ("Denglish" UI) (#6, #17, #39):** ✅ RESOLVED. Added dynamic runtime dictionary cross-lookup (`initGermanDictionary`) in `LanguageManager`, wired dynamic `QTranslator` installation/removal on language change, persisted language selection directly in WebAssembly `localStorage` (preventing reload loss), and localized all dialogs, chips, headers, and evaluation cards.
22. **Zero-State Onboarding & Level Briefings (#1, #18, #28):** ✅ RESOLVED. Created `OnboardingDialog.qml` with a 3-step introductory walkthrough (Athlete Profile & BMR, Daily Meal Planning, Level Progression & Biochemical Mastery) triggered automatically on first launch and accessible via `❓ Einführung / Guide` in the top bar. Added live pass/fail sub-goal checklists in `GoalSummaryCard.qml` with dynamic target tracking and multi-criteria breakdown (e.g. Level 5 Omega-3 and Ω-6 : Ω-3 ratio).
23. **Meal-Scoped Ingredient Selection (#11):** ✅ RESOLVED. Added `🔬 Explorer` button directly inside each meal card header in `CozyShoppingList.qml` that opens `IngredientExplorerDialog.qml` pre-scoped to that specific meal (`openForMeal(mealIndex)`).
24. **Show Sorted Nutrient Value on Explorer Rows & Realistic Spice Portions (#31, #32a, #49):** ✅ RESOLVED. Added dynamic sorted nutrient badges on each ingredient card (`🐟 Ω-3: 17.80g`, `⚡ K: 2525mg`, etc.) in `IngredientExplorerDialog.qml`. Added `🔬 Passende Zutaten im Explorer finden` direct shortcut from the sidebar level constraint card. Added spice/condiment detection for realistic serving sizes (`1g–5g`), fine-grained `1g` step increments, and quick-add chips `[1, 2, 5, 10, 15]g`.
25. **Gate `Next Level →` Behind Passing the Level's Core Constraint (#23):** ✅ RESOLVED. Gated level progression so `1 Star (Teilerfolg)` (calories-only) no longer unlocks subsequent levels when the biochemical constraint fails (`unlocked = (lvlNum == 1) || (prevStars >= 2)`). Gated `Next Level →` button in `EvaluationResultDialog.qml` behind `root.resultData.stars >= 2 && Boolean(root.resultData.primaryConstraintMet)`, with a clear warning callout explaining why the next level is locked.

### Results Screen Feature: Chrono-Nutrient Intake & Timing Dual Chart (COMPLETED ✅)
- **Interactive Chrono-Nutrient Timeline (`EvaluationResultDialog.qml` & `GameLevelManager`):**
  - Displays meal timing and nutrient intake across a 24-hour timeline (`00:00` to `24:00`).
  - **Dual Visualization:**
    - **Bar Plot (Meal Intake):** Vertical bars positioned at each meal's scheduled time, with meal icons and amount badges.
    - **Superimposed Line Plot (Cumulative Total):** Smooth curve showing cumulative daily intake with gradient fill and data point markers.
    - **Target Reference Line:** Dashed horizontal indicator displaying daily requirement thresholds.
    - **Diurnal Target Windows:** Shaded active time windows for timing-critical levels (e.g., Level 14 Evening Mg window ≥ 18:00, Level 13 Morning Ca window < 13:00, Level 19 Post-workout PepT1 window, Level 20 Pre-workout energy window).
  - **Quick Nutrient Switcher:** Interactive pill selector to toggle chart between active level goal, calories, protein, carbs, fat, fiber, magnesium, calcium, omega-3, and potassium.
  - **Contextual Timing Feedback:** Dynamic badge summarizing whether the nutrient was consumed inside optimal chronobiological windows.




