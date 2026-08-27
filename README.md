# Codex CLI Multi-Agent Configuration

Codex CLI의 기본 기능만으로 구성한 multi-agent 설정입니다. 프로젝트 범위로 쓰거나 `~/.codex`에 개인 기본값으로 설치할 수 있습니다. 별도 Python, Node.js, shell orchestration framework를 만들지 않고 `AGENTS.md`, `.codex/agents/`, custom subagent, sandbox, permission, model, reasoning 설정을 사용합니다.

## 준비 사항

### Windows

PowerShell에서 Git, Node.js LTS, Codex CLI를 설치합니다.

```powershell
winget install --id Git.Git --exact
winget install --id OpenJS.NodeJS.LTS --exact
npm install -g npm@latest
npm install -g @openai/codex@latest
```

### macOS

[Homebrew](https://brew.sh/)가 설치된 Terminal에서 Git, Node.js, Codex CLI를 설치합니다.

```sh
brew install git
brew install node
npm install -g npm@latest
npm install -g @openai/codex@latest
```

설치 후 Windows와 macOS 모두 `codex --version`으로 Codex CLI가 실행되는지 확인합니다.

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
    ├── advisor.toml
    ├── researcher.toml
    ├── implementer.toml
    ├── tester.toml
    ├── reviewer.toml
    ├── frontend-expert.toml
    ├── python-expert.toml
    ├── csharp-expert.toml
    ├── rust-expert.toml
    └── glass-scientist.toml
```

`AGENTS.md`는 공통 workflow와 안전 규칙을, 각 TOML은 한 agent의 역할·모델·추론 수준·sandbox를 정의합니다. `AGENTS.md`를 프로젝트 root에 두면 해당 프로젝트에만, `~/.codex/AGENTS.md`로 두면 모든 프로젝트에 개인 기본값으로 적용됩니다.

## 12개 Agent

| 구분 | Agent | 역할 | Sandbox |
|---|---|---|---|
| Architecture | architect | 시스템 구조, 모듈 경계, API, 의존성 방향 | read-only |
| Architecture | planner | 구현 단계, 파일 범위, 의존성, 검증 계획 | read-only |
| Architecture | advisor | 기술 선택지, trade-off, 위험, 권고 | read-only |
| Workflow | researcher | 외부 기술·문서·표준·호환성 조사 | read-only |
| Workflow | implementer | 승인된 기능·수정·리팩터링 구현 | workspace-write |
| Workflow | tester | 테스트, build, lint, type check, regression 검증 | workspace-write |
| Workflow | reviewer | 독립적 정확성·보안·호환성 검토 | read-only |
| Expert | frontend-expert | JS/TS, React, Next.js, Vite, UI/접근성/성능 | read-only |
| Expert | python-expert | Python, scientific computing, FastAPI, async, testing | read-only |
| Expert | csharp-expert | C#/.NET, Windows, desktop, 산업용 architecture | read-only |
| Expert | rust-expert | Rust, ownership, concurrency, FFI, performance | read-only |
| Expert | glass-scientist | Glass/Ceramic/Materials, 결함·측정·검사 도메인 | read-only |

`explorer`와 `vision-specialist`는 현재 기본 구성에 포함하지 않습니다.

## Delegation 원칙

Main Codex가 유일한 coordinator이며, **오직 Main Codex만 subagent를 호출**합니다. Subagent는 다른 subagent를 호출하거나 작업을 넘기지 않으며, 서로 직접 통신하지 않고 결과를 Main Codex에만 반환합니다. 전문 agent의 권고를 implementer에 전달하고 실행 여부를 결정하는 역할도 Main Codex가 담당합니다.

```text
Main Codex -> Sub-agent
```

필요한 agent만 선택적으로 사용합니다. 단순한 작업에 모든 agent를 호출하지 않으며, recursive delegation을 만들지 않습니다.

## 기본 Workflow

```text
단순 bug fix
Main -> implementer -> tester -> reviewer

일반 feature
Main -> architect -> planner -> implementer -> tester -> reviewer

기술 판단이 필요한 feature
Main -> advisor -> architect -> planner -> implementer -> tester -> reviewer

외부 조사가 필요한 feature
Main -> researcher -> architect -> planner -> implementer -> tester -> reviewer

특정 기술 또는 도메인이 핵심인 feature
Main -> relevant expert -> architect -> planner -> implementer -> tester -> reviewer
```

복합 작업에서는 Main Codex가 여러 specialist를 병렬로 직접 호출할 수 있습니다. 각 결과를 Main Codex가 취합한 뒤 다음 단계를 결정합니다.

## 설치

Codex CLI가 설치된 환경에서 이 저장소를 대상 프로젝트 root에 두거나, 필요한 파일을 대상 프로젝트에 복사합니다.

```sh
git clone https://github.com/InKyu0317/inq-codex-multi-agents.git
```

### 프로젝트 범위 설치

다음 항목을 대상 프로젝트 root에 복사합니다.

```text
AGENTS.md
.codex/
```

Codex는 프로젝트를 신뢰한 경우 `.codex/config.toml`과 `.codex/agents/*.toml`을 읽습니다. 설치 여부는 다음으로 확인할 수 있습니다.

```powershell
codex --version
```

### 개인 전역 설치

모든 프로젝트에서 공통 기본값으로 사용하려면 파일을 다음과 같이 배치합니다. 저장소의 `.codex` 디렉터리 자체를 `~/.codex` 안에 넣지 마십시오.

권장 방법은 저장소 root에서 운영체제에 맞는 설치 script를 실행하는 것입니다. 먼저 변경 예정 내용을 확인한 뒤 실제 설치를 진행합니다.

#### Windows

PowerShell script의 `-WhatIf`로 변경 대상을 확인합니다.

```powershell
.\install-global.ps1 -WhatIf
.\install-global.ps1
```

Execution Policy로 실행이 차단된 경우 현재 process에만 적용되는 방식으로 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-global.ps1
```

Windows 옵션은 다음과 같습니다.

- `-TargetCodexHome <path>`: 설치 대상을 명시합니다.
- `-MaxConcurrentThreads <1..64>`: session당 최대 agent thread 수를 지정합니다. 기본값은 4입니다.
- `-WhatIf`: 대상과 backup 파일을 쓰지 않고 변경 계획만 출력합니다.

#### macOS

macOS 기본 POSIX shell에서 다음과 같이 실행합니다. 실행 권한을 별도로 설정하지 않아도 됩니다.

```sh
sh ./install-global.sh --what-if
sh ./install-global.sh
```

macOS 옵션은 다음과 같습니다.

- `--target-codex-home <path>`: 설치 대상을 명시합니다.
- `--max-concurrent-threads <1..64>`: session당 최대 agent thread 수를 지정합니다. 기본값은 4입니다.
- `--what-if`: 대상과 backup 파일을 쓰지 않고 변경 계획만 출력합니다.
- `--help`: 사용법을 출력합니다.

두 script 모두 기존 `AGENTS.md`를 관리 마커 블록으로 병합하고, `config.toml`의 최상위 `model`, `model_reasoning_effort` 및 `[agents]` 설정을 갱신하며, 내용이 변경된 agent TOML만 복사합니다. 교체되는 기존 파일은 `<TargetCodexHome>/backups/inq-codex-multi-agents/<timestamp>/`에 백업됩니다. 설치 대상의 우선순위는 command-line에서 명시한 경로, `CODEX_HOME`, `~/.codex` 순서입니다. `AGENTS.override.md`가 있으면 `AGENTS.md`보다 우선하므로 경고를 출력합니다.

```text
~/.codex/
├── AGENTS.md
├── config.toml
└── agents/
    ├── architect.toml
    └── ...
```

- `AGENTS.md`를 `~/.codex/AGENTS.md`로 복사합니다. 이 지침은 모든 프로젝트에 개인 기본값으로 적용됩니다.
- `.codex/agents/*.toml`을 `~/.codex/agents/`로 복사합니다.
- 기존 `~/.codex/config.toml`을 덮어쓰지 말고, 이 저장소가 관리하는 메인 모델·추론 수준과 `[agents]` 설정만 병합합니다.

```toml
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"

[agents]
max_concurrent_threads_per_session = 4
```

기존 `config.toml`에서는 최상위 `model`과 `model_reasoning_effort`, 그리고 `[agents]` 테이블의 해당 키만 추가하거나 조정합니다. 중복된 관리 키가 있으면 설치를 중단해 사용자가 먼저 정리하도록 합니다. `README.md`는 설치 대상이 아닙니다.

이 저장소는 Codex CLI를 설치·재설치하지 않으며, 시스템 PATH나 사용자 전역 설정을 변경하지 않습니다. `install-global.ps1`과 `install-global.sh`는 이 저장소의 Codex 설정을 개인 전역 경로에 병합·복사하는 운영체제별 script이며, 별도 orchestration harness와 remove script는 제공하지 않습니다.

## 제거

프로젝트 설치를 제거할 때는 이 저장소가 추가한 `AGENTS.md`와 `.codex/`만 검토 후 삭제합니다. 개인 전역 설치를 제거할 때는 `~/.codex/agents/`에서 이 저장소가 추가한 agent 파일만 제거하고, `AGENTS.md`와 `config.toml`의 병합 내용은 다른 사용자 설정을 보존하며 수동으로 되돌립니다. Codex 애플리케이션, PATH, 인증 정보는 제거 대상이 아닙니다.

## 새 Expert 추가

실제 필요성이 확인된 뒤에만 `.codex/agents/<name>.toml`을 추가합니다. 각 파일에는 다음 필수 항목을 둡니다.

```toml
name = "expert-name"
description = "When Codex should use this expert."
developer_instructions = """
Role-specific instructions only.

Do not delegate work to or communicate directly with other subagents. Return results only to Main Codex.
"""
```

필요하면 `model`, `model_reasoning_effort`, `sandbox_mode`를 추가합니다. Subagent 격리·Main Codex 단일 보고 규칙은 각 TOML에도 명시하고, 그 밖의 공통 workflow 규칙은 반복하지 않고 `AGENTS.md`에 둡니다.

## 권한과 안전성

- 읽기·분석 agent 10개는 `read-only` sandbox를 사용합니다.
- `implementer`와 `tester`만 `workspace-write` sandbox를 사용합니다.
- `tester`는 쓰기 전 working tree를 확인하고, 기존 사용자 변경과 production code를 수정하지 않습니다. 임시 검증 산출물은 OS temp 또는 project의 ignored 경로를 우선 사용하고, 종료 시 정리하며 남은 파일을 보고합니다.
- 실행 중 선택한 부모 Codex session의 approval/permission 설정이 최종 적용됩니다.
- 전체 권한이나 시스템 전역 설정 변경은 편의상 사용하지 않습니다.
- 이 프로젝트에는 Pi, Hermes, custom daemon, queue, message broker, agent state database 같은 별도 harness가 없습니다.

## 모델과 비용

메인 Codex는 `gpt-5.6-terra`와 `medium` reasoning으로 고정합니다. 아키텍처·구현·리뷰는 `gpt-5.6-terra`와 `high` reasoning을 사용하고, 계획·조언·조사·일반 검증은 `gpt-5.6-luna`와 `medium` reasoning을 사용합니다. 언어·도메인 전문 agent는 `gpt-5.6-terra`와 `medium` reasoning을 사용합니다. 기본 구성은 `gpt-5.6-sol`을 사용하지 않으므로 Plus 플랜의 고성능 모델 사용량을 억제합니다. Agent는 실제로 도움이 될 때만 호출하며, 단순 작업에 workflow 전체를 적용하지 않습니다.

## 검증

구성을 변경한 뒤 다음을 확인합니다.

```powershell
codex doctor --summary
codex --ask-for-approval never "List the active instruction sources and available custom agents."
```

`codex doctor` 결과에서 config 오류가 없는지 확인합니다. 두 번째 명령은 새 session을 생성하므로 사용 중인 계정의 token 정책이 적용됩니다. 추가로 TOML 문법, 정확히 12개 agent, 12개 TOML 모두의 Main Codex 단독 delegation·결과 반환 규칙, 전문 agent의 Main Codex 단일 보고, `tester`의 작업 트리·임시 산출물 보호 규칙, README와 `AGENTS.md`의 일치, 불필요한 orchestration 코드 부재를 검토합니다.

## License

MIT
