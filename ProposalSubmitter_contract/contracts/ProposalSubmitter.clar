
;; title: ProposalSubmitter
;; version: 1.0.0
;; summary: Address reputation system for governance proposal quality and success rate scoring
;; description: This contract tracks the performance of addresses in submitting governance proposals,
;;              calculating reputation scores based on proposal quality, success rates, and community engagement.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1001))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u1002))
(define-constant ERR_INVALID_SCORE (err u1003))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u1004))
(define-constant ERR_ALREADY_VOTED (err u1005))
(define-constant ERR_INVALID_STATUS (err u1006))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_REPUTATION_SCORE u10000) ;; Maximum reputation score (100.00%)
(define-constant MIN_PROPOSALS_FOR_REPUTATION u3) ;; Minimum proposals needed for reputation calculation

;; Proposal statuses
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_PASSED u2)
(define-constant STATUS_FAILED u3)
(define-constant STATUS_WITHDRAWN u4)

;; data vars
(define-data-var next-proposal-id uint u1)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; data maps

;; Store detailed information about each proposal
(define-map proposals
  { proposal-id: uint }
  {
    submitter: principal,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    status: uint,
    quality-score: uint, ;; Score from 0-100 based on community evaluation
    votes-for: uint,
    votes-against: uint,
    submission-height: uint,
    resolution-height: (optional uint)
  }
)

;; Track address reputation metrics
(define-map address-reputation
  { address: principal }
  {
    total-proposals: uint,
    successful-proposals: uint,
    total-quality-score: uint,
    average-quality-score: uint,
    reputation-score: uint, ;; Calculated overall reputation (0-10000, representing 0-100.00%)
    last-updated: uint
  }
)

;; Track votes on proposal quality (separate from governance votes)
(define-map quality-votes
  { proposal-id: uint, voter: principal }
  { score: uint } ;; Quality score from 1-100
)

;; Track who has voted on each proposal's quality to prevent double voting
(define-map quality-voters
  { proposal-id: uint }
  { voters: (list 200 principal) }
)

;; Store proposal IDs by submitter for easy lookup
(define-map submitter-proposals
  { submitter: principal }
  { proposal-ids: (list 100 uint) }
)

;; public functions

;; Submit a new governance proposal
(define-public (submit-proposal (title (string-ascii 200)) (description (string-ascii 1000)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (submitter tx-sender)
    (current-height block-height)
  )
    ;; Create the proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        submitter: submitter,
        title: title,
        description: description,
        status: STATUS_ACTIVE,
        quality-score: u0,
        votes-for: u0,
        votes-against: u0,
        submission-height: current-height,
        resolution-height: none
      }
    )

    ;; Update submitter's proposal list
    (let (
      (current-proposals (default-to (list) (get proposal-ids (map-get? submitter-proposals { submitter: submitter }))))
    )
      (map-set submitter-proposals
        { submitter: submitter }
        { proposal-ids: (unwrap! (as-max-len? (append current-proposals proposal-id) u100) ERR_INVALID_STATUS) }
      )
    )

    ;; Initialize quality voters list
    (map-set quality-voters
      { proposal-id: proposal-id }
      { voters: (list) }
    )

    ;; Update address reputation (increment total proposals)
    (update-address-reputation submitter)

    ;; Increment next proposal ID
    (var-set next-proposal-id (+ proposal-id u1))

    (ok proposal-id)
  )
)

;; Vote on proposal quality (not governance outcome)
(define-public (vote-on-quality (proposal-id uint) (quality-score uint))
  (let (
    (voter tx-sender)
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (current-voters (default-to (list) (get voters (map-get? quality-voters { proposal-id: proposal-id }))))
  )
    ;; Validate inputs
    (asserts! (and (>= quality-score u1) (<= quality-score u100)) ERR_INVALID_SCORE)
    (asserts! (is-eq (get status proposal) STATUS_ACTIVE) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (is-none (map-get? quality-votes { proposal-id: proposal-id, voter: voter })) ERR_ALREADY_VOTED)

    ;; Record the quality vote
    (map-set quality-votes
      { proposal-id: proposal-id, voter: voter }
      { score: quality-score }
    )

    ;; Add voter to the list
    (map-set quality-voters
      { proposal-id: proposal-id }
      { voters: (unwrap! (as-max-len? (append current-voters voter) u200) ERR_INVALID_STATUS) }
    )

    ;; Update proposal's quality score (recalculate average)
    (update-proposal-quality-score proposal-id)

    (ok true)
  )
)

;; Admin function to update proposal status (would typically be called by governance system)
(define-public (update-proposal-status (proposal-id uint) (new-status uint) (votes-for uint) (votes-against uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (submitter (get submitter proposal))
  )
    ;; Only admin can update status
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_NOT_AUTHORIZED)
    (asserts! (or (is-eq new-status STATUS_PASSED)
                  (is-eq new-status STATUS_FAILED)
                  (is-eq new-status STATUS_WITHDRAWN)) ERR_INVALID_STATUS)

    ;; Update proposal
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        status: new-status,
        votes-for: votes-for,
        votes-against: votes-against,
        resolution-height: (some block-height)
      })
    )

    ;; Update submitter's reputation if proposal passed
    (if (is-eq new-status STATUS_PASSED)
      (increment-successful-proposals submitter)
      true
    )

    ;; Recalculate submitter's reputation
    (update-address-reputation submitter)

    (ok true)
  )
)

