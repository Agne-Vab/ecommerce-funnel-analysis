"WITH first_event_table AS (
  SELECT 
    FIRST_VALUE(event_timestamp) OVER (PARTITION BY user_pseudo_id, event_name ORDER BY event_timestamp) AS first_event_timestampt,
   *
  FROM `tc-da-1.turing_data_analytics.raw_events`
  ),

  top_3_countries AS (
    SELECT 
      COUNT(*) AS events, 
      country 
    FROM first_event_table 
    GROUP BY country
    ORDER BY events DESC 
    LIMIT 3
  ),

  events_top_3_countries AS (
    SELECT *
    FROM first_event_table
    WHERE first_event_timestampt = event_timestamp 
    AND country IN (SELECT country FROM top_3_countries)
  ),

  grouped_events AS (
    SELECT 
      RANK() OVER(ORDER BY COUNT(user_pseudo_id) DESC) AS event_order,
      COUNT(user_pseudo_id) AS event_num, 
      event_name,
      COUNT(CASE WHEN country = (SELECT country FROM top_3_countries ORDER BY events DESC LIMIT 1) THEN user_pseudo_id END) AS _1st_country_events,
      COUNT(CASE WHEN country = (SELECT country FROM top_3_countries ORDER BY events DESC LIMIT 1 OFFSET 1) THEN user_pseudo_id END) AS _2nd_country_events,
      COUNT(CASE WHEN country = (SELECT country FROM top_3_countries ORDER BY events DESC LIMIT 1 OFFSET 2) THEN user_pseudo_id END) AS _3rd_country_events,

    FROM events_top_3_countries
    WHERE event_name IN (
      ""first_visit"", 
      ""user_engagement"", 
      ""add_to_cart"", 
      ""begin_checkout"", 
      ""add_payment_info"", 
      ""purchase"" 
      )
    GROUP BY event_name
    ORDER BY event_num DESC
  )

  SELECT 
    event_order, 
    event_name, 
    _1st_country_events,
    _2nd_country_events,
    _3rd_country_events,
    ROUND(1 - (_1st_country_events/(LAG(_1st_country_events) OVER(ORDER BY _1st_country_events DESC))),4) AS _1st_drop_between_stages,
    ROUND(1 - (_2nd_country_events/(LAG(_2nd_country_events) OVER(ORDER BY _2nd_country_events DESC))),4) AS _2nd_drop_between_stages,
    ROUND(1 - (_3rd_country_events/(LAG(_3rd_country_events) OVER(ORDER BY _3rd_country_events DESC))),4) AS _3rd_drop_between_stages,
    ROUND(_1st_country_events/(SELECT _1st_country_events FROM grouped_events LIMIT 1), 4) AS _1st_country_perc_drop,
    ROUND(_2nd_country_events/(SELECT _2nd_country_events FROM grouped_events LIMIT 1), 4) AS _2nd_country_perc_drop,
    ROUND(_3rd_country_events/(SELECT _3rd_country_events FROM grouped_events LIMIT 1), 4) AS _3rd_country_perc_drop
  FROM grouped_events
  ORDER BY event_order
"