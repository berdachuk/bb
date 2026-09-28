# bb — Документ требований к продукту (PRD)

> Английская версия: [PRD.md](PRD.md)

| Поле | Значение |
| --- | --- |
| Продукт | **bb** |
| Слоган | Агентный IDE, который строит сам себя |
| Статус | Активная разработка (ядро архитектуры стабильно; сценарии и поверхности ещё эволюционируют) |
| Лицензия | MIT |
| Последнее обновление | 2026-09-25 |
| Основная дистрибуция | Desktop-приложение (рекомендуется macOS arm64; Linux AppImage — альфа), `npx bb-app@latest` / `@nightly` |
| Сопутствующие поверхности | Web UI, CLI `bb`, TypeScript SDK / HTTP API, mobile (iOS early access), getbb.app (маркетинг + Connect) |
| Назначение документа | Зафиксировать продуктовый замысел, требования и границы на основе поставляемого кода и vision |
| Связанные документы | [docs/VISION.md](docs/VISION.md), [docs/system-overview.md](docs/system-overview.md), [docs/repository-overview.md](docs/repository-overview.md), [docs/server-move-plan.md](docs/server-move-plan.md), [docs/forkable-plugins.md](docs/forkable-plugins.md), [README.md](README.md) |

---

## 1. Краткое резюме

bb — это **программируемое рабочее пространство для coding-агентов**. Оно оркестрирует агентов, которых пользователь уже аутентифицировал (Claude Code, Codex, Pi, Cursor через ACP и другие ACP-совместимые агенты), запускает их работу в **потоках (threads)** внутри **окружений (environments)** на зарегистрированных **хостах (hosts)** и одинаково открывает эту систему через desktop/web UI, CLI, SDK и HTTP API.

Цель продукта — не одно чат-окно поверх model API. bb задуман как control plane личной или командной **software factory**: несколько агентов параллельно, управляемые workspace’ы, делегирование, плагины, удалённые машины и автоматизация — при этом продукт остаётся простым для локального запуска и заслуживающим доверия.

**Сервер — это роль на одной машине** (`primaryHostId`), а не «единственный компьютер, который может запускать агентов». Каждая enrolled-машина может исполнять работу; server-owned состояние (БД, настройки, server-данные плагинов, remote access) можно перенести на другую persistent-машину за experiment `serverMove`.

---

## 2. Постановка проблемы

### 2.1 Какие проблемы решает bb

1. **Работа агентов фрагментирована.** Coding-агенты живут в разных CLI и UI с несовместимыми моделями сессий — параллельная работа, handoff и контроль затруднены.
2. **Только-UI инструменты оставляют агентов и скрипты без доступа.** То, что существует лишь в GUI, нельзя автоматизировать или делегировать другим агентам.
3. **Контекст исполнения плохо задан.** Нужен явный выбор: править основной checkout, изолированные worktree, personal workspace, project checkout или облачные sandbox’ы — с понятным lifecycle и cleanup.
4. **Мультиустройство и несколько машин неудобны.** Пользователи хотят управлять агентами с ноутбука, телефона или браузера, оставляя исполнение на доверенной машине (или нескольких), а позже переносить роль сервера без старта с нуля.
5. **Командам нужна расширяемость без форка.** Провайдеры, окружения, UI-панели, инструменты и workflows должны подключаться плагинами, чтобы bb подстраивался под инфраструктуру, а не навязывал один «благословенный» стек.

### 2.2 Не-цели (продуктовая позиция)

- Заменять CLI провайдеров или владеть их auth (bb использует уже аутентифицированных провайдеров пользователя).
- Требовать hosted cloud-аккаунт для базового локального использования (Connect и облачные плагины расширяют bb, но не заменяют локальный продукт).
- Поставлять нативный Windows agent runtime (Windows поддерживается через Ubuntu на WSL2).
- Делать телефон полноценным execution host (mobile — поверхность управления сервером bb).
- Automatic failover или восстановление мёртвого сервера из бэкапа как основной путь переноса (v1 server move — плановый, кооперативный перенос при онлайн старом сервере).
- Делать required core из hosted bb account / bb cloud AI (попытка account + AI gateway была откачена; AI-задачи обслуживают plugin-registered services, сегодня first-party automatic путь — Codex).

---

## 3. Видение и принципы

По [docs/VISION.md](docs/VISION.md):

| Принцип | Следствие для требований |
| --- | --- |
| **Пользователи и агенты — равноправные операторы** | Каждая end-user возможность поставляется в UI, CLI и SDK/HTTP с сопоставимой функциональностью. |
| **Расширяемость** | Кастомные провайдеры, окружения, LLM-сервисы, CLI-интеграции и UI-поверхности через систему плагинов. |
| **Гибкость, а не жёсткость** | Сильные defaults плюс unmanaged-пути; managed и unmanaged сценарии ощущаются естественно. |
| **Работает там, где вы есть** | Local-first сегодня; удалённые хосты, Connect, облачные sandbox’ы, mobile-клиенты и перенос сервера без перестройки ядра. |
| **Быстро и понятно** | Отзывчивый UI, операционная простота, низкая когнитивная нагрузка. |
| **Легко доверять и внедрять** | Локальный режим остаётся оцениваемым при security-ограничениях; hosted-функции — опциональные расширения. |

---

## 4. Персоны и jobs-to-be-done

### 4.1 Персоны

| Персона | Потребности |
| --- | --- |
| **Индивидуальный power user / indie hacker** | Несколько агентов параллельно, изоляция рискованных правок в worktree, управление из CLI и UI, кастомизация плагинами. |
| **Инженер в команде** | Маппинг репозиториев на проекты, review вывода агентов, связка с GitHub issues/PR, Tasks/Workflows для плановой работы. |
| **Remote / multi-machine разработчик** | Исполнение на рабочей станции или cloud-боксе; управление из браузера или телефона через Connect или Tailscale; опциональный перенос роли сервера на always-on машину. |
| **Автор агентов / автоматизаций** | Программное управление bb (`BBSdk`, CLI `bb`, workflows, automations): spawn, wait, inspect, clear, делегирование потоков. |
| **Автор плагинов** | Расширять провайдеры, окружения, машины, UI-слоты, инструменты, browser scripting и skills без форка bb. |
| **Maintainer / contributor** | Чёткие архитектурные границы, контракты и gates для контрибуций. |

### 4.2 Основные задачи

