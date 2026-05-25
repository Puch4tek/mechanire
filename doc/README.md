# Dokumentacja projektu

Ten folder zawiera dokumentację techniczną gry `serpentine-mechanik`.

## Spis

- `doc/architecture.md` - architektura runtime, zależności scen i skryptów
- `doc/code-reference.md` - referencja API skryptów (funkcje, hooki, punkty wejścia)
- `doc/gameplay-rules.md` - zasady gameplayu i kolizji
- `doc/ai.md` - logika AI węży enemy
- `doc/level-format.md` - format poziomów (`LevelData`, maski ścian, spawn)
- `doc/ui-and-mobile.md` - HUD, D-pad, safe area, edge-to-edge
- `doc/assets-and-textures.md` - pipeline tekstur, role sprite'ów i audio

## Szybki onboarding (dla deva)

1. Zacznij od `doc/architecture.md`.
2. Potem przeczytaj `doc/gameplay-rules.md` i `doc/ai.md`.
3. Jeśli edytujesz poziomy: `doc/level-format.md`.
4. Jeśli poprawiasz UX mobilny/HUD: `doc/ui-and-mobile.md`.
5. Jeśli poprawiasz grafiki/sound: `doc/assets-and-textures.md`.

## Źródła prawdy

- Główna logika gry: `scripts/GameController.gd`
- Ruch i render segmentów: `scripts/Snake.gd`
- Siatka i ściany: `scripts/GridController.gd`
- Layout UI i input D-pada: `scripts/Game.gd`
- Definicja danych poziomu: `scripts/LevelData.gd`


