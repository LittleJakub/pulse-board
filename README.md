# 📋 Pulse Board

**Your agent stack's operational heartbeat. Every cron job. One digest.**

You've got a bunch of skills running on a schedule — backing things up, watching VPNs, consolidating memory, doing whatever weird automation you've cooked up. And you have absolutely no idea if any of them actually ran today. Did the backup finish? Did the observer fire? Who knows! It's fine. Probably fine.

Pulse Board fixes that. Every scheduled skill logs a one-liner when it runs. Twice a day, an LLM reads those lines and writes you a friendly human summary. You get a message that tells you what happened, what didn't, and what exploded — without having to SSH in and grep through logs like an animal.

---

## How it works

```
your skill runs
  → log-append.sh writes one line to pending.log
  → digest-agent.sh fires twice daily
      reads pending.log
      saves full raw log to last-digest.md
      asks your OpenClaw agent to write a human summary
        (falls back to mechanical format if the agent is unavailable)
      delivers to Telegram / Discord / Feishu / log file
      clears pending.log
      prunes old detail logs
```

That's it. No daemon. No database. No magic. Just cron, bash, and a sprinkle of LLM.

---

## What you get

```
📋 Pulse Board Digest — 2026-03-15 05:00 CST
✅ 12 ok · 0 skipped · 0 warnings · 0 errors

All systems ran cleanly overnight. Total Recall observed 4 sessions,
the reflector consolidated once, and healthy-backup completed at 05:00
without complaint. Dream cycle ran at 03:00 and processed 7 observations.

• total-recall — ran 12x, all OK
• total-recall-reflector — ran 4x, all OK
• total-recall-dream — ran 1x, OK
• healthy-backup — ran 1x, OK
• daily-brief — ran 1x, OK
```

If something breaks, the relevant log lines show up in the digest so you know exactly what went wrong without hunting for it.

---

## Requirements

