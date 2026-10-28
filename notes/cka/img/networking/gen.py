"""네트워킹 정리본 그림 생성기.

python3 gen.py  ->  같은 폴더에 *.svg 를 쓴다. PNG 는 render.js 로 만든다.
"""
from pathlib import Path

OUT = Path(__file__).parent
FONT = "'WenQuanYi Zen Hei','Noto Sans KR','Apple SD Gothic Neo',sans-serif"

# 색: (채움, 테두리)
GRAY = ("#f3f4f6", "#9ca3af")
NODE = ("#f8fafc", "#64748b")
NS = ("#dbeafe", "#2563eb")
BR = ("#ffedd5", "#ea580c")
SVC = ("#ede9fe", "#7c3aed")
EXT = ("#dcfce7", "#16a34a")
RULE = ("#fef9c3", "#ca8a04")
RED = ("#fee2e2", "#dc2626")
INK = "#111827"
MUTED = "#4b5563"


class Svg:
    def __init__(self, w, h, title):
        self.w, self.h, self.parts = w, h, []
        self.text(w / 2, 34, title, size=20, weight=700)

    def rect(self, x, y, w, h, color=GRAY, r=10, dash=False, sw=1.6):
        d = ' stroke-dasharray="6 4"' if dash else ""
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
            f'fill="{color[0]}" stroke="{color[1]}" stroke-width="{sw}"{d}/>')

    def text(self, x, y, s, size=14, weight=400, color=INK, anchor="middle", mono=False):
        fam = "'DejaVu Sans Mono',monospace" if mono else FONT
        s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        self.parts.append(
            f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{size}" '
            f'font-weight="{weight}" fill="{color}" text-anchor="{anchor}">{s}</text>')

    def box(self, x, y, w, h, lines, color=GRAY, size=14, dash=False, bold_first=True, mono_rest=False):
        """가운데 정렬 상자. lines[0] 은 굵게."""
        self.rect(x, y, w, h, color, dash=dash)
        n = len(lines)
        lh = size + 6
        top = y + h / 2 - (n - 1) * lh / 2 + size * 0.35
        for i, s in enumerate(lines):
            self.text(x + w / 2, top + i * lh, s, size=size if i == 0 else size - 1,
                      weight=700 if (i == 0 and bold_first) else 400,
                      color=INK if i == 0 else MUTED, mono=(mono_rest and i > 0))

    def label(self, x, y, s, color=GRAY, size=13):
        """왼쪽 위 이름표 (큰 테두리 상자용)."""
        self.text(x + 12, y + 22, s, size=size, weight=700, color=color[1], anchor="start")

    def arrow(self, x1, y1, x2, y2, label=None, color="#374151", dash=False, lx=None, ly=None, size=12, both=False):
        d = ' stroke-dasharray="6 4"' if dash else ""
        start = ' marker-start="url(#ahs)"' if both else ""
        self.parts.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
            f'stroke-width="1.8"{d} marker-end="url(#ah)"{start}/>')
        if label:
            lx = (x1 + x2) / 2 if lx is None else lx
            ly = (y1 + y2) / 2 - 6 if ly is None else ly
            for i, s in enumerate(label.split("\n")):
                self.text(lx, ly + i * (size + 4), s, size=size, color=MUTED)

    def line(self, x1, y1, x2, y2, color="#374151", dash=False, sw=1.8):
        d = ' stroke-dasharray="6 4"' if dash else ""
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"{d}/>')

    def table(self, x, y, colw, rows, color=RULE, size=12, rowh=22, mono=True):
        w = sum(colw)
        self.rect(x, y, w, rowh * len(rows) + 8, color, r=6)
        for i, row in enumerate(rows):
            cx = x
            for j, cell in enumerate(row):
                self.text(cx + 8, y + 20 + i * rowh, cell, size=size, anchor="start",
                          weight=700 if i == 0 else 400, mono=(mono and i > 0))
                cx += colw[j]

    def save(self, name):
        body = "\n".join(self.parts)
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">
<defs>
<marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#374151"/></marker>
<marker id="ahs" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#374151"/></marker>
</defs>
<rect width="100%" height="100%" fill="#ffffff"/>
{body}
</svg>
'''
        (OUT / f"{name}.svg").write_text(svg, encoding="utf-8")


# 01. 스위치·라우터·게이트웨이 (1장)
def d01():
    s = Svg(960, 450, "1장 · 스위치는 같은 네트워크를, 라우터는 네트워크와 네트워크를 잇는다")
    s.rect(30, 60, 330, 250, NS, dash=True); s.label(30, 60, "네트워크 192.168.1.0/24", NS)
    s.rect(600, 60, 330, 250, NS, dash=True); s.label(600, 60, "네트워크 192.168.2.0/24", NS)
    s.box(130, 100, 130, 46, ["스위치"], GRAY)
    s.box(50, 210, 130, 56, ["A", "192.168.1.10"], NODE)
    s.box(210, 210, 130, 56, ["B", "192.168.1.11"], NODE)
    s.line(195, 146, 115, 210); s.line(195, 146, 275, 210)
    s.box(700, 100, 130, 46, ["스위치"], GRAY)
    s.box(620, 210, 130, 56, ["C", "192.168.2.10"], NODE)
    s.box(780, 210, 130, 56, ["D", "192.168.2.11"], NODE)
    s.line(765, 146, 685, 210); s.line(765, 146, 845, 210)
    s.box(400, 95, 160, 70, ["라우터", ".1.1  |  .2.1"], BR)
    s.arrow(260, 123, 398, 123, both=True)
    s.arrow(562, 123, 698, 123, both=True)
    s.box(400, 220, 160, 56, ["인터넷 (구글)", "172.217.194.0/24"], EXT)
    s.arrow(480, 165, 480, 218)
    s.table(30, 340, [130, 200], [["B의 라우팅 테이블", ""], ["192.168.2.0/24", "via 192.168.1.1"], ["default", "via 192.168.1.1"]])
    s.table(600, 340, [130, 200], [["C의 라우팅 테이블", ""], ["192.168.1.0/24", "via 192.168.2.1"], ["default", "via 192.168.2.1"]])
    s.text(480, 380, "라우트는 양쪽 모두에 넣어야", size=13, color=MUTED)
    s.text(480, 400, "답장이 돌아온다", size=13, color=MUTED)
    s.save("01-switch-router")


# 02. 이름 해석 순서 (2장)
def d02():
    s = Svg(960, 400, "2장 · 호스트 A가 이름 하나를 IP로 바꾸는 순서")
    s.box(30, 150, 140, 60, ["ping db", "(호스트 A)"], NODE)
    s.box(210, 70, 210, 64, ["/etc/nsswitch.conf", "hosts: files dns"], RULE, mono_rest=True)
    s.box(210, 220, 210, 64, ["① files = /etc/hosts", "192.168.1.11  db"], GRAY, mono_rest=True)
    s.box(460, 220, 230, 64, ["② 없으면 dns = /etc/resolv.conf", "nameserver 192.168.1.100"], GRAY, mono_rest=True)
    s.box(730, 220, 200, 64, ["내부 DNS 서버", "192.168.1.100"], SVC)
    s.box(730, 80, 200, 64, ["공용 DNS 8.8.8.8", "모르는 이름은 forward"], EXT)
    s.arrow(170, 165, 208, 110, "순서 확인", lx=170, ly=125)
    s.arrow(315, 134, 315, 218)
    s.arrow(420, 252, 458, 252)
    s.arrow(690, 252, 728, 252)
    s.arrow(830, 218, 830, 146, "facebook.com 등", lx=890, ly=185)
    s.text(480, 330, "search mycompany.com 이 있으면 web → web.mycompany.com 으로 붙여서 묻는다", size=14, color=MUTED)
    s.text(480, 356, "nslookup·dig 는 /etc/hosts 를 건너뛰고 DNS 서버에만 묻는다", size=14, color=MUTED)
    s.save("02-name-resolution")


# 03. 네트워크 네임스페이스 + 브리지 + NAT (3장)
def d03():
    s = Svg(960, 520, "3장 · 네임스페이스 두 개를 브리지로 묶고, 호스트를 게이트웨이로 쓴다")
    s.rect(30, 60, 640, 420, NODE); s.label(30, 60, "호스트 (eth0 192.168.1.2)", NODE)
    s.box(70, 110, 200, 80, ["red 네임스페이스", "veth-red", "192.168.15.1"], NS)
    s.box(430, 110, 200, 80, ["blue 네임스페이스", "veth-blue", "192.168.15.2"], NS)
    s.box(180, 260, 340, 70, ["브리지 v-net-0 (가상 스위치)", "호스트 쪽 IP 192.168.15.5"], BR)
    s.arrow(170, 190, 250, 258, "veth-red-br", both=True, lx=160, ly=230)
    s.arrow(530, 190, 450, 258, "veth-blue-br", both=True, lx=560, ly=230)
    s.box(180, 370, 340, 80, ["iptables (nat 테이블)", "POSTROUTING -s 192.168.15.0/24 MASQUERADE", "PREROUTING --dport 80 DNAT 192.168.15.2:80"], RULE, size=13, mono_rest=True)
    s.arrow(350, 330, 350, 368)
    s.box(720, 200, 210, 64, ["LAN 호스트", "192.168.1.3"], NODE)
    s.box(720, 380, 210, 64, ["인터넷", "8.8.8.8"], EXT)
    s.arrow(520, 400, 718, 240)
    s.text(825, 296, "나갈 때 보낸 주소를", size=12, color=MUTED)
    s.text(825, 314, "192.168.1.2 로 바꿈 (MASQUERADE)", size=12, color=MUTED)
    s.arrow(520, 420, 718, 412)
    s.text(800, 110, "blue 라우팅 테이블", size=13, weight=700)
    s.text(800, 132, "192.168.1.0/24 via 192.168.15.5", size=12, mono=True, color=MUTED)
    s.text(800, 152, "default via 192.168.15.5", size=12, mono=True, color=MUTED)
    s.save("03-netns-bridge-nat")


# 04. Docker bridge + 포트 매핑 (4장)
def d04():
    s = Svg(960, 400, "4장 · docker run -p 8080:80 이 하는 일")
    s.box(30, 160, 160, 64, ["외부 사용자", "http://192.168.1.10:8080"], EXT, size=13)
    s.rect(230, 60, 700, 300, NODE); s.label(230, 60, "Docker 호스트 (eth0 192.168.1.10)", NODE)
    s.box(260, 150, 230, 84, ["iptables DOCKER 체인", "dport 8080 →", "DNAT 172.17.0.3:80"], RULE, mono_rest=True)
    s.box(530, 150, 160, 84, ["docker0", "(Docker의 bridge)", "172.17.0.1/16"], BR)
    s.box(740, 140, 170, 104, ["컨테이너 네임스페이스", "eth0@veth", "172.17.0.3", "nginx :80"], NS)
    s.arrow(190, 192, 258, 192)
    s.arrow(490, 192, 528, 192)
    s.arrow(690, 192, 738, 192, "veth 쌍", ly=182)
    s.text(580, 300, "호스트 안에서는 curl 172.17.0.3:80 이 바로 되지만, 밖에서는 8080 매핑을 거쳐야 닿는다", size=13, color=MUTED)
    s.text(580, 324, "none: 네트워크 없음 · host: 호스트 네트워크를 그대로 공유 · bridge: 위 그림 (기본)", size=13, color=MUTED)
    s.save("04-docker-portmap")


# 05. CNI 호출 흐름 (5·8·9장)
def d05():
    s = Svg(960, 470, "5·8·9장 · Pod가 만들어질 때 CNI 플러그인이 불리는 순서")
    s.box(30, 80, 170, 60, ["kubelet", "Pod 만들어라"], NODE)
    s.box(250, 80, 210, 60, ["컨테이너 런타임", "containerd / CRI-O"], NODE)
    s.box(510, 80, 200, 60, ["① 네트워크 네임스페이스", "생성"], NS)
    s.arrow(200, 110, 248, 110)
    s.arrow(460, 110, 508, 110)
    s.box(250, 200, 260, 70, ["② 설정 읽기: /etc/cni/net.d/", "10-flannel.conflist", "(여러 개면 알파벳 순 첫 번째)"], RULE, size=13, mono_rest=False)
    s.box(560, 200, 370, 70, ["③ 실행: /opt/cni/bin/flannel", "ADD <container-id> <netns>", "(이어서 portmap 등 체인)"], BR, size=13)
    s.arrow(355, 140, 375, 198)
    s.arrow(510, 235, 558, 235)
    s.rect(560, 310, 370, 130, NS, dash=True); s.label(560, 310, "플러그인이 하는 일 (7.3의 스크립트와 같음)", NS)
    for i, t in enumerate(["veth 쌍 만들고 한쪽은 Pod, 한쪽은 브리지(cni0)에",
                           "IPAM(host-local / dhcp)에서 빈 IP 받기 → Pod에 붙이기",
                           "기본 게이트웨이 라우트 넣고 인터페이스 켜기",
                           "Pod 삭제 때는 DEL: 인터페이스 지우고 IP 반납"]):
        s.text(578, 352 + i * 22, "· " + t, size=13, anchor="start")
    s.arrow(745, 270, 745, 308)
    s.box(30, 330, 480, 90, ["CNI가 정한 책임 나누기", "런타임: 네임스페이스 만들고, 설정 읽고, 플러그인을 ADD/DEL로 부른다", "플러그인: ADD/DEL/CHECK 지원, 네트워크 연결과 IP 할당을 맡는다"], GRAY, size=13)
    s.save("06-cni-flow")


# 06. Pod 네트워크: 노드마다 브리지 + 라우트 (7장)
def d06():
    s = Svg(960, 500, "7장 · 노드마다 /24 서브넷, 합치면 10.244.0.0/16 하나의 Pod 네트워크")
    xs = [40, 350, 660]
    for i, x in enumerate(xs):
        n = i + 1
        s.rect(x, 60, 260, 250, NODE); s.label(x, 60, f"node{n}  eth0 192.168.1.{10 + n}", NODE)
        s.box(x + 30, 120, 200, 56, [f"Pod 10.244.{n}.2", f"Pod 10.244.{n}.3"], NS, size=13)
        s.box(x + 30, 200, 200, 64, ["브리지 v-net-0", f"10.244.{n}.1/24"], BR)
        s.line(x + 130, 176, x + 130, 200)
        s.line(x + 130, 310, x + 130, 360)
    s.line(170, 360, 790, 360, sw=2.4)
    s.text(650, 352, "노드 네트워크 192.168.1.0/24", size=13, color=MUTED)
    s.box(330, 390, 300, 30, ["라우터 (또는 각 노드의 라우팅 테이블)"], BR, size=13)
    s.line(480, 360, 480, 390)
    s.table(180, 428, [200, 200], [["목적지", "게이트웨이"], ["10.244.1.0/24 · 2.0 · 3.0", "192.168.1.11 · .12 · .13"]], size=12)
    s.arrow(230, 148, 390, 148, "10.244.1.2 → 10.244.2.2", lx=225, ly=112, dash=True)
    s.save("05-pod-network")


# 07. Service와 kube-proxy (10장)
def d07():
    s = Svg(960, 470, "10장 · Service IP는 어디에도 없다. kube-proxy가 심은 iptables 규칙만 있다")
    s.box(370, 60, 220, 56, ["kube-apiserver", "Service 생성 이벤트"], NODE)
    s.rect(30, 150, 430, 270, NODE); s.label(30, 150, "node1", NODE)
    s.rect(500, 150, 430, 270, NODE); s.label(500, 150, "node2", NODE)
    s.box(60, 190, 170, 50, ["kube-proxy", "(DaemonSet)"], NODE, size=13)
    s.box(530, 190, 170, 50, ["kube-proxy", "(DaemonSet)"], NODE, size=13)
    s.arrow(420, 116, 150, 188, "watch", lx=250, ly=140)
    s.arrow(540, 116, 615, 188, "watch", lx=610, ly=140)
    s.box(250, 190, 190, 50, ["db Pod", "10.244.1.2:3306"], NS, size=13)
    s.box(720, 190, 190, 50, ["web Pod", "10.244.2.5"], NS, size=13)
    for x in (60, 530):
        s.box(x, 280, 380, 80, ["iptables nat (모든 노드에 같은 규칙)", "dst 10.103.132.104:3306", "→ DNAT 10.244.1.2:3306"], RULE, size=13, mono_rest=True)
        s.arrow(x + 85, 240, x + 85, 278, "규칙 생성", lx=x + 130, ly=262)
    s.arrow(815, 240, 720, 278, "db-service:3306 로 접속", lx=860, ly=262)
    s.arrow(530, 345, 345, 242, "Pod IP로 전달", dash=True, lx=300, ly=268)
    s.box(30, 430, 430, 30, ["Pod CIDR 10.244.0.0/16 (CNI가 할당)"], NS, size=13)
    s.box(500, 430, 430, 30, ["Service CIDR 10.96.0.0/12 (apiserver가 할당) · 겹치면 안 됨"], SVC, size=13)
    s.save("07-service-kube-proxy")


# 08. 클러스터 DNS (11·12장)
def d08():
    s = Svg(960, 560, "11·12장 · Pod가 web-service 이름을 IP로 바꾸는 길")
    s.box(30, 80, 300, 110, ["test Pod (default 네임스페이스)", "/etc/resolv.conf", "nameserver 10.96.0.10", "search default.svc.cluster.local ..."], NS, size=13, mono_rest=True)
    s.box(390, 100, 190, 70, ["kube-dns Service", "10.96.0.10 :53"], SVC)
    s.rect(640, 60, 290, 210, NODE); s.label(640, 60, "kube-system 네임스페이스", NODE)
    s.box(660, 95, 120, 50, ["CoreDNS", "Pod 1"], EXT, size=13)
    s.box(790, 95, 120, 50, ["CoreDNS", "Pod 2"], EXT, size=13)
    s.box(660, 160, 250, 96, ["ConfigMap coredns", "→ /etc/coredns/Corefile", "kubernetes cluster.local", "pods insecure"], RULE, size=13, mono_rest=True)
    s.arrow(330, 135, 388, 135, "질의")
    s.arrow(580, 135, 658, 120)
    s.box(30, 230, 300, 64, ["kubelet 설정", "clusterDNS 10.96.0.10 · clusterDomain cluster.local"], GRAY, size=13)
    s.arrow(180, 230, 180, 192, "Pod 만들 때 resolv.conf 채움", lx=270, ly=215)
    s.box(660, 290, 270, 50, ["클러스터 밖 이름 (www.google.com)", "→ 노드의 resolv.conf 네임서버로 forward"], EXT, size=12)
    s.arrow(785, 270, 785, 288)
    # FQDN 해부
    s.text(480, 390, "FQDN 해부", size=16, weight=700)
    parts = [("web-service", "Service 이름", SVC), ("apps", "네임스페이스", NS), ("svc", "종류 (svc / pod)", BR), ("cluster.local", "루트 도메인", EXT)]
    x = 110
    for i, (p, d, c) in enumerate(parts):
        w = 150 if i != 3 else 170
        s.box(x, 405, w, 44, [p], c, size=15)
        s.text(x + w / 2, 470, d, size=13, color=MUTED)
        if i < 3:
            s.text(x + w + 10, 433, ".", size=22, weight=700)
        x += w + 20
    s.text(480, 505, "Pod 레코드: 10-244-2-5.apps.pod.cluster.local (IP의 점을 대시로)", size=13, color=MUTED, mono=False)
    s.text(480, 530, "search 줄은 Service용만 있어서 Pod는 FQDN 전체를 적어야 한다", size=13, color=MUTED)
    s.save("08-cluster-dns")


# 09. Ingress (13장)
def d09():
    s = Svg(960, 500, "13장 · 바깥 입구는 하나, 경로에 따라 안쪽 Service로 나눈다")
    s.box(30, 200, 150, 64, ["사용자", "my-online-store.com"], EXT, size=13)
    s.box(220, 200, 150, 64, ["NodePort 또는", "클라우드 LB (한 번만)"], GRAY, size=13)
    s.rect(410, 60, 520, 410, NODE); s.label(410, 60, "클러스터", NODE)
    s.box(440, 180, 200, 104, ["Ingress 컨트롤러", "nginx Deployment", "+ Service + ConfigMap", "+ ServiceAccount"], BR, size=13)
    s.box(440, 330, 200, 104, ["Ingress 리소스 (규칙)", "/wear  → wear-service", "/watch → video-service", "그 밖  → default backend"], RULE, size=12, mono_rest=True)
    s.arrow(540, 330, 540, 286, "watch 해서 nginx 설정", lx=600, ly=314)
    s.arrow(180, 232, 218, 232)
    s.arrow(370, 232, 438, 232)
    s.box(720, 100, 190, 60, ["wear-service", "→ wear Pod들"], SVC, size=13)
    s.box(720, 210, 190, 60, ["video-service", "→ video Pod들"], SVC, size=13)
    s.box(720, 320, 190, 60, ["default-http-backend", "→ 404 페이지"], RED, size=13)
    s.arrow(640, 205, 718, 130, "/wear", lx=660, ly=150)
    s.arrow(640, 232, 718, 240, "/watch")
    s.arrow(640, 260, 718, 350, "기타", lx=708, ly=292)
    s.text(670, 455, "앱이 / 에서만 동작하면 rewrite-target: / , 인증서 없으면 ssl-redirect: \"false\"", size=12, color=MUTED)
    s.save("09-ingress")


# 10. Gateway API (14장)
def d10():
    s = Svg(960, 470, "14장 · Gateway API는 역할마다 객체를 나눈다")
    cols = [("인프라 제공자", 30), ("클러스터 운영자", 340), ("애플리케이션 개발자", 650)]
    for name, x in cols:
        s.text(x + 140, 74, name, size=15, weight=700, color=MUTED)
    s.box(30, 100, 280, 100, ["GatewayClass", "controllerName:", "example.com/gateway-controller", "(nginx, Envoy, Istio ...)"], BR, size=13, mono_rest=True)
    s.box(340, 100, 280, 100, ["Gateway", "gatewayClassName: example-class", "listener https :443", "tls mode: Terminate → Secret"], SVC, size=13, mono_rest=True)
    s.box(650, 100, 280, 100, ["HTTPRoute", "parentRefs: example-gateway", "backendRefs app-v1 weight 80", "backendRefs app-v2 weight 20"], NS, size=13, mono_rest=True)
    s.arrow(338, 150, 312, 150)
    s.arrow(648, 150, 622, 150)
    s.text(325, 178, "참조", size=12, color=MUTED); s.text(635, 178, "참조", size=12, color=MUTED)
    s.box(650, 250, 130, 56, ["app-v1", "80%"], SVC, size=13)
    s.box(800, 250, 130, 56, ["app-v2", "20%"], SVC, size=13)
    s.arrow(740, 200, 715, 248); s.arrow(840, 200, 865, 248)
    s.table(30, 340, [300, 600], [["Ingress에서는", "Gateway API에서는"],
                                  ["nginx annotation force-ssl-redirect", "listener에 HTTPS·tls 명시"],
                                  ["canary·canary-weight annotation", "backendRefs weight 80 / 20"],
                                  ["컨트롤러마다 다른 CORS annotation", "ResponseHeaderModifier 필터 (어디서나 같음)"]],
            color=GRAY, size=13, rowh=24, mono=False)
    s.save("10-gateway-api")


if __name__ == "__main__":
    for f in (d01, d02, d03, d04, d05, d06, d07, d08, d09, d10):
        f()
    print("ok")
