-- Blood Donation and Emergency Matching System: DBMS Mini Project
-- Run this whole file in MySQL Workbench (lightning bolt button).
-- It creates a NEW database called blood_db, so your playlist project is untouched.

DROP DATABASE IF EXISTS blood_db;   -- lets you re-run the file from scratch
CREATE DATABASE blood_db;
USE blood_db;

-- ---------- TABLES ----------

CREATE TABLE blood_groups (
    blood_group VARCHAR(3) PRIMARY KEY
);

-- Which donor group can give to which recipient group
CREATE TABLE blood_compatibility (
    donor_group      VARCHAR(3),
    recipient_group  VARCHAR(3),
    PRIMARY KEY (donor_group, recipient_group),
    FOREIGN KEY (donor_group)     REFERENCES blood_groups(blood_group),
    FOREIGN KEY (recipient_group) REFERENCES blood_groups(blood_group)
);

CREATE TABLE donors (
    donor_id            INT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    gender              ENUM('M', 'F', 'Other') NOT NULL,
    dob                 DATE NOT NULL,
    blood_group         VARCHAR(3) NOT NULL,
    phone               VARCHAR(15) NOT NULL,
    city                VARCHAR(50) NOT NULL,
    weight_kg           DECIMAL(4,1) CHECK (weight_kg > 0),
    last_donation_date  DATE NULL,
    FOREIGN KEY (blood_group) REFERENCES blood_groups(blood_group)
);

CREATE TABLE hospitals (
    hospital_id  INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    city         VARCHAR(50) NOT NULL,
    phone        VARCHAR(15)
);

CREATE TABLE blood_requests (
    request_id      INT AUTO_INCREMENT PRIMARY KEY,
    hospital_id     INT NOT NULL,
    patient_name    VARCHAR(100) NOT NULL,
    blood_group     VARCHAR(3) NOT NULL,
    units_needed    INT NOT NULL CHECK (units_needed > 0),
    urgency         ENUM('Critical', 'Urgent', 'Normal') DEFAULT 'Normal',
    request_date    DATE NOT NULL,
    status          ENUM('Open', 'Fulfilled', 'Cancelled') DEFAULT 'Open',
    FOREIGN KEY (hospital_id) REFERENCES hospitals(hospital_id),
    FOREIGN KEY (blood_group) REFERENCES blood_groups(blood_group)
);

CREATE TABLE donations (
    donation_id    INT AUTO_INCREMENT PRIMARY KEY,
    donor_id       INT NOT NULL,
    hospital_id    INT NOT NULL,
    request_id     INT NULL,   -- NULL means a regular donation, not for a specific request
    donation_date  DATE NOT NULL,
    units          INT NOT NULL DEFAULT 1 CHECK (units BETWEEN 1 AND 2),
    FOREIGN KEY (donor_id)    REFERENCES donors(donor_id),
    FOREIGN KEY (hospital_id) REFERENCES hospitals(hospital_id),
    FOREIGN KEY (request_id)  REFERENCES blood_requests(request_id)
);

-- Units of each blood group currently held by each hospital
CREATE TABLE blood_stock (
    hospital_id      INT,
    blood_group      VARCHAR(3),
    units_available  INT NOT NULL DEFAULT 0 CHECK (units_available >= 0),
    PRIMARY KEY (hospital_id, blood_group),
    FOREIGN KEY (hospital_id) REFERENCES hospitals(hospital_id),
    FOREIGN KEY (blood_group) REFERENCES blood_groups(blood_group)
);

-- ---------- SAMPLE DATA ----------

INSERT INTO blood_groups VALUES ('A+'), ('A-'), ('B+'), ('B-'), ('AB+'), ('AB-'), ('O+'), ('O-');

-- Compatibility: (donor_group, recipient_group)
INSERT INTO blood_compatibility VALUES
('O-','O-'),('O-','O+'),('O-','A-'),('O-','A+'),('O-','B-'),('O-','B+'),('O-','AB-'),('O-','AB+'),
('O+','O+'),('O+','A+'),('O+','B+'),('O+','AB+'),
('A-','A-'),('A-','A+'),('A-','AB-'),('A-','AB+'),
('A+','A+'),('A+','AB+'),
('B-','B-'),('B-','B+'),('B-','AB-'),('B-','AB+'),
('B+','B+'),('B+','AB+'),
('AB-','AB-'),('AB-','AB+'),
('AB+','AB+');

