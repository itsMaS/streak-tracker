#!/bin/sh
# Wraps app.html (the artifact-ready fragment) into a full standalone page.
{
  printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<meta name="theme-color" content="#F26089">\n</head>\n<body style="margin:0">\n'
  cat app.html
  printf '\n</body>\n</html>\n'
} > index.html
echo "built index.html"
