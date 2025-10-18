# Security Violations Management System - Requirements

## Introduction

The Security Violations Management System is a comprehensive solution to separate security incidents from operational audit logs, providing dedicated tracking, investigation workflow, and business intelligence for border security violations. This system will replace the current mixed-purpose `pass_processing_audit` table with a clear separation between process decisions and security violations.

## Requirements

### Requirement 1: Configurable Severity Thresholds

**User Story:** As a country_admin, I want to configure severity thresholds for different violation types using the existing manage authority screen, so that I can adapt the system to our specific security policies and operational requirements without code changes.

#### Acceptance Criteria

1. WHEN configuring GPS distance violations THEN the system SHALL allow setting distance thresholds for LOW (<20km over), MEDIUM (20-50km over), HIGH (>50km over) severity levels
2. WHEN configuring illegal vehicle violations THEN the system SHALL allow setting time-based thresholds for CRITICAL (<7 days), HIGH (7-30 days), MEDIUM (>30 days) severity levels  
3. WHEN configuring expired pass violations THEN the system SHALL allow setting overdue thresholds for LOW (<7 days), MEDIUM (7-30 days), HIGH (>30 days) severity levels
4. WHEN updating thresholds THEN the system SHALL apply new thresholds to future violations immediately without system restart
5. WHEN storing threshold configurations THEN the system SHALL store in the authorities table and maintain audit trail of threshold changes with timestamps and country_admin information
6. WHEN validating thresholds THEN the system SHALL ensure logical consistency (LOW < MEDIUM < HIGH thresholds) and prevent invalid configurations

### Requirement 2: Security Violations Data Model

**User Story:** As a country_auditor, I want a dedicated system to track all security violations with proper categorization and severity levels, so that I can prioritize investigations and monitor security trends.

#### Acceptance Criteria

1. WHEN a security violation occurs THEN the system SHALL create a record in the `security_violations` table with violation type, severity level, and contextual data
2. WHEN storing violation data THEN the system SHALL include GPS coordinates, timestamp, responsible authority, and related pass information
3. WHEN categorizing violations THEN the system SHALL support severity levels: LOW, MEDIUM, HIGH, CRITICAL
4. WHEN tracking violations THEN the system SHALL support status workflow: open, investigating, resolved, false_positive
5. WHEN storing violation-specific data THEN the system SHALL use JSONB format for flexible, queryable metadata
6. WHEN linking violations to audit events THEN the system SHALL maintain referential integrity via `related_audit_id`

### Requirement 3: GPS Distance Violations Detection

**User Story:** As a country_auditor, I want to automatically detect when officials attempt to process passes outside the allowed GPS range, so that I can identify potential security breaches and ensure compliance with location-based controls.

#### Acceptance Criteria

1. WHEN GPS validation fails THEN the system SHALL create a `gps_distance_violation_detected` security violation record
2. WHEN recording GPS violations THEN the system SHALL capture actual distance, maximum allowed distance, border coordinates, and current coordinates
3. WHEN an official cancels due to GPS violation THEN the system SHALL log the decision in `pass_processing_audit` with reference to the violation
4. WHEN an official proceeds despite GPS violation THEN the system SHALL log both the violation and the override decision with justification
5. WHEN calculating severity THEN the system SHALL apply authority-specific configurable thresholds from Requirement 1 to determine violation severity level

### Requirement 4: Illegal Vehicle Detection

**User Story:** As a country_auditor, I want the system to automatically flag vehicles found in-country that show as "Departed", so that I can identify potential illegal re-entries and border control bypasses.

#### Acceptance Criteria

1. WHEN local authority scans a pass THEN the system SHALL check if vehicle status is "Departed"
2. WHEN vehicle shows as departed but is found in-country THEN the system SHALL create an `illegal_vehicle_in_country` violation
3. WHEN recording illegal vehicle violations THEN the system SHALL capture scan location, vehicle details, owner information, and days since departure
4. WHEN determining severity THEN the system SHALL apply authority-specific configurable thresholds from Requirement 1 based on days since departure
5. WHEN violation is detected THEN the system SHALL display appropriate warning to the scanning officer

### Requirement 5: Expired Pass Usage Violations

**User Story:** As a country_auditor, I want to track attempts to use expired passes, so that I can identify patterns of non-compliance and potential fraud.

#### Acceptance Criteria

