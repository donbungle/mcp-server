-- Sample data for MCP Development Database

-- Insert sample users
INSERT INTO users (username, email, full_name, department, role) VALUES
('john_doe', 'john.doe@company.com', 'John Doe', 'Engineering', 'admin'),
('jane_smith', 'jane.smith@company.com', 'Jane Smith', 'Marketing', 'user'),
('bob_wilson', 'bob.wilson@company.com', 'Bob Wilson', 'Sales', 'user'),
('alice_brown', 'alice.brown@company.com', 'Alice Brown', 'Engineering', 'user'),
('charlie_davis', 'charlie.davis@company.com', 'Charlie Davis', 'Support', 'user'),
('diana_miller', 'diana.miller@company.com', 'Diana Miller', 'Marketing', 'manager'),
('frank_garcia', 'frank.garcia@company.com', 'Frank Garcia', 'Engineering', 'user'),
('grace_lee', 'grace.lee@company.com', 'Grace Lee', 'Sales', 'manager'),
('henry_clark', 'henry.clark@company.com', 'Henry Clark', 'Support', 'user'),
('ivy_thompson', 'ivy.thompson@company.com', 'Ivy Thompson', 'Engineering', 'user');

-- Insert sample products
INSERT INTO products (name, description, category, price, stock_quantity, sku) VALUES
('Laptop Pro 15"', 'High-performance laptop with 16GB RAM and 512GB SSD', 'Electronics', 1299.99, 50, 'LAPTOP-PRO-15'),
('Wireless Mouse', 'Ergonomic wireless mouse with precision tracking', 'Electronics', 29.99, 200, 'MOUSE-WIRELESS-001'),
('Mechanical Keyboard', 'RGB mechanical keyboard with blue switches', 'Electronics', 149.99, 75, 'KEYBOARD-MECH-RGB'),
('Monitor 27"', '4K UHD monitor with USB-C connectivity', 'Electronics', 399.99, 30, 'MONITOR-27-4K'),
('Desk Lamp', 'LED desk lamp with adjustable brightness', 'Office', 59.99, 100, 'LAMP-LED-DESK'),
('Office Chair', 'Ergonomic office chair with lumbar support', 'Office', 299.99, 25, 'CHAIR-OFFICE-ERG'),
('Notebook Set', 'Set of 3 premium notebooks', 'Office', 19.99, 150, 'NOTEBOOK-SET-3'),
('Wireless Headphones', 'Noise-cancelling wireless headphones', 'Electronics', 199.99, 80, 'HEADPHONES-WIRELESS'),
('Phone Stand', 'Adjustable phone and tablet stand', 'Electronics', 24.99, 120, 'PHONE-STAND-ADJ'),
('Coffee Mug', 'Insulated coffee mug with company logo', 'Office', 14.99, 250, 'MUG-COFFEE-LOGO');

-- Insert sample orders (using subqueries to get user IDs)
INSERT INTO orders (user_id, total_amount, status, shipping_address, notes)
SELECT u.id, 1329.98, 'completed', '123 Main St, City, State 12345', 'Rush delivery'
FROM users u WHERE u.username = 'john_doe';

INSERT INTO orders (user_id, total_amount, status, shipping_address, notes)
SELECT u.id, 179.98, 'shipped', '456 Oak Ave, Town, State 67890', NULL
FROM users u WHERE u.username = 'jane_smith';

INSERT INTO orders (user_id, total_amount, status, shipping_address, notes)
SELECT u.id, 449.97, 'pending', '789 Pine Rd, Village, State 11111', 'Gift wrap requested'
FROM users u WHERE u.username = 'bob_wilson';

INSERT INTO orders (user_id, total_amount, status, shipping_address, notes)
SELECT u.id, 59.99, 'completed', '321 Elm St, City, State 22222', NULL
FROM users u WHERE u.username = 'alice_brown';

INSERT INTO orders (user_id, total_amount, status, shipping_address, notes)
SELECT u.id, 344.97, 'shipped', '654 Maple Dr, Town, State 33333', 'Leave at door'
FROM users u WHERE u.username = 'diana_miller';

-- Insert order items
-- Order 1 (john_doe): Laptop + Mouse
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'john_doe' AND p.sku = 'LAPTOP-PRO-15';

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'john_doe' AND p.sku = 'MOUSE-WIRELESS-001';

