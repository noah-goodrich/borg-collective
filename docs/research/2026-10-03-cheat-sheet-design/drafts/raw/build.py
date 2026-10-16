import re
from cards_a import CARDS,B,W,DIMS
import cards_b
def norm(s): return re.sub(r'\s+',' ',s.replace(' ',' ')).strip()
bands={}
for c in CARDS:
    avg=sum(a*b for a,b in zip(c['s'],W))
    band='keep' if avg>=7.0 else 'borderline' if avg>=5.0 else 'reject'
    c['avg']=avg;c['band']=band
    ov={'torre-lieberman-2018-review':'Supporting','brownstone-2024-ifs-problematic-popularity':'Supporting','ford-parnin-2015-frustration-categories':'Supporting','ko-myers-aung-2004-learning-barriers':'Supporting','aan-willcox-feeling-wheel':'Supporting','wahba-2026-affect-labeling-meta-zenodo':'Supporting','dulwich-centre-what-is-narrative-therapy':'Excluded','substack-2026-audhd-alexithymia':'Excluded'}
    if c['slug'] in ov: c['dec']=ov[c['slug']]
    if c['band']=='reject' and c['dec']!='Excluded': c['dec']='Excluded'
    if c['band']=='borderline': c['rat']='BORDERLINE-INCLUDED (gap-fill, documented). '+c['rat']
    if c['dec']=='Excluded' and not c['rat'].startswith(('Reject','EXCLUDED')): c['rat']='EXCLUDED: reject band (weighted avg below 5.0); retained as a card to make the cut visible. '+c['rat']
    src=c['qfile']
    path=B+'drafts/adapter/snapshots/'+src[8:] if src.startswith('ADAPTER:') else B+'drafts/raw/'+src
    txt=norm(open(path,errors='ignore').read())
    bad=[q for q in c['quotes'] if norm(q) not in txt]
    c['bad']=bad
    rows="\n".join(f"| {i+1} | {d} | {s}/10 | {j} |" for i,(d,s,j) in enumerate(zip(DIMS,c['s'],c['j'])))
    out=f"""# Source: {c['title']}

**Full citation:** {c['cite']}
**URL:** {c['url']}
**Date accessed:** 2026-10-03
**Evidence level:** {c['level']}
**Research topic area:** C2 naming & vocabulary - {c['area']}

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
{rows}

**Score band:** {c['band']}  (intermediate weighted average ~{avg:.1f}; band is the disposition)

## Bias Guard Check

- [{'x' if 'agree-ish' in c['bias'] or c['bias'].startswith('agree') else ' '}] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [{'x' if c['bias'].startswith('disagree') else ' '}] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [{'x' if c['bias']=='neutral' else ' '}] Neutral / no strong reaction

## Key Findings

""" + "\n".join("- "+f for f in c['findings']) + f"""

## Verified Quote(s)

**Location reference:** {c['loc']}

""" + "\n\n".join("> "+q for q in c['quotes']) + f"""

**Access status:** {c['access']}

## Inclusion Decision

**Decision:** {c['dec']}
**Rationale:** {c['rat']}

**Redundancy check:** {c['red']}

**Perspective category:** {c['persp']}
"""
    open(B+f"sources/c2-{c['slug']}.md",'w').write(out)
    print(f"{c['slug']:50s} {c['band']:10s} {avg:.2f} {c['persp']:20s} {c['access']:14s} BADQ={len(bad)}")
    for q in bad: print('   MISSING:',q[:90])
