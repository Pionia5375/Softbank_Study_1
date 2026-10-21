#!/usr/bin/env python3
"""용어 주석(.t / aside.notes) 짝 검사. 사용: python3 -I notes-check.py <html 파일>...
규칙:
 - 본문 .t 는 문서 순서대로 번호가 붙고, 그 뒤 처음 나오는 aside.notes 의 dt 들이 같은 순서로 짝이 된다.
 - aside.notes 는 .t 가 든 블록(p, ul/ol, .table-wrap, figure, dl, blockquote) 바로 뒤 형제이거나, .callout 안이면 그 callout 의 마지막 자식이어야 한다.
 - aside 하나가 소비하는 .t 수 == 그 aside 의 dt 수. aside 사이에 떠도는 .t 가 없어야 한다.
 - .t 는 h1~h4, nav, pre, svg, .chip, dl.terms, aside.notes 안에 두지 않는다. .t 안에 .t 금지.
 - 같은 용어를 한 장에서 두 번 .t 로 표시하면 경고.
 - dt 와 .t 글자가 느슨하게라도 맞아야 한다(한쪽이 다른 쪽을 포함)."""
import sys, re, html
from html.parser import HTMLParser

VOID={'meta','link','br','img','hr','input','path','rect','circle','line','ellipse','polygon','polyline','stop','use','source','wbr'}
class N:
    __slots__=('tag','attrs','kids','parent','line','text')
    def __init__(s,tag,attrs,parent,line): s.tag=tag; s.attrs=dict(attrs); s.kids=[]; s.parent=parent; s.line=line; s.text=''
    def cls(s): return s.attrs.get('class','').split()
    def has(s,c): return c in s.cls()
    def anc(s,pred):
        p=s.parent
        while p:
            if pred(p): return p
            p=p.parent
        return None
    def walk(s):
        yield s
        for k in s.kids:
            if isinstance(k,N): yield from k.walk()
    def txt(s): return ''.join(k if isinstance(k,str) else k.txt() for k in s.kids)
    def elkids(s): return [k for k in s.kids if isinstance(k,N)]
class P(HTMLParser):
    def __init__(s): super().__init__(convert_charrefs=True); s.root=N('#root',{},None,0); s.cur=s.root
    def handle_starttag(s,t,a):
        n=N(t,a,s.cur,s.getpos()[0]); s.cur.kids.append(n)
        if t not in VOID: s.cur=n
    def handle_startendtag(s,t,a): s.cur.kids.append(N(t,a,s.cur,s.getpos()[0]))
    def handle_endtag(s,t):
        c=s.cur
        while c and c.tag!=t: c=c.parent
        if c and c.parent: s.cur=c.parent
    def handle_data(s,d): s.cur.kids.append(d)

def norm(x): return re.sub(r'\s+','',re.sub(r'[（(].*?[)）]','',x)).lower()

