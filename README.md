# Damn Vulnerable DeFi - Security Learning Fork

This repository is a personal fork of the original [Damn Vulnerable DeFi](https://github.com/theredguild/damn-vulnerable-defi) project. I have created this fork to force myself into deeply learning and practicing Solidity smart contract security.

Damn Vulnerable DeFi is the premier playground for smart contract security, featuring realistic scenarios involving flashloans, price oracles, governance, NFTs, DEXs, lending pools, smart contract wallets, timelocks, vaults, meta-transactions, token distributions, upgradeability, and more.

## Goal

The main objective of this repository is to document my journey as I uncover flaws, exploit vulnerabilities, and learn how to write secure smart contracts. 

- **Exploits**: I will document my attack thoughts, vectors, and approaches in `exploits.md`.
- **Solutions**: I will document the conceptual fixes and mitigation strategies in `solutions.md`.

## Structure

- `src/`: Contains the vulnerable contracts for each challenge.
- `test/`: Contains the Foundry test files where solutions and exploits are validated.
- `exploits.md`: A dedicated file detailing the mechanics of the attacks.
- `solutions.md`: A dedicated file explaining how to patch the vulnerabilities.

## Challenges Progress

| Challenge | Status |
| :--- | :--- |
| ABI Smuggling | ⏳ Not Started |
| Backdoor | ⏳ Not Started |
| Climber | ⏳ Not Started |
| Compromised | ⏳ Not Started |
| Curvy Puppet | ⏳ Not Started |
| Free Rider | ⏳ Not Started |
| Naive Receiver | ✅ Completed |
| Puppet | ⏳ Not Started |
| Puppet V2 | ⏳ Not Started |
| Puppet V3 | ⏳ Not Started |
| Selfie | ✅ Completed |
| Shards | ⏳ Not Started |
| Side Entrance | ✅ Completed |
| The Rewarder | ✅ Completed |
| Truster | ✅ Completed |
| Unstoppable | ✅ Completed |
| Wallet Mining | ⏳ Not Started |
| Withdrawal | ⏳ Not Started |

## Install & Usage

1. Clone this repository.
2. Ensure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.
3. Rename the `.env.sample` file to `.env` and add a valid RPC URL (needed for mainnet forking challenges).
4. Run `forge build` to compile the contracts.
5. Code the solution/exploit in the corresponding test file (`test/<challenge-name>/<ChallengeName>.t.sol`).
6. Run `forge test --mp test/<challenge-name>/<ChallengeName>.t.sol` to verify your exploit.

> Note: In challenges that restrict the number of transactions, you might need to run the test with the `--isolate` flag.

## Rules

- Always use the `player` account.
- Do not modify the challenges' initial nor final conditions.
- You can code and deploy your own smart contracts.
- You can use Foundry's cheatcodes to advance time when necessary.

## Disclaimer

All code, practices, and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.
