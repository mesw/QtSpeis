import sqlite3
import sys
from pathlib import Path

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

EXPECTED_AUSTRIAN_FOODS = [
    "Schweinefleisch", "Kalbfleisch", "Faschiertes", "Bergkäse", "Tiroler Graukäse",
    "Saibling", "Kren", "Bärlauch", "Sauerkraut", "Rotkraut", "Preiselbeeren",
    "Maroni", "Kürbiskernöl", "Mohn", "Weizengrieß", "Knödelbrot", "Kümmel",
    "Liebstöckel", "Majoran"
]

EU_ALLERGEN_CODES = {
    "GLUTEN", "CRUSTACEANS", "EGGS", "FISH", "PEANUTS",
    "SOYBEANS", "MILK", "NUTS", "CELERY", "MUSTARD",
    "SESAME", "SULPHITES", "LUPIN", "MOLLUSCS"
}

def validate_database(db_path: Path) -> bool:
    print("=" * 70)
    print(f"VALIDIERE DATENBANK: {db_path}")
    print("=" * 70)

    if not db_path.exists():
        print(f"[FAIL] FEHLER: Datenbankdatei {db_path} existiert nicht!")
        return False

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    all_passed = True

    # --------------------------------------------------------------------------
    # Check 1: Bilingual & Uniqueness
    # --------------------------------------------------------------------------
    print("\n[Check 1] Zweisprachigkeit (DE & EN) und Eindeutigkeit...")
    cur.execute("SELECT id, name_de, name_en FROM foods WHERE name_de IS NULL OR trim(name_de) = '' OR name_en IS NULL OR trim(name_en) = ''")
    empty_names = cur.fetchall()
    if empty_names:
        print(f"  [FAIL] FEHLER: {len(empty_names)} Lebensmittel mit leerem deutschen oder englischen Namen: {empty_names[:5]}")
        all_passed = False
    else:
        print("  [OK] Alle Lebensmittel besitzen gültige deutsche und englische Namen.")

    cur.execute("SELECT name_de, COUNT(*) FROM foods GROUP BY lower(name_de) HAVING COUNT(*) > 1")
    dupes_de = cur.fetchall()
    if dupes_de:
        print(f"  [FAIL] FEHLER: Duplikate bei name_de gefunden: {dupes_de}")
        all_passed = False
    else:
        print("  [OK] Eindeutigkeit der Lebensmittelnamen (name_de) gewährleistet.")

    # --------------------------------------------------------------------------
    # Check 2: 100% Nährwert-Abdeckung & Makro-Integrität
    # --------------------------------------------------------------------------
    print("\n[Check 2] Nährwert-Abdeckung (100% Nährwerte in food_nutrients)...")
    cur.execute("SELECT count(*) FROM foods")
    total_foods = cur.fetchone()[0]

    cur.execute("""
        SELECT f.id, f.name_de, f.name_en 
        FROM foods f 
        LEFT JOIN food_nutrients fn ON f.id = fn.food_id 
        WHERE fn.food_id IS NULL
    """)
    missing_nutrients = cur.fetchall()

    if missing_nutrients:
        print(f"  [FAIL] FEHLER: {len(missing_nutrients)} von {total_foods} Lebensmitteln haben KEINE Nährwerte:")
        for fid, nde, nen in missing_nutrients:
            print(f"     - [ID {fid}] {nde} ({nen})")
        all_passed = False
    else:
        cur.execute("SELECT count(DISTINCT food_id), count(*) FROM food_nutrients")
        distinct_foods, total_variants = cur.fetchone()
        print(f"  [OK] Perfekte Nährwertabdeckung: {distinct_foods}/{total_foods} Lebensmittel haben Nährwerte ({total_variants} Zubereitungsvarianten).")

    cur.execute("SELECT food_id, preparation_state, calories_kcal, protein_g, carbs_g, fat_g FROM food_nutrients WHERE calories_kcal < 0 OR protein_g < 0 OR carbs_g < 0 OR fat_g < 0")
    negative_macros = cur.fetchall()
    if negative_macros:
        print(f"  [FAIL] FEHLER: Negative Nährwerte gefunden: {negative_macros[:5]}")
        all_passed = False
    else:
        print("  [OK] Makronährstoffe sind konsistent und nicht negativ.")

    # --------------------------------------------------------------------------
    # Check 3: Fettsäuren-Subprofile & Lipid-Integrität
    # --------------------------------------------------------------------------
    print("\n[Check 3] Fettsäuren-Subprofile (fat_saturated_g, omega_3_g, omega_6_g)...")
    cur.execute("PRAGMA table_info(food_nutrients)")
    cols = {r[1] for r in cur.fetchall()}
    required_fat_cols = {"fat_saturated_g", "fat_monounsaturated_g", "fat_polyunsaturated_g", "omega_3_g", "omega_6_g", "cholesterol_mg"}
    required_level_nutrients = {"vitamin_a_ug", "thiamine_mg", "phenylalanine_g", "tyrosine_g", "methionine_g"}
    missing_nut_cols = (required_fat_cols | required_level_nutrients) - cols

    if missing_nut_cols:
        print(f"  [FAIL] FEHLER: Folgende Nährwertspalten fehlen in food_nutrients: {missing_nut_cols}")
        all_passed = False
    else:
        print(f"  [OK] Alle geforderten Fettsäuren- und Level-Spalten ({', '.join(required_fat_cols | required_level_nutrients)}) sind vorhanden.")

        cur.execute("""
            SELECT food_id, preparation_state, fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g, omega_3_g, omega_6_g, cholesterol_mg
            FROM food_nutrients
            WHERE fat_saturated_g < 0 OR fat_monounsaturated_g < 0 OR fat_polyunsaturated_g < 0
               OR omega_3_g < 0 OR omega_6_g < 0 OR cholesterol_mg < 0
        """)
        negative_fats = cur.fetchall()
        if negative_fats:
            print(f"  [FAIL] FEHLER: Negative Fettsäuren-Werte gefunden: {negative_fats[:5]}")
            all_passed = False
        else:
            print("  [OK] Fettsäuren-Subkolumnen sind konsistent und nicht negativ.")

        # Prüfe signifikante Omega-3 Quellen (z.B. Lachs, Leinsamen, Saibling)
        cur.execute("""
            SELECT f.name_de, fn.fat_g, fn.omega_3_g, fn.omega_6_g 
            FROM food_nutrients fn
            JOIN foods f ON f.id = fn.food_id
            WHERE f.name_de IN ('Lachs', 'Leinsamen', 'Saibling', 'Walnüsse', 'Kürbiskernöl')
              AND fn.preparation_state = 'raw'
        """)
        omega_sources = cur.fetchall()
        print(f"  [INFO] Wichtige Omega-Fettsäuren-Quellen verifiziert:")
        for nde, fat, o3, o6 in omega_sources:
            print(f"     - {nde}: Fett: {fat}g | Omega-3: {o3}g | Omega-6: {o6}g")

    # --------------------------------------------------------------------------
    # Check 4: Biochemische Integrität & Constraints
    # --------------------------------------------------------------------------
    print("\n[Check 4] Biochemische Integrität & Constraint-Konformität...")
    cur.execute("PRAGMA table_info(food_biochem)")
    fb_cols = {r[1] for r in cur.fetchall()}
    required_biochem_cols = {"is_nightshade", "is_seed", "fodmap_level", "is_fermented", "has_phosvitin", "phytate_mg", "oxalate_mg"}
    missing_fb_cols = required_biochem_cols - fb_cols
    if missing_fb_cols:
        print(f"  [FAIL] FEHLER: Folgende Biochemie-Spalten fehlen: {missing_fb_cols}")
        all_passed = False
    else:
        print(f"  [OK] Alle Level-Guide Biochemie-Spalten ({', '.join(required_biochem_cols)}) sind vorhanden.")

    cur.execute("""
        SELECT f.id, f.name_de, f.gi_class, fb.iron_type, fb.polyphenol_level, fb.phytate_level, fb.oxalate_level, fb.fodmap_level
        FROM foods f
        JOIN food_biochem fb ON f.id = fb.food_id
        WHERE f.gi_class NOT IN ('low', 'medium', 'high')
           OR fb.iron_type NOT IN ('heme', 'non_heme', 'none')
           OR fb.polyphenol_level NOT BETWEEN 0 AND 2
           OR fb.phytate_level NOT BETWEEN 0 AND 2
           OR fb.oxalate_level NOT BETWEEN 0 AND 2
           OR fb.fodmap_level NOT IN ('low', 'medium', 'high')
    """)
    invalid_biochem = cur.fetchall()
    if invalid_biochem:
        print(f"  [FAIL] FEHLER: Ungültige Biochemie-Werte gefunden: {invalid_biochem}")
        all_passed = False
    else:
        print("  [OK] Alle biochemischen Werte und Enums liegen in den gültigen Wertebereichen.")

    cur.execute("SELECT count(*) FROM foods f LEFT JOIN food_biochem fb ON f.id = fb.food_id WHERE fb.food_id IS NULL")
    missing_biochem = cur.fetchone()[0]
    if missing_biochem > 0:
        print(f"  [FAIL] FEHLER: {missing_biochem} Lebensmittel ohne food_biochem Datensatz!")
        all_passed = False
    else:
        print("  [OK] 100% der Lebensmittel haben biochemische Datensätze.")

    # --------------------------------------------------------------------------
    # Check 5: FlavorDB & Rezept-Pairing Integrität
    # --------------------------------------------------------------------------
    print("\n[Check 5] FlavorDB Molekular- & Rezept-Aromagraph...")
    cur.execute("SELECT count(*) FROM flavor_pairings")
    pairing_count = cur.fetchone()[0]
    if pairing_count == 0:
        print("  [FAIL] FEHLER: Keine Aroma-Pairings berechnet!")
        all_passed = False
    else:
        cur.execute("SELECT count(DISTINCT food_id_a) FROM flavor_pairings")
        foods_with_pairings = cur.fetchone()[0]
        print(f"  [OK] {pairing_count} gerichtete Aroma-Kanten vorhanden ({foods_with_pairings} Zutaten mit Pairing-Profilen).")

    cur.execute("SELECT count(*) FROM flavor_pairings WHERE jaccard_score < 0.0 OR jaccard_score > 1.0")
    invalid_jaccard = cur.fetchone()[0]
    if invalid_jaccard > 0:
        print(f"  [FAIL] FEHLER: {invalid_jaccard} ungültige Jaccard-Scores außerhalb von [0.0, 1.0]!")
        all_passed = False
    else:
        print("  [OK] Alle Jaccard-Scores sind mathematisch valide im Intervall [0.0, 1.0].")

    # --------------------------------------------------------------------------
    # Check 6: Saisonalität (Exakt 12 Monate pro Lebensmittel)
    # --------------------------------------------------------------------------
    print("\n[Check 6] Saisonalität (12 Monate Vollständigkeit)...")
    cur.execute("""
        SELECT food_id, count(DISTINCT month) 
        FROM food_seasonality 
        GROUP BY food_id 
        HAVING count(DISTINCT month) != 12
    """)
    incomplete_seasonality = cur.fetchall()
    if incomplete_seasonality:
        print(f"  [FAIL] FEHLER: {len(incomplete_seasonality)} Lebensmittel haben keine vollständigen 12 Monate Saisonalität!")
        all_passed = False
    else:
        print(f"  [OK] 100% der Lebensmittel ({total_foods}) haben vollständige 12-Monats-Saisonalitätsprofile.")

    # --------------------------------------------------------------------------
    # Check 7: Allergen-Integrität (EU-14 Standard)
    # --------------------------------------------------------------------------
    print("\n[Check 7] Allergen-Integrität (food_allergens nach EU-14)...")
    cur.execute("SELECT count(*) FROM food_allergens")
    allergen_count = cur.fetchone()[0]
    if allergen_count == 0:
        print("  [FAIL] FEHLER: Keine Allergeneinträge in food_allergens!")
        all_passed = False
    else:
        cur.execute("SELECT DISTINCT allergen_code FROM food_allergens")
        present_codes = {r[0] for r in cur.fetchall()}
        invalid_codes = present_codes - EU_ALLERGEN_CODES
        if invalid_codes:
            print(f"  [FAIL] FEHLER: Ungültige Allergen-Codes gefunden: {invalid_codes}")
            all_passed = False
        else:
            print(f"  [OK] {allergen_count} Allergenzuweisungen über {len(present_codes)} EU-Allergenklassen vorhanden.")

        cur.execute("""
            SELECT f.name_de FROM foods f 
            WHERE f.category = 'Milchprodukte' 
              AND f.id NOT IN (SELECT food_id FROM food_allergens WHERE allergen_code = 'MILK')
        """)
        missing_milk = cur.fetchall()
        if missing_milk:
            print(f"  [FAIL] WARNUNG/FEHLER: Milchprodukte ohne MILK-Allergen: {missing_milk}")
            all_passed = False
        else:
            print("  [OK] Alle Milchprodukte sind korrekt mit dem Allergen 'MILK' markiert.")

    # --------------------------------------------------------------------------
    # Check 8: Prüfung der österreichischen Spezialitäten
    # --------------------------------------------------------------------------
    print("\n[Check 8] Prüfung der österreichischen Spezialitäten...")
    missing_austrian = []
    for food_name in EXPECTED_AUSTRIAN_FOODS:
        cur.execute("SELECT id FROM foods WHERE name_de = ?", (food_name,))
        row = cur.fetchone()
        if not row:
            missing_austrian.append(food_name)
        else:
            fid = row[0]
            cur.execute("SELECT count(*) FROM food_nutrients WHERE food_id = ?", (fid,))
            if cur.fetchone()[0] == 0:
                print(f"  [FAIL] {food_name} (ID {fid}) hat keine Nährwerte!")
                all_passed = False
            cur.execute("SELECT count(*) FROM food_biochem WHERE food_id = ?", (fid,))
            if cur.fetchone()[0] == 0:
                print(f"  [FAIL] {food_name} (ID {fid}) hat keine Biochemie-Daten!")
                all_passed = False
            cur.execute("SELECT count(*) FROM food_seasonality WHERE food_id = ?", (fid,))
            if cur.fetchone()[0] != 12:
                print(f"  [FAIL] {food_name} (ID {fid}) hat unvollständige Saisonalität!")
                all_passed = False
            cur.execute("SELECT count(*) FROM flavor_pairings WHERE food_id_a = ?", (fid,))
            if cur.fetchone()[0] == 0:
                print(f"  [FAIL] {food_name} (ID {fid}) hat keine Flavor-/Rezept-Pairings!")
                all_passed = False

    if missing_austrian:
        print(f"  [FAIL] Folgende österreichische Spezialitäten fehlen in der Datenbank: {missing_austrian}")
        all_passed = False
    else:
        print(f"  [OK] Alle {len(EXPECTED_AUSTRIAN_FOODS)} österreichischen Spezialitäten sind vollständig in allen Tabellen integriert.")

    # --------------------------------------------------------------------------
    # Check 9: Level Guide Progression (24 Core Levels & 12 Hero Modifiers)
    # --------------------------------------------------------------------------
    print("\n[Check 9] Level Guide Progression (24 Core Levels & 12 Hero Modifiers)...")
    cur.execute("SELECT count(*) FROM game_levels")
    level_count = cur.fetchone()[0]
    if level_count != 24:
        print(f"  [FAIL] FEHLER: Erwartet 24 Level in game_levels, gefunden: {level_count}")
        all_passed = False
    else:
        cur.execute("SELECT count(*) FROM game_levels WHERE title IS NULL OR target_formula IS NULL OR tolerance_json IS NULL")
        invalid_levels = cur.fetchone()[0]
        if invalid_levels > 0:
            print(f"  [FAIL] FEHLER: {invalid_levels} Level mit unvollständigen Metadaten!")
            all_passed = False
        else:
            print(f"  [OK] Alle 24 Progression-Level aus LEVEL_GUIDE.md vollständig in game_levels hinterlegt.")

    cur.execute("SELECT count(*) FROM hero_modifiers")
    hero_count = cur.fetchone()[0]
    if hero_count != 12:
        print(f"  [FAIL] FEHLER: Erwartet 12 Hero-Modifier in hero_modifiers, gefunden: {hero_count}")
        all_passed = False
    else:
        print(f"  [OK] Alle 12 Hero-Challenges (H1-H12) vollständig in hero_modifiers hinterlegt.")

    conn.close()

    print("\n" + "=" * 70)
    if all_passed:
        print("[SUCCESS] ALLE CHECKS ERFOLGREICH BESTANDEN!")
        print("=" * 70)
        return True
    else:
        print("[FAILED] VALIDIERUNG FEHLGESCHLAGEN: Mindestens ein Check ist fehlgeschlagen.")
        print("=" * 70)
        return False

if __name__ == "__main__":
    db_file = Path("speis.db")
    if len(sys.argv) > 1:
        db_file = Path(sys.argv[1])
    success = validate_database(db_file)
    sys.exit(0 if success else 1)
