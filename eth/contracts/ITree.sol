//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ITree {
    function echoBaseURI(address echoAddress)
        external
        view
        returns (string memory);
}
