
-- ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ *~ ~ * ~ * ~ *  ~ BOOK EXPLORATORY DATA ANALYSIS ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * 

CREATE TABLE book_stats AS (
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name),
     summary_stats AS
                          (SELECT
                             ROUND(AVG(ban_count), 2) AS mean,
                             PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ban_count) AS median,
                             MIN(ban_count) AS minimum,
                             MAX(ban_count) AS maximum,
                             MAX(ban_count) - MIN(ban_count) AS range,
                             ROUND(STDDEV(ban_count), 2) AS stddev,
                             ROUND(VARIANCE(ban_count), 2) AS variance,
                             PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ban_count) AS Q1,
                             PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ban_count) AS Q3
                           FROM bans_by_district),
     row_summary_stats AS
                          (SELECT 1 AS sno, 'mean' AS statistic, mean AS value FROM summary_stats
                           UNION
                           SELECT 2, 'median', median FROM summary_stats
                           UNION
                           SELECT 3, 'minimum', minimum FROM summary_stats
                           UNION
                           SELECT 4, 'maximum', maximum FROM summary_stats
                           UNION
                           SELECT 5, 'range', range FROM summary_stats
                           UNION
                           SELECT 6, 'standard deviation', stddev FROM summary_stats
                           UNION
                           SELECT 7, 'variance', variance FROM summary_stats
                           UNION
                           SELECT 9, 'Q1', Q1 FROM summary_stats
                           UNION
                           SELECT 10, 'Q3', Q3 FROM summary_stats
                           UNION
                           SELECT 11, 'IQR', (Q3 - Q1) FROM summary_stats
                           UNION
                           SELECT 12, 'skewness', ROUND(3 * (mean - median)::NUMERIC / stddev, 2) AS skewness FROM summary_stats)
SELECT *
FROM row_summary_stats
ORDER BY sno);

SELECT *
FROM book_stats;

-- ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ *~ ~ * ~ * ~ *  ~ ELECTION RESULT TABLES ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ *

---- Query that shows state, county, party, vote percent for election years 2008-2020
---- Changes format of state, county, and party from all capitals to first letter capitalized the rest lower case
---- Changes format of votes and total votes from integer to numeric to calculate the vote percent
---- Filters for the two major political parties (Democrat and Republican) for election years 2008-2020
---- Uses RANK to show vote percent from highest (1) to lowest (4) according to state, county, and party

CREATE TABLE election_rank_table AS (
SELECT
  INITCAP(state_name) AS state,
  INITCAP(county_name) AS county,
  INITCAP(party) AS party,
  year,
  ROUND((NULLIF(CAST(SUM(votes) AS numeric),0) / NULLIF(CAST(total_votes AS numeric),0) * 100),2) AS percent,
  RANK() OVER (PARTITION BY
                 state_name,
                 county_name,
                 party
               ORDER BY
                 ROUND((NULLIF(CAST(SUM(votes) AS numeric),0) / NULLIF(CAST(total_votes AS numeric),0) * 100),2) DESC)
               AS election_rank
FROM vote_data
WHERE
  year IN (2008, 2012, 2016, 2020)
  AND INITCAP(party) IN ('Democrat', 'Republican')
GROUP BY
  state_name,
  county_name,
  party,
  year,
  total_votes
ORDER BY
  state_name,
  county_name,
  party,
  year
)

SELECT *
FROM election_rank_table;

-- Troubleshooting: Test query by filtering for state as 'Delaware' because this state has fewest counties to check ranks
SELECT *
FROM election_rank_table
WHERE state = 'Delaware';

---- Query that shows year, state, county, party, current vote percent, and previous vote percent for election years 2012-2020
---- Changes format of state, county, and party from all capitals to first letter capitalized the rest lower case
---- Changes format of votes and total votes from integer to numeric to calculate the vote percent
---- Uses LAG to create a column to compare current year vote (current_vote) to previous year (previous_vote)
CREATE TABLE previous_current_table AS (
  WITH updated_table AS (WITH basic_table AS (
                           SELECT
                             year,
                             INITCAP(state_name) AS state_name,
                             INITCAP(county_name) AS county_name,
                             INITCAP(party) AS party,
                             votes,
                             total_votes,
                             ROUND(((NULLIF(CAST(votes AS numeric), 0) / CAST(total_votes AS numeric)) * 100), 2) AS vote_percent
                           FROM vote_data)
    SELECT
      year,
      state_name,
      county_name,
      party,
      vote_percent AS current_vote,
      LAG (vote_percent, 1) OVER (PARTITION BY county_name, state_name, party ORDER BY year) AS previous_vote
    FROM basic_table
    WHERE year IN (2012, 2016, 2020)
    ORDER BY
      state_name,
      county_name,
      year,
      party)
SELECT *
FROM updated_table
);

