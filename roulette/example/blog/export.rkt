#lang racket/base

(require json racket/cmdline racket/match racket/path
         (only-in "../blog.rkt" blog-parse)
         (only-in "../disrupt/core.rkt" export-queries))

(provide export-blog-bdd)

(define-namespace-anchor anchor)

(define (export-blog-bdd source)
  ;; Capture the final Boolean query expressions before tuple inference.
  (define forms
    (call-with-input-file source
      (lambda (port)
        (unless (equal? (read-line port 'any) "#lang roulette/example/blog")
          (error 'export-blog-bdd "expected #lang roulette/example/blog"))
        (blog-parse source port))))
  (define-values (model expressions)
    (match forms
      [(list model ... (list 'query expressions ...)) (values model expressions)]
      [_ (error 'export-blog-bdd "expected a final Boolean query statement")]))
  (when (ormap (lambda (form) (eq? (car form) 'query)) model)
    (error 'export-blog-bdd "use one final comma-separated query statement"))
  (define namespace (make-base-namespace))
  (namespace-attach-module (namespace-anchor->namespace anchor)
                           'roulette/example/blog namespace)
  (export-queries
   (lambda ()
     (parameterize ([current-namespace namespace])
       (namespace-require 'roulette/example/blog)
       (for ([form (in-list model)]) (eval form))
       (for/list ([expression (in-list expressions)]) (eval expression))))))

(module+ main
  (command-line
   #:args (source output)
   (when (equal? (simplify-path (path->complete-path source))
                (simplify-path (path->complete-path output)))
     (error 'export-blog-bdd "output must differ from the BLOG source"))
   (define artifact (export-blog-bdd source))
   (call-with-output-file output #:exists 'replace
     (lambda (port) (write-json artifact port)))))
