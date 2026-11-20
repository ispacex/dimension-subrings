# boinc-fetcher — collect finished BOINC Central batches on kimmy (MATH-492)

A batch on BOINC Central can finish while no agent is running (batch 194 did, on 2026-11-19).
`fetcher.py` runs on kimmy every 30 minutes, downloads the output of finished batches into a
persistent directory, checks it, and reports problems by Telegram and/or a comment on the
tracker issue of the batch.

**Read-only towards BOINC.** The only requests it sends are the RPCs `query_batches` /
`query_batch` (anything else is refused in code, `ALLOWED_RPCS`) and the batch tar download
`get_output3.php?action=get_batch_tar`. It never retires, aborts or deletes anything: that is a
human decision. (Note: retiring a batch on BOINC deletes its output, so retire only after the
fetcher reports the batch downloaded.)

Python 3.9+ standard library only; it reuses the protocol of the `boinc-central` MCP server
(`ispacex/boinc-central-mcp`, `client.py`).

## What one run does

1. `query_batches`. If BOINC cannot be queried for `boinc_fail_alert_hours` (3 h) → alert.
2. For every watched batch — each batch in the registry, and (with `download_unregistered`) any
   batch with `id >= min_batch_id`:
   - **complete, not yet downloaded** → GET the tar. The server announces its size
     (`Content-Length`, from `tar --totals`) before the body; if free space under `results_dir`
     is less than that size (×2 with `extract`) + `min_free_gb`, the response is closed unread,
     a **low-disk** alert goes out and the batch is tried again next run. Otherwise the tar is
     streamed to `batch_<id>.tar.part`, its length checked, renamed, and **verified**: it must
     open and read to the end (every member's data read), hold at least one non-empty file; its
     sha256, number of files, empty files and number of distinct jobs
     (`…__job_<name>__file_…`) are recorded in `manifest.json` next to it and compared with
     `njobs - nerror_jobs` (fewer files → a warning in the notification). Then the
     **complete** notification (path, size, files, error jobs), and the registry's
     `post_collect` command if any.
   - download or verification failure → alert, retry with backoff (30 min, doubling, at most
     12 h); after `max_attempts` (10) it gives up and says so (`fetcher.py --retry ID` resets).
     A failed archive is kept as `batch_<id>.tar.bad-<time>` for inspection.
   - **error jobs** above `error_fraction_threshold` (5%, per batch overridable) → alert
     (again when the count doubles or after `realert_hours`).
   - **running long**: still `init`/`in_progress` after `expected_hours` × 1.5 (registry, or
     `default_expected_hours` = 120) → alert, repeated daily.
   - registry batch **aborted**, or **not listed** at all (retired / wrong id) and never
     downloaded → alert.
3. Free space under `results_dir` below `min_free_gb` → **low-disk** alert (every 6 h while it
   lasts). kimmy's disk has filled before (GAP `gaptempdir*`; the hourly `gap-tmp-clean` cron
   handles those and is not touched by this service).
4. **Heartbeat**: the first run after `heartbeat_hour_utc` (06 UTC) each day sends one
   "alive" line (last good BOINC poll, free space, the batches it knows). If that line does
   not arrive one morning, the service (or kimmy) is down. Optionally `heartbeat_url` is
   fetched after every successful poll — point it at a dead-man's-switch service
   (e.g. healthchecks.io) to get an alert from outside when the pings stop.

Undelivered notifications stay in the state file's outbox and are retried on the next runs (up to
two days).

## Where things are on kimmy

Runs as user **leancheck** (the user tm jobs run as) from a **system** systemd unit with
`User=leancheck` (leancheck has no lingering user systemd):

| What | Path |
|---|---|
| code | `/home/leancheck/boinc-fetcher/` (`fetcher.py`, this README) |
| units | `/etc/systemd/system/boinc-fetcher.service`, `boinc-fetcher.timer` (`*:07,37`) |
| config | `/home/leancheck/.config/boinc-fetcher/config.json` |
| registry | `/home/leancheck/.config/boinc-fetcher/registry.json` |
| secrets (600, dir 700) | `/home/leancheck/.config/boinc-fetcher/secrets/` `boinc-authenticator`, `telegram-bot-token`, `tracker-token` |
| state, lock | `/home/leancheck/.local/state/boinc-fetcher/state.json` |
| results | `/home/leancheck/boinc-results/<batch_id>/batch_<id>.tar`, `manifest.json` (+ `files/` with `extract`, `post_collect.log`) |
| log | `journalctl -u boinc-fetcher` |

