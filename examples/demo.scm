(print "Hello, Lisp") ; "Hello, Lisp"

(define circle-area
  (lambda (r) (* pi (* r r))))
(print (circle-area 3)) ; 28.274

(define fact
  (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))
(print (fact 10)) ; 3628800
(print (circle-area (fact 10))) ; 41369087205782.695

(define first car)
(define rest cdr)
(define count
  (lambda (item L)
    (if L
        (+ (if (equal item (first L)) 1 0) (count item (rest L)))
        0)))

(print (count 0 (list 0 1 2 3 0 0))) ; 3
(print (count (quote the) (quote (the more the merrier the bigger the better)))) ; 4

(define twice (lambda (x) (* 2 x)))
(print (twice 5)) ; 10

(define repeat (lambda (f) (lambda (x) (f (f x)))))
(print ((repeat twice) 10)) ; 40
(print ((repeat (repeat twice)) 10)) ; 160
(print ((repeat (repeat (repeat twice))) 10)) ; 2560
(print ((repeat (repeat (repeat (repeat twice)))) 10)) ; 655360

(print (expt 2 16)) ; 65536

(define fib
  (lambda (n) (if (< n 2) 1 (+ (fib (- n 1)) (fib (- n 2))))))
(define range
  (lambda (a b) (if (= a b) (quote ()) (cons a (range (+ a 1) b)))))
(print (range 0 10)) ; (0 1 2 3 4 5 6 7 8 9)
(print (map fib (range 0 10))) ; (1 1 2 3 5 8 13 21 34 55)
