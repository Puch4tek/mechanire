# UI, HUD i mobile

## Główne założenia

UI sceny gry (`scenes/Game.tscn`) jest pozycjonowane dynamicznie przez `scripts/Game.gd`:

- względem planszy (`Maze`),
- z uwzględnieniem safe area ekranu,
- z clampowaniem do widocznego obszaru.

## HUD

- `ScoreLabel` i `LevelLabel` są po lewej stronie planszy, przy górnej części ekranu.
- `PauseButton`, `ResetButton` i `ArrowPanel` są po prawej stronie planszy.
- Rozmiar D-pada jest skalowany adaptacyjnie (`dpad_max_scale`) do wolnego miejsca.

## Safe area i rounded corners

`_get_safe_rect()` w `scripts/Game.gd`:

- pobiera `DisplayServer.get_display_safe_area()`,
- przelicza safe area z pikseli okna na viewport UI,
- używa fallbacku do pełnego viewportu, jeśli safe rect jest niepoprawny.

To ogranicza ryzyko ucinania UI przez notch / dynamic island / zaokrąglone rogi.

## Edge-to-edge

Konfiguracja edge-to-edge i kolorów tła jest po stronie eksportu (`export_presets.cfg`) i scen startowych.

## Input

- Klawiatura: `snake_*` i `ui_*`.
- Dotyk:
  - D-pad (`ArrowUp/Left/Right/Down`) wywołuje `queue_direction` przez `Game.gd`.
  - Dodatkowo swipe input jest obsługiwany w `GameController._input(...)`.

## Start screen

Layout startu jest sterowany oddzielnie (`scenes/StartScreen.tscn`, `scripts/StartScreen.gd`) i ma własne zasady tła/fill.

## Debug pomocniczy

- `scripts/BoardAreaHelper.gd` służy do wizualizacji obszaru planszy w edytorze.
- Helper jest użyteczny przy strojeniu pozycji HUD bez uruchamiania builda mobilnego.

