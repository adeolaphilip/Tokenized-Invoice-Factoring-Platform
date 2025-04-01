;; Invoice Verification Contract
;; This contract validates the legitimacy of submitted invoices

(define-data-var admin principal tx-sender)

;; Invoice status: 0 = pending, 1 = verified, 2 = rejected
(define-map invoices
  { invoice-id: (string-ascii 32) }
  {
    issuer: principal,
    debtor: principal,
    amount: uint,
    due-date: uint,
    status: uint,
    verification-date: uint
  }
)

(define-read-only (get-invoice (invoice-id (string-ascii 32)))
  (map-get? invoices { invoice-id: invoice-id })
)

(define-public (submit-invoice
    (invoice-id (string-ascii 32))
    (debtor principal)
    (amount uint)
    (due-date uint))
  (let ((issuer tx-sender))
    (if (map-insert invoices
          { invoice-id: invoice-id }
          {
            issuer: issuer,
            debtor: debtor,
            amount: amount,
            due-date: due-date,
            status: u0,
            verification-date: u0
          })
        (ok true)
        (err u1) ;; Invoice ID already exists
    )
  )
)

(define-public (verify-invoice (invoice-id (string-ascii 32)))
  (let ((invoice (unwrap! (get-invoice invoice-id) (err u2)))) ;; Invoice not found
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Not authorized
    (asserts! (is-eq (get status invoice) u0) (err u4)) ;; Invoice not in pending status

    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice {
        status: u1,
        verification-date: (unwrap-panic (get-block-info? time u0))
      })
    )
    (ok true)
  )
)

(define-public (reject-invoice (invoice-id (string-ascii 32)))
  (let ((invoice (unwrap! (get-invoice invoice-id) (err u2)))) ;; Invoice not found
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Not authorized
    (asserts! (is-eq (get status invoice) u0) (err u4)) ;; Invoice not in pending status

    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice {
        status: u2,
        verification-date: (unwrap-panic (get-block-info? time u0))
      })
    )
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Not authorized
    (var-set admin new-admin)
    (ok true)
  )
)

