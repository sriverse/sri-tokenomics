import { expect } from "chai";
import { ethers } from "hardhat";

let SRI_ADDRESS = "";

const delay = (seconds : number) => {
    return new Promise((resolve) => {
        setTimeout(resolve, seconds * 1000)
    })
}

describe("Vesting", function () {

    async function deployVestingContract(): Promise<any> {
        // Contracts are deployed using the first signer/account by default

        const MockUSDT = await ethers.getContractFactory("MockUSDT");
        const mockUSDT = await MockUSDT.deploy();
        SRI_ADDRESS = mockUSDT.address;
        const Vesting = await ethers.getContractFactory("SriTokenVesting");
        const vesting = await Vesting.deploy(mockUSDT.address);
        const [owner, otherAccount] = await ethers.getSigners();
        await vesting.deployed();

        return { vesting,owner, otherAccount, mockUSDT };
    }


    describe("Deployment", function () {
        it("Should set the right unlockTime", async function () {
            const { vesting } = await deployVestingContract();

            expect(await vesting.token()).to.equal(SRI_ADDRESS);
        });

        it("Should set the right owner", async function () {
            const { vesting, owner} = await deployVestingContract();

            expect(await vesting.owner()).to.equal(owner.address);
        });

        it("Should receive and store the funds to lock", async function () {
            const { vesting } = await deployVestingContract();

            expect(await vesting.token()).to.equal(
                SRI_ADDRESS
            );
        });

        it("Schecks initial states", async function () {
            const { vesting } = await deployVestingContract();

            expect(await vesting.beneficiary(0)).to.equal(
                "0x0000000000000000000000000000000000000000"
            );
            expect(await vesting.releaseTime(0)).to.equal(
                0
            );

            expect(await vesting.vestingAmount(0)).to.equal(
                0
            );
        });

    });

    describe("Vesting", function () {

        let sriVesting: any;
        let owner: any;
        let account1: any;
        let account2: any;


        beforeEach(async () =>{
            const { vesting } = await deployVestingContract();
            [owner, account1, account2] = await ethers.getSigners();
            sriVesting = vesting
        });
        it("should add vesting", async function () {
            console.log("adding vesting");
            const tx = await sriVesting.addVesting(account1.address, parseInt((new Date().getTime()/1000).toString()) + 10, 100 );

            const receipt = await tx.wait();

            const events = receipt.events;

            // Assert that the event was emitted
            expect(events.length).to.equal(1);

            // Assert the event name and parameters
            const event = events[0];
            expect(event.event).to.equal("TokenVestingAdded");
            expect(event.args.vestingId).to.equal(2, 'from is correct');
            expect(event.args.beneficiary).to.equal(account1.address, 'to is correct');
            expect(event.args.amount).to.equal("100", 'Value is correct');

            const releaseTime =  parseInt((new Date().getTime()/1000).toString()) + 10;
            const vestingData = await sriVesting.vestings(2);

            expect(vestingData.beneficiary).to.equal(
                account1.address
            );
            expect(vestingData.releaseTime).to.equal(
                releaseTime.toString()
            );

            expect(vestingData.amount).to.equal(
                "100"
            );

        });
    });

    describe("Release Vesting", function () {

        let sriVesting: any;
        let owner: any;
        let account1: any;
        let account2: any;
        let sriToken: any;


        beforeEach(async () =>{
            const { vesting, mockUSDT } = await deployVestingContract();
            sriToken = mockUSDT;
            [owner, account1, account2] = await ethers.getSigners();
            sriVesting = vesting
            const tx = await sriVesting.addVesting(account1.address, parseInt((new Date().getTime()/1000).toString()) + 10, 100 );

            await tx.wait();

        });

        it("should release vesting", async function () {

            await delay(10);
            const transfertx = await sriToken.transfer(sriVesting.address, 1000); // transfer token
            await transfertx.wait();
            expect(await sriToken.balanceOf(account1.address)).to.equal("0", 'pre-release balance is correct');

            const tx = await sriVesting.release(2);

            const receipt = await tx.wait();

            const events = receipt.events;

            console.log(receipt);

            // Assert that the event was emitted
            expect(events.length).to.equal(2);

            // Assert the event name and parameters
            const event = events[1];
            expect(event.event).to.equal("TokenVestingReleased");
            expect(event.args.vestingId).to.equal(2, 'from is correct');
            expect(event.args.beneficiary).to.equal(account1.address, 'to is correct');
            expect(event.args.amount).to.equal("100", 'Value is correct');

            const vestingData = await sriVesting.vestings(2);

            expect(vestingData.released).to.equal(
                true
            );

            expect(await sriToken.balanceOf(account1.address)).to.equal("100", 'balance is correct');

        });

    });


});