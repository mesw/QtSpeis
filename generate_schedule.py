DAY_PARTS = [
    {
        "title": "Tag",
        "start": "06:00",
        "end": "18:00",
        "icon": "☀️",
        "color": "#F59E0B",
        "periods": [
            ("Früher Morgen", 6, 9, "🌅"),
            ("Morgen", 9, 11, "🌤️"),
            ("Vormittag", 11, 13, "☕"),
            ("Nachmittag", 13, 16, "🥪"),
            ("Später Nachmittag", 16, 18, "🌇"),
        ],
    },
    {
        "title": "Nacht",
        "start": "18:00",
        "end": "06:00",
        "icon": "🌙",
        "color": "#1E3A8A",
        "periods": [
            ("Früher Abend", 18, 21, "🌆"),
            ("Später Abend", 21, 24, "🌌"),
            ("Späte Nacht", 0, 6, "🦉"),
        ],
    },
]

with open("schedule_1440_minutes.yaml", "w", encoding="utf-8") as f:
    f.write('version: "1.0"\n')
    f.write('title: "Vollständiger 24-Stunden-Ablauf auf Minutenebene"\n\n')
    f.write("plan:\n")

    for half in DAY_PARTS:
        f.write(f'  - title: "{half["title"]}"\n')
        f.write(f'    start: "{half["start"]}"\n')
        f.write(f'    end: "{half["end"]}"\n')
        f.write(f'    icon: {half["icon"]}\n')
        f.write(f'    color: "{half["color"]}"\n')
        f.write("    items:\n")

        for period_name, start_h, end_h, p_icon in half["periods"]:
            dur_h = (end_h - start_h) if end_h >= start_h else (24 - start_h + end_h)
            f.write(f'      - title: "{period_name}"\n')
            f.write(f'        start: "{start_h:02d}:00"\n')
            f.write(f'        duration: "{dur_h:02d}:00"\n')
            f.write(f"        icon: {p_icon}\n")
            f.write("        items:\n")

            hours_range = (
                range(start_h, end_h)
                if end_h > start_h
                else range(start_h, start_h + dur_h)
            )

            for h in hours_range:
                actual_h = h % 24
                next_h = (actual_h + 1) % 24
                f.write(
                    f'          - title: "Stunde {actual_h:02d}:00 - {next_h:02d}:00"\n'
                )
                f.write(f'            start: "{actual_h:02d}:00"\n')
                f.write('            duration: "01:00"\n')
                f.write("            icon: ⏳\n")
                f.write("            items:\n")

                for m in range(60):
                    next_m_val = (m + 1) % 60
                    next_h_val = (actual_h + 1) % 24 if m == 59 else actual_h
                    f.write(
                        f'              - title: "Minute {actual_h:02d}:{m:02d} - {next_h_val:02d}:{next_m_val:02d}"\n'
                    )
                    f.write(f'                start: "{actual_h:02d}:{m:02d}"\n')
                    f.write('                duration: "00:01"\n')
                    f.write("                icon: ⏱️\n")

print("Datei schedule_1440_minutes.yaml erfolgreich erstellt!")
