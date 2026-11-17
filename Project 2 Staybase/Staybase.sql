-- James McGuigan | 2026-16-11 | Staybase SQL Schema --
CREATE DATABASE IF NOT EXISTS booking_platform;
USE booking_platform;

-- 1: TABLES --

CREATE TABLE users (
    user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE user_roles (
    user_id INT UNSIGNED NOT NULL,
    role ENUM('host','guest') NOT NULL,
    PRIMARY KEY (user_id, role)
) ENGINE=InnoDB;

CREATE TABLE listings (
    listing_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    host_id INT UNSIGNED NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    location VARCHAR(255) NOT NULL,
    nightly_price DECIMAL(10,2) NOT NULL,
    cleaning_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    max_guests INT UNSIGNED NOT NULL,
    cancellation_policy ENUM('flexible','moderate','strict') NOT NULL,
    bookable_start_date DATE NOT NULL,
    bookable_end_date DATE NOT NULL,
    active_booking_count INT UNSIGNED NOT NULL DEFAULT 0,
    review_count INT UNSIGNED NOT NULL DEFAULT 0,
    average_rating DECIMAL(3,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB;

CREATE TABLE amenities (
    amenity_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE listing_amenities (
    listing_id INT UNSIGNED NOT NULL,
    amenity_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (listing_id, amenity_id)
) ENGINE=InnoDB;

CREATE TABLE host_bank_accounts (
    bank_account_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    host_id INT UNSIGNED NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    routing_number VARCHAR(20) NOT NULL,
    account_number VARCHAR(34) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE bookings (
    booking_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    guest_id INT UNSIGNED NOT NULL,
    listing_id INT UNSIGNED NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    number_of_guests INT UNSIGNED NOT NULL,
    nightly_price DECIMAL(10,2) NOT NULL,
    cleaning_fee DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) GENERATED ALWAYS AS
        (DATEDIFF(check_out, check_in) * nightly_price + cleaning_fee) STORED,
    status ENUM('REQUESTED','CONFIRMED','COMPLETED','CANCELLED') NOT NULL DEFAULT 'REQUESTED',
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP NULL,
    guest_arrival_confirmed_at TIMESTAMP NULL
) ENGINE=InnoDB;

CREATE TABLE payment_cards (
    card_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    guest_id INT UNSIGNED NOT NULL,
    provider_payment_method_id VARCHAR(255) NOT NULL,
    card_number VARCHAR(19) NOT NULL,
    ccv CHAR(3) NOT NULL,
    cardholder_name VARCHAR(150) NOT NULL,
    expiration_month TINYINT UNSIGNED NOT NULL,
    expiration_year SMALLINT UNSIGNED NOT NULL,
    billing_address VARCHAR(255) NOT NULL,
    last_four CHAR(4) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE payments (
    payment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_id INT UNSIGNED NOT NULL,
    card_id INT UNSIGNED NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status ENUM('PENDING','PAID','REFUNDED','RELEASED') NOT NULL DEFAULT 'PENDING',
    paid_at TIMESTAMP NULL,
    released_at TIMESTAMP NULL
) ENGINE=InnoDB;

CREATE TABLE reviews (
    review_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_id INT UNSIGNED NOT NULL,
    guest_id INT UNSIGNED NOT NULL,
    listing_id INT UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL,
    comment TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2: CONSTRAINTS --

ALTER TABLE users
    ADD CONSTRAINT uq_username UNIQUE (username),
    ADD CONSTRAINT uq_email UNIQUE (email);

ALTER TABLE user_roles
    ADD CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE RESTRICT;

ALTER TABLE listings
    ADD CONSTRAINT fk_listings_host FOREIGN KEY (host_id)
        REFERENCES users(user_id) ON DELETE RESTRICT,
    ADD CONSTRAINT chk_nightly_price CHECK (nightly_price >= 0),
    ADD CONSTRAINT chk_cleaning_fee CHECK (cleaning_fee >= 0),
    ADD CONSTRAINT chk_max_guests CHECK (max_guests > 0),
    ADD CONSTRAINT chk_booking_window CHECK (bookable_end_date > bookable_start_date),
    ADD CONSTRAINT chk_avg_rating CHECK (average_rating BETWEEN 0 AND 5);

ALTER TABLE amenities
    ADD CONSTRAINT uq_amenity_name UNIQUE (name);

ALTER TABLE listing_amenities
    ADD CONSTRAINT fk_la_listing FOREIGN KEY (listing_id)
        REFERENCES listings(listing_id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_la_amenity FOREIGN KEY (amenity_id)
        REFERENCES amenities(amenity_id) ON DELETE RESTRICT;

ALTER TABLE host_bank_accounts
    ADD CONSTRAINT fk_bank_host FOREIGN KEY (host_id)
        REFERENCES users(user_id) ON DELETE RESTRICT;

ALTER TABLE bookings
    ADD CONSTRAINT fk_bookings_guest FOREIGN KEY (guest_id) REFERENCES users(user_id),
    ADD CONSTRAINT fk_bookings_listing FOREIGN KEY (listing_id) REFERENCES listings(listing_id),
    ADD CONSTRAINT uq_guest_listing_checkin UNIQUE (guest_id, listing_id, check_in),
    ADD CONSTRAINT chk_dates CHECK (check_out > check_in),
    ADD CONSTRAINT chk_guests CHECK (number_of_guests > 0),
    ADD CONSTRAINT chk_price CHECK (nightly_price >= 0),
    ADD CONSTRAINT chk_fee CHECK (cleaning_fee >= 0),
    ADD CONSTRAINT chk_status_order CHECK (
        (status = 'REQUESTED') OR
        (status = 'CONFIRMED' AND confirmed_at IS NOT NULL) OR
        (status = 'COMPLETED') OR
        (status = 'CANCELLED')
    ),
    ADD INDEX idx_overlap (listing_id, status, check_in, check_out),
    ADD INDEX idx_guest (guest_id, status);

ALTER TABLE payment_cards
    ADD CONSTRAINT fk_cards_guest FOREIGN KEY (guest_id) REFERENCES users(user_id),
    ADD CONSTRAINT uq_provider_payment_method_id UNIQUE (provider_payment_method_id),
    ADD CONSTRAINT chk_exp_month CHECK (expiration_month BETWEEN 1 AND 12),
    ADD CONSTRAINT chk_ccv CHECK (ccv REGEXP '^[0-9]{3}$'),
    ADD INDEX idx_card_expiry (guest_id, expiration_year, expiration_month);

ALTER TABLE payments
    ADD CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id),
    ADD CONSTRAINT fk_payments_card FOREIGN KEY (card_id) REFERENCES payment_cards(card_id),
    ADD CONSTRAINT uq_booking_id UNIQUE (booking_id),
    ADD CONSTRAINT chk_amount CHECK (amount >= 0);

ALTER TABLE reviews
    ADD CONSTRAINT fk_reviews_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id),
    ADD CONSTRAINT fk_reviews_guest FOREIGN KEY (guest_id) REFERENCES users(user_id),
    ADD CONSTRAINT fk_reviews_listing FOREIGN KEY (listing_id) REFERENCES listings(listing_id),
    ADD CONSTRAINT uq_review_booking UNIQUE (booking_id),
    ADD CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5),
    ADD INDEX idx_reviews_listing (listing_id);

-- 3: TRIGGERS --

DELIMITER $$

CREATE TRIGGER trg_listing_host_bi BEFORE INSERT ON listings FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = NEW.host_id AND role = 'host') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing owner must have host role';
    END IF;
END$$

CREATE TRIGGER trg_listing_host_bu BEFORE UPDATE ON listings FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = NEW.host_id AND role = 'host') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing owner must have host role';
    END IF;
    IF EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.listing_id = OLD.listing_id AND b.status <> 'CANCELLED'
          AND (b.check_in < NEW.bookable_start_date OR b.check_out > NEW.bookable_end_date
               OR b.number_of_guests > NEW.max_guests)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing change would invalidate an active booking';
    END IF;
END$$

CREATE TRIGGER trg_bank_host_bi BEFORE INSERT ON host_bank_accounts FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = NEW.host_id AND role = 'host') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bank account owner must have host role';
    END IF;
END$$

CREATE TRIGGER trg_bank_host_bu BEFORE UPDATE ON host_bank_accounts FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = NEW.host_id AND role = 'host') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bank account owner must have host role';
    END IF;
