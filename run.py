#!/usr/bin/python

import sys
import pty

pty.spawn(sys.argv[1:]);
