// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest, console, xALPACACreditorLike } from "../../base/BaseTest.sol";

import { xALPACACreditor } from "../../../contracts/8.13/xALPACACreditor.sol";
import { IxALPACA } from "../../../contracts/8.13/interfaces/IxALPACA.sol";

import { mocking } from "../../utils/mocking.sol";
import { MockContract } from "../../utils/MockContract.sol";

// solhint-disable func-name-mixedcase
// solhint-disable contract-name-camelcase
contract xAlpacaCreditor_Test is BaseTest {
  using mocking for *;
  uint64 private constant VALUE_PER_XALPACA = 2 ether;

  xALPACACreditorLike private _creditor;
  IxALPACA private _xALPACA;

  address private _userAddress = address(1);

  function setUp() external {
    _xALPACA = IxALPACA(address(new MockContract()));
    _xALPACA.epoch.mockv(1);
    _xALPACA.balanceOf.mockv(_userAddress, 1 ether);

    _creditor = _setupxALPACACreditor(address(_xALPACA), VALUE_PER_XALPACA);
  }

  function testCorrectness_getUserCredit() external {
    assertEq(_creditor.getUserCredit(_userAddress), 2 ether);
  }

  function testCorrectness_afterUpdateValuePerxALPACA() external {
    _creditor.setValuePerxALPACA(4 ether);
    assertEq(_creditor.getUserCredit(_userAddress), 4 ether);
  }

  function testCannotSetValuePerXalpacaMoreThanThreshold() external {
    vm.expectRevert(abi.encodeWithSignature("xALPACACreditor_ValueTooHigh()"));
    _creditor.setValuePerxALPACA(10000 ether);
  }

  function testCanSetValuePerXalpacaLessThanThreshold(uint256 _value) external {
    vm.assume(_value < 1000 ether);
    _creditor.setValuePerxALPACA(_value);
  }
}