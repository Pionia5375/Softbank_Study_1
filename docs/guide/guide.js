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
    function apply(on) { document.body.classList.toggle("shallow", on); btn.setAttribute("aria-pressed", on ? "true" : "false"); btn.textContent = on ? "3단계 보이기" : "3단계 숨기기"; }
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
    try { window.mermaid.run({ querySelector: "pre.mermaid:not([data-processed])" }); } catch (e) { /* 다이어그램 문법 오류는 원문 그대로 보인다 */ }
  }

  function init() { buildNav(); renderMermaid(); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
