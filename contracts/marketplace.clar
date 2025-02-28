;; marketplace.clar
;; Core contract for the NeuralNexus AI Training Marketplace
;; Handles dataset registration, training job creation, and marketplace operations

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u402))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-PARAMETERS (err u400))
(define-constant ERR-PAYMENT-FAILED (err u500))
(define-constant ERR-INSUFFICIENT-FUNDS (err u501))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant PLATFORM-FEE-PERCENT u3) ;; 3% platform fee

;; Data structures
;; Dataset represents training data offered on the marketplace
(define-map datasets
  { dataset-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    metadata-url: (string-utf8 256),  ;; URL to encrypted metadata about the dataset
    price-per-use: uint,              ;; Price in microSTX
    access-count: uint,               ;; Number of times this dataset has been used
    active: bool,                     ;; Whether this dataset is available for use
    created-at: uint,                 ;; Block height when created
    category: (string-ascii 50)       ;; Category/domain of the dataset
  }
)

;; Training job represents a request to train a model using specified datasets
(define-map training-jobs
  { job-id: uint }
  {
    creator: principal,
    name: (string-ascii 100),
    datasets: (list 20 uint),         ;; List of dataset IDs to use
    computation-provider: (optional principal),  ;; Who will run the computation
    status: (string-ascii 20),        ;; "pending", "processing", "completed", "failed"
    result-url: (optional (string-utf8 256)),  ;; URL to the trained model (encrypted)
    total-cost: uint,                 ;; Total cost in microSTX
    created-at: uint,                 ;; Block height when created
    completed-at: (optional uint)     ;; Block height when completed
  }
)

;; Storage for user balances in the marketplace
(define-map user-balances
  { user: principal }
  { balance: uint }
)

;; Global counters
(define-data-var last-dataset-id uint u0)
(define-data-var last-job-id uint u0)


;; Read-only functions

;; Get dataset details
(define-read-only (get-dataset (dataset-id uint))
  (map-get? datasets { dataset-id: dataset-id })
)

;; Get training job details
(define-read-only (get-training-job (job-id uint))
  (map-get? training-jobs { job-id: job-id })
)

;; Get user's current balance in the marketplace
(define-read-only (get-user-balance (user principal))
  (default-to { balance: u0 } (map-get? user-balances { user: user }))
)

;; Get platform fee percentage
(define-read-only (get-platform-fee)
  PLATFORM-FEE-PERCENT
)


;; Public functions

;; Register a new dataset on the marketplace
(define-public (register-dataset 
    (name (string-ascii 100)) 
    (metadata-url (string-utf8 256)) 
    (price-per-use uint)
    (category (string-ascii 50)))
  (let 
    (
      (new-id (+ (var-get last-dataset-id) u1))
      (block-height block-height)
    )
    ;; Create the new dataset entry
    (map-set datasets
      { dataset-id: new-id }
      {
        owner: tx-sender,
        name: name,
        metadata-url: metadata-url,
        price-per-use: price-per-use,
        access-count: u0,
        active: true,
        created-at: block-height,
        category: category
      }
    )
    ;; Update the counter
    (var-set last-dataset-id new-id)
    ;; Return success with the new dataset ID
    (ok new-id)
  )
)

;; Update dataset information
(define-public (update-dataset 
    (dataset-id uint) 
    (name (string-ascii 100)) 
    (metadata-url (string-utf8 256)) 
    (price-per-use uint)
    (active bool)
    (category (string-ascii 50)))
  (let 
    (
      (dataset (unwrap! (map-get? datasets { dataset-id: dataset-id }) ERR-NOT-FOUND))
    )
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner dataset)) ERR-NOT-AUTHORIZED)
    
    ;; Update the dataset
    (map-set datasets
      { dataset-id: dataset-id }
      (merge dataset {
        name: name,
        metadata-url: metadata-url,
        price-per-use: price-per-use,
        active: active,
        category: category
      })
    )
    (ok true)
  )
)

;; Create a new training job
(define-public (create-training-job
    (name (string-ascii 100))
    (dataset-ids (list 20 uint)))
  (let 
    (
      (new-id (+ (var-get last-job-id) u1))
      (block-height block-height)
      (total-cost (fold calculate-job-cost dataset-ids u0))
      (user-balance (get balance (get-user-balance tx-sender)))
    )
    ;; Validate all datasets exist and are active
    (asserts! (fold validate-datasets dataset-ids true) ERR-NOT-FOUND)

    ;; Check if user has enough balance
    (asserts! (>= user-balance total-cost) ERR-INSUFFICIENT-FUNDS)

    ;; Create the job
    (map-set training-jobs
      { job-id: new-id }
      {
        creator: tx-sender,
        name: name,
        datasets: dataset-ids,
        computation-provider: none,
        status: "pending",
        result-url: none,
        total-cost: total-cost,
        created-at: block-height,
        completed-at: none
      }
    )

    ;; Deduct balance from user
    (map-set user-balances 
      { user: tx-sender }
      { balance: (- user-balance total-cost) }
    )

    ;; Update the job counter
    (var-set last-job-id new-id)

    ;; Return success with the new job ID
    (ok new-id)
  )
)


;; Initialize contract
(begin
  (var-set last-dataset-id u0)
)
