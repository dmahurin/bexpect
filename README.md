**bexpect** is a expect(tcl)-like implementation in bash.

The syntax follows tcl expect except for tcl specific language constructs.

Simple example:

```bash
#!/usr/bin/env bexpect
spawn "/bin/sh"
expect '$ '
send "ls -1 /etc\n"
```

Limitations:

Multi-line expect statements are tcl specific and not supported. expect statements take the form:
```
expect [-re|-ex|-gl] pattern
```

*expect_before* and *expect_after* are tcl specific and not implemented.

To support multiple matches, and similar behavior to *expect_before*/*expect_after*, new statements 'expect_nowait' and 'exp_next' are introduced.

tcl-expect

```tcl
expect {
    "password:" {
        send "password\r"
    } "yes/no)?" {
        send "yes\r"
        timeout -1
    } -re . {
        exp_continue
    } timeout {
        exit
    } eof {
        exit
    }
}
```

bexpect

```bash
while : ; do
    if expect_nowait "password:"; then
        send "password\r"
	break
    elif expect_nowait "yes/no)?"; then
        send "yes\r"
	break
        set timeout=-1
    elif expect_nowait "."; then
	exp_continue
	continue
    fi
    exp_next
}
```

tcl-expect

```tcl
expect_after {
	"username" {
		send "root\n"
		expect "password"
	}
	timeout { exit 1 }
}
expect "password"
```

bexpect

```bash
if ! expect "password"; then
	expect "username"
	send "root\n"
	expect "password"
fi
```
