//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

contract GigValidator is ChainlinkClient {
    string private constant PATH = "isValid";
  
    bool public isValid;
    bool public isFulfilled;
    bytes32 public gigHash;
    
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
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestIsGigValid(string memory _community, bytes32 _hash, string memory _mockIsValid) public returns (bytes32 requestId) 
    {
        isValid = false;
        isFulfilled = false;
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
        //isValid = (bytes(_isValid).length == bytes("true").length);
        isValid = _isValid;
        isFulfilled = true;
    }
}