1. Запустить работу агента по проекту в выбранном окружении и провайдере.
2. Следить за прогрессом вживую, прерывать, править сообщения, ставить follow-up в очередь, очищать контекст, вкладывать/делегировать потоки.
3. Смотреть diffs, файлы, терминалы, браузеры и артефакты; открывать работу в локальном редакторе, когда он доступен.
4. Масштабироваться на несколько машин (enrolled host daemons) и поверхностей управления (web, desktop, CLI, mobile); при необходимости переносить сервер.
5. Сохранять и переиспользовать контекст (memory, custom instructions, skills, tasks, annotations).
6. Автоматизировать повторяющуюся или многошаговую работу (automations с working directories, workflows, scheduled send, managers).

---

## 5. Продуктовые поверхности

Каждая поверхность — first-class. Паритет возможностей — жёсткое продуктовое требование, если поверхность явно не описана как частичная (например, mobile).

| Поверхность | Роль | Вход |
| --- | --- | --- |
| **Desktop app** | Рекомендуемая установка; Electron-оболочка супервизит packaged runtime и грузит web UI; helper локального редактора и desktop-браузер. | [desktop-latest](https://github.com/get-bb/bb/releases/tag/desktop-latest) / Nightly |
| **Packaged launcher** | `npx bb-app` поднимает server + host daemon + отдаёт UI; состояние в `~/.bb/`. | `npx bb-app@latest` → `http://localhost:38886` |
| **Web app** | Просмотр проектов/потоков/окружений; управление работой; настройки; UI плагинов; split panes. | Отдаётся сервером bb |
| **CLI (`bb`)** | Скриптуемое управление для людей и агентов: threads, projects, machines, plugins, providers, files, server move и т.д. | `npx --package bb-app bb …` |
| **SDK / HTTP API** | Программные клиенты; тот же server contract, что у приложения. | `import { BBSdk } from "bb-app"` |
| **Mobile app** | Нативный клиент управления (Expo); сначала iOS; pairing через Direct URL или bb connect. | TestFlight / сборки из исходников |
| **getbb.app** | Маркетинг + auth/dashboard Connect + просмотр plugin marketplace. | Cloudflare Workers (TanStack Start) |

### 5.1 Правила паритета поверхностей

- Новые end-user возможности **обязаны** поставляться в SDK и CLI `bb` вместе с UI и документироваться на discoverable поверхностях CLI/guide/skill.
- Mobile может опускать *frontend* плагинов, локальные daemon-функции и часть rich media; *backend* плагинов, pending interactions и базовое управление потоками должны работать там, где позволяет контракт.
- Возможности только для desktop (встроенная browser automation, annotations, локальный folder picker, editor helper) должны явно и понятно отказывать на поверхностях без co-located daemon/helper.

---

## 6. Системная архитектура (продуктовый взгляд)

### 6.1 Runtime-компоненты

| Компонент | Владеет | Не владеет |
| --- | --- | --- |
| **Server** | Продуктовая политика (defaults, instructions, поведение manager’ов, списки tools, поведение потоков); SQLite как source of truth; HTTP + WebSocket API; маршрутизация работы к демонам; server-owned данные плагинов и remote access. | Как workspace’ы провиженятся на диске; внутренности процессов провайдера за пределами daemon-контракта; host-owned файлы, которые остаются на машинах при переносе сервера. |
| **Host daemon** | Host-local примитивы: провиженинг workspace, lifecycle процессов провайдера, RPC-результаты, локальный helper API (открыть редактор, выбрать папку, статус демона). | Сборка продуктовой политики потоков/проектов. |
| **Clients (app / CLI / SDK / mobile)** | Презентация, скрипты и управление по server contract. | Прямая мутация состояния демона, кроме server + локальных helper API. |

**Пакеты контрактов (жёсткие границы):**

- `@bb/server-contract` — clients ↔ server (HTTP + WebSocket).
- `@bb/host-daemon-contract` — server ↔ host daemons (команды, события, локальный API).

Изменения wire-полей, меняющие смысл, обязательность или defaults протокола демона, требуют bump `HOST_DAEMON_PROTOCOL_VERSION`, чтобы зарегистрированные машины обновились.

### 6.2 Модель данных (ядро сущностей)

| Сущность | Определение |
| --- | --- |
| **Project** | Контейнер верхнего уровня, обычно репозиторий. Имеет один или несколько **sources** с расположением кода; каждый local-path source принадлежит конкретному enrolled host. Может нести project-scoped machine environment variables. |
| **Thread** | Единица работы: разговор с провайдером, lifecycle-состояние, append-only **events**. Обычные потоки делают работу; **manager**-потоки координируют другие. Потоки могут владеть дочерними для делегирования и вкладываться в sidebar. |
| **Environment** | Контекст исполнения: workspace path + host. **Unmanaged** (существующая директория) или **managed** (создан bb; очищается, когда не остаётся незаархивированных потоков). Несколько потоков могут делить окружение. |
| **Host / machine** | Долгоживущая daemon-идентичность execution-машины. Сервер работает на одном хосте (`primaryHostId`); можно enroll’ить удалённые. Project sources и environments сохраняют границу хоста. |
| **Lifecycle owner** | Опциональный неизменяемый `lifecycleOwnerThreadId` при создании: archive/delete владельца рекурсивно затрагивает dependents (side chats, workflow workers). Независимо от sidebar `parentThreadId` и fork `sourceThreadId`. |
| **Commands & events** | Сервер шлёт host RPC по daemon WebSocket; демоны публикуют прогресс провайдера/потока пакетами событий. Lifecycle-работа может завершаться асинхронно относительно вызывающего API. |
| **AI services** | Plugin-registered сервисы для заголовков потоков, commit messages и voice transcription. Выбор на задачу: `automatic`, `off` или service id (Settings → AI services / `bb settings ai-services`). Ключи `BB_INFERENCE` / `BB_TRANSCRIPTION` удалены. |

### 6.3 Lifecycle потока (статусы)

Статусы: `pending` → `starting` → `active` ↔ `idle`, плюс `stopping` и `error` как исходы исполнения.

| Статус | Смысл |
| --- | --- |
| `pending` | Строка есть; успешного dispatch ещё не было; ничего не провиженится. |
| `starting` | Первый dispatch прошёл; идёт провиженинг / старт сессии. |
| `active` | Идёт ход провайдера. |
| `idle` | Готов к follow-up или `/clear`. |
| `stopping` | Запрошена остановка; ждём settlement. |
| `error` | Неудачный run; возможен restart. |

Архивация и удаление — ортогональные измерения записи (не статусы). Lifecycle ownership каскадирует archive/delete на dependents; unarchive владельца не восстанавливает dependents. Архивация даёт undo grace (`ARCHIVE_UNDO_GRACE_MS`) до teardown: внутри окна Undo бесплатен, открытые терминалы остаются, mid-turn run может продолжаться; старт ещё в полёте останавливается сразу при archive.

### 6.4 Провиженинг окружений (продуктовые требования)

- Строки environment существуют до создания workspace; статус идёт `creating` → `provisioning` → `ready` | `error`.
- Ошибки создания **терминальны** (без тихого auto-retry ladder); явный retry переиспользует строку с увеличенным attempt.
- Setup-хуки: POSIX `.bb-env-setup.sh` после создания owned-path; `.bb-env-teardown.sh` перед удалением (таймаут 15 минут). Attached checkout / personal-workspace пути пропускают хуки.
- Managed worktree: `git worktree` на свежей ветке; опциональный `.worktreeinclude`; grace 5 минут после последней архивации перед удалением.
- Существующие worktree можно выбрать и adopt’ить при создании потока: адаптер привязывает путь без присвоения ownership (adopted worktree никогда не удаляются bb), а adoption исключает main checkout’ы и managed worktrees.

### 6.5 Роль сервера и перенос

- Пользовательский язык: **server** / **server machine**; API/SDK сохраняют `primaryHostId`.
- Плановый перенос (experiment `serverMove`) копирует только **server-owned** данные; host ID и host-owned файлы (worktrees, thread storage, checkouts, provider sessions) остаются на месте.
- Цели: только persistent-машины (включая provider-managed persistent VM, пока они держат роль сервера). Ephemeral sandbox’ы не могут быть целями.
- Checklist, выравнивание версий, freeze/copy с digest, health check, cutover Connect или direct-address и lock старой копии сервера обязательны для безопасного переноса. См. [docs/server-move-plan.md](docs/server-move-plan.md).

---

## 7. Функциональные требования

Приоритеты MoSCoW: **Must** / **Should** / **Could**.

### 7.1 Установка, запуск и конфигурация

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-LAUNCH-1 | Must | Packaged `npx bb-app` поднимает server + host daemon, отдаёт приложение и перезапускает упавший child, не останавливая второй. |
| F-LAUNCH-2 | Must | Desktop-приложение супервизит тот же packaged runtime и auto-update (stable и Nightly с раздельной identity). |
| F-LAUNCH-3 | Must | Каталог данных по умолчанию `~/.bb/`; флаги launcher’а и `bb-app config` / `env` / client SSH mappings перекрывают defaults с документированным precedence. |
| F-LAUNCH-4 | Must | `bb-app stop` останавливает launcher в другом терминале/фоне по записанной runtime identity. |
| F-LAUNCH-5 | Must | Reload конфигурации применяет live-reloadable ключи без полного рестарта; для startup-only ключей документируется необходимость рестарта. |
| F-LAUNCH-6 | Should | Dev-checkout’ы используют изолированные data dir и детерминированные порты, чтобы worktree могли работать рядом с packaged-инстансами. |
| F-LAUNCH-7 | Should | Server-side вызовы package manager используют bundled npm/npx из bb, а не унаследованный PATH, чтобы install, server move и установка skills работали на машинах без Node в PATH. |

### 7.2 Проекты и sources

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-PROJ-1 | Must | Пользователь может создавать/открывать проекты, привязанные к локальным путям на enrolled hosts. |
| F-PROJ-2 | Must | У проекта могут быть sources на нескольких хостах. |
| F-PROJ-3 | Must | Настройки проектов: переупорядочиваемый список и отдельная страница настроек на проект. |
| F-PROJ-4 | Should | GitHub `origin` remotes обнаруживаются для трекинга плагином GitHub. |
| F-PROJ-5 | Should | Project-scoped machine environment variables применяются на соответствующих хостах; страница настроек проекта показывает унаследованные глобальные переменные read-only с действием Override, а содержимое `.env` можно импортировать через Settings. |
| F-PROJ-6 | Should | Projectless-выбор явен и отражается в picker’ах. |

### 7.3 Потоки и разговор

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-THR-1 | Must | Spawn потоков с проектом, intent окружения, провайдером/моделью и начальным prompt (UI, CLI, SDK). |
| F-THR-2 | Must | Живой timeline сообщений, tool calls, file changes и diagnostics с realtime-обновлениями. |
| F-THR-3 | Must | Управление: follow-up, очередь сообщений, stop, retry восстанавливаемых ошибок, edit сообщений. |
| F-THR-4 | Must | Wait/poll хелперы для скриптов (`bb thread wait`, SDK wait/output). |
| F-THR-5 | Must | Вложенность потоков (drag-to-nest / parent-child) для иерархий делегирования. |
| F-THR-6 | Must | Manager-потоки координируют дочернюю работу по продуктовой политике сервера. |
| F-THR-7 | Must | Организация sidebar (секции, порядок, свёрнутость, destinations) синхронизируется через сервер между устройствами. |
| F-THR-8 | Should | Fork потоков (по умолчанию reuse source environment); сохранение уровня reasoning на follow-up. |
| F-THR-9 | Must | Пагинация timeline владеет event windows и сохраняет целостность групп разговора; последний завершённый context clear — history floor. |
| F-THR-10 | Could | Голосовой ввод через настроенный AI transcription service; сохранение неудачных записей; bb принимает записи до 25 MB (лимит сервиса Codex — 20 MB). |
| F-THR-11 | Must | Очистка контекста агента в idle-потоке (`/clear`, `bb thread clear`) с сохранением workspace и истории до clear floor. |
| F-THR-12 | Must | Spawn/fork могут назначить неизменяемый `lifecycleOwnerThreadId`; side chats и workflow workers назначают ownership при создании. |
| F-THR-13 | Should | Split panes сохраняют намеренно открытые архивные потоки; overflow split dragging работает в любом направлении; результаты thread-search открываются в split pane. |
| F-THR-14 | Should | Mentions потоков помечают relation; worktree-потоки группируются в каждом режиме организации sidebar. |
| F-THR-15 | Should | Перетаскивание потоков из sidebar в composer создаёт mention; поиск skills поддерживает fuzzy и явные `$skill`-mentions; подсказки mentions приоритизируют связанные потоки. |
| F-THR-16 | Should | Сохранить составленное сообщение как draft в очередь потока и отправить позже через Send now (bundled-плагин Drafts), без фиктивных scheduled-времён. |
| F-THR-17 | Should | Handoff в новый поток из follow-up composer с любым провайдером или моделью (включая текущего провайдера); явный Exit handoff восстанавливает исходные execution-настройки, сохраняет правки draft и убирает автоматическую ссылку на источник. CLI/SDK используют `bb thread spawn` / `threads.spawn` со ссылкой на источник в prompt. |
| F-THR-18 | Should | Отображение завершённых ходов настраивается per provider (сворачивать в строку «Worked for» или flat) с default’ами от провайдера; настройка в Settings → Providers или `bb settings completed-turns`; применяется к существующим потокам, conversation outline и `bb thread log`. |
| F-THR-19 | Should | Вкладки панелей можно закрывать «как другие» или «все справа»; явный режим отображения diff сохраняется при изменении размеров панели. |

### 7.4 Окружения и workspace’ы

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-ENV-1 | Must | Поддержка unmanaged директорий на хосте и managed git worktree (плагин worktree по умолчанию). |
| F-ENV-2 | Must | Поддержка плагинов personal workspace и project-checkout. |
| F-ENV-3 | Must | Статус и ошибки окружения видны в UI/CLI/SDK; резервации отдают `creating`. |
| F-ENV-4 | Must | Cleanup managed-окружений, когда не остаётся незаархивированных потоков (с документированным grace). |
| F-ENV-5 | Should | Кастомные окружения через плагины (например copy-on-write, Modal sandboxes). |
| F-ENV-6 | Should | Setup/teardown скрипты репозитория соблюдают документированные таймауты и контракты ошибок. |
| F-ENV-7 | Should | Создание потока в окружении открывает composer, готовый к отправке. |
| F-ENV-8 | Should | Корневой composer предлагает reuse существующего окружения при создании нового потока, а не только когда режим seeded из потока или заголовка workspace. |
| F-ENV-9 | Should | Worktree-провайдер перечисляет существующие worktree в рамках проекта и хоста и adopt’ит выбранный путь без присвоения ownership: bb никогда не удаляет adopted worktree, а main checkout’ы и managed worktrees исключены из adoption. |
| F-ENV-10 | Must | Строки destroyed environment сохраняются (не prune’ятся), чтобы последующее удаление потока всё ещё могло убрать host storage. |
| F-ENV-11 | Should | Shared project-checkout окружения переживают отмену starting-потока, который не стал их единственным live-пользователем. |

### 7.5 Хосты / машины

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-HOST-1 | Must | Primary локальный host daemon enroll’ится при первом запуске; роль сервера видна (badge / Role в `bb machine list`). |
| F-HOST-2 | Must | Можно enroll’ить дополнительные машины (installer / Connect machine credential / маршруты Tailscale). |
| F-HOST-3 | Must | `bb machine list` перечисляет постоянные машины; `--all` включает disposable sandbox’ы. |
| F-HOST-4 | Should | Machine-плагины могут провиженить облачные машины с pause/resume (например Modal); без incidental wakes; tracked allocations согласуются. |
| F-HOST-5 | Should | Searchable multi-machine picker отделяет выбор машины от выбора окружения для проектов с несколькими машинами. |
| F-HOST-6 | Should | Экспериментальный плановый перенос сервера на другую persistent-машину (`bb server move`, UI-диалог) с checklist, cutover и lock старой копии; desktop восстанавливает навигацию после moved server. |
| F-HOST-7 | Should | Desktop-приложение поддерживает сохраняемый список адресов серверов и позволяет переключаться между This Mac / local, Connect-серверами и кастомными URL (Desktop Settings / Window → Server), не теряя прежние записи. |
| F-HOST-8 | Must | Удаление машины может сохранить её потоки как read-only history; Connect shares удалённых хостов prune’ятся. |

### 7.6 Провайдеры и inference

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-PROV-1 | Must | Запуск потоков через установленные CLI провайдеров, которые аутентифицировал пользователь (Claude Code, Codex, Pi, ACP-агенты включая Cursor). |
| F-PROV-2 | Must | Смешивание провайдеров по потоку/задаче. |
| F-PROV-3 | Must | Настройка AI services для titles, commit messages и voice через Settings → AI services / `bb settings ai-services` (`automatic` / `off` / service id). Automatic пробует только first-party сервисы (сегодня сначала Codex); никогда third-party плагины. Legacy-ключи `BB_INFERENCE` / `BB_TRANSCRIPTION` игнорируются/отклоняются. |
| F-PROV-4 | Should | Плагин account pool ротирует аккаунты Claude/Codex при лимитах usage между машинами; вложенные bb-инстансы могут осознанно использовать Account Pooler родителя. |
| F-PROV-5 | Should | Плагины отчётов usage и retry провайдеров; кастомные ACP-агенты могут объявить, что отдают usage, когда их диалект это поддерживает. |
| F-PROV-6 | Must | Sign-in провайдера остаётся в терминале хоста; mobile/remote предполагают уже signed-in хост. |
| F-PROV-7 | Must | Resumed-потоки сохраняют собственные сессии провайдера (без cross-thread mixups). |
| F-PROV-8 | Must | Блокировать старт нового потока, если CLI выбранного провайдера отсутствует, с Install banner и объяснением восстановления. |
| F-PROV-9 | Should | Built-in provider-плагины (Claude Code, Codex, Pi, ACP) остаются forkable вне монорепозитория по [docs/forkable-plugins.md](docs/forkable-plugins.md). |

### 7.7 Файлы, редакторы, терминалы, браузеры

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-FILE-1 | Must | Обзор и mention файлов; пропуск gitignored путей ради производительности mentions. |
| F-FILE-2 | Must | Интеграция локального редактора через loopback helper (desktop / локальный `bb-app`); опциональный SSH target mapping для удалённых work hosts. |
| F-FILE-3 | Should | Monaco editor и inline-превью PDF/Markdown/HTML через плагины; общий file-preview target для inline-vis; ошибки preview объясняют причину, а не показывают общую ошибку загрузки. |
| F-FILE-4 | Should | Доступ к терминалу через возможности server/daemon, открытые CLI/SDK; завершённые терминалы сохраняют output 30 минут (или до рестарта host daemon) с деталями exit и хелперами `terminal read` / `terminal wait`. |
| F-FILE-5 | Should | Встроенный desktop-браузер + плагин Browser Automation; live headless browser previews с expandable lightbox; импорт cookies из установленных браузеров (включая Helium на macOS); keyboard focus не уходит на скрытые и automation-controlled вкладки. |
| F-FILE-6 | Should | Плагин Agent Annotations: выбор элементов во вкладке Browser, комментарии и структурированный контекст в prompt. |
| F-FILE-7 | Must | Отслеживание ownership вложений и reclaim unowned uploads; CLI image/file вложения загружаются до thread-запроса, в том числе при удалённом сервере. |
| F-FILE-8 | Should | Diff panel фильтрует файлы по path стандартными glob’ами. |
| F-FILE-9 | Should | Desktop zoom ограничен 50–300% шагами по 10% с transient zoom indicator. |

### 7.8 Плагины, skills и marketplace

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-PLUG-1 | Must | Установка, enable/disable и настройка плагинов из UI и `bb plugin`. |
| F-PLUG-2 | Must | Discovery official / community marketplace (категории, скриншоты, author pages) без установки кода при refresh; install pipeline валидирует пакеты. |
| F-PLUG-3 | Must | Plugin SDK с документированными surfaces; новые public API members — с префиксом `experimental_` до аудита. |
| F-PLUG-4 | Must | Skills — first-class (install, contribute instructions); отдельные workspace’ы от плагинов. |
| F-PLUG-5 | Should | BB Guide управляет, какое введение/skills получают агенты, включая инструкцию ждать пользовательского запроса перед созданием или отправкой сообщений в другие потоки bb. |
| F-PLUG-6 | Should | Примерные плагины и Plugin Guide как единственная документация plugin API. |
| F-PLUG-7 | Should | Единые plugin cards с сохранением detail tabs; plugin-declared icons резолвятся везде, где принимается имя иконки BB. |
| F-PLUG-8 | Must | Plugin safe mode (`bb plugin safe-mode` / SDK / command palette) останавливает каждый non-built-in установленный плагин, не очищая собственный enabled-флаг плагина; выключение safe mode восстанавливает ранее enabled плагины и сообщает о сбоях старта. Install/update/enable остановленных плагинов запрещены, пока safe mode включён. |
| F-PLUG-9 | Must | Sidebar navigation и thread list по умолчанию Automatic, предпочитая установленный replacement-плагин bundled `navigation` / `thread-list`. |
| F-PLUG-10 | Should | Перечисленные built-in плагины остаются forkable (публичный SDK + registry UI); CI `check:plugin-forks` enforced списком в `scripts/forkable-plugins.json`. |

### 7.9 Встроенные / официальные capability-плагины (каталог продукта)

Поставляются как bundled или catalog-плагины; присутствие в каталоге — часть продуктового предложения.

| Область | Плагины (представительные) | Пользовательский эффект |
| --- | --- | --- |
| Окружения | `environment-git-worktree`, `environment-personal-workspace`, `environment-project-checkout`, `environment-modal-sandbox` (experimental) | Изолированные или облачные workspace’ы |
| Провайдеры | `provider-claude-code`, `provider-codex`, `provider-pi`, `provider-acp`, `provider-usage`, `provider-retry`, `account-pool` | Запуск и управление backend’ами агентов |
| Планирование / ops | `tasks`, `workflows` (opt-in), `automations`, `scheduled-send`, `concurrency-limit` | Трекинг, оркестрация, расписание работы |
| Контекст | `memory`, `custom-instructions`, `bb-guide`, `drafts` (bundled, включён по умолчанию), `agent-annotations` | Долговременная память, guidance, сохранённые drafts, browser annotations |
| Коллаборация | `github`, `ask-user-question`, `secrets` | Issues/PR, уточняющие вопросы, secret prompts |
| Доступ | `connect`, `push-notifications`, `keep-awake` | Remote access, push на mobile/web/desktop, поддержание хоста awake |
| Shell UI | `navigation`, `thread-list` | Заменяемые sidebar navigation и thread list (Automatic предпочитает установленные forks) |
| UX | `side-chat`, `inline-vis`, `monaco-editor`, `pdf-preview`, `theme-preview`, `browser-automation` | Более богатый UX потоков и desktop |

### 7.10 Tasks (плагин)

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-TASK-1 | Must | Трекер в стиле Linear: проекты, папки, ключи, статусы, приоритеты, labels, subtasks, комментарии, вложения; поиск принимает термины в любом порядке. |
| F-TASK-2 | Must | Делегирование задачи агентскому потоку через presets (`bb tasks delegate` / UI). |
| F-TASK-3 | Must | Записи задач связаны с исполняющими потоками; опциональный notify-last-agent на комментариях. |
| F-TASK-4 | Must | Полный CLI `bb tasks` с `--json` для агентов. |

### 7.11 Workflows и automations

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-WF-1 | Should | Provider-independent JS-оркестрация в QuickJS; реальное reasoning делегируется обычным потокам bb. |
| F-WF-2 | Should | Author surface `bb_workflow_run`; inspect/cancel через `bb workflows` и live-карточки в потоке; дочерние потоки можно активировать прямо из inline workflow preview. |
| F-WF-3 | Must | Песочница: без Node/fs/shell/network/imports/clock/randomness внутри QuickJS; schema validation ограничена ради безопасности. |
| F-WF-4 | Should | Automations поддерживают явные working directories для скриптов. |
| F-WF-5 | Must | Попытки workflow workers назначают lifecycle ownership origin-потоку (включая replacements). |

### 7.12 Connect и несколько устройств

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-CONN-1 | Must | Различать **browser/control устройства** и **execution-машины**. |
| F-CONN-2 | Must | bb connect pairing сервера для account-gated remote URL; сервер владеет reconnect туннеля; Connect credential переезжает вместе с server move; клиенты переживают tunnel resets, не роняя visitors. |
| F-CONN-3 | Must | Документированный приватный путь Tailscale Serve; предупреждение против public Funnel / неаутентифицированного wildcard bind в недоверенных сетях. |
| F-CONN-4 | Should | Mobile pairing как connect machine (QR/код) за experiment `mobileApp` на этапе early access. |
| F-CONN-5 | Should | Push-уведомления независимо на mobile, web и desktop (iOS, когда сервер достигает `exp.host`). |
| F-CONN-6 | Must | Secret requests остаются живыми через bb connect и на месте в timeline. |

### 7.13 Mobile

| ID | Приоритет | Требование |
| --- | --- | --- |
| F-MOB-1 | Must | Нативная оболочка грузит web app сервера; нативно владеет pairing, профилями, push, deep links, share intents. |
| F-MOB-2 | Must | Enrollment через Direct URL и bb connect. |
| F-MOB-3 | Should | Дистрибуция iOS TestFlight; Android запланирован. |
| F-MOB-4 | Must | Явно недоступно на телефоне: plugin nav frontends, login провайдера, локальный editor/daemon, кастомные CSS-темы, desktop browser automation (задокументировано). |
| F-MOB-5 | Should | Компактные layouts: typeahead над new-thread prompt; стабильная trailing-колонка sidebar; Recent-статусы выровнены с desktop; короткие быстрые свайпы открывают compact sidebar; server error pages показываются в mobile shell. |
| F-MOB-6 | Should | Touch: оставлять клавиатуру открытой при удалении attachments в composer; не autofocus’ить new-thread composer; квадратные action buttons composer’а. |

---

## 8. Нефункциональные требования

### 8.1 Производительность и UX

| ID | Приоритет | Требование |
| --- | --- | --- |
| NF-PERF-1 | Must | Realtime-обновления по WebSocket для изменений thread/project/environment/host/system. |
| NF-PERF-2 | Must | UI остаётся usable при длинных run’ах агента (streaming markdown, стабильность Mermaid, отложенный контент drawer, retain после открытия). |
| NF-PERF-3 | Must | Без CSS `@scope`; sanctioned theme tokens (`--canvas` / `--ink`); общий persistent drawer pattern. |
| NF-PERF-4 | Should | Startup JS и фоновый polling остаются лёгкими (например меньше GitHub polling, быстрее file mentions). |
| NF-PERF-5 | Should | Timeline head state отделён от conversation context; рост внешнего timeline snap’ится, пока поток active; скролл не мерцает timeline. |
| NF-PERF-6 | Should | Quick palette поддерживает отдельные режимы и сгруппированные результаты поиска потоков; поиск по keyboard shortcuts ранжирует совпадения по видимому label выше совпадений только по description; есть команда открыть data directory. |

### 8.2 Надёжность

| ID | Приоритет | Требование |
| --- | --- | --- |
| NF-REL-1 | Must | SQLite — source of truth; сервер по сути stateless за пределами DB + process. |
| NF-REL-2 | Must | Старт environment/thread восстанавливается после рестарта сервера через persisted startup context и engine sweep. |
| NF-REL-3 | Must | Отключения демона оставляют cleanup pending до подтверждения; redemption Connect grant crash-safe. |
| NF-REL-4 | Should | Launcher изолирует stdio-логи, чтобы зависший терминал не блокировал логирование сервисов; логи без terminal escape sequences. |
| NF-REL-5 | Must | Cascade archive/delete lifecycle-owner надёжен; cleanup dependents повторяется на sweeps и reconnect. |
| NF-REL-6 | Should | Pruning таблицы events поддерживает здоровье долгоживущих установок (см. `docs/events-table-pruning.md`). |

### 8.3 Безопасность и доверие

| ID | Приоритет | Требование |
| --- | --- | --- |
| NF-SEC-1 | Must | Bind по умолчанию — loopback; `0.0.0.0` явно опасен (неаутентифицированный API с выполнением команд и чтением файлов). |
| NF-SEC-2 | Must | Connect machine credentials — секреты (не в `config list`); отзыв через dashboard. |
| NF-SEC-3 | Must | Local editor helper только на loopback и origin-trusted. |
| NF-SEC-4 | Must | QuickJS sandbox workflows и schema allowlists как описано выше. |
| NF-SEC-5 | Should | Плагин Memory отклоняет базовые prompt-injection и secret-паттерны. |
| NF-SEC-6 | Must | Телеметрия никогда не прикрепляет user/host/project/workspace/message content; opt-out через `BB_TELEMETRY=false` или постоянный переключатель в Settings; opt-out’ы трекаются анонимно без content. |
| NF-SEC-7 | Must | Export server move проверяется digest’ом и доступен для скачивания только целевой машине. |
| NF-SEC-8 | Must | Plugin safe mode блокирует side effects install/update/enable для non-built-in плагинов, пока он включён. |

### 8.4 Приватность и телеметрия

Production desktop и `npx bb-app` могут отправлять анонимные usage-события (старты, счётчики создания потоков, user messages, установки публичных плагинов) с ключом random per-install id. Development/source runs не отправляют. Приватные/локальные установки плагинов не сообщают имя плагина. Telemetry id переезжает вместе с server-owned данными при server move. Пользователи могут закрепить opt-out в Settings (помимо `BB_TELEMETRY=false`).

### 8.5 Совместимость

| ID | Приоритет | Требование |
| --- | --- | --- |
| NF-COMPAT-1 | Must | Нижняя граница Node.js 22.19; протестировано на 22.19+, 24 LTS, 26 Current. |
| NF-COMPAT-2 | Must | Хосты: macOS, Linux, Windows только через Ubuntu WSL2. |
| NF-COMPAT-3 | Must | Native add-ons ставятся через npm lifecycle scripts (`better-sqlite3`, `node-pty`, `@parcel/watcher`); документировать требование npm 12 `--allow-scripts`. |
| NF-COMPAT-4 | Must | Версионирование протокола демона для обновления enrolled машин. |
| NF-COMPAT-5 | Must | Server move блокируется, если target новее сервера, пока сервер не обновят; затем на target ставится точная версия сервера. |

### 8.6 Наблюдаемость и эксплуатация

| ID | Приоритет | Требование |
| --- | --- | --- |
| NF-OPS-1 | Must | Ротируемые app-логи плюс `server-stdio.log` / `host-daemon-stdio.log` в data dir. |
| NF-OPS-2 | Should | `bb status`, health endpoints и QA-доки для локальных debug-портов и data dirs. |
| NF-OPS-3 | Should | `bb server move --check` показывает blockers и warnings до копирования. |
| NF-OPS-4 | Should | `bb diagnostics cli-errors` суммирует упавшие локальные CLI-вызовы (путь команды, код ошибки и неизвестная команда/флаг; никогда значения аргументов) с `--since` / `--clear` / `--json`; CLI-ошибки предлагают валидные команды и флаги и объясняют недостающий контекст. |

---

## 9. Матрица поддержки платформ

| Платформа | Статус |
| --- | --- |
| macOS Apple Silicon desktop | Поддерживается (рекомендуется) |
| macOS Intel | Через `npx bb-app` (не фокус desktop-бинарника) |
| Linux x64 AppImage | Альфа |
| Linux host через `npx` / source | Поддерживается |
| Windows native | Не поддерживается |
| Windows + WSL2 Ubuntu | Поддерживается (все процессы bb внутри WSL2) |
| iOS mobile | Early access / TestFlight |
| Android mobile | Запланировано (код в основном platform-neutral; сборки не тестировались) |
| iPad | Работает phone layout |

---

## 10. Информационная архитектура (приложение)

Основные пользовательские объекты в UI:

1. **Home / dispatch** — старт работы, недавняя активность; режимы palette для поиска и действий (включая открытие data directory).
2. **Projects** — sources, настройки, reorder, project-scoped env vars с унаследованными read-only строками, импорт `.env`.
3. **Threads** — вложенный список (через плагин `thread-list`), секции, группировка worktree, живой timeline, composer (drafts, handoff), split panes, панели (diff с glob-фильтром, workflow inspector, side chat, browser previews и т.д.).
4. **Machines** — enrolled hosts, sandbox’ы, badge server-машины, опциональный поток Move server; desktop-меню Server для сохранённых адресов; удаление машины с опцией read-only history.
5. **Plugins / Skills** — browse marketplace, установка, настройка, отдельные workspace’ы, detail tabs; plugin safe mode.
6. **Settings** — appearance / interface (Automatic для navigation и thread-list), providers (отображение finished turns), AI services, files/editor, environment variables, remote access (Connect), experiments, browsers, telemetry opt-out.
7. **Plugin nav panels** — через плагин `navigation` (Tasks, GitHub, Docs, Automations и т.д.; web/desktop; не mobile frontends).
8. **Notification center** — пропущенные уведомления по push-каналам.

---

## 11. Требования к API и расширяемости

### 11.1 Публичный automation API

- HTTP-маршруты + WebSocket-уведомления по `@bb/server-contract`.
- TypeScript `BBSdk` покрывает projects, threads (включая timeline pagination, clear, lifecycle owner на spawn/fork), environments, hosts, plugins (включая safe mode), providers, AI services, files, terminals, skills, theme, guide, status, server move (experimental) и т.д.
- Группы команд CLI зеркалят области SDK; команды плагинов проксируются через `bb`; встроенные plugin CLI используют один декларативный контракт команд (`defineCli` / `cliCommand`) с единообразным parsing, validation, help и output.
- CLI-ошибки предлагают валидные команды и флаги, объясняют недостающий контекст и возвращают единый JSON-конверт ошибок для агентов.

### 11.2 Продуктовые правила Plugin API

- Plugin Guide — единственная документация plugin API; surfaces регистрируются в `packages/plugin-api-map`.
- Новые public members: префикс `experimental_` + запись в `docs/api_to_audit.md` до стабилизации.
- Plugin tools, ожидающие ввода пользователя (`bb.ui.requestInput`), могут пережить свой turn и возобновить агента или запустить новый turn при ответе; ошибки и dismissal не будят idle-потоки.
- Frontend-плагины регистрируют команды (`app.commands.register`) с default keyboard shortcuts; каждая команда переназначаема как `plugin:<plugin-id>/<command-id>`, а конфликты требуют явной замены.
- Composer control API позволяют плагинам задавать выбор в picker’ах, убирать принадлежащие им mentions, наблюдать успешные отправки и прикладывать plugin-owned данные к отправке, не интерпретируемые ядром.
- Плагины могут публиковать discoverable RPC-описания и wire-схемы для других плагинов и агентов; `bb plugin rpc list` / `bb plugin rpc inspect` показывают их.
- Плагины могут регистрировать AI services (`experimental_aiServices`), выбираемые на задачу (titles, commits, voice).
- Environment и machine plugin API позволяют сторонний провиженинг workspace и облака.
- Browser control и page-scripting API включают desktop browser automation и annotations-плагины; plugin browser extensions могут добавлять контролы рядом с адресной строкой, запускать скрипты на странице и получать сообщения из неё (experimental).
- Forkable built-ins не должны зависеть от приватных пакетов монорепозитория; см. [docs/forkable-plugins.md](docs/forkable-plugins.md).
- Plugin safe mode выгружает non-built-in плагины, не очищая enabled-флаг каждого плагина.

### 11.3 Provider bridge

- Адаптеры/bridges agent runtime для Codex, Claude Code, Pi и ACP.
- Документы provider parity и bridge protocol задают ожидаемое поведение событий и сессий.

---

## 12. Experiments (gated-функции)

Серверные experiment-флаги (по умолчанию выключены):

| Ключ | Назначение |
| --- | --- |
| `mobileApp` | Показать mobile pairing / remote-access mobile flows на этапе early access |
| `serverMove` | Плановый перенос роли сервера на другую persistent-машину |
| `sidebarProgressiveDisclosure` | Плотность UX sidebar |
| `changelogPreview` | In-app превью changelog |

Experiments должны переключаться через Settings и `bb settings experiment`. Wording/badge/колонка Role для server-машины могут поставляться без experiment; export/cutover требуют включённый `serverMove`. Бывшие ключи `multiMachinePicker` и `timelineWindowing` удалены; multi-machine picking и ownership окон timeline — обычное продуктовое поведение.

---

## 13. Метрики успеха

Ведущие индикаторы (согласованы с анонимной телеметрией, где она есть):

1. **Activation** — успешный первый проект + первый поток на новой установке.
2. **Engagement** — созданные потоки / user messages на установку (телеметрия).
3. **Breadth** — доля установок, использующих CLI или SDK за 7 дней (качественно + сигналы поддержки).
4. **Extensibility** — установки публичных плагинов; записи сторонних marketplace.
5. **Reliability** — доля ошибок создания окружений, успех reconnect демона, рестарты child launcher’а, успешные cutover server move (когорта experiment).
6. **Multi-device** — pairing Connect; mobile-сессии в когорте experiment.
7. **Retention** — weekly active installs, возвращающиеся после дня 7 / дня 30.

Качественный успех:

- Пользователи запускают параллельных агентов, не портя основной checkout.
- Агенты и люди ведут одни и те же workflows через CLI/SDK.
- Команды с жёсткими security-ограничениями могут полностью оценить bb в local/loopback режиме.
- Пользователи, переросшие ноутбук, могут перенести сервер на always-on машину, не теряя историю.

---

## 14. Ограничения и риски

| Риск | Смягчение |
| --- | --- |
| Churn CLI провайдеров ломает bridges | Provider-плагины + parity-тесты; изоляция bridges в `agent-runtime`. |
| Злоупотребление неаутентифицированным API на `0.0.0.0` | Предупреждения в доках; loopback по умолчанию; account gating Connect. |
| Сбои установки native addon (npm 12) | Документировать `--allow-scripts`; ясное руководство по ошибке bindings-file. |
| Рассинхрон протокола со старыми демонами | Bump `HOST_DAEMON_PROTOCOL_VERSION` форсирует обновление. |
| Gap возможностей mobile удивляет пользователей | Явный список unsupported в platform docs и settings. |
| Нестабильность Plugin API | Префикс `experimental_` + audit list до стабилизации. |
| Стоимость/сложность cloud sandbox | Держать Modal и подобные плагины experimental и opt-in. |
| Небезопасный или частичный server move | Checklist blockers, digest-checked export, health gate, lock старой копии; v1 требует онлайн source. |
| Сбойные third-party плагины | Plugin safe mode останавливает non-built-ins, не стирая enablement. |
| Регрессии hosted account / connect-gate | Держать bb account + AI gateway вне required core, пока не доказаны; предпочитать локальные Codex AI services. |

---

## 15. Роллаут и дистрибуция

| Канал | Аудитория |
| --- | --- |
| Desktop stable | Рекомендуемые пользователи по умолчанию |
| Desktop Nightly | Early adopters; отдельная app identity |
| `bb-app@latest` npm | Cross-platform / CI / WSL / Intel Mac |
| `bb-app@nightly` npm | Автосборки с `main` |
| iOS TestFlight | Mobile early access |
| Source `pnpm dev` / `pnpm start` | Контрибьюторы и advanced users |

Документы релизного процесса: `docs/bb-release-process.md`, `docs/official-plugin-release-process.md`.

---

## 16. Вне скоупа / будущие направления

Явно отложено или ещё формируется (не текущие Must-требования):

- Нативный Windows host daemon / PowerShell product path.
- Android store release и протестированный Android push.
- Замена provider-native auth UI внутри bb.
- Полностью hosted multi-tenant bb, заменяющий локальный SQLite по умолчанию.
- Гарантия pixel-complete паритета plugin frontend на mobile.
- Функции marketplace, ещё в draft (см. `docs/plugin-marketplace-plan.md`).
- Восстановление мёртвого сервера из бэкапа и automatic failover (за пределами планового `serverMove`).
- Перенос host-owned файлов (worktrees, checkouts, provider sessions) при relocation сервера.
- Required hosted bb account / bb cloud AI (откачено с main после поломки connect-gate; может вернуться позже как AI-service плагин).

Согласованные будущие направления из vision:

- Более богатая remote-оркестрация и peer-backed окружения.
- Более глубокая командная коллаборация вокруг tasks/workflows при сохранении модели локального доверия.
- Больше environment и machine провайдеров через стабильные plugin API.
- Более широкое продвижение server move после hardening experiment.
- Опциональные hosted AI services в том же AI-tasks API, не становясь единственным путём.

---

## 17. Критерии приёмки (продуктовый уровень)

Релиз считается product-complete для «core bb», когда выполнено всё ниже:

1. Новый пользователь на поддерживаемом хосте может установить через desktop или `npx bb-app`, открыть UI, добавить проект, spawn’нуть поток с аутентифицированным провайдером и видеть live events.
2. Тот же сценарий spawn/steer/wait/output/clear работает через CLI `bb` и `BBSdk` против этого сервера.
3. Работают и managed worktree, и unmanaged directory окружения; cleanup managed следует правилам grace/removal.
4. Enrollment второй машины (или Connect remote control) работает по докам без публикации API в публичный интернет по умолчанию.
5. Установка официального плагина (например Tasks или Memory) расширяет CLI и UI без форка сервера.
6. Телеметрия выключена в source/dev и opt-outable в production (settings и/или env); содержимое сообщений не покидает машину.
7. Матрица поддержки платформ и ограничения mobile соответствуют поставленным артефактам.
8. Lifecycle ownership каскадирует archive/delete для side chats и workflow workers как задокументировано; archive undo grace работает как указано.
9. При включённом `serverMove` плановый перенос на другую enrolled persistent-машину проходит checklist → copy → health → cutover и оставляет старую копию locked как обычную машину.
10. Сохранённый draft можно позже отправить через Send now из обычной очереди, а handoff в новый поток (включая тот же провайдер) выходит обратно к исходному execution без потери правок draft.
11. Plugin safe mode останавливает non-built-in плагины и чисто восстанавливает их при выключении.
12. AI services для titles/commits/voice настраиваются без удалённых ключей `BB_INFERENCE` / `BB_TRANSCRIPTION`.

---

## 18. Сопровождение документа

- Обновлять этот PRD при изменении vision, ядра сущностей, правил паритета поверхностей или Must-требований.
- Для операционных деталей предпочитать ссылки на живые reference-доки (`configuration.md`, `platform-support.md`, `worktrees.md`, `server-move-plan.md`, Plugin Guide), а не дублировать каждый флаг.
- Changelog (`CHANGELOG.md`) фиксирует поставленные дельты; этот PRD фиксирует замысел и требования.
- Держать [PRD.md](PRD.md) и этот файл синхронными при изменениях.

---

## Приложение A — Карта монорепозитория (для разработчиков)

| Область | Расположение |
| --- | --- |
| Launcher / публичный SDK export | `packages/bb-app` |
| Web UI | `apps/app` |
| Desktop shell | `apps/desktop` |
| Server | `apps/server` |
| Host daemon | `apps/host-daemon` |
| CLI | `apps/cli` |
| Mobile | `apps/mobile` |
| Маркетинг / Connect site | `apps/web` |
| Domain types | `packages/domain` |
| DB | `packages/db` |
| Контракты | `packages/server-contract`, `packages/host-daemon-contract` |
| Plugin SDK | `packages/plugin-sdk` |
| Встроенные плагины | `plugins/*` |

## Приложение B — Глоссарий

| Термин | Значение |
| --- | --- |
| **Thread (поток)** | Единица работы агента и разговора |
| **Manager thread** | Поток, координирующий другие потоки |
| **Lifecycle owner** | Неизменяемый owner-поток при создании; его archive/delete каскадируется на dependents |
| **Environment (окружение)** | Связка host + workspace для исполнения |
| **Host / machine** | Идентичность enrolled демона |
| **Server machine** | Хост, который сейчас держит роль сервера (`primaryHostId`) |
| **Source** | Расположение кода проекта на конкретном хосте |
| **Provider** | Внешний runtime coding-агента (CLI/ACP) |
| **Drafts** | Bundled-плагин, сохраняющий составленные сообщения в обычную очередь потока для последующей отправки |
| **Handoff** | Создание нового потока со ссылкой на исходный из follow-up composer с явным выходом для восстановления исходного execution |
| **AI service** | Plugin-registered backend для titles, commit messages или voice transcription |
| **Plugin safe mode** | Server-флаг, выгружающий каждый non-built-in установленный плагин до выключения |
| **Forkable plugin** | Built-in, который ставится/typecheck’ится/тестируется/собирается вне монорепозитория только на публичных пакетах |
| **Skill** | Пакет инструкций, который могут загрузить агенты |
| **Plugin** | Упакованное расширение (server и/или app) |
| **Connect** | Account-gated удалённый доступ и pairing машин |
| **Worktree** | Managed окружение на базе `git worktree` |
| **Context clear** | Сброс контекста агента (`/clear`), становящийся history floor timeline |
| **bb-app** | Опубликованный npm-пакет launcher’а |
