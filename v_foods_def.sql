CREATE VIEW v_foods AS
SELECT f.id,
       f.name_en AS name,
       f.name_de AS name_de,
       f.name_en AS name_en,
       '' AS name_fr,
       '' AS name_es,
       '' AS name_it,
       f.category,
       '' AS category_de,
       '' AS category_fr,
       '' AS category_es,
       '' AS category_it,
       f.meal_role,
       f.gi_class,
       f.gastric_emptying_hours,
       COALESCE(fn.calories_kcal, 0.0) AS calories,
       COALESCE(fn.carbs_g, 0.0) AS carbs,
       COALESCE(fn.protein_g, 0.0) AS protein,
       COALESCE(fn.fat_g, 0.0) AS fat,
       COALESCE(fn.fiber_g, 0.0) AS fiber,
       COALESCE(fn.fat_saturated_g, 0.0) AS sat_fat,
       COALESCE(fn.fat_monounsaturated_g, 0.0) AS mufa,
       COALESCE(fn.fat_polyunsaturated_g, 0.0) AS pufa,
       COALESCE(fn.omega_3_g, 0.0) AS omega_3,
       COALESCE(fn.omega_6_g, 0.0) AS omega_6,
       COALESCE(fn.calcium_mg, 0.0) AS calcium,
       COALESCE(fn.iron_mg, 0.0) AS iron,
       COALESCE(fn.zinc_mg, 0.0) AS zinc,
       COALESCE(fn.copper_mg, 0.0) AS copper,
       COALESCE(fn.magnesium_mg, 0.0) AS magnesium,
       COALESCE(fn.potassium_mg, 0.0) AS potassium,
       COALESCE(fn.sodium_mg, 0.0) AS sodium,
       COALESCE(fn.vitamin_a_ug, 0.0) AS vitamin_a,
       COALESCE(fn.vitamin_c_mg, 0.0) AS vitamin_c,
       COALESCE(fn.vitamin_d_ug, 0.0) AS vitamin_d,
       COALESCE(fn.vitamin_e_mg, 0.0) AS vitamin_e,
       COALESCE(fn.vitamin_k_ug, 0.0) AS vitamin_k,
       COALESCE(fn.thiamine_mg, 0.0) AS thiamine,
       COALESCE(fn.leucine_g, 0.0) AS leucine,
       COALESCE(fn.tryptophan_g, 0.0) AS tryptophan,
       COALESCE(fb.iron_type, 'none') AS iron_type,
       COALESCE(fb.is_dairy_calcium, 0) AS is_dairy_calcium,
       COALESCE(fb.polyphenol_level, 0) AS polyphenol_level,
       COALESCE(fb.contains_caffeine, 0) AS contains_caffeine,
       COALESCE(fb.phytate_mg, 0.0) AS phytate_mg,
       COALESCE(fb.oxalate_mg, 0.0) AS oxalate_mg,
       COALESCE(fb.is_viscous_fiber, 0) AS is_viscous_fiber,
       COALESCE(fb.is_nightshade, 0) AS is_nightshade,
       COALESCE(fb.is_seed, 0) AS is_seed,
       COALESCE(fb.fodmap_level, 'low') AS fodmap_level,
       COALESCE(fb.is_fermented, 0) AS is_fermented,
       COALESCE(fb.has_phosvitin, 0) AS has_phosvitin,
       CASE
           WHEN f.name_en LIKE '%Pineapple%' OR f.name_de LIKE '%Ananas%' THEN '🍍'
           WHEN f.name_en LIKE '%Pear%' OR f.name_de LIKE '%Birne%' THEN '🍐'
           WHEN f.name_en LIKE '%Apple%' OR f.name_de LIKE '%Apfel%' OR f.name_de LIKE '%Äpfel%' THEN '🍎'
           WHEN f.name_en LIKE '%Banana%' OR f.name_de LIKE '%Banane%' THEN '🍌'
           WHEN f.name_en LIKE '%Strawberry%' OR f.name_de LIKE '%Erdbeer%' THEN '🍓'
           WHEN f.name_en LIKE '%Cherry%' OR f.name_de LIKE '%Kirsch%' THEN '🍒'
           WHEN f.name_en LIKE '%Berry%' OR f.name_en LIKE '%Berries%' OR f.name_en LIKE '%Blueberry%' OR f.name_de LIKE '%Beere%' THEN '🫐'
           WHEN f.name_en LIKE '%Lemon%' OR f.name_en LIKE '%Lime%' OR f.name_de LIKE '%Zitrone%' OR f.name_de LIKE '%Limette%' THEN '🍋'
           WHEN f.name_en LIKE '%Orange%' OR f.name_en LIKE '%Mandarin%' OR f.name_en LIKE '%Grapefruit%' OR f.name_de LIKE '%Orange%' OR f.name_de LIKE '%Mandarine%' THEN '🍊'
           WHEN f.name_en LIKE '%Peach%' OR f.name_en LIKE '%Apricot%' OR f.name_en LIKE '%Plum%' OR f.name_de LIKE '%Pfirsich%' OR f.name_de LIKE '%Aprikose%' OR f.name_de LIKE '%Pflaume%' THEN '🍑'
           WHEN f.name_en LIKE '%Grape%' OR f.name_en LIKE '%Raisin%' OR f.name_de LIKE '%Traube%' OR f.name_de LIKE '%Rosine%' THEN '🍇'
           WHEN f.name_en LIKE '%Melon%' OR f.name_de LIKE '%Melone%' THEN '🍉'
           WHEN f.name_en LIKE '%Kiwi%' OR f.name_de LIKE '%Kiwi%' THEN '🥝'
           WHEN f.name_en LIKE '%Mango%' OR f.name_de LIKE '%Mango%' THEN '🥭'
           WHEN f.name_en LIKE '%Avocado%' OR f.name_de LIKE '%Avocado%' THEN '🥑'
           WHEN f.name_en LIKE '%Sweet potato%' OR f.name_de LIKE '%Süßkartoffel%' THEN '🍠'
           WHEN f.name_en LIKE '%Potato%' OR f.name_de LIKE '%Kartoffel%' THEN '🥔'
           WHEN f.name_en LIKE '%Carrot%' OR f.name_en LIKE '%Parsnip%' OR f.name_de LIKE '%Karotte%' OR f.name_de LIKE '%Möhre%' OR f.name_de LIKE '%Pastinake%' THEN '🥕'
           WHEN f.name_en LIKE '%Tomato%' OR f.name_de LIKE '%Tomate%' THEN '🍅'
           WHEN f.name_en LIKE '%Pepper%' OR f.name_de LIKE '%Paprika%' THEN '🫑'
           WHEN f.name_en LIKE '%Zucchini%' OR f.name_en LIKE '%Cucumber%' OR f.name_de LIKE '%Zucchini%' OR f.name_de LIKE '%Gurke%' THEN '🥒'
           WHEN f.name_en LIKE '%Broccoli%' OR f.name_en LIKE '%Cauliflower%' OR f.name_de LIKE '%Brokkoli%' OR f.name_de LIKE '%Blumenkohl%' OR f.name_de LIKE '%Rosenkohl%' OR f.name_de LIKE '%Kohlrabi%' THEN '🥦'
           WHEN f.name_en LIKE '%Spinach%' OR f.name_en LIKE '%Kale%' OR f.name_en LIKE '%Cabbage%' OR f.name_de LIKE '%Spinat%' OR f.name_de LIKE '%Kohl%' OR f.name_de LIKE '%Mangold%' OR f.name_de LIKE '%Sauerkraut%' THEN '🥬'
           WHEN f.name_en LIKE '%Salad%' OR f.name_en LIKE '%Lettuce%' OR f.name_de LIKE '%Salat%' OR f.name_de LIKE '%Rucola%' THEN '🥗'
           WHEN f.name_en LIKE '%Onion%' OR f.name_en LIKE '%Leek%' OR f.name_de LIKE '%Zwiebel%' OR f.name_de LIKE '%Lauch%' OR f.name_de LIKE '%Porree%' THEN '🧅'
           WHEN f.name_en LIKE '%Garlic%' OR f.name_de LIKE '%Knoblauch%' THEN '🧄'
           WHEN f.name_en LIKE '%Mushroom%' OR f.name_de LIKE '%Pilz%' OR f.name_de LIKE '%Champignon%' OR f.name_de LIKE '%Pfifferling%' THEN '🍄'
           WHEN f.name_en LIKE '%Corn%' OR f.name_de LIKE '%Mais%' THEN '🌽'
           WHEN f.name_en LIKE '%Eggplant%' OR f.name_de LIKE '%Aubergine%' THEN '🍆'
           WHEN f.name_en LIKE '%Oat%' OR f.name_en LIKE '%Porridge%' OR f.name_en LIKE '%Muesli%' OR f.name_en LIKE '%Quinoa%' OR f.name_en LIKE '%Millet%' OR f.name_en LIKE '%Buckwheat%' OR f.name_de LIKE '%Hafer%' OR f.name_de LIKE '%Müsli%' OR f.name_de LIKE '%Hirse%' OR f.name_de LIKE '%Buchweizen%' OR f.name_de LIKE '%Flocken%' THEN '🥣'
           WHEN f.name_en LIKE '%Bread%' OR f.name_en LIKE '%Roll%' OR f.name_en LIKE '%Toast%' OR f.name_de LIKE '%Brot%' OR f.name_de LIKE '%Brötchen%' THEN '🍞'
           WHEN f.name_en LIKE '%Rice%' OR f.name_de LIKE '%Reis%' THEN '🍚'
           WHEN f.name_en LIKE '%Pasta%' OR f.name_en LIKE '%Spaghetti%' OR f.name_en LIKE '%Noodle%' OR f.name_de LIKE '%Nudel%' OR f.name_de LIKE '%Spaghetti%' THEN '🍝'
           WHEN f.name_en LIKE '%Lentil%' OR f.name_en LIKE '%Bean%' OR f.name_en LIKE '%Chickpea%' OR f.name_en LIKE '%Pea%' OR f.name_de LIKE '%Linse%' OR f.name_de LIKE '%Bohne%' OR f.name_de LIKE '%Kichererbse%' OR f.name_de LIKE '%Erbse%' THEN '🫘'
           WHEN f.name_en LIKE '%Tofu%' OR f.name_en LIKE '%Tempeh%' OR f.name_en LIKE '%Butter%' OR f.name_de LIKE '%Butter%' OR f.name_de LIKE '%Margarine%' OR f.name_de LIKE '%Schmalz%' THEN '🧈'
           WHEN f.name_en LIKE '%Olive oil%' OR f.name_en LIKE '%Oil%' OR f.name_de LIKE '%Öl%' THEN '🫒'
           WHEN f.name_en LIKE '%Walnut%' OR f.name_en LIKE '%Nut%' OR f.name_en LIKE '%Almond%' OR f.name_en LIKE '%Cashew%' OR f.name_en LIKE '%Peanut%' OR f.name_en LIKE '%Pistachio%' OR f.name_de LIKE '%Nuss%' OR f.name_de LIKE '%Nüsse%' OR f.name_de LIKE '%Mandel%' OR f.name_de LIKE '%Cashew%' OR f.name_de LIKE '%Pistazie%' OR f.name_de LIKE '%Maroni%' THEN '🥜'
           WHEN f.name_en LIKE '%Seed%' OR f.name_en LIKE '%Psyllium%' OR f.name_de LIKE '%Samen%' OR f.name_de LIKE '%Kerne%' THEN '🌱'
           WHEN f.name_en LIKE '%Beef%' OR f.name_en LIKE '%Steak%' OR f.name_en LIKE '%Pork%' OR f.name_en LIKE '%Veal%' OR f.name_en LIKE '%Lamb%' OR f.name_en LIKE '%Ham%' OR f.name_de LIKE '%Rind%' OR f.name_de LIKE '%Schwein%' OR f.name_de LIKE '%Kalb%' OR f.name_de LIKE '%Lamm%' OR f.name_de LIKE '%Schinken%' OR f.name_de LIKE '%Wurst%' THEN '🥩'
           WHEN f.name_en LIKE '%Chicken%' OR f.name_en LIKE '%Turkey%' OR f.name_en LIKE '%Duck%' OR f.name_de LIKE '%Hähnchen%' OR f.name_de LIKE '%Huhn%' OR f.name_de LIKE '%Pute%' OR f.name_de LIKE '%Ente%' OR f.name_de LIKE '%Gans%' THEN '🍗'
           WHEN f.name_en LIKE '%Shrimp%' OR f.name_en LIKE '%Prawn%' OR f.name_de LIKE '%Garnele%' OR f.name_de LIKE '%Krabbe%' OR f.name_de LIKE '%Muschel%' THEN '🦐'
           WHEN f.name_en LIKE '%Salmon%' OR f.name_en LIKE '%Tuna%' OR f.name_en LIKE '%Fish%' OR f.name_en LIKE '%Trout%' OR f.name_en LIKE '%Cod%' OR f.name_en LIKE '%Herring%' OR f.name_en LIKE '%Mackerel%' OR f.name_de LIKE '%Lachs%' OR f.name_de LIKE '%Thunfisch%' OR f.name_de LIKE '%Forelle%' OR f.name_de LIKE '%Kabeljau%' OR f.name_de LIKE '%Hering%' OR f.name_de LIKE '%Makrele%' OR f.name_de LIKE '%Fisch%' THEN '🐟'
           WHEN f.name_en LIKE '%Egg%' OR f.name_de LIKE '%Ei%' OR f.name_de LIKE '%Hühnerei%' THEN '🥚'
           WHEN f.name_en LIKE '%Cheese%' OR f.name_en LIKE '%Mozzarella%' OR f.name_en LIKE '%Parmesan%' OR f.name_en LIKE '%Gouda%' OR f.name_en LIKE '%Feta%' OR f.name_de LIKE '%Käse%' OR f.name_de LIKE '%Camembert%' OR f.name_de LIKE '%Brie%' THEN '🧀'
           WHEN f.name_en LIKE '%Yogurt%' OR f.name_en LIKE '%Milk%' OR f.name_en LIKE '%Quark%' OR f.name_en LIKE '%Skyr%' OR f.name_en LIKE '%Kefir%' OR f.name_de LIKE '%Joghurt%' OR f.name_de LIKE '%Milch%' OR f.name_de LIKE '%Quark%' OR f.name_de LIKE '%Sahne%' OR f.name_de LIKE '%Schmand%' THEN '🥛'
           WHEN f.name_en LIKE '%Coffee%' OR f.name_en LIKE '%Espresso%' OR f.name_de LIKE '%Kaffee%' THEN '☕'
           WHEN f.name_en LIKE '%Tea%' OR f.name_de LIKE '%Tee%' THEN '🍵'
           WHEN f.name_en LIKE '%Whey%' OR f.name_en LIKE '%Protein%' OR f.name_en LIKE '%Juice%' OR f.name_de LIKE '%Saft%' THEN '🥤'
           WHEN f.name_en LIKE '%Water%' OR f.name_de LIKE '%Wasser%' THEN '💧'
           WHEN f.name_en LIKE '%Honey%' OR f.name_en LIKE '%Syrup%' OR f.name_de LIKE '%Honig%' OR f.name_de LIKE '%Sirup%' THEN '🍯'
           WHEN f.name_en LIKE '%Chocolate%' OR f.name_en LIKE '%Cocoa%' OR f.name_de LIKE '%Schokolade%' OR f.name_de LIKE '%Kakao%' THEN '🍫'
           WHEN f.category LIKE '%Getreide%' OR f.category LIKE '%Cereal%' OR f.category LIKE '%Grain%' THEN '🌾'
           WHEN f.category LIKE '%Fleisch%' OR f.category LIKE '%Meat%' THEN '🥩'
           WHEN f.category LIKE '%Fisch%' OR f.category LIKE '%Fish%' THEN '🐟'
           WHEN f.category LIKE '%Eier%' OR f.category LIKE '%Egg%' THEN '🥚'
           WHEN f.category LIKE '%Obst%' OR f.category LIKE '%Fruit%' THEN '🍎'
           WHEN f.category LIKE '%Gemüse%' OR f.category LIKE '%Vegetable%' THEN '🥦'
           WHEN f.category LIKE '%Salat%' OR f.category LIKE '%Salad%' THEN '🥗'
           WHEN f.category LIKE '%Hülsenfrüchte%' OR f.category LIKE '%Legume%' THEN '🫘'
           WHEN f.category LIKE '%Nüsse%' OR f.category LIKE '%Nut%' OR f.category LIKE '%Samen%' THEN '🥜'
           WHEN f.category LIKE '%Öle%' OR f.category LIKE '%Fette%' OR f.category LIKE '%Oil%' THEN '🫒'
           WHEN f.category LIKE '%Kräuter%' OR f.category LIKE '%Herb%' OR f.category LIKE '%Spice%' THEN '🌿'
           WHEN f.category LIKE '%Milch%' OR f.category LIKE '%Dairy%' THEN '🥛'
           WHEN f.category LIKE '%Süß%' OR f.category LIKE '%Sweet%' THEN '🍯'
           WHEN f.category LIKE '%Getränk%' OR f.category LIKE '%Beverage%' THEN '🥤'
           ELSE '🥗'
       END AS icon,
       CASE
           WHEN f.name_en LIKE '%Egg%' THEN 50
           WHEN f.name_en LIKE '%Bread%' THEN 50
           WHEN f.name_en LIKE '%Oat%' THEN 80
           WHEN f.name_en LIKE '%Oil%' OR f.name_en LIKE '%Butter%' THEN 10
           WHEN f.name_en LIKE '%Walnut%' OR f.name_en LIKE '%Nut%' OR f.name_en LIKE '%Seed%' OR f.name_en LIKE '%Cashew%' OR f.name_en LIKE '%Almond%' THEN 20
           WHEN f.name_en LIKE '%Coffee%' OR f.name_en LIKE '%Tea%' THEN 200
           WHEN f.name_en LIKE '%Milk%' OR f.name_en LIKE '%Yogurt%' THEN 150
           WHEN f.name_en LIKE '%Psyllium%' THEN 5
           WHEN f.name_en LIKE '%Whey%' THEN 25
           ELSE 100
       END AS serving_size,
       'g' AS serving_unit,
       '' AS barcode
FROM foods f
LEFT JOIN food_nutrients fn ON f.id = fn.food_id AND fn.preparation_state = (
    SELECT fn2.preparation_state FROM food_nutrients fn2 WHERE fn2.food_id = f.id
    ORDER BY CASE fn2.preparation_state WHEN 'raw' THEN 1 WHEN 'cooked' THEN 2 WHEN 'boiled' THEN 3 ELSE 4 END LIMIT 1
)
LEFT JOIN food_biochem fb ON f.id = fb.food_id;
