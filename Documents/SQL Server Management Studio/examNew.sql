------------------
------ Create Database

CREATE TABLE Cities(
	Id INT Primary KEY IDENTITY, 
	Name NVARCHAR(20) NOT NULL,
	CountryCode CHAR(2) NOT NULL
)

CREATE TABLE Hotels(
	Id INT PRIMARY KEY IDENTITY,
	Name NVARCHAR(30) NOT NULL,
	CityId INT NOT NULL Foreign Key References Cities(id),
	EmployeeCount INT NOT NULL,-- CHECK (EmployeeCount >= 0),
	BaseRate DECIMAL(15, 2)
)

CREATE TABLE Rooms(
	Id INT PRIMARY KEY IDENTITY,
	Price DECIMAL(15, 2) NOT NULL,
	Type NVARCHAR(20) NOT NULL,
	Beds INT NOT NULL,-- CHECK(Beds >= 0),
	HotelId INT FOREIGN KEY REFERENCES Hotels(Id)
)

CREATE TABLE Trips(
	Id INT PRIMARY KEY IDENTITY,-- (1,1),
	RoomId INT FOREIGN KEY REFERENCES Rooms(Id),
	ReturnDate DATE NOT NULL,
	ArrivalDate DATE NOT NULL,
	BookDate DATE NOT NULL, 
	CancelDate DATE,
	CONSTRAINT cr_CheckMoreDates CHECK(BookDate < ArrivalDate),
	CONSTRAINT cr_CheckDates CHECK(ArrivalDate < ReturnDate)
)


Create Table Accounts(
	Id INT PRIMARY KEY IDENTITY,-- (1,1),
	FirstName NVARCHAR(50) NOT NULL,
	MiddleName NVARCHAR(20),
	LastName NVARCHAR(50) NOT NULL,
	CityId INT FOREIGN KEY REFERENCES Cities(Id),
	BirthDate DATE NOT NULL,
	Email VARCHAR(100) NOT NULL UNIQUE
)


Create Table AccountsTrips(
	AccountId INT FOREIGN KEY REFERENCES Accounts(Id),
	TripId INT FOREIGN KEY REFERENCES Trips(Id),
	Luggage INT NOT NULL CHECK(Luggage >= 0),
	CONSTRAINT PK_PrimaryKEY PRIMARY KEY(AccountId, TripId)
)



------------------
------ Update Prices

UPDATE Rooms
	SET Price = 1.14 * Price
	Where HotelId = 5 OR HotelId = 7 OR HotelId = 9


------------------
--------- Delete Trips 


DELETE FROM AccountsTrips
Where AccountId = 47


------------------
---------- Find all Bulgarian Cities

SELECT Id, Name FROM Cities
	Where CountryCode = 'BG'
	ORDER BY Name

	
------------------
------------ Select accounts born after 1991

SELECT CAST(
	CASE 
		WHEN MiddleName IS NULL THEN CONCAT(FirstName, ' ', LastName)
		ELSE CONCAT(FirstName, ' ', MiddleName, ' ', LastName)
	END AS nvarchar(90)
)AS FullName, 
YEAR(BirthDate) as BirthYear
FROM Accounts
WHERE YEAR(BirthDate) > 1991
Order BY BirthYear DESC, FullName


------------------
------------ Find accounts with emails starting with e

SELECT a.FirstName, a.LastName, 
FORMAT(a.BirthDate, 'MM-dd-yyyy') as BirthDate,
c.Name As Hometown, a.Email FROM Accounts as a
JOIN Cities as c ON c.Id = a.CityId
Where LEFT(Email, 1) = 'e'
Order by Hometown DESC


------------------
-------------- Find First Class Rooms

SELECT r.Id, Price, h.Name as Hotel, c.Name as City FROM Rooms as r
JOIN Hotels as h ON h.Id = r.HotelId
JOIN Cities as c ON c.Id = h.CityId
Where Type = 'First Class'
Order by Price DESC, r.Id


------------------
----- Retrieve people who travel to their home town

