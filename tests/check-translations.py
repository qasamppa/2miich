#!/usr/bin/env python3
"""Every qsTr()/QT_TR_NOOP() string in the QML files must have a finished
Finnish translation in the file's own context (QML uses the file name as
the context). Strings marked with QT_TR_NOOP in the models are translated by
the pages with qsTranslate('<Model>', text), so they live in the model's
context.
"""
import re, sys, glob, os
import xml.etree.ElementTree as ET

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ts = ET.parse(os.path.join(root, 'translations', 'harbour-toomiich-fi.ts')).getroot()
have = {}
for ctx in ts.findall('context'):
    name = ctx.findtext('name')
    for m in ctx.findall('message'):
        tr = m.find('translation')
        done = tr is not None and tr.get('type') not in ('unfinished', 'obsolete', 'vanished') and (tr.text or '') != ''
        have[(name, m.findtext('source'))] = done

pat = re.compile(r"""(?:qsTr|QT_TR_NOOP)\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")\s*\)""")
missing = []
for f in sorted(glob.glob(os.path.join(root, 'qml', '**', '*.qml'), recursive=True)):
    ctx = os.path.splitext(os.path.basename(f))[0]
    for m in pat.finditer(open(f, encoding='utf-8').read()):
        text = (m.group(1) if m.group(1) is not None else m.group(2)).replace("\\'", "'")
        if not have.get((ctx, text)):
            missing.append((ctx, text))

page = open(os.path.join(root, 'qml', 'pages', 'DetailsPage.qml'), encoding='utf-8').read()
if "qsTranslate('GameModel', sectData.text)" not in page:
    missing.append(('DetailsPage', "period headers must use qsTranslate('GameModel', ...)"))

for ctx, text in missing:
    print('missing/unfinished translation: [%s] %r' % (ctx, text))
print('%d problem(s)' % len(missing))
sys.exit(1 if missing else 0)
