# Tree of Echoes

This contains an example of how a `Tree` of Echoes can let authors create an `Echo`.

Each `Echo` is a standalone ERC721 collection. When an `Echo` is published it sends
two tokens automatically: one to the author and another to the `Tree` to echo for eternity.

The author can configure their `Echo` to allow readers to `mint` an edition as a token.
The author can set a price or make it free to mint. Any money from minting or royalties go to the author.
And the author can configure whether it has a limited supply or no limit at all.
The author also controls the OpenSea listing for the collection.

The `Tree` (i.e. the coven) has some limited controls over the `Echo`:
the coven can update the author on an `Echo` or remove a misbehaving `Echo` from the `Tree`.

## Tech Details

- the `Tree` uses [EIP 1167](https://eips.ethereum.org/EIPS/eip-1167) to clone-create each `Echo` as a stand-alone ERC721 with its own address etc.
- each `Echo` has a deterministic address based on a supplied `bytes32 identifier` (so we know it's address ahead-of-time)
- each `Echo` defers to the `Tree` to "render" the `tokenURI`
- the `Tree` has a configurable `Renderer` which it, in turn, uses to generate each `tokenURI`
- the `Renderer` can be changed later but this edition produces IPFS URIs (when the Echo has been sealed to IPFS) and falls back to a web URI when it hasn't been sealed yet. 