SELECT t.Id, h.Name as HotelName, r.Type as RoomType,
	CAST(
		CASE
			WHEN t.CancelDate IS NOT NULL THEN 0
			ELSE (
			ISNULL(h.BaseRate, 0) + r.Price)
		END as DECIMAL(15, 2)
	) as Revenue
FROM Trips as t
JOIN Rooms as r ON r.Id = t.RoomId
JOIN Hotels as h ON h.Id = r.HotelId
Order by RoomType, t.Id
 

------------------
-- Find the longest and the shortest trip of each customer which is not cancelled

SELECT a.Id as AccountId, 
CONCAT(a.FirstName, ' ', a.LastName) as FullName, 
DATEDIFF(DAY, t.ArrivalDate, t.ReturnDate) as LongestTrip,
DENSE_RANK() OVER(ORDER BY DATEDIFF(DAY, t.ArrivalDate, t.ReturnDate) DESC) as rank
FROM Accounts as a
JOIN AccountsTrips as at ON at.AccountId = a.Id
JOIN Trips as t ON t.Id = at.TripId
Order by AccountId

SELECT a.Id as AccountId, 
CONCAT(a.FirstName, ' ', a.LastName) as FullName, 
DATEDIFF(DAY, t.ArrivalDate, t.ReturnDate) as LongestTrip,
DENSE_RANK() OVER(ORDER BY DATEDIFF(DAY, t.ArrivalDate, t.ReturnDate)) as rank
FROM Accounts as a
JOIN AccountsTrips as at ON at.AccountId = a.Id
JOIN Trips as t ON t.Id = at.TripId
Order by AccountId


------------------
------ Retrieve trip count for accounts

 SELECT a.Id, a.Email, c.Name, COUNT(at.TripId) as Trips FROM Accounts as a
 JOIN Cities as c ON c.Id = a.CityId
 JOIN AccountsTrips as at ON at.AccountId = a.Id
 JOIN Trips as t ON t.Id = at.TripId
 JOIN Rooms as r ON r.Id = t.RoomId
 JOIN Hotels as h ON h.Id = r.HotelId
 JOIN Cities as ci ON ci.Id = h.CityId
 Where c.Id = ci.Id 
 GROUP BY a.Id, a.Email, c.Name
 Order by Trips DESC, a.Id

 
------------------
 --- Find Top travellers from each country

SELECT AccountId, Email, CountryCode, Trips 
	FROM
	(
		SELECT a.Id as AccountId, a.Email as Email, c.CountryCode as CountryCode,
		COUNT(at.TripId) as Trips,
		DENSE_RANK() OVER(PARTITION BY c.CountryCode ORDER BY COUNT(at.TripId) DESC
		, a.Id
	) as rank
	FROM Cities as c
	LEFT JOIN HOtels as h ON h.CityId = c.Id
	LEFT JOIN Rooms as r ON r.HotelId = h.Id
	LEFT JOIN Trips as t ON t.RoomId = r.Id
	LEFT JOIN AccountsTrips as at ON at.TripId = t.Id
	LEFT JOIN Accounts as a ON a.Id = at.AccountId
	GROUP BY a.Id, a.Email, c.CountryCode
	) rnk 
Where rank = 1
Order by Trips DESC, AccountId


------------------
---- Calculate Luggage Costs (if luggage count is higher than 5, the fee is equal to luggage count multiplied by 5)

SELECT at.TripId, SUM(at.Luggage) as Luggage,
	CAST(
		CASE 
			WHEN SUM(at.Luggage) > 5 THEN CONCAT('$', SUM(at.Luggage * 5))
			ELSE '$0'
		END as VARCHAR(10)
	) as Fee
FROM AccountsTrips as at
WHERE at.Luggage > 0
GROUP BY at.TripId
Order by Luggage DESC


------------------
---- Retrieve information on arrival and destination points

 SELECT t.Id, CAST(
		CASE 
			WHEN MiddleName IS NULL THEN CONCAT(FirstName, ' ', LastName)
			ELSE CONCAT(FirstName, ' ', MiddleName, ' ', LastName)
		END AS nvarchar(90)
	)AS FullName, 