## Install / update

From the Mac, in this directory:

```sh
./deploy.sh            # = ./deploy.sh root@157.22.134.209
```

It copies the code to `/home/leancheck/boinc-fetcher/` and runs `install.sh` as root there:
creates the directories, installs `config.example.json` / `registry.example.json` as config and
registry **only if they do not exist yet**, installs and enables the timer. Then put the secrets
(never through the terminal output; each file mode 600, owner leancheck):

```sh
# BOINC Central account key (the same file the boinc-central MCP server reads on the Mac)
ssh root@157.22.134.209 'umask 077; cat > /home/leancheck/.config/boinc-fetcher/secrets/boinc-authenticator; chown leancheck: /home/leancheck/.config/boinc-fetcher/secrets/boinc-authenticator' \
  < ~/.config/boinc-central/authenticator
```

The Telegram bot token (bot @math_tasks_tmless_bot, credential 21 on MATH-75) goes to
`secrets/telegram-bot-token` the same way.

Useful commands on kimmy (as leancheck: `sudo -u leancheck …` or `runuser -u leancheck --`):

```sh
python3 ~/boinc-fetcher/fetcher.py --status          # state file
python3 ~/boinc-fetcher/fetcher.py --dry-run         # query and check, no download, nothing sent
python3 ~/boinc-fetcher/fetcher.py --test-notify     # a test line through the enabled channels
python3 ~/boinc-fetcher/fetcher.py --min-free-gb 100000 --dry-run   # see the low-disk path
python3 ~/boinc-fetcher/fetcher.py --retry 194       # forget failures (and a done download) of 194
systemctl start boinc-fetcher                        # a run now (as root)
```

## Adding a batch to the registry

Edit `/home/leancheck/.config/boinc-fetcher/registry.json` on kimmy (keys are batch ids as
strings):

```json
{"batches": {
  "194": {"issue": "MATH-478", "note": "ds473 case473 s=6 + case472 s=5"},
  "201": {"issue": "MATH-500", "expected_hours": 48, "error_fraction_threshold": 0.02,
          "post_collect": "tar -xf \"$BATCH_TAR\" -C \"$BATCH_DIR\" --one-top-level=files"}
}}
```

- `issue` — tracker issue that gets the batch's notifications as comments (when the tracker
  channel is on) and is named in Telegram messages.
- `expected_hours` — for the "running long" alert (alert after ×`long_running_factor`).
- `error_fraction_threshold` — overrides the global one.
- `post_collect` — shell command run once after a verified download, in the batch directory,
  with `BATCH_ID`, `BATCH_DIR`, `BATCH_TAR`, `BATCH_ISSUE` in the environment; output to
  `post_collect.log`, exit code reported. Keep it light — kimmy is the tm runner.

A batch that is not in the registry is still downloaded if `download_unregistered` is on and its
id is at least `min_batch_id` (194: the older batches 97 and 100 were collected by hand); its
notifications go to Telegram only.

## Notification channels

- **Telegram** (`telegram.enabled`, `chat_id`): the bot @math_tasks_tmless_bot. A bot can
  write to a person only after that person has pressed *Start* in a chat with the bot (or
  allowed it on the login widget). `chat_id` 634017 is the user allowed into
  task.math.tmless.org (MATH-75).
- **Tracker comment** (`tracker.enabled`, `base_url`, `events`): `POST
  {base_url}/rest/api/2/issue/<issue>/comment` with `Authorization: Bearer <token>` (the
  tracker's compatible API), token in `secrets/tracker-token`. Off until a token for this
  service exists. The heartbeat and disk alerts that belong to no batch go to Telegram only.

## Tests

```sh
python3 -m unittest boinc/fetcher/test_fetcher.py
```

A fake BOINC server on localhost: download and verification once, low disk skips the download,
truncated download and backoff, corrupt archive, error-fraction and running-long alerts, the
read-only guard, secret scrubbing, daily heartbeat, outbox retry. Nothing talks to BOINC.