END$$

CREATE TRIGGER trg_host_must_have_bank_bi BEFORE INSERT ON listings FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM host_bank_accounts WHERE host_id = NEW.host_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Host must have a bank account before listing';
    END IF;
END$$

CREATE TRIGGER trg_host_must_have_bank_bu BEFORE UPDATE ON listings FOR EACH ROW
BEGIN
    IF NEW.host_id <> OLD.host_id THEN
        IF NOT EXISTS (SELECT 1 FROM host_bank_accounts WHERE host_id = NEW.host_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New host must have a bank account';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_user_role_bd BEFORE DELETE ON user_roles FOR EACH ROW
BEGIN
    IF OLD.role = 'host' AND (
        EXISTS (SELECT 1 FROM listings WHERE host_id = OLD.user_id) OR
        EXISTS (SELECT 1 FROM host_bank_accounts WHERE host_id = OLD.user_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot remove host role while host records exist';
    END IF;
    IF OLD.role = 'guest' AND EXISTS (SELECT 1 FROM bookings WHERE guest_id = OLD.user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot remove guest role while bookings exist';
    END IF;
END$$

CREATE TRIGGER trg_user_role_bu BEFORE UPDATE ON user_roles FOR EACH ROW
BEGIN
    IF OLD.user_id <> NEW.user_id OR OLD.role <> NEW.role THEN
        IF OLD.role = 'host' AND (
            EXISTS (SELECT 1 FROM listings WHERE host_id = OLD.user_id) OR
            EXISTS (SELECT 1 FROM host_bank_accounts WHERE host_id = OLD.user_id)
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot change host role while host records exist';
        END IF;
        IF OLD.role = 'guest' AND EXISTS (SELECT 1 FROM bookings WHERE guest_id = OLD.user_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot change guest role while bookings exist';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_booking_bi BEFORE INSERT ON bookings FOR EACH ROW
BEGIN
    DECLARE v_host INT UNSIGNED DEFAULT NULL;
    DECLARE v_capacity INT UNSIGNED DEFAULT NULL;
    DECLARE v_start DATE DEFAULT NULL;
    DECLARE v_end DATE DEFAULT NULL;
    DECLARE v_cards INT DEFAULT 0;
    DECLARE v_overlap INT DEFAULT 0;

    SELECT host_id, max_guests, bookable_start_date, bookable_end_date
      INTO v_host, v_capacity, v_start, v_end
      FROM listings WHERE listing_id = NEW.listing_id FOR UPDATE;

    IF v_host IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing does not exist';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = NEW.guest_id AND role = 'guest') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking user must have guest role';
    END IF;
    IF NEW.guest_id = v_host THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Users cannot book their own listing';
    END IF;
    IF NEW.check_in < v_start OR NEW.check_out > v_end THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking is outside listing availability';
    END IF;
    IF NEW.number_of_guests > v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest count exceeds listing capacity';
    END IF;
    SELECT COUNT(*) INTO v_cards FROM payment_cards
      WHERE guest_id = NEW.guest_id
        AND (expiration_year > YEAR(CURRENT_DATE)
          OR (expiration_year = YEAR(CURRENT_DATE) AND expiration_month >= MONTH(CURRENT_DATE)));
    IF v_cards = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest needs a non-expired payment card';
    END IF;
    SELECT COUNT(*) INTO v_overlap FROM bookings
      WHERE listing_id = NEW.listing_id
        AND status <> 'CANCELLED'
        AND check_in < NEW.check_out
        AND check_out > NEW.check_in;
    IF v_overlap > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active booking overlaps an existing booking';
    END IF;
END$$

CREATE TRIGGER trg_booking_bu BEFORE UPDATE ON bookings FOR EACH ROW
BEGIN
    DECLARE v_host INT UNSIGNED DEFAULT NULL;
    DECLARE v_capacity INT UNSIGNED DEFAULT NULL;
    DECLARE v_start DATE DEFAULT NULL;
    DECLARE v_end DATE DEFAULT NULL;
    DECLARE v_cards INT DEFAULT 0;
    DECLARE v_overlap INT DEFAULT 0;

    SELECT host_id, max_guests, bookable_start_date, bookable_end_date
      INTO v_host, v_capacity, v_start, v_end
      FROM listings WHERE listing_id = NEW.listing_id FOR UPDATE;

    IF v_host IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing does not exist';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = NEW.guest_id AND role = 'guest') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking user must have guest role';
    END IF;
    IF NEW.guest_id = v_host THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Users cannot book their own listing';
    END IF;
    IF NEW.check_in < v_start OR NEW.check_out > v_end THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking is outside listing availability';
    END IF;
    IF NEW.number_of_guests > v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest count exceeds listing capacity';
    END IF;
    SELECT COUNT(*) INTO v_cards FROM payment_cards
      WHERE guest_id = NEW.guest_id
        AND (expiration_year > YEAR(CURRENT_DATE)
          OR (expiration_year = YEAR(CURRENT_DATE) AND expiration_month >= MONTH(CURRENT_DATE)));
    IF v_cards = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest needs a non-expired payment card';
    END IF;
    SELECT COUNT(*) INTO v_overlap FROM bookings
      WHERE listing_id = NEW.listing_id
        AND booking_id <> OLD.booking_id
        AND status <> 'CANCELLED'
        AND check_in < NEW.check_out
        AND check_out > NEW.check_in;
    IF v_overlap > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active booking overlaps an existing booking';
    END IF;

    IF OLD.status = 'REQUESTED' AND NEW.status = 'CONFIRMED' THEN
        IF NEW.confirmed_at IS NULL THEN SET NEW.confirmed_at = CURRENT_TIMESTAMP; END IF;
    ELSEIF OLD.status = 'CONFIRMED' AND NEW.status IN ('COMPLETED', 'CANCELLED') THEN
    ELSEIF OLD.status = 'REQUESTED' AND NEW.status = 'CANCELLED' THEN
    ELSEIF OLD.status = 'COMPLETED' OR OLD.status = 'CANCELLED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot change a completed or cancelled booking';
    ELSEIF OLD.status = 'CONFIRMED' AND NEW.status = 'CONFIRMED' THEN
    ELSEIF NEW.status = 'REQUESTED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot revert to REQUESTED';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid booking status transition';
    END IF;
END$$

CREATE TRIGGER trg_booking_ai AFTER INSERT ON bookings FOR EACH ROW
BEGIN
    IF NEW.status <> 'CANCELLED' THEN
        UPDATE listings SET active_booking_count = active_booking_count + 1 WHERE listing_id = NEW.listing_id;
    END IF;
END$$

CREATE TRIGGER trg_booking_ad AFTER DELETE ON bookings FOR EACH ROW
BEGIN
    IF OLD.status <> 'CANCELLED' THEN
        UPDATE listings SET active_booking_count = active_booking_count - 1
          WHERE listing_id = OLD.listing_id AND active_booking_count > 0;
    END IF;
END$$

CREATE TRIGGER trg_booking_au AFTER UPDATE ON bookings FOR EACH ROW
BEGIN
    IF OLD.listing_id = NEW.listing_id THEN
        UPDATE listings SET active_booking_count = active_booking_count
          - IF(OLD.status <> 'CANCELLED', 1, 0) + IF(NEW.status <> 'CANCELLED', 1, 0)
          WHERE listing_id = NEW.listing_id AND active_booking_count >= 0;
    ELSE
        IF OLD.status <> 'CANCELLED' THEN
            UPDATE listings SET active_booking_count = active_booking_count - 1
              WHERE listing_id = OLD.listing_id AND active_booking_count > 0;
        END IF;
        IF NEW.status <> 'CANCELLED' THEN
            UPDATE listings SET active_booking_count = active_booking_count + 1 WHERE listing_id = NEW.listing_id;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_review_bi BEFORE INSERT ON reviews FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM bookings WHERE booking_id = NEW.booking_id
        AND guest_id = NEW.guest_id AND listing_id = NEW.listing_id AND status = 'COMPLETED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the guest of a completed booking may review its listing';
    END IF;
END$$

CREATE TRIGGER trg_review_bu BEFORE UPDATE ON reviews FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM bookings WHERE booking_id = NEW.booking_id
        AND guest_id = NEW.guest_id AND listing_id = NEW.listing_id AND status = 'COMPLETED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the guest of a completed booking may review its listing';
    END IF;
END$$

CREATE TRIGGER trg_review_ai AFTER INSERT ON reviews FOR EACH ROW
BEGIN
    UPDATE listings l SET
        l.review_count = (SELECT COUNT(*) FROM reviews r WHERE r.listing_id = NEW.listing_id),
        l.average_rating = COALESCE((SELECT AVG(r.rating) FROM reviews r WHERE r.listing_id = NEW.listing_id), 0.00)
    WHERE l.listing_id = NEW.listing_id;
END$$

CREATE TRIGGER trg_review_ad AFTER DELETE ON reviews FOR EACH ROW
BEGIN
    UPDATE listings l SET
        l.review_count = (SELECT COUNT(*) FROM reviews r WHERE r.listing_id = OLD.listing_id),
        l.average_rating = COALESCE((SELECT AVG(r.rating) FROM reviews r WHERE r.listing_id = OLD.listing_id), 0.00)
    WHERE l.listing_id = OLD.listing_id;
END$$

CREATE TRIGGER trg_review_au AFTER UPDATE ON reviews FOR EACH ROW
BEGIN
    UPDATE listings l SET
        l.review_count = (SELECT COUNT(*) FROM reviews r WHERE r.listing_id = l.listing_id),
        l.average_rating = COALESCE((SELECT AVG(r.rating) FROM reviews r WHERE r.listing_id = l.listing_id), 0.00)
    WHERE l.listing_id IN (OLD.listing_id, NEW.listing_id);
END$$

CREATE TRIGGER trg_payment_bi BEFORE INSERT ON payments FOR EACH ROW
BEGIN
    DECLARE v_guest INT UNSIGNED DEFAULT NULL;
    DECLARE v_total DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_arrival TIMESTAMP DEFAULT NULL;
    DECLARE v_card_guest INT UNSIGNED DEFAULT NULL;
    SELECT guest_id, total_price, guest_arrival_confirmed_at INTO v_guest, v_total, v_arrival
      FROM bookings WHERE booking_id = NEW.booking_id;
    SELECT guest_id INTO v_card_guest FROM payment_cards WHERE card_id = NEW.card_id;
    IF v_guest IS NULL OR v_card_guest IS NULL OR v_guest <> v_card_guest THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment card must belong to booking guest';
    END IF;
    IF NEW.amount <> v_total THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must equal booking total';
    END IF;
    IF NEW.status = 'RELEASED' AND v_arrival IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest arrival confirmation required before release';
    END IF;
    IF NEW.status = 'RELEASED' AND NEW.released_at IS NULL THEN SET NEW.released_at = CURRENT_TIMESTAMP; END IF;
END$$

CREATE TRIGGER trg_payment_bu BEFORE UPDATE ON payments FOR EACH ROW
BEGIN
    DECLARE v_guest INT UNSIGNED DEFAULT NULL;
    DECLARE v_total DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_arrival TIMESTAMP DEFAULT NULL;
    DECLARE v_card_guest INT UNSIGNED DEFAULT NULL;
    SELECT guest_id, total_price, guest_arrival_confirmed_at INTO v_guest, v_total, v_arrival
      FROM bookings WHERE booking_id = NEW.booking_id;
    SELECT guest_id INTO v_card_guest FROM payment_cards WHERE card_id = NEW.card_id;
    IF v_guest IS NULL OR v_card_guest IS NULL OR v_guest <> v_card_guest THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment card must belong to booking guest';
    END IF;
    IF NEW.amount <> v_total THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must equal booking total';
    END IF;
    IF NEW.status = 'RELEASED' AND v_arrival IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest arrival confirmation required before release';
    END IF;
    IF NEW.status = 'RELEASED' AND NEW.released_at IS NULL THEN SET NEW.released_at = CURRENT_TIMESTAMP; END IF;
END$$

CREATE TRIGGER trg_users_bd BEFORE DELETE ON users FOR EACH ROW
BEGIN
    DELETE FROM user_roles WHERE user_id = OLD.user_id;
END$$

CREATE TRIGGER trg_listings_bd BEFORE DELETE ON listings FOR EACH ROW
BEGIN
    DELETE FROM listing_amenities WHERE listing_id = OLD.listing_id;
END$$

CREATE TRIGGER trg_amenities_bd BEFORE DELETE ON amenities FOR EACH ROW
BEGIN
    DELETE FROM listing_amenities WHERE amenity_id = OLD.amenity_id;
END$$

DELIMITER ;