-- Order 2 (jane_smith): Keyboard + Headphones
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'jane_smith' AND p.sku = 'KEYBOARD-MECH-RGB'
LIMIT 1;

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'jane_smith' AND p.sku = 'MOUSE-WIRELESS-001'
LIMIT 1;

-- Order 3 (bob_wilson): Monitor + Chair
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'bob_wilson' AND p.sku = 'MONITOR-27-4K'
LIMIT 1;

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'bob_wilson' AND p.sku = 'DESK-LAMP'
LIMIT 1;

-- Order 4 (alice_brown): Desk Lamp
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'alice_brown' AND p.sku = 'DESK-LAMP'
LIMIT 1;

-- Order 5 (diana_miller): Office Chair + Notebook Set + Coffee Mug
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 1, p.price, p.price
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'diana_miller' AND p.sku = 'CHAIR-OFFICE-ERG'
LIMIT 1;

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 2, p.price, p.price * 2
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'diana_miller' AND p.sku = 'NOTEBOOK-SET-3'
LIMIT 1;

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT o.id, p.id, 3, p.price, p.price * 3
FROM orders o, products p, users u
WHERE o.user_id = u.id AND u.username = 'diana_miller' AND p.sku = 'MUG-COFFEE-LOGO'
LIMIT 1;

-- Insert sample analytics events
INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, user_agent)
SELECT 
    u.id,
    'page_view',
    '{"page": "/products", "category": "electronics", "duration": 45}',
    '192.168.1.100',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
FROM users u WHERE u.username = 'john_doe';

INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, user_agent)
SELECT 
    u.id,
    'product_search',
    '{"query": "laptop", "results_count": 12, "filters": ["price_range"]}',
    '192.168.1.101',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
FROM users u WHERE u.username = 'jane_smith';

INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, user_agent)
SELECT 
    u.id,
    'add_to_cart',
    '{"product_id": "' || p.id || '", "quantity": 1, "price": ' || p.price || '}',
    '192.168.1.102',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15'
FROM users u, products p 
WHERE u.username = 'bob_wilson' AND p.sku = 'MONITOR-27-4K';

INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, user_agent)
SELECT 
    u.id,
    'checkout_start',
    '{"cart_value": 299.99, "items_count": 1}',
    '192.168.1.103',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
FROM users u WHERE u.username = 'alice_brown';

INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, user_agent)
SELECT 
    u.id,
    'purchase_complete',
    '{"order_id": "' || o.id || '", "total": ' || o.total_amount || ', "payment_method": "credit_card"}',
    '192.168.1.104',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
FROM users u, orders o 
WHERE u.username = 'diana_miller' AND o.user_id = u.id;

-- Insert app configuration
INSERT INTO app_config (key, value, description) VALUES
('site_name', 'MCP Development Store', 'Name of the application'),
('maintenance_mode', 'false', 'Whether the site is in maintenance mode'),
('max_upload_size', '10485760', 'Maximum file upload size in bytes'),
('session_timeout', '3600', 'Session timeout in seconds'),
('email_notifications', 'true', 'Whether email notifications are enabled'),
('analytics_enabled', 'true', 'Whether analytics tracking is enabled'),
('cache_duration', '300', 'Default cache duration in seconds'),
('api_rate_limit', '100', 'API requests per minute per user'),
('debug_mode', 'true', 'Whether debug mode is enabled'),
('database_version', '1.0.0', 'Current database schema version');

-- Create additional sample data with more recent timestamps
INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, created_at)
SELECT 
    u.id,
    'login',
    '{"method": "email", "device": "desktop"}',
    '192.168.1.' || (100 + (random() * 50)::int),
    NOW() - (random() * INTERVAL '7 days')
FROM users u
ORDER BY RANDOM()
LIMIT 20;

INSERT INTO analytics_events (user_id, event_type, event_data, ip_address, created_at)
SELECT 
    u.id,
    'logout',
    '{"session_duration": ' || (300 + random() * 3600)::int || '}',
    '192.168.1.' || (100 + (random() * 50)::int),
    NOW() - (random() * INTERVAL '7 days')
FROM users u
ORDER BY RANDOM()
LIMIT 15;

-- Update some product stock quantities randomly
UPDATE products SET stock_quantity = stock_quantity - (random() * 10)::int WHERE category = 'Electronics';
UPDATE products SET stock_quantity = stock_quantity - (random() * 5)::int WHERE category = 'Office';