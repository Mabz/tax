# Cross-Border Tax Platform - Application Documentation

## Overview

The Cross-Border Tax Platform is a Flutter application built with Supabase backend that manages cross-border vehicle passes, tax collection, and border control operations. The system supports multiple user roles and provides comprehensive management tools for authorities, border officials, and travelers.

## Application Architecture

### Technology Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL + Auth + Real-time)
- **Authentication**: Supabase Auth with Google Sign-In support
- **State Management**: StatefulWidget with real-time subscriptions
- **Database**: PostgreSQL via Supabase

### Key Dependencies
- `supabase_flutter`: Backend integration and authentication
- `google_sign_in`: Google OAuth integration
- `qr_flutter`: QR code generation for passes
- `mobile_scanner`: QR code scanning for validation
- `geolocator`: Location services for border control
- `shared_preferences`: Local data persistence

## Core Features

### 1. Authentication System
- **Email/Password Authentication**: Standard sign-up and sign-in
- **Google OAuth**: Single sign-on with Google accounts
- **Multi-Factor Authentication (MFA)**: TOTP-based 2FA support
- **Password Reset**: Email-based password recovery
- **Session Management**: Automatic session handling with real-time updates

### 2. Role-Based Access Control (RBAC)

The system implements a comprehensive role-based access control system with the following roles:

#### User Roles
- **Superuser**: Full system administration access
- **Country Admin**: Manages country-specific operations and users
- **Country Auditor**: Read-only access to country data for auditing
- **Border Official**: Validates passes at border crossings
- **Business Intelligence**: Access to analytics and reporting
- **Local Authority**: Manages local authority operations
- **Traveller**: Basic user role for purchasing and using passes

#### Authority System
- Users can be assigned to specific authorities within countries
- Authority selection determines available operations and data access
- Real-time authority switching for multi-authority users

### 3. Pass Management System

#### Pass Templates
- Configurable pass types for different vehicle categories
- Pricing and validity period management
- Country and authority-specific templates

#### Pass Purchasing
- Vehicle registration and validation
- Payment processing integration
- QR code generation for digital passes
- Pass history and status tracking

#### Pass Validation
- QR code scanning at border crossings
- Real-time validation with GPS location
- Audit trail for all validation activities
- Offline validation capabilities

### 4. Vehicle Management
- Vehicle registration and documentation
- Vehicle type categorization
- Tax rate management by vehicle type
- Vehicle search and filtering capabilities

### 5. Border Control System

#### Border Management
- Border crossing point configuration
- Border type categorization (land, sea, air)
- GPS coordinates and location mapping
- Authority assignment to borders

#### Border Official Operations
- Pass validation interface
- Real-time validation logging
- Location-based validation controls
- Offline operation support

### 6. Business Intelligence & Analytics

#### Pass Analytics
- Pass sales and usage statistics
- Revenue tracking and reporting
- Geographic distribution analysis
- Time-based trend analysis

#### Revenue Analytics
- Tax collection reporting
- Revenue by country/authority
- Payment method analysis
- Financial performance metrics

### 7. User Management

#### Profile Management
- User profile creation and updates
- Account activation/deactivation
- Role assignment and management
- Real-time profile synchronization

#### Invitation System
- Role-based invitation workflow
- Email invitation delivery
- Acceptance/decline tracking
- Real-time invitation updates

### 8. Audit & Compliance

#### Audit Logging
- Comprehensive activity logging
- User action tracking
- Data change auditing
- Compliance reporting

#### Security Features
- Account lockout protection
- Real-time security monitoring
- Session management
- Data encryption

## Application Structure

### Directory Organization
```
lib/
├── constants/          # Application constants and configuration
├── enums/             # Enumeration definitions
├── models/            # Data models and entities
├── screens/           # UI screens and pages
│   ├── bi/           # Business Intelligence screens
│   └── ...           # Other feature screens
├── services/          # Business logic and API services
├── utils/            # Utility functions and helpers
├── widgets/          # Reusable UI components
└── main.dart         # Application entry point
```

### Key Models

#### Core Entities
- **Profile**: User profile information and settings
- **Authority**: Government authorities managing borders
- **Country**: Country information and configuration
- **Border**: Border crossing points and details
- **Vehicle**: Vehicle registration and information
- **Pass**: Digital passes for border crossing
- **Role**: User roles and permissions

#### Supporting Models
- **Audit Log**: Activity and change tracking
- **Role Invitation**: User invitation workflow
- **Payment Details**: Payment and billing information
- **Border Assignment**: Authority-border relationships

### Service Layer

#### Authentication Services
- User authentication and session management
- Role verification and authorization
- MFA enrollment and challenge handling

#### Business Services
- **Authority Service**: Authority management and operations
- **Border Service**: Border crossing management
- **Pass Service**: Pass lifecycle management
- **Vehicle Service**: Vehicle registration and management
- **Profile Service**: User profile operations

#### Analytics Services
- **Business Intelligence Service**: Analytics and reporting
- **Audit Service**: Activity logging and compliance

## User Interface

### Navigation Structure
- **Drawer Navigation**: Role-based menu system
- **Authority Selection**: Context switching for multi-authority users
- **Real-time Updates**: Live data synchronization across screens

### Screen Categories

#### Administrative Screens
- Country Management
- User Management
- Authority Management
- Border Management
- Audit Management

#### Operational Screens
- Pass Dashboard
- Vehicle Management
- Border Validation
- Authority Validation

#### Analytics Screens
- BI Dashboard
- Pass Analytics
- Revenue Analytics

#### User Screens
- Profile Settings
- Account Security
- Invitation Management

## Data Flow

### Authentication Flow
1. User signs in via email/password or Google OAuth
2. System checks for MFA requirements
3. Profile and role information loaded
4. Authority context established
5. Real-time subscriptions activated

### Pass Validation Flow
1. Border official scans QR code
2. System validates pass authenticity
3. Location and authority verification
4. Validation result logged
5. Real-time updates to relevant parties

### Real-time Updates
- Profile changes (account status, roles)
- Invitation status changes
- Pass validation events
- System notifications

## Security Features

### Authentication Security
- Secure password requirements
- MFA support with TOTP
- Session timeout management
- Account lockout protection

### Authorization Security
- Role-based access control
- Authority-based data isolation
- Real-time permission validation
- Audit trail for all actions

### Data Security
- Encrypted data transmission
- Secure API endpoints
- Input validation and sanitization
- SQL injection prevention

## Configuration

### Environment Setup
- Supabase project configuration
- Google OAuth client setup
- Database schema and functions
- Real-time subscription channels

### Database Schema
- User profiles and authentication
- Role and permission management
- Country and authority structure
- Pass and vehicle management
- Audit and compliance logging

## Deployment

### Mobile Platforms
- Android APK/AAB generation
- iOS App Store deployment
- Platform-specific configurations

### Backend Services
- Supabase project deployment
- Database migrations
- Cloud function deployment
- Real-time channel configuration

## Monitoring & Analytics

### Application Monitoring
- User activity tracking
- Performance metrics
- Error logging and reporting
- Usage analytics

### Business Metrics
- Pass sales and revenue
- User engagement metrics
- System performance indicators
- Compliance reporting

## Support & Maintenance

### User Support
- In-app help and documentation
- Error message handling
- User feedback collection
- Support ticket integration

### System Maintenance
- Database backup and recovery
- Performance optimization
- Security updates
- Feature enhancement deployment

---

*This documentation provides a comprehensive overview of the Cross-Border Tax Platform application. For specific implementation details, refer to the source code and individual service documentation.*