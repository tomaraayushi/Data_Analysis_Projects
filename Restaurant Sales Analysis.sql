--Create tables and insert the data
CREATE TABLE sales(
	customer_id varchar(1),
	order_date DATE,
	product_id INTEGER
);

INSERT INTO sales
VALUES
	('A', '2021-01-01', 1),
  ('A', '2021-01-01', 2),
  ('A', '2021-01-07', 2),
  ('A', '2021-01-10', 3),
  ('A', '2021-01-11', 3),
  ('A', '2021-01-11', 3),
  ('B', '2021-01-01', 2),
  ('B', '2021-01-02', 2),
  ('B', '2021-01-04', 1),
  ('B', '2021-01-11', 1),
  ('B', '2021-01-16', 3),
  ('B', '2021-02-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-07', 3);
  
SELECT * FROM sales;  

CREATE TABLE menu(
	product_id integer,
	product_name varchar(5),
	price integer
);

INSERT INTO menu
VALUES 
	(1, 'sushi', 10),
  	(2, 'curry', 15),
  	(3, 'ramen', 12);
  
SELECT * FROM menu;
  
CREATE TABLE members(
	customer_id varchar(1),
	join_date DATE
);  
  
INSERT INTO members 
VALUES
	('A', '2021-01-07'),
	('B', '2021-01-09');
  
SELECT * FROM members;  

--Analyze the data
--What is the total amount each customer spent at the restaurant?
SELECT 
	customer_id,
	SUM(price)
FROM sales JOIN menu 
ON sales.product_id = menu.product_id
GROUP BY customer_id
ORDER BY customer_id;

--How many days has each customer visited the restaurant?
SELECT
	customer_id,
	COUNT(DISTINCT order_date) AS num_days
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

--What was the first item from the menu purchased by each customer?
WITH all_purchases AS(
	SELECT
		sales.customer_id,
		sales.order_date,
		menu.product_name,
		DENSE_RANK() OVER(
			PARTITION BY sales.customer_id
			ORDER BY sales.order_date
		) AS rank
	FROM sales INNER JOIN menu
		ON sales.product_id = menu.product_id
)

SELECT
	customer_id,
	product_name
FROM all_purchases
WHERE rank = 1
GROUP BY customer_id, product_name;
	
--What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
	product_name,
	COUNT(product_name) AS order_count
FROM sales INNER JOIN menu 
	ON sales.product_id = menu.product_id
GROUP BY product_name
ORDER BY order_count DESC
LIMIT 1;

--Which item was the most popular for each customer?
WITH all_orders AS(
	SELECT 
		s.customer_id,
		m.product_name,
		COUNT(s.customer_id) AS order_count,
		DENSE_RANK() OVER(
		PARTITION BY s.customer_id
		ORDER BY COUNT(s.customer_id) DESC) AS rank
	FROM sales s INNER JOIN menu m
		ON s.product_id = m.product_id
	GROUP BY customer_id, product_name
)

SELECT
	customer_id,
	product_name,
	order_count
FROM all_orders
WHERE rank = 1;
	
--Which item was purchased first by the customer after they became a member?
WITH members_orders AS(
	SELECT 
		s.customer_id,
		s.product_id,
		ROW_NUMBER() OVER(
		PARTITION BY s.customer_id
		ORDER BY s.order_date ) AS rank
	FROM sales s INNER JOIN members mem
		ON s.customer_id = mem.customer_id
	WHERE
		s.order_date >= mem.join_date
)

SELECT
	members_orders.customer_id,
	m.product_name
FROM members_orders INNER JOIN menu m
	ON members_orders.product_id = m.product_id
WHERE rank = 1
GROUP BY members_orders.customer_id, m.product_name
ORDER BY members_orders.customer_id;

--Which item was purchased just before the customer became a member?
WITH nonmem_orders AS(
	SELECT
		s.customer_id,
		s.product_id,
		ROW_NUMBER() OVER(
		PARTITION BY s.customer_id
		ORDER BY s.order_date DESC) AS rownum
	FROM sales s INNER JOIN members mem
		ON s.customer_id = mem.customer_id
	WHERE 
		s.order_date < mem.join_date
)

SELECT
	n.customer_id,
	m.product_name
FROM nonmem_orders n INNER JOIN menu m
	ON n.product_id = m.product_id
WHERE rownum = 1
ORDER BY n.customer_id;

--What is the total items and amount spent for each member before they became a member?
SELECT
	s.customer_id,
	COUNT(s.product_id) AS items_count,
	SUM(m.price) AS total_amount
FROM members mem INNER JOIN sales s
	ON mem.customer_id = s.customer_id
INNER JOIN menu m
	ON s.product_id = m.product_id
WHERE 
	s.order_date < mem.join_date
GROUP BY
	s.customer_id
ORDER BY 
	s.customer_id;

--If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH product_points AS(
	SELECT
		product_id,
		CASE 
			WHEN product_name = 'sushi' THEN price*20
			ELSE price*10
		END AS pdt_points
	FROM menu
)

SELECT
	s.customer_id,
	SUM(p.pdt_points) AS total_points
FROM sales s INNER JOIN product_points p
	ON s.product_id = p.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

--In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
--not just sushi - how many points do customer A and B have at the end of January?
SELECT
	s.customer_id,
	SUM(CASE 
			WHEN s.order_date >= mem.join_date AND s.order_date <= (mem.join_date +6) 
				THEN m.price*20
			WHEN m.product_name = 'sushi' 
				THEN m.price*20
			ELSE m.price*10 END) AS pdt_points
FROM members mem INNER JOIN sales s
	ON mem.customer_id = s.customer_id AND s.order_date <= '2021-01-31'
INNER JOIN menu m
	ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

--Join all tables
SELECT
	s.customer_id,
	s.order_date,
	m.product_name,
	m.price,
	CASE 
		WHEN mem.join_date > s.order_date THEN 'N'
		WHEN mem.join_date <= s.order_date THEN 'Y'
		ELSE 'N'
		END AS membership
FROM sales s LEFT JOIN members mem
	ON s.customer_id = mem.customer_id
LEFT JOIN menu m
	ON s.product_id = m.product_id
ORDER BY 
	s.customer_id;

--Rank customer products
WITH membership_stat AS(
	SELECT
		s.customer_id,
		s.order_date,
		m.product_name,
		m.price,
		CASE 
			WHEN mem.join_date <= s.order_date THEN 'Y'
			WHEN mem.join_date > s.order_date THEN 'N'
			ELSE 'N'
			END AS membership
	FROM sales s LEFT JOIN members mem
		ON s.customer_id = mem.customer_id
	JOIN menu m
		ON s.product_id = m.product_id
	ORDER BY s.customer_id, s.order_date
)

SELECT
	*,
	CASE
		WHEN ms.membership = 'N' THEN NULL
		ELSE RANK() OVER(
		PARTITION BY ms.customer_id, ms.membership
		ORDER BY ms.customer_id) 
		END AS customer_pdt_rank
FROM membership_stat ms;















  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  