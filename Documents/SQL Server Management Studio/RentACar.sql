USE RentACar

-------1. Create Database 

Create Table Clients(
	Id Int Primary Key Identity(1,1), 
	FirstName Nvarchar(30) NOT NULL,
	LastName Nvarchar(30) NOT NULL,
	Gender CHAR(1) CHECK (Gender = 'M' Or Gender = 'F'),
	BirthDate DateTime,
	CreditCard NVarchar(30) Not NULl,
	CardValidity DateTime,
	Email NVarchar(50) NOT NULL
)

Create Table Towns(
	Id INT Primary KEY Identity(1,1),
	Name NVarchar(50)
)

Create Table Offices(
	Id INT PRimary KEy Identity(1,1), 
	Name NVarchar(40),
	ParkingPlaces INT Check (ParkingPlaces >= 0),
	TownId INT NOT NULL Foreign Key References Towns(Id)
)

Create Table Models(
	Id INt Primary Key Identity(1,1),
	Manufacturer NVarchar(50) NOT NULL,
	Model NVarchar(50) NOT NULL,
	ProductionYear DateTime,
	Seats INT CHeck (Seats >= 0),
	Class NVarChar(10),
	Consumption DECIMAL(14, 2)
)

Create Table Vehicles(
	Id INT PRImary KEy Identity(1,1),
	ModelId INT NOT NULL Foreign KEy References Models(Id),
	OfficeId INT NOT NULL Foreign Key References Offices(Id),
	Mileage INT CHeck (Mileage >= 0)
)

Create Table Orders(
	Id INT PRIMARY KEY IDentity(1,1),
	ClientId INT NOT NULL Foreign KEy References Clients(Id),
	TownId INT NOT NULL Foreign KEy References Towns(Id),
	VehicleId INT NOT NULL Foreign KEy References Vehicles(Id),
	CollectionDate DateTime NOT NULL,
	CollectionOfficeId INT NOT NULL Foreign Key References Offices(Id),
	ReturnDate DAteTime NOT NULL,
	ReturnOfficeId INT Foreign KEy References Offices(Id), 
	Bill Decimal(14, 2),
	TotalMileage INT Check (TotalMileage >= 0) 
)


----------- 2. Seed Databse

Insert into Models(Manufacturer, Model, ProductionYear, Seats, Class, Consumption) VALUES
	('Chevrolet', 'Astro', '2005-07-27  00:00:00.000', 4, 'Economy', 12.60),
	('Toyota', 'Solara', '2009-10-15  00:00:00.000', 7, 'Family', 13.80),
	('Volvo', 'S40', '2010-10-12  00:00:00.000', 3, 'Average', 11.30),
	('Suzuki', 'Swift', '2000-02-03  00:00:00.000', 7, 'Economy',  16.20)

Insert into Orders(ClientId, TownId, VehicleId, CollectionDate, 
CollectionOfficeId, ReturnDate, ReturnOfficeId, Bill,  TotalMileage) VALUES

	(17, 2, 52, '2017-08-08', 30, '2017-09-04', 42, 2360.00, 7434),
	(78, 17, 50, '2017-04-22',  10, '2017-05-09', 12, 2326.00,  7326),
	(27, 13, 28, '2017-04-25', 21, '2017-05-09', 34, 597.00,  1880)

------------ 3. Update Database

Update Models
	SEt Class = 'Luxury'
	Where Consumption > 20

------------------------------------------
------------ 4. Querying
------------------------------------------

---------- 1. Select Clients with Invalid Credit Card

Select [Client Name], Email, Bill, Town FROM
		(
			Select c.Id as Id, CONCAT(c.FirstName, ' ', c.LastName) as [Client Name],
			c.Email as Email, o.Bill as Bill, t.Name as Town,
			DENSE_RANK() OVER(Partition BY t.Name Order by o.Bill DESC) as rank
			From Clients as c
			JOIN Orders as o ON o.ClientId = c.Id
			JOIN Towns as t ON t.Id = o.TownId
			Where c.CardValidity <  o.CollectionDate AND o.Bill IS NOT NULL
		) rnk
Where rank = 1 OR rank = 2
Order by Town, Bill, Id

---------------- 2. Find How many offices are situated in each town

Select t.Name as TownName, Count(o.TownId) as [Offices Number] FROM Towns as t
JOIN Offices as o ON o.TownId = t.Id
GROUP BY t.Name
Order by [Offices Number] DESC, t.Name

---------------- 3. Find most popular car models

SELECT m.Manufacturer, m.Model, COUNT(o.VehicleId) as TimesOrdered FROM Vehicles as v
RIGHT Join Models as m ON m.Id = v.ModelId
LEFT JOIN Orders as o ON v.Id = o.VehicleId
GROUP BY m.Manufacturer, m.Model
Order by TimesOrdered DESC, m.Manufacturer DESC, m.Model

----------------- 4. Discover preferred class car for each client

SELECT Names, Class FROM 
	(
			SELECT c.Id, CONCAT(c.FirstName, ' ', c.LastName) as Names,
			m.Class as Class,
			DENSE_RANK() OVER(Partition by c.FirstName, c.LastName ORDER BY COUNT(m.CLass) DESC) as rank
			 FROM Clients as c
			JOIN Orders as o  ON o.ClientId = c.Id
			JOIN Vehicles as v ON v.Id = o.VehicleId
			JOIN Models as m ON m.Id = v.ModelId
			GROUP BY c.Id, c.FirstName, c.LastName, m.Class
	) rnk 
