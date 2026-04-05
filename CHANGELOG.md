# Changelog

## [1.2.1] - 2026-04-06

### Fixed
- `digest-agent.sh` now sources `secrets_env` from `pulse.yaml` after reading
  config, matching what `plug.sh` already does. Fixes a regression introduced in
  `914ade0` where switching from `~/.openclaw/shared/secrets/openclaw-secrets.env`
  to `~/.openclaw/.env` silently dropped any `PATH` entries (e.g. npm-global bin)
  that lived in the old file, causing `openclaw` to be unfindable in cron and the
  digest to fall back to mechanical format every run.

---

## [1.2.0] - 2026-04-06

### Added
- chrono-somnia wiring section in README: ready-to-paste `plug.sh` commands for
  all four pipeline stages (`observe` / `dream` / `decay` / `brief`) with the
  recommended cron schedule.
- hiVe stack section in README now lists chrono-somnia with a direct link.

### Changed
- Renamed skill from **Pulse Board** to **pulse bOard** across all files.
- Example digest output in README updated to reflect chrono-somnia skill names.

### Fixed
- `digest-agent.sh` lock staleness check used `date -r <file>` which is
  macOS/BSD only. On Linux the fallback made `AGE` equal to the current unix
  timestamp (~1.7B s), always exceeding the 3600 s threshold — so concurrent
  runs would always nuke the lock. Replaced with `python3 os.path.getmtime`,
  which is cross-platform and already a hard dependency.

---

## [1.1.9] - 2026-03-15

### Added
- Feishu delivery channel (`channel: feishu` in `pulse.yaml`). Supports both
  group chat delivery and thread delivery. For threads, set `thread_id` to the
  root message ID (`om_xxx`) of the target thread — the installer now explains
  this clearly. Feishu fetches a tenant access token on each delivery and uses
  the IM v1 reply API for thread delivery.
- `install.sh` now includes Feishu as a channel option with guided setup.

### Fixed
- Feishu `content` field now correctly sent as a JSON-encoded string, not a
  JSON object. Feishu API requires `content` to be `{"text":"..."}` as a
  string, not an object.
- `digest-agent.sh` JSON parse now strips stdout prefix lines (OpenClaw plugin
  registration messages) before parsing the JSON response. Fixes `parse failed`
  when Feishu plugin is active.
- Default digest times changed from 06:00/18:00 to 05:00/17:00 to avoid
  clashing with other scheduled skills at those hours.
- `deliver.sh` now exports secrets with `set -a` before sourcing, matching the
  fix already in `digest-agent.sh`.

---

## [1.1.8] - 2026-03-15

### Added
- Feishu delivery channel. Add `channel: feishu` to `pulse.yaml` with
  `app_id`, `app_secret`, `chat_id`, and optional `thread_id`. The skill
  fetches a tenant access token on each delivery and sends via the Feishu
  IM v1 messages API. Thread delivery is supported for group topics.
- `install.sh` now includes Feishu as a channel option during interactive
  setup, with guided prompts for App ID, App Secret, Chat ID, and Thread ID.

---

## [1.1.7] - 2026-03-14

### Fixed
- `digest-agent.sh` now exports secrets to subprocesses via `set -a` before
  sourcing the secrets env file. Previously, variables like `DEEPSEEK_API_KEY`
  and `GATEWAY_TOKEN` were sourced into the current shell but not exported,
  so OpenClaw's subprocess couldn't see them. In cron's clean environment this
  caused `HTTP 401` on DeepSeek, fallback to OpenRouter free tier, and
  ultimately `parse failed` on the garbage HTML response.

---

## [1.1.6] - 2026-03-13

### Fixed
- `digest-agent.sh` prompt is now written to a temp file before being passed
  to `openclaw agent`. Previously the prompt was built as a shell variable
  containing the raw log — special characters (em dashes, newlines, Unicode)
  caused silent parse failures in cron's restricted shell environment, falling
  back to mechanical format every time.

---

