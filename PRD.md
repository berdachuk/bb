# bb — Product Requirements Document

> Русская версия: [PRD.ru.md](PRD.ru.md)

| Field | Value |
| --- | --- |
| Product | **bb** |
| Tagline | An agentic IDE that builds itself |
| Status | Active development (core architecture stable; workflows and surfaces evolving) |
| License | MIT |
| Last updated | 2026-10-08 |
| Shipped baseline | **0.45.0** (see [CHANGELOG.md](CHANGELOG.md)); Nightly/`main` may be ahead |
| Primary distribution | Desktop app (macOS arm64 recommended; Linux AppImage and Windows x64 installer alpha), `npx bb-app@latest` / `@nightly` |
| Companion surfaces | Web UI, `bb` CLI, TypeScript SDK / HTTP API, mobile (iOS TestFlight + Android APK alpha), getbb.app (marketing + Connect + Plugin Guide) |
| Document purpose | Capture product intent, requirements, and boundaries derived from the shipping codebase and vision |
| Related docs | [docs/VISION.md](docs/VISION.md), [docs/system-overview.md](docs/system-overview.md), [docs/repository-overview.md](docs/repository-overview.md), [docs/platform-support.md](docs/platform-support.md), [docs/configuration.md](docs/configuration.md), [docs/server-move-plan.md](docs/server-move-plan.md), [docs/forkable-plugins.md](docs/forkable-plugins.md), [README.md](README.md), [CHANGELOG.md](CHANGELOG.md) |

---

## 1. Executive summary

bb is a **programmable workspace for coding agents**. It orchestrates agents the user already authenticates (Claude Code, Codex, Pi, Cursor via ACP, and other ACP-compatible agents), runs their work in **threads** against **environments** on enrolled **hosts**, and exposes that system equally through a desktop/web UI, CLI, SDK, and HTTP API.

The product goal is not a single chat window bolted onto a model API. bb is meant to become the control plane for a personal or team **software factory**: multiple agents in parallel, managed workspaces, delegation, plugins, remote machines, and automation — while remaining easy to run locally and easy to trust.

The **server is a role on one machine** (`primaryHostId`), not “the only computer that can run agents.” Every enrolled machine can execute work; server-owned state (database, settings, plugin server data, remote access) can move to another persistent machine behind the `serverMove` experiment.

---

## 2. Problem statement

### 2.1 Problems bb addresses

1. **Agent work is fragmented.** Coding agents live in separate CLIs and UIs with incompatible session models, making parallel work, handoff, and oversight hard.
2. **UI-only tools leave agents and scripts behind.** Features that exist only in a GUI cannot be automated or delegated to other agents.
3. **Execution context is underspecified.** Users need clear choices between editing the main checkout, isolated worktrees, personal workspaces, project checkouts, or cloud sandboxes — with lifecycle and cleanup they can rely on.
4. **Multi-device and multi-machine work is awkward.** People want to steer agents from a laptop, phone, or browser while execution stays on a trusted machine (or several), and later move the server role without starting over.
5. **Teams need extensibility without forking.** Providers, environments, UI panels, tools, and workflows must be pluggable so bb adapts to infrastructure instead of forcing one blessed stack.

### 2.2 Non-goals (product posture)

- Replacing provider CLIs or owning their auth (bb uses the user’s existing authenticated providers).
- Requiring a hosted cloud account for core local use (Connect and cloud plugins extend bb; they do not replace the local product).
- Treating native Windows or Android as production-recommended platforms (both ship as **alpha**; WSL2 and macOS/Linux remain the trusted host paths).
- Making the phone a full execution host (mobile is a control surface for a bb server).
- Automatic failover or restoring a dead server from backup as the default move path (v1 server move is a planned, cooperative move while the old server is online; the server cannot be moved to a Windows machine).
- Requiring a hosted bb account or bb cloud AI for core local use (optional bb account unlocks Connect and bb cloud AI services; local Codex/Claude/Pi/ACP paths remain first-class without it).

---

## 3. Vision and principles

From [docs/VISION.md](docs/VISION.md):

| Principle | Requirement implication |
| --- | --- |
| **Users and agents are both first-class operators** | Every end-user feature ships on UI, CLI, and SDK/HTTP with equivalent capability. |
| **Extensible** | Custom providers, environments, LLM-backed services, CLI integrations, and UI surfaces via the plugin system. |
| **Flexible, not rigid** | Strong defaults plus unmanaged paths; managed and unmanaged flows both feel natural. |
| **Works wherever you are** | Local-first today; remote hosts, Connect, cloud sandboxes, mobile clients, and server relocation without redesigning the core model. |
| **Fast and understandable** | Responsive UI, operational simplicity, low cognitive overhead. |
| **Easy to trust and adopt** | Local mode remains evaluable under security constraints; hosted features are optional extensions. |

---

## 4. Personas and jobs-to-be-done

### 4.1 Personas

| Persona | Needs |
| --- | --- |
| **Individual power user / indie hacker** | Run several agents in parallel, isolate risky edits in worktrees, steer from CLI and UI, customize with plugins. |
| **Software engineer on a team** | Map repos to projects, review agent output, connect GitHub issues/PRs, use Tasks/Workflows for planned work. |
| **Remote / multi-machine developer** | Keep execution on a workstation or cloud box; control from browser or phone via Connect or Tailscale; optionally move the server role to an always-on machine. |
| **Agent / automation author** | Drive bb programmatically (`BBSdk`, `bb` CLI, workflows, automations) to spawn, wait, inspect, clear, and delegate threads. |
| **Plugin author** | Extend providers, environments, machines, UI slots, tools, browser scripting, and skills without forking bb. |
| **Maintainer / contributor** | Clear architecture boundaries, contracts, and contribution gates. |

### 4.2 Primary jobs

1. Start agent work on a project in a chosen environment and provider.
2. Follow live progress, interrupt, edit messages, queue follow-ups, clear context, and nest/delegate threads.
3. Inspect diffs, files, terminals, browsers, and artifacts; open work in a local editor when available.
4. Scale across machines (enrolled host daemons) and control surfaces (web, desktop, CLI, mobile); relocate the server when needed.
5. Persist and reuse context (memory, custom instructions, skills, tasks, annotations).
6. Automate recurring or multi-step work (automations with working directories, workflows, scheduled send, managers).

---

## 5. Product surfaces

Every surface is first-class. Capability parity is a hard product requirement unless a surface is explicitly documented as partial (e.g. mobile).

