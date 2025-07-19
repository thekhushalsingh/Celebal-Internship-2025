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