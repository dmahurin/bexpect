#!/usr/bin/python
import sys
import select
import time
import fcntl
import os

t = None
if len(sys.argv) > 1:
	t = int(sys.argv[1])
	t = None if t < 0 else t

fd = sys.stdin.fileno()
f = fcntl.fcntl(fd, fcntl.F_GETFL)
fcntl.fcntl(fd, fcntl.F_SETFL, f | os.O_NONBLOCK)

if sys.stdin in select.select([sys.stdin], [], [], t)[0]:
  chunk=sys.stdin.read()
  if(len(chunk) == 0):
    sys.exit(1)
  sys.stdout.write(chunk)

sys.exit(0)
