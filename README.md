# GTA 6 – Elektronika

Retro LCD hra inspirovaná kapesními hrami z 80. let, vytvořená v Godotu pro Windows.

Chytej pytle do tašky ve čtyřech pozicích. Pytel s dolary přidá 1 bod, vzácnější kontraband 5 bodů. Za každý nezachycený pytel ztratíš jeden ze tří životů. S rostoucím skóre přibývají předměty z různých drah a zrychluje tempo.

## Spuštění

**[Stáhnout Windows x64 verzi v1.0.0](https://github.com/matrixgp/GTA6_Retro_LCD/releases/latest)** – rozbal ZIP a spusť EXE.

Hotová Windows x64 verze obsahuje všechna data v jediném souboru `GTA6_Elektronika.exe`. Godot ani instalace nejsou potřeba. Balíček pro distribuci: `GTA6_Elektronika_Windows_x64.zip`.

## Ovládání

| Klávesa | Akce |
| --- | --- |
| Šipky vlevo / vpravo | Otočení postavy |
| Šipky nahoru / dolů | Výška tašky |
| Enter | Start, nová hra nebo potvrzení jména |
| Mezerník | Pauza a pokračování |
| T | TOP 10 v menu nebo při pauze |
| M | Zapnutí / vypnutí zvuku |

Do TOP 10 zadáš tři písmena klávesnicí nebo pomocí šipek a potvrdíš Enterem. Rekordy a nastavení zvuku se ukládají lokálně. Hodiny zobrazují aktuální systémový čas.

## Projekt a sestavení

1. Otevři `project.godot` v Godotu 4.7.2.
2. Hlavní scéna je `main.tscn`; hru spustíš klávesou F6 nebo F5.
3. Pro Windows export spusť PowerShell skript `.export_tools/prepare_templates.ps1`. Stáhne oficiální exportní šablony a ověří jejich SHA-512.
4. Exportuj preset **Windows Desktop**. Přednastavený výstup je `dist/GTA6_Elektronika.exe` s vloženými daty hry.

Podrobnosti sestavení jsou v [.export_tools/BUILD_NOTES.md](.export_tools/BUILD_NOTES.md). Zdrojové kontroly herní logiky, pauzy, rekordů, zvuku a animací jsou ve složce `tests/`; spouštějí se přes Godot `--headless --path . --script res://tests/<soubor>.gd`.

## Poznámka

Neoficiální fanouškovský projekt inspirovaný GTA a retro LCD hrami. Není spojený s Rockstar Games ani Take-Two Interactive. Názvy a značky patří jejich vlastníkům. Zvukové efekty jsou syntetizované ve hře.

Godot a jeho komponenty mají vlastní licence; jejich úplný přehled je přiložen k distribučnímu balíčku jako `GODOT_LICENCE.txt`.
