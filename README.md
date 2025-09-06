# 🏛️ Taxtrace - Local Tax Distribution Ledger

## 📋 Overview

Taxtrace is a transparent blockchain-based system that tracks where local tax revenues are allocated. Built on the Stacks blockchain using Clarity smart contracts, it provides complete transparency into how tax authorities collect and distribute public funds.

## ✨ Features

- 🏢 **Tax Authority Registration**: Register local tax authorities with their wallet addresses
- 📊 **Tax Collection Recording**: Log all tax collections with source information
- 🎯 **Allocation Categories**: Create categories for different spending areas (Education, Infrastructure, Healthcare, etc.)
- 💰 **Fund Allocation Tracking**: Track exactly how much goes to each category
- 📈 **Real-time Analytics**: View total collections and allocations by authority and category
- 🔒 **Transparent & Immutable**: All records are permanently stored on the blockchain

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run Clarinet commands to deploy and test

```bash
clarinet check
clarinet test
clarinet deploy
```

## 📖 Usage

### For Contract Owners

#### Register a Tax Authority
```clarity
(contract-call? .taxtrace register-tax-authority "City of Springfield" 'SP1234...)
```

#### Create Allocation Categories
```clarity
(contract-call? .taxtrace create-allocation-category "Education" "Public school funding and educational programs")
(contract-call? .taxtrace create-allocation-category "Infrastructure" "Roads, bridges, and public utilities")
(contract-call? .taxtrace create-allocation-category "Healthcare" "Public health services and hospitals")
```

### For Tax Authorities

#### Record Tax Collection
```clarity
(contract-call? .taxtrace record-tax-collection u1 u100000 "Property Tax Q1 2024")
```

#### Allocate Funds to Categories
```clarity
(contract-call? .taxtrace allocate-tax-funds u1 u1 u40000)  ;; 40% to Education
(contract-call? .taxtrace allocate-tax-funds u1 u2 u35000)  ;; 35% to Infrastructure
(contract-call? .taxtrace allocate-tax-funds u1 u3 u25000)  ;; 25% to Healthcare
```

### For Citizens (Read-Only)

#### View Tax Authority Information
```clarity
(contract-call? .taxtrace get-tax-authority u1)
```

#### Check Tax Record Details
```clarity
(contract-call? .taxtrace get-tax-record u1)
```

#### View Category Allocations
```clarity
(contract-call? .taxtrace get-authority-total-by-category u1 u1)
```

## 🔍 Key Functions

| Function | Description | Access |
|----------|-------------|---------|
| `register-tax-authority` | Register new tax collecting authority | Owner Only |
| `create-allocation-category` | Create spending categories | Owner Only |
| `record-tax-collection` | Log tax revenue collection | Public |
| `allocate-tax-funds` | Distribute funds to categories | Public |
| `get-tax-authority` | View authority details | Read-Only |
| `get-tax-record` | View collection records | Read-Only |
| `get-authority-total-by-category` | View total allocations | Read-Only |

## 🏗️ Contract Structure

- **Tax Authorities**: Registered entities that collect taxes
- **Tax Records**: Individual collection events with amounts and sources
- **Allocation Categories**: Spending categories (Education, Infrastructure, etc.)
- **Tax Allocations**: Records of how funds are distributed
- **Authority Allocations**: Running totals by authority and category

## 🛡️ Security Features

- Owner-only functions for critical operations
- Input validation for all parameters
- Immutable record keeping
- Transparent fund tracking

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with Clarinet
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions or issues, please open a GitHub issue or contact the development team.


