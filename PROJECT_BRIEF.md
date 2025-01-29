# rBUM Project Brief

## Project Overview
rBUM (Restic Backup Manager) is a native macOS application providing a graphical user interface for Restic backup operations. The application aims to simplify backup management while maintaining Restic's powerful features and security model.

## MVP Phase (5 Days)
### Day 1: Basic Structure and Restic Integration
- [ ] Basic Xcode project setup
- [ ] Simple ResticCommandService implementation
  - [ ] Repository init/list commands
  - [ ] Basic backup/restore commands
- [ ] Shell command execution framework
- [ ] Basic error handling

### Day 2: Core UI Framework
- [ ] Main navigation structure
- [ ] Repository list view
- [ ] Basic backup view
- [ ] Simple settings view
- [ ] Error display

### Day 3: Basic Security and Storage
- [ ] Simple password storage using Keychain
- [ ] Basic repository credentials management
- [ ] Repository location storage
- [ ] Configuration storage

### Day 4: Essential Features
- [ ] Repository creation/import
- [ ] Manual backup execution
- [ ] Basic restore functionality
- [ ] Simple progress indication
- [ ] Basic error reporting

### Day 5: Testing and Polish
- [ ] Basic integration testing
- [ ] UI refinements
- [ ] Critical bug fixes
- [ ] Basic user documentation
- [ ] MVP release preparation

## Major Development Areas

### 1. Project Setup and Infrastructure (1-2 days)
- [x] Initial repository setup
- [x] Project documentation
- [ ] Xcode project configuration
- [ ] CI/CD pipeline setup
- [ ] Development environment documentation

### 2. Core Restic Integration (2-3 weeks)
- [ ] ResticCommandService development
  - [ ] Command execution framework
  - [ ] Error handling and logging
  - [ ] Repository management commands
  - [ ] Backup operations
  - [ ] Restore operations
  - [ ] Unit tests
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

### 6. Testing and Quality Assurance (Ongoing, 2-3 weeks focused)
- [ ] Unit testing
  - [ ] Core services
  - [ ] ViewModels
  - [ ] Utilities
- [ ] Integration testing
- [ ] UI testing
- [ ] Performance testing
- [ ] Security testing

### 7. Documentation and Polish (1-2 weeks)
- [ ] User documentation
- [ ] API documentation
- [ ] Installation guide
- [ ] Troubleshooting guide
- [ ] Release notes

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
- Security Hardening
  - Security audit
  - Penetration testing
  - Bug fixes

### Week 6 (49.5 hours)
- Final Testing
  - Performance optimization
  - Edge case handling
  - UI/UX testing
- Documentation
  - User guide
  - API documentation
  - Release notes
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

### Mitigation Strategies
1. Daily progress tracking and scope adjustment
2. Early prototyping of critical features
3. Continuous testing throughout development
4. Regular stakeholder reviews
5. Clear MVP definition and feature prioritisation
6. Automated testing from Week 2 onwards

### Scope Management
Features that could be deferred if needed:
1. Advanced scheduling options
2. Complex restore scenarios
3. Detailed backup statistics
4. Advanced UI animations
5. Non-critical settings

## Success Criteria
1. Successful management of Restic repositories
2. Secure credential handling
3. Reliable backup scheduling
4. Intuitive user interface
5. Comprehensive error handling
6. Performance within acceptable parameters:
   - Repository scan < 30 seconds
   - Backup initiation < 5 seconds
   - UI responsiveness < 100ms

## Next Steps
1. Set up Xcode project structure
2. Begin ResticCommandService implementation
3. Create basic UI shell
4. Implement initial security framework

## Resource Requirements
- macOS Sonoma (14.0) or later
- Xcode 16.0
- macOS Ventura (13.0) or later
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
