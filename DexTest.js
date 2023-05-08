
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("P2P Dex Contract", function(){


    describe("Token Delpoyments", function(){

        it("T1 deployment", async function(){

            const [vishnu] = await ethers.getSigners();

            const T1 = await ethers.getContractFactory("T1", vishnu);

            const t1 = await T1.deploy(1000000);

            const ownerBalance = await t1.balanceOf(vishnu.address);

            const totalSupply = await t1.totalSupply();

            expect(totalSupply).to.equal(ownerBalance);

        })

        it("T2 deployment", async function(){

            const [sejal] = await ethers.getSigners();

            const T2 = await ethers.getContractFactory("T2", sejal);

            const t2 = await T2.deploy(1000000);

            const ownerBalance = await t2.balanceOf(sejal.address);

            const totalSupply = await t2.totalSupply();

            expect(totalSupply).to.equal(ownerBalance);

        })
    })


    describe("Dex | Create Order", function(){

        // before hook

        before(async () => {

            [admin, vishnu, sejal] = await ethers.getSigners();

            const T1 = await ethers.getContractFactory("T1", vishnu);
            const T2 = await ethers.getContractFactory("T2", sejal);
            const Dex = await ethers.getContractFactory("Dex", admin);

            t1 = await T1.deploy(1000000);
            await t1.deployed();
            t2 = await T2.deploy(1000000);
            await t2.deployed();
            Dex = await Dex.deploy();
            await Dex.deployed();

        }) 


        it("Create Order is working successfully", async function(){

            // create order function call

            const approve = await t1.approve(Dex.address, 100000, {from: vishnu.address});

            const allowance = await t1.connect(vishnu).allowance(vishnu.address, Dex.address);

            const createOrderTx = await Dex
                .connect(vishnu)
                .createOrder(100000, t1.address, 50, t2.address, 9999999999);

            await createOrderTx.wait();

            expect(createOrderTx.from).eq(vishnu.address);

        })

    })


    describe("Dex | Claim Order", function(){

        // before hook

        before(async () => {

            [admin, vishnu, sejal] = await ethers.getSigners();

            const T1 = await ethers.getContractFactory("T1", vishnu);
            const T2 = await ethers.getContractFactory("T2", sejal);
            const Dex = await ethers.getContractFactory("Dex", admin);

            t1 = await T1.deploy(1000000);
            await t1.deployed();
            t2 = await T2.deploy(1000000);
            await t2.deployed();
            Dex = await Dex.deploy();
            await Dex.deployed();

            const approve = await t1.approve(Dex.address, 100000, {from: vishnu.address});

            const allowance = await t1.connect(vishnu).allowance(vishnu.address, Dex.address);

            const createOrderTx = await Dex
                .connect(vishnu)
                .createOrder(100000, t1.address, 50, t2.address, 9999999999);

            await createOrderTx.wait();

        }) 

        it("Claim Order is working successfully", async function(){

            // claim order function call | buyer => sejal

            const approve = await t2.connect(sejal).approve(Dex.address, 50);

            const allowance = await t2.connect(sejal).allowance(sejal.address, Dex.address);

            const claimOrderTx = await Dex.connect(sejal).claimOrder(0);
            await claimOrderTx.wait();

            expect(claimOrderTx.from).eq(sejal.address);
        })

    })


    describe("Dex | Partial Order", function(){

        // before hook

        before(async () => {

            [admin, vishnu, sejal] = await ethers.getSigners();

            const T1 = await ethers.getContractFactory("T1", vishnu);
            const T2 = await ethers.getContractFactory("T2", sejal);
            const Dex = await ethers.getContractFactory("Dex", admin);

            t1 = await T1.deploy(1000000);
            await t1.deployed();
            t2 = await T2.deploy(1000000);
            await t2.deployed();
            Dex = await Dex.deploy();
            await Dex.deployed();

            const approve = await t1.approve(Dex.address, 100000, {from: vishnu.address});

            const allowance = await t1.connect(vishnu).allowance(vishnu.address, Dex.address);

            const createOrderTx = await Dex
                .connect(vishnu)
                .createOrder(100000, t1.address, 100, t2.address, 9999999999);

            await createOrderTx.wait();

        }) 

        it("Partial Order fullfillment is working successfully", async function(){

            // claim order function call | buyer => sejal

            const approve = await t2.connect(sejal).approve(Dex.address, 50);

            const allowance = await t2.connect(sejal).allowance(sejal.address, Dex.address);

            const buyOrderPartialTx = await Dex.connect(sejal).buyOrderPartial(0, 50);
            await buyOrderPartialTx.wait();

            expect(buyOrderPartialTx.from).eq(sejal.address);
        })

    })



})
 