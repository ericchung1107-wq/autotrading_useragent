#!/usr/bin/env bash
# Claude Code 토큰 절약 세팅 스크립트
# 사용법:  bash setup-claude-efficient.sh ~/proj1 ~/proj2 ~/proj3 ...
# 이미 있는 파일은 절대 덮어쓰지 않습니다.

set -e

if [ "$#" -eq 0 ]; then
  echo "사용법: bash $0 <프로젝트경로> [프로젝트경로 ...]"
  exit 1
fi

write_if_missing() {
  # $1 = 경로, 내용은 stdin
  if [ -e "$1" ]; then
    echo "  건너뜀(이미 있음): $1"
    cat > /dev/null
  else
    mkdir -p "$(dirname "$1")"
    cat > "$1"
    echo "  생성: $1"
  fi
}

# ---------- 1) 전역 규칙 (모든 프로젝트 공통) ----------
echo "[전역] ~/.claude"
write_if_missing "$HOME/.claude/CLAUDE.md" <<'EOF'
# 전역 작업 규칙 (토큰 절약)
- 요청 범위 밖의 파일은 읽지 않는다. 전체 코드베이스 탐색 금지.
- 파일은 필요한 부분만 읽는다 (함수/라인 범위 지정, grep 먼저).
- 수정 전에 계획을 3줄 이내로 말하고, 승인 없이 대규모 리팩터링 하지 않는다.
- 답변은 짧게. 변경한 내용은 요약 3줄 이내. 코드 전체를 다시 출력하지 않는다.
- 같은 오류가 2번 연속 안 풀리면 멈추고, 원인 가설과 현재 상태를 정리해서 보고한다.
- 큰 로그/출력은 head, tail, grep으로 줄여서 본다.
- 작업이 끝나면 /handoff 로 상태를 HANDOFF.md에 남기도록 제안한다.
EOF

# ---------- 2) 프로젝트별 세팅 ----------
for P in "$@"; do
  P="${P/#\~/$HOME}"
  if [ ! -d "$P" ]; then
    echo "[건너뜀] 폴더 없음: $P"
    continue
  fi
  NAME="$(basename "$P")"
  echo "[프로젝트] $P"

  # CLAUDE.md: 새 세션의 재설명 비용을 없애는 핵심 파일
  write_if_missing "$P/CLAUDE.md" <<EOF
# $NAME

## 한 줄 설명
(이 프로젝트가 무엇인지 1~2줄)

## 기술 스택
- (언어/프레임워크/DB)

## 폴더 구조
- src/ : (설명)
- (주요 폴더만 적기)

## 자주 쓰는 명령어
- 실행: (명령어)
- 테스트: (명령어)
- 빌드: (명령어)

## 규칙
- (코딩 스타일, 건드리면 안 되는 파일 등)

## 현재 상태
- 이어서 할 일은 HANDOFF.md 참고
EOF

  # HANDOFF.md: 세션 사이를 잇는 인수인계 파일
  write_if_missing "$P/HANDOFF.md" <<'EOF'
# HANDOFF
(아직 없음. 작업 후 /handoff 로 자동 갱신)
EOF

  # 프로젝트 설정: 기본 모델 Sonnet, 불필요한 파일 읽기 차단, 사고 토큰 상한
  write_if_missing "$P/.claude/settings.json" <<'EOF'
{
  "model": "sonnet",
  "env": {
    "MAX_THINKING_TOKENS": "8000"
  },
  "permissions": {
    "deny": [
      "Read(./node_modules/**)",
      "Read(./dist/**)",
      "Read(./build/**)",
      "Read(./.next/**)",
      "Read(./coverage/**)",
      "Read(./package-lock.json)",
      "Read(./yarn.lock)",
      "Read(./pnpm-lock.yaml)",
      "Read(./.env*)"
    ]
  }
}
EOF

  # /handoff : 작업 끝날 때 상태 저장 -> 이후 /clear
  write_if_missing "$P/.claude/commands/handoff.md" <<'EOF'
---
description: 현재 작업 상태를 HANDOFF.md에 저장 (이후 /clear 해도 됨)
---
지금까지의 작업을 HANDOFF.md 에 덮어써서 저장해줘. 20줄 이내, 아래 형식:

## 방금 한 일
## 현재 상태 (동작하는 것 / 깨진 것)
## 다음에 할 일 (우선순위 순, 관련 파일 경로 포함)
## 주의사항 / 결정한 사항

코드를 새로 읽거나 탐색하지 말고, 이 대화에서 이미 아는 내용만 써. 저장 후 "/clear 해도 됩니다"라고만 답해.
EOF

  # /resume-work : 새 세션 시작할 때 최소 비용으로 복귀
  write_if_missing "$P/.claude/commands/resume-work.md" <<'EOF'
---
description: HANDOFF.md만 읽고 이어서 작업 시작
---
HANDOFF.md 만 읽어. 다른 파일은 아직 읽지 마.
그다음 "다음에 할 일" 1번을 위해 꼭 필요한 파일만 읽고, 3줄 이내 계획을 말한 뒤 시작해.
EOF

  # /small : 작은 수정용 (탐색 금지)
  write_if_missing "$P/.claude/commands/small.md" <<'EOF'
---
description: 범위가 좁은 수정 (탐색 최소화)
argument-hint: <파일경로> <무엇을 바꿀지>
---
$ARGUMENTS

위 요청만 처리해. 언급된 파일 외에는 grep으로 꼭 필요한 곳만 확인하고, 다른 파일은 열지 마.
변경 후 한 줄 요약만 답해.
EOF

  # 탐색 전용 서브에이전트(저렴한 모델): 큰 검색을 메인 컨텍스트 밖에서 처리
  write_if_missing "$P/.claude/agents/finder.md" <<'EOF'
---
name: finder
description: 코드베이스에서 특정 함수/설정/사용처를 찾을 때 사용. 위치와 핵심 요약만 반환.
model: haiku
tools: Read, Grep, Glob
---
요청받은 것을 찾아서 "파일경로:라인 + 한 줄 설명" 형태로만 보고해. 코드 전체를 붙여넣지 마. 10개 이내.
EOF

  # .gitignore에 HANDOFF 추가는 선택사항이므로 안내만
done

# ---------- 3) 매니저 = 세션이 아니라 '상태 파일' ----------
write_if_missing "$HOME/claude-projects/STATUS.md" <<'EOF'
# 프로젝트 현황판 (세션 아님, 그냥 파일)
오늘 활성: (최대 2개만)

| 프로젝트 | 상태 | 다음 할 일 | 우선순위 |
|---|---|---|---|
| | | | |

규칙: 하루 시작에 오늘 돌릴 프로젝트 1~2개만 정한다. 나머지는 열지 않는다.
EOF

cat <<'EOF'

완료. 아래를 ~/.zshrc (또는 ~/.bashrc)에 추가하면 편합니다:

  # 프로젝트 폴더로 이동 + Sonnet으로 시작
  cc()  { cd "$1" && claude --model sonnet; }
  # 같은 폴더에서 직전 대화 이어가기
  ccc() { cd "$1" && claude --continue; }

일일 루틴:
  1) STATUS.md 보고 오늘 프로젝트 1~2개 선택
  2) cc ~/proj1   ->  /resume-work
  3) 작업 -> 끝나면 /handoff -> /clear
  4) 중간에 길어지면 /compact, 가끔 /context 로 점검
EOF
