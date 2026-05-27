# TODO — Documentation fixes

Issues found during a `/docs` review on 2026-05-27. All items are doc drift, not code bugs.

## High priority — wrong facts

- [x] **Schema version is recorded three different ways.** Align all three to v6:
  - [docs/schema.sql:1](docs/schema.sql) — header says `(v5)` and `PRAGMA user_version = 5`; bump to v6.
  - [docs/architecture.md:135](docs/architecture.md) — "`PRAGMA user_version` **4**"; bump to v6.
  - [docs/data-model.md:3](docs/data-model.md) — already correct at v6 (reference only).
  - Source of truth: [scripts/autoload/database.gd:165-188](scripts/autoload/database.gd) runs migrations through `_migrate_to_v6`.

- [x] **`SoundService` is undocumented.** Add it to:
  - Autoloads table in [docs/architecture.md](docs/architecture.md) (~line 153).
  - Services table in [docs/data-model.md](docs/data-model.md) (~line 146).
  - Source: [project.godot:27](project.godot), [scripts/autoload/sound_service.gd](scripts/autoload/sound_service.gd).

- [x] **`TagService` is missing from `architecture.md`.** Present in `data-model.md` but not in the Autoloads table or top-level flowchart in `architecture.md`.

- [x] **Daily / hourly aggregated metrics aren't documented.** Add a subsection under Pomodoro in [docs/data-model.md](docs/data-model.md) covering the rollup that drives the journal daily-metrics row.
  - Sources: [scripts/models/daily_work_stats.gd](scripts/models/daily_work_stats.gd), [scenes/journal/journal_daily_metrics_row.tscn](scenes/journal/journal_daily_metrics_row.tscn), aggregation methods on [scripts/autoload/pomodoro_service.gd](scripts/autoload/pomodoro_service.gd) / [scripts/autoload/database.gd](scripts/autoload/database.gd).

## Medium priority — incomplete repo layout

- [x] **Tests and GUT are invisible in the docs.** In [docs/architecture.md](docs/architecture.md):
  - Add `tests/` to the repo-layout block (~line 248).
  - Add one line noting tests run via GUT (`addons/gut`, configured by `.gutconfig.json`).
  - Source: 23 spec files in [tests/](tests), GUT enabled at [project.godot:38](project.godot).

- [x] **`scripts/` subdirs under-listed.** Architecture repo-layout block lists `{app,autoload,database,models,tools}/`; actual tree also has `journal/`, `tasks/`, `tags/`, `ui/`, `util/`.

- [x] **`assets/sounds/` missing from repo-layout block** in [docs/architecture.md](docs/architecture.md) (~line 248). Referenced by `SoundService`.

## Low priority — polish

- [x] **Flowchart naming is inconsistent.** [docs/architecture.md:27-66](docs/architecture.md) references `JournalUI` / `TaskUI` nodes in the wiring section but defines `JournalArea` / `TaskSidebar` in the presentation subgraph. Unify the names.

- [x] **Stale roadmap wording in `architecture.md:19`.** "Sync/backup on roadmap item **6**" — that item is now shipped per the README. Reword to a status descriptor.

- [x] **Pomodoro polish phrasing differs.** [docs/architecture.md:198](docs/architecture.md) says "Deferred"; README says "Not on roadmap — see recommendations". Pick one phrasing.

- [x] **Godot doc links are on 4.6.** Project targets 4.7. Update References in [docs/architecture.md:262-266](docs/architecture.md).

- [ ] **Screenshot may be stale.** [docs/screenshots/Screenshot_20260521_093840.png](docs/screenshots/Screenshot_20260521_093840.png) predates the daily-metrics row landing. Recapture manually (OS screenshot of a running build) when convenient.
  - **Note:** [scripts/tools/capture_screenshot.gd](scripts/tools/capture_screenshot.gd) is currently broken under Godot 4.7 — `--script` mode loads `main.tscn` before autoloads register, so `PomodoroService` / `Database` references fail to compile; `Timer.start()` also fails inside `SceneTree._init()` because children aren't yet inside the tree. Either fix the tool first (defer scene instantiation + start the timer from a process callback) or just use an OS screenshot.
