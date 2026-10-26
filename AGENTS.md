# QtSpeis — Development Rules & Architectural Invariants

## 1. Responsive QML UI Guidelines (Mobile vs. Desktop)
* **Narrow Screen Detection (`isNarrow`):** Always test and respect low screen widths (`width < 560px` or `width < 420px`).
* **Two-Line List Item Layout:** In narrow mode, ingredient rows must split across two lines:
  * **Line 1 (Top):** Ingredient name (left-aligned), calories, and delete button (right-aligned).
  * **Line 2 (Bottom):** Portion controls/spinners right-aligned to avoid clipping.
* **Emoji & Button Labels:**
  * **Mobile / Narrow Mode:** Display **only the icon/emoji** (icon-only mode) to conserve horizontal space.
  * **Desktop Mode:** Display **emoji + text label** (e.g. `✨ Reset Sample`).
  * **Never duplicate emojis** on button text (e.g., avoid `📋 📋 Plan`).
* **Collapsible Content:** High-density lists (e.g., meal cards) must support collapsible state with individual fold toggles and global collapse/expand all.
* **Contextual Guidance:** Replace static placeholder text with active level objectives and dynamic task summaries.

## 2. Safety & Destructive Action Guardrails
* **No Unconfirmed Deletions:** Destructive operations (`clearPlan`, `loadSamplePlan`, `overwriteSlot`, `deleteSlot`) must always prompt via a confirmation dialog before executing.
* **In-Memory & Storage Preservation:** Provide named savegame slots in local persistence alongside file export/import so users can test configurations without risking progress loss.

## 3. Dual-Target Build & Verification
Every code change modifying C++ or QML must be compiled and verified for both targets:
1. **Desktop MinGW 64-bit:**
   ```powershell
   cmd.exe /c "set PATH=C:\Qt\Tools\mingw1310_64\bin;C:\Qt\6.8.3\mingw_64\bin;%PATH% && ninja -C build_desktop"
   ```
2. **WebAssembly (Emscripten Single-Threaded Release):**
   ```powershell
   cmd.exe /c "call C:\Users\MiCHi\Downloads\emsdk\emsdk_env.bat && ninja -C build\WebAssembly_Qt_6_8_3_single_threaded-Release appQtSpeis"
   ```
* **No Busy-Polling on Long Links:** Emscripten linking and optimization can take 1–3 minutes. Use asynchronous timers (`schedule`) to check status rather than busy-polling.

## 4. Biochemical Domain & Personalization Rules
* **Calorie-% vs. Gram-%:** Never conflate Calorie percentages with Gram percentages:
  $$\text{Carbs/Protein (g)} = \frac{\text{kcal} \times \%}{4}, \quad \text{Fat (g)} = \frac{\text{kcal} \times \%}{9}$$
* **Sport Profile Customization:** Level 2 macro goals must evaluate dynamically against the user's active sport profile (default: 55% C / 12–18% P / 27–33% F for Ausdauersport mit hohem Krafteinsatz).
* **Fully Editable Recipes:** All pre-packaged recipes when loaded into a meal plan must remain 100% editable ingredient-by-ingredient.

## 5. Backlog & Scope Protocol
* When design questions, architectural edge cases, or potential features are deferred, record them immediately in [`TODO_LATER.md`](TODO_LATER.md) with thorough technical and biochemical descriptions.
