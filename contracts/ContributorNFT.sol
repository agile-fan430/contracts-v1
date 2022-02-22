// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {Signature} from "./Signature.sol";

/**
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *  - token ID and URI autogeneration
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract ContributorNFT is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721URIStorage,
    ERC721Pausable
{
    // Attach libaries
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    mapping(uint256 => bool) public valid;
    mapping(uint256 => string) private _ceramicIDs;

    bool private transferEnabled;

    address private minterAllowerAddr;

    struct Guild {
        string name;
        address[] admins;
    }

    mapping(uint16 => Guild) guildMapping;
    uint16 private guildCounter;

    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(uint256 => uint256) creationDate;

    // Nonce-validation array, for guaranteeing the uniqueness of signatures and mitigate replay attacks.
    mapping(string => bool) private seenNonces;

    event MINT(uint256 indexed tokenId);
    event BURN(uint256 indexed tokenId);

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;

    modifier _onlyMinter() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC721PresetMinterPauserAutoId: must have minter role to mint"
        );
        _;
    }

    modifier _onlyDAOAdmin() {
        require(
            hasRole(DAO_ADMIN_ROLE, _msgSender()),
            "ERC721PresetMinterPauserAutoId: must have minter role to mint"
        );
        _;
    }

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseTokenURI,
        address[] memory daoAdmins,
        address _minterAllowerAddr,
        bool _allowTransfers
    ) ERC721(_name, _symbol) {
        require(
            _minterAllowerAddr != address(0),
            "ERC721: Minter allower can't be null"
        );
        _baseTokenURI = baseTokenURI;

        transferEnabled = _allowTransfers;
        minterAllowerAddr = _minterAllowerAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        uint256 i;
        while (i < daoAdmins.length) {
            require(daoAdmins[i] != address(0), "ERC721: Admins can't be null");
            _setupRole(MINTER_ROLE, daoAdmins[i]);
            i++;
        }
    }

    /**
     * @notice Checks if a signature came from Gateway.
     *
     * @param _v Recovery ID of the signature
     * @param _r Output from the ECDSA signature
     * @param _s Output from the ECDSA signature
     * @param _nonce A nonce passed by Gateway for validating the deployment
     */
    function validateSignature(
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        string memory _nonce
    ) public {
        // Verify if Gateway has given permissions for the minter
        bytes32 messageHash = Signature.hashMessage(_nonce);
        bytes32 signedMessageHash = Signature.hashSignedMessage(messageHash);
        require(
            Signature.verifyMessageAuthenticity(
                signedMessageHash,
                minterAllowerAddr,
                _v,
                _r,
                _s
            ),
            "This message wasn't created by Gateway"
        );
        require(
            !seenNonces[_nonce],
            "This nonce was used on a previous deployment"
        );
        seenNonces[_nonce] = true;
    }

    /*=========================

     Getters

    ==============================*/

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    // @notice Returns the token URI for a specific token ID
    // @param _tokenId The ID of the token to verify
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_tokenId);
    }

    // @notice Returns the ceramic Id for a specific nft
    // @param _tokenId The ID of the token to verify
    function ceramicURI(uint256 _tokenId) public view returns (string memory) {
        return _ceramicIDs[_tokenId];
    }

    function getTransferability() public view returns (bool) {
        return transferEnabled;
    }

    function isValid(uint256 _tokenId) public view returns (bool) {
        return valid[_tokenId];
    }

    function getCreationDate(uint256 _tokenId) public view returns (uint256) {
        return creationDate[_tokenId];
    }

    function getGuild(uint16 idx) public view returns (Guild memory) {
        return guildMapping[idx];
    }

    function getCurrentGuildsNumber() public view returns (uint16) {
        return guildCounter;
    }

    /*=========================

     Setters

    ==============================*/

    function changeValidStatus(uint256 _tokenId) public _onlyDAOAdmin {
        valid[_tokenId] = !valid[_tokenId];
    }

    function setTransferability() public {
        transferEnabled = !transferEnabled;
    }

    function addGuild(string memory name, address[] memory _admins)
        public
        _onlyDAOAdmin
    {
        guildMapping[guildCounter++] = Guild(name, _admins);
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        address to,
        string memory _tokenURI,
        string memory _ceramicStream,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        string memory _nonce
    ) external virtual {
        // Verify if Gateway has given permissions for the minter
        this.validateSignature(_v, _r, _s, _nonce);

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(to, _tokenIdTracker.current());
        _setTokenURI(_tokenIdTracker.current(), _tokenURI);
        creationDate[_tokenIdTracker.current()] = block.timestamp;
        _ceramicIDs[_tokenIdTracker.current()] = _ceramicStream;
        emit MINT(_tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        address to,
        string memory _tokenURI,
        string memory _ceramicStream
    ) external virtual _onlyDAOAdmin {
        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(to, _tokenIdTracker.current());
        _setTokenURI(_tokenIdTracker.current(), _tokenURI);
        creationDate[_tokenIdTracker.current()] = block.timestamp;
        _ceramicIDs[_tokenIdTracker.current()] = _ceramicStream;
        emit MINT(_tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function retroactiveMint(
        address[] memory to,
        string[] memory _tokenURI,
        string[] memory _ceramicStream
    ) external virtual _onlyDAOAdmin {
        require(
            to.length == _tokenURI.length &&
                _tokenURI.length == _ceramicStream.length &&
                to.length > 1,
            "ERC721: Invalid data."
        );
        uint256 i;
        while (i < to.length) {
            this.mint(to[i], _tokenURI[i], _ceramicStream[i]);
            i++;
        }
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721) {
        require(transferEnabled, "ERC721: Unable to transfer NFT");

        super._transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721) {
        require(transferEnabled, "ERC721: Unable to transfer NFT");
        super.safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override(ERC721) {
        require(transferEnabled, "ERC721: Unable to transfer NFT");
        super._safeTransfer(from, to, tokenId, _data);
    }

    // @notice Burns the NFT with a specific token ID
    // @param _tokenId The ID of the token to burn
    function _burn(uint256 _tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        _burn(_tokenId);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `DAO_ADMIN_ROLE`.
     */
    function pause() public virtual _onlyDAOAdmin {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `DAO_ADMIN_ROLE`.
     */
    function unpause() public virtual _onlyDAOAdmin {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
