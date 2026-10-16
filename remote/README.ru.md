English version: [README.md](README.md).

# remote/ — долгие вычисления на удалённой машине

Перебор групп, решётки, сборки Lean идут часами. Их можно отправить фоновыми задачами на любую
Linux-машину с systemd и доступом по ssh («раннер»):

| Файл | Что |
|---|---|
| `ds-remote.sh` | `submit`, `status`, `log`, `fetch`, `cancel` — рабочее дерево как есть уезжает на машину и идёт там юнитом systemd |
| `setup-box.sh` | разовая подготовка машины: `uv`, а с `--gap` — копия установки GAP (GAP 4.15 с SmallGroups, anupq, io) |
| `py-env.sh` | окружение Python для задачи (`source remote/py-env.sh`), venv по хешу `requirements-py.txt` |

Настройка — только переменными окружения; хоста по умолчанию нет:

```bash
export DS_REMOTE_HOST=root@runner.example.org   # куда ssh; должен уметь systemd-run
export DS_REMOTE_USER=jobs                      # непривилегированный пользователь задач
# по желанию: DS_REMOTE_ROOT (по умолчанию /home/$DS_REMOTE_USER/ds-jobs), DS_REMOTE_SSH,
#             DS_REMOTE_UNIT (префикс имён юнитов, по умолчанию ds-), DS_REMOTE_GAP_SRC (для setup-box.sh --gap)
```

Задача идёт с nice 15 и idle-приоритетом ввода-вывода; `--cpus` и `--mem` ограничивают её
сильнее — на общей машине это стоит делать.

```bash
remote/setup-box.sh --gap                  # один раз: uv и GAP в $DS_REMOTE_ROOT/cache

remote/ds-remote.sh submit --name g64 --cpus 0-3 --mem 8G -- \
  'source remote/py-env.sh && cd compute && GAP=gap ./run_export.sh 64 1 267 all "$JOB_OUT/g64.jsonl" && python run.py "$JOB_OUT/g64.jsonl" "$JOB_OUT/A64.jsonl" --jobs 3'
remote/ds-remote.sh status               # все задачи: RUNNING / DONE / FAILED (exit N) / LOST
remote/ds-remote.sh status ID            # одна задача и хвост её лога
remote/ds-remote.sh log ID 100
remote/ds-remote.sh fetch ID             # out/, log, meta, exit → remote-results/ID/
remote/ds-remote.sh cancel ID
```

- Уезжают все файлы, которые отслеживает git, **с незакоммиченными правками** (и подмодули).
  Файл вне индекса не уезжает: скрипт называет такие файлы до отправки; `git add` их или
  передай `--untracked`.
- В `meta` записываются коммит и то, было ли дерево грязным.
- В задаче доступны `$JOB_OUT` (результаты, их забирает `fetch`), `$JOB_ROOT`, `$JOB_CACHE`
  (общий кэш: `uv`, venv по хешу `requirements-py.txt`, `gap`). `gap` и `uv` — в `PATH`.
  `TMPDIR` — `$JOB_ROOT/tmp`: один вызов `PqDescendants` может написать гигабайты.
- Python: `source remote/py-env.sh` (окружение делает `uv`, так что хватит системного `python3`
  без `ensurepip`).
- Коды выхода: `0` — всё хорошо; `1` — задача упала или (у `fetch`) ещё не кончилась; `2` —
  ничего не запускалось.
