//
//  BackupScheduleTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupScheduleTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup schedule with daily interval", tags: ["basic", "model"])
    func testDailySchedule() throws {
        // Given
        let time = Date()
        
        // When
        let schedule = BackupSchedule(interval: .daily, time: time)
        
        // Then
        #expect(schedule.interval == .daily)
        #expect(schedule.time == time)
    }
    
    @Test("Initialize backup schedule with weekly interval", tags: ["basic", "model"])
    func testWeeklySchedule() throws {
        // Given
        let time = Date()
        
        // When
        let schedule = BackupSchedule(interval: .weekly, time: time)
        
        // Then
        #expect(schedule.interval == .weekly)
        #expect(schedule.time == time)
    }
    
    @Test("Initialize backup schedule with monthly interval", tags: ["basic", "model"])
    func testMonthlySchedule() throws {
        // Given
        let time = Date()
        
        // When
        let schedule = BackupSchedule(interval: .monthly, time: time)
        
        // Then
        #expect(schedule.interval == .monthly)
        #expect(schedule.time == time)
    }
    
    @Test("Initialize backup schedule with custom interval", tags: ["basic", "model"])
    func testCustomSchedule() throws {
        // Given
        let time = Date()
        let hours = 12
        
        // When
        let schedule = BackupSchedule(interval: .custom(hours: hours), time: time)
        
        // Then
        if case let .custom(customHours) = schedule.interval {
            #expect(customHours == hours)
        } else {
            #expect(false, "Expected custom interval")
        }
        #expect(schedule.time == time)
    }
    
    // MARK: - Next Run Time Tests
    
    @Test("Calculate next run time for daily schedule", tags: ["model", "schedule"])
    func testNextRunTimeDaily() throws {
        // Given
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 15 // 3 PM
        components.minute = 30
        let scheduleTime = calendar.date(from: components)!
        let schedule = BackupSchedule(interval: .daily, time: scheduleTime)
        
        // Test cases with different current times
        let testCases = [
            // Current time before schedule time - should run same day
            (
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
            ),
            // Current time after schedule time - should run next day
            (
                calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!)!
            )
        ]
        
        for (currentTime, expectedNextRun) in testCases {
            let nextRun = schedule.nextRunTime(after: currentTime)
            let sameTimeOfDay = calendar.compare(nextRun, to: expectedNextRun, toGranularity: .minute) == .orderedSame
            #expect(sameTimeOfDay, "Next run time incorrect for current time: \(currentTime)")
        }
    }
    
    @Test("Calculate next run time for weekly schedule", tags: ["model", "schedule"])
    func testNextRunTimeWeekly() throws {
        // Given
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 15 // 3 PM
        components.minute = 30
        let scheduleTime = calendar.date(from: components)!
        let schedule = BackupSchedule(interval: .weekly, time: scheduleTime)
        
        // Test cases with different current times
        let testCases = [
            // Current time before schedule time - should run same week
            (
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
            ),
            // Current time after schedule time - should run next week
            (
                calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!)!
            )
        ]
        
        for (currentTime, expectedNextRun) in testCases {
            let nextRun = schedule.nextRunTime(after: currentTime)
            let sameTimeOfDay = calendar.compare(nextRun, to: expectedNextRun, toGranularity: .minute) == .orderedSame
            #expect(sameTimeOfDay, "Next run time incorrect for current time: \(currentTime)")
        }
    }
    
    @Test("Calculate next run time for monthly schedule", tags: ["model", "schedule"])
    func testNextRunTimeMonthly() throws {
        // Given
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 15 // 3 PM
        components.minute = 30
        let scheduleTime = calendar.date(from: components)!
        let schedule = BackupSchedule(interval: .monthly, time: scheduleTime)
        
        // Test cases with different current times
        let testCases = [
            // Current time before schedule time - should run same month
            (
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
            ),
            // Current time after schedule time - should run next month
            (
                calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                calendar.date(byAdding: .month, value: 1, to: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!)!
            )
        ]
        
        for (currentTime, expectedNextRun) in testCases {
            let nextRun = schedule.nextRunTime(after: currentTime)
            let sameTimeOfDay = calendar.compare(nextRun, to: expectedNextRun, toGranularity: .minute) == .orderedSame
            #expect(sameTimeOfDay, "Next run time incorrect for current time: \(currentTime)")
        }
    }
    
    @Test("Calculate next run time for custom schedule", tags: ["model", "schedule"])
    func testNextRunTimeCustom() throws {
        // Given
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 15 // 3 PM
        components.minute = 30
        let scheduleTime = calendar.date(from: components)!
        let schedule = BackupSchedule(interval: .custom(hours: 12), time: scheduleTime)
        
        // Test cases with different current times
        let testCases = [
            // Current time before schedule time - should run at schedule time
            (
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
            ),
            // Current time after schedule time - should run after custom interval
            (
                calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                calendar.date(byAdding: .hour, value: 12, to: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!)!
            )
        ]
        
        for (currentTime, expectedNextRun) in testCases {
            let nextRun = schedule.nextRunTime(after: currentTime)
            let sameTimeOfDay = calendar.compare(nextRun, to: expectedNextRun, toGranularity: .minute) == .orderedSame
            #expect(sameTimeOfDay, "Next run time incorrect for current time: \(currentTime)")
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare schedules for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        // Given
        let time = Date()
        let schedule1 = BackupSchedule(interval: .daily, time: time)
        let schedule2 = BackupSchedule(interval: .daily, time: time)
        let schedule3 = BackupSchedule(interval: .weekly, time: time)
        let schedule4 = BackupSchedule(interval: .daily, time: Date(timeIntervalSinceNow: 3600))
        
        // Then
        #expect(schedule1 == schedule2)
        #expect(schedule1 != schedule3)
        #expect(schedule1 != schedule4)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode schedule", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            BackupSchedule(interval: .daily, time: Date()),
            BackupSchedule(interval: .weekly, time: Date()),
            BackupSchedule(interval: .monthly, time: Date()),
            BackupSchedule(interval: .custom(hours: 12), time: Date())
        ]
        
        for schedule in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(schedule)
            let decoded = try decoder.decode(BackupSchedule.self, from: data)
            
            // Then
            #expect(decoded.interval == schedule.interval)
            #expect(decoded.time == schedule.time)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases in custom intervals", tags: ["model", "validation"])
    func testCustomIntervalEdgeCases() throws {
        let testCases = [
            1, // Minimum 1 hour
            24, // Daily equivalent
            168, // Weekly equivalent
            720, // Monthly equivalent (30 days)
            8760 // Yearly equivalent
        ]
        
        for hours in testCases {
            // When
            let schedule = BackupSchedule(interval: .custom(hours: hours), time: Date())
            
            // Then
            if case let .custom(customHours) = schedule.interval {
                #expect(customHours == hours)
            } else {
                #expect(false, "Expected custom interval")
            }
        }
    }
    
    @Test("Handle daylight saving time transitions", tags: ["model", "schedule"])
    func testDSTTransitions() throws {
        // Given
        let calendar = Calendar.current
        
        // Find next DST transition
        var components = DateComponents()
        components.month = 3 // March for Spring Forward
        components.hour = 2 // 2 AM
        components.minute = 0
        
        guard let dstTransition = calendar.nextDate(after: Date(),
                                                  matching: components,
                                                  matchingPolicy: .nextTime) else {
            #expect(false, "Could not find next DST transition")
            return
        }
        
        // Create schedule for 2:30 AM
        components.hour = 2
        components.minute = 30
        let scheduleTime = calendar.date(from: components)!
        let schedule = BackupSchedule(interval: .daily, time: scheduleTime)
        
        // Test next run time around DST transition
        let beforeDST = calendar.date(byAdding: .hour, value: -1, to: dstTransition)!
        let nextRun = schedule.nextRunTime(after: beforeDST)
        
        // Verify the next run is properly adjusted for DST
        let nextRunHour = calendar.component(.hour, from: nextRun)
        #expect(nextRunHour == 2 || nextRunHour == 3, "Next run should account for DST transition")
    }
    
    // MARK: - Weekly Day Tests
    
    @Test("Handle weekly schedule day selection", tags: ["model", "schedule"])
    func testWeeklyDaySelection() throws {
        // Given
        let time = Date()
        let testCases: [(Set<Weekday>, Bool)] = [
            // Valid cases
            ([.monday, .wednesday, .friday], true),
            ([.saturday, .sunday], true),
            ([.monday], true),
            (Set(Weekday.allCases), true),
            // Invalid cases
            ([], false)
        ]
        
        for (days, isValid) in testCases {
            let schedule = BackupSchedule(interval: .weekly, time: time, weeklyDays: days)
            
            if isValid {
                #expect(schedule.isValid)
                #expect(schedule.weeklyDays == days)
            } else {
                #expect(!schedule.isValid)
            }
        }
    }
    
    // MARK: - Monthly Day Tests
    
    @Test("Handle monthly schedule day selection", tags: ["model", "schedule"])
    func testMonthlyDaySelection() throws {
        // Given
        let time = Date()
        let testCases: [(Set<Int>, Bool)] = [
            // Valid cases
            ([1, 15, 30], true),
            ([1], true),
            (Set(1...31), true),
            // Invalid cases
            ([], false),
            ([0], false),
            ([32], false),
            ([-1], false)
        ]
        
        for (days, isValid) in testCases {
            let schedule = BackupSchedule(interval: .monthly, time: time, monthlyDays: days)
            
            if isValid {
                #expect(schedule.isValid)
                #expect(schedule.monthlyDays == days)
            } else {
                #expect(!schedule.isValid)
            }
        }
    }
    
    // MARK: - Time Window Tests
    
    @Test("Handle backup time window constraints", tags: ["model", "schedule"])
    func testTimeWindowConstraints() throws {
        // Given
        let calendar = Calendar.current
        let testCases: [(DateComponents, DateComponents, Bool)] = [
            // Valid windows
            (
                DateComponents(hour: 1, minute: 0),
                DateComponents(hour: 5, minute: 0),
                true
            ),
            (
                DateComponents(hour: 22, minute: 0),
                DateComponents(hour: 6, minute: 0),
                true
            ),
            // Invalid windows
            (
                DateComponents(hour: 5, minute: 0),
                DateComponents(hour: 1, minute: 0),
                false
            ),
            (
                DateComponents(hour: -1, minute: 0),
                DateComponents(hour: 5, minute: 0),
                false
            )
        ]
        
        for (start, end, isValid) in testCases {
            let schedule = BackupSchedule(
                interval: .daily,
                time: Date(),
                timeWindowStart: calendar.date(from: start),
                timeWindowEnd: calendar.date(from: end)
            )
            
            if isValid {
                #expect(schedule.isValid)
                #expect(schedule.timeWindowStart != nil)
                #expect(schedule.timeWindowEnd != nil)
            } else {
                #expect(!schedule.isValid)
            }
        }
    }
    
    // MARK: - Description Tests
    
    @Test("Generate human-readable schedule descriptions", tags: ["model", "description"])
    func testScheduleDescriptions() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 15
        components.minute = 30
        let time = calendar.date(from: components)!
        
        let testCases: [(BackupSchedule, String)] = [
            (
                BackupSchedule(interval: .daily, time: time),
                "Daily at 15:30"
            ),
            (
                BackupSchedule(
                    interval: .weekly,
                    time: time,
                    weeklyDays: [.monday, .wednesday, .friday]
                ),
                "Weekly on Monday, Wednesday, Friday at 15:30"
            ),
            (
                BackupSchedule(
                    interval: .monthly,
                    time: time,
                    monthlyDays: [1, 15]
                ),
                "Monthly on days 1, 15 at 15:30"
            ),
            (
                BackupSchedule(
                    interval: .custom(hours: 12),
                    time: time
                ),
                "Every 12 hours starting at 15:30"
            )
        ]
        
        for (schedule, expectedDescription) in testCases {
            #expect(schedule.description == expectedDescription)
        }
    }
}
