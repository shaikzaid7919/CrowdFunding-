use crowd_funding;
select * from crowdfunding_category;
select * from crowdfunding_creator;
select * from crowdfunding_location;
select * from projects;
-- Question 1
ALTER TABLE projects ADD COLUMN new_created_at DATETIME;
UPDATE projects SET new_created_at = FROM_UNIXTIME(created_at);
ALTER TABLE projects ADD COLUMN new_deadline DATETIME, ADD COLUMN new_updated_at DATETIME,
ADD COLUMN new_state_changed_at DATETIME,ADD COLUMN new_launched_at DATETIME;
UPDATE projects SET new_deadline = FROM_UNIXTIME(deadline), new_updated_at = FROM_UNIXTIME(updated_at), 
new_state_changed_at = FROM_UNIXTIME(state_changed_at), new_launched_at = FROM_UNIXTIME(launched_at);

-- Question 2
-- Create Calendar Table
CREATE TABLE calendar_table AS
SELECT dt AS calendar_date FROM (SELECT DATE_ADD((SELECT MIN(new_created_at) FROM projects),INTERVAL seq DAY) AS dt
    FROM (SELECT @row := @row + 1 AS seq FROM 
            (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL 
             SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
            (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL 
             SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
            (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL 
             SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3,
            (SELECT @row := -1) t0) AS numbers) AS dates WHERE dt <= (SELECT MAX(new_created_at) FROM projects);
ALTER TABLE calendar_table
ADD COLUMN year INT,
ADD COLUMN month_no INT,
ADD COLUMN month_fullname VARCHAR(20),
ADD COLUMN quarter_name VARCHAR(5),
ADD COLUMN Yearmonth VARCHAR(10),
ADD COLUMN weekday_no INT,
ADD COLUMN weekday_name VARCHAR(20),
ADD COLUMN financial_month VARCHAR(10),
ADD COLUMN financial_quarter VARCHAR(10);
select * from calendar_table;
UPDATE calendar_table
SET year = YEAR(calendar_date), month_no = MONTH(calendar_date), month_fullname = DATE_FORMAT(calendar_date, '%M'),
    quarter_name = CONCAT('Q', QUARTER(calendar_date)),Yearmonth = DATE_FORMAT(calendar_date, '%Y-%b'),
    weekday_no = DAYOFWEEK(calendar_date), weekday_name = DAYNAME(calendar_date),
-- Financial Month (April = 1 … March = 12)
    financial_month = CONCAT('FM', CASE WHEN MONTH(calendar_date) >= 4 THEN MONTH(calendar_date) - 3 ELSE MONTH(calendar_date) + 9
        END),
-- Financial Quarter (FQ-1 … FQ-4)
    financial_quarter = CONCAT('FQ-', CASE
            WHEN MONTH(calendar_date) BETWEEN 4 AND 6 THEN 1 WHEN MONTH(calendar_date) BETWEEN 7 AND 9 THEN 2 
            WHEN MONTH(calendar_date) BETWEEN 10 AND 12 THEN 3 ELSE 4
        END);
        
-- Question 4
 select * from projects;
 ALTER TABLE projects ADD COLUMN goal_usd DECIMAL(18,2);
UPDATE projects SET goal_usd = goal * static_usd_rate;
ALTER TABLE projects ADD COLUMN goal_calculated DECIMAL(10,2);
UPDATE projects SET goal_calculated = goal_usd / 88.67;

-- Question 5
-- Total number of Projects based on Outcome
SELECT state, COUNT(*) AS total_projects FROM crowd_funding.projects GROUP BY state
ORDER BY total_projects DESC;

-- Total number of Projects based on Location
SELECT country, COUNT(*) AS total_projects FROM crowd_funding.projects GROUP BY country
ORDER BY total_projects DESC;

-- Total number of Projects based on Category
SELECT c.name AS category_name,COUNT(p.projectID) AS total_projects FROM crowdfunding_category c LEFT JOIN projects p 
ON p.category_id = c.id GROUP BY c.name ORDER BY total_projects DESC;

-- Total number of Projects based on Year, Quarter and Month
select YEAR(new_created_at) AS year, QUARTER(new_created_at) AS quarter,MONTHNAME(new_created_at) AS month,
COUNT(*) AS total_projects FROM crowd_funding.projects
GROUP BY YEAR(new_created_at), QUARTER(new_created_at), MONTHNAME(new_created_at)
ORDER BY YEAR(new_created_at) DESC, QUARTER(new_created_at), MONTHNAME(new_created_at);

-- Question 6
-- Total No. Of Successful Projects by Amount Raised
SELECT name AS project_name, state, (goal*static_usd_rate) AS amount_raised
FROM crowd_funding.projects WHERE state = 'successful' order by amount_raised desc;

-- Total No. Of Successful Projects by Backers
SELECT name AS project_name, state, backers_count
FROM crowd_funding.projects WHERE state = 'successful'ORDER BY backers_count DESC;

-- Average No. Of days for Successful Projects
SELECT state as project, avg(datediff(new_state_changed_at, new_created_at)) AS avg_project_duration_days
FROM crowd_funding.projects WHERE state = 'successful'ORDER BY avg_project_duration_days DESC;

-- Question 7
-- Top Successful Project Based on No. Of Backers
SELECT projectID,name, backers_count FROM crowd_funding.projects WHERE state = 'successful'
ORDER BY backers_count DESC LIMIT 10;

-- Top Successful Project Based on Amount Raised
SELECT projectID,name,usd_pledged as Amount_raised
FROM projects WHERE state = 'successful' ORDER BY Amount_raised  DESC LIMIT 10;

-- Question 8
-- Percentage of Successful Projects Overall --
SELECT (COUNT(CASE WHEN state = 'successful' THEN 1 END) * 100.0 / COUNT(*)) AS success_percentage
FROM crowd_funding.projects;

-- Percentage of successful projects by category
SELECT c.name AS category_name, COUNT(p.ProjectID) AS total_projects,
    COUNT(CASE WHEN p.state = 'successful' THEN 1 END) AS successful_projects,
    (COUNT(CASE WHEN p.state = 'successful' THEN 1 END) * 100.0 / COUNT(p.ProjectID)) AS success_percentage
FROM crowd_funding.projects p
JOIN crowdfunding_category c ON p.category_id = c.id
GROUP BY c.name ORDER BY success_percentage DESC;

-- Percentage of successful projects by Year, Month and Quarter
SELECT YEAR(new_created_at) AS year, MONTH(new_created_at) AS month_no,
    DATE_FORMAT(new_created_at, '%b') AS month_name, SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END) AS successful_projects,
    COUNT(*) AS total_projects, ROUND(SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END) * 100.0/ COUNT(*), 2) AS success_percentage
FROM crowd_funding.projects WHERE new_created_at IS NOT NULL   -- <-- Important fix
GROUP BY YEAR(new_created_at), MONTH(new_created_at),DATE_FORMAT(new_created_at, '%b') ORDER BY year, month_no;

-- Percentage of Successful Projects by Goal Range --
SELECT 
    CASE 
        WHEN (goal * static_usd_rate) < 5000 THEN 'less than 5000'
        WHEN (goal * static_usd_rate) BETWEEN 5000 AND 20000 THEN '5000 to 20000'
        WHEN (goal * static_usd_rate) BETWEEN 20000 AND 50000 THEN '20000 to 50000'
        WHEN (goal * static_usd_rate) BETWEEN 50000 AND 100000 THEN '50000 to 100000'
        ELSE 'greater than 100000'
    END AS goal_range,
COUNT(ProjectID) AS total_projects,
COUNT(CASE WHEN state = 'successful' THEN 1 END) AS successful_projects,
ROUND((COUNT(CASE WHEN state = 'successful' THEN 1 END) * 100.0) / COUNT(ProjectID),2) AS success_percentage
FROM crowd_funding.projects GROUP BY goal_range ORDER BY success_percentage DESC;






