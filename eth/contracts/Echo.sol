//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRenderer.sol";

contract Echo is ERC721 {
    // This configuration is supplied during a clone's initialization.
    struct Config {
        address treeAddress;
        address authorAddress;
        // The generation ("batch") of this Echo.
        uint128 generationId;
        // The price to mint (zero indicates free).
        uint112 price;
        // The number that have been minted.
        uint8 totalSupply;
        // The number that _can_ be minted (zero indicates no-limit).
        uint8 supplyLimit;
    }
    Config config;

    // Throws if called by anyone other than the author.
    modifier onlyAuthor() {
        require(config.authorAddress == msg.sender, "Echo: not authorized");
        _;
    }

    // Throws if called by anything other than the tree.
    modifier onlyTree() {
        require(config.treeAddress == msg.sender, "Echo: not authorized");
        _;
    }

    // Throws if called by anyone other than the author or the tree.
    modifier onlyAuthorOrTree() {
        require(
            config.treeAddress == msg.sender ||
                config.authorAddress == msg.sender,
            "Echo: not authorized"
        );
        _;
    }

    constructor() ERC721("", "") {}

    // When a clone is initialized, it gets the author's address and supply limit.
    function initialize(
        address treeAddress,
        address authorAddress,
        uint128 generationId,
        uint112 price,
        uint8 supplyLimit
    ) external {
        require(config.treeAddress == address(0), "Echo: already configured");
        config = Config(
            treeAddress,
            authorAddress,
            generationId,
            price,
            0,
            supplyLimit
        );
        // One token goes to the author.
        _mint(authorAddress, generateTokenId());
        // Another token goes to the tree.
        _mint(treeAddress, generateTokenId());
        // The remaining are for sale.
    }

    function name() public view virtual override returns (string memory) {
        return "Echo";
    }

    function symbol() public view virtual override returns (string memory) {
        return "ECHO";
    }

    // This allows the author to control the OpenSea collection listing.
    function owner() public view virtual returns (address) {
        return config.authorAddress;
    }

    // Reports the generation ("batch") of this Echo.
    function generation() public view virtual returns (uint128) {
        return config.generationId;
    }

    // The number that have been minted.
    function totalSupply() external view returns (uint256) {
        return config.totalSupply;
    }

    function configuration() external view returns (Config memory) {
        return config;
    }

    // We ask the Tree for the token URI.
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            IRenderer(config.treeAddress).echoTokenURI(
                config.generationId,
                address(this),
                tokenId
            );
    }

    //
    // Minting
    //

    function mint() external payable {
        require(config.price == msg.value, "Echo: bad payment");
        _safeMint(msg.sender, generateTokenId());
    }

    function mintPrice() external view returns (uint112) {
        return config.price;
    }

    //
    // Admin methods
    //

    // This allows the author to withdraw any received funds.
    function withdraw() external onlyAuthor {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // This allows the author to withdraw any received ERC20 tokens.
    function withdrawERC20Tokens(IERC20 token) external onlyAuthor {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    // This allows the author to withdraw any received ERC721 tokens.
    function withdrawERC721Token(IERC721 token, uint256 tokenId)
        external
        onlyAuthor
    {
        token.transferFrom(address(this), msg.sender, tokenId);
    }

    // Update the author address for the echo.
    function updateAuthor(address authorAddress) external onlyAuthorOrTree {
        config.authorAddress = authorAddress;
    }

    // Update the author address for the echo.
    function updatePrice(uint112 price) external onlyAuthor {
        config.price = price;
    }

    // Helper to generate the next token ID and update counters.
    function generateTokenId() internal returns (uint256) {
        // When supplyLimit is 0 that indicates that there is no limit.
        require(
            config.supplyLimit == 0 || config.totalSupply < config.supplyLimit,
            "Echo: no supply remaining"
        );
        uint256 tokenId = config.totalSupply;
        config.totalSupply += 1;
        return tokenId;
    }

    // TODO: royalties
}
