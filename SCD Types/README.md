
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