WHERE rank = 1
Order by Names, Class, Id

---------------- 5. Find revenue by age group

SELECT AgeGroup, SUM(Bill) as Revenue, AVG(TotalMileage) as AverageMileage 
FROM
	(
	SELECT (CASE
			WHEN YEAR(c.BirthDate) BETWEEN 1970 AND 1979 THEN '70''s'
			WHEN YEAR(c.BirthDate) BETWEEN 1980 AND 1989 THEN '80''s'
			WHEN YEAR(c.BirthDate) BETWEEN 1990 AND 1999 THEN '90''s'
			ELSE 'Others'
	END) as AgeGroup, o.Bill as Bill, o.TotalMileage as TotalMileage FROM Clients as c
	JOIN Orders as o ON o.ClientId = c.Id 
	) gr
GROUP BY AgeGroup
Order by AgeGroup

----------------- 6. Find manufacturers who produces vehicles with consumption between 5 and 15 

SELECT Manufacturer, Avg(Consumption) as AverageConsumption
	 FROM (
			SELECT TOP 7 m.Manufacturer as Manufacturer,
			 m.Consumption as Consumption, 
			COUNT(o.VehicleId) as count FROM Models as m
			JOIN Vehicles as v ON v.ModelId = m.Id
			JOIN Orders as o ON o.VehicleId = v.Id
			Group BY m.Consumption, m.Manufacturer
			Order by COUNT(o.VehicleId) DESC
		) sth
GROUP BY Manufacturer
HAVING Avg(Consumption) BETWEEN 5 AND 15
Order by Manufacturer

----------------- 7. Discover ratio between male and female customers

WITH CTE AS
	(
		SELECT t.Name as Town, COUNT(c.Id) as TotalCount FROM Towns as t
		LEFT JOIN Orders as o ON o.TownId = t.Id
		LEFT JOIN Clients as c ON c.Id = o.ClientId
		GROUP BY t.Name
	)

SELECT CTE.Town, (MaleCount * 100 / TotalCount) as MalePercentage,
		(FemaleCount * 100 / TotalCount) as FemalePercentage FROM CTE
		LEFT JOIN (SELECT t.Name as Town, c.Gender, COUNT(c.Gender) as MaleCount FROM Towns as t
		LEFT JOIN Orders as o ON o.TownId = t.Id
		LEFT JOIN Clients as c ON c.Id = o.ClientId
		GROUP BY t.Name, c.Gender
		HAVING c.Gender = 'M'
) MaleCount ON MaleCount.Town = CTE.Town
		LEFT JOIN (SELECT t.Name as Town, c.Gender, COUNT(c.Gender) as FemaleCount FROM Towns as t
		LEFT JOIN Orders as o ON o.TownId = t.Id
		LEFT JOIN Clients as c ON c.Id = o.ClientId
		GROUP BY t.Name, c.Gender
		HAVING c.Gender = 'F'
) FemaleCOunt ON FemaleCOunt.Town = CTE.Town

------------------- 8. Find the closest office by TownName, which offers a vehicle with preferred seat count

CREATE FUNCTION udf_CheckForVehicle(@townName NVARCHAR(50), @seatsNumber INT)
RETURNS VARCHAR(100)
	AS
		BEGIN
		DECLARE @TownId INT = (SELECT Id FROM Towns WHERE Name = @townName)
		IF(@TownId IS NULL)
			BEGIN 
				RETURN 'Invalid Town'
			END

	DECLARE @Result VARCHAR(100) = (Select TOP 1 CONCAT(o.Name, ' - ', m.Model) FROM Vehicles as v
		JOIN Offices as o ON v.OfficeId = o.Id
		JOIN Models as m ON m.Id = v.ModelId
		WHERE m.Seats = @seatsNumber AND o.TownId = @TownId
		Order by o.Name)

	IF(@Result IS NULL)
		BEGIN 
			SET @Result = 'NO SUCH VEHICLE FOUND'
		END

	RETURN @Result;
END

--------------------- 9. Move a vehicle to another office

Create Procedure usp_MoveVehicle(@vehicleId INT, @officeId INT)
AS 
	Begin
	Begin Transaction

	If ((Select Id From Vehicles Where Id = @vehicleId) IS NULL)
		Begin 
			RollBack
		End


	If((Select Id From Offices where Id = @officeId) IS NULL)
		Begin
			RollBack
		End

Declare @CurrentParkingPlaces INT = (Select COUNT(Id) FROM Vehicles Where OfficeId = @officeId)

Declare @AvailableParkingPlaces INT = (Select ParkingPlaces From Offices Where Id = @officeId)

If(@CurrentParkingPlaces >= @AvailableParkingPlaces)
	Begin
		Raiserror('Not enough room in this office!', 16, 1)
		ROLLBACK
	End 
ELSE
	Begin
		Update Vehicles
		Set OfficeId = @officeId
		Where Id = @vehicleId
		COMMIT
	End
End

----------------------------- 10.  Update Mileage on placing an order

Create Trigger tr_SetMileage ON Orders for UPDATE
AS
	Update Vehicles
	Set Mileage += (Select TotalMileage FROM inserted)
	Where Id = (Select VehicleId FROM Inserted)

