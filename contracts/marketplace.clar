;; marketplace.clar - Basic Version
;; Core contract for the NeuralNexus AI Training Marketplace

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
;; Dataset represents training data offered on the marketplace
(define-map datasets
  { dataset-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    metadata-url: (string-utf8 256),  ;; URL to encrypted metadata about the dataset
    price-per-use: uint,              ;; Price in microSTX
    active: bool                      ;; Whether this dataset is available for use
  }
)

;; Global counter
(define-data-var last-dataset-id uint u0)

;; Read-only functions

;; Get dataset details
(define-read-only (get-dataset (dataset-id uint))
  (map-get? datasets { dataset-id: dataset-id })
)
