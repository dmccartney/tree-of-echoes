//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// This represents something that is responsible for producing the token URI for any Echo token.
interface IRenderer {
    function echoTokenURI(
        uint128 echoGenerationId,
        address echoAddress,
        uint256 tokenId
    ) external view returns (string memory);
}
