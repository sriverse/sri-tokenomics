pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DAOTreasuryVesting {
    using SafeERC20 for IERC20;

    IERC20 private sriToken;
    uint256 private tokensToVest = 0;
    uint256 private withdrawRequestId = 0;
    uint256 private vestingRequestId = 0;
    uint256 private ownerChangeRequestId = 0;
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

    struct VestingRequest {
        uint256 amount;
        address beneficiary;
        uint256 releaseTime;
        address requester;
        address[] approvedBy;
        bool isApproved;
        bool vestingStarted;
    }

    struct MultiSigTokenWithdrawRequest {
        uint256 amount;
        uint256 releaseTime;
        address[] signedBy;
        bool isReleased;
    }

    struct MultiSigOwnerChangeRequest {
        address[] signedBy;
        address newOwner;
        address requestedBy;
        bool isRequestAccepted;
    }

    mapping(uint256 => Vesting) public vestings;

    mapping(address => bool) public approvers;

    mapping(uint256 => MultiSigTokenWithdrawRequest) public withdrawRequest;

    mapping(uint256 => VestingRequest) public vestingRequest;

    mapping(uint256 => MultiSigOwnerChangeRequest) public ownerChangeRequest;


    event VestingRequestCreated(uint256 indexed vestingRequestId, address beneficiary, uint256 amount, address indexed requestedBy);
    event VestingRequestApprove(uint256 indexed vestingRequestId, address approvedBy);
    event TokenVestingReleased(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event TokenVestingAdded(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event SignatureApproved(uint256 indexed requestId, address indexed approver);
    event TokenVestingRemoved(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event WithdrawRequestCreated(uint256 indexed withdrawRequestId, uint256 amount);
    event OwnerChangeRequestCreated(uint256 indexed ownerRequestId, address newRequestedOwner, address requestedBy);
    event OwnerChangeRequestSigned(uint256 indexed requestId, address approvedBy);



constructor(IERC20 _token) public {
        require(address(_token) != address(0x0), "SRI token address is not valid");
        sriToken = _token;
        owner = msg.sender;

        approvers[0x1357d31951e0822a3305503C03752333D15747ae] = true;
        approvers[0x6149083bf6540ad439bFD28A2669B34EFCE2EBEA] = true;
        approvers[0xFd4B4248c2A0B70F8496421824Cc12707448Aad7] = true;
        approvers[0xe8d736096e62B40Ad5bDAc0029CA4daB87F0a976] = true;
        approvers[0x14476c04F0D38cC08C2F0e8728d82ffcC5644780] = true;

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Only owner can perform this action");
        _;
    }

    modifier onlyApprover() {
        require(approvers[msg.sender] == true, "Unauthorized: Only approver can perform this action");
        _;
    }

    modifier onlyApproverOrOwner() {
        require((approvers[msg.sender] == true || msg.sender == owner), "Unauthorized: Only approver can perform this action");
        _;
    }

    function transferOwnershipRequest(address newOwnerAddress) external onlyApprover {
        require(newOwnerAddress != address(0), "Invalid new owner address");
        owner = newOwnerAddress;
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
        tokensToVest = tokensToVest - vesting.amount;
        emit TokenVestingRemoved(_vestingId, vesting.beneficiary, vesting.amount);
    }

    function addVestingRequest(address _beneficiary, uint256 _releaseTime, uint256 _amount) public onlyApprover {
        require(_beneficiary != address(0x0), INVALID_BENEFICIARY);
        vestingRequestId = vestingRequestId + 1;
        vestingRequest[vestingRequestId] = VestingRequest({
        beneficiary : _beneficiary,
        releaseTime : _releaseTime,
        amount : _amount,
        requester : msg.sender,
        isApproved : false,
        vestingStarted : false,
        approvedBy : new address[](3)
        });
        emit VestingRequestCreated(vestingRequestId, _beneficiary, _amount, msg.sender);
    }

    function approveVestingRequest(uint256 requestId) public onlyApprover {

        VestingRequest storage vestingRequestInfo = vestingRequest[requestId];
        require(vestingRequestInfo.isApproved == false);
        require(vestingRequestInfo.requester != msg.sender);

        bool isAlreadySigned = false;
        bool hasUnsigned = false;
        uint256 signIndex = 0;

        for (uint8 i = 0; i < 3; i++) {
            if (vestingRequestInfo.approvedBy[i] == msg.sender) {
                isAlreadySigned = true;
                break;
            }
            if (vestingRequestInfo.approvedBy[i] == address(0)) {
                hasUnsigned = true;
                signIndex = i;
                break;
            }
        }

        require(isAlreadySigned == false, "Already signed");
        require(hasUnsigned == true);

        vestingRequestInfo.approvedBy[signIndex] = msg.sender;
        if (signIndex == 2) {
            vestingRequestInfo.isApproved = true;
        }
        emit VestingRequestApprove(requestId, msg.sender);
    }

    function startVesting(uint256 requestId) public onlyApprover {
        VestingRequest storage vestingRequestInfo = vestingRequest[requestId];
        require(vestingRequestInfo.isApproved == true);
        require(vestingRequestInfo.vestingStarted == false);
        tokensToVest = tokensToVest + vestingRequestInfo.amount;
        vestingId = vestingId + 1;
        vestings[vestingId] = Vesting({
        beneficiary : vestingRequestInfo.beneficiary,
        releaseTime : vestingRequestInfo.releaseTime,
        amount : vestingRequestInfo.amount,
        released : false
        });
        vestingRequestInfo.vestingStarted = true;
        emit TokenVestingAdded(vestingId, vestingRequestInfo.beneficiary, vestingRequestInfo.amount);
    }

    function release(uint256 _vestingId) public {
        Vesting storage vesting = vestings[_vestingId];
        require(vesting.beneficiary != address(0x0), INVALID_VESTING_ID);
        require(!vesting.released, VESTING_ALREADY_RELEASED);
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= vesting.releaseTime, NOT_VESTED);

        require(sriToken.balanceOf(address(this)) >= vesting.amount, INSUFFICIENT_BALANCE);
        vesting.released = true;
        tokensToVest = tokensToVest - vesting.amount;
        sriToken.safeTransfer(vesting.beneficiary, vesting.amount);
        emit TokenVestingReleased(_vestingId, vesting.beneficiary, vesting.amount);
    }

    function addWithdrawRequest(uint256 _amount) public onlyApproverOrOwner {

        withdrawRequestId = withdrawRequestId + 1;
        withdrawRequest[withdrawRequestId] = MultiSigTokenWithdrawRequest({
        amount : _amount,
        releaseTime : 0,
        signedBy : new address[](3),
        isReleased : false
        });
        emit WithdrawRequestCreated(withdrawRequestId, _amount);
    }

    function approveWithdrawRequest(uint256 requestId) public onlyApprover {

        MultiSigTokenWithdrawRequest storage multiSigTokenWithdrawRequest = withdrawRequest[requestId];
        require(multiSigTokenWithdrawRequest.isReleased == false);

        bool isAlreadySigned = false;
        bool hasUnsigned = false;
        uint256 signIndex = 0;
        for (uint8 i = 0; i < 3; i++) {
            if (multiSigTokenWithdrawRequest.signedBy[i] == msg.sender) {
                isAlreadySigned = true;
                break;
            }
            if (multiSigTokenWithdrawRequest.signedBy[i] == address(0)) {
                hasUnsigned = true;
                signIndex = i;
                break;
            }

        }
        require(isAlreadySigned == false);
        require(hasUnsigned == true);
        multiSigTokenWithdrawRequest.signedBy[signIndex] = msg.sender;
        if (signIndex == 2) {
            multiSigTokenWithdrawRequest.releaseTime = block.timestamp + 1;//48 * 60 * 60;
        }
        emit SignatureApproved(requestId, msg.sender);
    }

    function processApprovedRequest(uint256 requestId) public onlyOwner {
        MultiSigTokenWithdrawRequest storage multiSigTokenWithdrawRequest = withdrawRequest[requestId];
        require(multiSigTokenWithdrawRequest.isReleased == false);
        require(multiSigTokenWithdrawRequest.releaseTime < block.timestamp);
        multiSigTokenWithdrawRequest.isReleased = true;
        sriToken.safeTransfer(owner, multiSigTokenWithdrawRequest.amount);
    }

    function createOwnerChangeRequest(address _newOwner) public onlyApprover {
        ownerChangeRequestId = ownerChangeRequestId + 1;
        ownerChangeRequest[ownerChangeRequestId] = MultiSigOwnerChangeRequest({
        newOwner : _newOwner,
        signedBy : new address[](3),
        requestedBy : msg.sender,
        isRequestAccepted : false
        });
        emit OwnerChangeRequestCreated(ownerChangeRequestId, _newOwner, msg.sender);
    }

    function approveOwnerChangeRequest(uint256 requestId) public onlyApprover {

        MultiSigOwnerChangeRequest storage multiSigOwnerChangeRequest = ownerChangeRequest[requestId];
        require(multiSigOwnerChangeRequest.isRequestAccepted == false);
        require(multiSigOwnerChangeRequest.requestedBy != address(0));


        bool isAlreadySigned = false;
        bool hasUnsigned = false;
        uint256 signIndex = 0;
        for (uint8 i = 0; i < 3; i++) {
            if (multiSigOwnerChangeRequest.signedBy[i] == msg.sender) {
                isAlreadySigned = true;
                break;
            }
            if (multiSigOwnerChangeRequest.signedBy[i] == address(0)) {
                hasUnsigned = true;
                signIndex = i;
                break;
            }

        }
        require(isAlreadySigned == false);
        require(hasUnsigned == true);
        multiSigOwnerChangeRequest.signedBy[signIndex] = msg.sender;
        if (signIndex == 2) {
            owner = multiSigOwnerChangeRequest.newOwner;
        }
        emit OwnerChangeRequestSigned(requestId, msg.sender);
    }
}