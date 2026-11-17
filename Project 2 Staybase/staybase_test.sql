-- Staybase negative constraint tests
-- Run after Staybase.sql in a clean disposable database.
-- Each invalid operation is wrapped in a handler that prints PASS when rejected.

USE booking_platform;

DELIMITER $$

CREATE PROCEDURE expect_reject(IN label VARCHAR(100), IN sql_text TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT CONCAT('PASS: ', label) AS result;
        RESIGNAL;
    END;
    SET @stmt = sql_text;
    PREPARE stmt FROM @stmt;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('FAIL: ', label, ' was not rejected') AS result;
END$$

DELIMITER ;

-- Fixture data
INSERT INTO users (username, email, name, address, phone_number) VALUES
    ('host_alice','alice@example.com','Alice Host','123 Host St','555-0101'),
    ('guest_bob','bob@example.com','Bob Guest','456 Guest Ave','555-0202'),
    ('guest_carol','carol@example.com','Carol Guest','789 Carol Rd','555-0303');

INSERT INTO user_roles (user_id, role) VALUES
    (1,'host'),(1,'guest'),(2,'guest'),(3,'guest');

INSERT INTO host_bank_accounts (host_id, bank_name, routing_number, account_number) VALUES
    (1,'StayBank','123456789','987654321');

INSERT INTO listings (host_id, title, description, location, nightly_price, cleaning_fee,
    max_guests, cancellation_policy, bookable_start_date, bookable_end_date) VALUES
    (1,'Cozy Cabin','A cozy cabin','Mountain View',100.00,50.00,4,'flexible','2026-01-01','2026-12-31');

INSERT INTO amenities (amenity_id, name, description) VALUES
    (1,'WiFi','Wireless internet'),(2,'Pool','Swimming pool');

INSERT INTO listing_amenities (listing_id, amenity_id) VALUES (1,1);

-- Valid card for guest 2 (user_id 2)
INSERT INTO payment_cards (guest_id, provider_payment_method_id, card_number, ccv,
    cardholder_name, expiration_month, expiration_year, billing_address, last_four) VALUES
    (2,'pm_valid_2','4111111111111111','123','Bob Guest',12,2030,'456 Guest Ave','1111');

-- Expired card for guest 3 (user_id 3)
INSERT INTO payment_cards (guest_id, provider_payment_method_id, card_number, ccv,
    cardholder_name, expiration_month, expiration_year, billing_address, last_four) VALUES
    (3,'pm_expired_3','4222222222222222','456','Carol Guest',1,2020,'789 Carol Rd','2222');

-- TESTS ---------------------------------------------------------------

-- 1. Duplicate username rejected
CALL expect_reject('duplicate username',
    "INSERT INTO users (username,email,name,address,phone_number) VALUES ('host_alice','x@example.com','X','1 St','555')");

-- 2. Listing without host role rejected
CALL expect_reject('listing owner must be host',
    "INSERT INTO listings (host_id,title,description,location,nightly_price,cleaning_fee,max_guests,cancellation_policy,bookable_start_date,bookable_end_date)
     VALUES (2,'Bad Listing','x','x',100,0,1,'flexible','2026-01-01','2026-12-31')");

-- 3. Booking own listing rejected (guest 2 is host 1 via roles, but listing host is 1)
CALL expect_reject('guest books own listing',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (1,1,'2026-06-01','2026-06-03',2,100,50)");

-- 4. Guest with no valid card cannot book (guest 3 has only expired card)
CALL expect_reject('guest needs non-expired card',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (3,1,'2026-06-01','2026-06-03',2,100,50)");

-- 5. Booking outside availability window rejected
CALL expect_reject('booking outside availability',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (2,1,'2025-01-01','2025-01-03',2,100,50)");

-- 6. Guests exceed max rejected
CALL expect_reject('guests exceed max',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (2,1,'2026-06-01','2026-06-03',5,100,50)");

-- 7. Check-out before check-in rejected (CHECK constraint)
CALL expect_reject('check-out before check-in',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (2,1,'2026-06-05','2026-06-03',2,100,50)");

-- 8. Duplicate same listing same check-in rejected (UNIQUE)
INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
    VALUES (2,1,'2026-07-01','2026-07-03',2,100,50);
CALL expect_reject('same listing same check-in duplicate',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (2,1,'2026-07-01','2026-07-05',2,100,50)");

-- 9. Overlapping active booking rejected
CALL expect_reject('overlapping active booking',
    "INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee)
     VALUES (3,1,'2026-07-02','2026-07-04',2,100,50)");

-- 10. Review of non-completed booking rejected
CALL expect_reject('review of non-completed booking',
    "INSERT INTO reviews (booking_id,guest_id,listing_id,rating,comment)
     SELECT 1,2,1,5,'Great' FROM bookings WHERE booking_id=1 AND status='COMPLETED' LIMIT 0");

-- 11. Rating out of range rejected (CHECK)
INSERT INTO bookings (guest_id,listing_id,check_in,check_out,number_of_guests,nightly_price,cleaning_fee,status)
    VALUES (2,1,'2026-08-01','2026-08-03',2,100,50,'COMPLETED');
SET @completed_booking := LAST_INSERT_ID();
CALL expect_reject('rating out of range',
    CONCAT("INSERT INTO reviews (booking_id,guest_id,listing_id,rating,comment) VALUES (",
           @completed_booking,",2,1,6,'x')"));

-- 12. Payment card not owned by booking guest rejected
CALL expect_reject('payment card not owned by guest',
    CONCAT("INSERT INTO payments (booking_id,card_id,amount,status) VALUES (",
           @completed_booking,",3,",(SELECT total_price FROM bookings WHERE booking_id=@completed_booking),",'PAID')"));

-- 13. Payment amount not equal total rejected
CALL expect_reject('payment amount mismatch',
    CONCAT("INSERT INTO payments (booking_id,card_id,amount,status) VALUES (",
           @completed_booking,",2,999999.00,'PAID')"));

-- 14. Release without arrival confirmation rejected
CALL expect_reject('release without arrival confirmation',
    CONCAT("INSERT INTO payments (booking_id,card_id,amount,status) VALUES (",
           @completed_booking,",2,",(SELECT total_price FROM bookings WHERE booking_id=@completed_booking),",'RELEASED')"));

-- Teardown: drop procedure
DROP PROCEDURE IF EXISTS expect_reject;

DELIMITER ;

SELECT 'Negative constraint tests complete' AS result;
