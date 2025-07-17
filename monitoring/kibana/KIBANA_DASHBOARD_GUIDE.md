# Kibana Dashboard Setup Guide
### PizzaMaker Monitoring & Correlation ID Tracking

## Overview
This guide will help you create a comprehensive Kibana dashboard to monitor PizzaMaker microservices and track correlation IDs.

## Accessing Kibana
1. Open your browser and go to: **http://localhost:5601**
2. Wait for Kibana to load completely

## Dashboard Creation

### Step 1: Verify Index Patterns
1. Go to **Management** → **Stack Management** → **Index Patterns**
2. Verify that these exist:
   - `pizzamaker-logs-*`
   - `fluentd-*`

### Step 2: Data Exploration
1. Go to **Discover**
2. Select the `fluentd-*` index pattern
3. Observe the available fields:
   - `container_name` - Container name
   - `log` - JSON log content
   - `source` - stdout/stderr
   - `hostname` - Container host

### Step 3: Creating Visualizations

#### Visualization 1: Log Levels Distribution
1. Go to **Visualize** → **Create visualization** → **Pie chart**
2. Select index pattern `pizzamaker-logs-*`
3. Configuration:
   - **Metrics**: Count
   - **Buckets**: Add bucket → Split slices
   - **Aggregation**: Terms
   - **Field**: `log_level.keyword`
   - **Size**: 10
4. Save as "Log Levels Distribution"

#### Visualization 2: Service Activity Timeline
1. **Visualize** → **Create** → **Line chart**
2. Index pattern: `fluentd-*`
3. Configuration:
   - **Metrics**: Count
   - **Buckets**: X-axis → Date Histogram
   - **Field**: `@timestamp`
   - **Interval**: Auto
   - Add sub-bucket → Split series
   - **Aggregation**: Terms
   - **Field**: `container_name.keyword`
4. Save as "Service Activity Timeline"

#### Visualization 3: Error Detection
1. **Visualize** → **Create** → **Data table**
2. Index pattern: `fluentd-*`
3. Configuration:
   - **Metrics**: Count
   - **Buckets**: Split rows
   - **Aggregation**: Terms
   - **Field**: `container_name.keyword`
   - Add metric → Unique Count
   - **Field**: `log.keyword`
4. Apply filters:
   - `log: *error* OR log: *ERROR* OR log: *failed*`
5. Save as "Error Detection"

#### Visualization 4: Correlation ID Tracking
1. **Visualize** → **Create** → **Data table**
2. Index pattern: `pizzamaker-logs-*`
3. Configuration:
   - **Metrics**: Count
   - **Buckets**: Split rows
   - **Aggregation**: Terms
   - **Field**: `correlation_id.keyword`
   - **Size**: 20
   - Add bucket → Split rows
   - **Aggregation**: Terms
   - **Field**: `service_name.keyword`
4. Save as "Correlation ID Tracking"

#### Visualization 5: Health Status Metric
1. **Visualize** → **Create** → **Metric**
2. Index pattern: `fluentd-*`
3. Configuration:
   - **Metrics**: Count
   - Apply filter: `log: *healthy* OR log: *health*`
4. Save as "Health Status"

### Step 4: Creating Dashboard
1. Go to **Dashboard** → **Create new dashboard**
2. Click **Add**
3. Add all created visualizations:
   - Log Levels Distribution
   - Service Activity Timeline
   - Error Detection
   - Correlation ID Tracking
   - Health Status
4. Organize panels in the desired layout
5. Save the dashboard as **"PizzaMaker Monitoring & Correlation Dashboard"**

## Final Result
After completing all steps, you'll have a comprehensive dashboard that shows:
- **Real-time monitoring** of microservices
- **Correlation ID tracking** for distributed traces
- **Error detection** and alerting
- **Performance metrics** for each service
- **Historical trends** for temporal analysis
