import os
import re
import glob
import json
import sqlite3
import math
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional, Any

# ==============================================================================
# 0. KONFIGURATION & DATEIPFADE
# ==============================================================================
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("SPEIS_DATA_DIR", BASE_DIR.parent / "Speis" / "datasets"))
SPEIS_DIR = BASE_DIR.parent / "Speis"

PATH_SR_LEGACY = DATA_DIR / "fda_nal_usda_gov__fdc-datasets" / "FoodData_Central_sr_legacy_food_json_2018-04.json"
PATH_FOUNDATION = DATA_DIR / "fda_nal_usda_gov__fdc-datasets" / "foundationDownload.json"
DIR_FLAVORDB = DATA_DIR / "FlavorDB"
PATH_OPENFOODFACTS = DATA_DIR / "food.parquet"
PATH_SEASONALITY_JSON = BASE_DIR / "data" / "saisonaliaet.json"
CATALOG_PATH = BASE_DIR / "data" / "master_foods.json"
RECIPES_PATH = SPEIS_DIR / "recipes_collection.py"
DB_OUTPUT_PATH = BASE_DIR / "speis.db"

# Offizielle EU-14 Allergene nach VO (EU) Nr. 1169/2011
EU_ALLERGENS = {
    "GLUTEN": ("Glutenhaltiges Getreide", "Cereals containing gluten"),
    "CRUSTACEANS": ("Krebstiere", "Crustaceans"),
    "EGGS": ("Eier", "Eggs"),
    "FISH": ("Fische", "Fish"),
    "PEANUTS": ("Erdnüsse", "Peanuts"),
    "SOYBEANS": ("Sojabohnen", "Soybeans"),
    "MILK": ("Milch und Laktose", "Milk and dairy products"),
    "NUTS": ("Schalenfrüchte (Nüsse)", "Tree nuts"),
    "CELERY": ("Sellerie", "Celery"),
    "MUSTARD": ("Senf", "Mustard"),
    "SESAME": ("Sesamsamen", "Sesame seeds"),
    "SULPHITES": ("Schwefeldioxid und Sulfite", "Sulphur dioxide and sulphites"),
    "LUPIN": ("Lupinen", "Lupin"),
    "MOLLUSCS": ("Weichtiere", "Molluscs")
}

# ==============================================================================
# 1. HILFSDATEN: SUPPLEMENTS, CONSTRAINTS & REZEPTE
# ==============================================================================
IMSB_HERB_COMPATIBILITY = [
    ("Faschiertes", ["Bohnenkraut", "Koriander", "Liebstöckel", "Lorbeerblatt", "Majoran", "Oregano", "Petersilie", "Rosmarin", "Thymian"]),
    ("Wildgerichte", ["Essig", "Koriander", "Lorbeerblatt", "Majoran", "Rosmarin", "Wacholder", "Thymian"]),
    ("Geflügelgerichte", ["Basilikum", "Estragon", "Kerbel", "Majoran", "Petersilie", "Rosmarin", "Salbei", "Thymian", "Wacholder"]),
    ("Fischgerichte", ["Bohnenkraut", "Dille", "Essig", "Estragon", "Kerbel", "Lorbeerblatt", "Majoran", "Oregano", "Petersilie", "Rosmarin", "Salbei", "Thymian", "Wacholder"]),
    ("Gemüsegerichte", ["Basilikum", "Bohnenkraut", "Borretsch", "Dille", "Estragon", "Fenchel", "Kerbel", "Kümmel", "Liebstöckel", "Petersilie", "Rosmarin", "Thymian"]),
    ("Topfenaufstriche", ["Basilikum", "Bohnenkraut", "Borretsch", "Dille", "Estragon", "Kerbel", "Kümmel", "Liebstöckel", "Petersilie", "Thymian"])
]

CURATED_SUPPLEMENTS = [
    ("Sunday Natural", "Eisenbisglycinat + Vitamin C", "Kapsel", "IRON_STACK", "Eisenbisglycinat (el. Fe)", 25.0, "mg", "Nüchtern mit 500mg Vit C für DMT1-Reduktion Fe3+ -> Fe2+"),
    ("Sunday Natural", "Vitamin C Time Release / Ascorbinsäure", "Kapsel", "VITAMIN_C", "Ascorbinsäure", 500.0, "mg", "Cofaktor für DMT1-Eisenaufnahme und Prolylhydroxylase"),
    ("Sunday Natural", "Kollagenpeptide Hydrolysat (Typ I & III)", "Pulver", "COLLAGEN_PRE_WO", "Kollagenhydrolysat", 10.0, "g", "30-60 Min vor Belastung mit 200mg Vit C; koffeinfrei halten"),
    ("Sunday Natural", "Vitamin D3 5000 IE + K2 MK-7 100µg", "Tropfen", "D3_K2_FAT", "Cholecalciferol + MK-7", 5000.0, "IE", "Mit fettreicher Mahlzeit (>=10g Fett) für SR-BI/NPC1L1"),
    ("Doppelherz", "Omega-3 Seefischöl 2000 (EPA/DHA)", "Kapsel", "OMEGA3_FAT", "EPA + DHA Triglyceride", 2000.0, "mg", "Mit fetthaltiger Mahlzeit für Gallensäure-Emulgierung"),
    ("Pure Encapsulations", "Zinkpicolinat + Kupferglycinat Balance (15:1)", "Kapsel", "ZINC_COPPER_MEAL", "Zink (15mg) + Kupfer (1mg)", 15.0, "mg", "Stöchiometrie 15:1 verhindert Metallothionein-Kupfersperre"),
    ("Sunday Natural", "L-Citrullin (Rein / Fermentiert)", "Pulver", "CITRULLINE_PRE_WO", "L-Citrullin", 6.0, "g", "30-60 Min vor Workout nüchtern (System y+ NO-Synthese)"),
    ("Pure Encapsulations", "Beta-Alanin", "Kapsel", "BETA_ALANINE_PRE_WO", "Beta-Alanin", 1.6, "g", "Carnosin-Puffer; Pre-Workout Einnahme"),
    ("Doppelherz", "Kreatin-Monohydrat (Creapure)", "Pulver", "CREATINE_POST_WO", "Kreatin-Monohydrat", 5.0, "g", "Post-Workout mit Carbs/Protein für Insulin-SLC6A8-Upregulation"),
    ("Sunday Natural", "Magnesium-Malat (ATP-Support)", "Kapsel", "MG_MALATE_PM", "Magnesiummalat (el. Mg)", 150.0, "mg", "Nachmittags oder Post-Workout für Citratzyklus"),
    ("Pure Encapsulations", "Ubiquinol CoQ10 100mg", "Kapsel", "COQ10_FAT", "Ubiquinol", 100.0, "mg", "Mit fetthaltigem Snack am Nachmittag"),
    ("Sunday Natural", "L-Tryptophan 500mg", "Kapsel", "TRYPTOPHAN_SLEEP", "L-Tryptophan", 500.0, "mg", "Nüchtern 30-60 Min vor Schlaf; >=2h Abstand zu BCAAs/Protein (LAT1)"),
    ("Pure Encapsulations", "Magnesiumglycinat", "Kapsel", "MG_GLYCINATE_SLEEP", "Magnesiumbisglycinat (el. Mg)", 200.0, "mg", "Abends vor dem Schlafen; konkurriert nicht an LAT1"),
    ("Sunday Natural", "Bio Flohsamenschalen (Psyllium Husks)", "Pulver", "PSYLLIUM_FIBER", "Plantago ovata Schalen", 5.0, "g", "Mit 400ml Wasser; 90-120 Min Abstand zu allen Supplement-Stacks")
]

TIMING_CONSTRAINTS = [
    ("IRON_STACK", "CALCIUM_HIGH", "SEPARATION", 120, None, 1, 1.0, "Calcium (>=300mg) blockiert DMT1 und Ferroportin (Hallberg et al., 1991; Lynch, 2000)."),
    ("IRON_STACK", "CAFFEINE_POLYPHENOL", "SEPARATION", 150, None, 1, 1.0, "Polyphenole/Tannine in Kaffee & Tee bilden unlösliche Eisen-Chelate (-60 bis -90% Resorption; Hurrell et al., 1999)."),
    ("IRON_STACK", "ZINC_COPPER_MEAL", "SEPARATION", 120, None, 1, 0.8, "Hohe Einzeldosen Fe und Zn (Fe:Zn > 2:1) konkurrieren an DMT1 und ZIP-Transportern (Whittaker, 1998)."),
    ("COLLAGEN_PRE_WO", "WORKOUT", "BEFORE", 30, 60, 1, 1.0, "Kollagenpeptide + Vit C 30-60 Min vor mechanischer Belastung maximieren Prolin-Einbau in Sehnen (Shaw et al., 2017)."),
    ("COLLAGEN_PRE_WO", "CAFFEINE_POLYPHENOL", "SEPARATION", 150, None, 1, 1.0, "Koffein hemmt das Enzym Prolidase; OPCs/Tannine fällen prolinreiche Peptide aus (Donejko et al., 2014)."),
    ("CITRULLINE_PRE_WO", "WORKOUT", "BEFORE", 30, 60, 1, 0.9, "Nüchterne Aufnahme über System y+ maximiert NO-Synthese vor Belastung (White, 1985)."),
    ("CREATINE_POST_WO", "CARB_PROTEIN_MEAL", "WITH_MEAL", 0, 45, 0, 0.8, "Insulinanstieg nach Kohlenhydrat/Protein-Mahlzeit reguliert SLC6A8-Kreatintransporter hoch (Burke, 2007)."),
    ("D3_K2_FAT", "FAT_MEAL", "WITH_MEAL", 0, 30, 1, 0.9, "Fettlösliche Vitamine D3, K2 und Omega-3 benötigen >=10g Fett für Mizellenbildung und SR-BI/NPC1L1 (Goncalves et al., 2015)."),
    ("TRYPTOPHAN_SLEEP", "BCAA_PROTEIN_MEAL", "SEPARATION", 120, None, 1, 1.0, "L-Tryptophan konkurriert mit großen neutralen Aminosäuren (BCAAs) am LAT1-Transporter der Blut-Hirn-Schranke (Fernstrom, 2013)."),
    ("PSYLLIUM_FIBER", "ANY_SUPPLEMENT", "SEPARATION", 90, None, 1, 1.0, "Viskose Gelmatrix von Flohsamenschalen verzögert und reduziert die Resorption von Mineralstoffen und Peptiden."),
    ("HEAVY_MEAL", "WORKOUT", "BEFORE", 180, 240, 1, 0.9, "Magenverweildauer beachten: Hauptmahlzeiten 3-4h vor Belastung, leichte Kost (Couscous) ca. 2h vorher (IMSB, 2016).")
]

