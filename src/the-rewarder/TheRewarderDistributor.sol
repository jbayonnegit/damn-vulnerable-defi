// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

struct Distribution {
	uint256 remaining;
	uint256 nextBatchNumber;
	mapping(uint256 batchNumber => bytes32 root) roots;
	mapping(address claimer => mapping(uint256 word => uint256 bits)) claims;
}

struct Claim {
	uint256 batchNumber;
	uint256 amount;
	uint256 tokenIndex;
	bytes32[] proof;
}

/**
 * An efficient token distributor contract based on Merkle proofs and bitmaps
 */
contract TheRewarderDistributor {
	using BitMaps for BitMaps.BitMap;

	address public immutable owner = msg.sender;

	mapping(IERC20 token => Distribution) public distributions;

	error StillDistributing();
	error InvalidRoot();
	error AlreadyClaimed();
	error InvalidProof();
	error NotEnoughTokensToDistribute();

	event NewDistribution(IERC20 token, uint256 batchNumber, bytes32 newMerkleRoot, uint256 totalAmount);

	function getRemaining(address token) external view returns (uint256) {
		return distributions[IERC20(token)].remaining;
	}

	function getNextBatchNumber(address token) external view returns (uint256) {
		return distributions[IERC20(token)].nextBatchNumber;
	}

	function getRoot(address token, uint256 batchNumber) external view returns (bytes32) {
		return distributions[IERC20(token)].roots[batchNumber];
	}

	function createDistribution(IERC20 token, bytes32 newRoot, uint256 amount) external {
		if (amount == 0) revert NotEnoughTokensToDistribute();
		if (newRoot == bytes32(0)) revert InvalidRoot();
		if (distributions[token].remaining != 0) revert StillDistributing();

		distributions[token].remaining = amount;

		uint256 batchNumber = distributions[token].nextBatchNumber;
		distributions[token].roots[batchNumber] = newRoot;
		distributions[token].nextBatchNumber++;

		SafeTransferLib.safeTransferFrom(address(token), msg.sender, address(this), amount);

		emit NewDistribution(token, batchNumber, newRoot, amount);
	}

	function clean(IERC20[] calldata tokens) external {
		for (uint256 i = 0; i < tokens.length; i++) {
			IERC20 token = tokens[i];
			if (distributions[token].remaining == 0) {
				token.transfer(owner, token.balanceOf(address(this)));
			}
		}
	}


	/**
	 * 
	 *  * _setClaimed is almost never call :
	 * 
	 * _setClaimed is only call if :
	 * 
	 * 		- token is different from the claimed one
	 * 		- if its the last claim of Claim[] array
	 * 		@notice it can be call twice ( if token is different an if it's the last )
	 * 
	 * * Possibility to claimed multiple token in a signe loop tour
	 * 
	 *  
	 */
	// Allow claiming rewards of multiple tokens in a single transaction
	function claimRewards(Claim[] memory inputClaims, IERC20[] memory inputTokens) external {
		Claim memory inputClaim;
		IERC20 token;
		uint256 bitsSet; // accumulator
		uint256 amount;

		for (uint256 i = 0; i < inputClaims.length; i++) {
			inputClaim = inputClaims[i];

			uint256 wordPosition = inputClaim.batchNumber / 256;
			uint256 bitPosition = inputClaim.batchNumber % 256;
			/**
			 * This make no sens to me. 
			 * * We enter here when i == 0 and everytime we claim a different token from i - 1
			 */
			if (token != inputTokens[inputClaim.tokenIndex]) {                                       // If token is different from the claimed token
				if (address(token) != address(0)) {													 // If token is initialized : it's not claimed token but it is initialized
					if (!_setClaimed(token, amount, wordPosition, bitsSet)) revert AlreadyClaimed(); // Use of bitset and amount but uninitialized at i = 0 
				}

				token = inputTokens[inputClaim.tokenIndex];
				bitsSet = 1 << bitPosition; // set bit at given position
				amount = inputClaim.amount;
			} else {
				bitsSet = bitsSet | 1 << bitPosition;
				amount += inputClaim.amount;
			}

			// for the last claim
			if (i == inputClaims.length - 1) {
				if (!_setClaimed(token, amount, wordPosition, bitsSet)) revert AlreadyClaimed();
			}

			bytes32 leaf = keccak256(abi.encodePacked(msg.sender, inputClaim.amount));				/* Can two leafs have the same hash ?*/
			bytes32 root = distributions[token].roots[inputClaim.batchNumber];

			if (!MerkleProof.verify(inputClaim.proof, root, leaf)) revert InvalidProof();

			inputTokens[inputClaim.tokenIndex].transfer(msg.sender, inputClaim.amount);
		}
	}

	function _setClaimed(IERC20 token, uint256 amount, uint256 wordPosition, uint256 newBits) private returns (bool) {
		uint256 currentWord = distributions[token].claims[msg.sender][wordPosition];    // distributions[token].claims[msg.sender][wordPosition] uninitialized the first time : currentWord = 0
		if ((currentWord & newBits) != 0) return false;                                 // if (newBits != currentWord) { _; } else return ( false );
																						// newBits is always 0 except when it's the lenght - 1 claims in the Claim[] input array

		// update state
		distributions[token].claims[msg.sender][wordPosition] = currentWord | newBits;  // if newBits is correctly initialized : distributions[token].claims[msg.sender][wordPosition] is iniialized here
		distributions[token].remaining -= amount;

		return true;
	}
}