## [1.1.5] - 2026-03-11

### Fixed
- `digest-agent.sh` now joins all agent response payloads instead of reading
  only `payloads[0]`. When the agent returns multiple payloads (e.g. during
  multi-step reasoning), the previous code failed to parse and silently fell
  back to mechanical format. All payload texts are now concatenated and used
  as the LLM summary.

---

## [1.1.4] - 2026-03-11

### Fixed
- `install.sh` now detects the `openclaw` binary location at install time and
  automatically prepends its directory to the crontab `PATH` line. Previously,
  users with npm-global installs (e.g. `~/.npm-global/bin`) would silently get
  mechanical-only digests because `openclaw` was not found in cron's restricted
  PATH. The installer announces the PATH change and includes it in the confirmed
  crontab write — nothing silent.

### Notes
- If you already have pulse bOard installed and hit this issue, add this line
  to the top of your crontab manually (`crontab -e`):
  `PATH=/home/<you>/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`

---

## [1.1.3] - 2026-03-09

### Changed
- `digest-agent.sh` and `deliver.sh` rewritten for clarity and compactness —
  same behaviour, less code. Single-letter internal helpers, config reads
  collapsed to one line each, mechanical fallback simplified.
- `deliver.sh` Telegram payload now has `parse_mode: Markdown` baked in —
  header `*pulse bOard Digest*` renders bold; LLM body stays plain text.
- LLM prompt tightened: explicit instruction against asterisks, backticks,
  underscores, and all Markdown.

---

## [1.1.2] - 2026-03-09

### Fixed
- `deliver.sh` Telegram payload no longer includes `parse_mode: Markdown` —
  LLM-composed text containing backticks or asterisks was causing Telegram to
  return a 400 parse error. Digests now deliver as plain text.
- `digest-agent.sh` prompt updated to request plain text output from the agent
  instead of Telegram Markdown, preventing the agent from generating formatting
  characters that would trigger Telegram parse errors.

---

## [1.1.1] - 2026-03-09

### Fixed
- **Bug:** `deliver.sh` was overwriting `last-digest.md` (the raw log) with the
  composed/delivered message on every run. Raw log is now preserved in
  `last-digest.md` permanently. The composed message is written to a new
  separate file: `last-delivered.md`. These two files are now always distinct.
- `digest-agent.sh` delivery failure message updated to reference both files correctly.
- `pulse.yaml` `paths.last_digest` now correctly describes the raw log file.

### Added
- **Privacy disclosure:** `SKILL.md`, `install.sh` Step 7, and `_meta.json` now
  explicitly warn that when LLM composition is enabled, the raw `pending.log`
  is included in the prompt sent to the configured OpenClaw agent. If that agent
  uses a remote/cloud LLM provider, log content will be transmitted off-host.
  Users are advised to use a local-only agent (Ollama) if log privacy is required.
- `_meta.json` now includes a `privacy` section declaring both the LLM
  transmission risk and the caveat that pulse bOard cannot prevent plugged jobs
  from writing secrets into their outputs.
- `digest-agent.sh` inline comment notes the privacy implication before the
  agent call.

### Changed
- `deliver.sh` audit trail section rewritten — writes to `last-delivered.md`
  only, with explicit comment that `last-digest.md` is never touched.
- `SKILL.md` filesystem table updated to show both `last-digest.md` and
  `last-delivered.md` with correct descriptions.
- `SKILL.md` "Reviewing the raw log" section expanded into a full "Log files"
  section with a privacy warning block.

---

## [1.1.0] - 2026-03-09

### Added
- `digest-agent.sh` now composes human-readable digests via `openclaw agent`:
  - Opening verdict sentence (overall system health, casual but factual)
  - One bullet per skill — what ran, how many times, outcome
  - Errors and warnings expanded with relevant log lines
  - Mechanical status line (✅/⚠️ counts) always prepended — reliable regardless of LLM