IMSB_RECIPES_DATA = [
    ("Milchreis mit Pfirsich und Honig", "Frühstück", 1, 274, 10.2, 3.9, 48.8, [
        ("Magermilch", 225, "raw"), ("Reis", 30, "boiled"), ("Pfirsiche", 125, "canned"), ("Honig", 10, "raw"), ("Zimt", 1, "raw")
    ]),
    ("Warmer Hirsebrei mit Apfel", "Frühstück", 2, 515, 17.0, 17.0, 70.0, [
        ("Hirse", 100, "boiled"), ("Marillen", 40, "dried"), ("Walnüsse", 10, "raw"), ("Honig", 15, "raw"), ("Apfel", 150, "raw"), ("Zimt", 1, "raw")
    ]),
    ("Himbeer-Apfel-Müsli", "Frühstück", 1, 326, 11.6, 7.8, 49.3, [
        ("Haferflocken", 40, "raw"), ("Himbeeren", 100, "raw"), ("Apfel", 100, "raw"), ("Naturjogurt", 225, "raw"), ("Honig", 10, "raw")
    ]),
    ("Bananen-Himbeer-Shake", "Shake", 2, 255, 8.6, 4.1, 43.4, [
        ("Naturjogurt", 180, "raw"), ("Banane", 120, "raw"), ("Himbeeren", 100, "frozen"), ("Magermilch", 180, "raw"), ("Haferflocken", 30, "raw")
    ]),
    ("Tunfischaufstrich", "Aufstrich", 10, 48, 6.7, 1.8, 1.1, [
        ("Tunfisch", 150, "canned"), ("Frischkäse", 250, "raw"), ("Gurken", 60, "raw"), ("Schnittlauch", 15, "raw"), ("Rapsöl", 5, "raw"), ("Estragonsenf", 5, "raw")
    ]),
    ("Dilltopfen", "Aufstrich", 5, 37, 1.3, 1.3, 4.9, [
        ("Magertopfen", 250, "raw"), ("Dille", 15, "raw"), ("Rapsöl", 10, "raw")
    ]),
    ("Hering-Apfel-Salat", "Salat", 2, 172.7, 13.7, 7.2, 12.4, [
        ("Hering", 150, "raw"), ("Apfel", 100, "raw"), ("Gurken", 50, "raw"), ("Magertopfen", 50, "raw"), ("Buttermilch", 70, "raw"), ("Zwiebel", 25, "raw"), ("Dille", 5, "raw")
    ]),
    ("Karottencremesuppe", "Suppe", 1, 145, 5.2, 3.8, 21.0, [
        ("Karotten", 100, "boiled"), ("Magermilch", 60, "raw"), ("Naturjogurt", 20, "raw"), ("Petersilie", 5, "raw")
    ]),
    ("Zucchinicremesuppe", "Suppe", 1, 165, 4.5, 5.2, 24.0, [
        ("Zucchini", 200, "boiled"), ("Erdäpfel", 80, "boiled"), ("Zwiebel", 60, "cooked"), ("Knoblauch", 4, "cooked"), ("Rapsöl", 5, "raw"), ("Dille", 5, "raw")
    ]),
    ("Gemüseauflauf mit Penne", "Nudelgericht", 4, 512, 17.0, 20.0, 66.0, [
        ("Teigwaren", 300, "boiled"), ("Zucchini", 200, "cooked"), ("Karotten", 200, "cooked"), ("Spargel", 200, "cooked"), ("Paprika", 150, "cooked"), ("Parmesan", 30, "raw"), ("Magermilch", 500, "raw"), ("Butter", 30, "raw")
    ]),
    ("Tortilla Wrap mit Putenfleisch", "Fleischgericht", 1, 572, 43.4, 19.8, 53.1, [
        ("Weißbrot", 120, "raw"), ("Putenbrust", 100, "cooked"), ("Schnittkäse", 60, "raw"), ("Porree", 30, "cooked"), ("Paprika", 100, "cooked"), ("Paradeiser", 20, "cooked"), ("Olivenöl", 7, "raw")
    ]),
    ("Asiatische Hühnerbrust mit Basmatireis", "Fleischgericht", 1, 618.9, 38.7, 25.3, 58.2, [
        ("Hühnerbrust", 120, "cooked"), ("Reis", 50, "boiled"), ("Paprika", 50, "cooked"), ("Erbsen", 50, "cooked"), ("Sojabohnen", 50, "raw"), ("Rapsöl", 10, "raw"), ("Kurkuma", 3, "raw")
    ]),
    ("Couscous mit Gemüse (Pre-Workout)", "Vegetarisch", 1, 379, 12.2, 1.4, 77.3, [
        ("Couscous", 100, "boiled"), ("Melanzani", 250, "steamed"), ("Paradeiser", 300, "cooked"), ("Zitrusfrüchte", 20, "raw"), ("Petersilie", 10, "raw"), ("Rosmarin", 3, "raw")
    ]),
    ("Vegetarisches Chili", "Vegetarisch", 1, 402, 20.1, 12.9, 49.7, [
        ("Linsen", 100, "boiled"), ("Käferbohnen", 100, "boiled"), ("Zuckermais", 50, "boiled"), ("Zucchini", 100, "cooked"), ("Paradeiser", 150, "cooked"), ("Paprika", 150, "cooked"), ("Zwiebel", 50, "cooked"), ("Rapsöl", 10, "raw")
    ]),
    ("Erdäpfelpfanne mit Schafkäse", "Vegetarisch", 1, 382.3, 13.4, 18.6, 38.9, [
        ("Erdäpfel", 200, "boiled"), ("Paprika", 100, "cooked"), ("Porree", 40, "cooked"), ("Schafkäse", 20, "raw"), ("Schnittkäse", 20, "raw"), ("Rapsöl", 10, "raw"), ("Rosmarin", 3, "raw")
    ]),
    ("Gedünsteter Dorsch mit Brokkoli", "Fischgericht", 1, 243, 28.0, 10.4, 8.5, [
        ("Dorsch", 150, "steamed"), ("Brokkoli", 200, "steamed"), ("Rapsöl", 10, "raw"), ("Zitrusfrüchte", 15, "raw"), ("Dille", 5, "raw")
    ]),
    ("Pfirsich-Topfencreme", "Süßspeise", 1, 461, 36.6, 1.0, 70.9, [
        ("Magertopfen", 250, "raw"), ("Zitrusfrüchte", 100, "raw"), ("Pfirsiche", 150, "canned")
    ])
]

DAY_PLAN_TEMPLATES = [
    ("Variante A: Regenerationstag (Rest Day)", "NON_TRAINING", [
        ("06:30", "SUPPLEMENT", "Nüchtern-Eisen & Kollagen Stack", "10g Kollagen + 25mg Eisenbisglycinat + 500mg Vit C"),
        ("08:00", "MEAL", "Mahlzeit 1: Low-Ca Frühstück", "Eingeweichte Haferflocken, Eiklar-Spinat-Rührei, Heidelbeeren, Kürbiskerne, Zimt"),
        ("09:15", "DRINK", "Kaffee-Buffer (>2,5h nach Eisen/Kollagen)", "Espresso / Filterkaffee"),
        ("10:30", "MEAL_AND_SUPP", "Mahlzeit 2: AM Snack + Fettlösliches Stack", "Griechischer Joghurt, Walnüsse, Apfel + D3 (5000 IE), K2 (100µg), Omega-3 (2000mg)"),
        ("13:00", "MEAL_AND_SUPP", "Mahlzeit 3: Mittagessen + Zn/Cu", "Putenbrust, Süßkartoffelstampf, gedünsteter Brokkoli, Olivenöl + 15mg Zink / 1mg Kupfer"),
        ("15:00", "SUPPLEMENT", "Ballaststoff-Fenster (Flohsamenschalen)", "5g Flohsamenschalen in 400ml Wasser (2h nach Zn/Cu, 1h vor PM-Snack)"),
        ("16:00", "MEAL_AND_SUPP", "Mahlzeit 4: PM Energy Snack", "Reiswaffeln, Avocado, Putenbrust, Mandeln + 100mg CoQ10 + 150mg Mg-Malat"),
        ("19:00", "MEAL_AND_SUPP", "Mahlzeit 5: Anaboles Abendessen", "Wildlachsfilet, Quinoa, gebratener Spargel, Paprikasalat + 5g Kreatin + 250mg Vit C"),
        ("21:30", "SUPPLEMENT", "Night Stack (LAT1-Isolation)", "500mg L-Tryptophan + 200mg Magnesiumglycinat (nüchtern >2h nach Abendessen)")
    ]),
    ("Variante B: Frühes Morgentraining (06:30 - 07:45 Uhr)", "MORNING_WORKOUT", [
        ("06:00", "SUPPLEMENT", "Pre-WO Hydro & Tendon Stack (Stim-Free)", "10g Kollagen + 200mg Vit C + 6g L-Citrullin + Elektrolyte (koffeinfrei)"),
        ("06:30", "WORKOUT", "Trainingseinheit (60-75 Min)", "Morgentraining + Wasser"),
        ("08:00", "MEAL_AND_SUPP", "Mahlzeit 1: Post-WO Refuel Shake", "Whey Protein Isolat, reife Banane, Haferflocken, Honig + 5g Kreatin"),
        ("10:30", "SUPPLEMENT", "Verschobenes Nüchtern-Eisen-Fenster", "25mg Eisenbisglycinat + 500mg Vit C (2,5h nach Whey-Calcium, 1h vor Snack)"),
        ("11:30", "MEAL_AND_SUPP", "Mahlzeit 2: AM Snack + D3/K2/Omega-3", "Griechischer Joghurt, Walnüsse, Heidelbeeren + D3/K2/Omega-3 Stack"),
        ("14:00", "MEAL_AND_SUPP", "Mahlzeit 3: Mittagessen + Zn/Cu", "Putenbrust, Süßkartoffel, Dämpf-Brokkoli, Olivenöl + 15mg Zink / 1mg Kupfer"),
        ("15:15", "SUPPLEMENT", "Ballaststoff-Fenster (Flohsamenschalen)", "5g Flohsamenschalen in 400ml Wasser"),
        ("16:30", "MEAL_AND_SUPP", "Mahlzeit 4: PM Snack", "Reiswaffeln mit Mandelmus, Putenbrust, Gurke + 150mg Mg-Malat"),
        ("19:30", "MEAL", "Mahlzeit 5: Abendessen", "Wildlachs, Quinoa, Ofengemüse, Olivenöl"),
        ("22:00", "SUPPLEMENT", "Night Stack (LAT1-Isolation)", "500mg L-Tryptophan + 200mg Magnesiumglycinat")
    ]),
    ("Variante C: Feierabend-Training (17:30 - 18:45 Uhr)", "EVENING_WORKOUT", [
        ("07:00", "SUPPLEMENT", "Nüchtern-Eisen Stack", "25mg Eisenbisglycinat + 500mg Vit C"),
        ("08:15", "MEAL", "Mahlzeit 1: Low-Ca Frühstück", "Eingeweichte Haferflocken, Eiklar-Spinat-Rührei, Heidelbeeren"),
        ("09:30", "DRINK", "Kaffee-Buffer (>2,5h nach Eisen)", "Espresso / Filterkaffee"),
        ("10:30", "MEAL_AND_SUPP", "Mahlzeit 2: AM Snack + D3/K2/Omega-3", "Griechischer Joghurt mit Walnüssen + D3/K2/Omega-3 Stack"),
        ("13:00", "MEAL_AND_SUPP", "Mahlzeit 3: Mittagessen + Zn/Cu", "Rinderfilet oder Pute, Süßkartoffeln, Brokkoli, Olivenöl + 15mg Zink / 1mg Kupfer"),
        ("14:30", "SUPPLEMENT", "Ballaststoff-Fenster (Flohsamenschalen)", "5g Flohsamenschalen in 400ml Wasser (2h vor Pre-WO Stack)"),
        ("16:30", "MEAL_AND_SUPP", "Mahlzeit 4: Pre-WO Fuel & Collagen Stack", "Reiswaffel, kleine Banane + 10-15g Kollagen, 200mg Vit C, 6g L-Citrullin, 1.6g Beta-Alanin"),
        ("17:30", "WORKOUT", "Trainingseinheit (17:30 - 18:45 Uhr)", "Feierabend-Training + Wasser/Elektrolyte"),
        ("19:15", "MEAL_AND_SUPP", "Mahlzeit 5: Post-WO Festmahl", "Lachsfilet oder Steak, Reis/Süßkartoffel, Ofengemüse + 5g Kreatin + 150mg Mg-Malat"),
        ("21:45", "SUPPLEMENT", "Night Stack (LAT1-Isolation)", "500mg L-Tryptophan + 200mg Magnesiumglycinat")
    ])
]