INSERT INTO hospitals (name, city, phone) VALUES
('City Care Hospital',      'Ludhiana',   '0161-111111'),
('Sunrise Medical Centre',  'Chandigarh', '0172-222222'),
('Lifeline Hospital',       'Delhi',      '011-33333333'),
('Apex Hospital',           'Amritsar',   '0183-444444');

INSERT INTO donors (name, gender, dob, blood_group, phone, city, weight_kg, last_donation_date) VALUES
('Rohan Sharma',   'M', '1999-04-12', 'O+',  '9876500001', 'Ludhiana',   68.5, DATE_SUB(CURDATE(), INTERVAL 20 DAY)),
('Priya Verma',    'F', '2000-08-23', 'A+',  '9876500002', 'Ludhiana',   55.0, NULL),
('Aman Gill',      'M', '1997-01-30', 'B+',  '9876500003', 'Chandigarh', 72.0, DATE_SUB(CURDATE(), INTERVAL 120 DAY)),
('Simran Kaur',    'F', '2001-11-05', 'O-',  '9876500004', 'Ludhiana',   58.0, DATE_SUB(CURDATE(), INTERVAL 200 DAY)),
('Karan Mehta',    'M', '1995-06-17', 'AB+', '9876500005', 'Delhi',      80.0, NULL),
('Neha Singh',     'F', '1998-03-09', 'A-',  '9876500006', 'Chandigarh', 52.0, DATE_SUB(CURDATE(), INTERVAL 95 DAY)),
('Vikram Joshi',   'M', '1993-12-21', 'B-',  '9876500007', 'Delhi',      75.0, DATE_SUB(CURDATE(), INTERVAL 150 DAY)),
('Anjali Rao',     'F', '2002-02-14', 'O+',  '9876500008', 'Ludhiana',   49.0, NULL),
('Harpreet Singh', 'M', '1994-09-02', 'A+',  '9876500009', 'Amritsar',   70.0, DATE_SUB(CURDATE(), INTERVAL 60 DAY)),
('Manish Kumar',   'M', '1996-07-28', 'O+',  '9876500010', 'Ludhiana',   66.0, DATE_SUB(CURDATE(), INTERVAL 100 DAY));

INSERT INTO blood_requests (hospital_id, patient_name, blood_group, units_needed, urgency, request_date, status) VALUES
(1, 'Mohan Lal',   'A+',  2, 'Critical', CURDATE(),                        'Open'),
(2, 'Sunita Devi', 'O-',  1, 'Urgent',   DATE_SUB(CURDATE(), INTERVAL 2 DAY), 'Open'),
(3, 'Ravi Kumar',  'AB+', 3, 'Normal',   DATE_SUB(CURDATE(), INTERVAL 5 DAY), 'Fulfilled'),
(1, 'Geeta Rani',  'O+',  2, 'Urgent',   DATE_SUB(CURDATE(), INTERVAL 1 DAY), 'Open');

-- Past donations (inserted before the triggers exist, so they just load as history)
INSERT INTO donations (donor_id, hospital_id, request_id, donation_date, units) VALUES
(1,  1, NULL, DATE_SUB(CURDATE(), INTERVAL 20 DAY),  1),
(3,  2, NULL, DATE_SUB(CURDATE(), INTERVAL 120 DAY), 1),
(4,  1, NULL, DATE_SUB(CURDATE(), INTERVAL 200 DAY), 1),
(9,  4, NULL, DATE_SUB(CURDATE(), INTERVAL 60 DAY),  1),
(10, 1, NULL, DATE_SUB(CURDATE(), INTERVAL 100 DAY), 1);

INSERT INTO blood_stock (hospital_id, blood_group, units_available) VALUES
(1, 'O+', 5), (1, 'A+', 3), (1, 'B+', 1),
(2, 'B+', 2), (2, 'O-', 1),
(3, 'AB+', 4),
(4, 'A+', 2);

-- ---------- VIEWS ----------

-- Total stock of each blood group across all hospitals
CREATE VIEW v_stock_summary AS
SELECT blood_group, SUM(units_available) AS total_units
FROM blood_stock
GROUP BY blood_group;

