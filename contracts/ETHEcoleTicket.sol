//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./IERC721.sol";
import "./IERC20Permit.sol";

error ERC721TransferFailed(bytes returndata);
error ERC721TransferRejected(bytes4 retval);
error AllTicketsSold();
error MustBeOwner();
error Paused();

contract ETHEcoleTicket is IERC721 {
  mapping(address => uint256) public addressToNFT;
  mapping(uint256 => address) private nftOwner;
  mapping(uint256 => address) private approved;
  mapping(address => mapping(address => bool)) private operatorApprovals;
  mapping(uint256 => string) public nftName;

  bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

  uint256 public numberOfTickets;
  uint256 public totalSupply;
  uint256 public purchasePrice;
  address public paymentToken;

  bool public paused;
  address public owner;
  string public baseURI;

  event SetName(uint256 indexed tokenId, string name);
  event OwnershipTransferred(address indexed newOwner);
  event BaseURIChanged(string newBase);
  event PausedSet(bool paused);

  string public override name = "ETH Ecole Ticket";
  string public override symbol = "ECOLE";

  constructor(
    uint256 _numberOfTickets,
    address _paymentToken,
    uint256 _purchasePrice,
    string memory _baseURI
  ) {
    owner = msg.sender;
    numberOfTickets = _numberOfTickets;
    paymentToken = _paymentToken;
    purchasePrice = _purchasePrice;
    baseURI = _baseURI;
  }

  function balanceOf(address owner) external view override returns (uint256 balance) {
    return addressToNFT[owner] == 0 ? 0 : 1;
  }

  /**
   * @dev Returns the owner of the `tokenId` token.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function ownerOf(uint256 tokenId) external view override returns (address owner) {
    return nftOwner[tokenId];
  }

  function nameOf(uint256 tokenId) external view returns (string memory) {
    return nftName[tokenId];
  }

  function tokenURI(uint256 tokenId) external view override returns (string memory) {
    return string(abi.encodePacked(baseURI, uint2str(tokenId)));
  }

  function purchase(address recipient, string calldata name) external returns (uint256 ticketId) {
    return _purchase(recipient, name);
  }

  function purchaseWithPermit(
    address recipient,
    string calldata name,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 ticketId) {
    IERC20Permit(paymentToken).permit(msg.sender, address(this), purchasePrice, deadline, v, r, s);
    return _purchase(recipient, name);
  }

  function _purchase(address recipient, string memory name) private returns (uint256 ticketId) {
    if (totalSupply >= numberOfTickets) {
      revert AllTicketsSold();
    }
    if (paused) {
      revert Paused();
    }

    ticketId = totalSupply + 1;
    totalSupply = ticketId;

    IERC20Permit(paymentToken).transferFrom(msg.sender, address(this), purchasePrice);

    addressToNFT[recipient] = ticketId;
    nftOwner[ticketId] = recipient;
    nftName[ticketId] = name;

    emit Transfer(address(0), recipient, ticketId);
    emit SetName(ticketId, name);
  }

  function rename(uint256 tokenId, string calldata name) external {
    if (nftOwner[tokenId] != msg.sender) {
      revert MustBeOwner();
    }
    if (paused) {
      revert Paused();
    }

    nftName[tokenId] = name;

    emit SetName(tokenId, name);
  }

  function setPayment(address token, uint256 price) external {
    if (msg.sender != owner) {
      revert MustBeOwner();
    }
    purchasePrice = price;
    paymentToken = token;
  }

  function setCap(uint256 newCap) external {
    if (msg.sender != owner) {
      revert MustBeOwner();
    }
    numberOfTickets = newCap;
  }

  function setBaseURI(string calldata newBase) external {
    if (msg.sender != owner) {
      revert MustBeOwner();
    }
    baseURI = newBase;
    emit BaseURIChanged(newBase);
  }

  function transferOwnership(address newOwner) external {
    if (msg.sender != owner) {
      revert MustBeOwner();
    }
    owner = newOwner;
    emit OwnershipTransferred(newOwner);
  }

  function setPaused(bool _paused) external {
    if (msg.sender != owner) {
      revert MustBeOwner();
    }
    paused = _paused;
    emit PausedSet(_paused);
  }

  function withdraw(address token) external {
    if (msg.sender != owner) {
      revert MustBeOwner();
    }
    IERC20Permit(token).transfer(msg.sender, IERC20Permit(token).balanceOf(address(this)));
  }

  /**
   * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
   * are aware of the ERC721 protocol to prevent tokens from being forever locked.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must exist and be owned by `from`.
   * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function safeTransferFrom(
      address from,
      address to,
      uint256 tokenId
  ) external override {
    assertApprovedOrOwner(msg.sender, tokenId);
    _transfer(from, to, tokenId);
    _checkOnERC721Received(from, to, tokenId, '');
  }

  /**
   * @dev Transfers `tokenId` token from `from` to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must be owned by `from`.
   * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
   *
   * Emits a {Transfer} event.
   */
  function transferFrom(
      address from,
      address to,
      uint256 tokenId
  ) external override {
    assertApprovedOrOwner(msg.sender, tokenId);
    _transfer(from, to, tokenId);
  }

  /**
   * @dev Gives permission to `to` to transfer `tokenId` token to another account.
   * The approval is cleared when the token is transferred.
   *
   * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
   *
   * Requirements:
   *
   * - The caller must own the token or be an approved operator.
   * - `tokenId` must exist.
   *
   * Emits an {Approval} event.
   */
  function approve(address to, uint256 tokenId) external override {
    assertApprovedOrOwner(msg.sender, tokenId);
    approved[tokenId] = to;
    emit Approval(msg.sender, to, tokenId);
  }

  /**
   * @dev Returns the account approved for `tokenId` token.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function getApproved(uint256 tokenId) external view override returns (address operator) {
    return approved[tokenId];
  }

  /**
   * @dev Approve or remove `operator` as an operator for the caller.
   * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
   *
   * Requirements:
   *
   * - The `operator` cannot be the caller.
   *
   * Emits an {ApprovalForAll} event.
   */
  function setApprovalForAll(address operator, bool _approved) external override {
    operatorApprovals[msg.sender][operator] = _approved;
    emit ApprovalForAll(msg.sender, operator, _approved);
  }

  /**
   * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
   *
   * See {setApprovalForAll}
   */
  function isApprovedForAll(address tokenOwner, address operator) external view override returns (bool) {
    return operatorApprovals[tokenOwner][operator];
  }

  /**
   * @dev Safely transfers `tokenId` token from `from` to `to`.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must exist and be owned by `from`.
   * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function safeTransferFrom(
      address from,
      address to,
      uint256 tokenId,
      bytes calldata data
  ) external override {
    assertApprovedOrOwner(msg.sender, tokenId);
    _transfer(from, to, tokenId);
    _checkOnERC721Received(from, to, tokenId, data);
  }

  function assertApprovedOrOwner(address account, uint256 tokenId) private {
    if (nftOwner[tokenId] != account) {
      revert MustBeOwner();
    }
  }

  function _transfer(address from, address to, uint256 tokenId) private {
    if (paused) {
      revert Paused();
    }

    nftOwner[tokenId] = to;
    addressToNFT[from] = 0;
    addressToNFT[to] = 0;
    emit Transfer(from, to, tokenId);
  }

  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) private {
    if (!isContract(to)) {
      return;
    }

    bytes memory cdata = abi.encodeWithSignature(
      "onERC721Received(address,address,uint256,bytes)",
      msg.sender,
      from,
      tokenId,
      _data
    );
    (bool success, bytes memory returndata) = to.call(cdata);

    if (!success) {
      revert ERC721TransferFailed(returndata);
    }

    bytes4 retval = abi.decode(returndata, (bytes4));
    if (retval != _ERC721_RECEIVED) {
      revert ERC721TransferRejected(retval);
    }
  }

  function isContract(address _addr) private view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(_addr) }
    return size > 0;
  }

  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
      if (_i == 0) {
        return "0";
      }
      uint j = _i;
      uint len;
      while (j != 0) {
        len++;
        j /= 10;
      }
      bytes memory bstr = new bytes(len);
      uint k = len;
      while (_i != 0) {
        k = k-1;
        uint8 temp = (48 + uint8(_i - _i / 10 * 10));
        bytes1 b1 = bytes1(temp);
        bstr[k] = b1;
        _i /= 10;
      }
      return string(bstr);
    }
}
