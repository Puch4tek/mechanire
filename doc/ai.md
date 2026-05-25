# AI enemy

## Cel AI

AI enemy wybiera kierunek co `enemy_direction_interval`.

Decyzja opiera się o skoring ruchu i obejmuje:

- gonienie gracza,
- gonienie najbliższego extensiona,
- atak, gdy warunki kolizji są korzystne,
- unikanie blokad i stackowania enemy,
- losowość (żeby ruch nie był deterministyczny).

## Wybór celu: gracz vs extension

W `get_enemy_objective(...)`:

1. AI szuka najbliższego extensiona (`get_nearest_extension_cell`).
2. Porównuje dystans do extensiona i do gracza.
3. Jeśli extension jest bliżej - wybiera extension.
4. W przeciwnym razie - wybiera gracza (z flankowaniem przez `ENEMY_RING_OFFSETS`).

## Commit celu

Żeby AI nie "skakało" nerwowo między celami co tick:

- istnieje commit celu na czas `enemy_objective_commit_time`,
- cache celu jest trzymany per enemy (`instance_id`),
- jeśli commitowany extension znika z planszy, cel jest wybierany ponownie.

To daje bardziej stabilne zachowanie, ale bez utraty responsywności.

## Skoring kierunku

`score_enemy_direction(...)` uwzględnia:

- dystans do aktywnego celu,
- bonus ataku przy wejściu w segment gracza (w trybie chase gracza),
- karę/bonus przestrzeni (`count_open_paths`),
- separację od innych enemy (`enemy_separation_score`),
- drobną preferencję utrzymania bieżącego kierunku,
- losowość (`enemy_random_weight`).

## Anty-zakleszczenia

- Blokada wejścia enemy w ciało innego enemy.
- Dopuszczony specjalny swap głów przy idealnym head-to-head (`try_resolve_enemy_head_swap`).
- Dzięki temu enemy nie stoją na sobie i rzadziej zapętlają się naprzeciwko.
- Gdy pełny skoring nie znajdzie legalnego ruchu, działa fallback `choose_enemy_nonblocking_direction(...)`, który wybiera pierwszy bezpieczny kierunek bez zajmowania pól innych enemy.

## Parametry tuningu

Najważniejsze eksporty w `scripts/GameController.gd`:

- `enemy_direction_interval`
- `enemy_chase_weight`
- `enemy_space_weight`
- `enemy_random_weight`
- `enemy_attack_score`
- `enemy_objective_commit_time`

## Proponowany workflow balansu

1. Ustal tempo decyzji (`enemy_direction_interval`).
2. Ustal "charakter" AI (`enemy_random_weight` i `enemy_chase_weight`).
3. Ustal stabilność celu (`enemy_objective_commit_time`).
4. Testuj na 3 przypadkach:
   - gracz daleko, extension blisko,
   - gracz blisko, extension daleko,
   - dwa enemy walczą o ten sam extension.

