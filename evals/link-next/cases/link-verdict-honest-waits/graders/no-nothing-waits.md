---
type: regex
weight: 1
---
\n\x60{3,}[ \t]*\n(?:(?!\x60{3})(?![Nn]othing[^\n.]{0,25}(?:wait|ready|need|pending)|[Nn]o items?[^\n.]{0,15}wait)[\s\S])*$