SELECT *
FROM previous_current_table;

-- Troubleshooting: Test query by filtering for state as 'Delaware' because this state has fewest counties to check current, previous
SELECT *
FROM previous_current_table
WHERE state_name = 'Delaware';

-- ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ *

---- Query that shows state, county, district name, book ban count, party, year, vote percent for election years 2012-2020
---- 'book_bans' is primary table and filters entries from 'vote_table'
---- The LEFT JOIN allows addition of district name and book bans to the voting data
---- Series of small tables for election years 2012, 2016, 2020

-- Election year 2012
CREATE TABLE district_vote_bans_12 AS (
SELECT
  b.state,
  b.county,
  b.district_name,
  COUNT(b.title) AS bans,
  v.party,
  v.year,
  v.percent
FROM book_bans AS b
LEFT JOIN vote_table AS v
ON b.state = v.state AND b.county = v.county
WHERE b.county IN (SELECT county
                   FROM vote_table)
  AND b.county IS NOT null
  AND v.percent IS NOT null
  AND v.year = 2012
GROUP BY
  b.state,
  b.county,
  b.district_name,
  v.party,
  v.year,
  v.percent
ORDER BY
  b.state,
  b.county,
  b.district_name,
  v.party,
  v.year
)

-- Election year 2016
CREATE TABLE district_vote_bans_16 AS (
SELECT
  b.state,
  b.county,
  b.district_name,
  COUNT(b.title) AS bans,
  v.party,
  v.year,
  v.percent
FROM book_bans AS b
LEFT JOIN vote_table AS v
ON b.state = v.state AND b.county = v.county
WHERE b.county IN (SELECT county
                   FROM vote_table)
  AND b.county IS NOT null
  AND v.percent IS NOT null
  AND v.year = 2016
GROUP BY
  b.state,
  b.county,
  b.district_name,
  v.party,
  v.year,
  v.percent
ORDER BY
  b.state,
  b.county,
  b.district_name,
  v.party,
  v.year
)

-- Election year 2020
CREATE TABLE district_vote_bans_20 AS (
SELECT
  b.state,
  b.county,
  b.district_name,
  COUNT(b.title) AS bans,
  v.party,
  v.year,
  v.percent
FROM book_bans AS b
LEFT JOIN vote_table AS v
ON b.state = v.state AND b.county = v.county
WHERE b.county IN (SELECT county
                   FROM vote_table)
  AND b.county IS NOT null
  AND v.percent IS NOT null
  AND v.year = 2020
GROUP BY
  b.state,
  b.county,
  b.district_name,
  v.party,
  v.year,
  v.percent
ORDER BY
  b.state,
  b.county,
  b.district_name,
  v.party,
  v.year
)

-- Republican and Democrat counties by vote percent in election years 2012, 2016, 2020
-- Uses UNION ALL to consolidate tables from above into a single csv that can be exported into Excel
CREATE TABLE rep_12_20_elections AS (
(SELECT
   r_12.state,
   r_12.county,
   r_12.year,
   r_12.percent,
   r_12.party,
   COUNT(b.title) AS bans
FROM district_vote_bans_12 AS r_12
JOIN book_bans AS b
ON r_12.state = b.state AND r_12.county = b.county
GROUP BY  
   r_12.state,
   r_12.county,
   r_12.year,
   r_12.percent,
   r_12.party
ORDER BY percent DESC)
UNION ALL
(SELECT
   r_16.state,
   r_16.county,
   r_16.year,
   r_16.percent,
   r_16.party,
   COUNT(b.title) AS bans
FROM district_vote_bans_16 AS r_16
JOIN book_bans AS b
ON r_16.state = b.state AND r_16.county = b.county
GROUP BY  
   r_16.state,
   r_16.county,
   r_16.year,
   r_16.percent,
   r_16.party
ORDER BY percent DESC)
UNION ALL
(SELECT
   r_20.state,
   r_20.county,
   r_20.year,
   r_20.percent,
   r_20.party,
   COUNT(b.title) AS bans
FROM district_vote_bans_20 AS r_20
JOIN book_bans AS b
ON r_20.state = b.state AND r_20.county = b.county
GROUP BY  
   r_20.state,
   r_20.county,
   r_20.year,
   r_20.percent,
   r_20.party
ORDER BY percent DESC)
)

