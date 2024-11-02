WITH first_event_table AS (
  SELECT 
    FIRST_VALUE(event_timestamp) OVER (PARTITION BY user_pseudo_id, event_name ORDER BY event_timestamp) AS first_event_timestampt,
   
  FROM `tc-da-1.turing_data_analytics.raw_events`
  ),

  top_3_countries AS (
    SELECT 
      COUNT() AS events, 
      country 
    FROM first_event_table 
    GROUP BY country
    ORDER BY events DESC 
    LIMIT 3
  ),

  events_top_3_countries AS (
    SELECT 
    FROM first_event_table
    WHERE first_event_timestampt = event_timestamp 
    AND country IN (SELECT country FROM top_3_countries)
  ),

  grouped_events AS (
    SELECT 
      RANK() OVER(ORDER BY COUNT(user_pseudo_id) DESC) AS event_order,
      COUNT(user_pseudo_id) AS event_num, 
      event_name,
      COUNT(CASE WHEN category = desktop THEN user_pseudo_id END) AS desktop_events,
      COUNT(CASE WHEN category = mobile THEN user_pseudo_id END) AS mobile_events,
      COUNT(CASE WHEN category = tablet THEN user_pseudo_id END) AS tablet_events,

    FROM events_top_3_countries
    WHERE event_name IN (
      first_visit, 
      user_engagement, 
      add_to_cart, 
      begin_checkout, 
      add_payment_info, 
      purchase 
      )
    GROUP BY event_name
    ORDER BY event_num DESC
  )

  SELECT 
    event_order, 
    event_name, 
    desktop_events,
    mobile_events,
    tablet_events,
    ROUND(1 - (desktop_events(LAG(desktop_events) OVER(ORDER BY desktop_events DESC))),4) AS desktop_drop_between_stages,
    ROUND(1 - (mobile_events(LAG(mobile_events) OVER(ORDER BY mobile_events DESC))),4) AS mobile_drop_between_stages,
    ROUND(1 - (tablet_events(LAG(tablet_events) OVER(ORDER BY tablet_events DESC))),4) AS tablet_drop_between_stages,
    ROUND(desktop_events(SELECT desktop_events FROM grouped_events LIMIT 1), 4) AS desktop_perc_drop,
    ROUND(mobile_events(SELECT mobile_events FROM grouped_events LIMIT 1), 4) AS mobile_perc_drop,
    ROUND(tablet_events(SELECT tablet_events FROM grouped_events LIMIT 1), 4) AS tablet_perc_drop
  FROM grouped_events
  ORDER BY event_order

