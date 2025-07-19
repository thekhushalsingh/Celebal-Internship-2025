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

