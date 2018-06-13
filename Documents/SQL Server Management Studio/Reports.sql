Use Reports

----------- 1. Create Database

CREATE TABLE Status(
	Id INT PRImary KEy Identity, 
	Label VARCHAR(30) NOT NULL
)

Create Table Departments (
	Id Int Primary Key Identity,
	Name NVarchar(50) NOT NULL
)

Create Table Categories(
	Id INT primary Key Identity,
	Name Varchar(50) NOT NULL,
	DepartmentId INT Foreign Key References Departments(Id) 
)

Create Table Employees(
	Id INT Primary Key Identity,
	FirstName NVarchar(25),
	LastName NVarchar(25),
	Gender Char(1) CHECK (Gender = 'M' OR Gender = 'F'),
	BirthDate DAteTime, 
	Age INT CHECK (Age >= 0),
	DepartmentId INT Foreign Key References Departments(Id) NOT NULL
)

Create Table Users(
	Id INT Primary Key Identity,
	Username NVarChar(30) NOT NULL UNIQUE,
	Password NVarchar(50) NOT NULL,
	Name NVarchar(50),
	Gender Char(1) CHECK (Gender = 'M' OR Gender = 'F'),
	BirthDate DateTime,
	Age INT Check(Age >= 0),
	Email NVarchar(50) NOT NULL
)

Create table Reports (
	Id Int Primary Key Identity,
	CategoryId INT NOT NULL Foreign Key References Categories(Id),
	StatusId INT NOT NULL Foreign Key References Status(Id),
	OpenDate DateTime NOT NULL,
	CloseDate DateTime, 
	Description Varchar(200), 
	UserId INT NOT NULL Foreign Key References Users(Id),
	EmployeeId INT Foreign Key References Employees(Id)
)

-------------- 2. Find which employee is responsible for each report

Select e.FirstName, e.LastName, r.Description, 
FORMAT(r.OpenDate, 'yyyy-MM-dd', 'en-US') as OpenDate
FROM Reports as r
JOIN Employees as e ON
r.EmployeeId = e.Id
Order by e.Id, r.OpenDate, r.Id

--------------- 3. Find which category is reported most often

Select c.Name as CategoryName, COUNT(r.Id) as [Reports Numbers] FROM Reports as r
JOIN Categories as c ON 
c.Id = r.CategoryId
Group by c.Name
Order by [Reports Numbers] DESC, CategoryName

---------------- 4. Find how many employees work in each category

SELECT c.Name as CategoryName, COUNT(*) as [Employees Number]
 FROM Employees as e
JOIN Departments as d ON d.Id = e.DepartmentId
JOIN Categories as c ON c.DepartmentId = d.Id
GROUP BY c.Name
Order by CategoryName

--------------- 5. Find how many users serves each employee

SELECT CONCAT(e.FirstName, ' ', e.LastName) as Name, COUNT(Distinct r.Id) as [Users Number]
FROM Employees as e
LEFT JOIN Reports as r ON 
r.EmployeeId = e.Id
Group by e.FirstName, e.LastName
Order by [Users Number] DESC, Name

--------------- 6. Find which categories have users placing a report on their birthday

SELECT cat.Name FROM Categories as cat
WHERE cat.Id IN
	(
		SELECT cat.Id FROM Categories as cat
		JOIN Reports as r ON 
		r.CategoryId = cat.Id
		JOIN Users as u ON 
		u.Id = r.UserId
		WHERE DATEPART(DAYOFYEAR, u.BirthDate) = DATEPART(DAYOFYEAR, r.OpenDate)
	)
Order by cat.Name


---------------- 7. Username coincidence


SELECT u.Username from Users as u WHERE
u.Id IN
	(
		Select u1.Id FROM Users as u1
		JOIN Reports as r ON
		r.UserId = u1.Id
		JOIN Categories as c ON
		c.Id = r.CategoryId
		WHERE (u1.Username like '[0-9]%' AND c.Id = LEFT(u1.Username, 1))
		OR (u1.Username like '%[0-9]' AND c.Id = RIGHT(u1.Username, 1))
	)
ORDER BY u.Username

-------------------- 8. Find ropen/ closed reports count for each employees

SELECT CONCAT(e.FirstName, ' ', e.LastName) as Name,
CONCAT(ISNULL(CountClose.ClosedCount, 0), '/', ISNULL(CountOpen.OpenCount, 0)) as [Closed Open Reports]
FROM Employees as e
LEFT JOIN (
	Select e.Id, COUNT(*) as OpenCount FROM Reports as r
	JOIN Employees as e ON e.Id = r.EmployeeId
	Where YEAR(r.OpenDate) = 2016
	GROUP BY e.Id) CountOpen
