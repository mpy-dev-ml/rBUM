//
//  BackupNetworkTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
import Network
@testable import rBUM

struct BackupNetworkTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup network with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        
        // When
        let network = BackupNetwork(id: id)
        
        // Then
        #expect(network.id == id)
        #expect(network.isActive == false)
        #expect(network.currentInterface == nil)
        #expect(network.allowedInterfaces.isEmpty)
        #expect(network.bandwidthLimit == nil)
    }
    
    @Test("Initialize backup network with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let isActive = true
        let currentInterface = NetworkInterface(name: "en0", type: .wifi)
        let allowedInterfaces = [NetworkInterface(name: "en0", type: .wifi)]
        let bandwidthLimit: UInt64 = 1024 * 1024 // 1 MB/s
        
        // When
        let network = BackupNetwork(
            id: id,
            isActive: isActive,
            currentInterface: currentInterface,
            allowedInterfaces: allowedInterfaces,
            bandwidthLimit: bandwidthLimit
        )
        
        // Then
        #expect(network.id == id)
        #expect(network.isActive == isActive)
        #expect(network.currentInterface == currentInterface)
        #expect(network.allowedInterfaces == allowedInterfaces)
        #expect(network.bandwidthLimit == bandwidthLimit)
    }
    
    // MARK: - Interface Tests
    
    @Test("Handle network interfaces", tags: ["model", "interface"])
    func testNetworkInterfaces() throws {
        // Given
        var network = BackupNetwork(id: UUID())
        
        let interfaces = [
            NetworkInterface(name: "en0", type: .wifi),
            NetworkInterface(name: "en1", type: .ethernet),
            NetworkInterface(name: "utun0", type: .vpn)
        ]
        
        // Test adding interfaces
        for interface in interfaces {
            network.addAllowedInterface(interface)
        }
        #expect(network.allowedInterfaces.count == interfaces.count)
        
        // Test removing interfaces
        network.removeAllowedInterface(interfaces[0])
        #expect(network.allowedInterfaces.count == interfaces.count - 1)
        #expect(!network.allowedInterfaces.contains(interfaces[0]))
        
        // Test clearing interfaces
        network.clearAllowedInterfaces()
        #expect(network.allowedInterfaces.isEmpty)
    }
    
    // MARK: - Connection Tests
    
    @Test("Handle network connections", tags: ["model", "connection"])
    func testNetworkConnections() throws {
        // Given
        var network = BackupNetwork(id: UUID())
        let interface = NetworkInterface(name: "en0", type: .wifi)
        network.addAllowedInterface(interface)
        
        // Test connection establishment
        network.connect(interface)
        #expect(network.isActive)
        #expect(network.currentInterface == interface)
        
        // Test connection state
        #expect(network.isConnected)
        #expect(network.isAllowedInterface(interface))
        
        // Test disconnection
        network.disconnect()
        #expect(!network.isActive)
        #expect(network.currentInterface == nil)
    }
    
    // MARK: - Bandwidth Tests
    
    @Test("Handle bandwidth limits", tags: ["model", "bandwidth"])
    func testBandwidthLimits() throws {
        let testCases: [(UInt64?, Bool)] = [
            (nil, true),                    // No limit
            (1024 * 1024, true),           // 1 MB/s
            (1024 * 1024 * 10, true),      // 10 MB/s
            (0, false),                     // Invalid: 0
            (100, false)                    // Invalid: too low
        ]
        
        for (limit, isValid) in testCases {
            var network = BackupNetwork(id: UUID())
            
            if isValid {
                network.bandwidthLimit = limit
                #expect(network.bandwidthLimit == limit)
            } else {
                let originalLimit = network.bandwidthLimit
                network.bandwidthLimit = limit
                #expect(network.bandwidthLimit == originalLimit)
            }
        }
    }
    
    // MARK: - Transfer Tests
    
    @Test("Handle data transfers", tags: ["model", "transfer"])
    func testDataTransfers() throws {
        // Given
        var network = BackupNetwork(id: UUID())
        let interface = NetworkInterface(name: "en0", type: .wifi)
        network.addAllowedInterface(interface)
        network.connect(interface)
        
        // Test transfer start
        let transfer = network.startTransfer(size: 1024 * 1024)
        #expect(transfer != nil)
        #expect(transfer?.status == .pending)
        
        // Test transfer progress
        network.updateTransfer(transfer!.id, bytesTransferred: 512 * 1024)
        let updatedTransfer = network.getTransfer(transfer!.id)
        #expect(updatedTransfer?.progress == 0.5)
        
        // Test transfer completion
        network.completeTransfer(transfer!.id)
        let completedTransfer = network.getTransfer(transfer!.id)
        #expect(completedTransfer?.status == .completed)
    }
    
    // MARK: - Error Tests
    
    @Test("Handle network errors", tags: ["model", "error"])
    func testNetworkErrors() throws {
        // Given
        var network = BackupNetwork(id: UUID())
        let interface = NetworkInterface(name: "en0", type: .wifi)
        
        // Test connection errors
        let connectionError = network.connect(interface)
        #expect(connectionError == .interfaceNotAllowed)
        
        // Test transfer errors
        network.addAllowedInterface(interface)
        network.connect(interface)
        
        let transfer = network.startTransfer(size: 1024 * 1024)
        network.disconnect()
        
        let transferError = network.updateTransfer(transfer!.id, bytesTransferred: 512 * 1024)
        #expect(transferError == .notConnected)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Track network statistics", tags: ["model", "statistics"])
    func testNetworkStatistics() throws {
        // Given
        var network = BackupNetwork(id: UUID())
        let interface = NetworkInterface(name: "en0", type: .wifi)
        network.addAllowedInterface(interface)
        network.connect(interface)
        
        // Simulate transfers
        for size in [1024 * 1024, 2 * 1024 * 1024, 3 * 1024 * 1024] {
            let transfer = network.startTransfer(size: size)
            network.completeTransfer(transfer!.id)
        }
        
        // Test statistics
        let stats = network.statistics
        #expect(stats.totalBytesTransferred == 6 * 1024 * 1024)
        #expect(stats.totalTransfers == 3)
        #expect(stats.averageSpeed > 0)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare networks for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let network1 = BackupNetwork(
            id: UUID(),
            isActive: true,
            currentInterface: NetworkInterface(name: "en0", type: .wifi)
        )
        
        let network2 = BackupNetwork(
            id: network1.id,
            isActive: true,
            currentInterface: NetworkInterface(name: "en0", type: .wifi)
        )
        
        let network3 = BackupNetwork(
            id: UUID(),
            isActive: true,
            currentInterface: NetworkInterface(name: "en0", type: .wifi)
        )
        
        #expect(network1 == network2)
        #expect(network1 != network3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup network", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic network
            BackupNetwork(id: UUID()),
            // Active network with interface
            BackupNetwork(
                id: UUID(),
                isActive: true,
                currentInterface: NetworkInterface(name: "en0", type: .wifi),
                allowedInterfaces: [NetworkInterface(name: "en0", type: .wifi)],
                bandwidthLimit: 1024 * 1024
            )
        ]
        
        for network in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(network)
            let decoded = try decoder.decode(BackupNetwork.self, from: data)
            
            // Then
            #expect(decoded.id == network.id)
            #expect(decoded.isActive == network.isActive)
            #expect(decoded.currentInterface == network.currentInterface)
            #expect(decoded.allowedInterfaces == network.allowedInterfaces)
            #expect(decoded.bandwidthLimit == network.bandwidthLimit)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup network properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid network
            (UUID(), true, 1024 * 1024, true),
            // Invalid bandwidth limit
            (UUID(), true, 0, false),
            // Invalid state (active without interface)
            (UUID(), true, nil, false)
        ]
        
        for (id, active, bandwidth, isValid) in testCases {
            var network = BackupNetwork(id: id)
            network.isActive = active
            network.bandwidthLimit = bandwidth
            
            if active {
                network.addAllowedInterface(NetworkInterface(name: "en0", type: .wifi))
                network.connect(NetworkInterface(name: "en0", type: .wifi))
            }
            
            if isValid {
                #expect(network.isValid)
            } else {
                #expect(!network.isValid)
            }
        }
    }
}
