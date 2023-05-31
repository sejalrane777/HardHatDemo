// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";



/**
 * @title DEX: P2P swaping 
 *
 * This contract provides a way to:
 *  - Deposit tokens (Done)
 *  - Claim Deposit / Order  (Done)
 *  - Update/Delete Order   (Update Done)
 *  - Partial Order Fulfillment
 *  - Refund acive deposit
 */

 abstract contract ReentrancyGuard {
    bool internal locked;

    modifier noReentrant () {
        require (!locked, "No Re-entrancy");
        locked = true;
        _;
        locked = false;
    }
 } 


contract Dex is ReentrancyGuard{
    using SafeERC20 for IERC20;

    event DepositCreated (
        uint indexed _depositId, 
        uint _sellerAmount, 
        IERC20 indexed _sellerTokenAddress, 
        uint _buyerAmount, 
        IERC20 indexed _buyerTokenAddress 
    );

    event DepositUpdated (
        uint indexed _depositId, 
        uint _sellerAmount, 
        IERC20 indexed _sellerTokenAddress, 
        uint _buyerAmount, 
        IERC20 indexed _buyerTokenAddress
    );

    event ClaimOrder (
        uint indexed _depositId, 
        address _seller, 
        IERC20 indexed _sellerTokenAddress, 
        address _buyer, 
        IERC20 indexed _buyerTokenAddress 
    );

    event BuyPartialOrder (
        uint indexed _depositId,
        uint indexed _rate
    );

    event RefundActiveDeposit (
        uint indexed _depositId, 
        uint _sellerAmount, 
        IERC20 indexed _sellerTokenAddress, 
        uint _buyerAmount, 
        IERC20 indexed _buyerTokenAddress 
    );

    struct Deposit {
        bool isActive;
        address depositAddress;
        uint sellerAmount;
        IERC20 sellerContractAddress;
        uint buyerAmount;
        IERC20 buyerContractAddress;
        uint expiryTime;
    }

    Deposit [] public deposits;

    //Create Order
    /**
    * - @param
    * - Seller Amount
    * - Seller Contract Address
    * - buyer Amount
    * - buyer contract address
    * - validity time
    */

    function createOrder (
        uint _sellerAmount, //10 T1 Token
        IERC20 _sellerTokenAddress, //Contract address of T1
        uint _buyerAmount, //5 T2 Token
        IERC20 _buyerTokenAddress, //Contract address of T2
        uint _validityTime
    ) external noReentrant returns (uint) {
        require(_sellerAmount > 0, "SELL_MINIMUM_ONE_TOKEN");

        uint validityTime = block.timestamp + (_validityTime * 1 seconds);

        //Transfer seller amount => Contract address
        _safeTransferFrom(_sellerTokenAddress, msg.sender, address(this), _sellerAmount);

        Deposit memory depositObj = Deposit (
            true,
            msg.sender,
            _sellerAmount,
            _sellerTokenAddress,
            _buyerAmount,
            _buyerTokenAddress,
            validityTime
        );

        deposits.push(depositObj);

        uint depositId = deposits.length - 1;

        emit DepositCreated (
            depositId, 
            _sellerAmount, 
            _sellerTokenAddress, 
            _buyerAmount, 
            _buyerTokenAddress
        );

        return depositId;

    }

    function updateOrder (
        uint _sellerAmount, //15 T1 Token
        uint _buyerAmount, //7 T2 Token
        uint _validityTime,
        uint _orderId
    ) external {
        require(_sellerAmount > 0, "SELL_MINIMUM_ONE_TOKEN");

        //Transfer seller amount => Contract address
        _safeTransferFrom(deposits[_orderId].sellerContractAddress, msg.sender, address(this), _sellerAmount);

        deposits[_orderId].sellerAmount = _sellerAmount;
        deposits[_orderId].buyerAmount = _buyerAmount;
        deposits[_orderId].expiryTime = deposits[_orderId].expiryTime + ( _validityTime * 1 seconds );

        emit DepositUpdated (
            _orderId, 
            _sellerAmount, 
            deposits[_orderId].sellerContractAddress, 
            _buyerAmount, 
            deposits[_orderId].buyerContractAddress
        );

    }

    //Claim Order
    function claimOrder (uint _depositId) external noReentrant returns (uint) {
        Deposit storage depositObj = deposits[_depositId];
        // Deposit memory depositObj = deposits[_depositId];

        require(depositObj.expiryTime > block.timestamp, "ERR_EXPIRED_ORDER");

        address buyer = msg.sender;

        //Contract to buyer | T1 Token
        // IERC20(depositObj.sellerContractAddress).transfer(msg.sender, depositObj.sellerAmount);  //Either this or that
        _safeTransfer(depositObj.sellerContractAddress, msg.sender, depositObj.sellerAmount);
        depositObj.sellerAmount = 0;

        //Buyer to Seller | T2 Token
        _safeTransferFrom(depositObj.buyerContractAddress, buyer, depositObj.depositAddress, depositObj.buyerAmount);
        depositObj.buyerAmount = 0;

        depositObj.isActive = false;

        emit ClaimOrder(
            _depositId,
            depositObj.depositAddress,
            depositObj.sellerContractAddress,
            buyer,
            depositObj.buyerContractAddress
        );

        return _depositId;
    }

    function buyPartialOrder(
        uint _depositId, 
        uint _buyerAmount) 
        external noReentrant returns(uint){

            //Order buy 100 T1 token exchange of 200 T2 Token
            //                  ||
            //Order buy 20 T1 token exchange of 100 T2 Token
            //rate = T2/T1
            //rate * T1

        Deposit storage depositObj = deposits[_depositId];
        // Deposit memory depositObj = deposits[_depositId];

        require(depositObj.expiryTime > block.timestamp, "ERR_EXPIRED_ORDER");

        address buyer = msg.sender;

        uint rate = (depositObj.sellerAmount * 10**10) / depositObj.buyerAmount;
        uint updatedSellerAmount = (_buyerAmount * rate) / 10**10;

        depositObj.sellerAmount -= updatedSellerAmount;

        //10**10 == 1e10
        //3/2 = 1
        //4/3 = 1
        //2/3 = 0

        //Solidity works with whole numbers only

        //Contract to buyer | T1 Token
        _safeTransfer(
            depositObj.sellerContractAddress,
            msg.sender,
            updatedSellerAmount
        );


        //Buyer to Seller | T2 Token
        depositObj.buyerAmount -= _buyerAmount;
        _safeTransferFrom(
            depositObj.buyerContractAddress, 
            buyer, 
            depositObj.depositAddress,
            _buyerAmount
        );

        if(depositObj.sellerAmount == 0){
            depositObj.isActive = false;
        }

        emit BuyPartialOrder(_depositId, rate);
        return _depositId;

    }

     function refundActiveDeposit(uint _depositId) external {
        Deposit memory depositObj = deposits[_depositId];

        require(depositObj.expiryTime > block.timestamp, "ERR_EXPIRED_ORDER");
        require(depositObj.isActive, "INACTIVE_ORDER");
        require(depositObj.depositAddress == msg.sender, "UNAUTHORISED_ACCESSABILITY");

        _safeTransfer(
            depositObj.sellerContractAddress,
            msg.sender,
            depositObj.sellerAmount
        );

        emit RefundActiveDeposit(
            _depositId,
            depositObj.sellerAmount,
            depositObj.sellerContractAddress,
            depositObj.buyerAmount,
            depositObj.buyerContractAddress
        );

        delete deposits[_depositId];

    }


    //Token contract address, from contract address, to contract address, amount
    function _safeTransferFrom (
        IERC20 _token,  //token address
        address _from,
        address _to,
        uint _amount
    ) private {
        bool isSent = _token.transferFrom(_from, _to, _amount);
        require (isSent, "TRANSFER FROM | Token transferForm Failed");
    }


    //Token contract address, to contract address, amount
    function _safeTransfer (
        IERC20 _token,
        address _to,
        uint _amount
    ) private {
        bool isSent = _token.transfer(_to, _amount);
        require (isSent, "TRANSFER | Token transfer Failed");
    }


}
