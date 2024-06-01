// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FunctionsClient} from "chainlink/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "chainlink/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "chainlink/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/resources/link-token-contracts/
 */

/**
 * @title GettingStartedFunctionsConsumer
 * @notice This is an example contract to show how to make HTTP requests using Chainlink
 * @dev This contract uses hardcoded values and should not be used in production.
 */
contract AvaxFunctionsConsumer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    // Struct to store multiple image URLs
    struct ImageUrls {
        string url1;
        string url2;
        string url3;
    }

    // Mappings to store images for users
    mapping(address => string) private promptImage;
    mapping(address => ImageUrls) private userImageUrls;

    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Events to log responses and URL updates
    event Response(
        bytes32 indexed requestId,
        bool success,
        bytes response,
        bytes err
    );

    event PromptImageUpdated(address indexed user, string url);
    event ImageUrlsUpdated(address indexed user, string url1, string url2, string url3);

    // Router address - Hardcoded for AVAX FUJI TESTNET
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;

    // Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for AVAX FUJI TESTNET
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    // State variable to store the success status
    bool public successStatus;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    /**
     * @notice Sends an HTTP request to check image generation success from a prompt
     * @param subscriptionId The ID for the Chainlink subscription
     * @param prompt The prompt to generate the image
     * @param apiKey The API key for the Artify API
     * @return success The boolean success status of the request
     */
    function sendPromptRequest(
        uint64 subscriptionId,
        string calldata prompt,
        string calldata apiKey
    ) external onlyOwner returns (bool success) {
        string[] memory args = new string[](2);
        args[0] = prompt;
        args[1] = apiKey;

        // JavaScript source code
        string memory source =
            "const prompt = args[0];"
            "const apiKey = args[1];"
            "if (!apiKey) {"
            "  throw Error('Missing secret: apiKey, for this example try using your OpenAI API key');"
            "}"
            "const url = 'https://artify-m2y9.onrender.com/prompt-to-image';"
            "console.log(`HTTP POST Request to ${url} with prompt ${prompt}\\n`);"
            "const imageRequest = Functions.makeHttpRequest({"
            "  url: url,"
            "  method: 'POST',"
            "  headers: {"
            "    'Content-Type': 'application/json',"
            "    Authorization: `Bearer ${apiKey}`,"
            "  },"
            "  data: {"
            "    prompt: prompt,"
            "  },"
            "  timeout: 9000,"
            "});"
            "const imageResponse = await imageRequest;"
            "console.log('imageResponse', imageResponse);"
            "if (imageResponse.error) {"
            "  console.error(imageResponse.error);"
            "  throw Error('Request failed');"
            "}"
            "const data = imageResponse.data;"
            "console.log(JSON.stringify(data, null, 2));"
            "if (data.Response === 'Error') {"
            "  console.error(data.Message);"
            "  throw Error(`Functional error. Read message: ${data.Message}`);"
            "}"
            "const success = data.success;"
            "console.log('Image generation success:', success);"
            "const successAsUint256 = success ? 1 : 0;"
            "return Functions.encodeUint256(successAsUint256);";

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        // Temporary assignment for illustration
        success = true; // Adjust based on actual request handling logic
        return success;
    }

    /**
     * @notice Sends an HTTP request to convert an image to multiple images
     * @param subscriptionId The ID for the Chainlink subscription
     * @param imageUrl The URL of the image to be converted
     * @param apiKey The API key for the Artify API
     * @return success The boolean success status of the request
     */
    function sendImageRequest(
        uint64 subscriptionId,
        string calldata imageUrl,
        string calldata apiKey
    ) external onlyOwner returns (bool success) {
        string[] memory args = new string[](2);
        args[0] = imageUrl;
        args[1] = apiKey;

        // JavaScript source code
        string memory source =
            "const imageUrl = args[0];"
            "const apiKey = args[1];"
            "if (!apiKey) {"
            "  throw Error('Missing secret: apiKey, for this example try using your OpenAI API key');"
            "}"
            "const url = 'https://artify-m2y9.onrender.com/image-to-images';"
            "console.log(`HTTP POST Request to ${url} with image URL ${imageUrl}\\n`);"
            "const imageRequest = Functions.makeHttpRequest({"
            "  url: url,"
            "  method: 'POST',"
            "  headers: {"
            "    'Content-Type': 'application/json',"
            "    Authorization: `Bearer ${apiKey}`,"
            "  },"
            "  data: {"
            "    imageUrl: imageUrl,"
            "  },"
            "  timeout: 9000,"
            "});"
            "const imageResponse = await imageRequest;"
            "console.log('imageResponse', imageResponse);"
            "if (imageResponse.error) {"
            "  console.error(imageResponse.error);"
            "  throw Error('Request failed');"
            "}"
            "const data = imageResponse.data;"
            "console.log(JSON.stringify(data, null, 2));"
            "if (data.Response === 'Error') {"
            "  console.error(data.Message);"
            "  throw Error(`Functional error. Read message: ${data.Message}`);"
            "}"
            "const success = data.success;"
            "console.log('Image conversion success:', success);"
            "const successAsUint256 = success ? 1 : 0;"
            "return Functions.encodeUint256(successAsUint256);";

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        // Temporary assignment for illustration
        success = true; // Adjust based on actual request handling logic
        return success;
    }

    /**
     * @notice Function to update the image URL generated from a prompt
     * @param url The URL of the generated image
     */
    function setPromptImage(string calldata url) external onlyOwner {
        promptImage[msg.sender] = url;
        emit PromptImageUpdated(msg.sender, url);
    }

    /**
     * @notice Function to update the image URLs generated from an image
     * @param url1 The first URL of the generated images
     * @param url2 The second URL of the generated images
     * @param url3 The third URL of the generated images
     */
    function setImageUrls(string calldata url1, string calldata url2, string calldata url3) external onlyOwner {
        userImageUrls[msg.sender] = ImageUrls(url1, url2, url3);
        emit ImageUrlsUpdated(msg.sender, url1, url2, url3);
    }

    /**
     * @notice Function to fetch the stored image URL generated from a prompt
     * @return imageUrl The stored image URL
     */
    function getPromptImage() external view returns (string memory) {
        return promptImage[msg.sender];
    }

    /**
     * @notice Function to fetch the stored image URLs generated from an image
     * @return url1 The first stored image URL
     * @return url2 The second stored image URL
     * @return url3 The third stored image URL
     */
    function getImageUrls() external view returns (string memory url1, string memory url2, string memory url3) {
        ImageUrls memory urls = userImageUrls[msg.sender];
        return (urls.url1, urls.url2, urls.url3);
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        uint256 successAsUint256 = abi.decode(response, (uint256));
        successStatus = successAsUint256 == 1;
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, successStatus, s_lastResponse, s_lastError);
    }
}