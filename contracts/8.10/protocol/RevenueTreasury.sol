// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
**/

pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IGrassHouse.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IVault.sol";

import "../utils/SafeToken.sol";

/// @title RevenueTreasury - Receives Revenue and Settles Redistribution
contract RevenueTreasury is Initializable, OwnableUpgradeable {
  /// @notice Libraries
  using SafeToken for address;

  /// @notice Errors
  error RevenueTreasury_TokenMismatch();
  error RevenueTreasury_InvalidRewardPathLength();
  error RevenueTreasury_InvalidRewardPath();
  error RevenueTreasury_InvalidBps();

  /// @notice Events
  event LogFeedGrassHouse(address indexed _caller, uint256 _transferAmount, uint256 _swapAmount, uint256 _feedAmount);
  event LogSetGrassHouse(address indexed _caller, address _prevGrassHouse, address _newGrassHouse);
  event LogSetWhitelistedCallers(address indexed _caller, address indexed _address, bool _ok);
  event LogSetRewardPath(address indexed _caller, address[] _newRewardPath);
  event LogSetRouter(address indexed _caller, address _prevRouter, address _newRouter);
  event LogSetSplitBps(address indexed _caller, uint256 _prevSplitBps, uint256 _newSplitBps);

  /// @notice token - address of the receiving token
  /// Required to have token() if this contract to be destination of Worker's benefitial vault
  address public token;

  /// @notice grasshouseToken - address of the reward token
  address public grasshouseToken;

  /// @notice router - Pancake Router like address
  ISwapRouter public router;

  /// @notice grassHouse - Implementation of GrassHouse
  IGrassHouse public grassHouse;

  /// @notice vault - Implementation of vault
  IVault public vault;

  /// @notice rewardPath - Path to swap recieving token to grasshouse's token
  address[] public rewardPath;

  /// @notice remaining - Remaining bad debt amount to cover
  uint256 public remaining;

  /// @notice splitBps - Bps to split the receiving token
  uint256 public splitBps;

  /// @notice Initialize function
  /// @param _token Receiving token
  /// @param _grasshouse Grasshouse's contract address
  function initialize(
    address _token,
    IGrassHouse _grasshouse,
    IVault _vault,
    ISwapRouter _router,
    uint256 _remaining,
    uint256 _splitBps
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    token = _token;
    grassHouse = _grasshouse;
    vault = _vault;

    grasshouseToken = grassHouse.rewardToken();

    remaining = _remaining;

    splitBps = _splitBps;

    // sanity check
    router = _router;
    router.WETH();

    if (token != vault.token()) {
      revert RevenueTreasury_TokenMismatch();
    }

    if (splitBps > 10000) {
      revert RevenueTreasury_InvalidBps();
    }
  }

  /// @notice Split fund and distribute
  function feedGrassHouse() external {
    uint256 _transferAmount = 0;
    if (remaining > 0) {
      // Split the current receiving token balance per configured bps.
      uint256 split = (token.myBalance() * splitBps) / 10000;
      // The amount to transfer to vault shoule be equal to min(split , remaining)
      _transferAmount = split < remaining ? split : remaining;

      remaining = remaining - _transferAmount;
      token.safeTransfer(address(vault), _transferAmount);
    }

    // Swap all the rest to reward token
    uint256 _swapAmount = token.myBalance();
    token.safeApprove(address(router), _swapAmount);
    router.swapExactTokensForTokens(_swapAmount, 0, rewardPath, address(this), block.timestamp);
    token.safeApprove(address(router), 0);

    // Feed all reward token to grasshouse
    uint256 _feedAmount = grasshouseToken.myBalance();
    grasshouseToken.safeApprove(address(grassHouse), _feedAmount);
    grassHouse.feed(_feedAmount);
    emit LogFeedGrassHouse(msg.sender, _transferAmount, _swapAmount, _feedAmount);
  }

  /// @notice Set a new GrassHouse
  /// @param _newGrassHouse - new GrassHouse address
  function setGrassHouse(IGrassHouse _newGrassHouse) external onlyOwner {
    address _prevGrassHouse = address(grassHouse);
    grassHouse = _newGrassHouse;
    grasshouseToken = grassHouse.rewardToken();
    emit LogSetGrassHouse(msg.sender, _prevGrassHouse, address(_newGrassHouse));
  }

  /// @notice Set a new swap router
  /// @param _newRouter The new reward path.
  function setRouter(ISwapRouter _newRouter) external onlyOwner {
    address _prevRouter = address(router);
    router = _newRouter;

    emit LogSetRouter(msg.sender, _prevRouter, address(router));
  }

  /// @notice Set a new reward path. In case that the liquidity of the reward path has changed.
  /// @param _rewardPath The new reward path.
  function setRewardPath(address[] calldata _rewardPath) external onlyOwner {
    if (_rewardPath.length < 2) revert RevenueTreasury_InvalidRewardPathLength();

    if (_rewardPath[0] != token || _rewardPath[_rewardPath.length - 1] != grasshouseToken)
      revert RevenueTreasury_InvalidRewardPath();

    rewardPath = _rewardPath;

    emit LogSetRewardPath(msg.sender, _rewardPath);
  }

  /// @notice Set a new swap router
  /// @param _newSplitBps The new reward path.
  function setSplitBps(uint256 _newSplitBps) external onlyOwner {
    if (_newSplitBps > 10000) {
      revert RevenueTreasury_InvalidBps();
    }
    uint256 _prevSplitBps = splitBps;
    splitBps = _newSplitBps;

    emit LogSetSplitBps(msg.sender, _prevSplitBps, _newSplitBps);
  }
}
