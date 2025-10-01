-- ecomm_schema.sql
-- Complete E-commerce relational schema for MySQL (InnoDB, utf8mb4)
-- Includes: users, addresses, categories, products, product_images,
-- product_categories (M:N), inventory, orders, order_items (M:N with extra attrs),
-- payments (1:1 with orders), reviews, wishlists (M:N), tags (optional).

CREATE DATABASE IF NOT EXISTS ecomm_db
  CHARACTER SET = 'utf8mb4'
  COLLATE = 'utf8mb4_general_ci';
USE ecomm_db;

-- -------------------------------------------------------
-- Users (customers / admins)
-- -------------------------------------------------------
CREATE TABLE users (
    user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(30),
    role ENUM('customer','admin') NOT NULL DEFAULT 'customer',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Addresses (One-to-Many: user -> addresses)
-- -------------------------------------------------------
CREATE TABLE addresses (
    address_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    label VARCHAR(50), -- e.g., 'Home', 'Office'
    street VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(30),
    country VARCHAR(100) NOT NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_addresses_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Categories (hierarchical optional via parent_id)
-- -------------------------------------------------------
CREATE TABLE categories (
    category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(120) NOT NULL UNIQUE,
    description TEXT,
    parent_id INT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id)
        REFERENCES categories(category_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Products
-- -------------------------------------------------------
CREATE TABLE products (
    product_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    weight DECIMAL(10,3) DEFAULT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Product Images (One-to-Many: product -> images)
-- -------------------------------------------------------
CREATE TABLE product_images (
    image_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    url VARCHAR(1000) NOT NULL,
    alt_text VARCHAR(255),
    sort_order INT NOT NULL DEFAULT 0,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT fk_prodimg_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Product <-> Category (Many-to-Many)
-- -------------------------------------------------------
CREATE TABLE product_categories (
    product_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, category_id),
    CONSTRAINT fk_prodcat_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_prodcat_category FOREIGN KEY (category_id)
        REFERENCES categories(category_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Inventory (One-to-One / One-to-Many depending on stock model)
-- Each product has an inventory record; warehouses could be added later.
-- -------------------------------------------------------
CREATE TABLE inventory (
    product_id INT UNSIGNED PRIMARY KEY,
    stock_qty INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    reserved_qty INT NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0),
    last_restocked TIMESTAMP NULL,
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Orders (One-to-Many: user -> orders)
-- -------------------------------------------------------
CREATE TABLE orders (
    order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    order_number VARCHAR(50) NOT NULL UNIQUE, -- e.g., "ORD-20250930-0001"
    order_status ENUM('pending','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending',
    subtotal DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    shipping DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (shipping >= 0),
    tax DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
    total DECIMAL(10,2) NOT NULL CHECK (total >= 0),
    shipping_address_id INT UNSIGNED NULL,
    billing_address_id INT UNSIGNED NULL,
    placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_shipaddr FOREIGN KEY (shipping_address_id)
        REFERENCES addresses(address_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_orders_billaddr FOREIGN KEY (billing_address_id)
        REFERENCES addresses(address_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Order Items (Many-to-Many between orders and products with attributes)
-- composite PK (order_id, product_id)
-- -------------------------------------------------------
CREATE TABLE order_items (
    order_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    discount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_orderitems_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_orderitems_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Payments (1:1 with orders) - allow multiple payments in some systems; here we enforce one payment per order
-- -------------------------------------------------------
CREATE TABLE payments (
    payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL UNIQUE,
    payment_method ENUM('card','mpesa','paypal','bank_transfer') NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    payment_status ENUM('pending','completed','failed','refunded') NOT NULL DEFAULT 'pending',
    provider_transaction_id VARCHAR(255),
    paid_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Reviews (One-to-Many: product -> reviews; user -> reviews)
-- -------------------------------------------------------
CREATE TABLE reviews (
    review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(255),
    body TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reviews_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reviews_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Wishlists (Many-to-Many: users <-> products)
-- -------------------------------------------------------
CREATE TABLE wishlists (
    wishlist_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    name VARCHAR(150) NOT NULL DEFAULT 'My Wishlist',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_wishlist_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE wishlist_items (
    wishlist_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (wishlist_id, product_id),
    CONSTRAINT fk_wishlistitems_wishlist FOREIGN KEY (wishlist_id)
        REFERENCES wishlists(wishlist_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_wishlistitems_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Tags (optional) and Product_Tags (M:N)
-- -------------------------------------------------------
CREATE TABLE tags (
    tag_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(120) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE product_tags (
    product_id INT UNSIGNED NOT NULL,
    tag_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, tag_id),
    CONSTRAINT fk_prodtag_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_prodtag_tag FOREIGN KEY (tag_id)
        REFERENCES tags(tag_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- Some helpful indexes for performance
-- -------------------------------------------------------
CREATE INDEX idx_products_name ON products(name(100));
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orderitems_product ON order_items(product_id);
CREATE INDEX idx_inventory_stock ON inventory(stock_qty);

-- -------------------------------------------------------
-- Example trigger (optional): maintain inventory reserved_qty when order_items inserted
-- NOTE: This is a simple example — in production you'd want robust stock/reservation logic
-- -------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_orderitems_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  -- reduce available stock by quantity (if inventory exists)
  UPDATE inventory
    SET stock_qty = stock_qty - NEW.quantity,
        reserved_qty = reserved_qty + NEW.quantity
    WHERE product_id = NEW.product_id;
END$$
DELIMITER ;

-- -------------------------------------------------------
-- End of schema
-- -------------------------------------------------------