SELECT
  state,
  county,
  year,
  percent,
  party,
  bans
FROM rep_12_20_elections
WHERE party = 'Republican'
ORDER BY
  state,
  county,
  year,
  percent DESC;

CREATE TABLE dem_12_20_elections AS (
(SELECT
   d_12.state,
   d_12.county,
   d_12.year,
   d_12.percent,
   d_12.party,
   COUNT(b.title) AS bans
FROM district_vote_bans_12 AS d_12
JOIN book_bans AS b
ON d_12.state = b.state AND d_12.county = b.county
WHERE d_12.party = 'Democrat'
GROUP BY  
   d_12.state,
   d_12.county,
   d_12.year,
   d_12.percent,
   d_12.party
ORDER BY percent DESC)
UNION ALL
(SELECT
   d_16.state,
   d_16.county,
   d_16.year,
   d_16.percent,
   d_16.party,
   COUNT(b.title) AS bans
FROM district_vote_bans_16 AS d_16
JOIN book_bans AS b
ON d_16.state = b.state AND d_16.county = b.county
WHERE d_16.party = 'Democrat'
GROUP BY  
   d_16.state,
   d_16.county,
   d_16.year,
   d_16.percent,
   d_16.party
ORDER BY percent DESC)
UNION ALL
(SELECT
   d_20.state,
   d_20.county,
   d_20.year,
   d_20.percent,
   d_20.party,
   COUNT(b.title) AS bans
FROM district_vote_bans_20 AS d_20
JOIN book_bans AS b
ON d_20.state = b.state AND d_20.county = b.county
WHERE d_20.party = 'Democrat'
GROUP BY  
   d_20.state,
   d_20.county,
   d_20.year,
   d_20.percent,
   d_20.party
ORDER BY percent DESC)
)

SELECT
  state,
  county,
  year,
  percent,
  party,
  bans
FROM dem_12_20_elections
WHERE party = 'Democrat'
ORDER BY
  state,
  county,
  year,
  percent DESC;

-- ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ EXPLORATORY DATA ANALYSIS PARTS ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~

/*
-- MEAN: Average number of books banned in dataset
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT ROUND(AVG(ban_count), 0) AS mean
FROM bans_by_district;

-- MEDIAN: Median number of books banned in dataset
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ban_count) AS median
FROM bans_by_district;

-- MINIMUM: Minimum books banned in dataset
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT MIN(ban_count) AS minimum
FROM bans_by_district;

-- MAXIMUM: Maximum books banned in dataset
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT MAX(ban_count) AS maximum
FROM bans_by_district;

-- RANGE:
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT MAX(ban_count) - MIN(ban_count) AS range
FROM bans_by_district;

-- STANDARD DEVIATION:
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT ROUND(STDDEV(ban_count), 2) AS standard_deviation
FROM bans_by_district;

WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT ROUND(SQRT(VARIANCE(ban_count)), 2) AS stddev_using_variance
FROM bans_by_district;

-- VARIANCE:
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT ROUND(VARIANCE(ban_count), 2) AS variance
FROM bans_by_district;

WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT ROUND(POWER(STDDEV(ban_count), 2), 2) AS variance_using_stddev
FROM bans_by_district;

-- Q1:
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ban_count) AS Q1
FROM bans_by_district;

-- Q3:
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ban_count) AS Q3
FROM bans_by_district;

-- IQR (Interquartile Range):
WITH bans_by_district AS (SELECT
                            district_name,
                            COUNT(title) AS ban_count
                          FROM book_bans
                          WHERE district_name IS NOT null
                          GROUP BY
                            district_name)
SELECT
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ban_count) - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ban_count) AS IQR
FROM bans_by_district;

-- SKEWNESS:
WITH mean_median_sd AS (WITH bans_by_district AS (SELECT
                                                    district_name,
                                                    COUNT(title) AS ban_count
                                                  FROM book_bans
                                                  WHERE district_name IS NOT null
                                                  GROUP BY
                                                    district_name)
                       SELECT
                         AVG(ban_count) AS mean,
                         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ban_count) AS median,
                         STDDEV(ban_count) AS stddev
                       FROM bans_by_district)
SELECT
  ROUND(3* (mean - median)::NUMERIC / stddev, 2) AS skewness
FROM mean_median_sd;
*/