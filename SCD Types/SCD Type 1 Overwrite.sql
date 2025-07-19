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