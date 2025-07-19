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