def check(path):
    s=open(path,encoding='utf-8').read()
    p=P(); p.feed(s); root=p.root
    main=next((n for n in root.walk() if n.tag=='main'),root)
    errs=[]; warns=[]
    BAD={'h1','h2','h3','h4','nav','pre','svg','code'}
    pending=[]; seen={}; nt=0; na=0; nd=0; pairs=0
    for n in main.walk():
        if n.tag=='span' and n.has('t'):
            nt+=1
            bad=n.anc(lambda a:a.tag in ('h1','h2','h3','h4','nav','pre','svg') or a.has('chip') or (a.tag=='dl' and a.has('terms')) or (a.tag=='aside' and a.has('notes')) or (a.tag=='span' and a.has('t')))
            if bad: errs.append((n.line,f'.t "{n.txt().strip()}" 이 {bad.tag}.{".".join(bad.cls())} 안에 있음'))
            k=norm(n.txt())
            if k in seen: warns.append((n.line,f'.t "{n.txt().strip()}" 이 {seen[k]}행에 이어 두 번째'))
            else: seen[k]=n.line
            pending.append(n)
        elif n.tag=='aside' and n.has('notes'):
            na+=1
            divs=[d for d in n.elkids() if d.tag=='dl']
            items=[]
            for dl in divs:
                for d in dl.elkids():
                    if d.tag=='div': items.append(d)
                    elif d.tag=='dt': errs.append((d.line,'dt 가 <div> 로 안 싸여 있음 (dl > div > dt+dd)'))
            dts=[]
            for d in items:
                dt=[k for k in d.elkids() if k.tag=='dt']; dd=[k for k in d.elkids() if k.tag=='dd']
                if len(dt)!=1 or len(dd)!=1: errs.append((d.line,'div 안에 dt 하나 + dd 하나가 아님'))
                else: dts.append(dt[0])
            nd+=len(dts)
            # 붙은 자리
            par=n.parent; sib=par.elkids(); i=sib.index(n)
            if par.has('callout'):
                if i!=len(sib)-1: errs.append((n.line,'callout 안의 aside.notes 는 callout 의 마지막 자식이어야 함'))
                holder=par
            else:
                prev=sib[i-1] if i>0 else None
                if prev is None or prev.tag not in ('p','ul','ol','div','figure','dl','blockquote','table') or (prev.tag=='div' and not (prev.has('table-wrap') or prev.has('grid') or prev.has('fig'))):
                    errs.append((n.line,f'aside.notes 앞 형제가 본문 블록이 아님: {prev.tag if prev else None}.{".".join(prev.cls()) if prev else ""}'))
                holder=prev
            # 짝 맞춤
            if len(pending)!=len(dts):
                errs.append((n.line,f'이 aside 의 dt {len(dts)}개 vs 직전부터 쌓인 .t {len(pending)}개: '+', '.join(t.txt().strip() for t in pending)+' | dt: '+', '.join(d.txt().strip() for d in dts)))
            for t,d in zip(pending,dts):
                a,b=norm(t.txt()),norm(d.txt())
                if not (a and b and (a in b or b in a)): warns.append((d.line,f'dt "{d.txt().strip()}" 와 .t "{t.txt().strip()}" 가 안 맞아 보임'))
                if holder is not None and not (t is holder or t.anc(lambda x:x is holder)): errs.append((t.line,f'.t "{t.txt().strip()}" 가 주석이 붙은 블록 밖에 있음'))
                dd=[k for k in d.parent.elkids() if k.tag=='dd']
                if dd and len(dd[0].txt().strip())>220: warns.append((dd[0].line,f'dd 가 김({len(dd[0].txt().strip())}자): "{d.txt().strip()}"'))
                pairs+=1
            pending=[]
    if pending: errs.append((pending[0].line,f'마지막 aside 뒤에 남은 .t {len(pending)}개: '+', '.join(t.txt().strip() for t in pending)))
    # 아직 문장 안에 남은 괄호 설명 후보 (휴리스틱)
    cand=[]
    for n in main.walk():
        if n.tag in ('p','li','dd','td','figcaption') and not n.anc(lambda a:a.tag=='aside' and a.has('notes')):
            t=n.txt()
            for m in re.finditer(r'[가-힣A-Za-z][^()]{0,30}\(([^()]{28,})\)',t):
                inner=m.group(1)
                if re.search(r'[가-힣]',inner) and not re.search(r'^\d|^https?://|그림|표 \d|장\)|README|예:|예\)',inner):
                    cand.append((n.line,m.group(0)[:90]))
    print(f'{path}: .t {nt}  aside {na}  dt {nd}  짝 {pairs}  오류 {len(errs)}  경고 {len(warns)}  남은 괄호설명 후보 {len(cand)}')
    for l,e in errs: print(f'  ERR  L{l}: {e}')
    for l,w in warns[:40]: print(f'  WARN L{l}: {w}')
    if len(warns)>40: print(f'  ... 경고 {len(warns)-40}개 더')
    for l,c in cand[:25]: print(f'  CAND L{l}: {c}')
    if len(cand)>25: print(f'  ... 후보 {len(cand)-25}개 더')
    return len(errs)
if __name__=='__main__':
    sys.exit(1 if sum(check(p) for p in sys.argv[1:]) else 0)
