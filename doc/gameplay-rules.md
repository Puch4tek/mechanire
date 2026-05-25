# Gameplay i reguły kolizji

## Ruch

- Ruch jest **tile-by-tile**.
- Prędkość gracza i enemy jest niezależna (`player_speed_px`, `enemy_speed_px`).
- Kierunek wejściowy trafia do kolejki (`queue_direction`) i jest stosowany, gdy ruch jest legalny.
- Gracz ma tryb **ciągłego ruchu**: gdy kierunek na wprost jest zablokowany, gra automatycznie wybiera możliwy skręt.
- Auto-skręt gracza ma krótki **grace period** (`player_auto_turn_delay`), żeby dać czas na ręczny input.
- Jeśli dostępnych jest kilka legalnych opcji, wybór jest losowy (`pick_random`) dla mniej przewidywalnego flow.
- Kandydaci przy bloku ściany: tylko lewo/prawo (bez zawracania).

## Kampania

- Kampania ładuje poziomy z `level_paths` w `scripts/GameController.gd`.
- Po zaliczeniu poziomu pokazywany jest ekran `LevelComplete`.
- `Reset` restartuje **obecny poziom** (`reset_current_level()`), nie całą kampanię.

## Extensions (pickupy)

- Na planszy istnieje aktywny pickup `Extension`.
- Gracz i enemy mogą go zjeść.
- Efekty:
  - gracz: rośnie + dostaje punkty o wartość extensiona,
  - enemy: rośnie (bez zmiany score gracza),
  - po zjedzeniu spawnuje się kolejny extension.

## Reguły zjadania i kolizji

### 1) Zjadanie od tyłu (rear-end)

- Działa dla `gracz <-> enemy` według kierunku kontaktu z ogonem.
- Gracz ma dodatkowo dopuszczenie zjadania ogona enemy od boku (obsługa zakrętów).

### 2) Zjadanie głowy od tyłu

- Gracz może zjeść głowę enemy od tyłu.
- Enemy może zjeść głowę gracza od tyłu.

### 3) Zjadanie od przodu przy przewadze długości

- Dłuższy wąż może zjeść krótszego od przodu (`gracz->enemy` i `enemy->gracz`).
- Warunek: atakujący musi mieć więcej segmentów niż cel.

### 4) Kolizje enemy vs enemy

- Enemy **nie eliminują** siebie nawzajem klasyczną kolizją.
- Bezpośrednie stackowanie na tym samym ciele jest blokowane.
- Dla head-to-head istnieje specjalny mechanizm rozplątania (kontrolowany swap głów).
- AI enemy ma dodatkowy fallback wyboru kierunku, który preferuje ruch bez blokowania innych enemy.

## Warunki końca

- `GAME_OVER`: gracz zostaje wyeliminowany.
- `LEVEL_CLEAR`: poziom zaczynał z enemy i wszystkie enemy zostały usunięte (w tym brak oczekujących spawnów).

## Score

- Pickup extensiona przez gracza: `+extension.value`.
- Skuteczne zjedzenie enemy przez gracza: `+1`.

## Audio

- Pickup extensiona: `assets/Pickup.wav`.
- Zjedzenie segmentu enemy: `assets/Hit1.wav`.

