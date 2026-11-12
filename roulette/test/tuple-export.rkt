#lang racket/base

(require racket/file racket/list rackunit "../example/blog/export.rkt")

(define (export source)
  (define path (make-temporary-file "roulette-tuple-~a.blog"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file path #:exists 'replace
        (lambda (port) (displayln "#lang roulette/example/blog" port) (display source port)))
      (export-blog-joint path))
    (lambda () (delete-file path))))

(define (masses artifact)
  (for/hash ([row (in-list (hash-ref artifact 'outcomes))])
    (values (hash-ref row 'values) (hash-ref row 'probability))))

(module+ test
  (test-case "independent tuple outcomes"
    (define artifact (export "random Boolean A ~ BooleanDistrib(0.25);
                             random Boolean B ~ BooleanDistrib(0.5); query A, B;"))
    (check-equal? (hash-ref artifact 'queries) '(0 1))
    (check-equal? (masses artifact)
                  (hash '(#f #f) 0.375 '(#f #t) 0.375 '(#t #f) 0.125 '(#t #t) 0.125)))
  (test-case "correlated and repeated queries"
    (check-equal? (masses (export "random Boolean X ~ BooleanDistrib(0.25); query X, !X, X;"))
                  (hash '(#f #t #f) 0.75 '(#t #f #t) 0.25)))
  (test-case "observations normalize the joint"
    (define result
      (masses (export "random Boolean A ~ BooleanDistrib(0.5);
                       random Boolean B ~ if A then BooleanDistrib(0.8) else BooleanDistrib(0.2);
                       obs B = true; query A, B;")))
    (check-= (hash-ref result '(#t #t)) 0.8 1e-12)
    (check-= (hash-ref result '(#f #t)) 0.2 1e-12))
  (test-case "constants and impossible evidence"
    (check-equal? (masses (export "query true, false;")) (hash '(#t #f) 1.0))
    (check-equal? (hash-ref (export "random Boolean X ~ BooleanDistrib(0.5);
                                   obs X = true; obs X = false; query X;") 'outcomes) '()))
  (test-case "invalid input"
    (check-exn #rx"Boolean" (lambda () (export "query 2;")))
    (check-exn #rx"one final" (lambda () (export "query true; query false;")))))
