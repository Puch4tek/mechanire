# Format poziomów (`LevelData`)

Poziomy są zapisane jako `Resource` (`.tres`) klasy `LevelData`.

## Pola `LevelData`

- `width`, `height` - rozmiar siatki poziomu
- `snake_spawn` - fallback spawn gracza
- `player_spawn_box`, `player_spawn_direction`, `player_exit_cell` - konfiguracja boksu startowego gracza
- `enemy_spawns`, `enemy_spawn_directions`, `enemy_exit_cells` - dane spawnów enemy (część flow może być nadpisywana przez `GameController`)
- `cells_2d` - preferowany format ścian (wiersze)
- `cells` - legacy fallback (tablica 1D)

## Ściany i bitmaski

Każda komórka ma maskę ścian `0..15`.

### Bity

- `1` = top
- `2` = right
- `4` = bottom
- `8` = left

### Tabela wartości

- `0` = no walls
- `1` = top
- `2` = right
- `3` = top + right
- `4` = bottom
- `5` = bottom + top
- `6` = bottom + right
- `7` = top + right + bottom
- `8` = left
- `9` = left + top
- `10` = left + right
- `11` = left + right + top
- `12` = bottom + left
- `13` = bottom + left + top
- `14` = bottom + left + right
- `15` = all walls

## Jak działa ruch względem ścian

Ruch sprawdza aktualną komórkę i kierunek (`GridController.can_move`).

Przykład:

- ruch w prawo jest zablokowany, jeśli bieżąca komórka ma bit `RIGHT`.

To pozwala realizować m.in. one-way wyjścia z boksów startowych.

## Rekomendowany sposób edycji

1. Edytuj `cells_2d` (nie `cells`).
2. Zachowuj spójny `width` i `height` z liczbą kolumn/wierszy.
3. Po edycji uruchom grę i sprawdź:
   - legalność spawnów,
   - możliwość wyjścia z boksów,
   - brak softlocków ruchu.

## Kompatybilność

`LevelData.get_cell_mask(x, y)` najpierw czyta `cells_2d`, a gdy brak danych, używa `cells` (legacy).
