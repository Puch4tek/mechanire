# Architektura gry

## Przegląd

Projekt używa klasycznego podziału na:

- **prezentację sceny** (`scenes/*.tscn`),
- **logikę runtime** (`scripts/*.gd`),
- **dane poziomów jako resource** (`resources/*.tres`, klasa `LevelData`).

Główna scena rozgrywki to `scenes/Game.tscn`.

## Główne komponenty runtime

### `scripts/GameController.gd`

Orkiestrator gameplayu.

Odpowiada za:

- stan gry (`RUNNING`, `GAME_OVER`, `LEVEL_CLEAR`),
- flow kampanii (ładowanie poziomów 1..10),
- tick ruchu gracza i enemy,
- kolizje i reguły zjadania,
- spawn i pickup `extensions`,
- score i etykiety UI,
- audio SFX (`Pickup.wav`, `Hit1.wav`).

### `scripts/Snake.gd`

Pojedynczy model węża (działa zarówno dla gracza, jak i enemy).

Odpowiada za:

- listę segmentów i ich komórki (`segment_cells`),
- ruch tile-by-tile z akumulatorem czasu,
- wzrost/skracanie,
- render segmentów i dobór tekstur (head/body/tail/corner/transition),
- kolejność rysowania (`z_index`) podczas cofania fali segmentów.

### `scripts/GridController.gd`

Warstwa planszy i ścian.

Odpowiada za:

- załadowanie `LevelData`,
- budowę siatki ścian na bazie bitmask,
- render tilemapy,
- `can_move(cell, dir)` (autorytatywne sprawdzanie ruchu),
- centrowanie planszy względem viewportu.

### `scripts/Game.gd`

Kontroler UI i inputu sceny `Game`.

Odpowiada za:

- pozycjonowanie HUD względem planszy i safe area,
- adaptacyjny rozmiar D-pada,
- reset/pauza,
- przekazywanie wejścia strzałek do `GameController.queue_direction(...)`.

### `scripts/LevelData.gd`

Model danych poziomu.

Kluczowe pola:

- rozmiar (`width`, `height`),
- spawny gracza/enemy i parametry boksów startowych,
- ściany (`cells_2d`, fallback `cells`).

## Zależności między komponentami

- `GameController` korzysta z `GridController` i obiektu gracza `Snake`.
- Enemy to osobne instancje sceny `Snake`.
- `Game` nie zawiera logiki kolizji - tylko UI/layout/input i delegację do `GameController`.
- `GridController.can_move(...)` jest centralnym gatekeeperem ruchu po mapie.

## Pętla runtime (wysoki poziom)

W `GameController._process(delta)`:

1. tick gracza,
2. release enemy ze spawnu,
3. aktualizacja kierunku AI enemy w interwale,
4. tick enemy,
5. sprawdzenie warunku końca poziomu.

## Gdzie rozszerzać kod

- Nowa reguła kolizji/zjadania: `scripts/GameController.gd` (`try_advance_snake`, helpery kolizji).
- Nowe zachowanie ruchu segmentów: `scripts/Snake.gd`.
- Nowy format level resource: `scripts/LevelData.gd` + `scripts/GridController.gd`.
- Zmiany UX mobilnego/HUD: `scripts/Game.gd`.

