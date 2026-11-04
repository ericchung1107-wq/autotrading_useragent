# autotrading_useragent

## 한 줄 설명
유저 서버(Railway)에서 실행되는 Agent. 중앙 서버의 HMAC 서명 주문 요청을 받아 거래소(ccxt)에 직접 실행하고, 시작 시 중앙 서버에 URL 등록.

## 기술 스택
- Python 3.11+, FastAPI, uvicorn, ccxt, httpx, pydantic-settings, slowapi

## 폴더 구조
- main.py : FastAPI 앱, HMAC 검증, nonce 캐시, 엔드포인트
- exchange_client.py : 거래소 클라이언트(AgentExchangeClient)
- config.py : 환경변수 설정(AgentSettings)
- railway.json : 배포 설정

## 자주 쓰는 명령어
- 설치: pip install -r requirements.txt
- 실행: uvicorn main:app --port 8000
- 헬스체크: GET /healthz

## 규칙
- .env 절대 읽거나 커밋하지 않는다 (.env.example만 참고)
- HMAC/nonce 검증 로직은 승인 없이 변경 금지

## 현재 상태
- 이어서 할 일은 HANDOFF.md 참고

## 작업 규칙 (토큰 절약)
- 요청 범위 밖의 파일은 읽지 않는다. 전체 코드베이스 탐색 금지.
- 파일은 필요한 부분만 읽는다 (함수/라인 범위 지정, grep 먼저).
- 수정 전에 계획을 3줄 이내로 말하고, 승인 없이 대규모 리팩터링 하지 않는다.
- 답변은 짧게. 변경한 내용은 요약 3줄 이내. 코드 전체를 다시 출력하지 않는다.
- 같은 오류가 2번 연속 안 풀리면 멈추고, 원인 가설과 현재 상태를 정리해서 보고한다.
- 큰 로그/출력은 head, tail, grep으로 줄여서 본다.
- 작업이 끝나면 /handoff 로 상태를 HANDOFF.md에 남기도록 제안한다.
