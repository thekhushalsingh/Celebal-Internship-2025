
# SQL Server Stored Procedures for Slowly Changing Dimensions (SCD)

This repository provides a set of T-SQL scripts to create and manage various types of **Slowly Changing Dimensions (SCDs)** using stored procedures in **SQL Server 2019**. The examples are built using the `AdventureWorks2019` sample database.

SCDs are a fundamental data warehousing technique used to manage the history of dimension data. This project serves as a practical guide for understanding and implementing these different historical tracking methods.

---

## 📜 Features

This project includes stored procedures for the following SCD types:

* **SCD Type 0**: The Passive Method (No Changes)
* **SCD Type 1**: Overwrite
* **SCD Type 2**: Add a New Row (Full History)
* **SCD Type 3**: Add a New Attribute (Limited History)
* **SCD Type 4**: Use a History Table
* **SCD Type 6**: Combined Approach (1 + 2 + 3)

---
### SCD Type 0: The Passive Method
Concept: The dimension attributes never change. The data is loaded once and is never updated. This is suitable for attributes that are guaranteed to be static, like a date of birth.

Stored Procedure for SCD Type 0
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPerson_SCD0
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert new records that don't exist in the dimension
    INSERT INTO dbo.DimPerson_SCD0 (PersonID, FirstName, LastName, EmailPromotion)
    SELECT
        p.BusinessEntityID,
        p.FirstName,
        p.LastName,
        p.EmailPromotion
    FROM Person.Person p
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimPerson_SCD0 d
        WHERE d.PersonID = p.BusinessEntityID
    );
END;
GO

### SCD Type 1: Overwrite
Concept: When a change occurs in a source attribute, the corresponding attribute in the dimension table is overwritten with the new value. This method does not keep any history of old values.

Stored Procedure for SCD Type 1
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPerson_SCD1
AS
BEGIN
    SET NOCOUNT ON;

    -- Use MERGE to handle inserts and updates
    MERGE dbo.DimPerson_SCD1 AS Target
    USING Person.Person AS Source
    ON (Target.PersonID = Source.BusinessEntityID)
    -- For updates (records that match)
    WHEN MATCHED AND Target.EmailPromotion <> Source.EmailPromotion THEN
        UPDATE SET
            Target.EmailPromotion = Source.EmailPromotion
    -- For inserts (records that do not match)
    WHEN NOT MATCHED BY Target THEN
        INSERT (PersonID, FirstName, LastName, EmailPromotion)
        VALUES (Source.BusinessEntityID, Source.FirstName, Source.LastName, Source.EmailPromotion);
END;
GO

### SCD Type 2: Add a New Row
Concept: This is the most common method for tracking historical data. When an attribute changes, the existing record in the dimension is marked as "expired" (e.g., by setting an EndDate and IsCurrent flag), and a new record is inserted with the updated attribute value. This requires a surrogate key to uniquely identify each version of a dimension member.

Stored Procedure for SCD Type 2
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPerson_SCD2
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Identify changed records from the source
    SELECT
        p.BusinessEntityID,
        p.FirstName,
        p.LastName,
        p.EmailPromotion
    INTO #ChangedPersons
    FROM Person.Person p
    JOIN dbo.DimPerson_SCD2 d ON p.BusinessEntityID = d.PersonID
    WHERE d.IsCurrent = 1 AND d.EmailPromotion <> p.EmailPromotion;

    -- Step 2: Expire the old records for the changed persons
    UPDATE d
    SET
        d.EndDate = GETDATE(),
        d.IsCurrent = 0
    FROM dbo.DimPerson_SCD2 d
    JOIN #ChangedPersons c ON d.PersonID = c.BusinessEntityID
    WHERE d.IsCurrent = 1;

    -- Step 3: Insert the new version of the changed records
    INSERT INTO dbo.DimPerson_SCD2 (PersonID, FirstName, LastName, EmailPromotion, StartDate, EndDate, IsCurrent)
    SELECT
        c.BusinessEntityID,
        c.FirstName,
        c.LastName,
        c.EmailPromotion,
        GETDATE(), -- StartDate
        NULL,      -- EndDate
        1          -- IsCurrent
    FROM #ChangedPersons c;

    -- Step 4: Insert brand new records
    INSERT INTO dbo.DimPerson_SCD2 (PersonID, FirstName, LastName, EmailPromotion, StartDate, EndDate, IsCurrent)
    SELECT
        p.BusinessEntityID,
        p.FirstName,
        p.LastName,
        p.EmailPromotion,
        GETDATE(), -- StartDate
        NULL,      -- EndDate
        1          -- IsCurrent
    FROM Person.Person p
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimPerson_SCD2 d
        WHERE d.PersonID = p.BusinessEntityID
    );

    -- Clean up temp table
    DROP TABLE #ChangedPersons;
