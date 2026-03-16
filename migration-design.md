# 독서동호회 웹 전환 설계 계획서

*작성일: 2026-03-16*
*분석 대상: [독서동호회.pbix](/home/edwards/Dev/edwards.bookclub/독서동호회.pbix)*

## 1. 전환 목표

SharePoint List + Power BI 조합으로 운영 중인 독서동호회 서비스를 웹 기반 애플리케이션으로 전환한다. 목표는 다음 두 가지다.

1. 운영 데이터 입력과 조회를 하나의 서비스로 통합한다.
2. Power BI 없이도 운영 대시보드와 실무 관리 기능을 제공한다.

## 2. 현재 상태 분석

### 2.1 Power BI가 맡고 있는 역할

현재 Power BI는 단순 시각화만 하지 않는다. 다음 역할을 함께 수행하고 있다.

1. SharePoint 데이터를 운영용 뷰로 재구성
2. 날짜 차원 생성
3. 회원 역할 기반 적립금 계산
4. 도서 구매와 추가 납입금을 반영한 잔액 계산
5. 월별/지역별 출석 운영 화면 제공

따라서 웹 전환 시 BI 대체가 아니라 운영 시스템 재구성이 필요하다.

### 2.2 보고서 기반으로 추정한 사용자 시나리오

#### 관리자

- 회원 등록 및 수정
- 모임 생성
- 참석자 입력
- 적립 제외 처리
- 도서 신청 검토 및 상태 변경
- 월별 출석 및 잔액 점검

#### 일반 회원

- 도서 신청
- 출석 결과 확인
- 모임 사진 및 후기 열람

## 3. 목표 아키텍처

### 3.1 권장 방향

권장 방향은 다음과 같다.

- 백엔드: `Rails`
- DB: `SQLite`
- 프론트엔드: `Rails views + Hotwire` 또는 분리 필요 시 `Next.js`

권장 이유:

1. 현재 시스템의 핵심은 CRUD와 집계다.
2. 운영자가 주로 사용하는 백오피스 성격이 강하다.
3. 적립금 계산, 월별 필터, 관리 화면은 서버 중심 웹 앱으로 충분히 구현 가능하다.
4. SQLite + Rails는 초기 구축 속도와 유지보수 비용 측면에서 유리하다.

### 3.2 대안 방향

대안은 다음과 같다.

- 애플리케이션: `Next.js`
- ORM: `Prisma`
- DB: `SQLite`

적합한 경우:

1. 프론트엔드 인터랙션이 많아질 경우
2. 공개 사이트와 관리자 사이트를 한 앱에서 같이 운영할 경우
3. 향후 모바일 친화 UI와 대시보드 UX를 더 강하게 가져갈 경우

제약:

1. 관리자 CRUD 중심 요구만 놓고 보면 Rails보다 구조 복잡도가 커질 수 있다.
2. 집계 로직과 입력 폼 검증을 모두 직접 조합해야 한다.

## 4. 목표 도메인 모델

현행 Power BI 모델은 SharePoint 구조에 끌려간 형태이므로, 웹 전환 시 아래와 같이 정규화하는 것이 적절하다.

### 4.1 핵심 엔터티

#### `users`

로그인 계정.

주요 필드:
- `id`
- `email`
- `password_digest` 또는 외부 인증 키
- `role`
- `member_id`
- `created_at`
- `updated_at`

#### `members`

회원 마스터.

주요 필드:
- `id`
- `english_name`
- `korean_name`
- `department`
- `email`
- `member_role`
- `location`
- `active`
- `joined_on`
- `bio`
- `created_at`
- `updated_at`

비고:
- `isLeader`는 저장하지 않고 `member_role` 또는 권한 모델에서 파생한다.

#### `meetings`

모임 마스터.

주요 필드:
- `id`
- `title`
- `meeting_at`
- `location`
- `description`
- `review`
- `reserve_exempt_default`
- `created_by`
- `created_at`
- `updated_at`

비고:
- 현행 `출석!.Title`, `모임일시`, `Location`, `후기`를 하나의 모임 엔터티로 승격한다.

#### `meeting_attendances`

모임 참석자 조인 테이블.

주요 필드:
- `id`
- `meeting_id`
- `member_id`
- `reserve_exempt`
- `note`
- `created_at`
- `updated_at`

비고:
- 현행 `출석!` 테이블은 사실상 `meetings + meeting_attendances`가 섞인 비정규화 구조이므로 분리 필요

#### `meeting_photos`

모임 사진.

주요 필드:
- `id`
- `meeting_id`
- `file_path` 또는 `blob_key`
- `caption`
- `sort_order`
- `created_at`
- `updated_at`

#### `book_requests`

도서 신청 및 구매 이력.

주요 필드:
- `id`
- `member_id`
- `title`
- `author`
- `publisher`
- `price`
- `request_status`
- `cover_url`
- `link_url`
- `comment`
- `rating`
- `requested_on`
- `additional_payment`
- `created_at`
- `updated_at`

#### `reserve_policies`

적립 정책.

주요 필드:
- `id`
- `member_role`
- `attendance_points`
- `effective_from`
- `effective_to`

비고:
- 현행 하드코딩 `5000`, `10000`을 정책 테이블로 분리

