# Security Violations Management System - Implementation Plan

- [-] 1. Create core database schema and configuration system



  - Create `security_violation_thresholds` table with authority-specific configuration support
  - Create `security_violations` table with proper indexing and JSONB violation data storage
  - Implement severity calculation database function with configurable threshold support
  - Create default threshold configuration data for GPS distance, illegal vehicle, and expired pass violations
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 2. Implement threshold configuration service and models
  - Create `ViolationThresholds` model class with threshold validation and severity calculation methods
  - Create `SecurityViolationThresholdsService` with CRUD operations for threshold management
  - Implement threshold validation logic ensuring logical consistency (LOW < MEDIUM < HIGH < CRITICAL)
  - Create default threshold providers for each violation type with sensible fallback values
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

- [ ] 3. Create security violations core service and models
  - Create `SecurityViolation` model class with violation data serialization and status management
  - Implement `SecurityViolationsService` with violation creation, status updates, and querying capabilities
  - Create violation detection helper methods for automatic severity assignment using configurable thresholds
  - Implement violation data validation and sanitization for JSONB storage
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 4. Integrate GPS distance violation detection
  - Update `BorderSelectionService.validateBorderGpsDistance()` to create security violations when GPS validation fails
  - Modify GPS validation functions to log violations with proper severity calculation and location data
  - Update GPS violation dialog handling to reference created violation records
  - Ensure GPS validation audit events link to violation records via `related_violation_id`
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 5. Integrate illegal vehicle detection in authority validation
  - Update `AuthorityValidationScreen._completeValidation()` to detect and create illegal vehicle violations
  - Implement violation creation when vehicle status is "Departed" but found in-country
  - Add violation data collection including vehicle details, owner information, and scan context
  - Update validation result display to reference violation severity and provide investigation context
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 6. Implement expired pass violation detection
  - Update pass processing functions to detect expired pass usage attempts
  - Create expired pass violations with appropriate severity based on days overdue
  - Integrate violation creation into border processing and authority validation workflows
  - Ensure expired pass violations prevent unauthorized actions while logging the attempt
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 7. Create violations BI service and analytics functions
  - Implement `SecurityViolationsBIService` with analytics methods for violation counts, trends, and geographic distribution
  - Create database functions for violation analytics with filtering support (period, border, severity, type)
  - Implement violation heat map generation with geographic clustering and border context
  - Add violation trend analysis with time-series data and pattern detection capabilities
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [ ] 8. Integrate violations into Non-Compliance analytics screen
  - Update `BusinessIntelligenceService.getNonComplianceAnalytics()` to include violation data from new violations system
  - Add violation categories to Non-Compliance screen alongside overstayed vehicles with consistent styling and navigation
  - Implement violation drill-down popups with detailed violation information and investigation context
  - Update non-compliance banner calculation to include violation counts in total compliance metrics
  - Ensure all existing filters (period, border, entry/exit) apply consistently to violation queries
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [ ] 9. Create violations dashboard and detailed views
  - Create violations dashboard screen with comprehensive filtering and analytics capabilities
  - Implement multi-dimensional filtering (type, severity, location, time period) with filter state management
  - Add violation trend visualization with time-series charts and geographic heat maps
  - Create detailed violation view with investigation workflow and status management
  - Implement violation export functionality for compliance reporting and external analysis
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [ ]* 10. Write comprehensive tests for violations system
  - Create unit tests for threshold configuration validation and severity calculation logic
  - Write integration tests for violation detection workflows and BI analytics integration
  - Implement end-to-end tests for complete violation lifecycle from detection to resolution
  - Add performance tests for violation analytics queries and dashboard loading under various data loads
  - _Requirements: All requirements validation and system reliability_