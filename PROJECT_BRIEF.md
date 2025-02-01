# rBUM Project Brief

## Project Overview

rBUM (Restic Backup Manager) is a native macOS application providing a graphical user interface for [Restic](https://restic.net/) backup operations. The application aims to enhance the user experience of Restic on macOS whilst maintaining its powerful features and security model.

### About Restic Integration

rBUM is built as a GUI wrapper around Restic, developed by Alexander Neumann and contributors. We acknowledge and respect Restic's:
- Robust security architecture
- Efficient backup engine
- Proven reliability
- Active community development

Our goal is to complement Restic by providing a native macOS interface, not to replace or modify its core functionality. All backup operations are performed by Restic itself, ensuring that users benefit from its security guarantees and performance optimisations.

## MVP Phase (5 Days)
### Day 1: Basic Structure and Restic Integration
- [x] Basic Xcode project setup
  - [x] Project creation with SwiftUI
  - [x] Directory structure setup
  - [x] Window configuration
  - [x] Navigation structure
- [x] Simple ResticCommandService implementation
  - [x] Repository init/list commands
  - [x] Basic command execution framework
- [x] Shell command execution framework
- [x] Basic error handling

### Day 2: Core UI Framework
- [x] Main navigation structure
  - [x] Sidebar implementation
  - [x] Navigation split view
- [x] Repository list view (placeholder)
- [x] Basic settings view
  - [x] General tab
  - [x] Backup tab
  - [x] Security tab
- [x] Error display structure

### Day 3: Basic Security and Storage
- [x] Simple password storage using Keychain
  - [x] Secure password storage implementation
  - [x] Error handling and validation
  - [x] Test coverage
- [x] Basic repository credentials management
  - [x] Credentials model and storage
  - [x] Keychain integration
  - [x] Update and deletion handling
- [x] Repository location storage
  - [x] Repository metadata model
  - [x] Atomic file operations
  - [x] Path validation
- [x] Configuration storage
  - [x] Default settings management
  - [x] User preferences
  - [x] Secure storage implementation

### Day 4-5: Testing Infrastructure and Quality Assurance
- [x] Comprehensive test infrastructure
  - [x] Test plan organization
    - [x] Main test plan configuration
    - [x] Separate plans for unit, UI, and performance tests
    - [x] Environment variable configuration
  - [x] Swift Testing Framework integration
    - [x] Model tests conversion
    - [x] Service tests conversion
    - [x] ViewModel tests conversion
    - [x] TestContext pattern implementation
    - [x] Tagged tests for organized execution
  - [x] XCTest maintenance
    - [x] UI tests for SwiftUI components
    - [x] Performance tests for critical operations
  - [x] Test coverage monitoring
    - [x] Coverage reporting setup
    - [x] Critical path coverage
- [x] Code quality tools
  - [x] Static analyzer configuration
  - [x] SwiftLint integration
  - [x] Performance profiling setup

### Current Status
- Core functionality implemented
- Security features in place
- UI framework established
- Test infrastructure complete
  - Bimodal testing strategy (Swift Testing + XCTest)
  - Comprehensive test coverage
  - Performance monitoring
  - Dedicated TestMocksModule for shared test mocks
- Code quality improvements
  - Fixed unused result warnings
  - Proper Sendable conformance
  - Improved memory management
- Ready for feature development phase

### Test Infrastructure Improvements
#### TestMocksModule
- [x] Created dedicated module for test mocks
  - [x] MockUserDefaults implementation
  - [x] MockFileManager implementation
  - [x] MockNotificationCenter implementation
  - [x] Thread-safe design with proper Sendable conformance
  - [x] Public API for test usage
- [x] Integrated with existing test suite
  - [x] Updated BackupConfigurationTests
  - [x] Prepared for wider test coverage

#### Code Quality Enhancements
- [x] Improved command result handling
  - [x] Explicit handling of unused results
  - [x] Better error propagation
- [x] Enhanced thread safety
  - [x] Proper Sendable conformance
  - [x] Safe state management
- [x] Memory optimizations
  - [x] Removed unused variables
  - [x] Efficient resource management

## Major Development Areas

### 1. Project Setup and Infrastructure (1-2 days)
- [x] Initial repository setup
- [x] Project documentation
- [x] Xcode project configuration
- [x] CI/CD pipeline setup
  - [x] Swift build and test workflow
  - [x] SwiftLint configuration
  - [x] Documentation generation
- [x] Development environment documentation

### 2. Core Integration with Restic (2-3 weeks)
- [x] ResticCommandService development
  - [x] Command execution framework
  - [x] Error handling and logging
  - [x] Repository management commands
  - [x] Backup operations
    - [x] Path selection
    - [x] Progress monitoring
    - [x] Status reporting
  - [ ] Restore operations
  - [x] Unit tests
    - [x] Mock services
    - [x] Preview helpers
    - [x] Integration tests
- [ ] Drive scanning service
  - [ ] Repository discovery
  - [ ] Repository validation
  - [ ] Performance optimisation

### 3. Security Framework (2 weeks)
- [ ] Passkey integration
  - [ ] Implementation of PasskeyManager
  - [ ] Secure storage integration
  - [ ] Migration from existing password stores
- [ ] Repository credentials management
  - [ ] Secure credential storage
  - [ ] Credential rotation support
- [ ] Security testing and audit

### 4. User Interface Development (3-4 weeks)
- [ ] Core UI Components
  - [ ] Navigation structure
  - [ ] Repository management views
  - [ ] Backup/restore interfaces
  - [ ] Settings panels
- [ ] Advanced UI Features
  - [ ] Progress indicators
  - [ ] Notification system
  - [ ] Status monitoring
  - [ ] Error reporting
- [ ] UI Testing

### 5. Backup Scheduling System (1-2 weeks)
- [ ] Scheduler service
  - [ ] Schedule creation/management
  - [ ] Background task handling
  - [ ] Power management integration
- [ ] Schedule conflict resolution
- [ ] Notification system integration

### 6. Testing and Quality Assurance (2-3 weeks)
#### Testing Framework Strategy
- Swift Testing Framework
  - Unit tests for models, services, and viewmodels
  - Parameterized testing for multiple scenarios
  - Tagged tests for organised test execution
  - Async/await support for concurrent operations
  
- XCTest Framework
  - UI testing with XCUITest
  - Performance testing with XCTMetric
  - Baseline measurements and metrics

#### Test Categories and Timeline
1. Model Tests (Week 1)
   - Repository credentials
   - Backup progress monitoring
   - Data models validation

2. Service Tests (Week 2)
   - Core Restic command integration
   - Security and keychain services
   - Storage and configuration services

3. ViewModel Tests (Week 3)
   - Backup operations
   - Repository management
   - Settings and configuration

4. UI and Performance Tests (Weeks 4-5)
   - User interface flows
   - Backup performance metrics
   - Search and filter operations
   - Resource utilisation

#### Test Plan Structure
- Separate test plans for different scenarios:
  - Unit tests (Swift Testing)
  - UI tests (XCTest)
  - Performance tests (XCTest)
  - CI/CD pipeline tests

- Code coverage requirements:
  - Models: 95%
  - Services: 90%
  - ViewModels: 85%
  - UI Components: 75%

### 7. Documentation and Polish (1-2 weeks)
- [ ] User documentation
- [ ] API documentation
- [ ] Installation guide
- [ ] Troubleshooting guide
- [ ] Release notes

## Development Phases

### MVP Phase
- Basic repository management (create, import, delete)
- Snapshot management (create, restore, delete, prune)
- Backup creation with path selection
- Repository health monitoring
- Secure credential storage using macOS Keychain
- Error handling and logging
- Basic UI with repository list and details

### Post-MVP Phase

#### Snapshot Analytics and Statistics
- Snapshot size trends over time
- Backup frequency analysis
- Storage efficiency metrics
- Deduplication statistics
- Growth rate predictions
- Data type distribution analysis
- Visual graphs and charts
- Export statistics as reports
- Customisable time ranges for analysis
- Comparative analysis between repositories

#### Additional Features
- Advanced scheduling options
- Complex restore scenarios
- Detailed backup statistics
- Advanced UI animations
- Non-critical settings
- Advanced documentation features (defer to basic command reference)

## Timeline Summary
- Work Schedule: 5.5 days/week, 9 hours/day
- Total Development Time: 6 weeks (297 hours)
- Development Phases:
  1. MVP (Week 1, Days 1-5)
  2. Core Features (Week 1 Day 6 - Week 3)
  3. UI Polish and Security (Weeks 4-5)
  4. Testing and Release (Week 6)

## Weekly Breakdown

### Week 1 (49.5 hours)
- Days 1-5: MVP Phase as outlined above
- Day 6: MVP refinement and core feature planning

### Week 2 (49.5 hours)
- Enhanced Restic Integration
  - Robust command execution
  - Error handling improvements
  - Repository management
  - Basic scheduling framework

### Week 3 (49.5 hours)
- Security Implementation
  - Passkey integration
  - Credential management
  - Repository security
- Advanced Backup Features
  - Scheduling system
  - Progress monitoring
  - Status reporting

### Week 4 (49.5 hours)
- UI Development
  - Enhanced navigation
  - Progress visualisation
  - Status dashboard
  - Settings refinement
- Initial Testing Phase
  - Unit tests
  - Integration tests

### Week 5 (49.5 hours)
- UI Polish
  - Animation refinements
  - Accessibility improvements
  - Dark/Light mode support
  - Integrated documentation viewer
    - Restic command reference
    - Quick help integration
    - Context-sensitive help
    - Offline documentation support
- Security Hardening
  - Security audit
  - Penetration testing
  - Bug fixes

### Week 6 (49.5 hours)
- Final Testing
  - Performance optimisation
  - Edge case handling
  - UI/UX testing
- Documentation
  - User guide
  - API documentation
  - Release notes
  - Integrated Restic documentation
    - Command reference integration
    - Example usage scenarios
    - Troubleshooting guides
    - Quick reference cards
- Release Preparation
  - Final bug fixes
  - Release packaging
  - Distribution preparation

## Risk Assessment

### High Risk Areas
1. Compressed timeline impact on quality
2. Restic command integration complexity
3. Security implementation thoroughness
4. Feature scope management
5. Documentation synchronisation with Restic updates

### Mitigation Strategies
1. Daily progress tracking and scope adjustment
2. Early prototyping of critical features
3. Continuous testing throughout development
4. Regular stakeholder reviews
5. Clear MVP definition and feature prioritisation
6. Automated testing from Week 2 onwards
7. Documentation version tracking system

### Scope Management
Features that could be deferred if needed:
1. Advanced scheduling options
2. Complex restore scenarios
3. Detailed backup statistics
4. Advanced UI animations
5. Non-critical settings
6. Advanced documentation features (defer to basic command reference)

## Success Criteria
1. Successful management of Restic repositories
2. Secure credential handling
3. Reliable backup scheduling
4. Intuitive user interface
5. Comprehensive error handling
6. Accessible integrated documentation
7. Performance within acceptable parameters:
   - Repository scan < 30 seconds
   - Backup initiation < 5 seconds
   - UI responsiveness < 100ms
   - Documentation search < 500ms

## Next Steps
1. Set up Xcode project structure
2. Begin ResticCommandService implementation
3. Create basic UI shell
4. Implement initial security framework

## Resource Requirements
- macOS Sonoma (14.0) or later
- Xcode 16.0
- Swift 5.9.2
- Restic
- Test environments with various data sizes
- Security testing tools

## Review Points
- Weekly code reviews
- Bi-weekly progress assessment
- Monthly security reviews
- User testing at 50% and 80% completion

This brief will be updated as the project progresses and more detailed requirements are discovered.
