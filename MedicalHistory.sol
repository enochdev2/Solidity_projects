// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MedicalHistory {
     
     struct Patient {
        string name;
        uint age;
        string[] conditions;
        string[] medications;
     }


     mapping(address=> Patient) public  patients;

    function admitPatient(string memory _name, uint _age, string[] memory _conditions, string[] memory _medication) external {
        Patient memory _patient = Patient({
            name: _name, 
            age:_age, 
            conditions:_conditions,
            medications: _medication
            });
            patients[msg.sender] = _patient; 
    }

    function updatePatientDocument(string[] memory _conditions, string[] memory _medication) external {
         Patient storage _patient = patients[msg.sender];
         _patient.conditions = _conditions;
         _patient.medications = _medication;
    }

    function getPatientInfo()external view returns (Patient memory){
        Patient storage patient = patients[msg.sender];
        return patient;
    }
}