| Surface | Role | Entry |
| --- | --- | --- |
| **Desktop app** | Recommended install; Electron shell supervises packaged runtime and loads the web UI; local editor helper and desktop browser features; in-app updates on by default for packaged starts. | [desktop-latest](https://github.com/get-bb/bb/releases/tag/desktop-latest) / Nightly; Windows x64 installer **alpha** |
| **Packaged launcher** | `npx bb-app` starts server + host daemon + serves UI; stores state under `~/.bb/`; in-app updates on by default for `bb-app start`. | `npx bb-app@latest` → `http://localhost:38886` |
| **Web app** | Inspect projects/threads/environments; steer work; settings; plugin UI; split panes; first-run setup guide on new installs. | Served by bb server |
| **CLI (`bb`)** | Scriptable control for users and agents: threads, projects, machines, plugins, providers, files, storage, server move, etc. | `npx --package bb-app bb …` |
| **SDK / HTTP API** | Programmatic clients; same server contract as the app. | `import { BBSdk } from "bb-app"` |
| **Mobile app** | Native control client (Expo); iOS TestFlight + Android APK alpha; pairs via Direct URL or bb connect (no experiment gate). | Settings → Mobile downloads / TestFlight / `android-testing` APK |
| **getbb.app** | Marketing + Connect auth/dashboard + plugin marketplace browsing + Plugin Guide. | Cloudflare Workers (TanStack Start) |

### 5.1 Surface parity rules

- New end-user features **must** ship on SDK and `bb` CLI alongside the UI, and be documented on the discoverable CLI/guide/skill surfaces.
- Mobile may omit plugin *frontends*, local daemon features, and some rich media; plugin *backends*, pending interactions, and core thread control must still work where the contract allows.
- Desktop-only capabilities (built-in browser automation, annotations, local folder picker, editor helper) must fail clearly on surfaces that lack a co-located daemon/helper.

---

## 6. System architecture (product view)

### 6.1 Runtime components

| Component | Owns | Does not own |
| --- | --- | --- |
| **Server** | Product policy (defaults, instructions, manager behavior, tool lists, thread behavior); SQLite source of truth; HTTP + WebSocket API; routing work to daemons; server-owned plugin data and remote access. | How workspaces are provisioned on disk; provider process internals beyond the daemon contract; host-owned files that stay on each machine during a server move. |
| **Host daemon** | Host-local primitives: workspace provisioning, provider process lifecycle, RPC results, local helper API (open editor, pick folders, daemon status). | Product-level thread/project policy assembly. |
| **Clients (app / CLI / SDK / mobile)** | Presentation, scripting, and steering against the server contract. | Direct mutation of daemon state except via server + local helper APIs. |

**Contract packages (hard boundaries):**

- `@bb/server-contract` — clients ↔ server (HTTP + WebSocket).
- `@bb/host-daemon-contract` — server ↔ host daemons (commands, events, local API).

Wire-field changes that alter meaning, requiredness, or defaults on the daemon protocol require bumping `HOST_DAEMON_PROTOCOL_VERSION` so enrolled machines update.

### 6.2 Data model (core entities)

| Entity | Definition |
| --- | --- |
| **Project** | Top-level container, usually a repository. Has one or more **sources** locating code; each local-path source belongs to a specific enrolled host. May carry project-scoped machine environment variables. |
| **Thread** | Unit of work: conversation with a provider, lifecycle state, append-only **events**. Standard threads do work; **manager** threads coordinate others. Threads may own children for delegation and nest in the sidebar. |
| **Environment** | Execution context binding a workspace path to a host. **Unmanaged** (existing directory) or **managed** (bb-created; cleaned when no unarchived threads remain). Multiple threads may share an environment. |
| **Host / machine** | Long-lived daemon identity for an execution machine. The server runs on one host (`primaryHostId`); additional remote hosts can be enrolled. Project sources and environments retain the host boundary. |
| **Lifecycle owner** | Optional immutable `lifecycleOwnerThreadId` at creation: archive/delete of the owner recursively affects dependents (side chats, workflow workers). Independent of sidebar `parentThreadId` and fork `sourceThreadId`. |
| **Commands & events** | Server issues host RPC over the daemon WebSocket; daemons post provider/thread progress as event batches. Lifecycle work may complete asynchronously from the API caller’s perspective. |
| **AI services** | Plugin-registered services for thread titles, commit messages, and voice transcription. Per-task choice: `automatic`, `off`, or a service id (Settings → AI services / `bb settings ai-services`). Automatic tries **bb cloud** (`bb-ai`, signed-in bb account) first, then other registered services (including third-party) in plugin/service id order; Codex uses the CLI login on the primary machine. `BB_INFERENCE` / `BB_TRANSCRIPTION` config keys are removed. |

### 6.3 Thread lifecycle (statuses)

Statuses: `pending` → `starting` → `active` ↔ `idle`, with `stopping` and `error` as execution outcomes.

| Status | Meaning |
| --- | --- |
| `pending` | Row exists; never successfully dispatched; nothing provisioned. |
| `starting` | First dispatch cleared; provisioning / session start in progress. |
| `active` | Provider turn running. |
| `idle` | Ready for follow-up or `/clear`. |
| `stopping` | Stop requested; awaiting settlement. |
| `error` | Failed run; may restart. |

Archival and deletion are orthogonal record dimensions (not statuses). Lifecycle ownership cascades archive/delete to dependents; unarchiving an owner does not restore dependents. Archiving grants an undo grace (`ARCHIVE_UNDO_GRACE_MS`) before teardown: within the window, Undo is free, open terminals stay up, and a mid-turn run can keep going; a start still in flight is stopped immediately on archive.

### 6.4 Environment provisioning (product requirements)

- Environment rows exist before workspace creation; status walks `creating` → `provisioning` → `ready` | `error`.
- Creation failures are **terminal** (no silent auto-retry ladder); explicit retry reuses the row with an incremented attempt.
- Setup hooks: POSIX `.bb-env-setup.sh` after owned-path creation; `.bb-env-teardown.sh` before removal (15-minute timeout). Attached checkout / personal-workspace paths skip hooks.
- Managed worktrees: `git worktree` on a fresh branch; optional `.worktreeinclude`; five-minute grace after last archive before removal.
- Existing worktrees can be selected and adopted at thread creation: the adapter attaches the path without taking ownership (adopted worktrees are never deleted by bb), and adoption excludes main checkouts and bb-managed worktrees.

### 6.5 Server role and relocation

- User-facing language: **server** / **server machine**; API/SDK keep `primaryHostId`.
- A planned move (`serverMove` experiment) copies **server-owned** data only; host IDs and host-owned files (worktrees, thread storage, checkouts, provider sessions) stay put.
- Targets: persistent machines only (including provider-managed persistent VMs while they hold the server role). Ephemeral sandboxes cannot be targets.
- Checklist, version align, freeze/copy with digest, health check, Connect or direct-address cutover, and lock of the old server copy are required for a safe move. See [docs/server-move-plan.md](docs/server-move-plan.md).

---

## 7. Functional requirements

Requirements use MoSCoW priority: **Must** / **Should** / **Could**.

### 7.1 Install, launch, and configuration

| ID | Priority | Requirement |
| --- | --- | --- |
| F-LAUNCH-1 | Must | Packaged `npx bb-app` starts server + host daemon, serves the app, and restarts a crashed child without stopping the other. |
| F-LAUNCH-2 | Must | Desktop app supervises the same packaged runtime and auto-updates (stable and Nightly channels with separate identity). |
| F-LAUNCH-3 | Must | Default data directory `~/.bb/`; launcher flags and `bb-app config` / `env` / client SSH mappings override defaults with documented precedence. |
| F-LAUNCH-4 | Must | `bb-app stop` stops a background/other-terminal launcher using recorded runtime identity. |
| F-LAUNCH-5 | Must | Configuration reload applies live-reloadable keys without full restart; startup-only keys document that a restart is required. |
| F-LAUNCH-6 | Should | Dev checkouts use isolated data dirs and deterministic ports so worktrees can run alongside packaged instances. |
| F-LAUNCH-7 | Should | Server-side package-manager calls use bb's bundled npm/npx rather than the inherited PATH, so install, server move, and skill installs work on machines without Node on PATH. |
| F-LAUNCH-8 | Should | Packaged `bb-app start` enables in-app updates by default; Settings → Updates and `bb updates app` can apply and restart. |
| F-LAUNCH-9 | Should | New installs open a first-run setup guide (agent, projects, plugins, devices); finish/skip is recorded, and Settings / `bb settings replay-onboarding` can show it again. |

### 7.2 Projects and sources

| ID | Priority | Requirement |
| --- | --- | --- |
| F-PROJ-1 | Must | Users can create/open projects mapped to local paths on enrolled hosts. |
| F-PROJ-2 | Must | A project may have sources on multiple hosts. |
| F-PROJ-3 | Must | Project settings include reorderable project list and per-project settings page. |
| F-PROJ-4 | Should | GitHub `origin` remotes are discoverable for GitHub plugin tracking. |
| F-PROJ-5 | Should | Project-scoped machine environment variables apply on the relevant hosts; project settings list inherited global variables read-only with an Override action, and `.env` contents can be imported through Settings. |
| F-PROJ-6 | Should | Projectless selection is explicit and reflected in pickers. |

### 7.3 Threads and conversation

| ID | Priority | Requirement |
| --- | --- | --- |
| F-THR-1 | Must | Spawn threads with project, environment intent, provider/model, and initial prompt (UI, CLI, SDK). |
| F-THR-2 | Must | Live timeline of messages, tool calls, file changes, and diagnostics with realtime updates. |
| F-THR-3 | Must | Steer: send follow-ups, queue messages, stop, retry recoverable failures, edit messages. |
| F-THR-4 | Must | Wait/poll helpers for scripts (`bb thread wait`, SDK wait/output). |
| F-THR-5 | Must | Nest threads (drag-to-nest / parent-child) for delegation hierarchies. |
| F-THR-6 | Must | Manager threads can coordinate child work per server product policy. |
| F-THR-7 | Must | Sidebar organization (sections, order, collapsed state, destinations) syncs via the server across devices. |
| F-THR-8 | Should | Fork threads (reuse source environment by default); preserve reasoning level on follow-ups. |
| F-THR-9 | Must | Timeline pagination owns event windows and keeps conversation groups coherent; by default the latest completed context clear is the history floor, unless Settings → General `keepHistoryAfterContextClear` keeps earlier messages visible above the clear boundary. |
| F-THR-10 | Could | Voice input via configured AI transcription service; preserve failed recordings; bb accepts recordings up to 25 MB (Codex ≤20 MB, bb cloud ≤10 MB). |
| F-THR-11 | Must | Clear agent context in an idle thread (`/clear`, `bb thread clear`) while keeping workspace and history up to the clear floor. |
| F-THR-12 | Must | Spawn/fork may assign immutable `lifecycleOwnerThreadId`; side chats and workflow workers assign ownership at creation. |
| F-THR-13 | Should | Split panes keep deliberately opened archived threads; overflow split dragging works in any direction; thread-search results open in split panes. |
| F-THR-14 | Should | Thread mentions label relation; worktree threads group in every sidebar organization mode. |
| F-THR-15 | Should | Drag sidebar threads into a composer to mention them; skill search supports fuzzy matching and explicit `$skill` mentions; mention suggestions prioritize related threads. |
| F-THR-16 | Should | Save a composed message as a draft into the thread queue and send it later with Send now (bundled Drafts plugin), without fake scheduled times; there is no separate Drafts sidebar section — drafts stay on their owning thread. |
| F-THR-17 | Should | Hand off to a new thread from the follow-up composer with any provider or model (including the current provider); explicit Exit handoff restores the original execution settings, retains draft edits, and drops the automatic source reference. CLI/SDK callers use `bb thread spawn` / `threads.spawn` with the source reference in the prompt. |
| F-THR-18 | Should | Finished-turn display is configurable per provider (collapse into a "Worked for" row or flat) with provider-declared defaults; set in Settings → Providers or `bb settings completed-turns`; applies to existing threads, the conversation outline, and `bb thread log`. |
| F-THR-19 | Should | Panel tabs can be closed as other tabs or tabs to the right; an explicit diff display mode survives panel resizes. |
| F-THR-20 | Should | Thread-row quick actions and sidebar footer icons are customizable; sidebar layouts can differ per tab. |
| F-THR-21 | Should | Per-thread queue drawer open/collapsed choice is remembered; new queues can open by default; collapsed headers surface the newest queue reason and animated counts. |
| F-THR-22 | Should | Approval / Ask User Question cards open by default when presented; Ask User Question interactions may wait up to seven days. |
| F-THR-23 | Should | Thread Info panel presents commits, uncommitted changes, forks, and thread storage as one list system (storage as a folder tree); built-in Git shelf and Commit button can be hidden via `showGitChanges`. |

### 7.4 Environments and workspaces

| ID | Priority | Requirement |
| --- | --- | --- |
| F-ENV-1 | Must | Support unmanaged host directories and managed git worktrees (default worktree plugin). |
| F-ENV-2 | Must | Support personal workspace and project-checkout environment plugins. |
| F-ENV-3 | Must | Environment status and failures are visible in UI/CLI/SDK; reservations expose `creating`. |
| F-ENV-4 | Must | Cleanup of managed environments when no unarchived threads remain (with documented grace). |
| F-ENV-5 | Should | Plugin-defined custom environments (e.g. copy-on-write, Modal sandboxes). |
| F-ENV-6 | Should | Repository setup/teardown scripts honor the documented timeout and failure contracts. |
| F-ENV-7 | Should | Creating a thread in an environment opens the composer ready to send. |
| F-ENV-8 | Should | The root composer offers reuse of an existing environment when starting a new thread, not only when seeded from a thread or workspace header. |
| F-ENV-9 | Should | The worktree environment provider lists existing worktrees scoped to the project and host and adopts a selected path without taking ownership: bb never deletes an adopted worktree, and main checkouts and managed worktrees are excluded from adoption. |
| F-ENV-10 | Must | Destroyed environment rows are retained (not pruned) so later thread deletion can still remove host storage. |
| F-ENV-11 | Should | Shared project-checkout environments survive cancellation of a starting thread that has not become their sole live user. |
| F-ENV-12 | Should | Operators can clean unused environments via `bb environment cleanup` / SDK without deleting environments still referenced by live threads. |

### 7.5 Hosts / machines

| ID | Priority | Requirement |
| --- | --- | --- |
| F-HOST-1 | Must | Primary local host daemon enrolls on first launch; server role is visible (badge / Role in `bb machine list`). |
| F-HOST-2 | Must | Additional machines can be enrolled (installer / Connect machine credential / Tailscale routes). |
| F-HOST-3 | Must | `bb machine list` enumerates persistent machines; `--all` includes disposable sandboxes. |
| F-HOST-4 | Should | Machine plugins can provision cloud machines that pause/resume (e.g. Modal); incidental wakes avoided; tracked allocations reconciled. |
| F-HOST-5 | Should | Searchable multi-machine picker separates machine selection from environment selection for projects with several machines. |
| F-HOST-6 | Should | Experimental planned server move to another persistent machine (`bb server move`, UI dialog) with checklist, cutover, and old-copy lock; desktop recovers navigation after a moved server. |
| F-HOST-7 | Should | The desktop app supports a persisted list of saved server addresses and lets the user switch between This Mac / local, Connect servers, and custom URLs (Desktop Settings / Window → Server) without losing earlier entries. |
| F-HOST-8 | Must | Removing a machine can preserve its threads as read-only history; Connect shares of removed hosts are pruned. |
| F-HOST-9 | Should | Native Windows hosts (alpha) enroll via the Windows desktop installer or `npx` in PowerShell/CMD with Git for Windows; drive-letter paths only; PowerShell terminals; may be added as remote machines; cannot be a server-move target. |

### 7.6 Providers and inference

| ID | Priority | Requirement |
| --- | --- | --- |
| F-PROV-1 | Must | Run threads via installed provider CLIs the user authenticates (Claude Code, Codex, Pi, ACP agents including Cursor). |
| F-PROV-2 | Must | Mix providers per thread/task. |
| F-PROV-3 | Must | Configure AI services for titles, commit messages, and voice via Settings → AI services / `bb settings ai-services` (`automatic` / `off` / service id). Automatic tries bb cloud (`bb-ai`) first when the account is signed in, then other registered services (including third-party) in lexicographic plugin/service order; a picked service is used alone with documented fallbacks. Legacy `BB_INFERENCE` / `BB_TRANSCRIPTION` keys are ignored/refused. |
| F-PROV-4 | Should | Account pool plugin rotates Claude/Codex accounts on usage limits across machines; nested bb instances can deliberately reuse the parent's Account Pooler. |
| F-PROV-5 | Should | Provider usage reporting and retry plugins; custom ACP agents can declare that they report usage when their dialect supports it. |
| F-PROV-6 | Must | Provider sign-in remains on the host terminal; mobile/remote assume a signed-in host. |
| F-PROV-7 | Must | Resumed threads keep their own provider sessions (no cross-thread session mixups). |
| F-PROV-8 | Must | Block starting a new thread when the selected provider CLI is missing, with an Install banner that explains how to recover. |
| F-PROV-9 | Should | Built-in provider plugins (Claude Code, Codex, Pi, ACP) remain forkable outside the monorepo per [docs/forkable-plugins.md](docs/forkable-plugins.md). |
| F-PROV-10 | Must | Users can enable/disable individual providers (`bb provider enable` / `disable`, Settings → Providers) without uninstalling the plugin; disabled providers are omitted from pickers and reject new turns. |
| F-PROV-11 | Should | Providers may expose model-specific service tiers (including Codex Ultrafast); Settings → General `allowFastServiceTier` gates faster tiers for new turns. |
| F-PROV-12 | Should | bb cloud AI (`bb-ai`) can supply titles, commits, and voice for a signed-in bb account without a Codex login; `bb ai on` / `off` controls whether cloud AI is offered. |

### 7.7 Files, editors, terminals, browsers

| ID | Priority | Requirement |
| --- | --- | --- |
| F-FILE-1 | Must | Browse and mention files; skip gitignored paths for mention performance. |
| F-FILE-2 | Must | Local editor integration via loopback helper (desktop / local `bb-app`); optional SSH target mapping for remote work hosts. |
| F-FILE-3 | Should | Monaco editor and PDF/Markdown/HTML inline previews via plugins; shared file-preview target for inline-vis; preview failures explain the cause instead of a generic load error. |
| F-FILE-4 | Should | Terminal access through server/daemon capabilities exposed to CLI/SDK; exited terminals keep output readable for 30 minutes (or until the host daemon restarts) with exit details and `terminal read` / `terminal wait` helpers. |
| F-FILE-5 | Should | Desktop built-in browser + Browser Automation plugin; live headless browser previews with expandable lightbox; cookie import from installed browsers (including Helium on macOS); keyboard focus stays off hidden and automation-controlled tabs. |
| F-FILE-6 | Should | Agent Annotations plugin: select elements in a Browser tab, comment, and add structured context to the prompt. |
| F-FILE-7 | Must | Track attachment ownership and reclaim unowned uploads; CLI image/file attachments upload before the thread request, including when the server is remote. |
| F-FILE-8 | Should | Diff panel supports filtering files by path with standard globs. |
| F-FILE-9 | Should | Desktop zoom clamps to 50–300% in 10% steps with a transient zoom indicator. |
| F-FILE-10 | Should | File Editor offers an explicit Save action; desktop copy uses one clipboard path (native in bb Desktop). |
| F-FILE-11 | Should | Opt-in Storage & retention plugin (`bb--storage-retention`) provides durable archive/delete policies, usage scans, orphan cleanup, and CLI (`bb storage …`). |

### 7.8 Plugins, skills, and marketplace

| ID | Priority | Requirement |
| --- | --- | --- |
| F-PLUG-1 | Must | Install, enable/disable, and configure plugins from UI and `bb plugin`; installs and updates can run in the background without blocking the UI. |
| F-PLUG-2 | Must | Official / community marketplace discovery (categories, screenshots, author pages) without a refresh installing code; install pipeline validates packages. |
| F-PLUG-3 | Must | Plugin SDK with documented surfaces; new public API members are `experimental_` until audited. |
| F-PLUG-4 | Must | Skills are first-class (install, contribute instructions); separate workspaces from plugins. |
| F-PLUG-5 | Should | BB Guide controls which introduction/skills agents receive, including the instruction that agents wait for a user request before creating or messaging other bb threads. |
| F-PLUG-6 | Should | Example plugins and Plugin Guide as the sole plugin API documentation. |
| F-PLUG-7 | Should | Unified plugin cards with preserved detail tabs; plugin-declared icons resolve wherever a BB icon name is accepted. |
| F-PLUG-8 | Must | Plugin safe mode (`bb plugin safe-mode` / SDK / command palette) stops every non-built-in installed plugin without clearing each plugin’s own enabled flag; ending safe mode restores previously enabled plugins and reports start failures. Install/update/enable of stopped plugins is refused while safe mode is on. |
| F-PLUG-9 | Must | Sidebar navigation and thread list default to Automatic, preferring an installed replacement plugin over the bundled `navigation` / `thread-list` plugins. |
| F-PLUG-10 | Should | Listed built-in plugins stay forkable (public SDK + registry UI only); CI `check:plugin-forks` enforces the list in `scripts/forkable-plugins.json`. |

### 7.9 Built-in / official capability plugins (product catalog)

These ship as bundled or catalog plugins; presence in the catalog is part of the product offering.

| Area | Plugins (representative) | User-facing outcome |
| --- | --- | --- |
| Environments | `environment-git-worktree`, `environment-personal-workspace`, `environment-project-checkout`, `environment-modal-sandbox` (experimental) | Isolated or cloud workspaces |
| Providers | `provider-claude-code`, `provider-codex`, `provider-pi`, `provider-acp`, `provider-usage`, `provider-retry`, `account-pool` | Run and manage agent backends |
| Planning / ops | `tasks`, `workflows` (opt-in), `automations`, `scheduled-send`, `concurrency-limit` | Track, orchestrate, schedule work |
| Context | `memory`, `custom-instructions`, `bb-guide`, `drafts` (bundled, enabled by default), `prompt-library` (bundled, disabled by default), `agent-annotations`, `bb-ai` | Durable memory, guidance, saved drafts, prompt library, browser annotations, bb cloud AI |
| Collaboration | `github`, `ask-user-question`, `secrets` | Issues/PRs, clarifying questions, secret prompts |
| Access | `connect`, `push-notifications`, `keep-awake` | Remote access, mobile/web/desktop push, host wake |
| Storage | `storage-retention` (bundled, disabled by default) | Opt-in archive/delete retention and disk cleanup |
| Shell UI | `navigation`, `thread-list` | Replaceable sidebar navigation and thread list (Automatic prefers installed forks) |
| UX | `side-chat`, `inline-vis`, `monaco-editor`, `pdf-preview`, `theme-preview`, `browser-automation` | Richer thread and desktop UX |

### 7.10 Tasks (plugin)

| ID | Priority | Requirement |
| --- | --- | --- |
| F-TASK-1 | Must | Linear-style tracker: projects, folders, keys, statuses, priorities, labels, subtasks, comments, attachments; search accepts terms in any order. |
| F-TASK-2 | Must | Delegate a task to an agent thread via presets (`bb tasks delegate` / UI). |
| F-TASK-3 | Must | Keep task records linked to executing threads; optional notify-last-agent on comments. |
| F-TASK-4 | Must | Full `bb tasks` CLI with `--json` for agents. |

### 7.11 Workflows and automations

| ID | Priority | Requirement |
| --- | --- | --- |
| F-WF-1 | Should | Provider-independent JS orchestration in QuickJS; real reasoning delegated to ordinary bb threads. |
| F-WF-2 | Should | Author surface `bb_workflow_run`; inspect/cancel via `bb workflows` and in-thread live cards; child threads can be activated directly from inline workflow previews. |
| F-WF-3 | Must | Sandbox: no Node/fs/shell/network/imports/clock/randomness inside QuickJS; schema validation restricted for safety. |
| F-WF-4 | Should | Automations support explicit working directories for scripts. |
| F-WF-5 | Must | Workflow worker attempts assign lifecycle ownership to the origin thread (including replacements). |

### 7.12 Connect and multi-device

| ID | Priority | Requirement |
| --- | --- | --- |
| F-CONN-1 | Must | Distinguish **browser/control devices** from **execution machines**. |
| F-CONN-2 | Must | bb connect pairs a server for account-gated remote URLs; server owns tunnel reconnect; Connect credential travels with server move; clients ride through tunnel resets instead of failing visitors. |
| F-CONN-3 | Must | Documented private Tailscale Serve path; warn against public Funnel / unauthenticated wildcard bind on untrusted networks. |
| F-CONN-4 | Must | Mobile pairs as a connect machine (QR/code from Settings → Mobile or `bb connect machine-code`) without an experiment gate; requires signed-in bb account and Connect plugin. |
| F-CONN-5 | Should | Push notifications to mobile, web, and desktop independently (iOS when server can reach `exp.host`; Android push untested). |
| F-CONN-6 | Must | Secret requests stay alive through bb connect and remain in place in the timeline. |
| F-CONN-7 | Must | Custom DNS / reverse-proxy hostnames require a matching `BB_APP_URL` for DNS-rebinding protection; direct IP and bb Connect continue to work without it. |

### 7.13 Mobile

| ID | Priority | Requirement |
| --- | --- | --- |
| F-MOB-1 | Must | Native shell loads the server web app; native ownership of pairing, profiles, push, deep links, share intents. |
| F-MOB-2 | Must | Direct URL and bb connect enrollment. |
| F-MOB-3 | Should | iOS TestFlight distribution; Android APK alpha via public `android-testing` release / Settings → Mobile downloads (Play store and tested Android push still deferred). |
| F-MOB-4 | Must | Explicitly unavailable on phone: plugin nav frontends, provider login, local editor/daemon, custom CSS themes, desktop browser automation (documented). |
| F-MOB-5 | Should | Compact layouts: typeahead above new-thread prompt; stable sidebar trailing column; Recent statuses aligned with desktop; short fast swipes open the compact sidebar; server error pages surface in the mobile shell. |
| F-MOB-6 | Should | Touch: keep keyboard open when removing composer attachments; avoid autofocusing the new-thread composer; square composer action buttons; mobile terminal keyboard controls. |
| F-MOB-7 | Should | Settings → Mobile / `bb settings mobile-app` expose current iOS TestFlight and Android APK download metadata without routing the APK through the bb server. |

---

## 8. Non-functional requirements

### 8.1 Performance and UX

| ID | Priority | Requirement |
| --- | --- | --- |
| NF-PERF-1 | Must | Realtime updates over WebSocket for thread/project/environment/host/system changes. |
| NF-PERF-2 | Must | UI remains usable during long agent runs (streaming markdown, Mermaid stability, deferred drawer content, retain after open). |
| NF-PERF-3 | Must | Avoid CSS `@scope`; use sanctioned theme tokens (`--canvas` / `--ink`); shared persistent drawer pattern. |
| NF-PERF-4 | Should | Startup JS and background polling stay lean (e.g. reduced GitHub polling, faster file mentions). |
| NF-PERF-5 | Should | Timeline head state is separate from conversation context; outer timeline growth snaps while a thread is active; scrolling does not flicker the timeline. |
| NF-PERF-6 | Should | Quick palette supports distinct modes and grouped thread-search results; keyboard-shortcut search ranks visible label matches above description-only matches; includes a command to open the data directory. |

### 8.2 Reliability

| ID | Priority | Requirement |
| --- | --- | --- |
| NF-REL-1 | Must | SQLite is source of truth; server is effectively stateless beyond DB + process. |
| NF-REL-2 | Must | Environment/thread startup recovers across server restart via persisted startup context and engine sweep. |
| NF-REL-3 | Must | Daemon disconnects leave cleanup pending until confirmed; Connect grant redemption is crash-safe. |
| NF-REL-4 | Should | Launcher isolates stdio logs so a stalled terminal cannot block service logging; logs stay free of terminal escape sequences. |
| NF-REL-5 | Must | Lifecycle-owner delete/archive cascades reliably; dependent cleanup retries on sweeps and reconnect. |
| NF-REL-6 | Should | Events table pruning keeps long-lived installs healthy (see `docs/events-table-pruning.md`). |

### 8.3 Security and trust

| ID | Priority | Requirement |
| --- | --- | --- |
| NF-SEC-1 | Must | Default bind is loopback; `0.0.0.0` is explicitly dangerous (unauthenticated API with command execution and file reads). |
| NF-SEC-2 | Must | Connect machine credentials are secrets (not listed in `config list`); revoke via dashboard. |
| NF-SEC-3 | Must | Local editor helper is loopback-only and origin-trusted. |
| NF-SEC-4 | Must | Workflow QuickJS sandbox and schema allowlists as described above. |
| NF-SEC-5 | Should | Memory plugin rejects basic prompt-injection and secret patterns. |
| NF-SEC-6 | Must | Telemetry never attaches user/host/project/workspace/message content; opt out via `BB_TELEMETRY=false` or the persistent Settings toggle; opt-outs are tracked anonymously without content. |
| NF-SEC-7 | Must | Server-move export is digest-checked and downloadable only by the target machine. |
| NF-SEC-8 | Must | Plugin safe mode prevents install/update/enable side effects for non-built-in plugins while it is on. |

### 8.4 Privacy and telemetry

Production desktop and `npx bb-app` may send anonymous usage events (starts, thread creation counts, user message counts, public plugin installs) keyed by a random per-install id. Development/source runs do not send. Private/local plugin installs report no plugin name. Telemetry id moves with server-owned data on a server move. Users can persist an opt-out in Settings (in addition to `BB_TELEMETRY=false`).

### 8.5 Compatibility

| ID | Priority | Requirement |
| --- | --- | --- |
| NF-COMPAT-1 | Must | Node.js floor 22.19; tested on 22.19+, 24 LTS, 26 Current. |
| NF-COMPAT-2 | Must | Hosts: macOS, Linux, Windows via Ubuntu WSL2 only. |
| NF-COMPAT-3 | Must | Native add-ons install via npm lifecycle scripts (`better-sqlite3`, `node-pty`, `@parcel/watcher`); document npm 12 `--allow-scripts` requirement. |
| NF-COMPAT-4 | Must | Daemon protocol versioning for enrolled machine updates. |
| NF-COMPAT-5 | Must | Server move blocks when the target runs a newer bb than the server until the server is updated; then installs the server’s exact version on the target. |

### 8.6 Observability and operability

| ID | Priority | Requirement |
| --- | --- | --- |
| NF-OPS-1 | Must | Rotating app logs plus `server-stdio.log` / `host-daemon-stdio.log` under the data dir. |
| NF-OPS-2 | Should | `bb status`, health endpoints, and QA docs for local debugging ports and data dirs. |
| NF-OPS-3 | Should | `bb server move --check` surfaces blockers and warnings before copying. |
| NF-OPS-4 | Should | `bb diagnostics cli-errors` tallies failed local CLI invocations (command path, error code, and unknown command/flag; never argument values) with `--since` / `--clear` / `--json`; CLI errors suggest valid commands and flags and explain missing context. |
| NF-OPS-5 | Should | Opt-in server performance diagnostics require both startup permission (`BB_PERF_DIAGNOSTICS` / `--perf-diagnostics`) and the `performanceDiagnostics` experiment. |
| NF-OPS-6 | Should | Prompt history is browsable via `bb prompt-history list` / SDK alongside the opt-in Prompt Library plugin. |

---

## 9. Platform support matrix

| Platform | Status |
| --- | --- |
| macOS Apple Silicon desktop | Supported (recommended) |
| macOS Intel | Use `npx bb-app` (not desktop binary focus) |
| Linux x64 AppImage | Alpha |
| Linux host via `npx` / source | Supported |
| Windows 11 x64 native (desktop installer / `npx`) | Alpha (Git for Windows required; no server-move target) |
| Windows + WSL2 Ubuntu | Supported (all bb processes inside WSL2) |
| iOS mobile | Early access / TestFlight |
| Android mobile | Alpha APK (`android-testing` / Settings → Mobile); Play store and push untested |
| iPad | Runs phone layout |

---

## 10. Information architecture (app)

Primary user objects in the UI:

1. **Home / dispatch** — start work, recent activity, optional first-run / finish-setup checklist; palette modes for search and actions (including open data directory).
2. **Projects** — sources, settings, reorder, project-scoped env vars with inherited read-only rows, `.env` import.
3. **Threads** — nested list (via `thread-list` plugin), sections, worktree grouping, live timeline, composer (drafts, handoff, queue), split panes, Info panel (git facts, storage tree), panels (diff with glob filter, workflow inspector, side chat, browser previews, etc.).
4. **Machines** — enrolled hosts (including alpha Windows), sandboxes, server-machine badge, optional Move server flow; desktop Server menu for saved addresses; remove machine with read-only history option; Updates page shows one line per machine.
5. **Plugins / Skills** — marketplace browse, background install/update, configure, separate workspaces, detail tabs; plugin safe mode.
6. **Settings** — appearance / interface (navigation and thread-list provider Automatic, customizable row actions), providers (enable/disable, finished-turn display, service tiers), AI services / bb cloud AI, General (Git shelf, context-clear history, archive confirm, setup guide), files/editor, environment variables, Mobile downloads, remote access (Connect), experiments, browsers, Voice Input, telemetry opt-out.
7. **Plugin nav panels** — driven by the `navigation` plugin (Tasks, GitHub, Docs, Automations, Storage & retention when enabled, etc.; web/desktop; not mobile frontends).
8. **Notification center** — missed notifications across push channels.

---

## 11. API and extensibility requirements

### 11.1 Public automation API

- HTTP routes + WebSocket notifications per `@bb/server-contract`.
- TypeScript `BBSdk` covering projects, threads (including timeline pagination, clear, lifecycle owner on spawn/fork), environments (including cleanup), hosts, plugins (including safe mode), providers (including enable/disable), AI services, files, terminals, skills, theme, guide, status, prompt history, storage retention when the plugin is enabled, mobile-app download metadata, server move (experimental), etc.
- CLI command groups mirror SDK areas; plugin commands proxy through `bb`; built-in plugin CLIs share one declarative command contract (`defineCli` / `cliCommand`) with consistent parsing, validation, help, and output.
- CLI errors suggest valid commands and flags, explain missing context, and return consistent JSON error envelopes for agents.

### 11.2 Plugin API product rules

- Plugin Guide is the only plugin API documentation; surfaces registered in `packages/plugin-api-map`.
- New public members: `experimental_` prefix + entry in `docs/api_to_audit.md` until stabilized.
- Plugin tools awaiting user input (`bb.ui.requestInput`) may outlive their calling turn and resume the agent or start a new turn when answered; errors and dismissals do not wake idle threads.
- Frontend plugins register commands (`app.commands.register`) with default keyboard shortcuts; every command is rebindable under `plugin:<plugin-id>/<command-id>` and conflicts require explicit replacement.
- Composer control APIs let plugins set picker selections, remove plugin-owned mentions, observe successful submissions, and attach plugin-owned data to a submission without core interpreting it.
- Plugins can publish discoverable RPC descriptions and wire schemas for other plugins and agents; `bb plugin rpc list` / `bb plugin rpc inspect` expose them.
- Plugins may register AI services (`experimental_aiServices`) picked per task (titles, commits, voice).
- Environment and machine plugin APIs enable third-party workspace and cloud provisioning.
- Browser control and page-scripting APIs enable desktop browser automation and annotations plugins; plugin browser extensions can add address-bar controls, run page scripts, and receive page messages (experimental).
- Forkable built-ins must not depend on private monorepo packages; see [docs/forkable-plugins.md](docs/forkable-plugins.md).
- Plugin safe mode unloads non-built-in plugins without clearing each plugin’s enabled flag.

### 11.3 Provider bridge

- Agent runtime adapters/bridges for Codex, Claude Code, Pi, and ACP.
- Provider parity and bridge protocol docs define expected event and session behavior.

---

## 12. Experiments (gated features)

Server-persisted experiment flags (defaults off):

| Key | Intent |
| --- | --- |
| `serverMove` | Planned relocation of the server role to another persistent machine |
| `changelogPreview` | In-app changelog preview card on Settings → Updates |
| `navigationRail` | Persistent left navigation rail (desktop/web; phone/narrow keep drawer) |
| `performanceDiagnostics` | Server performance diagnostics UI (also needs startup permission) |

Experiments must be toggleable via Settings and `bb settings experiment`. Server-machine wording/badge/Role column may ship without the experiment; export/cutover require `serverMove` on. Former `mobileApp`, `sidebarProgressiveDisclosure`, `multiMachinePicker`, and `timelineWindowing` experiment keys are removed; mobile pairing, multi-machine picking, and timeline window ownership ship as ordinary product behavior.

---

## 13. Success metrics

Leading indicators (align with anonymous telemetry where available):

1. **Activation** — successful first project + first thread on a new install.
2. **Engagement** — threads created / user messages per install (telemetry).
3. **Breadth** — share of installs using CLI or SDK within 7 days (qualitative + support signals).
4. **Extensibility** — public plugin installs; third-party marketplace entries.
5. **Reliability** — rate of environment creation errors, daemon reconnect success, launcher child restarts, successful server-move cutovers (experiment cohort).
6. **Multi-device** — Connect pairings; mobile sessions among paired devices.
7. **Retention** — weekly active installs returning after day 7 / day 30.

Qualitative success:

- Users run parallel agents without corrupting their main checkout.
- Agents and humans can drive the same workflows through CLI/SDK.
- Security-conscious teams can evaluate bb fully in local/loopback mode.
- Users who outgrow a laptop can move the server to an always-on machine without discarding history.

---

## 14. Constraints and risks

| Risk | Mitigation |
| --- | --- |
| Provider CLI churn breaks bridges | Provider plugins + parity tests; isolate bridges in `agent-runtime`. |
| Unauthenticated API misuse on `0.0.0.0` | Docs warnings; default loopback; Connect account gating; `BB_APP_URL` for custom DNS. |
| Native addon install failures (npm 12) | Document `--allow-scripts`; clear bindings-file error guidance. |
| Protocol skew with old daemons | `HOST_DAEMON_PROTOCOL_VERSION` bump forces update. |
| Mobile feature gap surprises users | Explicit unsupported list in platform docs and settings. |
| Plugin API instability | `experimental_` prefix + audit list before stabilization. |
| Cloud sandbox cost/complexity | Keep Modal and similar plugins experimental and opt-in. |
| Unsafe or partial server moves | Checklist blockers, digest-checked export, health gate, old-copy lock; v1 requires online source; block Windows targets. |
| Misbehaving third-party plugins | Plugin safe mode stops non-built-ins without wiping enablement. |
| Alpha Windows / Android regressions | Keep alpha labels; prefer WSL2/macOS/Linux and iOS TestFlight for production evaluation. |
| bb cloud AI / Connect account regressions | Keep account + bb cloud AI optional; local provider CLIs and Codex AI services remain usable offline of getbb.app. |

---

## 15. Rollout and distribution

| Channel | Audience |
| --- | --- |
| Desktop stable (macOS arm64) | Default recommended users |
| Desktop Nightly | Early adopters; separate app identity |
| Desktop Windows x64 | Alpha |
| Linux AppImage | Alpha |
| `bb-app@latest` npm | Cross-platform / CI / WSL / Intel Mac / Windows alpha |
| `bb-app@nightly` npm | Automated builds from `main` |
| iOS TestFlight | Mobile early access |
| Android APK (`android-testing`) | Mobile alpha sideload |
| Source `pnpm dev` / `pnpm start` | Contributors and advanced users |

Release process docs: `docs/bb-release-process.md`, `docs/official-plugin-release-process.md`.

---

## 16. Out of scope / future directions

Explicitly deferred or emerging (not current Must requirements):

- Promoting native Windows or Android from alpha to recommended without a dedicated stability pass.
- Android Play store release and tested Android push.
- Replacing provider-native auth UIs inside bb.
- Fully hosted multi-tenant bb that replaces local SQLite as the default.
- Guaranteeing pixel-complete plugin frontend parity on mobile.
- Marketplace features still in draft (see `docs/plugin-marketplace-plan.md`).
- Dead-server restore from backup and automatic failover (beyond planned `serverMove`).
- Moving host-owned files (worktrees, checkouts, provider sessions) during server relocation.
- Moving the server role onto a Windows machine.
- Requiring a hosted bb account / bb cloud AI for core product use.

Aligned future directions from vision:

- Richer remote orchestration and peer-backed environments.
- Deeper team collaboration around tasks/workflows while preserving local trust model.
- More environment and machine providers via stable plugin APIs.
- Broader promotion of server move once the experiment hardens.
- Hardening Windows desktop and Android mobile beyond alpha.
- Expanding optional hosted AI services that plug into the same AI-tasks API without becoming the only path.

---

## 17. Acceptance criteria (product-level)

A release is product-complete for “core bb” when all of the following hold:

1. A new user on a supported host can install via desktop or `npx bb-app`, open the UI, add a project, spawn a thread with an authenticated provider, and see live events.
2. The same spawn/steer/wait/output/clear flow works via `bb` CLI and `BBSdk` against that server.
3. Managed worktree and unmanaged directory environments both work; managed cleanup follows the grace/removal rules.
4. Enrolling a second machine (or using Connect remote control) works per docs without exposing the API to the public internet by default.
5. Installing an official plugin (e.g. Tasks or Memory) extends CLI and UI without a server fork.
6. Telemetry is off in source/dev and opt-outable in production (settings and/or env); no message content leaves the machine.
7. Platform support matrix and mobile limitations are accurate for the shipped artifacts.
8. Lifecycle ownership cascades archive/delete for side chats and workflow workers as documented; archive undo grace behaves as specified.
9. With `serverMove` enabled, a planned move to another persistent enrolled (non-Windows) machine completes checklist → copy → health → cutover and leaves the old copy locked as a regular machine.
10. A saved draft can be sent later with Send now through the normal queue, and a handoff to a new thread (including within the same provider) exits back to the source execution without losing draft edits.
11. Plugin safe mode stops non-built-in plugins and restores them cleanly when turned off.
12. AI services for titles/commits/voice are configurable without the removed `BB_INFERENCE` / `BB_TRANSCRIPTION` keys; automatic can use bb cloud when signed in, otherwise falls through to other registered services.
13. Individual providers can be disabled and re-enabled without uninstalling plugins; disabled providers reject new turns.
14. Mobile pairing works without an experiment flag; Settings → Mobile exposes iOS TestFlight and Android APK download links.
15. Platform support matrix accurately labels Windows desktop and Android APK as alpha.

---

## 18. Document maintenance

- Update this PRD when vision, core entities, surface parity rules, or Must-level requirements change.
- Prefer linking to living reference docs (`configuration.md`, `platform-support.md`, `worktrees.md`, `server-move-plan.md`, Plugin Guide) for operational detail rather than duplicating every flag.
- Changelog (`CHANGELOG.md`) records shipped deltas; this PRD records intent and requirements.
- Keep [PRD.ru.md](PRD.ru.md) in sync when this document changes.

---

## Appendix A — Monorepo map (for implementers)

| Area | Location |
| --- | --- |
| Launcher / public SDK export | `packages/bb-app` |
| Web UI | `apps/app` |
| Desktop shell | `apps/desktop` |
| Server | `apps/server` |
| Host daemon | `apps/host-daemon` |
| CLI | `apps/cli` |
| Mobile | `apps/mobile` |
| Marketing / Connect site | `apps/web` |
| Domain types | `packages/domain` |
| DB | `packages/db` |
| Contracts | `packages/server-contract`, `packages/host-daemon-contract` |
| Plugin SDK | `packages/plugin-sdk` |
| Built-in plugins | `plugins/*` |

## Appendix B — Glossary

| Term | Meaning |
| --- | --- |
| **Thread** | Unit of agent work and conversation |
| **Manager thread** | Thread that coordinates other threads |
| **Lifecycle owner** | Immutable creation-time owner thread whose archive/delete cascades to dependents |
| **Environment** | Host + workspace binding for execution |
| **Host / machine** | Enrolled daemon identity |
| **Server machine** | Host currently holding the server role (`primaryHostId`) |
| **Source** | Project code location on a specific host |
| **Provider** | External coding agent runtime (CLI/ACP) |
| **Drafts** | Bundled plugin that saves composed messages into the normal thread queue for later sending (no separate Drafts sidebar section) |
| **Handoff** | Starting a new thread seeded with a reference to the source thread from the follow-up composer, explicitly exited to restore the original execution |
| **AI service** | Plugin-registered backend for titles, commit messages, or voice transcription |
| **bb cloud AI** | Optional `bb-ai` services backed by a signed-in bb account (automatic path for titles/commits/voice) |
| **Storage & retention** | Opt-in bundled plugin for archive/delete policies and disk cleanup |
| **Plugin safe mode** | Server flag that unloads every non-built-in installed plugin until turned off |
| **Forkable plugin** | Built-in that installs/typechecks/tests/builds outside the monorepo with public packages only |
| **Skill** | Instruction pack agents can load |
| **Plugin** | Packaged extension (server and/or app) |
| **Connect** | Account-gated remote access and machine pairing |
| **Worktree** | Managed `git worktree` environment |
| **Context clear** | Reset of agent context (`/clear`) that becomes the timeline history floor |
| **bb-app** | Published npm launcher package |
