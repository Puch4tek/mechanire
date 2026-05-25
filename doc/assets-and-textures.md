# Assety, tekstury i audio

## Foldery assetów

- `assets/golona` - tekstury gracza
- `assets/sobczi` - tekstury enemy
- `assets/arrows` - grafiki D-pada (`pressed` / `depressed`)
- `assets/Pickup.wav` - SFX pickupa
- `assets/Hit1.wav` - SFX zjadania segmentu

## Rola tekstur węża

Dla gracza i enemy są używane role:

- `head_texture`
- `body_texture`
- `tail_texture`
- `head_transition_texture`
- `tail_transition_texture`
- `corner_texture`

Mapowanie i rotacje są realizowane w `scripts/Snake.gd` (`update_positions`, helpery rotacji).

## Skalowanie segmentów

- Domyślna komórka planszy ma 64x64 px (`tile_size=64`).
- Segmenty są pozycjonowane po centrach komórek (`grid_to_world`).
- Klasa segmentu (`scripts/SnakeSegment.gd`) obsługuje dopasowanie skali tekstury do `tile_size`.

## D-pad

W aktualnym układzie D-pad używa `TextureButton` z:

- stanem normalnym (`depressed`),
- stanem wciśniętym (`pressed`).

Skalowanie i pozycję panelu kontroluje `scripts/Game.gd`.

## Dobre praktyki importu

Przy pixel arcie i spritesheetach:

- preferuj nearest filtering,
- uważaj na bleeding między klatkami (padding/ustawienia importu),
- trzymaj spójny rozmiar źródłowych assetów dla tych samych ról.

## Fallback ładowania tekstur

`GameController` ma helper `load_texture_from_folder(...)`:

- ładuje role tekstur z folderu gracza/enemy,
- daje fallbacki, gdy część plików nie istnieje.

To upraszcza podmiany paczek graficznych bez zmian w scenie.