# ==============================================================================
# 2. SCHEMA DEFINITION INKLUSIVE FETTSÄUREN-SUBKOLUMNEN
# ==============================================================================
def init_db_schema(conn: sqlite3.Connection):
    with conn:
        conn.executescript("""
        PRAGMA foreign_keys = ON;

        CREATE TABLE foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name_de TEXT NOT NULL UNIQUE,
            name_en TEXT NOT NULL,
            synonyms_at TEXT,
            flavordb_entity_id INTEGER,
            flavordb_alias TEXT,
            category TEXT NOT NULL,
            meal_role TEXT NOT NULL,
            gi_class TEXT NOT NULL CHECK(gi_class IN ('low', 'medium', 'high')),
            gastric_emptying_hours REAL NOT NULL,
            pre_workout_suitability INTEGER DEFAULT 1,
            is_common_dach INTEGER DEFAULT 1,
            off_dach_product_count INTEGER DEFAULT 0
        );

        CREATE TABLE food_allergens (
            food_id INTEGER NOT NULL,
            allergen_code TEXT NOT NULL,
            allergen_name_de TEXT NOT NULL,
            allergen_name_en TEXT NOT NULL,
            contains_status TEXT NOT NULL DEFAULT 'CONTAINS' CHECK(contains_status IN ('CONTAINS', 'MAY_CONTAIN', 'FREE')),
            PRIMARY KEY(food_id, allergen_code),
            FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE food_nutrients (
            food_id INTEGER NOT NULL,
            preparation_state TEXT NOT NULL,
            usda_fdc_id INTEGER,
            usda_description TEXT,
            calories_kcal REAL DEFAULT 0.0,
            protein_g REAL DEFAULT 0.0,
            carbs_g REAL DEFAULT 0.0,
            fat_g REAL DEFAULT 0.0,
            fat_saturated_g REAL DEFAULT 0.0,
            fat_monounsaturated_g REAL DEFAULT 0.0,
            fat_polyunsaturated_g REAL DEFAULT 0.0,
            omega_3_g REAL DEFAULT 0.0,
            omega_6_g REAL DEFAULT 0.0,
            cholesterol_mg REAL DEFAULT 0.0,
            fiber_g REAL DEFAULT 0.0,
            calcium_mg REAL DEFAULT 0.0,
            iron_mg REAL DEFAULT 0.0,
            zinc_mg REAL DEFAULT 0.0,
            copper_mg REAL DEFAULT 0.0,
            magnesium_mg REAL DEFAULT 0.0,
            manganese_mg REAL DEFAULT 0.0,
            potassium_mg REAL DEFAULT 0.0,
            sodium_mg REAL DEFAULT 0.0,
            vitamin_a_ug REAL DEFAULT 0.0,
            vitamin_c_mg REAL DEFAULT 0.0,
            vitamin_d_ug REAL DEFAULT 0.0,
            vitamin_e_mg REAL DEFAULT 0.0,
            vitamin_k_ug REAL DEFAULT 0.0,
            thiamine_mg REAL DEFAULT 0.0,
            leucine_g REAL DEFAULT 0.0,
            isoleucine_g REAL DEFAULT 0.0,
            valine_g REAL DEFAULT 0.0,
            tryptophan_g REAL DEFAULT 0.0,
            phenylalanine_g REAL DEFAULT 0.0,
            tyrosine_g REAL DEFAULT 0.0,
            methionine_g REAL DEFAULT 0.0,
            arginine_g REAL DEFAULT 0.0,
            lysine_g REAL DEFAULT 0.0,
            proline_g REAL DEFAULT 0.0,
            PRIMARY KEY(food_id, preparation_state),
            FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE food_biochem (
            food_id INTEGER PRIMARY KEY,
            contains_caffeine INTEGER DEFAULT 0,
            polyphenol_level INTEGER DEFAULT 0,
            is_dairy_calcium INTEGER DEFAULT 0,
            phytate_level INTEGER DEFAULT 0,
            oxalate_level INTEGER DEFAULT 0,
            is_viscous_fiber INTEGER DEFAULT 0,
            iron_type TEXT DEFAULT 'none' CHECK(iron_type IN ('heme', 'non_heme', 'none')),
            is_nightshade INTEGER DEFAULT 0,
            is_seed INTEGER DEFAULT 0,
            fodmap_level TEXT DEFAULT 'low' CHECK(fodmap_level IN ('low', 'medium', 'high')),
            is_fermented INTEGER DEFAULT 0,
            has_phosvitin INTEGER DEFAULT 0,
            phytate_mg REAL DEFAULT 0.0,
            oxalate_mg REAL DEFAULT 0.0,
            FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE flavor_pairings (
            food_id_a INTEGER NOT NULL,
            food_id_b INTEGER NOT NULL,
            shared_molecules_count INTEGER NOT NULL,
            jaccard_score REAL NOT NULL,
            top_shared_compounds TEXT,
            PRIMARY KEY(food_id_a, food_id_b),
            FOREIGN KEY(food_id_a) REFERENCES foods(id) ON DELETE CASCADE,
            FOREIGN KEY(food_id_b) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE culinary_herb_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dish_category TEXT NOT NULL,
            herb_name_de TEXT NOT NULL,
            UNIQUE(dish_category, herb_name_de)
        );

        CREATE TABLE food_seasonality (
            food_id INTEGER NOT NULL,
            month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
            availability_status TEXT NOT NULL CHECK(availability_status IN ('FRESH', 'STORAGE', 'UNAVAILABLE')),
            PRIMARY KEY(food_id, month),
            FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE supplements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            brand TEXT NOT NULL,
            product_name TEXT NOT NULL,
            form TEXT NOT NULL,
            timing_tag TEXT NOT NULL,
            active_compound TEXT NOT NULL,
            dosage_amount REAL NOT NULL,
            dosage_unit TEXT NOT NULL,
            biochem_note TEXT
        );

        CREATE TABLE timing_constraints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_tag TEXT NOT NULL,
            target_tag TEXT NOT NULL,
            relation TEXT NOT NULL CHECK(relation IN ('SEPARATION', 'BEFORE', 'AFTER', 'WITH_MEAL')),
            min_minutes INTEGER NOT NULL,
            max_minutes INTEGER,
            is_hard_constraint INTEGER DEFAULT 1,
            penalty_weight REAL DEFAULT 1.0,
            rationale TEXT
        );

        CREATE TABLE recipes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            servings INTEGER DEFAULT 1,
            ref_kcal REAL,
            ref_protein_g REAL,
            ref_fat_g REAL,
            ref_carbs_g REAL
        );

        CREATE TABLE recipe_ingredients (
            recipe_id INTEGER NOT NULL,
            food_id INTEGER NOT NULL,
            amount_g REAL NOT NULL,
            preparation_state TEXT DEFAULT 'raw',
            PRIMARY KEY(recipe_id, food_id),
            FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
            FOREIGN KEY(food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE day_plan_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            workout_timing_type TEXT NOT NULL
        );

        CREATE TABLE day_plan_template_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            template_id INTEGER NOT NULL,
            time_hhmm TEXT NOT NULL,
            event_type TEXT NOT NULL,
            title TEXT NOT NULL,
            details TEXT,
            FOREIGN KEY(template_id) REFERENCES day_plan_templates(id) ON DELETE CASCADE
        );

        CREATE TABLE game_levels (
            id INTEGER PRIMARY KEY,
            tier INTEGER NOT NULL,
            level_number INTEGER NOT NULL UNIQUE,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            badge TEXT NOT NULL,
            difficulty INTEGER NOT NULL,
            target_formula TEXT NOT NULL,
            biochem_rationale TEXT NOT NULL,
            coaching_tip TEXT NOT NULL,
            tolerance_json TEXT
        );

        CREATE TABLE hero_modifiers (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            badge TEXT NOT NULL,
            exclusion_boundary TEXT NOT NULL,
            biochem_conflict TEXT NOT NULL,
            solution_strategy TEXT NOT NULL,
            filter_rule_json TEXT NOT NULL
        );

        CREATE INDEX idx_game_levels_num ON game_levels(level_number);
        CREATE INDEX idx_foods_name_de ON foods(name_de);
        CREATE INDEX idx_foods_role ON foods(meal_role);
        CREATE INDEX idx_food_allergens_code ON food_allergens(allergen_code);
        CREATE INDEX idx_seasonality_month ON food_seasonality(month, availability_status);
        CREATE INDEX idx_flavor_pairings_score ON flavor_pairings(food_id_a, jaccard_score DESC);
        """)

# ==============================================================================
# 3. PHASE 1: MASTER-SPINE & ALLERGENE EINFÜGEN
# ==============================================================================
def populate_phase1_master_spine(conn: sqlite3.Connection, catalog: List[Dict[str, Any]]) -> Dict[str, int]:
    print("\n[Phase 1] Lade Master-Katalog, Biochemie & Allergen-Eigenschaften...")
    name_to_id = {}
    allergen_rows = []

    with conn:
        for item in catalog:
            cur = conn.execute("""
                INSERT INTO foods (
                    name_de, name_en, synonyms_at, flavordb_alias, category,
                    meal_role, gi_class, gastric_emptying_hours, pre_workout_suitability
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                item["name_de"], item["name_en"], item.get("synonyms_at", ""),
                item.get("flavordb_alias", ""), item["category"], item["meal_role"],
                item["gi_class"], item["gastric_emptying_hours"], item.get("pre_workout_suitability", 1)
            ))
            food_id = cur.lastrowid
            name_to_id[item["name_de"]] = food_id

            b = item["biochem"]
            conn.execute("""
                INSERT INTO food_biochem (
                    food_id, contains_caffeine, polyphenol_level, is_dairy_calcium,
                    phytate_level, oxalate_level, is_viscous_fiber, iron_type,
                    is_nightshade, is_seed, fodmap_level, is_fermented, has_phosvitin,
                    phytate_mg, oxalate_mg
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                food_id, b.get("contains_caffeine", 0), b.get("polyphenol_level", 0),
                b.get("is_dairy_calcium", 0), b.get("phytate_level", 0),
                b.get("oxalate_level", 0), b.get("is_viscous_fiber", 0),
                b.get("iron_type", "none"),
                b.get("is_nightshade", 0), b.get("is_seed", 0),
                b.get("fodmap_level", "low"), b.get("is_fermented", 0),
                b.get("has_phosvitin", 0), b.get("phytate_mg", 0.0),
                b.get("oxalate_mg", 0.0)
            ))

            for code in item.get("allergens", []):
                if code in EU_ALLERGENS:
                    name_de, name_en = EU_ALLERGENS[code]
                    allergen_rows.append((food_id, code, name_de, name_en, "CONTAINS"))

        conn.executemany("""
            INSERT INTO food_allergens (food_id, allergen_code, allergen_name_de, allergen_name_en, contains_status)
            VALUES (?, ?, ?, ?, ?)
        """, allergen_rows)

        for dish_cat, herbs in IMSB_HERB_COMPATIBILITY:
            for herb in herbs:
                conn.execute("""
                    INSERT OR IGNORE INTO culinary_herb_rules (dish_category, herb_name_de)
                    VALUES (?, ?)
                """, (dish_cat, herb))

    print(f"  -> {len(name_to_id)} Lebensmittel, {len(allergen_rows)} Allergeneinträge und {len(IMSB_HERB_COMPATIBILITY)} Kräutergruppen angelegt.")
    return name_to_id

# ==============================================================================
# 4. PHASE 2: USDA NÄHRWERTE INKL. VOLLSTÄNDIGER FETTSÄUREN
# ==============================================================================
USDA_NUTRIENT_MAP = {
    # Makros, Vitamine & Mineralien
    "208": ("calories_kcal", "kcal"),
    "957": ("calories_kcal", "kcal"),
    "958": ("calories_kcal", "kcal"),
    "2047": ("calories_kcal", "kcal"),
    "2048": ("calories_kcal", "kcal"),
    "203": ("protein_g", "g"),
    "205": ("carbs_g", "g"),
    "204": ("fat_g", "g"),
    "298": ("fat_g", "g"),
    "291": ("fiber_g", "g"),
    "301": ("calcium_mg", "mg"),
    "303": ("iron_mg", "mg"),
    "304": ("magnesium_mg", "mg"),
    "306": ("potassium_mg", "mg"),
    "307": ("sodium_mg", "mg"),
    "309": ("zinc_mg", "mg"),
    "312": ("copper_mg", "mg"),
    "315": ("manganese_mg", "mg"),
    "401": ("vitamin_c_mg", "mg"),
    "328": ("vitamin_d_ug", "ug"),
    "323": ("vitamin_e_mg", "mg"),
    "320": ("vitamin_a_ug", "ug"),
    "430": ("vitamin_k_ug", "ug"),
    "404": ("thiamine_mg", "mg"),
    # Aminosäuren
    "501": ("tryptophan_g", "g"),
    "503": ("isoleucine_g", "g"),
    "504": ("leucine_g", "g"),
    "505": ("lysine_g", "g"),
    "506": ("methionine_g", "g"),
    "508": ("phenylalanine_g", "g"),
    "509": ("tyrosine_g", "g"),
    "510": ("valine_g", "g"),
    "511": ("arginine_g", "g"),
    "517": ("proline_g", "g"),
    # Fettsäuren-Subprofile & Cholesterin
    "606": ("fat_saturated_g", "g"),
    "645": ("fat_monounsaturated_g", "g"),
    "646": ("fat_polyunsaturated_g", "g"),
    "601": ("cholesterol_mg", "mg")
}

