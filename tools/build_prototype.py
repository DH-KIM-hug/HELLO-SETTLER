"""prototype/app.html(게시용 본문)을 prototype/index.html(브라우저에서 바로 여는 파일)로 감싼다."""
import os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prototype")
body = open(os.path.join(root, "app.html"), encoding="utf-8").read()
head = """<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;font:14px system-ui,sans-serif}[hidden]{display:none!important}</style>
</head>
<body>
<!-- 생성 파일: 수정은 prototype/app.html 에서 하고 python3 tools/build_prototype.py 로 다시 만드세요 -->
"""
open(os.path.join(root, "index.html"), "w", encoding="utf-8").write(head + body + "\n</body>\n</html>\n")
print("ok")
