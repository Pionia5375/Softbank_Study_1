로드맵 위치: 2주차 / 모니터링 출처 목록 / 본선 주제 힌트·회사 방향·채용 소식을 가장 빨리 받기

# 05. 모니터링 출처·채널 목록

매일 아침 갱신 루틴(00-index.md 참고)이 이 목록을 위에서부터 훑는다. 루틴은 새 출처를 찾으면 추가하고, 죽은 링크는 지우지 않고 `상태`를 `죽음(YYYY-MM-DD)`으로 바꾼다.

- 확인 날짜: 2026-10-14 (WebFetch로 직접 열어 본 것만 `확인`, 나머지는 【미확인】)
- RSS 칸: `있음`(URL 병기) / `없음`(페이지에 피드 링크 없음) / `?`(못 봄)
- 주기: 실제 최근 글 간격을 보고 적은 대략값

## 0. 우선순위 (아침에 이 순서로 본다)

1. 해커톤 공지 (본선 일정·주제 힌트) → 1-A
2. SoftBank Corp. 보도자료·IR 뉴스 (회사 행보) → 2-A
3. 채용 공지 (@sb_graduate, 채용 페이지) → 3
4. 기술 블로그 (Zenn 공식, SB Intuitions) → 4
5. 일본 IT 뉴스 (GPU 클라우드·AI 데이터센터 보도) → 5

## 1. 해커톤 (가장 급함)

| 출처 | URL | 뭘 얻나 | 주기 | RSS | 상태 |
|---|---|---|---|---|---|
| A. 링커리어 공고 | https://linkareer.com/activity/340301 | 공식 일정·주최·문의처. 본선 킥오프 시각 | 공지 바뀔 때만 | 없음 | 확인 |
| B. KOREC 네이버 카페 공지 | https://cafe.naver.com/koreccafe/13175 | 상세 공지 원문. 장소 발표가 여기 먼저 올라올 가능성 【추정】 | 비정기 | ? | 【미확인】(로그인 필요할 수 있음) |
| C. 주최 메일 | korec.seoul@gmail.com 발신 메일 | 결과 메일(10/26), 회신 마감(10/27) | 이벤트 때 | - | 【사용자】 받은편지함 |
| D. 서울대 컴공 공지 | https://cse.snu.ac.kr/community/notice/25347 | 학교 쪽에 배포된 같은 공고. 공고 변경 비교용 | 거의 없음 | ? | 검색으로 존재 확인 |
| E. 작년 본선 레포 | github.com/2026-Softbank-hackathon (예선 팀 레포) | 다른 팀 공개 레포, 작년 우승작 비교 | 비정기 | - | 【사용자】 |
| F. ContestKorea 공고 | https://www.contestkorea.com/sub/view.php?Txt_gbn=1&Txt_bcode=030310001&str_no=202608180036 | 킥오프 10/30으로 적힌 쪽. 날짜 수정 여부 비교용 | 공지 바뀔 때만 | 없음 | 03 문서에서 확인 |

