# 📋 Pulse Board

**Your agent stack's operational heartbeat. Every cron job. One digest.**

You've got a bunch of skills running on a schedule — backing things up, watching VPNs, consolidating memory, doing whatever weird automation you've cooked up. And you have absolutely no idea if any of them actually ran today. Did the backup finish? Did the observer fire? Who knows! It's fine. Probably fine.

Pulse Board fixes that. Every scheduled skill logs a one-liner when it runs. Twice a day, an LLM reads those lines and writes you a friendly human summary. You get a Telegram (or Discord) message that tells you what happened, what didn't, and what exploded — without you having to SSH in and grep through logs like an animal.

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
      delivers to Telegram / Discord / log file
      clears pending.log
      prunes old detail logs
```

That's it. No daemon. No database. No magic. Just cron, bash, and a sprinkle of LLM.

---

## What you get in Telegram

```
📋 Pulse Board Digest — 2026-03-09 18:00 CST
✅ 4 ok · 0 skipped · 0 warnings · 0 errors

All systems ran cleanly this afternoon. Total Recall observed 3 sessions,
the reflector had nothing to consolidate, and healthy-backup completed at
05:00 without complaint.

• total-recall — ran 8x, all OK
• total-recall-reflector — ran 1x, OK
• total-recall-dream — ran 1x, OK
• healthy-backup — ran 1x, OK
```

If something breaks, the relevant log lines show up in the digest so you know exactly what went wrong without hunting for it.

---

## Requirements

- bash 4+, curl, python3 — standard on any modern Linux or macOS
- [OpenClaw](https://openclaw.ai) with at least one configured agent
- A Telegram bot token + chat ID, a Discord webhook, or just log-to-file if you want to keep it simple

No sudo. No root. No system-level writes outside `~/.pulse-board/`.

---

## Install

```bash
# Download the latest release and extract into your OpenClaw skills directory
tar -xzf pulse-board-1.1.3.tar.gz --strip-components=1 \
  -C ~/.openclaw/skills/pulse-board/

chmod +x ~/.openclaw/skills/pulse-board/*.sh
bash ~/.openclaw/skills/pulse-board/install.sh
```

The installer is interactive and walks you through everything:
- Timezone
- Delivery channel (Telegram / Discord / log file)
- Digest schedule (morning + evening hours)
- OpenClaw workspace path
- Which agent to use for digest composition
- Whether to patch your secrets env file (explicit opt-in, nothing silent)

It will show you exactly what it's about to write to your crontab and ask for confirmation before touching anything.

---

## Plug in a skill

Once Pulse Board is installed, you wire up your skills one by one:

```bash
bash ~/.openclaw/skills/pulse-board/plug.sh \
  --skill total-recall \
  --cron "*/15 * * * *" \
  --cmd "bash ~/.openclaw/skills/total-recall/scripts/observer-agent.sh"
```

That's all. Pulse Board wraps the command, wires the cron entry, and starts collecting outcomes automatically.

Run `plug.sh` with no arguments for an interactive discovery mode — it'll scan your existing crontab and OpenClaw jobs and let you pick which ones to wire up.

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
- Or set `digest.llm_agent` to an agent backed by a local model
- Or just don't enable LLM composition — the mechanical fallback is perfectly readable

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
| `deliver.sh` | Internal delivery handler (Telegram / Discord / log) |

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