# Spezifische Omega-3 / Omega-6 IDs
OMEGA_3_IDS = {"619", "851", "629", "631", "621"} # ALA, EPA, DPA, DHA
OMEGA_6_IDS = {"618", "675", "620", "855"}         # Linoleic, Arachidonic

def convert_nutrient_unit(val: float, source_unit: str, target_unit: str, target_col: str) -> float:
    if val is None or math.isnan(val):
        return 0.0
    s = (source_unit or "").strip().lower()
    t = target_unit.strip().lower()

    if s == t or (s in ["ug", "µg", "mcg"] and t in ["ug", "µg", "mcg"]):
        return float(val)

    if t == "kcal":
        if s in ["kj", "kilojoules"]:
            return round(float(val) / 4.184, 1)
        return float(val)

    if s == "iu" and "vitamin_d" in target_col:
        return float(val) * 0.025

    to_grams = {"g": 1.0, "mg": 1e-3, "ug": 1e-6, "µg": 1e-6, "mcg": 1e-6}
    from_grams = {"g": 1.0, "mg": 1e3, "ug": 1e6, "µg": 1e6, "mcg": 1e6}

    if s in to_grams and t in from_grams:
        val_in_g = float(val) * to_grams[s]
        return val_in_g * from_grams[t]

    return float(val)

def detect_prep_state(desc_lower: str) -> str:
    if any(w in desc_lower for w in ["steamed"]):
        return "steamed"
    if any(w in desc_lower for w in ["boiled", "simmered", "poached"]):
        return "boiled"
    if any(w in desc_lower for w in ["cooked", "roasted", "baked", "grilled", "broiled"]):
        return "cooked"
    if any(w in desc_lower for w in ["dried", "dehydrated", "prunes", "raisins"]):
        return "dried"
    if any(w in desc_lower for w in ["frozen"]):
        return "frozen"
    if any(w in desc_lower for w in ["canned"]):
        return "canned"
    return "raw"

def extract_nutrients_from_usda_item(item: dict) -> Dict[str, float]:
    target_cols = {col for col, _ in USDA_NUTRIENT_MAP.values()}
    values = {col: 0.0 for col in target_cols}
    values["omega_3_g"] = 0.0
    values["omega_6_g"] = 0.0
    kj_fallback = 0.0

    omega_3_compounds = {}
    omega_6_compounds = {}

    for fn in item.get("foodNutrients", []):
        nut = fn.get("nutrient", {})
        num = str(nut.get("number", ""))
        amt = fn.get("amount")
        unit_name = nut.get("unitName", "")
        if amt is None:
            continue

        val_float = float(amt)

        if num in USDA_NUTRIENT_MAP:
            col, target_unit = USDA_NUTRIENT_MAP[num]
            conv_val = convert_nutrient_unit(val_float, unit_name, target_unit, col)
            if values[col] == 0.0 or col == "fat_g":
                values[col] = conv_val

        if num in OMEGA_3_IDS:
            conv_val = convert_nutrient_unit(val_float, unit_name, "g", "omega_3_g")
            omega_3_compounds[num] = conv_val

        if num in OMEGA_6_IDS:
            conv_val = convert_nutrient_unit(val_float, unit_name, "g", "omega_6_g")
            omega_6_compounds[num] = conv_val

        if num == "321" and values["vitamin_a_ug"] == 0.0:
            values["vitamin_a_ug"] = round(val_float / 12.0, 1)

        if num in ("268", "1062"):
            kj_fallback = val_float

    # Berechne Summen für Omega-3 und Omega-6
    if omega_3_compounds:
        # Bevorzuge 851 (18:3 n-3 ALA) vor 619 (18:3 undifferentiated) falls beide vorliegen
        if "851" in omega_3_compounds and "619" in omega_3_compounds:
            omega_3_compounds.pop("619")
        values["omega_3_g"] = round(sum(omega_3_compounds.values()), 3)
    if omega_6_compounds:
        # Bevorzuge 675 vor 618 falls beide vorliegen
        if "675" in omega_6_compounds and "618" in omega_6_compounds:
            omega_6_compounds.pop("618")
        values["omega_6_g"] = round(sum(omega_6_compounds.values()), 3)

    if values["calories_kcal"] == 0.0:
        if kj_fallback > 0.0:
            values["calories_kcal"] = round(kj_fallback / 4.184, 1)
        elif values["protein_g"] > 0 or values["carbs_g"] > 0 or values["fat_g"] > 0:
            values["calories_kcal"] = round(values["protein_g"] * 4.0 + values["carbs_g"] * 4.0 + values["fat_g"] * 9.0, 1)

    return values

def matches_usda_terms(desc_lower: str, terms: List[str]) -> Tuple[bool, int]:
    best_score = 0
    matched = False
    is_composite = any(w in desc_lower for w in ["breakfast bar", "babyfood", "infant formula", "mayonnaise"])

    for term in terms:
        t = term.lower().strip()
        pattern = r'\b' + re.escape(t) + r'\b'
        if re.search(pattern, desc_lower):
            matched = True
            if desc_lower.startswith(t):
                score = 100 - len(desc_lower)
            elif f", {t}" in desc_lower:
                score = 80 - len(desc_lower)
            else:
                score = 50 - len(desc_lower)
            if is_composite:
                score -= 70
            if score > best_score:
                best_score = score
        elif desc_lower.startswith(t) or f", {t}" in desc_lower:
            matched = True
            score = 60 - len(desc_lower)
            if is_composite:
                score -= 70
            if score > best_score:
                best_score = score

    return matched, best_score

def populate_phase2_usda_nutrients(conn: sqlite3.Connection, catalog: List[Dict[str, Any]], name_to_id: Dict[str, int]):
    print("\n[Phase 2] Verarbeite USDA FoodData Central (SR Legacy & Foundation)...")
    raw_items = []
    if PATH_SR_LEGACY.exists():
        with open(PATH_SR_LEGACY, "r", encoding="utf-8") as f:
            raw_items.extend(json.load(f).get("SRLegacyFoods", []))
    if PATH_FOUNDATION.exists():
        with open(PATH_FOUNDATION, "r", encoding="utf-8") as f:
            raw_items.extend(json.load(f).get("FoundationFoods", []))

    if not raw_items:
        print("  [Warnung] Keine USDA-Dateien gefunden.")
        return

    inserted_variants = 0
    with conn:
        for item_data in catalog:
            name_de = item_data["name_de"]
            terms = item_data.get("usda_search_terms", [])
            food_id = name_to_id[name_de]

            # Spezifische Schweizer BLV-Präzision für Steirisches Kürbiskernöl
            if name_de == "Kürbiskernöl":
                conn.execute("""
                    INSERT OR REPLACE INTO food_nutrients (
                        food_id, preparation_state, usda_fdc_id, usda_description,
                        calories_kcal, protein_g, carbs_g, fat_g,
                        fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g,
                        omega_3_g, omega_6_g, cholesterol_mg, fiber_g,
                        calcium_mg, iron_mg, zinc_mg, copper_mg, magnesium_mg,
                        manganese_mg, potassium_mg, sodium_mg,
                        vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug,
                        thiamine_mg, leucine_g, isoleucine_g, valine_g, tryptophan_g,
                        phenylalanine_g, tyrosine_g, methionine_g,
                        arginine_g, lysine_g, proline_g
                    ) VALUES (
                        ?, 'raw', 999901, 'Steirisches Kuerbiskernoel g.g.A. (BLV Swiss Food Comp)',
                        884.0, 0.0, 0.0, 100.0,
                        19.0, 34.0, 47.0,
                        0.5, 46.5, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 15.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0
                    )
                """, (food_id,))
                inserted_variants += 1
                continue

            # Spezifische CoFID/BLV-Präzision für Griechisches Joghurt 10% Fett
            if name_de == "Griechisches Joghurt 10%":
                conn.execute("""
                    INSERT OR REPLACE INTO food_nutrients (
                        food_id, preparation_state, usda_fdc_id, usda_description,
                        calories_kcal, protein_g, carbs_g, fat_g,
                        fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g,
                        omega_3_g, omega_6_g, cholesterol_mg, fiber_g,
                        calcium_mg, iron_mg, zinc_mg, copper_mg, magnesium_mg,
                        manganese_mg, potassium_mg, sodium_mg,
                        vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug,
                        thiamine_mg, leucine_g, isoleucine_g, valine_g, tryptophan_g,
                        phenylalanine_g, tyrosine_g, methionine_g,
                        arginine_g, lysine_g, proline_g
                    ) VALUES (
                        ?, 'raw', 999902, 'Griechisches Joghurt 10% Fett (CoFID 12-555 / BLV Swiss)',
                        133.0, 5.7, 4.8, 10.2,
                        6.75, 2.53, 0.28,
                        0.05, 0.23, 16.7, 0.0,
                        126.0, 0.11, 0.50, 0.02, 13.0,
                        0.01, 184.0, 66.0,
                        115.0, 0.5, 0.1, 0.38, 0.2,
                        0.12, 0.56, 0.31, 0.38, 0.08,
                        0.27, 0.27, 0.15,
                        0.20, 0.46, 0.56
                    )
                """, (food_id,))
                inserted_variants += 1
                continue

            # Spezifische BLV-Präzision für Speisetopfen 20% F.i.T. (Halbfettquark)
            if name_de == "Speisetopfen 20%":
                conn.execute("""
                    INSERT OR REPLACE INTO food_nutrients (
                        food_id, preparation_state, usda_fdc_id, usda_description,
                        calories_kcal, protein_g, carbs_g, fat_g,
                        fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g,
                        omega_3_g, omega_6_g, cholesterol_mg, fiber_g,
                        calcium_mg, iron_mg, zinc_mg, copper_mg, magnesium_mg,
                        manganese_mg, potassium_mg, sodium_mg,
                        vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug,
                        thiamine_mg, leucine_g, isoleucine_g, valine_g, tryptophan_g,
                        phenylalanine_g, tyrosine_g, methionine_g,
                        arginine_g, lysine_g, proline_g
                    ) VALUES (
                        ?, 'raw', 999903, 'Speisetopfen 20% F.i.T. / Halbfettquark (BLV 571)',
                        99.0, 9.4, 4.1, 5.0,
                        3.0, 1.2, 0.2,
                        0.03, 0.15, 17.0, 0.0,
                        110.0, 0.1, 0.4, 0.02, 9.3,
                        0.01, 130.0, 32.0,
                        52.0, 0.2, 0.1, 0.13, 0.1,
                        0.01, 0.92, 0.51, 0.63, 0.13,
                        0.45, 0.45, 0.24,
                        0.33, 0.75, 0.92
                    )
                """, (food_id,))
                inserted_variants += 1
                continue

            # Spezifische BLV-Präzision für Rahmtopfen 40% F.i.T. (Rahmquark)
            if name_de == "Rahmtopfen 40%":
                conn.execute("""
                    INSERT OR REPLACE INTO food_nutrients (
                        food_id, preparation_state, usda_fdc_id, usda_description,
                        calories_kcal, protein_g, carbs_g, fat_g,
                        fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g,
                        omega_3_g, omega_6_g, cholesterol_mg, fiber_g,
                        calcium_mg, iron_mg, zinc_mg, copper_mg, magnesium_mg,
                        manganese_mg, potassium_mg, sodium_mg,
                        vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug,
                        thiamine_mg, leucine_g, isoleucine_g, valine_g, tryptophan_g,
                        phenylalanine_g, tyrosine_g, methionine_g,
                        arginine_g, lysine_g, proline_g
                    ) VALUES (
                        ?, 'raw', 999904, 'Rahmtopfen 40% F.i.T. / Rahmquark (BLV 70)',
                        183.0, 6.9, 3.7, 15.6,
                        9.4, 3.7, 0.7,
                        0.10, 0.50, 53.0, 0.0,
                        93.0, 0.1, 0.3, 0.02, 8.1,
                        0.01, 120.0, 29.0,
                        160.0, 0.4, 0.2, 0.40, 0.2,
                        0.02, 0.68, 0.37, 0.46, 0.10,
                        0.33, 0.33, 0.18,
                        0.24, 0.55, 0.68
                    )
                """, (food_id,))
                inserted_variants += 1
                continue

            state_candidates: Dict[str, Tuple[int, dict]] = {}
            for raw_food in raw_items:
                desc = raw_food.get("description", "")
                desc_clean = re.sub(r"\s*\([^)]*USDA[^)]*\)", "", desc, flags=re.IGNORECASE).strip()
                desc_lower = desc_clean.lower()

                matched, score = matches_usda_terms(desc_lower, terms)
                if matched:
                    prep_state = detect_prep_state(desc_lower)
                    if prep_state not in state_candidates or score > state_candidates[prep_state][0]:
                        state_candidates[prep_state] = (score, raw_food)

            for prep_state, (_, best_item) in state_candidates.items():
                nuts = extract_nutrients_from_usda_item(best_item)
                params = {
                    "food_id": food_id,
                    "prep_state": prep_state,
                    "fdc_id": best_item.get("fdcId"),
                    "desc": best_item.get("description"),
                    **nuts
                }
                conn.execute("""
                    INSERT OR REPLACE INTO food_nutrients (
                        food_id, preparation_state, usda_fdc_id, usda_description,
                        calories_kcal, protein_g, carbs_g, fat_g,
                        fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g,
                        omega_3_g, omega_6_g, cholesterol_mg, fiber_g,
                        calcium_mg, iron_mg, zinc_mg, copper_mg, magnesium_mg,
                        manganese_mg, potassium_mg, sodium_mg,
                        vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug,
                        thiamine_mg, leucine_g, isoleucine_g, valine_g, tryptophan_g,
                        phenylalanine_g, tyrosine_g, methionine_g,
                        arginine_g, lysine_g, proline_g
                    ) VALUES (
                        :food_id, :prep_state, :fdc_id, :desc,
                        :calories_kcal, :protein_g, :carbs_g, :fat_g,
                        :fat_saturated_g, :fat_monounsaturated_g, :fat_polyunsaturated_g,
                        :omega_3_g, :omega_6_g, :cholesterol_mg, :fiber_g,
                        :calcium_mg, :iron_mg, :zinc_mg, :copper_mg, :magnesium_mg,
                        :manganese_mg, :potassium_mg, :sodium_mg,
                        :vitamin_a_ug, :vitamin_c_mg, :vitamin_d_ug, :vitamin_e_mg, :vitamin_k_ug,
                        :thiamine_mg, :leucine_g, :isoleucine_g, :valine_g, :tryptophan_g,
                        :phenylalanine_g, :tyrosine_g, :methionine_g,
                        :arginine_g, :lysine_g, :proline_g
                    )
                """, params)
                inserted_variants += 1

    print(f"  -> {inserted_variants} Nährwertdatensätze inkl. Fettsäuren-Subprofile importiert.")