END;
GO

### SCD Type 3: Add a New Attribute
Concept: This method tracks limited history by adding a new column to store the "previous" value of an attribute. When the attribute changes, the current value is moved to the "previous" column, and the "current" column is updated with the new value.

Stored Procedure for SCD Type 3
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPerson_SCD3
AS
BEGIN
    SET NOCOUNT ON;

    -- Use MERGE for a concise implementation
    MERGE dbo.DimPerson_SCD3 AS Target
    USING Person.Person AS Source
    ON (Target.PersonID = Source.BusinessEntityID)
    -- When a person exists and their email promotion preference has changed
    WHEN MATCHED AND Target.CurrentEmailPromotion <> Source.EmailPromotion THEN
        UPDATE SET
            Target.PreviousEmailPromotion = Target.CurrentEmailPromotion,
            Target.CurrentEmailPromotion = Source.EmailPromotion
    -- When a new person is found in the source
    WHEN NOT MATCHED BY Target THEN
        INSERT (PersonID, FirstName, LastName, CurrentEmailPromotion, PreviousEmailPromotion)
        VALUES (Source.BusinessEntityID, Source.FirstName, Source.LastName, Source.EmailPromotion, NULL);
END;
GO

### SCD Type 4: Use a History Table (Corrected)
Concept: This approach uses two tables: a main dimension table that always stores the most current data (like SCD Type 1), and a separate history table that tracks all historical changes (similar to a log). The two tables are linked by the business key.

Stored Procedure for SCD Type 4
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPerson_SCD4
AS
BEGIN
    SET NOCOUNT ON;

    -- Create a temporary table to hold source data with a flag for changes
    SELECT
        p.BusinessEntityID,
        p.FirstName,
        p.LastName,
        p.EmailPromotion,
        h.EmailPromotion AS OldEmailPromotion,
        CASE
            -- A person is 'New' if they don't exist in the main dimension table.
            WHEN d4.PersonID IS NULL THEN 'New'
            -- A person is 'Changed' if their EmailPromotion in the source differs from the latest history record.
            -- ISNULL is used to handle the very first record for a person where history might not exist yet.
            WHEN ISNULL(h.EmailPromotion, -1) <> p.EmailPromotion THEN 'Changed'
            ELSE 'NoChange'
        END AS ChangeType
    INTO #SourceChanges
    FROM Person.Person p
    LEFT JOIN dbo.DimPerson_SCD4 d4 ON p.BusinessEntityID = d4.PersonID -- Main dimension table
    LEFT JOIN (
        -- Subquery to get only the most recent history record for each person
        SELECT PersonID, EmailPromotion
        FROM (
            SELECT PersonID, EmailPromotion, ROW_NUMBER() OVER(PARTITION BY PersonID ORDER BY StartDate DESC) as rn
            FROM dbo.DimPerson_SCD4_History
        ) hist_inner
        WHERE hist_inner.rn = 1
    ) h ON p.BusinessEntityID = h.PersonID; -- History table

    -- Step 1: Update the end date for the previous history record of changed items
    UPDATE h_update
    SET h_update.EndDate = GETDATE()
    FROM dbo.DimPerson_SCD4_History h_update
    JOIN #SourceChanges s ON h_update.PersonID = s.BusinessEntityID
    WHERE s.ChangeType = 'Changed' AND h_update.EndDate IS NULL;

    -- Step 2: Insert new records into the history table for new and changed items
    INSERT INTO dbo.DimPerson_SCD4_History (PersonID, EmailPromotion, StartDate, EndDate)
    SELECT
        BusinessEntityID,
        EmailPromotion,
        GETDATE(),
        NULL
    FROM #SourceChanges
    WHERE ChangeType IN ('New', 'Changed');

    -- Step 3: Use MERGE to update the main dimension table (SCD Type 1 logic)
    MERGE dbo.DimPerson_SCD4 AS Target
    USING #SourceChanges AS Source
    ON (Target.PersonID = Source.BusinessEntityID)
    WHEN MATCHED AND Source.ChangeType = 'Changed' THEN
        UPDATE SET
            -- Only non-tracked attributes are updated here if necessary.
            -- In this design, EmailPromotion is only in the history table.
            Target.FirstName = Source.FirstName,
            Target.LastName = Source.LastName
    WHEN NOT MATCHED BY Target AND Source.ChangeType = 'New' THEN
        INSERT (PersonID, FirstName, LastName)
        VALUES (Source.BusinessEntityID, Source.FirstName, Source.LastName);

    -- Clean up
    DROP TABLE #SourceChanges;
