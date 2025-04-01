;; Payment Distribution Contract
;; This contract handles funds when invoices are paid

(define-data-var admin principal tx-sender)

(define-map payments
  { invoice-id: (string-ascii 32) }
  {
    total-amount: uint,
    paid-amount: uint,
    payment-date: uint,
    is-fully-paid: bool
  }
)

(define-map token-holder-payments
  { invoice-id: (string-ascii 32), token-holder: principal }
  { amount-claimed: uint }
)

(define-read-only (get-payment-info (invoice-id (string-ascii 32)))
  (map-get? payments { invoice-id: invoice-id })
)

(define-read-only (get-holder-payment (invoice-id (string-ascii 32)) (token-holder principal))
  (map-get? token-holder-payments
    { invoice-id: invoice-id, token-holder: token-holder }
  )
)

(define-public (record-payment (invoice-id (string-ascii 32)) (amount uint))
  (let (
      (payment-info (default-to
        { total-amount: u0, paid-amount: u0, payment-date: u0, is-fully-paid: false }
        (get-payment-info invoice-id)))
      (new-paid-amount (+ (get paid-amount payment-info) amount))
      (is-fully-paid (>= new-paid-amount (get total-amount payment-info)))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized

    (map-set payments
      { invoice-id: invoice-id }
      {
        total-amount: (get total-amount payment-info),
        paid-amount: new-paid-amount,
        payment-date: (unwrap-panic (get-block-info? time u0)),
        is-fully-paid: is-fully-paid
      }
    )
    (ok is-fully-paid)
  )
)

(define-public (register-invoice-total (invoice-id (string-ascii 32)) (total-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (asserts! (is-none (get-payment-info invoice-id)) (err u2)) ;; Invoice already registered

    (map-set payments
      { invoice-id: invoice-id }
      {
        total-amount: total-amount,
        paid-amount: u0,
        payment-date: u0,
        is-fully-paid: false
      }
    )
    (ok true)
  )
)

(define-public (claim-payment
    (invoice-id (string-ascii 32))
    (token-amount uint)
    (total-tokens uint))
  (let (
      (payment-info (unwrap! (get-payment-info invoice-id) (err u3))) ;; Payment not found
      (holder-info (default-to
        { amount-claimed: u0 }
        (get-holder-payment invoice-id tx-sender)))
      (payment-share (/ (* (get paid-amount payment-info) token-amount) total-tokens))
    )
    (asserts! (> payment-share u0) (err u4)) ;; No payment to claim
    (asserts! (is-eq (get amount-claimed holder-info) u0) (err u5)) ;; Already claimed

    ;; Record the claim
    (map-set token-holder-payments
      { invoice-id: invoice-id, token-holder: tx-sender }
      { amount-claimed: payment-share }
    )

    ;; In a real implementation, this would transfer STX to the token holder
    (ok payment-share)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (var-set admin new-admin)
    (ok true)
  )
)

