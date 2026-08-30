#!/bin/sh
# Wraps app.html (the artifact-ready fragment) into a full standalone page.
# PWA-critical tags (manifest link, theme-color, icons) must live in <head> —
# Chrome ignores a manifest linked from <body>.
{
  printf '<!doctype html>\n<html lang="en">\n<head>\n'
  printf '<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
  printf '<meta name="theme-color" content="#A78BDB">\n'
  printf '<title>Streak Buddies</title>\n'
  printf '<link rel="manifest" href="manifest.webmanifest">\n'
  printf '<link rel="icon" type="image/png" href="icons/icon-192.png">\n'
  printf '<link rel="apple-touch-icon" href="icons/icon-192.png">\n'
  printf '</head>\n<body style="margin:0">\n'
  sed -e '/<link rel="manifest"/d' -e '/^<title>/d' app.html
  printf '\n</body>\n</html>\n'
} > index.html
echo "built index.html"
