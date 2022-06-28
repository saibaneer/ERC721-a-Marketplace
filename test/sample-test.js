const { expect } = require("chai");
const { assert } = require("chai");
const { ethers } = require("hardhat");

describe("New Monion Contract", function () {
  let admin;
  let minter;
  let vault;
  let lister;
  let commerce;
  let timerContract1;

  let deployer;
  let alice;
  let bob;
  let charlie;

  let marketFee = 200;
  before(async function () {
    [deployer, alice, bob, charlie] = await ethers.getSigners();
    const Admin = await ethers.getContractFactory("AdminConsole");
    admin = await Admin.deploy();
    await admin.deployed();
    console.log(`Admin contract address is ${admin.address}`);

    const Minter = await ethers.getContractFactory("Minter");
    minter = await Minter.deploy("Monion", "MNN", 200);
    await minter.deployed();
    console.log(`Minter contract address is ${minter.address}`);

    const Vault = await ethers.getContractFactory("MyNFTStorage");
    vault = await Vault.deploy(minter.address, admin.address);
    await vault.deployed();
    console.log(`Vault contract address is ${vault.address}`);

    const Lister = await ethers.getContractFactory("Listing");
    lister = await Lister.deploy(vault.address);
    await lister.deployed();
    console.log(`Lister contract address is ${lister.address}`);

    const Commerce = await ethers.getContractFactory("Commerce");
    commerce = await Commerce.deploy(vault.address, admin.address);
    await commerce.deployed();
    console.log(`Commerce contract address is ${commerce.address}`);
  });
  it("should allow admin add all the member contracts", async function () {
    // let adminArr = [minter.address, vault.address, lister.address, commerce.address];
    // for(let i = 0; i < adminArr; i++){
    //   await admin.connect(deployer).addMember(adminArr[i]);
    //   console.log("Added: ", adminArr[i])
    // }
    await admin.connect(deployer).addMember(minter.address);
    await admin.connect(deployer).addMember(vault.address);
    await admin.connect(deployer).addMember(lister.address);
    await admin.connect(deployer).addMember(commerce.address);

    await admin.connect(deployer).setFeeAccount(deployer.address);
    await admin.connect(deployer).setFeePercent(marketFee);

    expect(await admin.connect(deployer).getFeeAccount()).to.equal(
      deployer.address
    );
    expect(await admin.connect(deployer).getFeePercent()).to.equal(200);
    expect(await admin.connect(deployer).isAdmin(minter.address)).to.equal(
      true
    );
    expect(await admin.connect(deployer).isAdmin(vault.address)).to.equal(true);
    expect(await admin.connect(deployer).isAdmin(lister.address)).to.equal(
      true
    );
    expect(await admin.connect(deployer).isAdmin(commerce.address)).to.equal(
      true
    );
  });
  it("should NOT allow a non-admin member to add users to add addresses to the admin address array", async function () {
    try {
      await admin.connect(alice).addMember(alice.address);
    } catch (error) {
      assert(
        error.message.includes("You do not have permission to add members")
      );
      return;
    }
    assert(false);
  });
  it("should allow user to mint!", async function () {
    const test_uri = "our-api";
    // await minter.connect(alice).safeMint(test_uri, vault.address);
    expect(await minter.connect(alice).safeMint(test_uri, vault.address))
      .to.emit(minter, "Minted")
      .withArgs(1, vault.address, minter.address);
  });
  it("should allow users to list minted nft", async function () {
    // const price = ethers.utils.parseEther(1);
    // console.log(price);
    expect(
      await lister.connect(alice).addListingForSale(minter.address, 1, 300000)
    ).to.emit(vault, "ListedForSale");
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(
      alice.address
    );
  });

  it("should allow other users to buy minted nft", async function () {
    const priceInEther = await vault.getTokenPrice(1, minter.address);
    // console.log(priceInEther);
    await commerce.connect(bob).buy(1, minter.address, { value: priceInEther });
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(bob.address);
  });
  it("should allow the owner withdraw their NFT", async function () {
    await commerce.connect(bob).withdrawNFTs(1, minter.address);
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(
      await admin.returnAddressZero()
    );
  });
  it("should allow the owner of a token list the token for bidding", async function () {
    await minter.connect(bob).setApprovalForAll(vault.address, true);
    //await lister.connect(bob).addListingForBid(minter.address, 1, 500000, 2);
    expect(
      await lister.connect(bob).addListingForBid(minter.address, 1, 500000, 2)
    ).to.emit(vault, "ListedForBid");
    timerContract1 = await vault.fetchBidContract(1, minter.address);
    // console.log("Timer contract is: ", timerContract1)
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(bob.address);
  });
  it("should allow other users send in a bid", async function () {
    const bidVal1 = 600000;
    await commerce.connect(alice).bid(1, minter.address, { value: bidVal1 });
    const tx1 = await commerce.connect(alice).confirmBid(1, minter.address);
    expect(tx1.thisBid).to.equal(bidVal1);
    expect(tx1.bidder).to.equal(alice.address);

    const bidVal2 = 650000;
    await commerce.connect(charlie).bid(1, minter.address, { value: bidVal2 });
    const tx2 = await commerce.connect(charlie).confirmBid(1, minter.address);
    expect(tx2.thisBid).to.equal(bidVal2);
    expect(tx2.bidder).to.equal(charlie.address);

    const bidVal3 = 750000;
    await commerce.connect(deployer).bid(1, minter.address, { value: bidVal3 });
    const tx3 = await commerce.connect(deployer).confirmBid(1, minter.address);
    expect(tx3.thisBid).to.equal(bidVal3);
    expect(tx3.bidder).to.equal(deployer.address);
  });
  it("should allow a user withdraw their bid", async function () {
    await commerce.connect(deployer).withdrawBid(1, minter.address);
    const tx1 = await commerce.connect(deployer).confirmBid(1, minter.address);
    expect(tx1.thisBid).to.equal(0);
    expect(tx1.bidder).to.equal(deployer.address);
  });
  it("should NOT allow a bidder claim tokens before the bid ends", async function () {
    try {
      await commerce.connect(charlie).claimItem(1, minter.address);
    } catch (error) {
      assert(
        error.message.includes("Auction is still open, wait until close!")
      );
      return;
    }
    assert(false);
  });
  it("should NOT allow a lower bidder claim tokens", async function () {
    try {
      await ethers.provider.send("evm_increaseTime", [3 * 60 * 60]);
      await ethers.provider.send("evm_mine");
      await commerce.connect(bob).claimItem(1, minter.address);
    } catch (error) {
      assert(error.message.includes("You are not the highest bidder"));
      return;
    }
    assert(false);
  });
  it("should allow the highest bidder claim the tokens", async function () {
    await ethers.provider.send("evm_increaseTime", [3 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    await commerce.connect(charlie).claimItem(1, minter.address);
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(
      charlie.address
    );
  });
  it("should allow the other user who lost the bid to withdraw bid", async function () {
    await commerce.connect(alice).withdrawBid(1, minter.address);
    const tx1 = await commerce.connect(alice).confirmBid(1, minter.address);
    expect(tx1.thisBid).to.equal(0);
    expect(tx1.bidder).to.equal(alice.address);
  });
  it("should allow the winner of the bid to withdraw token", async function () {
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(
      charlie.address
    );
    await commerce.connect(charlie).withdrawNFTs(1, minter.address);
    expect(await vault.getTokenOwner(1, minter.address)).to.equal(
      await admin.returnAddressZero()
    );
  });
  describe("Test New Batch related features", function () {
    let newNFT;

    it("should mint 10 tokens for Alice", async function () {
      // expect(await lister.connect(alice).batchMinting("Sweet Tea Buns", "STB", 100, 10)).to.emit(lister, "Minted");
      const tokenName = "Sweet Tea Buns";
      const tokenSymbol = "STB";
      const tokenRoyalty = 100;
      const tokenQuantity = 10;
      await lister
        .connect(alice)
        .batchMinting(tokenName, tokenSymbol, tokenRoyalty, tokenQuantity);
      // await receipt.wait(1)
      // console.log(receipt.events[0].args[0])
      const eventFilter = lister.filters.Minted();
      const events = await lister.queryFilter(eventFilter, "latest");
      expect(alice.address).to.equal(events[0].args.owner);
      expect(tokenRoyalty).to.equal(events[0].args.fees);
      expect(tokenQuantity).to.equal(events[0].args.quantity);
      newNFT = events[0].args.nftAddress;
      console.log("Minted NFT address is: ", newNFT);
      // console.log("Owner address is: ", events[0].args.owner);
      // console.log("Quantity is: ", events[0].args.quantity.toString());
      // console.log("Fees are : ", events[0].args.fees.toString());
    });
    it("should mint additional tokens for Alice", async function () {
      expect(await lister.connect(alice).mintFromOwnersNFT(newNFT, 4))
        .to.emit(lister, "Minted")
        .withArgs(newNFT, alice.address, 4, 100);
    });
    it("should NOT allow users to list tokens they do not own!", async function () {
      try {
        await lister.connect(bob).addListingForSale(newNFT, 3, 300000);
      } catch (error) {
        assert(
          error.message.includes(
            "You do not have permission to list this token"
          )
        );
        return;
      }
      assert(false);
    });
    it("should NOT allow users call the vault contract directly!", async function () {
      try {
        await vault
          .connect(alice)
          ._createListingForSale(newNFT, 3, 300000, alice.address);
      } catch (error) {
        assert(
          error.message.includes(
            "You do not have permission to access this contract!"
          )
        );
        return;
      }
      assert(false);
    });
    it("should allow the user list 5 tokens in a batch for sale", async function () {
      const myIds = [0, 1, 2, 3, 4];
      const tokenPrice = ethers.utils.parseEther("2");
      const contractObject = await ethers.getContractAt(
        "BatchMinter",
        newNFT.toString()
      );
      await contractObject
        .connect(alice)
        .setApprovalForAll(vault.address, true);
      await lister
        .connect(alice)
        .batchListingForSale(newNFT, myIds, tokenPrice);
      expect(await vault.getTokenOwner(0, newNFT)).to.equal(alice.address);
      expect(await vault.getTokenOwner(1, newNFT)).to.equal(alice.address);
      expect(await vault.getTokenOwner(2, newNFT)).to.equal(alice.address);
      expect(await vault.getTokenOwner(3, newNFT)).to.equal(alice.address);
      expect(await vault.getTokenOwner(4, newNFT)).to.equal(alice.address);
    });
    it("should allow the user list 5 tokens in a batch for bids!", async function () {
      const myIds = [5, 6, 7, 8, 9];
      const tokenPrice = ethers.utils.parseEther("3");
      const contractObject = await ethers.getContractAt(
        "BatchMinter",
        newNFT.toString()
      );
      await contractObject
        .connect(alice)
        .setApprovalForAll(vault.address, true);
      await lister
        .connect(alice)
        .batchListingForBid(newNFT, myIds, tokenPrice, 1);
      expect(await vault.fetchBidContract(5, newNFT)).to.not.equal(
        await admin.returnAddressZero()
      );
      expect(await vault.fetchBidContract(6, newNFT)).to.not.equal(
        await admin.returnAddressZero()
      );
      expect(await vault.fetchBidContract(7, newNFT)).to.not.equal(
        await admin.returnAddressZero()
      );
      expect(await vault.fetchBidContract(8, newNFT)).to.not.equal(
        await admin.returnAddressZero()
      );
      expect(await vault.fetchBidContract(9, newNFT)).to.not.equal(
        await admin.returnAddressZero()
      );
    });
  });
  xdescribe("Test Batch Related Functions", function () {
    let fireNationNFT;

    before(async function () {
      //mint a batch NFT
      const BatchMinter = await ethers.getContractFactory("BatchMinter");
      fireNationNFT = await BatchMinter.deploy("FireNation", "ZUKO", 200, 10);
      await fireNationNFT.deployed();
    });
    it("should mint 10 fire nation tokens", async function () {
      await fireNationNFT.connect(alice).mint(vault.address);
      expect(await fireNationNFT.balanceOf(alice.address)).to.equal(10);
    });
    it("should NOT allow users to list tokens they do not own!", async function () {
      try {
        await lister
          .connect(bob)
          .addListingForSale(fireNationNFT.address, 3, 300000);
      } catch (error) {
        assert(
          error.message.includes(
            "You do not have permission to list this token"
          )
        );
        return;
      }
      assert(false);
    });
    it("should NOT allow users call the vault contract directly!", async function () {
      try {
        await vault
          .connect(alice)
          ._createListingForSale(
            fireNationNFT.address,
            3,
            300000,
            alice.address
          );
      } catch (error) {
        assert(
          error.message.includes(
            "You do not have permission to access this contract!"
          )
        );
        return;
      }
      assert(false);
    });
    it("should allow the user list 5 tokens in a batch for sale", async function () {
      const myIds = [0, 1, 2, 3, 4];
      const tokenPrice = ethers.utils.parseEther("2");
      await lister
        .connect(alice)
        .batchListingForSale(fireNationNFT.address, myIds, tokenPrice);
      expect(await vault.getTokenOwner(0, fireNationNFT.address)).to.equal(
        alice.address
      );
      expect(await vault.getTokenOwner(1, fireNationNFT.address)).to.equal(
        alice.address
      );
      expect(await vault.getTokenOwner(2, fireNationNFT.address)).to.equal(
        alice.address
      );
      expect(await vault.getTokenOwner(3, fireNationNFT.address)).to.equal(
        alice.address
      );
      expect(await vault.getTokenOwner(4, fireNationNFT.address)).to.equal(
        alice.address
      );
    });
    it("should allow the user list 5 tokens in a batch for bids!", async function () {
      const myIds = [5, 6, 7, 8, 9];
      const tokenPrice = ethers.utils.parseEther("3");
      await lister
        .connect(alice)
        .batchListingForBid(fireNationNFT.address, myIds, tokenPrice, 1);
      expect(
        await vault.fetchBidContract(5, fireNationNFT.address)
      ).to.not.equal(await admin.returnAddressZero());
      expect(
        await vault.fetchBidContract(6, fireNationNFT.address)
      ).to.not.equal(await admin.returnAddressZero());
      expect(
        await vault.fetchBidContract(7, fireNationNFT.address)
      ).to.not.equal(await admin.returnAddressZero());
      expect(
        await vault.fetchBidContract(8, fireNationNFT.address)
      ).to.not.equal(await admin.returnAddressZero());
      expect(
        await vault.fetchBidContract(9, fireNationNFT.address)
      ).to.not.equal(await admin.returnAddressZero());
    });
    describe("Test Royalty Related functions", function () {
      let aliceBalanceBeforeTx1;
      let marketBalanceBeforeTx1;

      let aliceBalanceAfterTx1;
      let aliceBalanceAfterTx2;
      before(async function () {
        aliceBalanceBeforeTx1 = await ethers.provider.getBalance(alice.address);
        marketBalanceBeforeTx1 = await ethers.provider.getBalance(
          deployer.address
        );
      });
      it("should test that royalties are distributed for minter during sale", async function () {
        const tokenPrice = await vault.getTokenPrice(0, fireNationNFT.address);
        await commerce
          .connect(bob)
          .buy(0, fireNationNFT.address, { value: tokenPrice });
        await commerce.connect(alice).withdrawFunds();
        // const bal = await commerce.connect(deployer).getBalance();

        await commerce.connect(deployer).withdrawMarketfunds();
        aliceBalanceAfterTx1 = await ethers.provider.getBalance(alice.address);
        let marketBalanceAfterTx1 = await ethers.provider.getBalance(
          deployer.address
        );
        // // console.log("Balance after: ", aliceBalanceAfterTx1)
        const diff1 = aliceBalanceAfterTx1 - aliceBalanceBeforeTx1;
        const diff2 = marketBalanceAfterTx1 - marketBalanceBeforeTx1;
        expect(diff1).to.be.greaterThan(0);
        expect(diff2).to.be.greaterThan(0);
        // console.log(diff2)
      });
      it("should test that secondary royalties are paid", async function () {
        const tokenPrice = ethers.utils.parseEther("4");
        await lister
          .connect(bob)
          .relistToken_forSale(fireNationNFT.address, 0, tokenPrice);

        const getListedPrice = await vault.getTokenPrice(
          0,
          fireNationNFT.address
        );
        const creatorBalanceBefore = await commerce.connect(alice).getBalance();
        await commerce
          .connect(charlie)
          .buy(0, fireNationNFT.address, { value: getListedPrice });
        const creatorBalanceAfter = await commerce.connect(alice).getBalance();
        assert(creatorBalanceAfter > creatorBalanceBefore);
      });
      it("should test that royalties are distributed for minter after bid", async function () {
        const bidVal0 = ethers.utils.parseEther("4");
        await lister
          .connect(charlie)
          .relistToken_forBid(fireNationNFT.address, 0, bidVal0, 1);

        const bidVal2 = ethers.utils.parseEther("5");
        await commerce
          .connect(alice)
          .bid(6, fireNationNFT.address, { value: bidVal2 });
        const tx2 = await commerce
          .connect(alice)
          .confirmBid(6, fireNationNFT.address);
        expect(tx2.thisBid).to.equal(bidVal2);
        expect(tx2.bidder).to.equal(alice.address);

        const bidVal1 = ethers.utils.parseEther("6");
        await commerce
          .connect(bob)
          .bid(6, fireNationNFT.address, { value: bidVal1 });
        const tx1 = await commerce
          .connect(bob)
          .confirmBid(6, fireNationNFT.address);
        expect(tx1.thisBid).to.equal(bidVal1);
        expect(tx1.bidder).to.equal(bob.address);

        await ethers.provider.send("evm_increaseTime", [2 * 60 * 60]);
        await ethers.provider.send("evm_mine");

        //Let's observe the bidding contract
        //get timer contract
        const timerAddress = await vault.fetchBidContract(
          6,
          fireNationNFT.address
        );
        let timerContract = await ethers.getContractAt("Timer", timerAddress);
        const [highestBidder, highestBid] = await timerContract._maxBidCalc();
        // const highestBidder = await timerContract.maximumBidder();
        console.log(`The highest bid is ${highestBid} from ${highestBidder}`);
        //call function on timer contract, and console.log
        expect(highestBidder).to.equal(bob.address);
        expect(highestBid).to.equal(bidVal1);

        console.log(
          "Alice's balance before claiming: ",
          await commerce.connect(alice).getBalance()
        );
        let aliceBalanceBeforeTx2 = await commerce.connect(alice).getBalance();
        await commerce.connect(bob).claimItem(6, fireNationNFT.address);
        console.log(
          "Alice's balance after  claiming: ",
          await commerce.connect(alice).getBalance()
        );
        expect(await vault.getTokenOwner(6, fireNationNFT.address)).to.equal(
          bob.address
        );
        expect(await vault.getTokenStatus(6, fireNationNFT.address)).to.equal(
          2
        );
        aliceBalanceAfterTx2 = await commerce.connect(alice).getBalance();
        const diff = aliceBalanceAfterTx2 - aliceBalanceBeforeTx2;
        expect(diff).to.be.greaterThan(0);
      });
    });
  });
});
