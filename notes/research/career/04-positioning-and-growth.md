로드맵 위치: 2주차 / 커리어 포지셔닝과 2028 입사까지 1.5년 성장 전략 / 본선 이후 면접·커피챗·유니버설 채용 연결

# 04. 포지셔닝과 성장 전략 (2026-10 → 2028-04)

- 작성: 2026-10-14, 1차 초안 → 셀프 리뷰 → 보강(2차). 다음 갱신 때 맨 아래 "갱신 로그"에 추가.
- 태그: 【사실】(출처) 【추정】 【미확인】 【사용자】. 일본어 공부 계획은 넣지 않는다(이미 완성, 【사용자】 2026-10-06).

## 0. 한 줄 결론

- "3학년"은 변명이 아니라 **성장 속도의 증거**로 쓴다. "0에서 한 달 만에 CKA + 본선, 입사 전 1.5년 동안 GPU 클라우드 운영에 필요한 이것을 더 쌓겠다"는 역산형 서사.
- 가장 큰 레버는 순서대로: ① 본선 상위 입상 → No.1채용/서류 면제 ② 해커톤 결과물을 "측정 숫자 + 설계 문서"로 공개 ③ AWS SAA + 추론 서빙 프로젝트 ④ 소프트뱅크 사람과의 관계 유지.
- 백업은 LY · CyberAgent · Mercari · Sakura · Rakuten. **Rakuten(10/30 09:00 JST), Mercari 인턴(10/31), LY 인프라 신졸 1차(11/9 10:00) 마감이 본선 앞뒤에 몰려 있다** → 지원할지 TODO(human).

---

## 1. 지금 위치 (프로필 정리)

| 항목 | 내용 | 근거 |
|---|---|---|
| 학적 | 인천대 컴공 3-2, 2028-02 졸업 예정 → 2028-04 입사 트랙(28卒) | 【사용자】 |
| 경력 | Java/Spring 백엔드, PM(TIME Korea), Techeer 멘토, App Center 리드 | 【사용자】 |
| 해커톤 | 예선 팀 camellia 리드, IR 기반 배포, 일본어 발표, 본선 진출 | 【사용자】 |
| 자격 | CKA 포함 한 달 사이 자격증 3개 | 【사용자】(타임라인 대화). 나머지 2개 이름은 이 문서에 미기재 → 갱신 때 채우기 |
| 일본어 | 완성, 소프트뱅크 측도 인지 | 【사용자】 |
| 인프라 실습 | 2026-10 시작. Lab 01~05(도커·k8s·프로브·HPA·선점) 실측 숫자 있음 | 【사실】 레포 `labs/`, `STATUS.md` |

### 1.1 "3학년"을 성장 서사로 만드는 법