> **킥오프 날짜는 아직 미정이다.** 【사실: 출처끼리 다름, 2026-10-14 확인】 Linkareer·서울대 공지는 **11/2(월) 20:00**, 같은 공고를 옮긴 ContestKorea(https://www.contestkorea.com/sub/view.php?Txt_gbn=1&Txt_bcode=030310001&str_no=202608180036)·동명대는 **10/30(금) 20:00**. 어느 쪽이 수정본인지 모른다. 10/26 결과 메일 또는 KOREC 공지로 확정될 때까지 루틴이 매일 확인한다 (03-finals-and-study-direction.md 2.4절 참고). 본선 11/7–8 서울, 예선 통과 약 50명, 장소 추후 공지는 출처가 일치한다.

## 2. 회사 행보 (SoftBank Corp. = 9434, 통신 회사. SoftBank Group(9984)과 헷갈리지 말 것)

| 출처 | URL | 뭘 얻나 | 주기 | RSS | 상태 |
|---|---|---|---|---|---|
| A. 보도자료 전체 (영문) | https://www.softbank.jp/en/corp/news/press/all/ | 신규 서비스·제휴·투자 발표 원문. 가장 빠름 | 주 수 회 | 없음 | 확인 |
| A'. 보도자료 (일문) | https://www.softbank.jp/corp/news/press/sbkk/ | 영문보다 먼저·더 많이 올라옴 【추정】 | 주 수 회 | ? | 【미확인】 |
| B. 법인(비즈) 뉴스 | https://www.softbank.jp/biz/news/ (클라우드: /biz/news/cloud/) | GPU 클라우드·AI 데이터센터 상품 발표. **본선 주제와 제일 가까운 곳** | 월 수 회 | 없음 | 확인 |
| C. IR 뉴스 | https://www.softbank.jp/en/corp/ir/news/ | 실적·적시공시 | 분기 + 수시 | 없음 | 확인 |
| C'. IR 캘린더 | https://www.softbank.jp/en/corp/ir/news/calendar/ | 다음 실적 발표일 | 분기 | 없음 | 확인 |
| D. 결산 자료 | https://www.softbank.jp/en/corp/ir/documents/financial_reports/ | 결산 설명 슬라이드. 사업부별 숫자 | 분기 | 없음 | 확인 |
| E. 성장 전략 "Activate AI for Society" | https://www.softbank.jp/en/corp/philosophy/strategy/ | 중기 방향 (설계 문서 서두 인용용) | 연 1회 | 없음 | 확인 |
| F. 통합 보고서 | https://www.softbank.jp/en/corp/ir/documents/integrated_reports/ | 기술 전략·인재 전략 장문 | 연 1회 | 없음 | 확인 |
| G. 기자회견 자료 | https://www.softbank.jp/en/corp/news/conference/ | 발표 슬라이드 원본 | 비정기 | 없음 | 확인 |
| H. SoftBank News (영문) | https://www.softbank.jp/en/sbnews/ | 보도자료를 풀어 쓴 기사. 배경 이해용 (카테고리: Future_Tech 등) | 주 1~2 | 없음 | 확인 |
| I. SoftBank News X | https://twitter.com/sbnews9434 | SoftBank News 새 글 알림 | 수시 | - | 페이지 링크로 확인 |
| J. SoftBank 공식 X | @SoftBank | 소비자 쪽 공지 위주 【추정】 | 수시 | - | 메타데이터로만 확인 |
| K. LinkedIn | https://www.linkedin.com/company/softbank-mobile | 영문 회사 소식·채용 | 주 수 회 | - | 페이지 링크로 확인 |
| L. YouTube (SoftBank News) | https://www.youtube.com/channel/UCcMKfz1n6L6erIlyyowlOOA | 발표 영상 | 비정기 | 있음(YouTube 채널 피드) 【추정】 | 페이지 링크로 확인 |
| M. 다음 실적 발표 | 2026-11-09 16:00 JST (Q2 FY2026) | 본선 직후. GPU 클라우드 첫 숫자 나올 수 있음 | - | - | 확인 (IR 페이지) |

## 3. 채용

| 출처 | URL | 뭘 얻나 | 주기 | RSS | 상태 |
|---|---|---|---|---|---|
| A. 신졸 채용 X | https://twitter.com/sb_graduate | 엔트리 오픈·마감 알림이 제일 빠름 | 수시 | - | 확인 |
| B. 신졸 채용 (일문) | https://www.softbank.jp/recruit/graduate/ | 모집 요강·코스 | 시즌마다 | 없음 | 확인 |
| C. 신졸 채용 (영문) | https://www.softbank.jp/en/recruit/graduate/ | 해외 학생용 안내 | 시즌마다 | 없음 | 확인 |
| D. JOB-MATCH 인턴 | https://www.softbank.jp/recruit/graduate/recruit/internship/ | 엔지니어 코스 직무 목록 (네트워크·SE·보안·솔루션·데이터·R&D). 클라우드 단독 코스는 없음. 국내외 학생 지원 가능 | 연 1회(5월 마감) | 없음 | 확인 |
| E. 인턴 목록 | https://www.softbank.jp/recruit/graduate/recruit/internlist/ | 다른 인턴 프로그램 | 시즌마다 | 없음 | 확인 |
| F. SoftBank Career NOW | https://www.softbank.jp/recruit/careernow/ | 사원 인터뷰·직무 소개 기사 | 월 수 회 | ? | 링크로 확인 |
| G. 경력 채용 | https://www.softbank.jp/recruit/career/ | 클라우드·AI 인프라 직무 공고 → 어떤 스택을 원하는지 | 수시 | 없음 | 【미확인】 |
| H. 채용 YouTube | https://www.youtube.com/channel/UCC47XuzdHahtUrB1k7BMFbg | 직무 설명 영상 | 비정기 | 【추정】 있음 | 링크로 확인 |
| I. 채용 Facebook | https://www.facebook.com/softbank.saiyo/ | 이벤트 공지 | 비정기 | - | 링크로 확인 |
| J. 취준 후기 (일본) | https://syukatsu-kaigi.jp/companies/74902 , https://plus.onecareer.jp/companies/73 | 면접 후기·질문 유형 | 수시 | 없음 | 검색으로 존재 확인 |
| K. SB Intuitions 채용 | https://open.talentio.com/r/1/c/sbintuitions/homes/4413 | LLM 자회사 직무 | 수시 | 없음 | 링크로 확인 |

## 4. 기술 블로그 (관련 직무 실무 내용)

| 출처 | URL | 뭘 얻나 | 주기 | RSS | 상태 |
|---|---|---|---|---|---|
| A. **SoftBank 테크블로그 (공식, Zenn)** | https://zenn.dev/p/softbank | 사내 엔지니어 실무 글. 2026-03 이전 글은 아래 B에 보관 | 주 1 정도 【추정】 | **있음** https://zenn.dev/p/softbank/feed | 확인 |
| B. 구 클라우드 기술 블로그 | https://www.softbank.jp/biz/blog/cloud-technology/ | 2026-03 이전 클라우드 실무 글 아카이브 | 정지 | 없음 | 링크로 확인 |
| C. SB Intuitions TECH BLOG | https://www.sbintuitions.co.jp/blog/ | 자체 LLM(Sarashina)·평가 벤치마크. 최근: J-MultiChallenge(9/28), Sarashina Image(9/4) | 월 2~3 | ? (하테나 블로그라 /feed 있을 가능성 【추정】) | 확인 |
| D. SB Intuitions X | https://x.com/sbintuitions | 모델 공개 알림 | 수시 | - | 링크로 확인 |
| E. LY Corp Tech Blog | https://techblog.lycorp.co.jp | 같은 그룹(LINE야후) 대규모 인프라·쿠버네티스 글 | 주 수 회 | 【추정】 있음 | 집계 사이트로 확인 |
| F. Qiita 조직 | https://qiita.com/organizations/softbank | 글 0개. 볼 필요 없음 | - | - | 확인(비어 있음) |
| G. 일본 기업 테크블로그 RSS 모음 | https://yamadashy.github.io/tech-blog-rss-feed/ | 일본 기업 블로그 전체 피드. SoftBank Zenn 포함 | 매일 | 있음 | 확인 |

## 5. 일본 IT 뉴스 (회사 행보를 제3자가 정리한 것)

| 출처 | URL | 뭘 얻나 | 주기 | RSS | 상태 |
|---|---|---|---|---|---|
| A. Impress Cloud Watch | https://cloud.watch.impress.co.jp/ | 클라우드 상품 발표 기사 (GPU 클라우드 10월 출시 기사 있음) | 매일 | 【추정】 있음 | 검색으로 확인 |
| B. @IT (ITmedia) | https://atmarkit.itmedia.co.jp/ | 해설 기사. 예: 2026-06-23 "SoftBank, 일본판 네오클라우드" (GPU 클라우드 = Infrinia AI Cloud OS + KaaS + Inference as a Service, 10월 출시) | 매일 | 【추정】 있음 | 확인 |
| C. Publickey | https://www.publickey1.jp/ | 클라우드 네이티브·쿠버네티스 동향 | 매일 | 【추정】 https://www.publickey1.jp/atom.xml | 【미확인】 |
| D. CodeZine | https://codezine.jp/ | 개발자 대상 SoftBank 발표 정리 | 매일 | ? | 검색으로 확인 |
| E. Google 뉴스 검색 | news.google.com 에서 "ソフトバンク GPU" "SoftBank Corp" 검색 | 여러 매체를 한 번에. 루틴은 WebSearch로 대체 | 실시간 | 있음(검색 RSS) | robots 차단으로 루틴에서 직접 못 읽음 |
| F. GeekNews (한국) | https://news.hada.io/ | 한국어 기술 뉴스. 일본 기업 소식은 드묾 | 매일 | 있음 | 검색으로 확인 |

## 6. 컨퍼런스·커뮤니티 (발표 자료로 실무 스택 확인)

| 출처 | URL | 뭘 얻나 | 시기 | 상태 |
|---|---|---|---|---|
| A. KubeCon + CloudNativeCon Japan 2026 | https://events.linuxfoundation.org/kubecon-cloudnativecon-japan-2026/ | 2026-07-29~30 요코하마, 이미 끝남. 발표 영상에서 SoftBank 세션 찾기 (CNCF 발표문엔 SoftBank 언급 없음) | 끝남 | 확인 |
| B. CloudNative Days | https://cloudnativedays.jp/ | 일본 클라우드 네이티브 커뮤니티 행사. 다음 회차 일정 【미확인】 | 연 2회 정도 【추정】 | 【미확인】 |
| C. SoftBank connpass | https://softbank.connpass.com/ | 사내 주최 공개 세미나 | 비정기 | 【미확인】(robots 차단) |
| D. SpeakerDeck/SlideShare | "ソフトバンク" 검색 | 사내 엔지니어 발표 슬라이드 | 비정기 | 【미확인】 |

## 7. 아직 못 찾은 것 (루틴이 계속 찾을 것)

- SoftBank Corp. 보도자료 RSS: 페이지에서 피드 링크를 못 찾음. 대안은 WebSearch `site:softbank.jp/corp/news/press` 를 날짜순으로.
- 적시공시(TDnet) 9434 바로가기: 【미확인】
- AI 데이터센터 GPU 클라우드 전용 상품 페이지·문서 URL: 10월 출시라 곧 생길 것 【추정】
- 해커톤 본선 장소 공지 위치 (카페 vs 메일)
- **본선 킥오프 공식 날짜** (11/2 vs 10/30): 네 공고(링커리어, 서울대, ContestKorea, 동명대)와 KOREC 카페를 매일 비교

## 핵심 결정 3개 (+대안)

1. **RSS 리더 대신 루틴이 WebFetch로 직접 연다.** 대안: Feedly 같은 RSS 리더. 버린 이유: SoftBank 공식 사이트 대부분이 RSS를 안 줘서 리더로는 절반만 잡힘.
2. **영문 보도자료를 기본, 일문은 보조.** 대안: 일문만. 버린 이유: 루틴 요약을 한국어로 쓸 때 영문 원문이 오역 위험이 적음. 일문에만 있는 발표는 일문 페이지로 보충.
3. **SoftBank Group(9984) 소식은 뺀다.** 대안: 그룹 전체 추적. 버린 이유: 채용·본선과 직접 연결되는 건 SoftBank Corp. 쪽이고, 그룹 투자 뉴스는 양이 많아 신호를 묻는다. 단 OpenAI 합작(SB OpenAI Japan)처럼 Corp.가 당사자면 넣는다.

## 셀프 연습 1개

- 2-B 법인 뉴스 클라우드 카테고리를 열고, 가장 최근 발표 하나를 골라 "이게 본선 주제 후보 A(멀티테넌트 추론 서버리스)와 어떻게 연결되는지" 한 줄로 써 보기.

## 검증 명령과 기대 출력

```bash
git log --oneline -1 -- notes/research/career/05-sources-and-channels.md
# 기대: 이 파일을 추가한 커밋 한 줄
grep -c '| 확인' notes/research/career/05-sources-and-channels.md
# 기대: 20 이상 (직접 확인한 출처 수)
```
