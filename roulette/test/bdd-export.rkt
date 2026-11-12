#lang racket/base

(require json racket/file racket/list racket/match racket/string rackunit
         (only-in roulette define-measurable*)
         roulette/engine/rsdd
         "../example/blog/export.rkt"
         "blog-test-support.rkt")

;; Evaluate the serialized artifact independently, including skipped variables
;; and complemented pointers. Observations map BDD labels to 0 or 1.
(define (weighted-count artifact [observations (hash)])
  (define diagram (hash-ref artifact 'bdd))
  (define weights (hash-ref artifact 'weights))
  (define nodes (list->vector (hash-ref diagram 'nodes)))
  (define pairs
    (for/vector ([i (in-range (hash-count weights))])
      (hash-ref weights (string->symbol (format "v~a" i)))))
  (define (remaining start end)
    (for/product ([i (in-range start end)])
      (define pair (vector-ref pairs i))
      (if (hash-has-key? observations i)
          (list-ref pair (hash-ref observations i))
          (apply + pair))))
  (define cache (make-hash))
  (define (count edge negated? level)
    (hash-ref!
     cache (list edge negated? level)
     (lambda ()
       (cond
         [(string? edge)
          (if (equal? (equal? edge "True") negated?)
              0.0 (remaining level (vector-length pairs)))]
         [else
          (define pointer (hash-ref edge 'Ptr))
          (define node (vector-ref nodes (hash-ref pointer 'index)))
          (define label (hash-ref node 'topvar))
          (define sign (not (equal? negated? (hash-ref pointer 'compl))))
          (* (remaining level label)
             (for/sum ([truth (if (hash-has-key? observations label)
                                 (list (hash-ref observations label)) '(0 1))])
               (* (list-ref (vector-ref pairs label) truth)
                  (count (hash-ref node (if (= truth 1) 'high 'low))
                         sign (add1 label)))))]))))
  (count (car (hash-ref diagram 'roots)) #f 0))

(define (export source)
  (define path (make-temporary-file "roulette-export-~a.blog"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file path #:exists 'replace
        (lambda (port) (displayln "#lang roulette/example/blog" port) (display source port)))
      (export-blog-bdd path))
    (lambda () (delete-file path))))

(module+ test
  (test-case "joint queries preserve dependence, polarity, and query order"
    (define artifact (export "random Boolean X ~ BooleanDistrib(0.25); query X, !X, X;"))
    (define labels (hash-ref artifact 'queries))
    (match-define (list a b c) labels)
    (check-equal? (length (hash-ref (hash-ref artifact 'bdd) 'roots)) 1)
    (for ([label (in-list labels)])
      (check-equal? (hash-ref (hash-ref artifact 'weights)
                            (string->symbol (format "v~a" label))) '(1.0 1.0)))
    (check-= (weighted-count artifact) 1 1e-12)
    (check-= (weighted-count artifact (hash a 1 b 0 c 1)) 0.25 1e-12)
    (check-= (weighted-count artifact (hash a 0 b 1 c 0)) 0.75 1e-12)
    (check-= (weighted-count artifact (hash a 1 b 1)) 0 1e-12))

  (test-case "observations and dependent distributions retain evidence mass"
    (define artifact
      (export "random Boolean A ~ BooleanDistrib(0.5);
               random Boolean B ~ if A then BooleanDistrib(0.8) else BooleanDistrib(0.2);
               obs B = true; query A, B;"))
    (define a (car (hash-ref artifact 'queries)))
    (define b (cadr (hash-ref artifact 'queries)))
    (check-= (weighted-count artifact) 0.5 1e-12)
    (check-= (weighted-count artifact (hash a 1 b 1)) 0.4 1e-12)
    (check-= (/ (weighted-count artifact (hash a 1)) (weighted-count artifact)) 0.8 1e-12)
    (check-= (weighted-count artifact (hash b 0)) 0 1e-12))

  (test-case "constant queries and impossible evidence"
    (define constants (export "query true, false, true;"))
    (define labels (hash-ref constants 'queries))
    (check-= (weighted-count constants) 1 1e-12)
    (check-= (weighted-count constants (hash (car labels) 0)) 0 1e-12)
    (check-= (weighted-count constants (hash (cadr labels) 0)) 1 1e-12)
    (define impossible
      (export "random Boolean X ~ BooleanDistrib(0.5);
               obs X = true; obs X = false; query X, !X;"))
    (check-= (weighted-count impossible) 0 1e-12))

  (test-case "many queries are compiled without a tuple outcome table"
    (define artifact
      (export (string-append "random Boolean X ~ BooleanDistrib(0.25); query "
                             (string-join (make-list 40 "X") ", ") ";")))
    (check-equal? (length (hash-ref artifact 'queries)) 40)
    (check-true (< (length (hash-ref (hash-ref artifact 'bdd) 'nodes)) 100))
    (check-= (weighted-count artifact) 1 1e-12)
    (check-= (weighted-count artifact (hash (car (hash-ref artifact 'queries)) 1)) 0.25 1e-12))

  (test-case "single-query export and invalid export requests"
    (define artifact (export "random Boolean X ~ BooleanDistrib(0.3); query X;"))
    (check-= (weighted-count artifact (hash (car (hash-ref artifact 'queries)) 1)) 0.3 1e-12)
    (check-exn #rx"Boolean" (lambda () (export "query 2;")))
    (check-exn #rx"one final" (lambda () (export "query true; query false;"))))

  (test-case "normal BLOG query printing is unchanged"
    (define-values (results output)
      (module-results "query true, false;"))
    (check-equal? results '((#t #f))))

  (test-case "unsupported weight semantics are rejected"
    (define-measurable* x (bernoulli-measure 1 1))
    (check-exn #rx"normalized numeric" (lambda () (export-query-bdd (list x))))))
