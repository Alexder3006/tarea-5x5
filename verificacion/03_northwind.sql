-- Conteos por tabla de northwind. Correr conectado a la base 'northwind'.
-- Igual en ambos dialectos.
SELECT 'categories' AS tabla, COUNT(*) AS filas FROM categories
UNION ALL SELECT 'customer_customer_demo' AS tabla, COUNT(*) AS filas FROM customer_customer_demo
UNION ALL SELECT 'customer_demographics' AS tabla, COUNT(*) AS filas FROM customer_demographics
UNION ALL SELECT 'customers' AS tabla, COUNT(*) AS filas FROM customers
UNION ALL SELECT 'employee_territories' AS tabla, COUNT(*) AS filas FROM employee_territories
UNION ALL SELECT 'employees' AS tabla, COUNT(*) AS filas FROM employees
UNION ALL SELECT 'order_details' AS tabla, COUNT(*) AS filas FROM order_details
UNION ALL SELECT 'orders' AS tabla, COUNT(*) AS filas FROM orders
UNION ALL SELECT 'products' AS tabla, COUNT(*) AS filas FROM products
UNION ALL SELECT 'region' AS tabla, COUNT(*) AS filas FROM region
UNION ALL SELECT 'shippers' AS tabla, COUNT(*) AS filas FROM shippers
UNION ALL SELECT 'suppliers' AS tabla, COUNT(*) AS filas FROM suppliers
UNION ALL SELECT 'territories' AS tabla, COUNT(*) AS filas FROM territories
UNION ALL SELECT 'us_states' AS tabla, COUNT(*) AS filas FROM us_states
ORDER BY tabla;
