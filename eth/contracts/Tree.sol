//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Echo.sol";
import "./IRenderer.sol";

// This lets authors create Echos -- stories drafted on the coven website and memorialized on chain.
//
// Each Echo is an ERC721 contract created with its own address.
// The author can set the price and supply limits (or make it free and unlimited).
// See createEcho()
//
// Each Echo also belongs to a "generation". The generations are used by the Tree
// to find the corresponding storage URIs. At first each generation is served
// from the coven website. But as each generation is "sealed" to IPFS the Tree
// begins pointing at IPFS for the Echos in that generation.
// See sealToIPFS(), setGenerationId()
//
contract Tree is Ownable, IRenderer, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    event EchoPublished(
        address indexed echoAddress,
        address indexed authorAddress
    );
    event EchoRemoved(address indexed echoAddress);
    event EchoMinted(address indexed echoAddress, address indexed buyerAddress);

    EnumerableSet.AddressSet echos;

    address immutable echoImplementation; // contains the byte code for created Echoes
    address renderer; // IRenderer that produces echo token URIs
    uint128 generationId;

    constructor() {
        // Deploys the implementation that will be cloned for each Echo.
        echoImplementation = address(new Echo());
    }

    // This predicts the `echoAddress` that will be created for an Echo with the specified `identifier`.
    // It also reports whether that Echo is `alreadyPublished`.
    //
    // This is helpful for arranging metadata before publication using the eventual contract address.
    function predictEchoAddress(bytes32 identifier)
        external
        view
        returns (address echoAddress, bool alreadyPublished)
    {
        echoAddress = Clones.predictDeterministicAddress(
            echoImplementation,
            identifier
        );
        alreadyPublished = echoAddress.isContract();
    }

    // Creates a new echo (ERC721 collection).
    // The new ERC721 will be at the address determined by the `identifier`. See #predictEchoAddress()
    //
    // A `price` of zero indicates it is free.
    // A `supplyLimit` of zero indicates there is no limit.
    // NOTE: `price` can be modified later via Echo.updatePrice()
    function createEcho(
        bytes32 identifier,
        uint112 price,
        uint8 supplyLimit
    ) external returns (address) {
        // TODO: consider using a captcha or requiring nominal payment
        address echoAddress = Clones.cloneDeterministic(
            echoImplementation,
            identifier
        );
        echos.add(echoAddress);
        Echo(echoAddress).initialize(
            address(this),
            msg.sender,
            generationId,
            price,
            supplyLimit
        );
        emit EchoPublished(echoAddress, msg.sender);
        return echoAddress;
    }

    function echoTokenURI(
        uint128 echoGenerationId,
        address echoAddress,
        uint256 tokenId
    ) external view override returns (string memory) {
        require(echos.contains(echoAddress), "Tree: unknown echo");
        return
            IRenderer(renderer).echoTokenURI(
                echoGenerationId,
                echoAddress,
                tokenId
            );
    }

    function setRenderer(address _renderer) external onlyOwner {
        renderer = _renderer;
    }

    //
    // Echo enumeration
    //
    function echoCount() external view returns (uint256) {
        return echos.length();
    }

    function echoAt(uint256 index) external view returns (address) {
        return echos.at(index);
    }

    //
    // Admin methods
    //

    // Updates the generation ("batch") for all subsequently created Echoes.
    function setGenerationId(uint128 _generationId) external onlyOwner {
        generationId = _generationId;
    }

    // Removes the echo from the tree.
    function removeEcho(address echoAddress) external onlyOwner {
        require(echos.contains(echoAddress), "unknown echo");
        echos.remove(echoAddress);
        emit EchoRemoved(echoAddress);
    }

    // Update the author for the specified Echo.
    function updateAuthor(address echoAddress, address authorAddress)
        external
        onlyOwner
    {
        require(echos.contains(echoAddress), "unknown echo");
        Echo(echoAddress).updateAuthor(authorAddress);
    }

    // This allows the owner to withdraw any received funds.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // This allows the owner to withdraw any received ERC20 tokens.
    function withdrawERC20Tokens(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    // This allows the owner to withdraw any received ERC721 tokens.
    function withdrawERC721Token(IERC721 token, uint256 tokenId)
        external
        onlyOwner
    {
        token.transferFrom(address(this), msg.sender, tokenId);
    }
}