ON CountOpen.Id = e.ID
LEFT JOIN
	(Select e.Id, COUNT(*) as ClosedCount FROM Reports as r
	JOIN Employees as e ON e.Id = r.EmployeeId
	Where YEAR(r.CloseDate) = 2016
	GROUP BY e.Id) CountClose
ON CountClose.Id = e.Id
Where OpenCount IS NOT NULL OR ClosedCount IS NOT NULL
Order by Name, e.Id

----------------------- 9. Find how long does it take for each department to close a report on average

SELECT d.Name as [Department Name],
ISNULL(CAST(AVG(DATEDIFF(Day, r.OpenDate, r.CloseDate)) as VARCHAR), 'no info') as [Average Duration]
FROM Departments as d
JOIN Categories as c on c.DepartmentId = d.Id
JOIN Reports as r ON r.CategoryId = c.Id
Group by d.Name
Order by [Department Name] 

------------------------ 10. Find what percentage of the reports for each department go to each of the categories

SELECT d.Name as [Department Name], c.Name as [Category Name],
CAST((COUNT(r.Id) * 100 / CAST(total.totalCount as decimal)) AS decimal) as Percentage
FROM Departments as d
LEFT JOIN Categories as c on c.DepartmentId = d.Id
JOIN Reports as r ON r.CategoryId = c.Id
JOIN
	 (
		SELECT d.Id, COUNT(r.Id) as totalCount  FROM Departments as d
		JOIN Categories as c on c.DepartmentId = d.Id
		JOIN Reports as r ON r.CategoryId = c.Id
		GROUP BY d.Id
	 ) total
ON total.Id = d.Id
GROUP BY d.Name, c.Name, totalCount
Having COUNT(r.Id) * 100 / total.totalCount != 0
Order by [Department Name], [Category Name], Percentage

--------------------- 11. Find how much reports does an employee have with a certain status

CREATE FUNCTION dbo.udf_GetReportsCount(@employeeId INT, @StatusId INT)
RETURNS INT
AS
BEGIN
DECLARE @Result INT = (Select COUNT(*) FROM Reports
							Where EmployeeId = @employeeId AND StatusId = @StatusId) 

RETURN @Result

END

-------------------- 12. Set status on closed reports

CREATE TRIGGER tr_SetCloseDate ON Reports AFTER UPDATE
AS
BEGIN
		UPDATE Reports
		SET StatusId = (Select Id fROM Status Where Label = 'completed')
		WHere Id IN (Select Id FROM inserted
		WHere CloseDate Is NOT NULL) AND Id IN (Select Id FROM deleted WHere CloseDate IS NULL)
END

----------------------- 13. Find the main report status for each category

WITH CTE AS (
SELECT Category, LabelCount, Label
 FROM (
SELECT cat.Name as Category, COUNT(s.Label) as LabelCount, s.Label as Label,
DENSE_RANK() OVER(Partition by cat.Name ORder BY COUNT(s.Id) DESC) as rank
FROM Categories as cat
JOIN Reports as r ON r.CategoryId = cat.Id
JOIN Status as s ON s.Id = r.StatusId
Where s.Label = 'waiting' OR s.Label = 'in progress'
GROUP by cat.Name, s.LAbel
) rnk 
WHere rank = 1
) 
SELECT CategoryName as [Category Name], ReportsNumber as [Reports Number], Status as [Main Status]  FROM (

SELECT CTE.Category AS CategoryName, countLabel as ReportsNumber,
(
CASE
WHen rankCount.CountRank > 1 THEN 'equal'
ELSE CTE.Label
END
) AS Status FROM CTE
JOIN (SELECT Categories.Name as Category, COUNT(*) as countLabel FROM Reports
JOIN Categories ON Categories.Id = Reports.CategoryId
JOIN Status as s ON s.Id = Reports.StatusId
Where s.Label = 'waiting' OR s.Label = 'in progress'
GROUP BY Categories.Name) labelCount ON labelCount.Category = CTE.Category
JOIN (Select Category, COUNT(*) as CountRank FROM CTE
GROUP BY Category) rankCount ON CTE.Category = rankCount.Category
--GROUP BY CTE.Category, CTE.Label, labelCount.countLabel, CTE.LabelCount
) rnk
GROUP BY CategoryName, ReportsNumber, Status
Order by [Category Name], [Reports Number], [Main Status]
