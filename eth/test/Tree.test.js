const { expect } = require("chai");
const { ethers } = require("hardhat");
const uuid = require("uuid");

const SALE_PRICE = ethers.utils.parseEther("0.01");

describe("TreeOfEchoes", function () {
  let TREE_OWNER;
  let AUTHOR_A, AUTHOR_B, AUTHOR_C;
  let READER_A, READER_B, READER_C;
  beforeEach(async function () {
    let signers = await ethers.getSigners();
    TREE_OWNER = signers[0];
    AUTHOR_A = signers[1];
    AUTHOR_B = signers[2];
    AUTHOR_C = signers[3];
    READER_A = signers[4];
    READER_B = signers[5];
    READER_C = signers[6];
  });

  it("initial tree has no echo", async function () {
    let tree = await deployTree("https://example.com/");
    expect(await tree.echoCount()).to.equal(0);
  });

  it("creating an echo mints to the author and the tree", async function () {
    let tree = await deployTree("https://example.com/");
    await tree
      .connect(AUTHOR_A)
      .createEcho(asBytes32("Echo Title"), SALE_PRICE, 10);
    expect(await tree.echoCount()).to.equal(1);
    let echo = await echoContractAt(tree, 0);
    expect(await echo.owner()).to.equal(AUTHOR_A.address);
    expect(await echo.totalSupply()).to.equal(2);
    expect(await echo.balanceOf(AUTHOR_A.address)).to.equal(1);
    expect(await echo.balanceOf(tree.address)).to.equal(1);
    expect(await echo.tokenURI(0)).to.equal(
      `https://example.com/${echo.address.toLowerCase()}/0`
    );
    expect(await echo.tokenURI(1)).to.equal(
      `https://example.com/${echo.address.toLowerCase()}/1`
    );
  });

  it("echo contract addresses are deterministic", async function () {
    let tree = await deployTree("https://example.com/");
    expect(await tree.echoCount()).to.equal(0);

    // Predict the echo address
    let before = await tree.predictEchoAddress(asBytes32("Echo Title"));

    // Then publish the Echo
    await tree
      .connect(AUTHOR_A)
      .createEcho(asBytes32("Echo Title"), SALE_PRICE, 10);

    // Then check again
    let after = await tree.predictEchoAddress(asBytes32("Echo Title"));
    let echoAddress = await tree.echoAt(0);

    // Make sure the predictions were right.
    expect(before.echoAddress).to.equal(echoAddress);
    expect(before.alreadyPublished).to.equal(false);
    expect(after.echoAddress).to.equal(echoAddress);
    expect(after.alreadyPublished).to.equal(true);
  });

  it("the tree can enumerate the echos", async function () {
    let tree = await deployTree("https://example.com/");
    await tree
      .connect(AUTHOR_A)
      .createEcho(asBytes32("Echo Title Aye"), SALE_PRICE, 10);
    await tree
      .connect(AUTHOR_B)
      .createEcho(asBytes32("Echo Title Bee"), SALE_PRICE, 10);
    await tree
      .connect(AUTHOR_C)
      .createEcho(asBytes32("Echo Title Cee"), SALE_PRICE, 10);

    expect(await tree.echoCount()).to.equal(3);
    let owners = await Promise.all(
      [0, 1, 2].map(async (index) => {
        let echo = await echoContractAt(tree, index);
        return await echo.owner();
      })
    );
    expect(owners).to.have.members([
      AUTHOR_A.address,
      AUTHOR_B.address,
      AUTHOR_C.address,
    ]);
  });

  it("identifiers can be uuids", async function () {
    let tree = await deployTree("https://example.com/");
    let IDs = [
      { author: AUTHOR_A, id: "11111111-1111-1111-8888-111111111111" },
      { author: AUTHOR_B, id: "22222222-2222-2222-8888-222222222222" },
      { author: AUTHOR_C, id: "33333333-3333-3333-8888-333333333333" },
    ];
    let uuidAsBytes32 = (id) => ethers.utils.zeroPad(uuid.parse(id), 32);
    // lookup each echo's address
    // e.g. predictedAddress[0] == address where id "11111111-1111..." will be created
    let predictedAddress = await Promise.all(
      IDs.map(async ({ id }) => {
        let [echoAddress, alreadyPublished] = await tree.predictEchoAddress(
          uuidAsBytes32(id)
        );
        return echoAddress;
      })
    );

    await Promise.all(
      IDs.map(({ author, id }) =>
        tree.connect(author).createEcho(uuidAsBytes32(id), SALE_PRICE, 10)
      )
    );

    // Now we verify that they all published at the predicted addreses.
    await Promise.all(
      IDs.map(async ({ author, id }, i) => {
        let echo = await ethers.getContractAt("Echo", predictedAddress[i]);
        expect(await echo.owner()).to.equal(author.address);
      })
    );
  });

  it("free mints are free", async function () {
    let tree = await deployTree("https://example.com/");

    await tree
      .connect(AUTHOR_A)
      .createEcho(asBytes32("Echo Title"), 0 /* = FREE */, 10);
    let echo = await echoContractAt(tree, 0);
    expect(await echo.mintPrice()).to.equal(0);
    await echo.connect(READER_A).mint(/* no payment value */);
    expect(await echo.totalSupply()).to.equal(3);
    expect(await echo.balanceOf(READER_A.address)).to.equal(1);
  });

  it("authors can update their price", async function () {
    let tree = await deployTree("https://example.com/");

    await tree
      .connect(AUTHOR_A)
      .createEcho(asBytes32("Echo Title"), SALE_PRICE, 10);
    let echo = await echoContractAt(tree, 0);

    // Now pretend Author A wants to bump up the price on their Echo
    let TEN_ETH = ethers.utils.parseEther("10");
    await echo.connect(AUTHOR_A).updatePrice(TEN_ETH);
    expect(await echo.mintPrice()).to.equal(TEN_ETH);

    await expect(echo.connect(READER_A).mint(/* no payment value */)).to.be
      .reverted;
    await echo.connect(READER_A).mint({ value: TEN_ETH });
    expect(await echo.totalSupply()).to.equal(3);
  });

  it("supply limits are enforced", async function () {
    let tree = await deployTree("https://example.com/");
    await tree
      .connect(AUTHOR_A)
      .createEcho(asBytes32("Echo Title"), SALE_PRICE, 10);
    let echo = await echoContractAt(tree, 0);
    for (let i = 0; i < 8; i++) {
      await echo.connect(READER_A).mint({ value: SALE_PRICE });
    }
    expect(await echo.totalSupply()).to.equal(10);

    // And now the 11th one should fail.
    await expect(echo.connect(READER_A).mint({ value: SALE_PRICE })).to.be
      .reverted;
  });
});

// Helpers
async function deployTree(baseURI) {
  const Tree = await ethers.getContractFactory("Tree");
  const tree = await Tree.deploy();
  await tree.deployed();
  await tree.setBaseURI(baseURI);
  return tree;
}

async function echoContractAt(tree, index) {
  let echoAddress = await tree.echoAt(index);

  return await ethers.getContractAt("Echo", echoAddress);
}

function asBytes32(text) {
  return ethers.utils.formatBytes32String(text);
}
