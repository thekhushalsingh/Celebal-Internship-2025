SELECT patient_id, patient_name, conditions
FROM Patients
WHERE
    conditions REGEXP '(^| )DIAB1[0-9]*($| )';


--khushal singh