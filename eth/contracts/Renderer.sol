//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IRenderer.sol";

// This is responsible for producing the token URI for each Echo token.
contract Renderer is IRenderer, Ownable {
    mapping(uint128 => string) ipfsCidByGenerationId;
    string defaultBaseURI;

    constructor(string memory _defaultBaseURI) {
        defaultBaseURI = _defaultBaseURI;
    }

    // This produces the token URI for the Echo token.
    // It yields an IPFS URI when the Echo belongs to a generation that has been sealed to IPFS.
    // Otherwise, it uses the web `defaultBaseURI`.
    function echoTokenURI(
        uint128 echoGenerationId,
        address echoAddress,
        uint256 tokenId
    ) external view override returns (string memory) {
        string memory baseURI = defaultBaseURI;
        string storage ipfsCidSlug = ipfsCidByGenerationId[echoGenerationId];
        if (bytes(ipfsCidSlug).length > 0) {
            baseURI = string(abi.encodePacked("ipfs://", ipfsCidSlug, "/"));
        }
        return
            string(
                abi.encodePacked(
                    baseURI,
                    Strings.toHexString(uint160(echoAddress), 20),
                    "/",
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    // Updates the base URI used by Echos that have not yet been sealed to IPFS.
    function setDefaultBaseURI(string memory uri) external onlyOwner {
        defaultBaseURI = uri;
    }

    // Seals all Echos that belong to `generationId` into IPFS at the specified `ipfsCid`.
    // Future calls for these Echo's token URIs will point at IPFS.
    function sealToIPFS(uint128 generationId, string memory ipfsCid)
        external
        onlyOwner
    {
        ipfsCidByGenerationId[generationId] = ipfsCid;
    }
}
