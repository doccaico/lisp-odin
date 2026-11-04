### lisp-odin (Tested on Windows)
A very simple Lisp. It is a implementation in Odin.
### Odin version
```
$ odin version
odin version dev-2026-11-nightly:9a69916
```
### Run
```sh
# REPL
$ odin run . -- -r

# load a file
$ odin run . -- examples\demo.scm
```

### Load a file in REPL
```
lisp-odin> (:load "examples\\demo.scm")
"Hello, Lisp"
28.274333882308138
3628800
41369087205782.695
3
4
10
40
160
2560
655360
65536
(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
(1, 1, 2, 3, 5, 8, 13, 21, 34, 55)
```
