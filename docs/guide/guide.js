// FaaS PoC 가이드 공통 스크립트: 왼쪽 목차, 이 페이지 소제목 목록, "깊이 3단계 숨기기", mermaid 테마
(function () {
  var CHAPTERS = [
    { no: "00", file: "index.html", title: "전체 그림" },
    { no: "01", file: "ch01-gitops.html", title: "GitOps와 Argo CD" },
    { no: "02", file: "ch02-rollouts.html", title: "점진 배포와 자동 롤백" },
    { no: "03", file: "ch03-tenancy.html", title: "멀티테넌시와 노드 풀" },
    { no: "04", file: "ch04-network.html", title: "네트워크: eBPF와 Cilium" },
    { no: "05", file: "ch05-knative.html", title: "서버리스: Knative" },
    { no: "06", file: "ch06-build-runtime.html", title: "이미지 빌드와 gVisor" },
    { no: "07", file: "ch07-control-plane.html", title: "컨트롤 플레인과 MCP" },
    { no: "08", file: "ch08-resilience.html", title: "장애 주입과 관측" },
    { no: "09", file: "ch09-ec2-k3s.html", title: "EC2·k3s·Terraform" }
  ];

  function store(key, val) {
    try { if (val === undefined) return localStorage.getItem(key); localStorage.setItem(key, val); } catch (e) { return null; }
  }

  function here() {
    var p = location.pathname.split("/").pop();
    return p && /\.html$/.test(p) ? p : "index.html";
  }

  function buildNav() {
    var nav = document.querySelector("nav.nav");
    if (!nav) return;
    var cur = here();
    var html = '<a class="brand" href="index.html">FaaS PoC 가이드</a><div class="brand-sub">poc/01~07 · 구조와 동작 원리</div><ol>';
    CHAPTERS.forEach(function (c) {
      var isHere = c.file === cur;
      html += '<li><a href="' + c.file + '"' + (isHere ? ' class="here" aria-current="page"' : "") + '><span class="ch-no">' + c.no + "</span>" + c.title + "</a>";
      if (isHere) {
        var heads = document.querySelectorAll("main h2[id]");
        if (heads.length) {
          html += '<div class="toc">';
          heads.forEach(function (h) { html += '<a href="#' + h.id + '">' + h.textContent + "</a>"; });
          html += "</div>";
        }
      }
      html += "</li>";
    });
    html += '</ol><div class="tools"><button type="button" id="toggle-deep" aria-pressed="false">3단계 숨기기</button></div>';
    nav.innerHTML = html;

    var btn = document.getElementById("toggle-deep");
    function apply(on) { document.body.classList.toggle("shallow", on); btn.setAttribute("aria-pressed", on ? "true" : "false"); btn.textContent = on ? "3단계 보이기" : "3단계 숨기기"; scheduleNotes(); }
    apply(store("guide-shallow") === "1");
    btn.addEventListener("click", function () { var on = !document.body.classList.contains("shallow"); apply(on); store("guide-shallow", on ? "1" : "0"); });

    // 페이저 (이전/다음 장)
    var pager = document.querySelector(".pager");
    if (pager && !pager.children.length) {
      var i = CHAPTERS.findIndex(function (c) { return c.file === cur; });
      var out = "";
      if (i > 0) out += '<a href="' + CHAPTERS[i - 1].file + '"><span>이전 장</span>' + CHAPTERS[i - 1].no + " " + CHAPTERS[i - 1].title + "</a>";
      else out += "<span></span>";
      if (i >= 0 && i < CHAPTERS.length - 1) out += '<a href="' + CHAPTERS[i + 1].file + '"><span>다음 장</span>' + CHAPTERS[i + 1].no + " " + CHAPTERS[i + 1].title + "</a>";
      pager.innerHTML = out;
    }
  }

  function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }

  function renderMermaid() {
    if (!window.mermaid) return;
    var dark = matchMedia("(prefers-color-scheme: dark)").matches;
    var t = document.documentElement.getAttribute("data-theme");
    if (t === "dark") dark = true; if (t === "light") dark = false;
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: "base",
      fontFamily: css("--font-body"),
      themeVariables: {
        darkMode: dark,
        background: css("--surface"),
        primaryColor: css("--accent-soft"),
        primaryBorderColor: css("--accent-line"),
        primaryTextColor: css("--text"),
        secondaryColor: css("--user-soft"),
        secondaryBorderColor: css("--user-line"),
        tertiaryColor: css("--surface-2"),
        tertiaryBorderColor: css("--line"),
        lineColor: css("--edge"),
        textColor: css("--text"),
        mainBkg: css("--accent-soft"),
        nodeBorder: css("--accent-line"),
        clusterBkg: css("--surface-2"),
        clusterBorder: css("--line"),
        titleColor: css("--text"),
        edgeLabelBackground: css("--surface"),
        actorBkg: css("--accent-soft"),
        actorBorder: css("--accent-line"),
        actorTextColor: css("--text"),
        actorLineColor: css("--edge"),
        signalColor: css("--text"),
        signalTextColor: css("--text"),
        labelBoxBkgColor: css("--surface-2"),
        labelBoxBorderColor: css("--line"),
        labelTextColor: css("--text"),
        loopTextColor: css("--text"),
        noteBkgColor: css("--warn-soft"),
        noteBorderColor: css("--warn-line"),
        noteTextColor: css("--text"),
        activationBkgColor: css("--user-soft"),
        activationBorderColor: css("--user-line"),
        sequenceNumberColor: css("--surface"),
        fontSize: "14px"
      },
      flowchart: { htmlLabels: true, curve: "basis" },
      sequence: { mirrorActors: false, showSequenceNumbers: true }
    });
    try { var r = window.mermaid.run({ querySelector: "pre.mermaid:not([data-processed])" }); if (r && r.then) r.then(scheduleNotes, scheduleNotes); } catch (e) { /* 다이어그램 문법 오류는 원문 그대로 보인다 */ }
  }

  // ---------- 용어 주석 배치 ----------
  // 본문 .t(용어) 와 aside.notes 안의 dt/dd 를 순서대로 짝지어 hover 하이라이트와 title 을 붙이고,
  // 넓은 화면(≥1260px)에서는 aside 를 그 단락 옆 여백으로 띄운다. 겹치면 아래로 밀고, 다음 그림·표·제목과 겹칠 자리면 단락 아래에 둔다.
  var LIMIT = "figure, .table-wrap, pre, .grid, .wide, .pager, h2, .tier, .fig";
  function pairNotes() {
    var main = document.querySelector("main"); if (!main) return;
    var terms = main.querySelectorAll(".t");
    var items = main.querySelectorAll("aside.notes dl > div");
    terms.forEach(function (t, i) {
      var it = items[i]; if (!it) return;
      t.setAttribute("data-n", i + 1); it.setAttribute("data-n", i + 1);
      var dd = it.querySelector("dd"); if (dd) t.title = dd.textContent.trim();
      t.addEventListener("mouseenter", function () { it.classList.add("hl"); });
      t.addEventListener("mouseleave", function () { it.classList.remove("hl"); });
      it.addEventListener("mouseenter", function () { t.classList.add("hl"); });
      it.addEventListener("mouseleave", function () { t.classList.remove("hl"); });
    });
  }
  function topIn(el, page) { return el.getBoundingClientRect().top - page.getBoundingClientRect().top; }
  function nextLimitTop(a, page) {
    var el = a;
    while (el && el !== page) {
      var n = el.nextElementSibling;
      if (n) {
        if (n.matches(LIMIT)) return topIn(n, page);
        var d = n.querySelector(LIMIT); if (d) return topIn(d, page);
        el = n; continue;
      }
      var p = el.parentElement;
      if (!p || p === page) return null;
      if (p.matches(".tier, .callout")) return topIn(p, page) + p.offsetHeight;
      el = p;
    }
    return null;
  }
  function layoutNotes() {
    var page = document.querySelector(".page"); if (!page) return;
    var wide = matchMedia("(min-width: 1260px)").matches;
    var notes = page.querySelectorAll("aside.notes");
    var last = -1e9, gap = 14;
    notes.forEach(function (a) {
      a.classList.remove("side"); a.style.top = "";
      if (!wide || a.offsetParent === null) return;
      var prev = a.previousElementSibling;
      if (!prev || a.closest(".callout, .grid, .table-wrap, figure, .item, li, dd")) return;
      // 앞 블록이 그림·표·코드처럼 폭이 넓은 것이면 여백이 비어 있지 않으므로 그 아래 상자로 둔다
      if (prev.matches("figure, .table-wrap, .grid, pre, .wide, .fig")) return;
      var top = Math.max(topIn(prev, page), last + gap);
      a.classList.add("side");
      // top 은 .page 기준으로 계산했지만, 실제 기준점(offsetParent)은 position: relative 인 .tier 일 수 있다
      a.style.top = (top - topIn(a.offsetParent || page, page)) + "px";
      var h = a.offsetHeight, lim = nextLimitTop(a, page);
      if (lim !== null && top + h > lim - gap) { a.classList.remove("side"); a.style.top = ""; return; }
      last = top + h;
    });
  }
  var notesTimer = null;
  function scheduleNotes() { clearTimeout(notesTimer); notesTimer = setTimeout(layoutNotes, 60); }
  function initNotes() {
    pairNotes(); layoutNotes();
    window.addEventListener("resize", scheduleNotes);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(scheduleNotes);
    window.addEventListener("load", scheduleNotes);
    var page = document.querySelector(".page");
    if (page && window.ResizeObserver) new ResizeObserver(scheduleNotes).observe(page);
  }

  function init() { buildNav(); initNotes(); renderMermaid(); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