#### `fiscal_periods`

운영 연도 또는 회계 기수.

주요 필드:
- `id`
- `name`
- `start_date`
- `end_date`
- `active`

비고:
- Power BI의 `DATE(2026,1,1)` 하드코딩 제거 목적

## 5. 계산 및 집계 설계

### 5.1 적립금 계산

웹 시스템의 적립금 계산식:

1. `meeting_attendances.reserve_exempt = false`인 출석만 적립 대상
2. 참석자의 `member_role`에 대응하는 `reserve_policies.attendance_points` 적용
3. 회원별 누적 적립금 합계 계산

### 5.2 잔액 계산

잔액 계산식:

`balance = attendance_reserve_total - purchased_book_total + additional_payment_total`

주의점:

- 집계 기준 기간은 활성 `fiscal_period`에 따라 달라져야 한다.
- 계산식은 SQL view 또는 서비스 객체로 구현하고, 화면에서는 읽기 전용 집계 결과를 사용한다.

### 5.3 대시보드 집계

필수 집계:

1. 월별 출석 수
2. 지역별 출석 수
3. 회원별 적립금
4. 회원별 도서 집행 금액
5. 회원별 잔액
6. 월별 모임 사진 수

## 6. 웹 화면 설계 초안

### 6.1 관리자 화면

1. 회원 관리
2. 모임 관리
3. 출석 입력
4. 도서 신청 관리
5. 적립금/잔액 대시보드
6. 기간/월 필터

### 6.2 회원 화면

1. 도서 신청 폼
2. 모임 사진/후기 열람
3. 개인 적립금 내역 조회

### 6.3 대시보드 화면

1. 운영 개요
2. 지역별 출석 차트
3. 월별 출석 추이
4. 회원별 잔액 테이블
5. 최근 모임 갤러리

## 7. 마이그레이션 단계 계획

### Phase 1. 현행 구조 정리

산출물:
- 데이터 사전
- SharePoint 리스트 export 규격
- 계산 규칙 정의서

작업:
- SharePoint 실제 컬럼명과 상태값 정리
- `Progess`, `별점`, `후기` 등 값 체계 확인
- `출석!`를 모임/참석자 구조로 분해하는 매핑 규칙 확정

### Phase 2. 목표 스키마 설계

산출물:
- SQLite 스키마
- ERD
- 초기 seed 정책

작업:
- 테이블 생성
- 인덱스 설계
- 제약조건 추가
- 운영 연도 및 적립 정책 초기값 정의

### Phase 3. 데이터 이관 스크립트

산출물:
- SharePoint export importer
- 검증 리포트

작업:
- 회원 이관
- 도서 신청 이관
- 출석/모임 분해 이관
- 사진 URL 또는 첨부파일 처리 전략 확정

### Phase 4. 관리자 기능 구현

산출물:
- CRUD 화면
- 대시보드 1차 버전

작업:
- 회원 관리
- 모임/출석 관리
- 도서 신청 처리
- 적립금 집계 화면

### Phase 5. 검증 및 전환

산출물:
- Power BI 대비 검증표
- 운영 전환 체크리스트

작업:
- 회원별 적립금 대조
- 도서 구매 합계 대조
- 월별 출석 수 대조
- 운영자 UAT

## 8. 기술 선택 비교

### 방향 A: Rails 단일 앱

장점:
- CRUD 중심 요구에 가장 적합
- 관리자 화면 구현 속도가 빠름
- SQLite와 궁합이 좋음
- 계산 로직을 서버에서 일관되게 관리하기 쉬움

단점:
- BI 스타일 인터랙티브 대시보드 표현은 제한적일 수 있음

### 방향 B: Next.js 단일 앱

장점:
- UI 자유도가 높음
- 대시보드와 공개 페이지 디자인에 유리
- 향후 프론트엔드 확장성이 좋음

단점:
- 서버 액션, ORM, 인증, 관리자 UX 조합 설계가 더 필요함
- 초기 구조 결정 비용이 더 큼

### 권장 결론

현재 요구는 "운영 시스템 재구축"이 핵심이므로 1차 버전은 `Rails + SQLite`가 더 적합하다. 이후 공개 페이지나 고급 대시보드가 필요해지면 별도 프론트엔드를 붙이는 2단계 구조가 합리적이다.

## 9. 주요 리스크

1. SharePoint 원본의 다중값 필드가 정규화 시 손실될 수 있음
2. `출석!`의 현재 레코드 구조가 모임 단위와 참석자 단위를 혼합하고 있어 이관 규칙이 필요함
3. Power BI의 상대 날짜 필터와 운영 연도 하드코딩을 그대로 옮기면 운영 규칙이 숨겨진 채 유지될 수 있음
4. 사진/첨부파일 저장 전략을 초기에 정하지 않으면 이관 범위가 흔들릴 수 있음

## 10. 다음 작업 권장안

1. SharePoint Lists를 CSV 또는 JSON으로 export
2. 실제 상태값과 예외 케이스 표본 검토
3. 목표 SQLite 스키마 초안 작성
4. Rails 기준 초기 모델과 importer 설계
5. Power BI 지표와 동일한 SQL 집계 검증
