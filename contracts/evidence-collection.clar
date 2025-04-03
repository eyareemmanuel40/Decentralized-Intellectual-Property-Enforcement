;; Evidence Collection Contract
;; Securely stores proof of violations

;; Data Maps
(define-map evidence-records
  { evidence-id: (string-utf8 36) }
  {
    submitter: principal,
    description: (string-utf8 500),
    submission-date: uint,
    content-hash: (buff 32),
    evidence-type: (string-utf8 20),
    url: (optional (string-utf8 255))
  }
)

(define-map user-evidence
  { user: principal }
  { evidence-ids: (list 100 (string-utf8 36)) }
)

;; Error Codes
(define-constant ERR-NOT-FOUND u1)
(define-constant ERR-UNAUTHORIZED u2)
(define-constant ERR-ALREADY-EXISTS u3)

;; Public Functions
(define-public (submit-evidence
    (evidence-id (string-utf8 36))
    (description (string-utf8 500))
    (content-hash (buff 32))
    (evidence-type (string-utf8 20))
    (url (optional (string-utf8 255))))
  (let
    ((submission-date (get-block-info? time (- block-height u1))))

    ;; Check if evidence already exists
    (asserts! (is-none (map-get? evidence-records { evidence-id: evidence-id })) (err ERR-ALREADY-EXISTS))

    ;; Insert the evidence record
    (map-set evidence-records
      { evidence-id: evidence-id }
      {
        submitter: tx-sender,
        description: description,
        submission-date: (default-to u0 submission-date),
        content-hash: content-hash,
        evidence-type: evidence-type,
        url: url
      }
    )

    ;; Update user's evidence list
    (match (map-get? user-evidence { user: tx-sender })
      existing-entry (map-set user-evidence
                      { user: tx-sender }
                      { evidence-ids: (unwrap-panic (as-max-len? (append (get evidence-ids existing-entry) evidence-id) u100)) })
      (map-set user-evidence
        { user: tx-sender }
        { evidence-ids: (list evidence-id) })
    )

    (ok evidence-id)
  )
)

(define-public (update-evidence
    (evidence-id (string-utf8 36))
    (description (string-utf8 500))
    (url (optional (string-utf8 255))))
  (let
    ((evidence-data (unwrap! (map-get? evidence-records { evidence-id: evidence-id }) (err ERR-NOT-FOUND))))

    ;; Check if sender is the submitter
    (asserts! (is-eq tx-sender (get submitter evidence-data)) (err ERR-UNAUTHORIZED))

    ;; Update evidence record
    (map-set evidence-records
      { evidence-id: evidence-id }
      (merge evidence-data {
        description: description,
        url: url
      })
    )

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-evidence-details (evidence-id (string-utf8 36)))
  (map-get? evidence-records { evidence-id: evidence-id })
)

(define-read-only (get-user-evidence (user principal))
  (map-get? user-evidence { user: user })
)

(define-read-only (verify-evidence-hash
    (evidence-id (string-utf8 36))
    (hash-to-verify (buff 32)))
  (match (map-get? evidence-records { evidence-id: evidence-id })
    evidence-data (ok (is-eq (get content-hash evidence-data) hash-to-verify))
    (err ERR-NOT-FOUND)
  )
)

