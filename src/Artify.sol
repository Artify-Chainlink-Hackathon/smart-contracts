// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//This is the contract for minting , listing and buying assets on the marketplace.
import "@openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract Artify is ERC721URIStorage, Ownable {    
   
   //STATE VARIABLES
    uint256 private _nextTokenId;
    address owner;
    string private decription;
    string private baseUri;
    address payable private feeAddress;
    uint8 public feeRate;
    uint8 public royaltyRate;    
    uint256 collectionCount;

    //STRUCTS
    struct Asset {
        address  _creator;
        address  _tokenOwner;
        string description;
        uint256 price;
        uint256 listedDate;
        bool listed;
        uint256 tokenId;
        uint soldTime;
    }

    struct Collection {
        uint256 collectionId;
        string name;
        string description;
        uint256[] tokenIds; // List of token IDs belonging to this collection
        bool exists;
        bool listed;
    
    }    

    
    //Array of all NFTs
    Asset[] public listedAssets;
    // Array of all NFT collections
    Collection[] public listedCollections;

    // Event declarations
    event Minted(address indexed creator, uint256 indexed tokenId);
    event Listed(address indexed owner, uint256 indexed tokenId, uint256 amount);
    event CancelledListing(uint256 indexed tokenId, address indexed owner);
    event FeeRateUpdated(uint256 indexed oldFeeRate, uint256 indexed newFeeRate);
    event AssetBought(uint256 indexed tokenId, address indexed prevOwner, address indexed newOwner, uint256 amount);
    event CollectionCreated(uint256 indexed collectionId, string name, string description);


    constructor(
        address payable _feeAddress, 
        uint8 _feeRate,
        uint8 _royaltyRate
          
    )ERC721("Artify", "ATY")  {
     
        feeRate = _feeRate;
        royaltyRate = _royaltyRate;
        feeAddress = _feeAddress;  
        owner == msg.sender;      
    }

    //Mappings
    mapping(address => uint256) private minterTokenId;
    mapping(address owner => uint256[] tokenId) public userAssetsList;
    mapping(address => mapping(uint256 => Asset)) public userAssets;  
    mapping(uint256 => Collection) public collectionsById;  

    //MINT NFTS
    function mint(string calldata description) external {
        uint256 tokenId = _nextTokenId++;    

        minterTokenId[msg.sender]++;
        Asset storage asset = userAssets[msg.sender][tokenId];
        require(asset._tokenOwner == address(0), "Something gone wrong");
        _safeMint(msg.sender, tokenId);
        asset._creator = msg.sender;
        asset._tokenOwner = msg.sender;
        asset.price = 0;
        asset.tokenId = tokenId;
        asset.description = description;

        emit Minted(msg.sender, tokenId);
    }

    //LIST NFTS FOR SALE
    function listTokenForSale(uint256 _amount, address payable _owner, uint256 _tokenId) external {
        Asset storage asset = userAssets[_owner][_tokenId];
        require(!asset.listed, "Asset already listed");
        require(asset._creator != address(0), "Does not own this asset");
        require(asset._tokenOwner == _owner, "Does not own this asset to this address");
        asset.listedDate = block.timestamp;
        asset.listed = true;
        asset.price = _amount * (1 ether);
        userAssetsList[_owner].push(_tokenId);
        listedAssets.push(asset);
        _approve(address(this), _tokenId, _owner);

        emit Listed(_owner, _tokenId, _amount);
    }

    //CANCEL LISTING
    function cancelListing(uint256 _tokenId, address _owner) public {
        Asset storage asset = userAssets[_owner][_tokenId];
        require(asset.listed, "Asset Not listed");
        (bool isProofed, uint256 _index) = verify(_owner, _tokenId);
        require(isProofed, "Not owner by this user");

        asset.listed = false;
        _approve(address(0), _tokenId, _owner);
        Asset memory lastAsset = listedAssets[listedAssets.length - 1];
        listedAssets[_index] = lastAsset;
        listedAssets.pop();

        emit CancelledListing(_tokenId, _owner);
    }

    //AUTH CHECK
    function verify(address _owner, uint256 id) private view returns (bool status, uint256 index) {
        uint256 totalListed = listedAssets.length;
        for (uint256 i = 0; i < totalListed; i++) {
            Asset memory asset = listedAssets[i];
            if (asset._tokenOwner == _owner && asset.tokenId == id) return (status = true, index = i);
        }
        return (status = false, index);
    }

    //ADJUST RATE
    function setFeeRate(uint8 _feeRate) external {
        require(owner == msg.sender);
        feeRate = _feeRate;

        emit FeeRateUpdated(feeRate, _feeRate);
    }

    //BUY ASSET
    function buyAsset(address payable _newOwner, uint256 index) external payable {
        uint256 _amount = getPriceOfAssetByIndex(index);
        require(_amount <= msg.sender.balance, "Not enough balance to make purchase");  

        
        Asset storage asset = listedAssets[index];        
        require(asset.listed, "Asset Not listed");
        require(asset.price <= _amount, "Insufficient funds");    
        uint platformFee_ = (_amount * feeRate) / 100;       
        uint royaltyFee = (_amount * royaltyRate) / 100;
        uint salesRemains = _amount - platformFee_  - royaltyFee;
        address previousOwner = asset._tokenOwner;
       
        //Make Transfers
        previousOwner.call{value : salesRemains};
        asset._creator.call{value: royaltyFee};
        address(this).call{value: platformFee_};    

        // Update struct
        asset._tokenOwner = _newOwner;   
        asset._tokenOwner = _newOwner;
        asset.listed = false;
        asset.listedDate = 0;
        asset.soldTime = ++asset.soldTime;

        emit AssetBought(listedAssets[index].tokenId, asset._tokenOwner, _newOwner, _amount);
    }

    //RETURN PRICE FROM INDEX
    function getPriceOfAssetByIndex(uint256 index) public view returns (uint256) {
        require(index < listedAssets.length, "Asset index out of bounds");
        return listedAssets[index].price;
    }

    //COLLECTIONS
    function createCollection( string memory _name, string memory _description, uint256[] memory _tokenIds) public {
        uint256 collectionId = collectionCount++;        
        Collection storage collection = collectionsById[collectionId]; 
        collection.collectionId = collectionId;       
        collection.name= _name;
        collection.description = _description;
        collection.tokenIds = _tokenIds;// List of token IDs belonging to this collection
        collection.exists = true;

        listedCollections.push(collection);        
        emit CollectionCreated(collection.collectionId, _name, _description);
    }

    //MINT AS PART OF A COLLECTION
    function mintAsPartOfCollection(string calldata description, uint256 _collectionId) external {
        // Ensure the collection exists
        require(collectionsById[_collectionId].exists, "Collection does not exist");

        uint256 tokenId = _nextTokenId++;
        minterTokenId[msg.sender]++;
        Asset storage asset = userAssets[msg.sender][tokenId];
        require(asset._tokenOwner == address(0), "Something gone wrong");
        _safeMint(msg.sender, tokenId);
        asset._creator = msg.sender;
        asset._tokenOwner = msg.sender;
        asset.price = 0;
        asset.tokenId = tokenId;
        asset.description = description;

        // Add the token ID to the collection
        collectionsById[_collectionId].tokenIds.push(tokenId);
    }

    //lIST AS PART OF A COLLECTION
    function listTokenForSale(uint256 _amount, address payable _owner, uint256 _tokenId, uint256 _collectionId) external {
        Asset storage asset = userAssets[_owner][_tokenId];
        require(!asset.listed, "Asset already listed");
        require(asset._creator!= address(0), "Does not own this asset");
        require(asset._tokenOwner == _owner, "Does not own this asset to this address");
        asset.listedDate = block.timestamp;
        asset.listed = true;
        asset.price = _amount * (1 ether);
        userAssetsList[_owner].push(_tokenId);
        listedAssets.push(asset);
        _approve(address(this), _tokenId, _owner);

        // If the asset is part of a collection, update the collection's listing
        if (_collectionId > 0) {
            require(collectionsById[_collectionId].exists, "Collection does not exist");
            collectionsById[_collectionId].listed = true;
        }
    }

}
