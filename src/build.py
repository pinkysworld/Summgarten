import pathlib,re
d=pathlib.Path(__file__).parent
inc={k:(d/f"_{k}.html").read_text() for k in("head","nav","foot")}
for p in d.glob("[!_]*.html"):
    t=re.sub(r"<!--(head|nav|foot)-->",lambda m:inc[m.group(1)],p.read_text())
    (d.parent/p.name).write_text(t)
    print(p.name)