- Full raw log always written to `~/.pulse-board/logs/last-digest.md` for on-demand review
- `pulse.yaml` new fields: `digest.llm_agent` (default: `main`) and `digest.llm_timeout` (default: 60s)
- `install.sh` Step 7: prompts for digest agent ID (lists available agents) and timeout
- Graceful fallback to mechanical format if `openclaw` is not in PATH, agent call fails, or times out

### Changed
- `install.sh` step count updated from 6 to 7
- `SKILL.md` updated to document raw log availability and agent digest flow

### Design notes
- Agent is called via `openclaw agent --agent <id> --message <prompt> --json`
- Raw log is passed as context in the prompt — never sent externally
- Delivered Telegram/Discord message contains only the LLM summary, not the raw log
- Raw log accessible on demand via `last-digest.md` or by asking your agent

---

## [1.0.5] - 2026-03-09

### Fixed / Security
- `install.sh` secrets env patch is now **explicit opt-in**: the installer
  shows exactly which keys are missing and why, then asks for confirmation
  before appending anything. Nothing is written to the secrets env file
  silently.
- `install.sh` crontab change is now **announced before it happens**: the
  installer prints the exact entries it will add and asks for confirmation.
- `plug.sh` `wrap_cmd` now carries an explicit comment explaining that the
  secrets env is sourced in the cron shell context only — it is never read,
  parsed, logged, or transmitted by `plug.sh` itself.
- `_meta.json` now fully declares `requires.binaries`, `requires.env_vars`,
  `filesystem.creates/reads/modifies`, `network.external_endpoints`, and
  `credentials` — eliminating the metadata/behavior mismatch flagged by the
  OpenClaw security scanner.
- `SKILL.md` now includes a full **"What this skill touches"** section
  (filesystem, crontab, secrets env, network, credentials) so human review
  matches scanner expectations before installation.

### Changed
- No behavioral changes — all logic is identical to 1.0.4. This release is
  purely transparency and consent improvements.

---

## [1.0.4] - 2026-03-09

### Fixed
- `plug.sh` cron tag colon-escaping bug: shell echo was silently dropping the
  colon in `# pulse-board:<skill>` tags, breaking `unplug.sh` discovery and
  producing duplicate cron entries on re-run. All crontab writes now go through
  `python3 subprocess` to bypass shell escaping entirely.
- `install.sh` step counter: steps 4 and 5 were both labelled `[ 4 / 5 ]`.
  Steps renumbered correctly as 1–6 with the new workspace step added.

### Added
- `install.sh` now adds a **Step 6: OpenClaw workspace** prompt and writes
  `openclaw_workspace` to `pulse.yaml`.
- `install.sh` post-install **secrets env patch**: automatically appends
  `LLM_API_KEY=ollama` and `OPENCLAW_WORKSPACE=<path>` to the secrets env file
  if those keys are absent.
- `install.sh` digest cron jobs now written via `python3 subprocess`.

### Changed
- `install.sh` step count updated from 5 to 6.

---

## [1.0.3] - 2026-03-08

### Added
- `plug.sh` discovery mode: scan crontab and OpenClaw `jobs.json`, merge,
  deduplicate, present numbered menu
- `install.sh` asks for OpenClaw cron directory, writes to `pulse.yaml`
- `plug.sh` auto-skips pure `agentTurn` jobs and already-plugged jobs
- Manual flag mode (`--skill`, `--cron`, `--cmd`) still works

---

## [1.0.2] - 2026-03-08

Complete redesign. Setup goes from ~15 terminal operations to 2.

### Added
- `install.sh` — interactive installer
- `plug.sh` — register + wire cron in one command
- `unplug.sh` — remove skill + cron in one command

### Removed
- `setup.sh`, `register.sh`, `unregister.sh`, `templates/`, `docs/`

---

## [1.0.1] - 2026-03-08

### Fixed
- Flat script structure, `SKILL_DIR` resolution, `digest-agent.sh` paths

---

## [1.0.0] - 2026-03-08

Initial release.
