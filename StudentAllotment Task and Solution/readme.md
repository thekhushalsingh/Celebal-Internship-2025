# Student Allotment SQL Problem

This project implements an elective allocation system using SQL. The system allocates elective subjects to students based on their GPA and preferences.

## Table of Contents

- [Database Schema](#database-schema)
- [Setup Instructions](#setup-instructions)
- [Running the Allocation Procedure](#running-the-allocation-procedure)
- [Verification](#verification)
- [Contact](#contact)

## Database Schema

The system uses the following tables:

1. **StudentDetails**: Stores student information.
2. **SubjectDetails**: Stores subject information and available seats.
3. **StudentPreference**: Stores student preferences for subjects.
4. **Allotments**: Stores the allocated subjects for students.
5. **UnallotedStudents**: Stores students who were not allocated any subjects.

## Setup Instructions

1. **Create and Populate Required Tables**

   To create and populate the required tables, please refer to the SQL script available at the following link:  
   [Student Allotment SQL Table]()

2. **Create the Stored Procedure**

   To create the stored procedure, please refer to the SQL script available at the following link:  
   [Student Allotment SQL Solution]()

## Running the Allocation Procedure

Once the tables are created and populated, and the stored procedure is defined, you can execute the stored procedure to allocate electives:

```sql
EXEC AllocateElectives;
```

## Verification

To verify the results of the allocation, you can query the `Allotments` and `UnallotedStudents` tables:

```sql
-- Check Allotments
SELECT * FROM Allotments;

-- Check UnallotedStudents
SELECT * FROM UnallotedStudents;
```
