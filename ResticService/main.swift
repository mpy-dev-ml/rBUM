//
//  main.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 9 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation
import os.log

// MARK: - Service Configuration

/// The bundle identifier for the XPC service
private let serviceBundleIdentifier = "dev.mpy.ResticService"

/// Logger for the XPC service main process
private let logger = Logger(
    subsystem: serviceBundleIdentifier,
    category: "ServiceMain"
)

// MARK: - Main Entry Point

logger.info("Starting Restic XPC Service...")

// Verify we're running as an XPC service
guard NSXPCConnection.current() != nil else {
    logger.error("Process not running as XPC service")
    exit(1)
}

// Create and configure the service instance
let service = ResticService()

// Create and configure the XPC listener
let listener = NSXPCListener.service()
listener.delegate = service

// Set up signal handling for graceful shutdown
signal(SIGTERM) { _ in
    logger.info("Received SIGTERM, initiating graceful shutdown...")
    
    // Perform any cleanup here if needed
    
    exit(0)
}

signal(SIGINT) { _ in
    logger.info("Received SIGINT, initiating graceful shutdown...")
    
    // Perform any cleanup here if needed
    
    exit(0)
}

// Start the service
logger.info("Resuming XPC listener...")
listener.resume()

// Run the main loop
logger.info("Entering main run loop...")
RunLoop.main.run()