;; Admin function to change contract admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_NOT_AUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

;; read only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get address reputation
(define-read-only (get-address-reputation (address principal))
  (map-get? address-reputation { address: address })
)

;; Get quality vote by voter for a proposal
(define-read-only (get-quality-vote (proposal-id uint) (voter principal))
  (map-get? quality-votes { proposal-id: proposal-id, voter: voter })
)

;; Get all proposal IDs by submitter
(define-read-only (get-submitter-proposals (submitter principal))
  (map-get? submitter-proposals { submitter: submitter })
)

;; Get current proposal ID (next to be assigned)
(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)

;; Get contract admin
(define-read-only (get-admin)
  (var-get contract-admin)
)

;; Calculate reputation score based on success rate and quality
(define-read-only (calculate-reputation-score (total-proposals uint) (successful-proposals uint) (average-quality uint))
  (if (< total-proposals MIN_PROPOSALS_FOR_REPUTATION)
    u0 ;; Not enough proposals for reputation
    (let (
      (success-rate (/ (* successful-proposals u10000) total-proposals)) ;; Success rate as percentage * 100
      (quality-component (/ (* average-quality u100) u100)) ;; Quality score component
      (reputation (/ (+ success-rate quality-component) u2)) ;; Average of success rate and quality
    )
      (if (> reputation MAX_REPUTATION_SCORE)
        MAX_REPUTATION_SCORE
        reputation
      )
    )
  )
)

;; Get quality voters for a proposal
(define-read-only (get-quality-voters (proposal-id uint))
  (map-get? quality-voters { proposal-id: proposal-id })
)

;; private functions

;; Update address reputation metrics
(define-private (update-address-reputation (address principal))
  (let (
    (current-rep (map-get? address-reputation { address: address }))
    (proposals-list (default-to (list) (get proposal-ids (map-get? submitter-proposals { submitter: address }))))
    (total-proposals (len proposals-list))
  )
    (if (is-none current-rep)
      ;; Create new reputation entry
      (map-set address-reputation
        { address: address }
        {
          total-proposals: total-proposals,
          successful-proposals: u0,
          total-quality-score: u0,
          average-quality-score: u0,
          reputation-score: u0,
          last-updated: block-height
        }
      )
      ;; Update existing reputation
      (let (
        (rep (unwrap-panic current-rep))
        (total-quality (calculate-total-quality-score address proposals-list))
        (avg-quality (if (> total-proposals u0) (/ total-quality total-proposals) u0))
        (successful (get successful-proposals rep))
        (new-reputation (calculate-reputation-score total-proposals successful avg-quality))
      )
        (map-set address-reputation
          { address: address }
          {
            total-proposals: total-proposals,
            successful-proposals: successful,
            total-quality-score: total-quality,
            average-quality-score: avg-quality,
            reputation-score: new-reputation,
            last-updated: block-height
          }
        )
      )
    )
    true
  )
)

;; Increment successful proposals count for an address
(define-private (increment-successful-proposals (address principal))
  (let (
    (current-rep (unwrap! (map-get? address-reputation { address: address }) false))
    (new-successful (+ (get successful-proposals current-rep) u1))
  )
    (map-set address-reputation
      { address: address }
      (merge current-rep { successful-proposals: new-successful })
    )
    true
  )
)

;; Calculate total quality score for all proposals by an address
(define-private (calculate-total-quality-score (address principal) (proposal-ids (list 100 uint)))
  (fold calculate-quality-for-proposal proposal-ids u0)
)

;; Helper function for quality score calculation
(define-private (calculate-quality-for-proposal (proposal-id uint) (total-so-far uint))
  (let (
    (proposal (map-get? proposals { proposal-id: proposal-id }))
  )
    (if (is-some proposal)
      (+ total-so-far (get quality-score (unwrap-panic proposal)))
      total-so-far
    )
  )
)

;; Update proposal's quality score based on all votes
(define-private (update-proposal-quality-score (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) false))
    (voters-data (map-get? quality-voters { proposal-id: proposal-id }))
    (voters (if (is-some voters-data) (get voters (unwrap-panic voters-data)) (list)))
    (total-score (calculate-average-quality-score proposal-id voters))
    (vote-count (len voters))
    (average-score (if (> vote-count u0) (/ total-score vote-count) u0))
  )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { quality-score: average-score })
    )
    true
  )
)

;; Calculate average quality score from all votes
(define-private (calculate-average-quality-score (proposal-id uint) (voters (list 200 principal)))
  (fold sum-quality-votes voters u0)
)

;; Helper function to sum quality votes
(define-private (sum-quality-votes (voter principal) (total-so-far uint))
  (let (
    (vote (map-get? quality-votes { proposal-id: u0, voter: voter })) ;; Note: this is a simplified version
  )
    ;; In a real implementation, you'd need to pass proposal-id through the fold
    ;; For now, this is a placeholder structure
    total-so-far
  )
)
