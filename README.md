# Codex Multi-Agent Configuration

Codex의 기본 custom agent 기능만으로 구성한 가성비 중심 multi-agent 설정입니다. 별도 scheduler, daemon, queue, state database, orchestration wrapper는 사용하지 않습니다.

## 요구 사항

- Codex CLI 0.150.1 이상 권장
- Git
- Windows PowerShell 또는 POSIX shell

```powershell
codex --version
```

## 구성

```text
AGENTS.md
install-global.ps1
install-global.sh
.codex/
├── config.toml
└── agents/
    ├── architect.toml
    ├── planner.toml
    ├── implementer.toml
    ├── tester.toml
    ├── reviewer.toml
    ├── material-scientist.toml
    ├── luna-worker-light.toml
    ├── luna-worker-medium.toml
    └── luna-worker-high.toml
```

## Agent 구성

| Agent | Model / Reasoning | Sandbox | 용도 |
|---|---|---|---|
| `architect` | Terra high | read-only | 구조, 경계, API, 의존성 |
| `planner` | Terra medium | read-only | 구현 순서, 파일 범위, 분할, 검증 계획 |
| `implementer` | Terra high | workspace-write | 승인된 구현과 관련 테스트 |
| `tester` | Luna medium | workspace-write | test, build, lint, type check, regression |
| `reviewer` | Terra high | read-only | 독립적인 정확성·보안·호환성 검토 |
| `material-scientist` | Terra high | read-only | glass, ceramic, battery 도메인 판단 |
| `luna-worker-light` | Luna low | read-only | 검색, 요약, inventory, 단순 분석 |
| `luna-worker-medium` | Luna medium | workspace-write | 제한된 수정, 기계적 변경, 작은 refactor |
| `luna-worker-high` | Luna high | workspace-write | 어렵지만 명확히 제한된 독립 작업 |

Main Codex는 `gpt-5.6-terra`와 `high` reasoning을 사용합니다. 이름이 지정되지 않은 subagent의 기본값은 `gpt-5.6-luna`와 `medium` reasoning입니다.

## Delegation 원칙

Main Codex만 subagent를 호출하고 결과를 통합합니다. Subagent는 다른 subagent를 호출하거나 직접 통신하지 않습니다. 필요한 agent만 사용하고, 서로 겹치는 파일을 수정하는 write agent를 동시에 실행하지 않습니다.

```text
단순 bug fix
Main -> implementer -> tester -> reviewer

일반 feature
Main -> architect -> planner -> implementer -> tester -> reviewer

재료 도메인 feature
Main -> material-scientist -> architect -> planner -> implementer -> tester -> reviewer

범용 작업
Main -> 적절한 luna-worker 단계
```

## 프로젝트 범위 설치

저장소의 `AGENTS.md`와 `.codex/`를 대상 프로젝트 root에 복사합니다. Codex가 해당 프로젝트를 신뢰해야 project-scoped 설정을 읽습니다.

## 개인 전역 설치

먼저 저장소를 clone합니다.

```sh
git clone https://github.com/InKyu0317/inq-codex-multi-agents.git
cd inq-codex-multi-agents
```

### Windows

```powershell
.\install-global.ps1 -WhatIf
.\install-global.ps1
```

옵션:

- `-TargetCodexHome <path>`
- `-MaxConcurrentThreads <1..64>` — 기본값 4
- `-WhatIf`

### macOS/Linux

```sh
sh ./install-global.sh --what-if
sh ./install-global.sh
```

옵션:

- `--target-codex-home PATH`
- `--max-concurrent-threads N` — 기본값 4
- `--what-if`
- `--help`

설치 스크립트는 다음 항목만 관리합니다.

- `AGENTS.md`의 marker block 병합
- `config.toml`의 Main model/reasoning과 `[agents]` 기본값 병합
- 9개 custom agent TOML 설치
- 이전 버전의 advisor/researcher/언어별 expert/glass-scientist 파일을 백업한 뒤 활성 폴더에서 제거

교체되거나 제거되는 파일은 다음 위치에 먼저 백업됩니다.

```text
~/.codex/backups/inq-codex-multi-agents/<timestamp>/
```

다른 프로젝트 신뢰, plugin, MCP, desktop, 인증 설정은 덮어쓰지 않습니다. `AGENTS.override.md`가 있으면 더 높은 우선순위를 가지므로 설치 스크립트가 경고합니다.

설치되는 핵심 설정:

```toml
model = "gpt-5.6-terra"
model_reasoning_effort = "high"

[agents]
max_concurrent_threads_per_session = 4
default_subagent_model = "gpt-5.6-luna"
default_subagent_reasoning_effort = "medium"
```

## 안전성

- 분석 역할은 `read-only`입니다.
- 구현·테스트 및 Luna medium/high worker만 `workspace-write`입니다.
- 부모 session에서 선택한 live permission이 agent 파일의 기본값보다 우선할 수 있습니다.
- installer는 PATH, 인증 정보, Codex 설치 파일을 변경하지 않습니다.
- legacy agent를 제거하기 전에 반드시 backup합니다.

## 검증

```powershell
codex doctor --summary
codex --strict-config app-server --stdio
```

새 Codex session에서 custom agent 목록이 9개인지 확인합니다. 설치 스크립트 변경 시에는 빈 대상과 이전 12개 구성이 있는 대상 모두에서 `WhatIf`와 실제 설치를 검사해야 합니다.

## License

MIT
