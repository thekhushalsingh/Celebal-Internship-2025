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