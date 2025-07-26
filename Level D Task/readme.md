# 🗓️ Time Dimension Table Generator (SQL Server)

This project contains a SQL Server stored procedure that automatically populates a `TimeDimension` table with detailed date-related attributes for any given year. It is useful for building data warehouses, business intelligence reports, and analytics dashboards.

---

## 📌 Features

- Populates full date dimension for a given year using a single `INSERT INTO ... SELECT` statement.
- Auto-generates attributes like:
  - Day, Month, Quarter, Year
  - Day Names (Long & Short)
  - Week Number, Day Number of Year
  - Suffix (1st, 2nd, etc.)
  - Fiscal Year, Fiscal Period, Fiscal Quarter

---

## 🛠️ Setup

### 1. Create the TimeDimension Table

```sql
CREATE TABLE TimeDimension (
    SKDate INT PRIMARY KEY,
    KeyDate DATE,
    Date DATE,
    CalendarDay INT,
    CalendarMonth INT,
    CalendarQuarter INT,
    CalendarYear INT,
    DayNameLong VARCHAR(20),
    DayNameShort VARCHAR(10),
    DayNumberOfWeek INT,
    DayNumberOfYear INT,
    DaySuffix VARCHAR(5),
    FiscalWeek INT,
    FiscalPeriod INT,
    FiscalQuarter INT,
    FiscalYear INT,
    [Fiscal Year/Period] VARCHAR(10)
);
```

### 2. CREATE PROCEDURE PopulateTimeDimension
```sql
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
```
### 3. Execute the Procedure
Pass any date of the year you want to populate:
```sql
EXEC PopulateTimeDimension @InputDate = '2020-07-14';
```
This will generate and insert all 365/366 days for the year 2020.

🧪 Sample Query
```sql
SELECT * FROM TimeDimension ORDER BY Date;
```
### 4. Screenshot
![image](https://github.com/thekhushalsingh/Celebal-Internship-2025/blob/main/Level%20D%20Task/Screenshot.png)
