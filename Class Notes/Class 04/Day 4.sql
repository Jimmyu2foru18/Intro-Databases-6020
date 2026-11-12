--Class 4--
-- ERD to Relational Database Design: Congress Tracking System

Create Database lab_6020;

USE lab_6020;

-- ==========================================
-- 1. Strong Entities (from ERD)
-- ==========================================

-- State entity: stores state information
Create table State(
  name varchar(50) PRIMARY KEY,
  region varchar(50)
);

-- Congress person entity: stores congress person information
Create table CongressPerson(
  name varchar(100) PRIMARY KEY,
  party varchar(50)
);

-- Bill entity: stores bill information
Create table Bill(
  name varchar(200) PRIMARY KEY,
  vote_date date,
  passed_failed varchar(10)
);

-- ==========================================
-- 2. Relationship Tables (from ERD)
-- ==========================================

-- represents: relationship between State and Congress person
-- Attributes from ERD: district, since
Create table Represents(
  state_name varchar(50),
  person_name varchar(100),
  district varchar(50),
  since year,
  PRIMARY KEY (state_name, person_name),
  FOREIGN KEY (state_name) REFERENCES State(name),
  FOREIGN KEY (person_name) REFERENCES CongressPerson(name)
);

-- sponsor: relationship between Congress person and Bill
-- No additional attributes in ERD
Create table Sponsor(
  person_name varchar(100),
  bill_name varchar(200),
  PRIMARY KEY (person_name, bill_name),
  FOREIGN KEY (person_name) REFERENCES CongressPerson(name),
  FOREIGN KEY (bill_name) REFERENCES Bill(name)
);

-- vote: relationship between Congress person and Bill
-- Attributes from ERD: Abstain or Voted, Vote date
Create table Vote(
  person_name varchar(100),
  bill_name varchar(200),
  vote_type varchar(20),
  vote_date date,
  PRIMARY KEY (person_name, bill_name),
  FOREIGN KEY (person_name) REFERENCES CongressPerson(name),
  FOREIGN KEY (bill_name) REFERENCES Bill(name)
);

-- ==========================================
-- 3. Sample Data Inserts
-- ==========================================

-- Insert States
INSERT INTO State VALUES ('California', 'West');
INSERT INTO State VALUES ('Texas', 'South');
INSERT INTO State VALUES ('New York', 'Northeast');
INSERT INTO State VALUES ('Florida', 'South');

-- Insert Congress persons
INSERT INTO CongressPerson VALUES ('Nancy Pelosi', 'Democrat');
INSERT INTO CongressPerson VALUES ('Kevin McCarthy', 'Republican');
INSERT INTO CongressPerson VALUES ('Alexandria Ocasio-Cortez', 'Democrat');
INSERT INTO CongressPerson VALUES ('Ted Cruz', 'Republican');

-- Insert Bills
INSERT INTO Bill VALUES ('H.R. 1 - Infrastructure', '2024-01-15', 'Passed');
INSERT INTO Bill VALUES ('H.R. 2 - Climate Action', '2024-02-20', 'Failed');
INSERT INTO Bill VALUES ('S. 100 - Tax Reform', '2024-03-10', 'Passed');
INSERT INTO Bill VALUES ('H.R. 50 - Education', '2024-04-05', 'Passed');

-- Insert Represents relationships
INSERT INTO Represents VALUES ('California', 'Nancy Pelosi', 'CA-12', 1987);
INSERT INTO Represents VALUES ('California', 'Alexandria Ocasio-Cortez', 'NY-14', 2019);
INSERT INTO Represents VALUES ('Texas', 'Kevin McCarthy', 'CA-20', 2007);
INSERT INTO Represents VALUES ('Texas', 'Ted Cruz', 'TX-1', 2013);

-- Insert Sponsor relationships
INSERT INTO Sponsor VALUES ('Nancy Pelosi', 'H.R. 1 - Infrastructure');
INSERT INTO Sponsor VALUES ('Kevin McCarthy', 'H.R. 2 - Climate Action');
INSERT INTO Sponsor VALUES ('Alexandria Ocasio-Cortez', 'H.R. 2 - Climate Action');
INSERT INTO Sponsor VALUES ('Ted Cruz', 'S. 100 - Tax Reform');

-- Insert Vote relationships
INSERT INTO Vote VALUES ('Nancy Pelosi', 'H.R. 1 - Infrastructure', 'Yea', '2024-01-15');
INSERT INTO Vote VALUES ('Kevin McCarthy', 'H.R. 1 - Infrastructure', 'Yea', '2024-01-15');
INSERT INTO Vote VALUES ('Alexandria Ocasio-Cortez', 'H.R. 1 - Infrastructure', 'Yea', '2024-01-15');
INSERT INTO Vote VALUES ('Ted Cruz', 'H.R. 1 - Infrastructure', 'Nay', '2024-01-15');
INSERT INTO Vote VALUES ('Nancy Pelosi', 'H.R. 2 - Climate Action', 'Yea', '2024-02-20');
INSERT INTO Vote VALUES ('Kevin McCarthy', 'H.R. 2 - Climate Action', 'Nay', '2024-02-20');
INSERT INTO Vote VALUES ('Alexandria Ocasio-Cortez', 'H.R. 2 - Climate Action', 'Yea', '2024-02-20');
INSERT INTO Vote VALUES ('Ted Cruz', 'S. 100 - Tax Reform', 'Yea', '2024-03-10');

-- ==========================================
-- 4. JOIN Queries Across Multiple Tables
-- ==========================================

