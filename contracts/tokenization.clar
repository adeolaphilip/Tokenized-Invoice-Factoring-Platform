;; Tokenization Contract
;; This contract converts invoices into tradable digital assets

(define-fungible-token invoice-token)
(define-data-var admin principal tx-sender)

(define-map tokenized-invoices
  { invoice-id: (string-ascii 32) }
  {
    token-id: uint,
    total-supply: uint,
    price-per-token: uint,
    issuer: principal,
    debtor: principal,
    due-date: uint,
    is-paid: bool
  }
)

(define-data-var token-counter uint u0)

(define-read-only (get-tokenized-invoice (invoice-id (string-ascii 32)))
  (map-get? tokenized-invoices { invoice-id: invoice-id })
)

(define-public (tokenize-invoice
    (invoice-id (string-ascii 32))
    (issuer principal)
    (debtor principal)
    (amount uint)
    (due-date uint)
    (token-price uint))
  (let (
      (token-id (var-get token-counter))
      (token-supply (/ amount token-price))
    )
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (asserts! (> token-supply u0) (err u2)) ;; Invalid token supply

    ;; Mint tokens to the issuer
    (try! (ft-mint? invoice-token token-supply issuer))

    ;; Record the tokenized invoice
    (map-set tokenized-invoices
      { invoice-id: invoice-id }
      {
        token-id: token-id,
        total-supply: token-supply,
        price-per-token: token-price,
        issuer: issuer,
        debtor: debtor,
        due-date: due-date,
        is-paid: false
      }
    )

    ;; Increment token counter
    (var-set token-counter (+ token-id u1))

    (ok token-id)
  )
)

(define-public (transfer-tokens (recipient principal) (amount uint))
  (ft-transfer? invoice-token amount tx-sender recipient)
)

(define-public (mark-invoice-paid (invoice-id (string-ascii 32)))
  (let ((invoice (unwrap! (get-tokenized-invoice invoice-id) (err u3)))) ;; Invoice not found
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (asserts! (not (get is-paid invoice)) (err u4)) ;; Invoice already paid

    (map-set tokenized-invoices
      { invoice-id: invoice-id }
      (merge invoice { is-paid: true })
    )
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Not authorized
    (var-set admin new-admin)
    (ok true)
  )
)

