import {expect} from "chai";
import {ethers} from "hardhat";

let SRI_ADDRESS = "";

const delay = (seconds: number) => {
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

        return {vesting, owner, otherAccount, mockUSDT};
    }


    describe("Deployment", function () {
        it("Should set the right unlockTime", async function () {
            const {vesting} = await deployVestingContract();

            expect(await vesting.token()).to.equal(SRI_ADDRESS);
        });

        it("Should set the right owner", async function () {
            const {vesting, owner} = await deployVestingContract();

            expect(await vesting.owner()).to.equal(owner.address);
        });

        it("Should receive and store the funds to lock", async function () {
            const {vesting} = await deployVestingContract();

            expect(await vesting.token()).to.equal(
                SRI_ADDRESS
            );
        });

        it("Schecks initial states", async function () {
            const {vesting} = await deployVestingContract();

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
        let sriToken: any;
        let owner: any;
        let account1: any;
        let account2: any;
        let account3: any;
        let account4: any;
        let account5: any;


        beforeEach(async () => {
            const {vesting, mockUSDT} = await deployVestingContract();
            [owner, account1, account2, account3, account4, account5] = await ethers.getSigners();
            // console.log(account1.address);
            // console.log(account2.address);
            // console.log(account3.address);
            // console.log(account4.address);
            // console.log(account5.address);

            sriVesting = vesting
            sriToken = mockUSDT;

        });
        it("should request vesting", async function () {
            console.log("adding vesting");
            const tx = await sriVesting.connect(account1).addVestingRequest(account1.address, parseInt((new Date().getTime() / 1000).toString()) + 10, 100);

            const receipt = await tx.wait();

            const events = receipt.events;

            // Assert that the event was emitted
            expect(events.length).to.equal(1);

            // Assert the event name and parameters
            const event = events[0];
            expect(event.event).to.equal("VestingRequestCreated");
            expect(event.args.vestingRequestId).to.equal(1, 'from is correct');
            expect(event.args.beneficiary).to.equal(account1.address, 'to is correct');
            expect(event.args.amount).to.equal("100", 'Value is correct');
            expect(event.args.requestedBy).to.equal(account1.address, 'Value is correct');


            const releaseTime = parseInt((new Date().getTime() / 1000).toString()) + 10;
            const vestingData = await sriVesting.vestingRequest(1);

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

        it("should approve vesting request", async function () {
            console.log("adding vesting");
            const tx0 = await sriVesting.connect(account1).addVestingRequest(account1.address, parseInt((new Date().getTime() / 1000).toString()) + 10, 100);

            const receipt0 = await tx0.wait();
            const tx = await sriVesting.connect(account2).approveVestingRequest(1);

            const receipt = await tx.wait();

            // const tx1 = await sriVesting.approveVestingRequest(1);

            const events = receipt.events;

            // Assert that the event was emitted
            expect(events.length).to.equal(1);

            // Assert the event name and parameters
            const event = events[0];
            expect(event.event).to.equal("VestingRequestApprove");
            expect(event.args.vestingRequestId).to.equal(1, 'request ID is correct');
            expect(event.args.approvedBy).to.equal(account2.address, 'approved by is correct');

            const vestingData = await sriVesting.vestingRequest(1);

            expect(vestingData.beneficiary).to.equal(
                account1.address
            );
            expect(vestingData.amount).to.equal(
                "100"
            );

        });

        it("should approve request and start vesting ", async function () {
            const tx0 = await sriVesting.connect(account1).addVestingRequest(account1.address, parseInt((new Date().getTime() / 1000).toString()) + 10, 100);

            const tx = await sriVesting.connect(account2).approveVestingRequest(1);
            const tx1 = await sriVesting.connect(account3).approveVestingRequest(1);

            const tx2 = await sriVesting.connect(account4).approveVestingRequest(1);


            const receipt = await tx2.wait();

            // const tx1 = await sriVesting.approveVestingRequest(1);


            // Assert that the event was emitted


            const vestingData = await sriVesting.vestingRequest(1);

            expect(vestingData.beneficiary).to.equal(
                account1.address
            );
            expect(vestingData.isApproved).to.equal(
                true
            );
            expect(vestingData.amount).to.equal(
                "100"
            );

            const vestingTx = await sriVesting.connect(account1).startVesting(1);

            const recepit = await vestingTx.wait(1);
            const events = recepit.events;

            const event = events[0];
            expect(event.event).to.equal("TokenVestingAdded");
            expect(event.args.vestingId).to.equal(1, 'from is correct');
            expect(event.args.beneficiary).to.equal(account1.address, 'to is correct');
            expect(event.args.amount).to.equal("100", 'Value is correct');

            const vestingInfo = await sriVesting.vestings(1);


            await delay(10);
                    const transfertx = await sriToken.transfer(sriVesting.address, 1000); // transfer token
                    await transfertx.wait();
                    expect(await sriToken.balanceOf(account1.address)).to.equal("0", 'pre-release balance is correct');
                    const releaseTx = await sriVesting.release(1);

                    const releaseReceipt = await releaseTx.wait();

                    const eventrelease = releaseReceipt.events;

                    // Assert that the event was emitted
                    expect(eventrelease.length).to.equal(2);

                    // Assert the event name and parameters
                    const releaseEvent = eventrelease[1];
                    expect(releaseEvent.event).to.equal("TokenVestingReleased");
                    expect(releaseEvent.args.vestingId).to.equal(1, 'from is correct');
                    expect(releaseEvent.args.beneficiary).to.equal(account1.address, 'to is correct');
                    expect(releaseEvent.args.amount).to.equal("100", 'Value is correct');
                    expect(await sriToken.balanceOf(account1.address)).to.equal("100", 'balance is correct');


        });
    });

    describe("Withdrawal token", function () {

        let sriVesting: any;
        let owner: any;
        let account1: any;
        let account2: any;
        let account3: any;
        let account4: any;
        let account5: any;
        let sriToken: any;


        beforeEach(async () =>{
            const { vesting, mockUSDT } = await deployVestingContract();
            sriToken = mockUSDT;
            [owner, account1, account2, account3,account4,account5] = await ethers.getSigners();
            sriVesting = vesting
            const transfertx = await sriToken.transfer(sriVesting.address, 1000); // transfer token
            transfertx.wait();
        });

        it("should add withdraw request", async function () {

            const tx = await sriVesting.addWithdrawRequest(100);

            const receipt = await tx.wait(1);

            expect(receipt.events.length).to.equal(1);
            const event = receipt.events[0];
            expect(event.event).to.equal("WithdrawRequestCreated");
            expect(event.args.withdrawRequestId).to.equal(1, 'from is correct');
            expect(event.args.amount).to.equal("100", 'Value is correct');

        });

        it("should sign and withdraw amount", async function () {

            const tx = await sriVesting.addWithdrawRequest(100);

            const receipt = await tx.wait(1);

            expect(receipt.events.length).to.equal(1);
            let event = receipt.events[0];
            expect(event.event).to.equal("WithdrawRequestCreated");
            expect(event.args.withdrawRequestId).to.equal(1, 'from is correct');
            expect(event.args.amount).to.equal("100", 'Value is correct');

            const tx1= await sriVesting.connect(account1).approveWithdrawRequest(1);
            const receipt1 = await tx1.wait(1);
            expect(receipt1.events.length).to.equal(1);
            let sevent = receipt1.events[0];
            expect(sevent.event).to.equal("SignatureApproved");
            expect(sevent.args.requestId).to.equal(1, 'from is correct');
            expect(sevent.args.approver).to.equal(account1.address, 'Value is correct');
            const tx2= await sriVesting.connect(account2).approveWithdrawRequest(1);
            const tx3= await sriVesting.connect(account3).approveWithdrawRequest(1);
            const receipt3 = await tx3.wait(1);

            const requestInfo = await sriVesting.withdrawRequest(1);

            console.log(requestInfo);

            const tx4 = await sriVesting.processApprovedRequest(1);
            const receipt4 = await tx4.wait(1);
            // let revent = receipt4.events[0];
            // expect(revent.event).to.equal("SignatureApproved");
            // expect(revent.args.requestId).to.equal(1, 'from is correct');
            // expect(revent.args.approver).to.equal(account1.address, 'Value is correct');

            const requestInfonew = await sriVesting.withdrawRequest(1);

            console.log(requestInfonew);


        });


    });


});