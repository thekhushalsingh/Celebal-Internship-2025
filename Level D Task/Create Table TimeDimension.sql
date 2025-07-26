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