-- Query 1: Congress persons with their state and region
SELECT 
  cp.name AS congress_person,
  cp.party,
  s.name AS state,
  s.region,
  r.district,
  r.since
FROM CongressPerson cp
JOIN Represents r ON cp.name = r.person_name
JOIN State s ON r.state_name = s.name;

-- Query 2: Voting records with bill details
SELECT 
  cp.name AS congress_person,
  cp.party,
  b.name AS bill,
  b.vote_date AS bill_vote_date,
  v.vote_type,
  v.vote_date AS individual_vote_date
FROM CongressPerson cp
JOIN Vote v ON cp.name = v.person_name
JOIN Bill b ON v.bill_name = b.name
WHERE v.vote_type = 'Yea'
ORDER BY b.vote_date DESC;

-- ==========================================
-- 5. Sponsorship Queries
-- ==========================================

-- Query 3: Bills that passed and their sponsors
SELECT 
  cp.name AS sponsor,
  cp.party,
  b.name AS bill,
  b.passed_failed
FROM CongressPerson cp
JOIN Sponsor sp ON cp.name = sp.person_name
JOIN Bill b ON sp.bill_name = b.name
WHERE b.passed_failed = 'Passed';

-- Query 4: All sponsors for a specific bill
SELECT 
  cp.name AS sponsor,
  cp.party,
  b.name AS bill
FROM CongressPerson cp
JOIN Sponsor sp ON cp.name = sp.person_name
JOIN Bill b ON sp.bill_name = b.name
WHERE b.name = 'H.R. 2 - Climate Action';

-- ==========================================
-- 6. Aggregation Queries
-- ==========================================

-- Query 5: Vote counts by party
SELECT 
  cp.party,
  COUNT(*) AS total_votes,
  SUM(CASE WHEN v.vote_type = 'Yea' THEN 1 ELSE 0 END) AS yea_votes,
  SUM(CASE WHEN v.vote_type = 'Nay' THEN 1 ELSE 0 END) AS nay_votes,
  SUM(CASE WHEN v.vote_type = 'Abstain' THEN 1 ELSE 0 END) AS abstain_votes
FROM CongressPerson cp
JOIN Vote v ON cp.name = v.person_name
GROUP BY cp.party;

-- Query 6: Congress persons per state
SELECT 
  s.name AS state,
  s.region,
  COUNT(*) AS congress_count
FROM State s
JOIN Represents r ON s.name = r.state_name
JOIN CongressPerson cp ON r.person_name = cp.name
GROUP BY s.name, s.region
ORDER BY congress_count DESC;

-- Query 7: Bills with most sponsors
SELECT 
  b.name AS bill,
  COUNT(sp.person_name) AS sponsor_count,
  b.passed_failed
FROM Bill b
JOIN Sponsor sp ON b.name = sp.bill_name
GROUP BY b.name, b.passed_failed
ORDER BY sponsor_count DESC;

-- ==========================================
-- 7. Subquery Examples
-- ==========================================

-- Query 8: Congress persons who voted Yea on all bills they voted on
-- (In this dataset, everyone voted Yea or Nay, but this pattern is useful)
SELECT DISTINCT cp.name, cp.party
FROM CongressPerson cp
JOIN Vote v ON cp.name = v.person_name
WHERE v.vote_type = 'Yea';

-- Query 9: Bills that no one voted against
SELECT b.name, b.passed_failed
FROM Bill b
WHERE b.name NOT IN (
  SELECT bill_name FROM Vote WHERE vote_type = 'Nay'
);

-- Query 10: States with the most sponsors
SELECT 
  s.name AS state,
  COUNT(DISTINCT sp.person_name) AS sponsor_count
FROM State s
JOIN Represents r ON s.name = r.state_name
JOIN Sponsor sp ON r.person_name = sp.person_name
GROUP BY s.name
ORDER BY sponsor_count DESC;

-- ==========================================
-- 8. LEFT JOIN Examples
-- ==========================================

-- Query 11: All congress persons and their votes (including those with no votes)
SELECT 
  cp.name,
  cp.party,
  b.name AS bill,
  v.vote_type
FROM CongressPerson cp
LEFT JOIN Vote v ON cp.name = v.person_name
LEFT JOIN Bill b ON v.bill_name = b.name;

-- Query 12: All bills and their sponsors (including bills with no sponsors)
SELECT 
  b.name AS bill,
  b.passed_failed,
  cp.name AS sponsor
FROM Bill b
LEFT JOIN Sponsor sp ON b.name = sp.bill_name
LEFT JOIN CongressPerson cp ON sp.person_name = cp.name;

-- ==========================================
-- 9. Complex Multi-Table Query
-- ==========================================

-- Query 13: Full details - Congress person, state, bills sponsored, and voting record
SELECT 
  cp.name AS congress_person,
  cp.party,
  s.name AS state,
  s.region,
  r.district,
  r.since,
  b_sponsored.name AS sponsored_bill,
  b_sponsored.passed_failed,
  b_voted.name AS voted_bill,
  v.vote_type,
  v.vote_date AS vote_date
FROM CongressPerson cp
JOIN Represents r ON cp.name = r.person_name
JOIN State s ON r.state_name = s.name
LEFT JOIN Sponsor sp ON cp.name = sp.person_name
LEFT JOIN Bill b_sponsored ON sp.bill_name = b_sponsored.name
LEFT JOIN Vote v ON cp.name = v.person_name
LEFT JOIN Bill b_voted ON v.bill_name = b_voted.name
ORDER BY cp.name, b_sponsored.name, b_voted.name;
