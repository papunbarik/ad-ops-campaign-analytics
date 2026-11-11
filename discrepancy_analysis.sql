-- Campaign Log Reconciliation: DSP Delivery vs. CM360 Ad Server Logs
-- Purpose: Detect >5% impression discrepancy and flag pacing anomalies

WITH dsp_aggregated AS (
    SELECT 
        placement_id,
        channel,
        flight_date,
        SUM(impressions) AS total_dsp_impressions,
        SUM(spend_usd) AS total_spend,
        SUM(clicks) AS total_clicks
    FROM raw_dsp_delivery_logs
    WHERE flight_date BETWEEN '2024-07-01' AND '2024-09-30'
    GROUP BY placement_id, channel, flight_date
),

cm360_aggregated AS (
    SELECT 
        placement_id,
        flight_date,
        SUM(ad_server_impressions) AS total_cm360_impressions,
        SUM(recorded_clicks) AS total_cm360_clicks
    FROM raw_cm360_server_logs
    WHERE flight_date BETWEEN '2024-07-01' AND '2024-09-30'
    GROUP BY placement_id, flight_date
)

SELECT 
    d.placement_id,
    d.channel,
    d.flight_date,
    d.total_dsp_impressions,
    c.total_cm360_impressions,
    d.total_spend,
    (d.total_dsp_impressions - COALESCE(c.total_cm360_impressions, 0)) AS impression_gap,
    ROUND(
        ABS(d.total_dsp_impressions - COALESCE(c.total_cm360_impressions, 0)) * 100.0 / NULLIF(d.total_dsp_impressions, 0),
        2
    ) AS discrepancy_percentage,
    CASE 
        WHEN ABS(d.total_dsp_impressions - COALESCE(c.total_cm360_impressions, 0)) * 100.0 / NULLIF(d.total_dsp_impressions, 0) > 8.0 
            THEN 'CRITICAL_DISCREPANCY'
        WHEN ABS(d.total_dsp_impressions - COALESCE(c.total_cm360_impressions, 0)) * 100.0 / NULLIF(d.total_dsp_impressions, 0) > 5.0 
            THEN 'WARNING_FLAG'
        ELSE 'RECONCILED'
    END AS audit_status
FROM dsp_aggregated d
LEFT JOIN cm360_aggregated c 
    ON d.placement_id = c.placement_id 
    AND d.flight_date = c.flight_date
ORDER BY discrepancy_percentage DESC;