# ==============================================================================
# 5. PHASE 3: FLAVORDB MOLEKULARER AROMA-GRAPH & REZEPT-PAIRING
# ==============================================================================
def load_recipe_pairings() -> Dict[Tuple[str, str], Tuple[int, List[str]]]:
    recipe_cooccur: Dict[Tuple[str, str], Tuple[int, List[str]]] = {}
    all_recipes = []

    for title, _, _, _, _, _, _, ing_list in IMSB_RECIPES_DATA:
        ings = [item[0] for item in ing_list]
        all_recipes.append((title, ings))

    # Authentische österreichische Traditionsgerichte & Aromenkombinationen
    AUSTRIAN_CLASSIC_DISHES = [
        ("Wiener Schnitzel", ["Kalbfleisch", "Hühnerei", "Weißbrot", "Butter", "Zitrone", "Preiselbeeren", "Erdäpfel", "Vogerlsalat"]),
        ("Schweinsbraten mit Sauerkraut & Knödel", ["Schweinefleisch", "Sauerkraut", "Knödelbrot", "Kümmel", "Knoblauch", "Zwiebel"]),
        ("Tafelspitz mit Semmelkren & Schnittlauchsauce", ["Rindfleisch", "Kren", "Knödelbrot", "Karotten", "Sellerie", "Liebstöckel", "Schnittlauch", "Sauerrahm"]),
        ("Tiroler Gröstl", ["Rindfleisch", "Schweinefleisch", "Erdäpfel", "Zwiebel", "Kümmel", "Majoran", "Hühnerei", "Butter"]),
        ("Grießnockerlsuppe", ["Weizengrieß", "Hühnerei", "Butter", "Liebstöckel", "Schnittlauch", "Rindfleisch", "Karotten"]),
        ("Steirischer Käferbohnensalat", ["Käferbohnen", "Kürbiskernöl", "Kren", "Zwiebel", "Vogerlsalat", "Apfel", "Hühnerei"]),
        ("Mohnnudeln", ["Erdäpfel", "Mohn", "Butter", "Zimt", "Zwetschken"]),
        ("Faschierte Laibchen mit Püree", ["Faschiertes", "Knödelbrot", "Hühnerei", "Zwiebel", "Knoblauch", "Majoran", "Senf", "Erdäpfel"]),
        ("Saibling / Forelle gebraten", ["Saibling", "Forelle", "Zitrone", "Butter", "Petersilie", "Erdäpfel", "Kren"]),
        ("Graukäse sauer", ["Tiroler Graukäse", "Zwiebel", "Essig", "Kürbiskernöl", "Kümmel", "Vollkornbrot"]),
        ("Caprese mit Paradeisern", ["Mozzarella", "Paradeiser", "Basilikum", "Olivenöl"]),
        ("Gebackener Camembert", ["Camembert", "Preiselbeeren", "Hühnerei", "Weißbrot", "Butter"]),
        ("Topfenknödel mit Marillen", ["Speisetopfen 20%", "Weizengrieß", "Butter", "Hühnerei", "Marillen"]),
        ("Topfenstrudel", ["Rahmtopfen 40%", "Sauerrahm", "Hühnerei", "Zitrone", "Butter"]),
        ("Tzatziki", ["Griechisches Joghurt 10%", "Gurken", "Knoblauch", "Olivenöl", "Dille"]),
        ("Beeren-Joghurt Schale", ["Griechisches Joghurt 2%", "Haferflocken", "Heidelbeeren", "Walnüsse"])
    ]
    for title, ings in AUSTRIAN_CLASSIC_DISHES:
        all_recipes.append((title, ings))

    if RECIPES_PATH.exists():
        try:
            import ast
            with open(RECIPES_PATH, "r", encoding="utf-8") as f:
                tree = ast.parse(f.read())
            for node in tree.body:
                if isinstance(node, ast.Assign):
                    for target in node.targets:
                        if isinstance(target, ast.Name) and target.id == "RECIPES":
                            val = ast.literal_eval(node.value)
                            for r in val:
                                title = r.get("dish_name", "Rezept")
                                ings = list(r.get("ingredients", {}).keys())
                                all_recipes.append((title, ings))
        except Exception as e:
            print(f"  [Info] Konnte {RECIPES_PATH} nicht voll einlesen: {e}")

    RECIPE_NAME_MAP = {
        "apfel": "Apfel", "müsli": "Haferflocken", "joghurt": "Naturjogurt",
        "haselnuss": "Haselnüsse", "sonnenblumenkern": "Sonnenblumenkerne",
        "rosine": "Weintrauben", "honig": "Honig", "banane": "Banane",
        "himbeere": "Himbeeren", "magermilch": "Magermilch", "haferflocken": "Haferflocken",
        "thunfisch, roh": "Tunfisch", "radicchio, raw": "Rucola", "gurke": "Gurken",
        "paprika": "Paprika", "zwiebel": "Zwiebel", "tomate": "Paradeiser",
        "oliven": "Olivenöl", "rapsöl": "Rapsöl", "essig": "Zitrone",
        "senf": "Estragonsenf", "knoblauch": "Knoblauch", "pfeffer": "Kurkuma",
        "karotte": "Karotten", "vollmilch, uht": "Magermilch", "petersilie": "Petersilie",
        "chicken": "Hühnerbrust", "basmati rice": "Reis", "bamboo shoot": "Spargel",
        "erbse": "Erbsen", "sojasprossen, roh": "Sojabohnen", "sojasauce": "Estragonsenf",
        "curry leaf": "Kurkuma", "hüttenkäse, nature": "Hüttenkäse",
        "orangensaft": "Zitrusfrüchte", "pfirsich": "Pfirsiche", "ingwer": "Ingwer",
        "zitronensaft": "Zitrone", "dattel": "Marillen", "zimt": "Zimt",
        "dille": "Dille", "mandel": "Mandeln", "walnuss": "Walnüsse",
        "hirse": "Hirse", "quinoa": "Quinoa", "lachs": "Lachs", "dorsch": "Dorsch",
        "schweinefleisch": "Schweinefleisch", "schwein": "Schweinefleisch",
        "kalb": "Kalbfleisch", "faschiertes": "Faschiertes", "bergkäse": "Bergkäse",
        "graukäse": "Tiroler Graukäse", "saibling": "Saibling", "kren": "Kren",
        "bärlauch": "Bärlauch", "sauerkraut": "Sauerkraut", "rotkraut": "Rotkraut",
        "preiselbeeren": "Preiselbeeren", "maroni": "Maroni", "kürbiskernöl": "Kürbiskernöl",
        "mohn": "Mohn", "weizengrieß": "Weizengrieß", "knödelbrot": "Knödelbrot",
        "kümmel": "Kümmel", "liebstöckel": "Liebstöckel", "majoran": "Majoran"
    }

    ignored = {"wasser", "salz", "gemüsebouillon", "zucker"}

    for dish_title, ings in all_recipes:
        canonical_ings = set()
        for raw_ing in ings:
            clean = raw_ing.lower().strip()
            if clean in ignored:
                continue
            mapped = RECIPE_NAME_MAP.get(clean, raw_ing)
            canonical_ings.add(mapped)

        canon_list = sorted(list(canonical_ings))
        for i, a in enumerate(canon_list):
            for b in canon_list[i+1:]:
                pair = tuple(sorted([a, b]))
                if pair not in recipe_cooccur:
                    recipe_cooccur[pair] = (0, [])
                cnt, dishes = recipe_cooccur[pair]
                if dish_title not in dishes:
                    dishes.append(dish_title)
                recipe_cooccur[pair] = (cnt + 1, dishes)

    return recipe_cooccur

