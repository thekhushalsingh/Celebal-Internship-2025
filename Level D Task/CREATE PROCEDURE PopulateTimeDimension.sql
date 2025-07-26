CREATE PROCEDURE PopulateTimeDimension
    @InputDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartDate DATE = DATEFROMPARTS(YEAR(@InputDate), 1, 1);
    DECLARE @EndDate DATE = DATEFROMPARTS(YEAR(@InputDate), 12, 31);

    ;WITH DateRange AS (
        SELECT @StartDate AS DateValue
        UNION ALL
        SELECT DATEADD(DAY, 1, DateValue)
        FROM DateRange
        WHERE DateValue < @EndDate
    )
    INSERT INTO TimeDimension (
        SKDate,
        KeyDate,
        Date,
        CalendarDay,
        CalendarMonth,
        CalendarQuarter,
        CalendarYear,
        DayNameLong,
        DayNameShort,
        DayNumberOfWeek,
        DayNumberOfYear,
        DaySuffix,
        FiscalWeek,
        FiscalPeriod,
        FiscalQuarter,
        FiscalYear,
        [Fiscal Year/Period]
    )
    SELECT
        CONVERT(INT, FORMAT(DateValue, 'yyyyMMdd')) AS SKDate,
        DateValue AS KeyDate,
        DateValue AS Date,
        DAY(DateValue) AS CalendarDay,
        MONTH(DateValue) AS CalendarMonth,
        DATEPART(QUARTER, DateValue) AS CalendarQuarter,
        YEAR(DateValue) AS CalendarYear,
        DATENAME(WEEKDAY, DateValue) AS DayNameLong,
        LEFT(DATENAME(WEEKDAY, DateValue), 3) AS DayNameShort,
        DATEPART(WEEKDAY, DateValue) AS DayNumberOfWeek,
        DATEPART(DAYOFYEAR, DateValue) AS DayNumberOfYear,
        FORMAT(DAY(DateValue), '00') +
            CASE 
                WHEN DAY(DateValue) IN (11,12,13) THEN 'th'
                WHEN RIGHT(DAY(DateValue),1) = '1' THEN 'st'
                WHEN RIGHT(DAY(DateValue),1) = '2' THEN 'nd'
                WHEN RIGHT(DAY(DateValue),1) = '3' THEN 'rd'
                ELSE 'th'
            END AS DaySuffix,
        DATEPART(WEEK, DateValue) AS FiscalWeek,
        MONTH(DateValue) AS FiscalPeriod,
        DATEPART(QUARTER, DateValue) AS FiscalQuarter,
        YEAR(DateValue) AS FiscalYear,
        CAST(YEAR(DateValue) AS VARCHAR) + RIGHT('0' + CAST(MONTH(DateValue) AS VARCHAR), 2) AS [Fiscal Year/Period]
    FROM DateRange
    OPTION (MAXRECURSION 366);
END
