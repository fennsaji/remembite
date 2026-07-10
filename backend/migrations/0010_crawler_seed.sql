-- Seed 18 Indian cities with approximate bounding boxes (decimal degrees).
-- crawl_grid_points is populated programmatically by CrawlerService on first use.

INSERT INTO crawler_cities (name, lat_min, lat_max, lng_min, lng_max) VALUES
-- Metro cities
('Mumbai',          18.89, 19.27, 72.77, 73.03),
('Delhi NCR',       28.40, 28.88, 76.84, 77.57),
('Bangalore',       12.83, 13.14, 77.46, 77.75),
('Hyderabad',       17.27, 17.60, 78.25, 78.60),
('Chennai',         12.90, 13.23, 80.15, 80.30),
('Kolkata',         22.47, 22.65, 88.29, 88.43),
('Pune',            18.43, 18.64, 73.76, 73.98),
('Ahmedabad',       22.95, 23.13, 72.49, 72.68),
-- Tier-2 cities
('Jaipur',          26.79, 26.98, 75.71, 75.90),
('Lucknow',         26.79, 26.96, 80.88, 81.05),
('Surat',           21.10, 21.27, 72.77, 72.94),
('Indore',          22.63, 22.78, 75.79, 75.93),
('Bhopal',          23.16, 23.32, 77.33, 77.50),
('Chandigarh',      30.65, 30.77, 76.72, 76.86),
('Kochi',            9.91, 10.05, 76.22, 76.36),
('Coimbatore',      10.96, 11.08, 76.92, 77.06),
('Visakhapatnam',   17.64, 17.78, 83.17, 83.30),
('Nagpur',          21.07, 21.22, 79.00, 79.15)
ON CONFLICT (name) DO NOTHING;