c.Name as [From],
ci.Name as [To],
CAST(
	CASE 
		WHEN t.CancelDate IS NOT NULL THEN 'Canceled'
		ELSE CONCAT(DATEDIFF(DAY, t.ArrivalDate, t.ReturnDate), ' days')
	END AS VARCHAR
) as Duration
FROM Trips as t
JOIN AccountsTrips as at ON at.TripId = t.Id
JOIN Accounts as a ON a.Id = at.AccountId
LEFT JOIN Cities as c ON c.Id = a.CityId
LEFT JOIN Rooms as r ON r.Id = t.RoomId
LEFT JOIN Hotels as h ON h.Id = r.HotelId
LEFT JOIN Cities as ci ON ci.Id = h.CityId
Order by FullName, Id


------------------
 ----------- Find an available room

 CREATE OR ALTER FUNCTION udf_GetAvailableRoom(@HotelId INT, @Date DATE, @People INT)
RETURNS VARCHAR(100)
AS
	BEGIN

	DECLARE @RoomId INT = (SELECT TOP 1 r.Id FROM Rooms as r
	Where r.Id NOT IN
						(Select r.Id FROM Rooms as r
						JOIN Trips as t ON t.RoomId = r.Id
						Where @Date BETWEEN t.ArrivalDate AND t.ReturnDate AND t.CancelDate IS NULL)
						and r.HotelId = @HotelId
						AND r.Beds >= @People
						Order by r.Price DESC)

	DECLARE @baseRate DECIMAL(15, 2) = (Select BaseRate FROM Hotels Where Id = @HotelId)

	DECLARE @result VARCHAR(100) = 'No rooms available';

	IF(@RoomId IS NOT NULL)
		BEGIN 
			 DECLARE @roomType NVARCHAR(20) = 
				(Select Type from Rooms Where Id = @RoomId)
			 DECLARE @Beds INT = 
				(Select Beds FROM Rooms Where Id = @RoomId)
			 DECLARE @roomPrice DECIMAL(15, 2) = 
				(Select Price FROM Rooms Where Id = @RoomId)
			 DECLARE @totalPrice DECIMAL(15, 2) = (@baseRate + @roomPrice) * @People

			 SET @result = CONCAT('Room ', @roomId, ': ', @roomType, ' (', @beds, ' beds) - $', @totalPrice)

		END

	RETURN @result;
END


------------------
----------- Switch Rooms

CREATE OR ALTER PROCEDURE usp_SwitchRoom(@TripId INT, @TargetRoomId INT)
AS
	BEGIN
		BEGIN TRANSACTION

			DECLARE @hotelID INT = (Select r.HotelId FROM Rooms as r
									JOIN Trips as t ON t.RoomId = r.Id
									Where t.Id = @TripId)

			DECLARE @people INT = (Select COUNT(a.Id) FROM Trips as t
								       JOIN AccountsTrips as at ON at.TripId = t.Id
								       JOIN Accounts as a ON at.AccountId = a.Id
								       Where t.Id = @TripId
								       GROUP BY t.Id)

			UPDATE Trips
				SET RoomId = @TargetRoomId
				Where Id = @TripId

			IF(@hotelID != (Select HotelId FROM Rooms Where Id = @TargetRoomId))
				BEGIN
					RAISERROR('Target room is in another hotel!', 16, 1)
					ROLLBACK
					RETURN
				END

			IF(@people > (Select Beds FROM Rooms Where Id = @TargetRoomId))
				BEGIN
					RAISERROR('Not enough beds in target room!', 16, 2)
					ROLLBACK
					RETURN
				END

		COMMIT
	END

	
------------------
 --------- Cancel a trip
 CREATE TRIGGER tr_CancelTrip ON Trips INSTEAD OF DELETE
AS
	BEGIN
		UPDATE Trips
		SET CancelDate = GETDATE()
		WHERE Id IN 
					(select Id FROM Deleted
					 WHERE CancelDate IS NULL)

	END