-- Open requests, most urgent first
CREATE VIEW v_open_requests AS
SELECT r.request_id, r.patient_name, r.blood_group, r.units_needed,
       r.urgency, r.request_date, h.name AS hospital, h.city
FROM blood_requests r
JOIN hospitals h ON r.hospital_id = h.hospital_id
WHERE r.status = 'Open'
ORDER BY FIELD(r.urgency, 'Critical', 'Urgent', 'Normal'), r.request_date;

-- ---------- STORED PROCEDURE ----------
-- Given a request, find donors who are compatible, in the same city,
-- weigh at least 50 kg, and have not donated in the last 90 days.
-- Exact blood group matches are listed first.

DELIMITER $$

CREATE PROCEDURE find_eligible_donors(IN p_request_id INT)
BEGIN
    SELECT d.donor_id, d.name, d.phone, d.blood_group, d.city, d.last_donation_date
    FROM blood_requests r
    JOIN hospitals h            ON r.hospital_id = h.hospital_id
    JOIN blood_compatibility bc ON bc.recipient_group = r.blood_group
    JOIN donors d               ON d.blood_group = bc.donor_group
    WHERE r.request_id = p_request_id
      AND d.city = h.city
      AND d.weight_kg >= 50
      AND (d.last_donation_date IS NULL
           OR d.last_donation_date <= DATE_SUB(CURDATE(), INTERVAL 90 DAY))
    ORDER BY (d.blood_group = r.blood_group) DESC, d.last_donation_date;
END$$

-- ---------- TRIGGERS ----------

-- Trigger 1: block donations from donors who are not eligible
CREATE TRIGGER trg_check_donor_eligibility
BEFORE INSERT ON donations
FOR EACH ROW
BEGIN
    DECLARE v_last DATE;
    DECLARE v_weight DECIMAL(4,1);

    SELECT last_donation_date, weight_kg
    INTO v_last, v_weight
    FROM donors
    WHERE donor_id = NEW.donor_id;

    IF v_weight < 50 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Donor weighs less than 50 kg. Not eligible to donate.';
    END IF;

    IF v_last IS NOT NULL AND DATEDIFF(NEW.donation_date, v_last) < 90 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Donor donated less than 90 days ago. Not eligible yet.';
    END IF;
END$$

-- Trigger 2: after a donation, update the donor's last date and the hospital stock
CREATE TRIGGER trg_update_after_donation
AFTER INSERT ON donations
FOR EACH ROW
BEGIN
    UPDATE donors
    SET last_donation_date = NEW.donation_date
    WHERE donor_id = NEW.donor_id;

    INSERT INTO blood_stock (hospital_id, blood_group, units_available)
    SELECT NEW.hospital_id, d.blood_group, NEW.units
    FROM donors d
    WHERE d.donor_id = NEW.donor_id
    ON DUPLICATE KEY UPDATE units_available = units_available + NEW.units;
END$$

DELIMITER ;

-- ---------- TRY THESE (run them one at a time) ----------

-- 1. Who can donate for request 1 (A+ patient in Ludhiana)?
CALL find_eligible_donors(1);

-- 2. Stock summary and open requests (views)
SELECT * FROM v_stock_summary;
SELECT * FROM v_open_requests;

-- 3. Number of donors in each blood group (aggregate)
SELECT blood_group, COUNT(*) AS total_donors
FROM donors
GROUP BY blood_group
ORDER BY total_donors DESC;

-- 4. Donors who have never donated (subquery)
SELECT name, blood_group, city
FROM donors
WHERE donor_id NOT IN (SELECT donor_id FROM donations);

-- 5. Total units donated per hospital (join + aggregate)
SELECT h.name, SUM(dn.units) AS units_received
FROM hospitals h
JOIN donations dn ON h.hospital_id = dn.hospital_id
GROUP BY h.hospital_id, h.name;

-- 6. Test the triggers:
-- This should FAIL (Rohan donated 20 days ago):
-- INSERT INTO donations (donor_id, hospital_id, donation_date, units) VALUES (1, 1, CURDATE(), 1);
-- This should WORK and increase O- stock at hospital 1 (Simran, 200 days ago):
-- INSERT INTO donations (donor_id, hospital_id, donation_date, units) VALUES (4, 1, CURDATE(), 1);
-- SELECT * FROM blood_stock WHERE hospital_id = 1;