- 【사실】 유니버설 채용 Entry Level은 입사 시 30세 미만이면 신졸·기졸·재직자 모두 같은 트랙, 통년 모집, 4월/10월 입사 ([softbank.jp universal](https://www.softbank.jp/recruit/graduate/recruit/universal/)). 즉 학년 보정은 없다.
- 【사실】 면접 후기에서 핵심은 "ソフトバンクバリューにマッチしているか", 스피드·도전이 반복해서 나온다 ([외자취활 후기](https://gaishishukatsu.com/selection_reports/28910)). 신졸 전형은 ES + SPI + 1:1 온라인 면접 20~30분 × 3회 정도, 가쿠치카를 깊게 판다 ([ONE CAREER](https://www.onecareer.jp/companies/73/experiences/2027/176340/1381910)).
- 【사실】 소프트뱅크 밸류 5개: No.1 / 挑戦 / 逆算 / スピード / 執念 ([softbank.jp philosophy](https://www.softbank.jp/corp/philosophy/)).
- 【사실】 GPU 클라우드 경력 공고도 PM·프로젝트 리드 경험을 우대 ([005070](https://www.softbank.jp/recruit/career/positions/detail/005070/)) → App Center 리드·camellia 리드는 "인프라 + 리딩" 조합으로 내세운다.
- 【추정】 그래서 학년은 "같은 결과를 더 이른 시점에 냈다 + 입사 전까지 남은 시간이 더 길다"로 프레이밍한다. 변명처럼 먼저 꺼내지 않는다.

**밸류 ↔ 경험 매핑 (면접 소재, 숫자 필수)** 【추정】

| 밸류 | 소재 | 넣을 숫자 |
|---|---|---|
| 逆算 | 본선 날짜에서 거꾸로 짠 6주 로드맵 + 게이트(10/11, 10/18, 10/25, 11/1) | 셋업 드릴 1분 59초, 게이트 통과 여부 |
| スピード | 인프라 경험 0 → 한 달 만에 CKA, Lab 01~05 | 기간(일), 실측값(롤아웃 실패율 51% → 3%, 롤백 0.25초) |
| 挑戦 | Java 백엔드에서 클라우드 인프라로 영역 전환, 일본어 발표 | 예선 → 본선 진출 |
| 執念 | 예선 기간 막힌 문제를 끝까지 판 사례(팀 camellia) | TODO(human): 실제 사례 1개 고르기 |
| No.1 | 본선 결과 | 11/8 이후 채움 |

---

## 2. 소프트뱅크 쪽 채용 경로 지도

| 경로 | 내용 | 너에게 의미 |
|---|---|---|
| 해커톤 특별 트랙 | 【사실】 "우수 참가자 및 본선 진출자"에게 서류 면제 및 면접 **기회**, 본선 상위 입상은 "서류 면제 및 면접 확약" ([SNU 공지](https://cse.snu.ac.kr/en/community/notice/25347)). 전원 보장은 아님 | 본선 진출로 기회는 확보, 확약은 입상해야 |
| No.1채용 | 【사실】 전국 대회 이상 수준, "Technology No.1" 예시에 「各種ハッカソン優勝経験」·Kaggle Master·탑 학회 논문. 동영상/서류 → 면접 수회 ([No.1채용](https://www.softbank.jp/recruit/graduate/recruit/method/no1/)). 2027년도 접수는 종료, **2028년도 창구는 아직 공고 없음** ([flow](https://www.softbank.jp/recruit/graduate/recruit/flow/), 2026-10-14 확인) | 우승 시 가장 강한 루트 【추정】. 창구 열리는 시기 【미확인】 |
| OPEN (総合職 엔지니어 코스) | 【사실】 입사 후 배속 결정 ([flow](https://www.softbank.jp/recruit/graduate/recruit/flow/)) | 기본 루트 |
| JOB-MATCH | 【사실】 네트워크/시스템/솔루션/보안 엔지니어, 데이터 사이언티스트 등 초기 배속 확약 ([flow](https://www.softbank.jp/recruit/graduate/recruit/flow/)) | GPU 클라우드 쪽을 원하면 어떤 직종이 매핑되는지 커피챗에서 확인 |
| 28卒 JOB-MATCH 인턴 | 【사실】 2·4주, 시급 1,250엔, 해외 대학생 가능, 5/18 마감(종료). 배속 확약은 28卒 내정 + 같은 직종 희망 시에만 ([internship](https://www.softbank.jp/recruit/graduate/recruit/internship/)). 겨울 인턴·28卒 대상 이벤트는 공고 없음(2026-10-14 확인) | 이미 지남. 대신 해커톤이 같은 역할 |

- 【미확인】 해커톤 "특별 포지션"이 OPEN/JOB-MATCH 중 어디에 가까운지, 배속 확약인지 → 커피챗 질문 5번.
- 【사실】 GPU 클라우드 실무 요건(경력직 공고): K8s/VMware/KVM 기반 구축 경험, 우대 NVIDIA GPU 서버·Lustre/Ceph·Python/Ansible/Terraform, **GPU·CUDA는 입사 후 배워도 된다**, PM 경험 우대 ([005070](https://www.softbank.jp/recruit/career/positions/detail/005070/)). 네트워크 쪽은 EVPN/VXLAN, InfiniBand/RoCEv2 ([005063](https://www.softbank.jp/recruit/career/positions/detail/005063/)).
- 【사실】 "AI Data Center GPU Cloud"가 2026-10 상용 개시, 소프트웨어는 사내 Infrinia 팀의 **Infrinia AI Cloud OS**(Kubernetes as a Service, Inference as a Service) ([보도자료 2026-05-25](https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260525_01/)). → 본선 주제 후보 A(멀티테넌트 추론 서버리스)와 정확히 같은 방향.

---

## 3. 가치를 올리는 것들 (우선순위)

### 3.1 자격증

- 【사실】 소프트뱅크는 자격 필수는 아님. 대신 수험료 + 장려금 지원, 대상 약 280개(2024-02 기준) ([welfare](https://www.softbank.jp/recruit/graduate/company/welfare/), [guideline](https://www.softbank.jp/recruit/graduate/recruit/guideline/)).
- 【사실】 AWS Advanced Tier 파트너, 2025년 "All AWS Certifications" 보유 엔지니어 9명을 블로그로 홍보 ([cloud-tech blog](https://www.softbank.jp/biz/blog/cloud-technology/articles/202507/aws-all-cert-2025/)).

| 순위 | 자격 | 이유 | 시기 |
|---|---|---|---|
| 1 | AWS SAA | 회사가 공개적으로 축하하는 계열, CKA가 못 덮는 관리형 클라우드·VPC·IAM 보완 【추정】 | 2026-12 |
| 2 | CKS | CKA가 선행 조건 【사실】 ([k8s training](https://kubernetes.io/training/)), 멀티테넌트 GPU 클라우드 보안 얘기로 연결 | 2027 상반기 |
| 3 | 応用情報技術者 | 일본 기업 인지도 높음, 2026년도부터 CBT 【사실】 ([@IT](https://atmarkit.itmedia.co.jp/ait/articles/2608/31/news097.html)). 해외 시험장 못 찾음 → 일본 방문 필요 【추정】 | 일본 갈 일 있을 때만 |
| 보류 | CKAD, KCNA/KCSA, LPIC | CKA와 중복 【추정】 | - |
| 보류 | NVIDIA NCP-AII | 데이터센터 실무 2~3년 권장 【사실】 ([NVIDIA](https://www.nvidia.com/en-us/learn/certification/ai-infrastructure-professional)) | 입사 후 |

- 【추정】 자격증은 "이미 충분히 신호가 있음" 단계. 다음 1개(SAA)까지만 하고, 그 이후 시간은 프로젝트·OSS에 쓰는 편이 비용 대비 효과가 크다.

### 3.2 프로젝트 (가장 중요)

- 【사실】 일본 신졸 대상에서도 GPU 스케줄링이 다뤄진다: CyberAgent ML 플랫폼 인턴이 GKE에서 커스텀 스케줄러를 Go로 작성 ([CyberAgent](https://www.cyberagent.co.jp/careers/students/event/detail/id=32702)). CIU 신졸 인프라 직무 기술: Kubernetes, Cluster API, Kubeflow, KServe, Ceph, RoCEv2 ([CIU](https://www.cyberagent.co.jp/careers/students/tech/jobs/detail/id=27086)).
- 【추정】 추천 대표작 1개: **"작은 Infrinia" — 멀티테넌트 LLM 추론 플랫폼**
  - Terraform으로 클러스터 → K8s + vLLM 또는 KServe → Kueue로 GPU 큐잉 → Prometheus/DCGM 지표 → k6 부하 테스트 리포트(p95 지연, 토큰당 비용)
  - 그 위에 Spring으로 셀프서비스 API(테넌트·쿼터·과금) → 백엔드 강점이 차별점
  - 본선 결과물을 그대로 키우는 형태라 시간 낭비가 없다
- 【사실】 엔지니어 채용 담당 관점: README가 "어디를 보면 되는지" 안내해야 하고, 설계 이유 문서와 학습 습관이 평가된다 ([speakerdeck](https://speakerdeck.com/tetsunosuke/20211125)).

### 3.3 인턴

- 소프트뱅크 28卒 인턴은 종료(위 표). 남은 선택지:
  - 【사실】 Mercari 2028졸 인턴, **2026-10-31 마감**, 일본 2~3개월, 비자·주거 지원, Platform/SRE 트랙(Go, K8s, Terraform) ([workable](https://apply.workable.com/mercari/jobs/view/EC5A1078C4))
  - 【사실】 IIJ 2028졸 "Network & Cloud" 5일 / 클라우드 3주 유급, 마감 2027-02-28 ([마이나비](https://job.mynavi.jp/28/pc/search/corp64952/is.html))
  - 【사실】 Kakao 채용연계 인턴에 과거 인프라 트랙 존재 ([kakaocorp](https://www.kakaocorp.com/page/detail/10677?lang=ENG)), 2027 공고 【미확인】
  - 【사실】 AWS Korea Cloud Support Intern은 2025·2026 졸업자 대상이었음 ([amazon.jobs](https://amazon.jobs/en/jobs/2729754/cloud-support-intern)). 2028 졸업자용 공고 【미확인】
- 【추정】 내정이 일찍 나오면 2027 여름은 인턴 대신 OSS 멘토십(LFX)이 더 낫다. 내정이 안 나오면 일본 기업 인턴이 우선.

### 3.4 오픈소스 기여 (1.5년 안에 현실적인 것)

- 【사실】 LFX Mentorship 연 3회(봄 3~5월/여름 6~8월/가을 9~11월), 프로젝트 공개는 1월 중순·4월 중순·7월 중순, 지원 약 4주, 12주 유급 ([LFX docs](https://docs.linuxfoundation.org/lfx/mentorship/mentorship-program-timelines)).
- 【사실】 GSoC 2026 기여자 지원 3/16~3/31 ([GSoC](https://developers.google.com/open-source/gsoc/timeline)). 2027 일정 【미확인】, 비슷할 것 【추정】.
- 단계 【추정】:
  1. 2026-11 ~ 2027-01: kubernetes/website 일본어 번역(/ja) good-first-issue, kind·vLLM·Kueue·KServe 문서 수정. 일본어 번역은 이미 가진 능력을 OSS 실적으로 바꾸는 가장 싼 방법.
  2. 2027-02 / 2027-05: LFX(Kueue, KServe, Kubeflow, Volcano 등 AI 인프라 쪽) 또는 GSoC 지원.
  3. 2027 하반기: 기여 내용으로 Kubernetes Meetup Tokyo / CloudNative Days에서 LT.

---

## 4. 보여 주는 법 (포트폴리오·프로필)

- 【사실】 일본 LinkedIn 사용자는 약 621만(인구 약 5%) ([NapoleonCat](https://napoleoncat.com/stats/linkedin-users-in-japan/)) → 신졸 채용 메인 채널은 아님 【추정】.
- 【사실】 OfferBox: 27卒 학생 240,867명, 기업 약 19,600곳 ([neo-career](https://www.neo-career.co.jp/humanresource/offerbox/date/)). LAPRAS는 GitHub·Qiita·Zenn을 자동 포트폴리오로 묶고, 2026년 한국 IT 인재 대상 서비스를 시작했다는 보도 ([CodeZine](https://codezine.jp/news/detail/14000), [Newsweek Japan](https://www.newsweekjapan.jp/articles/-/330163)).

| 채널 | 할 일 | 우선 |
|---|---|---|
| GitHub 프로필 README | 대표작 3개 + 각 1줄 숫자(예: "롤아웃 실패율 51% → 3%") | 필수 |
| 해커톤/본선 레포 README | 구조도, "내가 쓴 코드는 여기", 설계 결정 링크, 측정표 | 필수 |
| Zenn (일본어 기사) | 3~5편: CKA 한 달 기록, 본선 아키텍처 회고, 추론 서빙 부하 측정 | 필수 |
| OfferBox, LAPRAS | 일본어 프로필, 가쿠치카를 "역산 → 행동 → 숫자" 형식으로 | 필수 |
| connpass LT | SoftBank Tech Night 등 참가 → 1회 발표 | 2027 |
| LinkedIn | 영·일·한 3개 언어 프로필, 소프트뱅크·KOREC 사람 연결용 | 선택 |
| ONE CAREER / 외자취활 | ES·면접 후기 읽기용 | 읽기만 |

---

## 5. 해커톤 이후 네트워킹

- 【미확인】 김택근(Kim Tackkun)님의 소속·역할은 공개 자료에서 찾지 못함. 본선 현장에서 명함(名刺) 또는 LinkedIn 받기.
- 【사실】 KOREC은 한국 → 일본 취업 서비스(ビーウェルインターナショナル, 창업자 春日井萌) ([起業手帳](https://sogyotecho.jp/?p=207467)). 운영 측 연락 창구일 가능성 【추정】.
- 【사실】 SoftBank Tech Night connpass 그룹 존재, 2026 주제: RAG 품질(8/28), Platform Engineering(3/17) 등 ([connpass](https://sbtechnight.connpass.com/)). 온라인 세션도 있어 한국에서 참여 가능 【추정】.
- 【사실】 일본 가이드는 カジュアル面談을 "ほぼ選考と同意義"로 본다 ([jo-katsu](https://jo-katsu.com/campus/2066)). 감사 메일은 당일 또는 다음 날 오전, 평일 9~18시, 구체적 배운 점 포함, "ご返信には及びません"이면 답장 안 함 ([crexgroup](https://crexgroup.com/ja/shukatsu/?p=387)).

### 5.1 커피챗 질문 (12개)

**팀·업무**
1. 普段どの組織で、どんなシステムを担当されていますか？ (역할부터 확인)
2. Infrinia AI Cloud OS のような内製基盤と、AWS/GCP 案件の比率は日常業務でどう分かれますか？
3. GPU クラウドの商用開始前後で、現場で一番難しかった課題は何でしたか？
4. AITRAS や Telco AI Cloud のような通信×AI 領域に新卒が関わる余地はありますか？

**채용 경로**
5. ハッカソンの「特別ポジション」は JOB-MATCH と OPEN のどちらに近いですか？配属は確約されますか？
6. 2028年4月入社を目指す場合、ユニバーサル採用ではいつ頃エントリーするのが理想ですか？
7. 韓国の大学から入社された方は、ビザ・入社前研修でどんなサポートがありましたか？
8. 選考でハッカソンの成果物や GitHub はどの程度見られますか？

**입사 전 준비**
9. エンジニアコースの1〜2年目で「これができると強い」スキルは何ですか？（K8s・ネットワーク・LLM 推論など）
10. 資格（AWS 等）と個人開発、どちらを優先すべきだと思われますか？

**문화·관계 유지**
11. テクシバや Tech Night のような発信活動に若手はどう関わっていますか？
12. 今後、進捗のご報告をさせていただいてもよろしいでしょうか？ (마지막에)

- 피할 것 【추정】: 연봉·잔업 첫 질문, "붙을 수 있나요", 채용 페이지에 있는 내용, 추천 직접 요청(대신 조언 요청).
- 1.5년 관계 유지 【추정】: 분기 1회, 매번 구체 결과 1개(배포한 프로젝트, 자격, OSS 머지, 기사)와 함께 짧게.

---

## 6. 백업 회사 (같은 방향, 다른 문)

| 순위 | 회사 | 왜 맞나 | 지금 할 일 |
|---|---|---|---|
| 1 | LY Corporation | 사내 프라이빗 클라우드 K8s 플랫폼(KaaS·IaaS·서비스 메시) 【사실】 ([LY intern](https://www.lycorp.co.jp/ja/recruit/newgrads/internship/engineer)). 2028 입사 "Infra Engineering Expert" 모집 중, 1차 **11/9 10:00**, 2차 12/7, 3차 1/5, 전형은 전부 일본어 【사실】 ([jd0002](https://www.lycorp.co.jp/en/recruit/newgrads/engineer/jd0002/)). 소프트뱅크 그룹사라 해커톤 서사가 이어짐 【추정】 | 2차(12/7) 지원이 본선과 안 겹침 【추정】 |
| 2 | CyberAgent (CIU) | GPU 클러스터·KaaS·GPUaaS·KServe, 스킬 매칭 최고. 일본어 필요(충족) 【사실】 ([CIU](https://www.cyberagent.co.jp/careers/students/tech/jobs/detail/id=27086)) | 인턴 공고 감시 |
| 3 | Mercari | 신졸 약 50명 중 44명 외국 국적 사례, 비자·주거 지원 【사실】 ([기사](https://stofficetokyo.ch/news/startups/japan-online-flea-market-operator-mercari-hires-large-number-of-non-japanese-grads)) | **10/31 인턴 마감** |
| 4 | Sakura Internet | 高火力 B200 GPU 클라우드, 28졸 채용 포털 있음, 8월 5일 인턴 【사실】 ([sakura](https://www.sakura.ad.jp/recruit/graduates/)) | 2027-08 인턴 |
| 5 | Rakuten | 2028 입사 Term 1 지원 **10/2~10/30 09:00 JST**, 조기 마감 가능 【사실】 ([rakuten](https://global.rakuten.com/corp/careers/graduates/recruit_engineer/)) | 지원 여부 결정 |
| 별도 | AWS Japan SA 신졸 | 2028졸 본선형 전형 진행 중 【사실】 ([AWS](https://aws.amazon.com/jp/careers/newgraduate/internship)). PM·고객 대응 강점과 맞음 【추정】 | 확인만 |
| 도전 | Preferred Networks | 계산 기반·MN-Core 트랙, 해외 지원·비자 지원 【사실】 ([PFN FAQ](https://www.preferred.jp/ja/careers/faq)). 문턱 매우 높음 【추정】 | 패스 권장 |

- 【사실】 한국 내 일본 기업 채용 행사: 글로벌 탤런트 페어(COEX, 2026-06, 해외기업 121곳 중 일본 32곳) ([bizwatch](https://news.bizwatch.co.kr/article/industry/2026/06/01/0020)). 대부분 중소 IT 【사실】 → 위 5곳과는 결이 다름.
- 【추정】 백업 지원은 "소프트뱅크 면접 연습"으로도 가치가 있다. 단, 본선(11/7~8) 준비 시간을 깎지 않는 선에서.

---

## 7. 1.5년 로드맵 (2026-10 → 2028-04)

| 구간 | 목표 | 핵심 할 일 | 산출물 |
|---|---|---|---|
| **P0** 10/14~11/8 | 본선 상위 입상 | 본선 준비만. 백업 지원은 TODO(human) 결정 1개만 | 본선 데모, 설계 문서 |
| **P1** 11/9~12월 | 해커톤을 자산으로 | 커피챗 + 감사 메일(당일), 본선 레포 README·측정표 정리, Zenn 기사 1~2편, OfferBox·LAPRAS 개설, LY 2차(12/7) 지원, AWS SAA | 공개 레포, 기사, SAA |
| **P2** 2027-01~03 | 소프트뱅크 전형 | 특별 트랙/No.1채용 면접(시기 【미확인】), SPI 가볍게, k8s ja 번역 기여 시작, LY 3차(1/5) 결과 | 면접, 첫 OSS PR |
| **P3** 2027-04~08 | 대표작 + 확장 | "작은 Infrinia" 추론 플랫폼 v1, LFX/GSoC 지원, 내정 없으면 일본 기업 인턴 지원 | 대표작, 부하 리포트 |
| **P4** 2027-09~12 | 내정 확정·입사 준비 | 내정 시: CKS, connpass LT, 분기 업데이트 / 미내정 시: 유니버설 재지원 + 백업 본전형 | LT, CKS |
| **P5** 2028-01~03 | 입국 | 【사실】 기술·인문지식·국제업무 비자는 회사가 COE 신청, 처리 1~3개월 ([출입국재류관리청](https://www.moj.go.jp/isa/applications/procedures/16-1.html)) → 12~1월 서류. 졸업 서류 늦으면 10월 입사로 전환(해외 졸업자 10/1 입사 가능 【사실】 [guideline](https://www.softbank.jp/recruit/graduate/recruit/guideline/)) | 비자, 입사 |

---

## 핵심 결정 3개 (+대안)

1. **다음 자격은 AWS SAA 하나로 끝낸다.** 대안: CKS 먼저(K8s 깊이), 応用情報(일본 인지도). 버린 이유: SAA가 소프트뱅크 클라우드 조직 신호와 가장 직접 맞고, 이후 시간은 프로젝트가 더 효율적 【추정】.
2. **대표작은 본선 결과물을 키운 "멀티테넌트 추론 플랫폼" 1개.** 대안: 매번 새 토이 프로젝트, Kaggle. 버린 이유: GPU 클라우드 공고·Infrinia 방향과 정확히 일치하고 본선 시간을 재사용.
3. **백업 지원은 본선 전에는 최소화, LY는 12/7 2차로.** 대안: Rakuten·Mercari 10월 마감 둘 다 지원. 트레이드오프: 면접 경험·안전망 vs 본선 준비 시간. → **TODO(human): Rakuten(10/30)·Mercari(10/31) 지원할지 정하기**

## 셀프 연습 1개

- 위 1.1 표의 "執念" 칸에 들어갈 예선 사례 하나를 골라 "상황 → 역산한 목표 → 행동 → 숫자 결과" 4줄로 써 보기(일본어 그대로 OK). 커피챗 자기소개 30초 버전의 재료가 된다.

## 검증 명령과 기대 출력

```bash
# 핵심 출처가 살아 있는지 확인 (각 줄 200 기대)
for u in \
  https://www.softbank.jp/recruit/graduate/recruit/method/no1/ \
  https://www.softbank.jp/recruit/graduate/recruit/universal/ \
  https://cse.snu.ac.kr/en/community/notice/25347 \
  https://sbtechnight.connpass.com/ ; do
  printf '%s ' "$(curl -s -o /dev/null -w '%{http_code}' "$u")"; echo "$u"
done
# 기대: 200 https://www.softbank.jp/...  (4줄 모두 200)
```

---

## 못 찾은 것 (다음 루프 후보)

- 김택근님 공개 프로필, 竹園님 공개 정보
- 해커톤 "특별 포지션"과 OPEN/JOB-MATCH의 관계, 면접 시기, 2028년도 No.1채용 창구
- 소프트뱅크 지원 자격 280개 목록과 장려금 금액
- 소프트뱅크에 입사한 한국인 엔지니어의 공개 후기
- 2027 LFX/GSoC 공식 일정, Kakao·Naver Cloud 2027 인턴

## 갱신 로그

- 2026-10-14 v1: 4개 병렬 조사(자격·프로젝트·인턴·OSS / 평가·포트폴리오 / 백업 회사 / 네트워킹) 종합.
- 2026-10-14 v2(셀프 리뷰): 핵심 주장 8개 원문 재확인. 고친 것: 해커톤 혜택은 "전원 보장"이 아니라 본선 진출자 기회 / 입상자 확약, No.1채용 2028 창구 미공고, JOB-MATCH 배속 확약 조건, LY는 해외·비자 신졸 공고가 2026 입사용(낡음) → 2028 인프라 공고(일본어 전형, 11/9·12/7·1/5)로 교체, Rakuten 마감 시각 09:00. 1.1에 PM 우대 근거 추가.