def populate_phase3_flavordb(conn: sqlite3.Connection, catalog: List[Dict[str, Any]], name_to_id: Dict[str, int]):
    print("\n[Phase 3] Berechne molekularen FlavorDB-Graphen & Rezept-Synergien...")
    food_molecules: Dict[int, Set[str]] = {}

    if DIR_FLAVORDB.exists():
        alias_to_entity = {}
        for jf in glob.glob(str(DIR_FLAVORDB / "*.json")):
            try:
                with open(jf, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    eid = data.get("entity_id")
                    alias = (data.get("entity_alias") or "").lower().strip()
                    readable = (data.get("entity_alias_readable") or "").lower().strip()
                    name = (data.get("entity_name") or "").lower().strip()
                    mols = {
                        m.get("common_name") or str(m.get("pubchem_id"))
                        for m in data.get("molecules", [])
                        if m.get("common_name") or m.get("pubchem_id")
                    }
                    if mols:
                        entry = {"entity_id": eid, "molecules": mols}
                        for k in [alias, readable, name]:
                            if k:
                                alias_to_entity[k] = entry
            except Exception:
                pass

        with conn:
            for item in catalog:
                food_id = name_to_id[item["name_de"]]
                fdb_alias = item.get("flavordb_alias", "").lower().strip()
                if not fdb_alias:
                    continue

                matched = alias_to_entity.get(fdb_alias)
                if not matched:
                    for k, v in alias_to_entity.items():
                        if fdb_alias == k or (len(fdb_alias) > 3 and (fdb_alias in k or k in fdb_alias)):
                            matched = v
                            break
                if matched:
                    food_molecules[food_id] = matched["molecules"]
                    conn.execute("UPDATE foods SET flavordb_entity_id = ? WHERE id = ?", (matched["entity_id"], food_id))

    pairings: Dict[Tuple[int, int], Tuple[int, float, str]] = {}
    fids = sorted(food_molecules.keys())
    for i, fid_a in enumerate(fids):
        mols_a = food_molecules[fid_a]
        for fid_b in fids[i+1:]:
            mols_b = food_molecules[fid_b]
            shared = mols_a.intersection(mols_b)
            if len(shared) >= 3:
                union_len = len(mols_a.union(mols_b))
                jaccard = round(len(shared) / union_len, 4) if union_len else 0.0
                top_compounds = ", ".join(sorted(list(shared))[:5])
                pairings[(fid_a, fid_b)] = (len(shared), jaccard, top_compounds)
                pairings[(fid_b, fid_a)] = (len(shared), jaccard, top_compounds)

    # Ergänze Rezept-Synergien
    recipe_cooccur = load_recipe_pairings()
    added_recipe_edges = 0

    fruit_names = {item["name_de"] for item in catalog if item.get("category") == "Obst" or item.get("meal_role") == "fruit"}

    for (ing_a, ing_b), (cnt, dishes) in recipe_cooccur.items():
        fid_a = name_to_id.get(ing_a)
        fid_b = name_to_id.get(ing_b)
        if not fid_a or not fid_b or fid_a == fid_b:
            continue

        pair_key = (fid_a, fid_b)
        if pair_key not in pairings or ing_a in fruit_names or ing_b in fruit_names:
            score = round(min(0.95, 0.15 * cnt + 0.05), 4)
            comp_str = f"Rezept-Kombination ({cnt}x): {', '.join(dishes[:3])}"
            if pair_key not in pairings or score > pairings[pair_key][1]:
                pairings[pair_key] = (cnt, score, comp_str)
                pairings[(fid_b, fid_a)] = (cnt, score, comp_str)
                added_recipe_edges += 1

    rows_to_insert = [
        (fa, fb, sc, jc, tc)
        for (fa, fb), (sc, jc, tc) in pairings.items()
    ]

    with conn:
        conn.executemany("""
            INSERT OR REPLACE INTO flavor_pairings (
                food_id_a, food_id_b, shared_molecules_count, jaccard_score, top_shared_compounds
            ) VALUES (?, ?, ?, ?, ?)
        """, rows_to_insert)

    print(f"  -> {len(food_molecules)} Zutaten mit FlavorDB verknüpft | {len(rows_to_insert)} gerichtete Aroma- & Rezept-Kanten berechnet ({added_recipe_edges} aus Rezepten).")

# ==============================================================================
# 6. PHASE 4: DACH SAISONALITÄT
# ==============================================================================
def populate_phase4_seasonality(conn: sqlite3.Connection, catalog: List[Dict[str, Any]], name_to_id: Dict[str, int]):
    print("\n[Phase 4] Integriere DACH-Saisonkalender...")
    season_map: Dict[str, Tuple[List[int], List[int]]] = {}

    if PATH_SEASONALITY_JSON.exists():
        with open(PATH_SEASONALITY_JSON, "r", encoding="utf-8") as f:
            for item in json.load(f):
                season_map[item["name_de"]] = (item.get("fresh_months", []), item.get("storage_months", []))
                for syn in item.get("synonyms", []):
                    season_map[syn] = (item.get("fresh_months", []), item.get("storage_months", []))

    rows = []
    for item in catalog:
        name_de = item["name_de"]
        fid = name_to_id[name_de]
        
        cat_season = item.get("seasonality")
        if cat_season:
            fresh_m = cat_season.get("fresh_months", [])
            storage_m = cat_season.get("storage_months", [])
        elif name_de in season_map:
            fresh_m, storage_m = season_map[name_de]
        else:
            syn_found = False
            for s in item.get("synonyms_at", "").split(";"):
                s_clean = s.strip()
                if s_clean in season_map:
                    fresh_m, storage_m = season_map[s_clean]
                    syn_found = True
                    break
            if not syn_found:
                fresh_m, storage_m = [], list(range(1, 13))

        for m in range(1, 13):
            if m in fresh_m:
                status = "FRESH"
            elif m in storage_m or not fresh_m:
                status = "STORAGE"
            else:
                status = "UNAVAILABLE"
            rows.append((fid, m, status))

    with conn:
        conn.executemany("""
            INSERT OR REPLACE INTO food_seasonality (food_id, month, availability_status)
            VALUES (?, ?, ?)
        """, rows)

    print(f"  -> {len(rows)} Saisonalitätseinträge für {len(catalog)} Lebensmittel angelegt.")

# ==============================================================================
# 7. PHASE 5: OPEN FOOD FACTS
# ==============================================================================
def populate_phase5_openfoodfacts(conn: sqlite3.Connection, name_to_id: Dict[str, int]):
    print("\n[Phase 5] Prüfe Supermarkt-Präsenz via Open Food Facts...")
    if not PATH_OPENFOODFACTS.exists():
        print("  [Info] food.parquet nicht vorhanden – Standard-Flags aktiv.")
        return

    cached_counts = {}
    speis_old = SPEIS_DIR / "speis.db"
    if speis_old.exists():
        try:
            con_old = sqlite3.connect(speis_old)
            for r in con_old.execute("SELECT name_de, off_dach_product_count FROM foods"):
                cached_counts[r[0]] = r[1]
            con_old.close()
        except Exception:
            pass

    with conn:
        for name_de, fid in name_to_id.items():
            cnt = cached_counts.get(name_de, 0)
            conn.execute("UPDATE foods SET off_dach_product_count = ? WHERE id = ?", (cnt, fid))

    print(f"  -> Open Food Facts Präsenzwerte initialisiert.")

# ==============================================================================
# 8. PHASE 6-8: SUPPLEMENTS, CONSTRAINTS & REZEPTE
# ==============================================================================
def populate_phases_6_7_8(conn: sqlite3.Connection, name_to_id: Dict[str, int]):
    print("\n[Phasen 6-8] Speichere Supplements, Constraints, Rezepte und Tagespläne...")
    with conn:
        conn.executemany("""
            INSERT INTO supplements (
                brand, product_name, form, timing_tag,
                active_compound, dosage_amount, dosage_unit, biochem_note
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, CURATED_SUPPLEMENTS)

        conn.executemany("""
            INSERT INTO timing_constraints (
                source_tag, target_tag, relation, min_minutes, max_minutes,
                is_hard_constraint, penalty_weight, rationale
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, TIMING_CONSTRAINTS)

        for title, cat, servings, kcal, ew, fett, kh, ing_list in IMSB_RECIPES_DATA:
            cur = conn.execute("""
                INSERT INTO recipes (title, category, servings, ref_kcal, ref_protein_g, ref_fat_g, ref_carbs_g)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (title, cat, servings, kcal, ew, fett, kh))
            rec_id = cur.lastrowid
            for ing_name, amount_g, prep in ing_list:
                fid = name_to_id.get(ing_name)
                if fid:
                    conn.execute("""
                        INSERT OR REPLACE INTO recipe_ingredients (recipe_id, food_id, amount_g, preparation_state)
                        VALUES (?, ?, ?, ?)
                    """, (rec_id, fid, amount_g, prep))

        for tpl_name, wo_type, events in DAY_PLAN_TEMPLATES:
            cur = conn.execute("""
                INSERT INTO day_plan_templates (name, workout_timing_type)
                VALUES (?, ?)
            """, (tpl_name, wo_type))
            tpl_id = cur.lastrowid
            for hhmm, ev_type, ev_title, ev_details in events:
                conn.execute("""
                    INSERT INTO day_plan_template_events (template_id, time_hhmm, event_type, title, details)
                    VALUES (?, ?, ?, ?, ?)
                """, (tpl_id, hhmm, ev_type, ev_title, ev_details))

    print("  -> Phasen 6-8 erfolgreich gespeichert.")

# ==============================================================================
# HAUPTBUILDER
# ==============================================================================


# ==============================================================================
# 9. PHASE 9: GAME PROGRESSION CAMPAIGN (24 LEVELS) & 12 HERO CHALLENGES
# ==============================================================================
CORE_CAMPAIGN_LEVELS = [
    # Tier 1: Energetics & Foundational Macronutrients (Levels 1-6)
    (
        1, 1, 1, "Caloric Equilibrium", "Energy Target: 2,000 kcal", "⚡ 2,000 kcal", 1,
        "total_calories == 2000 +- 50 kcal",
        "The first law of thermodynamics dictates net mass and energy balance. Maintaining isocaloric equilibrium stabilizes hepatic glycogen flux and prevents compensatory metabolic adaptation.",
        "Use primary staple portion sizing (rice, oats, sweet potatoes) to land in the target bullseye.",
        json.dumps({"target_calories": 2000.0, "tolerance_calories": 50.0})
    ),
    (
        2, 1, 2, "Macronutrient Harmony", "50% Carbs • 25% Protein • 25% Fat", "⚖️ 50 / 25 / 25", 1,
        "carbs_pct == 50 +- 4 AND protein_pct == 25 +- 3 AND fat_pct == 25 +- 3",
        "Delivers 250g glycogen substrate, 1.6-1.8 g/kg protein for muscle protein synthesis (MPS), and 55.5g lipids for bile acid release and steroid hormone synthesis.",
        "Balance lean protein sources (chicken breast, Greek yogurt, lentils) with complex starches and cold-pressed plant oils.",
        json.dumps({"target_carbs_pct": 50.0, "tol_carbs_pct": 4.0, "target_protein_pct": 25.0, "tol_protein_pct": 3.0, "target_fat_pct": 25.0, "tol_fat_pct": 3.0})
    ),
    (
        3, 1, 3, "Gut Microbiome Fiber Floor", "Total Fiber >= 35g/day", "🌾 Fiber ≥ 35g", 2,
        "total_fiber_g >= 35.0",
        "Fermentation of soluble and prebiotic fibers by colonic microbiota yields short-chain fatty acids (SCFAs: butyrate, propionate, acetate), acidifying the luminal environment, increasing distal mineral solubility, and strengthening tight junction integrity.",
        "Incorporate rolled oats, steamed vegetables, beans, and berries; whole grains fulfill this without blowing caloric targets.",
        json.dumps({"min_fiber_g": 35.0})
    ),
    (
        4, 1, 4, "Saturated Fat Ceiling & Lipid Quality", "SatFat < 8% of kcal • Unsaturated >= 70% of lipids", "🫒 SatFat < 8%", 2,
        "sat_fat_kcal_pct < 8.0 AND (mufa_g + pufa_g) / total_fat_g >= 0.70",
        "Excess SFAs (palmitate) downregulate hepatic LDL receptor expression via SREBP-2 suppression, while high monounsaturated oleic acid preserves endothelial nitric oxide bioavailability.",
        "Swap butter and fatty meats for extra virgin olive oil, nuts, and oily fish.",
        json.dumps({"max_sat_fat_pct_kcal": 8.0, "min_unsaturated_fat_pct": 70.0})
    ),
    (
        5, 1, 5, "Essential Fatty Acid Balance", "Omega-6 : Omega-3 <= 4:1 • Omega-3 >= 2.5g", "🐟 Ω-6 : Ω-3 ≤ 4:1", 2,
        "omega_6_g / omega_3_g <= 4.0 AND omega_3_g >= 2.5",
        "Linoleic acid (LA) and alpha-linolenic acid (ALA) compete for Delta-6-desaturase. Ratios exceeding 10:1 favor pro-inflammatory series-2 prostaglandins and series-4 leukotrienes over anti-inflammatory resolvins and protectins (EPA/DHA).",
        "Add a portion of wild salmon or 15g of walnuts/chia seeds; choose olive or rapeseed oil over sunflower oil.",
        json.dumps({"max_omega6_to_omega3_ratio": 4.0, "min_omega3_g": 2.5})
    ),
    (
        6, 1, 6, "The Sodium–Potassium Pump Baseline", "Potassium >= 3,500mg • Sodium < 2,000mg • Na:K < 1.0 (molar)", "⚡ Na : K < 1.0 (molar)", 2,
        "potassium_mg >= 3500 AND sodium_mg < 2000 AND (sodium_mg / 23.0) / (potassium_mg / 39.1) < 1.0",
        "Essential for maintaining resting membrane potential (Na+/K+-ATPase pump), preserving vascular elasticity, and minimizing urinary calcium wasting.",
        "Build your carb base around steamed potatoes, spinach, zucchini, and bananas rather than processed salty breads.",
        json.dumps({"min_potassium_mg": 3500.0, "max_sodium_mg": 2000.0, "max_molar_na_k_ratio": 1.0})
    ),

    # Tier 2: Micronutrient Ratios & Stoichiometry (Levels 7-12)
    (
        7, 2, 7, "The Bone & Muscle Mineral Axis", "Calcium to Magnesium mass ratio 1.5:1 to 2.0:1", "🦴 Ca : Mg = 1.5–2.0", 3,
        "calcium_mg / magnesium_mg >= 1.5 AND calcium_mg / magnesium_mg <= 2.0",
        "Ratios > 2.6:1 competitively inhibit magnesium transport and impair parathyroid hormone (PTH) sensitivity. Magnesium acts as a physiological calcium channel blocker, preventing aberrant intracellular calcium accumulation.",
        "If your calcium is climbing from dairy, balance it with pumpkin seeds, spinach, or whole cacao.",
        json.dumps({"min_ca_mg_ratio": 1.5, "max_ca_mg_ratio": 2.0})
    ),
    (
        8, 2, 8, "Trace Metal Stoichiometry", "Zinc to Copper mass ratio 10:1 to 15:1 • Zn >= 11mg • Cu >= 0.9mg", "🛡️ Zn : Cu = 10:1 – 15:1", 3,
        "zinc_mg >= 11.0 AND copper_mg >= 0.9 AND (zinc_mg / copper_mg >= 10.0 AND zinc_mg / copper_mg <= 15.0)",
        "High unbuffered zinc induces mucosal cell metallothionein, which binds copper with higher affinity than zinc, sequestering copper and inducing secondary microcytic anemia.",
        "Pair zinc-rich pumpkin seeds or lean meats with a touch of copper-rich dark chocolate or whole oats.",
        json.dumps({"min_zinc_mg": 11.0, "min_copper_mg": 0.9, "min_zn_cu_ratio": 10.0, "max_zn_cu_ratio": 15.0})
    ),
    (
        9, 2, 9, "Local Ecology & Terroir", "100% of fresh fruits and vegetables match active month FRESH or STORAGE", "🌱 100% Seasonal", 3,
        "ALL(fruit_veg_status IN ('FRESH', 'STORAGE'))",
        "Freshly harvested seasonal produce preserves up to 3x higher ascorbic acid and polyphenol titers compared to produce undergoing extended cold-chain storage and ethylene degreening.",
        "In autumn/winter, rely on root vegetables, cabbage, squash, and regional apples rather than imported summer berries.",
        json.dumps({"required_seasonality_pct": 100.0})
    ),
    (
        10, 2, 10, "Stoichiometric Enhancer Pairing (Rule 3)", "50–80mg Vit C with Non-Heme Fe (>=2mg)", "🍋 50–80mg Vit C with Non-Heme Fe", 3,
        "IF meal.non_heme_fe >= 2.0 THEN meal.vitamin_c_mg >= 50.0",
        "Ascorbic acid reduces ferric iron (Fe3+) to ferrous iron (Fe2+) at duodenal pH, maintaining solubility and neutralizing up to 25mg of phytate phosphorus, increasing absorption by +68-164%.",
        "Squeeze fresh lemon juice over plant proteins or add sliced red bell peppers to your grain/legume dishes.",
        json.dumps({"non_heme_iron_threshold_mg": 2.0, "min_vitamin_c_mg": 50.0, "max_vitamin_c_target_mg": 80.0})
    ),
    (
        11, 2, 11, "Lipid-Matrix Activation for Fat-Soluble Vitamins (Rule 5a)", "10–15g Fat in Meals with >=30% RDA Vit A/D/E/K", "🥑 10–15g Fat Matrix", 3,
        "IF meal.has_fat_soluble_vit_30pct THEN meal.fat_g >= 10.0",
        "Fat-soluble vitamins require mixed micelle formation driven by bile salt secretion to activate enterocyte transporters SR-BI, CD36, and NPC1L1. Fat-free ingestion results in >80% fecal excretion.",
        "Never eat dry salads or fat-free steamed carrots/greens; dress them with a tablespoon of olive oil or a slice of avocado.",
        json.dumps({"min_meal_fat_g": 10.0, "max_ideal_meal_fat_g": 15.0})
    ),
    (
        12, 2, 12, "Competitive Transporter Separation (Rule 5b)", "High-Dose Vit E (>50 IU) Decoupled from Vit D & K by >=2h", "💊 Vit E Decoupled from D & K", 3,
        "IF meal_a.vit_e_mg >= 33.5 AND meal_b.vit_d_or_k THEN abs(time_a - time_b) >= 120",
        "alpha-Tocopherol competitively displaces cholecalciferol and phylloquinone at NPC1L1 and upregulates hepatic CYP4F2, accelerating the oxidative catabolism of Vitamin K.",
        "Take your Vitamin D3/K2 drops with a morning fatty meal, and enjoy whole nut snacks or Vitamin E foods in the afternoon.",
        json.dumps({"vit_e_threshold_mg": 33.5, "min_separation_minutes": 120})
    ),

    # Tier 3: Chrono-Nutrition & Transporter Decoupling (Levels 13-18)
    (
        13, 3, 13, "Chrono-Mineral Timing: Morning Calcium Gate", ">= 60% of total daily calcium consumed before 13:00", "☀️ Morning Ca ≥ 60%", 3,
        "calcium_before_13h / total_calcium >= 0.60",
        "Synchronizes with the circadian rhythm of parathyroid hormone (PTH) and bone remodeling. Morning calcium suppresses excessive osteoclastic PTH spikes while leaving afternoon/evening free for iron.",
        "Consume your yogurt, kefir, fortified oats, or cheese during breakfast and morning snack.",
        json.dumps({"min_morning_calcium_pct": 60.0, "cutoff_time": "13:00"})
    ),
    (
        14, 3, 14, "Chrono-Mineral Timing: Evening Magnesium Window", ">= 50% of total daily magnesium consumed after 18:00", "🌙 Evening Mg ≥ 50%", 3,
        "magnesium_after_18h / total_magnesium >= 0.50",
        "Magnesium modulates the NMDA receptor complex and acts as a cofactor for serotonin N-acetyltransferase (melatonin synthesis), promoting slow-wave sleep and parasympathetic activation.",
        "Include pumpkin seeds, quinoa, steamed greens, or magnesium bisglycinate with your dinner or evening routine.",
        json.dumps({"min_evening_magnesium_pct": 50.0, "cutoff_time": "18:00"})
    ),
    (
        15, 3, 15, "Calcium & Iron Decoupling (Rule 2)", "Primary Fe meal has Calcium < 50mg and 0g Egg Yolk Phosvitin", "🚫 Ca < 50mg in Primary Fe Meal", 4,
        "primary_iron_meal.calcium_mg < 50.0 AND primary_iron_meal.has_phosvitin == 0",
        "Calcium binds mucosal transferrin and competitively blocks hDMT1 (inhibition hits 50-60% at 300mg with a 4-hour cellular refractory period). Egg yolk phosvitin forms insoluble, non-absorbable iron phosphoserine chelates.",
        "For your primary iron meal (e.g. steak, lean beef, or lentils), omit cheese, yogurt, and whole eggs; hydrate with pure water instead of milk or high-calcium mineral water.",
        json.dumps({"max_calcium_mg_in_fe_meal": 50.0, "egg_phosvitin_allowed": 0})
    ),
    (
        16, 3, 16, "The Polyphenol Decoupling Law (Rule 1)", "Coffee/Tea separated by >=45-60m before & >=60-120m after Fe/Zn/Thiamine meal", "☕ 60–120m Polyphenol Buffer", 4,
        "abs(polyphenol_time - fe_zn_thiamin_meal_time) >= 60",
        "Galloyl and catechol groups form insoluble polyphenol-metal complexes in the duodenal lumen, halving iron absorption (37.2% -> 18.1%) and impairing thiamine intestinal uptake.",
        "Don't drink your coffee or tea with your iron-rich lunch; enjoy your cup 1 to 2 hours after you finish eating.",
        json.dumps({"min_buffer_minutes_before": 45, "min_buffer_minutes_after": 60})
    ),
    (
        17, 3, 17, "Culinary De-Phytinization (Rule 4)", "Phy:Fe < 1.0 & Phy:Zn < 15 via Sourdough, Soaking, or Vit C Bypass", "🍞 Phy:Fe < 1.0 & Phy:Zn < 15", 4,
        "(phytate_mg / 660.0) / (iron_mg / 55.85) < 1.0 OR has_prep_bypass == 1",
        "Phytate binds multivalent cations into insoluble precipitates. Sourdough fermentation activates cereal phytases (optimum pH 4.5-5.5), degrading IP6 down to IP1-IP3.",
        "Choose traditional artisan sourdough bread and soak your overnight oats in water or lactic starter before cooking.",
        json.dumps({"max_molar_phy_fe": 1.0, "max_molar_phy_zn": 15.0, "vit_c_bypass_mg": 65.0})
    ),
    (
        18, 3, 18, "Viscous Gel-Matrix Decoupling", "Viscous fiber boluses separated by >= 90m from mineral meals / supplements", "⏳ Fiber Gel Decoupled (≥ 90m)", 4,
        "abs(viscous_fiber_time - mineral_meal_time) >= 90",
        "Viscous mucilage creates an unstirred water layer along intestinal enterocytes, physically trapping divalent cations (Fe2+, Zn2+, Mg2+) and reducing bioavailability.",
        "Take psyllium husk or fiber drinks in the mid-afternoon with plenty of water, far away from your mineral-rich meals.",
        json.dumps({"min_separation_minutes": 90})
    ),

    # Tier 4: Molecular Kinetics, Athletic Perturbations & Grandmaster Mastery (Levels 19-24)
    (
        19, 4, 19, "Post-Workout Rapid Kinetics (PepT1) (Rule 6a)", "25–35g High-BV Protein within 45–90m post-workout", "⚡ PepT1 Post-WO Surge", 4,
        "(post_wo_time - workout_end_time <= 90) AND protein_g >= 25.0 AND protein_g <= 35.0",
        "The low-affinity, high-capacity oligopeptide transporter PepT1 (SLC15A1) absorbs di- and tripeptides significantly faster and with lower osmotic burden than free amino acids, maximizing post-exercise muscle protein synthesis.",
        "Within an hour of finishing your training, drink a whey/plant isolate shake or eat a light, tender protein meal with fast-digesting carbs.",
        json.dumps({"min_protein_g": 25.0, "max_protein_g": 35.0, "max_post_wo_minutes": 90})
    ),
    (
        20, 4, 20, "Pre-Workout Gastric Emptying & Glycemic Stability", "Low/Med GI (<=55) • Fat <= 8g • Clearance <= 2.5h Pre-WO", "🏃 Pre-WO Fuel (Low-GI, > 2.5h)", 4,
        "pre_wo_meal.gi_class != 'high' AND pre_wo_meal.fat_g <= 8.0 AND (workout_start_time - pre_wo_time >= 150)",
        "High-GI pre-workout meals trigger rebound hyperinsulinemia, inhibiting lipolysis and causing acute intra-workout hypoglycemia. High fat/fiber delays gastric emptying, causing splanchnic ischemia and GI distress.",
        "Keep your pre-workout meal moderate in clean carbs (quinoa, basmati rice, sweet potato), lean in protein, and light on fat.",
        json.dumps({"max_gi": 55, "max_fat_g": 8.0, "min_clearance_minutes": 150})
    ),
    (
        21, 4, 21, "The Post-Exercise Hepcidin Window (Rule 7)", "Primary Fe meals: >=3h Pre-WO, <=30m Post-WO, or >=6h Post-WO", "🎯 Hepcidin Bypass (Fe <30m or >6h Post-WO)", 5,
        "fe_meal_time <= workout_start - 180 OR fe_meal_time <= workout_end + 30 OR fe_meal_time >= workout_end + 360",
        "Strenuous eccentric or endurance exercise induces an acute IL-6 cytokine spike that triggers hepatic transcription of hepcidin, peaking at 3-6 hours post-exercise. Circulating hepcidin binds enterocyte basolateral ferroportin, internalizing and degrading it, completely locking down iron absorption.",
        "Eat your primary iron-rich meal at lunch before your afternoon workout, or wait until late evening/next morning.",
        json.dumps({"pre_wo_fe_buffer_min": 180, "immediate_post_fe_buffer_min": 30, "delayed_post_fe_buffer_min": 360})
    ),
    (
        22, 4, 22, "MPS Leucine Trigger Distribution", ">= 2.5g L-Leucine in each of the 3 main meals", "🧬 Leucine ≥ 2.5g per Main Meal", 5,
        "meal1.leucine_g >= 2.5 AND meal2.leucine_g >= 2.5 AND meal3.leucine_g >= 2.5",
        "Leucine acts as a molecular trigger binding Sestrin2, which relieves inhibition on GATOR2, recruiting Rag GTPases to translocate mTORC1 to the lysosomal membrane. A sub-threshold dose (< 2g) fails to maximally stimulate MPS.",
        "Distribute your protein evenly across breakfast, lunch, and dinner so each meal provides at least 25–30g of quality protein.",
        json.dumps({"min_leucine_g_per_main_meal": 2.5})
    ),
    (
        23, 4, 23, "Pre-Sleep Blood-Brain Barrier Preservation (LAT1) (Rule 6b)", "Tryptophan : LNAA ratio >= 0.08 in evening • No BCAA bolus", "🧠 High Trp : LNAA Pre-Sleep", 5,
        "evening_window.tryptophan_g / evening_window.lnaa_g >= 0.08",
        "Tryptophan competes with Large Neutral Amino Acids (BCAAs, Phe, Tyr, Met) for the blood-brain barrier transporter LAT1 (SLC7A5). An evening surge of BCAAs displaces tryptophan, choking cerebral serotonin and melatonin synthesis and disturbing sleep architecture.",
        "Keep dinner carbohydrates complex and wholesome; avoid taking post-workout BCAA powders or massive red-meat steaks right before bed.",
        json.dumps({"min_trp_lnaa_ratio": 0.08})
    ),
    (
        24, 4, 24, "Grandmaster Bio-Architect", "All 23 previous constraints active simultaneously with zero violations", "👑 Grandmaster 24/24", 5,
        "ALL(level_1_to_23_passed == true)",
        "The zenith of precision nutrition: optimal thermodynamics, clean macro partitioning, strict micronutrient stoichiometry, and exact diurnal transporter synchronization.",
        "Harmonize every meal: front-load calcium, decouple polyphenols, hit leucine targets, and balance minerals.",
        json.dumps({"required_levels_passed": 23})
    )
]

HERO_MODIFIERS = [
    (
        "H1", "Celiac Sanction", "🌾🚫 Celiac Sanction",
        "0.0g Gluten (No wheat, spelt, rye, barley, kamut)",
        "Eliminates breads/pasta; breaks traditional sourdough de-phytinization (Rule 4).",
        "Pseudocereals (quinoa, buckwheat), GF oats, sweet potatoes; lactic soaking + Vit C bypass.",
        json.dumps({"exclude_allergen": "GLUTEN"})
    ),
    (
        "H2", "Dairy-Free Fortress", "🥛🚫 Dairy-Free Fortress",
        "0.0g Dairy (No milk, yogurt, cheese, whey, casein)",
        "Greek yogurt and whey isolate are lost for Morning Ca Gate (L13) and PepT1 (L19).",
        "Calcium-set tofu, bone-in sardines, tahini, bok choy, hydrolyzed pea-rice peptides.",
        json.dumps({"exclude_allergen": "MILK"})
    ),
    (
        "H3", "Nut-Free Haven", "🥜🚫 Nut-Free Haven",
        "0.0g Tree Nuts & Peanuts",
        "Walnuts (primary plant Omega-3 ALA) and almonds (Vit E) are eliminated.",
        "Chia/flax seeds, extra virgin olive/rapeseed oil, avocado, sunflower seeds.",
        json.dumps({"exclude_allergens": ["NUTS", "PEANUTS"]})
    ),
    (
        "H4", "Seed-Free Sanctum", "🌻🚫 Seed-Free Sanctum",
        "0.0g Seeds (No pumpkin, chia, flax, sesame, sunflower)",
        "Pumpkin seeds were the primary driver for Evening Mg (L14) and Zn:Cu (L8).",
        "Steamed spinach, quinoa, Swiss chard, dark cocoa (>85%), lean beef, magnesium bisglycinate.",
        json.dumps({"exclude_seed": 1})
    ),
    (
        "H5", "Low-FODMAP Gauntlet", "🫃🚫 Low-FODMAP Gauntlet",
        "Zero High-FODMAP Foods (No onions, garlic, apples, wheat, beans)",
        "Eliminates high-fiber legumes, alliums, and pomme fruits while requiring >=35g fiber.",
        "Unripe bananas, kiwis, blueberries, zucchini, carrots, spinach, firm tofu, garlic-infused olive oil.",
        json.dumps({"exclude_fodmap": ["high"]})
    ),
    (
        "H6", "Solanaceae Shield", "🍅🚫 Solanaceae Shield",
        "Zero Nightshades (No peppers, potatoes, tomatoes, eggplant)",
        "Bell pepper (Rule 3 Vit C enhancer) and white potatoes (potassium) are banned.",
        "Fresh lemon juice, raw broccoli florets, red cabbage, sweet potatoes, winter squash.",
        json.dumps({"exclude_nightshade": 1})
    ),
    (
        "H7", "Low-Histamine Shield", "🧬🚫 Low-Histamine Shield",
        "Zero Aged/Fermented Foods (No sourdough, aged cheese, canned fish)",
        "Sourdough de-phytinization (Rule 4) and canned tuna/sardines are eliminated.",
        "Fresh flash-frozen fish/poultry, warm-water soaking with acute Vit C bypass (no fermentation).",
        json.dumps({"exclude_fermented": 1})
    ),
    (
        "H8", "Low-Oxalate Shield", "💎🚫 Low-Oxalate Shield",
        "Oxalates < 50mg/day (No spinach, chard, beets, almonds, cocoa)",
        "High-potassium spinach and sweet potatoes are eliminated.",
        "Steamed zucchini, cauliflower, carrots, peeled boiled russet potatoes, curly kale, bok choy.",
        json.dumps({"max_daily_oxalate_mg": 50.0})
    ),
    (
        "H9", "Vegan Bio-Architect", "🌱👑 Vegan Bio-Architect",
        "100% Plant-Based (No meat, fish, eggs, dairy, collagen)",
        "100% non-heme iron requires constant Vit C pairing; plant protein leucine trigger is hard to reach.",
        "Tempeh, calcium-set tofu, lupin flakes, pea/rice peptide isolate, microalgae EPA/DHA.",
        json.dumps({"exclude_categories": ["Fleisch", "Fisch", "Eier", "Milchprodukte"]})
    ),
    (
        "H10", "AIP Iron Chef", "⚔️👑 AIP Iron Chef",
        "Full AIP Exclusion (No grains, legumes, dairy, eggs, nightshades, nuts, seeds)",
        "All conventional starches and plant proteins are eliminated simultaneously.",
        "Ancestral tubers (sweet potato, parsnip, plantain), grass-fed meats, wild fish, olive oil, avocado.",
        json.dumps({"exclude_categories": ["Getreide", "Hülsenfrüchte", "Milchprodukte", "Eier", "Nüsse"], "exclude_nightshade": 1, "exclude_seed": 1})
    ),
    (
        "H11", "Dual Lipid Exclusion", "🌰🚫 Dual Lipid Exclusion",
        "Zero Nuts AND Zero Seeds",
        "Eliminates both primary whole-food plant fats and evening magnesium snack anchors.",
        "Extra virgin olive oil, whole avocado, wild salmon/mackerel, steamed dark greens, quinoa.",
        json.dumps({"exclude_categories": ["Nüsse"]})
    ),
    (
        "H12", "Deep Ocean Pescatarian", "🌊🐟 Deep Ocean Pescatarian",
        "Zero Terrestrial Meat & Poultry (Marine seafood and eggs only)",
        "Finding high heme iron without red meat; avoiding egg phosvitin trap (Rule 2).",
        "Steamed mussels and clams, wild salmon, cod, tuna.",
        json.dumps({"exclude_categories": ["Fleisch"]})
    )
]

def populate_phase9_game_levels(conn: sqlite3.Connection):
    print("\n[Phase 9] Speichere 24 Level Progression & 12 Hero Modifiers aus LEVEL_GUIDE.md...")
    with conn:
        conn.executemany("""
            INSERT OR REPLACE INTO game_levels (
                id, tier, level_number, title, subtitle, badge, difficulty,
                target_formula, biochem_rationale, coaching_tip, tolerance_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, CORE_CAMPAIGN_LEVELS)

        conn.executemany("""
            INSERT OR REPLACE INTO hero_modifiers (
                id, title, badge, exclusion_boundary, biochem_conflict,
                solution_strategy, filter_rule_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """, HERO_MODIFIERS)

    print(f"  -> {len(CORE_CAMPAIGN_LEVELS)} Level und {len(HERO_MODIFIERS)} Hero-Challenges erfolgreich in speis.db hinterlegt.")

def build_speis_database(catalog_path: Path = CATALOG_PATH, output_path: Path = DB_OUTPUT_PATH):
    print("=" * 70)
    print(f"STARTE SPEIS DATENBANK-BUILD -> {output_path}")
    print("=" * 70)

    if not catalog_path.exists():
        raise FileNotFoundError(f"Lebensmittelkatalog nicht gefunden: {catalog_path}")

    with open(catalog_path, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    if output_path.exists():
        output_path.unlink()

    conn = sqlite3.connect(output_path)
    init_db_schema(conn)

    name_to_id = populate_phase1_master_spine(conn, catalog)
    populate_phase2_usda_nutrients(conn, catalog, name_to_id)
    populate_phase3_flavordb(conn, catalog, name_to_id)
    populate_phase4_seasonality(conn, catalog, name_to_id)
    populate_phase5_openfoodfacts(conn, name_to_id)
    populate_phases_6_7_8(conn, name_to_id)
    populate_phase9_game_levels(conn)

    v_foods_sql = BASE_DIR / "v_foods_def.sql"
    if v_foods_sql.exists():
        with open(v_foods_sql, "r", encoding="utf-8") as vf:
            conn.executescript(vf.read())
            conn.commit()
            print("View v_foods created.")

    conn.close()
    size_kb = output_path.stat().st_size / 1024.0
    print("\n" + "=" * 70)
    print(f"BUILD VOLLSTÄNDIG: '{output_path}' ({size_kb:.1f} KB)")
    print("=" * 70)

if __name__ == "__main__":
    build_speis_database()
