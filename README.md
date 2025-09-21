# ProposalSubmitter

A Clarity smart contract for Stacks blockchain that implements an address reputation system for governance proposal quality and success rate scoring.

## Description

ProposalSubmitter tracks the performance of addresses in submitting governance proposals, calculating reputation scores based on proposal quality, success rates, and community engagement. This system enables communities to identify high-quality proposal submitters and incentivize better governance participation.

## Features

- **Proposal Submission**: Submit governance proposals with title and description
- **Quality Voting**: Community members can vote on proposal quality (1-100 scale)
- **Reputation Tracking**: Automatic calculation of submitter reputation scores
- **Success Rate Monitoring**: Track proposal success/failure rates for each address
- **Admin Controls**: Administrative functions for proposal status updates
- **Comprehensive Metrics**: Detailed statistics for proposals and submitters

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Version**: 1.0.0
- **Clarity Version**: 2
- **Epoch**: 2.5

### Key Constants

- `MAX_REPUTATION_SCORE`: 10,000 (representing 100.00%)
- `MIN_PROPOSALS_FOR_REPUTATION`: 3 proposals required for reputation calculation
- **Proposal Statuses**: Active (1), Passed (2), Failed (3), Withdrawn (4)

### Data Structures

#### Proposals Map
- `proposal-id`: Unique identifier
- `submitter`: Address that submitted the proposal
- `title`: Proposal title (max 200 characters)
- `description`: Proposal description (max 1000 characters)
- `status`: Current proposal status
- `quality-score`: Average quality score from community votes
- `votes-for/votes-against`: Governance vote counts
- `submission-height`: Block height when submitted
- `resolution-height`: Block height when resolved

#### Address Reputation Map
- `total-proposals`: Number of proposals submitted
- `successful-proposals`: Number of passed proposals
- `total-quality-score`: Sum of all quality scores
- `average-quality-score`: Average quality across all proposals
- `reputation-score`: Overall reputation (0-10,000)
- `last-updated`: Last update block height

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity smart contract development tool
- [Node.js](https://nodejs.org/) (if using TypeScript testing)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd ProposalSubmitter
```

2. Navigate to the contract directory:
```bash
cd ProposalSubmitter_contract
```

3. Install dependencies:
```bash
npm install
```

4. Check contract syntax:
```bash
clarinet check
```

## Usage Examples

### Submit a Proposal

```clarity
(contract-call? .ProposalSubmitter submit-proposal
  "Increase block rewards"
  "This proposal suggests increasing mining rewards to improve network security")
```

### Vote on Proposal Quality

```clarity
(contract-call? .ProposalSubmitter vote-on-quality u1 u85)
;; Vote score of 85/100 for proposal ID 1
```

### Get Proposal Details

```clarity
(contract-call? .ProposalSubmitter get-proposal u1)
```

### Check Address Reputation

```clarity
(contract-call? .ProposalSubmitter get-address-reputation 'SP1ABC123...)
```

## Contract Functions

### Public Functions

#### `submit-proposal`
**Parameters**: `title` (string-ascii 200), `description` (string-ascii 1000)
**Returns**: `(response uint uint)`
**Description**: Submit a new governance proposal. Automatically updates submitter's reputation metrics.

#### `vote-on-quality`
**Parameters**: `proposal-id` (uint), `quality-score` (uint)
**Returns**: `(response bool uint)`
**Description**: Vote on proposal quality (1-100 scale). Each address can vote once per proposal.

#### `update-proposal-status`
**Parameters**: `proposal-id` (uint), `new-status` (uint), `votes-for` (uint), `votes-against` (uint)
**Returns**: `(response bool uint)`
**Description**: Admin-only function to update proposal status and vote counts.

#### `set-admin`
**Parameters**: `new-admin` (principal)
**Returns**: `(response bool uint)`
**Description**: Admin-only function to change contract administrator.

### Read-Only Functions

#### `get-proposal`
**Parameters**: `proposal-id` (uint)
**Returns**: `(optional proposal-data)`
**Description**: Retrieve complete proposal information.

#### `get-address-reputation`
**Parameters**: `address` (principal)
**Returns**: `(optional reputation-data)`
**Description**: Get reputation metrics for an address.

#### `get-quality-vote`
**Parameters**: `proposal-id` (uint), `voter` (principal)
**Returns**: `(optional quality-vote-data)`
**Description**: Check if and how an address voted on proposal quality.

#### `get-submitter-proposals`
**Parameters**: `submitter` (principal)
**Returns**: `(optional proposal-ids-list)`
**Description**: Get list of proposal IDs submitted by an address.

#### `calculate-reputation-score`
**Parameters**: `total-proposals` (uint), `successful-proposals` (uint), `average-quality` (uint)
**Returns**: `uint`
**Description**: Calculate reputation score based on success rate and quality.

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy the contract:
```clarity
::deploy_contracts
```

3. Test functions:
```clarity
(contract-call? .ProposalSubmitter submit-proposal "Test Proposal" "Testing the contract")
```

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`

2. Deploy to testnet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`

2. Deploy to mainnet:
```bash
clarinet deployments generate --mainnet
clarinet deployments apply --mainnet
```

## Security Notes

### Access Controls
- Only the contract admin can update proposal statuses
- Admin role can be transferred but requires current admin authorization
- Quality voting is restricted to one vote per address per proposal

### Input Validation
- Proposal titles limited to 200 ASCII characters
- Descriptions limited to 1000 ASCII characters
- Quality scores must be between 1-100
- Status updates limited to valid status codes

### Reputation Calculation
- Minimum 3 proposals required before reputation score calculation
- Reputation scores capped at maximum value (10,000)
- Success rate and quality scores weighted equally in reputation calculation

### Known Limitations
- Quality vote summation function has a simplified implementation (line 371-376)
- Maximum 100 proposals per submitter due to list length restrictions
- Maximum 200 quality voters per proposal

### Best Practices
- Regularly monitor admin operations
- Validate proposal content before submission
- Consider implementing time-based voting windows
- Monitor for spam or low-quality proposals

## Error Codes

- `u1000`: Not authorized
- `u1001`: Proposal not found
- `u1002`: Proposal already exists
- `u1003`: Invalid score
- `u1004`: Proposal not active
- `u1005`: Already voted
- `u1006`: Invalid status

## License

This project is licensed under the terms specified in the repository license file.

## Contributing

Please review the contributing guidelines before submitting pull requests or issues.
