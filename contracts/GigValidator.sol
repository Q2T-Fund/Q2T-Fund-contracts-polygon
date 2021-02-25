//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "./IGigsRegistry.sol";

contract GigValidator is ChainlinkClient {
    event requiestFulfilled (bytes32 _requestId, bytes32 _hash, bool _isValid, bool _isConfirmed);

    bytes4 public constant IDENTITY = 0xbf444387;

    string private constant PATH = "isValid";
  
    bool public isValid;
    bool public isFulfilled;
    bool public isRequested;
    bool public isConfirmed;
    bytes32 public communityIdHash;
    bytes32 public gigHash;
    address public gigsRegistry;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    /**
     * Network: Kovan
     * Oracle: 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
     * Job ID: 6d914edc36e14d6c880c9c55bda5bc04 (ethbool)	
     * Fee: 0.1 LINK
     */
    constructor(address _oracle, bytes32 _jobId) public {
        setPublicChainlinkToken();
        oracle = _oracle;
        jobId = _jobId;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    /**
     * Create a Chainlink request to retrieve API response if created gig is valid
     */
     //!!! REMOVE MOCK ONCE REAL API IS AVAILABLE
    function requestIsGigValid(string memory _community, bytes32 _hash, string memory _mockIsValid) public returns (bytes32 requestId) 
    {
        require(IGigsRegistry(msg.sender).IDENTITY() == bytes4(0x95fe5fc1), "not registry");
        require(!isRequested, "already requested");
        gigsRegistry = msg.sender;
        
        isValid = false;
        isFulfilled = false;
        isRequested = true;
        isConfirmed = false;
        communityIdHash = keccak256(abi.encodePacked(_community));
        gigHash = _hash;
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", "https://api.distributed.town/api/gig/1/validateHash");
        request.add("queryParams", string(
            abi.encodePacked(
                "hash=",
                _hash,
                "&communityID=",
                _community,
                "&isMock=true&returnTrue=", 
                _mockIsValid
            )));       

        request.add("path", PATH);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, bool _isValid) public recordChainlinkFulfillment(_requestId)
    {
        if(_isValid && (gigsRegistry != address(0))) {
            isConfirmed = IGigsRegistry(gigsRegistry).confirmGig(gigHash);
        }

        isValid = _isValid;
        isFulfilled = true;
        isRequested = false;
        gigsRegistry = address(0);

        emit requiestFulfilled(_requestId, gigHash, _isValid, isConfirmed);
    }

    function reset() public {
        require(isRequested, "not requested");
        require(msg.sender == gigsRegistry, "not requestor");

        isValid = false;
        isFulfilled = false;
        isRequested = false;
        isConfirmed = false;
        gigsRegistry = address(0);
    }
}