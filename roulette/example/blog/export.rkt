#lang racket/base

(require json racket/cmdline racket/match racket/path
         (only-in rosette [boolean? symbolic-boolean?])
         (only-in "../blog.rkt" blog-parse)
         (only-in "../disrupt/core.rkt" query pmf-hash))

(provide export-blog-joint)

(define-namespace-anchor anchor)

(define (export-blog-joint source)
  ;; Use ordinary tuple inference, including its outcome enumeration and WMC.
  (define forms
    (call-with-input-file source
      (lambda (port)
        (unless (equal? (read-line port 'any) "#lang roulette/example/blog")
          (error 'export-blog-joint "expected #lang roulette/example/blog"))
        (blog-parse source port))))
  (define-values (model expressions)
    (match forms
      [(list model ... (list 'query expressions ...)) (values model expressions)]
      [_ (error 'export-blog-joint "expected a final Boolean query statement")]))
  (when (ormap (lambda (form) (eq? (car form) 'query)) model)
    (error 'export-blog-joint "use one final comma-separated query statement"))
  (define namespace (make-base-namespace))
  (namespace-attach-module (namespace-anchor->namespace anchor)
                           'roulette/example/blog namespace)
  (define distribution
    (pmf-hash
     (query
      (parameterize ([current-namespace namespace])
        (namespace-require 'roulette/example/blog)
        (for ([form (in-list model)]) (eval form))
        (define values (for/list ([expression (in-list expressions)]) (eval expression)))
        (unless (andmap symbolic-boolean? values)
          (error 'export-blog-joint "expected Boolean queries"))
        values))))
  (hasheq 'queries (for/list ([i (in-range (length expressions))]) i)
          'outcomes (for/list ([(values probability) (in-hash distribution)])
                      (hasheq 'values values 'probability (exact->inexact probability)))))

(module+ main
  (command-line
   #:args (source output)
   (when (equal? (simplify-path (path->complete-path source))
                (simplify-path (path->complete-path output)))
     (error 'export-blog-joint "output must differ from the BLOG source"))
   (define artifact (export-blog-joint source))
   (call-with-output-file output #:exists 'replace
     (lambda (port) (write-json artifact port)))))
