# Codex CLI Multi-Agent Configuration

Codex CLI의 기본 기능만으로 구성한 프로젝트 범위 multi-agent 설정입니다. 별도 Python, Node.js, shell orchestration framework를 만들지 않고 `AGENTS.md`, `.codex/agents/`, custom subagent, sandbox, permission, model, reasoning 설정을 사용합니다.

## 구성

```text
AGENTS.md
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

`AGENTS.md`는 프로젝트 전체 workflow와 안전 규칙을, 각 TOML은 한 agent의 역할·모델·추론 수준·sandbox를 정의합니다.

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

Main Codex가 유일한 coordinator이며, **오직 Main Codex만 subagent를 호출**합니다. Subagent는 다른 subagent를 호출하거나 작업을 넘기지 않고 결과를 Main Codex에 반환합니다.

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

```powershell
git clone https://github.com/InKyu0317/inq-codex-multi-agents.git
```

프로젝트별 설정으로 사용할 경우 다음 항목을 대상 프로젝트 root에 유지합니다.

```text
AGENTS.md
.codex/
```

Codex는 프로젝트를 신뢰한 경우 `.codex/config.toml`과 `.codex/agents/*.toml`을 읽습니다. 설치 여부는 다음으로 확인할 수 있습니다.

```powershell
codex --version
```

이 저장소는 Codex CLI를 설치·재설치하지 않으며, 시스템 PATH나 사용자 전역 설정을 변경하지 않습니다. 현재 setup script와 remove script는 존재하지 않으므로, 별도 harness나 설치 스크립트를 추가하지 않습니다.

## 제거

대상 프로젝트에서 이 설정을 제거할 때는 이 저장소가 추가한 `AGENTS.md`와 `.codex/`만 검토 후 삭제합니다. 다른 프로젝트, 사용자 전역 `~/.codex`, Codex 애플리케이션, PATH, 인증 정보는 제거 대상이 아닙니다.

## 새 Expert 추가

실제 필요성이 확인된 뒤에만 `.codex/agents/<name>.toml`을 추가합니다. 각 파일에는 다음 필수 항목을 둡니다.

```toml
name = "expert-name"
description = "When Codex should use this expert."
developer_instructions = """
Role-specific instructions only.
"""
```

필요하면 `model`, `model_reasoning_effort`, `sandbox_mode`를 추가합니다. 공통 workflow 규칙은 TOML에 반복하지 않고 `AGENTS.md`에 둡니다.

## 권한과 안전성

- 읽기·분석 agent 10개는 `read-only` sandbox를 사용합니다.
- `implementer`와 `tester`만 `workspace-write` sandbox를 사용합니다.
- 실행 중 선택한 부모 Codex session의 approval/permission 설정이 최종 적용됩니다.
- 전체 권한이나 시스템 전역 설정 변경은 편의상 사용하지 않습니다.
- 이 프로젝트에는 Pi, Hermes, custom daemon, queue, message broker, agent state database 같은 별도 harness가 없습니다.

## 검증

구성을 변경한 뒤 다음을 확인합니다.

```powershell
codex --strict-config -C . agents --help
```

그리고 TOML 문법, 정확히 12개 agent, Main Codex 단독 delegation, README와 `AGENTS.md`의 일치, 불필요한 orchestration 코드 부재를 검토합니다.

## License

MIT
