    pragma solidity ^ 0.4.4;
    
    
    import "./CptData.sol";
    import "./WeIdContract.sol";
    import "./RoleController.sol";
    
    contract CptController{
        
    /*
      我们的凭证架构基于Weidentity的系统，对其进行了修改和补充
      在我们的系统架构中，分为政府用户、机构用户、个人用户和特殊的凭证发布者
      要求架构关系为：政府->机构->个人
      即政府给机构进行签名认证
      个人参与项目
      机构根据个人项目参与情况按照规范生成凭据
    */
    
    // 错误编码
    uint constant private CPT_NOT_EXIST = 500301;
    uint constant private GOVERNMENT_CPT_ID_EXCEED_MAX = 500302;
    uint constant private CPT_PUBLISHER_NOT_EXIST = 500303;
    uint constant private CPT_ALREADY_EXIST = 500304;
    uint constant private NO_PERMISSION = 500305;
    
    // 默认CPT版本
    int constant private CPT_DEFAULT_VERSION = 1;
    
    WeIdContract private weIdContract;
    RoleController private roleController;
    
    // Reserved for contract owner check
    address private internalRoleControllerAddress;
    address private owner;
    
    // CPT and Policy data storage address separately
    address private cptDataStorageAddress;
    address private policyDataStorageAddress;
    
    function CptController(
        address cptDataAddress,
        address weIdContractAddress
    )
        public
    {
        owner = msg.sender;
        weIdContract = WeIdContract(weIdContractAddress);
        cptDataStorageAddress = cptDataAddress;
    }
    
    function setPolicyData(
        address policyDataAddress
    )
        public
    {
        if (msg.sender != owner || policyDataAddress == 0x0) {
            return;
        }
        policyDataStorageAddress = policyDataAddress;
    }
    
    function setRoleController(
        address roleControllerAddress
    )
        public
    {
        if (msg.sender != owner || roleControllerAddress == 0x0) {
            return;
        }
        roleController = RoleController(roleControllerAddress);
        if (roleController.ROLE_PERSON() <= 0) {
            return;
        }
        internalRoleControllerAddress = roleControllerAddress;
    }
    
    event RegisterCptRetLog(
        uint retCode,
        uint cptId,
        int cptVersion
    );
    
    event RegisterCptGovernmentSignatureRetLog(
        uint retCode,
        uint cptId,
        int cptVersion
    );
    
    event UpdateCptRetLog(
        uint retCode,
        uint cptId,
        int cptVersion
    );
        
    event UpdateCptGovernmentSignatureRetLog(
        uint retCode,
        uint cptId,
        int cptVersion
    );
    
    
    //记录政府签名
    function registerCptGovernmentSignatureInner(
        uint cptId,
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers,
        address dataStorageAddress
    )
        private
        returns(bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        CptData cptData = CptData(dataStorageAddress);
        if (cptData.isCptExist(cptId)) {
            RegisterCptRetLog(CPT_ALREADY_EXIST, cptId, 0);
            return false;
        }
    
        // Authority related checks. We use tx.origin here to decide the authority. For SDK
        // calls, publisher and tx.origin are normally the same. For DApp calls, tx.origin dictates.
        uint lowId = cptData.GOVERNMENT_START_ID();
        uint highId = cptData.NONE_GOVERNMENT_START_ID();
        if (cptId < lowId) {
            // Only committee member can create this, check initialization first
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_GOVERNMENT())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        }
    else if (cptId < highId) {
            // Only authority issuer can create this, check initialization first
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        }
    
        cptData.putgovernmentsignature(cptId, goverv, goverr, govers);
    
        RegisterCptGovernmentSignatureRetLog(0, cptId, CPT_DEFAULT_VERSION);
        return true;
    }
    
    function registerCptGovernmentSignature(
        uint cptId,
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers
    )
        public
        returns(bool)
    {
        return registerCptGovernmentSignatureInner(cptId, publisher, goverv, goverr, govers, cptDataStorageAddress);
    }
    
    function registerPolicyGovernmentSignature(
        uint cptId,
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers
    )
        public
        returns(bool)
    {
        return registerCptGovernmentSignatureInner(cptId, publisher, goverv, goverr, govers, policyDataStorageAddress);
    }
        
    function registerCptGovernmentSignatureInner(
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers,
        address dataStorageAddress
    )
        private
        returns(bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        CptData cptData = CptData(dataStorageAddress);
    
        uint cptId = cptData.getCptId(publisher);
        if (cptId == 0) {
            RegisterCptRetLog(GOVERNMENT_CPT_ID_EXCEED_MAX, 0, 0);
            return false;
        }
        int cptVersion = CPT_DEFAULT_VERSION;
        cptData.putgovernmentsignature(cptId, goverv, goverr, govers);
    
        RegisterCptGovernmentSignatureRetLog(0, cptId, cptVersion);
        return true;
    }
    
    function registerCptGovernmentSignature(
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers
    )
        public
        returns(bool)
    {
        return registerCptGovernmentSignatureInner(publisher, goverv, goverr, govers, cptDataStorageAddress);
    }
    
    function registerPolicyGovernmentSignature(
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers
    )
        public
        returns(bool)
    {
        return registerCptGovernmentSignatureInner(publisher, goverv, goverr, govers, policyDataStorageAddress);
    }
    
    
    //记录cpt信息（除了政府签名）
    function registerCptInner(
        uint cptId,
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address dataStorageAddress
    )
        private
        returns(bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        CptData cptData = CptData(dataStorageAddress);
        if (cptData.isCptExist(cptId)) {
            RegisterCptRetLog(CPT_ALREADY_EXIST, cptId, 0);
            return false;
        }
    
        // Authority related checks. We use tx.origin here to decide the authority. For SDK
        // calls, publisher and tx.origin are normally the same. For DApp calls, tx.origin dictates.
        uint lowId = cptData.GOVERNMENT_START_ID();
        uint highId = cptData.NONE_GOVERNMENT_START_ID();
        if (cptId < lowId) {
            // Only committee member can create this, check initialization first
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_ORGANIZATION())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        }
    else if (cptId < highId) {
            // Only authority issuer can create this, check initialization first
            if (internalRoleControllerAddress == 0x0) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
            if (!roleController.checkPermission(tx.origin, roleController.MODIFY_KEY_CPT())) {
                RegisterCptRetLog(NO_PERMISSION, cptId, 0);
                return false;
            }
        }
    
        intArray[0] = CPT_DEFAULT_VERSION;
        cptData.putCptnoGovernmentSignature(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);
    
        RegisterCptRetLog(0, cptId, CPT_DEFAULT_VERSION);
        return true;
    }
    
    
    function registerCpt(
        uint cptId,
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        returns(bool)
    {
        return registerCptInner(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s, cptDataStorageAddress);
    }
    
    
    function registerPolicy(
        uint cptId,
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        returns(bool)
    {
        return registerCptInner(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s, policyDataStorageAddress);
    }
    
    
    function registerCptInner(
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address dataStorageAddress
    )
        private
        returns(bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            RegisterCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        CptData cptData = CptData(dataStorageAddress);
    
        uint cptId = cptData.getCptId(publisher);
        if (cptId == 0) {
            RegisterCptRetLog(GOVERNMENT_CPT_ID_EXCEED_MAX, 0, 0);
            return false;
        }
        int cptVersion = CPT_DEFAULT_VERSION;
        intArray[0] = cptVersion;
        cptData.putCptnoGovernmentSignature(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);
    
        RegisterCptRetLog(0, cptId, cptVersion);
        return true;
    }
    
    
    function registerCpt(
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        returns(bool)
    {
        return registerCptInner(publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s, cptDataStorageAddress);
    }
    
    
    function registerPolicy(
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        returns(bool)
    {
        return registerCptInner(publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s, policyDataStorageAddress);
    }
    
    //更新政府签名的信息
    function updateCptGovernmentSignatureInner(
        uint cptId,
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers,
        address dataStorageAddress
    )
        private
        returns(bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            UpdateCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        CptData cptData = CptData(dataStorageAddress);
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_GOVERNMENT())
            && publisher != cptData.getCptPublisher(cptId)) {
            UpdateCptRetLog(NO_PERMISSION, 0, 0);
            return false;
        }
        if (cptData.isCptExist(cptId)) {
            int[8] memory cptIntArray = cptData.getCptIntArray(cptId);
            int cptVersion = cptIntArray[0] + 1;
            cptData.putgovernmentsignature(cptId, goverv, goverr, govers);
            UpdateCptGovernmentSignatureRetLog(0, cptId, cptVersion);
            return true;
        }
    else {
        UpdateCptGovernmentSignatureRetLog(CPT_NOT_EXIST, 0, 0);
        return false;
        }
    }
    
    
    function updateCptGovernmentSignature(
        uint cptId,
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers
    )
        public
        returns(bool)
    {
        return updateCptGovernmentSignatureInner(cptId, publisher, goverv, goverr, govers, cptDataStorageAddress);
    }
    
    //更新cpt中的信息（除去政府签名）
    function updateCptInner(
        uint cptId,
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address dataStorageAddress
    )
        private
        returns(bool)
    {
        if (!weIdContract.isIdentityExist(publisher)) {
            UpdateCptRetLog(CPT_PUBLISHER_NOT_EXIST, 0, 0);
            return false;
        }
        CptData cptData = CptData(dataStorageAddress);
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_ORGANIZATION())
            && publisher != cptData.getCptPublisher(cptId)) {
            UpdateCptRetLog(NO_PERMISSION, 0, 0);
            return false;
        }
        if (cptData.isCptExist(cptId)) {
            int[8] memory cptIntArray = cptData.getCptIntArray(cptId);
            int cptVersion = cptIntArray[0] + 1;
            intArray[0] = cptVersion;
            int created = cptIntArray[1];
            intArray[1] = created;
            cptData.putCptnoGovernmentSignature(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s);
            UpdateCptRetLog(0, cptId, cptVersion);
            return true;
        }
    else {
        UpdateCptRetLog(CPT_NOT_EXIST, 0, 0);
        return false;
        }
    }
    
    
    function updateCpt(
        uint cptId,
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        returns(bool)
    {
        return updateCptInner(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s, cptDataStorageAddress);
    }   
    
    
    function updatePolicy(
        uint cptId,
        address publisher,
        int[8] intArray,
        bytes32[8] bytes32Array,
        bytes32[128] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        returns(bool)
    {
        return updateCptInner(cptId, publisher, intArray, bytes32Array, jsonSchemaArray, v, r, s, policyDataStorageAddress);
    }
    
    
    //
    function queryCptGovernmentSignatureInner(
        uint cptId,
        address dataStorageAddress
    )
        private
        constant
        returns(
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers)
    {
        CptData cptData = CptData(dataStorageAddress);
        publisher = cptData.getCptPublisher(cptId);
        (goverv, goverr, govers) = cptData.getGoverSignature(cptId);
    }
    
    //查询政府签名信息
    function queryCptGovernmentSignature(
        uint cptId
    )
        public
        constant
        returns
    (
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers)
    {
        return queryCptGovernmentSignatureInner(cptId, cptDataStorageAddress);
    }
    
    
    function queryPolicyGovernmentSignature(
        uint cptId
    )
        public
        constant
        returns
    (
        address publisher,
        uint8 goverv,
        bytes32 goverr,
        bytes32 govers)
    {
        return queryCptGovernmentSignatureInner(cptId, policyDataStorageAddress);
    }
    
    //查询cpt中信息
    function queryCptInner(
        uint cptId,
        address dataStorageAddress
    )
        private
        constant
        returns(
        address publisher,
        int[] intArray,
        bytes32[] bytes32Array,
        bytes32[] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s)
    {
        CptData cptData = CptData(dataStorageAddress);
        publisher = cptData.getCptPublisher(cptId);
        intArray = getCptDynamicIntArray(cptId, dataStorageAddress);
        bytes32Array = getCptDynamicBytes32Array(cptId, dataStorageAddress);
        jsonSchemaArray = getCptDynamicJsonSchemaArray(cptId, dataStorageAddress);
        (v, r, s) = cptData.getCptSignature(cptId);
    }
    
    
    function queryCpt(
        uint cptId
    )
        public
        constant
        returns
    (
        address publisher,
        int[] intArray,
        bytes32[] bytes32Array,
        bytes32[] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s)
    {
        return queryCptInner(cptId, cptDataStorageAddress);
    }
    
    
    function queryPolicy(
        uint cptId
    )
        public
        constant
        returns
    (
        address publisher,
        int[] intArray,
        bytes32[] bytes32Array,
        bytes32[] jsonSchemaArray,
        uint8 v,
        bytes32 r,
        bytes32 s)
    {
        return queryCptInner(cptId, policyDataStorageAddress);
    }
    
    
    function getCptDynamicIntArray(
        uint cptId,
        address dataStorageAddress
    )
        public
        constant
        returns(int[])
    {
        CptData cptData = CptData(dataStorageAddress);
        int[8] memory staticIntArray = cptData.getCptIntArray(cptId);
        int[] memory dynamicIntArray = new int[](8);
        for (uint i = 0; i < 8; i++) {
            dynamicIntArray[i] = staticIntArray[i];
        }
        return dynamicIntArray;
    }
    
    
    function getCptDynamicBytes32Array(
        uint cptId,
        address dataStorageAddress
    )
        public
        constant
        returns(bytes32[])
    {
        CptData cptData = CptData(dataStorageAddress);
        bytes32[8] memory staticBytes32Array = cptData.getCptBytes32Array(cptId);
        bytes32[] memory dynamicBytes32Array = new bytes32[](8);
        for (uint i = 0; i < 8; i++) {
            dynamicBytes32Array[i] = staticBytes32Array[i];
        }
        return dynamicBytes32Array;
    }
    
    
    function getCptDynamicJsonSchemaArray(
        uint cptId,
        address dataStorageAddress
    )
        public
        constant
        returns(bytes32[])
    {
        CptData cptData = CptData(dataStorageAddress);
        bytes32[128] memory staticBytes32Array = cptData.getCptJsonSchemaArray(cptId);
        bytes32[] memory dynamicBytes32Array = new bytes32[](128);
        for (uint i = 0; i < 128; i++) {
            dynamicBytes32Array[i] = staticBytes32Array[i];
        }
        return dynamicBytes32Array;
    }
    
    
    function getPolicyIdList(uint startPos, uint num)
        public
        constant
        returns(uint[])
    {
        CptData cptData = CptData(policyDataStorageAddress);
        uint totalLength = cptData.getDatasetLength();
        uint dataLength;
        if (totalLength < startPos) {
            return new uint[](1);
        }
    else if (totalLength <= startPos + num) {
     dataLength = totalLength - startPos;
    }
    else {
     dataLength = num;
    }
    uint[] memory result = new uint[](dataLength);
    for (uint i = 0; i < dataLength; i++) {
        result[i] = cptData.getCptIdFromIndex(startPos + i);
    }
    return result;
    }
    
    
    function getCptIdList(uint startPos, uint num)
        public
        constant
        returns(uint[])
    {
        CptData cptData = CptData(cptDataStorageAddress);
        uint totalLength = cptData.getDatasetLength();
        uint dataLength;
        if (totalLength < startPos) {
            return new uint[](1);
        }
        else if (totalLength <= startPos + num) {
        dataLength = totalLength - startPos;
        }
        else {
            dataLength = num;
        }
        uint[] memory result = new uint[](dataLength);
        for (uint i = 0; i < dataLength; i++) {
            result[i] = cptData.getCptIdFromIndex(startPos + i);
        }
        return result;
    }
    
    
    function getTotalCptId() public constant returns(uint) {
        CptData cptData = CptData(cptDataStorageAddress);
        return cptData.getDatasetLength();
    }
    
    
    function getTotalPolicyId() public constant returns(uint) {
        CptData cptData = CptData(policyDataStorageAddress);
        return cptData.getDatasetLength();
    }
    
    
    // --------------------------------------------------------
    // Credential Template storage related funcs
    // store the cptId and blocknumber
    mapping(uint => uint) credentialTemplateStored;
    event CredentialTemplate(
        uint cptId,
        bytes credentialPublicKey,
        bytes credentialProof
    );
    
    function putCredentialTemplate(
        uint cptId,
        bytes credentialPublicKey,
        bytes credentialProof
    )
        public
    {
        CredentialTemplate(cptId, credentialPublicKey, credentialProof);
        credentialTemplateStored[cptId] = block.number;
    }
    
    function getCredentialTemplateBlock(
        uint cptId
    )
        public
        constant
        returns(uint)
    {
        return credentialTemplateStored[cptId];
    }
    
    // --------------------------------------------------------
    // Claim Policy storage belonging to v.s. Presentation, Publisher WeID, and CPT
    // Store the registered Presentation Policy ID (uint) v.s. Claim Policy ID list (uint[])
    mapping(uint => uint[]) private claimPoliciesFromPresentation;
    mapping(uint => address) private claimPoliciesWeIdFromPresentation;
    // Store the registered CPT ID (uint) v.s. Claim Policy ID list (uint[])
    mapping(uint => uint[]) private claimPoliciesFromCPT;
    
    uint private presentationClaimMapId = 1;
    
    function putClaimPoliciesIntoPresentationMap(uint[] uintArray) public {
        claimPoliciesFromPresentation[presentationClaimMapId] = uintArray;
        claimPoliciesWeIdFromPresentation[presentationClaimMapId] = msg.sender;
        RegisterCptRetLog(0, presentationClaimMapId, CPT_DEFAULT_VERSION);
        presentationClaimMapId++;
    }
    
    function getClaimPoliciesFromPresentationMap(uint presentationId) public constant returns(uint[], address) {
        return (claimPoliciesFromPresentation[presentationId], claimPoliciesWeIdFromPresentation[presentationId]);
    }
    
    function putClaimPoliciesIntoCptMap(uint cptId, uint[] uintArray) public {
        claimPoliciesFromCPT[cptId] = uintArray;
        RegisterCptRetLog(0, cptId, CPT_DEFAULT_VERSION);
    }
    
    function getClaimPoliciesFromCptMap(uint cptId) public constant returns(uint[]) {
        return claimPoliciesFromCPT[cptId];
    }
    }