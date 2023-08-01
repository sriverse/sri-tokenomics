pragma solidity 0.8.18;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract SriTokenVesting {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private sriToken;
    uint256 private tokensToVest = 0;
    uint256 private withdrawRequestId = 0;
    uint256 private vestingId = 0;
    address public owner; // Add owner variable


    string private constant INSUFFICIENT_BALANCE = "Insufficient balance";
    string private constant INVALID_VESTING_ID = "Invalid vesting id";
    string private constant VESTING_ALREADY_RELEASED = "Vesting already released";
    string private constant INVALID_BENEFICIARY = "Invalid beneficiary address";
    string private constant NOT_VESTED = "Tokens have not vested yet";

    struct Vesting {
        uint256 releaseTime;
        uint256 amount;
        address beneficiary;
        bool released;
    }

    struct MultiSigTokenWithdrawRequest {
        uint256 amount;
        uint256 releaseTime;
        address[] signedBy;
        bool isReleased;
    }

    mapping(uint256 => Vesting) public vestings;

    mapping(address => bool) public approvers;

    mapping(uint256 => MultiSigTokenWithdrawRequest) public withdrawRequest;

    event TokenVestingReleased(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event TokenVestingAdded(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event SignatureApproved(uint256 indexed requestId, address indexed approver);
    event TokenVestingRemoved(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token) public {
        require(address(_token) != address(0x0), "SRI token address is not valid");
        sriToken = _token;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Only owner can perform this action");
        _;
    }

    modifier onlyApprover() {
        require(approvers[msg.sender] == true, "Unauthorized: Only owner can perform this action");
        _;
    }

    function transferOwnership(address newOwnerAddress) external onlyOwner {
        require(newOwnerAddress != address(0), "Invalid new owner address");
        owner = newOwnerAddress;
    }

    function token() public view returns (IERC20) {
        return sriToken;
    }

    function beneficiary(uint256 _vestingId) public view returns (address) {
        return vestings[_vestingId].beneficiary;
    }

    function releaseTime(uint256 _vestingId) public view returns (uint256) {
        return vestings[_vestingId].releaseTime;
    }

    function vestingAmount(uint256 _vestingId) public view returns (uint256) {
        return vestings[_vestingId].amount;
    }

    function removeVesting(uint256 _vestingId) public onlyOwner {
        Vesting storage vesting = vestings[_vestingId];
        require(vesting.beneficiary != address(0x0), INVALID_VESTING_ID);
        require(!vesting.released, VESTING_ALREADY_RELEASED);
        vesting.released = true;
        tokensToVest = tokensToVest.sub(vesting.amount);
        emit TokenVestingRemoved(_vestingId, vesting.beneficiary, vesting.amount);
    }

    function addVesting(address _beneficiary, uint256 _releaseTime, uint256 _amount) public onlyOwner {
        require(_beneficiary != address(0x0), INVALID_BENEFICIARY);
        tokensToVest = tokensToVest.add(_amount);
        vestingId = vestingId.add(1);
        vestings[vestingId] = Vesting({
        beneficiary : _beneficiary,
        releaseTime : _releaseTime,
        amount : _amount,
        released : false
        });
        emit TokenVestingAdded(vestingId, _beneficiary, _amount);
    }

    function release(uint256 _vestingId) public {
        Vesting storage vesting = vestings[_vestingId];
        require(vesting.beneficiary != address(0x0), INVALID_VESTING_ID);
        require(!vesting.released, VESTING_ALREADY_RELEASED);
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= vesting.releaseTime, NOT_VESTED);

        require(sriToken.balanceOf(address(this)) >= vesting.amount, INSUFFICIENT_BALANCE);
        vesting.released = true;
        tokensToVest = tokensToVest.sub(vesting.amount);
        sriToken.safeTransfer(vesting.beneficiary, vesting.amount);
        emit TokenVestingReleased(_vestingId, vesting.beneficiary, vesting.amount);
    }

    function addWithdrawRequest(uint256 _amount) public onlyOwner {

        withdrawRequestId = withdrawRequestId.add(1);
        withdrawRequest[withdrawRequestId] = MultiSigTokenWithdrawRequest({
        amount : _amount,
        releaseTime : 0,
        signedBy :  new address[](3),
        isReleased: false
        });
    }

    function approveWithdrawRequest(uint256 requestId) public onlyApprover {

        MultiSigTokenWithdrawRequest storage multiSigTokenWithdrawRequest = withdrawRequest[requestId];
        require(multiSigTokenWithdrawRequest.isReleased == false);
        require(multiSigTokenWithdrawRequest.signedBy.length < 3);

        bool isAlreadySigned = false;
        for (uint8 i = 0; i < 3; i++) {
            if (multiSigTokenWithdrawRequest.signedBy[i] == msg.sender) {
                isAlreadySigned = true;
                break;
            }
        }

        require(isAlreadySigned == false);
        uint256 signIndex = multiSigTokenWithdrawRequest.signedBy.length;
        multiSigTokenWithdrawRequest.signedBy[multiSigTokenWithdrawRequest.signedBy.length] = msg.sender;
        if (signIndex == 2) {
            multiSigTokenWithdrawRequest.releaseTime = block.timestamp + 48 * 60 * 60;
        }

        emit SignatureApproved(requestId, msg.sender);
    }

    function processApprovedRequest(uint256 requestId) public onlyOwner {
        MultiSigTokenWithdrawRequest storage multiSigTokenWithdrawRequest = withdrawRequest[requestId];
        require(multiSigTokenWithdrawRequest.releaseTime != 0);
        sriToken.safeTransfer(owner, multiSigTokenWithdrawRequest.amount);
        multiSigTokenWithdrawRequest.isReleased = true;


    }
}