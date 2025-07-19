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