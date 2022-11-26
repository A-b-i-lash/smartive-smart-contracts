// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

pragma solidity >=0.8.0;

contract ClinicalTrialData is ERC1155, Ownable, AccessControl {
    bytes32 private constant DOCTOR_ROLE = keccak256("DOCTOR_ROLE");
    bytes32 private constant DATA_CENTER_ROLE = keccak256("DATA_CENTER_ROLE");
    using Counters for Counters.Counter;
    Counters.Counter private _patientIdCounter;

    enum Gender {MALE, FEMALE, OTHER}

    struct PatientOverview {
        uint256 patientId;
        uint256 age;
        Gender gender;
        address doctorAddress;
    }
    
    struct Patient {
        uint256 patientId;
        uint256 age;
        Gender gender;
        string[] diseases;
        string[] drugs;
        address doctorAddress;
        LabResult[] labResults;
    }

    struct LabResult {
        string testName;
        uint256 testValue;
        uint256 timestamp;
    }
    
    struct Doctor {
        string name;
        address doctorAddress;
        uint256 enteredDataNumber;
        uint256 soldDataNumber;
    }

    struct ClinicalDataCenter {
        string name;
        uint256 workerCapacity;
        address addressInfo;
    }

    mapping(uint256 => PatientOverview) patientOverviews;
    mapping(uint256 => Patient) private patients;
    mapping(address => Doctor) doctors;
    mapping(address => ClinicalDataCenter) dataCenters;
    address[] doctorList;
    address[] dataCenterList;
    uint256[] patientList;
    uint256 constant public dataEnterPrice = 0.0005 ether;
    uint256 constant public dataBuyPrice = 0.002 ether;
    
    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addDoctor(string memory name, address doctorAddress) public onlyOwner {
        require(doctors[msg.sender].doctorAddress == address(0), "Doctor has already added.");
        doctors[doctorAddress] = Doctor(name, doctorAddress, 0, 0);
        _grantRole(DOCTOR_ROLE, doctorAddress);
        doctorList.push(doctorAddress);
    }

    function addDataCenter(string memory name, uint256 workerCapacity, address dataCenterAddress) public onlyOwner {
        require(dataCenters[msg.sender].addressInfo == address(0), "Data center has already added.");
        dataCenters[dataCenterAddress] = ClinicalDataCenter(name, workerCapacity, dataCenterAddress);
        _grantRole(DATA_CENTER_ROLE, dataCenterAddress);
        dataCenterList.push(dataCenterAddress);
    }

    function addPatient(uint256 age, uint8 genderIndex, string[] memory diseases, string[] memory drugs) public onlyRole(DOCTOR_ROLE) payable {
        require(genderIndex <= uint8(Gender.OTHER), "Gender is out of range.");
        require(age > 0, "Please enter a valid age.");
        require(diseases.length > 0, "Disases can not be empty.");
        require(msg.value >= dataEnterPrice, "You don't have enough price.");
        uint256 patientId = _patientIdCounter.current();
        _patientIdCounter.increment();
        Patient storage patientEntered = patients[patientId];
        patientEntered.patientId = patientId;
        patientEntered.age = age;
        patientEntered.gender = Gender(genderIndex);
        patientEntered.diseases = diseases;
        patientEntered.drugs = drugs;
        patientEntered.doctorAddress = msg.sender;
        patientOverviews[patientId] = PatientOverview(patientId, age, Gender(genderIndex), msg.sender);
        doctors[msg.sender].enteredDataNumber++;
        patientList.push(patientId);
    }

    function addLabResult(uint256 patientId, string memory testName, uint256 testValue) public onlyRole(DOCTOR_ROLE) {
        require(patients[patientId].age > 0, "There is no patient with the given id.");
        require(patients[patientId].doctorAddress == msg.sender, "This patient is not your patient.");
        patients[patientId].labResults.push(LabResult(testName, testValue, block.timestamp));
    }

    function buyData(uint256 patientId) public onlyRole(DATA_CENTER_ROLE) payable {
        require(msg.value >= dataBuyPrice, "You don't have enough price.");
        require(patients[patientId].age > 0, "There is no patient with the given id.");
        require(balanceOf(msg.sender, patientId) == 0, "You have already bough this patient data.");
        doctors[patients[patientId].doctorAddress].soldDataNumber++;
        _mint(msg.sender, patientId, 1, "");
        (bool success, ) = payable(patients[patientId].doctorAddress).call{value: dataBuyPrice / 2}("");
        require(success, "The money couldn't be transferred");
    }

    function seePatientData(uint256 patientId) public view onlyRole(DATA_CENTER_ROLE) returns (Patient memory patient) {
        require(patients[patientId].age > 0, "There is no patient with the given id.");
        require(balanceOf(msg.sender, patientId) > 0, "You didn't buy this patient data.");
        return patients[patientId];
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance is 0.");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw couldn't be completed");
    }

    function getAllDoctorList() public view returns(address[] memory _doctorItems) {
        return doctorList;
    }

    function getAllDataCenterList() public view returns(address[] memory _dataCentertems) {
        return dataCenterList;
    }

    function getAllPatientList() public view returns(uint256[] memory items) {
        return patientList;
    }

    function getPatientOverviewById(uint256 patientId) public view returns(PatientOverview memory item) {
        return patientOverviews[patientId];
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}