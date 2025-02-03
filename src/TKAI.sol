// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Token has a fixed supply , transfers could be pause and token could not be burned
 * @title TKAI token
 */
contract TKAI is ERC20Capped, ERC20Pausable, Ownable {
  // Maximum supply is 300M TKAI
  uint256 private constant _totalSupply = 300_000_000_000_000_000_000_000_000;

  constructor(
    string memory _name,
    string memory _symbol,
    address owner
  ) ERC20(_name, _symbol) ERC20Capped(_totalSupply) ERC20Pausable() Ownable(owner) {
    transferOwnership(owner);
  }

  function decimals() public pure override returns (uint8) {
    return 18;
  }

  function pause() external virtual onlyOwner {
    _pause();
  }

  function unpause() external virtual onlyOwner {
    _unpause();
  }

  function burn(uint256) public pure {
    revert();
  }
  function burnFrom(address, uint256) public pure {
    revert();
  }

  function _update(address from, address to, uint256 value) internal virtual override(ERC20Capped, ERC20Pausable) whenNotPaused {
    super._update(from, to, value);

    if (from == address(0)) {
      uint256 maxSupply = cap();
      uint256 supply = totalSupply();
      if (supply > maxSupply) {
        revert ERC20ExceededCap(supply, maxSupply);
      }
    }
  }
}