END;
GO

### SCD Type 6: Combined Approach (1+2+3) (Corrected)
Concept: SCD Type 6 builds on the other types to provide a powerful hybrid solution. It combines:

SCD Type 1: Overwriting a Current attribute for easy reporting on the latest state.

SCD Type 2: Adding a new row to maintain full history (StartDate, EndDate, IsCurrent).

SCD Type 3: Adding a Previous attribute to easily see the prior state.

Stored Procedure for SCD Type 6
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimPerson_SCD6
AS
BEGIN
    SET NOCOUNT ON;

    -- A temporary table to store the state of persons whose EmailPromotion has changed.
    -- We store the old value to use it as the "PreviousEmailPromotion" later.
    SELECT
        p.BusinessEntityID,
        p.FirstName,
        p.LastName,
        p.EmailPromotion AS NewEmailPromotion,
        d.CurrentEmailPromotion AS OldEmailPromotion
    INTO #ChangedPersonsSCD6
    FROM Person.Person p
    JOIN dbo.DimPerson_SCD6 d ON p.BusinessEntityID = d.PersonID
    WHERE d.IsCurrent = 1 AND d.CurrentEmailPromotion <> p.EmailPromotion;

    -- Step 1: Expire the old "current" records for the changed persons.
    -- This marks the end of the validity of the old record.
    UPDATE d
    SET
        d.EndDate = GETDATE(),
        d.IsCurrent = 0
    FROM dbo.DimPerson_SCD6 d
    JOIN #ChangedPersonsSCD6 c ON d.PersonID = c.BusinessEntityID
    WHERE d.IsCurrent = 1;

    -- Step 2: Insert the new "current" records.
    -- These new records contain the updated information.
    INSERT INTO dbo.DimPerson_SCD6 (
        PersonID, FirstName, LastName,
        CurrentEmailPromotion, PreviousEmailPromotion,
        StartDate, EndDate, IsCurrent
    )
    SELECT
        c.BusinessEntityID,
        c.FirstName,
        c.LastName,
        c.NewEmailPromotion,      -- The new value for the tracked attribute.
        c.OldEmailPromotion,      -- The old value is now the "previous" value.
        GETDATE(),                -- The start date for this version of the record.
        NULL,                     -- The end date is NULL because this is the current version.
        1                         -- This is the current version.
    FROM #ChangedPersonsSCD6 c;

    -- Step 3: Update the CurrentEmailPromotion on all historical (non-current) rows for the changed person.
    -- This is the SCD Type 1 aspect of Type 6, ensuring the "current" view is consistent across all versions.
    UPDATE d
    SET d.CurrentEmailPromotion = c.NewEmailPromotion
    FROM dbo.DimPerson_SCD6 d
    JOIN #ChangedPersonsSCD6 c ON d.PersonID = c.BusinessEntityID;

    -- Step 4: Insert brand new records for persons not yet in the dimension.
    INSERT INTO dbo.DimPerson_SCD6 (
        PersonID, FirstName, LastName,
        CurrentEmailPromotion, PreviousEmailPromotion,
        StartDate, EndDate, IsCurrent
    )
    SELECT
        p.BusinessEntityID,
        p.FirstName,
        p.LastName,
        p.EmailPromotion,
        NULL, -- No previous value for a new record.
        GETDATE(),
        NULL,
        1
    FROM Person.Person p
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimPerson_SCD6 d
        WHERE d.PersonID = p.BusinessEntityID
    );

    -- Clean up the temporary table.
    DROP TABLE #ChangedPersonsSCD6;
END;
GO

## 💾 Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **SQL Server 2019** (or a later version).
2.  The **AdventureWorks2019** sample database. You can download it from the official Microsoft repository.

---

## 🛠️ Setup

First, you need to create the target dimension tables for each SCD type. Run the script below in your SQL Server instance against the `AdventureWorks2019` database.