- bash 4+, curl, python3 — standard on any modern Linux or macOS
- [OpenClaw](https://openclaw.ai) with at least one configured agent
- One of: Telegram bot, Discord webhook, Feishu app, or log-to-file

No sudo. No root. No system-level writes outside `~/.pulse-board/`.

---

## Install

```bash
# Download the latest release and extract into your OpenClaw skills directory
tar -xzf pulse-board-1.1.9.tar.gz --strip-components=1 \
  -C ~/.openclaw/skills/pulse-board/

chmod +x ~/.openclaw/skills/pulse-board/*.sh
bash ~/.openclaw/skills/pulse-board/install.sh
```

The installer walks you through everything:
- Timezone
- Delivery channel (Telegram / Discord / Feishu / log file)
- Digest schedule (morning + evening hours, default 05:00 / 17:00)
- OpenClaw workspace path
- Which agent to use for digest composition
- Whether to patch your secrets env file (explicit opt-in, nothing silent)

It will show you exactly what it's about to write to your crontab before touching anything.

---

## Delivery channels

### Telegram
Standard bot API. Supports forum group threads via `message_thread_id`.

```yaml
delivery:
  channel: telegram
  telegram:
    enabled:   true
    bot_token: "your-bot-token"
    chat_id:   "-100xxxxxxxxxx"
    thread_id: "6"   # optional — forum topic ID
```

### Discord
Webhook delivery.

```yaml
delivery:
  channel: discord
  discord:
    enabled:     true
    webhook_url: "https://discord.com/api/webhooks/..."
```

### Feishu
App-based delivery using tenant access token. Supports group chat and thread delivery.

```yaml
delivery:
  channel: feishu
  feishu:
    enabled:    true
    app_id:     "cli_xxxxxxxxxx"
    app_secret: "your-app-secret"
    chat_id:    "oc_xxxxxxxxxx"    # group chat ID
    thread_id:  "om_xxxxxxxxxx"    # optional — root message ID of target thread
```

> ⚠️ **Feishu thread note:** `thread_id` must be the **root message ID** (`om_xxx`) of the thread — not the thread ID (`omt_xxx`). To find it, fetch messages from the thread via the Feishu API (`GET /im/v1/messages?container_id_type=thread&container_id=omt_xxx`) and grab the first `message_id`.

### Log file only
No external delivery — digest is written to `~/.pulse-board/logs/last-delivered.md` only.

```yaml
delivery:
  channel: log
```

---

## Plug in a skill

Once Pulse Board is installed, wire up your skills one by one:

```bash
bash ~/.openclaw/skills/pulse-board/plug.sh \
  --skill total-recall \
  --cron "*/15 * * * *" \
  --cmd "bash ~/.openclaw/skills/total-recall/scripts/observer-agent.sh"
```

That's all. Pulse Board wraps the command, wires the cron entry, and starts collecting outcomes automatically.

Run `plug.sh` with no arguments for an interactive discovery mode.

> ⚠️ **Total Recall dream cycle note:** `dream-cycle.sh` is a file operations helper called *by* the agent — not a standalone runner. Wire the dream cycle as a full agent turn instead:
> ```bash
> bash ~/.openclaw/skills/pulse-board/plug.sh \
>   --skill total-recall-dream \
>   --cron "0 3 * * *" \
>   --cmd "openclaw agent --agent main --timeout 1800 --message \"Run the Total Recall Dream Cycle. Follow the instructions in ~/.openclaw/workspace/skills/total-recall/prompts/dream-cycle-prompt.md exactly. Use READ_ONLY_MODE=false and DREAM_PHASE=1.\" --json"
> ```

---

## Remove a skill

```bash
bash ~/.openclaw/skills/pulse-board/unplug.sh --skill total-recall
```

Removes the cron entry and registry file. Clean.

---

## Test it

```bash
bash ~/.openclaw/skills/pulse-board/log-append.sh \
  --skill test --status OK --message "Hello Pulse Board"

bash ~/.openclaw/skills/pulse-board/digest-agent.sh
```

Check your configured delivery channel. You should get a digest within a few seconds.

---

## Log files

After every digest run, two files are written:

| File | Contains |
|------|----------|
| `~/.pulse-board/logs/last-digest.md` | Full raw log from `pending.log` — always preserved |
| `~/.pulse-board/logs/last-delivered.md` | The exact message that was sent to your channel |

Want to review last night's raw log? Ask your agent: *"show me the last digest log"* and it'll read `last-digest.md` on demand.

---

## Privacy note

When LLM digest composition is enabled, the full `pending.log` is included in the prompt sent to your configured OpenClaw agent. If that agent uses a remote/cloud LLM provider, your log content will leave the host.

If that's a concern:
- Point the digest agent at a local-only model (e.g. Ollama) in `pulse.yaml` → `digest.llm_agent`
- Or just disable LLM composition — the mechanical fallback is perfectly readable

Also worth knowing: Pulse Board cannot prevent plugged cron jobs from writing secrets into their stdout/stderr. Make sure your jobs don't echo credentials into their outputs.

---

## Files

| File | Purpose |
|------|---------|
| `install.sh` | One-time interactive setup |
| `plug.sh` | Register a skill and wire its cron entry |
| `unplug.sh` | Remove a skill and its cron entry |
| `log-append.sh` | Called by skill cron wrappers to record outcomes |
| `digest-agent.sh` | Runs on schedule — composes and delivers the digest |
| `deliver.sh` | Internal delivery handler (Telegram / Discord / Feishu / log) |

---

## Updating

```bash
cd ~/.openclaw/skills/pulse-board
git pull
chmod +x *.sh
```

Your `~/.pulse-board/config/pulse.yaml` is never touched by updates — config lives outside the skill directory and is yours to keep.

---

## Wipe and reinstall

Sometimes you just want a clean slate:

```bash
crontab -l | grep -v "pulse-board" | crontab -
rm -rf ~/.pulse-board ~/.openclaw/skills/pulse-board/*
tar -xzf pulse-board-X.Y.Z.tar.gz --strip-components=1 \
  -C ~/.openclaw/skills/pulse-board/
chmod +x ~/.openclaw/skills/pulse-board/*.sh
bash ~/.openclaw/skills/pulse-board/install.sh
```

---

## Part of the hiVe stack

Pulse Board was built as part of [hiVe](https://github.com/LittleJakub) — a personal multi-agent system running on OpenClaw. It's designed to be lightweight, composable, and easy to drop into any OpenClaw setup without getting in the way of everything else.

If you're running your own agent stack and want operational visibility without babysitting your crontab, this is for you.

---

## License

MIT. Do whatever you want with it. If it saves your bacon, a ⭐ is always appreciated.