1. WHEN an expired pass is scanned THEN the system SHALL create an `expired_pass_violation` record
2. WHEN recording expired pass violations THEN the system SHALL capture expiration date, days overdue, attempted action, and location
3. WHEN determining severity THEN the system SHALL apply authority-specific configurable thresholds from Requirement 1 based on days overdue
4. WHEN violation occurs THEN the system SHALL prevent the requested action and log the attempt

### Requirement 6: Security Violations Dashboard

**User Story:** As a country_auditor, I want a comprehensive violations dashboard with filtering and analytics capabilities integrated with the existing Non-Compliance system, so that I can monitor security incidents alongside overstayed vehicles and identify patterns requiring attention.

#### Acceptance Criteria

1. WHEN accessing Non-Compliance screen THEN the system SHALL display security violations as additional clickable categories alongside overstayed vehicles
2. WHEN applying time period filters THEN the system SHALL support existing filter options (all_time, last_30_days, last_7_days, custom_range) for violations
3. WHEN filtering by borders THEN the system SHALL support existing border filtering (any_border, specific_border, any_entry, any_exit) for violations
4. WHEN calculating non-compliance totals THEN the system SHALL include violation counts in the banner total alongside overstayed vehicles
5. WHEN clicking violation categories THEN the system SHALL provide drill-down popups similar to overstayed vehicles with violation details
6. WHEN displaying violation trends THEN the system SHALL show geographic distribution and time-based analytics
7. WHEN combining filters THEN the system SHALL apply all selected criteria (period + border + entry/exit) to violation queries consistently
8. WHEN investigating patterns THEN the system SHALL highlight repeat offenders and high-risk locations within the existing Non-Compliance interface

<!--
### Requirement 8: Investigation Workflow (Future Enhancement)

**User Story:** As a security investigator, I want a structured workflow to manage violation investigations from detection to resolution, so that I can ensure all security incidents are properly addressed.

#### Acceptance Criteria

1. WHEN a violation is created THEN the system SHALL automatically assign status "open"
2. WHEN starting investigation THEN authorized users SHALL be able to update status to "investigating"
3. WHEN resolving violations THEN investigators SHALL be able to mark as "resolved" with resolution notes
4. WHEN violations are false positives THEN investigators SHALL be able to mark as "false_positive" with explanation
5. WHEN tracking investigation time THEN the system SHALL calculate time from creation to resolution
6. WHEN violations remain open THEN the system SHALL support escalation rules based on severity and age

### Requirement 9: Real-time Alerting (Future Enhancement)

**User Story:** As a security manager, I want to receive immediate notifications for critical security violations, so that I can respond quickly to potential security threats.

#### Acceptance Criteria

1. WHEN CRITICAL violations occur THEN the system SHALL generate immediate alerts to designated personnel
2. WHEN HIGH severity violations accumulate THEN the system SHALL send summary alerts based on configurable thresholds
3. WHEN violations occur at specific locations THEN the system SHALL support location-based alerting rules
4. WHEN repeat violations occur THEN the system SHALL escalate alerts for patterns indicating systematic issues
5. WHEN alerts are generated THEN the system SHALL include violation details, location, and recommended actions

### Requirement 10: API and Integration Support (Future Enhancement)

**User Story:** As a system integrator, I want well-defined APIs for security violations data, so that I can integrate with external security systems and reporting tools.

#### Acceptance Criteria

1. WHEN accessing violation data THEN the system SHALL provide REST API endpoints for CRUD operations
2. WHEN querying violations THEN the API SHALL support filtering, sorting, and pagination
3. WHEN integrating with external systems THEN the API SHALL support webhook notifications for new violations
4. WHEN ensuring security THEN all API access SHALL require proper authentication and authorization
5. WHEN maintaining performance THEN API responses SHALL include appropriate caching headers and rate limiting

### Requirement 11: Audit and Compliance (Future Enhancement)

**User Story:** As a compliance officer, I want complete audit trails for all security violation activities, so that I can demonstrate regulatory compliance and support legal proceedings.

#### Acceptance Criteria

1. WHEN violations are created, updated, or resolved THEN the system SHALL log all changes with timestamps and user information
2. WHEN accessing violation data THEN the system SHALL maintain immutable audit logs of all access attempts
3. WHEN generating compliance reports THEN the system SHALL provide standardized formats for regulatory submission
4. WHEN supporting legal proceedings THEN the system SHALL provide tamper-evident data export capabilities
5. WHEN ensuring data retention THEN the system SHALL support configurable retention policies for different violation types
-->