```sql
-- Use the AdventureWorks2019 database
USE AdventureWorks2019;
GO

-- Drop tables if they already exist to start fresh
IF OBJECT_ID('dbo.DimPerson_SCD0', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD0;
IF OBJECT_ID('dbo.DimPerson_SCD1', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD1;
IF OBJECT_ID('dbo.DimPerson_SCD2', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD2;
IF OBJECT_ID('dbo.DimPerson_SCD3', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD3;
IF OBJECT_ID('dbo.DimPerson_SCD4_History', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD4_History;
IF OBJECT_ID('dbo.DimPerson_SCD4', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD4;
IF OBJECT_ID('dbo.DimPerson_SCD6', 'U') IS NOT NULL DROP TABLE dbo.DimPerson_SCD6;
GO

-- Create Dimension Table for SCD Type 0
CREATE TABLE dbo.DimPerson_SCD0 (
    PersonID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    EmailPromotion INT
);

-- Create Dimension Table for SCD Type 1
CREATE TABLE dbo.DimPerson_SCD1 (
    PersonID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    EmailPromotion INT
);

-- Create Dimension Table for SCD Type 2
CREATE TABLE dbo.DimPerson_SCD2 (
    PersonSK INT PRIMARY KEY IDENTITY(1,1), -- Surrogate Key
    PersonID INT, -- Business Key
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    EmailPromotion INT,
    StartDate DATETIME,
    EndDate DATETIME,
    IsCurrent BIT
);

-- Create Dimension Table for SCD Type 3
CREATE TABLE dbo.DimPerson_SCD3 (
    PersonID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    CurrentEmailPromotion INT,
    PreviousEmailPromotion INT
);

-- Create Dimension Table for SCD Type 4
CREATE TABLE dbo.DimPerson_SCD4 (
    PersonID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50)
);

-- Create History Table for SCD Type 4
CREATE TABLE dbo.DimPerson_SCD4_History (
    HistorySK INT PRIMARY KEY IDENTITY(1,1),
    PersonID INT,
    EmailPromotion INT,
    StartDate DATETIME,
    EndDate DATETIME
);

-- Create Dimension Table for SCD Type 6
CREATE TABLE dbo.DimPerson_SCD6 (
    PersonSK INT PRIMARY KEY IDENTITY(1,1), -- Surrogate Key
    PersonID INT, -- Business Key
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    CurrentEmailPromotion INT,
    PreviousEmailPromotion INT,
    StartDate DATETIME,
    EndDate DATETIME,
    IsCurrent BIT
);
GO
```

---

## 🚀 Usage

1.  **Create the Stored Procedures**: Run the provided SQL files (`usp_Load_DimPerson_SCD0.sql`, `usp_Load_DimPerson_SCD1.sql`, etc.) to create the stored procedures in your database.

2.  **Execute a Procedure**: To populate or update a dimension table, execute the corresponding stored procedure.

    ```sql
    -- Example: Load the SCD Type 1 Dimension
    EXEC dbo.usp_Load_DimPerson_SCD1;

    -- Example: Load the SCD Type 2 Dimension
    EXEC dbo.usp_Load_DimPerson_SCD2;
    ```

---

## 📊 How to View Data

After running a load procedure, you can query the tables to see the results.

```sql
-- View SCD Type 1 Data (overwrites changes)
SELECT * FROM dbo.DimPerson_SCD1 ORDER BY PersonID;

-- View SCD Type 2 Data (shows full history)
SELECT * FROM dbo.DimPerson_SCD2 ORDER BY PersonID, StartDate;

-- View just the current records in SCD Type 2
SELECT * FROM dbo.DimPerson_SCD2 WHERE IsCurrent = 1 ORDER BY PersonID;

-- View SCD Type 4 main table and history table
SELECT * FROM dbo.DimPerson_SCD4 ORDER BY PersonID;
SELECT * FROM dbo.DimPerson_SCD4_History ORDER BY PersonID, StartDate;
```

---

## 🧪 Testing Changes

To see the SCD logic in action, you can simulate a change in the source data and re-run the procedures.

1.  **Make a Change**: Run an `UPDATE` on the source `Person.Person` table.

    ```sql
    -- Example: Change the email preference for a person
    UPDATE Person.Person
    SET EmailPromotion = 2 -- Change from its original value
    WHERE BusinessEntityID = 2;
    ```

2.  **Re-run a Stored Procedure**:

    ```sql
    EXEC dbo.usp_Load_DimPerson_SCD2;
    ```

3.  **Observe the Result**: Query the dimension table again. For SCD Type 2, you will now see a new, current row for Person 2 with the updated value, and the old row will be marked as historical.
4.  Screenshot

5. ![image](https://github.com/thekhushalsingh/Celebal-Internship-2025/blob/main/SCD%20Types/Screenshot/Screenshot.png)
